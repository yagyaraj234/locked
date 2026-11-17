import AppKit
import Observation
import ServiceManagement
import SwiftUI

/// Login item that relaunches Locked if it is killed (the plist is copied into the app bundle).
let loginAgent = SMAppService.agent(plistName: "com.yagyaraj.locked.keepalive.plist")

/// Owns the saved policy, reads the clock, and enforces the policy's verdicts.
@Observable final class AppModel {
    private(set) var policy = Policy()
    private(set) var active: [ActiveSession] = []
    /// Sessions ended early and coming back after a break; not also in `active`.
    private(set) var onBreak: [Suppression] = []
    /// A session blocks sites, but Locked has no Accessibility permission to read browsers.
    private(set) var cantReadBrowsers = false

    @ObservationIgnored private let blockScreen = BlockScreen()
    @ObservationIgnored private var onboardingWindow: NSWindow?
    @ObservationIgnored private let defaults = UserDefaults.standard
    /// One browser read at a time: a slow or prompting browser must not queue up a read per tick.
    @ObservationIgnored private var readingBrowser = false
    @ObservationIgnored private var readingBackground = false

    var sessions: [Session] { policy.sessions }

    init() {
        let decoder = JSONDecoder()
        if let data = defaults.data(forKey: "policy") {
            if let saved = try? decoder.decode(Policy.self, from: data) {
                policy = saved
            } else {
                // Unreadable (say, saved by a newer version): kept aside, because the next save overwrites it.
                defaults.set(data, forKey: "policy.unreadable")
            }
        }
        // Something kept aside by an earlier launch comes back once this version can read it,
        // beside any sessions made since. Old runs and breaks are long over, so only the rules return.
        if let kept = defaults.data(forKey: "policy.unreadable"), let saved = try? decoder.decode(Policy.self, from: kept) {
            if policy.sessions.isEmpty {
                policy = saved
            } else {
                policy.sessions += saved.sessions.filter { old in !policy.sessions.contains { $0.id == old.id } }
                policy.everySession.add(saved.everySession)
            }
            defaults.removeObject(forKey: "policy.unreadable")
            if let data = try? JSONEncoder().encode(policy) { defaults.set(data, forKey: "policy") }
        }
        if !defaults.bool(forKey: "didRegisterLoginAgent") {
            // Once only, so turning the toggle off in Settings sticks. A failure
            // (say, running from outside /Applications) is tried again next launch.
            try? SMAppService.mainApp.unregister()  // the plain login item of 0.1; the agent replaces it
            if (try? loginAgent.register()) != nil { defaults.set(true, forKey: "didRegisterLoginAgent") }
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

    /// Active or on a break. A break is not a way out: the session comes back after it.
    func isLocked(_ id: UUID) -> Bool { isActive(id) || onBreak.contains { $0.sessionID == id } }

    /// Some session is locked, so Quit, the every-session list and the login item are too.
    var locked: Bool { !active.isEmpty || !onBreak.isEmpty }

    // MARK: Changes. A locked session can't be edited or deleted.

    func save(_ session: Session) {
        guard !isLocked(session.id) else { return }
        if let index = policy.sessions.firstIndex(where: { $0.id == session.id }) {
            policy.sessions[index] = session
        } else {
            policy.sessions.append(session)
        }
        changed()
    }

    func delete(_ id: UUID) {
        guard !isLocked(id) else { return }
        policy.sessions.removeAll { $0.id == id }
        policy.runs.removeAll { $0.sessionID == id }
        policy.suppressions.removeAll { $0.sessionID == id }
        changed()
    }

    /// Locked while any session is, since it applies to all of them.
    func setEverySession(_ list: BlockList) {
        guard !locked else { return }
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

    /// Shows the block screen as it will look, from Settings.
    func previewBlockScreen() { blockScreen.show(goal: sessions.first?.goal ?? "") }

    // MARK: Onboarding

    func showOnboarding() {
        let window = onboardingWindow ?? NSWindow(contentRect: .zero, styleMask: [.titled, .closable, .fullSizeContentView],
                                                  backing: .buffered, defer: false)
        window.title = "Welcome to Locked"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        if onboardingWindow == nil {
            // Closing the window by its button counts as finishing, or it would return every launch.
            NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [defaults] _ in
                defaults.set(true, forKey: "didOnboard")
            }
        }
        window.contentViewController = NSHostingController(rootView: OnboardingView().environment(self))
        window.layoutIfNeeded()  // size to the content first, or center() centres an empty window
        window.center()
        onboardingWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()  // an agent app's windows open behind otherwise
    }

    /// Ends onboarding. `session` is nil when it was skipped; `list` is added to the every-session list.
    /// Setup can't finish while a session is locked (its Finish is disabled), so the answers are never dropped.
    func finishOnboarding(session: Session?, list: BlockList = BlockList()) {
        if session != nil, locked { return }
        defaults.set(true, forKey: "didOnboard")
        onboardingWindow?.close()
        guard let session else { return }
        // Setup run again updates the session it made last time instead of adding a twin.
        if let index = policy.sessions.firstIndex(where: { $0.name == session.name }) {
            policy.sessions[index].goal = session.goal
            policy.sessions[index].schedule = session.schedule
        } else {
            policy.sessions.append(session)
        }
        policy.everySession.add(list)
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
        let nowOnBreak = policy.breaks(at: now).filter { pause in !nowActive.contains { $0.id == pause.sessionID } }
        if nowOnBreak != onBreak { onBreak = nowOnBreak }

        // Browser permission only matters once some session blocks a site.
        let sitesEverySession = !policy.everySession.sites.isEmpty
        let usesSites = sitesEverySession || policy.sessions.contains { !$0.sites.isEmpty }
        let denied = usesSites && !Browser.permissionGranted
        if denied != cantReadBrowsers { cantReadBrowsers = denied }

        // Every blocked app that is showing, not only the front one: a window behind another still scrolls and plays.
        if !nowActive.isEmpty {
            for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular && !app.isHidden {
                if let id = app.bundleIdentifier, case .blocked = policy.verdict(for: .app(id), at: now) { app.hide() }
            }
        }

        // A blocked site in a browser window that is not in front is still scrollable and playing.
        if !denied, !readingBackground, nowActive.contains(where: { sitesEverySession || !$0.session.sites.isEmpty }) {
            let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
            let others = NSWorkspace.shared.runningApplications.compactMap { app -> (NSRunningApplication, Browser)? in
                guard app.activationPolicy == .regular, !app.isHidden, app.processIdentifier != frontPID,
                      let id = app.bundleIdentifier, let browser = Browser.of(id) else { return nil }
                return (app, browser)
            }
            if !others.isEmpty {
                readingBackground = true
                Task {
                    defer { readingBackground = false }
                    for (app, browser) in others {
                        let urls = await browser.allURLs(pid: app.processIdentifier)
                        if urls.contains(where: { if case .blocked = policy.verdict(for: .url($0), at: Date()) { true } else { false } }) {
                            app.hide()
                        }
                    }
                }
            }
        }

        guard let front = NSWorkspace.shared.frontmostApplication, let bundleID = front.bundleIdentifier else { return }
        if case .blocked(_, let goal) = policy.verdict(for: .app(bundleID), at: now) {
            front.hide()  // never terminate: unsaved work stays safe
            blockScreen.show(goal: goal)
        } else if let browser = Browser.of(bundleID),
                  nowActive.contains(where: { sitesEverySession || !$0.session.sites.isEmpty }) {
            if denied {
                // Fails closed: otherwise switching Accessibility off would switch site blocking off.
                front.hide()
                blockScreen.show(goal: "Allow Accessibility for Locked to use your browser")
            } else if !readingBrowser {
                let pid = front.processIdentifier
                readingBrowser = true
                Task {
                    defer { readingBrowser = false }
                    guard let url = await browser.frontURL(pid: pid),
                          case .blocked(_, let goal) = policy.verdict(for: .url(url), at: Date()) else { return }
                    var covered = await browser.redirect(pid: pid, showing: goal) == .blockPage
                    if covered {
                        // Trust nothing: the tab must really have left the blocked address.
                        try? await Task.sleep(for: .milliseconds(500))
                        if let after = await browser.frontURL(pid: pid),
                           case .blocked = policy.verdict(for: .url(after), at: Date()) { covered = false }
                    }
                    if !covered, NSWorkspace.shared.frontmostApplication?.processIdentifier == pid {
                        blockScreen.show(goal: goal)
                    }
                }
            }
        }
    }
}

func appName(_ bundleID: String) -> String {
    NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)?
        .deletingPathExtension().lastPathComponent ?? bundleID
}
