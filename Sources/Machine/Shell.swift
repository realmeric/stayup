import Foundation

/// Every subprocess the app runs goes through here.
///
/// One function so there is one place to look when something ran that should
/// not have, and one place for a test to stand in front of: `runner` replaces
/// the real `Process` for the length of a test, and `tearDown` puts it back.
enum Shell {
    struct Result {
        let status: Int32
        let out: String
        let err: String
    }

    /// Set by tests to record what would have run. Nil in the app.
    static var runner: ((String, [String]) throws -> (Int32, String, String))?

    @discardableResult
    static func run(_ path: String, _ args: [String]) throws -> (status: Int32, out: String, err: String) {
        if let runner {
            return try runner(path, args)
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error
        try process.run()
        // Read before waiting: a child that fills a 64 KB pipe while nobody is
        // draining it blocks forever, and `waitUntilExit` would wait with it.
        let outData = output.fileHandleForReading.readDataToEndOfFile()
        let errData = error.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus,
                String(decoding: outData, as: UTF8.self),
                String(decoding: errData, as: UTF8.self))
    }
}
