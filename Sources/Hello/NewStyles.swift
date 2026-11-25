import SwiftUI

extension LauncherModel {
    /// Après une mise à jour qui apporte des styles : une seule ligne discrète dans les suggestions.
    /// ↵ ouvre la présentation, ⌘↵ la masque pour de bon.
    func newStylesItem() -> ResultItem? {
        let styles = AppSettings.shared.newStyles
        guard !styles.isEmpty, AppSettings.shared.onboarded else { return nil }
        let names = styles.map(\.title)
        let title = styles.count == 1 ? "Nouveau style : \(names[0])" : "\(styles.count) nouveaux styles"
        let subtitle = styles.count == 1 ? styles[0].detail : ListFormatter.localizedString(byJoining: names)
        return ResultItem(id: "new-styles", section: "Nouveautés", title: title, subtitle: subtitle,
                          icon: .symbol("paintpalette.fill", .pink),
                          primary: ItemAction(title: "Découvrir") { WindowManager.showNewStyles() },
                          secondary: ItemAction(title: "Masquer") { [unowned self] in
                              AppSettings.shared.markStylesSeen()
                              refresh()
                          })
    }
}

/// Présentation des nouveaux styles : une carte dessinée par style, son effet d'ouverture en une phrase,
/// et un bouton pour l'essayer tout de suite. Fermer (ou finir) marque les styles comme vus.
struct NewStylesView: View {
    let styles: [PanelStyle]
    @StateObject private var pager = Pager()

    final class Pager: ObservableObject {
        @Published var index = 0
        @Published var forward = true
    }

    var body: some View {
        let style = styles[pager.index]
        VStack(spacing: 0) {
            Text(styles.count == 1 ? "Un nouveau style" : "\(styles.count) nouveaux styles")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.top, 30)

            ZStack {
                StyleArt(style: style)
                    .id(style)
                    .transition(.asymmetric(
                        insertion: .offset(x: pager.forward ? 40 : -40).combined(with: .opacity),
                        removal: .offset(x: pager.forward ? -40 : 40).combined(with: .opacity)))
            }
            .frame(width: 360, height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.1))
            }
            .shadow(color: .black.opacity(0.35), radius: 18, y: 10)
            .padding(.top, 16)

            VStack(spacing: 6) {
                Text(style.title).font(.system(size: 19, weight: .semibold))
                Text(style.detail)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 360)
            .padding(.top, 18)
            .id("text-\(style.rawValue)")
            .transition(.opacity)

            Spacer(minLength: 12)

            HStack(spacing: 10) {
                Button { go(-1) } label: { Image(systemName: "chevron.left").frame(width: 14) }
                    .keyboardShortcut(.leftArrow, modifiers: [])
                    .disabled(pager.index == 0)
                HStack(spacing: 5) {
                    ForEach(styles.indices, id: \.self) { i in
                        Circle().fill(i == pager.index ? Color.primary : Color.primary.opacity(0.25))
                            .frame(width: 5, height: 5)
                    }
                }
                Button { go(1) } label: { Image(systemName: "chevron.right").frame(width: 14) }
                    .keyboardShortcut(.rightArrow, modifiers: [])
                    .disabled(pager.index == styles.count - 1)
                Spacer()
                Button("Plus tard") { close() }
                    .keyboardShortcut(.cancelAction)
                Button("Essayer") { tryStyle(style) }
                    .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 22)
        }
        .frame(width: 460, height: 420)
        .background(Color(hex: "#1C1C1E"))
    }

    private func go(_ step: Int) {
        let next = min(max(pager.index + step, 0), styles.count - 1)
        guard next != pager.index else { return }
        pager.forward = step > 0
        withAnimation(Motion.scaled(.spring(response: 0.34, dampingFraction: 0.86))) { pager.index = next }
    }

    private func tryStyle(_ style: PanelStyle) {
        AppSettings.shared.panelStyle = style
        close()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { Controller.shared.show() }
    }

    private func close() {
        AppSettings.shared.markStylesSeen()
        WindowManager.closeNewStyles()
        Controller.shared.model.refresh()
    }
}
