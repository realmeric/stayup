import AppKit
import XCTest
@testable import StayUp

final class StatusIconTests: XCTestCase {
    private func status(helper: HelperStatus = .installed,
                        raised: Bool = false,
                        paused: PauseReason? = nil,
                        percent: Int = 100) -> Status {
        var status = Status()
        status.helper = helper
        status.raised = raised
        status.paused = paused
        status.power = PowerReading(onAC: true, percent: percent)
        return status
    }

    func testOff() {
        XCTAssertEqual(StatusIcon.name(for: status()), "moon.zzz")
    }

    func testRaised() {
        XCTAssertEqual(StatusIcon.name(for: status(raised: true)), "sun.max.fill")
    }

    func testTooHot() {
        XCTAssertEqual(StatusIcon.name(for: status(paused: .thermal)), "thermometer.high")
    }

    func testLowBattery() {
        XCTAssertEqual(StatusIcon.name(for: status(paused: .battery)), "battery.25percent")
    }

    func testNotCharging() {
        XCTAssertEqual(StatusIcon.name(for: status(paused: .charging)), "bolt.slash")
    }

    /// The rule missing outranks everything: nothing else in the status can
    /// be acted on until it is there.
    func testTheHelperOutranksTheRest() {
        XCTAssertEqual(StatusIcon.name(for: status(helper: .missing, raised: true)),
                       "exclamationmark.triangle")
    }

    /// Every name is a symbol that exists on this Mac. A typo here shows up
    /// as an empty menu bar, which is not a failure anyone would read.
    func testEverySymbolExists() {
        for status in [status(),
                       status(raised: true),
                       status(paused: .thermal),
                       status(paused: .battery),
                       status(paused: .charging),
                       status(helper: .missing)] {
            let name = StatusIcon.name(for: status)
            XCTAssertNotNil(NSImage(systemSymbolName: name, accessibilityDescription: nil), name)
        }
    }
}
