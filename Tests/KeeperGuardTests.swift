import XCTest
@testable import StayUp

/// The two guards. Heat cannot be made to order on this Mac, so this is where
/// the thermal rules are actually proved; `STAYUP_FAKE_THERMAL` only proves
/// the wiring.
final class KeeperGuardTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_788_000_000)
    private var keeper = Keeper()

    override func setUp() {
        super.setUp()
        keeper = Keeper(settings: .defaults)
    }

    private func at(_ seconds: TimeInterval,
                    thermal: ThermalLevel = .nominal,
                    onAC: Bool = true,
                    percent: Int = 100,
                    lidClosed: Bool = false) -> Inputs {
        Inputs(now: t0.addingTimeInterval(seconds),
               thermal: thermal,
               power: PowerReading(onAC: onAC, percent: percent),
               lidClosed: lidClosed,
               lastAgentWrite: nil)
    }

    private func startTimed() {
        _ = keeper.start(.timed(until: t0.addingTimeInterval(7200)), inputs: at(0))
    }

    // MARK: - Heat

    /// A pause with the lid closed means the Mac sleeps, which also means the
    /// app stops running and the resume waits for the lid to open. That is the
    /// honest limit, and it is what the notification says.
    func testCriticalPausesAndSleepsWithTheLidClosed() {
        startTimed()
        XCTAssertEqual(keeper.tick(inputs: at(20, thermal: .critical, lidClosed: true)),
                       [.release(sleepNow: true), .notify(.paused(.thermal))])
        XCTAssertEqual(keeper.paused, .thermal)
    }

    func testThePauseDoesNotRepeat() {
        startTimed()
        _ = keeper.tick(inputs: at(20, thermal: .critical))
        XCTAssertEqual(keeper.tick(inputs: at(40, thermal: .critical)), [])
        XCTAssertEqual(keeper.tick(inputs: at(60, thermal: .critical)), [])
    }

    /// Two minutes of calm, not one reading of it. A Mac that hovers on the
    /// line would otherwise pause and resume every twenty seconds.
    func testItResumesOnlyAfterTwoMinutesOfCalm() {
        startTimed()
        _ = keeper.tick(inputs: at(20, thermal: .critical))
        XCTAssertEqual(keeper.tick(inputs: at(40, thermal: .fair)), [])
        XCTAssertEqual(keeper.tick(inputs: at(159, thermal: .fair)), [])
        XCTAssertEqual(keeper.tick(inputs: at(160, thermal: .fair)),
                       [.notify(.resumed), .raise])
        XCTAssertTrue(keeper.raised)
    }

    /// The calm has to be continuous: one hot reading in the middle starts the
    /// two minutes again.
    func testHeatInTheMiddleRestartsTheCalm() {
        startTimed()
        _ = keeper.tick(inputs: at(20, thermal: .critical))
        _ = keeper.tick(inputs: at(40, thermal: .fair))
        _ = keeper.tick(inputs: at(100, thermal: .critical))
        XCTAssertEqual(keeper.tick(inputs: at(120, thermal: .fair)), [])
        XCTAssertEqual(keeper.tick(inputs: at(239, thermal: .fair)), [])
        XCTAssertEqual(keeper.tick(inputs: at(240, thermal: .fair)),
                       [.notify(.resumed), .raise])
    }

    /// Serious under the default level: a word, not a pause.
    func testSeriousWarnsOnceAndKeepsGoing() {
        startTimed()
        XCTAssertEqual(keeper.tick(inputs: at(20, thermal: .serious)), [.notify(.thermalWarning)])
        XCTAssertEqual(keeper.tick(inputs: at(40, thermal: .serious)), [])
        XCTAssertTrue(keeper.raised)
        XCTAssertNil(keeper.paused)
    }

    func testSeriousPausesWhenThatIsTheLevel() {
        keeper.settings.thermalPauseLevel = .serious
        startTimed()
        XCTAssertEqual(keeper.tick(inputs: at(20, thermal: .serious)),
                       [.release(sleepNow: false), .notify(.paused(.thermal))])
    }

    /// The warning is per session, so a second start says it again.
    func testTheHeatWarningComesBackWithANewSession() {
        startTimed()
        _ = keeper.tick(inputs: at(20, thermal: .serious))
        _ = keeper.stop(reason: .stopped, inputs: at(40))
        _ = keeper.start(.timed(until: t0.addingTimeInterval(7200)), inputs: at(60))
        XCTAssertEqual(keeper.tick(inputs: at(80, thermal: .serious)), [.notify(.thermalWarning)])
    }

    // MARK: - Battery

    func testItPausesUnderTheFloor() {
        startTimed()
        XCTAssertEqual(keeper.tick(inputs: at(20, onAC: false, percent: 14)),
                       [.release(sleepNow: false), .notify(.paused(.battery))])
    }

    func testFifteenIsNotUnderTheFloor() {
        startTimed()
        XCTAssertEqual(keeper.tick(inputs: at(20, onAC: false, percent: 15)), [])
        XCTAssertTrue(keeper.raised)
    }

    /// The floor and the resume are different numbers on purpose: coming back
    /// at 15% would pause again on the next tick.
    func testItResumesAtTwentyAndNotAtNineteen() {
        startTimed()
        _ = keeper.tick(inputs: at(20, onAC: false, percent: 14))
        XCTAssertEqual(keeper.tick(inputs: at(40, onAC: false, percent: 19)), [])
        XCTAssertEqual(keeper.tick(inputs: at(60, onAC: false, percent: 20)),
                       [.notify(.resumed), .raise])
    }

    func testTheCableResumesAtAnyPercent() {
        startTimed()
        _ = keeper.tick(inputs: at(20, onAC: false, percent: 5))
        XCTAssertEqual(keeper.tick(inputs: at(40, onAC: true, percent: 5)),
                       [.notify(.resumed), .raise])
    }

    /// Switched off from the menu, heat is not consulted at all. The reading
    /// still arrives; nothing is done with it.
    func testHeatIsIgnoredWhenTheSwitchIsOff() {
        keeper.settings.pauseWhenHot = false
        startTimed()
        XCTAssertEqual(keeper.tick(inputs: at(20, thermal: .critical)), [])
        XCTAssertTrue(keeper.raised)
        XCTAssertNil(keeper.paused)
    }

    func testTheFloorIsIgnoredWhenTheSwitchIsOff() {
        keeper.settings.pauseOnLowBattery = false
        startTimed()
        XCTAssertEqual(keeper.tick(inputs: at(20, onAC: false, percent: 3)), [])
        XCTAssertTrue(keeper.raised)
    }

    // MARK: - Only while charging

    func testOnlyWhileChargingPausesOnBatteryAtAnyPercent() {
        keeper.settings.onlyWhileCharging = true
        startTimed()
        XCTAssertEqual(keeper.tick(inputs: at(20, onAC: false, percent: 90)),
                       [.release(sleepNow: false), .notify(.paused(.charging))])
        XCTAssertEqual(keeper.tick(inputs: at(40, onAC: true, percent: 90)),
                       [.notify(.resumed), .raise])
    }

    /// Starting into a guard pauses on the way in rather than raising the flag
    /// and dropping it a tick later.
    func testStartingIntoAGuardNeverRaises() {
        keeper.settings.onlyWhileCharging = true
        let effects = keeper.start(.timed(until: t0.addingTimeInterval(7200)),
                                   inputs: at(0, onAC: false, percent: 90))
        XCTAssertEqual(effects, [.notify(.paused(.charging))])
        XCTAssertFalse(keeper.raised)
    }

    // MARK: - Guards against each other

    /// A pause lifts on its own condition and no other. Hot and unplugged, the
    /// cable going in must not resume a thermal pause.
    func testTheCableDoesNotLiftAThermalPause() {
        startTimed()
        _ = keeper.tick(inputs: at(20, thermal: .critical, onAC: false, percent: 50))
        XCTAssertEqual(keeper.tick(inputs: at(40, thermal: .critical, onAC: true)), [])
        XCTAssertEqual(keeper.paused, .thermal)
    }

    /// And a session that runs out while paused ends without a second release:
    /// the flag came down when the pause started.
    func testASessionCanEndWhilePaused() {
        _ = keeper.start(.timed(until: t0.addingTimeInterval(60)), inputs: at(0))
        _ = keeper.tick(inputs: at(20, thermal: .critical))
        XCTAssertEqual(keeper.tick(inputs: at(60, thermal: .critical)), [])
        XCTAssertEqual(keeper.mode, .off)
        XCTAssertNil(keeper.paused)
    }
}
