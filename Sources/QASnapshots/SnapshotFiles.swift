import Foundation
import UIKit
import XCTest

struct SnapshotFiles {
    private let fileManager: FileManager = .default
    private let screen: SnapshotDevice
    private let isComparisonFilesUseful: Bool

    private let folder: URL

    let reference: URL
    let diff: URL
    let new: URL
    let merge: URL

    init(
        device: SnapshotDevice,
        testName: String,
        suffix: String,
        testFile: StaticString,
        isComparisonFilesUseful: Bool
    ) throws {
        screen = device
        let referenceURL = device.referenceURL(testName: testName, suffix: suffix, testFile: testFile)
        folder = referenceURL.deletingLastPathComponent()
        reference = referenceURL
        diff = try referenceURL.addingSuffixInImageURL("diff")
        new = try referenceURL.addingSuffixInImageURL("new")
        merge = try referenceURL.addingSuffixInImageURL("merge")
        self.isComparisonFilesUseful = isComparisonFilesUseful
    }

    /// Форматируем аналогично reference (в PNG) для корректного сравнения
    func formatSnapshot(_ image: UIImage) throws -> UIImage {
        try UIImage(data: try image.makePNGData(), scale: screen.scale)
            .get(elseThrow: SnapshotError("Не смогли отформатировать snapshot image пол scale от reference"))
    }

    func recordReference(_ image: UIImage) throws {
        try createFolderIfMissing()
        try image.makePNGData().write(to: reference)
    }

    func removeDiff() throws {
        for path in [diff.path, new.path, merge.path] where fileManager.fileExists(atPath: path) {
            try fileManager.removeItem(atPath: path)
        }
    }

    @concurrent
    func recordDiff(_ new: Snapshot, _ reference: Snapshot) async throws {
        guard isComparisonFilesUseful else { return }

        let diff = try await GPU.metalLib().renderDiff(new, reference)
        let images = [reference.original, new.original, diff.original]
        let mergeSize = CGSize(
            width: images.reduce(into: CGFloat(0)) { $0 += $1.size.width },
            height: reference.original.size.height
        )
        let merge = UIGraphicsImageRenderer(size: mergeSize).image { _ in
            var shift: CGFloat = 0
            for image in images {
                image.draw(at: CGPoint(x: shift, y: 0))
                shift += image.size.width
            }
        }
        let attachmentDescription = screen.attachmentDescription
        async let saveAttechmentResult = await Self.saveXctAttachment(merge, attachmentDescription)

        try createFolderIfMissing()
        try new.original.makePNGData().write(to: self.new)
        try diff.original.makePNGData().write(to: self.diff)
        try merge.makePNGData().write(to: self.merge)

        await saveAttechmentResult
    }

    private func createFolderIfMissing() throws {
        if !fileManager.fileExists(atPath: folder.path) {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        }
    }

    @MainActor
    private static func saveXctAttachment(_ image: UIImage, _ attachmentDescription: String) async {
        XCTContext.runActivity(named: attachmentDescription) {
            $0.attach(image, "Render")
        }
    }
}

extension URL {
    fileprivate func addingSuffixInImageURL(_ suffix: String) throws -> URL {
        guard let url = URL(string: absoluteString.addingSuffixInImageURL(suffix)) else {
            throw SnapshotError("Не смогли добавить суффикс: \(suffix) к url: \(absoluteString)")
        }
        return url
    }
}

extension String {
    fileprivate func addingSuffixInImageURL(_ suffix: String) -> String {
        guard let splitIndex = lastIndex(of: ".") else {
            return self
        }
        return String(self[..<splitIndex]) + "_" + suffix + String(self[splitIndex...])
    }
}

extension XCTActivity {
    fileprivate func attach(_ image: UIImage, _ name: String) {
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        add(attachment)
    }
}
