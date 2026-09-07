import AppKit
import XCTest
@testable import StayUp

/// Which of the two things a click on the icon is.
///
/// The whole reason the icon is an `NSStatusItem` rather than a `MenuBarExtra`
/// is that the left button has to do something other than open the menu, so
/// this is the rule that makes the app what it is.
@MainActor
final class StatusItemTests: XCTestCase {
    private func event(_ type: NSEvent.EventType,
                       flags: NSEvent.ModifierFlags = []) -> NSEvent? {
        NSEvent.mouseEvent(with: type,
                           location: .zero,
                           modifierFlags: flags,
                           timestamp: 0,
                           windowNumber: 0,
                           context: nil,
                           eventNumber: 0,
                           clickCount: 1,
                           pressure: 1)
    }

    func testALeftClickToggles() throws {
        let event = try XCTUnwrap(event(.leftMouseUp))
        XCTAssertEqual(StatusItemController.gesture(for: event), .toggle)
    }

    func testARightClickOpensTheMenu() throws {
        let event = try XCTUnwrap(event(.rightMouseUp))
        XCTAssertEqual(StatusItemController.gesture(for: event), .menu)
    }

    /// A Mac with the trackpad's secondary click switched off has no other way
    /// to reach the menu.
    func testControlClickOpensTheMenu() throws {
        let event = try XCTUnwrap(event(.leftMouseUp, flags: [.control]))
        XCTAssertEqual(StatusItemController.gesture(for: event), .menu)
    }

    /// The modifiers people hold for other reasons are not the menu.
    func testTheOtherModifiersStillToggle() throws {
        for flags in [NSEvent.ModifierFlags.command, .option, .shift] {
            let event = try XCTUnwrap(event(.leftMouseUp, flags: flags))
            XCTAssertEqual(StatusItemController.gesture(for: event), .toggle,
                           String(describing: flags))
        }
    }

    /// The button was pressed either way, and the left one is the common case.
    func testNoEventAtAllIsAToggle() {
        XCTAssertEqual(StatusItemController.gesture(for: nil), .toggle)
    }
}
