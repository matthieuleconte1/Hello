import Foundation

struct UsageRecord: Codable {
    var count = 0
    var first = Date()
    var last = Date()
    var recent: [Date] = []          // 60 dernières ouvertures
    var queries: [String: Int] = [:] // ce qui a été tapé avant de choisir l'élément (préfixes)
}

/// Mémoire d'utilisation "frécence" (fréquence × récence, à la Firefox) + apprentissage
/// de ce que tu tapes : si tu choisis Safari après avoir tapé « s », « s » finira par donner Safari.
enum Usage {
    private static let url = ClipboardHistory.dir.appendingPathComponent("usage.json")
    private static var saveScheduled = false
    private(set) static var records: [String: UsageRecord] = load()

    static func record(_ id: String, query: String) {
        var r = records[id] ?? UsageRecord()
        let now = Date()
        r.count += 1
        r.last = now
        r.recent.append(now)
        if r.recent.count > 60 { r.recent.removeFirst(r.recent.count - 60) }
        let q = Fuzzy.fold(query.trimmingCharacters(in: .whitespaces))
        if !q.isEmpty && AppSettings.shared.learnQueries {
            // On apprend chaque préfixe tapé : « saf » apprend aussi « s » et « sa ».
            for length in 1...min(q.count, 8) {
                r.queries[String(q.prefix(length)), default: 0] += 1
            }
        }
        records[id] = r
        scheduleSave()
    }

    /// Fréquence × récence : chaque ouverture récente pèse plus lourd qu'une ancienne.
    static func frecency(_ id: String) -> Double {
        guard let r = records[id], r.count > 0 else { return 0 }
        guard !r.recent.isEmpty else { return Double(r.count) * 10 }
        let now = Date()
        let weights = r.recent.map { date -> Double in
            let days = now.timeIntervalSince(date) / 86_400
            switch days {
            case ..<1: return 100
            case ..<4: return 80
            case ..<14: return 60
            case ..<31: return 40
            case ..<90: return 20
            default: return 10
            }
        }
        return Double(r.count) * weights.reduce(0, +) / Double(weights.count)
    }

    /// Bonus ajouté au score de correspondance (qui va de ~1 à 1000).
    static func boost(_ id: String, query: String) -> Int {
        boost(id, folded: Fuzzy.fold(query.trimmingCharacters(in: .whitespaces)))
    }

    /// Même chose avec une requête déjà normalisée (évite de la replier pour chaque app à chaque frappe).
    static func boost(_ id: String, folded q: String) -> Int {
        let settings = AppSettings.shared
        let f = settings.frecencyRanking ? frecency(id) : 0
        var bonus = f > 0 ? min(250, Int(60 * log2(1 + f / 40))) : 0
        if settings.learnQueries, let learned = records[id]?.queries[q], learned > 0 {
            bonus += min(450, 150 + learned * 60)
        }
        return bonus
    }

    static func top(_ n: Int) -> [String] {
        // Score calculé une fois par élément (et pas deux fois par comparaison du tri).
        records.keys.map { ($0, frecency($0)) }.sorted { $0.1 > $1.1 }.prefix(n).map(\.0)
    }

    static func launches(_ id: String, inLast days: Double) -> Int {
        let limit = Date().addingTimeInterval(-days * 86_400)
        return records[id]?.recent.filter { $0 > limit }.count ?? 0
    }

    /// Ouvertures par jour sur les `days` derniers jours (le plus ancien d'abord).
    static func daily(_ id: String, days: Int) -> [Int] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var buckets = Array(repeating: 0, count: days)
        for date in records[id]?.recent ?? [] {
            let diff = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: today).day ?? days
            if diff >= 0 && diff < days { buckets[days - 1 - diff] += 1 }
        }
        return buckets
    }

    /// Les requêtes courtes les plus utilisées pour un élément (ex. « s », « sa »).
    static func shortcuts(_ id: String, limit: Int = 3) -> [String] {
        guard let queries = records[id]?.queries else { return [] }
        return queries.filter { $0.key.count <= 4 }
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key.count < $1.key.count }
            .prefix(limit).map(\.key)
    }

    static func forget(_ id: String) {
        records[id] = nil
        scheduleSave()
    }

    static func reset() {
        records = [:]
        scheduleSave()
    }

    private static func load() -> [String: UsageRecord] {
        if let data = try? Data(contentsOf: url),
           let saved = try? JSONDecoder().decode([String: UsageRecord].self, from: data) {
            return saved
        }
        // Migration de l'ancien simple compteur.
        let old = UserDefaults.standard.dictionary(forKey: "usage") as? [String: Int] ?? [:]
        return old.mapValues { UsageRecord(count: $0) }
    }

    private static func scheduleSave() {
        guard !saveScheduled else { return }
        saveScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            saveScheduled = false
            let snapshot = records
            DispatchQueue.global(qos: .utility).async {
                if let data = try? JSONEncoder().encode(snapshot) { try? data.write(to: url, options: .atomic) }
            }
        }
    }
}
