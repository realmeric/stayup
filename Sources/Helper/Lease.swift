import Foundation

/// A claim with a deadline.
///
/// While the flag is up, the app writes an expiry two minutes ahead and
/// rewrites it on every 20 s tick. Anyone who finds the file in the past knows
/// the app stopped renewing, whatever the reason, and is entitled to clear the
/// flag. The guard agent is that anyone.
enum Lease {
    static let directory: URL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/StayUp", isDirectory: true)

    static func url(base: URL = directory) -> URL {
        base.appendingPathComponent("lease")
    }

    /// ISO-8601 UTC to the second. Fractional seconds are off because
    /// `guard.sh` parses this with `date -j -f "%Y-%m-%dT%H:%M:%SZ"`, which
    /// has no way to skip them.
    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    static func renew(until: Date, base: URL = directory) {
        do {
            try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
            let text = formatter.string(from: until) + "\n"
            try Data(text.utf8).write(to: url(base: base), options: .atomic)
        } catch {
            Log.flag.error("the lease would not write: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func clear(base: URL = directory) {
        do {
            try FileManager.default.removeItem(at: url(base: base))
        } catch CocoaError.fileNoSuchFile {
            // Already gone is the state we wanted.
        } catch {
            Log.flag.error("the lease would not clear: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func read(base: URL = directory) -> Date? {
        guard let data = try? Data(contentsOf: url(base: base)) else { return nil }
        let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return formatter.date(from: text)
    }
}
