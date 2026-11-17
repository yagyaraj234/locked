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
        let photo = NSImage(contentsOf: Backdrop.image()).flatMap { $0.isValid ? $0 : nil }
        window.contentView = NSHostingView(rootView: BlockView(goal: goal, photo: photo) { [window] in window.orderOut(nil) })
        // The display the pointer is on, which is where the blocked app was being used.
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        window.setFrame(screen?.frame ?? .zero, display: true)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

private struct BlockView: View {
    let goal: String
    /// The user's own backdrop; nil gives the standard look.
    let photo: NSImage?
    let dismiss: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        ZStack {
            // The same look as setup and the in-tab block page.
            Color(red: 0.05, green: 0.06, blue: 0.08)
            if let photo {
                // As an overlay, so filling the screen can't stretch the layout past it.
                Color.clear.overlay { Image(nsImage: photo).resizable().scaledToFill() }
                    .clipped()
                    .accessibilityHidden(true)
                Color.black.opacity(0.4)  // keeps the goal readable over any picture
            } else {
                RadialGradient(colors: [Color.accentColor.opacity(0.38), .clear], center: .top, startRadius: 0, endRadius: 520)
            }
            VStack(spacing: 0) {
                // The picture is the hero: the lock and label step aside for it.
                if photo == nil {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                    Text("LOCKED")
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(.secondary)
                        .padding(.top, 28)
                }
                Text(goal.isEmpty ? "Back to work" : goal)
                    .font(.system(size: 64, weight: .bold))
                    .tracking(-1.2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                    .shadow(color: .black.opacity(photo == nil ? 0 : 0.5), radius: 12, y: 2)
                    .padding(.top, 14)
                Button("Back to work", action: dismiss)
                    .buttonStyle(PillStyle())
                    .keyboardShortcut(.defaultAction)
                    .padding(.top, 40)
            }
            .padding(80)
            // The backdrop covers the app at once; only the words arrive, like the in-tab block page.
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 12)
            .onAppear {
                withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(duration: 0.4, bounce: 0)) { shown = true }
            }
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
    }
}
