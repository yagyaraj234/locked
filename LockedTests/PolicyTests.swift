import Foundation
import Testing

/// A fixed calendar so no test depends on the machine's time zone or clock.
let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

/// November 2026: the 9th is a Monday, the 15th a Sunday.
func nov(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    utc.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
}

let work = Session(name: "Work", goal: "Ship the feature", apps: ["com.tinyspeck.slackmacgap"])

@Suite struct ManualRuns {
    let policy = Policy(sessions: [work], runs: [ManualRun(sessionID: work.id, end: nov(9, 11))])

    @Test func `with no run nothing is active or blocked`() {
        let idle = Policy(sessions: [work])
        #expect(idle.activeSessions(at: nov(9, 10)).isEmpty)
        #expect(idle.verdict(for: .app("com.tinyspeck.slackmacgap"), at: nov(9, 10)) == .allowed)
    }

    @Test func `a listed app is blocked with the session's goal while the run lasts`() {
        #expect(policy.verdict(for: .app("com.tinyspeck.slackmacgap"), at: nov(9, 10, 59))
            == .blocked(sessionID: work.id, goal: "Ship the feature"))
    }

    @Test func `an unlisted app is allowed`() {
        #expect(policy.verdict(for: .app("com.apple.dt.Xcode"), at: nov(9, 10)) == .allowed)
    }

    @Test func `the run is over at its end time`() {
        #expect(policy.verdict(for: .app("com.tinyspeck.slackmacgap"), at: nov(9, 11)) == .allowed)
        #expect(policy.activeSessions(at: nov(9, 11)).isEmpty)
    }

    @Test func `an active session reports when it ends`() {
        let active = policy.activeSessions(at: nov(9, 10))
        #expect(active.map(\.session.id) == [work.id])
        #expect(active.first?.end == nov(9, 11))
    }

    @Test(arguments: ["com.yagyaraj.locked", "com.apple.finder", "com.apple.systempreferences"])
    func `Locked, Finder and System Settings are never blocked`(bundleID: String) {
        var session = work
        session.apps.append(bundleID)
        let policy = Policy(sessions: [session], runs: [ManualRun(sessionID: session.id, end: nov(9, 11))])
        #expect(policy.verdict(for: .app(bundleID), at: nov(9, 10)) == .allowed)
    }
}

@Suite struct Schedules {
    /// Monday to Friday, 09:00 to 17:00.
    static let office = Session(name: "Office", goal: "Deep work", apps: ["com.tinyspeck.slackmacgap"],
                                schedule: Schedule(weekdays: [2, 3, 4, 5, 6], start: 9 * 60, end: 17 * 60))
    /// Friday nights, 22:00 to 06:00 the next morning.
    static let night = Session(name: "Night", goal: "Sleep", apps: ["com.tinyspeck.slackmacgap"],
                               schedule: Schedule(weekdays: [6], start: 22 * 60, end: 6 * 60))

    func isActive(_ session: Session, at now: Date) -> Bool {
        !Policy(sessions: [session]).activeSessions(at: now, calendar: utc).isEmpty
    }

    @Test func `a scheduled session is active on its weekdays only`() {
        #expect(isActive(Self.office, at: nov(9, 10)))    // Monday
        #expect(!isActive(Self.office, at: nov(15, 10)))  // Sunday
    }

    @Test func `the window includes its start and excludes its end`() {
        #expect(!isActive(Self.office, at: nov(9, 8, 59)))
        #expect(isActive(Self.office, at: nov(9, 9)))
        #expect(isActive(Self.office, at: nov(9, 16, 59)))
        #expect(!isActive(Self.office, at: nov(9, 17)))
    }

    @Test func `a scheduled session ends when its window does`() {
        let active = Policy(sessions: [Self.office]).activeSessions(at: nov(9, 10), calendar: utc)
        #expect(active.first?.end == nov(9, 17))
    }

    @Test func `a window crossing midnight runs into the next morning`() {
        #expect(isActive(Self.night, at: nov(13, 23)))     // Friday evening
        #expect(isActive(Self.night, at: nov(14, 5, 59)))  // Saturday morning
        #expect(!isActive(Self.night, at: nov(14, 6)))
        let active = Policy(sessions: [Self.night]).activeSessions(at: nov(13, 23), calendar: utc)
        #expect(active.first?.end == nov(14, 6))
    }

    @Test func `a window crossing midnight belongs to the weekday it starts on`() {
        #expect(!isActive(Self.night, at: nov(13, 5)))   // Friday morning: Thursday night isn't selected
        #expect(!isActive(Self.night, at: nov(14, 23)))  // Saturday evening
    }

    @Test func `a session with no schedule is never active on its own`() {
        #expect(!isActive(work, at: nov(9, 10)))
    }
}

@Suite struct Sites {
    func verdict(rule: String, url: String) -> Verdict {
        let session = Session(name: "Focus", goal: "Read", sites: [SiteRule(parsing: rule)!])
        let policy = Policy(sessions: [session], runs: [ManualRun(sessionID: session.id, end: nov(9, 11))])
        return policy.verdict(for: .url(URL(string: url)!), at: nov(9, 10))
    }

    func blocks(rule: String, url: String) -> Bool { verdict(rule: rule, url: url) != .allowed }

    @Test func `a domain rule blocks that domain, reporting the goal`() {
        guard case .blocked(_, goal: "Read") = verdict(rule: "youtube.com", url: "https://youtube.com/watch?v=1") else {
            Issue.record("expected the site to be blocked with the session's goal")
            return
        }
    }

    @Test func `a domain rule blocks subdomains`() {
        #expect(blocks(rule: "youtube.com", url: "https://m.youtube.com/"))
        #expect(blocks(rule: "youtube.com", url: "https://music.app.youtube.com/x"))
    }

    @Test(arguments: ["https://notyoutube.com/", "https://youtube.com.evil.net/", "https://example.com/youtube.com"])
    func `lookalike domains are left alone`(url: String) {
        #expect(!blocks(rule: "youtube.com", url: url))
    }

    @Test func `a path rule blocks only URLs under that path`() {
        #expect(blocks(rule: "youtube.com/shorts", url: "https://www.youtube.com/shorts/abc123"))
        #expect(!blocks(rule: "youtube.com/shorts", url: "https://www.youtube.com/watch?v=1"))
        #expect(!blocks(rule: "youtube.com/shorts", url: "https://www.youtube.com"))
    }

    @Test func `matching ignores www, host case, scheme, port and query`() {
        #expect(blocks(rule: "youtube.com", url: "https://WWW.YouTube.com/"))
        #expect(blocks(rule: "youtube.com", url: "http://youtube.com:8080/feed?x=1"))
    }

    @Test func `a rule typed as a full address is reduced to its domain and path`() {
        #expect(SiteRule(parsing: " https://www.YouTube.com/ ") == SiteRule(parsing: "youtube.com"))
        #expect(SiteRule(parsing: "http://Reddit.com/r/all")?.text == "reddit.com/r/all")
        #expect(SiteRule(parsing: "   ") == nil)
    }
}

@Suite struct Overlap {
    static let slack = "com.tinyspeck.slackmacgap"
    static let mail = "com.apple.mail"
    /// Saved first, scheduled Monday to Friday 09:00 to 17:00.
    static let office = Session(name: "Office", goal: "Deep work", apps: [slack], sites: [SiteRule(parsing: "reddit.com")!],
                                schedule: Schedule(weekdays: [2, 3, 4, 5, 6], start: 9 * 60, end: 17 * 60))
    /// Saved second, started by hand until 11:00 on Monday.
    static let sprint = Session(name: "Sprint", goal: "Finish the draft", apps: [slack, mail])
    let policy = Policy(sessions: [office, sprint], runs: [ManualRun(sessionID: sprint.id, end: nov(9, 11))])

    func goal(_ target: Target, at now: Date) -> String? {
        if case .blocked(_, let goal) = policy.verdict(for: target, at: now, calendar: utc) { goal } else { nil }
    }

    @Test func `two active sessions block the union of their lists`() {
        #expect(policy.activeSessions(at: nov(9, 10), calendar: utc).map(\.session.name) == ["Office", "Sprint"])
        #expect(goal(.app(Self.mail), at: nov(9, 10)) != nil)
        #expect(goal(.url(URL(string: "https://reddit.com/")!), at: nov(9, 10)) != nil)
    }

    @Test func `each block shows the goal of the session that caused it`() {
        #expect(goal(.app(Self.mail), at: nov(9, 10)) == "Finish the draft")
        #expect(goal(.url(URL(string: "https://reddit.com/")!), at: nov(9, 10)) == "Deep work")
    }

    @Test func `when both block a target the earlier saved session's goal wins`() {
        #expect(goal(.app(Self.slack), at: nov(9, 10)) == "Deep work")
    }

    @Test func `when one session ends the other keeps blocking its own list`() {
        #expect(goal(.app(Self.mail), at: nov(9, 11)) == nil)
        #expect(goal(.app(Self.slack), at: nov(9, 11)) == "Deep work")
        #expect(policy.activeSessions(at: nov(9, 11), calendar: utc).first?.end == nov(9, 17))
    }
}

@Suite struct EndingEarly {
    @Test func `ending a manual run early stops it`() {
        var policy = Policy(sessions: [work], runs: [ManualRun(sessionID: work.id, end: nov(9, 11))])
        policy.endEarly(work.id, at: nov(9, 10), calendar: utc)
        #expect(policy.activeSessions(at: nov(9, 10), calendar: utc).isEmpty)
    }

    @Test func `a scheduled session ended early stays off for the rest of its window only`() {
        var policy = Policy(sessions: [Overlap.office])
        policy.endEarly(Overlap.office.id, at: nov(9, 10), calendar: utc)
        #expect(policy.activeSessions(at: nov(9, 10), calendar: utc).isEmpty)
        #expect(policy.activeSessions(at: nov(9, 16, 59), calendar: utc).isEmpty)
        #expect(policy.activeSessions(at: nov(10, 9), calendar: utc).map(\.session.name) == ["Office"])  // Tuesday
    }

    @Test func `ending one session early leaves the other running`() {
        var policy = Policy(sessions: [Overlap.office, Overlap.sprint],
                            runs: [ManualRun(sessionID: Overlap.sprint.id, end: nov(9, 11))])
        policy.endEarly(Overlap.office.id, at: nov(9, 10), calendar: utc)
        #expect(policy.activeSessions(at: nov(9, 10), calendar: utc).map(\.session.name) == ["Sprint"])
    }

    @Test func `a session can be started by hand again after being ended early`() {
        var policy = Policy(sessions: [Overlap.office])
        policy.endEarly(Overlap.office.id, at: nov(9, 10), calendar: utc)
        policy.start(Overlap.office.id, until: nov(9, 12))
        #expect(policy.activeSessions(at: nov(9, 11), calendar: utc).first?.end == nov(9, 12))
    }
}
