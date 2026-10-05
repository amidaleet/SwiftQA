import QAMust
import XCTest

final class MustErrorTests: XCTestCase {
    func test_fail_FailsTheTest() {
        expectMustFailure { Must.fail("boom") }
    }

    func test_skip_ThrowsXCTSkip() {
        XCTAssertThrowsError(try Must.skip("later")) { error in
            XCTAssertTrue(error is XCTSkip)
        }
    }

    func test_throwAnyError() {
        Must.throwAnyError { throw SampleError.invalid }
        expectMustFailure { Must.throwAnyError { 1 } }
    }

    func test_throwError_MatchingError() {
        Must.throwError({ throw SampleError.invalid }, SampleError.invalid)
    }

    func test_throwError_FailsWhenErrorDiffersOrIsMissing() {
        expectMustFailure {
            Must.throwError({ throw SampleError.invalid }, SampleError.other)
        }
        expectMustFailure {
            Must.throwError({ 1 }, SampleError.invalid)
        }
        expectMustFailure {
            Must.throwError({ throw OtherError.boom }, SampleError.invalid)
        }
    }

    func test_throwError_Async_MatchingError() async {
        await Must.throwError({ () async throws -> Int in
            throw SampleError.invalid
        }, SampleError.invalid)
    }

    func test_noThrow() {
        Must.noThrow { 1 }
        expectMustFailure { Must.noThrow { throw SampleError.invalid } }
    }

    func test_beFailure_EquatableError() {
        Must.beFailure(Result<Int, SampleError>.failure(.invalid), SampleError.invalid)
        expectMustFailure {
            Must.beFailure(Result<Int, SampleError>.success(1), SampleError.invalid)
        }
        expectMustFailure {
            Must.beFailure(nil as Result<Int, SampleError>?, SampleError.invalid)
        }
    }

    func test_beSuccess() {
        Must.beSuccess(Result<Int, SampleError>.success(1), 1)
        Must.beSuccess(Result<Void, SampleError>.success(()))
        expectMustFailure {
            Must.beSuccess(Result<Int, SampleError>.failure(.invalid), 1)
        }
        expectMustFailure {
            Must.beSuccess(nil as Result<Void, SampleError>?)
        }
    }

    func test_unwrap() throws {
        let value = try Must.unwrap(1 as Int?)
        XCTAssertEqual(value, 1)
        expectMustFailure {
            do {
                _ = try Must.unwrap(nil as Int?)
            } catch {}
        }
    }

    func test_encode_AndDecode() {
        let model = Item(id: 1)
        Must.encode(model, to: ["id": 1])
        Must.decode(["id": 1], to: model)
        Must.decode(#"{"id":1}"#, to: model)
    }

    func test_failDecode() {
        Must.failDecode(["name": "x"], to: Item(id: 1))
        expectMustFailure {
            Must.failDecode(["id": 1], to: Item(id: 1))
        }
    }
}

private struct Item: Codable, Equatable {
    var id: Int
}

private enum SampleError: Error, Equatable {
    case invalid
    case other
}

private enum OtherError: Error {
    case boom
}
