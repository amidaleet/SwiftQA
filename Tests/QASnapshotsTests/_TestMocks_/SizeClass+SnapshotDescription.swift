import SwiftUI
import UIKit

extension UIUserInterfaceSizeClass {
    var snapshotDescription: String {
        switch self {
        case .compact: "compact"
        case .regular: "regular"
        default: "unspecified"
        }
    }

    var swiftUI: UserInterfaceSizeClass? {
        switch self {
        case .compact: .compact
        case .regular: .regular
        default: nil
        }
    }
}

extension UserInterfaceSizeClass {
    var snapshotDescription: String {
        switch self {
        case .compact: "compact"
        case .regular: "regular"
        @unknown default: UIUserInterfaceSizeClass.unspecified.snapshotDescription
        }
    }
}
