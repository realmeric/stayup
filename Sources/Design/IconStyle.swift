import AppKit
import Foundation

/// The glyph in the menu bar, as a choice.
///
/// Each style is a pair rather than one symbol: the filled variant says a
/// session is running and the outline says it is not, which is a difference you
/// can read at a glance in the corner of your eye without reading a colour.
/// Colour then says *which* state, and the two together survive a colourblind
/// eye and a menu bar full of other icons.
enum IconStyle: String, Codable, CaseIterable, Identifiable {
    case coffee
    case mug
    case sun
    case bolt
    case eye
    case moon

    var id: String { rawValue }

    /// What the settings window calls it.
    var title: String {
        switch self {
        case .coffee: return "Coffee"
        case .mug: return "Mug"
        case .sun: return "Sun"
        case .bolt: return "Bolt"
        case .eye: return "Eye"
        case .moon: return "Moon"
        }
    }

    var outline: String {
        switch self {
        case .coffee: return "cup.and.saucer"
        case .mug: return "mug"
        case .sun: return "sun.max"
        case .bolt: return "bolt"
        case .eye: return "eye"
        case .moon: return "moon.zzz"
        }
    }

    var filled: String {
        switch self {
        case .coffee: return "cup.and.saucer.fill"
        case .mug: return "mug.fill"
        case .sun: return "sun.max.fill"
        case .bolt: return "bolt.fill"
        case .eye: return "eye.fill"
        case .moon: return "moon.zzz.fill"
        }
    }

    func name(filled: Bool) -> String {
        filled ? self.filled : outline
    }

    /// Both halves exist on this Mac. A style whose symbol is missing draws
    /// nothing at all, and an empty menu bar is not a failure anyone can read.
    var isDrawable: Bool {
        NSImage(systemSymbolName: outline, accessibilityDescription: nil) != nil
            && NSImage(systemSymbolName: filled, accessibilityDescription: nil) != nil
    }
}
