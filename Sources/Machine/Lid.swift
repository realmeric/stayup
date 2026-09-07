import Foundation
import IOKit

/// Whether the lid is closed.
///
/// `AppleClamshellState` on `IOPMrootDomain`, a boolean, true when closed. A
/// desktop Mac has no such property; missing reads as open, which is the
/// answer that keeps `sleepnow` from firing on a machine with no lid.
enum Lid {
    private static var warned = false

    static func isClosed() -> Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault,
                                                  IOServiceMatching("IOPMrootDomain"))
        guard service != 0 else {
            warnOnce("IOPMrootDomain did not match")
            return false
        }
        defer { IOObjectRelease(service) }
        guard let property = IORegistryEntryCreateCFProperty(service,
                                                             "AppleClamshellState" as CFString,
                                                             kCFAllocatorDefault,
                                                             0)?.takeRetainedValue() else {
            warnOnce("AppleClamshellState is not on IOPMrootDomain")
            return false
        }
        guard CFGetTypeID(property) == CFBooleanGetTypeID() else {
            warnOnce("AppleClamshellState is not a boolean")
            return false
        }
        // swiftlint:disable:next force_cast
        return CFBooleanGetValue((property as! CFBoolean))
    }

    private static func warnOnce(_ reason: String) {
        guard !warned else { return }
        warned = true
        Log.sources.error("lid unreadable: \(reason, privacy: .public); reading it as open")
    }
}
