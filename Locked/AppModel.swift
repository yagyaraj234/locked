import AppKit
import Observation
import ServiceManagement
import SwiftUI

/// Owns the saved policy, reads the clock, and enforces the policy's verdicts.
@Observable final class AppModel {
    private(set) var policy = Policy()
    private(set) var active: [ActiveSession] = []
    /// Running browsers whose Automation permission has been denied.
    private(set) var deniedBrowsers: [Browser] = []

    @ObservationIgnored private let blockScreen = BlockScreen()
    @ObservationIgnored private var onboardingWindow: NSWindow?
    @ObservationIgnored private let defaults = UserDefaults.standard
    /// One browser read at a time: a slow or prompting browser must not queue up a read per tick.
    @ObservationIgnored private var readingBrowser = false

    var sessions: [Session] { policy.sessions }

    init() {
        if let data = defaults.data(forKey: "policy"), let saved = try? JSONDecoder().decode(Policy.self, from: data) {
            policy = saved
        }
        if !defaults.bool(forKey: "didRegisterLoginItem") {
            // Once only, so turning the toggle off in Settings sticks. A failure
            // (say, running from outside /Applications) is tried again next launch.
            if (try? SMAppService.mainApp.register()) != nil { defaults.set(true, forKey: "didRegisterLoginItem") }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        // Everything is recomputed from the clock each second, so schedules,
        // relaunches and wake from sleep need no bookkeeping of their own.
        Task {
            // Deferred to here because NSApp doesn't exist yet while the App struct is being built.
            if !defaults.bool(forKey: "didOnboard"), policy.sessions.isEmpty { showOnboarding() }
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

    /// Locked while any session is active, since it applies to all of them.
    func setEverySession(_ list: BlockList) {
        guard active.isEmpty else { return }
        policy.everySession = list
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

    // MARK: Onboarding

    func showOnboarding() {
        let window = onboardingWindow ?? NSWindow(contentRect: .zero, styleMask: [.titled, .closable, .fullSizeContentView],
                                                  backing: .buffered, defer: false)
        window.title = "Welcome to Locked"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: OnboardingView().environment(self))
        window.layoutIfNeeded()  // size to the content first, or center() centres an empty window
        window.center()
        onboardingWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()  // an agent app's windows open behind otherwise
    }

    /// Ends onboarding. `session` is nil when it was skipped; `list` is added to the every-session list.
    func finishOnboarding(session: Session?, list: BlockList = BlockList()) {
        defaults.set(true, forKey: "didOnboard")
        onboardingWindow?.close()
        guard let session, active.isEmpty else { return }
        policy.sessions.append(session)
        policy.everySession.apps += list.apps.filter { !policy.everySession.apps.contains($0) }
        policy.everySession.sites += list.sites.filter { !policy.everySession.sites.contains($0) }
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

        // Browser permission only matters once some session blocks a site.
        let sitesEverySession = !policy.everySession.sites.isEmpty
        let usesSites = sitesEverySession || policy.sessions.contains { !$0.sites.isEmpty }
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        let denied = usesSites ? running.compactMap(Browser.of).filter(\.permissionDenied).sorted { $0.name < $1.name } : []
        if denied != deniedBrowsers { deniedBrowsers = denied }

        guard let front = NSWorkspace.shared.frontmostApplication, let bundleID = front.bundleIdentifier else { return }
        if case .blocked(_, let goal) = policy.verdict(for: .app(bundleID), at: now) {
            front.hide()  // never terminate: unsaved work stays safe
            blockScreen.show(goal: goal)
        } else if let browser = Browser.of(bundleID), !denied.contains(browser),
                  nowActive.contains(where: { sitesEverySession || !$0.session.sites.isEmpty }), !readingBrowser {
            readingBrowser = true
            Task {
                defer { readingBrowser = false }
                guard let url = await browser.frontURL(),
                      case .blocked(_, let goal) = policy.verdict(for: .url(url), at: Date()) else { return }
                if await browser.redirect(showing: goal) == .needsBlockScreen { blockScreen.show(goal: goal) }
            }
        }
    }
}

func appName(_ bundleID: String) -> String {
    NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)?
        .deletingPathExtension().lastPathComponent ?? bundleID
}
