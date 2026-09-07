import Carbon.HIToolbox
import XCTest
@testable import StayUp

/// The global shortcut. Registering it needs a running app, so what is checked
/// here is the part that has to be right before that: the combination itself,
/// how it reads, and what it refuses.
final class HotkeyTests: XCTestCase {
    /// Control-Option-Command-B, as asked for, and written the way macOS
    /// writes modifiers rather than the order they were typed.
    func testTheDefaultIsControlOptionCommandB() {
        let hotkey = Hotkey.default
        XCTAssertEqual(hotkey.keyCode, UInt32(kVK_ANSI_B))
        XCTAssertEqual(hotkey.display, "⌃⌥⌘B")
        XCTAssertTrue(hotkey.isUsable)
    }

    func testItReadsBackEveryModifier() {
        let all = Hotkey(keyCode: UInt32(kVK_ANSI_B),
                         modifiers: UInt32(cmdKey | optionKey | controlKey | shiftKey))
        XCTAssertEqual(all.display, "⌃⌥⇧⌘B")
    }

    /// A shortcut with no modifier fires while you are typing an email.
    func testAKeyOnItsOwnIsNotUsable() {
        XCTAssertFalse(Hotkey(keyCode: UInt32(kVK_ANSI_B), modifiers: 0).isUsable)
        XCTAssertFalse(Hotkey(keyCode: UInt32(kVK_ANSI_B),
                              modifiers: UInt32(shiftKey)).isUsable)
    }

    /// Shift alone is not enough, but shift with something else is.
    func testShiftCountsOnlyBesideAnother() {
        XCTAssertTrue(Hotkey(keyCode: UInt32(kVK_ANSI_B),
                             modifiers: UInt32(shiftKey | cmdKey)).isUsable)
    }

    func testTheNamedKeysHaveNames() {
        XCTAssertEqual(Hotkey.keyName(UInt32(kVK_Space)), "Space")
        XCTAssertEqual(Hotkey.keyName(UInt32(kVK_Escape)), "⎋")
        XCTAssertEqual(Hotkey.keyName(UInt32(kVK_F5)), "F5")
        XCTAssertEqual(Hotkey.keyName(UInt32(kVK_LeftArrow)), "←")
    }

    /// The letter comes from the layout in front of you rather than a table
    /// baked in here, so a Turkish-Q keyboard reads as itself.
    func testALetterKeyNamesItself() {
        let name = Hotkey.keyName(UInt32(kVK_ANSI_B))
        XCTAssertFalse(name.isEmpty)
        XCTAssertFalse(name.hasPrefix("Key "), name)
    }

    func testTheModifierTranslation() {
        XCTAssertEqual(Hotkey.carbonModifiers(from: [.command]), UInt32(cmdKey))
        XCTAssertEqual(Hotkey.carbonModifiers(from: [.command, .option, .control]),
                       UInt32(cmdKey | optionKey | controlKey))
        XCTAssertEqual(Hotkey.carbonModifiers(from: []), 0)
        // Caps lock and function are not modifiers a shortcut can hold.
        XCTAssertEqual(Hotkey.carbonModifiers(from: [.capsLock, .function]), 0)
    }

    /// It survives the settings file, because it is stored as Carbon's own
    /// numbers rather than a translation that could go stale.
    func testItSurvivesARoundTrip() throws {
        let encoded = try JSONEncoder().encode(Hotkey.default)
        XCTAssertEqual(try JSONDecoder().decode(Hotkey.self, from: encoded), .default)
    }

    func testTheDefaultSettingsCarryIt() {
        XCTAssertTrue(Settings.defaults.hotkeyEnabled)
        XCTAssertEqual(Settings.defaults.hotkey, .default)
    }
}
