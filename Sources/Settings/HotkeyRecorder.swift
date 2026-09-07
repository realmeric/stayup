import AppKit
import SwiftUI

/// The control you click and then press a shortcut into.
///
/// AppKit, because catching a raw key press means being the first responder
/// and reading `keyDown`, and SwiftUI has no way to say either. While it is
/// recording it also turns off the shortcut it is about to replace, or pressing
/// the current one would fire the app instead of being caught.
struct HotkeyRecorder: NSViewRepresentable {
    @Binding var hotkey: Hotkey
    var isEnabled: Bool

    func makeNSView(context: Context) -> RecorderView {
        let view = RecorderView()
        view.onCapture = { hotkey = $0 }
        return view
    }

    func updateNSView(_ view: RecorderView, context: Context) {
        view.hotkey = hotkey
        view.isEnabled = isEnabled
        view.needsDisplay = true
    }

    final class RecorderView: NSView {
        var hotkey: Hotkey = .default
        var isEnabled = true
        var onCapture: ((Hotkey) -> Void)?
        private var recording = false {
            didSet {
                HotkeyCenter.shared.adopt(recording ? nil : hotkey, enabled: !recording)
                needsDisplay = true
            }
        }

        override var acceptsFirstResponder: Bool { isEnabled }
        override var intrinsicContentSize: NSSize { NSSize(width: 132, height: 24) }

        override func mouseDown(with event: NSEvent) {
            guard isEnabled else { return }
            window?.makeFirstResponder(self)
            recording = true
        }

        override func resignFirstResponder() -> Bool {
            recording = false
            return true
        }

        override func keyDown(with event: NSEvent) {
            guard recording else { return super.keyDown(with: event) }
            // Escape leaves the shortcut as it was, which is the only way out
            // of a recorder that is swallowing every key you press.
            guard event.keyCode != 53 else {
                recording = false
                window?.makeFirstResponder(nil)
                return
            }
            let modifiers = Hotkey.carbonModifiers(from: event.modifierFlags)
            let candidate = Hotkey(keyCode: UInt32(event.keyCode), modifiers: modifiers)
            // A shortcut with no modifier fires while you are typing an email.
            guard candidate.isUsable else { NSSound.beep(); return }
            hotkey = candidate
            onCapture?(candidate)
            recording = false
            window?.makeFirstResponder(nil)
        }

        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            // While recording, a combination that is also a menu shortcut has
            // to reach keyDown rather than being eaten by the menu.
            guard recording else { return super.performKeyEquivalent(with: event) }
            keyDown(with: event)
            return true
        }

        override func draw(_ dirtyRect: NSRect) {
            let rounded = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
                                       xRadius: 6, yRadius: 6)
            (recording ? NSColor.controlAccentColor.withAlphaComponent(0.16)
                       : NSColor.controlBackgroundColor).setFill()
            rounded.fill()
            (recording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
            rounded.stroke()

            let text = recording ? "Press a shortcut" : hotkey.display
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            let color: NSColor = isEnabled
                ? (recording ? .secondaryLabelColor : .labelColor)
                : .tertiaryLabelColor
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: recording ? 11 : 13,
                                         weight: recording ? .regular : .medium),
                .foregroundColor: color,
                .paragraphStyle: style
            ]
            let size = (text as NSString).size(withAttributes: attributes)
            (text as NSString).draw(
                in: NSRect(x: 0, y: (bounds.height - size.height) / 2,
                           width: bounds.width, height: size.height),
                withAttributes: attributes)
        }
    }
}
