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

/// Apps and sites blocked whenever any session is active, on top of that session's own lists.
nonisolated struct BlockList: Codable, Equatable, Sendable {
    /// Bundle identifiers.
    var apps: [String] = []
    var sites: [SiteRule] = []

    /// Adds what `other` lists and this one doesn't.
    mutating func add(_ other: BlockList) {
        apps += other.apps.filter { !apps.contains($0) }
        sites += other.sites.filter { !sites.contains($0) }
    }
}

/// A domain, optionally narrowed to a path prefix. Build one with `init(parsing:)`,
/// which is what keeps `domain` lowercase and free of scheme, port and `www.`.
nonisolated struct SiteRule: Codable, Hashable, Sendable {
    var domain: String
    /// Empty, or a path starting with "/".
    var pathPrefix: String

    var text: String { domain + pathPrefix }

    /// Reads what a person types: "youtube.com", "youtube.com/shorts", or a pasted address.
    /// Nil unless it is a plausible domain: dotted, no spaces, letters, digits and hyphens.
    init?(parsing input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains(where: \.isWhitespace) else { return nil }
        var rest = Substring(trimmed)
        if let scheme = rest.range(of: "://") { rest = rest[scheme.upperBound...] }
        rest = rest.prefix { $0 != "?" && $0 != "#" }
        let slash = rest.firstIndex(of: "/") ?? rest.endIndex
        let host = Self.normalized(host: rest[..<slash].prefix { $0 != ":" })
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2, labels.allSatisfy({ !$0.isEmpty }),
              host.allSatisfy({ $0 == "." || $0 == "-" || ($0.isASCII && ($0.isLetter || $0.isNumber)) })
        else { return nil }
        domain = host
        // "youtube.com/shorts/" is the same rule as "youtube.com/shorts".
        var path = String(rest[slash...])
        while path.hasSuffix("/") { path.removeLast() }
        // Browsers report paths percent-encoded, which is how `URL.path()` gives them.
        if !path.contains("%") { path = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path }
        pathPrefix = path
    }

    func matches(_ url: URL) -> Bool {
        guard let host = url.host().map(Self.normalized(host:)) else { return false }
        guard host == domain || host.hasSuffix("." + domain) else { return false }
        // Whole path segments only: "/shorts" covers "/shorts/abc" but not "/shortstories".
        let path = url.path()
        return pathPrefix.isEmpty || path == pathPrefix || path.hasPrefix(pathPrefix + "/")
    }

    private static func normalized(host: some StringProtocol) -> String {
        // "youtube.com." is the same site as "youtube.com", and browsers load it.
        var host = host.lowercased()
        if host.hasSuffix(".") { host.removeLast() }
        if host.hasPrefix("www.") { host = String(host.dropFirst(4)) }
        // Browsers report non-ASCII domains as punycode.
        return host.split(separator: ".", omittingEmptySubsequences: false).map { punycode(String($0)) }.joined(separator: ".")
    }

    /// RFC 3492, for one label.
    private static func punycode(_ label: String) -> String {
        let code = label.unicodeScalars.map { Int($0.value) }
        guard code.contains(where: { $0 >= 128 }) else { return label }
        var out = String(String.UnicodeScalarView(label.unicodeScalars.filter { $0.value < 128 }))
        let basic = out.count
        var handled = basic
        if basic > 0 { out += "-" }
        var n = 128, delta = 0, bias = 72
        func digit(_ d: Int) -> Character { Character(UnicodeScalar(UInt8(d < 26 ? 97 + d : 22 + d))) }
        while handled < code.count {
            let next = code.filter { $0 >= n }.min()!
            delta += (next - n) * (handled + 1)
            n = next
            for c in code {
                if c < n { delta += 1 }
                guard c == n else { continue }
                var q = delta, k = 36
                while true {
                    let t = k <= bias ? 1 : k >= bias + 26 ? 26 : k - bias
                    if q < t { break }
                    out.append(digit(t + (q - t) % (36 - t)))
                    q = (q - t) / (36 - t)
                    k += 36
                }
                out.append(digit(q))
                var d = handled == basic ? delta / 700 : delta / 2
                d += d / (handled + 1)
                var m = 0
                while d > 455 { d /= 35; m += 36 }
                bias = m + 36 * d / (d + 38)
                delta = 0
                handled += 1
            }
            delta += 1
            n += 1
        }
        return "xn--" + out
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
/// a short break, or the end of the window if that comes first.
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
    var everySession = BlockList()

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

    /// Sessions ended early that are on their break at `now`, each with when it comes back.
    /// A break is still part of the session: it stays locked against edits.
    func breaks(at now: Date) -> [Suppression] {
        suppressions.filter { now < $0.until }
    }

    func verdict(for target: Target, at now: Date, calendar: Calendar = .current) -> Verdict {
        let active = activeSessions(at: now, calendar: calendar)
        // A session that lists the target itself gives the goal, ahead of the every-session list.
        let own = active.first { blocks(target, apps: $0.session.apps, sites: $0.session.sites) }
        let always = blocks(target, apps: everySession.apps, sites: everySession.sites)
        guard let match = own ?? (always ? active.first : nil) else { return .allowed }
        return .blocked(sessionID: match.session.id, goal: match.session.goal)
    }

    /// Starts a manual run. Starting again can lengthen a run but never shorten it:
    /// the only way to end sooner is `endEarly`.
    mutating func start(_ sessionID: UUID, until end: Date) {
        let latest = runs.filter { $0.sessionID == sessionID }.map(\.end).max()
        runs.removeAll { $0.sessionID == sessionID }
        runs.append(ManualRun(sessionID: sessionID, end: max(end, latest ?? end)))
    }

    /// How long a scheduled session stays off after being ended early.
    static let breakLength: TimeInterval = 15 * 60

    /// Ends a session now: drops its manual run and, if it is inside a scheduled
    /// window, keeps the schedule off for a break (or until the window ends, if sooner).
    mutating func endEarly(_ sessionID: UUID, at now: Date, calendar: Calendar = .current) {
        runs.removeAll { $0.sessionID == sessionID }
        suppressions.removeAll { $0.sessionID == sessionID }
        let schedule = sessions.first { $0.id == sessionID }?.schedule
        if let window = schedule?.window(containing: now, calendar: calendar) {
            suppressions.append(Suppression(sessionID: sessionID, until: min(window.end, now.addingTimeInterval(Self.breakLength))))
        }
    }
}

nonisolated extension Policy {
    /// Written out so data saved before a field existed still loads: every field is optional on read.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessions = try container.decodeIfPresent([Session].self, forKey: .sessions) ?? []
        runs = try container.decodeIfPresent([ManualRun].self, forKey: .runs) ?? []
        suppressions = try container.decodeIfPresent([Suppression].self, forKey: .suppressions) ?? []
        everySession = try container.decodeIfPresent(BlockList.self, forKey: .everySession) ?? BlockList()
    }
}

nonisolated extension Session {
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        goal = try c.decodeIfPresent(String.self, forKey: .goal) ?? ""
        apps = try c.decodeIfPresent([String].self, forKey: .apps) ?? []
        sites = try c.decodeIfPresent([SiteRule].self, forKey: .sites) ?? []
        schedule = try c.decodeIfPresent(Schedule.self, forKey: .schedule)
    }
}

nonisolated extension BlockList {
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        apps = try c.decodeIfPresent([String].self, forKey: .apps) ?? []
        sites = try c.decodeIfPresent([SiteRule].self, forKey: .sites) ?? []
    }
}

nonisolated extension Schedule {
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        weekdays = try c.decodeIfPresent(Set<Int>.self, forKey: .weekdays) ?? []
        start = try c.decodeIfPresent(Int.self, forKey: .start) ?? 9 * 60
        end = try c.decodeIfPresent(Int.self, forKey: .end) ?? 17 * 60
    }
}

nonisolated extension SiteRule {
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        domain = try c.decode(String.self, forKey: .domain)
        pathPrefix = try c.decodeIfPresent(String.self, forKey: .pathPrefix) ?? ""
    }
}

private nonisolated func blocks(_ target: Target, apps: [String], sites: [SiteRule]) -> Bool {
    switch target {
    case .app(let bundleID):
        !Policy.neverBlocked.contains(bundleID) && apps.contains(bundleID)
    case .url(let url):
        sites.contains { $0.matches(url) }
    }
}
