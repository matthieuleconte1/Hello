import AppKit
import Combine
import Carbon
import ServiceManagement
import SwiftUI

enum Mode: Equatable {
    case root, apps, emoji, clipboard, colors, menuBar, hotkey, output, uninstall, uninstallFiles, stats, agent

    var title: String {
        switch self {
        case .root: "Hello"
        case .apps: "Applications"
        case .emoji: "Emoji & Symboles"
        case .clipboard: "Presse-papiers"
        case .colors: "Couleurs"
        case .menuBar: "Barre des menus"
        case .hotkey: "Raccourci"
        case .output: "Terminal"
        case .uninstall, .uninstallFiles: "Désinstaller"
        case .stats: "Statistiques"
        case .agent: "Hermes"
        }
    }

    var symbol: String {
        switch self {
        case .root: "sparkle"
        case .apps: "square.grid.3x3.fill"
        case .emoji: "face.smiling"
        case .clipboard: "doc.on.clipboard"
        case .colors: "eyedropper.halffull"
        case .menuBar: "menubar.rectangle"
        case .hotkey: "keyboard"
        case .output: "terminal"
        case .uninstall, .uninstallFiles: "trash"
        case .stats: "chart.bar.xaxis"
        case .agent: "sparkles"
        }
    }

    var placeholder: String {
        switch self {
        case .root: "Rechercher une app, une commande… ou cd ~/dossier"
        case .apps: "Rechercher une application…"
        case .emoji: "Rechercher un emoji ou un symbole…"
        case .clipboard: "Rechercher dans l'historique…"
        case .colors: "Rechercher une couleur…"
        case .menuBar: "Masquer automatiquement la barre des menus…"
        case .hotkey: "Raccourci pour ouvrir Hello…"
        case .output: ""
        case .uninstall: "Quelle application désinstaller ?"
        case .uninstallFiles: "Filtrer les fichiers…"
        case .stats: "Rechercher une app…"
        case .agent: ""
        }
    }

    var emptyText: String {
        switch self {
        case .clipboard: "L'historique est vide — copiez quelque chose !"
        case .emoji: "Aucun caractère trouvé"
        default: "Aucun résultat"
        }
    }
}

struct ItemAction {
    let title: String
    let run: () -> Void
}

enum ItemIcon {
    case file(String)
    case symbol(String, Color)
    case color(NSColor)
    case image(URL)
}

enum Preview {
    case clip(ClipEntry)
    case color(StoredColor)
    case stats(String)
    case empty
}

struct ResultItem: Identifiable {
    let id: String
    var section: String? = nil
    let title: String
    var subtitle: String? = nil
    var icon: ItemIcon
    var accessory: String? = nil
    var primary: ItemAction
    var secondary: ItemAction? = nil
    var tertiary: ItemAction? = nil
    var remove: ItemAction? = nil
    var completion: String? = nil
    var preview: Preview = .empty
    var checked: Bool? = nil
    var copyText: String? = nil
}

struct Hint: Identifiable {
    let label: String
    let key: String
    var id: String { key }
}

struct Command {
    let id: String
    let title: String
    let subtitle: String
    let keywords: String
    let icon: ItemIcon
    var suggested = false
    var actionTitle = "Ouvrir"
    var secondary: ItemAction? = nil
    let action: () -> Void
}

enum ActionKind { case primary, secondary, tertiary }

final class LauncherModel: ObservableObject {
    @Published var query = "" {
        didSet { if query != oldValue && !muted { selection = 0; update() } }
    }
    @Published private(set) var mode: Mode = .root
    @Published private(set) var items: [ResultItem] = []
    @Published private(set) var glyphs: [Glyph] = []
    @Published var selection = 0 {
        didSet { if mode == .apps { followSelection() } }
    }
    @Published private(set) var glyphFilter: GlyphFilter = .all
    @Published private(set) var toast: String?
    @Published private(set) var run: ShellRun?
    @Published private(set) var agent: AgentRun?
    private var agentWatch: AnyCancellable?
    @Published private(set) var presented = false
    @Published private(set) var revealID = 0
    @Published private(set) var forward = true
    // Grille d'applications : page affichée, glissement en cours du trackpad, pages gardées à l'écran.
    @Published private(set) var appPage = 0
    @Published private(set) var appPageRange = 0...1
    @Published private(set) var iconsLoaded = 0
    /// Couleur de l'app qu'on vient d'ouvrir : Hello s'en teinte pendant qu'il s'efface.
    @Published private(set) var closingTint: NSColor?
    /// Seule la translation de la bande observe ce geste, pas le panneau ni les cases.
    let pager = PagerState()
    private var swipe: AppSwipe?
    private var lastWheelPage = Date.distantPast

    var gridColumns: Int { AppSettings.shared.panelSize.gridColumns }
    /// Cadre du panneau dans la fenêtre (coordonnées SwiftUI). Égal à la fenêtre, sauf pendant
    /// l'agrandissement vers la grille d'applications où la fenêtre englobe l'ancien et le nouveau cadre.
    @Published private(set) var panelRect: CGRect?
    /// Icônes de la grille en place (false : elles arrivent floues et grossies, comme sur iPhone).
    @Published private(set) var appsRevealed = true
    /// Colonnes × rangées de la grille, fixées d'après la grande taille du panneau.
    private(set) var appGridShape = (columns: 7, rows: 3)
    var appColumns: Int { appGridShape.columns }
    var appsPerPage: Int { appGridShape.columns * appGridShape.rows }

    func setPanelRect(_ rect: CGRect?) { panelRect = rect }
    func setAppGridShape(columns: Int, rows: Int) { appGridShape = (columns, rows) }
    private var rootQuery = ""
    private var muted = false
    private var toastWork: DispatchWorkItem?
    /// Recalculés une fois par ouverture (ou après une action), pas à chaque frappe :
    /// l'état de connexion (SMAppService, ~3 ms) et la liste des apps ouvertes coûtent trop cher par touche.
    private var cachedCommands: [(command: Command, title: String, keys: String)]?
    private var cachedRunning: Set<String>?
    private var cachedCanPaste: Bool?
    var c: Controller { .shared }

    // Désinstallation en cours
    private var uninstallApp: AppEntry?
    private var uninstallFiles: [Leftover] = []
    private var uninstallChecked = Set<String>()
    private var uninstallSizes: [String: Int64] = [:]
    private var uninstallReturn: Mode = .root
    private var uninstalling = false

    // MARK: - Navigation

    func reset(to newMode: Mode) {
        mode = newMode
        appsRevealed = true
        swipe = nil
        pager.rootSwipe = 0
        pager.reset()
        appPage = 0
        appPageRange = 0...1
        rootQuery = ""
        invalidateCaches()
        glyphFilter = .all
        run = nil
        uninstallApp = nil
        setQuery("")
    }

    /// Réaffiche l'état laissé tel quel (texte, mode, sélection, commande en cours) en rafraîchissant les données.
    func resume() {
        invalidateCaches()
        let kept = selection
        if mode != .output { refresh() }
        let count = mode == .emoji ? glyphs.count : items.count
        selection = count == 0 ? 0 : min(kept, count - 1)
    }

    func setQuery(_ q: String) {
        muted = true
        query = q
        muted = false
        selection = 0
        update()
    }

    func enter(_ newMode: Mode) {
        if mode == .root { rootQuery = query }
        if newMode == .apps {
            appPage = 0
            pager.reset()
            appPageRange = 0...1
            swipe = nil
            c.morphPanel(toApps: true)
            appsRevealed = !(AppSettings.shared.animations && presented)
        }
        navigate(forward: true) {
            mode = newMode
            setQuery("")
        }
        if !appsRevealed {
            // Au tour suivant : les icônes se posent (chacune anime sa propre arrivée, en cascade depuis le centre).
            DispatchQueue.main.async { self.appsRevealed = true }
        }
    }

    /// Ouverture allégée quand Hello est rouvert très vite : même mouvement, sans reflet ni cascade.
    @Published private(set) var lightReveal = false

    func setClosingTint(_ color: NSColor?) {
        closingTint = color
    }

    func setPresented(_ value: Bool, light: Bool = false) {
        if value && !presented {
            lightReveal = light
            if !light { revealID += 1 }
        }
        presented = value
    }

    private func navigate(forward isForward: Bool, _ change: () -> Void) {
        forward = isForward
        if let animation = Motion.scaled(AppSettings.shared.panelStyle.reveal.navigation), presented {
            withAnimation(animation, change)
        } else {
            change()
        }
    }

    func attachAgent(_ run: AgentRun) {
        agent = run
        agentWatch = run.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
    }

    func back() {
        run?.cancel()
        run = nil
        agent?.cancel()
        agent = nil
        agentWatch = nil
        if mode == .uninstallFiles && uninstallReturn == .uninstall {
            uninstallApp = nil
            navigate(forward: false) {
                mode = .uninstall
                setQuery("")
            }
            return
        }
        uninstallApp = nil
        let leavingApps = mode == .apps
        if leavingApps {
            appsRevealed = false
            swipe = nil
            releaseVelocity = 0
            pager.reset()
        }
        navigate(forward: false) {
            mode = .root
            setQuery(rootQuery)
        }
        if leavingApps { c.morphPanel(toApps: false) }
        DispatchQueue.main.async { self.c.focusSearch() }
    }

    /// Recalcule les résultats en relisant l'état du système (après une action, un changement externe).
    func refresh() {
        invalidateCaches()
        update()
    }

    private func invalidateCaches() {
        cachedCommands = nil
        cachedRunning = nil
        cachedCanPaste = nil
    }

    /// Collage direct possible (réglage + accessibilité). AXIsProcessTrusted interroge le système :
    /// lu une fois par ouverture, pas pour chaque ligne du presse-papiers ni à chaque rendu du pied de page.
    var canPaste: Bool {
        if let cachedCanPaste { return cachedCanPaste }
        let value = Paster.canPaste
        cachedCanPaste = value
        return value
    }

    /// Recalcule les résultats pour la requête courante (chemin de la frappe : aucun appel système coûteux).
    private func update() {
        switch mode {
        case .root: items = rootItems()
        case .apps:
            items = gridAppItems()
            preloadAppIcons()
        case .emoji: glyphs = GlyphIndex.search(query, filter: glyphFilter)
        case .clipboard: items = clipboardItems()
        case .colors: items = colorItems()
        case .menuBar: items = menuBarItems()
        case .hotkey: items = hotkeyItems()
        case .output, .agent: items = []
        case .uninstall: items = uninstallPickerItems()
        case .uninstallFiles: items = uninstallFileItems()
        case .stats: items = statsItems()
        }
        let count = mode == .emoji ? glyphs.count : items.count
        selection = count == 0 ? 0 : min(max(selection, 0), count - 1)
        scheduleFit()
    }

    private var fitScheduled = false

    /// Ajuste la hauteur du panneau au tour suivant, une seule fois même si plusieurs changements la demandent.
    /// Pas tout de suite : l'animation forcerait SwiftUI à redessiner au milieu de la mise à jour (champ vidé par
    /// Échap, message…), avec l'ancienne hauteur, et le panneau pouvait rester grand et vide.
    private func scheduleFit() {
        guard presented, !fitScheduled else { return }
        fitScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.fitScheduled = false
            if self.presented { self.c.fitPanelHeight() }
        }
    }

    /// Hauteur du panneau : à l'accueil, juste ce qu'il faut pour les résultats (comme Spotlight),
    /// ailleurs la hauteur réglée. Calcul d'après les hauteurs fixes de ResultList / ResultRow.
    func preferredPanelHeight(max limit: CGFloat) -> CGFloat {
        if collapsed { return 60 }
        guard mode == .root else { return limit }
        let chrome: CGFloat = 60 + 1 + 1 + 40
        guard !items.isEmpty else { return min(limit, chrome + 150) }
        var list: CGFloat = 16
        for (index, item) in items.enumerated() {
            if index > 0 { list += 2 }
            if let section = item.section, index == 0 || items[index - 1].section != section {
                list += 14 + 2 + (index == 0 ? 2 : 10)
            }
            list += AppSettings.shared.rowDensity.rowHeight
            if chrome + list >= limit { return limit }
        }
        return min(limit, chrome + list)
    }

    func appsDidChange() {
        if mode == .root || mode == .apps { refresh() }
    }

    func clipboardDidChange() {
        cachedCommands = nil
        if mode == .clipboard { refresh() }
    }

    var selectedItem: ResultItem? { items.indices.contains(selection) ? items[selection] : nil }
    var selectedGlyph: Glyph? { glyphs.indices.contains(selection) ? glyphs[selection] : nil }

    /// Mode focus : seulement la barre de recherche, tant que rien n'est tapé (un message s'affiche quand même).
    var collapsed: Bool {
        AppSettings.shared.focusMode && mode == .root && toast == nil
            && query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func flash(_ text: String) {
        toast = text
        scheduleFit()
        toastWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.toast = nil
            self.scheduleFit()
        }
        toastWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2, execute: work)
    }

    // MARK: - Clavier

    func handleKey(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let cmd = flags.contains(.command)
        let grid = mode == .emoji || mode == .apps

        switch Int(event.keyCode) {
        case kVK_Escape:
            escape()
            return true
        case kVK_DownArrow where mode == .apps:
            moveInPage(appColumns)
            return true
        case kVK_UpArrow where mode == .apps:
            moveInPage(-appColumns)
            return true
        case kVK_LeftArrow where mode == .apps && cmd, kVK_PageUp where mode == .apps:
            turnPage(-1)
            return true
        case kVK_RightArrow where mode == .apps && cmd, kVK_PageDown where mode == .apps:
            turnPage(1)
            return true
        case kVK_DownArrow:
            move(grid ? gridColumns : 1)
            return true
        case kVK_UpArrow:
            move(grid ? -gridColumns : -1)
            return true
        case kVK_LeftArrow where grid && !cmd:
            move(-1)
            return true
        case kVK_RightArrow where grid && !cmd:
            move(1)
            return true
        case kVK_Return, kVK_ANSI_KeypadEnter:
            if flags.contains(.shift), let text = selectedItem?.copyText {
                Paster.copy(text)
                c.hide()
                return true
            }
            activate(cmd ? .secondary : flags.contains(.option) ? .tertiary : .primary)
            return true
        case kVK_Tab:
            tab()
            return true
        case kVK_Delete where cmd && selectedItem?.remove != nil:
            selectedItem?.remove?.run()
            return true
        case kVK_Delete where query.isEmpty && mode != .root:
            back()
            return true
        default:
            break
        }

        if mode == .output, let key = event.charactersIgnoringModifiers?.lowercased() {
            if flags.contains(.control) && key == "c" {
                run?.cancel()
                return true
            }
            if cmd && key == "r", let run, !run.running {
                startRun(run.command)
                return true
            }
        }

        // Pas de menu Édition visible (app sans Dock) : on relaie les raccourcis d'édition.
        guard cmd, let key = event.charactersIgnoringModifiers?.lowercased() else { return false }
        switch key {
        case "v":
            // Lien file:// collé dans Hello vide : le fichier s'ouvre tout de suite avec son app par défaut.
            if mode == .root, query.isEmpty, !flags.contains(.shift),
               let text = NSPasteboard.general.string(forType: .string),
               let path = Self.fileURLPath(text), FileManager.default.fileExists(atPath: path) {
                c.hide()
                NSWorkspace.shared.open(URL(fileURLWithPath: path))
                return true
            }
            return NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
        case "c": return NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
        case "x": return NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil)
        case "a": return NSApp.sendAction(#selector(NSResponder.selectAll(_:)), to: nil, from: nil)
        case "z":
            return NSApp.sendAction(Selector(flags.contains(.shift) ? "redo:" : "undo:"), to: nil, from: nil)
        case "w":
            c.hide()
            return true
        case ",":
            WindowManager.showSettings()
            return true
        default:
            return false
        }
    }

    private func move(_ delta: Int) {
        let count = mode == .emoji ? glyphs.count : items.count
        guard count > 0 else { return }
        selection = min(max(selection + delta, 0), count - 1)
    }

    /// Grille d'apps : ↑↓ restent dans la page affichée (←→ passent d'une page à l'autre).
    private func moveInPage(_ delta: Int) {
        guard !items.isEmpty else { return }
        let target = selection + delta
        guard target >= 0, target / appsPerPage == selection / appsPerPage else { return }
        let clamped = min(target, items.count - 1)
        let row = { (index: Int) in (index % self.appsPerPage) / self.appColumns }
        if row(clamped) != row(selection) { selection = clamped }
    }

    var appPageCount: Int { max(1, (items.count + appsPerPage - 1) / appsPerPage) }

    func turnPage(_ delta: Int) {
        guard !items.isEmpty else { return }
        let page = selection / appsPerPage + delta
        guard page >= 0, page * appsPerPage < items.count else { return }
        selection = page * appsPerPage
    }

    private func escape() {
        switch mode {
        case .root:
            query.isEmpty ? c.hide() : setQuery("")
        case .output:
            if run?.running == true { run?.cancel() } else { back() }
        case .agent:
            if agent?.isThinking == true { agent?.cancel() } else { back() }
        default:
            query.isEmpty ? back() : setQuery("")
        }
    }

    private func tab() {
        switch mode {
        case .emoji:
            glyphFilter = glyphFilter.next
            selection = 0
            refresh()
        case .root:
            if let completion = selectedItem?.completion { setQuery(completion) }
        case .uninstallFiles:
            let all = Set(uninstallFiles.map(\.path))
            uninstallChecked = uninstallChecked == all ? [] : all
            refresh()
        default:
            break
        }
    }

    func activate(_ kind: ActionKind) {
        switch mode {
        case .emoji:
            guard let glyph = selectedGlyph else { return }
            Recents.add(glyph.char)
            if kind == .primary {
                c.hide()
                Paster.insert(glyph.char)
            } else {
                Paster.copy(glyph.char)
                c.hide()
            }
        case .agent:
            guard let agent else { return }
            switch (agent.phase, kind) {
            case (.answer, .secondary) where agent.level == .research:
                // Continuer la même conversation dans le terminal.
                agent.continueInTerminal()
                c.hide()
            case (.answer, .secondary):
                startAgent(agent.request, level: .research)
            case (.answer(let text), _):
                Paster.copy(text)
                c.hide()
            case (.escalate(let prompt), .secondary):
                agent.send(prompt)
                c.hide()
            case (.escalate(let prompt), _):
                agent.research(prompt)
            case (.done, _), (.delegated, _), (.failed, _):
                c.hide()
            case (.thinking, _), (.streaming, _):
                break
            }
        case .output:
            guard let run else { return }
            if kind == .secondary {
                c.hide()
                Shell.runInTerminal(run.command)
            } else {
                Paster.copy(run.output)
                flash("Sortie copiée")
            }
        default:
            guard let item = selectedItem else { return }
            switch kind {
            case .primary: item.primary.run()
            case .secondary: item.secondary?.run()
            case .tertiary: item.tertiary?.run()
            }
        }
    }

    var hints: [Hint] {
        switch mode {
        case .emoji:
            guard selectedGlyph != nil else { return [] }
            return [Hint(label: canPaste ? "Coller" : "Copier", key: "↵"),
                    Hint(label: "Copier", key: "⌘↵"),
                    Hint(label: glyphFilter.next.title, key: "⇥")]
        case .agent:
            switch agent?.phase {
            case .thinking?, .streaming?: return [Hint(label: "Annuler", key: "esc")]
            case .answer?:
                return [Hint(label: "Copier", key: "↵"),
                        Hint(label: agent?.level == .research ? "Continuer dans le terminal" : "Chercher plus", key: "⌘↵"),
                        Hint(label: "Retour", key: "esc")]
            case .escalate?:
                return [Hint(label: "Recherche", key: "↵"), Hint(label: "Approfondi (terminal)", key: "⌘↵"),
                        Hint(label: "Annuler", key: "esc")]
            default: return [Hint(label: "Fermer", key: "↵"), Hint(label: "Retour", key: "esc")]
            }
        case .output:
            let running = run?.running == true
            return [Hint(label: "Copier la sortie", key: "↵"),
                    running ? Hint(label: "Arrêter", key: "⌃C") : Hint(label: "Relancer", key: "⌘R"),
                    Hint(label: "Dans Terminal", key: "⌘↵")]
        default:
            guard let item = selectedItem else { return [] }
            var hints = [Hint(label: item.primary.title, key: "↵")]
            if let s = item.secondary { hints.append(Hint(label: s.title, key: "⌘↵")) }
            if let t = item.tertiary { hints.append(Hint(label: t.title, key: "⌥↵")) }
            if let r = item.remove { hints.append(Hint(label: r.title, key: "⌘⌫")) }
            if item.copyText != nil && hints.count < 3 { hints.append(Hint(label: "Copier", key: "⇧↵")) }
            if item.completion != nil { hints.append(Hint(label: "Compléter", key: "⇥")) }
            if mode == .uninstallFiles { hints.append(Hint(label: "Tout", key: "⇥")) }
            return Array(hints.prefix(4))
        }
    }

    // MARK: - Racine

    private func rootItems() -> [ResultItem] {
        let q = query.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return AppSettings.shared.focusMode ? [] : suggestions() }

        if q.hasPrefix("?") { return agentItems(q, explicit: true) }
        if let files = fileURLItems(q) { return files }
        var out = terminalItems(q)
        let folded = Fuzzy.fold(q)
        let running = runningPaths
        // On classe d'abord, et on ne construit les lignes que pour les 40 premiers.
        var scored: [(Int, () -> ResultItem)] = []

        for app in c.apps.apps {
            guard let s = app.score(folded) else { continue }
            scored.append((s + Usage.boost(app.id, folded: folded),
                           { self.appItem(app, running: running.contains(app.path), query: q) }))
        }
        for entry in foldedCommands {
            let s = Fuzzy.score(folded, entry.title) ?? (Fuzzy.wordsMatch(folded, entry.keys) ? 520 : nil)
            if let s { scored.append((s + Usage.boost(entry.command.id, folded: folded), { self.commandItem(entry.command, query: q) })) }
        }
        scored += customCommandItems(q, folded: folded).map { item in (item.0, { item.1 }) }
        scored.sort { $0.0 > $1.0 }
        out += scored.prefix(40).map { $0.1() }

        if !out.contains(where: { $0.id.hasPrefix("run:") || $0.id.hasPrefix("proc:") || $0.id.hasPrefix("port") }) {
            out += historyFallback(q)
        }
        // Rien de pertinent (ou une vraie phrase) : Hermes passe en tête, sinon il reste en dernier recours.
        let agent = agentItems(q, explicit: false)
        let sentence = q.split(separator: " ").count >= 4
        return (out.isEmpty || sentence) ? agent + out : out + agent
    }

    private func suggestions() -> [ResultItem] {
        var out: [ResultItem] = []
        let apps = Dictionary(c.apps.apps.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let allCommands = commands
        let byID = Dictionary(allCommands.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let running = runningPaths

        for id in Usage.top(12) where out.count < 6 && AppSettings.shared.showRecents {
            var item: ResultItem
            if let app = apps[id] { item = appItem(app, running: running.contains(app.path)) }
            else if let command = byID[id] { item = commandItem(command) }
            else if id.hasPrefix("path:"), Shell.isFolder(String(id.dropFirst(5))) {
                item = pathItem(String(id.dropFirst(5)), completion: nil)
            }
            else { continue }
            item.section = "Récents"
            out.append(item)
        }
        for command in allCommands where command.suggested && !out.contains(where: { $0.id == command.id }) {
            var item = commandItem(command)
            item.section = "Commandes"
            out.append(item)
        }
        // Astuce du terminal : seulement tant qu'il y a peu de récents (elle ne sert qu'à découvrir).
        guard out.filter({ $0.section == "Récents" }).count < 3 else { return out }
        out.append(ResultItem(
            id: "hint.shell", section: "Terminal", title: "cd ~/dossier   ·   > commande shell",
            subtitle: "« cd ./code » ouvre ~/code dans le Finder · ⌘↵ l'ouvre dans \(Shell.terminal.name)",
            icon: .symbol("terminal", .gray),
            primary: ItemAction(title: "Essayer") { [unowned self] in setQuery("cd ~/") }))
        return out
    }

    /// Toutes les apps par ordre alphabétique (ou par pertinence pendant une recherche), pour la grille.
    private func gridAppItems() -> [ResultItem] {
        let q = Fuzzy.fold(query.trimmingCharacters(in: .whitespaces))
        let running = runningPaths
        var apps = c.apps.apps
        if !q.isEmpty {
            let scored: [(score: Int, app: AppEntry)] = apps.compactMap { app in app.score(q).map { ($0, app) } }
            // Tri stable : à score égal, l'ordre alphabétique de l'index est conservé.
            apps = scored.enumerated()
                .sorted { $0.element.score != $1.element.score ? $0.element.score > $1.element.score : $0.offset < $1.offset }
                .map(\.element.app)
        }
        return apps.map { appItem($0, running: running.contains($0.path), query: query) }
    }

    private func appItem(_ app: AppEntry, running: Bool, query: String = "") -> ResultItem {
        let url = URL(fileURLWithPath: app.path)
        return ResultItem(
            id: app.id, title: app.name, subtitle: app.detail, icon: .file(app.path),
            accessory: running ? "Ouverte" : nil,
            primary: ItemAction(title: "Ouvrir") { [unowned self] in
                launch(app, query: query)
            },
            secondary: ItemAction(title: "Afficher dans le Finder") { [unowned self] in
                c.hide()
                NSWorkspace.shared.activateFileViewerSelecting([url])
            },
            tertiary: running ? ItemAction(title: "Quitter l'app") { [unowned self] in
                NSWorkspace.shared.runningApplications.filter { $0.bundleURL?.path == app.path }.forEach { $0.terminate() }
                flash("\(app.name) quittée")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.refresh() }
            } : nil,
            remove: Uninstaller.canUninstall(app) ? ItemAction(title: "Désinstaller") { [unowned self] in
                startUninstall(app, from: .root)
            } : nil)
    }

    /// Ouvre l'app tout de suite ; Hello prend sa couleur pendant qu'il s'efface (sans rien retarder).
    private func launch(_ app: AppEntry, query: String) {
        Usage.record(app.id, query: query)
        let effects = AppSettings.shared.animations && AppSettings.shared.launchEffects
        c.hide(tint: effects ? IconColor.dominant(app.path) : nil)
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: app.path), configuration: config)
    }

    private func commandItem(_ command: Command, query: String = "") -> ResultItem {
        ResultItem(id: command.id, title: command.title, subtitle: command.subtitle, icon: command.icon,
                   accessory: "Commande",
                   primary: ItemAction(title: command.actionTitle) {
                       Usage.record(command.id, query: query)
                       command.action()
                   },
                   secondary: command.secondary)
    }

    private var runningPaths: Set<String> {
        if let cachedRunning { return cachedRunning }
        let paths = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleURL?.path })
        cachedRunning = paths
        return paths
    }

    private var commands: [Command] { foldedCommands.map(\.command) }

    /// Commandes avec titre et mots-clés déjà normalisés pour la recherche floue.
    private var foldedCommands: [(command: Command, title: String, keys: String)] {
        if let cachedCommands { return cachedCommands }
        let list = buildCommands().map { command in
            let title = Fuzzy.fold(command.title)
            return (command, title, title + " " + Fuzzy.fold(command.keywords))
        }
        cachedCommands = list
        return list
    }

    private func buildCommands() -> [Command] {
        let loginEnabled = SMAppService.mainApp.status == .enabled
        var list: [Command] = [
            Command(id: "cmd.apps", title: "Toutes les applications", subtitle: "Grille de grandes icônes, page par page",
                    keywords: "applications apps launchpad grille toutes icones", icon: .symbol("square.grid.3x3.fill", .purple),
                    suggested: true) { [unowned self] in enter(.apps) },
            Command(id: "cmd.emoji", title: "Emoji & Symboles", subtitle: "Chercher et insérer emoji et caractères Unicode",
                    keywords: "emoji smiley unicode caractere symbole glyphe", icon: .symbol("face.smiling", .orange),
                    suggested: true) { [unowned self] in enter(.emoji) },
            Command(id: "cmd.clipboard", title: "Historique du presse-papiers",
                    subtitle: "\(c.clipboard.entries.count) élément(s)",
                    keywords: "clipboard presse papiers copier coller historique", icon: .symbol("doc.on.clipboard", .blue),
                    suggested: true) { [unowned self] in enter(.clipboard) },
            Command(id: "cmd.pick", title: "Pipette de couleur", subtitle: "Capturer une couleur n'importe où à l'écran",
                    keywords: "color picker couleur pipette eyedropper hex rgb", icon: .symbol("eyedropper.halffull", .pink),
                    suggested: true, actionTitle: "Choisir",
                    secondary: ItemAction(title: "Historique des couleurs") { [unowned self] in enter(.colors) }
            ) { [unowned self] in pickColor() },
            Command(id: "cmd.colors", title: "Historique des couleurs", subtitle: "\(c.colors.items.count) couleur(s)",
                    keywords: "color couleur historique hex palette", icon: .symbol("paintpalette", .pink)
            ) { [unowned self] in enter(.colors) },
            Command(id: "cmd.menubar", title: "Barre des menus", subtitle: "Masquage automatique : \(MenuBarMode.current.title)",
                    keywords: "menu bar barre des menus masquer afficher plein ecran fullscreen hide",
                    icon: .symbol("menubar.rectangle", .indigo), suggested: true) { [unowned self] in enter(.menuBar) },
        ]
        for m in MenuBarMode.allCases {
            list.append(Command(id: "cmd.menubar." + m.rawValue, title: "Masquer la barre des menus : \(m.title)",
                                subtitle: m.detail, keywords: "menu bar barre menus masquer hide",
                                icon: .symbol(m.symbol, .indigo), actionTitle: "Appliquer") { [unowned self] in
                m.apply()
                flash("Barre des menus : \(m.title)")
                refresh()
            })
        }
        let focus = AppSettings.shared.focusMode
        list.append(Command(id: "cmd.focus", title: focus ? "Désactiver le mode focus" : "Activer le mode focus",
                            subtitle: "À l'ouverture, seulement la barre de recherche",
                            keywords: "focus minimal epure barre recherche seule spotlight",
                            icon: .symbol("scope", .teal), actionTitle: focus ? "Désactiver" : "Activer") { [unowned self] in
            AppSettings.shared.focusMode.toggle()
            setQuery("")
            flash(AppSettings.shared.focusMode ? "Mode focus activé" : "Mode focus désactivé")
        })
        for style in PanelStyle.allCases {
            list.append(Command(id: "cmd.style." + style.rawValue, title: "Style : \(style.title)",
                                subtitle: style.detail, keywords: "style theme apparence design da look visuel",
                                icon: .symbol(style.symbol, .teal), actionTitle: "Appliquer") { [unowned self] in
                AppSettings.shared.panelStyle = style
                c.applyStyle()
                refresh()
                flash("Style : \(style.title)")
            })
        }
        for palette in AtelierPalette.allCases {
            list.append(Command(id: "cmd.palette." + palette.rawValue, title: "Couleurs : \(palette.title)",
                                subtitle: "Thème de couleurs du style Atelier Expressif",
                                keywords: "couleurs theme palette accent atelier material",
                                icon: .symbol("paintpalette.fill", .teal), actionTitle: "Appliquer") { [unowned self] in
                AppSettings.shared.atelierPalette = palette
                AppSettings.shared.panelStyle = .atelier
                c.applyStyle()
                refresh()
                flash("Couleurs : \(palette.title)")
            })
        }
        list += [
            Command(id: "cmd.hotkey", title: "Raccourci global de Hello", subtitle: "Actuel : \(Prefs.hotkey.label)",
                    keywords: "raccourci hotkey shortcut clavier", icon: .symbol("keyboard", .gray)
            ) { [unowned self] in enter(.hotkey) },
            Command(id: "cmd.login",
                    title: loginEnabled ? "Ne plus lancer Hello à l'ouverture de session" : "Lancer Hello à l'ouverture de session",
                    subtitle: loginEnabled ? "Actuellement activé" : "Actuellement désactivé",
                    keywords: "login demarrage startup ouverture session", icon: .symbol("power", .green),
                    actionTitle: loginEnabled ? "Désactiver" : "Activer") { [unowned self] in
                do {
                    if loginEnabled {
                        try SMAppService.mainApp.unregister()
                    } else {
                        try SMAppService.mainApp.register()
                    }
                    flash(loginEnabled ? "Désactivé" : "Hello se lancera à l'ouverture de session")
                } catch {
                    flash("Impossible : \(error.localizedDescription)")
                }
                refresh()
            },
            Command(id: "cmd.uninstall", title: "Désinstaller une application",
                    subtitle: "Supprime l'app et les fichiers de votre choix",
                    keywords: "uninstall desinstaller supprimer app cleaner corbeille",
                    icon: .symbol("trash", .red), suggested: true) { [unowned self] in enter(.uninstall) },
            Command(id: "cmd.settings", title: "Réglages de Hello", subtitle: "Apparence, recherche, presse-papiers… (⌘,)",
                    keywords: "reglages parametres preferences settings options configuration",
                    icon: .symbol("gearshape.fill", .gray), suggested: true) { [unowned self] in
                c.hide()
                WindowManager.showSettings()
            },
            Command(id: "cmd.permissions", title: "Vérifier les permissions", subtitle: "Accessibilité, Finder, disque, raccourci",
                    keywords: "permissions autorisations accessibilite checkup verifier",
                    icon: .symbol("checkmark.shield.fill", .green)) { [unowned self] in
                c.hide()
                WindowManager.showSettings(tab: .permissions)
            },
            Command(id: "cmd.stats", title: "Statistiques d'utilisation",
                    subtitle: "Apps les plus utilisées, historique et raccourcis appris",
                    keywords: "stats statistiques usage frequent utilisation historique",
                    icon: .symbol("chart.bar.xaxis", .teal)) { [unowned self] in enter(.stats) },
            Command(id: "cmd.resetstats", title: "Réinitialiser les statistiques d'utilisation",
                    subtitle: "Oublie la fréquence et les raccourcis appris",
                    keywords: "reset reinitialiser stats statistiques usage oublier",
                    icon: .symbol("arrow.counterclockwise", .red), actionTitle: "Réinitialiser") { [unowned self] in
                Usage.reset()
                flash("Statistiques réinitialisées")
                refresh()
            },
            Command(id: "cmd.clearclip", title: "Vider l'historique du presse-papiers", subtitle: "Supprime tous les éléments",
                    keywords: "clear effacer vider clipboard presse papiers", icon: .symbol("trash", .red),
                    actionTitle: "Vider") { [unowned self] in
                c.clipboard.clear()
                flash("Historique vidé")
                refresh()
            },
            Command(id: "cmd.reload", title: "Recharger les applications", subtitle: "Relancer l'indexation",
                    keywords: "reload refresh index apps", icon: .symbol("arrow.clockwise", .gray)
            ) { [unowned self] in
                c.apps.refresh()
                flash("Applications rechargées")
            },
            Command(id: "cmd.quit", title: "Quitter Hello", subtitle: "Ferme complètement le lanceur",
                    keywords: "quit exit quitter fermer", icon: .symbol("xmark.circle", .gray), actionTitle: "Quitter"
            ) { NSApp.terminate(nil) },
        ]
        return list
    }

    // MARK: - Pages de la grille d'applications

    private var pageSpring: Animation { .spring(response: 0.36, dampingFraction: 0.86) }
    /// Vitesse des pages (pt/s) au moment où les doigts quittent le trackpad : le ressort la reprend
    /// au lieu de repartir de zéro (sinon la page « marque un arrêt » avant de s'aimanter).
    private var releaseVelocity: CGFloat = 0

    private func pageAnimation(remaining: CGFloat) -> Animation {
        let velocity = releaseVelocity
        releaseVelocity = 0
        guard abs(remaining) > 1 else { return pageSpring }
        return .interpolatingSpring(Spring(response: 0.36, dampingRatio: 0.86),
                                    initialVelocity: max(-14, min(14, Double(velocity / remaining))))
    }

    /// La page suit la sélection (clavier, points, fin de balayage, recherche).
    private func followSelection() {
        let page = selection / appsPerPage
        guard page != appPage else { return }
        let animate = AppSettings.shared.animations && presented
        // Les pages traversées sont préparées avant de lancer le ressort.
        let range = min(appPage, page)...max(appPage, page)
        if !animate {
            appPage = page
            pager.reset(page: page)
            appPageRange = max(0, page - 1)...(page + 1)
            return
        }
        let slide = { [self] in
            guard mode == .apps, selection / appsPerPage == page else { return }
            let remaining = (-CGFloat(page) - pager.position) * c.panelSize.width
            withAnimation(pageAnimation(remaining: remaining)) { pager.settle(page: page) }
            appPage = page
            // Une fois le ressort posé, on ne garde que la page et ses deux voisines.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                guard let self, self.mode == .apps, self.appPage == page, self.swipe == nil else { return }
                self.appPageRange = max(0, page - 1)...(page + 1)
            }
        }
        if appPageRange.contains(range.lowerBound) && appPageRange.contains(range.upperBound) {
            slide()
        } else {
            // Saut de plusieurs pages : on insère d'abord les pages intermédiaires, puis on glisse au tour suivant.
            appPageRange = range
            DispatchQueue.main.async(execute: slide)
        }
    }

    /// Balayage au trackpad (ou molette). Les apps sont « à droite » de Hello :
    /// - accueil : glisser vers la droite (doigts vers la gauche) ouvre la grille d'applications ;
    /// - grille : la page suit les doigts, s'aimante au relâchement ; depuis la 1re page, glisser vers la gauche revient.
    /// Le trackpad vibre au franchissement du seuil (dans un sens comme dans l'autre) et en butée.
    func handleScroll(_ event: NSEvent) -> Bool {
        switch mode {
        case .root: return handleRootScroll(event)
        case .apps where !items.isEmpty: return handleGridScroll(event)
        default: return false
        }
    }

    /// Met à jour le geste en cours ; nil tant que l'axe n'est pas décidé (premier mouvement non nul).
    private func trackSwipe(_ event: NSEvent) -> AppSwipe? {
        if event.phase.contains(.began) || event.phase.contains(.mayBegin) || swipe == nil {
            swipe = AppSwipe()
        }
        guard var current = swipe else { return nil }
        let dx = event.scrollingDeltaX, dy = event.scrollingDeltaY
        if current.horizontal == nil, dx != 0 || dy != 0 { current.horizontal = abs(dx) > abs(dy) }
        guard let horizontal = current.horizontal else {
            swipe = current
            return nil
        }
        let delta = horizontal ? dx : dy
        current.offset += delta
        let now = event.timestamp
        if let last = current.lastTime, now > last {
            current.velocity = current.velocity * 0.6 + (delta / CGFloat(now - last)) * 0.4
        }
        current.lastTime = now
        swipe = current
        return current
    }

    private func isEnd(_ event: NSEvent) -> Bool {
        event.phase.contains(.ended) || event.phase.contains(.cancelled)
    }

    private func handleRootScroll(_ event: NSEvent) -> Bool {
        // Seuls les balayages horizontaux du trackpad comptent : le défilement vertical de la liste passe.
        guard event.hasPreciseScrollingDeltas, !event.phase.isEmpty, event.momentumPhase.isEmpty else { return false }
        let threshold = c.panelSize.width * 0.14

        if isEnd(event) {
            let current = swipe
            swipe = nil
            guard current?.horizontal == true else { return false }
            let fast = (current?.velocity ?? 0) < -700
            if event.phase.contains(.ended), current?.armed == true || fast {
                pager.rootSwipe = 0
                enter(.apps)
            } else {
                withAnimation(AppSettings.shared.animations ? pageSpring : nil) { pager.rootSwipe = 0 }
            }
            return true
        }

        guard var current = trackSwipe(event) else { return false }
        guard current.horizontal == true else { return false }
        let armed = current.offset < -threshold
        if armed != current.armed {
            current.armed = armed
            armed ? Haptic.strong() : Haptic.tick()
            swipe = current
        }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { pager.rootSwipe = max(0, -current.offset / threshold) }
        return true
    }

    private func handleGridScroll(_ event: NSEvent) -> Bool {
        // L'inertie après le relâchement est ignorée : c'est le ressort qui finit le mouvement.
        if !event.momentumPhase.isEmpty { return true }

        guard event.hasPreciseScrollingDeltas, !event.phase.isEmpty else {
            // Molette classique : un cran = une page.
            let delta = event.scrollingDeltaX != 0 ? event.scrollingDeltaX : event.scrollingDeltaY
            guard delta != 0, Date().timeIntervalSince(lastWheelPage) > 0.25 else { return true }
            lastWheelPage = Date()
            turnPage(delta < 0 ? 1 : -1)
            return true
        }

        let width = c.panelSize.width
        let threshold = width * 0.18
        let lastPage = appPageCount - 1

        if isEnd(event) {
            let current = swipe ?? AppSwipe()
            swipe = nil
            let fast = abs(current.velocity) > 600 && (current.velocity < 0) == (current.offset < 0)
            let target = appPage + (current.offset < 0 ? 1 : -1)
            let ended = event.phase.contains(.ended)
            releaseVelocity = ended ? current.velocity : 0
            if ended, target < 0, current.armed || (fast && current.offset > threshold * 0.5) {
                // Première page tirée vers la gauche : retour à l'accueil.
                back()
            } else if ended, target >= 0, target <= lastPage, abs(current.offset) > threshold || fast {
                selection = min(target * appsPerPage, items.count - 1)
            } else {
                let remaining = (-CGFloat(appPage) - pager.position) * width
                let animation = pageAnimation(remaining: remaining)
                withAnimation(AppSettings.shared.animations ? animation : nil) { pager.settle(page: appPage) }
            }
            return true
        }

        guard var current = trackSwipe(event) else { return true }

        let backZone = current.offset > 0 && appPage == 0
        let atEnd = current.offset < 0 && appPage == lastPage
        let shown = atEnd ? current.offset * 0.28
            : backZone ? current.offset * 0.5
            : max(-width, min(width, current.offset))

        // Vibrations : seuil franchi (fort), seuil annulé (léger), butée de la dernière page (léger).
        let armed = !atEnd && abs(current.offset) > threshold
        if armed != current.armed {
            current.armed = armed
            armed ? Haptic.strong() : Haptic.tick()
        }
        let bumped = atEnd && abs(current.offset) > 24
        if bumped != current.bumped {
            current.bumped = bumped
            if bumped { Haptic.tick() }
        }
        swipe = current

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { pager.drag(shown, page: appPage, width: width) }
        return true
    }

    /// Grandes icônes chargées en arrière-plan, page affichée d'abord puis ses voisines :
    /// le défilement ne lit jamais une icône sur le fil principal.
    private func preloadAppIcons() {
        let per = appsPerPage
        let paths = items.map { item -> String? in
            if case .file(let path) = item.icon { return path }
            return nil
        }
        let current = min(appPage, appPageCount - 1)
        let order = (0..<appPageCount).sorted { abs($0 - current) < abs($1 - current) }
        let batches = order.map { page in
            (page, paths[page * per..<min((page + 1) * per, paths.count)]
                .compactMap { $0 }
                .filter { IconCache.cachedIcon($0, large: true) == nil })
        }.filter { !$0.1.isEmpty }
        guard !batches.isEmpty else { return }
        // Seules les pages affichées sont redessinées : une page hors de l'écran trouvera ses icônes en cache
        // quand elle sera construite (sinon chaque lot redessinait tout le panneau, y compris en plein agrandissement).
        IconCache.preload(batches) { [weak self] page in
            guard let self, mode == .apps, appPageRange.contains(page) else { return }
            iconsLoaded += 1
        }
    }

    // MARK: - Terminal

    func startRun(_ command: String) {
        ShellHistory.record(command)
        let run = ShellRun(command: command)
        if mode != .output { enter(.output) }
        self.run = run
        run.start()
    }

    private static var silentRuns: [ShellRun] = []

    func runSilently(_ command: String, name: String) {
        ShellHistory.record(command)
        let run = ShellRun(command: command)
        Self.silentRuns.append(run)
        run.onFinish = { [weak self, weak run] status in
            Self.silentRuns.removeAll { $0 === run }
            self?.flash(status == 0 ? "✓ \(name) terminé" : "✗ \(name) : code \(status)")
        }
        run.start()
        flash("\(name)…")
    }

    // MARK: - Presse-papiers

    private func clipboardItems() -> [ResultItem] {
        let q = Fuzzy.fold(query.trimmingCharacters(in: .whitespaces))
        let history = c.clipboard
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        let pasteTitle = canPaste ? "Coller" : "Copier"
        return history.entries
            .filter { q.isEmpty || history.searchKey($0).contains(q) }
            .prefix(200)
            .map { entry in
                ResultItem(
                    id: entry.id.uuidString, title: entry.title,
                    subtitle: [entry.source, formatter.localizedString(for: entry.date, relativeTo: Date())]
                        .compactMap { $0 }.joined(separator: " · "),
                    icon: entry.icon,
                    primary: ItemAction(title: pasteTitle) { [unowned self] in
                        c.hide()
                        history.restore(entry, paste: true)
                    },
                    secondary: ItemAction(title: "Copier") { [unowned self] in
                        history.restore(entry, paste: false)
                        c.hide()
                    },
                    tertiary: entry.kind == .files ? ItemAction(title: "Afficher dans le Finder") { [unowned self] in
                        c.hide()
                        NSWorkspace.shared.activateFileViewerSelecting((entry.files ?? []).map { URL(fileURLWithPath: $0) })
                    } : nil,
                    remove: ItemAction(title: "Supprimer") { [unowned self] in
                        history.remove(entry)
                        refresh()
                    },
                    preview: .clip(entry))
            }
    }

    // MARK: - Couleurs

    func pickColor() {
        c.hide()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [unowned self] in
            ColorPicker.pick { [unowned self] color in
                guard let color, let stored = c.colors.add(color) else { return }
                Paster.copy(stored.hex)
                c.show(mode: .colors)
                selection = 1
                flash("\(stored.hex) copié dans le presse-papiers")
            }
        }
    }

    private func copyAndClose(_ value: String) {
        Paster.copy(value)
        c.hide()
    }

    private func colorItems() -> [ResultItem] {
        let q = Fuzzy.fold(query.trimmingCharacters(in: .whitespaces))
        var out = [ResultItem(
            id: "pick", title: "Choisir une couleur à l'écran", subtitle: "Ouvre la loupe de macOS",
            icon: .symbol("eyedropper.halffull", .pink),
            primary: ItemAction(title: "Choisir") { [unowned self] in pickColor() })]
        for color in c.colors.items {
            if !q.isEmpty && !Fuzzy.fold(color.formats.map(\.value).joined(separator: " ")).contains(q) { continue }
            out.append(ResultItem(
                id: color.id.uuidString, title: color.hex, subtitle: color.rgb, icon: .color(color.nsColor),
                primary: ItemAction(title: "Copier HEX") { [unowned self] in copyAndClose(color.hex) },
                secondary: ItemAction(title: "Copier RGB") { [unowned self] in copyAndClose(color.rgb) },
                tertiary: ItemAction(title: "Copier HSL") { [unowned self] in copyAndClose(color.hsl) },
                remove: ItemAction(title: "Supprimer") { [unowned self] in
                    c.colors.remove(color)
                    refresh()
                },
                preview: .color(color)))
        }
        return out
    }

    // MARK: - Réglages

    private func menuBarItems() -> [ResultItem] {
        let current = MenuBarMode.current
        return MenuBarMode.allCases.map { m in
            ResultItem(id: "mb." + m.rawValue, title: m.title, subtitle: m.detail, icon: .symbol(m.symbol, .indigo),
                       accessory: m == current ? "✓ Actuel" : nil,
                       primary: ItemAction(title: "Appliquer") { [unowned self] in
                           m.apply()
                           flash("Barre des menus : \(m.title)")
                           refresh()
                       })
        }
    }

    private func hotkeyItems() -> [ResultItem] {
        let current = Prefs.hotkey
        return Prefs.hotkeys.map { choice in
            ResultItem(id: "hk." + choice.id, title: choice.label, subtitle: choice.note,
                       icon: .symbol("command", .gray),
                       accessory: choice.id == current.id ? "✓ Actuel" : nil,
                       primary: ItemAction(title: "Utiliser") { [unowned self] in
                           let previous = Prefs.hotkey
                           Prefs.hotkey = choice
                           if c.applyHotkey() {
                               flash("Raccourci : \(choice.label)")
                           } else {
                               Prefs.hotkey = previous
                               c.applyHotkey()
                               flash("\(choice.label) est déjà utilisé par une autre app")
                           }
                           refresh()
                       })
        }
    }

    // MARK: - Désinstallation

    private func uninstallPickerItems() -> [ResultItem] {
        let q = Fuzzy.fold(query.trimmingCharacters(in: .whitespaces))
        return c.apps.apps
            .filter(Uninstaller.canUninstall)
            .compactMap { app -> (Int, AppEntry)? in
                if q.isEmpty { return (0, app) }
                return app.score(q).map { ($0, app) }
            }
            .sorted { $0.0 > $1.0 }
            .map { _, app in
                ResultItem(id: app.id, title: app.name, subtitle: Shell.abbreviate(app.path), icon: .file(app.path),
                           primary: ItemAction(title: "Choisir") { [unowned self] in
                               startUninstall(app, from: .uninstall)
                           })
            }
    }

    private func startUninstall(_ app: AppEntry, from origin: Mode) {
        if mode == .root { rootQuery = query }
        uninstallReturn = origin
        uninstallApp = app
        uninstallFiles = Uninstaller.find(app)
        uninstallChecked = Set(uninstallFiles.map(\.path))
        uninstallSizes = [:]
        navigate(forward: true) {
            mode = .uninstallFiles
            setQuery("")
        }

        let files = uninstallFiles
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            for file in files {
                let size = Uninstaller.size(file.path)
                DispatchQueue.main.async {
                    guard let self, self.uninstallApp?.id == app.id else { return }
                    self.uninstallSizes[file.path] = size
                    if self.mode == .uninstallFiles { self.refresh() }
                }
            }
        }
    }

    private func formatSize(_ bytes: Int64?) -> String {
        bytes.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "…"
    }

    private func uninstallFileItems() -> [ResultItem] {
        guard let app = uninstallApp else { return [] }
        let q = Fuzzy.fold(query.trimmingCharacters(in: .whitespaces))
        let checked = uninstallFiles.filter { uninstallChecked.contains($0.path) }
        let total = checked.reduce(Int64(0)) { $0 + (uninstallSizes[$1.path] ?? 0) }
        let trashTitle = "Mettre à la corbeille (\(checked.count) · \(formatSize(total)))"

        return uninstallFiles
            .filter { q.isEmpty || Fuzzy.fold($0.path + " " + $0.kind).contains(q) }
            .map { file in
                let isChecked = uninstallChecked.contains(file.path)
                return ResultItem(
                    id: "rm:" + file.path,
                    section: file.kind == "Application" ? app.name : "Fichiers associés",
                    title: file.kind == "Application" ? app.name : (file.path as NSString).lastPathComponent,
                    subtitle: file.kind + " · " + Shell.abbreviate(file.path),
                    icon: .file(file.path),
                    accessory: formatSize(uninstallSizes[file.path]),
                    primary: ItemAction(title: isChecked ? "Garder" : "Supprimer") { [unowned self] in
                        if isChecked { uninstallChecked.remove(file.path) } else { uninstallChecked.insert(file.path) }
                        refresh()
                    },
                    secondary: ItemAction(title: trashTitle) { [unowned self] in performUninstall() },
                    tertiary: ItemAction(title: "Afficher dans le Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: file.path)])
                    },
                    checked: isChecked)
            }
    }

    private func performUninstall() {
        guard let app = uninstallApp else { return }
        let paths = uninstallFiles.map(\.path).filter(uninstallChecked.contains)
        guard !paths.isEmpty else {
            flash("Rien de coché")
            return
        }
        guard !uninstalling else { return }
        uninstalling = true
        let bytes = paths.reduce(Int64(0)) { $0 + (uninstallSizes[$1] ?? 0) }

        // L'app tourne : on la ferme d'abord. Elle peut demander d'enregistrer un document — Hello s'efface
        // pour ne pas recouvrir sa fenêtre (le panneau flotte au-dessus des autres).
        let running = NSWorkspace.shared.runningApplications.filter { $0.bundleURL?.path == app.path }
        if !running.isEmpty {
            c.hide()
            running.forEach { $0.terminate() }
        }

        waitForExit(running, until: Date().addingTimeInterval(15)) { [unowned self] quit in
            guard quit else {
                finishUninstall("\(app.name) est toujours ouverte — quitte-la puis réessaie")
                return
            }
            // Fichiers protégés : le Finder demande le mot de passe. Hello s'efface pendant ce temps et
            // reste réactif (la mise à la corbeille se fait hors du fil principal).
            Uninstaller.trash(paths, beforeFinder: { [unowned self] in c.hide() }) { [unowned self] done, failed in
                c.apps.refresh()
                finishUninstall(failed.isEmpty
                    ? "\(app.name) désinstallée — \(done) élément(s), \(formatSize(bytes)) à la corbeille"
                    : "\(failed.count) élément(s) n'ont pas pu être supprimés")
            }
        }
    }

    /// Attend la fin des apps sans bloquer le fil principal (une app peut afficher « Enregistrer ? » avant de quitter).
    private func waitForExit(_ apps: [NSRunningApplication], until deadline: Date, then: @escaping (Bool) -> Void) {
        if apps.allSatisfy(\.isTerminated) { return then(true) }
        if Date() > deadline { return then(false) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.waitForExit(apps, until: deadline, then: then)
        }
    }

    private func finishUninstall(_ message: String) {
        uninstalling = false
        uninstallApp = nil
        if !c.isVisible { c.show() }
        reset(to: .root)
        flash(message)
    }

    // MARK: - Statistiques

    func statsName(_ id: String) -> (name: String, icon: ItemIcon)? {
        if id.hasPrefix("path:") {
            let path = String(id.dropFirst(5))
            return Shell.isFolder(path) ? (Shell.abbreviate(path), .file(path)) : nil
        }
        if id.hasPrefix("custom:"),
           let custom = AppSettings.shared.customCommands.first(where: { "custom:" + $0.id.uuidString == id }) {
            return (custom.name, .symbol("terminal.fill", .teal))
        }
        if let app = c.apps.apps.first(where: { $0.id == id }) { return (app.name, .file(app.path)) }
        if let command = commands.first(where: { $0.id == id }) { return (command.title, command.icon) }
        return nil
    }

    private func statsItems() -> [ResultItem] {
        let q = Fuzzy.fold(query.trimmingCharacters(in: .whitespaces))
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        var rank = 0
        return Usage.top(200).compactMap { id -> ResultItem? in
            guard let info = statsName(id), let record = Usage.records[id] else { return nil }
            rank += 1
            if !q.isEmpty && !Fuzzy.fold(info.name).contains(q) { return nil }
            let week = Usage.launches(id, inLast: 7)
            let app = c.apps.apps.first { $0.id == id }
            return ResultItem(
                id: "stats:" + id, title: "\(rank). \(info.name)",
                subtitle: "\(record.count) ouverture\(record.count > 1 ? "s" : "") · \(week) cette semaine · "
                    + formatter.localizedString(for: record.last, relativeTo: Date()),
                icon: info.icon,
                accessory: Usage.shortcuts(id).map { "« \($0) »" }.joined(separator: " "),
                primary: ItemAction(title: "Ouvrir") { [unowned self] in
                    if let app { appItem(app, running: false).primary.run() }
                    else if id.hasPrefix("path:") { pathItem(String(id.dropFirst(5)), completion: nil).primary.run() }
                    else { commands.first { $0.id == id }?.action() }
                },
                remove: ItemAction(title: "Oublier") { [unowned self] in
                    Usage.forget(id)
                    refresh()
                },
                preview: .stats(id))
        }
    }
}

/// Geste de balayage en cours sur la grille d'applications.
struct AppSwipe {
    var horizontal: Bool?
    var offset: CGFloat = 0
    var velocity: CGFloat = 0
    var lastTime: TimeInterval?
    var armed = false
    var bumped = false
}

/// Retours du trackpad Force Touch (sans effet sur une souris ou un trackpad sans haptique).
enum Haptic {
    private static var performer: NSHapticFeedbackPerformer { NSHapticFeedbackManager.defaultPerformer }

    /// Le retour le plus marqué de macOS (celui du clic forcé), doublé pour bien le sentir sous le doigt.
    static func strong() {
        performer.perform(.levelChange, performanceTime: .now)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
            performer.perform(.levelChange, performanceTime: .now)
        }
    }

    static func tick() {
        performer.perform(.generic, performanceTime: .now)
    }
}

/// Geste du trackpad en cours (grille d'applications et balayage depuis l'accueil).
final class PagerState: ObservableObject {
    /// Position en pages, indépendante de la taille animée du panneau.
    @Published private(set) var position: CGFloat = 0

    func drag(_ offset: CGFloat, page: Int, width: CGFloat) {
        guard width > 0 else { return }
        position = -CGFloat(page) + offset / width
    }

    func settle(page: Int) { position = -CGFloat(page) }

    func reset(page: Int = 0) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { settle(page: page) }
    }
    /// Accueil : progression du balayage vers la grille (1 = seuil atteint).
    @Published var rootSwipe: CGFloat = 0
}
