import SwiftUI

/// Une seule translation pour toute la bande de pages. Les pages restent dans l'arbre SwiftUI
/// du panneau : aucun NSHostingView imbriqué ne participe à son calcul de taille.
struct AppPagerOffset: ViewModifier {
    @ObservedObject var pager: PagerState
    let width: CGFloat

    func body(content: Content) -> some View {
        content.offset(x: pager.position * width)
    }
}
