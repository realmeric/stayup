import Foundation
import IOKit.pwr_mgt

/// The display's own idle timer, which the flag does not touch.
///
/// `SleepDisabled` overrides every path into system sleep, the lid included,
/// and says nothing at all about the screen: powerd still blanks it after
/// `displaysleep` minutes, 2 on battery and 10 on AC on this Mac. Holding the
/// screen up is a separate claim, and this is it, the same
/// `PreventUserIdleDisplaySleep` assertion `caffeinate -d` takes. It needs no
/// root, and it dies with the process, so unlike the flag there is nothing
/// here for the guard to clean up.
protocol ScreenHolding: AnyObject {
    /// Both are idempotent. The engine syncs the claim on every tick and only
    /// a change is meant to cost anything.
    func hold()
    func release()
}

final class DisplayAssertion: ScreenHolding {
    private var id = IOPMAssertionID(0)
    private var held = false

    func hold() {
        guard !held else { return }
        var taken = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            Copy.screenAssertion as CFString,
            &taken)
        guard result == kIOReturnSuccess else {
            Log.flag.error("the screen would not stay on: IOKit said \(result, privacy: .public)")
            return
        }
        id = taken
        held = true
        Log.flag.info("screen held on")
    }

    func release() {
        guard held else { return }
        IOPMAssertionRelease(id)
        held = false
        Log.flag.info("screen let go")
    }
}

/// What the tests hold. `claims` records the order, so a test can say the
/// screen was taken once and given back once rather than only that it ended
/// released.
final class FakeScreen: ScreenHolding {
    private(set) var claims: [Bool] = []
    var held: Bool { claims.last == true }

    func hold() {
        guard claims.last != true else { return }
        claims.append(true)
    }

    func release() {
        guard claims.last == true else { return }
        claims.append(false)
    }
}
