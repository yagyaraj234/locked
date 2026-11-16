import AppKit
import SwiftUI

/// The full-screen reminder shown over a blocked app.
final class BlockScreen {
    private final class Window: NSWindow {
        override var canBecomeKey: Bool { true }  // borderless windows refuse by default
    }

    private lazy var window: NSWindow = {
        let window = Window(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        return window
    }()

    func show(goal: String) {
        window.contentView = NSHostingView(rootView: BlockView(goal: goal) { [window] in window.orderOut(nil) })
        // The display the pointer is on, which is where the blocked app was being used.
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        window.setFrame(screen?.frame ?? .zero, display: true)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

private struct BlockView: View {
    let goal: String
    let dismiss: () -> Void

    var body: some View {
        ZStack {
            // The same look as setup and the in-tab block page.
            Color(red: 0.05, green: 0.06, blue: 0.08)
            RadialGradient(colors: [Color.accentColor.opacity(0.38), .clear], center: .top, startRadius: 0, endRadius: 520)
            VStack(spacing: 0) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text("LOCKED")
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(.secondary)
                    .padding(.top, 28)
                Text(goal.isEmpty ? "Back to work" : goal)
                    .font(.system(size: 64, weight: .bold))
                    .tracking(-1.2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                    .padding(.top, 14)
                Button("Back to work", action: dismiss)
                    .buttonStyle(PillStyle())
                    .keyboardShortcut(.defaultAction)
                    .padding(.top, 40)
            }
            .padding(80)
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
    }
}
