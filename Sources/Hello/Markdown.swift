import AppKit
import SwiftUI

/// Markdown des réponses de l'IA : titres, listes (imbriquées, à cocher), citations, blocs de code, tableaux,
/// filets, liens et styles en ligne, et formules LaTeX — `$…$` ou `\(…\)` dans le texte, `$$…$$`, `\[…\]` ou
/// `\begin{…}` sur leurs propres lignes.
struct MarkdownText: View {
    let text: String
    @Environment(\.styleTokens) private var style

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(MarkdownBlock.parse(text).enumerated()), id: \.offset) { _, block in
                view(block)
            }
        }
        .font(.system(size: 13.5))
        .textSelection(.enabled)
        .tint(style.monochrome ?? .cyan)
    }

    @ViewBuilder private func view(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let content):
            let size: CGFloat = level == 1 ? 17 : level == 2 ? 15 : 14
            MarkdownInline.text(content, size: size)
                .font(.system(size: size, weight: .bold))
                .padding(.top, 4)
        case .bullet(let indent, let marker, let content):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(marker).foregroundStyle(.secondary).monospacedDigit()
                MarkdownInline.text(content, size: 13.5)
            }
            .padding(.leading, CGFloat(indent) * 16)
        case .task(let indent, let done, let content):
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Image(systemName: done ? "checkmark.square.fill" : "square").foregroundStyle(.secondary)
                MarkdownInline.text(content, size: 13.5)
                    .strikethrough(done)
                    .foregroundStyle(done ? .secondary : .primary)
            }
            .padding(.leading, CGFloat(indent) * 16)
        case .quote(let content):
            MarkdownInline.text(content, size: 13.5)
                .foregroundStyle(.secondary)
                .padding(.leading, 10)
                .overlay(alignment: .leading) { Rectangle().fill(.tertiary).frame(width: 2) }
        case .code(let content, let language):
            Text(content)
                .font(.system(size: 12, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.quinary))
                .overlay(alignment: .topTrailing) {
                    if !language.isEmpty {
                        Text(language.lowercased()).font(.system(size: 9.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(.tertiary).padding(6)
                    }
                }
        case .math(let latex):
            MathBlock(latex: latex)
        case .table(let table):
            MarkdownTableView(table: table)
                .padding(.vertical, 2)
        case .rule:
            Rectangle().fill(.quaternary).frame(height: 1).padding(.vertical, 4)
        case .paragraph(let content):
            MarkdownInline.text(content, size: 13.5)
        }
    }
}

enum MarkdownBlock {
    case heading(Int, String)
    case bullet(indent: Int, marker: String, String)
    case task(indent: Int, done: Bool, String)
    case quote(String)
    case code(String, language: String)
    case math(String)
    case table(MarkdownTable)
    case rule
    case paragraph(String)

    static func parse(_ text: String) -> [MarkdownBlock] {
        let lines = text.components(separatedBy: "\n")
        var out: [MarkdownBlock] = []
        var index = 0
        while index < lines.count {
            let raw = lines[index]
            let line = raw.trimmingCharacters(in: .whitespaces)
            index += 1
            if line.isEmpty { continue }

            // Bloc de code (« ```math » : une formule).
            if line.hasPrefix("```") || line.hasPrefix("~~~") {
                let fence = String(line.prefix(3))
                let language = line.dropFirst(3).trimmingCharacters(in: .whitespaces)
                var body: [String] = []
                while index < lines.count, !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix(fence) {
                    body.append(lines[index])
                    index += 1
                }
                index += 1
                let content = body.joined(separator: "\n")
                out.append(["math", "latex", "tex", "katex"].contains(language.lowercased())
                    ? .math(content) : .code(content, language: language))
                continue
            }

            // Formule à part : `$$…$$`, `\[…\]`, ou un environnement LaTeX (`\begin{align}`…).
            if let (open, close) = [("$$", "$$"), ("\\[", "\\]")].first(where: { line.hasPrefix($0.0) }) {
                let rest = line.dropFirst(open.count)
                if let end = rest.range(of: close) {
                    out.append(.math(String(rest[..<end.lowerBound])))
                    let tail = rest[end.upperBound...].trimmingCharacters(in: .whitespaces)
                    if !tail.isEmpty { out.append(.paragraph(tail)) }
                    continue
                }
                var body = [String(rest)]
                var closed = false
                while index < lines.count {
                    let next = lines[index]
                    index += 1
                    if let end = next.range(of: close) {
                        body.append(String(next[..<end.lowerBound]))
                        closed = true
                        break
                    }
                    body.append(next)
                }
                // Formule pas encore refermée (réponse en cours) : montrée telle quelle en attendant.
                out.append(closed ? .math(body.joined(separator: "\n"))
                    : .code(([open] + body).joined(separator: "\n"), language: ""))
                continue
            }
            if line.hasPrefix("\\begin{"), let name = line.dropFirst(7).split(separator: "}").first {
                let end = "\\end{\(name)}"
                var body = [line]
                while !body.last!.contains(end), index < lines.count {
                    body.append(lines[index])
                    index += 1
                }
                out.append(.math(body.joined(separator: "\n")))
                continue
            }

            // Tableau : une ligne d'en-tête, puis la ligne de séparation (`|---|:--:|`).
            if line.contains("|"), index < lines.count, MarkdownTable.isSeparator(lines[index]) {
                let header = MarkdownTable.cells(line)
                let align = MarkdownTable.cells(lines[index]).map(MarkdownTable.alignment)
                index += 1
                var rows: [[String]] = []
                while index < lines.count {
                    let next = lines[index].trimmingCharacters(in: .whitespaces)
                    guard next.contains("|") else { break }
                    rows.append(MarkdownTable.cells(next))
                    index += 1
                }
                out.append(.table(MarkdownTable(header: header, align: align, rows: rows)))
                continue
            }

            if line.count >= 3, let first = line.first, "-*_".contains(first), line.allSatisfy({ $0 == first || $0 == " " }) {
                out.append(.rule)
                continue
            }
            if line.hasPrefix("#") {
                let level = line.prefix { $0 == "#" }.count
                out.append(.heading(level, line.dropFirst(level).trimmingCharacters(in: .whitespaces)))
                continue
            }
            // Retrait des listes imbriquées : deux espaces (ou une tabulation) par niveau.
            let indent = min(raw.prefix { $0 == " " || $0 == "\t" }.reduce(0) { $0 + ($1 == "\t" ? 4 : 1) } / 2, 4)
            if ["- ", "* ", "+ ", "• "].contains(where: line.hasPrefix) {
                let content = String(line.dropFirst(2))
                if content.hasPrefix("[ ] ") || content.hasPrefix("[x] ") || content.hasPrefix("[X] ") {
                    out.append(.task(indent: indent, done: !content.hasPrefix("[ ]"), String(content.dropFirst(4))))
                } else {
                    out.append(.bullet(indent: indent, marker: indent.isMultiple(of: 2) ? "•" : "◦", content))
                }
            } else if let mark = line.firstIndex(where: { $0 == "." || $0 == ")" }), !line[..<mark].isEmpty,
                      line[..<mark].count <= 3, line[..<mark].allSatisfy(\.isNumber), line[line.index(after: mark)...].hasPrefix(" ") {
                out.append(.bullet(indent: indent, marker: String(line[..<mark]) + ".",
                                   line[line.index(after: mark)...].trimmingCharacters(in: .whitespaces)))
            } else if line.hasPrefix(">") {
                out.append(.quote(line.dropFirst().trimmingCharacters(in: .whitespaces)))
            } else {
                out.append(.paragraph(line))
            }
        }
        return out
    }
}

// MARK: - Texte en ligne

enum MarkdownInline {
    enum Piece: Equatable {
        case markdown(String)
        case math(String, display: Bool)
    }

    /// Texte en ligne : le Markdown (gras, italique, code, liens) et les formules, à la taille du texte.
    /// Une formule simple s'écrit en caractères (sélectionnable) ; les autres sont composées en image.
    static func text(_ string: String, size: CGFloat) -> Text {
        let pieces = split(string)
        if pieces.count == 1, case .markdown(let markdown) = pieces[0] { return Text(attributed(markdown)) }
        var result = Text(verbatim: "")
        for piece in pieces {
            let next: Text
            switch piece {
            case .markdown(let markdown):
                next = Text(attributed(markdown))
            case .math(let latex, let display):
                if !display, let plain = MathRender.plain(latex) {
                    var run = AttributedString(plain)
                    run.font = Font.custom("STIXTwoMath-Regular", size: size * 1.12)
                    next = Text(run)
                } else if let rendered = MathRender.image(latex, size: size * 1.1, display: display) {
                    next = Text(Image(nsImage: rendered.image).renderingMode(.template)).baselineOffset(-rendered.descent)
                } else {
                    next = Text(verbatim: latex)
                }
            }
            result = Text("\(result)\(next)")
        }
        return result
    }

    private static func attributed(_ markdown: String) -> AttributedString {
        (try? AttributedString(markdown: markdown, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(markdown)
    }

    /// Découpe le texte en Markdown et en formules ; rien n'est pris pour une formule dans le code (`…`),
    /// ni un prix (« 5 $ et 10 $ », « $5 à $10 »).
    static func split(_ string: String) -> [Piece] {
        let chars = Array(string)
        var pieces: [Piece] = []
        var buffer = ""
        var code = false
        var i = 0
        func flush() {
            if !buffer.isEmpty { pieces.append(.markdown(buffer)) }
            buffer = ""
        }
        while i < chars.count {
            let c = chars[i]
            if c == "`" {
                code.toggle()
            } else if !code, c == "\\", i + 1 < chars.count {
                let next = chars[i + 1]
                if next == "(" || next == "[", let end = find(next == "(" ? "\\)" : "\\]", in: chars, from: i + 2) {
                    flush()
                    pieces.append(.math(String(chars[(i + 2)..<end]), display: next == "["))
                    i = end + 2
                    continue
                }
                if next == "$" {
                    buffer += "\\$"
                    i += 2
                    continue
                }
            } else if !code, c == "$" {
                if i + 1 < chars.count, chars[i + 1] == "$", let end = find("$$", in: chars, from: i + 2) {
                    flush()
                    pieces.append(.math(String(chars[(i + 2)..<end]), display: true))
                    i = end + 2
                    continue
                }
                if let end = dollarEnd(chars, from: i) {
                    flush()
                    pieces.append(.math(String(chars[(i + 1)..<end]), display: false))
                    i = end + 1
                    continue
                }
            }
            buffer.append(c)
            i += 1
        }
        flush()
        return pieces
    }

    /// Fin d'une formule `$…$` ouverte en `start` : collée à son contenu des deux côtés, et pas suivie d'un chiffre.
    static func dollarEnd(_ chars: [Character], from start: Int) -> Int? {
        guard start + 1 < chars.count, !chars[start + 1].isWhitespace, chars[start + 1] != "$" else { return nil }
        var j = start + 2
        while j < chars.count {
            if chars[j] == "$", chars[j - 1] != "\\" {
                guard !chars[j - 1].isWhitespace, j + 1 >= chars.count || !chars[j + 1].isNumber else { return nil }
                return j
            }
            j += 1
        }
        return nil
    }

    private static func find(_ needle: String, in chars: [Character], from start: Int) -> Int? {
        let pattern = Array(needle)
        guard start <= chars.count - pattern.count else { return nil }
        for j in start...(chars.count - pattern.count) where Array(chars[j..<(j + pattern.count)]) == pattern {
            return j
        }
        return nil
    }
}

// MARK: - Formules et tableaux

/// Formule composée sur sa propre ligne, centrée ; trop large, elle défile. Clic droit : copier le LaTeX.
struct MathBlock: View {
    let latex: String

    var body: some View {
        if let rendered = MathRender.image(latex, size: 16, display: true) {
            let image = Image(nsImage: rendered.image).renderingMode(.template)
            ViewThatFits(in: .horizontal) {
                image.frame(maxWidth: .infinity)
                ScrollView(.horizontal, showsIndicators: false) { image }
            }
            .padding(.vertical, 4)
            .help(latex.trimmingCharacters(in: .whitespacesAndNewlines))
            .contextMenu {
                Button("Copier le LaTeX") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(latex.trimmingCharacters(in: .whitespacesAndNewlines), forType: .string)
                }
            }
        } else {
            Text(latex).font(.system(size: 12, design: .monospaced))
        }
    }
}

struct MarkdownTable {
    var header: [String]
    var align: [Alignment]
    var rows: [[String]]

    /// Ligne de séparation sous l'en-tête : des tirets, des deux-points pour l'alignement, des barres.
    static func isSeparator(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.contains("-") && trimmed.contains("|") && trimmed.allSatisfy { "|:- \t".contains($0) }
    }

    static func alignment(_ cell: String) -> Alignment {
        switch (cell.hasPrefix(":"), cell.hasSuffix(":")) {
        case (true, true): .center
        case (false, true): .trailing
        default: .leading
        }
    }

    /// Cellules d'une ligne : séparées par `|`, sauf dans le code, dans une formule ou échappé (`\|`).
    static func cells(_ line: String) -> [String] {
        var chars = Array(line.trimmingCharacters(in: .whitespaces))
        if chars.first == "|" { chars.removeFirst() }
        if chars.last == "|", chars.dropLast().last != "\\" { chars.removeLast() }
        var cells: [String] = []
        var cell = ""
        var code = false
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "`" { code.toggle() }
            if !code, c == "\\", i + 1 < chars.count, chars[i + 1] == "|" {
                cell.append("|")
                i += 2
                continue
            }
            if !code, c == "$", let end = MarkdownInline.dollarEnd(chars, from: i) {
                cell += String(chars[i...end])
                i = end + 1
                continue
            }
            if !code, c == "|" {
                cells.append(cell.trimmingCharacters(in: .whitespaces))
                cell = ""
            } else {
                cell.append(c)
            }
            i += 1
        }
        cells.append(cell.trimmingCharacters(in: .whitespaces))
        return cells
    }
}

struct MarkdownTableView: View {
    let table: MarkdownTable

    var body: some View {
        let columns = max(table.header.count, table.rows.map(\.count).max() ?? 0)
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                ForEach(0..<columns, id: \.self) { column in
                    cell(column < table.header.count ? table.header[column] : "", column, header: true)
                }
            }
            ForEach(Array(table.rows.enumerated()), id: \.offset) { index, row in
                Rectangle().fill(index == 0 ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.quinary))
                    .frame(height: 1)
                    .gridCellUnsizedAxes(.horizontal)
                GridRow {
                    ForEach(0..<columns, id: \.self) { column in
                        cell(column < row.count ? row[column] : "", column, header: false)
                    }
                }
            }
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(.quaternary, lineWidth: 1))
    }

    private func cell(_ text: String, _ column: Int, header: Bool) -> some View {
        let alignment = column < table.align.count ? table.align[column] : .leading
        return MarkdownInline.text(text, size: 12.5)
            .font(.system(size: 12.5, weight: header ? .semibold : .regular))
            .multilineTextAlignment(alignment == .trailing ? .trailing : alignment == .center ? .center : .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            .background(header ? AnyShapeStyle(.quinary) : AnyShapeStyle(.clear))
    }
}
