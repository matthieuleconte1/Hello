import XCTest
@testable import Hello

final class MarkdownTests: XCTestCase {
    func testDollarAmountsAreNotMath() {
        XCTAssertEqual(MarkdownInline.split("De $5 à $10 par mois"), [.markdown("De $5 à $10 par mois")])
        XCTAssertEqual(MarkdownInline.split("Entre $5-$10"), [.markdown("Entre $5-$10")])
    }

    func testInlineAndDisplayMathAreSplitOut() {
        XCTAssertEqual(MarkdownInline.split("Soit $x^2$ et \\(y\\)."),
                       [.markdown("Soit "), .math("x^2", display: false), .markdown(" et "), .math("y", display: false), .markdown(".")])
        XCTAssertEqual(MarkdownInline.split("`$PATH` vaut $$a$$"),
                       [.markdown("`$PATH` vaut "), .math("a", display: true)])
    }

    func testTableCellsKeepPipesInsideMathAndEscapes() {
        XCTAssertEqual(MarkdownTable.cells("| $|x|$ | a \\| b | `c|d` |"), ["$|x|$", "a | b", "`c|d`"])
        XCTAssertTrue(MarkdownTable.isSeparator("|:--|:-:|--:|"))
        XCTAssertFalse(MarkdownTable.isSeparator("---"))
    }

    func testBlocks() {
        let blocks = MarkdownBlock.parse("""
        | A | B |
        |---|--:|
        | 1 | 2 |

        $$
        \\frac{1}{2}
        $$
        - [x] fait
          - sous-point
        ---
        """)
        guard blocks.count == 5 else { return XCTFail("\(blocks)") }
        if case .table(let table) = blocks[0] {
            XCTAssertEqual(table.header, ["A", "B"])
            XCTAssertEqual(table.rows, [["1", "2"]])
            XCTAssertEqual(table.align, [.leading, .trailing])
        } else { XCTFail() }
        if case .math(let latex) = blocks[1] { XCTAssertEqual(latex.trimmingCharacters(in: .whitespacesAndNewlines), "\\frac{1}{2}") } else { XCTFail() }
        if case .task(0, true, "fait") = blocks[2] {} else { XCTFail("\(blocks[2])") }
        if case .bullet(1, _, "sous-point") = blocks[3] {} else { XCTFail("\(blocks[3])") }
        if case .rule = blocks[4] {} else { XCTFail() }
    }

    func testSimpleMathIsWrittenInUnicode() {
        XCTAssertEqual(MathRender.plain("x^2 + y_1 \\leq \\alpha"), "𝑥² + 𝑦₁ ≤ 𝛼")
        XCTAssertEqual(MathRender.plain("\\mathbb{R}^n"), "ℝⁿ")
        XCTAssertNil(MathRender.plain("\\frac{a}{b}"))
        XCTAssertNil(MathRender.plain("\\sum_{i=1}^n i"))
    }

    func testEveryFormulaLaysOut() {
        for latex in ["\\frac{a}{b}", "\\sqrt[3]{x+1}", "\\begin{pmatrix} 1 & 2 \\\\ 3 & 4 \\end{pmatrix}",
                      "\\left( \\frac{1}{2} \\right", "}{x", "x^", "\\unknown{x}", "a \\\\ b & c"] {
            XCTAssertNotNil(MathRender.image(latex, size: 16, display: true), latex)
        }
    }
}
