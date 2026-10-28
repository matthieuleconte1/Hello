# Page de Hello

Page statique sans dépendance : `dist/index.html`, `styles.css`, `launcher.js` (le lanceur), `app.js` (thèmes, défilé, démarrage) et `icon.svg`.

```sh
python3 -m http.server 4191 --directory "$(git rev-parse --show-toplevel)/website/dist"
```

Ouvrir http://localhost:4191 dans **Helium** pour la vérification visuelle.

En ligne : https://matthieuleconte1.github.io/Hello/. Le workflow `.github/workflows/pages.yml` publie `dist/` tel quel sur GitHub Pages à chaque push sur `main` qui touche `website/` (ou à la main depuis l'onglet Actions).

Les cinq styles web (Expressif, Glyphe, Phosphore, Papier et Néo-brutal) et leurs palettes reprennent `Styles.swift` et `Settings.swift`. La structure, les polices et le ressort de Glyphe suivent la charte Atelier Glyphe fournie : cadre `#050403`, panneau `#080604`, surface `#121212`, contrôle `#242424`, texte blanc et accent `#ED6A0C`. Titres en Zalando Sans Expanded, corps en Red Hat Display ; grille de 4 px, rayons concentriques, filet et ombre selon la couche. Un seul accent en Glyphe. La Nuit utilise le rouge et les contours. Les polices web sont chargées depuis Google Fonts, avec repli local.

Le lanceur (`launcher.js`) reproduit le panneau natif à partir de `Views.swift`, `Styles.swift`, `Motion.swift` et `LauncherModel.swift` : en-tête de 60, lignes de 44, pied de 40 avec touches ; sélection qui glisse, liste segmentée d’Atelier, logo en anneau de `Mark.swift` ; suggestions « Récents » et « Commandes » ; grille d’apps, emoji, presse-papiers avec aperçu, terminal (`>` ou `$`), dossiers (`cd`) et IA (`?`). Il répond aux mêmes raccourcis (↑↓←→, ↵, ⌘↵, ⌥↵, Tab, Échap, double Échap pour arrêter) et rejoue l’ouverture propre à chaque style (vague, dépliage, CRT, page, tampon). C’est une démonstration locale : aucune commande système ni requête IA n’est exécutée. Les préférences de thème sont mémorisées dans le navigateur. « Accent macOS » est représenté en bleu sur le web, où la couleur système native n’est pas accessible. Les réglages natifs plus fins (intensité, densité, formes, givre, horaires de Nuit) restent dans l’application.

La page change intégralement de matière. Le thème Verre reste exclusivement dans l’app native. Les icônes SVG en contours évoquent les applications macOS. Le défilé initial est une hélice 3D de 36 mini-lanceurs, une par combinaison web (style, palette, apparence), avec les couleurs réellement calculées. Les cartes jaillissent du lanceur, tournent en 1,9 s pendant que toute la page change de thème au même rythme, puis se replient dans le lanceur avec une onde de choc ; toute interaction l’interrompt et restaure le thème choisi. Les transitions physiques sont finies, relançables et annulées si les animations sont désactivées. `prefers-reduced-motion` est prioritaire.

Les changements de thème utilisent une révélation circulaire de 440 ms, un mouvement en perspective du lanceur et une transition du titre. Les clics rapides annulent la transition précédente. Sans View Transitions, le panneau utilise son animation locale.

Au premier chargement, un écran de démarrage reprend le chargeur « comète de points » d’Atelier Glyphe et mesure la fluidité pendant 1,1 s (hélice cachée qui tourne dessous). Selon la cadence mesurée, le défilé est complet, allégé (sans ombres) ou remplacé par un simple lien ; un clic ou une touche le passe. Le bouton « Animations » en haut à droite coupe toutes les animations de la page.
