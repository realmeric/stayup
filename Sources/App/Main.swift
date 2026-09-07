import SwiftUI

/// The one engine, reachable from both the scene and the app delegate.
@MainActor
enum Live {
    static let engine = Engine()
}

@main
struct StayUpApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var engine = Live.engine

    var body: some Scene {
        MenuBarExtra {
            MenuView().environmentObject(engine)
        } label: {
            Image(systemName: StatusIcon.name(for: engine.status))
        }
        .menuBarExtraStyle(.menu)

        // Qualified because this app has a `Settings` of its own, the struct
        // of numbers in `Sources/Keeper`, and it wins the bare name here.
        // S-08 puts the window's contents in.
        SwiftUI.Settings { EmptyView() }
    }
}
