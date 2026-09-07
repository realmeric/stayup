import XCTest
@testable import StayUp

final class FlagWriterTests: XCTestCase {
    private var asked: [(String, [String])] = []

    override func setUp() {
        super.setUp()
        asked = []
    }

    override func tearDown() {
        Shell.runner = nil
        super.tearDown()
    }

    /// The exact command line, spelled out. This is the one call in the app
    /// that a sudoers rule matches argument for argument, so a change here
    /// that looks harmless is a change that stops working silently.
    func testRaiseAsksSudoForExactlyOneThing() throws {
        Shell.runner = { path, args in
            self.asked.append((path, args))
            return (0, "", "")
        }
        try SudoFlagWriter().raise()
        XCTAssertEqual(asked.count, 1)
        XCTAssertEqual(asked.first?.0, "/usr/bin/sudo")
        XCTAssertEqual(asked.first?.1, ["-n", "/usr/bin/pmset", "-a", "disablesleep", "1"])
    }

    func testReleaseAsksForTheZero() throws {
        Shell.runner = { path, args in
            self.asked.append((path, args))
            return (0, "", "")
        }
        try SudoFlagWriter().release()
        XCTAssertEqual(asked.first?.1, ["-n", "/usr/bin/pmset", "-a", "disablesleep", "0"])
    }

    /// Without the rule, `sudo -n` exits 1 with this on stderr. It has to
    /// throw rather than be read as done, or the app would believe the flag
    /// was up and stop watching.
    func testRefusalThrowsWithSudosOwnWords() {
        Shell.runner = { _, _ in (1, "", "sudo: a password is required\n") }
        XCTAssertThrowsError(try SudoFlagWriter().raise()) { error in
            XCTAssertEqual(error as? FlagError, .refused("sudo: a password is required"))
        }
    }

    func testTheFakeRecordsTheOrder() throws {
        let writer = FakeFlagWriter()
        try writer.raise()
        try writer.release()
        try writer.raise()
        XCTAssertEqual(writer.raised, [true, false, true])
    }

    /// The dry run writer is what `STAYUP_DRY_RUN` picks, and its whole job is
    /// to touch nothing.
    func testTheDryRunWriterRunsNothing() throws {
        Shell.runner = { path, args in
            self.asked.append((path, args))
            return (0, "", "")
        }
        try DryRunFlagWriter().raise()
        try DryRunFlagWriter().release()
        XCTAssertTrue(asked.isEmpty)
    }
}

/// The probe. It is the real call rather than a question about it, because
/// `sudo -l` lists a rule on Macs where the call itself still prompts, and on
/// an admin account the blanket `(ALL) ALL` answers the question too.
final class HelperProbeTests: XCTestCase {
    private var asked: [[String]] = []

    override func setUp() {
        super.setUp()
        asked = []
        Shell.runner = { path, args in
            self.asked.append([path] + args)
            return (0, "", "")
        }
    }

    override func tearDown() {
        Shell.runner = nil
        super.tearDown()
    }

    /// The value carried is the one the app wants right now, not the one it
    /// read. Anything else could put a stale 1 back over a clear the guard
    /// had just made.
    func testItProbesWithTheValueTheAppWants() {
        XCTAssertEqual(HelperInstaller.status(wanting: true), .installed)
        XCTAssertEqual(asked, [["/usr/bin/sudo", "-n", "/usr/bin/pmset", "-a", "disablesleep", "1"]])
    }

    func testProbingWhileOffRepeatsTheZero() {
        XCTAssertEqual(HelperInstaller.status(wanting: false), .installed)
        XCTAssertEqual(asked, [["/usr/bin/sudo", "-n", "/usr/bin/pmset", "-a", "disablesleep", "0"]])
    }

    func testARefusalReadsAsMissing() {
        Shell.runner = { _, _ in (1, "", "sudo: a password is required\n") }
        XCTAssertEqual(HelperInstaller.status(wanting: false), .missing)
    }
}
