import AppKit
import ServiceManagement

/// Icône dans la barre des menus. Le menu est reconstruit uniquement à l'ouverture.
final class StatusMenu: NSObject, NSMenuDelegate {
    private var item: NSStatusItem?

    func remove() {
        if let item { NSStatusBar.system.removeStatusItem(item) }
        item = nil
    }

    func install() {
        guard item == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = Self.icon
        item.button?.toolTip = "Hello"
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        self.item = item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        let c = Controller.shared
        menu.removeAllItems()

        let open = menu.addAction("Ouvrir Hello", symbol: "sparkle") { c.show() }
        if Prefs.hotkey.id == "cmd-space" {
            open.keyEquivalent = " "
            open.keyEquivalentModifierMask = [.command]
        }
        if !c.hotKey.isRegistered {
            menu.addItem(.disabled("⚠︎ \(Prefs.hotkey.label) est utilisé par une autre app"))
        }
        menu.addItem(.separator())
        menu.addAction("Emoji & Symboles", symbol: "face.smiling") { c.show(mode: .emoji) }
        menu.addAction("Presse-papiers", symbol: "doc.on.clipboard") { c.show(mode: .clipboard) }
        menu.addAction("Pipette de couleur", symbol: "eyedropper.halffull") { c.model.pickColor() }

        let barItem = NSMenuItem(title: "Barre des menus", action: nil, keyEquivalent: "")
        barItem.image = NSImage(systemSymbolName: "menubar.rectangle", accessibilityDescription: nil)
        let bar = NSMenu()
        let current = MenuBarMode.current
        for mode in MenuBarMode.allCases {
            bar.addAction("Masquer : \(mode.title)") { mode.apply() }.state = mode == current ? .on : .off
        }
        barItem.submenu = bar
        menu.addItem(barItem)

        menu.addItem(.separator())
        menu.addAction("Statistiques d'utilisation", symbol: "chart.bar.xaxis") { c.show(mode: .stats) }
        menu.addAction("Réglages…", symbol: "gearshape") { WindowManager.showSettings() }.keyEquivalent = ","
        let login = SMAppService.mainApp.status == .enabled
        menu.addAction("Lancer à l'ouverture de session") {
            if login { try? SMAppService.mainApp.unregister() } else { try? SMAppService.mainApp.register() }
        }.state = login ? .on : .off
        menu.addAction("Quitter Hello") { NSApp.terminate(nil) }.keyEquivalent = "q"
    }

    /// Le logo (anneau ouvert et point), en image « template » : il suit le thème de la barre des menus.
    private static let icon = HelloMark.templateImage()
}

/// NSMenuItem qui exécute une closure.
private final class ClosureItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) { fatalError() }

    @objc private func fire() { handler() }
}

private extension NSMenu {
    @discardableResult
    func addAction(_ title: String, symbol: String? = nil, _ handler: @escaping () -> Void) -> NSMenuItem {
        let item = ClosureItem(title, handler: handler)
        if let symbol { item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
        addItem(item)
        return item
    }
}

private extension NSMenuItem {
    static func disabled(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }
}
