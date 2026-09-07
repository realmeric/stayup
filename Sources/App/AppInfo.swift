import Foundation

/// What the bundle says about itself.
///
/// Read through here rather than from `Bundle.main` at the call site, because
/// under the test bundle the host app's identifiers are the ones that answer
/// and a fallback keeps the log subsystem stable either way.
enum AppInfo {
    static var bundleID: String {
        Bundle.main.bundleIdentifier ?? "com.meric.stayup"
    }

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /// Where the app is running from. A login item only registers for an app
    /// under /Applications; from a build directory `SMAppService` reports
    /// success and nothing ever launches.
    static var isInApplications: Bool {
        Bundle.main.bundleURL.path.hasPrefix("/Applications/")
    }

    static var name: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "StayUp"
    }
}
