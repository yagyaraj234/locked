import AppKit
import Observation
import ServiceManagement

/// Owns the saved policy, reads the clock, and enforces the policy's verdicts.
@Observable final class AppModel {
    private(set) var policy = Policy()
    private(set) var active: [ActiveSession] = []
    /// Running browsers whose Automation permission has been denied.
    private(set) var deniedBrowsers: [Browser] = []

    @ObservationIgnored private let blockScreen = BlockScreen()
    @ObservationIgnored private let defaults = UserDefaults.standard

    var sessions: [Session] { policy.sessions }

    init() {
        if let data = defaults.data(forKey: "policy"), let saved = try? JSONDecoder().decode(Policy.self, from: data) {
            policy = saved
        }
        if !defaults.bool(forKey: "didRegisterLoginItem") {
            // Once only, so turning the toggle off in Settings sticks.
            try? SMAppService.mainApp.register()
            defaults.set(true, forKey: "didRegisterLoginItem")
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        // Everything is recomputed from the clock each second, so schedules,
        // relaunches and wake from sleep need no bookkeeping of their own.
        Task {
            while true {
                tick()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func isActive(_ id: UUID) -> Bool { active.contains { $0.id == id } }

    // MARK: Changes. An active session is locked: it can't be edited or deleted.

    func save(_ session: Session) {
        guard !isActive(session.id) else { return }
        if let index = policy.sessions.firstIndex(where: { $0.id == session.id }) {
            policy.sessions[index] = session
        } else {
            policy.sessions.append(session)
        }
        changed()
    }

    func delete(_ id: UUID) {
        guard !isActive(id) else { return }
        policy.sessions.removeAll { $0.id == id }
        policy.runs.removeAll { $0.sessionID == id }
        policy.suppressions.removeAll { $0.sessionID == id }
        changed()
    }

    func start(_ id: UUID, minutes: Int) {
        policy.start(id, until: Date().addingTimeInterval(TimeInterval(minutes * 60)))
        changed()
    }

    func endEarly(_ id: UUID) {
        policy.endEarly(id, at: Date())
        changed()
    }

    private func changed() {
        if let data = try? JSONEncoder().encode(policy) { defaults.set(data, forKey: "policy") }
        tick()
    }

    // MARK: Enforcement

    private func tick() {
        let now = Date()
        let nowActive = policy.activeSessions(at: now)
        if nowActive != active { active = nowActive }

        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        let denied = Browser.allCases.filter { running.contains($0.rawValue) && $0.automationDenied }
        if denied != deniedBrowsers { deniedBrowsers = denied }

        guard let front = NSWorkspace.shared.frontmostApplication, let bundleID = front.bundleIdentifier else { return }
        if case .blocked(_, let goal) = policy.verdict(for: .app(bundleID), at: now) {
            front.hide()  // never terminate: unsaved work stays safe
            blockScreen.show(goal: goal)
        } else if let browser = Browser(rawValue: bundleID), !denied.contains(browser),
                  nowActive.contains(where: { !$0.session.sites.isEmpty }),
                  let url = browser.frontURL(),
                  case .blocked(_, let goal) = policy.verdict(for: .url(url), at: now) {
            if browser.redirect(showing: goal) == .needsBlockScreen { blockScreen.show(goal: goal) }
        }
    }
}

func appName(_ bundleID: String) -> String {
    NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)?
        .deletingPathExtension().lastPathComponent ?? bundleID
}
