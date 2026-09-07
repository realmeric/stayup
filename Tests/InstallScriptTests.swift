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

    /// The install, rehearsed.
    ///
    /// The real script writes to `/etc/sudoers.d` and loads a LaunchDaemon, so
    /// it can only ever be run once, by hand, behind a password. This runs the
    /// same script with its four root-owned destinations pointed at a temp
    /// directory and `launchctl` and `pmset` replaced by scripts that write
    /// down what they were asked, which leaves the order of the steps, the
    /// rule it writes and the plist it installs all provable.
    func testTheInstallDoesWhatItSaysItDoes() throws {
        let room = try rehearsalRoom()
        let said = try rehearse(in: room, arguments: ["501"])

        let rule = try String(contentsOf: room.appendingPathComponent("etc/sudoers.d/stayup"),
                              encoding: .utf8)
        XCTAssertTrue(rule.hasPrefix("#501 ALL=(root) NOPASSWD:"), rule)
        XCTAssertTrue(rule.contains("disablesleep 1"), rule)
        XCTAssertTrue(rule.contains("disablesleep 0"), rule)

        let daemon = room.appendingPathComponent("Library/LaunchDaemons/com.meric.stayup.reset.plist")
        XCTAssertTrue(FileManager.default.fileExists(atPath: daemon.path))
        let parsed = try PropertyListSerialization
            .propertyList(from: try Data(contentsOf: daemon), format: nil) as? [String: Any]
        XCTAssertEqual(parsed?["Label"] as? String, "com.meric.stayup.reset")

        // Bootout first, ignoring its failure, because bootstrap of a label
        // already loaded fails. Then the flag down, because the moment the
        // rule exists is a good moment for it to be known down.
        XCTAssertEqual(try calls(in: room), [
            "launchctl bootout system/com.meric.stayup.reset",
            "launchctl bootstrap system \(daemon.path)",
            "pmset -a disablesleep 0"
        ])
        XCTAssertTrue(said.contains("flag down"), said)
    }

    /// And the way back out leaves nothing behind.
    func testTheRemoveTakesEverythingAway() throws {
        let room = try rehearsalRoom()
        _ = try rehearse(in: room, arguments: ["501"])
        try FileManager.default.removeItem(at: room.appendingPathComponent("calls"))
        _ = try rehearse(in: room, arguments: ["501", "remove"])

        XCTAssertFalse(FileManager.default.fileExists(
            atPath: room.appendingPathComponent("etc/sudoers.d/stayup").path))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: room.appendingPathComponent("Library/LaunchDaemons/com.meric.stayup.reset.plist").path))
        XCTAssertEqual(try calls(in: room), [
            "launchctl bootout system/com.meric.stayup.reset",
            "pmset -a disablesleep 0"
        ])
    }

    /// The user is named by uid, and only digits make a uid.
    ///
    /// `#501` is sudoers' own user-ID spec, but `#` followed by anything else
    /// is a comment - and `visudo -cf` accepts a comment. A rule built from a
    /// bad argument would install, parse, grant nothing, and leave the app
    /// saying it was set up, so the script refuses before it writes anything.
    func testANonNumericUserInstallsNothing() throws {
        for bad in ["alice", "name@company.com", "501x", ""] {
            let room = try rehearsalRoom()
            let result = try run(in: room, arguments: [bad])
            XCTAssertNotEqual(result.status, 0, bad)
            // No argument at all is caught a line earlier, by the shell, with
            // the usage message rather than this one.
            if !bad.isEmpty {
                XCTAssertTrue(result.err.contains("nothing was installed"), result.err)
            }
            XCTAssertFalse(FileManager.default.fileExists(
                atPath: room.appendingPathComponent("etc/sudoers.d/stayup").path), bad)
        }
    }

    /// And the app hands it a uid, not a name.
    func testTheAppNamesTheUserByNumber() {
        let command = HelperInstaller.command(script: "/tmp/x.sh", arguments: [])
        XCTAssertTrue(command.contains("\\\"\(getuid())\\\""), command)
    }

    // MARK: - The rehearsal

    private func rehearsalRoom() throws -> URL {
        let room = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("install-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: room) }
        for path in ["etc/sudoers.d", "Library/LaunchDaemons", "bin"] {
            try FileManager.default.createDirectory(at: room.appendingPathComponent(path),
                                                    withIntermediateDirectories: true)
        }
        for tool in ["launchctl", "pmset"] {
            let url = room.appendingPathComponent("bin/\(tool)")
            try Data("#!/bin/sh\necho \"\(tool) $*\" >> \"\(room.path)/calls\"\n".utf8)
                .write(to: url)
            try FileManager.default.setAttributes([.posixPermissions: 0o755],
                                                  ofItemAtPath: url.path)
        }
        // The plist has to sit beside the script, which is what the real
        // install does when it stages both into a temp directory.
        try FileManager.default.copyItem(
            at: try resource("com.meric.stayup.reset.plist"),
            to: room.appendingPathComponent("com.meric.stayup.reset.plist"))

        var text = try String(contentsOf: try resource("install-helper.sh"), encoding: .utf8)
        text = text
            .replacingOccurrences(of: "rule=/etc/sudoers.d/stayup",
                                  with: "rule=\(room.path)/etc/sudoers.d/stayup")
            .replacingOccurrences(of: "daemon=/Library/LaunchDaemons",
                                  with: "daemon=\(room.path)/Library/LaunchDaemons")
            // Neither of these can run without root, and neither is what is
            // being checked here.
            .replacingOccurrences(of: "/usr/bin/install -o root -g wheel -m 0440",
                                  with: "/usr/bin/install -m 0644")
            .replacingOccurrences(of: "/usr/sbin/chown root:wheel", with: "/usr/bin/true")
            .replacingOccurrences(of: "/bin/launchctl", with: "\(room.path)/bin/launchctl")
            .replacingOccurrences(of: "/usr/bin/pmset", with: "\(room.path)/bin/pmset")
        try Data(text.utf8).write(to: room.appendingPathComponent("install-helper.sh"))
        return room
    }

    private func run(in room: URL, arguments: [String]) throws
        -> (status: Int32, out: String, err: String) {
        try Shell.run("/bin/sh", [room.appendingPathComponent("install-helper.sh").path] + arguments)
    }

    private func rehearse(in room: URL, arguments: [String]) throws -> String {
        let result = try run(in: room, arguments: arguments)
        XCTAssertEqual(result.status, 0, result.err)
        return result.out
    }

    private func calls(in room: URL) throws -> [String] {
        try String(contentsOf: room.appendingPathComponent("calls"), encoding: .utf8)
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
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

/// The release script never runs in a test - it builds, signs and can write to
/// /Applications. What is checked is that it parses, and that the two things
/// it refuses to ship without are still the things it looks for.
final class ReleaseScriptTests: XCTestCase {
    private func script() throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("scripts/release.sh")
        return try String(contentsOf: url, encoding: .utf8)
    }

    func testItParses() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("scripts/release.sh")
        let result = try Shell.run("/bin/zsh", ["-n", url.path])
        XCTAssertEqual(result.status, 0, result.err)
    }

    /// An app without `LSUIElement` takes a Dock tile, which for a menu bar
    /// app is the difference between shipped and half-shipped.
    func testItRefusesAnAppThatWouldAppearOnTheDock() throws {
        XCTAssertTrue(try script().contains("LSUIElement"))
    }

    /// And one without its resources cannot set itself up at all.
    func testItRefusesAnAppMissingItsResources() throws {
        let text = try script()
        for resource in ["install-helper.sh", "guard.sh", "com.meric.stayup.reset.plist"] {
            XCTAssertTrue(text.contains(resource), resource)
        }
    }

    /// The build stays out of the repository on purpose; a synced bundle
    /// cannot be signed.
    func testItBuildsOutsideTheRepository() throws {
        XCTAssertTrue(try script().contains("$HOME/Library/Caches/StayUp/build"))
    }
}
