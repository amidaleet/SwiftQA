import PrettyDump
import QAMust
import XCTest

final class PrettyErrorTests: XCTestCase {
    func test_PlainError_errorDomain() {
        let error = PlainError()

        Must.equal(error.errorDomain, "plain-error")
    }

    func test_PlainError_errorName() {
        let error = PlainError()

        Must.equal(error.errorName, "plain-error")
    }

    func test_PlainError_errorCode() {
        let error = PlainError()

        Must.equal(error.errorCode, .noPrettyErrorCode)
    }

    func test_ABCError_errorDomain() {
        let error = ABCError()

        Must.equal(error.errorDomain, "abc-error")
    }

    func test_EnumError_errorName() {
        let error = EnumError.string()

        Must.equal(error.errorName, "string")
    }

    func test_EnumError_errorCode() {
        let error = EnumError.string()

        Must.equal(error.errorCode, EnumError.ID.allCases.firstIndex(of: .string))
    }

    func test_NestedError_errorDomain() {
        let error = Container.NestedError()

        Must.equal(error.errorDomain, "nested-error")
    }
}

private struct PlainError: PrettyError {}
private struct ABCError: PrettyError {}

private enum EnumError: PrettyError, Identifiable {
    enum ID: String, CaseIterable {
        case simple
        case string
    }

    var id: ID {
        switch self {
        case .simple: .simple
        case .string: .string
        }
    }

    case simple
    case string(String = "some")
}

private enum Container {
    struct NestedError: PrettyError {}
}
