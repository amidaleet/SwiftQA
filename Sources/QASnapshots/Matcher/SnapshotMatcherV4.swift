import UIKit
import XCTest

struct SnapshotMatcherV4: @unchecked Sendable {
    private static let bytesPerPixel = 4 // RGBA
    private static let maxColorComponentDelta = 15 // out of 255
    private static let colorsSliceSize = 16_000 // pixels * 4 (RGBA)

    private let files: SnapshotFiles
    private let mode: SnapshotMode
    private let snapshot: UIImage

    init(
        snapshot: UIImage,
        files: SnapshotFiles,
        mode: SnapshotMode
    ) throws {
        self.snapshot = try files.formatSnapshot(snapshot)
        self.files = files
        self.mode = mode
    }

    @concurrent
    func run() async throws {
        switch mode {
        case let .record(onlyChanged, removeDiff):
            return try await record(onlyChanged: onlyChanged, removeDiff: removeDiff)
        case .verify:
            return try await verify()
        }
    }

    private func record(onlyChanged: Bool, removeDiff: Bool) async throws {
        if onlyChanged {
            do {
                try await verify()
            } catch {
                try files.recordReference(snapshot)
            }
        } else {
            try files.recordReference(snapshot)
        }

        if removeDiff {
            try files.removeDiff()
        }
    }

    private func verify() async throws {
        let referenceData = try Data(contentsOf: files.reference)
        guard let reference = UIImage(data: referenceData, scale: snapshot.scale) else {
            throw SnapshotError.corruptedPNGFile(files.reference)
        }

        let isEqual = try await compare(snapshot, reference)

        if isEqual {
            /// Подчищаем от прошлого прогона, если остались
            try files.removeDiff()
        } else {
            try await files.recordDiff(Snapshot(original: snapshot), Snapshot(original: reference))
            throw SnapshotError.testFailed(files.merge)
        }
    }

    private func compare(_ snapshot: UIImage, _ reference: UIImage) async throws -> Bool {
        guard snapshot.size == reference.size else {
            throw SnapshotError.differentImageSizes(snapshot.size, reference.size)
        }

        let snapshotCGImage = try snapshot.makeCGImage()
        let referenceCGImage = try reference.makeCGImage()

        guard snapshotCGImage.bitsPerPixel == referenceCGImage.bitsPerPixel else {
            throw SnapshotError.differentImageSizes(snapshot.size, reference.size)
        }
        guard snapshotCGImage.bitsPerPixel / 8 == Self.bytesPerPixel else {
            throw SnapshotError.differentImageSizes(snapshot.size, reference.size)
        }

        // Рассчитываем bitmap в размерах UIImage.size (points).
        // Реальный размер (pixels): snapshotCGImage.size == pointsSize * scale
        let bitmapSize = snapshot.size

        async let snapshotColorsAsync = Task { snapshotCGImage.pixelColorBytesVector(bitmapSize) }.value
        async let referenceColorsAsync = Task { referenceCGImage.pixelColorBytesVector(bitmapSize) }.value

        let (snapshotColors, referenceColors) = await (snapshotColorsAsync, referenceColorsAsync)

        guard snapshotColors.count == referenceColors.count, snapshotColors.count % Self.bytesPerPixel == 0 else {
            throw SnapshotError.differentImageSizes(snapshotCGImage.size, referenceCGImage.size)
        }

        return await withTaskGroup(of: Bool.self) { group in
            var index = 0

            while index < snapshotColors.endIndex {
                let start = index
                let end = min(index + Self.colorsSliceSize, snapshotColors.endIndex)

                group.addTask {
                    if Task.isCancelled { return true }

                    return isAllPixelsRGBAMatches(snapshotColors[start ..< end], referenceColors[start ..< end])
                }
                index += Self.colorsSliceSize
            }
            for await isSliceColorsMatches in group where !isSliceColorsMatches {
                group.cancelAll()
                return false
            }
            return true
        }
    }

    private func isAllPixelsRGBAMatches(_ left: ArraySlice<UInt8>, _ right: ArraySlice<UInt8>) -> Bool {
        var componentNumber = 0 // 1...4 - color part, 0 - unset
        var index = left.startIndex

        while index < left.endIndex {
            componentNumber += 1

            let left = left[index]
            let right = right[index]
            // Разница между компонентой цвета пикселя (абсолют, >= 0)
            let diff = left > right ? left - right : right - left

            if diff > Self.maxColorComponentDelta {
                return false
            }

            if componentNumber == Self.bytesPerPixel {
                // moving to next color
                componentNumber = 0
            }
            index += 1
        }

        return true
    }
}
