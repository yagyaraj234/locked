import SwiftUI

@main
struct LockedApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra("Locked", systemImage: model.active.isEmpty ? "lock.open" : "lock.fill") {
            PanelView().environment(model)
        }
        .menuBarExtraStyle(.window)

        Window("Locked Settings", id: "settings") {
            SettingsView().environment(model)
        }
        .hiddenAtLaunch()
        .commands {
            // Replaces the default Quit so Cmd-Q is gone too while a session is running.
            CommandGroup(replacing: .appTermination) {
                if model.active.isEmpty {
                    Button("Quit Locked") { NSApp.terminate(nil) }.keyboardShortcut("q")
                }
            }
        }

        WindowGroup("End Session Early", id: "end-early", for: UUID.self) { $sessionID in
            if let sessionID { EndEarlyView(sessionID: sessionID).environment(model) }
        }
        .windowResizability(.contentSize)
        .hiddenAtLaunch()
    }
}

extension Scene {
    /// A menu bar app shows no window until asked.
    func hiddenAtLaunch() -> some Scene {
        defaultLaunchBehavior(.suppressed).restorationBehavior(.disabled)
    }
}

struct PanelView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @State private var picked: UUID?
    @State private var minutes = 25

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.active.isEmpty {
                Text("No session active").foregroundStyle(.secondary)
            }
            ForEach(model.active) { active in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(active.session.name).bold()
                        Spacer()
                        Text(timerInterval: Date.now...max(Date.now, active.end)).monospacedDigit()
                    }
                    Text((active.session.apps.map(appName) + active.session.sites.map(\.text)).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("End early…") { open("end-early", active.id) }
                }
            }

            let everySession = model.policy.everySession
            if !model.active.isEmpty, !(everySession.apps.isEmpty && everySession.sites.isEmpty) {
                Text("Every session: " + (everySession.apps.map(appName) + everySession.sites.map(\.text)).joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !model.sessions.isEmpty {
                Divider()
                HStack {
                    Picker("Session", selection: Binding { sessionToStart } set: { picked = $0 }) {
                        ForEach(model.sessions) { Text($0.name).tag(Optional($0.id)) }
                    }
                    Picker("Duration", selection: $minutes) {
                        ForEach([15, 25, 45, 60, 90, 120], id: \.self) { Text("\($0) min").tag($0) }
                    }
                    .fixedSize()
                    Button("Start now") {
                        if let sessionToStart { model.start(sessionToStart, minutes: minutes) }
                    }
                }
                .labelsHidden()
            }

            ForEach(model.deniedBrowsers) { browser in
                HStack {
                    Label("Can't read \(browser.name): site blocking is off there", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Spacer()
                    Button("Allow…") {
                        if browser.kind == .gecko { Task { await browser.requestPermission() } }
                        NSWorkspace.shared.open(browser.permissionPane)
                    }
                }
            }

            Divider()
            HStack {
                Button("Settings…") { open("settings", nil) }
                Spacer()
                // No way out through Quit while a session is running.
                if model.active.isEmpty {
                    Button("Quit Locked") { NSApp.terminate(nil) }
                }
            }
        }
        .padding()
        .frame(width: 340)
    }

    /// The picked session, or the first one if nothing is picked or the pick was deleted.
    private var sessionToStart: UUID? {
        model.sessions.contains { $0.id == picked } ? picked : model.sessions.first?.id
    }

    private func open(_ id: String, _ sessionID: UUID?) {
        if let sessionID { openWindow(id: id, value: sessionID) } else { openWindow(id: id) }
        // An agent app's windows open behind whatever is in front, and activation alone
        // doesn't always raise them. The window exists one turn after openWindow.
        Task {
            NSApp.activate(ignoringOtherApps: true)
            for window in NSApp.windows where window.identifier?.rawValue.hasPrefix(id) == true {
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
            }
        }
    }
}

/// Ending early costs sixty uninterrupted seconds with this window in front.
struct EndEarlyView: View {
    let sessionID: UUID
    @Environment(AppModel.self) private var model
    @Environment(\.controlActiveState) private var activeState
    @Environment(\.dismiss) private var dismiss
    @State private var remaining = 60

    var body: some View {
        VStack(spacing: 12) {
            Text("Ending “\(model.sessions.first { $0.id == sessionID }?.name ?? "")”").font(.headline)
            Text("\(remaining)").font(.system(size: 64, weight: .bold)).monospacedDigit()
            Text("Keep this window in front. Leaving it restarts the countdown.")
                .foregroundStyle(.secondary)
            Button("Keep going", role: .cancel) { dismiss() }
        }
        .padding(32)
        .frame(width: 360)
        // Restarts whenever the window gains or loses focus, which is what resets the count.
        // Switching desktops changes no focus, so the loop checks for that itself.
        .task(id: activeState) {
            remaining = 60
            guard model.isActive(sessionID) else { return dismiss() }
            guard activeState == .key else { return }
            while remaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                // On another desktop the window stays key, so focus alone doesn't catch it.
                if NSApp.keyWindow?.isOnActiveSpace == true { remaining -= 1 } else { remaining = 60 }
            }
            if model.isActive(sessionID) { model.endEarly(sessionID) }  // it may have ended by itself meanwhile
            dismiss()
        }
    }
}
