import SwiftUI

@main
struct StayUpApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        // A placeholder scene so `App` has one at all. S-07 replaces this with
        // the menu bar item.
        Settings { EmptyView() }
    }
}
