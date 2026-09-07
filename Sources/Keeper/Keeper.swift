import Foundation

/// Everything the engine hands the keeper on a tick.
struct Inputs {
    var now: Date
    var thermal: ThermalLevel = .nominal
    var power: PowerReading = PowerReading(onAC: true, percent: 100)
    var lidClosed: Bool = false
    var lastAgentWrite: Date?
}

enum PauseReason: Equatable {
    case thermal
    case battery
    case charging
}

enum EndReason: Equatable {
    case timer
    case agentsIdle
    case cap
    case stopped
    case quit
}

enum Notice: Equatable {
    case paused(PauseReason)
    case resumed
    case ended(EndReason)
    /// How long is left, in seconds.
    case warning(TimeInterval)
    case thermalWarning
}

/// What the keeper wants done. It does none of it itself.
enum Effect: Equatable {
    case raise
    case release(sleepNow: Bool)
    case notify(Notice)
}

/// The decision, and nothing else.
///
/// No IOKit, no shell, and nothing in here reads the clock. Every rule that
/// depends on the time takes
/// `now` as an argument, so it can be asked about a moment three hours from
/// now without waiting for it.
struct Keeper {
    private(set) var mode: Mode = .off
    private(set) var paused: PauseReason?
    private(set) var raised = false
    /// When the heat last came down to fair or better, or nil while it is
    /// above. A thermal pause lifts on a stretch of calm, not on one reading.
    private(set) var calmSince: Date?
    private(set) var warned = false
    private(set) var thermalWarned = false
    var settings: Settings

    init(settings: Settings = .defaults) {
        self.settings = settings
    }

    mutating func start(_ mode: Mode, inputs: Inputs) -> [Effect] {
        self.mode = mode
        paused = nil
        warned = false
        thermalWarned = false
        calmSince = nil
        // A session that starts into a guard should pause on the way in
        // rather than raise the flag and drop it a tick later, so a start is
        // a tick with a new mode on it.
        return tick(inputs: inputs)
    }

    mutating func stop(reason: EndReason, inputs: Inputs) -> [Effect] {
        var effects: [Effect] = []
        if raised {
            // You clicked Stop, so you are at the keyboard and the lid is
            // open; quitting could be anything, so that one follows the lid.
            effects.append(.release(sleepNow: reason == .quit ? inputs.lidClosed : false))
            raised = false
        }
        mode = .off
        paused = nil
        warned = false
        thermalWarned = false
        calmSince = nil
        return effects
    }

    mutating func tick(inputs: Inputs) -> [Effect] {
        var effects: [Effect] = []
        endIfOver(inputs, into: &effects)
        applyGuards(inputs, into: &effects)
        moveTheFlag(into: &effects)
        warnIfDue(inputs, into: &effects)
        return effects
    }

    // MARK: - The rules, in the order a tick applies them

    /// First: has the session run out on its own terms.
    private mutating func endIfOver(_ inputs: Inputs, into effects: inout [Effect]) {
        guard let reason = endReason(inputs) else { return }
        mode = .off
        paused = nil
        warned = false
        thermalWarned = false
        calmSince = nil
        if raised {
            effects.append(.release(sleepNow: inputs.lidClosed))
            raised = false
            effects.append(.notify(.ended(reason)))
        }
    }

    private func endReason(_ inputs: Inputs) -> EndReason? {
        switch mode {
        case .off:
            return nil
        case .timed(let until):
            return inputs.now >= until ? .timer : nil
        case .follow(let started):
            let running = inputs.now.timeIntervalSince(started)
            if running > settings.followCap { return .cap }
            guard running > settings.followGrace else { return nil }
            guard let last = inputs.lastAgentWrite else { return .agentsIdle }
            return inputs.now.timeIntervalSince(last) > settings.idleTimeout ? .agentsIdle : nil
        case .indefinite(let started):
            guard settings.indefiniteCap != 0 else { return nil }
            return inputs.now.timeIntervalSince(started) > settings.indefiniteCap ? .cap : nil
        }
    }

    /// Second: the guards, which only exist while a session is running.
    private mutating func applyGuards(_ inputs: Inputs, into effects: inout [Effect]) {
        guard mode.isActive else { return }
        trackCalm(inputs)

        if let current = paused {
            guard hasLifted(current, inputs) else { return }
            paused = nil
            effects.append(.notify(.resumed))
            return
        }

        guard let reason = pauseReason(inputs) else { return }
        paused = reason
        if raised {
            effects.append(.release(sleepNow: inputs.lidClosed))
            raised = false
        }
        effects.append(.notify(.paused(reason)))
    }

    /// The order matters only in what the notification says: charging first
    /// because it is a choice you made, then heat, then the battery floor.
    private func pauseReason(_ inputs: Inputs) -> PauseReason? {
        if settings.onlyWhileCharging && !inputs.power.onAC { return .charging }
        if inputs.thermal >= settings.thermalPauseLevel { return .thermal }
        if !inputs.power.onAC && inputs.power.percent < settings.batteryFloor { return .battery }
        return nil
    }

    /// A pause lifts on its own condition and no other, so a Mac that got hot
    /// while unplugged does not resume the moment the cable goes in.
    private func hasLifted(_ reason: PauseReason, _ inputs: Inputs) -> Bool {
        switch reason {
        case .charging:
            return inputs.power.onAC
        case .battery:
            return inputs.power.onAC || inputs.power.percent >= settings.batteryResume
        case .thermal:
            guard let calmSince else { return false }
            return inputs.now.timeIntervalSince(calmSince) >= settings.thermalCalm
        }
    }

    private mutating func trackCalm(_ inputs: Inputs) {
        if inputs.thermal <= .fair {
            if calmSince == nil { calmSince = inputs.now }
        } else {
            calmSince = nil
        }
    }

    /// Third: the flag follows from the two above and nothing else.
    private mutating func moveTheFlag(into effects: inout [Effect]) {
        let wanted = mode.isActive && paused == nil
        if wanted && !raised {
            effects.append(.raise)
            raised = true
        } else if !wanted && raised {
            effects.append(.release(sleepNow: false))
            raised = false
        }
    }

    /// Fourth: what is worth saying while nothing is changing.
    private mutating func warnIfDue(_ inputs: Inputs, into effects: inout [Effect]) {
        guard paused == nil else { return }
        if case .timed(let until) = mode, !warned {
            let left = until.timeIntervalSince(inputs.now)
            if left <= settings.warnBeforeEnd {
                warned = true
                effects.append(.notify(.warning(left)))
            }
        }
        // Serious heat under a critical pause level is the case where nothing
        // happens and the reason nothing happened is worth knowing.
        if mode.isActive,
           !thermalWarned,
           inputs.thermal == .serious,
           settings.thermalPauseLevel > .serious {
            thermalWarned = true
            effects.append(.notify(.thermalWarning))
        }
    }
}
