import Foundation

/// The `SleepDisabled` flag, read.
///
/// `pmset -g` prints it as a line of its own above the settings block: a
/// leading space, the word, two tabs, the digit. On a Mac where the flag has
/// never been set the line is absent, and absent means 0. Splitting on
/// whitespace and taking the first two tokens survives all three shapes.
enum SleepFlag {
    static func read() -> Bool {
        guard let result = try? Shell.run("/usr/bin/pmset", ["-g"]) else {
            Log.flag.error("pmset -g would not run; reading the flag as down")
            return false
        }
        return parse(result.out)
    }

    static func parse(_ text: String) -> Bool {
        for line in text.split(separator: "\n") {
            let tokens = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard tokens.count >= 2, tokens[0] == "SleepDisabled" else { continue }
            return tokens[1] == "1"
        }
        return false
    }
}
