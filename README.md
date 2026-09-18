# QA

Swift snapshot testing for UIKit and SwiftUI. Compare a rendered view to a PNG reference on a set of device sizes, with optional accessibility overlays and light/dark dual frames.

## Requirements

- iOS 15+
- Swift 6
- Xcode 16+ (SwiftSyntax 600)
- XCTest (linked by `QASnapshots`; use that product from a unit-test target with a host app)

UI snapshot tests need an iOS Simulator host. Macro expansion tests run on macOS with `swift test`.

You need to have `.xcodeproj` to host your snapshot test targets. Test target should set the host app in TEST_HOST setting in order to run UIKit/SwiftUI. Swift Package targets do not support TEST_HOST.

## Installation

Add this package as depenency to project.

```swift
dependencies: [
    .package(url: "https://github.com/amidaleet/SwiftQA.git", from: "1.0.0"),
],
```

Add `QASnapshots` to the test target only (it links XCTest).

Add `QASnapshotsAssets` to the host app or the test target so SwiftPM copies the resource bundle. 

## Usage

### `@SnapshotSuite`

Functions named `test*` that return `some View`, `UIView`, `UIViewController`, `SnapshotSut`, or `SnapshotSutHolder` become XCTest methods:

```swift
import QASnapshots
import SwiftUI
import XCTest

@SnapshotSuite(deviceGroup: .phone)
struct MyViewTests {
    func test_Default() -> some View {
        MyView()
    }

    @SnapshotTest(deviceGroup: .tablet, includeAccessibility: true)
    func test_iPad(device: SnapshotDevice) -> UIView {
        MyUIView()
    }

    @UnitTest
    func test_Logic() {
        XCTAssertEqual(2 + 2, 4)
    }
}
```

Override suite defaults on one test with `@SnapshotTest`. Mark a `test*` function that is not a snapshot as `@UnitTest`.

### Imperative API

```swift
await Snapshots.match(deviceGroup: .phone) { _ in
    MyView()
}

await Snapshots.matchErrors(
    expected: [SnapshotError.sutReused],
    prepareReference: { _ in ReferenceView() },
    prepareSut: { _ in reusedView }
)
```

### Dual theme

`@DualThemeSnapshotSuite` captures light and dark in one double-width frame. Implement `SnapshotThemeApplying` and pass the type:

```swift
@DualThemeSnapshotSuite(theme: AppSnapshotTheme.self, deviceGroup: .phone)
struct ThemedViewTests {
    func test_Card() -> some View {
        CardView()
    }
}
```

Or call `Snapshots.matchDualThemes` and lay out the two halves yourself.

### Devices and mode

| API | Role |
| --- | --- |
| `.phone` | iPhone SE + iPhone 13 mini |
| `.tablet` | iPad mini |
| `.phone.universal` | portrait + landscape |
| `.phone.noSafeArea` / `.cropped` | modifiers on a group |
| `.custom(width:height:)` | fixed canvas |
| `mode: .verify` | compare to reference (default) |
| `mode: .record` | write / update the PNG |

Reference files live next to the test source:

```
MyViewTests.swift
_Snapshots_/Default_375x667@2x.png
```

Names are `{testName}_{width}x{height}@{scale}x.png`. A `_Accessibility` suffix is added when `includeAccessibility: true`.

On mismatch the matcher writes `*_diff.png`, `*_new.png`, and `*_merge.png` beside the reference and attaches the merge image to the XCTest activity.

## Simulator requirement

By default any simulator is allowed. Pin a model and OS if references must not drift.

**Code** (wins over the environment variable):

```swift
Snapshots.requireSimulator(
    model: "iPhone17,3",
    os: OperatingSystemVersion(majorVersion: 26, minorVersion: 5, patchVersion: 0),
    hint: "<Add here your repo command to create and prepare desired iOS simulator>"
)
```

Call this once from the test bundle (for example in `setUp` of a base class, or a module initializer).

**Environment**

```
QA_SNAPSHOTS_SIMULATOR=iPhone17,3@26.5.0
QA_SNAPSHOTS_SIMULATOR_HINT=Optional extra text in the failure message
```

Format is `SIMULATOR_MODEL_IDENTIFIER@major.minor.patch`. Record mode checks before capture and skips on mismatch. Verify mode checks only after a failed comparison.

## Package layout

| Product / target | Role |
| --- | --- |
| `QASnapshots` | Runtime: capture, compare (CPU / Metal), macros. Links `XCTest`. |
| `QASnapshotsAssets` | Resource bundle (Metal, localization, Crosshairs). Depend on it from the host app or test target. |
| `QASnapshotsMacros` | Compiler plugin (`@SnapshotSuite`, `@SnapshotTest`, `@UnitTest`, `@DualThemeSnapshotSuite`) |
| `QASnapshotsMacrosTests` | Macro expansion tests |

`QASnapshotsTests` (UI snapshots) is not an SPM test target: it needs a host app, so an Xcode project is required to run it.
