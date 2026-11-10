@testable import QASnapshots
import SwiftUI
import UIKit
import XCTest

@SnapshotSuite(deviceGroup: .tablet.universal + .tablet13 + .tabletCompactColumn)
struct TraitsSnapshotTests {
    func test_Traits_InView() -> UIView {
        TraitsView()
    }

    func test_Traits_InViewController() -> UIViewController {
        TraitsViewController()
    }

    func test_Traits_InSwiftUIView() -> some View {
        TraitsSwiftUIView()
    }
}
