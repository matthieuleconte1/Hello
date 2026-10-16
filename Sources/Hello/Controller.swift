import AppKit
import Carbon
import SwiftUI

enum PanelLayout {
    static var size: CGSize { AppSettings.shared.panelSize.size }
    /// Arrondi réglable ; borné pour que l'image de l'ombre (coins + flou) tienne dans le plus petit panneau.
    static var radius: CGFloat {
        StyleTokens.current.radius ?? CGFloat(min(max(AppSettings.shared.cornerRadius, 12), 32))
    }
    /// Marges transparentes de la fenêtre autour du panneau : l'ombre (dessinée par SwiftUI) y déborde.
    static let margin = (top: CGFloat(24), side: CGFloat(56), bottom: CGFloat(76))

    /// Mode Applications : grand panneau proportionnel à l'écran (jamais plus petit que la taille réglée).
    static func appsSize(on screen: NSScreen) -> CGSize {
        let visible = screen.visibleFrame
        return CGSize(width: min(max(visible.width * 0.72, size.width), 1180),
                      height: min(max(visible.height * 0.78, size.height), 800))
    }

    /// Plus grande page possible de la grille (9 colonnes × 5 rangées).
    static let maxAppsPerPage = 45

    /// Colonnes × rangées de la grille pour une taille de panneau (cases d'environ 130 pt).
    static func appGrid(for panel: CGSize) -> (columns: Int, rows: Int) {
        let width = panel.width - 36
        let height = panel.height - 60 - 40 - 2 - 28 - 12
        return (min(max(Int(width / 128), 5), 9), min(max(Int(height / 134), 3), 5))
    }
}

final class LauncherPanel: NSPanel {
    init<V: View>(content: V) {
        super.init(contentRect: NSRect(origin: .zero, size: PanelLayout.size),
                   styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        // Ombre dessinée par SwiftUI (la fenêtre, plus grande que le panneau, est transparente autour).
        hasShadow = false
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false
        animationBehavior = .none
        appearance = NSAppearance(named: .darkAqua)

        let host = NSHostingView(rootView: content)
        host.sizingOptions = []
        host.frame = NSRect(origin: .zero, size: PanelLayout.size)
        host.autoresizingMask = [.width, .height]
        contentView = host
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class Controller: NSObject, NSWindowDelegate {
    static let shared = Controller()

    let model = LauncherModel()
    let apps = AppIndex()
    let clipboard = ClipboardHistory()
    let colors = ColorStore()
    weak var searchField: NSTextField?

    let hotKey = HotKey()
    private let statusMenu = StatusMenu()
    private var panel: LauncherPanel!
    private var keyMonitor: Any?
    private var scrollMonitor: Any?
    private var activity: NSObjectProtocol?
    private var lastReveal = Date.distantPast
    /// Fermeture en fondu teinté en cours (numéro, pour ignorer un fondu interrompu par une réouverture).
    private var closing: Int?
    private var closeCount = 0
    private var screen: NSScreen?
    /// Jusqu'à quand l'état du panneau (mode, texte, sélection, commande en cours) doit être repris.
    private var resumeUntil = Date.distantPast

    func start() {
        panel = LauncherPanel(content: LauncherView(model: model))
        panel.delegate = self

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isKeyWindow else { return event }
            if self.closing != nil { return nil }
            if let editor = self.searchField?.currentEditor() as? NSTextView, editor.hasMarkedText() { return event }
            return self.model.handleKey(event) ? nil : event
        }

        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, event.window === self.panel else { return event }
            return self.model.handleScroll(event) ? nil : event
        }

        HotKey.onPress = { [weak self] in self?.toggle() }
        applyHotkey()
        // Si le raccourci est pris (Raycast, Alfred…), on réessaie quand une app se ferme.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self, !self.hotKey.isRegistered else { return }
            self.applyHotkey()
        }
        updateStatusItem()

        // Sans ça, App Nap espace le timer du presse-papiers et des copies sont ratées.
        // Le timer reste très peu coûteux (lecture d'un entier toutes les ~0,75 s, avec tolérance).
        activity = ProcessInfo.processInfo.beginActivity(options: .userInitiatedAllowingIdleSystemSleep,
                                                        reason: "Historique du presse-papiers")
        clipboard.onChange = { [weak self] in self?.model.clipboardDidChange() }
        clipboard.start()
        apps.refresh()
        Shell.loadUserPath()
        Hermes.locate()
        EngineStatus.locate()
        Attachments.cleanUp()
        AgentNotifier.shared.install()
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { Updater.shared.checkIfDue() }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 3) { GlyphIndex.warm() }

        if AppSettings.shared.onboarded {
            show()
        } else {
            WindowManager.showOnboarding()
        }
    }

    func updateStatusItem() {
        AppSettings.shared.showMenuBarIcon ? statusMenu.install() : statusMenu.remove()
    }

    @discardableResult
    func applyHotkey() -> Bool {
        let choice = Prefs.hotkey
        return hotKey.register(keyCode: choice.keyCode, modifiers: choice.modifiers)
    }

    func toggle() {
        panel.isVisible && closing == nil ? hide() : show()
    }

    func show(mode: Mode = .root) {
        cancelClosing()
        apps.refreshIfStale()
        // Hello a été masqué par autre chose que toi (fenêtre système, alerte, autre app), ou Hermes travaille
        // (ou a fini) en arrière-plan : on reprend où on en était.
        if mode == .root && (Date() < resumeUntil || model.agentInBackground) {
            model.resume()
        } else {
            model.reset(to: mode)
        }
        model.markAgentSeen()
        Updater.shared.checkIfDue()
        resumeUntil = .distantPast
        position()
        applyStyle()
        let wasVisible = panel.isVisible
        panel.makeKeyAndOrderFront(nil)
        focusSearch()
        guard !wasVisible else { return }
        // Ouverture "snappy" : petit ressort rapide (échelle + fondu), rendu par le GPU.
        // Rouvert moins de 6 s après la dernière ouverture : version allégée (plus courte, sans reflet ni cascade).
        // Le Verre rejoue sa goutte à chaque ouverture, sauf si on rouvre aussitôt (aller-retour au raccourci).
        let window: TimeInterval = AppSettings.shared.panelStyle == .glass ? 1.5 : 6
        let light = Date().timeIntervalSince(lastReveal) < window
        lastReveal = Date()
        if let animation = Motion.scaled(AppSettings.shared.panelStyle.reveal.open(light: light)) {
            withAnimation(animation) { model.setPresented(true, light: light) }
        } else {
            model.setPresented(true)
        }
    }

    var isVisible: Bool { panel.isVisible }

    /// Fermeture voulue (Échap, action lancée, raccourci…) : la prochaine ouverture repart de zéro.
    /// Avec `tint` (app ouverte) : la sélection et la barre de recherche s'illuminent de sa couleur et Hello s'efface
    /// aussitôt (≈0,2 s), sans plus réagir — rien n'est retardé, l'app se lance en parallèle.
    func hide(tint: NSColor? = nil) {
        guard panel.isVisible, closing == nil else { return }
        resumeUntil = .distantPast
        guard let tint else {
            panel.orderOut(nil)
            model.setPresented(false)
            return
        }
        closeCount += 1
        let id = closeCount
        closing = id
        withAnimation(.easeOut(duration: 0.07)) { model.setClosingTint(tint) }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self, self.closing == id else { return }
            self.finishClosing()
            self.panel.orderOut(nil)
            self.model.setPresented(false)
        })
    }

    private func finishClosing() {
        closing = nil
        panel.alphaValue = 1
        model.setClosingTint(nil)
    }

    /// Réouverture pendant le fondu : on l'arrête net.
    private func cancelClosing() {
        guard closing != nil else { return }
        finishClosing()
        panel.orderOut(nil)
        model.setPresented(false)
    }

    func focusSearch() {
        guard let field = searchField, field.window === panel else { return }
        panel.makeFirstResponder(field)
        field.currentEditor()?.selectedRange = NSRange(location: (field.stringValue as NSString).length, length: 0)
        (field.currentEditor() as? NSTextView)?.insertionPointColor = StyleTokens.current.searchNSColor
    }

    /// Apparence de la fenêtre selon le style : barres de défilement, menus contextuels et couleurs système suivent.
    func applyStyle() {
        let style = StyleTokens.current
        panel.appearance = NSAppearance(named: style.dark ? .darkAqua : .aqua)
        (searchField?.currentEditor() as? NSTextView)?.insertionPointColor = style.searchNSColor
    }

    var panelSize: CGSize { model.panelRect?.size ?? PanelLayout.size }

    /// La fenêtre est posée une fois par ouverture et ne change plus de taille : elle couvre le panneau normal
    /// à sa hauteur maximale et le grand panneau des applications, plus des marges transparentes pour l'ombre.
    /// Hauteur selon les résultats et passage aux applications sont animés par SwiftUI à l'intérieur (GPU),
    /// sans jamais redimensionner la fenêtre — c'est ce qui coûtait le plus cher à chaque frappe.
    private func position() {
        let mouse = NSEvent.mouseLocation
        screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let screen else { return }
        let area = panelFrame(apps: false, height: PanelLayout.size.height, on: screen)
            .union(panelFrame(apps: true, on: screen))
        let m = PanelLayout.margin
        let window = NSRect(x: area.minX - m.side, y: area.minY - m.bottom,
                            width: area.width + 2 * m.side, height: area.height + m.top + m.bottom)
        panel.setFrame(window, display: false)
        model.setPanelRect(local(panelFrame(apps: model.mode == .apps, on: screen), in: window))
    }

    /// Cadre du panneau à l'écran. Le grand panneau des applications garde le même haut que le panneau normal
    /// (il s'agrandit vers le bas et sur les côtés), sauf s'il dépasserait du bas de l'écran.
    private func panelFrame(apps: Bool, height: CGFloat? = nil, on screen: NSScreen) -> NSRect {
        let frame = screen.frame
        let visible = screen.visibleFrame
        let base = PanelLayout.size
        let top = AppSettings.shared.panelPosition == .upper
            ? frame.maxY - frame.height * 0.2
            : frame.midY + base.height / 2
        let size = apps ? PanelLayout.appsSize(on: screen)
            : CGSize(width: base.width, height: height ?? model.preferredPanelHeight(max: base.height))
        if apps {
            let grid = PanelLayout.appGrid(for: size)
            model.setAppGridShape(columns: grid.columns, rows: grid.rows)
        }
        var y = max(visible.minY + 20, top - size.height)
        y = min(y, visible.maxY - size.height)
        return NSRect(x: frame.midX - size.width / 2, y: y, width: size.width, height: size.height)
    }

    /// Passage animé entre le panneau normal et le grand panneau des applications : un ressort SwiftUI sur le cadre
    /// du panneau. Relancé en plein vol (allers-retours rapides), il repart d'où il en est, avec sa vitesse.
    func morphPanel(toApps: Bool) {
        guard let screen else { return }
        let target = local(panelFrame(apps: toApps, on: screen), in: panel.frame)
        guard panel.isVisible, AppSettings.shared.animations else { return model.setPanelRect(target) }
        withAnimation(Self.morphSpring) { model.setPanelRect(target) }
    }

    private static let morphSpring = Animation.spring(response: 0.44, dampingFraction: 0.84)

    /// Hauteur ajustée aux résultats, bord du haut fixe : le panneau s'allonge ou se replie vers le bas.
    func fitPanelHeight() {
        guard panel.isVisible, closing == nil, model.mode != .apps, let screen, let current = model.panelRect else { return }
        let target = local(panelFrame(apps: false, on: screen), in: panel.frame)
        guard abs(current.height - target.height) > 0.5 || abs(current.width - target.width) > 0.5 else { return }
        guard AppSettings.shared.animations else { return model.setPanelRect(target) }
        // La largeur change : c'est le retour depuis la grille d'applications (déclenché ici, pendant la navigation,
        // avant morphPanel) — même ressort que l'aller, sinon le retour part sur le ressort court des résultats.
        let morphing = abs(current.width - target.width) > 0.5
        withAnimation(morphing ? Self.morphSpring : .spring(response: 0.3, dampingFraction: 0.88)) {
            model.setPanelRect(target)
        }
    }

    /// Cadre écran → coordonnées SwiftUI de la fenêtre (origine en haut à gauche).
    private func local(_ rect: NSRect, in window: NSRect) -> CGRect {
        CGRect(x: rect.minX - window.minX, y: window.maxY - rect.maxY, width: rect.width, height: rect.height)
    }

    /// Le panneau perd le focus sans qu'on l'ait fermé : on garde l'état.
    /// Volé par une autre fenêtre (alerte, demande de permission, app qui passe devant) : repris pendant 10 min.
    /// Clic ailleurs : repris pendant 90 s, comme Raycast.
    func windowDidResignKey(_ notification: Notification) {
        // L'app ouverte prend le focus pendant le fondu : on laisse le fondu finir.
        guard panel.isVisible, closing == nil else { return }
        let clickedAway = NSEvent.pressedMouseButtons != 0
        panel.orderOut(nil)
        model.setPresented(false)
        resumeUntil = Date().addingTimeInterval(clickedAway ? 90 : 600)
    }
}
