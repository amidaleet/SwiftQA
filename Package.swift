// swift-tools-version:6.3

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "QA",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15),
        .macOS(.v15),
    ],
    products: [
        .library(name: "PrettyDump", targets: ["PrettyDump"]),
        .library(name: "QASnapshots", targets: ["QASnapshots"]),
        .library(name: "QASnapshotsAssets", targets: ["QASnapshotsAssets"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax", "600.0.1" ..< "605.0.0"),
    ],
    targets: [
        .target(name: "PrettyDump"),
        .testTarget(
            name: "PrettyDumpTests",
            dependencies: ["PrettyDump"]
        ),
        .macro(
            name: "QASnapshotsMacros",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "QASnapshots",
            dependencies: ["QASnapshotsMacros", "PrettyDump"],
            linkerSettings: [
                .linkedFramework("XCTest"),
            ]
        ),
        .target(
            name: "QASnapshotsAssets",
            resources: [
                .process("Snapshots.metal"),
                .process("Images.xcassets"),
                .process("en.lproj"),
                .process("ru.lproj"),
                .process("de.lproj"),
            ]
        ),
        .testTarget(
            name: "QASnapshotsMacrosTests",
            dependencies: [
                "QASnapshotsMacros",
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
