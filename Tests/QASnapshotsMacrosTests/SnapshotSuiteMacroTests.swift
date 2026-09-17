import QASnapshotsMacros
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

final class SnapshotSuiteMacroTests: XCTestCase {
    private let testMacros: [String: Macro.Type] = [
        "SnapshotSuite": SnapshotSuiteMacro.self,
        "SnapshotTest": SnapshotTestMacro.self,
        "UnitTest": UnitTestMacro.self,
        "DualThemeSnapshotSuite": SnapshotSuiteMacro.self,
    ]

    // MARK: - Host generation

    func test_generatesHost_forSnapshotTests() throws {
        assertMacroExpansion(
            """
            @SnapshotSuite
            struct MyViewTests {
                var context = ViewContext.tests()

                func test_iPhone_Light() -> SnapshotSut {
                    return MyView().makeUIView(context)
                }

                func testIPhoneDark() -> SnapshotSut {
                    return MyView().makeUIView(context)
                }
            }
            """,
            expandedSource: """
            struct MyViewTests {
                var context = ViewContext.tests()

                func test_iPhone_Light() -> SnapshotSut {
                    return MyView().makeUIView(context)
                }

                func testIPhoneDark() -> SnapshotSut {
                    return MyView().makeUIView(context)
                }
            }

            final class MyViewTestsHost: XCTestCase {
                func test_iPhone_Light() async {
                    await Snapshots.match(prepareSut: { _ in
                        let suite = MyViewTests()
                        return suite.test_iPhone_Light()
                    })
                }

                func testIPhoneDark() async {
                    await Snapshots.match(prepareSut: { _ in
                        let suite = MyViewTests()
                        return suite.testIPhoneDark()
                    })
                }
            }
            """,
            macros: testMacros
        )
    }

    func test_generatesHost_withSnapshotTestAttribute() throws {
        assertMacroExpansion(
            """
            @SnapshotSuite
            struct MyViewTests {
                @SnapshotTest(mode: .record, deviceGroup: .tablet, includeAccessibility: true)
                func test_iPad() -> SnapshotSut {
                    return MyView().makeUIView(context)
                }
            }
            """,
            expandedSource: """
            struct MyViewTests {
                func test_iPad() -> SnapshotSut {
                    return MyView().makeUIView(context)
                }
            }

            final class MyViewTestsHost: XCTestCase {
                func test_iPad() async {
                    await Snapshots.match(mode: .record, deviceGroup: .tablet, includeAccessibility: true, prepareSut: { _ in
                        let suite = MyViewTests()
                        return suite.test_iPad()
                    })
                }
            }
            """,
            macros: testMacros
        )
    }

    func test_generatesHost_withTestName() throws {
        assertMacroExpansion(
            """
            @SnapshotSuite
            struct MyViewTests {
                @SnapshotTest(testName: "CustomSnapshotName")
                func test_MakeSaveCardModel_DarkUserInterfaceStyle() -> SnapshotSut {
                    return MyView()
                }
            }
            """,
            expandedSource: """
            struct MyViewTests {
                func test_MakeSaveCardModel_DarkUserInterfaceStyle() -> SnapshotSut {
                    return MyView()
                }
            }

            final class MyViewTestsHost: XCTestCase {
                func test_MakeSaveCardModel_DarkUserInterfaceStyle() async {
                    await Snapshots.match(testName: "CustomSnapshotName", prepareSut: { _ in
                        let suite = MyViewTests()
                        return suite.test_MakeSaveCardModel_DarkUserInterfaceStyle()
                    })
                }
            }
            """,
            macros: testMacros
        )
    }

    func test_generatesHost_mergesSuiteAndTestArguments() throws {
        assertMacroExpansion(
            """
            @SnapshotSuite(deviceGroup: .phone, includeAccessibility: true)
            struct MyViewTests {
                func test_iPhone() -> SnapshotSut {
                    return MyView()
                }

                @SnapshotTest(mode: .record)
                func test_record() -> SnapshotSut {
                    return MyView()
                }

                @SnapshotTest(matcher: .default, deviceGroup: .tablet)
                func test_tablet() -> SnapshotSut {
                    return MyView()
                }
            }
            """,
            expandedSource: """
            struct MyViewTests {
                func test_iPhone() -> SnapshotSut {
                    return MyView()
                }
                func test_record() -> SnapshotSut {
                    return MyView()
                }
                func test_tablet() -> SnapshotSut {
                    return MyView()
                }
            }

            final class MyViewTestsHost: XCTestCase {
                func test_iPhone() async {
                    await Snapshots.match(deviceGroup: .phone, includeAccessibility: true, prepareSut: { _ in
                        let suite = MyViewTests()
                        return suite.test_iPhone()
                    })
                }

                func test_record() async {
                    await Snapshots.match(mode: .record, deviceGroup: .phone, includeAccessibility: true, prepareSut: { _ in
                        let suite = MyViewTests()
                        return suite.test_record()
                    })
                }

                func test_tablet() async {
                    await Snapshots.match(matcher: .default, deviceGroup: .tablet, includeAccessibility: true, prepareSut: { _ in
                        let suite = MyViewTests()
                        return suite.test_tablet()
                    })
                }
            }
            """,
            macros: testMacros
        )
    }

    func test_generatesHost_withSnapshotDevice() throws {
        assertMacroExpansion(
            """
            @SnapshotSuite
            struct MyViewTests {
                var context = ViewContext.tests()

                func test_iPhone_Light(device: SnapshotDevice) -> SnapshotSut {
                    return MyView().makeUIView(context)
                }

                func test_WithOtherParamName(screen: SnapshotDevice) -> SnapshotSut {
                    return MyView()
                }

                func test_WithoutLabel(_ d: SnapshotDevice) -> SnapshotSut {
                    return MyView()
                }
            }
            """,
            expandedSource: """
            struct MyViewTests {
                var context = ViewContext.tests()

                func test_iPhone_Light(device: SnapshotDevice) -> SnapshotSut {
                    return MyView().makeUIView(context)
                }

                func test_WithOtherParamName(screen: SnapshotDevice) -> SnapshotSut {
                    return MyView()
                }

                func test_WithoutLabel(_ d: SnapshotDevice) -> SnapshotSut {
                    return MyView()
                }
            }

            final class MyViewTestsHost: XCTestCase {
                func test_iPhone_Light() async {
                    await Snapshots.match(prepareSut: { device in
                        let suite = MyViewTests()
                        return suite.test_iPhone_Light(device: device)
                    })
                }

                func test_WithOtherParamName() async {
                    await Snapshots.match(prepareSut: { device in
                        let suite = MyViewTests()
                        return suite.test_WithOtherParamName(screen: device)
                    })
                }

                func test_WithoutLabel() async {
                    await Snapshots.match(prepareSut: { device in
                        let suite = MyViewTests()
                        return suite.test_WithoutLabel(device)
                    })
                }
            }
            """,
            macros: testMacros
        )
    }

    func test_generatesHost_forMutatingSuite() throws {
        assertMacroExpansion(
            """
            @SnapshotSuite
            struct MyViewTests {
                var isDark = false

                mutating func test_iPhone_Light() -> SnapshotSut {
                    isDark = true
                    return MyView()
                }
            }
            """,
            expandedSource: """
            struct MyViewTests {
                var isDark = false

                mutating func test_iPhone_Light() -> SnapshotSut {
                    isDark = true
                    return MyView()
                }
            }

            final class MyViewTestsHost: XCTestCase {
                func test_iPhone_Light() async {
                    await Snapshots.match(prepareSut: { _ in
                        var suite = MyViewTests()
                        return suite.test_iPhone_Light()
                    })
                }
            }
            """,
            macros: testMacros
        )
    }

    func test_generatesHost_withDualTheme() throws {
        assertMacroExpansion(
            """
            @DualThemeSnapshotSuite(theme: SnapshotTheme.self)
            struct MyViewTests {
                var context = ViewContext.tests()

                @SnapshotTest(deviceGroup: .tablet)
                func test_iPad_Light() -> some View {
                    return MyView()
                }

                func test_iPhone_Light() -> some View {
                    return MyView()
                }
            }
            """,
            expandedSource: """
            struct MyViewTests {
                var context = ViewContext.tests()
                func test_iPad_Light() -> some View {
                    return MyView()
                }

                func test_iPhone_Light() -> some View {
                    return MyView()
                }
            }

            final class MyViewTestsHost: XCTestCase {
                func test_iPad_Light() async {
                    await Snapshots.matchDualThemes(deviceGroup: .tablet, prepareSut: { device in
                        let suite = MyViewTests()
                        let sut = suite.test_iPad_Light()
                        return DualThemeSnapshot.make(sut, device: device, theme: SnapshotTheme.self)
                    })
                }

                func test_iPhone_Light() async {
                    await Snapshots.matchDualThemes(prepareSut: { device in
                        let suite = MyViewTests()
                        let sut = suite.test_iPhone_Light()
                        return DualThemeSnapshot.make(sut, device: device, theme: SnapshotTheme.self)
                    })
                }
            }
            """,
            macros: testMacros
        )
    }

    func test_generatesHost_forSupportedReturnTypes() throws {
        assertMacroExpansion(
            """
            @SnapshotSuite
            struct MyViewTests {
                func test_UIView() -> UIView {
                    UIView()
                }

                func test_UIViewController() -> UIViewController {
                    UIViewController()
                }

                func test_SnapshotSutHolder() -> SnapshotSutHolder {
                    SnapshotSutHolder(UIView())
                }
            }
            """,
            expandedSource: """
            struct MyViewTests {
                func test_UIView() -> UIView {
                    UIView()
                }

                func test_UIViewController() -> UIViewController {
                    UIViewController()
                }

                func test_SnapshotSutHolder() -> SnapshotSutHolder {
                    SnapshotSutHolder(UIView())
                }
            }

            final class MyViewTestsHost: XCTestCase {
                func test_UIView() async {
                    await Snapshots.match(prepareSut: { _ in
                        let suite = MyViewTests()
                        return suite.test_UIView()
                    })
                }

                func test_UIViewController() async {
                    await Snapshots.match(prepareSut: { _ in
                        let suite = MyViewTests()
                        return suite.test_UIViewController()
                    })
                }

                func test_SnapshotSutHolder() async {
                    await Snapshots.match(prepareSut: { _ in
                        let suite = MyViewTests()
                        return suite.test_SnapshotSutHolder()
                    })
                }
            }
            """,
            macros: testMacros
        )
    }

    func test_generatesHost_forSomeViewReturnType() throws {
        assertMacroExpansion(
            """
            @SnapshotSuite
            struct PhoneEnteringViewSnapshotTests {
                func sut() -> some View {
                    PhoneEnteringView()
                }

                func test_PhoneEnteringView_Default() -> some View {
                    sut()
                }
            }
            """,
            expandedSource: """
            struct PhoneEnteringViewSnapshotTests {
                func sut() -> some View {
                    PhoneEnteringView()
                }

                func test_PhoneEnteringView_Default() -> some View {
                    sut()
                }
            }

            final class PhoneEnteringViewSnapshotTestsHost: XCTestCase {
                func test_PhoneEnteringView_Default() async {
                    await Snapshots.match(prepareSut: { _ in
                        let suite = PhoneEnteringViewSnapshotTests()
                        return suite.test_PhoneEnteringView_Default()
                    })
                }
            }
            """,
            macros: testMacros
        )
    }

    func test_generatesHost_forThrowsSnapshot() throws {
        assertMacroExpansion(
            """
            @SnapshotSuite
            struct MyViewTests {
                func test_Default() throws -> SnapshotSut {
                    try makeSut()
                }
            }
            """,
            expandedSource: """
            struct MyViewTests {
                func test_Default() throws -> SnapshotSut {
                    try makeSut()
                }
            }

            final class MyViewTestsHost: XCTestCase {
                func test_Default() async {
                    await Snapshots.match(prepareSut: { _ in
                        let suite = MyViewTests()
                        return try suite.test_Default()
                    })
                }
            }
            """,
            macros: testMacros
        )
    }

    func test_generatesUnitHost_forSyncAndThrows() throws {
        assertMacroExpansion(
            """
            @SnapshotSuite
            struct TextModelSnapshotTests {
                func test_TextModel_Default() -> SnapshotSut {
                    TextModel()
                }

                @UnitTest
                func test_TextModel_Parsing() {
                    XCTAssertEqual(TextModel().maxLines, 2)
                }

                @UnitTest
                func test_TextModel_Decoding() throws {
                    throw TestError.failed
                }
            }
            """,
            expandedSource: """
            struct TextModelSnapshotTests {
                func test_TextModel_Default() -> SnapshotSut {
                    TextModel()
                }
                func test_TextModel_Parsing() {
                    XCTAssertEqual(TextModel().maxLines, 2)
                }
                func test_TextModel_Decoding() throws {
                    throw TestError.failed
                }
            }

            final class TextModelSnapshotTestsHost: XCTestCase {
                func test_TextModel_Default() async {
                    await Snapshots.match(prepareSut: { _ in
                        let suite = TextModelSnapshotTests()
                        return suite.test_TextModel_Default()
                    })
                }

                func test_TextModel_Parsing() {
                    let suite = TextModelSnapshotTests()
                    suite.test_TextModel_Parsing()
                }

                func test_TextModel_Decoding() throws {
                    let suite = TextModelSnapshotTests()
                    try suite.test_TextModel_Decoding()
                }
            }
            """,
            macros: testMacros
        )
    }

    func test_generatesUnitHost_forAsync() throws {
        assertMacroExpansion(
            """
            @SnapshotSuite
            struct TextModelSnapshotTests {
                @UnitTest
                func test_TextModel_Parsing() async {
                    XCTAssertEqual(TextModel().maxLines, 2)
                }

                @UnitTest
                func test_TextModel_Decoding() async throws {
                    throw TestError.failed
                }
            }
            """,
            expandedSource: """
            struct TextModelSnapshotTests {
                func test_TextModel_Parsing() async {
                    XCTAssertEqual(TextModel().maxLines, 2)
                }
                func test_TextModel_Decoding() async throws {
                    throw TestError.failed
                }
            }

            final class TextModelSnapshotTestsHost: XCTestCase {
                func test_TextModel_Parsing() async {
                    let suite = TextModelSnapshotTests()
                    await suite.test_TextModel_Parsing()
                }

                func test_TextModel_Decoding() async throws {
                    let suite = TextModelSnapshotTests()
                    try await suite.test_TextModel_Decoding()
                }
            }
            """,
            macros: testMacros
        )
    }

    func test_diagnoses_emptySuite() throws {
        assertMacroExpansion(
            """
            @SnapshotSuite
            struct MyViewTests {
                func helper() {
                }
            }
            """,
            expandedSource: """
            struct MyViewTests {
                func helper() {
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    // swiftlint:disable:next line_length
                    message: "В @SnapshotSuite должна быть хотя бы одна test* функция (snapshot или с @UnitTest)",
                    line: 1,
                    column: 1
                ),
            ],
            macros: testMacros
        )
    }

    // MARK: - Diagnostics

    func test_diagnoses_notAStruct() throws {
        assertMacroExpansion(
            """
            @SnapshotSuite
            class MyViewTests {
                func test_iPhone_Light() -> SnapshotSut {
                    return MyView().makeUIView(context)
                }
            }
            """,
            expandedSource: """
            class MyViewTests {
                func test_iPhone_Light() -> SnapshotSut {
                    return MyView().makeUIView(context)
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@SnapshotSuite может применяться только к структурам",
                    line: 1,
                    column: 1
                ),
            ],
            macros: testMacros
        )
    }

    func test_diagnoses_snapshotOnNonTest() throws {
        assertMacroExpansion(
            """
            @SnapshotSuite
            struct MyViewTests {
                @SnapshotTest
                func someHelper() {
                }
            }
            """,
            expandedSource: """
            struct MyViewTests {
                func someHelper() {
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    // swiftlint:disable:next line_length
                    message: "@SnapshotTest можно применять только к тестовым функциям (начинающимся с 'test')",
                    line: 3,
                    column: 5
                ),
            ],
            macros: testMacros
        )
    }

    func test_diagnoses_unitTestOnNonTest() throws {
        assertMacroExpansion(
            """
            @SnapshotSuite
            struct MyViewTests {
                @UnitTest
                func someHelper() {
                }
            }
            """,
            expandedSource: """
            struct MyViewTests {
                func someHelper() {
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    // swiftlint:disable:next line_length
                    message: "@UnitTest можно применять только к тестовым функциям (начинающимся с 'test')",
                    line: 3,
                    column: 5
                ),
            ],
            macros: testMacros
        )
    }

    func test_diagnoses_snapshotTestOnUnitTest() throws {
        assertMacroExpansion(
            """
            @SnapshotSuite
            struct MyViewTests {
                @SnapshotTest(deviceGroup: .tablet)
                func test_ModelParsing() {
                }
            }
            """,
            expandedSource: """
            struct MyViewTests {
                func test_ModelParsing() {
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    // swiftlint:disable:next line_length
                    message: "@SnapshotTest можно применять только к snapshot-тестам (возвращающим SnapshotSut, UIView, UIViewController, SnapshotSutHolder или some View)",
                    line: 3,
                    column: 5
                ),
            ],
            macros: testMacros
        )
    }

    func test_diagnoses_snapshotTestWithUnitTest() throws {
        assertMacroExpansion(
            """
            @SnapshotSuite
            struct MyViewTests {
                @SnapshotTest(deviceGroup: .tablet)
                @UnitTest
                func test_ModelParsing() {
                }
            }
            """,
            expandedSource: """
            struct MyViewTests {
                func test_ModelParsing() {
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@SnapshotTest и @UnitTest нельзя применять к одной функции",
                    line: 3,
                    column: 5
                ),
            ],
            macros: testMacros
        )
    }

    func test_diagnoses_unitTestOnSnapshotTest() throws {
        assertMacroExpansion(
            """
            @SnapshotSuite
            struct MyViewTests {
                @UnitTest
                func test_Default() -> SnapshotSut {
                    MyView()
                }
            }
            """,
            expandedSource: """
            struct MyViewTests {
                func test_Default() -> SnapshotSut {
                    MyView()
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@UnitTest можно применять только к unit-тестам (без snapshot return type)",
                    line: 3,
                    column: 5
                ),
            ],
            macros: testMacros
        )
    }

    func test_diagnoses_unsupportedSnapshotReturnType() throws {
        assertMacroExpansion(
            """
            @SnapshotSuite
            struct MyViewTests {
                func test_BadReturnType() -> String {
                    "oops"
                }
            }
            """,
            expandedSource: """
            struct MyViewTests {
                func test_BadReturnType() -> String {
                    "oops"
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    // swiftlint:disable:next line_length
                    message: "Snapshot test-функция должна возвращать SnapshotSut, UIView, UIViewController, SnapshotSutHolder или some View",
                    line: 3,
                    column: 34
                ),
            ],
            macros: testMacros
        )
    }

    func test_diagnoses_missingSnapshotReturnType() throws {
        assertMacroExpansion(
            """
            @SnapshotSuite
            struct MyViewTests {
                func test_ForgotReturnType() {
                    MyView()
                }
            }
            """,
            expandedSource: """
            struct MyViewTests {
                func test_ForgotReturnType() {
                    MyView()
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    // swiftlint:disable:next line_length
                    message: "У test-функции должен быть snapshot return type (SnapshotSut, UIView, UIViewController, SnapshotSutHolder или some View) или атрибут @UnitTest",
                    line: 3,
                    column: 31
                ),
            ],
            macros: testMacros
        )
    }

    func test_diagnoses_deviceOnUnitTest() throws {
        assertMacroExpansion(
            """
            @SnapshotSuite
            struct MyViewTests {
                @UnitTest
                func test_ModelParsing(device: SnapshotDevice) {
                }
            }
            """,
            expandedSource: """
            struct MyViewTests {
                func test_ModelParsing(device: SnapshotDevice) {
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "Параметр SnapshotDevice допустим только в snapshot-тестах",
                    line: 4,
                    column: 36
                ),
            ],
            macros: testMacros
        )
    }

    func test_diagnoses_invalidFirstParameterOnSnapshotTest() throws {
        assertMacroExpansion(
            """
            @SnapshotSuite
            struct MyViewTests {
                func test_Default(context: ViewContext) -> SnapshotSut {
                    MyView()
                }
            }
            """,
            expandedSource: """
            struct MyViewTests {
                func test_Default(context: ViewContext) -> SnapshotSut {
                    MyView()
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "Первый параметр snapshot-теста должен иметь тип SnapshotDevice",
                    line: 3,
                    column: 32
                ),
            ],
            macros: testMacros
        )
    }
}
