import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Controller.shared.start()
    }

    // Relancer Hello depuis le Finder / Spotlight ouvre simplement le panneau.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Controller.shared.show()
        return false
    }
}
