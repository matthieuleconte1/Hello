import Foundation

/// Un échange avec Hermes : la demande et ce qui en est sorti.
struct ChatTurn: Codable, Identifiable {
    enum Kind: String, Codable { case answer, done, code }

    var id = UUID()
    let date: Date
    let level: Int
    let request: String
    /// Réponse, résumé d'une action, ou prompt envoyé au terminal (niveau 3).
    let answer: String
    let kind: Kind
    var steps: [String] = []
    var attachments: [String] = []
    var sessionID: String?
    /// Fournisseur qui a répondu (absent des conversations enregistrées avant le choix du fournisseur : Hermes).
    var engine: String?

    var agentLevel: AgentLevel { AgentLevel(rawValue: level) ?? .fast }
    var agentEngine: AgentEngine { engine.flatMap(AgentEngine.init(rawValue:)) ?? .hermes }
}

/// Une conversation : la première demande et ses questions de suite.
struct ChatConversation: Codable, Identifiable {
    var id = UUID()
    var turns: [ChatTurn] = []

    var title: String { turns.first?.request ?? "" }
    var updated: Date { turns.last?.date ?? .distantPast }

    /// Échanges précédents, joints aux prompts pour que Hermes reprenne le fil (les plus récents, réponses abrégées).
    var transcript: String {
        guard !turns.isEmpty else { return "" }
        let lines = turns.suffix(8).map { turn -> String in
            var answer = turn.answer
            if answer.count > 1500 { answer = String(answer.prefix(1500)) + "…" }
            let files = turn.attachments.isEmpty ? "" : "\n(attached: \(turn.attachments.joined(separator: ", ")))"
            let what = turn.kind == .code ? "sent to a coding session in the terminal" : "answered"
            return "User: \(turn.request)\(files)\nAssistant (\(what)): \(answer)"
        }
        return lines.joined(separator: "\n\n")
    }
}

/// Historique des conversations avec Hermes, gardé dans ~/Library/Application Support/Hello/chats.json.
final class ChatStore: ObservableObject {
    static let shared = ChatStore()
    private static let limit = 200

    @Published private(set) var conversations: [ChatConversation] = []
    private let url = ClipboardHistory.dir.appendingPathComponent("chats.json")
    private let io = DispatchQueue(label: "hello.chats.io", qos: .utility)

    private init() {
        if let data = try? Data(contentsOf: url),
           let list = try? JSONDecoder().decode([ChatConversation].self, from: data) {
            conversations = list
        }
    }

    /// Enregistre la conversation (nouvelle ou prolongée) et la remonte en tête.
    func save(_ conversation: ChatConversation) {
        guard !conversation.turns.isEmpty else { return }
        conversations.removeAll { $0.id == conversation.id }
        conversations.insert(conversation, at: 0)
        if conversations.count > Self.limit { conversations.removeLast(conversations.count - Self.limit) }
        write()
    }

    func delete(_ id: UUID) {
        conversations.removeAll { $0.id == id }
        write()
    }

    func clear() {
        conversations = []
        write()
    }

    func search(_ query: String) -> [ChatConversation] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return conversations }
        return conversations.filter { conversation in
            conversation.turns.contains {
                $0.request.localizedCaseInsensitiveContains(q) || $0.answer.localizedCaseInsensitiveContains(q)
            }
        }
    }

    private func write() {
        let snapshot = conversations
        let url = url
        io.async {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: url, options: .atomic)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        }
    }
}

extension LauncherModel {
    /// Ligne d'une conversation passée (mode Conversations, et sous « ? » vide).
    func chatItem(_ conversation: ChatConversation, section: String? = nil) -> ResultItem {
        let last = conversation.turns.last
        let level = last?.agentLevel ?? .fast
        let when = Self.relativeDate.localizedString(for: conversation.updated, relativeTo: Date())
        let exchanges = conversation.turns.count > 1 ? " · \(conversation.turns.count) échanges" : ""
        let snippet = (last?.answer ?? "").replacingOccurrences(of: "\n", with: " ").prefix(90)
        return ResultItem(
            id: "chat:" + conversation.id.uuidString, section: section, title: conversation.title,
            subtitle: "\(when)\(exchanges) · \(snippet)",
            icon: .symbol(level.symbol, level.tint),
            primary: ItemAction(title: "Reprendre") { [unowned self] in openConversation(conversation) },
            secondary: last?.sessionID == nil ? nil : ItemAction(title: "Continuer dans le terminal") { [unowned self] in
                AgentRun(restoring: conversation).continueInTerminal()
                c.hide()
            },
            remove: ItemAction(title: "Supprimer") { [unowned self] in
                ChatStore.shared.delete(conversation.id)
                refresh()
            },
            copyText: last?.answer)
    }

    func chatItems() -> [ResultItem] {
        ChatStore.shared.search(query).prefix(80).map { chatItem($0) }
    }

    /// Rouvre une conversation dans la vue de l'agent, prête pour une question de suite.
    func openConversation(_ conversation: ChatConversation) {
        guard !conversation.turns.isEmpty else { return }
        let run = AgentRun(restoring: conversation)
        enter(.agent)
        attachAgent(run)
        DispatchQueue.main.async { self.c.focusSearch() }
    }

    /// Question de suite : même conversation, Hermes reçoit les échanges précédents.
    func followUp(_ text: String, level: AgentLevel) {
        guard let previous = agent else { return }
        let run = AgentRun(request: text, level: level, conversation: previous.conversation)
        attachAgent(run)
        setQuery("")
        run.start()
        if level == .code { c.hide() }
    }

    static let relativeDate: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.unitsStyle = .short
        return formatter
    }()
}
