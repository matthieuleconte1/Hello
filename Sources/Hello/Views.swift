import AppKit
import SwiftUI

struct LauncherView: View {
    @ObservedObject var model: LauncherModel
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        // La fenêtre est plus grande que le panneau (marges pour l'ombre, place pour le grand panneau des apps) :
        // le panneau y est posé à `panelRect`, que SwiftUI anime (hauteur selon les résultats, passage aux apps).
        GeometryReader { geo in
            let rect = model.panelRect ?? CGRect(origin: .zero, size: geo.size)
            ZStack(alignment: .topLeading) {
                // Clic dans l'ombre autour du panneau : on ferme, comme un clic ailleurs.
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { Controller.shared.hide() }
                panel(size: rect.size)
                    .offset(x: rect.minX, y: rect.minY)
            }
            .allowsHitTesting(model.closingTint == nil)
        }
        .environment(\.styleTokens, StyleTokens.current)
    }

    private func panel(size: CGSize) -> some View {
        let shown = model.presented
        let closing = model.closingTint != nil
        let style = StyleTokens.current
        let reveal = settings.panelStyle.reveal
        let shape = RoundedRectangle(cornerRadius: PanelLayout.radius, style: .continuous)
        return VStack(spacing: 0) {
            header
                .environment(\.colorScheme, style.headerDark ? .dark : .light)
                .foregroundStyle(style.headerInk)
            // Mode focus : rien sous la barre de recherche tant qu'on n'a rien tapé.
            if !model.collapsed {
                Group {
                    StyleDivider()
                    ZStack {
                        content
                            .id(model.mode)
                            .transition(reveal.modeTransition(forward: model.forward))
                    }
                    .modifier(RootSwipeOffset(pager: model.pager, active: model.mode == .root))
                    // La page sortante ne doit pas imposer la grande taille de la grille au retour.
                    // Panneau en retrait : 8 pt de cadre de chaque côté (`styledPane` les ajoute autour).
                    .frame(width: size.width - (style.insetPane ? 16 : 0), height: max(0, size.height - 102),
                           alignment: .top)
                    .overlay(alignment: .trailing) {
                        if model.mode == .root { SwipeToAppsHint(pager: model.pager) }
                    }
                    .clipped()
                    .styledPane(style, panelRadius: PanelLayout.radius)
                    .environment(\.colorScheme, style.dark ? .dark : .light)
                    .foregroundStyle(style.ink)
                    StyleDivider()
                    footer
                        .environment(\.colorScheme, style.chromeDark ? .dark : .light)
                        .foregroundStyle(style.chromeInk)
                }
                .transition(.opacity)
            }
        }
        // Verre : le contenu se "met au point" juste après le verre, l'œil va droit au champ de recherche.
        .blur(radius: shown || model.lightReveal || reveal != .glass ? 0 : 8 * Motion.amplitude)
        .opacity(shown ? 1 : 0)
        .animation(shown && settings.animations && !model.lightReveal ? .easeOut(duration: 0.18).delay(0.02) : nil,
                   value: shown)
        .frame(width: size.width, height: size.height, alignment: .top)
        .clipShape(shape)
        .styledSurface(style, cornerRadius: PanelLayout.radius)
        // Verre : clair au début de la goutte (on voit le bureau net à travers le fumé), puis il se givre en grandissant.
        // Le givre suit l'élan de la goutte : un ressort qui part quand elle se pose (≈0,2 s). Réouverture rapide :
        // pas d'animation, le verre est givré tout de suite.
        .environment(\.glassFrost, GlassFrost(
            value: shown || reveal != .glass ? 1 : 0,
            animation: model.lightReveal ? nil : Motion.scaled(.spring(response: 0.22, dampingFraction: 0.9).delay(0.2))))
        .background {
            if let offset = style.hardShadow {
                // L'ombre pleine « atterrit » avec le panneau, et reste en place quand il s'enfonce dessus au lancement.
                let landed = shown ? offset : 0
                let shift: CGFloat = closing && reveal == .slam ? 6 : 0
                ZStack {
                    // Néo-brutal : une seconde ombre, de la couleur de sélection, claque puis rentre sous la noire.
                    if settings.panelStyle == .brutal {
                        StampShadow(trigger: model.revealID, color: style.selectionFill, radius: PanelLayout.radius,
                                    rest: offset)
                    }
                    shape.fill(style.hardShadowColor)
                        .offset(x: landed - shift, y: landed - shift)
                        .animation(Motion.scaled(reveal.close), value: closing)
                }
                .opacity(AppSettings.shared.shadowStrength)
            } else {
                PanelShadow(size: size, shape: shape)
            }
        }
        .overlay {
            OpeningEffect(style: settings.panelStyle, tokens: style, trigger: model.revealID, size: size,
                          radius: PanelLayout.radius, pill: CGRect(x: 8, y: 7, width: size.width - 16, height: 46),
                          underline: CGRect(x: 48, y: 47, width: min(size.width * 0.45, 360), height: 0),
                          mark: CGPoint(x: 29, y: 30))
        }
        .overlay {
            if model.dropTargeted && Hermes.available && model.mode == .root {
                shape.strokeBorder(style.accent, style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
                    .overlay(alignment: .bottom) {
                        Label("Lâche pour joindre à \(AgentEngine.assistant.name)", systemImage: "paperclip")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Capsule().fill(.regularMaterial))
                            .padding(.bottom, 52)
                    }
                    .allowsHitTesting(false)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $model.dropTargeted) { model.dropFiles($0) }
        .tint(style.accent)
        .modifier(PanelMotion(reveal: reveal, shown: shown, light: model.lightReveal,
                              closing: closing, revealID: model.revealID))
    }

    private var header: some View {
        let style = StyleTokens.current
        return HStack(spacing: 10) {
            if model.mode == .root {
                switch style.mark {
                case .logo:
                    AnimatedMark(skin: style.markSkin, trigger: model.revealID)
                        .frame(width: 22, height: 22)
                case .symbol(let name):
                    Image(systemName: name)
                        .font(.system(size: 18, weight: style.searchBar != nil ? .semibold : .medium))
                        .foregroundStyle(style.searchBar != nil ? .primary : .secondary)
                        .symbolEffect(.bounce.down, value: model.revealID)
                case .prompt(let prompt):
                    Text(prompt)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundStyle(style.accent)
                }
            } else {
                Button(action: model.back) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left").font(.system(size: 10, weight: .bold))
                        Image(systemName: model.mode.symbol)
                        Text(model.mode.title)
                    }
                    .font(style.font(12, .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.quaternary))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            // Pendant que Hermes travaille, la demande ; ensuite, le champ pour une question de suite.
            if model.mode == .agent, let agent = model.agent, agent.isThinking {
                Text(agent.request)
                    .font(style.font(16, .medium, title: true))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                if !agent.attachments.isEmpty {
                    Label("\(agent.attachments.count)", systemImage: "paperclip")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .help(agent.attachments.map(\.name).joined(separator: "\n"))
                }
                if agent.isThinking { ProgressView().controlSize(.small) }
            } else if model.mode == .output, let run = model.run {
                Text("$ " + run.command)
                    .font(.system(size: 15, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                RunStatus(run: run)
            } else {
                SearchField(text: $model.query, placeholder: model.placeholder)
                    .frame(height: 34)
                    // Invite dessinée par SwiftUI : celle d'AppKit, pendant l'édition, se décale avec certaines polices.
                    .background(alignment: .leading) {
                        if model.query.isEmpty {
                            Text(model.placeholder)
                                .font(Font(style.searchFont as CTFont))
                                .foregroundStyle(Color(nsColor: style.placeholderNSColor))
                                .lineLimit(1)
                                .padding(.leading, 2)
                                .allowsHitTesting(false)
                        }
                    }
                if model.mode == .emoji { FilterPicker(model: model) }
                if model.mode == .root {
                    if !model.attachments.isEmpty { AttachmentStrip(model: model) }
                    if Hermes.available && (model.query.isEmpty || !model.attachments.isEmpty) {
                        headerButton("paperclip", help: "Joindre des fichiers pour \(AgentEngine.assistant.name) (⌘O)") { model.pickFilesForAgent() }
                        headerButton("camera.viewfinder", help: "Capture d'écran pour \(AgentEngine.assistant.name) (⇧⌘S)") { model.captureForAgent() }
                    }
                    headerButton(Mode.apps.symbol, help: "Toutes les applications") { model.enter(.apps) }
                }
            }
        }
        // Material : barre de recherche en pilule (hauteur 46) posée dans l'en-tête.
        .padding(.leading, style.searchBar != nil ? 16 : 18)
        .padding(.trailing, style.searchBar != nil ? 6 : 18)
        .frame(height: style.searchBar != nil ? 46 : 60)
        .background { if let bar = style.searchBar { Capsule().fill(bar) } }
        .scaleEffect(x: style.searchBar != nil && !model.presented && Motion.enabled ? 1 - 0.12 * Motion.amplitude : 1)
        .animation(model.presented && !model.lightReveal
                   ? Motion.scaled(.spring(response: 0.5, dampingFraction: 0.66).delay(0.04)) : nil,
                   value: model.presented)
        .padding(.horizontal, style.searchBar != nil ? 8 : 0)
        .frame(height: 60)
        .background {
            if let tint = model.closingTint { SearchGlow(color: Color(nsColor: tint)) }
        }
    }

    private func headerButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        let style = StyleTokens.current
        return Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(style.iconButton.map { AnyShapeStyle($0.ink) } ?? AnyShapeStyle(.secondary))
                .frame(width: style.iconButton != nil ? 34 : 30, height: style.iconButton != nil ? 34 : 30)
                .background { if let button = style.iconButton { Circle().fill(button.fill) } }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    /// Contenu du mode, construit avec une copie de ses données (résultats, sélection) plutôt qu'en les relisant
    /// dans le modèle : pendant la transition, la vue qui s'en va garde les siennes. Sinon elle se redessinerait
    /// avec les résultats du nouveau mode (icônes chargées sur le fil principal en plein ressort → à-coup).
    @ViewBuilder private var content: some View {
        let mode = model.mode
        switch mode {
        case .emoji:
            GlyphGrid(model: model, glyphs: model.glyphs, selection: model.selection)
        case .apps:
            AppGrid(model: model, items: model.items, selection: model.selection)
        case .output:
            if let run = model.run { OutputView(run: run) }
        case .agent:
            // « / » dans le champ de question de suite : la liste des commandes remplace un instant la conversation.
            if model.query.hasPrefix("/") {
                ResultList(model: model, mode: mode, items: model.items, selection: model.selection, clickActivates: true)
            } else if let agent = model.agent {
                AgentView(run: agent)
            }
        case .clipboard, .colors, .stats:
            HStack(spacing: 0) {
                ResultList(model: model, mode: mode, items: model.items, selection: model.selection, clickActivates: false)
                    .frame(width: 300)
                StyleDivider(vertical: true)
                PreviewPane(model: model, mode: mode, item: model.selectedItem)
            }
        default:
            ResultList(model: model, mode: mode, items: model.items, selection: model.selection, clickActivates: true)
        }
    }

    private var footer: some View {
        let style = StyleTokens.current
        return HStack(spacing: 16) {
            Group {
                if let toast = model.toast {
                    Label(toast, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(style.toast)
                } else if model.mode == .emoji, let glyph = model.selectedGlyph {
                    Text(glyph.name).foregroundStyle(.primary)
                        + Text("   \(glyph.code)").foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
            .truncationMode(.tail)

            Spacer(minLength: 8)

            ForEach(settings.showHints ? model.hints : []) { hint in
                HStack(spacing: 6) {
                    Text(hint.label).foregroundStyle(hint.key == "↵" ? .primary : .secondary)
                        .tracking(style.chromeCaps ? 0.7 : 0)
                    KeyCap(hint.key, primary: hint.key == "↵")
                }
                .fixedSize()
            }
        }
        .textCase(style.chromeCaps ? .uppercase : nil)
        .font(style.chromeCaps ? .system(size: 11, weight: .medium).width(.condensed) : style.font(12))
        .padding(.horizontal, 16)
        .frame(height: 40)
    }
}

// MARK: - Liste

struct ResultList: View {
    @ObservedObject var model: LauncherModel
    let mode: Mode
    let items: [ResultItem]
    let selection: Int
    let clickActivates: Bool
    @Namespace private var selectionSpace

    var body: some View {
        let style = StyleTokens.current
        // Glyphe : les titres se décodent pendant l'ouverture complète (pas à la réouverture rapide).
        let decode = style.decodeTitles && Motion.enabled && AppSettings.shared.cascadeRows && !model.lightReveal
            ? model.revealDate : nil
        if items.isEmpty {
            EmptyState(text: mode.emptyText, symbol: mode.symbol)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            VStack(alignment: .leading, spacing: 2) {
                                if let section = item.section, index == 0 || items[index - 1].section != section {
                                    Text(style.sectionTitle(section))
                                        .font(style.sectionFont)
                                        .tracking(style.sectionTracking)
                                        .foregroundStyle(style.header == .emphasized ? .primary : .secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.bottom, style.sectionRule != nil ? 4 : 0)
                                        .overlay(alignment: .bottom) {
                                            if let rule = style.sectionRule {
                                                HRule().stroke(rule, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                                                    .frame(height: 1)
                                            }
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.top, index == 0 ? 2 : 10)
                                }
                                ResultRow(item: item, selected: index == selection,
                                          decodeStart: decode.map { $0.addingTimeInterval(RevealStyle.waveDelay(index) / Motion.speed) })
                                    .background {
                                        if let segmented = style.segmented {
                                            SegmentCard(card: segmented.card, outer: segmented.outer, inner: segmented.inner,
                                                        first: index == 0 || items[index - 1].section != item.section,
                                                        last: index == items.count - 1 || items[index + 1].section != item.section,
                                                        selected: index == selection, selectedRadius: style.rowRadius)
                                            if index == selection, model.closingTint != nil {
                                                SelectionFill(tint: model.closingTint, radius: style.rowRadius)
                                            }
                                        } else if index == selection {
                                            SelectionFill(tint: model.closingTint, radius: style.rowRadius)
                                                .matchedGeometryEffect(id: "selection", in: selectionSpace)
                                        }
                                    }
                                    .onTapGesture(count: 2) {
                                        model.selection = index
                                        model.activate(.primary)
                                    }
                                    .simultaneousGesture(TapGesture().onEnded {
                                        model.selection = index
                                        if clickActivates { model.activate(.primary) }
                                    })
                            }
                            .modifier(RevealItem(order: index, shown: model.presented, light: model.lightReveal))
                            .id(item.id)
                        }
                    }
                    .padding(8)
                    .animation(Motion.scaled(style.motion), value: selection)
                }
                .onChange(of: selection) { _, index in
                    guard items.indices.contains(index) else { return }
                    proxy.scrollTo(items[index].id)
                }
            }
        }
    }
}

struct ResultRow: View {
    let item: ResultItem
    let selected: Bool
    /// Début du décodage du titre (Glyphe) ; nil : titre affiché tel quel.
    var decodeStart: Date? = nil

    var body: some View {
        let style = StyleTokens.current
        HStack(spacing: 11) {
            if let checked = item.checked {
                Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(checked ? Color.red : Color.secondary)
            }
            let density = AppSettings.shared.rowDensity
            ItemIconView(icon: item.icon).frame(width: density.iconSize, height: density.iconSize)
                .opacity(item.checked == false ? 0.45 : 1)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    if selected && style.blinkingCursor { BlinkingCursor(height: 14 * style.textScale) }
                    DecodeText(text: item.title, start: decodeStart)
                        .font(style.titleFont)
                        .lineLimit(1)
                }
                if let subtitle = item.subtitle, AppSettings.shared.showSubtitles, density != .compact {
                    Text(subtitle)
                        .font(style.font(11.5 * style.textScale))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 8)
            if let accessory = item.accessory, AppSettings.shared.showAccessories || accessory == "Ouverte" {
                HStack(spacing: 5) {
                    if accessory == "Ouverte" {
                        Circle().fill(selected && style.selectionInk != nil ? AnyShapeStyle(.primary) : AnyShapeStyle(style.live))
                            .frame(width: 5, height: 5)
                    }
                    Text(accessory)
                }
                .font(style.font(11, style.strongMeta ? .medium : .regular))
                .foregroundStyle(selected || style.strongMeta ? .secondary : .tertiary)
            }
        }
        .environment(\.rowSelected, selected)
        .modifier(InkOverride(color: selected ? style.selectionInk : nil))
        .padding(.horizontal, 10)
        .frame(height: AppSettings.shared.rowDensity.rowHeight)
        .contentShape(Rectangle())
    }
}

struct ItemIconView: View {
    let icon: ItemIcon
    @Environment(\.styleTokens) private var style

    var body: some View {
        switch icon {
        case .file(let path):
            Image(nsImage: IconCache.icon(path)).resizable().interpolation(.high).styledIcon(style)
        case .symbol(let name, let tint):
            SymbolTile(name: name, tint: tint)
        case .color(let color):
            Circle()
                .fill(Color(nsColor: color))
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.2), lineWidth: 1))
                .padding(3)
        case .image(let url):
            Thumbnail(url: url, pixels: 64, fill: true)
                .frame(width: 26, height: 26)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
    }
}

// MARK: - Grille d'applications

/// Toutes les apps en grandes icônes, par pages. Le défilement est piloté par le modèle (trackpad, molette,
/// clavier, points) : chaque page est posée à son décalage et seules la page affichée et ses voisines sont rendues.
struct AppGrid: View {
    @ObservedObject var model: LauncherModel
    let items: [ResultItem]
    let selection: Int
    @Namespace private var selectionSpace

    var body: some View {
        if items.isEmpty {
            EmptyState(text: Mode.apps.emptyText, symbol: Mode.apps.symbol)
        } else {
            let perPage = model.appsPerPage
            let pages = max(1, (items.count + perPage - 1) / perPage)
            let visible = model.appPageRange.clamped(to: 0...(pages - 1))
            VStack(spacing: 0) {
                GeometryReader { geo in
                    ZStack(alignment: .topLeading) {
                        ForEach(Array(visible), id: \.self) { index in
                            AppPage(model: model, items: items, selection: selection, page: index,
                                    selectionSpace: selectionSpace)
                                .frame(width: geo.size.width, height: geo.size.height)
                                .offset(x: CGFloat(index) * geo.size.width)
                        }
                    }
                    .modifier(AppPagerOffset(pager: model.pager, width: geo.size.width))
                }
                .clipped()

                PageDots(count: pages, current: model.appPage) { index in
                    model.selection = min(index * perPage, items.count - 1)
                }
                .frame(height: 28)
            }
        }
    }
}

/// Accueil : la liste recule un peu pendant le balayage vers la grille.
struct RootSwipeOffset: ViewModifier {
    @ObservedObject var pager: PagerState
    let active: Bool

    func body(content: Content) -> some View {
        content.offset(x: active ? -min(pager.rootSwipe, 1.4) * 34 : 0)
    }
}

/// Accueil : la grille d'applications « arrive » par la droite pendant le balayage.
struct SwipeToAppsHint: View {
    @ObservedObject var pager: PagerState

    var body: some View {
        if pager.rootSwipe > 0 { hint(pager.rootSwipe) }
    }

    private func hint(_ progress: CGFloat) -> some View {
        let p = min(progress, 1)
        let ready = progress >= 1
        return VStack(spacing: 6) {
            Image(systemName: Mode.apps.symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(ready ? Color.white : Color.primary)
                .frame(width: 44, height: 44)
                .background(Circle().fill(ready ? Color.accentColor : Color.primary.opacity(0.12)))
                .scaleEffect(ready ? 1.08 : 0.8 + 0.2 * p)
            Text("Applications")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .opacity(Double(p))
        .offset(x: (1 - p) * 30)
        .padding(.trailing, 16)
        .animation(.snappy(duration: 0.15), value: ready)
        .allowsHitTesting(false)
    }
}

struct AppPage: View {
    @ObservedObject var model: LauncherModel
    let items: [ResultItem]
    let selection: Int
    let page: Int
    let selectionSpace: Namespace.ID

    var body: some View {
        let columns = model.appColumns
        let perPage = model.appsPerPage
        let rows = perPage / columns
        let start = page * perPage
        // La page peut survivre un instant à ses apps (réouverture qui repart de la racine, recherche qui
        // réduit la liste, page en cours de retrait) : elle s'affiche alors vide au lieu de lire hors limites.
        let end = min(start + perPage, items.count)
        let slice = start < end ? Array(items[start..<end].enumerated()) : []

        GeometryReader { geo in
            let cell = CGSize(width: geo.size.width / CGFloat(columns), height: geo.size.height / CGFloat(rows))
            // Taille continue : pendant l'agrandissement du panneau, les icônes grandissent avec lui.
            let iconSize = max(12, min(cell.width * 0.76, cell.height - 30, 112))
            // Une page entière est préparée avant de glisser : aucune case créée pendant le swipe.
            VStack(alignment: .leading, spacing: 0) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(slice.filter { $0.offset / columns == row }, id: \.element.id) { offset, item in
                            let index = start + offset
                            AppCell(item: item, size: cell, iconSize: iconSize, selected: index == selection)
                                .background {
                                    if index == selection {
                                        SelectionFill(tint: model.closingTint, radius: StyleTokens.current.cellRadius)
                                            .padding(4)
                                            // Le surlignage reste dans sa page pendant le glissement.
                                            .matchedGeometryEffect(id: "selection-\(page)", in: selectionSpace)
                                    }
                                }
                                .onTapGesture {
                                    model.selection = index
                                    model.activate(.primary)
                                }
                                .contextMenu {
                                    ForEach(Array([item.primary, item.secondary, item.tertiary, item.remove]
                                        .compactMap { $0 }.enumerated()), id: \.offset) { _, action in
                                        Button(action.title) {
                                            model.selection = index
                                            action.run()
                                        }
                                    }
                                }
                                .help(item.subtitle ?? item.title)
                                .modifier(SpringboardReveal(column: offset % columns, row: offset / columns,
                                                            columns: columns, rows: rows, revealed: model.appsRevealed))
                                .modifier(RevealItem(order: offset / columns, shown: model.presented, light: model.lightReveal))
                        }
                    }
                }
            }
        }
        // Animations limitées à l'intérieur de la page (surlignage, icônes qui arrivent) : posées plus haut,
        // elles écraseraient le ressort du changement de page.
        .animation(Motion.scaled(StyleTokens.current.motion), value: selection)
        .animation(.easeOut(duration: 0.2), value: model.iconsLoaded)
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .blur(radius: model.appsRevealed ? 0 : 10)
        .animation(AppSettings.shared.animations ? .easeOut(duration: model.appsRevealed ? 0.38 : 0.14) : nil,
                   value: model.appsRevealed)
    }
}

/// Arrivée des icônes façon iPhone : elles viennent de l'extérieur, grossies et floues, et se posent
/// en cascade du centre vers les bords. En sortie, le mouvement inverse.
struct SpringboardReveal: ViewModifier {
    let column: Int
    let row: Int
    let columns: Int
    let rows: Int
    let revealed: Bool

    func body(content: Content) -> some View {
        let dx = CGFloat(column) - CGFloat(columns - 1) / 2
        let dy = CGFloat(row) - CGFloat(rows - 1) / 2
        let distance = Double(hypot(dx, dy))
        content
            .scaleEffect(revealed ? 1 : 1.45)
            .offset(x: revealed ? 0 : dx * 26, y: revealed ? 0 : dy * 26)
            .opacity(revealed ? 1 : 0)
            .animation(AppSettings.shared.animations
                       ? (revealed ? .spring(response: 0.5, dampingFraction: 0.78).delay(0.06 + distance * 0.035)
                                   : .easeIn(duration: 0.16))
                       : nil,
                       value: revealed)
    }
}

struct AppCell: View {
    let item: ResultItem
    let size: CGSize
    let iconSize: CGFloat
    let selected: Bool
    /// Survol propre à chaque case : seules les deux cases concernées se redessinent quand la souris passe
    /// de l'une à l'autre (un état partagé redessinait toute la grille, y compris pendant le glissement des pages).
    @StateObject private var hover = CellHover()
    /// L'icône, gardée par la case une fois chargée : le cache peut l'évincer (pression mémoire) sans que la case
    /// redevienne vide ; une case qui n'en a pas la demande elle-même.
    @StateObject private var icon = CellIcon()

    var body: some View {
        let raised = selected || hover.inside
        let style = StyleTokens.current
        VStack(spacing: 7) {
            Group {
                if case .file(let path) = item.icon {
                    // Pas encore chargée : emplacement discret, l'icône apparaît en fondu.
                    if let image = icon.image ?? IconCache.cachedIcon(path, large: true) {
                        Image(nsImage: image).resizable().interpolation(.high)
                            .styledIcon(style)
                            .transition(.opacity)
                    } else {
                        RoundedRectangle(cornerRadius: iconSize * 0.22, style: .continuous)
                            .fill(.quinary)
                            .padding(iconSize * 0.08)
                    }
                } else {
                    ItemIconView(icon: item.icon)
                }
            }
            .frame(width: iconSize, height: iconSize)
            // Ombre seulement sous l'icône soulevée : des dizaines d'ombres qui glissent coûtent cher à chaque image.
            .background {
                if raised {
                    RoundedRectangle(cornerRadius: iconSize * 0.24, style: .continuous)
                        .fill(Color.black.opacity(0.45))
                        .padding(iconSize * 0.12)
                        .blur(radius: 9)
                        .offset(y: 7)
                        .transition(.opacity)
                }
            }
            .scaleEffect(raised ? 1.08 : 1)
            .offset(y: raised ? -3 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.62), value: raised)

            HStack(spacing: 4) {
                if item.accessory == "Ouverte" {
                    Circle().fill(selected && style.selectionInk != nil ? AnyShapeStyle(.primary) : AnyShapeStyle(style.live))
                        .frame(width: 4, height: 4)
                }
                Text(item.title)
                    .font(style.font(12, style.titleWeight, title: true))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .modifier(InkOverride(color: selected ? style.selectionInk : nil))
            .padding(.horizontal, 6)
        }
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
        .onAppear {
            if case .file(let path) = item.icon { icon.load(path) }
        }
        .onHover { inside in
            // Pages en mouvement : les cases qui défilent sous la souris ne se soulèvent pas au passage.
            let inside = inside && !PagerState.isMoving
            if hover.inside != inside { hover.inside = inside }
        }
    }
}

/// Icône d'une case de la grille (@State n'est pas disponible sans Xcode complet).
final class CellIcon: ObservableObject {
    @Published private(set) var image: NSImage?
    private var path: String?

    func load(_ path: String) {
        guard self.path != path || image == nil else { return }
        self.path = path
        IconCache.requestLarge(path) { [weak self] image in
            guard let self, self.path == path else { return }
            withAnimation(.easeOut(duration: 0.2)) { self.image = image }
        }
    }
}

/// Survol d'une case de la grille (@State n'est pas disponible sans Xcode complet).
final class CellHover: ObservableObject {
    @Published var inside = false
}

/// Surlignage de la sélection. À l'ouverture d'une app, il prend sa couleur et rayonne.
struct SelectionFill: View {
    let tint: NSColor?
    let radius: CGFloat
    @Environment(\.styleTokens) private var style

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if let tint {
            let color = Color(nsColor: tint)
            let neighbour = Color(nsColor: tint.shiftingHue(by: 0.06))
            shape
                .fill(LinearGradient(colors: [color.opacity(0.85), neighbour.opacity(0.55)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(shape.strokeBorder(Color.white.opacity(0.45), lineWidth: 1))
                .shadow(color: color.opacity(0.75), radius: 16)
                .transition(.opacity)
        } else {
            ZStack(alignment: .leading) {
                if let offset = style.selectionHardShadow { shape.fill(Color.black).offset(x: offset, y: offset) }
                shape.fill(style.selectionFill)
                if let border = style.selectionBorder { shape.strokeBorder(border, lineWidth: 2) }
                if let bar = style.selectionBar {
                    Capsule().fill(bar).frame(width: 3).padding(.vertical, 10).padding(.leading, 3)
                }
            }
        }
    }
}

/// Carte d'une liste segmentée (Material 3 Expressive) : coins larges aux bords du groupe, serrés entre
/// les lignes. Sélectionnée, elle se remplit et s'arrondit en pilule (les rayons s'animent avec le ressort).
struct SegmentCard: View {
    let card: Color
    let outer: CGFloat
    let inner: CGFloat
    let first: Bool
    let last: Bool
    let selected: Bool
    let selectedRadius: CGFloat
    @Environment(\.styleTokens) private var style

    var body: some View {
        let top = selected ? selectedRadius : (first ? outer : inner)
        let bottom = selected ? selectedRadius : (last ? outer : inner)
        UnevenRoundedRectangle(topLeadingRadius: top, bottomLeadingRadius: bottom,
                               bottomTrailingRadius: bottom, topTrailingRadius: top, style: .continuous)
            .fill(selected ? style.selectionFill : card)
    }
}

/// Texte d'un élément sélectionné quand le style le recolore (sélection pleine, vidéo inverse…).
struct InkOverride: ViewModifier {
    let color: Color?

    func body(content: Content) -> some View {
        if let color { content.foregroundStyle(color) } else { content }
    }
}

/// Séparateur aux couleurs du style.
struct StyleDivider: View {
    var vertical = false
    @Environment(\.styleTokens) private var style

    var body: some View {
        Rectangle()
            .fill(style.divider)
            .frame(width: vertical ? 1 : nil, height: vertical ? nil : 1)
    }
}

/// Barre de recherche à l'ouverture d'une app : une bande lumineuse de sa couleur derrière le champ.
struct SearchGlow: View {
    let color: Color

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        shape
            .fill(LinearGradient(colors: [color.opacity(0.55), color.opacity(0.18)], startPoint: .leading, endPoint: .trailing))
            .overlay(shape.strokeBorder(color.opacity(0.8), lineWidth: 1))
            .shadow(color: color.opacity(0.6), radius: 14)
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .transition(.opacity)
            .allowsHitTesting(false)
    }
}

/// Ombre du panneau, dessinée par SwiftUI (la fenêtre n'a plus d'ombre système) : elle suit le panneau
/// quand il grandit, sans recalcul côté serveur de fenêtres. Masquée sous le verre pour ne pas l'assombrir.
/// Rendue une seule fois en image « 9 parts » qui s'étire : avant, le flou (sur toute la taille du panneau et son
/// débordement) était recalculé à chaque image de l'agrandissement vers les applications et du repli des résultats.
struct PanelShadow: View {
    let size: CGSize
    let shape: RoundedRectangle

    static let bleed: CGFloat = 110

    var body: some View {
        let radius = PanelLayout.radius
        // Bords de l'image jamais étirés : débordement + coin arrondi + étalement du flou (24) et décalage (16).
        let cap = Self.bleed + radius + 88
        // Panneau plus petit que deux coins (un seul résultat, mode focus) : les coins de l'image se chevaucheraient
        // et le creux sous le panneau se décalerait (bordure claire). On dessine alors l'ombre directement.
        let fits = min(size.width, size.height) + 2 * Self.bleed >= 2 * cap + 2
        Group {
            if fits, let image = Self.image(radius: radius) {
                Image(nsImage: image)
                    .resizable(capInsets: EdgeInsets(top: cap, leading: cap, bottom: cap, trailing: cap))
            } else {
                PanelShadowDrawing(size: size, shape: shape).drawingGroup()
            }
        }
        // Plus grande que le panneau : centrée sur lui, elle déborde de `bleed` de chaque côté.
        .frame(width: size.width + 2 * Self.bleed, height: size.height + 2 * Self.bleed)
        .opacity(AppSettings.shared.shadowStrength)
        .allowsHitTesting(false)
    }

    /// Une image par arrondi (rendue une fois, au premier affichage avec cet arrondi).
    @MainActor private static var images: [CGFloat: NSImage] = [:]

    @MainActor private static func image(radius: CGFloat) -> NSImage? {
        if let cached = images[radius] { return cached }
        let side = 2 * (radius + 88) + 2
        let drawing = PanelShadowDrawing(size: CGSize(width: side, height: side),
                                         shape: RoundedRectangle(cornerRadius: radius, style: .continuous))
        let renderer = ImageRenderer(content: drawing)
        renderer.scale = 2
        let image = renderer.nsImage
        images[radius] = image
        return image
    }
}

/// Deux flous sous la forme du panneau, évidés là où se trouve le verre.
struct PanelShadowDrawing: View {
    let size: CGSize
    let shape: RoundedRectangle

    var body: some View {
        ZStack {
            shape.fill(Color.black.opacity(0.38)).blur(radius: 24).offset(y: 16)
            shape.fill(Color.black.opacity(0.22)).blur(radius: 3).offset(y: 1)
        }
        .frame(width: size.width, height: size.height)
        .padding(PanelShadow.bleed)
        .mask {
            ZStack {
                Rectangle()
                shape.frame(width: size.width, height: size.height).blendMode(.destinationOut)
            }
            .compositingGroup()
        }
    }
}

extension NSColor {
    func shiftingHue(by delta: CGFloat) -> NSColor {
        guard let rgb = usingColorSpace(.sRGB) else { return self }
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        rgb.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return NSColor(hue: (h + delta).truncatingRemainder(dividingBy: 1), saturation: s, brightness: b, alpha: a)
    }
}

struct PageDots: View {
    let count: Int
    let current: Int
    let select: (Int) -> Void

    var body: some View {
        if count > 1 {
            HStack(spacing: 8) {
                ForEach(0..<count, id: \.self) { index in
                    Circle()
                        .fill(StyleTokens.current.ink.opacity(index == current ? 0.85 : 0.25))
                        .frame(width: 7, height: 7)
                        .padding(3)
                        .contentShape(Rectangle())
                        .onTapGesture { select(index) }
                }
            }
            .animation(.snappy(duration: 0.2), value: current)
        }
    }
}

// MARK: - Emoji

struct FilterPicker: View {
    @ObservedObject var model: LauncherModel

    var body: some View {
        HStack(spacing: 2) {
            ForEach(GlyphFilter.allCases, id: \.self) { filter in
                Text(filter.title)
                    .font(.system(size: 11.5, weight: .medium))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background {
                        if filter == model.glyphFilter { Capsule().fill(.quaternary) }
                    }
                    .foregroundStyle(filter == model.glyphFilter ? .primary : .secondary)
            }
        }
        .padding(2)
        .background(Capsule().fill(.quinary))
    }
}

struct GlyphGrid: View {
    @ObservedObject var model: LauncherModel
    let glyphs: [Glyph]
    let selection: Int
    @Namespace private var selectionSpace

    var body: some View {
        if glyphs.isEmpty {
            EmptyState(text: Mode.emoji.emptyText, symbol: "face.dashed")
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: model.gridColumns),
                              spacing: 4) {
                        ForEach(Array(glyphs.enumerated()), id: \.element.id) { index, glyph in
                            Text(glyph.char)
                                .font(.system(size: glyph.isEmoji ? 30 : 24))
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .modifier(InkOverride(color: index == selection ? StyleTokens.current.selectionInk : nil))
                                .background {
                                    if index == selection {
                                        SelectionFill(tint: nil, radius: StyleTokens.current.rowRadius == 22 ? 18 : StyleTokens.current.rowRadius)
                                            .matchedGeometryEffect(id: "selection", in: selectionSpace)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    model.selection = index
                                    model.activate(.primary)
                                }
                                .help(glyph.name)
                                .modifier(RevealItem(order: index / model.gridColumns, shown: model.presented, light: model.lightReveal))
                                .id(glyph.id)
                        }
                    }
                    .padding(10)
                    .animation(Motion.scaled(StyleTokens.current.motion), value: selection)
                }
                .onChange(of: selection) { _, index in
                    guard glyphs.indices.contains(index) else { return }
                    proxy.scrollTo(glyphs[index].id)
                }
            }
        }
    }
}

// MARK: - Aperçus

struct PreviewPane: View {
    let model: LauncherModel
    let mode: Mode
    let item: ResultItem?

    var body: some View {
        Group {
            switch item?.preview ?? .empty {
            case .clip(let entry): ClipPreview(entry: entry)
            case .color(let color): ColorPreview(color: color, model: model)
            case .stats(let id): StatsPreview(id: id, model: model)
            case .empty:
                EmptyState(text: mode == .colors ? "↵ pour capturer une couleur à l'écran" : "", symbol: mode.symbol)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ClipPreview: View {
    let entry: ClipEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                switch entry.kind {
                case .text:
                    ScrollView {
                        Text(String((entry.text ?? "").prefix(20_000)))
                            .font(.system(size: 12.5, design: entry.looksLikeCode ? .monospaced : .default))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(16)
                    }
                case .image:
                    if let url = entry.imageURL {
                        Thumbnail(url: url, pixels: 1200)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .padding(16)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                case .files:
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(entry.files ?? [], id: \.self) { path in
                                HStack(spacing: 8) {
                                    Image(nsImage: IconCache.icon(path)).resizable().frame(width: 20, height: 20)
                                    Text(Shell.abbreviate(path)).lineLimit(1).truncationMode(.middle)
                                }
                            }
                        }
                        .font(.system(size: 12))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            StyleDivider()
            VStack(alignment: .leading, spacing: 5) {
                MetaRow(label: "Source", value: entry.source ?? "—")
                MetaRow(label: "Copié", value: entry.date.formatted(date: .abbreviated, time: .shortened))
                MetaRow(label: "Contenu", value: entry.detail)
            }
            .padding(14)
        }
    }
}

struct StatsPreview: View {
    let id: String
    let model: LauncherModel

    var body: some View {
        let record = Usage.records[id]
        let info = model.statsName(id)
        let days = Usage.daily(id, days: 14)
        let peak = max(days.max() ?? 1, 1)

        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                if let icon = info?.icon { ItemIconView(icon: icon).frame(width: 40, height: 40) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(info?.name ?? "").font(.system(size: 16, weight: .semibold))
                    Text("Score de frécence : \(Int(Usage.frecency(id)))")
                        .font(.system(size: 11.5)).foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                StatTile(value: "\(record?.count ?? 0)", label: "au total")
                StatTile(value: "\(Usage.launches(id, inLast: 7))", label: "7 jours")
                StatTile(value: "\(Usage.launches(id, inLast: 30))", label: "30 jours")
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("14 derniers jours").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(days.enumerated()), id: \.offset) { index, count in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(index == days.count - 1 ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                            .frame(height: count == 0 ? 2 : max(4, 56 * CGFloat(count) / CGFloat(peak)))
                            .frame(maxWidth: .infinity)
                            .help("\(count) ouverture(s)")
                    }
                }
                .frame(height: 56, alignment: .bottom)
            }

            let shortcuts = Usage.shortcuts(id, limit: 5)
            if !shortcuts.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Raccourcis appris").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        ForEach(shortcuts, id: \.self) { s in
                            Text(s)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Capsule().fill(.quaternary))
                        }
                    }
                }
            }

            Spacer()
            if let record {
                MetaRow(label: "Première utilisation", value: record.first.formatted(date: .abbreviated, time: .omitted))
                MetaRow(label: "Dernière utilisation", value: record.last.formatted(date: .abbreviated, time: .shortened))
            }
        }
        .padding(18)
    }
}

struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 20, weight: .semibold, design: .rounded)).monospacedDigit()
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.quinary))
    }
}

struct MetaRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).lineLimit(1)
        }
        .font(.system(size: 11.5))
    }
}

struct ColorPreview: View {
    let color: StoredColor
    let model: LauncherModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: color.nsColor))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))
                .frame(height: 120)
                .padding(.bottom, 6)
            ForEach(color.formats) { format in
                Button {
                    Paster.copy(format.value)
                    model.flash("\(format.value) copié")
                } label: {
                    HStack {
                        Text(format.name).foregroundStyle(.secondary).frame(width: 64, alignment: .leading)
                        Text(format.value).font(.system(size: 12, design: .monospaced)).lineLimit(1)
                        Spacer()
                        Image(systemName: "doc.on.doc").foregroundStyle(.tertiary)
                    }
                    .font(.system(size: 12))
                    .padding(.vertical, 5)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(18)
    }
}

// MARK: - Terminal

struct OutputView: View {
    @ObservedObject var run: ShellRun

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Group {
                    if run.isEmpty {
                        Text(run.running ? "…" : "(aucune sortie)").foregroundStyle(.secondary)
                    } else {
                        Text(run.rendered)
                    }
                }
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                Color.clear.frame(height: 1).id("bottom")
            }
            .onChange(of: run.rendered) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
        }
    }
}

struct AgentView: View {
    @ObservedObject var run: AgentRun

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(run.earlier) { turn in
                        PastTurn(turn: turn)
                        StyleDivider()
                    }
                    if !run.isThinking || !run.earlier.isEmpty {
                        Text(run.request)
                            .font(.system(size: 14.5, weight: .semibold))
                            .textSelection(.enabled)
                    }
                    HStack(spacing: 8) {
                        levelBadge
                        ForEach(run.attachments) { attachment in
                            AttachmentThumb(attachment: attachment, size: 22)
                        }
                    }
                    switch run.phase {
                    case .thinking:
                        status("sparkles", .purple, "\(run.modelLabel) \(run.stage)…")
                        stepList(running: true)
                        elapsed
                    case .streaming(let text):
                        status("sparkles", .purple, "\(run.modelLabel) répond…")
                        stepList(running: true)
                        MarkdownText(text: text)
                        elapsed
                    case .done(let summary):
                        status("checkmark.circle.fill", .green, "Fait")
                        MarkdownText(text: summary)
                        stepList(running: false)
                        if !run.details.isEmpty { promptBox(run.details) }
                    case .answer(let text):
                        status("text.bubble.fill", .blue, "Réponse de \(run.modelLabel)")
                        MarkdownText(text: text)
                    case .escalate(let prompt):
                        status("arrow.up.right.circle.fill", .orange, "Demande trop complexe pour le niveau rapide")
                        Text("↵ pour la passer en Recherche & Action (\(AgentLevel.work.modelLabel)), "
                             + "⌘↵ pour une session de code dans \(Shell.terminal.name).")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                        promptBox(prompt)
                    case .delegated(let prompt):
                        status("arrow.up.forward.app.fill", .purple,
                               "Envoyé à \(AgentLevel.code.modelLabel) dans \(Shell.terminal.name)")
                        promptBox(prompt)
                    case .failed(let message):
                        status("exclamationmark.triangle.fill", .orange, "\(run.engine.title) n'a pas pu répondre")
                        Text(message).font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    Color.clear.frame(height: 1).id("end")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .onChange(of: streamLength) { _, _ in proxy.scrollTo("end", anchor: .bottom) }
            // Conversation rouverte ou question de suite : on arrive sur le dernier échange.
            .onAppear { if !run.earlier.isEmpty { proxy.scrollTo("end", anchor: .bottom) } }
        }
    }

    private var streamLength: Int {
        if case .streaming(let text) = run.phase { return text.count }
        return run.steps.count
    }

    /// Ce que Hermes a fait (commandes, clics, lectures) ; la dernière étape tourne tant qu'il travaille.
    @ViewBuilder private func stepList(running: Bool) -> some View {
        if !run.steps.isEmpty {
            let shown = Array(run.steps.suffix(8).enumerated())
            let hidden = run.steps.count - shown.count
            VStack(alignment: .leading, spacing: 5) {
                if hidden > 0 {
                    Text("+ \(hidden) étape\(hidden > 1 ? "s" : "") avant").foregroundStyle(.tertiary)
                }
                ForEach(shown, id: \.offset) { index, step in
                    let current = running && index == shown.count - 1
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Image(systemName: current ? "circle.dotted" : "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(current ? AnyShapeStyle(.purple) : AnyShapeStyle(.tertiary))
                            .symbolEffect(.pulse, isActive: current)
                        Text(step)
                            .font(step.hasPrefix("$ ") ? .system(size: 11.5, design: .monospaced) : .system(size: 12))
                            .foregroundStyle(current ? .primary : .secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
            .font(.system(size: 12))
        }
    }

    private var levelBadge: some View {
        Label(run.isThinking && run.stage == "choisit le niveau" ? "Auto · choix du niveau…"
              : "Niveau \(run.level.rawValue) · \(run.level.title)",
              systemImage: run.level.symbol)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(run.level.tint)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(run.level.tint.opacity(0.14)))
    }

    private var elapsed: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { context in
            Text(String(format: "%.1f s", context.date.timeIntervalSince(run.startedAt)))
                .font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
        }
    }

    private func status(_ symbol: String, _ tint: Color, _ text: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(tint)
    }

    private func promptBox(_ prompt: String) -> some View {
        Text(prompt)
            .font(.system(size: 12.5))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.quinary))
    }
}

/// Échange précédent d'une conversation : la demande, puis la réponse, en plus discret que l'échange en cours.
struct PastTurn: View {
    let turn: ChatTurn

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(turn.request).font(.system(size: 13.5, weight: .semibold))
                Spacer(minLength: 8)
                Label(turn.agentLevel.title, systemImage: turn.agentLevel.symbol)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(turn.agentLevel.tint)
            }
            if turn.kind == .code {
                Label("Envoyé à une session de code dans le terminal", systemImage: "arrow.up.forward.app")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            } else {
                MarkdownText(text: turn.answer).opacity(0.8)
            }
        }
        .textSelection(.enabled)
    }
}

/// Pièces jointes dans la barre de recherche : vignettes, avec une croix pour en retirer une.
struct AttachmentStrip: View {
    @ObservedObject var model: LauncherModel

    var body: some View {
        HStack(spacing: 6) {
            ForEach(model.attachments.suffix(4)) { attachment in
                AttachmentThumb(attachment: attachment, size: 30)
                    .overlay(alignment: .topTrailing) {
                        Button { model.detach(attachment) } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .black.opacity(0.65))
                        }
                        .buttonStyle(.plain)
                        .offset(x: 5, y: -5)
                        .help("Retirer")
                    }
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
            if model.attachments.count > 4 {
                Text("+\(model.attachments.count - 4)").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            }
        }
        .animation(Motion.scaled(.spring(response: 0.3, dampingFraction: 0.7)), value: model.attachments)
    }
}

struct AttachmentThumb: View {
    let attachment: Attachment
    let size: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
        Image(nsImage: attachment.thumbnail)
            .resizable()
            .aspectRatio(contentMode: attachment.isImage ? .fill : .fit)
            .frame(width: size, height: size)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5))
            .help(attachment.isScreenshot ? "Capture d'écran" : attachment.url.path)
    }
}

/// Markdown simple rendu ligne par ligne : titres, listes, citations, blocs de code, liens et styles en ligne.
struct MarkdownText: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .heading(let level, let content):
                    Text(inline(content))
                        .font(.system(size: level == 1 ? 17 : level == 2 ? 15 : 14, weight: .bold))
                        .padding(.top, 4)
                case .bullet(let marker, let content):
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(marker).foregroundStyle(.secondary)
                        Text(inline(content))
                    }
                case .quote(let content):
                    Text(inline(content))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 10)
                        .overlay(alignment: .leading) { Rectangle().fill(Color.secondary.opacity(0.4)).frame(width: 2) }
                case .code(let content):
                    Text(content)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.quinary))
                case .paragraph(let content):
                    Text(inline(content))
                }
            }
        }
        .font(.system(size: 13.5))
        .textSelection(.enabled)
        .tint(.cyan)
    }

    private enum Block {
        case heading(Int, String), bullet(String, String), quote(String), code(String), paragraph(String)
    }

    private var blocks: [Block] {
        var out: [Block] = []
        var code: [String]?
        for raw in text.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("```") {
                if let lines = code { out.append(.code(lines.joined(separator: "\n"))); code = nil } else { code = [] }
                continue
            }
            if code != nil { code?.append(raw); continue }
            if line.isEmpty { continue }
            if line.hasPrefix("#") {
                let level = line.prefix { $0 == "#" }.count
                out.append(.heading(level, line.dropFirst(level).trimmingCharacters(in: .whitespaces)))
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("• ") {
                out.append(.bullet("•", String(line.dropFirst(2))))
            } else if let dot = line.firstIndex(of: "."), line[..<dot].allSatisfy(\.isNumber), !line[..<dot].isEmpty,
                      line[line.index(after: dot)...].hasPrefix(" ") {
                out.append(.bullet(String(line[...dot]), line[line.index(after: dot)...].trimmingCharacters(in: .whitespaces)))
            } else if line.hasPrefix(">") {
                out.append(.quote(line.dropFirst().trimmingCharacters(in: .whitespaces)))
            } else {
                out.append(.paragraph(line))
            }
        }
        if let lines = code { out.append(.code(lines.joined(separator: "\n"))) }
        return out
    }

    private func inline(_ s: String) -> AttributedString {
        (try? AttributedString(markdown: s, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(s)
    }
}

struct RunStatus: View {
    @ObservedObject var run: ShellRun

    var body: some View {
        if run.running {
            ProgressView().controlSize(.small)
        } else if let status = run.status {
            Label((status == 0 ? "OK" : "Code \(status)") + " · " + run.elapsed,
                  systemImage: status == 0 ? "checkmark.circle.fill" : "xmark.octagon.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(status == 0 ? .green : .red)
        }
    }
}

// MARK: - Animations

struct SweepValues {
    var angle = Angle.degrees(-40)
    var opacity = 0.0
}

/// Le « halo » : un reflet aux couleurs de l'icône fait le tour du bord à l'ouverture, puis s'éteint.
/// Dure 0,8 s ; ensuite les calques (dont un flou de la taille du panneau) sont retirés de l'arbre
/// pour ne rien coûter pendant la frappe.
struct HaloSweep: View {
    let trigger: Int
    let size: CGSize
    let radius: CGFloat
    /// Couleurs du reflet (celles du style) ; nil : pas de reflet.
    let colors: [Color]?

    var body: some View {
        if AppSettings.shared.haloSweep && AppSettings.shared.animations, let colors {
            Color.clear
                .frame(width: size.width, height: size.height)
                .keyframeAnimator(initialValue: SweepValues(), trigger: trigger) { view, value in
                    view.overlay {
                        if value.opacity > 0.001 { sweep(value, colors: colors) }
                    }
                } keyframes: { _ in
                    // Départ rapide puis décélération : le reflet « claque » et s'éteint vite (~0,6 s).
                    KeyframeTrack(\.angle) {
                        SpringKeyframe(.degrees(250), duration: 0.62, spring: .init(response: 0.5, dampingRatio: 1))
                    }
                    KeyframeTrack(\.opacity) {
                        LinearKeyframe(1, duration: 0.06)
                        LinearKeyframe(1, duration: 0.2)
                        CubicKeyframe(0, duration: 0.34)
                    }
                }
                .allowsHitTesting(false)
        }
    }

    private nonisolated func sweep(_ value: SweepValues, colors: [Color]) -> some View {
        let diagonal = hypot(size.width, size.height)
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let gradient = AngularGradient(colors: [.clear, .clear] + colors + [.clear], center: .center)
        let ring = Circle()
            .fill(gradient)
            .frame(width: diagonal, height: diagonal)
            .rotationEffect(value.angle)
            .opacity(value.opacity)
            .frame(width: size.width, height: size.height)
        return ZStack {
            ring.mask(shape.strokeBorder(lineWidth: 10)).blur(radius: 9).opacity(0.55)
            ring.mask(shape.strokeBorder(lineWidth: 1.5))
        }
        .frame(width: size.width, height: size.height)
        .clipShape(shape)
    }
}

// MARK: - Composants

struct KeyCap: View {
    let key: String
    let primary: Bool
    @Environment(\.styleTokens) private var style
    init(_ key: String, primary: Bool = false) {
        self.key = key
        self.primary = primary
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 5, style: .continuous)
        let filled = primary && style.primaryKeyFill != nil
        Text(key)
            .font(.system(size: 11, weight: filled ? .bold : .medium,
                          design: style.design == .monospaced || style.monoKeys ? .monospaced : .rounded))
            .foregroundStyle(filled ? style.primaryKeyInk ?? style.keyInk : style.keyInk)
            .padding(.horizontal, 6)
            .frame(minWidth: 22, minHeight: 20)
            .background {
                ZStack {
                    if style.keyHardShadow { shape.fill(Color.black).offset(x: 2, y: 2) }
                    shape.fill(filled ? style.primaryKeyFill ?? style.keyFill : style.keyFill)
                    if let border = style.keyBorder, !filled || style.keyHardShadow {
                        shape.strokeBorder(border, lineWidth: style.keyHardShadow ? 1.5 : 1)
                    }
                }
            }
    }
}

struct EmptyState: View {
    let text: String
    let symbol: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 28, weight: .light))
            if !text.isEmpty { Text(text).font(.system(size: 13)) }
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Texte (et curseur) centrés verticalement : NSTextField les colle en haut de son cadre, ce qui décale ou rogne
/// les polices aux grandes métriques (Google Sans Flex).
final class CenteredTextFieldCell: NSTextFieldCell {
    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        var frame = super.drawingRect(forBounds: rect)
        // Hauteur d'une ligne de la police (et non du texte courant : le champ vide doit centrer l'invite pareil).
        let height = font.map { ceil(NSLayoutManager().defaultLineHeight(for: $0)) } ?? cellSize(forBounds: rect).height
        if height < frame.height {
            frame.origin.y += (frame.height - height) / 2
            frame.size.height = height
        }
        return frame
    }

    /// Le texte d'invite est dessiné dans ce rectangle-là.
    override func titleRect(forBounds rect: NSRect) -> NSRect {
        drawingRect(forBounds: rect)
    }

    override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, event: NSEvent?) {
        super.edit(withFrame: drawingRect(forBounds: rect), in: controlView, editor: textObj, delegate: delegate, event: event)
    }

    override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?,
                         start selStart: Int, length selLength: Int) {
        super.select(withFrame: drawingRect(forBounds: rect), in: controlView, editor: textObj, delegate: delegate,
                     start: selStart, length: selLength)
    }
}

/// NSTextField plutôt qu'un TextField SwiftUI : focus fiable dans un panneau non activant.
struct SearchField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.cell = CenteredTextFieldCell(textCell: "")
        field.isEditable = true
        field.isSelectable = true
        // Le champ prend toute la hauteur proposée (34 pt) ; la cellule y centre le texte.
        field.setContentHuggingPriority(.defaultLow, for: .vertical)
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = StyleTokens.current.searchFont
        field.cell?.usesSingleLineMode = true
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        field.delegate = context.coordinator
        field.stringValue = text
        context.coordinator.applyStyle(to: field, placeholder: placeholder)
        Controller.shared.searchField = field
        DispatchQueue.main.async { Controller.shared.focusSearch() }
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self
        context.coordinator.applyStyle(to: field, placeholder: placeholder)
        if field.stringValue != text {
            field.stringValue = text
            field.currentEditor()?.selectedRange = NSRange(location: (text as NSString).length, length: 0)
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: SearchField
        /// Style et texte d'invite appliqués : on ne refait rien à chaque frappe.
        private var applied: String?
        init(_ parent: SearchField) { self.parent = parent }

        func applyStyle(to field: NSTextField, placeholder: String) {
            let current = AppSettings.shared.styleSignature + "|" + placeholder
            if applied == current { return }
            applied = current
            let style = StyleTokens.current
            field.font = style.searchFont
            field.textColor = style.searchNSColor
            field.setAccessibilityPlaceholderValue(placeholder)
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.stringValue
        }
    }
}

// MARK: - Verre

/// Apparence du verre (Réglages › Apparence), en valeur : l'aperçu et les vignettes des thèmes en montrent d'autres.
struct GlassLook {
    var material: GlassMaterial
    var tint: Color?
    var frostOpacity: Double = 1
    var border = false
    /// Aperçu dans les réglages : le givre floute le contenu de la fenêtre (et non le bureau derrière elle).
    var withinWindow = false

    static var current: GlassLook {
        let s = AppSettings.shared
        return GlassLook(material: s.glassMaterial,
                         tint: s.glassTintAmount > 0.001 ? Color(hex: s.glassTintHex).opacity(s.glassTintAmount) : nil,
                         frostOpacity: s.frostOpacity, border: s.glassBorder)
    }

    init(material: GlassMaterial, tint: Color?, frostOpacity: Double = 1, border: Bool = false, withinWindow: Bool = false) {
        self.material = material
        self.tint = tint
        self.frostOpacity = frostOpacity
        self.border = border
        self.withinWindow = withinWindow
    }

    init(_ preset: LookPreset, withinWindow: Bool) {
        self.init(material: preset.material,
                  tint: preset.tintAmount > 0 ? Color(hex: preset.tintHex).opacity(preset.tintAmount) : nil,
                  border: preset.border, withinWindow: withinWindow)
    }
}

extension View {
    /// Liquid Glass (macOS 26+) ou verre dépoli, posé derrière la vue. Rien n'est posé entre le verre et le
    /// contenu : un voile de flou dessiné par-dessus le Liquid Glass l'effacerait.
    func glassPanel(cornerRadius radius: CGFloat, look: GlassLook = .current) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return background { GlassSurface(shape: shape, look: look) }
            .overlay {
                if look.border { shape.strokeBorder(Color.white.opacity(0.18), lineWidth: 1).allowsHitTesting(false) }
            }
    }
}

/// Le verre lui-même. Avec `glassFrost` < 1 (ouverture du Verre), le flou s'efface et laisse voir le bureau net,
/// mais le fumé reste : la teinte du verre est alors relayée par un simple aplat de la même couleur.
private struct GlassSurface: View {
    let shape: RoundedRectangle
    let look: GlassLook
    @Environment(\.glassFrost) private var frost

    var body: some View {
        ZStack {
            #if compiler(>=6.2)
            if #available(macOS 26.0, *), look.material != .frosted {
                let glass: Glass = look.material == .clear ? .clear : .regular
                Color.clear
                    .glassEffect(look.tint.map { glass.tint($0) } ?? glass, in: shape)
                    .opacity(frost.value)
                if let tint = look.tint { shape.fill(tint).opacity(1 - frost.value) }
            } else {
                frosted
            }
            #else
            frosted
            #endif
        }
        // Le verre reste clair pendant que la goutte gonfle et se givre quand elle se pose, porté par l'élan du
        // mouvement. À la fermeture, retour immédiat au verre clair (le panneau n'est déjà plus à l'écran).
        .animation(frost.value >= 1 ? frost.animation : nil, value: frost)
    }

    private var frosted: some View {
        ZStack {
            VisualEffectBackground(withinWindow: look.withinWindow).opacity(look.frostOpacity * frost.value)
            if let tint = look.tint { tint }
        }
        .clipShape(shape)
    }
}

struct VisualEffectBackground: NSViewRepresentable {
    var withinWindow = false

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = withinWindow ? .withinWindow : .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.blendingMode = withinWindow ? .withinWindow : .behindWindow
    }
}
