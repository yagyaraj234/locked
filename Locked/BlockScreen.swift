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
        VStack(spacing: 24) {
            Image(systemName: "lock.fill").font(.system(size: 48)).foregroundStyle(.secondary)
            Text(goal.isEmpty ? "Back to work" : goal)
                .font(.system(size: 44, weight: .bold))
                .multilineTextAlignment(.center)
            Button("Back to work", action: dismiss)
                .controlSize(.extraLarge)
                .keyboardShortcut(.defaultAction)
        }
        .padding(80)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}
