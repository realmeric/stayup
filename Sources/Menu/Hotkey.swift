import AppKit
import Carbon.HIToolbox

/// A key and the modifiers held with it.
///
/// Stored as Carbon's own numbers rather than `NSEvent.ModifierFlags`, because
/// Carbon is what registers it and a translation kept in a settings file is a
/// translation that can go stale. The display name is worked out from them on
/// the way to the screen.
struct Hotkey: Codable, Equatable, Hashable {
    /// A virtual key code, which is a position on the keyboard rather than a
    /// letter: the same physical key on a Turkish-Q layout and a US one.
    var keyCode: UInt32
    /// `cmdKey`, `optionKey`, `controlKey`, `shiftKey`, or-ed together.
    var modifiers: UInt32

    /// Control-Option-Command-B. Nothing in macOS claims it, and it is
    /// reachable one-handed.
    static let `default` = Hotkey(keyCode: UInt32(kVK_ANSI_B),
                                  modifiers: UInt32(cmdKey | optionKey | controlKey))

    /// What the settings window shows: `⌃⌥⌘B`, in the order macOS writes them.
    var display: String {
        var text = ""
        if modifiers & UInt32(controlKey) != 0 { text += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { text += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { text += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { text += "⌘" }
        return text + Hotkey.keyName(keyCode)
    }

    /// A shortcut with no modifier is a shortcut that fires while you type.
    var isUsable: Bool {
        modifiers & UInt32(cmdKey | optionKey | controlKey) != 0
    }

    // MARK: - The two translations

    /// Carbon's flags from AppKit's, for a key the recorder just caught.
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        return carbon
    }

    /// The names of the keys that have no printable character of their own,
    /// and the letters and digits for everything else.
    static func keyName(_ keyCode: UInt32) -> String {
        if let named = named[Int(keyCode)] { return named }
        return printable(keyCode) ?? "Key \(keyCode)"
    }

    private static let named: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫",
        kVK_Escape: "⎋", kVK_ForwardDelete: "⌦", kVK_Home: "↖", kVK_End: "↘",
        kVK_PageUp: "⇞", kVK_PageDown: "⇟", kVK_LeftArrow: "←",
        kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5",
        kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10",
        kVK_F11: "F11", kVK_F12: "F12"
    ]

    /// What the key produces on the layout in front of you, asked of the
    /// layout itself: on a Turkish-Q keyboard the key at `kVK_ANSI_I` is not
    /// an `i`, and a table baked in here would say it was.
    private static func printable(_ keyCode: UInt32) -> String? {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?
            .takeRetainedValue(),
            let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        var deadKeys: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)
        let status = data.withUnsafeBytes { raw -> OSStatus in
            guard let layout = raw.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self)
            else { return -1 }
            return UCKeyTranslate(layout,
                                  UInt16(keyCode),
                                  UInt16(kUCKeyActionDisplay),
                                  0,
                                  UInt32(LMGetKbdType()),
                                  OptionBits(kUCKeyTranslateNoDeadKeysMask),
                                  &deadKeys,
                                  characters.count,
                                  &length,
                                  &characters)
        }
        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: characters, count: length).uppercased()
    }
}

/// The one global shortcut, held for as long as the app runs.
///
/// Carbon's `RegisterEventHotKey` rather than `NSEvent.addGlobalMonitor`:
/// the monitor needs Accessibility permission and sees every keystroke on the
/// Mac, which is an enormous thing to ask for one shortcut. Carbon asks for
/// nothing and only ever hears the combination it registered.
@MainActor
final class HotkeyCenter {
    static let shared = HotkeyCenter()

    /// Called on the main thread when the shortcut fires.
    var action: (() -> Void)?

    private var reference: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var registered: Hotkey?
    /// Ours among any other Carbon hot keys in the process.
    private let identifier = EventHotKeyID(signature: OSType(0x53545559), id: 1)

    private init() {}

    /// Register `hotkey`, replacing whatever was registered before. Passing nil
    /// or an unusable combination leaves nothing registered, which is what the
    /// off switch does.
    @discardableResult
    func adopt(_ hotkey: Hotkey?, enabled: Bool) -> Bool {
        guard enabled, let hotkey, hotkey.isUsable else {
            unregister()
            return false
        }
        guard hotkey != registered || reference == nil else { return true }
        unregister()
        installHandlerIfNeeded()

        var new: EventHotKeyRef?
        let status = RegisterEventHotKey(hotkey.keyCode,
                                         hotkey.modifiers,
                                         identifier,
                                         GetEventDispatcherTarget(),
                                         0,
                                         &new)
        guard status == noErr, let new else {
            // Almost always because something else on the Mac already owns the
            // combination. Worth a line rather than a silent dead switch.
            Log.menu.error("the shortcut \(hotkey.display, privacy: .public) would not register: \(status)")
            return false
        }
        reference = new
        registered = hotkey
        Log.menu.info("shortcut \(hotkey.display, privacy: .public) registered")
        return true
    }

    func unregister() {
        if let reference { UnregisterEventHotKey(reference) }
        reference = nil
        registered = nil
    }

    private func installHandlerIfNeeded() {
        guard handler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), { _, event, _ -> OSStatus in
            var fired = EventHotKeyID()
            GetEventParameter(event,
                              EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID),
                              nil,
                              MemoryLayout<EventHotKeyID>.size,
                              nil,
                              &fired)
            guard fired.signature == OSType(0x53545559) else { return OSStatus(eventNotHandledErr) }
            // Carbon calls this on the main thread already; the hop is so the
            // work is unambiguously main-actor to the compiler.
            DispatchQueue.main.async { HotkeyCenter.shared.action?() }
            return noErr
        }, 1, &spec, nil, &handler)
    }
}
