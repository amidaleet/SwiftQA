import UIKit
import XCTest

struct SnapshotMatcherV5 {
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
        let image1 = Snapshot(original: snapshot)
        let image2 = Snapshot(original: reference)

        guard image1.original.size == image2.original.size else {
            throw SnapshotError.differentImageSizes(image1.original.size, image2.original.size)
        }

        if try await GPU.metalLib().isLooksEqually(image1, image2) {
            /// Подчищаем от прошлого прогона, если остались
            try files.removeDiff()
        } else {
            try await files.recordDiff(image1, image2)
            throw SnapshotError.testFailed(files.merge)
        }
    }
}
