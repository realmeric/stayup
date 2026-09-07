import XCTest
@testable import StayUp

/// The install script is the one piece of StayUp that runs as root, and the
/// one piece that cannot be exercised in a test: it would ask for a password
/// and change the machine. What can be checked without either is that it
/// parses, that the line it would write is a line sudo accepts, and that the
/// plist it installs is a plist launchd will take.
final class InstallScriptTests: XCTestCase {
    /// The test bundle is hosted by the app, so `Bundle.main` is the app and
    /// this is the same lookup `HelperInstaller` makes. A resource that moved
    /// out of the bundle fails here rather than at the password prompt.
    private func resource(_ name: String) throws -> URL {
        try XCTUnwrap(Bundle.main.url(forResource: name, withExtension: nil),
                      "\(name) is not in the app bundle")
    }

    func testTheScriptParses() throws {
        let script = try resource("install-helper.sh")
        let result = try Shell.run("/bin/sh", ["-n", script.path])
        XCTAssertEqual(result.status, 0, result.err)
    }

    /// The rule itself, checked the way the script checks it before putting it
    /// anywhere near `/etc/sudoers.d`. A syntax error there can lock every
    /// `sudo` on the machine; `visudo -cf` on a file you own needs no root.
    ///
    /// The user is a uid, because a short name is free-form text: on an
    /// SSO-enrolled Mac it can be an email address, and it would have to be
    /// sanitized against sudoers and the shell both. Digits read the same to
    /// everything.
    func testTheRuleItWouldWriteParses() throws {
        let candidate = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("stayup-rule-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: candidate) }
        let line = "#501 ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0\n"
        try Data(line.utf8).write(to: candidate)
        let result = try Shell.run("/usr/sbin/visudo", ["-cf", candidate.path])
        XCTAssertEqual(result.status, 0, result.out + result.err)
    }

    /// And the line the script actually holds is the line that was checked.
    func testTheScriptWritesThatRule() throws {
        let script = try resource("install-helper.sh")
        let text = try String(contentsOf: script, encoding: .utf8)
        XCTAssertTrue(
            text.contains("#$uid ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0"),
            "the rule in the script is not the rule this test checked")
    }

    /// Two levels of quoting meet in the admin command: AppleScript's, which
    /// this string is written in, and the shell's, which `do shell script`
    /// hands the string to. The proof is that the script sees exactly the
    /// arguments it was given, so this runs the same string through osascript
    /// with an echo in place of the installer and no administrator privileges.
    func testTheAdminCommandPassesItsArgumentsThrough() throws {
        let echo = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("stayup echo \(UUID().uuidString).sh")
        defer { try? FileManager.default.removeItem(at: echo) }
        try Data("for a in \"$@\"; do echo \"[$a]\"; done\n".utf8).write(to: echo)

        let command = HelperInstaller.command(script: echo.path,
                                              arguments: ["remove"],
                                              user: "501")
        XCTAssertTrue(command.hasSuffix("with administrator privileges"))
        // The one word this test must not run under.
        let rehearsal = command.replacingOccurrences(of: " with administrator privileges",
                                                     with: "")
        let result = try Shell.run("/usr/bin/osascript", ["-e", rehearsal])
        XCTAssertEqual(result.status, 0, result.err)
        // `$@` is what follows the script path, and the script ran at all
        // from a path with a space in it, which is the thing being proved.
        XCTAssertEqual(result.out.trimmingCharacters(in: .whitespacesAndNewlines),
                       "[501]\r[remove]")
    }

    func testThePlistIsAPlist() throws {
        let plist = try resource("com.meric.stayup.reset.plist")
        let result = try Shell.run("/usr/bin/plutil", ["-lint", plist.path])
        XCTAssertEqual(result.status, 0, result.out + result.err)

        let data = try Data(contentsOf: plist)
        let parsed = try PropertyListSerialization
            .propertyList(from: data, format: nil) as? [String: Any]
        XCTAssertEqual(parsed?["Label"] as? String, "com.meric.stayup.reset")
        XCTAssertEqual(parsed?["ProgramArguments"] as? [String],
                       ["/usr/bin/pmset", "-a", "disablesleep", "0"])
        XCTAssertEqual(parsed?["RunAtLoad"] as? Bool, true)
    }
}
