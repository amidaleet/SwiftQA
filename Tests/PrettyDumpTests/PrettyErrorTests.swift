import PrettyDump
import Testing

@Suite
struct PrettyErrorTests {
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

    @Test
    func testGeneratedErrorDomain() {
        let error = PlainError()

        #expect(error.errorDomain == "plain-error")
    }

    @Test
    func testGeneratedPlainErrorName() {
        let error = PlainError()

        #expect(error.errorName == "plain-error")
    }

    @Test
    func testGeneratedPlainErrorCode() {
        let error = PlainError()

        #expect(error.errorCode == .noPrettyErrorCode)
    }

    @Test
    func testGeneratedUpperSeriesErrorDomain() {
        let error = ABCError()

        #expect(error.errorDomain == "abc-error")
    }

    @Test
    func testGeneratedEnumErrorName() {
        let error = EnumError.string()

        #expect(error.errorName == "string")
    }

    @Test
    func testGeneratedEnumErrorCode() {
        let error = EnumError.string()

        #expect(error.errorCode == EnumError.ID.allCases.firstIndex(of: .string))
    }

    @Test
    func testGeneratedNestedErrorDomain() {
        let error = Container.NestedError()

        #expect(error.errorDomain == "nested-error")
    }
}
