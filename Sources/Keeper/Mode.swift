import Foundation

/// What the app was asked to do, and the one fact each answer needs.
enum Mode: Equatable, Codable {
    case off
    /// Awake until a wall clock time.
    case timed(until: Date)
    /// Awake until the transcripts stop growing, counted from here.
    case follow(started: Date)
    /// Awake until the cap, or until somebody says stop.
    case indefinite(started: Date)

    var isActive: Bool {
        self != .off
    }
}
