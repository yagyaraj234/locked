import AppKit

/// The browsers whose front tab Locked can read and redirect through Apple Events.
enum Browser: String, CaseIterable, Identifiable {
    case safari = "com.apple.Safari"
    case chrome = "com.google.Chrome"
    case arc = "company.thebrowser.Browser"
    case brave = "com.brave.Browser"
    case edge = "com.microsoft.edgemac"

    enum Redirect { case blockPage, needsBlockScreen }

    var id: String { rawValue }
    var name: String { appName(rawValue) }

    /// Denied outright. An undecided permission isn't a warning: macOS asks on the first read.
    var automationDenied: Bool {
        let target = NSAppleEventDescriptor(bundleIdentifier: rawValue)
        return AEDeterminePermissionToAutomateTarget(target.aeDesc, typeWildCard, typeWildCard, false)
            == OSStatus(errAEEventNotPermitted)
    }

    private var tab: String { self == .safari ? "current tab of front window" : "active tab of front window" }

    /// The URL of the front tab; `nil` when there is no window, no page, or no permission.
    func frontURL() -> URL? {
        run("get URL of \(tab)").flatMap { URL(string: $0) }
    }

    /// Sends the front tab to something that shows `goal`.
    func redirect(showing goal: String) -> Redirect {
        // Safari refuses an Apple Events redirect to a file URL, so it gets a blank
        // tab and the caller covers it with the native block screen.
        guard self != .safari, let page = Bundle.main.url(forResource: "block", withExtension: "html") else {
            _ = run("set URL of \(tab) to \"about:blank\"")
            return .needsBlockScreen
        }
        // Percent-encoded, so the goal can't break out of the AppleScript string.
        let fragment = goal.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        _ = run("set URL of \(tab) to \"\(page.absoluteString)#\(fragment)\"")
        return .blockPage
    }

    // ponytail: compiles a script per call and blocks the main thread while the browser
    // answers (about once a second, only while a browser is in front). The timeout caps
    // that at a second for a hung browser. Move to a background actor with cached
    // scripts if even that stalls the UI.
    private func run(_ command: String) -> String? {
        var error: NSDictionary?
        let result = NSAppleScript(source: """
            with timeout of 1 second
            tell application id "\(rawValue)" to \(command)
            end timeout
            """)?
            .executeAndReturnError(&error)
        return error == nil ? result?.stringValue : nil
    }
}
