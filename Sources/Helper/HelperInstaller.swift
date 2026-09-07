import Foundation

enum HelperStatus: Equatable {
    case installed
    case missing
}

enum HelperError: Error, Equatable {
    /// The admin dialog was dismissed. Not a failure: the answer was no.
    case cancelled
    case failed(String)
    case resourceMissing(String)
}

/// The one password, asked once.
///
/// Everything privileged StayUp will ever do is decided here: a sudoers rule
/// naming exactly two commands, and a LaunchDaemon that takes the flag down at
/// boot. After this the app runs `sudo -n` and never prompts again.
enum HelperInstaller {
    static func status() -> HelperStatus {
        // `sudo -n -l <command>` asks the question without running anything:
        // exit 0 and the command echoed back when a rule allows it, exit 1
        // otherwise, and either way in a millisecond with no prompt.
        guard let result = try? Shell.run("/usr/bin/sudo",
                                          ["-n", "-l", "/usr/bin/pmset", "-a", "disablesleep", "1"])
        else { return .missing }
        return result.status == 0 ? .installed : .missing
    }

    static func install() throws {
        try runScript(arguments: [])
    }

    static func uninstall() throws {
        try runScript(arguments: ["remove"])
    }

    private static func runScript(arguments: [String]) throws {
        let staged = try stageResources()
        defer { try? FileManager.default.removeItem(at: staged) }
        let script = staged.appendingPathComponent("install-helper.sh").path
        let result = try Shell.run("/usr/bin/osascript",
                                   ["-e", command(script: script, arguments: arguments)])
        guard result.status == 0 else {
            let message = result.err.trimmingCharacters(in: .whitespacesAndNewlines)
            if message.contains("User canceled") || message.contains("-128") {
                throw HelperError.cancelled
            }
            throw HelperError.failed(message)
        }
        Log.flag.info("helper script said: \(result.out.trimmingCharacters(in: .whitespacesAndNewlines), privacy: .public)")
    }

    /// `do shell script ... with administrator privileges` is the standard
    /// prompt: it names the calling app, and the script runs as root with a
    /// minimal environment, which is why every path inside the script is
    /// absolute. Two levels of quoting meet here, AppleScript's and the
    /// shell's, which is why this is a function with a test rather than a
    /// string built at the call site.
    static func command(script: String, arguments: [String], user: String = NSUserName()) -> String {
        let inner = ([script, user] + arguments)
            .map { "\\\"\($0)\\\"" }
            .joined(separator: " ")
        return "do shell script \"/bin/sh \(inner)\" with administrator privileges"
    }

    /// The script and the plist beside each other in a directory root can
    /// read: the app bundle is fine to run from, but the script copies the
    /// plist from its own directory and a temp copy keeps that one line true.
    private static func stageResources() throws -> URL {
        let staged = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("stayup-install-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: staged, withIntermediateDirectories: true)
        for name in ["install-helper.sh", "com.meric.stayup.reset.plist"] {
            guard let source = Bundle.main.url(forResource: name, withExtension: nil) else {
                throw HelperError.resourceMissing(name)
            }
            let destination = staged.appendingPathComponent(name)
            try FileManager.default.copyItem(at: source, to: destination)
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o755],
                                              ofItemAtPath: staged.appendingPathComponent("install-helper.sh").path)
        return staged
    }
}
