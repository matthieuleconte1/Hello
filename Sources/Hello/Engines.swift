import Foundation

/// Fournisseur d'IA d'un niveau : Hermes, Claude Code, Codex ou Antigravity (Gemini), des outils en ligne de commande déjà connectés
/// à leur compte. Hello les lance, lit leurs événements et affiche le résultat.
enum AgentEngine: String, CaseIterable, Identifiable {
    case hermes, claude, codex, agy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hermes: "Hermes"
        case .claude: "Claude Code"
        case .codex: "Codex"
        case .agy: "Antigravity"
        }
    }

    var binary: String? {
        self == .hermes ? Hermes.binary : EngineStatus.shared.paths[self]
    }

    var installed: Bool { binary != nil }

    var installCommand: String {
        switch self {
        case .hermes: Hermes.installCommand
        case .claude: "curl -fsSL https://claude.ai/install.sh | bash"
        case .codex: "brew install codex"
        case .agy: "open https://antigravity.google/download"
        }
    }

    /// Modèles proposés (Hermes a sa propre liste, groupée par compte) : valeur passée à l'outil, nom affiché.
    var models: [ModelChoice] {
        switch self {
        case .hermes: Hermes.models.map { ModelChoice(id: $0.model, name: $0.model) }
        case .claude: [ModelChoice(id: "opus", name: "Opus 5.5"), ModelChoice(id: "sonnet", name: "Sonnet 5.5"),
                       ModelChoice(id: "haiku", name: "Haiku 5.5"), ModelChoice(id: "fable", name: "Fable 5.1")]
        case .codex: EngineStatus.shared.codexModels
        case .agy: EngineStatus.shared.agyModels
        }
    }

    var reasoningLevels: [String] {
        switch self {
        case .hermes: ["none", "minimal", "low", "medium", "high", "xhigh"]
        case .claude, .codex, .agy: ["low", "medium", "high", "xhigh", "max"]
        }
    }

    /// Réglage proposé quand on choisit ce fournisseur pour un niveau.
    func defaults(for level: AgentLevel) -> (provider: String, model: String, reasoning: String) {
        switch (self, level) {
        case (.hermes, .fast): ("openai-codex", "gpt-6-luna", "low")
        case (.hermes, .work): ("anthropic", "claude-sonnet-5-5", "medium")
        case (.hermes, .code): ("", "", "")
        case (.claude, .fast): ("", "haiku", "low")
        case (.claude, .work): ("", "sonnet", "medium")
        case (.claude, .code): ("", "opus", "")
        case (.codex, .fast): ("", "gpt-6-luna", "low")
        case (.codex, .work): ("", "gpt-6.1-sol", "medium")
        case (.codex, .code): ("", "", "")
        // Le niveau de raisonnement fait partie du nom des modèles d'Antigravity.
        case (.agy, .fast): ("", "gemini-3.8-flash-low", "")
        case (.agy, .work): ("", "gemini-4-hydrogen-medium", "")
        case (.agy, .code): ("", "", "")
        }
    }

    func modelName(_ id: String) -> String {
        models.first { $0.id == id }?.name ?? id
    }

    // MARK: Arguments

    private func modelArgs(_ config: LevelConfig) -> [String] {
        switch self {
        case .hermes:
            var args = Hermes.modelArgs(provider: config.provider, model: config.model)
            if !config.reasoning.isEmpty { args += ["--reasoning", config.reasoning] }
            return args
        case .claude, .agy:
            return (config.model.isEmpty ? [] : ["--model", config.model])
                + (config.reasoning.isEmpty ? [] : ["--effort", config.reasoning])
        case .codex:
            return (config.model.isEmpty ? [] : ["-m", config.model])
                + (config.reasoning.isEmpty ? [] : ["-c", "model_reasoning_effort=\"\(config.reasoning)\""])
        }
    }

    /// Niveau 1 : classement sans aucun outil. Codex répond en JSON (`streamsRouter`), les autres en texte.
    func routerArgs(_ prompt: String, _ config: LevelConfig) -> [String] {
        switch self {
        case .hermes: ["-z", prompt, "-t", "todo"] + modelArgs(config)
        case .claude: ["-p", prompt, "--output-format", "text", "--tools", "", "--no-session-persistence"] + modelArgs(config)
        case .codex: ["exec", prompt, "--json", "--skip-git-repo-check", "--ephemeral", "-s", "read-only"] + modelArgs(config)
        case .agy: ["-p", prompt, "--output-format", "text"] + modelArgs(config)
        }
    }

    var streamsRouter: Bool { self == .codex }

    /// Niveau 2 : web et actions sur le Mac, en flux d'événements.
    func workArgs(_ prompt: String, _ config: LevelConfig, context: MacContext) -> [String] {
        switch self {
        case .hermes:
            return ["chat", "-q", prompt, "--format", "stream-json", "--max-turns", "30", "--run-budget", "300",
                    "-t", Hermes.workTools] + Hermes.imageArgs(context) + modelArgs(config)
        case .claude:
            // Outils permis d'office, rien d'autre (dontAsk refuse ce qui demanderait une confirmation).
            return ["-p", prompt, "--output-format", "stream-json", "--verbose", "--include-partial-messages",
                    "--allowedTools", "Bash,Read,Glob,Grep,WebSearch,WebFetch,TodoWrite",
                    "--disallowedTools", "Bash(rm *),Bash(sudo *),Bash(git push *),Bash(diskutil *)",
                    "--permission-mode", "dontAsk"] + modelArgs(config)
        case .codex:
            // Bac à sable : écriture dans le dossier de travail, réseau ouvert ; recherche web native.
            let images = context.attachments.filter(\.isImage).map(\.url.path)
            return ["--search", "exec", prompt, "--json", "--skip-git-repo-check", "-s", "workspace-write",
                    "-c", "sandbox_workspace_write.network_access=true",
                    "-C", Shell.expand(AppSettings.shared.agentWorkdir)]
                + modelArgs(config) + (images.isEmpty ? [] : ["-i"] + images)
        case .agy:
            // Mode par défaut (request-review) : Antigravity juge lui-même les commandes à risque.
            return ["-p", prompt, "--output-format", "stream-json"] + modelArgs(config)
        }
    }

    /// Hermes borne lui-même sa durée ; pour les autres, Hello arrête le processus.
    var needsTimeout: Bool { self != .hermes }

    /// Niveau 3 : session interactive dans le terminal, amorcée avec le prompt.
    func terminalCommand(_ prompt: String, _ config: LevelConfig) -> String {
        let head = switch self {
        case .hermes: "hermes chat -q"
        case .claude: "claude"
        case .codex: "codex"
        case .agy: "agy -i"
        }
        return ([head, Hermes.quote(prompt)] + modelArgs(config).map(Hermes.quote)).joined(separator: " ")
    }

    /// Reprend une session dans le terminal.
    func resumeCommand(_ sessionID: String, _ config: LevelConfig) -> String {
        switch self {
        case .hermes: (["hermes chat --resume", Hermes.quote(sessionID)] + Hermes.modelArgs(provider: config.provider, model: config.model)
                .map(Hermes.quote)).joined(separator: " ")
        case .claude: "claude --resume \(Hermes.quote(sessionID))"
        case .codex: "codex resume \(Hermes.quote(sessionID))"
        case .agy: "agy --conversation \(Hermes.quote(sessionID))"
        }
    }

    /// Nom de l'assistant dans l'interface : celui du fournisseur s'il est le même partout, sinon « l'IA ».
    static var assistant: (name: String, capitalized: String, short: String) {
        let engines = Set(AgentLevel.allCases.map(\.config.engine))
        guard engines.count == 1, let engine = engines.first else { return ("l'IA", "L'IA", "IA") }
        return (engine.title, engine.title, engine.title)
    }
}

struct ModelChoice: Hashable {
    let id: String
    let name: String
}

/// Réglage d'un niveau : fournisseur, compte (Hermes seulement), modèle, raisonnement.
struct LevelConfig {
    let engine: AgentEngine
    let provider: String
    let model: String
    let reasoning: String

    var label: String {
        switch engine {
        case .hermes: Hermes.label(provider: provider, model: model)
        case .claude, .codex, .agy: (model.isEmpty ? "modèle par défaut" : engine.modelName(model)) + " · " + engine.title
        }
    }
}

extension AgentLevel {
    var config: LevelConfig {
        let s = AppSettings.shared
        return switch self {
        case .fast: LevelConfig(engine: AgentEngine(rawValue: s.agentRouterEngine) ?? .hermes,
                                provider: s.agentRouterProvider, model: s.agentRouterModel, reasoning: s.agentRouterReasoning)
        case .work: LevelConfig(engine: AgentEngine(rawValue: s.agentResearchEngine) ?? .hermes,
                                provider: s.agentResearchProvider, model: s.agentResearchModel, reasoning: s.agentResearchReasoning)
        case .code: LevelConfig(engine: AgentEngine(rawValue: s.agentDefaultEngine) ?? .hermes,
                                provider: s.agentDefaultProvider, model: s.agentDefaultModel, reasoning: s.agentDefaultReasoning)
        }
    }

    /// Change le fournisseur du niveau et reprend le réglage proposé pour lui.
    func setEngine(_ engine: AgentEngine) {
        let s = AppSettings.shared
        let d = engine.defaults(for: self)
        switch self {
        case .fast:
            s.agentRouterEngine = engine.rawValue
            (s.agentRouterProvider, s.agentRouterModel, s.agentRouterReasoning) = d
        case .work:
            s.agentResearchEngine = engine.rawValue
            (s.agentResearchProvider, s.agentResearchModel, s.agentResearchReasoning) = d
        case .code:
            s.agentDefaultEngine = engine.rawValue
            (s.agentDefaultProvider, s.agentDefaultModel, s.agentDefaultReasoning) = d
        }
    }
}

/// Emplacements de `claude`, `codex` et `agy`, et modèles de Codex et d'Antigravity (Hermes a son propre état).
final class EngineStatus: ObservableObject {
    static let shared = EngineStatus()
    @Published fileprivate(set) var paths: [AgentEngine: String] = [:]
    @Published fileprivate(set) var codexModels: [ModelChoice] = []
    @Published fileprivate(set) var agyModels: [ModelChoice] = []

    static func locate() {
        DispatchQueue.global(qos: .utility).async {
            var found: [AgentEngine: String] = [:]
            let places: [AgentEngine: [String]] = [
                .claude: [Shell.home + "/.local/bin/claude", "/opt/homebrew/bin/claude", "/usr/local/bin/claude",
                          Shell.home + "/.claude/local/claude"],
                .codex: ["/opt/homebrew/bin/codex", "/usr/local/bin/codex", Shell.home + "/.local/bin/codex"],
                .agy: [Shell.home + "/.local/bin/agy", "/opt/homebrew/bin/agy", "/usr/local/bin/agy"],
            ]
            for (engine, candidates) in places {
                let fromShell = Shell.capture("command -v \(engine.rawValue)").trimmingCharacters(in: .whitespacesAndNewlines)
                    .split(separator: "\n").last.map(String.init) ?? ""
                found[engine] = ([fromShell] + candidates).first {
                    $0.hasPrefix("/") && FileManager.default.isExecutableFile(atPath: $0)
                }
            }
            // Les fournisseurs trouvés s'affichent tout de suite ; les modèles d'Antigravity (lus sur le réseau)
            // arrivent ensuite.
            let models = codexModelList()
            DispatchQueue.main.async {
                shared.paths = found
                shared.codexModels = models
            }
            let agy = found[.agy].map(agyModelList) ?? []
            DispatchQueue.main.async { if !agy.isEmpty { shared.agyModels = agy } }
        }
    }

    /// `agy models` : une ligne « identifiant<TAB>nom affiché » par modèle.
    private static func agyModelList(_ binary: String) -> [ModelChoice] {
        Shell.capture(Hermes.quote(binary) + " models").split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "\t", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2, !parts[0].isEmpty, !parts[0].contains(" ") else { return nil }
            return ModelChoice(id: parts[0], name: parts[1])
        }
    }

    /// Modèles visibles du cache de Codex (~/.codex/models_cache.json).
    private static func codexModelList() -> [ModelChoice] {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: Shell.home + "/.codex/models_cache.json")),
              let cache = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = cache["models"] as? [[String: Any]] else { return [] }
        return models.compactMap { model in
            guard (model["visibility"] as? String) != "hide", let slug = model["slug"] as? String else { return nil }
            return ModelChoice(id: slug, name: model["display_name"] as? String ?? slug)
        }
    }
}

// MARK: - Événements

enum EngineEvent {
    case session(String)
    case step(String)
    case text(String)
    case final(String)
    case failure(String)
}

/// Lit le flux JSON d'un fournisseur, ligne par ligne, et le traduit en événements communs.
final class EventParser {
    private let engine: AgentEngine
    private var lastMessage = ""
    private var lastError: String?

    init(_ engine: AgentEngine) { self.engine = engine }

    func feed(_ line: String) -> [EngineEvent] {
        guard let data = line.data(using: .utf8),
              let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        switch engine {
        case .hermes: return hermes(event)
        case .claude: return claude(event)
        case .codex: return codex(event)
        case .agy: return agy(event)
        }
    }

    private func hermes(_ event: [String: Any]) -> [EngineEvent] {
        var out: [EngineEvent] = []
        if let sid = event["session_id"] as? String, !sid.isEmpty { out.append(.session(sid)) }
        switch event["type"] as? String {
        case "tool_use":
            out.append(.step(Hermes.stepLabel(event["name"] as? String ?? "", input: event["input"] as? [String: Any])))
        case "text":
            out.append(.text(event["text"] as? String ?? ""))
        case "result":
            let text = (event["text"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            out.append(text.isEmpty ? .failure(event["error"] as? String ?? "Aucune réponse.") : .final(text))
        default: break
        }
        return out
    }

    private func claude(_ event: [String: Any]) -> [EngineEvent] {
        switch event["type"] as? String {
        case "system":
            if event["subtype"] as? String == "init", let sid = event["session_id"] as? String { return [.session(sid)] }
        case "stream_event":
            if let inner = event["event"] as? [String: Any], inner["type"] as? String == "content_block_delta",
               let delta = inner["delta"] as? [String: Any], delta["type"] as? String == "text_delta",
               let text = delta["text"] as? String {
                return [.text(text)]
            }
        case "assistant":
            let content = (event["message"] as? [String: Any])?["content"] as? [[String: Any]] ?? []
            return content.filter { $0["type"] as? String == "tool_use" }.map {
                .step(Self.claudeStep($0["name"] as? String ?? "", input: $0["input"] as? [String: Any]))
            }
        case "result":
            let text = (event["result"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if event["is_error"] as? Bool == true || text.isEmpty {
                return [.failure(text.isEmpty ? "Aucune réponse." : text)]
            }
            return [.final(text)]
        default: break
        }
        return []
    }

    private func codex(_ event: [String: Any]) -> [EngineEvent] {
        let item = event["item"] as? [String: Any] ?? [:]
        switch (event["type"] as? String, item["type"] as? String) {
        case ("thread.started", _):
            if let id = event["thread_id"] as? String { return [.session(id)] }
        case ("item.started", "command_execution"?):
            return [.step("$ " + Self.unwrapShell(item["command"] as? String ?? ""))]
        case ("item.started", "web_search"?):
            return [.step((item["query"] as? String).map { "Cherche « \($0) »" } ?? "Cherche sur le web")]
        case ("item.started", "file_change"?):
            return [.step("Modifie des fichiers")]
        case ("item.started", "mcp_tool_call"?):
            return [.step(item["tool"] as? String ?? "Utilise un outil")]
        case ("item.completed", "agent_message"?):
            let text = item["text"] as? String ?? ""
            lastMessage = text
            return [.text(text + "\n\n")]
        case ("turn.completed", _):
            let text = lastMessage.trimmingCharacters(in: .whitespacesAndNewlines)
            return [text.isEmpty ? .failure(lastError ?? "Aucune réponse.") : .final(text)]
        case ("turn.failed", _):
            return [.failure((event["error"] as? [String: Any])?["message"] as? String ?? lastError ?? "Codex a échoué.")]
        case ("error", _):
            lastError = event["message"] as? String
        default: break
        }
        return []
    }

    /// Antigravity : `init`, puis des `step_update` (outils, morceaux de texte), puis `result`.
    private func agy(_ event: [String: Any]) -> [EngineEvent] {
        switch event["event"] as? String {
        case "init":
            if let id = event["conversation_id"] as? String { return [.session(id)] }
        case "step_update":
            let step = event["step_update"] as? [String: Any] ?? [:]
            switch step["step_type"] as? String {
            case "tool" where step["state"] as? String == "ACTIVE":
                let info = step["tool_info"] as? [String: Any]
                return [.step(Self.agyStep(step["tool_name"] as? String ?? "", input: info?["parameters"] as? [String: Any]))]
            case "agent_response":
                if let text = step["text_delta"] as? String, !text.isEmpty { return [.text(text)] }
            default: break
            }
        case "result":
            let result = event["result"] as? [String: Any] ?? [:]
            let text = (result["response"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if result["status"] as? String != "SUCCESS" || text.isEmpty {
                let error = (result["error"] as? String) ?? ((result["error"] as? [String: Any])?["message"] as? String)
                return [.failure(text.isEmpty ? error ?? "Aucune réponse." : text)]
            }
            return [.final(text)]
        default: break
        }
        return []
    }

    private static func agyStep(_ name: String, input: [String: Any]?) -> String {
        let text = { (keys: [String]) in
            keys.lazy.compactMap { (input?[$0] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) }.first
        }
        let file = { text(["AbsolutePath", "TargetFile", "FilePath", "path"]).map { URL(fileURLWithPath: $0).lastPathComponent } ?? "un fichier" }
        switch name {
        case "run_command": return text(["CommandLine", "command"]).map { "$ " + $0.replacingOccurrences(of: "\n", with: " ⏎ ") } ?? "Lance une commande"
        case "view_file": return "Lit \(file())"
        case "write_to_file", "replace_file_content", "multi_replace_file_content", "sed_file", "notebook_edit": return "Écrit \(file())"
        case "find_by_name", "grep_search", "list_dir": return "Cherche des fichiers"
        case "search_web": return text(["query", "Query"]).map { "Cherche « \($0) »" } ?? "Cherche sur le web"
        case "read_url_content": return "Lit une page web"
        case "manage_task": return "Planifie les étapes"
        case "invoke_subagent", "browser_subagent": return "Délègue une sous-tâche"
        case let n where n.hasPrefix("browser") || n.contains("_browser"): return "Navigue dans le navigateur"
        default: return name
        }
    }

    /// « /bin/zsh -lc "osascript … && date" » ou « /bin/zsh -lc date » → la commande elle-même.
    private static func unwrapShell(_ command: String) -> String {
        guard let prefix = command.range(of: #"^/bin/\w+ -l?c "#, options: .regularExpression) else { return command }
        var inner = String(command[prefix.upperBound...])
        if let first = inner.first, first == "\"" || first == "'", inner.count >= 2, inner.last == first {
            inner = String(inner.dropFirst().dropLast())
        }
        return inner.replacingOccurrences(of: "\\\"", with: "\"")
    }

    private static func claudeStep(_ name: String, input: [String: Any]?) -> String {
        let text = { (key: String) in (input?[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) }
        let file = { text("file_path").map { URL(fileURLWithPath: $0).lastPathComponent } ?? "un fichier" }
        switch name {
        case "Bash": return text("command").map { "$ " + $0.replacingOccurrences(of: "\n", with: " ⏎ ") } ?? "Lance une commande"
        case "Read": return "Lit \(file())"
        case "Write", "Edit", "MultiEdit", "NotebookEdit": return "Écrit \(file())"
        case "Glob", "Grep": return "Cherche des fichiers"
        case "WebSearch": return text("query").map { "Cherche « \($0) »" } ?? "Cherche sur le web"
        case "WebFetch": return "Lit une page web"
        case "TodoWrite": return "Planifie les étapes"
        case "Task", "Agent": return "Délègue une sous-tâche"
        default: return name
        }
    }
}
