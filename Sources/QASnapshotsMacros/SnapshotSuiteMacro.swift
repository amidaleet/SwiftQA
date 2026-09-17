import Foundation
import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct SnapshotSuiteMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw Error.notAStruct
        }

        let structName = structDecl.name.text
        let testClassName = "\(structName)Host"

        var hostMethods: [DeclSyntax] = []

        let macroName = node.attributeName.as(IdentifierTypeSyntax.self)?.name.text ?? "SnapshotSuite"
        let isDualThemeSuite = macroName == "DualThemeSnapshotSuite"
        let defaultMethod = isDualThemeSuite ? "matchDualThemes" : "match"
        let suiteArguments = snapshotArguments(from: node.arguments?.as(LabeledExprListSyntax.self))

        for member in structDecl.memberBlock.members {
            guard let funcDecl = member.decl.as(FunctionDeclSyntax.self) else {
                continue
            }

            switch processTestFunction(
                funcDecl: funcDecl,
                structName: structName,
                defaultMethod: defaultMethod,
                isDualThemeSuite: isDualThemeSuite,
                suiteArguments: suiteArguments,
                in: context
            ) {
            case let .snapshot(hostMethod),
                 let .unit(hostMethod):
                hostMethods.append(hostMethod)
            case .skip:
                continue
            }
        }

        guard !hostMethods.isEmpty else {
            if shouldDiagnoseAsEmptySuite(structDecl) {
                context.diagnose(Diagnostic(node: Syntax(node), message: Error.emptySuite))
            }
            return []
        }

        let membersString = hostMethods.map { $0.description }.joined(separator: "\n\n")

        let classDecl: DeclSyntax = """
        final class \(raw: testClassName): XCTestCase {
            \(raw: membersString.replacingOccurrences(of: "\n", with: "\n    "))
        }
        """

        return [classDecl]
    }

    private static func shouldDiagnoseAsEmptySuite(_ structDecl: StructDeclSyntax) -> Bool {
        !containsTestPrefixedMember(in: structDecl)
            && !containsTestMacroAttribute(in: structDecl)
    }

    private static func containsTestPrefixedMember(in structDecl: StructDeclSyntax) -> Bool {
        structDecl.memberBlock.members.contains { member in
            guard let funcDecl = member.decl.as(FunctionDeclSyntax.self) else { return false }
            return funcDecl.name.text.hasPrefix("test")
        }
    }

    private static func containsTestMacroAttribute(in structDecl: StructDeclSyntax) -> Bool {
        structDecl.memberBlock.members.contains { member in
            guard let funcDecl = member.decl.as(FunctionDeclSyntax.self) else { return false }
            return funcDecl.attributes.contains { attr in
                guard let customAttr = attr.as(AttributeSyntax.self),
                      let name = customAttr.attributeName.as(IdentifierTypeSyntax.self)?.name.text
                else { return false }
                return name == "SnapshotTest" || name == "UnitTest"
            }
        }
    }
}

public struct SnapshotTestMacro: PeerMacro {
    public static func expansion(
        of _: AttributeSyntax,
        providingPeersOf _: some DeclSyntaxProtocol,
        in _: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        []
    }
}

public struct UnitTestMacro: PeerMacro {
    public static func expansion(
        of _: AttributeSyntax,
        providingPeersOf _: some DeclSyntaxProtocol,
        in _: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        []
    }
}

// MARK: - SnapshotSuiteMacro+ProcessTestFunction

extension SnapshotSuiteMacro {
    private enum ProcessResult {
        case snapshot(DeclSyntax)
        case unit(DeclSyntax)
        case skip
    }

    private static func processTestFunction(
        funcDecl: FunctionDeclSyntax,
        structName: String,
        defaultMethod: String,
        isDualThemeSuite: Bool,
        suiteArguments: [String: String],
        in context: some MacroExpansionContext
    ) -> ProcessResult {
        let funcName = funcDecl.name.text
        let isTestFunc = funcName.hasPrefix("test")

        var testArguments: [String: String] = [:]
        var snapshotAttr: AttributeSyntax?
        var unitTestAttr: AttributeSyntax?

        for attr in funcDecl.attributes {
            guard let customAttr = attr.as(AttributeSyntax.self),
                  let attrName = customAttr.attributeName.as(IdentifierTypeSyntax.self)?.name.text
            else {
                continue
            }

            switch attrName {
            case "SnapshotTest":
                snapshotAttr = customAttr
                testArguments = snapshotArguments(from: customAttr.arguments?.as(LabeledExprListSyntax.self))
            case "UnitTest":
                unitTestAttr = customAttr
            default:
                continue
            }
        }

        if let snapshotAttr, unitTestAttr != nil {
            context.diagnose(Diagnostic(node: Syntax(snapshotAttr), message: Error.snapshotTestWithUnitTest))
            return .skip
        }

        if let snapshotAttr, !isTestFunc {
            context.diagnose(Diagnostic(node: Syntax(snapshotAttr), message: Error.snapshotOnNonTestFunc))
            return .skip
        }

        if let unitTestAttr, !isTestFunc {
            context.diagnose(Diagnostic(node: Syntax(unitTestAttr), message: Error.unitTestOnNonTest))
            return .skip
        }

        guard isTestFunc else {
            return .skip
        }

        let returnType = funcDecl.signature.returnClause?.type
        let isSnapshotTest = isSnapshotReturnType(returnType)

        if let snapshotAttr, !isSnapshotTest {
            context.diagnose(Diagnostic(node: Syntax(snapshotAttr), message: Error.snapshotTestOnUnitTest))
            return .skip
        }

        if let unitTestAttr, isSnapshotTest {
            context.diagnose(Diagnostic(node: Syntax(unitTestAttr), message: Error.unitTestOnSnapshotTest))
            return .skip
        }

        if !isSnapshotTest, unitTestAttr == nil, !isVoidReturnType(returnType), let returnType {
            context.diagnose(Diagnostic(
                node: Syntax(returnType),
                message: Error.unsupportedSnapshotReturnType
            ))
            return .skip
        }

        if !isSnapshotTest, unitTestAttr == nil, isVoidReturnType(returnType) {
            context.diagnose(Diagnostic(
                node: Syntax(funcDecl.signature),
                message: Error.missingSnapshotReturnType
            ))
            return .skip
        }

        let params = funcDecl.signature.parameterClause.parameters
        let isMutating = funcDecl.modifiers.contains(where: { $0.name.text == "mutating" })
        let suiteDeclKeyword = isMutating ? "var" : "let"

        if isSnapshotTest {
            if let firstParam = params.first, !isSnapshotDeviceType(firstParam.type) {
                context.diagnose(Diagnostic(
                    node: Syntax(firstParam.type),
                    message: Error.invalidSnapshotTestParameter
                ))
                return .skip
            }

            return .snapshot(
                snapshotHostMethod(
                    funcDecl: funcDecl,
                    funcName: funcName,
                    structName: structName,
                    suiteDeclKeyword: suiteDeclKeyword,
                    defaultMethod: defaultMethod,
                    isDualThemeSuite: isDualThemeSuite,
                    suiteArguments: suiteArguments,
                    testArguments: testArguments,
                    params: params
                )
            )
        }

        if hasSnapshotDeviceParameter(params), let firstParam = params.first {
            context.diagnose(Diagnostic(
                node: Syntax(firstParam.type),
                message: Error.snapshotDeviceOnUnitTest
            ))
            return .skip
        }

        return .unit(
            unitHostMethod(
                funcDecl: funcDecl,
                funcName: funcName,
                structName: structName,
                suiteDeclKeyword: suiteDeclKeyword
            )
        )
    }
}

// MARK: - SnapshotSuiteMacro+HostGeneration

extension SnapshotSuiteMacro {
    private static func snapshotHostMethod(
        funcDecl: FunctionDeclSyntax,
        funcName: String,
        structName: String,
        suiteDeclKeyword: String,
        defaultMethod: String,
        isDualThemeSuite: Bool,
        suiteArguments: [String: String],
        testArguments: [String: String],
        params: FunctionParameterListSyntax
    ) -> DeclSyntax {
        let passedArguments = serializedArguments(
            mergedArguments(suite: suiteArguments, test: testArguments)
        )
        let comma = passedArguments.isEmpty ? "" : ", "

        let isThrows = funcDecl.signature.effectSpecifiers?.throwsClause?.throwsSpecifier != nil
        let callPrefix = callPrefix(isAsync: false, isThrows: isThrows)

        let closureParam: String
        let callArgs: String

        if let firstParam = params.first {
            closureParam = "device"
            let label = firstParam.firstName.text
            if label == "_" {
                callArgs = "device"
            } else {
                callArgs = "\(label): device"
            }
        } else {
            closureParam = "_"
            callArgs = ""
        }

        let theme = suiteArguments["theme"]
        // Тему подставляем только вью: UIView и UIViewController кадр собирают сами.
        let isViewSut = funcDecl.signature.returnClause.map { isSomeViewType($0.type) } ?? false

        guard isDualThemeSuite, isViewSut, let theme else {
            return """
            func \(raw: funcName)() async {
                await Snapshots.\(raw: defaultMethod)(\(raw: passedArguments)\(raw: comma)prepareSut: { \(raw: closureParam) in
                    \(raw: suiteDeclKeyword) suite = \(raw: structName)()
                    return \(raw: callPrefix)suite.\(raw: funcName)(\(raw: callArgs))
                })
            }
            """
        }

        return """
        func \(raw: funcName)() async {
            await Snapshots.\(raw: defaultMethod)(\(raw: passedArguments)\(raw: comma)prepareSut: { device in
                \(raw: suiteDeclKeyword) suite = \(raw: structName)()
                let sut = \(raw: callPrefix)suite.\(raw: funcName)(\(raw: callArgs))
                return DualThemeSnapshot.make(sut, device: device, theme: \(raw: theme))
            })
        }
        """
    }

    private static func unitHostMethod(
        funcDecl: FunctionDeclSyntax,
        funcName: String,
        structName: String,
        suiteDeclKeyword: String
    ) -> DeclSyntax {
        let isThrows = funcDecl.signature.effectSpecifiers?.throwsClause?.throwsSpecifier != nil
        let isAsync = funcDecl.signature.effectSpecifiers?.asyncSpecifier != nil

        let asyncKeyword = isAsync ? " async" : ""
        let throwsKeyword = isThrows ? " throws" : ""
        let callPrefix = callPrefix(isAsync: isAsync, isThrows: isThrows)

        return """
        func \(raw: funcName)()\(raw: asyncKeyword)\(raw: throwsKeyword) {
            \(raw: suiteDeclKeyword) suite = \(raw: structName)()
            \(raw: callPrefix)suite.\(raw: funcName)()
        }
        """
    }

    private static func callPrefix(isAsync: Bool, isThrows: Bool) -> String {
        switch (isAsync, isThrows) {
        case (true, true): "try await "
        case (true, false): "await "
        case (false, true): "try "
        case (false, false): ""
        }
    }
}

// MARK: - SnapshotSuiteMacro+ReturnType

extension SnapshotSuiteMacro {
    /// Именованные return types snapshot test-функций.
    ///
    /// Дополнительно поддерживается `some View` / `some SwiftUI.View` — см. `isSomeViewType`.
    /// Не распознаются qualified types (`UIKit.UIView`), подклассы и typealiases —
    /// в сигнатуре лучше использовать канонические имена из `snapshotReturnTypeNames`.
    private static let snapshotReturnTypeNames: Set<String> = [
        "SnapshotSut",
        "UIView",
        "UIViewController",
        "SnapshotSutHolder",
    ]

    private static let supportedSnapshotReturnTypesMessage =
        "SnapshotSut, UIView, UIViewController, SnapshotSutHolder или some View"

    private static func isSnapshotReturnType(_ type: TypeSyntax?) -> Bool {
        guard let type else { return false }

        if let identifier = type.as(IdentifierTypeSyntax.self) {
            return snapshotReturnTypeNames.contains(identifier.name.text)
        }

        if isSomeViewType(type) {
            return true
        }

        return false
    }

    private static func isVoidReturnType(_ type: TypeSyntax?) -> Bool {
        guard let type else { return true }

        if let identifier = type.as(IdentifierTypeSyntax.self), identifier.name.text == "Void" {
            return true
        }

        if let tuple = type.as(TupleTypeSyntax.self), tuple.elements.isEmpty {
            return true
        }

        return false
    }

    private static func isSomeViewType(_ type: TypeSyntax) -> Bool {
        guard let someOrAny = type.as(SomeOrAnyTypeSyntax.self),
              someOrAny.someOrAnySpecifier.tokenKind == .keyword(.some)
        else {
            return false
        }

        return isViewType(someOrAny.constraint)
    }

    private static func isViewType(_ type: TypeSyntax) -> Bool {
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            return identifier.name.text == "View"
        }

        if let member = type.as(MemberTypeSyntax.self) {
            return member.name.text == "View"
        }

        return false
    }

    private static func hasSnapshotDeviceParameter(_ params: FunctionParameterListSyntax) -> Bool {
        guard let firstParam = params.first else { return false }
        return isSnapshotDeviceType(firstParam.type)
    }

    private static func isSnapshotDeviceType(_ type: TypeSyntax) -> Bool {
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            return identifier.name.text == "SnapshotDevice"
        }
        return false
    }
}

// MARK: - SnapshotSuiteMacro+Arguments

extension SnapshotSuiteMacro {
    private static let snapshotArgumentOrder = [
        "testName",
        "matcher",
        "mode",
        "deviceGroup",
        "includeAccessibility",
    ]

    private static func snapshotArguments(from arguments: LabeledExprListSyntax?) -> [String: String] {
        guard let arguments else { return [:] }

        var result: [String: String] = [:]
        for argument in arguments {
            guard let label = argument.label?.text else { continue }
            result[label] = argument.expression.description.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return result
    }

    private static func mergedArguments(suite: [String: String], test: [String: String]) -> [String: String] {
        suite.merging(test) { _, testValue in testValue }
    }

    private static func serializedArguments(_ arguments: [String: String]) -> String {
        snapshotArgumentOrder.compactMap { key in
            guard let value = arguments[key] else { return nil }
            return "\(key): \(value)"
        }
        .joined(separator: ", ")
    }
}

// MARK: - SnapshotSuiteMacro+Error

// swiftlint:disable line_length
extension SnapshotSuiteMacro {
    enum Error: String, Swift.Error, DiagnosticMessage {
        case notAStruct
        case snapshotOnNonTestFunc
        case unitTestOnNonTest
        case snapshotTestOnUnitTest
        case unitTestOnSnapshotTest
        case snapshotTestWithUnitTest
        case snapshotDeviceOnUnitTest
        case invalidSnapshotTestParameter
        case unsupportedSnapshotReturnType
        case missingSnapshotReturnType
        case emptySuite

        var message: String {
            switch self {
            case .notAStruct:
                return "@SnapshotSuite может применяться только к структурам"
            case .snapshotOnNonTestFunc:
                return "@SnapshotTest можно применять только к тестовым функциям (начинающимся с 'test')"
            case .unitTestOnNonTest:
                return "@UnitTest можно применять только к тестовым функциям (начинающимся с 'test')"
            case .snapshotTestOnUnitTest:
                return "@SnapshotTest можно применять только к snapshot-тестам (возвращающим \(SnapshotSuiteMacro.supportedSnapshotReturnTypesMessage))"
            case .unitTestOnSnapshotTest:
                return "@UnitTest можно применять только к unit-тестам (без snapshot return type)"
            case .snapshotTestWithUnitTest:
                return "@SnapshotTest и @UnitTest нельзя применять к одной функции"
            case .snapshotDeviceOnUnitTest:
                return "Параметр SnapshotDevice допустим только в snapshot-тестах"
            case .invalidSnapshotTestParameter:
                return "Первый параметр snapshot-теста должен иметь тип SnapshotDevice"
            case .unsupportedSnapshotReturnType:
                return "Snapshot test-функция должна возвращать \(SnapshotSuiteMacro.supportedSnapshotReturnTypesMessage)"
            case .missingSnapshotReturnType:
                return "У test-функции должен быть snapshot return type (\(SnapshotSuiteMacro.supportedSnapshotReturnTypesMessage)) или атрибут @UnitTest"
            case .emptySuite:
                return "В @SnapshotSuite должна быть хотя бы одна test* функция (snapshot или с @UnitTest)"
            }
        }

        var diagnosticID: MessageID {
            .init(domain: SnapshotSuiteMacro.diagnosticIDDomain, id: rawValue)
        }

        var severity: DiagnosticSeverity {
            .error
        }
    }
}

// swiftlint:enable line_length

// MARK: - SnapshotSuiteMacro+diagnosticIDDomain

extension SnapshotSuiteMacro {
    static let diagnosticIDDomain = "SnapshotSuiteMacro"
}
