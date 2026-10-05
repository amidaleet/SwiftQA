# QA

Utilities for writing tests: formatting, equality, assertions, and UI snapshots.

- `PrettyDump` formats arbitrary values and errors for logs, assertions, and JSON.
- `CustomDump` mirrors values for logs and diffs.
- `QAMust` is the XCTest layer on top of them + test helpers (like equality by walking mirrors).
- `QASnapshots` compares rendered views to PNG references.

## Requirements

- iOS 15+
- Swift 6
- Xcode 16+ (SwiftSyntax 600)
- XCTest, linked by:
  - `QASnapshots`
  - `QAMust`

  Use those products from a unit-test target.
  UI snapshots also need a host app.

UI snapshot tests need an iOS Simulator host.
Macro expansion tests run on macOS with `swift test`.

Snapshot test targets need an `.xcodeproj`:

- Set the host app in `TEST_HOST` to run UIKit or SwiftUI.
- Swift Package targets do not support `TEST_HOST`.

## Installation

Add this package as depenency to project.

```swift
dependencies: [
    .package(url: "https://github.com/amidaleet/SwiftQA.git", from: "1.0.0"),
],
```

- `PrettyDump` — every target that calls `Pretty` or conforms to `PrettyError` / `PrettyConvertible`.
- `CustomDump` — any target that needs a mirror diff or `customDump`.
  - Does not link XCTest.
- `QAMust` — test target only.
  - Links XCTest.
  - Depends on `CustomDump` and `PrettyDump`.
- `QASnapshots` — test target only.
  - Links XCTest.
  - Depends on `PrettyDump`.
- `QASnapshotsAssets` — host app or the test target, so SwiftPM copies the resource bundle.

## QASnapshots

Swift snapshot testing for UIKit and SwiftUI.
Compare a rendered view to a PNG reference on a set of device sizes, with optional accessibility overlays and light/dark dual frames.

### `@SnapshotSuite`

Functions named `test*` become XCTest methods when they return:

- `some View`
- `UIView`
- `UIViewController`
- `SnapshotSut`
- `SnapshotSutHolder`

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

- `@SnapshotTest` overrides suite defaults on one test.
- `@UnitTest` marks a `test*` function that is not a snapshot.

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

`@DualThemeSnapshotSuite` captures light and dark in one double-width frame.
Implement `SnapshotThemeApplying` and pass the type:

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

- Name: `{testName}_{width}x{height}@{scale}x.png`
- `includeAccessibility: true` adds a `_Accessibility` suffix.

On mismatch the matcher writes these beside the reference and attaches the merge image to the XCTest activity:

- `*_diff.png`
- `*_new.png`
- `*_merge.png`

## Simulator requirement

By default any simulator is allowed.
Pin a model and OS if references must not drift.

**Code** (wins over the environment variable):

```swift
Snapshots.requireSimulator(
    model: "iPhone17,3",
    os: OperatingSystemVersion(majorVersion: 26, minorVersion: 5, patchVersion: 0),
    hint: "<Add here your repo command to create and prepare desired iOS simulator>"
)
```

Call this once from the test bundle, for example:

- `setUp` of a base class
- a module initializer

**Environment**

```
QA_SNAPSHOTS_SIMULATOR=iPhone17,3@26.5.0
QA_SNAPSHOTS_SIMULATOR_HINT=Optional extra text in the failure message
```

Format is `SIMULATOR_MODEL_IDENTIFIER@major.minor.patch`.

- Record mode checks before capture and skips on mismatch.
- Verify mode checks only after a failed comparison.

## PrettyDump

```swift
import PrettyDump

Pretty.string(model)
Pretty.json(model)

struct Timeout: PrettyError {}
```

`Pretty.convert` mirrors the value into a `PrettyElement`.
Conform to `PrettyConvertible` when that mirror is too noisy.

- `PrettyUnconvertible` prints the type name.
- `PrettyRawConvertible` prints the raw value.
- `PrettyError` builds a stable domain, name, and code for `NSError`.
- `JSON` is `typealias JSON = Any`.

`PrettyDump` and `CustomDump` do not link XCTest.
All library products are static.

In an Xcode project, link them only from the final image:

- app
- extension
- test bundle

A static framework that links a product copies its object file into the archive.
Another copy in the same image duplicates symbols.
Package targets have no autolink entries, so a static framework that only imports the product still needs the final image to link it.

## CustomDump

Mirror-based dump and diff.
Safe for production targets.

```swift
import CustomDump

String(customDumping: model)
diff(previous, current) // nil when the mirrors match
```

`diff` returns a line diff, or `nil` when the values match.

- `DiffFormat.default` uses `-`, `+`, and space.
- `DiffFormat.proportional` uses characters that line up in Xcode's failure font.

Conform to one of these when the default mirror is too noisy:

- `CustomDumpReflectable`
- `CustomDumpStringConvertible`
- `CustomDumpRepresentable`

## QAMust

XCTest assertions.
Test targets only.

```swift
import QAMust

Must.equal(received, expected)
Must.beTrue(flag)
Must.beFalse(flag)
Must.beNil(value)
Must.beNotNil(value)
Must.throwError({ try decode() }, DecodeError.invalid)
```

Names drop the `assert` prefix.

`Must.equal` prints a `CustomDump` diff (`DiffFormat.proportional`) when the values differ.

- `Must.equal` requires `Equatable` and uses `==`.
- `Must.mirrorEqual` uses `areMirrorEqual`, including when the type is `Equatable`.
- `Must.containAll` and `Must.containAllMirrorEqual` are the same split.

`QAMustTests` covers these assertions.

### MirrorEqual

```swift
import QAMust

struct LoginState: MirrorEquatable {
    var email = ""
    var token = ""
}

areMirrorEqual(received, expected)
```

`MirrorEquatable` synthesizes `==` by walking the mirror, so stored properties do not have to be `Equatable`.

- Dictionaries match by key.
- Sets ignore order.
- Conform to `AlwaysEqualToSameMetatypeInMirror` when a field should count as equal for any two values of that same type, instead of walking its children.

## Package layout

| Product / target | Role |
| --- | --- |
| `PrettyDump` | Value and error formatting: `Pretty`, `PrettyElement`, `PrettyConvertible`, `PrettyError`. |
| `PrettyDumpTests` | Unit tests for `PrettyDump`. SPM test target (`swift test`). |
| `CustomDump` | Mirror dump and diff: `customDump`, `diff`. No XCTest. |
| `QAMust` | XCTest assertions: `Must`, `MirrorEquatable`, `areMirrorEqual`. Depends on `CustomDump` and `PrettyDump`. |
| `QAMustTests` | Unit tests for `Must`, `areMirrorEqual`. SPM test target (`swift test`). |
| `QASnapshots` | Runtime: capture, compare (CPU / Metal), macros. Links `XCTest`. Depends on `PrettyDump`. |
| `QASnapshotsAssets` | Resource bundle (Metal, localization, Crosshairs). Depend on it from the host app or test target. |
| `QASnapshotsMacros` | Compiler plugin (`@SnapshotSuite`, `@SnapshotTest`, `@UnitTest`, `@DualThemeSnapshotSuite`) |
| `QASnapshotsMacrosTests` | Macro expansion tests |

`QASnapshotsTests` (UI snapshots) is not an SPM test target.
It needs a host app, so an Xcode project is required to run it.
