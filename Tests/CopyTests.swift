import XCTest
@testable import StayUp

final class CopyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_788_000_000)

    private func status(mode: Mode = .off,
                        helper: HelperStatus = .installed,
                        paused: PauseReason? = nil,
                        percent: Int = 100,
                        lastAgentWrite: Date? = nil) -> Status {
        var status = Status()
        status.mode = mode
        status.helper = helper
        status.paused = paused
        status.power = PowerReading(onAC: true, percent: percent)
        status.lastAgentWrite = lastAgentWrite
        return status
    }

    // MARK: - Durations

    func testTheMenusDurationsReadAsWritten() {
        XCTAssertEqual(Copy.duration(1800), "30 m")
        XCTAssertEqual(Copy.duration(3600), "1 h")
        XCTAssertEqual(Copy.duration(7200), "2 h")
        XCTAssertEqual(Copy.duration(18000), "5 h")
        XCTAssertEqual(Copy.duration(28800), "8 h")
    }

    func testAnythingElseReadsAsHoursAndMinutes() {
        XCTAssertEqual(Copy.duration(4980), "1 h 23 m")
        XCTAssertEqual(Copy.duration(59), "0 m")
        XCTAssertEqual(Copy.duration(-10), "0 m")
    }

    /// The menu instructs and the status line reports, so they are worded
    /// differently on purpose.
    func testTheMenuSpellsItOut() {
        XCTAssertEqual(Copy.awakeFor(1800), "Awake for 30 minutes")
        XCTAssertEqual(Copy.awakeFor(3600), "Awake for 1 hour")
        XCTAssertEqual(Copy.awakeFor(7200), "Awake for 2 hours")
        XCTAssertEqual(Copy.awakeFor(28800), "Awake for 8 hours")
        XCTAssertEqual(Copy.awakeFor(4980), "Awake for 1 hour 23 minutes")
    }

    // MARK: - The status line

    func testOff() {
        XCTAssertEqual(Copy.statusLine(status(), now: now), "Off")
    }

    func testTimed() {
        let status = status(mode: .timed(until: now.addingTimeInterval(4980)))
        XCTAssertEqual(Copy.statusLine(status, now: now), "Awake · 1 h 23 m left")
    }

    func testFollow() {
        let status = status(mode: .follow(started: now.addingTimeInterval(-600)),
                            lastAgentWrite: now.addingTimeInterval(-40))
        XCTAssertEqual(Copy.statusLine(status, now: now),
                       "Awake · until the agents finish · last write 40 s ago")
    }

    /// Before the first transcript there is nothing to report, and the grace
    /// is the reason that is not yet a problem.
    func testFollowBeforeAnyWrite() {
        let status = status(mode: .follow(started: now))
        XCTAssertEqual(Copy.statusLine(status, now: now),
                       "Awake · until the agents finish · never")
    }

    func testIndefiniteCountsUp() {
        let status = status(mode: .indefinite(started: now.addingTimeInterval(-11520)))
        XCTAssertEqual(Copy.statusLine(status, now: now), "Awake · 3 h 12 m")
    }

    func testTooHot() {
        let status = status(mode: .timed(until: now), paused: .thermal)
        XCTAssertEqual(Copy.statusLine(status, now: now), "Paused · too hot")
    }

    func testLowBattery() {
        let status = status(mode: .timed(until: now), paused: .battery, percent: 12)
        XCTAssertEqual(Copy.statusLine(status, now: now), "Paused · battery 12%")
    }

    func testNotCharging() {
        let status = status(mode: .timed(until: now), paused: .charging)
        XCTAssertEqual(Copy.statusLine(status, now: now), "Paused · not charging")
    }

    /// Whatever else is true, the first thing to say is that it cannot work
    /// yet.
    func testTheHelperOutranksTheRest() {
        let status = status(mode: .timed(until: now.addingTimeInterval(600)), helper: .missing)
        XCTAssertEqual(Copy.statusLine(status, now: now), "Set up needed")
    }

    // MARK: - How long ago

    func testAgo() {
        XCTAssertEqual(Copy.ago(0), "0 s ago")
        XCTAssertEqual(Copy.ago(40), "40 s ago")
        XCTAssertEqual(Copy.ago(59), "59 s ago")
        XCTAssertEqual(Copy.ago(60), "1 m ago")
        XCTAssertEqual(Copy.ago(3599), "59 m ago")
        XCTAssertEqual(Copy.ago(3600), "1 h ago")
        XCTAssertEqual(Copy.ago(4980), "1 h 23 m ago")
    }

    /// A clock a second behind should not read as the future.
    func testTheFutureReadsAsNow() {
        XCTAssertEqual(Copy.ago(-5), "0 s ago")
    }
}
