import Foundation
import IOKit.ps

struct PowerReading: Equatable {
    var onAC: Bool
    var percent: Int
}

/// The cable and the battery.
///
/// IOKit.ps rather than `pmset -g batt`, because it is a dictionary rather
/// than a sentence and it can be told to notify. The parser stays as a
/// fallback for the day the dictionary comes back empty, and because it is the
/// only half of this that a test can hold still.
enum Power {
    static func read() -> PowerReading {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return fallback()
        }
        let type = IOPSGetProvidingPowerSourceType(blob)?.takeUnretainedValue() as String?
        let onAC = type == kIOPSACPowerValue
        guard let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef],
              let first = sources.first,
              let description = IOPSGetPowerSourceDescription(blob, first)?
                  .takeUnretainedValue() as? [String: Any],
              let current = description[kIOPSCurrentCapacityKey] as? Int else {
            // No battery at all: a Mac on a desk is always on the cable and
            // always full, and both guards should read as satisfied.
            return PowerReading(onAC: onAC || type == nil, percent: 100)
        }
        let maximum = description[kIOPSMaxCapacityKey] as? Int ?? 100
        let percent = maximum == 100 ? current : Int((Double(current) / Double(maximum)) * 100)
        return PowerReading(onAC: onAC, percent: percent)
    }

    private static func fallback() -> PowerReading {
        guard let result = try? Shell.run("/usr/bin/pmset", ["-g", "batt"]) else {
            Log.sources.error("neither IOKit.ps nor pmset answered; reading AC at 100%")
            return PowerReading(onAC: true, percent: 100)
        }
        return parse(pmsetBatt: result.out)
    }

    /// `pmset -g batt` reads:
    ///
    ///     Now drawing from 'Battery Power'
    ///      -InternalBattery-0 (id=22806627)	76%; discharging; 13:26 remaining present: true
    static func parse(pmsetBatt text: String) -> PowerReading {
        var onAC = true
        var percent = 100
        for line in text.split(separator: "\n") {
            if line.contains("'Battery Power'") { onAC = false }
            if line.contains("'AC Power'") { onAC = true }
            guard let token = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
                .first(where: { $0.hasSuffix("%;") || $0.hasSuffix("%") }),
                  let value = Int(token.prefix(while: \.isNumber)) else { continue }
            percent = value
        }
        return PowerReading(onAC: onAC, percent: percent)
    }
}
