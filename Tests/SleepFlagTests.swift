import XCTest
@testable import StayUp

/// The three shapes `pmset -g` prints, from `docs/notes.md`, "Reading the
/// machine". The tabs are real tabs on purpose: the parser must not depend on
/// how many of them there are.
final class SleepFlagTests: XCTestCase {
    private let raised = """
    System-wide power settings:
     SleepDisabled\t\t1
    Currently in use:
     standby              1
    """

    private let lowered = """
    System-wide power settings:
     SleepDisabled\t\t0
    Currently in use:
     standby              1
    """

    private let neverSet = """
    System-wide power settings:
    Currently in use:
     standby              1
     hibernatemode        3
    """

    func testRaisedReadsTrue() {
        XCTAssertTrue(SleepFlag.parse(raised))
    }

    func testLoweredReadsFalse() {
        XCTAssertFalse(SleepFlag.parse(lowered))
    }

    /// A Mac on which the flag has never been set prints no line at all, and
    /// that is the same answer as 0.
    func testAbsentReadsFalse() {
        XCTAssertFalse(SleepFlag.parse(neverSet))
    }
}
