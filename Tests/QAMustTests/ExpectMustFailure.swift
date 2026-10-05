import XCTest

func expectMustFailure(_ body: () -> Void) {
    XCTExpectFailure {
        body()
    }
}
