import XCTest
@testable import StayUp

/// The keeper, asked about moments rather than made to wait for them. Every
/// test here fixes `t0` and hands the clock in.
final class KeeperTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_788_000_000)
    private var keeper = Keeper()

    override func setUp() {
        super.setUp()
        keeper = Keeper(settings: .defaults)
    }

    private func at(_ seconds: TimeInterval,
                    lidClosed: Bool = false,
                    lastAgentWrite: Date? = nil) -> Inputs {
        Inputs(now: t0.addingTimeInterval(seconds),
               lidClosed: lidClosed,
               lastAgentWrite: lastAgentWrite)
    }

    // MARK: - Timed

    func testStartingATimedSessionRaisesTheFlag() {
        XCTAssertEqual(keeper.start(.timed(until: t0.addingTimeInterval(1800)), inputs: at(0)),
                       [.raise])
        XCTAssertTrue(keeper.raised)
    }

    func testNothingHappensInTheMiddle() {
        _ = keeper.start(.timed(until: t0.addingTimeInterval(1800)), inputs: at(0))
        XCTAssertEqual(keeper.tick(inputs: at(600)), [])
        XCTAssertEqual(keeper.tick(inputs: at(1499)), [])
    }

    /// Five minutes out, once. A warning that repeats every 20 s for the last
    /// five minutes is fifteen notifications.
    func testItWarnsFiveMinutesOutAndOnlyOnce() {
        _ = keeper.start(.timed(until: t0.addingTimeInterval(1800)), inputs: at(0))
        XCTAssertEqual(keeper.tick(inputs: at(1500)), [.notify(.warning(300))])
        XCTAssertEqual(keeper.tick(inputs: at(1520)), [])
        XCTAssertEqual(keeper.tick(inputs: at(1740)), [])
    }

    /// The lid decides whether the release is followed by a sleep, because
    /// with the lid closed "the time is up" should mean asleep now rather than
    /// whenever powerd next looks.
    func testTheTimerEndsItAndTheLidDecidesTheSleep() {
        _ = keeper.start(.timed(until: t0.addingTimeInterval(1800)), inputs: at(0))
        _ = keeper.tick(inputs: at(1500))
        XCTAssertEqual(keeper.tick(inputs: at(1800, lidClosed: true)),
                       [.release(sleepNow: true), .notify(.ended(.timer))])
        XCTAssertEqual(keeper.mode, .off)
        XCTAssertFalse(keeper.raised)
    }

    func testWithTheLidOpenTheTimerDoesNotSleepTheMac() {
        _ = keeper.start(.timed(until: t0.addingTimeInterval(1800)), inputs: at(0))
        _ = keeper.tick(inputs: at(1500))
        XCTAssertEqual(keeper.tick(inputs: at(1800)),
                       [.release(sleepNow: false), .notify(.ended(.timer))])
    }

    func testAnEndedSessionStaysEnded() {
        _ = keeper.start(.timed(until: t0.addingTimeInterval(1800)), inputs: at(0))
        _ = keeper.tick(inputs: at(1500))
        _ = keeper.tick(inputs: at(1800))
        XCTAssertEqual(keeper.tick(inputs: at(1820)), [])
    }

    // MARK: - Follow

    /// Nothing has written a transcript at all. The grace is what keeps this
    /// from ending on the first tick, so the session can be started before the
    /// agent is.
    func testFollowWithNoWritesEndsAfterTheGrace() {
        XCTAssertEqual(keeper.start(.follow(started: t0), inputs: at(0)), [.raise])
        XCTAssertEqual(keeper.tick(inputs: at(300)), [])
        XCTAssertEqual(keeper.tick(inputs: at(301)),
                       [.release(sleepNow: false), .notify(.ended(.agentsIdle))])
    }

    /// A write four minutes in buys three more minutes from the moment of the
    /// write, not from the start.
    func testFollowFollowsTheLastWrite() {
        let write = t0.addingTimeInterval(240)
        _ = keeper.start(.follow(started: t0), inputs: at(0))
        XCTAssertEqual(keeper.tick(inputs: at(360, lastAgentWrite: write)), [])
        XCTAssertEqual(keeper.tick(inputs: at(420, lastAgentWrite: write)), [])
        XCTAssertEqual(keeper.tick(inputs: at(421, lastAgentWrite: write)),
                       [.release(sleepNow: false), .notify(.ended(.agentsIdle))])
    }

    /// An agent that never stops writing still does not keep the Mac awake
    /// for a week.
    func testFollowHasACap() {
        var busy = t0
        _ = keeper.start(.follow(started: t0), inputs: at(0))
        busy = t0.addingTimeInterval(28800)
        XCTAssertEqual(keeper.tick(inputs: at(28800, lastAgentWrite: busy)), [])
        busy = t0.addingTimeInterval(28801)
        XCTAssertEqual(keeper.tick(inputs: at(28801, lastAgentWrite: busy)),
                       [.release(sleepNow: false), .notify(.ended(.cap(28800)))])
    }

    // MARK: - Indefinite

    func testIndefiniteRunsToItsCap() {
        _ = keeper.start(.indefinite(started: t0), inputs: at(0))
        XCTAssertEqual(keeper.tick(inputs: at(86340)), [])
        XCTAssertEqual(keeper.tick(inputs: at(86401)),
                       [.release(sleepNow: false), .notify(.ended(.cap(86400)))])
    }

    /// A cap of 0 is the setting this app exists because of, so it is spelled
    /// out rather than left to be discovered.
    func testACapOfZeroNeverEnds() {
        keeper.settings.indefiniteCap = 0
        _ = keeper.start(.indefinite(started: t0), inputs: at(0))
        XCTAssertEqual(keeper.tick(inputs: at(86401)), [])
        XCTAssertEqual(keeper.tick(inputs: at(864000)), [])
        XCTAssertTrue(keeper.raised)
    }

    // MARK: - Stop

    /// You clicked it, so you are at the keyboard and the Mac should stay up.
    func testStopReleasesWithoutSleeping() {
        _ = keeper.start(.timed(until: t0.addingTimeInterval(1800)), inputs: at(0))
        XCTAssertEqual(keeper.stop(reason: .stopped, inputs: at(60, lidClosed: true)),
                       [.release(sleepNow: false)])
        XCTAssertEqual(keeper.mode, .off)
    }

    /// Quit could be anything, including a shutdown, so it follows the lid.
    func testQuitFollowsTheLid() {
        _ = keeper.start(.timed(until: t0.addingTimeInterval(1800)), inputs: at(0))
        XCTAssertEqual(keeper.stop(reason: .quit, inputs: at(60, lidClosed: true)),
                       [.release(sleepNow: true)])
    }

    func testStoppingWhenNothingIsRunningDoesNothing() {
        XCTAssertEqual(keeper.stop(reason: .stopped, inputs: at(0)), [])
    }
}
