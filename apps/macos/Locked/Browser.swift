import AppKit
import ApplicationServices

/// A browser whose front tab Locked can read and redirect. Any Chromium or Firefox-family
/// browser qualifies: it is recognised from its app bundle, so there is no list to keep up.
struct Browser: Identifiable, Hashable {
    /// The engine. Every kind is read and redirected through Accessibility, so one
    /// permission covers them all; the kind only decides how a redirect is confirmed.
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
        // Chromium: scriptable (which Electron apps are not), and carries Chromium's resource pack in its framework.
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

    /// One Accessibility permission for Locked covers every browser.
    static var permissionGranted: Bool { AXIsProcessTrusted() }

    static let permissionPane = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!

    /// Shows macOS's own prompt. It has no answer to wait for: it points at System
    /// Settings, and the caller polls `permissionGranted`.
    static func requestPermission() {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    // MARK: Reading and redirecting

    private var pid: pid_t {
        NSRunningApplication.runningApplications(withBundleIdentifier: id).first?.processIdentifier ?? 0
    }

    /// The URL of the front tab; `nil` when there is no window, no page, or no permission.
    /// Chromium puts it on the window (`AXDocument`); otherwise it is the web area's `AXURL`,
    /// else the address bar's text.
    func frontURL() async -> URL? { await Self.read(pid: pid) }

    // Off the main thread: a busy browser can take its time answering.
    @concurrent private static func read(pid: pid_t) async -> URL? {
        guard pid != 0, let window = window(pid) else { return nil }
        if let document = attribute(window, kAXDocumentAttribute) as? String, let url = URL(string: document) { return url }
        if let area = find(window, depth: 16, where: { role($0) == "AXWebArea" && attribute($0, "AXURL") != nil }),
           let url = attribute(area, "AXURL") as? URL { return url }
        guard let bar = addressBar(in: window), let text = attribute(bar, kAXValueAttribute) as? String,
              !text.isEmpty else { return nil }
        // Browsers hide the scheme in the bar.
        return URL(string: text.contains("://") ? text : "https://" + text)
    }

    /// Sends the front tab to something that shows `goal`, by typing an address into the
    /// address bar. Tried on 2026-11-16: Chrome takes the bundled block page; Safari takes
    /// `about:blank` but not a file address, so the caller covers it with the block screen.
    /// Gecko is untested (none was installed) and treated like Safari.
    func redirect(showing goal: String) async -> Redirect {
        var address = "about:blank"
        if kind == .chromium, let bundled = Bundle.main.url(forResource: "block", withExtension: "html") {
            let page = Backdrop.page(bundled: bundled)
            address = page.absoluteString + "#" + (goal.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "")
        }
        // Chromium's bar reports a confirm as done without navigating, so it gets a Return.
        await Self.navigate(pid: pid, to: address, pressReturn: kind == .chromium)
        return address == "about:blank" ? .needsBlockScreen : .blockPage
    }

    @concurrent private static func navigate(pid: pid_t, to address: String, pressReturn: Bool) async {
        guard pid != 0, let window = window(pid), let bar = addressBar(in: window) else { return }
        AXUIElementSetAttributeValue(bar, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(bar, kAXValueAttribute as CFString, address as CFString)
        if pressReturn {
            for down in [true, false] { CGEvent(keyboardEventSource: nil, virtualKey: 36, keyDown: down)?.postToPid(pid) }
        } else {
            AXUIElementPerformAction(bar, kAXConfirmAction as CFString)
        }
    }

    // MARK: Accessibility

    nonisolated private static func window(_ pid: pid_t) -> AXUIElement? {
        let app = AXUIElementCreateApplication(pid)
        // Chromium and Gecko build their accessibility tree only for a client that asks.
        AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        return attribute(app, kAXFocusedWindowAttribute).map { $0 as! AXUIElement }
    }

    // The address bar is the first text field in the window's toolbar, whatever the language.
    nonisolated private static func addressBar(in window: AXUIElement) -> AXUIElement? {
        find(window, depth: 12) { role($0) == "AXTextField" && attribute($0, kAXValueAttribute) is String }
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
