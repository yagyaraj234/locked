import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var selection: UUID?

    var body: some View {
        NavigationSplitView {
            List(model.sessions, selection: $selection) { session in
                Label(session.name.isEmpty ? "Untitled" : session.name,
                      systemImage: model.isActive(session.id) ? "lock.fill" : "lock.open")
            }
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading) {
                    Button("New Session", systemImage: "plus") {
                        let session = Session(name: "New session")
                        model.save(session)
                        selection = session.id
                    }
                    LaunchAtLoginToggle()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            if let session = model.sessions.first(where: { $0.id == selection }) {
                SessionEditor(session: session, locked: model.isActive(session.id))
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
    @State private var newSite = ""

    init(session: Session, locked: Bool) {
        self.session = session
        self.locked = locked
        _draft = State(initialValue: session)
    }

    var body: some View {
        Form {
            if locked {
                Label("This session is active. It can't be changed until it ends.", systemImage: "lock.fill")
            }
            Group {
                Section {
                    TextField("Name", text: $draft.name)
                    TextField("Goal", text: $draft.goal, prompt: Text("Shown when something is blocked"))
                }
                Section("Apps") {
                    ForEach(draft.apps, id: \.self) { bundleID in
                        row(appName(bundleID)) { draft.apps.removeAll { $0 == bundleID } }
                    }
                    Button("Add Apps…", action: pickApps)
                }
                Section("Sites") {
                    ForEach(draft.sites, id: \.self) { rule in
                        row(rule.text) { draft.sites.removeAll { $0 == rule } }
                    }
                    TextField("Add a site", text: $newSite, prompt: Text("youtube.com or youtube.com/shorts"))
                        .onSubmit(addSite)
                }
                Section("Schedule") {
                    Toggle("Repeat weekly", isOn: Binding { draft.schedule != nil } set: { draft.schedule = $0 ? Schedule() : nil })
                    if let schedule = Binding($draft.schedule) {
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
                        if schedule.wrappedValue.end <= schedule.wrappedValue.start {
                            Text("Ends the next morning.").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                HStack {
                    Button("Delete Session", role: .destructive) { model.delete(session.id) }
                    Spacer()
                    Button("Save") {
                        addSite()
                        model.save(draft)
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(draft == session && newSite.isEmpty)
                }
            }
            .disabled(locked)
        }
        .formStyle(.grouped)
    }

    private func row(_ title: String, remove: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
            Spacer()
            Button("Remove", systemImage: "minus.circle", action: remove)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
        }
    }

    private func pickApps() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(filePath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for id in panel.urls.compactMap({ Bundle(url: $0)?.bundleIdentifier }) where !draft.apps.contains(id) {
            draft.apps.append(id)
        }
    }

    private func addSite() {
        guard let rule = SiteRule(parsing: newSite) else { return }
        if !draft.sites.contains(rule) { draft.sites.append(rule) }
        newSite = ""
    }

    /// Bridges minutes after midnight to the `Date` a `DatePicker` wants.
    private func time(_ minutes: Binding<Int>) -> Binding<Date> {
        let calendar = Calendar.current
        return Binding {
            calendar.date(bySettingHour: minutes.wrappedValue / 60, minute: minutes.wrappedValue % 60, second: 0, of: Date()) ?? Date()
        } set: {
            let parts = calendar.dateComponents([.hour, .minute], from: $0)
            minutes.wrappedValue = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        }
    }
}

private struct LaunchAtLoginToggle: View {
    @Environment(\.controlActiveState) private var activeState
    @State private var enabled = SMAppService.mainApp.status == .enabled

    var body: some View {
        Toggle("Launch at login", isOn: Binding { enabled } set: { on in
            try? on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
            enabled = SMAppService.mainApp.status == .enabled
        })
        // Re-read on focus: it may have been changed in System Settings.
        .onChange(of: activeState) { enabled = SMAppService.mainApp.status == .enabled }
    }
}
