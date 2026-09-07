import OSLog

/// The app has no window, so the log is the only place it can talk.
///
///     /usr/bin/log stream --predicate 'subsystem == "com.meric.stayup"' --level debug
///
/// `/usr/bin/log` spelled out, because zsh has a builtin called `log`.
enum Log {
    static let app = Logger(subsystem: AppInfo.bundleID, category: "app")
    static let flag = Logger(subsystem: AppInfo.bundleID, category: "flag")
    static let keeper = Logger(subsystem: AppInfo.bundleID, category: "keeper")
    static let sources = Logger(subsystem: AppInfo.bundleID, category: "sources")
    static let menu = Logger(subsystem: AppInfo.bundleID, category: "menu")
}
