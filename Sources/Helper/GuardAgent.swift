import Foundation

enum GuardAgentError: Error, Equatable {
    case resourceMissing(String)
    case launchctlRefused(String)
}

/// The LaunchAgent that runs `guard.sh` every 60 s.
///
/// No password anywhere in here: a user agent is the user's to load, which is
/// why this can go in behind the same click as the sudoers rule rather than
/// asking for a second one.
enum GuardAgent {
    static let label = "com.meric.stayup.guard"

    static var scriptURL: URL {
        Lease.directory.appendingPathComponent("guard.sh")
    }

    static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static var logURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/StayUp/guard.log")
    }

    static func install() throws {
        guard let source = Bundle.main.url(forResource: "guard.sh", withExtension: nil) else {
            throw GuardAgentError.resourceMissing("guard.sh")
        }
        let manager = FileManager.default
        try manager.createDirectory(at: Lease.directory, withIntermediateDirectories: true)
        try manager.createDirectory(at: logURL.deletingLastPathComponent(),
                                    withIntermediateDirectories: true)
        try manager.createDirectory(at: plistURL.deletingLastPathComponent(),
                                    withIntermediateDirectories: true)
        // A copy rather than the bundle's own file: the agent has to keep
        // running while the app is being rebuilt or replaced.
        if manager.fileExists(atPath: scriptURL.path) {
            try manager.removeItem(at: scriptURL)
        }
        try manager.copyItem(at: source, to: scriptURL)
        try manager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [scriptURL.path],
            "StartInterval": 60,
            "RunAtLoad": true,
            "StandardOutPath": logURL.path,
            "StandardErrorPath": logURL.path
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist,
                                                      format: .xml,
                                                      options: 0)
        try data.write(to: plistURL, options: .atomic)

        // `bootstrap` of a label already loaded fails, so `bootout` first and
        // ignore its own failure when there was nothing to remove.
        _ = try? Shell.run("/bin/launchctl", ["bootout", domain + "/" + label])
        let result = try Shell.run("/bin/launchctl", ["bootstrap", domain, plistURL.path])
        guard result.status == 0 else {
            throw GuardAgentError.launchctlRefused(
                result.err.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        Log.flag.info("guard agent loaded")
    }

    static func uninstall() throws {
        _ = try? Shell.run("/bin/launchctl", ["bootout", domain + "/" + label])
        try? FileManager.default.removeItem(at: plistURL)
        try? FileManager.default.removeItem(at: scriptURL)
        Log.flag.info("guard agent unloaded")
    }

    static func status() -> Bool {
        guard let result = try? Shell.run("/bin/launchctl", ["print", domain + "/" + label]) else {
            return false
        }
        return result.status == 0
    }

    private static var domain: String { "gui/\(getuid())" }
}
