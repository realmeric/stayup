import AppKit

/// The glyph in the menu bar, as a function of the status and the settings.
///
/// Two readings rather than one. The *shape* is filled while a session holds
/// the flag and outlined the rest of the time, which is legible in the corner
/// of your eye and legible to an eye that cannot separate the colours. The
/// *colour* then says which of the resting states it is.
enum StatusIcon {
    struct Look: Equatable {
        var symbol: String
        var color: String
        /// A held session: the awake colour, at the weight of a stopped one.
        var dimmed: Bool
    }

    static func look(for status: Status, settings: Settings) -> Look {
        let style = settings.iconStyle
        // The rule is not installed, so nothing can be raised. That used to be
        // a warning triangle, which shouted at you every launch about a thing
        // you had already decided to do later. It is the resting glyph.
        guard status.helper == .installed else {
            return Look(symbol: style.outline, color: settings.idleColor, dimmed: false)
        }
        if status.paused != nil {
            // Still a session, still yours, just not holding the flag: the
            // awake colour with the conviction taken out of it.
            return Look(symbol: style.outline, color: settings.awakeColor, dimmed: true)
        }
        if status.raised {
            return Look(symbol: style.filled, color: settings.awakeColor, dimmed: false)
        }
        return Look(symbol: style.outline, color: settings.idleColor, dimmed: false)
    }

    /// The drawn image.
    ///
    /// Not a template image: a template is tinted by the menu bar and the whole
    /// point here is a colour somebody chose. The size is pinned to 16 pt so a
    /// change of glyph never shifts the icons beside it.
    static func image(for status: Status, settings: Settings) -> NSImage? {
        let look = look(for: status, settings: settings)
        let configuration = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        guard let base = NSImage(systemSymbolName: look.symbol,
                                 accessibilityDescription: Copy.statusLine(status, now: Date()))?
            .withSymbolConfiguration(configuration) else { return nil }

        var color = NSColor(hexString: look.color)
        if look.dimmed { color = color.withAlphaComponent(Palette.pausedOpacity) }

        let tinted = NSImage(size: base.size, flipped: false) { rect in
            base.draw(in: rect)
            color.set()
            rect.fill(using: .sourceAtop)
            return true
        }
        tinted.isTemplate = false
        tinted.accessibilityDescription = base.accessibilityDescription
        return tinted
    }
}
