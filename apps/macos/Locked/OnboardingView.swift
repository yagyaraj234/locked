import SwiftUI

/// First-run setup: one question per screen, ending in a first session and the every-session block list.
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State var step = 0
    @State private var line = 0
    @State private var goal = ""
    @State private var picked: Set<String> = []
    /// Apps and sites added by hand, on top of the picked kinds.
    @State private var extra = BlockList()
    @State private var newSite = ""
    @State private var when = When.work
    @FocusState private var goalFocused: Bool
    /// Supported browsers installed here; one Accessibility permission covers them all.
    @State private var browsers = Browser.installed
    @State private var granted = Browser.permissionGranted

    private static let lastStep = 5
    private static let intro = ["Some apps are easy to open and hard to leave.", "Locked keeps them shut while you work."]

    /// Everything the answers block: the picked kinds, then anything added by hand.
    private var list: BlockList {
        var list = extra
        for kind in Distraction.all where picked.contains(kind.name) {
            list.apps += kind.apps.filter { !list.apps.contains($0) }
            list.sites += kind.sites.filter { !list.sites.contains($0) }
        }
        return list
    }

    private var blockedSummary: String {
        let list = list
        if list.apps.isEmpty && list.sites.isEmpty { return "Pick at least one." }
        let sites = list.sites.isEmpty ? nil : "\(list.sites.count) site\(list.sites.count == 1 ? "" : "s")"
        let apps = list.apps.isEmpty ? nil : "\(list.apps.count) app\(list.apps.count == 1 ? "" : "s")"
        return [sites, apps].compactMap(\.self).joined(separator: " and ")
    }

    private var canContinue: Bool {
        switch step {
        case 1: !goal.trimmingCharacters(in: .whitespaces).isEmpty
        case 2: !list.apps.isEmpty || !list.sites.isEmpty
        // No session is created until Locked can actually see the browsers.
        case 4: list.sites.isEmpty || browsers.isEmpty || granted
        default: true
        }
    }

    var body: some View {
        ZStack {
            // Under the title bar too, or that strip stays its own colour.
            Color(red: 0.05, green: 0.06, blue: 0.08).ignoresSafeArea()
            RadialGradient(colors: [Color.accentColor.opacity(0.38), .clear], center: .top, startRadius: 0, endRadius: 420)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Open until the last screen, where it clicks shut.
                Image(systemName: step == Self.lastStep ? "lock.fill" : "lock.open.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.tint)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(height: 40)
                    .padding(.top, 60)
                    .accessibilityHidden(true)

                Group {
                    switch step {
                    case 0: introStep
                    case 1: goalStep
                    case 2: distractionStep
                    case 3: whenStep
                    case 4: permissionStep
                    default: summaryStep
                    }
                }
                .id(step)
                .transition(.asymmetric(
                    insertion: reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 12)),
                    removal: .opacity.animation(.easeOut(duration: 0.12))
                ))
                .frame(maxWidth: 540, maxHeight: .infinity)

                footer
            }
        }
        .frame(width: 760, height: 580)
        .contentShape(Rectangle())
        .onTapGesture { if step == 0 { advance() } }
        .environment(\.colorScheme, .dark)
    }

    private var footer: some View {
        ZStack {
            if step == 0 {
                Text("Click anywhere or press Return").font(.callout).foregroundStyle(.tertiary)
            }
            HStack {
                Button(step == 0 ? "Skip Setup" : "Back") {
                    if step == 0 { model.finishOnboarding(session: nil) } else { go(-1) }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                Spacer()
                Button(step == Self.lastStep ? "Finish" : "Continue", action: advance)
                    .buttonStyle(PillStyle())
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canContinue)
            }
        }
        .padding(24)
    }

    private func advance() {
        guard canContinue else { return }
        if step == 0, line < Self.intro.count - 1 {
            withAnimation(.easeOut(duration: 0.3)) { line += 1 }
        } else if step < Self.lastStep {
            go(1)
        } else {
            model.finishOnboarding(session: Session(name: when.name, goal: goal, schedule: when.schedule), list: list)
        }
    }

    private func go(_ delta: Int) {
        // Critically damped: it was a click, not a throw, so nothing should overshoot.
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(duration: 0.4, bounce: 0)) { step += delta }
    }

    // MARK: Steps

    private var introStep: some View {
        Text(Self.intro[line])
            .font(.system(size: 28, weight: .semibold))
            .tracking(-0.4)
            .multilineTextAlignment(.center)
            .id(line)
            .transition(.opacity)
    }

    private var goalStep: some View {
        VStack(spacing: 28) {
            question("What do you want to get done?", "Locked shows you this whenever it blocks something.")
            VStack(spacing: 10) {
                TextField("Your goal", text: $goal, prompt: Text("Finish the report"))
                    .textFieldStyle(.plain)
                    .font(.system(size: 24, weight: .medium))
                    .multilineTextAlignment(.center)
                    .focused($goalFocused)
                    .onAppear { goalFocused = true }
                Rectangle().fill(.tint.opacity(goalFocused ? 0.9 : 0.3)).frame(height: 2)
            }
            .frame(width: 400)
        }
    }

    private var distractionStep: some View {
        VStack(spacing: 22) {
            question("What pulls you away?", "Pick all that apply. You can fine-tune the list in Settings.")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(Distraction.all, id: \.name) { kind in
                    let isOn = picked.contains(kind.name)
                    Button {
                        if isOn { picked.remove(kind.name) } else { picked.insert(kind.name) }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: kind.symbol).font(.title3).frame(width: 24)
                            Text(kind.name).font(.headline)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 52)
                    }
                    .buttonStyle(CardStyle(isOn: isOn))
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
            HStack(spacing: 10) {
                Button("Add an App…") { extra.apps += chooseApps().filter { !extra.apps.contains($0) } }
                TextField("Add a site", text: $newSite, prompt: Text("Or a site, like twitch.tv"))
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addSite)
            }
            VStack(spacing: 10) {
                Text(blockedSummary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                blockedChips
            }
            .animation(.easeOut(duration: 0.2), value: list)
        }
    }

    /// Exactly what the answers block: each app by icon and name, each site by address.
    private var blockedChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(list.apps, id: \.self) { app in
                    HStack(spacing: 5) {
                        Image(nsImage: icon(of: app)).resizable().frame(width: 18, height: 18)
                        Text(appName(app))
                    }
                    .modifier(Chip())
                }
                ForEach(list.sites, id: \.self) { site in
                    Text(site.text).modifier(Chip())
                }
            }
        }
        .frame(height: 28)
    }

    private var whenStep: some View {
        VStack(spacing: 22) {
            question("When should it lock?", "You can change the hours later.")
            VStack(spacing: 10) {
                ForEach(When.allCases, id: \.self) { option in
                    Button { when = option } label: {
                        HStack(spacing: 14) {
                            Image(systemName: option.symbol).font(.title3).frame(width: 26)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.title).font(.headline)
                                Text(option.detail).font(.callout).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 60)
                    }
                    .buttonStyle(CardStyle(isOn: when == option))
                    .accessibilityAddTraits(when == option ? .isSelected : [])
                }
            }
            .frame(width: 420)
        }
    }

    private var permissionStep: some View {
        VStack(spacing: 22) {
            question("Let Locked see your browsers.", browsers.isEmpty
                     ? "No supported browser found, so there is nothing to allow."
                     : "Locked reads the address of the front tab to block sites. One permission covers every browser.")
            if !browsers.isEmpty {
                HStack(spacing: 14) {
                    HStack(spacing: -8) {
                        ForEach(browsers.prefix(4)) { Image(nsImage: icon(of: $0.id)).resizable().frame(width: 28, height: 28) }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Accessibility").font(.headline)
                        Text(browsers.map(\.name).joined(separator: ", ")).font(.callout).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    if granted {
                        Label("Allowed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                            .transition(reduceMotion ? .opacity : .scale(scale: 0.9).combined(with: .opacity))
                    } else {
                        Button("Allow") { Browser.requestPermission() }
                    }
                }
                .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(duration: 0.4, bounce: 0.2), value: granted)
                .padding(.horizontal, 16)
                .frame(height: 56)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .frame(width: 420)
            }
        }
        // Granting happens in System Settings, so look again each second.
        .task {
            while !Task.isCancelled {
                granted = Browser.permissionGranted
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func icon(of bundleID: String) -> NSImage {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
            .map { NSWorkspace.shared.icon(forFile: $0.path) } ?? NSImage()
    }

    private var summaryStep: some View {
        VStack(spacing: 24) {
            question("You're set.", when.schedule == nil
                     ? "Start it from the lock in your menu bar."
                     : "Locked waits in your menu bar and locks on schedule.")
            VStack(spacing: 0) {
                row("Your goal", goal)
                Divider()
                row("Stays shut", blockedSummary)
                Divider()
                row("Locks", when.schedule == nil ? when.title : when.detail)
            }
            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .frame(width: 420)
        }
    }

    // MARK: Pieces

    private func question(_ title: String, _ detail: String) -> some View {
        VStack(spacing: 8) {
            // Large type reads too loose at default spacing, so it is pulled in slightly.
            Text(title).font(.system(size: 30, weight: .bold)).tracking(-0.5)
            Text(detail).font(.title3).foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.semibold).lineLimit(1)
        }
        .padding(.horizontal, 16)
        .frame(height: 46)
    }

    private func addSite() {
        guard let rule = SiteRule(parsing: newSite) else { return }
        if !extra.sites.contains(rule) { extra.sites.append(rule) }
        newSite = ""
    }
}

// MARK: - Answers

/// A kind of distraction and what picking it blocks. Apps are only blocked if installed.
private struct Distraction {
    let name: String
    let symbol: String
    let sites: [SiteRule]
    let apps: [String]

    init(_ name: String, _ symbol: String, sites: [String], apps: [String] = []) {
        self.name = name
        self.symbol = symbol
        self.sites = sites.compactMap(SiteRule.init(parsing:))
        self.apps = apps.filter { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil }
    }

    // ponytail: a short hand-picked list, not a maintained catalogue; anything missing is added by hand.
    static let all = [
        Distraction("Social", "bubble.left.and.bubble.right",
                    sites: ["x.com", "twitter.com", "instagram.com", "facebook.com", "reddit.com", "tiktok.com", "threads.net", "linkedin.com"]),
        Distraction("Video", "play.rectangle",
                    sites: ["youtube.com", "netflix.com", "twitch.tv", "primevideo.com", "hotstar.com"], apps: ["com.apple.TV"]),
        Distraction("News", "newspaper",
                    sites: ["news.google.com", "news.ycombinator.com", "nytimes.com", "bbc.com", "cnn.com"], apps: ["com.apple.news"]),
        Distraction("Games", "gamecontroller",
                    sites: ["store.steampowered.com", "epicgames.com", "chess.com"],
                    apps: ["com.valvesoftware.steam", "com.apple.Chess"]),
        Distraction("Shopping", "cart", sites: ["amazon.com", "amazon.in", "flipkart.com", "ebay.com"]),
        Distraction("Chat", "message",
                    sites: ["web.whatsapp.com", "discord.com", "web.telegram.org"],
                    apps: ["com.hnc.Discord", "net.whatsapp.WhatsApp", "ru.keepcoder.Telegram", "com.apple.MobileSMS"]),
    ]
}

private enum When: CaseIterable {
    case work, evenings, manual

    var name: String {
        switch self {
        case .work: "Work hours"
        case .evenings: "Evenings"
        case .manual: "Focus"
        }
    }

    var title: String { self == .manual ? "Only when I start it" : name }

    var detail: String {
        switch self {
        case .work: "Monday to Friday, 9 am to 5 pm"
        case .evenings: "Every day, 8 pm to 11 pm"
        case .manual: "From the menu bar, for as long as I pick"
        }
    }

    var symbol: String {
        switch self {
        case .work: "briefcase"
        case .evenings: "moon"
        case .manual: "hand.tap"
        }
    }

    var schedule: Schedule? {
        switch self {
        case .work: Schedule(weekdays: [2, 3, 4, 5, 6], start: 9 * 60, end: 17 * 60)
        case .evenings: Schedule(weekdays: Set(1...7), start: 20 * 60, end: 23 * 60)
        case .manual: nil
        }
    }
}

// MARK: - Controls

/// A selectable card: tinted and outlined when on. Answers the press on the way down.
private struct CardStyle: ButtonStyle {
    let isOn: Bool
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        configuration.label
            .background(isOn ? AnyShapeStyle(.tint.opacity(0.22)) : AnyShapeStyle(.white.opacity(hovering ? 0.11 : 0.07)), in: shape)
            .overlay { shape.strokeBorder(.tint, lineWidth: 2).opacity(isOn ? 1 : 0) }
            .contentShape(shape)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.15), value: isOn)
            .animation(.easeOut(duration: 0.12), value: hovering)
            .onHover { hovering = $0 }
    }
}

private struct Chip: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.callout)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .frame(height: 26)
            .background(.white.opacity(0.09), in: Capsule())
    }
}

struct PillStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.black)
            .padding(.horizontal, 22)
            .frame(height: 38)
            .background(.white.opacity(isEnabled ? 1 : 0.3), in: Capsule())
            .animation(.easeOut(duration: 0.15), value: isEnabled)
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
