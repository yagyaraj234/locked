import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var selection: Selection? = .everySession

    private enum Selection: Hashable {
        case everySession
        case blockScreen
        case session(UUID)
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label("Every Session", systemImage: "square.stack.3d.up").tag(Selection.everySession)
                Label("Block Screen", systemImage: "photo").tag(Selection.blockScreen)
                Section("Sessions") {
                    ForEach(model.sessions) { session in
                        Label(session.name.isEmpty ? "Untitled" : session.name,
                              systemImage: model.isLocked(session.id) ? "lock.fill" : "lock.open")
                            .tag(Selection.session(session.id))
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading) {
                    Button("New Session", systemImage: "plus") {
                        let session = Session(name: "New session")
                        model.save(session)
                        selection = .session(session.id)
                    }
                    LaunchAtLoginToggle()
                    Button("Setup Guide…") { model.showOnboarding() }
                        .buttonStyle(.link)
                        .disabled(model.locked)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            if selection == .everySession {
                EverySessionEditor()
            } else if selection == .blockScreen {
                BlockScreenEditor()
            } else if let session = model.sessions.first(where: { selection == .session($0.id) }) {
                SessionEditor(session: session, locked: model.isLocked(session.id))
                    .id(session.id)
            } else {
                Text("Select a session, or add one.").foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 640, minHeight: 480)
    }
}

/// Edits a draft and commits it on Save, so a half-entered schedule can't lock the session mid-edit.
private struct SessionEditor: View {
    let session: Session
    let locked: Bool
    @Environment(AppModel.self) private var model
    @State private var draft: Session
    @State private var confirmingDelete = false

    /// A weekly schedule with no day never runs, so it can't be saved.
    private var canSave: Bool { draft.schedule?.weekdays.isEmpty != true }

    init(session: Session, locked: Bool) {
        self.session = session
        self.locked = locked
        _draft = State(initialValue: session)
    }

    var body: some View {
        Form {
            if locked {
                Label("This session is running or on a break. It can't be changed until it ends.", systemImage: "lock.fill")
            }
            Group {
                Section {
                    TextField("Name", text: $draft.name)
                    TextField("Goal", text: $draft.goal, prompt: Text("Shown when something is blocked"))
                }
                BlockListSections(apps: $draft.apps, sites: $draft.sites)
                ScheduleSection(schedule: $draft.schedule)
                HStack {
                    Button("Delete Session", role: .destructive) { confirmingDelete = true }
                    Spacer()
                    Button("Save") { model.save(draft) }
                        .keyboardShortcut(.defaultAction)
                        .disabled(draft == session || !canSave)
                }
            }
            .disabled(locked)
        }
        .formStyle(.grouped)
        .confirmationDialog("Delete “\(session.name)”?", isPresented: $confirmingDelete) {
            Button("Delete Session", role: .destructive) { model.delete(session.id) }
        }
        // Changed elsewhere (Setup Guide run again): start from that, or leaving would save the old draft over it.
        .onChange(of: session) { draft = session }
        // Leaving for another row keeps the edits rather than dropping them. A deleted session stays deleted.
        .onDisappear {
            if !locked, canSave, draft != session, model.sessions.contains(where: { $0.id == session.id }) { model.save(draft) }
        }
    }
}

/// Blocked in every session, so common distractions are listed once.
private struct EverySessionEditor: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let list = Binding { model.policy.everySession } set: { model.setEverySession($0) }
        Form {
            if !model.locked {
                Text("Blocked whenever any session is active, on top of that session's own apps and sites.")
                    .foregroundStyle(.secondary)
            } else {
                Label("A session is running or on a break. This list can't be changed until it ends.", systemImage: "lock.fill")
            }
            BlockListSections(apps: list.apps, sites: list.sites)
                .disabled(model.locked)
        }
        .formStyle(.grouped)
    }
}

/// The picture behind every block. Never locked: it changes how a block looks, not what is blocked.
private struct BlockScreenEditor: View {
    @Environment(AppModel.self) private var model
    @State private var photo = NSImage(contentsOf: Backdrop.image())
    @State private var failed = false

    var body: some View {
        Form {
            Section {
                if let photo {
                    Image(nsImage: photo)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 180)
                        .clipShape(.rect(cornerRadius: 8))
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("Current background")
                }
                HStack {
                    Button("Choose Image…", action: choose)
                    if photo != nil { Button("Remove", action: remove) }
                    Spacer()
                    Button("Preview") { model.previewBlockScreen() }
                }
                if failed {
                    Label("Couldn't open that image.", systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                }
            } header: {
                Text("Background")
            } footer: {
                Text("Your own picture behind the goal, whenever an app or site is blocked.")
            }
        }
        .formStyle(.grouped)
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        failed = (try? Backdrop.set(from: url)) == nil
        if !failed { photo = NSImage(contentsOf: Backdrop.image()) }
    }

    private func remove() {
        Backdrop.remove()
        photo = nil
        failed = false
    }
}

/// The Apps and Sites sections, shared by a session and the every-session list.
struct BlockListSections: View {
    @Binding var apps: [String]
    @Binding var sites: [SiteRule]
    @State private var newSite = ""

    var body: some View {
        Section("Apps") {
            ForEach(apps, id: \.self) { bundleID in
                row(appName(bundleID)) { apps.removeAll { $0 == bundleID } }
            }
            Button("Add Apps…", action: pickApps)
        }
        Section("Sites") {
            ForEach(sites, id: \.self) { rule in
                row(rule.text) { sites.removeAll { $0 == rule } }
            }
            HStack {
                TextField("Add a site", text: $newSite, prompt: Text("youtube.com or youtube.com/shorts"))
                    .onSubmit(addSite)
                Button("Add", action: addSite).disabled(SiteRule(parsing: newSite) == nil)
            }
        }
    }

    private func row(_ title: String, remove: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
            Spacer()
            Button("Remove", systemImage: "minus.circle") { withAnimation(.easeOut(duration: 0.2), remove) }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
        }
    }

    private func pickApps() {
        let picked = chooseApps().filter { !apps.contains($0) }
        withAnimation(.easeOut(duration: 0.2)) { apps += picked }
    }

    private func addSite() {
        guard let rule = SiteRule(parsing: newSite) else { return }
        if !sites.contains(rule) { withAnimation(.easeOut(duration: 0.2)) { sites.append(rule) } }
        newSite = ""
    }
}

/// Weekly repeat, weekdays and times. Off means the session only runs by hand.
struct ScheduleSection: View {
    @Binding var schedule: Schedule?

    var body: some View {
        Section("Schedule") {
            Toggle("Repeat weekly", isOn: Binding { schedule != nil } set: { on in
                withAnimation(.easeOut(duration: 0.2)) { schedule = on ? Schedule() : nil }
            })
            if let schedule = Binding($schedule) {
                HStack {
                    ForEach(1...7, id: \.self) { weekday in
                        Toggle(Calendar.current.veryShortWeekdaySymbols[weekday - 1], isOn: Binding {
                            schedule.wrappedValue.weekdays.contains(weekday)
                        } set: { on in
                            if on { schedule.wrappedValue.weekdays.insert(weekday) } else { schedule.wrappedValue.weekdays.remove(weekday) }
                        })
                        .toggleStyle(.button)
                        .accessibilityLabel(Calendar.current.weekdaySymbols[weekday - 1])
                    }
                }
                DatePicker("Starts", selection: time(schedule.start), displayedComponents: .hourAndMinute)
                DatePicker("Ends", selection: time(schedule.end), displayedComponents: .hourAndMinute)
                if schedule.wrappedValue.weekdays.isEmpty {
                    Text("Pick at least one day, or it never runs.").font(.caption).foregroundStyle(.secondary)
                }
                if schedule.wrappedValue.end <= schedule.wrappedValue.start {
                    Text("Ends the next morning.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// The standard open panel, rooted at Applications. Returns the bundle IDs chosen.
func chooseApps() -> [String] {
    let panel = NSOpenPanel()
    panel.directoryURL = URL(filePath: "/Applications")
    panel.allowedContentTypes = [.application]
    panel.allowsMultipleSelection = true
    guard panel.runModal() == .OK else { return [] }
    return panel.urls.compactMap { Bundle(url: $0)?.bundleIdentifier }
}

/// Bridges minutes after midnight to the `Date` a `DatePicker` wants.
func time(_ minutes: Binding<Int>) -> Binding<Date> {
    let calendar = Calendar.current
    return Binding {
        calendar.date(bySettingHour: minutes.wrappedValue / 60, minute: minutes.wrappedValue % 60, second: 0, of: Date()) ?? Date()
    } set: {
        let parts = calendar.dateComponents([.hour, .minute], from: $0)
        minutes.wrappedValue = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
}

private struct LaunchAtLoginToggle: View {
    @Environment(AppModel.self) private var model
    @Environment(\.controlActiveState) private var activeState
    @State private var enabled = loginAgent.status == .enabled

    var body: some View {
        Toggle("Launch at login", isOn: Binding { enabled } set: { on in
            try? on ? loginAgent.register() : loginAgent.unregister()
            enabled = loginAgent.status == .enabled
        })
        .disabled(model.locked)  // or a restart would end the session
        // Re-read on focus: it may have been changed in System Settings.
        .onChange(of: activeState) { enabled = loginAgent.status == .enabled }
    }
}
