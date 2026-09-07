import AppKit
import SwiftUI

/// Every colour StayUp draws, which is fewer than it sounds: the app is one
/// glyph in the menu bar and a window of controls the system paints. What is
/// here is the glyph's two states and the way a chosen colour survives a round
/// trip through the settings file.
enum Palette {
    /// The three the app ships with, as text: what the settings file says when
    /// nobody has changed them, and what Defaults puts back.
    ///
    /// Orange because the metaphor is coffee and because it is the one hue
    /// that reads as "on" against both a light and a dark menu bar without
    /// changing. White for the resting state, which the menu bar itself tints
    /// to black in a light appearance.
    static let defaultAwake = "#FF9F0A"
    static let defaultIdle = "#FFFFFF"

    /// A held session is the awake colour with the conviction taken out of it:
    /// the same hue, so it reads as the same session, at a weight that reads as
    /// stopped. A third colour in the settings would be a third decision
    /// nobody asked to make.
    static let pausedOpacity: CGFloat = 0.55
}

extension Color {
    /// `#FF9F0A`, `FF9F0A`, or anything else - which is black, and visibly
    /// wrong, rather than a crash. A colour is never load-bearing enough to
    /// take the app down over.
    init(hexString: String) {
        var text = hexString.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("#") { text.removeFirst() }
        self.init(hex: UInt32(text, radix: 16) ?? 0)
    }

    /// Back to `#FF9F0A`, for writing into the settings file.
    ///
    /// Through `NSColor` and into sRGB first: a `Color` can be any colour space
    /// the picker chose, and reading its components without converting gives
    /// numbers that mean something else.
    var hexString: String {
        let srgb = NSColor(self).usingColorSpace(.sRGB) ?? .black
        let channel = { (value: CGFloat) in Int((min(max(value, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X",
                      channel(srgb.redComponent),
                      channel(srgb.greenComponent),
                      channel(srgb.blueComponent))
    }

    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

extension NSColor {
    /// The same reading, for the menu bar, which is drawn in AppKit.
    convenience init(hexString: String) {
        var text = hexString.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("#") { text.removeFirst() }
        let hex = UInt32(text, radix: 16) ?? 0
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}
