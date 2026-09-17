import CoreGraphics
import CoreImage
import Metal
import MetalKit
import UIKit

final class GPU: Sendable {
    /// Lazy init, protected by static let semaphore
    private static let _metalLib: Result<MetalLib, Error> = Result { try MetalLib() }

    private init() {}

    static func metalLib() throws -> MetalLib {
        try _metalLib.get()
    }

    static func warmUpMetalLib() throws {
        _ = try metalLib()
    }
}

final class MetalLib: Sendable {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let checkPipeState: MTLComputePipelineState
    private let renderPipeState: MTLComputePipelineState

    private nonisolated(unsafe) let textureOptions: [MTKTextureLoader.Option: Any] = [
        .SRGB: false,
        .textureUsage: MTLTextureUsage.shaderRead.rawValue,
    ]
    private let context = CIContext()
    private nonisolated(unsafe) let imageOptions: [CIImageOption: Any] = [
        .colorSpace: CGImage.snapshotColorSpace,
    ]
    private let appleNativePixelFormat = MTLPixelFormat.bgra8Unorm

    fileprivate init() throws {
        let device = try MTLCreateSystemDefaultDevice().get(elseThrow: SnapshotError("Не создается MTLCreateSystemDefaultDevice()"))
        let library = try device.makeDefaultLibrary(bundle: try Bundle.snapshotsKitAssets())
        let checkFunction = try library.makeFunction(name: "fastCheckForColorEquality").get(elseThrow: SnapshotError("Не смогли загрузить щейдер makeSnapshotDiff из бандла"))
        let renderFunction = try library.makeFunction(name: "renderSnapshotDiff").get(elseThrow: SnapshotError("Не смогли загрузить щейдер makeSnapshotDiff из бандла"))

        self.device = device
        self.commandQueue = try device.makeCommandQueue().get(elseThrow: SnapshotError("Не создается device.makeCommandQueue()"))
        self.checkPipeState = try device.makeComputePipelineState(function: checkFunction)
        self.renderPipeState = try device.makeComputePipelineState(function: renderFunction)
    }

    func isLooksEqually(_ image1: Snapshot, _ image2: Snapshot) async throws -> Bool {
        async let textureATask = try loadTexture(image1, pointSized: true)
        async let textureBTask = try loadTexture(image2, pointSized: true)

        let (textureA, textureB) = try await (textureATask, textureBTask)

        guard textureA.pixelFormat == appleNativePixelFormat, textureB.pixelFormat == appleNativePixelFormat else {
            throw SnapshotError("Входные текстуры в неверном формате. Ожидался .bgra8Unorm, получили А: \(textureA.pixelFormat), B: \(textureB.pixelFormat)")
        }

        guard let buffer = commandQueue.makeCommandBuffer(), let encoder = buffer.makeComputeCommandEncoder() else {
            throw SnapshotError("Не создался commandBuffer/commandEncoder")
        }

        var failFlag: UInt32 = 0
        let failedFlagBuffer = try device.makeBuffer(
            bytes: &failFlag,
            length: MemoryLayout<UInt32>.size,
            options: .storageModeShared
        ).get(elseThrow: SnapshotError("differenceCountBuffer не создался"))

        try encodeCompare(encoder, checkPipeState, textureA, textureB, failedFlagBuffer)

        buffer.commit()
        await buffer.completed()

        return failedFlagBuffer.contents().assumingMemoryBound(to: Int32.self).pointee == 0
    }

    func renderDiff(_ image1: Snapshot, _ image2: Snapshot) async throws -> Snapshot {
        async let textureATask = try loadTexture(image1, pointSized: false)
        async let textureBTask = try loadTexture(image2, pointSized: false)

        let (textureA, textureB) = try await (textureATask, textureBTask)

        guard textureA.pixelFormat == appleNativePixelFormat, textureB.pixelFormat == appleNativePixelFormat else {
            throw SnapshotError("Входные текстуры в неверном формате. Ожидался .bgra8Unorm, получили А: \(textureA.pixelFormat), B: \(textureB.pixelFormat)")
        }

        guard let buffer = commandQueue.makeCommandBuffer(), let encoder = buffer.makeComputeCommandEncoder() else {
            throw SnapshotError("Не создался commandBuffer/commandEncoder")
        }

        let textureD = try makeTexture(textureA.width, textureA.height)
        try encodeRenderDiff(encoder, renderPipeState, textureA, textureB, textureD)

        buffer.commit()
        await buffer.completed()

        return try makeImageFromTexture(textureD, scale: image1.original.scale)
    }

    private func encodeCompare(
        _ encoder: MTLComputeCommandEncoder,
        _ pipeState: MTLComputePipelineState,
        _ textureA: MTLTexture,
        _ textureB: MTLTexture,
        _ failedFlagBuffer: MTLBuffer
    ) throws {
        encoder.setComputePipelineState(pipeState)
        encoder.setTexture(textureA, index: 0)
        encoder.setTexture(textureB, index: 1)
        encoder.setBuffer(failedFlagBuffer, offset: 0, index: 0)

        let threadsWidth = pipeState.threadExecutionWidth
        let threadsHeight = pipeState.maxTotalThreadsPerThreadgroup / threadsWidth
        let threadsPerThreadgroup = MTLSize(width: threadsWidth, height: threadsHeight, depth: 1)

        if device.supportsFamily(.apple4) {
            let threadsPerGrid = MTLSize(width: textureA.width, height: textureA.height, depth: 1)
            encoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        } else {
            let threadgroupsPerGrid = MTLSize(
                width: (textureA.width + threadsWidth - 1) / threadsWidth,
                height: (textureA.height + threadsHeight - 1) / threadsHeight,
                depth: 1
            )
            encoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        }
        encoder.endEncoding()
    }

    private func encodeRenderDiff(
        _ encoder: MTLComputeCommandEncoder,
        _ pipeState: MTLComputePipelineState,
        _ textureA: MTLTexture,
        _ textureB: MTLTexture,
        _ diffTexture: MTLTexture
    ) throws {
        encoder.setComputePipelineState(pipeState)
        encoder.setTexture(textureA, index: 0)
        encoder.setTexture(textureB, index: 1)
        encoder.setTexture(diffTexture, index: 2)

        let threadsWidth = pipeState.threadExecutionWidth
        let threadsHeight = pipeState.maxTotalThreadsPerThreadgroup / threadsWidth
        let threadsPerThreadgroup = MTLSize(width: threadsWidth, height: threadsHeight, depth: 1)

        if device.supportsFamily(.apple4) {
            let threadsPerGrid = MTLSize(width: diffTexture.width, height: diffTexture.height, depth: 1)
            encoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        } else {
            let threadgroupsPerGrid = MTLSize(
                width: (diffTexture.width + threadsWidth - 1) / threadsWidth,
                height: (diffTexture.height + threadsHeight - 1) / threadsHeight,
                depth: 1
            )
            encoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        }
        encoder.endEncoding()
    }

    private func loadTexture(_ snapshot: Snapshot, pointSized: Bool) async throws -> MTLTexture {
        let cgImage: CGImage
        if pointSized {
            var snapshot = snapshot
            cgImage = try snapshot.scaledForComparison().makeCGImage()
        } else {
            cgImage = try snapshot.original.makeCGImage()
        }
        return try await MTKTextureLoader(device: device)
            .newTexture(cgImage: cgImage, options: textureOptions)
    }

    private func makeTexture(_ width: Int, _ height: Int) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: appleNativePixelFormat, width: width, height: height, mipmapped: false)
        descriptor.usage = [.shaderWrite, .shaderRead]
        descriptor.storageMode = .shared

        return try device.makeTexture(descriptor: descriptor).get(elseThrow: SnapshotError("Не создается diff текстура"))
    }

    private func makeImageFromTexture(_ texture: MTLTexture, scale: CGFloat) throws -> Snapshot {
        guard
            let ciImage = CIImage(mtlTexture: texture, options: imageOptions),
            let cgImage = context.createCGImage(ciImage, from: ciImage.extent)
        else {
            throw SnapshotError("Не можем создать CGImage из MTLTexture")
        }
        let image = UIImage(cgImage: cgImage, scale: scale, orientation: .downMirrored)
        return Snapshot(original: image)
    }
}
