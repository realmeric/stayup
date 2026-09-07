import AppKit
import XCTest
@testable import StayUp

/// The glyph in the menu bar. Two readings: the shape says whether the flag is
/// up, the colour says which resting state it is.
final class StatusIconTests: XCTestCase {
    private var settings = Settings.defaults

    override func setUp() {
        super.setUp()
        settings = .defaults
    }

    private func status(helper: HelperStatus = .installed,
                        raised: Bool = false,
                        paused: PauseReason? = nil) -> Status {
        var status = Status()
        status.helper = helper
        status.raised = raised
        status.paused = paused
        return status
    }

    private func look(_ status: Status) -> StatusIcon.Look {
        StatusIcon.look(for: status, settings: settings)
    }

    /// Resting: the outline, in the resting colour, which ships white.
    func testOff() {
        XCTAssertEqual(look(status()),
                       StatusIcon.Look(symbol: "cup.and.saucer",
                                       color: Palette.defaultIdle,
                                       dimmed: false))
    }

    /// Awake: filled, orange.
    func testAwake() {
        XCTAssertEqual(look(status(raised: true)),
                       StatusIcon.Look(symbol: "cup.and.saucer.fill",
                                       color: Palette.defaultAwake,
                                       dimmed: false))
    }

    /// Held: still your session, so still the awake colour, at the weight of a
    /// stopped one. Every pause reads the same, because what you need to know
    /// from the corner of your eye is that it is not holding the flag; the
    /// menu says why.
    func testEveryPauseReadsAsHeld() {
        for reason in [PauseReason.thermal, .battery, .charging] {
            XCTAssertEqual(look(status(paused: reason)),
                           StatusIcon.Look(symbol: "cup.and.saucer",
                                           color: Palette.defaultAwake,
                                           dimmed: true),
                           String(describing: reason))
        }
    }

    /// No warning triangle. Nothing is wrong when the rule is not in yet, and
    /// an alarm every launch about a thing you decided to do later is noise.
    func testNoRuleIsTheRestingGlyph() {
        XCTAssertEqual(look(status(helper: .missing)),
                       StatusIcon.Look(symbol: "cup.and.saucer",
                                       color: Palette.defaultIdle,
                                       dimmed: false))
        XCTAssertNotEqual(look(status(helper: .missing)).symbol, "exclamationmark.triangle")
    }

    /// The rule missing outranks a raised flag, which cannot happen anyway.
    func testTheHelperOutranksTheRest() {
        XCTAssertFalse(look(status(helper: .missing, raised: true)).symbol.hasSuffix(".fill"))
    }

    // MARK: - What the user chose

    func testTheGlyphFollowsTheChoice() {
        settings.iconStyle = .bolt
        XCTAssertEqual(look(status(raised: true)).symbol, "bolt.fill")
        XCTAssertEqual(look(status()).symbol, "bolt")
    }

    func testTheColoursFollowTheChoice() {
        settings.awakeColor = "#00FF00"
        settings.idleColor = "#0000FF"
        XCTAssertEqual(look(status(raised: true)).color, "#00FF00")
        XCTAssertEqual(look(status()).color, "#0000FF")
        XCTAssertEqual(look(status(paused: .thermal)).color, "#00FF00")
    }

    /// Every style has both halves, and both exist on this Mac. A missing
    /// symbol draws nothing at all, and an empty menu bar is not a failure
    /// anyone can read.
    func testEveryStyleIsDrawable() {
        for style in IconStyle.allCases {
            XCTAssertTrue(style.isDrawable, style.rawValue)
            XCTAssertFalse(style.title.isEmpty, style.rawValue)
            XCTAssertNotEqual(style.outline, style.filled, style.rawValue)
        }
    }

    /// And the image actually comes out, tinted rather than a template: a
    /// template would be repainted by the menu bar and the colour would be
    /// whatever macOS felt like.
    func testTheImageIsDrawnAndTinted() throws {
        let image = try XCTUnwrap(StatusIcon.image(for: status(raised: true), settings: settings))
        XCTAssertFalse(image.isTemplate)
        XCTAssertGreaterThan(image.size.width, 0)
    }
}
