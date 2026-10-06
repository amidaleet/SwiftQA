import QAMust
import XCTest

final class MustValueTests: XCTestCase {
    func test_beTrue_PassesForTrue() {
        Must.beTrue(true)
        Must.beTrue(true as Bool?)
    }

    func test_beTrue_FailsForFalseOrNil() {
        expectMustFailure { Must.beTrue(false) }
        expectMustFailure { Must.beTrue(nil as Bool?) }
    }

    func test_beFalse_PassesForFalse() {
        Must.beFalse(false)
    }

    func test_beFalse_FailsForTrue() {
        expectMustFailure { Must.beFalse(true) }
    }

    func test_beNil_AndBeNotNil() {
        Must.beNil(nil as Int?)
        Must.beNotNil(1 as Int?)
        expectMustFailure { Must.beNil(1 as Int?) }
        expectMustFailure { Must.beNotNil(nil as Int?) }
    }

    func test_beEmpty_AndNonEmpty() {
        Must.beEmpty([Int]())
        Must.beNonEmpty([1])
        expectMustFailure { Must.beEmpty([1]) }
        expectMustFailure { Must.beNonEmpty([Int]()) }
    }

    func test_beSingle_ReturnsTheOnlyElement() {
        XCTAssertEqual(Must.beSingle([7]), 7)
        expectMustFailure { _ = Must.beSingle([Int]()) }
        expectMustFailure { _ = Must.beSingle([1, 2]) }
    }

    func test_equal_UsesEquatable() {
        Must.equal(1, 1)
        expectMustFailure { Must.equal(1, 2) }
    }

    func test_equal_Async() async {
        await Must.equalAsync(1, 1)
    }

    func test_equal_FloatingPointAccuracy() {
        Must.equal(1.0, 1.05, accuracy: 0.1)
        expectMustFailure { Must.equal(1.0, 2.0, accuracy: 0.1) }
        expectMustFailure { Must.equal(nil as Double?, 1, accuracy: 0.1) }
    }

    func test_equal_Predicate() {
        Must.equal(["A"], ["a"]) { $0.caseInsensitiveCompare($1) == .orderedSame }
        expectMustFailure {
            Must.equal([1], [2]) { $0 == $1 }
        }
        expectMustFailure {
            Must.equal([1], [1, 2]) { $0 == $1 }
        }
    }

    func test_notEqual() {
        Must.notEqual(1, 2)
        expectMustFailure { Must.notEqual(1, 1) }
    }

    func test_mirrorEqual_WalksMirrorEvenWhenEquatableMatches() {
        Must.mirrorEqual(Payload(name: "a"), Payload(name: "a"))
        Must.equal(Counted(value: 1), Counted(value: 2))
        expectMustFailure {
            Must.mirrorEqual(Counted(value: 1), Counted(value: 2))
        }
        expectMustFailure {
            Must.mirrorEqual(Payload(name: "a"), Payload(name: "b"))
        }
    }

    func test_equalByReference() {
        let object = NSObject()
        Must.equalByReference(object, object)
        expectMustFailure { Must.equalByReference(NSObject(), NSObject()) }
        Must.equalByReference(nil, nil)
    }

    func test_equalDate_RespectsGranularity() {
        let start = Date(timeIntervalSince1970: 0)
        Must.equalDate(granularity: .second, start, start.addingTimeInterval(0.4))
        expectMustFailure {
            Must.equalDate(
                granularity: .year,
                start,
                start.addingTimeInterval(86_400 * 400)
            )
        }
    }

    func test_contain_AndNotContain() {
        Must.contain(Flags.a.union(.b), value: .a)
        Must.contain([1, 2], value: 2)
        Must.notContain(Flags.a, value: .b)
        expectMustFailure { Must.contain(Flags.a, value: .b) }
        expectMustFailure { Must.contain([1], value: 2) }
        expectMustFailure { Must.notContain(Flags.a, value: .a) }
    }

    func test_containAll_UsesEquatable() {
        Must.containAll([1, 2, 2], other: [2, 1])
        expectMustFailure { Must.containAll([1], other: [1, 2]) }
    }

    func test_containAllMirrorEqual_WalksElements() {
        Must.containAllMirrorEqual(
            [Payload(name: "a"), Payload(name: "b")],
            other: [Payload(name: "b"), Payload(name: "a")]
        )
        expectMustFailure {
            Must.containAllMirrorEqual([Payload(name: "a")], other: [Payload(name: "b")])
        }
    }

    @MainActor
    func test_step_RunsBody() {
        var ran = false
        Must.step("run") { ran = true }
        XCTAssertTrue(ran)
    }

    @MainActor
    func test_step_FailsWhenBodyThrows() {
        expectMustFailure {
            Must.step("run") { throw SampleError.invalid }
        }
    }
}

private struct Payload {
    var name: String
}

private struct Counted: Equatable {
    var value: Int

    static func == (lhs: Counted, rhs: Counted) -> Bool {
        lhs.value / 10 == rhs.value / 10
    }
}

private struct Flags: OptionSet {
    let rawValue: Int

    static let a = Flags(rawValue: 1)
    static let b = Flags(rawValue: 2)
}

private enum SampleError: Error {
    case invalid
}
