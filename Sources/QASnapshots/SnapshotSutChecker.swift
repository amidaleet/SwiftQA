import SwiftUI
import UIKit

final class SnapshotSutChecker: @unchecked Sendable {
    /// Have to hold all the suts to avoid ID collision
    private var suts: [SnapshotSut] = []
    private var seenIDs: Set<ObjectIdentifier> = []

    var isFailed: Bool { suts.count != seenIDs.count }

    @MainActor
    func check(_ sut: SnapshotSut) throws {
        suts.append(sut)
        if !seenIDs.insert(sut.sutID).inserted {
            throw SnapshotError.sutReused
        }
    }
}
