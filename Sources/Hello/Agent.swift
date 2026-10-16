import AppKit
import SwiftUI
import Combine
import UserNotifications

/// Intégration de Hermes Agent (Nous Research) : un modèle rapide « routeur » agit tout de suite
/// sur les demandes simples, ou reformule la demande et l'envoie au modèle par défaut dans le terminal.
enum Hermes {
    /// Commande d'installation officielle (README de Hermes Agent).
    static let installCommand = "curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash"

    static var binary: String? { HermesStatus.shared.binary }
    static var models: [ModelOption] { HermesStatus.shared.models }
    /// Providers pour lesquels Hermes a des identifiants.
    static var providers: [String] { HermesStatus.shared.providers }

    /// L'agent est utilisable dès qu'un des fournisseurs (Hermes, Claude Code, Codex) est installé.
    static var available: Bool { AppSettings.shared.agentEnabled && AgentEngine.allCases.contains(where: \.installed) }

    /// Localise `hermes` et lit ses comptes. Au lancement, puis à la demande (onboarding, réglages).
    static func locate() {
        let status = HermesStatus.shared
        guard !status.checking else { return }
        status.checking = true
        DispatchQueue.global(qos: .utility).async {
            // `zsh -l` ne lit pas ~/.zshrc, où l'installeur ajoute souvent ~/.local/bin : on regarde aussi
            // les emplacements habituels.
            let fromShell = Shell.capture("command -v hermes").trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: "\n").last.map(String.init) ?? ""
            let candidates = [fromShell, Shell.home + "/.local/bin/hermes", "/opt/homebrew/bin/hermes", "/usr/local/bin/hermes"]
            let path = candidates.first { $0.hasPrefix("/") && FileManager.default.isExecutableFile(atPath: $0) }
            let (providers, models) = loadAccounts()
            DispatchQueue.main.async {
                status.binary = path
                status.providers = path == nil ? [] : providers
                status.models = path == nil ? [] : models
                status.checking = false
                adaptModels()
            }
        }
    }

    struct ModelOption: Hashable {
        let provider: String
        let model: String
        var tag: String { provider + "|" + model }
    }

    static func providerName(_ id: String) -> String {
        switch id {
        case "openai-codex": "OpenAI (ChatGPT)"
        case "anthropic": "Anthropic"
        case "copilot": "GitHub Copilot"
        case "nous": "Nous"
        case "openrouter": "OpenRouter"
        default: id
        }
    }

    private static let providerOrder = ["openai-codex", "anthropic", "copilot", "nous", "openrouter"]

    /// Providers connectés (auth.json + provider du config.yaml) et modèles connus (cache de `hermes model`).
    private static func loadAccounts() -> ([String], [ModelOption]) {
        let home = Shell.home + "/.hermes"
        var providers: [String] = []
        if let data = try? Data(contentsOf: URL(fileURLWithPath: home + "/auth.json")),
           let auth = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for key in ["providers", "credential_pool"] {
                for name in ((auth[key] as? [String: Any])?.keys).map(Array.init) ?? [] where !providers.contains(name) {
                    providers.append(name)
                }
            }
        }
        if let provider = configuredProvider(home + "/config.yaml"), !providers.contains(provider) {
            providers.append(provider)
        }
        providers.sort { (providerOrder.firstIndex(of: $0) ?? 99) < (providerOrder.firstIndex(of: $1) ?? 99) }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: home + "/provider_models_cache.json")),
              let cache = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return (providers, []) }
        let models = providers.flatMap { provider -> [ModelOption] in
            let list = (cache[provider] as? [String: Any])?["models"] as? [String] ?? []
            return list.map { ModelOption(provider: provider, model: $0) }
        }
        return (providers, models)
    }

    /// `provider:` de la section `model:` du config.yaml (clé API ou provider local, absent d'auth.json).
    private static func configuredProvider(_ path: String) -> String? {
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        var inModel = false
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            if !line.hasPrefix(" ") && !line.hasPrefix("\t") { inModel = line.hasPrefix("model:") }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if inModel, trimmed.hasPrefix("provider:") {
                let value = trimmed.dropFirst("provider:".count).trimmingCharacters(in: CharacterSet(charactersIn: " \"'"))
                return value.isEmpty ? nil : value
            }
        }
        return nil
    }

    /// Modèles préférés par rôle, du plus au moins souhaitable, parmi ceux des comptes connectés.
    private static let quickPreferences = ["gpt-6-luna", "claude-haiku-4-5-20251001", "gpt-5.4-mini", "claude-haiku-4.5", "gpt-5-mini"]
    private static let researchPreferences = ["claude-sonnet-5-5", "gpt-6.1-sol", "claude-sonnet-5", "gpt-5.4"]

    /// Les réglages par défaut visent ChatGPT (Luna) et Anthropic (Sonnet). Si le compte correspondant n'est pas
    /// connecté, on bascule sur un modèle d'un compte qui l'est, sinon sur le modèle par défaut de Hermes.
    static func adaptModels() {
        let providers = Self.providers
        guard !providers.isEmpty else { return }
        let s = AppSettings.shared
        // Seuls les niveaux confiés à Hermes utilisent ses comptes.
        guard AgentLevel.allCases.contains(where: { $0.config.engine == .hermes }) else { return }
        func pick(_ preferences: [String]) -> ModelOption? {
            preferences.lazy.compactMap { name in models.first { $0.model == name } }.first
        }
        if AgentLevel.fast.config.engine == .hermes, !s.agentRouterModel.isEmpty, !providers.contains(s.agentRouterProvider) {
            let choice = pick(quickPreferences)
            s.agentRouterProvider = choice?.provider ?? ""
            s.agentRouterModel = choice?.model ?? ""
        }
        if AgentLevel.work.config.engine == .hermes, !s.agentResearchModel.isEmpty, !providers.contains(s.agentResearchProvider) {
            let choice = pick(researchPreferences)
            s.agentResearchProvider = choice?.provider ?? ""
            s.agentResearchModel = choice?.model ?? ""
        }
        if AgentLevel.code.config.engine == .hermes, !s.agentDefaultProvider.isEmpty, !providers.contains(s.agentDefaultProvider) {
            s.agentDefaultProvider = ""
            s.agentDefaultModel = ""
        }
    }

    static func label(provider: String, model: String) -> String {
        guard !model.isEmpty else { return "modèle par défaut de Hermes" }
        return provider.isEmpty ? model : "\(model) (\(providerName(provider)))"
    }


    /// Arguments -m / --provider pour un modèle choisi dans les réglages.
    static func modelArgs(provider: String, model: String) -> [String] {
        var args: [String] = []
        if !model.isEmpty { args += ["-m", model] }
        if !provider.isEmpty { args += ["--provider", provider] }
        return args
    }

    static func quote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }


    /// Phase 1 : classement sans outils (rapide, ne peut rien faire lui-même).
    static func routerPrompt(for request: String, context: MacContext) -> String {
        let forms: String
        if AppSettings.shared.agentStrategy == "delegate" {
            forms = """
            Reply exactly: CODE: <rewritten, precise, self-contained prompt for a coding agent, in the user's \
            language, with useful context: paths, constraints, expected result>
            """
        } else {
            forms = """
            Decide the level of effort needed and reply with exactly one of these forms and nothing else:
            ANSWER: <short answer in the user's language> — level 1, fast: a short answer you are sure of is enough \
            (fact, definition, conversion, which command to use).
            WORK: <the request rewritten as a precise, self-contained instruction in the user's language> — level 2, \
            research and action: needs up-to-date information, web search, comparing sources or a thoughtful \
            explanation, or any action on this Mac (open, launch or control apps, change a setting, find, open or \
            organize files, look at the screen or the attachments).
            CODE: <rewritten, precise, self-contained prompt for a coding agent, in the user's language, with useful \
            context: paths, constraints, expected result> — level 3: writing or fixing code, building an app or a \
            script, long multi-step work in a project.
            """
        }
        return """
        You are the fast router of Hello, a launcher on the user's Mac (macOS). Classify the user's request. \
        You have no tools and must not try to do the task.
        \(forms)

        \(context.routerNote)

        User request: \(request)
        """
    }

    /// Niveau 2 : recherche et actions sur le Mac, bornées en tours et en durée.
    static func workPrompt(for instruction: String, context: MacContext) -> String {
        """
        \(instruction)

        \(context.block)

        You can both research and act.
        For a question: research it carefully (use the web when useful) and answer in the user's language, structured \
        and concise, with short sections or bullet points when it helps, and cite sources as markdown links.
        For an action: do it now on this Mac, with as few tool calls as possible. Ways to act, in order of preference:
        1. Shell: `open` (apps, files, URLs; `open -a "App"`, `open -R` reveals in Finder), `mdfind` (Spotlight) to \
        find files, `shortcuts list` / `shortcuts run "Name"`, `defaults`, `pmset`, `networksetup`, `pbcopy` / `pbpaste`.
        2. AppleScript with `osascript -e`: scriptable apps (Finder selection and windows, the current tab of Safari \
        or Chrome, Music, Calendar, Reminders, Notes, Mail drafts), System Events (dark mode, keystrokes, menus, the \
        interface of other apps), `set volume output volume N`.
        3. To see the screen: `screencapture -x /tmp/hello-screen.png`, then vision_analyze.
        Never do anything destructive or irreversible (deleting or overwriting data, emptying the trash, sending \
        messages or emails, payments, purchases, pushing code, changing passwords or security settings): prepare it \
        (draft, open the right page or window) and leave the last step to the user.
        When you performed an action, finish with one line: DONE: <short summary in the user's language>
        """
    }

    /// Outils du niveau 2. Pas de computer_use : lancé depuis Hello, personne n'est là pour approuver un clic.
    static let workTools = "web,file,terminal,vision,browser,memory"

    /// La première image jointe part avec la demande ; les autres sont citées par leur chemin.
    static func imageArgs(_ context: MacContext) -> [String] {
        context.firstImage.map { ["--image", $0.url.path] } ?? []
    }

    /// Étape lisible d'après un événement `tool_use` de Hermes.
    static func stepLabel(_ name: String, input: [String: Any]?) -> String {
        let text = { (key: String) in (input?[key] as? String).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } }
        let file = { (key: String) in text(key).map { URL(fileURLWithPath: $0).lastPathComponent } ?? "un fichier" }
        switch name {
        case "terminal": return text("command").map { "$ " + $0.replacingOccurrences(of: "\n", with: " ⏎ ") } ?? "Lance une commande"
        case "vision_analyze": return "Regarde l'image"
        case "read_file": return "Lit \(file("path"))"
        case "write_file", "patch": return "Écrit \(file("path"))"
        case "search_files": return "Cherche des fichiers"
        case "web_search": return text("query").map { "Cherche « \($0) »" } ?? "Cherche sur le web"
        case "web_extract": return "Lit une page web"
        case "execute_code": return "Exécute du code"
        case "todo_list": return "Planifie les étapes"
        case let n where n.hasPrefix("browser"): return "Navigue dans le navigateur"
        default: return name
        }
    }
}

/// État observable de Hermes, pour l'onboarding et les réglages.
final class HermesStatus: ObservableObject {
    static let shared = HermesStatus()
    @Published fileprivate(set) var binary: String?
    @Published fileprivate(set) var providers: [String] = []
    @Published fileprivate(set) var models: [Hermes.ModelOption] = []
    @Published fileprivate(set) var checking = false
}

/// Les trois niveaux de l'agent. Fast : Luna répond seule ou choisit le niveau (Auto). Recherche & Action : web et
/// actions sur le Mac, réponse dans Hello. Code : session interactive dans le terminal.
enum AgentLevel: Int, CaseIterable {
    case fast = 1, work, code

    var title: String {
        switch self {
        case .fast: "Fast"
        case .work: "Recherche & Action"
        case .code: "Code"
        }
    }

    var symbol: String {
        switch self {
        case .fast: "bolt.fill"
        case .work: "magnifyingglass.circle.fill"
        case .code: "chevron.left.forwardslash.chevron.right"
        }
    }

    var tint: Color {
        switch self {
        case .fast: .yellow
        case .work: .cyan
        case .code: .purple
        }
    }

    /// Modèle et fournisseur utilisés à ce niveau, pour l'affichage.
    var modelLabel: String { config.label }

    var detail: String {
        switch self {
        case .fast: "Auto : répond ou choisit le niveau"
        case .work: "Cherche sur le web, agit sur le Mac, répond ici"
        case .code: "Session de code dans \(Shell.terminal.name)"
        }
    }
}

final class AgentRun: ObservableObject {
    enum Phase {
        case thinking
        case streaming(String)
        case done(String)
        case answer(String)
        case escalate(String)
        case delegated(String)
        case failed(String)
    }

    let request: String
    @Published private(set) var level: AgentLevel
    @Published private(set) var phase: Phase = .thinking {
        didSet {
            guard !isThinking else { return }
            record()
            if !finished {
                finished = true
                onFinish?(self)
            }
        }
    }
    /// Appelé une fois, quand la demande se termine (réponse, action, échec ou annulation).
    var onFinish: ((AgentRun) -> Void)?
    private var finished = false
    @Published private(set) var stage = "analyse ta demande"
    @Published private(set) var details = ""
    /// Étapes déjà faites (commandes, clics, lectures), affichées au fil de l'eau.
    @Published private(set) var steps: [String] = []
    /// App au premier plan et pièces jointes, figées au moment de la demande.
    let context: MacContext
    var attachments: [Attachment] { context.attachments }
    /// Conversation dont cette demande fait partie ; l'échange y est ajouté quand il se termine.
    private(set) var conversation: ChatConversation
    /// Échanges précédents, affichés au-dessus de la demande en cours.
    let earlier: [ChatTurn]
    private var recorded = false
    private(set) var sessionID: String?
    /// Fournisseur de l'étape en cours (celui du niveau, figé au lancement).
    private(set) var engine: AgentEngine
    private(set) var startedAt = Date()
    private var process: Process?

    init(request: String, level: AgentLevel, attachments: [Attachment] = [],
         conversation: ChatConversation = ChatConversation()) {
        self.request = request
        self.level = level
        engine = level.config.engine
        self.conversation = conversation
        earlier = conversation.turns
        context = MacContext(attachments: attachments, history: conversation.transcript)
    }

    /// Conversation rouverte depuis l'historique : son dernier échange, déjà terminé.
    init(restoring conversation: ChatConversation) {
        let last = conversation.turns.last
        request = last?.request ?? ""
        level = last?.agentLevel ?? .fast
        engine = last?.agentEngine ?? .hermes
        self.conversation = conversation
        earlier = Array(conversation.turns.dropLast())
        recorded = true
        steps = last?.steps ?? []
        sessionID = last?.sessionID
        let files = (last?.attachments ?? []).filter { FileManager.default.fileExists(atPath: $0) }
        context = MacContext(attachments: files.map { Attachment(url: URL(fileURLWithPath: $0)) })
        phase = switch last?.kind {
        case .done?: .done(last?.answer ?? "")
        case .code?: .delegated(last?.answer ?? "")
        default: .answer(last?.answer ?? "")
        }
    }

    /// Ajoute l'échange terminé à la conversation, et à l'historique s'il est activé. Les échecs ne sont pas gardés.
    private func record() {
        guard !recorded else { return }
        let outcome: (ChatTurn.Kind, String)
        switch phase {
        case .answer(let text): outcome = (.answer, text)
        case .done(let summary): outcome = (.done, summary)
        case .delegated(let prompt): outcome = (.code, prompt)
        default: return
        }
        recorded = true
        conversation.turns.append(ChatTurn(date: Date(), level: level.rawValue, request: request, answer: outcome.1,
                                           kind: outcome.0, steps: steps, attachments: attachments.map(\.url.path),
                                           sessionID: sessionID, engine: engine.rawValue))
        if AppSettings.shared.agentHistory { ChatStore.shared.save(conversation) }
        // La barre de recherche revient, pour une question de suite.
        DispatchQueue.main.async { Controller.shared.focusSearch() }
    }

    var isThinking: Bool {
        switch phase {
        case .thinking, .streaming: return true
        default: return false
        }
    }

    var modelLabel: String { level.modelLabel }

    /// Le fournisseur du niveau, s'il est installé ; sinon la demande échoue avec un message clair.
    private func engine(for level: AgentLevel) -> (AgentEngine, LevelConfig)? {
        let config = level.config
        guard config.engine.installed else {
            phase = .failed("\(config.engine.title) n'est pas installé. Choisis un autre fournisseur dans Réglages › Agent, "
                            + "ou installe-le : \(config.engine.installCommand)")
            return nil
        }
        engine = config.engine
        return (config.engine, config)
    }

    func start() {
        startedAt = Date()
        switch level {
        case .code: send(request)
        case .work: work(request)
        case .fast:
            stage = "choisit le niveau"
            AppSettings.shared.agentStrategy == "act" ? work(request) : classify()
        }
    }

    // MARK: Niveau 1 — Fast / Auto

    private func classify() {
        guard let (engine, config) = engine(for: .fast) else { return }
        let args = engine.routerArgs(Hermes.routerPrompt(for: request, context: context), config)
        if engine.streamsRouter {
            stream(args, showText: false, budget: 90) { [weak self] text in self?.route(text) }
        } else {
            launch(args, budget: engine.needsTimeout ? 90 : nil) { [weak self] text in self?.route(text) }
        }
    }

    /// Luna a choisi : niveau 1 (elle répond), 2 (recherche & action) ou 3 (code dans le terminal).
    private func route(_ text: String) {
        let tags = ["ANSWER:", "WORK:", "CODE:"]
        let found = tags.compactMap { tag in text.range(of: tag).map { (tag, $0) } }
            .min { $0.1.lowerBound < $1.1.lowerBound }
        guard let (tag, range) = found else {
            phase = .answer(text)
            return
        }
        let content = text[range.upperBound...]
            .replacingOccurrences(of: #"\s*[—–-]\s*level\s*\d\s*$"#, with: "", options: [.regularExpression, .caseInsensitive])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        switch tag {
        case "WORK:": work(content)
        case "CODE:":
            level = .code
            send(content)
            // Le terminal passe devant : on referme le panneau.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { Controller.shared.hide() }
        default: phase = .answer(content)
        }
    }

    // MARK: Niveau 2 — Recherche & Action (réponse en direct dans Hello)

    func work(_ prompt: String) {
        stage = "s'en occupe"
        level = .work
        phase = .thinking
        startedAt = Date()
        guard let (engine, config) = engine(for: .work) else { return }
        let args = engine.workArgs(Hermes.workPrompt(for: prompt, context: context), config, context: context)
        stream(args, showText: true, budget: engine.needsTimeout ? 300 : nil) { [weak self] text in
            guard let self else { return }
            // Une action se termine par « DONE: résumé » ; une recherche, par la réponse elle-même.
            if let range = text.range(of: "DONE:", options: .backwards) {
                details = text[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
                phase = .done(text[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines))
            } else {
                phase = .answer(text)
            }
        }
    }

    // MARK: Niveau 3 — Code (terminal)

    func send(_ prompt: String) {
        guard let (engine, config) = engine(for: .code) else { return }
        Shell.runInTerminal(engine.terminalCommand(prompt + "\n\n" + context.block, config),
                            in: Shell.expand(AppSettings.shared.agentWorkdir))
        phase = .delegated(prompt)
    }

    /// Reprend la session du niveau 2 dans le terminal, avec le fournisseur qui l'a menée.
    func continueInTerminal() {
        guard let sessionID, engine.installed else { return send(request) }
        Shell.runInTerminal(engine.resumeCommand(sessionID, AgentLevel.work.config),
                            in: Shell.expand(AppSettings.shared.agentWorkdir))
    }

    // MARK: Processus

    /// Fournisseur en flux JSON : étapes et texte au fil de l'eau, puis `finish` avec la réponse finale.
    private func stream(_ args: [String], showText: Bool, budget: TimeInterval?, finish: @escaping (String) -> Void) {
        steps = []
        var streamed = ""
        let parser = EventParser(engine)
        launch(args, budget: budget, streaming: { [weak self] line in
            guard let self, isThinking else { return }
            for event in parser.feed(line) {
                switch event {
                case .session(let id): sessionID = id
                case .step(let step):
                    steps.append(step)
                    if !showText { stage = step.hasPrefix("$ ") ? "lance une commande" : step.prefix(1).lowercased() + step.dropFirst() }
                case .text(let text):
                    streamed += text
                    if showText { phase = .streaming(streamed) }
                case .final(let text): finish(text)
                case .failure(let message): phase = .failed(message)
                }
                guard isThinking else { return }
            }
        }) { [weak self] _ in
            guard let self, self.isThinking else { return }
            let text = streamed.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty { phase = .failed("Aucune réponse.") } else { finish(text) }
        }
    }

    /// Lance le fournisseur. `streaming` reçoit chaque ligne de sortie au fil de l'eau (sur le fil principal),
    /// `handle` la sortie complète à la fin (code 0 uniquement). `budget` : arrêt forcé au-delà (en secondes).
    private func launch(_ args: [String], budget: TimeInterval? = nil, streaming: ((String) -> Void)? = nil,
                        then handle: @escaping (String) -> Void) {
        guard let binary = engine.binary else {
            phase = .failed("\(engine.title) introuvable dans le PATH.")
            return
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: Shell.expand(AppSettings.shared.agentWorkdir))
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = Shell.userPath
        env["NO_COLOR"] = "1"
        process.environment = env
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err
        process.standardInput = FileHandle.nullDevice

        let collected = LockedText()
        out.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                return
            }
            let lines = collected.append(String(decoding: data, as: UTF8.self))
            if let streaming, !lines.isEmpty {
                DispatchQueue.main.async { lines.forEach(streaming) }
            }
        }
        process.terminationHandler = { [weak self] p in
            let errors = String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                out.fileHandleForReading.readabilityHandler = nil
                let rest = collected.flush()
                if let streaming, !rest.isEmpty { streaming(rest) }
                guard let self, self.isThinking else { return }
                let text = collected.all.trimmingCharacters(in: .whitespacesAndNewlines)
                if p.terminationStatus == 0 && !text.isEmpty {
                    handle(text)
                } else {
                    let detail = errors.split(separator: "\n").suffix(4).joined(separator: "\n")
                    self.phase = .failed(p.terminationReason == .uncaughtSignal ? (self.timedOut ? "Trop long : arrêté." : "Annulé.")
                        : (detail.isEmpty ? "\(self.engine.title) a quitté avec le code \(p.terminationStatus)." : detail))
                }
            }
        }
        do {
            try process.run()
            self.process = process
            if let budget {
                DispatchQueue.main.asyncAfter(deadline: .now() + budget) { [weak self, weak process] in
                    guard let self, let process, process.isRunning else { return }
                    timedOut = true
                    process.terminate()
                }
            }
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private var timedOut = false

    func cancel() {
        if process?.isRunning == true { process?.terminate() }
    }
}

/// Hermes a fini pendant que Hello était fermé : une notification, et un clic rouvre la conversation.
final class AgentNotifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AgentNotifier()
    /// Hors d'un .app (binaire lancé par `swift run`), le centre de notifications fait planter le processus.
    private let available = Bundle.main.bundleURL.pathExtension == "app"

    func install() {
        guard available else { return }
        UNUserNotificationCenter.current().delegate = self
    }

    func post(_ run: AgentRun) {
        guard available else { return }
        let content = UNMutableNotificationContent()
        let text: String
        switch run.phase {
        case .answer(let answer): content.title = "\(run.engine.title) a répondu"; text = answer
        case .done(let summary): content.title = "\(run.engine.title) a terminé"; text = summary
        case .failed(let message): content.title = "\(run.engine.title) n'a pas pu répondre"; text = message
        default: return
        }
        content.subtitle = run.request
        content.body = String(text.replacingOccurrences(of: "\n", with: " ").prefix(180))
        content.sound = .default
        let request = UNNotificationRequest(identifier: "hermes-\(UUID().uuidString)", content: content, trigger: nil)
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            if granted { center.add(request) }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        DispatchQueue.main.async { Controller.shared.show() }
        completionHandler()
    }
}

/// Tampon de sortie partagé entre le fil de lecture et le fil principal ; découpe en lignes.
private final class LockedText {
    private let lock = NSLock()
    private var buffer = ""
    private(set) var all = ""

    func append(_ chunk: String) -> [String] {
        lock.lock(); defer { lock.unlock() }
        all += chunk
        buffer += chunk
        var lines: [String] = []
        while let newline = buffer.firstIndex(of: "\n") {
            lines.append(String(buffer[..<newline]))
            buffer = String(buffer[buffer.index(after: newline)...])
        }
        return lines
    }

    func flush() -> String {
        lock.lock(); defer { lock.unlock() }
        let rest = buffer
        buffer = ""
        return rest
    }
}

extension LauncherModel {
    /// Éléments de l'agent. « ? » rapide, « ?? » recherche, « ??? » approfondi (le niveau choisi passe en tête).
    func agentItems(_ q: String, explicit: Bool) -> [ResultItem] {
        guard Hermes.available else { return [] }
        let marks = explicit ? q.prefix { $0 == "?" }.count : 0
        let request = explicit ? String(q.dropFirst(marks)).trimmingCharacters(in: .whitespaces) : q
        if request.isEmpty && !attachments.isEmpty {
            let what = attachments.count > 1 ? "ces \(attachments.count) fichiers"
                : attachments[0].isScreenshot ? "cette capture" : "« \(attachments[0].name) »"
            let ask = "Qu'est-ce que c'est ? Décris et analyse " + (attachments.count > 1 ? "les pièces jointes." : "la pièce jointe.")
            return [ResultItem(id: "agent.attachments", section: "Agent", title: "Demander à \(AgentEngine.assistant.name) d'analyser \(what)",
                               subtitle: "Ou écris ce qu'il doit en faire · ⌫ retire le dernier fichier",
                               icon: .symbol("paperclip", .purple),
                               primary: ItemAction(title: "Analyser") { [unowned self] in startAgent(ask, level: .fast) },
                               secondary: ItemAction(title: "Recherche & Action") { [unowned self] in startAgent(ask, level: .work) })]
        }
        guard !request.isEmpty else {
            // « ? » seul : l'invite, puis les dernières conversations à reprendre.
            let recent = ChatStore.shared.conversations.prefix(4).map { chatItem($0, section: "Conversations récentes") }
            let all = ChatStore.shared.conversations.count > 4
                ? [ResultItem(id: "agent.chats", section: "Conversations récentes", title: "Toutes les conversations",
                              subtitle: "\(ChatStore.shared.conversations.count) conversations avec l'IA",
                              icon: .symbol("bubble.left.and.text.bubble.right", .purple),
                              primary: ItemAction(title: "Ouvrir") { [unowned self] in enter(.chats) })]
                : []
            return [ResultItem(id: "agent.hint", section: "Agent", title: "Demande n'importe quoi à \(AgentEngine.assistant.name)",
                               subtitle: "Auto : Luna choisit le niveau · « ?? » Recherche & Action · « ??? » Code · ⌘O fichier · ⇧⌘S capture",
                               icon: .symbol("sparkles", .purple), primary: ItemAction(title: "OK") {})] + recent + all
        }
        let item = { [unowned self] (level: AgentLevel) -> ResultItem in
            ResultItem(
                id: "agent\(level.rawValue):" + request, section: "Agent",
                title: level == .fast ? "Demander à \(AgentEngine.assistant.name) : \(request)" : "\(level.title) : \(request)",
                subtitle: "\(level.detail) · \(level.modelLabel)",
                icon: .symbol(level.symbol, level.tint), accessory: "Niveau \(level.rawValue)",
                primary: ItemAction(title: level == .fast ? "Demander" : level.title) { [unowned self] in
                    startAgent(request, level: level)
                },
                secondary: level == .fast ? ItemAction(title: "Recherche & Action") { [unowned self] in
                    startAgent(request, level: .work)
                } : nil,
                tertiary: level == .fast ? ItemAction(title: "Code") { [unowned self] in
                    startAgent(request, level: .code)
                } : nil,
                copyText: request)
        }
        // Par défaut Luna décide ; « ?? » et « ??? » forcent un niveau.
        return [item(AgentLevel(rawValue: min(max(marks, 1), 3)) ?? .fast)]
    }

    func startAgent(_ request: String, level: AgentLevel) {
        let run = AgentRun(request: request, level: level, attachments: attachments)
        enter(.agent)
        attachAgent(run)
        run.start()
        if level == .code { c.hide() }
    }
}
