import Combine
import Foundation

/// What the menu draws and what the log reports.
struct Status: Equatable {
    var mode: Mode = .off
    var paused: PauseReason?
    var raised = false
    /// When a timed session runs out. Nil in every other mode.
    var endsAt: Date?
    var helper: HelperStatus = .missing
    var thermal: ThermalLevel = .nominal
    var power = PowerReading(onAC: true, percent: 100)
    var lidClosed = false
    var lastAgentWrite: Date?
    /// What `sudo` said the last time it refused. Cleared by the next start.
    var error: String?
}

/// The wiring: the machine into the keeper, and the keeper's mind into the
/// flag, the lease and the notifications.
///
/// This is the one place in the app that reads the clock, and the only place
/// that turns an `Effect` into something that happened.
@MainActor
final class Engine: ObservableObject {
    @Published private(set) var status = Status()

    /// Changed from the menu and from the settings window, and written down
    /// the moment it changes: there is no Save button anywhere in this app.
    @Published var settings: Settings {
        didSet {
            keeper.settings = settings
            (agents as? AgentActivity)?.directories = settings.watchedDirectories
            store.save(settings)
            // The screen is claimed from the settings rather than from an
            // effect, so switching it off mid-session lets go on the spot.
            syncScreen()
            if settings.hotkey != oldValue.hotkey
                || settings.hotkeyEnabled != oldValue.hotkeyEnabled {
                adoptHotkey()
            }
        }
    }

    private var keeper: Keeper
    private let thermal: ThermalSource
    private let power: PowerSource
    private let lid: LidSource
    private let agents: AgentSource
    private let writer: FlagWriting
    private let screen: ScreenHolding
    private var notifier: Notifying
    private let store: SettingsStore
    private let helperStatus: (Bool) -> HelperStatus
    private let leaseBase: URL
    private let interval: TimeInterval
    private var timer: Timer?

    /// How far ahead the lease is written. Two minutes against a guard that
    /// runs every one: a tick can be missed without the flag coming down, and
    /// two cannot.
    private let leaseAhead: TimeInterval = 120

    init(store: SettingsStore = SettingsStore(),
         settings: Settings? = nil,
         thermal: ThermalSource = MachineThermalSource(),
         power: PowerSource = MachinePowerSource(),
         lid: LidSource = MachineLidSource(),
         agents: AgentSource = AgentActivity(),
         writer: FlagWriting? = nil,
         screen: ScreenHolding = DisplayAssertion(),
         notifier: Notifying? = nil,
         helperStatus: @escaping (Bool) -> HelperStatus = { HelperInstaller.status(wanting: $0) },
         leaseBase: URL = Lease.directory,
         interval: TimeInterval = 20) {
        let settings = settings ?? store.load()
        self.store = store
        self.settings = settings
        self.keeper = Keeper(settings: settings)
        self.thermal = thermal
        self.power = power
        self.lid = lid
        self.agents = agents
        self.writer = writer ?? Engine.defaultWriter()
        self.screen = screen
        self.notifier = notifier ?? LoggingNotifier()
        self.helperStatus = helperStatus
        self.leaseBase = leaseBase
        self.interval = interval
        (self.agents as? AgentActivity)?.directories = settings.watchedDirectories

        let wake: () -> Void = { [weak self] in
            Task { @MainActor in self?.tick() }
        }
        if notifier == nil {
            // After the stored properties, because it reads the settings back
            // out of the engine each time it has something to say.
            self.notifier = UserNotifier(settings: { [weak self] in self?.settings ?? .defaults })
        }
        self.thermal.onChange = wake
        self.power.onChange = wake
        self.lid.onChange = wake
        self.agents.onChange = wake
    }

    private static func defaultWriter() -> FlagWriting {
        ProcessInfo.processInfo.environment["STAYUP_DRY_RUN"] != nil
            ? DryRunFlagWriter()
            : SudoFlagWriter()
    }

    /// Hand the current shortcut to the one thing that registers it. Called at
    /// launch and whenever the choice changes.
    func adoptHotkey() {
        HotkeyCenter.shared.adopt(settings.hotkey, enabled: settings.hotkeyEnabled)
    }

    func use(_ notifier: Notifying) {
        self.notifier = notifier
    }

    func startTicking() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        tick()
    }

    func stopTicking() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - What the menu calls

    func start(_ mode: Mode) {
        // Nothing is running yet, so the probe re-applies 0, which is what
        // the flag should be reading anyway.
        status.helper = helperStatus(keeper.raised)
        guard status.helper == .installed else {
            Log.app.error("start refused: the sudoers rule is not installed")
            refreshStatus(inputs: gather())
            return
        }
        status.error = nil
        notifier.prepare()
        // Gathered once: the effects and the lease should be written against
        // the same reading the decision was made from.
        let inputs = gather()
        apply(keeper.start(mode, inputs: inputs), inputs: inputs)
    }

    /// What a left click on the icon and the shortcut both do: stop a session
    /// that is running, or start the one the settings call the quick start.
    ///
    /// One gesture for both directions on purpose. A switch you flip is a
    /// switch you can use without looking at it, which is the whole argument
    /// for putting it on the left button.
    func toggleQuickStart() {
        if keeper.mode.isActive {
            stop()
            return
        }
        let now = Date()
        switch settings.quickStart {
        case .timed(let seconds):
            start(.timed(until: now.addingTimeInterval(seconds)))
        case .follow:
            start(.follow(started: now))
        case .indefinite:
            start(.indefinite(started: now))
        }
    }

    func stop(reason: EndReason = .stopped) {
        let inputs = gather()
        apply(keeper.stop(reason: reason, inputs: inputs), inputs: inputs)
    }

    func tick() {
        let inputs = gather()
        apply(keeper.tick(inputs: inputs), inputs: inputs)
        // The lease is rewritten on every tick the flag is up, not only on the
        // tick that raised it: it is a claim that has to stay ahead of the
        // guard, not a record that a session started.
        if keeper.raised {
            Lease.renew(until: inputs.now.addingTimeInterval(leaseAhead), base: leaseBase)
        }
    }

    // MARK: - The turn of the crank

    private func gather() -> Inputs {
        Inputs(now: Date(),
               thermal: thermal.read(),
               power: power.read(),
               lidClosed: lid.read(),
               lastAgentWrite: agents.read())
    }

    private func apply(_ effects: [Effect], inputs: Inputs? = nil) {
        let inputs = inputs ?? gather()
        for effect in effects {
            switch effect {
            case .raise:
                // The lease only follows a flag that actually went up. A
                // lease over a flag that is down would tell the guard to
                // leave something alone that was never raised.
                if perform({ try writer.raise() }) {
                    Lease.renew(until: inputs.now.addingTimeInterval(leaseAhead), base: leaseBase)
                }
            case .release(let sleepNow):
                // The flag comes down before the lease does, always. The other
                // order leaves a moment in which the flag is up and nothing is
                // claiming it, which is exactly what the guard clears.
                _ = perform { try writer.release() }
                Lease.clear(base: leaseBase)
                if sleepNow { sleep() }
            case .notify(let notice):
                notifier.deliver(notice)
            }
        }
        syncScreen()
        refreshStatus(inputs: inputs)
    }

    /// The second sleep. The flag stops the Mac sleeping and does nothing at
    /// all about the display, which powerd blanks on its own timer; this
    /// follows the flag so the two go up and come down together.
    private func syncScreen() {
        if keeper.raised && settings.keepScreenOn {
            screen.hold()
        } else {
            screen.release()
        }
    }

    /// A writer that refuses is the end of the session, not a tick to retry:
    /// the rule is gone or `sudo` has changed its mind, and neither gets
    /// better by asking again in twenty seconds.
    @discardableResult
    private func perform(_ work: () throws -> Void) -> Bool {
        do {
            try work()
            return true
        } catch {
            let message: String
            if case FlagError.refused(let said) = error, !said.isEmpty {
                message = said
            } else {
                message = error.localizedDescription
            }
            Log.flag.error("the flag would not move: \(message, privacy: .public)")
            status.error = message
            _ = keeper.stop(reason: .stopped, inputs: gather())
            Lease.clear(base: leaseBase)
            return false
        }
    }

    private func sleep() {
        do {
            // No root needed for this one, and it is the difference between
            // "the timer ended" meaning asleep now and meaning whenever powerd
            // next re-evaluates the lid.
            _ = try Shell.run("/usr/bin/pmset", ["sleepnow"])
            Log.flag.info("asked the Mac to sleep")
        } catch {
            Log.flag.error("sleepnow would not run: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func refreshStatus(inputs: Inputs) {
        var endsAt: Date?
        if case .timed(let until) = keeper.mode { endsAt = until }
        status.mode = keeper.mode
        status.paused = keeper.paused
        status.raised = keeper.raised
        status.endsAt = endsAt
        status.helper = helperStatus(keeper.raised)
        status.thermal = inputs.thermal
        status.power = inputs.power
        status.lidClosed = inputs.lidClosed
        status.lastAgentWrite = inputs.lastAgentWrite
    }
}
