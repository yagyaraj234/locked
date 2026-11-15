import SwiftUI

/// First-run setup: three questions that produce a first session and the every-session block list.
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var step = 0
    @State private var session = Session(name: "Focus")
    @State private var list = BlockList()

    /// Common distractions offered as one-click picks. Apps are only offered if installed.
    private static let suggestedApps = [
        "com.hnc.Discord", "net.whatsapp.WhatsApp", "ru.keepcoder.Telegram", "com.apple.MobileSMS",
        "com.tinyspeck.slackmacgap", "com.apple.mail", "com.valvesoftware.steam", "com.apple.TV",
    ].filter { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil }
    private static let suggestedSites = [
        "youtube.com", "x.com", "instagram.com", "facebook.com", "reddit.com", "tiktok.com", "netflix.com", "linkedin.com",
    ].compactMap(SiteRule.init(parsing:))

    var body: some View {
        VStack(spacing: 0) {
            Form {
                switch step {
                case 0:
                    Section {
                        TextField("Goal", text: $session.goal, prompt: Text("Finish the report"))
                        TextField("Session name", text: $session.name)
                    } header: {
                        question("What do you want to get done?", "Locked shows you this goal whenever it blocks something.")
                    }
                case 1:
                    Section {
                        picks(Self.suggestedApps, in: $list.apps, title: appName)
                        picks(Self.suggestedSites, in: $list.sites, title: \.text)
                    } header: {
                        question("What gets in your way?", "These are blocked in every session. Pick from the common ones or add your own below.")
                    }
                    BlockListSections(apps: $list.apps, sites: $list.sites)
                default:
                    Section {} header: {
                        question("When should it run?", "Repeat it weekly, or leave this off and start it yourself from the menu bar.")
                    }
                    ScheduleSection(schedule: $session.schedule)
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Skip Setup") { model.finishOnboarding(session: nil) }
                Spacer()
                if step > 0 { Button("Back") { step -= 1 } }
                Button(step < 2 ? "Continue" : "Finish") {
                    if step < 2 { step += 1 } else { model.finishOnboarding(session: session, list: list) }
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 520, height: 560)
    }

    private func question(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.title2.bold()).foregroundStyle(.primary)
            Text(detail)
        }
        .textCase(nil)
        .padding(.bottom, 4)
    }

    /// A wrapping row of toggle buttons; each adds its item to `selection` or takes it out.
    private func picks<Item: Hashable>(_ items: [Item], in selection: Binding<[Item]>, title: @escaping (Item) -> String) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], alignment: .leading) {
            ForEach(items, id: \.self) { item in
                Toggle(title(item), isOn: Binding { selection.wrappedValue.contains(item) } set: { on in
                    if on { selection.wrappedValue.append(item) } else { selection.wrappedValue.removeAll { $0 == item } }
                })
                .toggleStyle(.button)
            }
        }
    }
}
