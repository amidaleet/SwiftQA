@testable import QASnapshots
import SwiftUI
import UIKit
import XCTest

final class DualThemeSnapshotTests: XCTestCase {
    @MainActor
    func test_Make_DoubledWidthDevice_ThemeGetsOriginalDeviceForBothHalves() {
        let group = SnapshotDeviceGroup.phone + .tablet + .tabletCompactColumn
        XCTAssertEqual(group.doubledWidth.devices.count, group.devices.count)

        for (device, doubled) in zip(group.devices, group.doubledWidth.devices) {
            RecordingTheme.devices = []

            _ = DualThemeSnapshot.make(Color.clear, device: doubled, theme: RecordingTheme.self)

            let message = device.referenceSizeName
            XCTAssertEqual(RecordingTheme.devices.map(\.size), [device.size, device.size], message)
            XCTAssertEqual(RecordingTheme.devices.map(\.insets), [device.insets, device.insets], message)
            XCTAssertEqual(RecordingTheme.devices.map(\.scale), [device.scale, device.scale], message)
            XCTAssertEqual(RecordingTheme.devices.map(\.traits), [device.traits, device.traits], message)
        }
    }

    func test_HalfWidth_LandscapeDevice_HalvesOnlyWidth() {
        let device = SnapshotDeviceGroup.tablet.landscape.devices[0]

        let half = device.halfWidth

        XCTAssertEqual(half.size, CGSize(width: device.size.width / 2, height: device.size.height))
        XCTAssertEqual(half.orientation, device.orientation)
        XCTAssertEqual(half.insets, device.insets)
        XCTAssertEqual(half.isCropOn, device.isCropOn)
    }
}

@MainActor
private enum RecordingTheme: SnapshotThemeApplying {
    static var devices: [SnapshotDevice] = []

    static func prepare(
        _ sut: some View,
        colorScheme _: ColorScheme,
        device: SnapshotDevice
    ) -> AnyView {
        devices.append(device)
        return AnyView(sut)
    }
}
