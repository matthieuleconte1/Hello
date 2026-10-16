import AppKit

/// Commandes « / » de l'agent, à l'accueil comme dans le champ de question de suite.
/// Sans conversation ouverte, celles qui en ont besoin agissent sur la plus récente.
struct SlashCommand {
    let name: String
    var aliases: [String] = []
    /// Argument attendu, affiché dans la liste (« <demande> »).
    var argument: String? = nil
    var argumentRequired = false
    let title: String
    let summary: String
    let symbol: String
    let run: (LauncherModel, String) -> Void

    func matches(_ word: String) -> Bool {
        word.isEmpty || ([name] + aliases).contains { $0.hasPrefix(word) }
    }

    func isExactly(_ word: String) -> Bool { ([name] + aliases).contains(word) }

    static let all: [SlashCommand] = [
        SlashCommand(name: "resume", aliases: ["history", "conversations"], argument: "<recherche>",
                     title: "Reprendre", summary: "Reprendre une conversation passée",
                     symbol: "bubble.left.and.text.bubble.right") { model, args in
            model.enter(.chats)
            model.setQuery(args)
        },
        SlashCommand(name: "new", aliases: ["clear"], argument: "<demande>",
                     title: "Nouvelle", summary: "Nouvelle conversation, sans les échanges précédents",
                     symbol: "square.and.pencil") { model, args in
            model.newConversation(args)
        },
        SlashCommand(name: "fast", argument: "<demande>", argumentRequired: true,
                     title: "Demander", summary: "Niveau 1 · Fast : Luna répond tout de suite", symbol: AgentLevel.fast.symbol) {
            model, args in model.ask(args, level: .fast)
        },
        SlashCommand(name: "work", aliases: ["recherche", "search"], argument: "<demande>", argumentRequired: true,
                     title: "Recherche & Action", summary: "Niveau 2 · cherche sur le web et agit sur le Mac",
                     symbol: AgentLevel.work.symbol) { model, args in model.ask(args, level: .work) },
        SlashCommand(name: "code", argument: "<demande>", argumentRequired: true,
                     title: "Code", summary: "Niveau 3 · session de code dans le terminal", symbol: AgentLevel.code.symbol) {
            model, args in model.ask(args, level: .code)
        },
        SlashCommand(name: "retry", aliases: ["again"], title: "Relancer",
                     summary: "Reposer la dernière demande, au même niveau", symbol: "arrow.clockwise") { model, _ in
            model.retryLast()
        },
        SlashCommand(name: "terminal", aliases: ["continue"], title: "Continuer dans le terminal",
                     summary: "Reprendre la conversation dans une session interactive, dans le terminal", symbol: "terminal") { model, _ in
            model.continueLastInTerminal()
        },
        SlashCommand(name: "copy", title: "Copier", summary: "Copier la dernière réponse", symbol: "doc.on.doc") { model, _ in
            guard let answer = model.currentConversation?.turns.last?.answer else { return model.flash("Aucune réponse à copier") }
            Paster.copy(answer)
            model.flash("Réponse copiée")
        },
        SlashCommand(name: "delete", aliases: ["forget"], title: "Supprimer",
                     summary: "Supprimer la conversation de l'historique", symbol: "trash") { model, _ in
            model.deleteCurrentConversation()
        },
        SlashCommand(name: "memory", title: "Mémoire", summary: "Ce que Hermes a retenu de toi (~/.hermes/memories)",
                     symbol: "brain") { model, _ in
            model.openHermesMemory()
        },
        SlashCommand(name: "model", aliases: ["models", "settings"], title: "Modèles",
                     summary: "Choisir les modèles de chaque niveau (Réglages › Agent)", symbol: "cpu") { model, _ in
            model.c.hide()
            WindowManager.showSettings(tab: .agent)
        },
        SlashCommand(name: "help", title: "Aide", summary: "Toutes les commandes « / »", symbol: "questionmark.circle") { model, _ in
            model.setQuery("/")
        },
    ]
}

extension LauncherModel {
    /// Commandes « / » correspondant au texte : « /re » propose /resume et /retry, « /code ma demande » la seule /code.
    func slashItems(_ text: String) -> [ResultItem] {
        guard Hermes.available, text.hasPrefix("/") else { return [] }
        let (first, args) = Shell.splitFirst(String(text.dropFirst()))
        let word = first.lowercased()
        // Un argument tapé : on ne garde que la commande exacte (sinon c'est un chemin, « /Users/… »).
        let commands = args.isEmpty ? SlashCommand.all.filter { $0.matches(word) }
            : SlashCommand.all.filter { $0.isExactly(word) }
        return commands.map { command in
            let usage = "/\(command.name)" + (command.argument.map { " \($0)" } ?? "")
            let missing = command.argumentRequired && args.isEmpty
            return ResultItem(
                id: "slash:" + command.name, section: "Commandes IA",
                title: args.isEmpty ? usage : "/\(command.name) \(args)",
                subtitle: command.summary,
                icon: .symbol(command.symbol, .purple),
                primary: ItemAction(title: command.title) { [unowned self] in
                    if missing { return setQuery("/\(command.name) ") }
                    command.run(self, args)
                },
                completion: "/\(command.name) ")
        }
    }

    /// Conversation visée : celle ouverte dans l'agent, sinon la plus récente de l'historique.
    var currentConversation: ChatConversation? {
        if mode == .agent, let conversation = agent?.conversation, !conversation.turns.isEmpty { return conversation }
        return ChatStore.shared.conversations.first
    }

    /// Demande à un niveau donné : question de suite dans une conversation ouverte, sinon nouvelle conversation.
    func ask(_ request: String, level: AgentLevel) {
        if mode == .agent, agent?.isThinking == false {
            followUp(request, level: level)
        } else {
            startAgent(request, level: level)
        }
    }

    func newConversation(_ request: String) {
        guard request.isEmpty else { return startAgent(request, level: .fast) }
        if mode != .root { back() }
        setQuery("? ")
    }

    func retryLast() {
        guard var conversation = currentConversation, let last = conversation.turns.popLast() else {
            return flash("Aucune demande à relancer")
        }
        let run = AgentRun(request: last.request, level: last.agentLevel, conversation: conversation)
        if mode != .agent { enter(.agent) }
        attachAgent(run)
        setQuery("")
        run.start()
        if last.agentLevel == .code { c.hide() }
    }

    func continueLastInTerminal() {
        guard let conversation = currentConversation else { return flash("Aucune conversation à continuer") }
        if conversation.turns.last?.sessionID != nil {
            AgentRun(restoring: conversation).continueInTerminal()
        } else {
            // Pas de session Hermes à reprendre (réponse de Luna) : le terminal repart avec les échanges en contexte.
            AgentRun(request: "Reprends cette conversation là où elle s'est arrêtée.", level: .code,
                     conversation: conversation).start()
        }
        c.hide()
    }

    func deleteCurrentConversation() {
        guard let conversation = currentConversation else { return flash("Aucune conversation à supprimer") }
        ChatStore.shared.delete(conversation.id)
        if mode == .agent { back() }
        flash("Conversation supprimée")
    }

    func openHermesMemory() {
        let folder = URL(fileURLWithPath: Shell.home + "/.hermes/memories")
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        guard !files.isEmpty else { return flash("Hermes n'a encore rien retenu") }
        c.hide()
        NSWorkspace.shared.open(folder)
    }
}
