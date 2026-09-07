import Foundation

enum FlagError: Error, Equatable {
    /// `sudo -n` came back without doing it. The message is sudo's own; when
    /// the rule is missing it reads `sudo: a password is required`.
    case refused(String)
}

protocol FlagWriting {
    func raise() throws
    func release() throws
}

/// The only place in the app that says `pmset`.
///
/// `-n` is what makes this safe to call from a GUI app: with the rule in place
/// it runs, without one it fails in a millisecond rather than hanging on a
/// password prompt that has no terminal to appear in.
struct SudoFlagWriter: FlagWriting {
    func raise() throws { try write("1") }
    func release() throws { try write("0") }

    private func write(_ value: String) throws {
        let result = try Shell.run("/usr/bin/sudo",
                                   ["-n", "/usr/bin/pmset", "-a", "disablesleep", value])
        guard result.status == 0 else {
            throw FlagError.refused(result.err.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        Log.flag.info("flag \(value == "1" ? "raised" : "released", privacy: .public)")
    }
}

/// What runs under `STAYUP_DRY_RUN`, so the whole machine can be exercised
/// without touching the real flag.
struct DryRunFlagWriter: FlagWriting {
    func raise() { Log.flag.info("dry run: would raise") }
    func release() { Log.flag.info("dry run: would release") }
}

/// What the tests hold. `raised` records the order, so a test can say the flag
/// went up once and came down once rather than only that it ended down.
final class FakeFlagWriter: FlagWriting {
    private(set) var raised: [Bool] = []
    var failure: FlagError?

    func raise() throws {
        if let failure { throw failure }
        raised.append(true)
    }

    func release() throws {
        if let failure { throw failure }
        raised.append(false)
    }
}
