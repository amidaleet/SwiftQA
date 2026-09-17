import Foundation

extension Bundle {
    static func snapshotsKitAssets() throws -> Bundle {
        let names = [
            "QASnapshotsAssets",
            "QA_QASnapshotsAssets",
            "QASnapshotsAssets_QASnapshotsAssets",
        ]
        for name in names {
            if let bundle = Bundle.main.tryChild(name) {
                return bundle
            }
        }
        let owner = Bundle(for: SnapshotCanvas.self)
        for name in names {
            if let bundle = owner.tryChild(name) {
                return bundle
            }
        }
        throw SnapshotError("Не нашли бандл QASnapshotsAssets — добавьте product QASnapshotsAssets в host app или тестовый таргет")
    }
}
