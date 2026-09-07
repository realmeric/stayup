import XCTest
@testable import StayUp

/// The `pmset -g batt` fallback. IOKit.ps is what the app reads; this parser
/// exists for the day it comes back empty, and it is the only half of the
/// power reading that can be held still in a test.
final class PowerTests: XCTestCase {
    func testDischarging() {
        let text = """
        Now drawing from 'Battery Power'
         -InternalBattery-0 (id=22806627)\t76%; discharging; 13:26 remaining present: true
        """
        XCTAssertEqual(Power.parse(pmsetBatt: text), PowerReading(onAC: false, percent: 76))
    }

    func testCharged() {
        let text = """
        Now drawing from 'AC Power'
         -InternalBattery-0 (id=22806627)\t100%; charged; 0:00 remaining present: true
        """
        XCTAssertEqual(Power.parse(pmsetBatt: text), PowerReading(onAC: true, percent: 100))
    }

    /// A Mac with no battery prints the source and nothing else.
    func testNoBattery() {
        XCTAssertEqual(Power.parse(pmsetBatt: "Now drawing from 'AC Power'"),
                       PowerReading(onAC: true, percent: 100))
    }
}
