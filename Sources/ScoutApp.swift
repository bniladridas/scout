import SwiftUI

@main
struct ScoutApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1220, minHeight: 760)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
