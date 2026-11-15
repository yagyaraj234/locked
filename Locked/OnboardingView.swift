import SwiftUI

/// First-run setup: three questions that produce a first session and the every-session block list.
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State var step = 0
    @State private var forward = true
    @State private var session = Session(name: "Focus")
    @State private var list = BlockList()
    @State private var newSite = ""
    @State private var tilesShown = false
    @FocusState private var goalFocused: Bool

    private static let lastStep = 2
    private static let goalIdeas = ["Ship the feature", "Study for the exam", "Write for an hour", "Sleep on time"]
    /// Common distractions offered as one-click picks. Apps are only offered if installed.
    private static let suggestedApps = [
        "com.hnc.Discord", "net.whatsapp.WhatsApp", "ru.keepcoder.Telegram", "com.apple.MobileSMS",
        "com.tinyspeck.slackmacgap", "com.apple.mail", "com.spotify.client", "com.apple.Music",
        "com.apple.TV", "com.apple.news", "com.valvesoftware.steam", "org.whispersystems.signal-desktop",
    ].filter { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil }
    private static let suggestedSites = [
        "youtube.com", "x.com", "instagram.com", "facebook.com", "reddit.com", "tiktok.com", "netflix.com", "linkedin.com",
    ].compactMap(SiteRule.init(parsing:))

    var body: some View {
        VStack(spacing: 0) {
            // The picture stays put while the questions change under it.
            OnboardingStage(step: step, session: session, list: list)
                .padding(.horizontal, 40)
                .padding(.top, 44)

            ZStack(alignment: .top) {
                Group {
                    switch step {
                    case 0: goalStep
                    case 1: blockStep
                    default: scheduleStep
                    }
                }
                .id(step)
                // Arrives from the side it was asked for; leaves faster than it came.
                .transition(.asymmetric(
                    insertion: reduceMotion ? .opacity : .opacity.combined(with: .offset(x: forward ? 24 : -24)),
                    removal: .opacity.animation(.easeOut(duration: 0.12))
                ))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            Divider()
            ZStack {
                progress
                HStack {
                    Button("Skip Setup") { model.finishOnboarding(session: nil) }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if step > 0 {
                        Button("Back") { go(-1) }
                    }
                    Button(step < Self.lastStep ? "Continue" : "Finish") {
                        if step < Self.lastStep { go(1) } else { model.finishOnboarding(session: session, list: list) }
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(step == 0 && session.goal.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .controlSize(.large)
            .padding(20)
        }
        .frame(width: 640, height: 660)
    }

    private func go(_ delta: Int) {
        forward = delta > 0
        // Critically damped: it was a click, not a throw, so nothing should overshoot.
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(duration: 0.35, bounce: 0)) { step += delta }
    }

    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(0...Self.lastStep, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
                    .frame(width: index == step ? 22 : 7, height: 7)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Step \(step + 1) of \(Self.lastStep + 1)")
    }

    // MARK: Steps

    private var goalStep: some View {
        VStack(spacing: 18) {
            header("What do you want to get done?", "Locked puts this in front of you whenever it blocks something.")
            TextField("Your goal", text: $session.goal, prompt: Text("Finish the report"))
                .textFieldStyle(.plain)
                .font(.title2)
                .multilineTextAlignment(.center)
                .padding(14)
                .background(.quinary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .focused($goalFocused)
                .onAppear { goalFocused = true }
            HStack(spacing: 8) {
                ForEach(Self.goalIdeas, id: \.self) { idea in
                    Button(idea) { session.goal = idea }
                        .buttonStyle(ChipStyle())
                }
            }
            LabeledContent("Session name") {
                TextField("Session name", text: $session.name)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
            }
            .foregroundStyle(.secondary)
            .padding(.top, 10)
        }
        .padding(.horizontal, 56)
    }

    private var blockStep: some View {
        // Suggestions first, then anything added by hand, so every pick stays visible.
        let apps = Self.suggestedApps + list.apps.filter { !Self.suggestedApps.contains($0) }
        let sites = Self.suggestedSites + list.sites.filter { !Self.suggestedSites.contains($0) }
        return VStack(spacing: 14) {
            header("What gets in your way?", "Blocked in every session. You can change this later in Settings.")
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Apps").font(.headline)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10)], spacing: 10) {
                        ForEach(Array(apps.enumerated()), id: \.element) { index, bundleID in
                            Tile(isOn: picked(bundleID, in: $list.apps)) {
                                appTile { Image(nsImage: appIcon(bundleID)).resizable() } title: { appName(bundleID) }
                            }
                            .staggered(index, shown: tilesShown, reduceMotion: reduceMotion)
                        }
                        Button {
                            list.apps += chooseApps().filter { !list.apps.contains($0) }
                        } label: {
                            appTile { Image(systemName: "plus").font(.title2) } title: { "Other…" }
                                .background(.quinary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel("Add other apps")
                        .staggered(apps.count, shown: tilesShown, reduceMotion: reduceMotion)
                    }

                    Text("Sites").font(.headline).padding(.top, 8)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                        ForEach(Array(sites.enumerated()), id: \.element) { index, rule in
                            Tile(isOn: picked(rule, in: $list.sites)) {
                                Text(rule.text).lineLimit(1).frame(maxWidth: .infinity).padding(.vertical, 9)
                            }
                            .staggered(apps.count + 1 + index, shown: tilesShown, reduceMotion: reduceMotion)
                        }
                    }
                    HStack {
                        TextField("Add a site", text: $newSite, prompt: Text("Another site, like twitch.tv"))
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(addSite)
                        Button("Add", action: addSite).disabled(SiteRule(parsing: newSite) == nil)
                    }
                    .padding(.top, 2)
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 4)
            }
        }
        .onAppear { tilesShown = true }
        .onDisappear { tilesShown = false }
    }

    private var scheduleStep: some View {
        VStack(spacing: 18) {
            header("When should it run?", "A schedule starts and stops the session for you.")
            HStack(spacing: 12) {
                Tile(isOn: Binding { session.schedule != nil } set: { _ in
                    session.schedule = session.schedule ?? Schedule(weekdays: [2, 3, 4, 5, 6])
                }) {
                    choice("clock.arrow.2.circlepath", "On a schedule", "The same hours each week")
                }
                Tile(isOn: Binding { session.schedule == nil } set: { _ in session.schedule = nil }) {
                    choice("hand.tap", "When I start it", "From the menu bar, for as long as I pick")
                }
            }
            if let schedule = Binding($session.schedule) {
                VStack(spacing: 14) {
                    HStack(spacing: 8) {
                        ForEach(1...7, id: \.self) { weekday in
                            let isOn = schedule.wrappedValue.weekdays.contains(weekday)
                            Button {
                                if isOn { schedule.wrappedValue.weekdays.remove(weekday) } else { schedule.wrappedValue.weekdays.insert(weekday) }
                            } label: {
                                Text(Calendar.current.veryShortWeekdaySymbols[weekday - 1])
                                    .fontWeight(.semibold)
                                    .foregroundStyle(isOn ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                                    .frame(width: 38, height: 38)
                                    .background(isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(.quinary), in: Circle())
                                    .contentShape(Circle())
                            }
                            .buttonStyle(PressableStyle())
                            .accessibilityLabel(Calendar.current.weekdaySymbols[weekday - 1])
                            .accessibilityAddTraits(isOn ? .isSelected : [])
                        }
                    }
                    HStack {
                        Text("From")
                        DatePicker("Starts", selection: time(schedule.start), displayedComponents: .hourAndMinute)
                        Text("to")
                        DatePicker("Ends", selection: time(schedule.end), displayedComponents: .hourAndMinute)
                    }
                    .labelsHidden()
                    if schedule.wrappedValue.weekdays.isEmpty {
                        Text("Pick at least one day, or it will never start.").font(.callout).foregroundStyle(.orange)
                    } else if schedule.wrappedValue.end <= schedule.wrappedValue.start {
                        Text("Ends the next morning.").font(.callout).foregroundStyle(.secondary)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity)
                .background(.quinary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 56)
        .animation(.easeOut(duration: 0.2), value: session.schedule == nil)
    }

    // MARK: Pieces

    private func header(_ title: String, _ detail: String) -> some View {
        VStack(spacing: 6) {
            // Large type reads too loose at default spacing, so it is pulled in slightly.
            Text(title).font(.system(size: 26, weight: .bold)).tracking(-0.4)
            Text(detail).foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(.top, 22)
    }

    private func appTile(@ViewBuilder icon: () -> some View, title: () -> String) -> some View {
        VStack(spacing: 6) {
            icon().frame(width: 44, height: 44)
            Text(title()).font(.caption).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private func choice(_ symbol: String, _ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol).font(.title2).foregroundStyle(.tint)
            Text(title).font(.headline)
            Text(detail).font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }

    private func picked<Item: Equatable>(_ item: Item, in selection: Binding<[Item]>) -> Binding<Bool> {
        Binding { selection.wrappedValue.contains(item) } set: { on in
            if on { selection.wrappedValue.append(item) } else { selection.wrappedValue.removeAll { $0 == item } }
        }
    }

    private func addSite() {
        guard let rule = SiteRule(parsing: newSite) else { return }
        if !list.sites.contains(rule) { list.sites.append(rule) }
        newSite = ""
    }
}

// MARK: - Controls

/// Answers the press itself, on the way down, so the click feels heard.
private struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct ChipStyle: ButtonStyle {
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.primary.opacity(hovering ? 0.1 : 0.05), in: Capsule())
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: hovering)
            .onHover { hovering = $0 }
    }
}

/// A selectable card: tinted, outlined and ticked when on.
private struct Tile<Label: View>: View {
    @Binding var isOn: Bool
    @ViewBuilder var label: Label
    @State private var hovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        Button { isOn.toggle() } label: {
            label
                .background(isOn ? AnyShapeStyle(.tint.opacity(0.16)) : AnyShapeStyle(.primary.opacity(hovering ? 0.09 : 0.05)), in: shape)
                .overlay { shape.strokeBorder(.tint, lineWidth: 2).opacity(isOn ? 1 : 0) }
                .overlay(alignment: .topTrailing) {
                    if isOn {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white, .tint)
                            .padding(6)
                            // From nearly full size: nothing real pops out of a point.
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                    }
                }
                .contentShape(shape)
                .contentShape(.focusEffect, shape)
        }
        .buttonStyle(PressableStyle())
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: isOn)
        .animation(.easeOut(duration: 0.12), value: hovering)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

private extension View {
    /// Tiles arrive one after another, 30 ms apart, instead of all at once.
    func staggered(_ index: Int, shown: Bool, reduceMotion: Bool) -> some View {
        opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 8)
            .animation(.easeOut(duration: 0.25).delay(Double(min(index, 14)) * 0.03), value: shown)
    }
}

// MARK: - Stage

/// A miniature of the Mac, drawn from the answers so far, showing what each one will do.
/// Only the answers are real words; everything else is placeholder bars.
private struct OnboardingStage: View {
    let step: Int
    let session: Session
    let list: BlockList
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var blocked = false

    private static let height: CGFloat = 150
    private static let menuBar: CGFloat = 16
    private static let sceneHeight = height - menuBar

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        ZStack(alignment: .top) {
            LinearGradient(colors: [Color.accentColor.opacity(0.42), Color.accentColor.opacity(0.14)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Group {
                switch step {
                case 0: goalScene
                case 1: blockScene
                default: scheduleScene
                }
            }
            // A fixed box: the windows inside are taller on purpose and must be cut, not push the stage up.
            .frame(height: Self.sceneHeight, alignment: .top)
            .clipped()
            .padding(.top, Self.menuBar)
            .transition(.opacity)
            menuBarStrip
        }
        .frame(height: Self.height)
        .clipShape(shape)
        .overlay { shape.strokeBorder(.primary.opacity(0.1)) }
        .accessibilityHidden(true)
    }

    private func bar(_ width: CGFloat, opacity: Double = 0.22) -> some View {
        Capsule().fill(.primary.opacity(opacity)).frame(width: width, height: 4)
    }

    private var menuBarStrip: some View {
        HStack(spacing: 8) {
            bar(14, opacity: 0.4); bar(22); bar(18); bar(24)
            Spacer()
            Image(systemName: step == 0 && blocked ? "lock.fill" : "lock.open.fill").font(.system(size: 8, weight: .bold))
            bar(28)
        }
        .padding(.horizontal, 10)
        .frame(height: Self.menuBar)
        .background(.ultraThinMaterial)
    }

    /// A placeholder app window, taller than the stage so its foot is cut off rather than floating.
    private func window(width: CGFloat, @ViewBuilder top: () -> some View = { EmptyView() }) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in Circle().fill(.quaternary).frame(width: 6, height: 6) }
                top().padding(.leading, 4)
            }
            .frame(height: 18)
            bar(width * 0.55, opacity: 0.3); bar(width * 0.75); bar(width * 0.65); bar(width * 0.4); bar(width * 0.7)
        }
        .padding(10)
        .frame(width: width, height: 170, alignment: .topLeading)
        .background(.background, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        .padding(.top, 12)
    }

    /// A window is open; then Locked covers it with the goal being typed below.
    private var goalScene: some View {
        window(width: 300)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .overlay {
                if blocked {
                    VStack(spacing: 7) {
                        Image(systemName: "lock.fill").font(.system(size: 13)).foregroundStyle(.white.opacity(0.55))
                        Text(session.goal.isEmpty ? "Your goal" : session.goal)
                            .font(.system(size: 19, weight: .bold))
                            .tracking(-0.2)
                            .foregroundStyle(.white.opacity(session.goal.isEmpty ? 0.45 : 1))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .padding(.horizontal, 24)
                        Text("Back to work")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(.white.opacity(0.18), in: Capsule())
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(white: 0.07).opacity(0.8))
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 1.03)))
                }
            }
            .animation(.easeOut(duration: 0.15), value: session.goal)
            .task {
                // One thing happens: the screen is in use, then it is locked.
                try? await Task.sleep(for: .milliseconds(450))
                withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.45, bounce: 0)) { blocked = true }
            }
    }

    /// The picks land on the desktop with a lock on each: sites as browser tabs, apps in the Dock.
    private var blockScene: some View {
        window(width: 400) {
            HStack(spacing: 5) {
                if list.sites.isEmpty {
                    ForEach([58, 46, 64], id: \.self) { Capsule().fill(.primary.opacity(0.08)).frame(width: $0, height: 18) }
                }
                ForEach(list.sites.suffix(4), id: \.self) { rule in
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill").font(.system(size: 7, weight: .bold)).foregroundStyle(.tint)
                        Text(rule.text).font(.system(size: 9, weight: .medium)).lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 18)
                    .background(.primary.opacity(0.08), in: Capsule())
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.sceneHeight, alignment: .top)
        .overlay(alignment: .bottom) {
            HStack(spacing: 8) {
                if list.apps.isEmpty {
                    ForEach(0..<5, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 7, style: .continuous).fill(.primary.opacity(0.12)).frame(width: 30, height: 30)
                    }
                }
                ForEach(list.apps.suffix(8), id: \.self) { bundleID in
                    Image(nsImage: appIcon(bundleID))
                        .resizable()
                        .frame(width: 30, height: 30)
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 6, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 12, height: 12)
                                .background(.tint, in: Circle())
                                .offset(x: 3, y: 3)
                        }
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }
            .padding(7)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
            .padding(.bottom, 8)
        }
        .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(duration: 0.3, bounce: 0), value: list)
    }

    /// A week of days, each a 24-hour track, filled where the session runs.
    private var scheduleScene: some View {
        ZStack(alignment: .topTrailing) {
            if let schedule = session.schedule {
                let track: CGFloat = 92
                HStack(spacing: 14) {
                    ForEach(1...7, id: \.self) { weekday in
                        VStack(spacing: 5) {
                            ZStack(alignment: .top) {
                                RoundedRectangle(cornerRadius: 5, style: .continuous).fill(.background.opacity(0.55))
                                ForEach(Self.bands(schedule, on: weekday), id: \.self) { band in
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(.tint)
                                        .frame(height: max(3, CGFloat(band.upperBound - band.lowerBound) / 1440 * track))
                                        .offset(y: CGFloat(band.lowerBound) / 1440 * track)
                                }
                            }
                            .frame(width: 48, height: track)
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                            Text(Calendar.current.veryShortWeekdaySymbols[weekday - 1])
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
            } else {
                window(width: 300)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.leading, 36)
                    .transition(.opacity)
                // Hangs from the padlock in the menu bar, where it really opens.
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(session.name.isEmpty ? "Focus" : session.name).font(.system(size: 10, weight: .semibold)).lineLimit(1)
                        Spacer()
                        bar(26)
                    }
                    HStack(spacing: 6) {
                        Text("25 min").font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 8).frame(height: 18)
                            .background(.primary.opacity(0.08), in: Capsule())
                        Text("Start now").font(.system(size: 9, weight: .semibold)).foregroundStyle(.white)
                            .padding(.horizontal, 9).frame(height: 18)
                            .background(.tint, in: Capsule())
                    }
                }
                .padding(10)
                .frame(width: 170, alignment: .leading)
                .background(.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
                .padding(.top, 6)
                .padding(.trailing, 14)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(duration: 0.35, bounce: 0), value: session.schedule)
    }

    /// The minutes of `weekday` the schedule covers: its own window, plus any spill from the night before.
    private static func bands(_ schedule: Schedule, on weekday: Int) -> [Range<Int>] {
        let crossesMidnight = schedule.end <= schedule.start
        var bands: [Range<Int>] = []
        if schedule.weekdays.contains(weekday) {
            bands.append(schedule.start..<(crossesMidnight ? 1440 : schedule.end))
        }
        if crossesMidnight, schedule.end > 0, schedule.weekdays.contains(weekday == 1 ? 7 : weekday - 1) {
            bands.append(0..<schedule.end)
        }
        return bands
    }
}

func appIcon(_ bundleID: String) -> NSImage {
    NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID).map { NSWorkspace.shared.icon(forFile: $0.path) }
        ?? NSImage(named: NSImage.applicationIconName) ?? NSImage()
}
