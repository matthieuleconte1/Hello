import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum SettingsTab: String, CaseIterable, Identifiable {
    case general, appearance, motion, search, commands, agent, clipboard, stats, permissions
    var id: String { rawValue }

    /// Groupes de la barre latérale.
    static let groups: [[SettingsTab]] = [
        [.general, .appearance, .motion],
        [.search, .commands, .agent],
        [.clipboard, .stats],
        [.permissions],
    ]

    var title: String {
        switch self {
        case .general: "Général"
        case .appearance: "Apparence"
        case .motion: "Animations"
        case .search: "Recherche & Terminal"
        case .commands: "Commandes perso"
        case .agent: "Agent IA"
        case .clipboard: "Presse-papiers & Emoji"
        case .stats: "Statistiques"
        case .permissions: "Permissions"
        }
    }

    /// Phrase sous le titre, en tête du panneau.
    var subtitle: String {
        switch self {
        case .general: "Raccourci pour ouvrir Hello, démarrage et icône dans la barre des menus."
        case .appearance: "Style du panneau, couleurs, mise en page et taille. Tout s'applique dès la prochaine ouverture."
        case .motion: "Chaque style a ses propres animations : ouverture, arrivée des résultats, navigation et lancement."
        case .search: "Classement des résultats, commandes shell, terminal et éditeur utilisés."
        case .commands: "Tes mots-clés avec argument : « gh apple/swift », « yt lofi »…"
        case .agent: "L'IA répond, cherche ou code pour toi, avec le fournisseur et le modèle adaptés à chaque niveau."
        case .clipboard: "Historique du presse-papiers, collage direct et emoji."
        case .stats: "Ce que tu ouvres le plus, et les raccourcis que Hello a appris."
        case .permissions: "Ce dont Hello a besoin, et rien de plus."
        }
    }

    /// Mots trouvés par la recherche des réglages (en plus du titre et de la phrase).
    var keywords: String {
        switch self {
        case .general: "raccourci hotkey clavier commande espace démarrage session ouverture barre des menus icône accueil données dossier"
        case .appearance: "style thème couleurs palette accent verre liquid glass atelier material phosphore papier néo-brutal focus "
            + "clair sombre forme icônes taille position arrondi ombre densité compacte aérée texte sous-titres type raccourcis"
        case .motion: "animations mouvement vitesse lent rapide intensité subtiles expressives cascade reflet effet ouverture lancement ressort"
        case .search: "recherche terminal shell zsh historique zoxide éditeur frécence apprentissage récents classement"
        case .commands: "commandes perso mots-clés url argument raccourci web"
        case .agent: "hermes ia intelligence artificielle modèle agent luna claude gpt raisonnement recherche"
        case .clipboard: "presse-papiers historique emoji coller images confidentiels limite durée symboles"
        case .stats: "statistiques usage réinitialiser oublier raccourcis appris"
        case .permissions: "accessibilité finder spotlight accès disque automatisation autorisations"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .appearance: "paintbrush"
        case .motion: "wand.and.stars"
        case .search: "magnifyingglass"
        case .commands: "terminal"
        case .agent: "sparkles"
        case .clipboard: "doc.on.clipboard"
        case .stats: "chart.bar.xaxis"
        case .permissions: "checkmark.shield"
        }
    }

    var tint: Color {
        switch self {
        case .general: .gray
        case .appearance: .blue
        case .motion: .pink
        case .search: .indigo
        case .commands: Color(white: 0.3)
        case .agent: .purple
        case .clipboard: .cyan
        case .stats: .teal
        case .permissions: .green
        }
    }

    func matches(_ query: String) -> Bool {
        let words = Fuzzy.fold(query).split(separator: " ")
        let haystack = Fuzzy.fold(title + " " + subtitle + " " + keywords)
        return words.allSatisfy { haystack.contains($0) }
    }
}

/// Icône de la barre latérale des réglages : symbole blanc sur pastille colorée, comme Réglages Système.
struct SettingsIcon: View {
    let symbol: String
    let tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(tint.gradient)
            .frame(width: 22, height: 22)
            .overlay(Image(systemName: symbol).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(.white))
    }
}

/// Panneau affiché, retenu d'une ouverture à l'autre (comme Réglages Système).
final class TabSelection: ObservableObject {
    @Published var tab = SettingsTab(rawValue: UserDefaults.standard.string(forKey: "settingsTab") ?? "") ?? .general {
        didSet { UserDefaults.standard.set(tab.rawValue, forKey: "settingsTab") }
    }
}

final class OnboardingState: ObservableObject {
    @Published var step = 0
}

/// Confirmation native (évite @State, indisponible sans Xcode complet).
func confirm(_ title: String, button: String) -> Bool {
    let alert = NSAlert()
    alert.messageText = title
    alert.alertStyle = .warning
    alert.addButton(withTitle: button)
    alert.addButton(withTitle: "Annuler")
    return alert.runModal() == .alertFirstButtonReturn
}

enum WindowManager {
    private static var settingsWindow: NSWindow?
    private static var onboardingWindow: NSWindow?
    private static let selection = TabSelection()

    static func showSettings(tab: SettingsTab? = nil) {
        Controller.shared.hide()
        if let tab { selection.tab = tab }
        if settingsWindow == nil {
            let window = makeWindow(size: NSSize(width: 940, height: 700),
                                    content: SettingsView(selection: selection))
            window.title = "Réglages de Hello"
            window.toolbarStyle = .unified
            window.toolbar = NSToolbar()
            settingsWindow = window
        }
        present(settingsWindow!)
    }

    /// Titre de la fenêtre : le panneau affiché, comme Réglages Système.
    static func setSettingsTitle(_ title: String) {
        settingsWindow?.title = title
    }

    static func showOnboarding() {
        Controller.shared.hide()
        onboardingWindow?.close()
        let window = makeWindow(size: NSSize(width: 620, height: 560), content: OnboardingView(state: OnboardingState()))
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        onboardingWindow = window
        present(window)
    }

    static func closeOnboarding() {
        onboardingWindow?.close()
        onboardingWindow = nil
    }

    private static func makeWindow<V: View>(size: NSSize, content: V) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = NSHostingView(rootView: content)
        window.center()
        return window
    }

    private static func present(_ window: NSWindow) {
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
}

// MARK: - Composants partagés

struct PermissionRow<Actions: View>: View {
    let symbol: String
    let tint: Color
    let title: String
    let detail: String
    let ok: Bool
    var optional = false
    @ViewBuilder var actions: Actions

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint.gradient)
                .frame(width: 32, height: 32)
                .overlay(Image(systemName: symbol).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    if optional {
                        Text("facultatif").font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Capsule().fill(Color.primary.opacity(0.08)))
                            .foregroundStyle(.secondary)
                    }
                }
                Text(detail).font(.system(size: 11.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) { actions }.padding(.top, 3)
            }
            Spacer(minLength: 8)
            StatusBadge(ok: ok, optional: optional)
        }
        .padding(.vertical, 4)
    }
}

struct StatusBadge: View {
    let ok: Bool
    var optional = false

    var body: some View {
        Label(ok ? "OK" : (optional ? "Non" : "Requis"),
              systemImage: ok ? "checkmark.circle.fill" : (optional ? "minus.circle" : "exclamationmark.triangle.fill"))
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(ok ? Color.green : (optional ? Color.secondary : Color.orange))
            .labelStyle(.titleAndIcon)
    }
}

/// Liste de vérification réutilisée par l'onboarding et les réglages.
struct PermissionChecklist: View {
    @ObservedObject var center = PermissionCenter.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PermissionRow(symbol: "command", tint: .indigo, title: "Raccourci \(Prefs.hotkey.label)",
                          detail: hotkeyDetail, ok: center.hotkeyActive) {
                if !center.hotkeyActive {
                    if center.spotlightConflict {
                        Button("Désactiver ⌘ Espace de Spotlight") { center.disableSpotlightShortcut() }
                    }
                    if center.raycastRunning {
                        Button("Quitter Raycast") { center.quitRaycast() }
                    }
                    Button("Réessayer") { center.retryHotkey() }
                }
            }
            PermissionRow(symbol: "accessibility", tint: .blue, title: "Accessibilité",
                          detail: "Permet de coller directement emoji et éléments du presse-papiers dans l'app active. "
                              + "Sans elle, Hello copie seulement. Après une recompilation, retire Hello de la liste puis rajoute-le.",
                          ok: center.accessibility) {
                if !center.accessibility {
                    Button("Autoriser…") { center.requestAccessibility() }
                    Button("Ouvrir les Réglages") { center.openSettings("Privacy_Accessibility") }
                }
            }
            PermissionRow(symbol: "folder.badge.gearshape", tint: .teal, title: "Contrôle du Finder",
                          detail: "Pour supprimer les fichiers protégés lors d'une désinstallation (le Finder demande le mot de passe).",
                          ok: center.automation == .granted, optional: true) {
                if center.automation != .granted {
                    Button(center.automation == .denied ? "Ouvrir les Réglages" : "Autoriser…") { center.requestAutomation() }
                }
            }
            PermissionRow(symbol: "internaldrive", tint: .gray, title: "Accès complet au disque",
                          detail: "Pour mesurer et nettoyer les données d'autres apps (conteneurs) sans demande à chaque fois.",
                          ok: center.fullDisk, optional: true) {
                if !center.fullDisk {
                    Button("Ouvrir les Réglages") { center.openFullDiskSettings() }
                }
            }
        }
        .controlSize(.small)
        .onAppear { center.startWatching() }
        .onDisappear { center.stopWatching() }
    }

    private var hotkeyDetail: String {
        if center.hotkeyActive { return "Actif : appuie dessus n'importe où pour ouvrir Hello." }
        if center.spotlightConflict { return "Spotlight utilise déjà ce raccourci." }
        if center.raycastRunning { return "Raycast tourne et utilise sans doute ce raccourci." }
        return "Une autre app utilise ce raccourci. Choisis-en un autre ou libère-le."
    }
}

/// Vérification de l'agent IA (Hermes), réutilisée par l'onboarding et les réglages.
struct AgentChecklist: View {
    @ObservedObject private var hermes = HermesStatus.shared
    @ObservedObject private var engines = EngineStatus.shared
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PermissionRow(symbol: "sparkles", tint: .purple, title: "Hermes Agent",
                          detail: hermes.binary.map { "Installé : \($0)" }
                              ?? "L'agent IA de Nous Research, utilisé par Hello pour « ? ta demande ». "
                              + "L'installation se fait dans le Terminal (quelques minutes).",
                          ok: hermes.binary != nil, optional: true) {
                if hermes.binary == nil {
                    Button("Installer dans \(Shell.terminal.name)") { Shell.runInTerminal(Hermes.installCommand) }
                    Button("Copier la commande") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(Hermes.installCommand, forType: .string)
                    }
                }
            }
            PermissionRow(symbol: "person.crop.circle.badge.checkmark", tint: .green, title: "Compte IA connecté",
                          detail: accountsDetail, ok: !hermes.providers.isEmpty, optional: true) {
                if hermes.binary != nil {
                    Button(hermes.providers.isEmpty ? "Se connecter…" : "Changer de compte…") {
                        Shell.runInTerminal("hermes model")
                    }
                }
            }
            ForEach([AgentEngine.claude, .codex]) { engine in
                PermissionRow(symbol: engine == .claude ? "asterisk" : "chevron.left.forwardslash.chevron.right",
                              tint: engine == .claude ? .orange : .teal, title: engine.title,
                              detail: engine.binary.map { "Installé : \($0)" }
                                  ?? "Optionnel : un autre fournisseur possible pour chaque niveau, avec ton compte "
                                  + (engine == .claude ? "Claude." : "ChatGPT."),
                              ok: engine.installed, optional: true) {
                    if !engine.installed {
                        Button("Installer dans \(Shell.terminal.name)") { Shell.runInTerminal(engine.installCommand) }
                    }
                }
            }
            PermissionRow(symbol: "cpu", tint: .orange, title: "Modèles utilisés",
                          detail: "Fast : \(AgentLevel.fast.modelLabel)\nRecherche & Action : \(AgentLevel.work.modelLabel)\n"
                              + "Code : \(AgentLevel.code.modelLabel)",
                          ok: AgentLevel.allCases.allSatisfy { $0.config.engine.installed }, optional: true) {
                EmptyView()
            }
            HStack {
                Toggle("Activer l'agent dans Hello", isOn: $settings.agentEnabled).toggleStyle(.switch)
                Spacer()
                if hermes.checking { ProgressView().controlSize(.small) }
                Button("Revérifier") {
                    Hermes.locate()
                    EngineStatus.locate()
                }.disabled(hermes.checking)
            }
        }
        .controlSize(.small)
        .onAppear {
            Hermes.locate()
            EngineStatus.locate()
        }
        // Retour du Terminal après l'installation ou la connexion : on revérifie.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Hermes.locate()
            EngineStatus.locate()
        }
    }

    private var accountsDetail: String {
        if hermes.binary == nil { return "Installe d'abord Hermes Agent." }
        if hermes.providers.isEmpty {
            return "Connecte un compte (ChatGPT, Claude, Copilot, OpenRouter…) : choisis un provider puis un modèle dans le Terminal."
        }
        return hermes.providers.map(Hermes.providerName).joined(separator: ", ")
    }
}

struct HotkeyPicker: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Picker("Raccourci pour ouvrir Hello", selection: Binding(get: { Prefs.hotkey.id }, set: { id in
            guard let choice = Prefs.hotkeys.first(where: { $0.id == id }) else { return }
            Prefs.hotkey = choice
            Controller.shared.applyHotkey()
            PermissionCenter.shared.refresh()
        })) {
            ForEach(Prefs.hotkeys, id: \.id) { Text($0.label).tag($0.id) }
        }
    }
}

// MARK: - Onboarding

struct OnboardingView: View {
    @ObservedObject var state: OnboardingState
    private var step: Int { state.step }
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var center = PermissionCenter.shared
    private let steps = 5

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch step {
                case 0: welcome
                case 1: shortcut
                case 2: permissions
                case 3: agent
                default: ready
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 44)
            .padding(.top, 40)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)))
            .id(step)

            HStack {
                if step > 0 {
                    Button("Retour") { go(step - 1) }.keyboardShortcut(.cancelAction)
                }
                Spacer()
                HStack(spacing: 6) {
                    ForEach(0..<steps, id: \.self) { i in
                        Capsule().fill(i == step ? Color.primary : Color.primary.opacity(0.2))
                            .frame(width: i == step ? 18 : 6, height: 6)
                    }
                }
                Spacer()
                Button(step == steps - 1 ? "Commencer" : "Continuer") {
                    if step == steps - 1 { finish() } else { go(step + 1) }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(20)
        }
        .frame(width: 620, height: 560)
        .glassPanel(cornerRadius: 0)
        .onAppear { center.startWatching() }
        .onDisappear { center.stopWatching() }
    }

    private func go(_ newStep: Int) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { state.step = newStep }
    }

    private func finish() {
        settings.onboarded = true
        WindowManager.closeOnboarding()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { Controller.shared.show() }
    }

    private var welcome: some View {
        VStack(spacing: 18) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 96, height: 96)
            Text("Bienvenue dans Hello").font(.system(size: 28, weight: .bold))
            Text("Un lanceur rapide et léger pour ton Mac.").font(.system(size: 14)).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 12) {
                Feature(symbol: "app.badge", tint: .blue, title: "Apps", text: "Ouvre n'importe quelle app en 1 ou 2 lettres, Hello apprend tes habitudes.")
                Feature(symbol: "terminal", tint: .gray, title: "Terminal", text: "« cd ./code » ouvre un dossier, « > commande » l'exécute.")
                Feature(symbol: "face.smiling", tint: .orange, title: "Emoji & Unicode", text: "Recherche en français, collage direct.")
                Feature(symbol: "doc.on.clipboard", tint: .cyan, title: "Presse-papiers", text: "Tout ce que tu copies, retrouvable.")
                Feature(symbol: "sparkles", tint: .purple, title: "Assistant IA", text: "« ? ta demande » : réponse, action ou recherche, via Hermes, Claude Code ou Codex.")
                Feature(symbol: "eyedropper.halffull", tint: .pink, title: "Pipette & plus", text: "Couleurs, barre des menus, désinstallation propre.")
            }
            .padding(.top, 8)
        }
    }

    private var shortcut: some View {
        VStack(alignment: .leading, spacing: 18) {
            StepHeader(symbol: "command", title: "Ton raccourci", text: "La touche magique pour faire apparaître Hello, où que tu sois.")
            VStack(spacing: 8) {
                ForEach(Prefs.hotkeys, id: \.id) { choice in
                    Button {
                        Prefs.hotkey = choice
                        Controller.shared.applyHotkey()
                        center.refresh()
                    } label: {
                        HStack {
                            Text(choice.label).font(.system(size: 15, weight: .semibold, design: .rounded))
                            if choice.id == "cmd-space" { Text("recommandé").font(.system(size: 11)).foregroundStyle(.secondary) }
                            Spacer()
                            if Prefs.hotkey.id == choice.id {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor)
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.primary.opacity(Prefs.hotkey.id == choice.id ? 0.12 : 0.05)))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .id(center.hotkeyActive)
            HStack {
                StatusBadge(ok: center.hotkeyActive)
                Text(center.hotkeyActive ? "Raccourci actif" : "Raccourci déjà utilisé ailleurs")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                Spacer()
                if !center.hotkeyActive && center.spotlightConflict {
                    Button("Libérer de Spotlight") { center.disableSpotlightShortcut() }.controlSize(.small)
                }
                if !center.hotkeyActive && center.raycastRunning {
                    Button("Quitter Raycast") { center.quitRaycast() }.controlSize(.small)
                }
            }
        }
    }

    private var permissions: some View {
        VStack(alignment: .leading, spacing: 18) {
            StepHeader(symbol: "checkmark.shield", title: "Vérification des permissions",
                       text: "Hello n'a besoin que du strict minimum. Tout se met à jour en direct.")
            ScrollView { PermissionChecklist() }
        }
    }

    private var agent: some View {
        VStack(alignment: .leading, spacing: 18) {
            StepHeader(symbol: "sparkles", title: "Assistant IA",
                       text: "Tape « ? ta demande » dans Hello : réponse, action rapide, recherche web ou session dans le terminal. "
                           + "Facultatif : tout le reste de Hello fonctionne sans.")
            ScrollView { AgentChecklist() }
        }
    }

    private var ready: some View {
        VStack(alignment: .leading, spacing: 18) {
            StepHeader(symbol: "checkmark.circle", title: "Presque prêt", text: "Quelques réglages rapides (tout est modifiable ensuite avec ⌘,).")
            VStack(spacing: 0) {
                ToggleRow(title: "Lancer Hello à l'ouverture de session",
                          isOn: Binding(get: { center.launchAtLogin }, set: { center.setLaunchAtLogin($0) }))
                Divider().opacity(0.4)
                ToggleRow(title: "Icône dans la barre des menus", isOn: $settings.showMenuBarIcon)
                Divider().opacity(0.4)
                ToggleRow(title: "Historique du presse-papiers", isOn: $settings.clipboardEnabled)
                Divider().opacity(0.4)
                ToggleRow(title: "Animations", isOn: $settings.animations)
            }
            .padding(.horizontal, 14)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.05)))

            VStack(alignment: .leading, spacing: 6) {
                Text("Essaie en premier :").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                Text("\(Prefs.hotkey.label)  puis  « saf »,  « cd ./code »,  « emoji »,  « stats »"
                     + (Hermes.available ? ",  « ? météo à Paris »" : ""))
                    .font(.system(size: 12.5, design: .monospaced))
            }
        }
    }
}

private struct Feature: View {
    let symbol: String
    let tint: Color
    let title: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(tint.gradient).frame(width: 30, height: 30)
                .overlay(Image(systemName: symbol).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(text).font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }
    }
}

private struct StepHeader: View {
    let symbol: String
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol).font(.system(size: 26, weight: .medium)).foregroundStyle(Color.accentColor)
            Text(title).font(.system(size: 24, weight: .bold))
            Text(text).font(.system(size: 13)).foregroundStyle(.secondary)
        }
    }
}

private struct ToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) { Text(title).font(.system(size: 13)) }
            .toggleStyle(.switch)
            .padding(.vertical, 9)
    }
}

// MARK: - Réglages

final class SettingsSearch: ObservableObject {
    @Published var query = ""
}

/// Réglages façon Réglages Système (macOS 26 / 27) : barre latérale en verre avec recherche et carte Hello,
/// panneaux groupés qui s'ouvrent sur une grande icône, un titre et une phrase.
struct SettingsView: View {
    @ObservedObject var selection: TabSelection
    @StateObject private var search = SettingsSearch()

    var body: some View {
        NavigationSplitView {
            List(selection: $selection.tab) {
                if search.query.trimmingCharacters(in: .whitespaces).isEmpty {
                    Section { HelloSidebarCard() }
                    ForEach(Array(SettingsTab.groups.enumerated()), id: \.offset) { _, group in
                        Section { ForEach(group) { row($0) } }
                    }
                } else {
                    let found = SettingsTab.allCases.filter { $0.matches(search.query) }
                    Section("Résultats") {
                        ForEach(found) { row($0) }
                        if found.isEmpty {
                            Text("Aucun réglage trouvé").foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .searchable(text: $search.query, placement: .sidebar, prompt: "Rechercher")
            .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
        } detail: {
            Group {
                switch selection.tab {
                case .general: GeneralSettings()
                case .appearance: AppearanceSettings()
                case .motion: MotionSettings()
                case .search: SearchSettings()
                case .commands: CustomCommandsSettings()
                case .agent: AgentSettings()
                case .clipboard: ClipboardSettings()
                case .stats: StatsSettings()
                case .permissions: PermissionsSettings()
                }
            }
            .formStyle(.grouped)
            .navigationTitle(selection.tab.title)
            .id(selection.tab)
        }
        .frame(minWidth: 860, minHeight: 600)
        .onAppear { WindowManager.setSettingsTitle(selection.tab.title) }
        .onChange(of: selection.tab) { _, tab in WindowManager.setSettingsTitle(tab.title) }
    }

    private func row(_ tab: SettingsTab) -> some View {
        Label { Text(tab.title) } icon: { SettingsIcon(symbol: tab.symbol, tint: tab.tint) }
            .padding(.vertical, 2)
            .tag(tab)
    }
}

/// Carte en tête de la barre latérale, comme le compte Apple dans Réglages Système.
private struct HelloSidebarCard: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 1) {
                Text("Hello").font(.system(size: 13, weight: .semibold))
                Text("\(AppSettings.shared.panelStyle.title) · \(Prefs.hotkey.label)")
                    .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

/// En-tête d'un panneau : grande icône, titre et phrase, centrés (comme les panneaux de Réglages Système).
struct PaneHeader: View {
    let tab: SettingsTab

    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(tab.tint.gradient)
                .frame(width: 60, height: 60)
                .overlay(Image(systemName: tab.symbol).font(.system(size: 28, weight: .medium)).foregroundStyle(.white))
                .shadow(color: tab.tint.opacity(0.35), radius: 10, y: 4)
            Text(tab.title).font(.system(size: 22, weight: .bold))
            Text(tab.subtitle)
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
        .padding(.bottom, 18)
    }
}

/// Formulaire d'un panneau, précédé de son en-tête (qui défile avec lui).
struct SettingsForm<Content: View>: View {
    let tab: SettingsTab
    @ViewBuilder let content: Content

    var body: some View {
        Form {
            // En-tête de section (et non une ligne) : pas de carte grise autour, comme dans Réglages Système.
            Section {} header: {
                PaneHeader(tab: tab)
                    .textCase(nil)
                    .foregroundStyle(.primary)
            }
            content
        }
    }
}

private struct GeneralSettings: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var center = PermissionCenter.shared

    var body: some View {
        SettingsForm(tab: .general) {
            Section {
                HotkeyPicker()
                LabeledContent("État") {
                    StatusBadge(ok: center.hotkeyActive)
                }
            } header: { Text("Raccourci") } footer: {
                Text("⌘ Espace nécessite de désactiver le raccourci de Spotlight (voir Permissions).")
            }
            Section("Démarrage") {
                Toggle("Lancer Hello à l'ouverture de session",
                       isOn: Binding(get: { center.launchAtLogin }, set: { center.setLaunchAtLogin($0) }))
                Toggle("Icône dans la barre des menus", isOn: $settings.showMenuBarIcon)
            }
            Section {
                Button("Revoir l'accueil…") { WindowManager.showOnboarding() }
            } footer: {
                Text("Sans icône dans la barre des menus, relance Hello depuis le Finder pour ouvrir le panneau.")
            }
            UpdateSettings()
            Section {
                Button("Afficher les données dans le Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([ClipboardHistory.dir])
                }
            } header: { Text("Données") } footer: {
                Text("Historique, statistiques et images restent sur ce Mac, dans ~/Library/Application Support/Hello.")
            }
        }
        .onAppear { center.startWatching() }
        .onDisappear { center.stopWatching() }
    }
}

private struct AppearanceSettings: View {
    @ObservedObject private var settings = AppSettings.shared

    private var tint: Binding<Color> {
        Binding(get: { Color(hex: settings.glassTintHex) }, set: { settings.glassTintHex = $0.hexString })
    }

    private var highlight: Binding<Color> {
        Binding(get: { Color(hex: settings.highlightHex) }, set: { settings.highlightHex = $0.hexString })
    }

    var body: some View {
        SettingsForm(tab: .appearance) {
            Section {
                if settings.panelStyle == .glass {
                    LookPreview(settings: settings)
                        .listRowInsets(EdgeInsets())
                } else {
                    ZStack {
                        StyleCard.backdrop(settings.panelStyle)
                        StyleSample(style: settings.panelStyle)
                    }
                    .frame(height: 250)
                    .listRowInsets(EdgeInsets())
                }
            }

            Section {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 14) {
                    ForEach(PanelStyle.allCases) { style in
                        StyleCard(style: style, selected: settings.panelStyle == style) {
                            withAnimation(.snappy(duration: 0.25)) { settings.panelStyle = style }
                        }
                    }
                }
                .padding(.vertical, 6)
            } header: { Text("Style") } footer: {
                Text(settings.panelStyle.detail + " Aussi depuis Hello : tape « style ».")
            }

            switch settings.panelStyle {
            case .glass: glassSections
            case .atelier: atelierSections
            case .glyph: glyphSections
            case .phosphor:
                Section {
                    SwatchRow(items: PhosphorColor.allCases.map { ($0.id, $0.title, [$0.colors.ink, $0.colors.screen]) },
                              selected: settings.phosphorColor.id) { id in
                        settings.phosphorColor = PhosphorColor(rawValue: id) ?? .green
                    }
                } header: { Text("Phosphore") } footer: {
                    Text("La couleur des vieux écrans : vert P1 des terminaux, ambre P3 des Minitel et IBM 5151, blanc P4 des télés.")
                }
            case .paper:
                Section("Papier") {
                    Picker("Teinte", selection: $settings.paperTone) {
                        ForEach(PaperTone.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
            case .brutal:
                Section("Néo-brutal") {
                    SwatchRow(items: BrutalColor.allCases.map { ($0.id, $0.title, [$0.color]) },
                              selected: settings.brutalColor.id) { id in
                        settings.brutalColor = BrutalColor(rawValue: id) ?? .pink
                    }
                }
            }

            Section {
                Toggle("Mode focus", isOn: $settings.focusMode)
            } header: { Text("Ouverture") } footer: {
                Text("Seulement la barre de recherche à l'ouverture : les résultats apparaissent dès que tu tapes, "
                     + "comme Spotlight. Aussi depuis Hello : tape « focus ».")
            }

            Section {
                Picker("Densité des lignes", selection: $settings.rowDensity) {
                    ForEach(RowDensity.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                LabeledContent("Taille du texte") {
                    HStack {
                        Slider(value: $settings.textScale, in: 0.85...1.25, step: 0.05) { EmptyView() }
                            minimumValueLabel: { Image(systemName: "textformat.size.smaller") }
                            maximumValueLabel: { Image(systemName: "textformat.size.larger") }
                        Text("\(Int((settings.textScale * 100).rounded())) %").monospacedDigit().foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .trailing)
                    }
                }
                Toggle("Sous-titres des résultats", isOn: $settings.showSubtitles)
                Toggle("Type des résultats (Commande, Dossier…)", isOn: $settings.showAccessories)
                Toggle("Raccourcis clavier en bas du panneau", isOn: $settings.showHints)
            } header: { Text("Mise en page") } footer: {
                Text("En densité compacte, les sous-titres sont masqués.")
            }

            Section("Panneau") {
                Picker("Taille", selection: $settings.panelSize) {
                    ForEach(PanelSize.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Position", selection: $settings.panelPosition) {
                    ForEach(PanelPosition.allCases) { Text($0.title).tag($0) }
                }
                if settings.panelStyle == .glass {
                    LabeledContent("Arrondi des coins") {
                        HStack {
                            Slider(value: $settings.cornerRadius, in: 12...32, step: 2)
                            Text("\(Int(settings.cornerRadius)) pt").monospacedDigit().foregroundStyle(.secondary)
                                .frame(width: 40, alignment: .trailing)
                        }
                    }
                }
                LabeledContent("Ombre") {
                    Slider(value: $settings.shadowStrength, in: 0...1) { EmptyView() }
                        minimumValueLabel: { Image(systemName: "square") }
                        maximumValueLabel: { Image(systemName: "square.fill") }
                }
            }

            Section {
                HStack {
                    Button("Ouvrir le panneau") { Controller.shared.show() }
                    Spacer()
                    Button("Rétablir l'apparence par défaut") {
                        withAnimation(.snappy(duration: 0.25)) { settings.resetAppearance() }
                    }
                }
            }
        }
    }

    /// Réglages propres au style Atelier (Material 3 Expressive).
    @ViewBuilder private var atelierSections: some View {
        Section {
            HStack(alignment: .top, spacing: 14) {
                ForEach(AtelierPalette.allCases) { palette in
                    PaletteSwatch(palette: palette, selected: settings.atelierPalette == palette) {
                        settings.atelierPalette = palette
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 6)
            Toggle("Inverser les deux accents", isOn: $settings.atelierSwap)
        } header: { Text("Couleurs") } footer: {
            Text("Le premier accent colore le bouton, la touche ↵ et la sélection en couleur ; le second, les pastilles "
                 + "d'icônes. Le reste reste neutre. Aussi depuis Hello : tape « couleurs ».")
        }

        Section("Atelier") {
            Picker("Apparence", selection: $settings.atelierAppearance) {
                ForEach(ThemeAppearance.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            Toggle("Sélection en couleur en mode clair", isOn: $settings.atelierColoredSelection)
                .disabled(settings.atelierAppearance == .dark)
            LabeledContent("Forme des icônes sélectionnées") {
                HStack(spacing: 6) {
                    ForEach(AtelierShape.allCases) { shape in
                        Button { settings.atelierShape = shape } label: {
                            CookieShape(lobes: shape.lobes, depth: shape.depth)
                                .fill(settings.atelierShape == shape ? AtelierPalette.current.primary : Color.primary.opacity(0.25))
                                .frame(width: 24, height: 24)
                                .padding(4)
                                .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(settings.atelierShape == shape ? Color.primary.opacity(0.12) : .clear))
                                .rotationEffect(.degrees(settings.atelierShape == shape ? 20 : 0))
                                .animation(StyleTokens.Atelier.spring, value: settings.atelierShape)
                        }
                        .buttonStyle(.plain)
                        .help(shape.title)
                    }
                }
            }
        }
    }

    /// Réglages propres au style Atelier Glyphe.
    @ViewBuilder private var glyphSections: some View {
        let night = settings.glyphEffectiveAppearance == .night
        Section {
            SwatchRow(items: GlyphAccent.allCases.map { ($0.id, $0.title, [$0.swatch]) },
                      selected: settings.glyphAccent.id) { id in
                settings.glyphAccent = GlyphAccent(rawValue: id) ?? .orange
            }
            .disabled(night)
            Picker("Apparence", selection: $settings.glyphAppearance) {
                ForEach(GlyphAppearance.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
        } header: { Text("Atelier Glyphe") } footer: {
            Text("Une seule couleur, qui marque la touche ↵, le logo et l'icône choisie.")
        }

        Section {
            Toggle("Passer en Nuit automatiquement", isOn: $settings.glyphAutoNight)
            if settings.glyphAutoNight {
                LabeledContent("Entre") {
                    HStack(spacing: 8) {
                        hourPicker($settings.glyphNightStart)
                        Text("et")
                        hourPicker($settings.glyphNightEnd)
                    }
                }
            }
            LabeledContent("Luminosité") {
                HStack {
                    Slider(value: $settings.glyphNightLevel, in: 0.4...1) { EmptyView() }
                        minimumValueLabel: { Image(systemName: "moon") }
                        maximumValueLabel: { Image(systemName: "moon.fill") }
                    Text("\(Int((settings.glyphNightLevel * 100).rounded())) %").monospacedDigit().foregroundStyle(.secondary)
                        .frame(width: 44, alignment: .trailing)
                }
            }
            .disabled(!night && !settings.glyphAutoNight && settings.glyphAppearance != .night)
        } header: { Text("Nuit") } footer: {
            Text((night ? "La Nuit est active. " : "")
                 + "Tout passe en un seul rouge sur noir pour préserver la vision nocturne : la forme prend le relais "
                 + "de la couleur (rempli = choisi, au trait = disponible), les icônes d'apps virent au rouge et rien "
                 + "ne s'éclaire d'une autre couleur. L'heure est vérifiée à chaque ouverture de Hello.")
        }
    }

    private func hourPicker(_ hour: Binding<Int>) -> some View {
        Picker("", selection: hour) {
            ForEach(0..<24, id: \.self) { Text("\($0) h").tag($0) }
        }
        .labelsHidden()
        .fixedSize()
    }

    /// Réglages propres au style Verre.
    @ViewBuilder private var glassSections: some View {
        Section("Thèmes") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 14) {
                ForEach(LookPreset.all) { preset in
                    PresetCard(preset: preset, selected: settings.matches(preset)) {
                        withAnimation(.snappy(duration: 0.25)) { settings.apply(preset) }
                    }
                }
            }
            .padding(.vertical, 6)
        }

        Section {
            Picker("Matériau", selection: $settings.glassMaterial) {
                ForEach(GlassMaterial.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            LabeledContent("Teinte") {
                HStack(spacing: 10) {
                    Slider(value: $settings.glassTintAmount, in: 0...0.8)
                    SwiftUI.ColorPicker("", selection: tint, supportsOpacity: false).labelsHidden()
                }
            }
            if settings.glassMaterial == .frosted {
                LabeledContent("Givre") {
                    Slider(value: $settings.frostOpacity, in: 0.3...1) { EmptyView() }
                        minimumValueLabel: { Image(systemName: "drop") }
                        maximumValueLabel: { Image(systemName: "drop.fill") }
                }
            }
            Toggle("Liseré lumineux autour du panneau", isOn: $settings.glassBorder)
        } header: { Text("Verre") } footer: {
            Text(materialFooter)
        }

        Section("Sélection") {
            LabeledContent("Couleur") {
                HStack(spacing: 10) {
                    Slider(value: $settings.highlightAmount, in: 0.05...0.5)
                    SwiftUI.ColorPicker("", selection: highlight, supportsOpacity: false).labelsHidden()
                }
            }
        }
    }

    private var materialFooter: String {
        var text = settings.glassMaterial.detail
        if settings.glassMaterial != .frosted && !GlassMaterial.liquidAvailable {
            text += " Liquid Glass demande macOS 26 : le verre dépoli est utilisé à la place."
        }
        return text + " Teinte à zéro : verre pur, sans voile."
    }
}

/// Fond d'aperçu coloré, pour que le verre, sa teinte et ses reflets se voient.
private struct PreviewWallpaper: View {
    /// Taille des formes (les vignettes des thèmes utilisent une version réduite).
    var scale: CGFloat = 1

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#1B1F4B"), Color(hex: "#3B1E5C"), Color(hex: "#0E3B4F")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            blob("#FF7A59", 180, blur: 50, x: -170, y: -50)
            blob("#7A5CFF", 220, blur: 60, x: 170, y: 40)
            blob("#2FD3C8", 140, blur: 45, x: 30, y: 90)
            // Quelques formes nettes : la réfraction du Liquid Glass se voit sur leurs bords.
            bar(0.85, width: 90, x: -120, y: -78)
            bar(0.6, width: 140, x: 110, y: 84)
        }
        .clipped()
    }

    private func blob(_ hex: String, _ size: CGFloat, blur: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Circle().fill(Color(hex: hex)).frame(width: size * scale, height: size * scale)
            .blur(radius: blur * scale).offset(x: x * scale, y: y * scale)
    }

    private func bar(_ opacity: Double, width: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 8 * scale).fill(Color.white.opacity(opacity))
            .frame(width: width * scale, height: 10 * scale).offset(x: x * scale, y: y * scale)
    }
}

/// Aperçu en direct du panneau avec l'apparence choisie.
private struct LookPreview: View {
    @ObservedObject var settings: AppSettings

    private static let rows: [(String, String, String)] = [
        ("com.apple.Safari", "Safari", "safari"),
        ("com.apple.finder", "Finder", "folder"),
        ("com.apple.systempreferences", "Réglages Système", "gearshape"),
    ]

    var body: some View {
        let radius = PanelLayout.radius * 0.8
        let look = GlassLook(material: settings.glassMaterial,
                             tint: settings.glassTintAmount > 0.001
                                 ? Color(hex: settings.glassTintHex).opacity(settings.glassTintAmount) : nil,
                             frostOpacity: settings.frostOpacity, border: settings.glassBorder, withinWindow: true)
        ZStack {
            PreviewWallpaper()
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    HelloMark(skin: .ink(.primary)).frame(width: 16, height: 16)
                    Text("saf").font(.system(size: 15))
                    Spacer()
                    Image(systemName: "square.grid.3x3.fill").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .frame(height: 40)
                Divider().opacity(0.5)
                VStack(spacing: 2) {
                    ForEach(Array(Self.rows.enumerated()), id: \.offset) { index, row in
                        HStack(spacing: 9) {
                            icon(row.0, fallback: row.2).frame(width: 20, height: 20)
                            Text(row.1).font(.system(size: 12, weight: .medium))
                            Spacer()
                            Text("Application").font(.system(size: 10.5)).foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 9)
                        .frame(height: 32)
                        .background {
                            if index == 0 {
                                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(settings.highlight)
                            }
                        }
                    }
                }
                .padding(6)
                Spacer(minLength: 0)
            }
            .frame(width: 360, height: 190)
            .glassPanel(cornerRadius: radius, look: look)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color.black.opacity(0.35 * settings.shadowStrength))
                    .blur(radius: 14).offset(y: 10)
            }
            .environment(\.colorScheme, .dark)
        }
        .frame(height: 250)
        .animation(.snappy(duration: 0.25), value: settings.cornerRadius)
    }

    @ViewBuilder
    private func icon(_ bundleID: String, fallback: String) -> some View {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            Image(nsImage: IconCache.icon(url.path)).resizable()
        } else {
            ItemIconView(icon: .symbol(fallback, .blue))
        }
    }
}

/// Vignette d'un thème : son verre et sa sélection sur le fond d'aperçu.
private struct PresetCard: View {
    let preset: LookPreset
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                ZStack {
                    PreviewWallpaper(scale: 0.45)
                    VStack(alignment: .leading, spacing: 4) {
                        Capsule().fill(Color.white.opacity(0.55)).frame(width: 34, height: 4)
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color(hex: preset.highlightHex).opacity(preset.highlightAmount + 0.08))
                            .frame(height: 9)
                        Capsule().fill(Color.white.opacity(0.3)).frame(width: 40, height: 4)
                    }
                    .padding(8)
                    .frame(width: 84, height: 48)
                    .glassPanel(cornerRadius: 10, look: GlassLook(preset, withinWindow: true))
                    .environment(\.colorScheme, .dark)
                }
                .frame(height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(selected ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: selected ? 2.5 : 1)
                }
                Text(preset.name)
                    .font(.system(size: 11.5, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? .primary : .secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct SearchSettings: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        SettingsForm(tab: .search) {
            Section {
                Toggle("Classer par fréquence et récence", isOn: $settings.frecencyRanking)
                Toggle("Apprendre mes raccourcis (« s » → Safari)", isOn: $settings.learnQueries)
                Toggle("Afficher les récents quand le champ est vide", isOn: $settings.showRecents)
                Button("Recharger la liste des applications") { Controller.shared.apps.refresh() }
            } header: { Text("Classement") }
            Section {
                Toggle("Commandes terminal (cd, open, > commande)", isOn: $settings.shellCommands)
                Toggle("Suggérer l'historique zsh (~/.zsh_history)", isOn: $settings.zshHistory)
                Toggle("Dossiers fréquents de zoxide (s'il est installé)", isOn: $settings.useZoxide)
                Toggle("Charger ~/.zshrc (alias et fonctions perso)", isOn: $settings.shellInteractive)
                Button("Effacer l'historique des commandes Hello") { ShellHistory.clear() }
                Picker("Terminal", selection: $settings.terminalID) {
                    Text("Automatique (\(Shell.terminal.name))").tag("")
                    ForEach(ExternalApps.installed(ExternalApps.terminals), id: \.id) { Text($0.name).tag($0.id) }
                }
                Picker("Éditeur (⌥↵ sur un dossier)", selection: $settings.editorID) {
                    Text("Automatique").tag("")
                    Text("Aucun").tag("none")
                    ForEach(ExternalApps.installed(ExternalApps.editors), id: \.id) { Text($0.name).tag($0.id) }
                }
            } header: { Text("Terminal") } footer: {
                Text("Les commandes s'exécutent dans zsh depuis ton dossier personnel. « > » seul affiche l'historique, "
                     + "« kill nom » arrête un processus, « port 3000 » ou « :3000 » montre qui écoute, « z nom » saute à un dossier fréquent, « ip » donne ton adresse.")
            }
        }
    }
}

/// Réglages › Général › Mises à jour.
private struct UpdateSettings: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var updater = Updater.shared

    var body: some View {
        Section {
            LabeledContent("Version installée", value: Updater.currentVersion)
            Toggle("Vérifier automatiquement (une fois par jour)", isOn: $settings.autoUpdateCheck)
            Toggle("Inclure les préversions (alpha, bêta)", isOn: $settings.updatePrereleases)
            HStack {
                Text(status).foregroundStyle(.secondary)
                Spacer()
                if updater.busy { ProgressView().controlSize(.small) }
                if let release = updater.pending, !updater.busy {
                    Button("Notes") { NSWorkspace.shared.open(release.page) }
                    Button("Installer \(release.version)") { updater.install() }.keyboardShortcut(.defaultAction)
                } else {
                    Button("Rechercher maintenant") { updater.check() }.disabled(updater.busy)
                }
            }
        } header: { Text("Mises à jour") } footer: {
            Text("Hello cherche les nouvelles versions dans les releases GitHub de \(Updater.repo), télécharge l'app, "
                 + "la remplace et se relance. Tes réglages, ton historique et tes conversations sont gardés.")
        }
    }

    private var status: String {
        switch updater.state {
        case .idle: "Pas encore vérifié."
        case .checking: "Recherche…"
        case .upToDate: "Hello est à jour."
        case .available(let release): "Hello \(release.version) est disponible."
        case .downloading(let progress): "Téléchargement… \(Int(progress * 100)) %"
        case .installing: "Installation… Hello va se relancer."
        case .failed(let message): "Échec : \(message)"
        }
    }
}

private struct AgentSettings: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var chats = ChatStore.shared
    @ObservedObject private var engines = EngineStatus.shared

    /// Fournisseur, modèle et raisonnement d'un niveau. Changer de fournisseur reprend le réglage proposé pour lui.
    @ViewBuilder
    private func levelControls(_ level: AgentLevel, provider: Binding<String>, model: Binding<String>,
                               reasoning: Binding<String>) -> some View {
        let engine = level.config.engine
        Picker("Fournisseur", selection: Binding(get: { engine }, set: { level.setEngine($0) })) {
            ForEach(AgentEngine.allCases) { option in
                Text(option.installed ? option.title : "\(option.title) (non installé)").tag(option)
            }
        }
        if engine == .hermes {
            modelPicker("Modèle", provider: provider, model: model, allowDefault: true)
        } else {
            let known = engine.models
            let choices = model.wrappedValue.isEmpty || known.contains(where: { $0.id == model.wrappedValue })
                ? known : [ModelChoice(id: model.wrappedValue, name: model.wrappedValue)] + known
            Picker("Modèle", selection: model) {
                Text("Défaut de \(engine.title)").tag("")
                ForEach(choices, id: \.id) { Text($0.name).tag($0.id) }
            }
        }
        Picker("Raisonnement", selection: reasoning) {
            Text("Défaut").tag("")
            ForEach(engine.reasoningLevels, id: \.self) { Text($0).tag($0) }
            if !reasoning.wrappedValue.isEmpty && !engine.reasoningLevels.contains(reasoning.wrappedValue) {
                Text(reasoning.wrappedValue).tag(reasoning.wrappedValue)
            }
        }
        if !engine.installed {
            Button("Installer \(engine.title) dans \(Shell.terminal.name)") { Shell.runInTerminal(engine.installCommand) }
        }
    }

    /// Menu groupé par provider ; la sélection est « provider|modèle ».
    private func modelPicker(_ title: String, provider: Binding<String>, model: Binding<String>, allowDefault: Bool) -> some View {
        let current = model.wrappedValue.isEmpty ? "" : provider.wrappedValue + "|" + model.wrappedValue
        var options = Hermes.models
        if !current.isEmpty && !options.contains(where: { $0.tag == current }) {
            options.insert(Hermes.ModelOption(provider: provider.wrappedValue, model: model.wrappedValue), at: 0)
        }
        let providers = options.reduce(into: [String]()) { if !$0.contains($1.provider) { $0.append($1.provider) } }
        let selection = Binding<String>(
            get: { current },
            set: { tag in
                let parts = tag.split(separator: "|", maxSplits: 1).map(String.init)
                provider.wrappedValue = parts.count == 2 ? parts[0] : ""
                model.wrappedValue = parts.count == 2 ? parts[1] : ""
            })
        return Picker(title, selection: selection) {
            if allowDefault { Text("Défaut de Hermes").tag("") }
            ForEach(providers, id: \.self) { p in
                Section(Hermes.providerName(p.isEmpty ? "défaut" : p)) {
                    ForEach(options.filter { $0.provider == p }, id: \.tag) { Text($0.model).tag($0.tag) }
                }
            }
        }
    }

    var body: some View {
        SettingsForm(tab: .agent) {
            Section {
                AgentChecklist().padding(.vertical, 4)
            } footer: {
                Text("Tape « ? ta demande » (ou une phrase). En Auto, le niveau 1 répond tout de suite (Fast) ou "
                     + "passe la main au niveau 2 · Recherche & Action (web et actions sur le Mac, réponse dans Hello) ou "
                     + "au niveau 3 · Code (session dans le terminal). ⌘↵ / « ?? » force le niveau 2, ⌥↵ / « ??? » le niveau 3. "
                     + "Tape « / » pour les commandes : /resume, /new, /retry, /code, /terminal, /copy…")
            }
            Section {
                levelControls(.fast, provider: $settings.agentRouterProvider, model: $settings.agentRouterModel,
                              reasoning: $settings.agentRouterReasoning)
                Picker("Mode", selection: $settings.agentStrategy) {
                    Text("Auto : choisir le niveau selon la demande").tag("auto")
                    Text("Toujours Recherche & Action").tag("act")
                    Text("Toujours Code").tag("delegate")
                }
            } header: { Text("Niveau 1 · Fast / Auto") } footer: {
                Text("Répond seul aux questions simples, sans aucun outil. Pour le reste, il reformule ta demande "
                     + "et la confie au niveau 2 ou 3. Prends un modèle rapide : Luna (Hermes ou Codex), Haiku (Claude Code).")
            }
            Section {
                levelControls(.work, provider: $settings.agentResearchProvider, model: $settings.agentResearchModel,
                              reasoning: $settings.agentResearchReasoning)
            } header: { Text("Niveau 2 · Recherche & Action") } footer: {
                Text("Cherche sur le web et agit sur le Mac (terminal, AppleScript, Raccourcis, captures d'écran), puis répond "
                     + "dans Hello, en direct. Il ne clique jamais à ta place et laisse la dernière étape des actions "
                     + "irréversibles. 5 min maximum. Joins des fichiers avec ⌘O ou ⌘V, une capture avec ⇧⌘S. "
                     + "⌘↵ sur la réponse reprend la conversation dans le terminal. " + workSafety)
            }
            Section {
                levelControls(.code, provider: $settings.agentDefaultProvider, model: $settings.agentDefaultModel,
                              reasoning: $settings.agentDefaultReasoning)
                TextField("Dossier de travail", text: $settings.agentWorkdir)
            } header: { Text("Niveau 3 · Code (terminal)") } footer: {
                Text("Ouvert dans \(Shell.terminal.name) (Réglages › Recherche & Terminal) avec une session interactive du fournisseur, "
                     + "dans le dossier de travail, pour écrire du code, créer une app ou un script, ou tout travail long sur un projet.")
            }
            Section {
                Toggle("Garder l'historique des conversations", isOn: $settings.agentHistory)
                Button("Effacer les \(chats.conversations.count) conversations") {
                    if confirm("Effacer toutes les conversations avec l'IA ?", button: "Effacer") { chats.clear() }
                }
                .disabled(chats.conversations.isEmpty)
            } header: { Text("Mémoire") } footer: {
                Text("Sous une réponse, tape une question de suite : l'IA reçoit les échanges précédents, quel que soit le "
                     + "fournisseur. Les conversations se retrouvent avec « ? », « /resume » ou la commande « Conversations avec "
                     + "l'IA », et sont gardées sur ce Mac (200 au plus). Hermes peut aussi noter dans sa propre mémoire ce "
                     + "qu'il apprend de toi.")
            }
        }
        .onAppear { EngineStatus.locate() }
    }

    /// Ce que le fournisseur du niveau 2 a le droit de faire sans demander.
    private var workSafety: String {
        switch AgentLevel.work.config.engine {
        case .hermes: "Hermes bloque lui-même les commandes dangereuses."
        case .claude: "Claude Code n'a que le terminal, la lecture de fichiers et le web ; rm, sudo et git push lui sont refusés."
        case .codex: "Codex travaille dans son bac à sable : il n'écrit que dans le dossier de travail, avec accès au réseau."
        }
    }
}

private struct CustomCommandsSettings: View {
    @ObservedObject private var settings = AppSettings.shared

    private func binding<T>(_ id: UUID, _ key: WritableKeyPath<CustomCommand, T>, _ fallback: T) -> Binding<T> {
        Binding(
            get: { settings.customCommands.first { $0.id == id }?[keyPath: key] ?? fallback },
            set: { value in
                guard let i = settings.customCommands.firstIndex(where: { $0.id == id }) else { return }
                settings.customCommands[i][keyPath: key] = value
            })
    }

    var body: some View {
        SettingsForm(tab: .commands) {
            ForEach(settings.customCommands) { custom in
                Section {
                    TextField("Nom", text: binding(custom.id, \.name, ""))
                    TextField("Mot-clé", text: binding(custom.id, \.keyword, ""))
                    TextField("Commande", text: binding(custom.id, \.command, ""))
                        .font(.system(size: 12, design: .monospaced))
                    Picker("Exécution", selection: binding(custom.id, \.mode, .app)) {
                        ForEach(CustomCommand.RunMode.allCases) { Text($0.title).tag($0) }
                    }
                    Button("Supprimer", role: .destructive) {
                        settings.customCommands.removeAll { $0.id == custom.id }
                    }
                }
            }
            Section {
                Button("Ajouter une commande") {
                    settings.customCommands.append(CustomCommand(name: "Nouvelle commande", keyword: "", command: "echo Bonjour", mode: .app))
                }
            } footer: {
                Text("« {} » dans la commande est remplacé par ce que tu tapes après le mot-clé : avec le mot-clé « gh » et "
                     + "« open https://github.com/{} », taper « gh apple/swift » ouvre le dépôt. En silence : Hello affiche juste le résultat.")
            }
        }
    }
}

private struct ClipboardSettings: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        SettingsForm(tab: .clipboard) {
            Section("Historique") {
                Toggle("Enregistrer l'historique du presse-papiers", isOn: $settings.clipboardEnabled)
                Picker("Nombre d'éléments", selection: $settings.clipboardLimit) {
                    ForEach([50, 100, 300, 1000], id: \.self) { Text("\($0)").tag($0) }
                }
                .onChange(of: settings.clipboardLimit) { _, _ in Controller.shared.clipboard.prune() }
                Picker("Conserver", selection: $settings.clipboardRetentionDays) {
                    Text("1 jour").tag(1)
                    Text("1 semaine").tag(7)
                    Text("1 mois").tag(30)
                    Text("Toujours").tag(0)
                }
                .onChange(of: settings.clipboardRetentionDays) { _, _ in Controller.shared.clipboard.prune() }
                Toggle("Enregistrer les images", isOn: $settings.clipboardImages)
                Button("Vider l'historique…", role: .destructive) {
                    if confirm("Vider tout l'historique du presse-papiers ?", button: "Vider") {
                        Controller.shared.clipboard.clear()
                    }
                }
            }
            Section {
                ForEach(settings.clipboardIgnored, id: \.self) { id in
                    HStack {
                        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
                            Image(nsImage: IconCache.icon(url.path)).resizable().frame(width: 18, height: 18)
                            Text(FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: ""))
                        } else {
                            Text(id)
                        }
                        Spacer()
                        Button { settings.clipboardIgnored.removeAll { $0 == id } } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button("Ajouter une app…") { addIgnoredApp() }
            } header: { Text("Apps ignorées") } footer: {
                Text("Les copies faites dans ces apps ne sont jamais enregistrées. Les gestionnaires de mots de passe sont toujours ignorés.")
            }
            Section("Coller") {
                Toggle("↵ colle directement dans l'app active (sinon copie)", isOn: $settings.pasteOnEnter)
                Button("Effacer les emoji récents") { Recents.clear() }
            }
        }
    }

    private func addIgnoredApp() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let id = Bundle(url: url)?.bundleIdentifier, !settings.clipboardIgnored.contains(id) {
                settings.clipboardIgnored.append(id)
            }
        }
    }
}

private struct StatsSettings: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        let top = Usage.top(8)
        SettingsForm(tab: .stats) {
            Section("Top 8") {
                if top.isEmpty { Text("Pas encore de données.").foregroundStyle(.secondary) }
                ForEach(Array(top.enumerated()), id: \.element) { index, id in
                    if let info = Controller.shared.model.statsName(id), let record = Usage.records[id] {
                        HStack(spacing: 10) {
                            Text("\(index + 1)").font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.secondary).frame(width: 18)
                            ItemIconView(icon: info.icon).frame(width: 20, height: 20)
                            Text(info.name)
                            Spacer()
                            Text(Usage.shortcuts(id).map { "« \($0) »" }.joined(separator: " "))
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                            Text("\(record.count)×").monospacedDigit()
                        }
                    }
                }
            }
            Section {
                Button("Ouvrir les statistiques détaillées") { Controller.shared.show(mode: .stats) }
                Button("Réinitialiser les statistiques…", role: .destructive) {
                    if confirm("Oublier toutes les statistiques et raccourcis appris ?", button: "Réinitialiser") {
                        Usage.reset()
                        settings.statsRevision += 1
                    }
                }
            }
        }
        .id(settings.statsRevision)
    }
}

private struct PermissionsSettings: View {
    var body: some View {
        SettingsForm(tab: .permissions) {
            Section {
                PermissionChecklist().padding(.vertical, 6)
            } footer: {
                Text("Hello n'utilise ni le micro, ni la caméra, ni l'enregistrement de l'écran. La pipette utilise la loupe système.")
            }
        }
    }
}

// MARK: - Animations

/// Rejoue l'ouverture du style dans l'aperçu.
final class PreviewReplay: ObservableObject {
    @Published var shown = true
    @Published var id = 0

    func replay(_ style: PanelStyle) {
        shown = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(Motion.scaled(style.reveal.open(light: false))) {
                self.shown = true
                self.id += 1
            }
        }
    }
}

private struct MotionSettings: View {
    @ObservedObject private var settings = AppSettings.shared
    @StateObject private var replay = PreviewReplay()

    var body: some View {
        SettingsForm(tab: .motion) {
            Section {
                ZStack(alignment: .bottomTrailing) {
                    ZStack {
                        StyleCard.backdrop(settings.panelStyle)
                        StyleSample(style: settings.panelStyle, shown: replay.shown, revealID: replay.id)
                    }
                    .frame(height: 250)
                    .clipped()
                    Button {
                        replay.replay(settings.panelStyle)
                    } label: {
                        Label("Rejouer", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .padding(12)
                }
                .listRowInsets(EdgeInsets())
            } footer: {
                Text("\(settings.panelStyle.title) : \(settings.panelStyle.reveal.summary)")
            }

            Section("Mouvement") {
                Toggle("Animations", isOn: $settings.animations)
                Picker("Intensité", selection: $settings.motionIntensity) {
                    ForEach(MotionIntensity.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .disabled(!settings.animations)
                LabeledContent("Vitesse") {
                    HStack {
                        Slider(value: $settings.animationSpeed, in: 0.5...2, step: 0.25) { EmptyView() }
                            minimumValueLabel: { Image(systemName: "tortoise") }
                            maximumValueLabel: { Image(systemName: "hare") }
                        Text(String(format: "%.2g×", settings.animationSpeed)).monospacedDigit().foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
                .disabled(!settings.animations)
            }

            Section {
                Toggle("Résultats qui arrivent en cascade", isOn: $settings.cascadeRows)
                Toggle("Effet d'ouverture du style", isOn: $settings.haloSweep)
                Toggle("Effets au lancement d'une app", isOn: $settings.launchEffects)
            } header: { Text("Effets") } footer: {
                Text("À l'ouverture, en \(settings.panelStyle.title) : \(settings.panelStyle.reveal.effect) "
                     + "Au lancement, Hello prend la couleur de l'app ouverte et s'efface à la manière de son style.")
            }
            .disabled(!settings.animations)

            Section {
                HStack {
                    Button("Tester dans Hello") { Controller.shared.show() }
                    Spacer()
                    Button("Rétablir les animations par défaut") {
                        settings.animations = true
                        settings.motionIntensity = .normal
                        settings.animationSpeed = 1
                        settings.cascadeRows = true
                        settings.haloSweep = true
                        settings.launchEffects = true
                    }
                }
            }
        }
        .onAppear { replay.replay(settings.panelStyle) }
        .onChange(of: settings.panelStyle) { _, style in replay.replay(style) }
        .onChange(of: settings.motionIntensity) { _, _ in replay.replay(settings.panelStyle) }
        .onChange(of: settings.animationSpeed) { _, _ in replay.replay(settings.panelStyle) }
    }
}

/// Rangée de pastilles de couleur à choisir (une ou deux couleurs par pastille).
struct SwatchRow: View {
    let items: [(id: String, title: String, colors: [Color])]
    let selected: String
    let choose: (String) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ForEach(items, id: \.id) { item in
                Button { choose(item.id) } label: {
                    VStack(spacing: 6) {
                        HStack(spacing: 0) { ForEach(Array(item.colors.enumerated()), id: \.offset) { $0.element } }
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(Color.primary.opacity(0.15), lineWidth: 1))
                            .padding(3)
                            .overlay(Circle().strokeBorder(item.id == selected ? Color.primary : .clear, lineWidth: 2))
                        Text(item.title)
                            .font(.system(size: 11, weight: item.id == selected ? .semibold : .regular))
                            .foregroundStyle(item.id == selected ? .primary : .secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 6)
    }
}
