import Foundation

// The blocking policy: every decision about what is blocked and when.
// Pure: no AppKit, no timers, no clock. Time is always passed in.

nonisolated struct Session: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var name = ""
    var goal = ""
    /// Bundle identifiers.
    var apps: [String] = []
    var sites: [SiteRule] = []
    /// `nil` means the session only ever runs by hand.
    var schedule: Schedule?
}

/// A domain, optionally narrowed to a path prefix. Build one with `init(parsing:)`,
/// which is what keeps `domain` lowercase and free of scheme, port and `www.`.
nonisolated struct SiteRule: Codable, Hashable, Sendable {
    var domain: String
    /// Empty, or a path starting with "/".
    var pathPrefix: String

    var text: String { domain + pathPrefix }

    /// Reads what a person types: "youtube.com", "youtube.com/shorts", or a pasted address.
    init?(parsing input: String) {
        var rest = Substring(input.trimmingCharacters(in: .whitespacesAndNewlines))
        if let scheme = rest.range(of: "://") { rest = rest[scheme.upperBound...] }
        let slash = rest.firstIndex(of: "/") ?? rest.endIndex
        let host = Self.normalized(host: rest[..<slash].prefix { $0 != ":" })
        guard !host.isEmpty else { return nil }
        domain = host
        pathPrefix = rest[slash...] == "/" ? "" : String(rest[slash...])
    }

    func matches(_ url: URL) -> Bool {
        guard let host = url.host().map(Self.normalized(host:)) else { return false }
        return (host == domain || host.hasSuffix("." + domain)) && url.path().hasPrefix(pathPrefix)
    }

    private static func normalized(host: some StringProtocol) -> String {
        let host = host.lowercased()
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}

/// A weekly window. An end at or before the start crosses midnight, and the
/// window belongs to the weekday it starts on.
nonisolated struct Schedule: Codable, Equatable, Sendable {
    /// `Calendar` weekday numbers: 1 is Sunday, 7 is Saturday.
    var weekdays: Set<Int> = []
    /// Minutes after midnight.
    var start = 9 * 60
    var end = 17 * 60

    /// The window that contains `now`, if there is one.
    func window(containing now: Date, calendar: Calendar) -> DateInterval? {
        let today = calendar.startOfDay(for: now)
        // A window crossing midnight may have started yesterday.
        for offset in [0, -1] {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  weekdays.contains(calendar.component(.weekday, from: day)),
                  let lastDay = calendar.date(byAdding: .day, value: end > start ? 0 : 1, to: day),
                  let opens = calendar.date(bySettingHour: start / 60, minute: start % 60, second: 0, of: day),
                  let closes = calendar.date(bySettingHour: end / 60, minute: end % 60, second: 0, of: lastDay)
            else { continue }
            if opens <= now && now < closes { return DateInterval(start: opens, end: closes) }
        }
        return nil
    }
}

/// A session started by hand, running until `end`.
nonisolated struct ManualRun: Codable, Equatable, Sendable {
    var sessionID: UUID
    var end: Date
}

/// A scheduled session ended early: its schedule is ignored until `until`,
/// the end of the window it was ended in.
nonisolated struct Suppression: Codable, Equatable, Sendable {
    var sessionID: UUID
    var until: Date
}

nonisolated enum Target: Sendable {
    case app(String)
    case url(URL)
}

nonisolated enum Verdict: Equatable, Sendable {
    case allowed
    case blocked(sessionID: UUID, goal: String)
}

nonisolated struct ActiveSession: Equatable, Identifiable, Sendable {
    var session: Session
    var end: Date
    var id: UUID { session.id }
}

nonisolated struct Policy: Codable, Equatable, Sendable {
    /// Never blocked, whatever a session lists: Locked itself, Finder, System Settings.
    static let neverBlocked: Set<String> = ["com.yagyaraj.locked", "com.apple.finder", "com.apple.systempreferences"]

    var sessions: [Session] = []
    var runs: [ManualRun] = []
    var suppressions: [Suppression] = []

    /// The sessions active at `now`, in saved order.
    func activeSessions(at now: Date, calendar: Calendar = .current) -> [ActiveSession] {
        sessions.compactMap { session in
            var ends = runs.filter { $0.sessionID == session.id && now < $0.end }.map(\.end)
            let suppressed = suppressions.contains { $0.sessionID == session.id && now < $0.until }
            if !suppressed, let window = session.schedule?.window(containing: now, calendar: calendar) {
                ends.append(window.end)
            }
            return ends.max().map { ActiveSession(session: session, end: $0) }
        }
    }

    func verdict(for target: Target, at now: Date, calendar: Calendar = .current) -> Verdict {
        for active in activeSessions(at: now, calendar: calendar) where active.session.blocks(target) {
            return .blocked(sessionID: active.session.id, goal: active.session.goal)
        }
        return .allowed
    }

    /// Starts a manual run, replacing any earlier one for the same session.
    mutating func start(_ sessionID: UUID, until end: Date) {
        runs.removeAll { $0.sessionID == sessionID }
        runs.append(ManualRun(sessionID: sessionID, end: end))
    }

    /// Ends a session now: drops its manual run and, if it is inside a scheduled
    /// window, keeps the schedule off until that window ends.
    mutating func endEarly(_ sessionID: UUID, at now: Date, calendar: Calendar = .current) {
        runs.removeAll { $0.sessionID == sessionID }
        suppressions.removeAll { $0.sessionID == sessionID }
        let schedule = sessions.first { $0.id == sessionID }?.schedule
        if let window = schedule?.window(containing: now, calendar: calendar) {
            suppressions.append(Suppression(sessionID: sessionID, until: window.end))
        }
    }
}

private nonisolated extension Session {
    func blocks(_ target: Target) -> Bool {
        switch target {
        case .app(let bundleID):
            !Policy.neverBlocked.contains(bundleID) && apps.contains(bundleID)
        case .url(let url):
            sites.contains { $0.matches(url) }
        }
    }
}
