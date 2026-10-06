import AppKit
import SwiftUI
import Combine

/// Intégration de Hermes Agent (Nous Research) : un modèle rapide « routeur » agit tout de suite
/// sur les demandes simples, ou reformule la demande et l'envoie au modèle par défaut dans le terminal.
enum Hermes {
    /// Commande d'installation officielle (README de Hermes Agent).
    static let installCommand = "curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash"

    static var binary: String? { HermesStatus.shared.binary }
    static var models: [ModelOption] { HermesStatus.shared.models }
    /// Providers pour lesquels Hermes a des identifiants.
    static var providers: [String] { HermesStatus.shared.providers }

    static var available: Bool { binary != nil && AppSettings.shared.agentEnabled }

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
        func pick(_ preferences: [String]) -> ModelOption? {
            preferences.lazy.compactMap { name in models.first { $0.model == name } }.first
        }
        if !s.agentRouterModel.isEmpty && !providers.contains(s.agentRouterProvider) {
            let choice = pick(quickPreferences)
            s.agentRouterProvider = choice?.provider ?? ""
            s.agentRouterModel = choice?.model ?? ""
        }
        if !s.agentResearchModel.isEmpty && !providers.contains(s.agentResearchProvider) {
            let choice = pick(researchPreferences)
            s.agentResearchProvider = choice?.provider ?? ""
            s.agentResearchModel = choice?.model ?? ""
        }
        if !s.agentDefaultProvider.isEmpty && !providers.contains(s.agentDefaultProvider) {
            s.agentDefaultProvider = ""
            s.agentDefaultModel = ""
        }
    }

    static func label(provider: String, model: String) -> String {
        guard !model.isEmpty else { return "modèle par défaut de Hermes" }
        return provider.isEmpty ? model : "\(model) (\(providerName(provider)))"
    }

    static var defaultModelLabel: String {
        label(provider: AppSettings.shared.agentDefaultProvider, model: AppSettings.shared.agentDefaultModel)
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

    /// Ouvre une session Hermes interactive dans le terminal choisi, amorcée avec le prompt.
    static func delegate(_ prompt: String) {
        let settings = AppSettings.shared
        var command = "hermes chat -q \(quote(prompt))"
        for arg in modelArgs(provider: settings.agentDefaultProvider, model: settings.agentDefaultModel) {
            command += " " + quote(arg)
        }
        if !settings.agentDefaultReasoning.isEmpty { command += " --reasoning \(settings.agentDefaultReasoning)" }
        Shell.runInTerminal(command, in: Shell.expand(settings.agentWorkdir))
    }

    /// Phase 1 : classement sans outils (rapide, ne peut rien faire lui-même).
    static func routerPrompt(for request: String) -> String {
        let forms: String
        if AppSettings.shared.agentStrategy == "delegate" {
            forms = """
            Reply exactly: DELEGATE: <rewritten, precise, self-contained prompt for a more capable agent, in the user's \
            language, with useful context: paths, constraints, expected result>
            """
        } else {
            forms = """
            Decide the level of effort needed and reply with exactly one of these forms and nothing else:
            ANSWER: <short answer in the user's language> — level 1: a short answer you are sure of is enough \
            (fact, definition, conversion, which command to use).
            ACT: <the quick action to perform, rewritten as a precise instruction> — level 1: doable in under a minute \
            with a few commands (open or launch something, change a setting, create a single file or folder, run one \
            short command).
            RESEARCH: <rewritten, precise question in the user's language> — level 2: needs up-to-date information, web \
            search, comparing sources, or a thoughtful explanation, but no long work on the Mac.
            DELEGATE: <rewritten, precise, self-contained prompt for a more capable agent, in the user's language, with \
            useful context: paths, constraints, expected result> — level 3: coding, building an app, multi-step work on \
            files or projects, anything long, destructive or irreversible.
            """
        }
        return """
        You are the fast router of Hello, a launcher on the user's Mac (macOS). Classify the user's request. \
        You have no tools and must not try to do the task.
        \(forms)

        User request: \(request)
        """
    }

    /// Phase 2 : exécution d'une action rapide, bornée en tours et en durée.
    static func actPrompt(for instruction: String) -> String {
        """
        \(instruction)

        Do it now on this Mac with as few tool calls as possible. Never do anything destructive or irreversible \
        (deleting data, sending messages, payments, pushing code). Finish with one line: \
        DONE: <short summary in the user's language>
        """
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

/// Les trois niveaux de réflexion de l'agent.
enum AgentLevel: Int, CaseIterable {
    case quick = 1, research, deep

    var title: String {
        switch self {
        case .quick: "Rapide"
        case .research: "Recherche"
        case .deep: "Approfondi"
        }
    }

    var symbol: String {
        switch self {
        case .quick: "bolt.fill"
        case .research: "magnifyingglass.circle.fill"
        case .deep: "brain.head.profile"
        }
    }

    var tint: Color {
        switch self {
        case .quick: .yellow
        case .research: .cyan
        case .deep: .purple
        }
    }

    /// Modèle utilisé à ce niveau, pour l'affichage.
    var modelLabel: String {
        let s = AppSettings.shared
        switch self {
        case .quick: return Hermes.label(provider: s.agentRouterProvider, model: s.agentRouterModel)
        case .research: return Hermes.label(provider: s.agentResearchProvider, model: s.agentResearchModel)
        case .deep: return Hermes.defaultModelLabel
        }
    }

    var detail: String {
        switch self {
        case .quick: "Luna choisit le niveau"
        case .research: "Cherche sur le web et répond ici"
        case .deep: "Session complète dans \(Shell.terminal.name)"
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
    @Published private(set) var phase: Phase = .thinking
    @Published private(set) var stage = "analyse ta demande"
    @Published private(set) var details = ""
    private(set) var sessionID: String?
    private(set) var startedAt = Date()
    private var process: Process?

    init(request: String, level: AgentLevel) {
        self.request = request
        self.level = level
    }

    var isThinking: Bool {
        switch phase {
        case .thinking, .streaming: return true
        default: return false
        }
    }

    var modelLabel: String { level.modelLabel }

    func start() {
        startedAt = Date()
        switch level {
        case .deep: send(request)
        case .research: research(request)
        case .quick:
            stage = "choisit le niveau"
            AppSettings.shared.agentStrategy == "act" ? act(request) : classify()
        }
    }

    // MARK: Niveau 1 — Rapide

    private func classify() {
        let settings = AppSettings.shared
        var args = ["-z", Hermes.routerPrompt(for: request), "-t", "todo"]
            + Hermes.modelArgs(provider: settings.agentRouterProvider, model: settings.agentRouterModel)
        if !settings.agentRouterReasoning.isEmpty { args += ["--reasoning", settings.agentRouterReasoning] }
        launch(args) { [weak self] text in self?.route(text) }
    }

    private func act(_ instruction: String) {
        let settings = AppSettings.shared
        stage = "s'en occupe"
        var args = ["chat", "-Q", "-q", Hermes.actPrompt(for: instruction),
                    "--max-turns", "8", "--run-budget", "60", "-t", "terminal,file,web"]
            + Hermes.modelArgs(provider: settings.agentRouterProvider, model: settings.agentRouterModel)
        if !settings.agentRouterReasoning.isEmpty { args += ["--reasoning", settings.agentRouterReasoning] }
        launch(args) { [weak self] text in
            guard let self else { return }
            if let range = text.range(of: "DONE:", options: .backwards) {
                details = text[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
                phase = .done(text[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines))
            } else {
                phase = .done(text)
            }
        }
    }

    /// Luna a choisi : niveau 1 (réponse ou action), 2 (recherche) ou 3 (terminal).
    private func route(_ text: String) {
        let tags = ["ANSWER:", "ACT:", "RESEARCH:", "DELEGATE:"]
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
        case "ACT:": act(content)
        case "RESEARCH:": research(content)
        case "DELEGATE:":
            level = .deep
            send(content)
            // Le terminal passe devant : on referme le panneau.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { Controller.shared.hide() }
        default: phase = .answer(content)
        }
    }

    // MARK: Niveau 2 — Recherche (réponse en direct dans Hello)

    func research(_ prompt: String) {
        let settings = AppSettings.shared
        stage = "cherche"
        level = .research
        phase = .thinking
        startedAt = Date()
        let instructions = """
        \(prompt)

        Research this carefully (use the web when useful) and answer in the user's language, structured and concise, \
        with short sections or bullet points when it helps, and cite sources as markdown links. \
        Never do anything destructive or irreversible on this Mac.
        """
        var args = ["chat", "-q", instructions, "--format", "stream-json",
                    "--max-turns", "25", "--run-budget", "300", "-t", "web,file,terminal"]
            + Hermes.modelArgs(provider: settings.agentResearchProvider, model: settings.agentResearchModel)
        if !settings.agentResearchReasoning.isEmpty { args += ["--reasoning", settings.agentResearchReasoning] }
        var streamed = ""
        launch(args, streaming: { [weak self] line in
            guard let self, let data = line.data(using: .utf8),
                  let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            if let sid = event["session_id"] as? String { sessionID = sid }
            switch event["type"] as? String {
            case "text":
                streamed += event["text"] as? String ?? ""
                phase = .streaming(streamed)
            case "result":
                let text = (event["text"] as? String) ?? streamed
                phase = text.isEmpty ? .failed("Aucune réponse.") : .answer(text)
            default: break
            }
        }) { [weak self] _ in
            guard let self, self.isThinking else { return }
            phase = streamed.isEmpty ? .failed("Aucune réponse.") : .answer(streamed)
        }
    }

    // MARK: Niveau 3 — Approfondi (terminal)

    func send(_ prompt: String) {
        Hermes.delegate(prompt)
        phase = .delegated(prompt)
    }

    /// Reprend la session de recherche dans le terminal, avec le même modèle.
    func continueInTerminal() {
        guard let sessionID else { return send(request) }
        let s = AppSettings.shared
        var command = "hermes chat --resume \(Hermes.quote(sessionID))"
        for arg in Hermes.modelArgs(provider: s.agentResearchProvider, model: s.agentResearchModel) {
            command += " " + Hermes.quote(arg)
        }
        Shell.runInTerminal(command, in: Shell.expand(s.agentWorkdir))
    }

    // MARK: Processus

    /// Lance Hermes. `streaming` reçoit chaque ligne de sortie au fil de l'eau (sur le fil principal),
    /// `handle` la sortie complète à la fin (code 0 uniquement).
    private func launch(_ args: [String], streaming: ((String) -> Void)? = nil, then handle: @escaping (String) -> Void) {
        guard let binary = Hermes.binary else {
            phase = .failed("Hermes introuvable dans le PATH.")
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
                    self.phase = .failed(p.terminationReason == .uncaughtSignal ? "Annulé."
                        : (detail.isEmpty ? "Hermes a quitté avec le code \(p.terminationStatus)." : detail))
                }
            }
        }
        do {
            try process.run()
            self.process = process
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func cancel() {
        if process?.isRunning == true { process?.terminate() }
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
        guard !request.isEmpty else {
            return [ResultItem(id: "agent.hint", section: "Agent", title: "Demande n'importe quoi à Hermes",
                               subtitle: "Luna choisit le niveau · « ?? » force la recherche · « ??? » force le terminal",
                               icon: .symbol("sparkles", .purple), primary: ItemAction(title: "OK") {})]
        }
        let item = { [unowned self] (level: AgentLevel) -> ResultItem in
            ResultItem(
                id: "agent\(level.rawValue):" + request, section: "Agent",
                title: level == .quick ? "Demander à Hermes : \(request)" : "\(level.title) : \(request)",
                subtitle: "\(level.detail) · \(level.modelLabel)",
                icon: .symbol(level.symbol, level.tint), accessory: "Niveau \(level.rawValue)",
                primary: ItemAction(title: level == .quick ? "Demander" : level.title) { [unowned self] in
                    startAgent(request, level: level)
                },
                secondary: level == .quick ? ItemAction(title: "Forcer Recherche") { [unowned self] in
                    startAgent(request, level: .research)
                } : nil,
                tertiary: level == .quick ? ItemAction(title: "Forcer Approfondi") { [unowned self] in
                    startAgent(request, level: .deep)
                } : nil,
                copyText: request)
        }
        // Par défaut Luna décide ; « ?? » et « ??? » forcent un niveau.
        return [item(AgentLevel(rawValue: min(max(marks, 1), 3)) ?? .quick)]
    }

    func startAgent(_ request: String, level: AgentLevel) {
        let run = AgentRun(request: request, level: level)
        enter(.agent)
        attachAgent(run)
        run.start()
        if level == .deep { c.hide() }
    }
}
