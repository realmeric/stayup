import Foundation

protocol AgentSource: AnyObject {
    var onChange: (() -> Void)? { get set }
    /// When an agent last wrote anything, or nil if none of them ever has.
    func read() -> Date?
}

/// Whether an agent is working, read from the only signal there is.
///
/// Claude Code's transcripts carry no status field, so busy is a file
/// growing: the newest modification date under the watched directories is the
/// last moment an agent did something. Three hundred files is a `stat` each
/// and a few milliseconds in all, which is why this is done on every tick
/// rather than cached.
final class AgentActivity: AgentSource {
    var onChange: (() -> Void)?
    var directories: [String]

    init(directories: [String] = Settings.defaults.watchedDirectories) {
        self.directories = directories
    }

    func read() -> Date? {
        if let faked = FakeEnvironment.agentWrite(now: Date()) { return faked }
        let began = Date()
        var newest: Date?
        var counted = 0
        for path in directories {
            let root = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            // A directory that is not there is a tool that is not installed,
            // which is not a problem worth a line in the log every 20 s.
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else { continue }
            guard let walk = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]) else { continue }
            for case let file as URL in walk where file.pathExtension == "jsonl" {
                counted += 1
                guard let written = try? file.resourceValues(forKeys: [.contentModificationDateKey])
                    .contentModificationDate else { continue }
                if newest == nil || written > newest! { newest = written }
            }
        }
        let elapsed = Date().timeIntervalSince(began)
        Log.sources.debug("agent activity: \(counted) transcripts in \(Int(elapsed * 1000)) ms")
        return newest
    }
}
