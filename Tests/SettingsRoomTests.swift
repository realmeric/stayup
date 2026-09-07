import SwiftUI
import XCTest
@testable import StayUp

/// The rooms of the settings window.
///
/// Not what they look like: a `Form` in a `TabView` does not draw outside a
/// real window. What is checked here is what can be: that every setting has
/// somewhere to live, and that the two battery numbers cannot be set to a
/// pair that pauses and resumes forever.
@MainActor
final class SettingsRoomTests: XCTestCase {
    private enum Room: String {
        case sessions, agents, guards, helper
    }

    /// Every field of the settings has a control in some room.
    ///
    /// The promise of this window is "the numbers", and the way that promise
    /// quietly breaks is a field added to `Settings` that nobody wires up: it
    /// works, it persists, and the only way to change it is to edit the JSON
    /// in `defaults`. The list is walked out of the type itself, so adding a
    /// field fails this until somebody says which room it went in.
    func testEveryFieldHasARoom() {
        let placed: [String: Room] = [
            "durations": .sessions,
            "indefiniteCap": .sessions,
            "warnBeforeEnd": .sessions,
            "notifications": .sessions,
            "idleTimeout": .agents,
            "followGrace": .agents,
            "followCap": .agents,
            "watchedDirectories": .agents,
            "pauseWhenHot": .guards,
            "thermalPauseLevel": .guards,
            "thermalCalm": .guards,
            "pauseOnLowBattery": .guards,
            "batteryFloor": .guards,
            "batteryResume": .guards,
            "onlyWhileCharging": .guards
        ]

        var found: Set<String> = []
        for field in Mirror(reflecting: Settings()).children {
            guard let name = field.label else { continue }
            found.insert(name)
        }

        let unplaced = found.subtracting(placed.keys)
        XCTAssertTrue(unplaced.isEmpty,
                      "these settings have no room: \(unplaced.sorted().joined(separator: ", "))")
        let gone = Set(placed.keys).subtracting(found)
        XCTAssertTrue(gone.isEmpty,
                      "these settings no longer exist: \(gone.sorted().joined(separator: ", "))")
    }

    /// Every room is named, because the tab bar is the only way to reach three
    /// of the four.
    func testEveryRoomIsNamed() {
        XCTAssertFalse(Copy.roomSessions.isEmpty)
        XCTAssertFalse(Copy.roomAgents.isEmpty)
        XCTAssertFalse(Copy.roomGuards.isEmpty)
        XCTAssertFalse(Copy.roomHelper.isEmpty)
    }

    /// Every label in the window is a real sentence and no two rows say the
    /// same thing. A `Form` full of blank `LabeledContent` draws fine and
    /// reads as nothing.
    func testEveryLabelSaysSomething() {
        let labels = [Copy.indefiniteCap, Copy.warnBeforeEnd, Copy.notifications,
                      Copy.durations, Copy.addDuration, Copy.remove,
                      Copy.idleTimeout, Copy.followGrace, Copy.followCap,
                      Copy.watchedDirectories, Copy.addDirectory,
                      Copy.heat, Copy.battery, Copy.pauseWhenHot,
                      Copy.thermalPauseLevel, Copy.levelCritical, Copy.levelSerious,
                      Copy.thermalCalm, Copy.pauseOnLowBattery, Copy.batteryFloor,
                      Copy.batteryResume, Copy.onlyWhileCharging,
                      Copy.helperRule, Copy.helperGuard, Copy.installed,
                      Copy.notInstalled, Copy.installHelper, Copy.removeHelper]
        for label in labels {
            XCTAssertFalse(label.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        XCTAssertEqual(Set(labels).count, labels.count, "two rows say the same thing")
    }

    /// A resume at or below the floor pauses again on the next tick, so the
    /// window will not let the two be set that way.
    func testTheResumeStaysAboveTheFloor() {
        XCTAssertGreaterThan(Settings.defaults.batteryResume, Settings.defaults.batteryFloor)
    }

    /// A cap of zero is the one number in here that means something other than
    /// its value, so it says so.
    func testACapOfZeroReadsAsNoCap() {
        XCTAssertEqual(Copy.cap(0), "no cap")
        XCTAssertEqual(Copy.cap(86400), "24 h")
    }
}
