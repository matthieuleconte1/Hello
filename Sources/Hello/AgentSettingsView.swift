import AppKit
import SwiftUI

// MARK: - Logos des fournisseurs

/// Logo d'un fournisseur : l'icône de son app quand elle est installée sur ce Mac (Claude, ChatGPT/Codex,
/// Hermes, Antigravity), sinon une pastille dessinée à sa couleur. Rien n'est téléchargé.
enum ProviderLogos {
    private static var cache: [AgentEngine: NSImage?] = [:]

    private static func bundleIDs(_ engine: AgentEngine) -> [String] {
        switch engine {
        case .hermes: ["com.nousresearch.hermes.setup", "com.nousresearch.hermes"]
        case .claude: ["com.anthropic.claudefordesktop"]
        case .codex: ["com.openai.codex", "com.openai.chat"]
        case .agy: ["com.google.antigravity", "com.google.Antigravity"]
        }
    }

    static func image(_ engine: AgentEngine) -> NSImage? {
        if let cached = cache[engine] { return cached }
        var image = bundleIDs(engine).lazy
            .compactMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
            .map { NSWorkspace.shared.icon(forFile: $0.path) }
            .first
        if image == nil, engine == .hermes {
            image = NSImage(contentsOfFile: Shell.home + "/.hermes/hermes-agent/assets/icon-master.svg")
        }
        cache[engine] = image
        return image
    }
}

extension AgentEngine {
    /// Couleur de marque, pour les bordures et les pastilles.
    var brand: Color {
        switch self {
        case .hermes: .purple
        case .claude: Color(red: 0.85, green: 0.47, blue: 0.34)
        case .codex: .teal
        case .agy: .blue
        }
    }

    var company: String {
        switch self {
        case .hermes: "Nous Research"
        case .claude: "Anthropic"
        case .codex: "OpenAI"
        case .agy: "Google · Gemini"
        }
    }

    /// Installation : dans le terminal, ou la page de téléchargement pour Antigravity.
    func install() {
        if self == .agy, let url = URL(string: "https://antigravity.google/download") {
            NSWorkspace.shared.open(url)
        } else {
            Shell.runInTerminal(installCommand)
        }
    }

    /// Niveaux confiés à ce fournisseur.
    var levels: [AgentLevel] { AgentLevel.allCases.filter { $0.config.engine == self } }
}

struct ProviderLogo: View {
    let engine: AgentEngine
    var size: CGFloat = 32

    var body: some View {
        if let image = ProviderLogos.image(engine) {
            Image(nsImage: image).resizable().interpolation(.high).aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else if engine == .agy {
            // Sans l'app : l'arche d'Antigravity sur une tuile claire, comme son icône.
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(Color.white)
                .overlay(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5))
                .frame(width: size * 0.82, height: size * 0.82)
                .overlay(AntigravityMark()
                    .fill(LinearGradient(colors: AntigravityMark.colors, startPoint: .bottomLeading, endPoint: .bottomTrailing))
                    .frame(width: size * 0.56, height: size * 0.56))
                .shadow(color: .black.opacity(0.15), radius: size * 0.03, y: size * 0.02)
                .frame(width: size, height: size)
        } else {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(LinearGradient(colors: [engine.brand, engine.brand.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: size * 0.82, height: size * 0.82)
                .overlay(Text(String(engine.title.prefix(1))).font(.system(size: size * 0.42, weight: .bold)).foregroundStyle(.white))
                .frame(width: size, height: size)
        }
    }
}

/// L'arche d'Antigravity (tracé de son icône officielle, boîte 16 × 16).
struct AntigravityMark: Shape {
    static let colors = [Color(red: 0.98, green: 0.74, blue: 0.02), Color(red: 0.20, green: 0.66, blue: 0.33),
                         Color(red: 0.26, green: 0.52, blue: 0.96), Color(red: 0.63, green: 0.26, blue: 0.96),
                         Color(red: 0.92, green: 0.26, blue: 0.21)]

    func path(in rect: CGRect) -> Path {
        let k = min(rect.width, rect.height) / 16
        let dx = rect.minX + (rect.width - 16 * k) / 2, dy = rect.minY + (rect.height - 16 * k) / 2
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: dx + x * k, y: dy + y * k) }
        var path = Path()
        path.move(to: p(14.1452, 14.6818))
        path.addCurve(to: p(15.0997, 13.7273), control1: p(14.9937, 15.3182), control2: p(16.2664, 14.894))
        path.addCurve(to: p(7.99366, 1), control1: p(11.5998, 10.3333), control2: p(12.3421, 1))
        path.addCurve(to: p(0.887603, 13.7273), control1: p(3.64518, 1), control2: p(4.3876, 10.3333))
        path.addCurve(to: p(1.84215, 14.6818), control1: p(-0.385123, 15), control2: p(0.993664, 15.3182))
        path.addCurve(to: p(7.99366, 8.5303), control1: p(5.13002, 12.4545), control2: p(4.9179, 8.5303))
        path.addCurve(to: p(14.1452, 14.6818), control1: p(11.0694, 8.5303), control2: p(10.8573, 12.4545))
        path.closeSubpath()
        return path
    }
}

// MARK: - Petites pièces

/// Pastille d'un niveau : son numéro dans un rond à sa couleur.
private struct LevelBadge: View {
    let level: AgentLevel
    var size: CGFloat = 22

    var body: some View {
        Circle().fill(level.tint.gradient)
            .frame(width: size, height: size)
            .overlay(Text("\(level.rawValue)").font(.system(size: size * 0.5, weight: .bold, design: .rounded))
                .foregroundStyle(level == .fast ? .black.opacity(0.75) : .white))
    }
}

private struct Chip: View {
    let text: String
    var symbol: String?
    var tint: Color = .secondary

    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol).font(.system(size: 9, weight: .semibold)) }
            Text(text).font(.system(size: 10.5, weight: .medium)).lineLimit(1)
        }
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(Capsule().fill(tint.opacity(0.13)))
        .foregroundStyle(tint)
    }
}

/// Carte arrondie posée dans une ligne de formulaire.
private struct Card<Content: View>: View {
    var tint: Color = .primary
    var highlighted = false
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(highlighted ? tint.opacity(0.10) : Color.primary.opacity(0.035)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(highlighted ? tint.opacity(0.7) : Color.primary.opacity(0.08), lineWidth: highlighted ? 1.5 : 1))
    }
}

// MARK: - Parcours d'une demande

/// Les trois niveaux côte à côte, reliés : qui répond, avec quel modèle, et ce que fait le mode Auto.
private struct LevelFlow: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var engines = EngineStatus.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "text.cursor").foregroundStyle(.secondary)
                Text("« ? ta demande »").font(.system(size: 12, weight: .semibold, design: .monospaced))
                Image(systemName: "arrow.right").font(.system(size: 10, weight: .bold)).foregroundStyle(.tertiary)
                Chip(text: strategyLabel, symbol: "arrow.triangle.branch", tint: .purple)
                Spacer()
            }
            HStack(alignment: .center, spacing: 6) {
                node(.fast)
                connector(active: settings.agentStrategy == "auto")
                node(.work)
                connector(active: settings.agentStrategy == "auto")
                node(.code)
            }
            HStack(spacing: 6) {
                Chip(text: "Répond seul", symbol: "text.bubble", tint: .yellow)
                Chip(text: "Action simple", symbol: "bolt", tint: .yellow)
                Chip(text: "Web + actions sur le Mac", symbol: "globe", tint: .cyan)
                Chip(text: "Session dans \(Shell.terminal.name)", symbol: "terminal", tint: .purple)
            }
        }
        .padding(.vertical, 4)
    }

    private var strategyLabel: String {
        switch settings.agentStrategy {
        case "act": "Toujours Recherche & Action"
        case "delegate": "Toujours Code"
        default: "Auto"
        }
    }

    private func node(_ level: AgentLevel) -> some View {
        let config = level.config
        let dimmed = (settings.agentStrategy == "act" && level != .work) || (settings.agentStrategy == "delegate" && level != .code)
        return Card(tint: level.tint, highlighted: !dimmed) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    LevelBadge(level: level)
                    Text(level.title).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                }
                HStack(spacing: 8) {
                    ProviderLogo(engine: config.engine, size: 30)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(config.model.isEmpty ? "Modèle par défaut" : config.engine.modelName(config.model))
                            .font(.system(size: 11.5, weight: .medium)).lineLimit(1)
                        Text(config.engine.title).font(.system(size: 10.5)).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                if !config.engine.installed {
                    Chip(text: "Non installé", symbol: "exclamationmark.triangle.fill", tint: .orange)
                } else if !config.reasoning.isEmpty {
                    Chip(text: "Raisonnement \(config.reasoning)", symbol: "brain", tint: level.tint == .yellow ? .orange : level.tint)
                }
            }
        }
        .opacity(dimmed ? 0.45 : 1)
    }

    private func connector(active: Bool) -> some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(active ? AnyShapeStyle(.secondary) : AnyShapeStyle(.quaternary))
    }
}

// MARK: - Fournisseurs

private struct ProviderCard: View {
    let engine: AgentEngine
    /// Observé pour redessiner la carte quand un niveau change de fournisseur.
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var hermes = HermesStatus.shared
    @ObservedObject private var engines = EngineStatus.shared

    var body: some View {
        Card(tint: engine.brand, highlighted: engine.installed && !engine.levels.isEmpty) {
            HStack(alignment: .top, spacing: 10) {
                ProviderLogo(engine: engine, size: 40)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(engine.title).font(.system(size: 13, weight: .semibold))
                        Circle().fill(engine.installed ? Color.green : Color.secondary.opacity(0.4)).frame(width: 7, height: 7)
                    }
                    Text(engine.company).font(.system(size: 10.5)).foregroundStyle(.secondary)
                    Text(detail).font(.system(size: 10.5)).foregroundStyle(.tertiary).lineLimit(2)
                    HStack(spacing: 4) {
                        ForEach(engine.levels, id: \.self) { LevelBadge(level: $0, size: 16) }
                        if engine.installed && engine.levels.isEmpty {
                            Text("Aucun niveau").font(.system(size: 10)).foregroundStyle(.tertiary)
                        }
                        Spacer(minLength: 0)
                        actions
                    }
                    .padding(.top, 2)
                }
            }
        }
    }

    private var detail: String {
        guard engine.installed else { return "Non installé" }
        if engine == .hermes {
            return hermes.providers.isEmpty ? "Aucun compte connecté"
                : hermes.providers.map(Hermes.providerName).joined(separator: ", ")
        }
        let count = engine.models.count
        return count > 0 ? "\(count) modèles disponibles" : "Installé"
    }

    @ViewBuilder private var actions: some View {
        if !engine.installed {
            Button(engine == .agy ? "Télécharger…" : "Installer…") { engine.install() }
                .controlSize(.small)
        } else if engine == .hermes {
            Button(hermes.providers.isEmpty ? "Se connecter…" : "Comptes…") { Shell.runInTerminal("hermes model") }
                .controlSize(.small)
        }
    }
}

// MARK: - Choix du fournisseur d'un niveau

/// Rangée de tuiles avec logo : un clic change le fournisseur du niveau.
private struct ProviderPicker: View {
    let level: AgentLevel
    /// Le fournisseur se lit dans les réglages : sans les observer, la tuile choisie ne bougerait pas.
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var engines = EngineStatus.shared
    @ObservedObject private var hermes = HermesStatus.shared

    var body: some View {
        let current = level.config.engine
        HStack(spacing: 8) {
            ForEach(AgentEngine.allCases) { engine in
                Button { if engine != current { level.setEngine(engine) } } label: {
                    VStack(spacing: 5) {
                        ProviderLogo(engine: engine, size: 28)
                        Text(engine.title).font(.system(size: 11, weight: engine == current ? .semibold : .regular)).lineLimit(1)
                        Text(engine.installed ? " " : "non installé").font(.system(size: 9)).foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(engine == current ? level.tint.opacity(0.14) : Color.primary.opacity(0.03)))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(engine == current ? level.tint : Color.primary.opacity(0.08),
                                      lineWidth: engine == current ? 1.5 : 1))
                    .opacity(engine.installed || engine == current ? 1 : 0.55)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(engine.installed ? "Confier ce niveau à \(engine.title)" : "\(engine.title) n'est pas installé")
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Autorisations

private struct PermissionTile: View {
    let symbol: String
    let tint: Color
    let title: String
    let ok: Bool
    let action: (() -> Void)?

    var body: some View {
        Card(tint: ok ? .green : .orange, highlighted: !ok) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 7, style: .continuous).fill(tint.gradient)
                    .frame(width: 26, height: 26)
                    .overlay(Image(systemName: symbol).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 12, weight: .medium)).lineLimit(1)
                    Text(ok ? "Autorisé" : "Non autorisé").font(.system(size: 10.5))
                        .foregroundStyle(ok ? Color.green : Color.orange)
                }
                Spacer(minLength: 0)
                if !ok, let action { Button("Autoriser…", action: action).controlSize(.small) }
            }
        }
    }
}

// MARK: - Panneau

struct AgentSettings: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var chats = ChatStore.shared
    @ObservedObject private var engines = EngineStatus.shared
    @ObservedObject private var hermes = HermesStatus.shared
    @ObservedObject private var center = PermissionCenter.shared

    private let twoColumns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        SettingsForm(tab: .agent) {
            Section {
                Toggle(isOn: $settings.agentEnabled) {
                    Text("Activer l'agent dans Hello")
                    Text("Tape « ? » suivi de ta demande. « ?? » force le niveau 2, « ??? » le niveau 3, « / » les commandes.")
                }
                .toggleStyle(.switch)
            }
            Section("Parcours d'une demande") {
                LevelFlow()
                Picker("Mode", selection: $settings.agentStrategy) {
                    Text("Auto").tag("auto")
                    Text("Toujours Recherche & Action").tag("act")
                    Text("Toujours Code").tag("delegate")
                }
                .pickerStyle(.segmented)
            }
            Section {
                LazyVGrid(columns: twoColumns, spacing: 10) {
                    ForEach(AgentEngine.allCases) { ProviderCard(engine: $0) }
                }
                .padding(.vertical, 4)
            } header: {
                HStack {
                    Text("Fournisseurs")
                    Spacer()
                    if hermes.checking { ProgressView().controlSize(.mini) }
                    Button("Revérifier") {
                        Hermes.locate()
                        EngineStatus.locate()
                    }
                    .buttonStyle(.link).font(.system(size: 11))
                }
            } footer: {
                Text("Des outils en ligne de commande déjà connectés à ton compte. Les pastilles indiquent les niveaux qu'ils servent.")
            }
            levelSection(.fast, provider: $settings.agentRouterProvider, model: $settings.agentRouterModel,
                         reasoning: $settings.agentRouterReasoning,
                         footer: "Répond seul aux questions simples et fait lui-même les actions simples (ouvrir un fichier, "
                             + "une app, un lien). Sinon il reformule et passe la main. Prends un modèle rapide : Luna, Haiku, "
                             + "Gemini Flash.")
            levelSection(.work, provider: $settings.agentResearchProvider, model: $settings.agentResearchModel,
                         reasoning: $settings.agentResearchReasoning,
                         footer: "Web et actions sur le Mac (terminal, AppleScript, Raccourcis, captures), réponse en direct "
                             + "dans Hello, 5 min au plus. Laisse toujours la dernière étape des actions irréversibles. "
                             + workSafety)
            levelSection(.code, provider: $settings.agentDefaultProvider, model: $settings.agentDefaultModel,
                         reasoning: $settings.agentDefaultReasoning,
                         footer: "Session interactive dans \(Shell.terminal.name), dans le dossier de travail : code, apps, "
                             + "scripts, travail long sur un projet.") {
                TextField("Dossier de travail", text: $settings.agentWorkdir)
            }
            Section {
                LazyVGrid(columns: twoColumns, spacing: 10) {
                    PermissionTile(symbol: "accessibility", tint: .blue, title: "Accessibilité", ok: center.accessibility,
                                   action: center.requestAccessibility)
                    PermissionTile(symbol: "gearshape.2", tint: .gray, title: "System Events",
                                   ok: center.systemEvents == .granted, action: center.requestSystemEvents)
                    PermissionTile(symbol: "rectangle.dashed.badge.record", tint: .red, title: "Capture d'écran",
                                   ok: CGPreflightScreenCaptureAccess(), action: { _ = Attachments.canCaptureScreen() })
                    PermissionTile(symbol: "macwindow.on.rectangle", tint: .indigo, title: "Fenêtres partagées",
                                   ok: settings.agentWindows, action: { settings.agentWindows = true })
                }
                .padding(.vertical, 4)
                Toggle("Donner à l'IA la liste des fenêtres ouvertes", isOn: $settings.agentWindows)
            } header: { Text("Ce que l'IA peut faire sur ce Mac") } footer: {
                Text("Les commandes de l'IA héritent des autorisations de Hello. Depuis la 2.2.2, macOS les garde d'une "
                     + "mise à jour à l'autre : en venant d'une version plus ancienne, retire Hello de la liste puis rajoute-le, "
                     + "une dernière fois.")
            }
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.text.bubble.right.fill").font(.system(size: 22))
                        .foregroundStyle(.purple.gradient)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(chats.conversations.count) conversation\(chats.conversations.count > 1 ? "s" : "")")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Gardées sur ce Mac (200 au plus). Reprends-les avec « ? » ou /resume.")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Tout effacer…") {
                        if confirm("Effacer toutes les conversations avec l'IA ?", button: "Effacer") { chats.clear() }
                    }
                    .disabled(chats.conversations.isEmpty)
                }
                .padding(.vertical, 2)
                Toggle("Garder l'historique des conversations", isOn: $settings.agentHistory)
            } header: { Text("Mémoire") } footer: {
                Text("Une question de suite reçoit les échanges précédents, quel que soit le fournisseur.")
            }
        }
        .onAppear {
            Hermes.locate()
            EngineStatus.locate()
            center.startWatching()
        }
        .onDisappear { center.stopWatching() }
    }

    private func levelSection(_ level: AgentLevel, provider: Binding<String>, model: Binding<String>,
                              reasoning: Binding<String>, footer: String) -> some View {
        levelSection(level, provider: provider, model: model, reasoning: reasoning, footer: footer) { EmptyView() }
    }

    private func levelSection<Extra: View>(_ level: AgentLevel, provider: Binding<String>, model: Binding<String>,
                                           reasoning: Binding<String>, footer: String,
                                           @ViewBuilder extra: () -> Extra) -> some View {
        let engine = level.config.engine
        return Section {
            ProviderPicker(level: level)
            if engine == .hermes {
                hermesModelPicker(provider: provider, model: model)
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
            .pickerStyle(.segmented)
            extra()
            if !engine.installed {
                Button(engine == .agy ? "Télécharger \(engine.title)…" : "Installer \(engine.title) dans \(Shell.terminal.name)") {
                    engine.install()
                }
            }
        } header: {
            HStack(spacing: 8) {
                LevelBadge(level: level, size: 18)
                Text("Niveau \(level.rawValue) · \(level.title)")
                Spacer()
                Image(systemName: level.symbol).foregroundStyle(level.tint)
            }
        } footer: {
            Text(footer)
        }
    }

    /// Menu groupé par compte ; la sélection est « provider|modèle ».
    private func hermesModelPicker(provider: Binding<String>, model: Binding<String>) -> some View {
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
        return Picker("Modèle", selection: selection) {
            Text("Défaut de Hermes").tag("")
            ForEach(providers, id: \.self) { p in
                Section(Hermes.providerName(p.isEmpty ? "défaut" : p)) {
                    ForEach(options.filter { $0.provider == p }, id: \.tag) { Text($0.model).tag($0.tag) }
                }
            }
        }
    }

    /// Ce que le fournisseur du niveau 2 a le droit de faire sans demander.
    private var workSafety: String {
        switch AgentLevel.work.config.engine {
        case .hermes: "Hermes bloque lui-même les commandes dangereuses."
        case .claude: "Claude Code n'a que le terminal, la lecture de fichiers et le web ; rm, sudo et git push lui sont refusés."
        case .codex: "Codex travaille dans son bac à sable : il n'écrit que dans le dossier de travail, avec accès au réseau."
        case .agy: "Antigravity juge lui-même les commandes à risque avant de les lancer."
        }
    }
}
