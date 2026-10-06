import AppKit
import ApplicationServices
import ServiceManagement

enum PermissionState {
    case granted, denied, unknown
}

/// État des permissions et du raccourci. Rafraîchi seulement quand une fenêtre qui l'affiche est ouverte.
final class PermissionCenter: ObservableObject {
    static let shared = PermissionCenter()

    @Published private(set) var accessibility = false
    @Published private(set) var automation: PermissionState = .unknown
    @Published private(set) var fullDisk = false
    @Published private(set) var hotkeyActive = false
    @Published private(set) var spotlightConflict = false
    @Published private(set) var raycastRunning = false
    @Published private(set) var launchAtLogin = false

    private var timer: Timer?
    private var watchers = 0

    var allEssentialsOK: Bool { accessibility && hotkeyActive }

    func startWatching() {
        watchers += 1
        refresh()
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in self?.refresh() }
        timer.tolerance = 0.5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stopWatching() {
        watchers = max(0, watchers - 1)
        guard watchers == 0 else { return }
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        update(\.accessibility, AXIsProcessTrusted())
        update(\.fullDisk, Self.hasFullDiskAccess())
        update(\.hotkeyActive, Controller.shared.hotKey.isRegistered)
        update(\.spotlightConflict, Prefs.hotkey.id == "cmd-space" && Self.spotlightUsesCommandSpace())
        update(\.raycastRunning, !NSRunningApplication.runningApplications(withBundleIdentifier: "com.raycast.macos").isEmpty)
        update(\.launchAtLogin, SMAppService.mainApp.status == .enabled)
        DispatchQueue.global(qos: .utility).async {
            let state = Self.finderAutomation(ask: false)
            DispatchQueue.main.async { self.update(\.automation, state) }
        }
    }

    private func update<T: Equatable>(_ key: ReferenceWritableKeyPath<PermissionCenter, T>, _ value: T) {
        if self[keyPath: key] != value { self[keyPath: key] = value }
    }

    // MARK: - Actions

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options) { openSettings("Privacy_Accessibility") }
    }

    func requestAutomation() {
        DispatchQueue.global(qos: .userInitiated).async {
            let state = Self.finderAutomation(ask: true)
            DispatchQueue.main.async {
                self.update(\.automation, state)
                if state == .denied { self.openSettings("Privacy_Automation") }
            }
        }
    }

    func openFullDiskSettings() { openSettings("Privacy_AllFiles") }

    func openSettings(_ anchor: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }

    func retryHotkey() {
        Controller.shared.applyHotkey()
        refresh()
    }

    func quitRaycast() {
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.raycast.macos").forEach { $0.terminate() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.retryHotkey() }
    }

    /// Désactive ⌘ Espace pour Spotlight (même effet que dans Réglages › Clavier › Raccourcis).
    func disableSpotlightShortcut() {
        let entry = "<dict><key>enabled</key><false/><key>value</key><dict><key>parameters</key><array>"
            + "<integer>65535</integer><integer>49</integer><integer>1048576</integer></array>"
            + "<key>type</key><string>standard</string></dict></dict>"
        run("/usr/bin/defaults", ["write", "com.apple.symbolichotkeys", "AppleSymbolicHotKeys", "-dict-add", "64", entry])
        run("/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings", ["-u"])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.retryHotkey() }
    }

    func setLaunchAtLogin(_ on: Bool) {
        if on { try? SMAppService.mainApp.register() } else { try? SMAppService.mainApp.unregister() }
        refresh()
    }

    // MARK: - Vérifications

    private func run(_ path: String, _ args: [String]) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        try? p.run()
        p.waitUntilExit()
    }

    private static func hasFullDiskAccess() -> Bool {
        let path = Shell.home + "/Library/Application Support/com.apple.TCC/TCC.db"
        guard let handle = FileHandle(forReadingAtPath: path) else { return false }
        try? handle.close()
        return true
    }

    private static func spotlightUsesCommandSpace() -> Bool {
        let keys = CFPreferencesCopyAppValue("AppleSymbolicHotKeys" as CFString, "com.apple.symbolichotkeys" as CFString)
        guard let dict = keys as? [String: Any], let spotlight = dict["64"] as? [String: Any] else { return true }
        return spotlight["enabled"] as? Bool ?? true
    }

    private static func finderAutomation(ask: Bool) -> PermissionState {
        let target = NSAppleEventDescriptor(bundleIdentifier: "com.apple.finder")
        guard let desc = target.aeDesc else { return .unknown }
        let status = AEDeterminePermissionToAutomateTarget(desc, typeWildCard, typeWildCard, ask)
        switch status {
        case noErr: return .granted
        case OSStatus(errAEEventNotPermitted): return .denied
        default: return .unknown
        }
    }
}
