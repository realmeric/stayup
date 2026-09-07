import XCTest
@testable import StayUp

/// The guard runs as a launchd job with almost no environment, so every path
/// in it is absolute and `PATH` cannot be used to stand fakes in front of
/// anything. These tests rewrite the two `/usr/bin` paths in a copy of the
/// script instead, and point `HOME` at a temp directory, which is enough to
/// run the real script against a fake `pmset` and a fake `sudo`.
final class GuardScriptTests: XCTestCase {
    private var room: URL!
    private var script: URL!
    private var receipt: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        room = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("guard-\(UUID().uuidString)", isDirectory: true)
        let bin = room.appendingPathComponent("bin", isDirectory: true)
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        receipt = room.appendingPathComponent("sudo-was-asked")

        try write(bin.appendingPathComponent("pmset"),
                  "#!/bin/sh\nprintf ' SleepDisabled\\t\\t1\\n'\n")
        try write(bin.appendingPathComponent("sudo"),
                  "#!/bin/sh\necho \"$@\" >> \"\(receipt.path)\"\n")

        let source = try XCTUnwrap(Bundle.main.url(forResource: "guard.sh", withExtension: nil))
        let text = try String(contentsOf: source, encoding: .utf8)
            .replacingOccurrences(of: "pmset=/usr/bin/pmset",
                                  with: "pmset=\(bin.path)/pmset")
            .replacingOccurrences(of: "sudo=/usr/bin/sudo",
                                  with: "sudo=\(bin.path)/sudo")
        script = room.appendingPathComponent("guard.sh")
        try write(script, text)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: room)
        super.tearDown()
    }

    private func write(_ url: URL, _ text: String) throws {
        try Data(text.utf8).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }

    private func writeLease(_ date: Date) throws {
        let directory = room.appendingPathComponent("Library/Application Support/StayUp",
                                                    isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        Lease.renew(until: date, base: directory)
    }

    /// `env -i` on purpose: the guard has to work with the environment launchd
    /// actually gives it, which is next to nothing.
    @discardableResult
    private func runGuard() throws -> String {
        let result = try Shell.run("/usr/bin/env",
                                   ["-i", "HOME=\(room.path)", "/bin/sh", script.path])
        XCTAssertEqual(result.status, 0, result.err)
        return result.out
    }

    private var whatSudoWasAsked: String {
        (try? String(contentsOf: receipt, encoding: .utf8)) ?? ""
    }

    func testTheScriptParses() throws {
        let source = try XCTUnwrap(Bundle.main.url(forResource: "guard.sh", withExtension: nil))
        let result = try Shell.run("/bin/sh", ["-n", source.path])
        XCTAssertEqual(result.status, 0, result.err)
    }

    /// The flag is up and nobody is claiming it. This is the force-quit case.
    func testAMissingLeaseClearsTheFlag() throws {
        let said = try runGuard()
        XCTAssertTrue(whatSudoWasAsked.contains("-n \(room.path)/bin/pmset -a disablesleep 0"),
                      whatSudoWasAsked)
        XCTAssertTrue(said.contains("flag cleared, lease missing"), said)
    }

    /// A live session. The guard's job here is to do nothing at all.
    func testALeaseInTheFutureIsLeftAlone() throws {
        try writeLease(Date().addingTimeInterval(3600))
        let said = try runGuard()
        XCTAssertEqual(whatSudoWasAsked, "")
        XCTAssertEqual(said, "")
    }

    /// The app stopped renewing an hour ago. This is the crash and the hang.
    func testAnExpiredLeaseClearsTheFlag() throws {
        try writeLease(Date().addingTimeInterval(-3600))
        let said = try runGuard()
        XCTAssertTrue(whatSudoWasAsked.contains("-a disablesleep 0"), whatSudoWasAsked)
        XCTAssertTrue(said.contains("flag cleared, lease expired at"), said)
    }

    /// A lease nobody can parse is not a lease.
    func testAnUnreadableLeaseClearsTheFlag() throws {
        let directory = room.appendingPathComponent("Library/Application Support/StayUp",
                                                    isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not a date\n".utf8).write(to: directory.appendingPathComponent("lease"))
        try runGuard()
        XCTAssertTrue(whatSudoWasAsked.contains("-a disablesleep 0"), whatSudoWasAsked)
    }

    /// The flag is already down, so there is nothing to clear whatever the
    /// lease says. The guard must not reach for sudo on every one of its 1440
    /// runs a day.
    func testADownFlagAsksNothing() throws {
        try write(room.appendingPathComponent("bin/pmset"),
                  "#!/bin/sh\nprintf ' SleepDisabled\\t\\t0\\n'\n")
        try runGuard()
        XCTAssertEqual(whatSudoWasAsked, "")
    }

    /// And a Mac where the flag was never set prints no such line at all.
    func testAnAbsentFlagLineAsksNothing() throws {
        try write(room.appendingPathComponent("bin/pmset"),
                  "#!/bin/sh\necho 'Currently in use:'\n")
        try runGuard()
        XCTAssertEqual(whatSudoWasAsked, "")
    }
}
