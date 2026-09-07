import AppKit
import Combine

/// The icon in the menu bar and what clicking it does.
///
/// Left click starts or stops a session with whatever the settings call the
/// quick start; right click opens the menu. That split is the reason this is an
/// `NSStatusItem` and not a `MenuBarExtra`: SwiftUI's version has one gesture
/// and it is "open the list", which makes the commonest thing you want to do
/// take two clicks and a read.
@MainActor
final class StatusItemController {
    private let engine: Engine
    private let item: NSStatusItem
    private let statusMenu: StatusMenu
    private var watch: AnyCancellable?

    init(engine: Engine) {
        self.engine = engine
        self.statusMenu = StatusMenu(engine: engine)
        self.item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = item.button {
            button.target = self
            button.action = #selector(clicked)
            // Both buttons through one action, so the handler can ask which
            // arrived. Assigning `item.menu` instead would give the menu to
            // the left button too and there would be no click left to toggle
            // with.
            //
            // `.rightMouseDown` rather than `.rightMouseUp`: measured on
            // 2026-09-07, a right click on a status item with the up mask set
            // never reaches the action at all. The left button keeps the up
            // mask, which is where a click is normally counted.
            button.sendAction(on: [.leftMouseUp, .rightMouseDown])
            button.toolTip = AppInfo.name
        }

        watch = engine.$status.sink { [weak self] status in
            self?.draw(status)
        }
        draw(engine.status)
    }

    func refresh() {
        draw(engine.status)
    }

    private func draw(_ status: Status) {
        item.button?.image = StatusIcon.image(for: status, settings: engine.settings)
        item.button?.toolTip = Copy.statusLine(status, now: Date())
    }

    @objc private func clicked() {
        let gesture = StatusItemController.gesture(for: NSApp.currentEvent)
        Log.menu.debug("click: event \(NSApp.currentEvent?.type.rawValue ?? 0, privacy: .public) read as \(String(describing: gesture), privacy: .public)")
        switch gesture {
        case .menu: open()
        case .toggle: engine.toggleQuickStart()
        }
    }

    enum Gesture: Equatable {
        case toggle
        case menu
    }

    /// Which of the two a click was.
    ///
    /// A function of the event and nothing else, so the rule can be read and
    /// tested without a mouse. Control-click counts as a right click because
    /// macOS has said so since before there were two buttons, and a Mac with
    /// the trackpad's secondary click switched off has no other way to reach
    /// the menu. An event that never arrived is a toggle: the button was
    /// pressed, and the left one is the common case.
    static func gesture(for event: NSEvent?) -> Gesture {
        guard let event else { return .toggle }
        if event.type == .rightMouseUp || event.type == .rightMouseDown { return .menu }
        if event.modifierFlags.contains(.control) { return .menu }
        return .toggle
    }

    /// Handed to the item for the length of one click, then taken back.
    ///
    /// The menu cannot simply live on the item: an `NSStatusItem` with `menu`
    /// set permanently stops sending its action altogether, and the left click
    /// quietly stops working. Assigning it around a `performClick` gives the
    /// menu its normal behaviour - the item highlights, the menu tracks, the
    /// call returns when it closes - and leaves the action in place for the
    /// next left click.
    private func open() {
        // After the current event, not during it. A right click arrives as
        // `.rightMouseDown` and AppKit is still tracking the button when the
        // action runs; a menu opened inside that never draws. Measured on
        // 2026-09-07: neither `performClick` nor `popUp` put anything on
        // screen synchronously, and both work one turn of the run loop later.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.item.menu = self.statusMenu.menu
            self.item.button?.performClick(nil)
            self.item.menu = nil
        }
    }
}
