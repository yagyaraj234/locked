import AppKit
import ApplicationServices

/// A browser whose front tab Locked can read and redirect. Any Chromium or Firefox-family
/// browser qualifies: it is recognised from its app bundle, so there is no list to keep up.
struct Browser: Identifiable, Hashable {
    /// How the tab is reached. Safari and Chromium answer Apple Events; Gecko (Firefox, Zen,
    /// LibreWolf, Floorp…) has no scripting, so it is read through Accessibility.
    enum Kind { case safari, chromium, gecko }
    enum Redirect { case blockPage, needsBlockScreen }

    let id: String  // bundle identifier
    let kind: Kind
    var name: String { appName(id) }

    // Per bundle: the app bundle is inspected once, not every second.
    private static var known: [String: Browser?] = [:]

    static func of(_ bundleID: String) -> Browser? {
        if let cached = known[bundleID] { return cached }
        let browser = detect(bundleID)
        known[bundleID] = .some(browser)
        return browser
    }

    private static func detect(_ bundleID: String) -> Browser? {
        if bundleID == "com.apple.Safari" { return Browser(id: bundleID, kind: .safari) }
        guard let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let fm = FileManager.default
        let contents = app.appending(path: "Contents")
        if fm.fileExists(atPath: contents.appending(path: "MacOS/XUL").path) {
            return Browser(id: bundleID, kind: .gecko)
        }
        // Chromium: scriptable, and carries Chromium's resource pack in its framework.
        let frameworks = (try? fm.contentsOfDirectory(at: contents.appending(path: "Frameworks"), includingPropertiesForKeys: nil)) ?? []
        let scriptable = Bundle(url: app)?.object(forInfoDictionaryKey: "NSAppleScriptEnabled") as? Bool == true
        if scriptable, frameworks.contains(where: {
            fm.fileExists(atPath: $0.appending(path: "Resources/chrome_100_percent.pak").path)
        }) { return Browser(id: bundleID, kind: .chromium) }
        return nil
    }

    /// Every supported browser installed here: the apps that open web links.
    static var installed: [Browser] {
        let handlers = NSWorkspace.shared.urlsForApplications(toOpen: URL(string: "https://example.com")!)
        var seen = Set<String>()
        return handlers.compactMap { Bundle(url: $0)?.bundleIdentifier }
            .filter { seen.insert($0).inserted }
            .compactMap(of)
    }

    // MARK: Permission

    private var appleEventStatus: OSStatus {
        let target = NSAppleEventDescriptor(bundleIdentifier: id)
        return AEDeterminePermissionToAutomateTarget(target.aeDesc, typeWildCard, typeWildCard, false)
    }

    /// Denied outright. An undecided permission isn't a warning: macOS asks on the first read.
    var permissionDenied: Bool {
        kind == .gecko ? !AXIsProcessTrusted() : appleEventStatus == OSStatus(errAEEventNotPermitted)
    }

    /// Decided yes. A browser that isn't running can't be asked, so it counts as not yet.
    var permissionGranted: Bool {
        kind == .gecko ? AXIsProcessTrusted() : appleEventStatus == noErr
    }

    /// Opens the System Settings pane where the permission is granted.
    var permissionPane: URL {
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_" + (kind == .gecko ? "Accessibility" : "Automation"))!
    }

    /// Shows macOS's own prompt. An Automation prompt needs the browser running, so a closed
    /// one is opened out of sight first. Accessibility has no answer to wait for: the prompt
    /// points at System Settings, and the caller polls `permissionGranted`.
    func requestPermission() async {
        if kind == .gecko {
            _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
            return
        }
        if pid == 0, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = false
            configuration.hides = true
            _ = try? await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        }
        await askAppleEvents()
    }

    // Blocks until the prompt is answered, so never on the main thread.
    @concurrent private func askAppleEvents() async {
        let target = NSAppleEventDescriptor(bundleIdentifier: id)
        _ = AEDeterminePermissionToAutomateTarget(target.aeDesc, typeWildCard, typeWildCard, true)
    }

    // MARK: Reading and redirecting

    private var tab: String { kind == .safari ? "current tab of front window" : "active tab of front window" }

    /// The URL of the front tab; `nil` when there is no window, no page, or no permission.
    func frontURL() async -> URL? {
        if kind == .gecko { return await Self.geckoURL(pid: pid) }
        return await run("get URL of \(tab)").flatMap { URL(string: $0) }
    }

    /// Sends the front tab to something that shows `goal`.
    func redirect(showing goal: String) async -> Redirect {
        if kind == .gecko {
            await Self.geckoNavigate(pid: pid, to: "about:blank")
            return .needsBlockScreen
        }
        // Safari refuses an Apple Events redirect to a file URL, so it gets a blank
        // tab and the caller covers it with the native block screen.
        guard kind != .safari, let page = Bundle.main.url(forResource: "block", withExtension: "html") else {
            _ = await run("set URL of \(tab) to \"about:blank\"")
            return .needsBlockScreen
        }
        // Percent-encoded, so the goal can't break out of the AppleScript string.
        let fragment = goal.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        _ = await run("set URL of \(tab) to \"\(page.absoluteString)#\(fragment)\"")
        return .blockPage
    }

    private var pid: pid_t {
        NSRunningApplication.runningApplications(withBundleIdentifier: id).first?.processIdentifier ?? 0
    }

    // Off the main thread: the browser can take its time, and the first-use Automation
    // prompt holds the call until it is answered. The script is made and run in one go
    // because an NSAppleScript must stay on the thread that created it.
    // ponytail: compiles a script per call (about once a second, only while a browser
    // is in front). Cache compiled scripts on one dedicated thread if that ever shows up.
    @concurrent private func run(_ command: String) async -> String? {
        var error: NSDictionary?
        let result = NSAppleScript(source: """
            with timeout of 1 second
            tell application id "\(id)" to \(command)
            end timeout
            """)?
            .executeAndReturnError(&error)
        return error == nil ? result?.stringValue : nil
    }

    // MARK: Gecko, through Accessibility. Untested: no Firefox-family browser was installed.

    /// The page's address, from the web area (`AXURL`), else the address bar's text.
    @concurrent private static func geckoURL(pid: pid_t) async -> URL? {
        guard pid != 0, let window = geckoWindow(pid) else { return nil }
        if let area = find(window, depth: 12, where: { role($0) == "AXWebArea" && attribute($0, "AXURL") != nil }),
           let url = attribute(area, "AXURL") as? URL { return url }
        guard let bar = addressBar(in: window), let text = attribute(bar, kAXValueAttribute) as? String else { return nil }
        // Firefox hides the scheme in the bar.
        return URL(string: text.contains("://") ? text : "https://" + text)
    }

    /// Types `address` into the address bar and presses Return.
    @concurrent private static func geckoNavigate(pid: pid_t, to address: String) async {
        guard pid != 0, let window = geckoWindow(pid), let bar = addressBar(in: window) else { return }
        AXUIElementSetAttributeValue(bar, kAXValueAttribute as CFString, address as CFString)
        AXUIElementPerformAction(bar, kAXConfirmAction as CFString)
    }

    nonisolated private static func geckoWindow(_ pid: pid_t) -> AXUIElement? {
        let app = AXUIElementCreateApplication(pid)
        // Gecko builds its accessibility tree only for a client that asks.
        AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        return attribute(app, kAXFocusedWindowAttribute).map { $0 as! AXUIElement }
    }

    // The address bar is the first text field in the window's toolbar, whatever the language.
    nonisolated private static func addressBar(in window: AXUIElement) -> AXUIElement? {
        find(window, depth: 6) { role($0) == "AXTextField" && attribute($0, kAXValueAttribute) is String }
    }

    nonisolated private static func role(_ element: AXUIElement) -> String? { attribute(element, kAXRoleAttribute) as? String }

    nonisolated private static func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
        var value: AnyObject?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }

    nonisolated private static func find(_ element: AXUIElement, depth: Int, where match: (AXUIElement) -> Bool) -> AXUIElement? {
        if match(element) { return element }
        guard depth > 0, let children = attribute(element, kAXChildrenAttribute) as? [AXUIElement] else { return nil }
        for child in children { if let hit = find(child, depth: depth - 1, where: match) { return hit } }
        return nil
    }
}
