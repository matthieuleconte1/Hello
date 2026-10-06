import Foundation

struct Glyph: Identifiable {
    let id: String
    let char: String
    let name: String
    let key: String
    let isEmoji: Bool

    var code: String {
        char.unicodeScalars.filter { $0.value != 0xFE0F }
            .map { String(format: "U+%04X", $0.value) }.joined(separator: " ")
    }

    func withID(_ newID: String) -> Glyph {
        Glyph(id: newID, char: char, name: name, key: key, isEmoji: isEmoji)
    }
}

enum GlyphFilter: CaseIterable {
    case all, emoji, symbols

    var title: String {
        switch self {
        case .all: "Tout"
        case .emoji: "Emoji"
        case .symbols: "Symboles"
        }
    }

    var next: GlyphFilter {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }
}

/// Emoji et caractères Unicode générés à partir des données Unicode du système
/// (noms officiels), construits une seule fois, paresseusement.
enum GlyphIndex {
    static let emoji: [Glyph] = buildEmoji()
    static let symbols: [Glyph] = buildSymbols()
    private static let byChar: [String: Glyph] =
        Dictionary((emoji + symbols).map { ($0.char, $0) }, uniquingKeysWith: { a, _ in a })

    static func warm() { _ = byChar.count }

    static func search(_ query: String, filter: GlyphFilter) -> [Glyph] {
        let pool: [Glyph]
        switch filter {
        case .all: pool = emoji + symbols
        case .emoji: pool = emoji
        case .symbols: pool = symbols
        }
        let q = Fuzzy.fold(query).trimmingCharacters(in: .whitespaces)
        if q.isEmpty {
            let recents = Recents.chars.compactMap { byChar[$0] }
                .filter { filter == .all || $0.isEmoji == (filter == .emoji) }
                .map { $0.withID("recent-" + $0.id) }
            return recents + pool
        }

        let tokens = q.split(separator: " ").map { token -> [String] in
            let t = String(token)
            return [t] + Aliases.expand(t)
        }
        var hits: [(rank: Int, index: Int, glyph: Glyph)] = []
        for (i, g) in pool.enumerated() {
            guard tokens.allSatisfy({ alternatives in alternatives.contains { g.key.contains($0) } }) else { continue }
            let rank = g.key.hasPrefix(q) ? 0 : (g.key.contains(" " + q) ? 1 : 2)
            hits.append((rank, i, g))
        }
        hits.sort { $0.rank != $1.rank ? $0.rank < $1.rank : $0.index < $1.index }
        var result = hits.map(\.glyph)

        // On a tapé/collé le caractère lui-même : on l'affiche en premier.
        let raw = query.trimmingCharacters(in: .whitespaces)
        if let exact = byChar[raw] ?? byChar[raw + "\u{FE0F}"], !result.contains(where: { $0.id == exact.id }) {
            result.insert(exact, at: 0)
        }
        return result
    }

    private static func displayName(_ name: String) -> String {
        let lower = name.lowercased()
        return lower.prefix(1).uppercased() + lower.dropFirst()
    }

    private static func hexCode(_ v: UInt32) -> String { String(format: "u+%04x", v) }

    private static func buildEmoji() -> [Glyph] {
        // Ordre choisi pour avoir les visages d'abord, puis gens, objets, nature, etc.
        let ranges: [ClosedRange<UInt32>] = [
            0x1F600...0x1F64F, 0x1F900...0x1F9FF, 0x1FAE0...0x1FAFF, 0x1F440...0x1F4FF, 0x1F300...0x1F43F,
            0x1FA70...0x1FADF, 0x1F500...0x1F5FF, 0x1F680...0x1F6FF, 0x2600...0x27BF, 0x2300...0x23FF,
            0x2B00...0x2BFF, 0x1F000...0x1F2FF, 0x2190...0x21FF, 0x25A0...0x25FF, 0x2934...0x2935,
            0x3030...0x303D, 0x3297...0x3299, 0x00A9...0x00AE, 0x203C...0x2049, 0x2122...0x2139,
        ]
        var seen = Set<UInt32>()
        var out: [Glyph] = []
        for range in ranges {
            for v in range {
                guard seen.insert(v).inserted, let scalar = Unicode.Scalar(v) else { continue }
                let p = scalar.properties
                guard p.isEmoji, !p.isEmojiModifier, !(0x1F1E6...0x1F1FF).contains(v),
                      let name = p.name else { continue }
                let char = p.isEmojiPresentation ? String(scalar) : String(scalar) + "\u{FE0F}"
                out.append(Glyph(id: "e\(v)", char: char, name: displayName(name),
                                 key: name.lowercased() + " " + hexCode(v), isEmoji: true))
            }
        }

        let sequences: [(String, String)] = [
            ("❤️‍🔥", "heart on fire"), ("❤️‍🩹", "mending heart"), ("😮‍💨", "face exhaling"),
            ("😵‍💫", "face with spiral eyes"), ("😶‍🌫️", "face in clouds"), ("🧑‍💻", "technologist"),
            ("👨‍💻", "man technologist"), ("👩‍💻", "woman technologist"), ("🧑‍🚀", "astronaut"),
            ("🧑‍🍳", "cook"), ("🧑‍🎨", "artist"), ("🧑‍🔬", "scientist"), ("🧑‍🎓", "student"),
            ("🐈‍⬛", "black cat"), ("🐻‍❄️", "polar bear"), ("🐦‍🔥", "phoenix"), ("🍋‍🟩", "lime"),
            ("🏳️‍🌈", "rainbow flag"), ("🏳️‍⚧️", "transgender flag"), ("🏴‍☠️", "pirate flag"),
            ("👁️‍🗨️", "eye in speech bubble"), ("🧑‍🤝‍🧑", "people holding hands"), ("👨‍👩‍👧", "family"),
            ("#️⃣", "keycap number sign"), ("*️⃣", "keycap asterisk"),
        ] + (0...9).map { ("\($0)\u{FE0F}\u{20E3}", "keycap \($0)") }
        for (i, (char, name)) in sequences.enumerated() {
            out.append(Glyph(id: "s\(i)", char: char, name: displayName(name), key: name, isEmoji: true))
        }

        let local = Locale.current
        let english = Locale(identifier: "en_US")
        for region in Locale.Region.isoRegions {
            let code = region.identifier
            guard code.count == 2, code.unicodeScalars.allSatisfy({ (65...90).contains($0.value) }),
                  let name = local.localizedString(forRegionCode: code) else { continue }
            let flag = code.unicodeScalars.compactMap { Unicode.Scalar(0x1F1E6 + $0.value - 65) }
                .map(String.init).joined()
            let en = english.localizedString(forRegionCode: code) ?? ""
            out.append(Glyph(id: "f" + code, char: flag, name: "Drapeau : " + name,
                             key: Fuzzy.fold("flag drapeau \(name) \(en) \(code)"), isEmoji: true))
        }
        return out
    }

    private static func buildSymbols() -> [Glyph] {
        let ranges: [ClosedRange<UInt32>] = [
            0x2318...0x2318, 0x2325...0x2325, 0x21E7...0x21E7, 0x2303...0x2303, 0x238B...0x238B,
            0x23CE...0x23CE, 0x232B...0x232B, 0x2326...0x2326, 0x21E5...0x21E5, 0x2190...0x21FF,
            0x27F0...0x27FF, 0x2900...0x297F, 0x2B00...0x2BFF, 0x2200...0x22FF, 0x2980...0x2AFF,
            0x2010...0x205E, 0x20A0...0x20C0, 0x00A1...0x00BF, 0x00C0...0x00FF, 0x0152...0x0153,
            0x0178...0x0178, 0x2100...0x214F, 0x2150...0x218B, 0x2070...0x209C, 0x0391...0x03C9,
            0x2460...0x24FF, 0x25A0...0x25FF, 0x2600...0x26FF, 0x2700...0x27BF, 0x2300...0x23FF,
            0x2500...0x259F,
        ]
        var seen = Set<UInt32>()
        var out = [Glyph(id: "apple", char: "\u{F8FF}", name: "Logo Apple", key: "apple logo pomme u+f8ff", isEmoji: false)]
        for range in ranges {
            for v in range {
                guard seen.insert(v).inserted, let scalar = Unicode.Scalar(v) else { continue }
                let p = scalar.properties
                guard let name = p.name, !p.isEmojiPresentation, !p.isWhitespace else { continue }
                switch p.generalCategory {
                case .control, .format, .nonspacingMark, .enclosingMark, .spacingMark, .unassigned,
                     .privateUse, .surrogate, .lineSeparator, .paragraphSeparator, .spaceSeparator:
                    continue
                default:
                    break
                }
                out.append(Glyph(id: "u\(v)", char: String(scalar), name: displayName(name),
                                 key: name.lowercased() + " " + hexCode(v), isEmoji: false))
            }
        }
        return out
    }
}

enum Recents {
    static private(set) var chars: [String] = UserDefaults.standard.stringArray(forKey: "recentGlyphs") ?? []

    static func add(_ char: String) {
        chars.removeAll { $0 == char }
        chars.insert(char, at: 0)
        if chars.count > 22 { chars.removeLast(chars.count - 22) }
        UserDefaults.standard.set(chars, forKey: "recentGlyphs")
    }

    static func clear() {
        chars = []
        UserDefaults.standard.set(chars, forKey: "recentGlyphs")
    }
}

/// Les noms Unicode sont en anglais : ces alias permettent de chercher en français.
enum Aliases {
    static func expand(_ token: String) -> [String] {
        guard token.count >= 2 else { return [] }
        return table.flatMap { key, values in
            (key == token || (token.count >= 3 && key.hasPrefix(token))) ? values : []
        }
    }

    private static let table: [String: [String]] = [
        "coeur": ["heart"], "amour": ["heart", "love", "kiss"], "rire": ["joy", "laugh", "grinning", "rolling"],
        "sourire": ["smil", "grin"], "triste": ["sad", "cry", "disappointed", "pensive"], "pleur": ["cry", "sob", "tear"],
        "larme": ["tear", "cry"], "colere": ["angry", "rage", "pouting"], "peur": ["fear", "scream"],
        "clin": ["wink"], "bisou": ["kiss"], "fatigue": ["tired", "sleep", "yawn"], "dormir": ["sleep", "zzz"],
        "reflechir": ["thinking"], "chaud": ["hot"], "froid": ["cold", "freezing"], "malade": ["sick", "mask", "nause"],
        "fou": ["zany", "crazy"], "choque": ["astonished", "shock", "open mouth"], "cool": ["sunglasses", "cool"],
        "feu": ["fire"], "pouce": ["thumbs"], "main": ["hand"], "merci": ["folded hands"], "prier": ["folded hands"],
        "applaudir": ["clapping"], "muscle": ["biceps"], "yeux": ["eyes"], "oeil": ["eye"], "cerveau": ["brain"],
        "crane": ["skull"], "fantome": ["ghost"], "caca": ["pile of poo"], "fete": ["party", "confetti", "balloon"],
        "cadeau": ["gift"], "gateau": ["cake"], "biere": ["beer"], "vin": ["wine"], "cafe": ["coffee", "hot beverage"],
        "the": ["teacup", "tea"], "pomme": ["apple"], "fraise": ["strawberry"], "banane": ["banana"],
        "chat": ["cat"], "chien": ["dog"], "cheval": ["horse"], "lapin": ["rabbit"], "ours": ["bear"],
        "singe": ["monkey"], "oiseau": ["bird"], "poisson": ["fish"], "cochon": ["pig"], "vache": ["cow"],
        "licorne": ["unicorn"], "serpent": ["snake"], "tortue": ["turtle"], "papillon": ["butterfly"],
        "soleil": ["sun"], "lune": ["moon"], "etoile": ["star"], "nuage": ["cloud"], "pluie": ["rain"],
        "neige": ["snow"], "eclair": ["lightning", "high voltage"], "arc-en-ciel": ["rainbow"], "arbre": ["tree"],
        "fleur": ["flower", "blossom", "rose", "tulip"], "plante": ["plant", "seedling"], "terre": ["earth", "globe"],
        "voiture": ["car", "automobile"], "avion": ["airplane"], "fusee": ["rocket"], "velo": ["bicycle"],
        "train": ["train"], "bateau": ["boat", "ship"], "maison": ["house"], "argent": ["money", "dollar"],
        "ordinateur": ["computer", "laptop"], "telephone": ["phone", "telephone"], "livre": ["book", "pound"],
        "crayon": ["pencil"], "stylo": ["pen"], "cle": ["key"], "cadenas": ["lock"], "coche": ["check mark"],
        "valider": ["check mark"], "croix": ["cross mark", "multiplication"], "attention": ["warning"],
        "interdit": ["prohibited", "no entry"], "musique": ["music", "musical"], "horloge": ["clock"],
        "trophee": ["trophy"], "medaille": ["medal"], "ballon": ["ball", "balloon"], "cible": ["direct hit", "target"],
        "idee": ["light bulb"], "ampoule": ["light bulb"], "bombe": ["bomb"], "poubelle": ["wastebasket"],
        "dossier": ["folder"], "calendrier": ["calendar"], "epingle": ["pushpin", "pin"], "loupe": ["magnifying"],
        "cloche": ["bell"], "drapeau": ["flag"], "fleche": ["arrow"], "haut": ["up"], "bas": ["down"],
        "gauche": ["left"], "droite": ["right"], "cent": ["hundred"], "degre": ["degree"], "infini": ["infinity"],
        "somme": ["summation"], "different": ["not equal"], "environ": ["almost equal"], "racine": ["square root"],
        "plus": ["plus"], "moins": ["minus"], "fois": ["multiplication"], "divise": ["division"],
        "puce": ["bullet"], "tiret": ["dash"], "guillemet": ["quotation"], "copyright": ["copyright"],
        "marque": ["trade mark", "registered"], "paragraphe": ["pilcrow", "section sign"], "points": ["ellipsis"],
        "commande": ["place of interest"], "cmd": ["place of interest"], "option": ["option key"],
        "shift": ["upwards white arrow"], "majuscule": ["capital", "upwards white arrow"], "minuscule": ["small"],
        "controle": ["up arrowhead"], "ctrl": ["up arrowhead"], "echap": ["broken circle with northwest arrow"],
        "escape": ["broken circle with northwest arrow"], "entree": ["return symbol"], "retour": ["return symbol"],
        "effacer": ["erase"], "tab": ["rightwards arrow to bar"], "accent": ["acute", "grave", "circumflex"],
        "aigu": ["acute"], "circonflexe": ["circumflex"], "trema": ["diaeresis"], "cedille": ["cedilla"],
        "ligature": ["ligature"], "euro": ["euro"], "carre": ["square"], "cercle": ["circle"], "triangle": ["triangle"],
        "etoiles": ["star"], "rouge": ["red"], "vert": ["green"], "bleu": ["blue"], "jaune": ["yellow"],
        "noir": ["black"], "blanc": ["white"], "violet": ["purple"], "orange": ["orange"],
    ]
}
