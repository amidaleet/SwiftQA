@testable import QASnapshots
import SwiftUI
import UIKit
import XCTest

final class TraitsTests: XCTestCase {
    @MainActor
    func test_Traits_iPadGroups_Regular() {
        let devices = (SnapshotDeviceGroup.tablet.universal + .tablet13).devices

        for device in devices {
            Env.assertRenderedTraits(
                device: device,
                horizontalSizeClass: .regular,
                verticalSizeClass: .regular,
                userInterfaceIdiom: .pad
            )
        }
    }

    @MainActor
    func test_Traits_TabletCompactColumn_Compact() {
        for device in SnapshotDeviceGroup.tabletCompactColumn.devices {
            Env.assertRenderedTraits(
                device: device,
                horizontalSizeClass: .compact,
                verticalSizeClass: .regular,
                userInterfaceIdiom: .pad
            )
        }
    }

    @MainActor
    func test_Traits_TabletSplitMode_ColumnSizesAndTraits() {
        let devices = SnapshotDeviceGroup.tabletSplitMode.devices

        XCTAssertEqual(
            devices.map(\.size),
            [
                CGSize(width: 320, height: 1_133),
                CGSize(width: 414, height: 1_133),
                CGSize(width: 375, height: 744),
                CGSize(width: 561.5, height: 744),
                CGSize(width: 748, height: 744),
            ]
        )
        XCTAssertEqual(
            devices.map(\.traits),
            [.iPadCompactColumn, .iPadCompactColumn, .iPadCompactColumn, .iPadCompactColumn, .iPad]
        )
        let horizontalSizeClasses: [UIUserInterfaceSizeClass] = [.compact, .compact, .compact, .compact, .regular]
        for (device, horizontalSizeClass) in zip(devices, horizontalSizeClasses) {
            Env.assertRenderedTraits(
                device: device,
                horizontalSizeClass: horizontalSizeClass,
                verticalSizeClass: .regular,
                userInterfaceIdiom: .pad
            )
        }
    }

    @available(iOS 17.0, *)
    @MainActor
    func test_Traits_PhoneAndCustom_NotOverridden() {
        let devices = SnapshotDeviceGroup.phone.devices + SnapshotDeviceGroup.custom().devices

        for device in devices {
            XCTAssertEqual(device.traits, .simulator)
            Env.assertNoTraitOverrides(device: device)
        }
    }

    func test_Traits_DoubledWidth_KeepsTraits() {
        let devices = SnapshotDeviceGroup.tablet.doubledWidth.devices

        XCTAssertEqual(devices.map(\.traits), [.iPad])
    }

    func test_ReferenceNames_Groups_Unique() {
        let groups: [SnapshotDeviceGroup] = [
            .phone.universal,
            .tablet.universal,
            .tablet13.universal,
            .tabletCompactColumn,
            .tabletSplitMode,
            .tablet.universal + .tablet13 + .tabletCompactColumn,
        ]

        for group in groups {
            XCTAssertTrue(group.hasUniqueReferenceNames, "\(group.devices.map(\.referenceSizeName))")
        }
        XCTAssertFalse((SnapshotDeviceGroup.tablet + .tablet).hasUniqueReferenceNames)
    }
}

private struct RenderedSut {
    let name: String
    let sut: SnapshotSut
    let renderedTraits: @MainActor () -> UITraitCollection?
}

private enum Env {
    @MainActor
    static func assertRenderedTraits(
        device: SnapshotDevice,
        horizontalSizeClass: UIUserInterfaceSizeClass,
        verticalSizeClass: UIUserInterfaceSizeClass,
        userInterfaceIdiom: UIUserInterfaceIdiom,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let view = TraitsView()
        let controller = TraitsViewController()
        let swiftUIView = TraitsSwiftUIView()
        let suts = [
            RenderedSut(name: "UIView", sut: view, renderedTraits: { view.renderedTraits }),
            RenderedSut(name: "UIViewController", sut: controller, renderedTraits: { controller.traitsView?.renderedTraits }),
        ]
        let message = device.attachmentDescription

        for sut in suts {
            _ = SnapshotCanvas(sut: sut.sut, screen: device).capture()
            let traits = sut.renderedTraits()
            let sutMessage = "\(sut.name), \(message)"

            XCTAssertEqual(traits?.horizontalSizeClass, horizontalSizeClass, sutMessage, file: file, line: line)
            XCTAssertEqual(traits?.verticalSizeClass, verticalSizeClass, sutMessage, file: file, line: line)
            XCTAssertEqual(traits?.userInterfaceIdiom, userInterfaceIdiom, sutMessage, file: file, line: line)
        }

        _ = SnapshotCanvas(sut: swiftUIView.snapshotSut(), screen: device).capture()

        XCTAssertEqual(swiftUIView.box.horizontalSizeClass, horizontalSizeClass.swiftUI, message, file: file, line: line)
        XCTAssertEqual(swiftUIView.box.verticalSizeClass, verticalSizeClass.swiftUI, message, file: file, line: line)
    }

    @available(iOS 17.0, *)
    @MainActor
    static func assertNoTraitOverrides(
        device: SnapshotDevice,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let controller = TraitsViewController()
        let canvases = [
            SnapshotCanvas(sut: TraitsView(), screen: device),
            SnapshotCanvas(sut: controller, screen: device),
        ]
        let message = device.attachmentDescription

        for canvas in canvases {
            canvas.loadViewIfNeeded()
        }
        for overrides in canvases.map(\.traitOverrides) + [controller.traitOverrides] {
            XCTAssertFalse(overrides.contains(UITraitHorizontalSizeClass.self), message, file: file, line: line)
            XCTAssertFalse(overrides.contains(UITraitVerticalSizeClass.self), message, file: file, line: line)
            XCTAssertFalse(overrides.contains(UITraitUserInterfaceIdiom.self), message, file: file, line: line)
        }
    }
}
