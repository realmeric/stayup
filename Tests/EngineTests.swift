import XCTest
@testable import StayUp

/// The engine with every dependency held: fake sources, a fake writer, a lease
/// in a temp directory and the tick driven by hand. Nothing here runs `sudo`,
/// `pmset` or `osascript`.
@MainActor
final class EngineTests: XCTestCase {
    private var room: URL!
    private var thermal: FakeThermalSource!
    private var power: FakePowerSource!
    private var lid: FakeLidSource!
    private var agents: FakeAgentSource!
    private var writer: FakeFlagWriter!
    private var notifier: RecordingNotifier!
    private var helper: HelperStatus = .installed
    private var suite: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suite = "engine-\(UUID().uuidString)"
        room = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(suite, isDirectory: true)
        thermal = FakeThermalSource()
        power = FakePowerSource()
        lid = FakeLidSource()
        agents = FakeAgentSource()
        writer = FakeFlagWriter()
        notifier = RecordingNotifier()
        helper = .installed
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: room)
        Shell.runner = nil
        super.tearDown()
    }

    private func makeEngine(settings: Settings = .defaults) -> Engine {
        // Its own defaults suite: nothing under Tests/ writes to the real one.
        Engine(store: SettingsStore(defaults: UserDefaults(suiteName: suite)!),
               settings: settings,
               thermal: thermal,
               power: power,
               lid: lid,
               agents: agents,
               writer: writer,
               notifier: notifier,
               helperStatus: { _ in self.helper },
               leaseBase: room,
               interval: 3600)
    }

    private var lease: Date? { Lease.read(base: room) }

    func testStartingRaisesTheFlagAndWritesALease() {
        let engine = makeEngine()
        engine.start(.timed(until: Date().addingTimeInterval(1800)))
        XCTAssertEqual(writer.raised, [true])
        XCTAssertTrue(engine.status.raised)
        let ahead = try? XCTUnwrap(lease).timeIntervalSinceNow
        XCTAssertNotNil(ahead)
        XCTAssertEqual(ahead ?? 0, 120, accuracy: 5)
    }

    /// The lease is rewritten on every tick, not only on the tick that raised
    /// the flag: it has to stay ahead of a guard that runs every 60 s.
    func testEveryTickRenewsTheLease() throws {
        let engine = makeEngine()
        engine.start(.timed(until: Date().addingTimeInterval(1800)))
        let first = try XCTUnwrap(lease)
        Lease.renew(until: Date().addingTimeInterval(-1), base: room)
        engine.tick()
        let second = try XCTUnwrap(lease)
        XCTAssertGreaterThan(second, first.addingTimeInterval(-1))
        XCTAssertEqual(second.timeIntervalSinceNow, 120, accuracy: 5)
    }

    /// Stop takes the flag down and the lease with it, in that order.
    func testStopReleasesAndClearsTheLease() {
        let engine = makeEngine()
        engine.start(.timed(until: Date().addingTimeInterval(1800)))
        engine.stop()
        XCTAssertEqual(writer.raised, [true, false])
        XCTAssertNil(lease)
        XCTAssertEqual(engine.status.mode, .off)
    }

    /// A refusal is the end of the session, not a tick to retry. The message
    /// is sudo's own, so the menu can show what actually went wrong.
    func testARefusalEndsTheSessionAndIsRemembered() {
        writer.failure = .refused("sudo: a password is required")
        let engine = makeEngine()
        engine.start(.timed(until: Date().addingTimeInterval(1800)))
        XCTAssertEqual(engine.status.error, "sudo: a password is required")
        XCTAssertEqual(engine.status.mode, .off)
        XCTAssertFalse(engine.status.raised)
        XCTAssertNil(lease)
    }

    /// Without the rule there is nothing to start, and saying so beats
    /// raising a flag that will not go up.
    func testStartIsRefusedWithoutTheRule() {
        helper = .missing
        let engine = makeEngine()
        engine.start(.timed(until: Date().addingTimeInterval(1800)))
        XCTAssertEqual(engine.status.mode, .off)
        XCTAssertEqual(writer.raised, [])
        XCTAssertEqual(engine.status.helper, .missing)
    }

    /// The guard, all the way through: the reading changes, the tick sees it,
    /// the flag comes down, the lease goes, and the notification is delivered.
    func testHeatPausesTheSessionAndSaysSo() {
        let engine = makeEngine()
        engine.start(.timed(until: Date().addingTimeInterval(1800)))
        thermal.level = .critical
        engine.tick()
        XCTAssertEqual(writer.raised, [true, false])
        XCTAssertNil(lease)
        XCTAssertEqual(notifier.notices, [.paused(.thermal)])
        XCTAssertEqual(engine.status.paused, .thermal)
    }

    /// A release with the lid closed is followed by `pmset sleepnow`, so that
    /// "the machine is too hot" means asleep now rather than whenever powerd
    /// next re-evaluates the lid.
    func testAClosedLidIsFollowedBySleepnow() {
        var asked: [[String]] = []
        Shell.runner = { path, args in
            asked.append([path] + args)
            return (0, "", "")
        }
        lid.closed = true
        let engine = makeEngine()
        engine.start(.timed(until: Date().addingTimeInterval(1800)))
        thermal.level = .critical
        engine.tick()
        XCTAssertEqual(asked, [["/usr/bin/pmset", "sleepnow"]])
    }

    /// With the lid open there is nobody to wake it, so nothing is asked.
    func testAnOpenLidIsNotFollowedBySleepnow() {
        var asked: [[String]] = []
        Shell.runner = { path, args in
            asked.append([path] + args)
            return (0, "", "")
        }
        let engine = makeEngine()
        engine.start(.timed(until: Date().addingTimeInterval(1800)))
        thermal.level = .critical
        engine.tick()
        XCTAssertEqual(asked, [])
    }

    /// Quit follows the lid, because quitting could be a shutdown.
    func testQuitWithTheLidClosedSleepsTheMac() {
        var asked: [[String]] = []
        Shell.runner = { path, args in
            asked.append([path] + args)
            return (0, "", "")
        }
        lid.closed = true
        let engine = makeEngine()
        engine.start(.timed(until: Date().addingTimeInterval(1800)))
        engine.stop(reason: .quit)
        XCTAssertEqual(asked, [["/usr/bin/pmset", "sleepnow"]])
    }

    func testStopWithTheLidClosedDoesNotSleepTheMac() {
        var asked: [[String]] = []
        Shell.runner = { path, args in
            asked.append([path] + args)
            return (0, "", "")
        }
        lid.closed = true
        let engine = makeEngine()
        engine.start(.timed(until: Date().addingTimeInterval(1800)))
        engine.stop()
        XCTAssertEqual(asked, [])
    }

    /// The engine reads the machine once per tick and puts every reading in
    /// the status, because the menu draws from the status and nothing else.
    func testTheStatusCarriesTheReadings() {
        thermal.level = .fair
        power.reading = PowerReading(onAC: false, percent: 42)
        lid.closed = true
        agents.lastWrite = Date(timeIntervalSince1970: 1_788_000_000)
        let engine = makeEngine()
        engine.tick()
        XCTAssertEqual(engine.status.thermal, .fair)
        XCTAssertEqual(engine.status.power, PowerReading(onAC: false, percent: 42))
        XCTAssertTrue(engine.status.lidClosed)
        XCTAssertEqual(engine.status.lastAgentWrite, agents.lastWrite)
        XCTAssertEqual(engine.status.helper, .installed)
    }

    /// Follow ends on its own once the transcripts stop growing, and the
    /// engine is what turns that into a released flag.
    func testFollowEndsWhenTheAgentsGoQuiet() {
        let engine = makeEngine()
        agents.lastWrite = Date()
        engine.start(.follow(started: Date().addingTimeInterval(-600)))
        XCTAssertEqual(writer.raised, [true])
        agents.lastWrite = Date().addingTimeInterval(-1200)
        engine.tick()
        XCTAssertEqual(writer.raised, [true, false])
        XCTAssertEqual(notifier.notices, [.ended(.agentsIdle)])
        XCTAssertNil(lease)
    }
}
