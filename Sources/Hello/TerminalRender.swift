import SwiftUI

/// Interprète la sortie d'un terminal (séquences ANSI) en texte stylé :
/// couleurs 16 / 256 / truecolor, gras, atténué, italique, souligné, inverse,
/// retour chariot (barres de progression) et effacement de ligne.
struct TermStyle: Equatable {
    enum Tint: Equatable {
        case index(Int)
        case rgb(Double, Double, Double)
    }

    var foreground: Tint?
    var background: Tint?
    var bold = false
    var dim = false
    var italic = false
    var underline = false
    var inverse = false
}

struct TermSegment {
    var text: String
    var style: TermStyle
}

final class TerminalBuffer {
    private(set) var lines: [[TermSegment]] = [[]]
    private var style = TermStyle()
    private var pending = ""          // séquence d'échappement coupée entre deux lectures
    private var carriageReturn = false
    private let maxLines = 4000

    var isEmpty: Bool { lines.count == 1 && lines[0].isEmpty }

    var plainText: String {
        lines.map { $0.map(\.text).joined() }.joined(separator: "\n")
    }

    func feed(_ chunk: String) {
        var input = pending + chunk
        pending = ""
        var text = ""
        var index = input.startIndex

        func flush() {
            guard !text.isEmpty else { return }
            if carriageReturn {
                lines[lines.count - 1] = []
                carriageReturn = false
            }
            if var last = lines[lines.count - 1].last, last.style == style {
                last.text += text
                lines[lines.count - 1][lines[lines.count - 1].count - 1] = last
            } else {
                lines[lines.count - 1].append(TermSegment(text: text, style: style))
            }
            text = ""
        }

        while index < input.endIndex {
            let ch = input[index]
            switch ch {
            case "\u{1B}":
                flush()
                guard let end = escapeEnd(in: input, from: index) else {
                    pending = String(input[index...])
                    input = ""
                    return
                }
                let sequence = input[index..<end]
                if sequence.hasPrefix("\u{1B}["), let final = sequence.last {
                    let params = sequence.dropFirst(2).dropLast()
                    if final == "m" { applySGR(String(params)) }
                    if final == "K" { eraseLine(String(params)) }
                    if final == "J" && params.contains("2") { lines = [[]] }
                }
                index = end
                continue
            case "\r\n", "\n":
                flush()
                carriageReturn = false
                lines.append([])
                if lines.count > maxLines { lines.removeFirst(lines.count - maxLines) }
            case "\r":
                flush()
                carriageReturn = true
            case "\u{07}", "\u{08}", "\u{0E}", "\u{0F}":
                break
            default:
                text.append(ch)
            }
            index = input.index(after: index)
        }
        flush()
    }

    /// Fin d'une séquence CSI (ESC [ … lettre) ou OSC (ESC ] … BEL / ESC \), nil si incomplète.
    private func escapeEnd(in s: String, from start: String.Index) -> String.Index? {
        var i = s.index(after: start)
        guard i < s.endIndex else { return nil }
        switch s[i] {
        case "[":
            i = s.index(after: i)
            while i < s.endIndex {
                if let v = s[i].asciiValue, (0x40...0x7E).contains(v) { return s.index(after: i) }
                i = s.index(after: i)
            }
            return nil
        case "]":
            while i < s.endIndex {
                if s[i] == "\u{07}" { return s.index(after: i) }
                if s[i] == "\u{1B}", s.index(after: i) < s.endIndex, s[s.index(after: i)] == "\\" {
                    return s.index(i, offsetBy: 2)
                }
                i = s.index(after: i)
            }
            return nil
        default:
            return s.index(after: i)
        }
    }

    private func eraseLine(_ params: String) {
        if params.isEmpty || params == "0" || params == "2" {
            if carriageReturn || params == "2" { lines[lines.count - 1] = [] }
        }
    }

    private func applySGR(_ params: String) {
        let codes = params.isEmpty ? [0] : params.split(separator: ";", omittingEmptySubsequences: false).map { Int($0) ?? 0 }
        var i = 0
        while i < codes.count {
            let code = codes[i]
            switch code {
            case 0: style = TermStyle()
            case 1: style.bold = true
            case 2: style.dim = true
            case 3: style.italic = true
            case 4: style.underline = true
            case 7: style.inverse = true
            case 22: style.bold = false; style.dim = false
            case 23: style.italic = false
            case 24: style.underline = false
            case 27: style.inverse = false
            case 30...37: style.foreground = .index(code - 30)
            case 90...97: style.foreground = .index(code - 90 + 8)
            case 39: style.foreground = nil
            case 40...47: style.background = .index(code - 40)
            case 100...107: style.background = .index(code - 100 + 8)
            case 49: style.background = nil
            case 38, 48:
                var tint: TermStyle.Tint?
                if i + 2 < codes.count, codes[i + 1] == 5 {
                    tint = .index(codes[i + 2])
                    i += 2
                } else if i + 4 < codes.count, codes[i + 1] == 2 {
                    tint = .rgb(Double(codes[i + 2]) / 255, Double(codes[i + 3]) / 255, Double(codes[i + 4]) / 255)
                    i += 4
                }
                if code == 38 { style.foreground = tint } else { style.background = tint }
            default: break
            }
            i += 1
        }
    }

    // MARK: - Rendu

    /// Palette pensée pour le fond sombre du panneau (le noir ANSI reste lisible).
    private static let palette: [(Double, Double, Double)] = [
        (0.36, 0.38, 0.44), (1.00, 0.37, 0.43), (0.35, 0.97, 0.56), (0.95, 0.98, 0.62),
        (0.34, 0.78, 1.00), (1.00, 0.42, 0.76), (0.60, 0.93, 1.00), (0.82, 0.82, 0.86),
        (0.48, 0.50, 0.55), (1.00, 0.54, 0.54), (0.49, 1.00, 0.66), (1.00, 0.96, 0.54),
        (0.49, 0.83, 1.00), (1.00, 0.57, 0.87), (0.72, 0.96, 1.00), (1.00, 1.00, 1.00),
    ]

    static func color(_ tint: TermStyle.Tint) -> Color {
        switch tint {
        case .rgb(let r, let g, let b):
            return Color(red: r, green: g, blue: b)
        case .index(let n) where n < 16:
            let c = palette[max(0, n)]
            return Color(red: c.0, green: c.1, blue: c.2)
        case .index(let n) where n < 232:
            let steps: [Double] = [0, 95, 135, 175, 215, 255]
            let v = n - 16
            return Color(red: steps[v / 36] / 255, green: steps[(v / 6) % 6] / 255, blue: steps[v % 6] / 255)
        case .index(let n):
            let level = Double(8 + (min(n, 255) - 232) * 10) / 255
            return Color(red: level, green: level, blue: level)
        }
    }

    func attributed(fontSize: CGFloat) -> AttributedString {
        var result = AttributedString()
        for (i, line) in lines.enumerated() {
            for segment in line {
                var piece = AttributedString(segment.text)
                let s = segment.style
                var font = Font.system(size: fontSize, weight: s.bold ? .bold : .regular, design: .monospaced)
                if s.italic { font = font.italic() }
                piece.font = font
                var fg = s.foreground.map(Self.color)
                var bg = s.background.map(Self.color)
                if s.inverse { (fg, bg) = (bg ?? Color(white: 0.1), fg ?? .white) }
                if let fg { piece.foregroundColor = s.dim ? fg.opacity(0.6) : fg }
                else if s.dim { piece.foregroundColor = Color.primary.opacity(0.55) }
                if let bg { piece.backgroundColor = bg }
                if s.underline { piece.underlineStyle = .single }
                result.append(piece)
            }
            if i < lines.count - 1 { result.append(AttributedString("\n")) }
        }
        return result
    }
}
