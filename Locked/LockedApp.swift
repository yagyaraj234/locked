import SwiftUI

@main
struct LockedApp: App {
    var body: some Scene {
        MenuBarExtra("Locked", systemImage: "lock.open") {
            PanelView()
        }
        .menuBarExtraStyle(.window)

        Window("Locked Settings", id: "settings") {
            Text("Settings").frame(width: 400, height: 300)
        }
    }
}

struct PanelView: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading) {
            Button("Settings…") {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }
            Button("Quit Locked") { NSApp.terminate(nil) }
        }
        .padding()
    }
}
