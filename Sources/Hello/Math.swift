import AppKit
import CoreText

/// LaTeX des réponses de l'IA, composé sur place, sans dépendance : un sous-ensemble courant (fractions, racines,
/// exposants et indices, sommes et intégrales, matrices, `cases`, `aligned`, accents, lettres grecques, ℝ 𝒜 𝐀…)
/// mis en boîtes comme le fait TeX — une largeur, une hauteur au-dessus de la ligne de base, une profondeur en
/// dessous — puis dessiné en STIX Two Math, la police mathématique du Mac. Image gabarit : elle prend l'encre du style.
indirect enum MathNode {
    /// Caractères d'une même classe (lettre, chiffre, opérateur, relation…), en police mathématique.
    case atom(String, MathClass)
    /// Texte droit (`\text`), en police de texte.
    case text(String)
    /// Espace, en em.
    case space(CGFloat)
    case row([MathNode])
    case frac(MathNode, MathNode, bar: Bool)
    case root(MathNode, index: MathNode?)
    case scripts(MathNode, sup: MathNode?, sub: MathNode?)
    /// Grand opérateur (∑, ∫) ou nom de fonction (sin, lim) ; `limits` : bornes dessus et dessous en display.
    case op(String, symbol: Bool, limits: Bool)
    case fenced(String, MathNode, String)
    case accent(MathNode, String)
    case table([[MathNode]], align: [MathAlign], left: String, right: String, columnGap: CGFloat)

    /// Classe TeX, pour les espaces autour des opérateurs et des relations ; nil : transparent (espace).
    var mathClass: MathClass? {
        switch self {
        case .atom(_, let cls): cls
        case .space: nil
        case .op: .op
        case .scripts(let base, _, _): base.mathClass ?? .ord
        default: .ord
        }
    }
}

enum MathClass { case ord, op, bin, rel, open, close, punct }
enum MathAlign { case left, center, right }

// MARK: - Lecture

struct MathParser {
    private enum Token: Equatable {
        case command(String), char(Character), open, close, sup, sub, amp
    }

    /// Alphabet des lettres en cours (`\mathbb{R}`, `\mathbf{x}`…).
    private enum Alphabet { case italic, roman, bold, boldItalic, blackboard, script, fraktur, sans }

    private let chars: [Character]
    private var i = 0
    private var alphabet = Alphabet.italic

    static func parse(_ latex: String) -> MathNode {
        var parser = MathParser(chars: Array(latex))
        var nodes = parser.row()
        // Accolade fermante en trop : ignorée.
        while parser.peek() == .close {
            _ = parser.next()
            nodes += parser.row()
        }
        guard parser.peek() != nil else { return .row(nodes) }
        // Plusieurs lignes (`\\`) ou des colonnes (`&`) hors environnement : alignées comme dans `aligned`.
        parser.i = 0
        return parser.environment("aligned")
    }

    private init(chars: [Character]) { self.chars = chars }

    // MARK: Jetons

    private mutating func skipSpaces() {
        while i < chars.count, chars[i].isWhitespace { i += 1 }
    }

    private mutating func next() -> Token? {
        skipSpaces()
        guard i < chars.count else { return nil }
        let c = chars[i]
        i += 1
        switch c {
        case "\\":
            guard i < chars.count else { return .char("\\") }
            if chars[i].isASCII, chars[i].isLetter {
                var name = ""
                while i < chars.count, chars[i].isASCII, chars[i].isLetter { name.append(chars[i]); i += 1 }
                // `\operatorname*`, `\begin{align*}` : l'étoile fait partie de la commande.
                if i < chars.count, chars[i] == "*", name == "operatorname" { name.append("*"); i += 1 }
                return .command(name)
            }
            let symbol = chars[i]
            i += 1
            return .command(String(symbol))
        case "{": return .open
        case "}": return .close
        case "^": return .sup
        case "_": return .sub
        case "&": return .amp
        default: return .char(c)
        }
    }

    private mutating func peek() -> Token? {
        let saved = i
        defer { i = saved }
        return next()
    }

    /// Contenu brut entre accolades (`\text{…}`, `\begin{…}`), espaces compris.
    private mutating func rawGroup() -> String {
        skipSpaces()
        guard i < chars.count, chars[i] == "{" else { return "" }
        i += 1
        var depth = 1
        var out = ""
        while i < chars.count {
            let c = chars[i]
            i += 1
            if c == "\\", i < chars.count, "{}$%&_#".contains(chars[i]) { out.append(chars[i]); i += 1; continue }
            if c == "{" { depth += 1 } else if c == "}" { depth -= 1; if depth == 0 { break } }
            out.append(c)
        }
        return out
    }

    /// Argument optionnel entre crochets (`\sqrt[3]{x}`).
    private mutating func optionalArgument() -> String? {
        skipSpaces()
        guard i < chars.count, chars[i] == "[" else { return nil }
        i += 1
        var out = ""
        while i < chars.count, chars[i] != "]" { out.append(chars[i]); i += 1 }
        i += 1
        return out
    }

    // MARK: Lignes et atomes

    private func stops(_ token: Token) -> Bool {
        switch token {
        case .close, .amp: true
        case .command(let name): name == "\\" || name == "right" || name == "end"
        default: false
        }
    }

    /// Une suite d'atomes, jusqu'à une fin de groupe, une cellule, `\right` ou `\end`.
    private mutating func row() -> [MathNode] {
        var nodes: [MathNode] = []
        while let token = peek(), !stops(token) {
            _ = next()
            switch token {
            case .sup, .sub:
                let argument = argument()
                let base = nodes.popLast() ?? .atom("", .ord)
                if case .scripts(let inner, var sup, var sub) = base {
                    if token == .sup { sup = argument } else { sub = argument }
                    nodes.append(.scripts(inner, sup: sup, sub: sub))
                } else {
                    nodes.append(.scripts(base, sup: token == .sup ? argument : nil, sub: token == .sub ? argument : nil))
                }
            default:
                if let node = atom(token) { nodes.append(node) }
            }
        }
        // Fin du texte sans `}` fermante : le groupe ouvert est simplement refermé.
        return nodes
    }

    /// Argument d'une commande ou d'un exposant : un groupe ou un seul atome.
    private mutating func argument() -> MathNode {
        guard let token = next() else { return .row([]) }
        return atom(token) ?? .row([])
    }

    private mutating func group() -> MathNode {
        let nodes = row()
        if peek() == .close { _ = next() }
        return nodes.count == 1 ? nodes[0] : .row(nodes)
    }

    private mutating func styled(_ alphabet: Alphabet) -> MathNode {
        let saved = self.alphabet
        self.alphabet = alphabet
        defer { self.alphabet = saved }
        return argument()
    }

    private mutating func atom(_ token: Token) -> MathNode? {
        switch token {
        case .open: return group()
        case .close, .amp, .sup, .sub: return nil
        case .char(let c): return character(c)
        case .command(let name): return command(name)
        }
    }

    private func character(_ c: Character) -> MathNode? {
        if c.isLetter { return .atom(letter(c), .ord) }
        if c.isNumber { return .atom(alphabet == .bold ? Self.shift(c, upper: nil, lower: nil, digit: 0x1D7CE) : String(c), .ord) }
        switch c {
        case "+": return .atom("+", .bin)
        case "-": return .atom("−", .bin)
        case "*": return .atom("∗", .bin)
        case "=", "<", ">": return .atom(String(c), .rel)
        case ":": return .atom(":", .rel)
        case ",", ";": return .atom(String(c), .punct)
        case "(", "[": return .atom(String(c), .open)
        case ")", "]", "!", "?": return .atom(String(c), .close)
        case "'": return .atom("′", .ord)
        case "~": return .space(0.33)
        default: return .atom(String(c), .ord)
        }
    }

    private func letter(_ c: Character) -> String {
        switch alphabet {
        case .roman: return String(c)
        case .italic:
            if c == "h" { return "ℎ" }
            return Self.shift(c, upper: 0x1D434, lower: 0x1D44E)
        case .bold: return Self.shift(c, upper: 0x1D400, lower: 0x1D41A)
        case .boldItalic: return Self.shift(c, upper: 0x1D468, lower: 0x1D482)
        case .sans: return Self.shift(c, upper: 0x1D5A0, lower: 0x1D5BA)
        case .blackboard:
            let special: [Character: String] = ["C": "ℂ", "H": "ℍ", "N": "ℕ", "P": "ℙ", "Q": "ℚ", "R": "ℝ", "Z": "ℤ"]
            return special[c] ?? Self.shift(c, upper: 0x1D538, lower: 0x1D552)
        case .script:
            let special: [Character: String] = ["B": "ℬ", "E": "ℰ", "F": "ℱ", "H": "ℋ", "I": "ℐ", "L": "ℒ", "M": "ℳ",
                                                "R": "ℛ", "e": "ℯ", "g": "ℊ", "o": "ℴ"]
            return special[c] ?? Self.shift(c, upper: 0x1D49C, lower: 0x1D4B6)
        case .fraktur:
            let special: [Character: String] = ["C": "ℭ", "H": "ℌ", "I": "ℑ", "R": "ℜ", "Z": "ℨ"]
            return special[c] ?? Self.shift(c, upper: 0x1D504, lower: 0x1D51E)
        }
    }

    /// Lettre (ou chiffre) latine dans un alphabet mathématique Unicode ; inchangée sinon.
    private static func shift(_ c: Character, upper: UInt32?, lower: UInt32?, digit: UInt32? = nil) -> String {
        guard let ascii = c.asciiValue else { return String(c) }
        let base: UInt32?
        let offset: UInt32
        switch ascii {
        case 65...90: (base, offset) = (upper, UInt32(ascii - 65))
        case 97...122: (base, offset) = (lower, UInt32(ascii - 97))
        case 48...57: (base, offset) = (digit, UInt32(ascii - 48))
        default: return String(c)
        }
        guard let base, let scalar = Unicode.Scalar(base + offset) else { return String(c) }
        return String(Character(scalar))
    }

    // MARK: Commandes

    private mutating func command(_ name: String) -> MathNode? {
        if let (symbol, cls) = MathSymbols.table[name] { return .atom(symbol, cls) }
        if let greek = MathSymbols.greek[name] { return .atom(alphabet == .italic ? MathSymbols.italicGreek(greek) : greek, .ord) }
        if let symbol = MathSymbols.bigOperators[name] { return .op(symbol, symbol: true, limits: !symbol.hasPrefix("∫") && !"∬∭∮".contains(symbol)) }
        if MathSymbols.functions.contains(name) { return .op(name, symbol: false, limits: MathSymbols.limitFunctions.contains(name)) }
        if let space = MathSymbols.spaces[name] { return .space(space) }
        switch name {
        case "frac", "dfrac", "tfrac", "cfrac":
            let numerator = argument()
            return .frac(numerator, argument(), bar: true)
        case "binom", "dbinom", "tbinom":
            let top = argument()
            return .fenced("(", .frac(top, argument(), bar: false), ")")
        case "sqrt":
            let index = optionalArgument().map { MathParser.parse($0) }
            return .root(argument(), index: index)
        case "left":
            let open = delimiter()
            let inner = row()
            if peek() == .command("right") { _ = next() }
            return .fenced(open, .row(inner), delimiter())
        case "right": return nil
        case "middle", "big", "Big", "bigg", "Bigg", "bigl", "bigr", "Bigl", "Bigr", "biggl", "biggr":
            let d = delimiter()
            return .atom(d, name.hasSuffix("l") ? .open : name.hasSuffix("r") ? .close : .ord)
        case "begin": return environment(rawGroup())
        case "text", "textrm", "textup", "mbox", "hbox", "textnormal", "textit", "textbf", "textsf", "texttt":
            return .text(rawGroup())
        case "operatorname": return .op(rawGroup(), symbol: false, limits: false)
        case "operatorname*": return .op(rawGroup(), symbol: false, limits: true)
        case "mathrm", "rm", "mathup": return styled(.roman)
        case "mathit": return styled(.italic)
        case "mathbf", "bf", "bold": return styled(.bold)
        case "boldsymbol", "bm": return styled(.boldItalic)
        case "mathbb", "Bbb": return styled(.blackboard)
        case "mathcal", "mathscr": return styled(.script)
        case "mathfrak": return styled(.fraktur)
        case "mathsf": return styled(.sans)
        case "hat", "widehat", "bar", "overline", "vec", "overrightarrow", "tilde", "widetilde", "dot", "ddot",
             "underline", "check", "breve", "acute", "grave":
            return .accent(argument(), name)
        case "not":
            guard let token = next(), let node = atom(token) else { return .atom("/", .ord) }
            if case .atom(let s, let cls) = node { return .atom(s + "\u{0338}", cls) }
            return node
        case "color":
            _ = rawGroup()
            return nil
        case "textcolor", "colorbox":
            _ = rawGroup()
            return argument()
        case "label", "tag":
            _ = rawGroup()
            return nil
        case "displaystyle", "textstyle", "scriptstyle", "limits", "nolimits", "nonumber", "notag":
            return nil
        case "overbrace", "underbrace", "boxed", "phantom", "mathop", "mathrel", "mathbin", "mathord":
            return argument()
        case "{", "}", "%", "$", "#", "&", "_":
            return .atom(name, name == "{" ? .open : name == "}" ? .close : .ord)
        case "|": return .atom("‖", .ord)
        case "\\": return nil
        default:
            return .text("\\" + name)
        }
    }

    /// Délimiteur après `\left`, `\right`, `\big`… : un caractère ou une commande ; « . » : aucun.
    private mutating func delimiter() -> String {
        guard let token = next() else { return "" }
        switch token {
        case .char("."): return ""
        case .char("<"): return "⟨"
        case .char(">"): return "⟩"
        case .char(let c): return String(c)
        case .command(let name):
            let names = ["{": "{", "}": "}", "|": "‖", "lbrace": "{", "rbrace": "}", "langle": "⟨", "rangle": "⟩",
                         "vert": "|", "lvert": "|", "rvert": "|", "Vert": "‖", "lVert": "‖", "rVert": "‖",
                         "lfloor": "⌊", "rfloor": "⌋", "lceil": "⌈", "rceil": "⌉", "lbrack": "[", "rbrack": "]"]
            return names[name] ?? ""
        default: return ""
        }
    }

    fileprivate mutating func environment(_ name: String) -> MathNode {
        let env = name.replacingOccurrences(of: "*", with: "")
        var columns: [MathAlign]?
        if env == "array" {
            columns = rawGroup().compactMap { ["l": .left, "c": .center, "r": .right][$0] }
        } else if env == "alignat" {
            _ = rawGroup()
        }
        var rows: [[MathNode]] = [[]]
        loop: while true {
            let cell = row()
            rows[rows.count - 1].append(cell.count == 1 ? cell[0] : .row(cell))
            guard let token = next() else { break }
            switch token {
            case .amp: continue
            case .command("\\"):
                _ = optionalArgument()
                rows.append([])
            case .command("end"):
                _ = rawGroup()
                break loop
            default: break loop
            }
        }
        // `\\` final : pas de ligne vide en bas.
        if rows.count > 1, let last = rows.last, last.count == 1, case .row(let nodes) = last[0], nodes.isEmpty { rows.removeLast() }
        let count = rows.map(\.count).max() ?? 1
        switch env {
        case "equation", "displaymath", "math":
            return rows.first?.first ?? .row([])
        case "aligned", "align", "alignat", "split", "eqnarray", "flalign":
            let align: [MathAlign] = count == 1 ? [.center] : (0..<count).map { $0.isMultiple(of: 2) ? .right : .left }
            return .table(rows, align: align, left: "", right: "", columnGap: 0)
        case "gathered", "gather", "multline":
            return .table(rows, align: [.center], left: "", right: "", columnGap: 0)
        case "cases", "dcases":
            return .table(rows, align: [.left, .left], left: "{", right: "", columnGap: 1)
        case "rcases":
            return .table(rows, align: [.left, .left], left: "", right: "}", columnGap: 1)
        default:
            let fences: [String: (String, String)] = ["pmatrix": ("(", ")"), "bmatrix": ("[", "]"), "Bmatrix": ("{", "}"),
                                                       "vmatrix": ("|", "|"), "Vmatrix": ("‖", "‖")]
            let (left, right) = fences[env] ?? ("", "")
            return .table(rows, align: columns ?? [.center], left: left, right: right, columnGap: 0.9)
        }
    }
}

enum MathSymbols {
    static let greek: [String: String] = [
        "alpha": "α", "beta": "β", "gamma": "γ", "delta": "δ", "epsilon": "ϵ", "varepsilon": "ε", "zeta": "ζ",
        "eta": "η", "theta": "θ", "vartheta": "ϑ", "iota": "ι", "kappa": "κ", "varkappa": "ϰ", "lambda": "λ",
        "mu": "μ", "nu": "ν", "xi": "ξ", "omicron": "ο", "pi": "π", "varpi": "ϖ", "rho": "ρ", "varrho": "ϱ",
        "sigma": "σ", "varsigma": "ς", "tau": "τ", "upsilon": "υ", "phi": "ϕ", "varphi": "φ", "chi": "χ",
        "psi": "ψ", "omega": "ω",
        "Gamma": "Γ", "Delta": "Δ", "Theta": "Θ", "Lambda": "Λ", "Xi": "Ξ", "Pi": "Π", "Sigma": "Σ",
        "Upsilon": "Υ", "Phi": "Φ", "Psi": "Ψ", "Omega": "Ω",
    ]

    /// Minuscules grecques en italique mathématique, comme TeX (les capitales restent droites).
    static func italicGreek(_ s: String) -> String {
        let order = Array("αβγδεζηθικλμνξοπρςστυφχψω")
        let variants: [Character: UInt32] = ["ϵ": 0x1D716, "ϑ": 0x1D717, "ϰ": 0x1D718, "ϕ": 0x1D719, "ϱ": 0x1D71A, "ϖ": 0x1D71B]
        guard let c = s.first else { return s }
        if let index = order.firstIndex(of: c), let scalar = Unicode.Scalar(0x1D6FC + UInt32(index)) { return String(Character(scalar)) }
        if let code = variants[c], let scalar = Unicode.Scalar(code) { return String(Character(scalar)) }
        return s
    }

    static let table: [String: (String, MathClass)] = [
        // Opérations
        "pm": ("±", .bin), "mp": ("∓", .bin), "times": ("×", .bin), "div": ("÷", .bin), "cdot": ("⋅", .bin),
        "ast": ("∗", .bin), "star": ("⋆", .bin), "circ": ("∘", .bin), "bullet": ("∙", .bin), "oplus": ("⊕", .bin),
        "ominus": ("⊖", .bin), "otimes": ("⊗", .bin), "odot": ("⊙", .bin), "cup": ("∪", .bin), "cap": ("∩", .bin),
        "setminus": ("∖", .bin), "wedge": ("∧", .bin), "land": ("∧", .bin), "vee": ("∨", .bin), "lor": ("∨", .bin),
        "sqcup": ("⊔", .bin), "sqcap": ("⊓", .bin), "dagger": ("†", .bin), "amalg": ("⨿", .bin),
        // Relations
        "leq": ("≤", .rel), "le": ("≤", .rel), "geq": ("≥", .rel), "ge": ("≥", .rel), "neq": ("≠", .rel),
        "ne": ("≠", .rel), "approx": ("≈", .rel), "equiv": ("≡", .rel), "sim": ("∼", .rel), "simeq": ("≃", .rel),
        "cong": ("≅", .rel), "propto": ("∝", .rel), "ll": ("≪", .rel), "gg": ("≫", .rel), "leqslant": ("⩽", .rel),
        "geqslant": ("⩾", .rel), "prec": ("≺", .rel), "succ": ("≻", .rel), "preceq": ("⪯", .rel), "succeq": ("⪰", .rel),
        "in": ("∈", .rel), "notin": ("∉", .rel), "ni": ("∋", .rel), "subset": ("⊂", .rel), "supset": ("⊃", .rel),
        "subseteq": ("⊆", .rel), "supseteq": ("⊇", .rel), "subsetneq": ("⊊", .rel), "perp": ("⊥", .rel),
        "parallel": ("∥", .rel), "mid": ("∣", .rel), "nmid": ("∤", .rel), "models": ("⊨", .rel), "vdash": ("⊢", .rel),
        "coloneqq": ("≔", .rel), "doteq": ("≐", .rel), "asymp": ("≍", .rel),
        "to": ("→", .rel), "rightarrow": ("→", .rel), "leftarrow": ("←", .rel), "gets": ("←", .rel),
        "leftrightarrow": ("↔", .rel), "Rightarrow": ("⇒", .rel), "Leftarrow": ("⇐", .rel), "Leftrightarrow": ("⇔", .rel),
        "implies": ("⟹", .rel), "impliedby": ("⟸", .rel), "iff": ("⟺", .rel), "mapsto": ("↦", .rel),
        "longrightarrow": ("⟶", .rel), "longleftarrow": ("⟵", .rel), "longmapsto": ("⟼", .rel),
        "Longrightarrow": ("⟹", .rel), "Longleftrightarrow": ("⟺", .rel), "uparrow": ("↑", .rel),
        "downarrow": ("↓", .rel), "nearrow": ("↗", .rel), "searrow": ("↘", .rel), "hookrightarrow": ("↪", .rel),
        "rightleftharpoons": ("⇌", .rel), "xrightarrow": ("⟶", .rel),
        // Symboles
        "infty": ("∞", .ord), "partial": ("∂", .ord), "nabla": ("∇", .ord), "forall": ("∀", .ord),
        "exists": ("∃", .ord), "nexists": ("∄", .ord), "emptyset": ("∅", .ord), "varnothing": ("∅", .ord),
        "neg": ("¬", .ord), "lnot": ("¬", .ord), "angle": ("∠", .ord), "triangle": ("△", .ord), "hbar": ("ℏ", .ord),
        "ell": ("ℓ", .ord), "Re": ("ℜ", .ord), "Im": ("ℑ", .ord), "aleph": ("ℵ", .ord), "wp": ("℘", .ord),
        "prime": ("′", .ord), "degree": ("°", .ord), "dots": ("…", .ord), "ldots": ("…", .ord), "cdots": ("⋯", .ord),
        "vdots": ("⋮", .ord), "ddots": ("⋱", .ord), "therefore": ("∴", .rel), "because": ("∵", .rel),
        "top": ("⊤", .ord), "bot": ("⊥", .ord), "square": ("□", .ord), "Box": ("□", .ord), "checkmark": ("✓", .ord),
        "clubsuit": ("♣", .ord), "heartsuit": ("♡", .ord), "spadesuit": ("♠", .ord), "diamondsuit": ("♢", .ord),
        "imath": ("𝚤", .ord), "jmath": ("𝚥", .ord), "dag": ("†", .ord), "S": ("§", .ord), "P": ("¶", .ord),
        "langle": ("⟨", .open), "rangle": ("⟩", .close), "lfloor": ("⌊", .open), "rfloor": ("⌋", .close),
        "lceil": ("⌈", .open), "rceil": ("⌉", .close), "lbrace": ("{", .open), "rbrace": ("}", .close),
        "vert": ("|", .ord), "lvert": ("|", .open), "rvert": ("|", .close), "Vert": ("‖", .ord),
        "colon": (":", .punct), "backslash": ("∖", .ord),
    ]

    static let bigOperators: [String: String] = [
        "sum": "∑", "prod": "∏", "coprod": "∐", "int": "∫", "iint": "∬", "iiint": "∭", "oint": "∮",
        "bigcup": "⋃", "bigcap": "⋂", "bigoplus": "⨁", "bigotimes": "⨂", "bigodot": "⨀", "bigvee": "⋁",
        "bigwedge": "⋀", "bigsqcup": "⨆",
    ]

    static let functions: Set<String> = [
        "sin", "cos", "tan", "cot", "sec", "csc", "arcsin", "arccos", "arctan", "sinh", "cosh", "tanh", "coth",
        "log", "ln", "lg", "exp", "det", "dim", "ker", "deg", "gcd", "arg", "min", "max", "sup", "inf", "lim",
        "liminf", "limsup", "Pr", "hom", "mod", "bmod", "tr", "rank", "sgn", "argmax", "argmin",
    ]
    static let limitFunctions: Set<String> = ["lim", "liminf", "limsup", "max", "min", "sup", "inf", "det", "gcd", "Pr",
                                               "argmax", "argmin"]

    static let spaces: [String: CGFloat] = [
        ",": 3 / 18, "thinspace": 3 / 18, ":": 4 / 18, ">": 4 / 18, "medspace": 4 / 18, ";": 5 / 18,
        "thickspace": 5 / 18, "!": -3 / 18, "negthinspace": -3 / 18, " ": 0.25, "enspace": 0.5, "quad": 1, "qquad": 2,
    ]
}

// MARK: - Composition

/// Une boîte à la TeX : dessinée à partir de son origine, sur la ligne de base (repère CoreGraphics, y vers le haut).
struct MathBox {
    var width: CGFloat
    var ascent: CGFloat
    var descent: CGFloat
    var draw: (CGContext, CGPoint) -> Void

    static let empty = MathBox(width: 0, ascent: 0, descent: 0) { _, _ in }

    /// Boîtes posées les unes par rapport aux autres (décalage horizontal, hauteur de la ligne de base).
    static func place(_ parts: [(MathBox, CGFloat, CGFloat)], width: CGFloat) -> MathBox {
        let ascent = parts.map { $0.0.ascent + $0.2 }.max() ?? 0
        let descent = parts.map { $0.0.descent - $0.2 }.max() ?? 0
        return MathBox(width: width, ascent: max(ascent, 0), descent: max(descent, 0)) { context, origin in
            for (box, dx, dy) in parts { box.draw(context, CGPoint(x: origin.x + dx, y: origin.y + dy)) }
        }
    }
}

struct MathStyle {
    var size: CGFloat
    var base: CGFloat
    var display: Bool
    /// Indices et exposants : ni espace moyen, ni espace large (comme TeX).
    var script = false

    /// Axe mathématique (barre de fraction, centre des délimiteurs), et épaisseur des filets (STIX Two Math).
    var axis: CGFloat { size * 0.258 }
    var rule: CGFloat { max(size * 0.066, 0.7) }

    var scriptStyle: MathStyle {
        MathStyle(size: max(size * 0.7, base * 0.5), base: base, display: false, script: true)
    }

    var fractionStyle: MathStyle {
        display ? MathStyle(size: size, base: base, display: false, script: script)
            : MathStyle(size: max(size * 0.8, base * 0.5), base: base, display: false, script: script)
    }

    var textStyle: MathStyle { MathStyle(size: size, base: base, display: false, script: script) }
}

enum MathLayout {
    private static var fonts: [String: CTFont] = [:]

    static func font(_ name: String, _ size: CGFloat) -> CTFont {
        let key = "\(name)|\(size)"
        if let font = fonts[key] { return font }
        let font = CTFontCreateWithName(name as CFString, size, nil)
        fonts[key] = font
        return font
    }

    static func mathFont(_ size: CGFloat) -> CTFont { font("STIXTwoMath-Regular", size) }
    static func textFont(_ size: CGFloat) -> CTFont { font("STIXTwoText", size) }

    static func glyph(_ string: String, _ font: CTFont) -> MathBox {
        guard !string.isEmpty else { return .empty }
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0, alpha: 1),
        ]))
        let width = CTLineGetTypographicBounds(line, nil, nil, nil)
        let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        let xHeight = CTFontGetXHeight(font)
        let ascent = bounds.isNull ? xHeight : max(bounds.maxY, xHeight)
        let descent = bounds.isNull ? 0 : max(-bounds.minY, 0)
        return MathBox(width: width, ascent: ascent, descent: descent) { context, origin in
            context.textMatrix = .identity
            context.textPosition = origin
            CTLineDraw(line, context)
        }
    }

    /// Glyphe centré sur l'axe (grands opérateurs).
    private static func centered(_ string: String, _ font: CTFont, axis: CGFloat) -> MathBox {
        var box = glyph(string, font)
        let shift = axis - (box.ascent - box.descent) / 2
        let draw = box.draw
        box.ascent += shift
        box.descent -= shift
        box.draw = { context, origin in draw(context, CGPoint(x: origin.x, y: origin.y + shift)) }
        return box
    }

    static func layout(_ node: MathNode, _ style: MathStyle) -> MathBox {
        switch node {
        case .atom(let string, _):
            return glyph(string, mathFont(style.size))
        case .text(let string):
            return glyph(string, textFont(style.size))
        case .space(let em):
            return MathBox(width: em * style.size, ascent: 0, descent: 0) { _, _ in }
        case .row(let nodes):
            return row(nodes, style)
        case .frac(let numerator, let denominator, let bar):
            return fraction(numerator, denominator, bar: bar, style)
        case .root(let radicand, let index):
            return root(radicand, index: index, style)
        case .scripts(let base, let sup, let sub):
            return scripts(base, sup: sup, sub: sub, style)
        case .op(let name, let symbol, _):
            if symbol {
                let integral = "∫∬∭∮".contains(name)
                let scale: CGFloat = style.display ? (integral ? 1.75 : 1.45) : (integral ? 1.25 : 1.1)
                return centered(name, mathFont(style.size * scale), axis: style.axis)
            }
            return glyph(name, textFont(style.size))
        case .fenced(let left, let inner, let right):
            let content = layout(inner, style)
            let open = delimiter(left, around: content, style)
            let close = delimiter(right, around: content, style)
            let gap = style.size * 0.04
            return MathBox.place([(open, 0, 0), (content, open.width + gap, 0), (close, open.width + gap * 2 + content.width, 0)],
                                 width: open.width + content.width + close.width + gap * 2)
        case .accent(let base, let kind):
            return accent(base, kind, style)
        case .table(let rows, let align, let left, let right, let gap):
            return table(rows, align: align, left: left, right: right, columnGap: gap, style)
        }
    }

    // MARK: Ligne

    /// Espaces de TeX entre classes, en dix-huitièmes d'em ; négatif : seulement hors indices et exposants.
    private static func spacing(_ left: MathClass, _ right: MathClass) -> CGFloat {
        switch (left, right) {
        case (.ord, .op), (.op, .ord), (.op, .op), (.close, .op): 3
        case (.bin, _), (_, .bin): -4
        case (.rel, .rel), (.open, .rel), (.rel, .close), (.rel, .punct): 0
        case (.rel, _), (_, .rel): -5
        case (.punct, _): -3
        default: 0
        }
    }

    /// `afterOrd` : la ligne continue une cellule précédente (colonne de droite d'un `aligned`, qui commence par « = »).
    static func row(_ nodes: [MathNode], _ style: MathStyle, afterOrd: Bool = false) -> MathBox {
        // Classes effectives : un « − » en tête ou après une relation est un signe (ord), pas une soustraction.
        var classes: [MathClass?] = []
        var previous: MathClass? = afterOrd ? .ord : nil
        for node in nodes {
            guard var cls = node.mathClass else { classes.append(nil); continue }
            if cls == .bin, previous == nil || [.bin, .op, .rel, .open, .punct].contains(previous!) { cls = .ord }
            classes.append(cls)
            previous = cls
        }
        if let last = classes.lastIndex(where: { $0 != nil }), classes[last] == .bin { classes[last] = .ord }

        var parts: [(MathBox, CGFloat, CGFloat)] = []
        var x: CGFloat = 0
        previous = afterOrd ? .ord : nil
        for (node, cls) in zip(nodes, classes) {
            if let cls, let previous {
                let gap = spacing(previous, cls)
                if gap > 0 || !style.script { x += abs(gap) / 18 * style.size }
            }
            let box = layout(node, style)
            parts.append((box, x, 0))
            x += box.width
            if let cls { previous = cls }
        }
        return MathBox.place(parts, width: x)
    }

    // MARK: Fractions, racines, indices

    private static func fraction(_ numerator: MathNode, _ denominator: MathNode, bar: Bool, _ style: MathStyle) -> MathBox {
        let inner = style.fractionStyle
        let top = layout(numerator, inner)
        let bottom = layout(denominator, inner)
        let rule = bar ? style.rule : 0
        let gap = style.size * (style.display ? 0.16 : 0.11) + (bar ? 0 : style.size * 0.1)
        let pad = style.size * 0.12
        let width = max(top.width, bottom.width) + pad * 2
        let up = style.axis + rule / 2 + gap + top.descent
        let down = rule / 2 + gap + bottom.ascent - style.axis
        let barBox = MathBox(width: width, ascent: 0, descent: 0) { context, origin in
            guard bar else { return }
            context.fill(CGRect(x: origin.x + pad * 0.5, y: origin.y + style.axis - rule / 2, width: width - pad, height: rule))
        }
        return MathBox.place([(top, (width - top.width) / 2, up), (barBox, 0, 0), (bottom, (width - bottom.width) / 2, -down)],
                             width: width)
    }

    private static func root(_ radicand: MathNode, index: MathNode?, _ style: MathStyle) -> MathBox {
        let body = layout(radicand, style)
        let rule = style.rule
        let gap = style.size * (style.display ? 0.16 : 0.1)
        let s = style.size
        let top = max(body.ascent, s * 0.7) + gap
        let bottom = -max(body.descent, s * 0.05) - s * 0.04
        let sign = s * 0.6
        // Indice de la racine (∛) : petit, posé dans le creux du signe.
        let indexBox = index.map { layout($0, MathStyle(size: max(s * 0.5, style.base * 0.45), base: style.base, display: false, script: true)) }
        let lead = max((indexBox?.width ?? 0) - sign * 0.45, 0)
        let height = top - bottom
        let shape = MathBox(width: lead + sign + body.width + s * 0.12, ascent: top + rule, descent: -bottom) { context, origin in
            let x = origin.x + lead
            let y = origin.y
            context.setLineWidth(rule)
            context.setLineJoin(.round)
            context.setLineCap(.round)
            context.move(to: CGPoint(x: x + s * 0.04, y: y + bottom + height * 0.42))
            context.addLine(to: CGPoint(x: x + s * 0.16, y: y + bottom + height * 0.5))
            context.strokePath()
            context.setLineWidth(rule * 1.9)
            context.move(to: CGPoint(x: x + s * 0.16, y: y + bottom + height * 0.5))
            context.addLine(to: CGPoint(x: x + sign * 0.5, y: y + bottom))
            context.strokePath()
            context.setLineWidth(rule)
            context.move(to: CGPoint(x: x + sign * 0.5, y: y + bottom))
            context.addLine(to: CGPoint(x: x + sign, y: y + top + rule / 2))
            context.addLine(to: CGPoint(x: x + sign + body.width + s * 0.1, y: y + top + rule / 2))
            context.strokePath()
        }
        var parts: [(MathBox, CGFloat, CGFloat)] = [(shape, 0, 0), (body, lead + sign + s * 0.04, 0)]
        if let indexBox {
            parts.append((indexBox, max(lead + sign * 0.45 - indexBox.width, 0), bottom + height * 0.56 + indexBox.descent))
        }
        return MathBox.place(parts, width: shape.width)
    }

    private static func scripts(_ base: MathNode, sup: MathNode?, sub: MathNode?, _ style: MathStyle) -> MathBox {
        let small = style.scriptStyle
        let s = style.size
        // Bornes dessus et dessous (∑, lim) en display.
        if case .op(_, _, let limits) = base, limits, style.display {
            let op = layout(base, style)
            let upper = sup.map { layout($0, small) }
            let lower = sub.map { layout($0, small) }
            let width = max(op.width, upper?.width ?? 0, lower?.width ?? 0)
            var parts: [(MathBox, CGFloat, CGFloat)] = [(op, (width - op.width) / 2, 0)]
            if let upper { parts.append((upper, (width - upper.width) / 2, op.ascent + s * 0.12 + upper.descent)) }
            if let lower { parts.append((lower, (width - lower.width) / 2, -(op.descent + s * 0.1 + lower.ascent))) }
            return MathBox.place(parts, width: width)
        }
        let box = layout(base, style)
        let upper = sup.map { layout($0, small) }
        let lower = sub.map { layout($0, small) }
        var up = max(s * 0.36, box.ascent - s * 0.28)
        var down = max(s * 0.2, box.descent + s * 0.05 * (box.descent > s * 0.3 ? 1 : 0))
        if let upper { up = max(up, upper.descent + s * 0.12) }
        if let lower { down = max(down, lower.ascent - s * 0.4) }
        if let upper, let lower {
            let clash = s * 0.18 - ((up - upper.descent) - (lower.ascent - down))
            if clash > 0 { down += clash }
        }
        // Les intégrales penchent : leur exposant part plus loin que leur indice.
        var supKern: CGFloat = 0
        if case .op(let name, true, _) = base, "∫∬∭∮".contains(name) { supKern = s * 0.12 }
        let x = box.width + s * 0.04
        var parts: [(MathBox, CGFloat, CGFloat)] = [(box, 0, 0)]
        if let upper { parts.append((upper, x + supKern, up)) }
        if let lower { parts.append((lower, x - supKern * 0.6, -down)) }
        let width = x + max((upper?.width ?? 0) + supKern, (lower?.width ?? 0) - supKern * 0.6) + s * 0.04
        return MathBox.place(parts, width: width)
    }

    private static func accent(_ base: MathNode, _ kind: String, _ style: MathStyle) -> MathBox {
        let box = layout(base, style)
        let s = style.size
        let rule = style.rule
        // Les lettres italiques penchent : l'accent se décale un peu vers la droite.
        var skew: CGFloat = 0
        if case .atom(let string, .ord) = base, string.count == 1 { skew = s * 0.06 }
        switch kind {
        case "bar", "overline":
            let inset = kind == "bar" ? box.width * 0.08 : 0
            let y = box.ascent + s * 0.1
            let line = MathBox(width: box.width, ascent: y + rule, descent: 0) { context, origin in
                context.fill(CGRect(x: origin.x + inset + skew, y: origin.y + y, width: box.width - inset * 2, height: rule))
            }
            return MathBox.place([(box, 0, 0), (line, 0, 0)], width: box.width)
        case "underline":
            let y = -box.descent - s * 0.12
            let line = MathBox(width: box.width, ascent: 0, descent: -y + rule) { context, origin in
                context.fill(CGRect(x: origin.x, y: origin.y + y - rule, width: box.width, height: rule))
            }
            return MathBox.place([(box, 0, 0), (line, 0, 0)], width: box.width)
        case "vec", "overrightarrow":
            let y = box.ascent + s * 0.16
            let width = max(box.width, s * 0.45)
            let arrow = MathBox(width: width, ascent: y + s * 0.1, descent: 0) { context, origin in
                let x0 = origin.x + (box.width - width) / 2 + skew
                let x1 = x0 + width
                let yy = origin.y + y
                context.setLineWidth(rule)
                context.setLineCap(.round)
                context.setLineJoin(.round)
                context.move(to: CGPoint(x: x0, y: yy))
                context.addLine(to: CGPoint(x: x1, y: yy))
                context.move(to: CGPoint(x: x1 - s * 0.12, y: yy + s * 0.08))
                context.addLine(to: CGPoint(x: x1, y: yy))
                context.addLine(to: CGPoint(x: x1 - s * 0.12, y: yy - s * 0.08))
                context.strokePath()
            }
            return MathBox.place([(box, 0, 0), (arrow, 0, 0)], width: box.width)
        default:
            let marks = ["hat": "ˆ", "widehat": "ˆ", "tilde": "˜", "widetilde": "˜", "dot": "˙", "ddot": "¨",
                         "check": "ˇ", "breve": "˘", "acute": "´", "grave": "`"]
            let mark = glyph(marks[kind] ?? "ˆ", mathFont(s))
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: marks[kind] ?? "ˆ", attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): mathFont(s),
            ]))
            let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
            // Accent large sur plusieurs lettres : étiré en largeur.
            let stretch = kind.hasPrefix("wide") ? max(box.width * 0.9 / max(bounds.width, 1), 1) : 1
            let dy = box.ascent + s * 0.06 - (bounds.isNull ? 0 : bounds.minY)
            let width = mark.width * stretch
            let draw = mark.draw
            let accentBox = MathBox(width: width, ascent: dy + (bounds.isNull ? 0 : bounds.maxY), descent: 0) { context, origin in
                context.saveGState()
                context.translateBy(x: origin.x + (box.width - width) / 2 + skew, y: origin.y + dy)
                context.scaleBy(x: stretch, y: 1)
                draw(context, .zero)
                context.restoreGState()
            }
            return MathBox.place([(box, 0, 0), (accentBox, 0, 0)], width: box.width)
        }
    }

    // MARK: Délimiteurs et tableaux

    /// Délimiteur à la hauteur de ce qu'il entoure, centré sur l'axe : le glyphe de la police s'il suffit,
    /// sinon dessiné à la bonne hauteur.
    private static func delimiter(_ d: String, around content: MathBox, _ style: MathStyle) -> MathBox {
        delimiter(d, height: 2 * max(content.ascent - style.axis, content.descent + style.axis) + style.size * 0.12, style)
    }

    static func delimiter(_ d: String, height: CGFloat, _ style: MathStyle) -> MathBox {
        guard !d.isEmpty else { return MathBox(width: style.size * 0.06, ascent: 0, descent: 0) { _, _ in } }
        let s = style.size
        if height <= s * 1.15 {
            return centered(d, mathFont(s), axis: style.axis)
        }
        let rule = style.rule * 1.1
        let wide = "{}".contains(d)
        let width = s * (wide ? 0.5 : d == "|" || d == "‖" ? 0.3 : 0.4)
        let half = height / 2
        let axis = style.axis
        return MathBox(width: width, ascent: axis + half, descent: half - axis) { context, origin in
            let top = origin.y + axis + half
            let bottom = origin.y + axis - half
            let mid = origin.y + axis
            let x = origin.x
            context.setLineWidth(rule)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            // Les délimiteurs de droite sont ceux de gauche en miroir.
            let mirrored = ")]}⟩⌋⌉".contains(d)
            context.saveGState()
            if mirrored {
                context.translateBy(x: x * 2 + width, y: 0)
                context.scaleBy(x: -1, y: 1)
            }
            switch d {
            case "(", ")":
                let right = x + width * 0.82
                let outer = x + width * 0.12
                let path = CGMutablePath()
                path.move(to: CGPoint(x: right, y: top))
                path.addQuadCurve(to: CGPoint(x: right, y: bottom), control: CGPoint(x: 2 * outer - right, y: mid))
                path.addQuadCurve(to: CGPoint(x: right, y: top), control: CGPoint(x: 2 * (outer + rule * 1.2) - right, y: mid))
                context.addPath(path)
                context.fillPath()
            case "[", "]", "⌊", "⌋", "⌈", "⌉":
                let stem = x + width * 0.3
                context.move(to: CGPoint(x: stem, y: top))
                context.addLine(to: CGPoint(x: stem, y: bottom))
                if d != "⌈" && d != "⌉" {
                    context.move(to: CGPoint(x: stem, y: bottom))
                    context.addLine(to: CGPoint(x: x + width * 0.85, y: bottom))
                }
                if d != "⌊" && d != "⌋" {
                    context.move(to: CGPoint(x: stem, y: top))
                    context.addLine(to: CGPoint(x: x + width * 0.85, y: top))
                }
                context.strokePath()
            case "{", "}":
                let right = x + width * 0.85
                let stem = x + width * 0.5
                let tip = x + width * 0.12
                let r = min(s * 0.18, half * 0.3)
                context.move(to: CGPoint(x: right, y: top))
                context.addQuadCurve(to: CGPoint(x: stem, y: top - r), control: CGPoint(x: stem, y: top))
                context.addLine(to: CGPoint(x: stem, y: mid + r))
                context.addQuadCurve(to: CGPoint(x: tip, y: mid), control: CGPoint(x: stem, y: mid))
                context.addQuadCurve(to: CGPoint(x: stem, y: mid - r), control: CGPoint(x: stem, y: mid))
                context.addLine(to: CGPoint(x: stem, y: bottom + r))
                context.addQuadCurve(to: CGPoint(x: right, y: bottom), control: CGPoint(x: stem, y: bottom))
                context.strokePath()
            case "⟨", "⟩":
                context.move(to: CGPoint(x: x + width * 0.8, y: top))
                context.addLine(to: CGPoint(x: x + width * 0.2, y: mid))
                context.addLine(to: CGPoint(x: x + width * 0.8, y: bottom))
                context.strokePath()
            case "‖":
                for stem in [x + width * 0.3, x + width * 0.7] {
                    context.move(to: CGPoint(x: stem, y: top))
                    context.addLine(to: CGPoint(x: stem, y: bottom))
                }
                context.strokePath()
            default:
                context.move(to: CGPoint(x: x + width / 2, y: top))
                context.addLine(to: CGPoint(x: x + width / 2, y: bottom))
                context.strokePath()
            }
            context.restoreGState()
        }
    }

    private static func table(_ rows: [[MathNode]], align: [MathAlign], left: String, right: String,
                              columnGap: CGFloat, _ style: MathStyle) -> MathBox {
        let inner = style.textStyle
        let s = style.size
        let count = rows.map(\.count).max() ?? 0
        guard count > 0 else { return .empty }
        let aligned = columnGap == 0 && align.count > 1
        // Colonnes d'un `aligned` qui commencent à droite du « & » : la relation garde ses espaces.
        let boxes: [[MathBox]] = rows.map { cells in
            (0..<count).map { column in
                guard column < cells.count else { return .empty }
                let cell = cells[column]
                if aligned, column % 2 == 1 {
                    if case .row(let nodes) = cell { return row(nodes, inner, afterOrd: true) }
                    return row([cell], inner, afterOrd: true)
                }
                return layout(cell, inner)
            }
        }
        let widths = (0..<count).map { column in boxes.map { $0[column].width }.max() ?? 0 }
        let ascents = boxes.map { max($0.map(\.ascent).max() ?? 0, s * 0.72) }
        let descents = boxes.map { max($0.map(\.descent).max() ?? 0, s * 0.28) }
        let rowGap = s * (aligned || align == [.left, .left] ? 0.4 : 0.32)
        let height = zip(ascents, descents).map(+).reduce(0, +) + rowGap * CGFloat(max(rows.count - 1, 0))
        let gaps = (0..<count).map { column -> CGFloat in
            guard column > 0 else { return 0 }
            if aligned { return column % 2 == 0 ? s * 1.6 : 0 }
            return columnGap * s
        }
        let open = delimiter(left, height: height + s * 0.2, style)
        let close = delimiter(right, height: height + s * 0.2, style)
        let pad = left.isEmpty && right.isEmpty ? 0 : s * 0.12
        var parts: [(MathBox, CGFloat, CGFloat)] = [(open, 0, 0)]
        var y = style.axis + height / 2
        for (index, cells) in boxes.enumerated() {
            y -= ascents[index]
            var x = open.width + pad
            for column in 0..<count {
                x += gaps[column]
                let box = cells[column]
                let mode = align.indices.contains(column) ? align[column] : align.last ?? .center
                let dx: CGFloat = switch mode {
                case .left: 0
                case .center: (widths[column] - box.width) / 2
                case .right: widths[column] - box.width
                }
                parts.append((box, x + dx, y))
                x += widths[column]
            }
            y -= descents[index] + rowGap
        }
        let contentWidth = widths.reduce(0, +) + gaps.reduce(0, +)
        parts.append((close, open.width + pad * 2 + contentWidth, 0))
        return MathBox.place(parts, width: open.width + pad * 2 + contentWidth + close.width)
    }
}

// MARK: - Rendu

/// Formules prêtes à afficher : une image gabarit (teintée par l'encre du style) et la profondeur sous la ligne
/// de base, pour l'aligner sur le texte. Gardées en cache : le texte d'une réponse se redessine à chaque mot reçu.
enum MathRender {
    final class Rendered {
        let image: NSImage
        let descent: CGFloat
        init(image: NSImage, descent: CGFloat) { self.image = image; self.descent = descent }
    }

    private static let cache = NSCache<NSString, Rendered>()

    static func image(_ latex: String, size: CGFloat, display: Bool) -> Rendered? {
        let key = "\(size)|\(display)|\(latex)" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        let box = MathLayout.layout(MathParser.parse(latex), MathStyle(size: size, base: size, display: display))
        guard box.width > 0 else { return nil }
        let pad: CGFloat = 1
        let width = ceil(box.width + pad * 2)
        let height = ceil(box.ascent + box.descent + pad * 2)
        let scale = max(NSScreen.main?.backingScaleFactor ?? 2, 2)
        guard let context = CGContext(data: nil, width: Int(width * scale), height: Int(height * scale), bitsPerComponent: 8,
                                      bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.scaleBy(x: scale, y: scale)
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.setStrokeColor(CGColor(gray: 0, alpha: 1))
        context.setShouldSmoothFonts(false)
        box.draw(context, CGPoint(x: pad, y: pad + ceil(box.descent)))
        guard let cg = context.makeImage() else { return nil }
        let image = NSImage(cgImage: cg, size: NSSize(width: width, height: height))
        image.isTemplate = true
        let rendered = Rendered(image: image, descent: ceil(box.descent) + pad)
        cache.setObject(rendered, forKey: key)
        return rendered
    }

    /// Formule simple écrite en caractères Unicode (𝑥² + 𝑦₁ ≤ 𝛼), sélectionnable et copiable dans le texte ;
    /// nil si elle a besoin d'être composée (fraction, racine sur plusieurs signes, matrice…).
    static func plain(_ latex: String) -> String? {
        plain(MathParser.parse(latex))
    }

    private static func plain(_ node: MathNode) -> String? {
        switch node {
        case .atom(let string, _): return string
        case .text(let string): return string
        case .space(let em): return em >= 0.9 ? "  " : em > 0.2 ? " " : em > 0 ? "\u{2009}" : ""
        case .row(let nodes):
            var out = ""
            var previous: MathClass?
            for node in nodes {
                guard let part = plain(node) else { return nil }
                var cls = node.mathClass
                if cls == .bin, previous == nil || [.bin, .op, .rel, .open, .punct].contains(previous!) { cls = .ord }
                switch cls {
                case .bin, .rel: out += " " + part + " "
                case .punct: out += part + " "
                case .op: out += (out.isEmpty || out.hasSuffix(" ") ? "" : " ") + part + "\u{2009}"
                default: out += part
                }
                if let cls { previous = cls }
            }
            return out.trimmingCharacters(in: .whitespaces)
        case .scripts(let base, let sup, let sub):
            if case .op(_, _, true) = base { return nil }
            guard let body = plain(base) else { return nil }
            var out = body
            if let sub { guard let text = plain(sub).flatMap({ map($0, subscripts) }) else { return nil }; out += text }
            if let sup { guard let text = plain(sup).flatMap({ map($0, superscripts) }) else { return nil }; out += text }
            return out
        case .op(let name, _, _): return name
        case .root(let radicand, nil):
            guard case .atom(let string, _) = radicand else { return nil }
            return "√" + string
        case .fenced(let left, let inner, let right):
            guard let body = plain(inner) else { return nil }
            return left + body + right
        case .accent(let base, let kind):
            let marks = ["bar": "\u{0304}", "overline": "\u{0305}", "hat": "\u{0302}", "vec": "\u{20D7}",
                         "tilde": "\u{0303}", "dot": "\u{0307}", "ddot": "\u{0308}", "check": "\u{030C}"]
            guard case .atom(let string, _) = base, string.count == 1, let mark = marks[kind] else { return nil }
            return string + mark
        default: return nil
        }
    }

    /// Exposants et indices Unicode ; nil dès qu'un caractère n'en a pas.
    private static func map(_ string: String, _ table: [Character: Character]) -> String? {
        var out = ""
        for c in string {
            if c == " " || c == "\u{2009}" { continue }
            guard let mapped = table[asciiLetter(c) ?? c] else { return nil }
            out.append(mapped)
        }
        return out
    }

    /// Lettre italique mathématique (𝑥) ramenée à sa lettre latine (x).
    private static func asciiLetter(_ c: Character) -> Character? {
        guard let scalar = c.unicodeScalars.first?.value else { return nil }
        if c == "ℎ" { return "h" }
        if (0x1D44E...0x1D467).contains(scalar) { return Character(Unicode.Scalar(UInt8(97 + scalar - 0x1D44E))) }
        if (0x1D434...0x1D44D).contains(scalar) { return Character(Unicode.Scalar(UInt8(65 + scalar - 0x1D434))) }
        if c == "−" { return "-" }
        return nil
    }

    private static let superscripts: [Character: Character] = Dictionary(zip(
        "0123456789+-=()abcdefghijklmnoprstuvwxyzABDEGHIJKLMNOPRTUVW′",
        "⁰¹²³⁴⁵⁶⁷⁸⁹⁺⁻⁼⁽⁾ᵃᵇᶜᵈᵉᶠᵍʰⁱʲᵏˡᵐⁿᵒᵖʳˢᵗᵘᵛʷˣʸᶻᴬᴮᴰᴱᴳᴴᴵᴶᴷᴸᴹᴺᴼᴾᴿᵀᵁⱽᵂ′"), uniquingKeysWith: { a, _ in a })
    private static let subscripts: [Character: Character] = Dictionary(zip(
        "0123456789+-=()aehijklmnoprstuvx",
        "₀₁₂₃₄₅₆₇₈₉₊₋₌₍₎ₐₑₕᵢⱼₖₗₘₙₒₚᵣₛₜᵤᵥₓ"), uniquingKeysWith: { a, _ in a })
}
