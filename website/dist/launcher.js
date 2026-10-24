'use strict';
// Simulation du lanceur natif. Les valeurs reprennent l'app : StyleTokens (Styles.swift) pour les couleurs,
// LauncherView (Views.swift) pour les mesures — en-tête 60, lignes 44, pied 40 — et RevealStyle (Motion.swift)
// pour les ouvertures. Rien n'est exécuté : apps, commandes et réponses sont des exemples locaux.
const Launcher = (() => {
  const panel = document.getElementById('launcher');
  const field = document.getElementById('search');
  const list = document.getElementById('demo-content');
  const pane = panel.querySelector('.hl-pane');
  const toastBox = document.getElementById('demo-status');
  const hintsBox = document.getElementById('demo-hint');
  const back = document.getElementById('demo-back');
  const markBox = document.getElementById('hl-mark');
  const buttons = document.getElementById('hl-buttons');
  const runBox = document.getElementById('hl-run');
  const requestBox = document.getElementById('hl-request');
  const glow = panel.querySelector('.hl-glow');
  const fx = panel.querySelector('.hl-fx');
  const motion = () => typeof motionEnabled !== 'function' || motionEnabled();

  // ——— Ressorts : réponse et amortissement comme dans SwiftUI ———
  function springEasing(response, damping) {
    const w = 2 * Math.PI / response;
    const wd = w * Math.sqrt(1 - damping * damping);
    const duration = Math.min(1.4, -Math.log(.003) / (damping * w));
    const at = t => 1 - Math.exp(-damping * w * t) * (Math.cos(wd * t) + damping * w / wd * Math.sin(wd * t));
    const points = Array.from({ length: 41 }, (_, i) => i === 40 ? 1 : +at(i / 40 * duration).toFixed(4));
    return { easing: `linear(${points.join(',')})`, duration: Math.round(duration * 1000) };
  }
  const linearSupported = CSS.supports('transition-timing-function', 'linear(0, 1)');
  const spring = (response, damping) => {
    const curve = springEasing(response, damping);
    return linearSupported ? curve : { easing: 'cubic-bezier(.3,1.25,.5,1)', duration: curve.duration };
  };
  const rgba = (hex, alpha) => {
    const n = parseInt(hex.slice(1), 16);
    return `rgba(${n >> 16 & 255},${n >> 8 & 255},${n & 255},${alpha})`;
  };

  // ——— Symboles (équivalents des SF Symbols de l'app) ———
  const symbolPaths = {
    grid: '<g fill="currentColor" stroke="none"><rect x="1.5" y="1.5" width="3.6" height="3.6" rx="1"/><rect x="6.2" y="1.5" width="3.6" height="3.6" rx="1"/><rect x="10.9" y="1.5" width="3.6" height="3.6" rx="1"/><rect x="1.5" y="6.2" width="3.6" height="3.6" rx="1"/><rect x="6.2" y="6.2" width="3.6" height="3.6" rx="1"/><rect x="10.9" y="6.2" width="3.6" height="3.6" rx="1"/><rect x="1.5" y="10.9" width="3.6" height="3.6" rx="1"/><rect x="6.2" y="10.9" width="3.6" height="3.6" rx="1"/><rect x="10.9" y="10.9" width="3.6" height="3.6" rx="1"/></g>',
    smile: '<circle cx="8" cy="8" r="6.3"/><path d="M5.4 9.6c1.4 1.6 3.8 1.6 5.2 0"/><circle cx="5.9" cy="6.4" r=".5" fill="currentColor"/><circle cx="10.1" cy="6.4" r=".5" fill="currentColor"/>',
    clipboard: '<rect x="3" y="3" width="10" height="11.5" rx="2"/><path d="M6 2.2h4v2.2H6zM5.5 8h5M5.5 10.8h3.5"/>',
    eyedropper: '<path d="m10.4 2.6 3 3-1.4 1.4-3-3zM9.2 5.2 3.4 11v1.6H5l5.8-5.8"/>',
    menubar: '<rect x="1.8" y="3" width="12.4" height="10" rx="2"/><path d="M1.8 6h12.4"/>',
    trash: '<path d="M2.8 4.2h10.4M6.2 4.2V2.6h3.6v1.6M4 4.2l.7 9.2h6.6l.7-9.2M6.6 6.8v4.4M9.4 6.8v4.4"/>',
    gear: '<circle cx="8" cy="8" r="2.2"/><path d="M8 1.6v2M8 12.4v2M1.6 8h2M12.4 8h2M3.5 3.5l1.4 1.4M11.1 11.1l1.4 1.4M3.5 12.5l1.4-1.4M11.1 4.9l1.4-1.4"/>',
    terminal: '<rect x="1.8" y="2.6" width="12.4" height="10.8" rx="2"/><path d="m4.6 6.2 2 1.8-2 1.8M8.4 10h3"/>',
    sparkles: '<path d="M7 1.8 8.3 5.7 12.2 7 8.3 8.3 7 12.2 5.7 8.3 1.8 7l3.9-1.3zM12.4 10.4l.6 1.6 1.6.6-1.6.6-.6 1.6-.6-1.6-1.6-.6 1.6-.6z"/>',
    bolt: '<path d="M9 1.6 3.6 9h4l-1 5.4L12.4 7h-4z"/>',
    clock: '<circle cx="8" cy="8" r="6.2"/><path d="M8 4.6V8l2.4 1.6"/>',
    bubbles: '<path d="M2 3.4h8.2v5.4H5.4L3 10.8V8.8H2zM12 6.4h2v5.2h-1v1.8l-2.2-1.8H7.6v-1.4"/>',
    chart: '<path d="M2.2 13.8h11.6M4 11.6V8M7 11.6V4.2M10 11.6V6.4M13 11.6V9.4"/>',
    keyboard: '<rect x="1.4" y="4" width="13.2" height="8" rx="1.6"/><path d="M4 6.6h.1M6.6 6.6h.1M9.2 6.6h.1M11.8 6.6h.1M4.8 9.4h6.4"/>',
    check: '<circle cx="8" cy="8" r="6.2" fill="currentColor" stroke="none"/><path d="m5.2 8.2 1.9 1.9 3.7-4" stroke="#fff"/>',
    xmark: '<circle cx="8" cy="8" r="6.2"/><path d="m5.8 5.8 4.4 4.4m0-4.4-4.4 4.4"/>',
    paperclip: '<path d="M11.6 7.2 7.1 11.7a2.6 2.6 0 0 1-3.7-3.7l5-5a1.7 1.7 0 0 1 2.5 2.5L6.1 10.3a.9.9 0 0 1-1.2-1.2l4.3-4.3"/>',
    camera: '<path d="M2 5V3.4C2 2.6 2.6 2 3.4 2H5M11 2h1.6c.8 0 1.4.6 1.4 1.4V5M14 11v1.6c0 .8-.6 1.4-1.4 1.4H11M5 14H3.4C2.6 14 2 13.4 2 12.6V11"/><circle cx="8" cy="8" r="2.4"/>',
    text: '<path d="M3 3.4h10M3 6.4h10M3 9.4h10M3 12.4h6"/>',
    link: '<path d="m6.6 9.4 2.8-2.8M5.4 7.6 3.9 9.1a2.4 2.4 0 0 0 3.4 3.4l1.5-1.5M10.6 8.4l1.5-1.5a2.4 2.4 0 0 0-3.4-3.4L7.2 5"/>',
    chevron: '<path d="M10 3 5 8l5 5"/>'
  };
  function symbol(name, className = 'hl-symbol') {
    return `<svg class="${className}" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${symbolPaths[name] || symbolPaths.sparkles}</svg>`;
  }

  // ——— Icônes d'apps : des carrés arrondis à la manière de macOS (dessins génériques) ———
  const squircle = fill => `<rect width="64" height="64" rx="14.5" fill="${fill}"/>`;
  const shine = '<rect width="64" height="32" rx="14.5" fill="#fff" opacity=".12"/>';
  const appArt = {
    safari: squircle('#f4f4f6') + '<circle cx="32" cy="32" r="23" fill="#1a8cff"/><circle cx="32" cy="32" r="23" fill="none" stroke="#fff" stroke-opacity=".5" stroke-width="1.5" stroke-dasharray="1 4.2"/><path d="M32 32 45 19 35.5 35.5Z" fill="#ff3b30"/><path d="M32 32 19 45 28.5 28.5Z" fill="#fff"/>',
    finder: squircle('#e9f3fd') + '<path d="M0 14.5A14.5 14.5 0 0 1 14.5 0H36c-4 9-6 19-6 30h5v34H14.5A14.5 14.5 0 0 1 0 49.5Z" fill="#1d8bf5"/><path d="M20 20v6M44 20v6" stroke="#0b2a4a" stroke-width="3.4" stroke-linecap="round"/><path d="M16 42c10 7 22 7 32 0" fill="none" stroke="#0b2a4a" stroke-width="3" stroke-linecap="round"/>',
    notes: squircle('#fffdf6') + '<path d="M0 14.5A14.5 14.5 0 0 1 14.5 0h35A14.5 14.5 0 0 1 64 14.5V19H0Z" fill="#f9c440"/><path d="M12 30h40M12 39h40M12 48h28" stroke="#d6d1c4" stroke-width="2.4" stroke-linecap="round"/>',
    terminal: squircle('#2b2b2d') + '<rect x="5" y="5" width="54" height="54" rx="10" fill="#111" stroke="#4a4a4d"/><path d="m15 24 9 8-9 8M28 41h14" fill="none" stroke="#f2f2f2" stroke-width="3.6" stroke-linecap="round" stroke-linejoin="round"/>',
    calendar: squircle('#fff') + '<text x="32" y="21" text-anchor="middle" font-family="-apple-system,Helvetica,Arial" font-weight="600" font-size="11" fill="#ff3b30">VEN.</text><text x="32" y="51" text-anchor="middle" font-family="-apple-system,Helvetica,Arial" font-weight="300" font-size="30" fill="#222">24</text>',
    settings: squircle('#8e8e93') + shine + '<circle cx="32" cy="32" r="18" fill="#d8d8dc"/><circle cx="32" cy="32" r="18" fill="none" stroke="#6b6b70" stroke-width="5" stroke-dasharray="4 3.1"/><circle cx="32" cy="32" r="7" fill="#8e8e93"/>',
    messages: squircle('#34c759') + shine + '<path d="M32 15c-11 0-19 7-19 16 0 5 3 9 7 12l-2 7 8-4c2 .6 4 .8 6 .8 11 0 19-7 19-16S43 15 32 15Z" fill="#fff"/>',
    mail: squircle('#1f8bff') + shine + '<rect x="12" y="19" width="40" height="27" rx="4" fill="#fff"/><path d="m13 21 19 14 19-14" fill="none" stroke="#1f8bff" stroke-width="2.6" stroke-linejoin="round"/>',
    music: squircle('#fa2d55') + shine + '<path d="M26 44V20l18-4v24" fill="none" stroke="#fff" stroke-width="3.6" stroke-linejoin="round"/><circle cx="22" cy="44" r="5.5" fill="#fff"/><circle cx="40" cy="40" r="5.5" fill="#fff"/>',
    photos: squircle('#fff') + ['#ff9f0a', '#ffd60a', '#30d158', '#64d2ff', '#0a84ff', '#bf5af2', '#ff375f', '#ff453a'].map((c, i) => `<ellipse cx="32" cy="20" rx="6.5" ry="11" fill="${c}" opacity=".85" transform="rotate(${i * 45} 32 32)"/>`).join(''),
    maps: squircle('#dff0c9') + '<path d="M0 40 64 24M22 0l12 64M40 0v64" stroke="#fff" stroke-width="5"/><path d="M0 40 64 24" stroke="#f7c948" stroke-width="3"/><path d="M38 14c-6 0-10 4-10 10 0 7 10 18 10 18s10-11 10-18c0-6-4-10-10-10Z" fill="#ff3b30"/><circle cx="38" cy="24" r="4" fill="#fff"/>',
    reminders: squircle('#fff') + ['#ff9f0a', '#0a84ff', '#ff375f'].map((c, i) => `<circle cx="17" cy="${19 + i * 13}" r="4.6" fill="none" stroke="${c}" stroke-width="2.6"/><path d="M27 ${19 + i * 13}h22" stroke="#d1d1d6" stroke-width="2.4" stroke-linecap="round"/>`).join(''),
    appstore: squircle('#1c8cff') + shine + '<path d="M27 16 41 44M37 16 23 44M18 37h28" stroke="#fff" stroke-width="4.2" stroke-linecap="round"/>',
    preview: squircle('#e8eef8') + '<rect x="14" y="18" width="30" height="32" rx="3" fill="#fff" stroke="#b6c3d6" transform="rotate(-8 29 34)"/><rect x="20" y="14" width="30" height="32" rx="3" fill="#fff" stroke="#9fb2cc"/><path d="m24 40 7-9 5 6 4-4 6 7Z" fill="#4aa3ff"/><circle cx="41" cy="22" r="3" fill="#ffcc00"/>',
    calculator: squircle('#2c2c2e') + [0, 1, 2, 3].flatMap(r => [0, 1, 2].map(c => `<circle cx="${18 + c * 14}" cy="${18 + r * 10}" r="4" fill="${c === 2 ? '#ff9f0a' : '#6b6b70'}"/>`)).join(''),
    folder: '<path d="M4 16a6 6 0 0 1 6-6h14l6 6h24a6 6 0 0 1 6 6v26a6 6 0 0 1-6 6H10a6 6 0 0 1-6-6Z" fill="#3aa0f0"/><path d="M4 24a6 6 0 0 1 6-6h44a6 6 0 0 1 6 6v24a6 6 0 0 1-6 6H10a6 6 0 0 1-6-6Z" fill="#62b8f8"/>'
  };
  const appIcon = name => `<span class="hl-app"><svg viewBox="0 0 64 64" aria-hidden="true">${appArt[name]}</svg></span>`;

  // ——— Données d'exemple ———
  const apps = [
    ['safari', 'Safari', '#1a8cff', true], ['finder', 'Finder', '#1d8bf5', true], ['notes', 'Notes', '#f9c440'],
    ['terminal', 'Terminal', '#3a3a3c', true], ['calendar', 'Calendrier', '#ff3b30'], ['settings', 'Réglages Système', '#8e8e93'],
    ['messages', 'Messages', '#34c759', true], ['mail', 'Mail', '#1f8bff'], ['music', 'Musique', '#fa2d55'],
    ['photos', 'Photos', '#ff9f0a'], ['maps', 'Plans', '#30d158'], ['reminders', 'Rappels', '#ff9f0a'],
    ['appstore', 'App Store', '#1c8cff'], ['preview', 'Aperçu', '#4aa3ff'], ['calculator', 'Calculette', '#ff9f0a']
  ].map(([icon, title, tint, running = false]) => ({
    id: icon, title, tint, running, icon: { app: icon }, accessory: running ? 'Ouverte' : null,
    primary: 'Ouvrir', secondary: 'Afficher dans le Finder', tertiary: running ? 'Quitter l’app' : null,
    remove: 'Désinstaller', kind: 'app'
  }));
  const app = id => apps.find(item => item.id === id);
  const command = (id, title, subtitle, icon, tint, extra = {}) => ({
    id, title, subtitle, icon: { symbol: icon, tint }, accessory: 'Commande', primary: 'Ouvrir', kind: 'command', ...extra
  });
  const commands = [
    command('cmd.apps', 'Toutes les applications', 'Grille de grandes icônes, page par page', 'grid', '#af52de', { suggested: true, mode: 'apps' }),
    command('cmd.emoji', 'Emoji & Symboles', 'Chercher et insérer emoji et caractères Unicode', 'smile', '#ff9500', { suggested: true, mode: 'emoji' }),
    command('cmd.clipboard', 'Historique du presse-papiers', '4 élément(s)', 'clipboard', '#007aff', { suggested: true, mode: 'clipboard' }),
    command('cmd.pick', 'Pipette de couleur', 'Capturer une couleur n’importe où à l’écran', 'eyedropper', '#ff2d55', { suggested: true, primary: 'Choisir', secondary: 'Historique des couleurs' }),
    command('cmd.menubar', 'Barre des menus', 'Masquage automatique : Jamais', 'menubar', '#5856d6', { suggested: true }),
    command('cmd.uninstall', 'Désinstaller une application', 'Supprime l’app et les fichiers de votre choix', 'trash', '#ff3b30', { suggested: true }),
    command('cmd.settings', 'Réglages de Hello', 'Apparence, recherche, presse-papiers… (⌘,)', 'gear', '#8e8e93', { suggested: true }),
    command('cmd.chats', 'Conversations avec l’IA', '6 conversations', 'bubbles', '#af52de'),
    command('cmd.stats', 'Statistiques d’utilisation', 'Apps et commandes les plus utilisées', 'chart', '#30b0c7'),
    command('cmd.hotkey', 'Raccourci global de Hello', 'Actuel : ⌘ Espace', 'keyboard', '#8e8e93'),
    command('cmd.quit', 'Quitter Hello', 'Ferme complètement le lanceur', 'xmark', '#8e8e93', { primary: 'Quitter' })
  ];
  const recents = ['safari', 'terminal', 'notes', 'finder'];
  const clips = [
    { id: 'clip1', title: 'Réunion produit à 14 h, salle Lumière', subtitle: 'Notes · il y a 2 min', icon: { symbol: 'text', tint: '#8e8e93' }, body: 'Réunion produit à 14 h, salle Lumière.\nApporter les maquettes du lanceur.', kind: 'Texte', source: 'Notes' },
    { id: 'clip2', title: 'https://github.com/matthieuleconte1/Hello', subtitle: 'Safari · il y a 8 min', icon: { symbol: 'link', tint: '#007aff' }, body: 'https://github.com/matthieuleconte1/Hello', kind: 'Lien', source: 'Safari' },
    { id: 'clip3', title: 'cd ~/Code/Halo && swift build', subtitle: 'Terminal · il y a 25 min', icon: { symbol: 'terminal', tint: '#3a3a3c' }, body: 'cd ~/Code/Halo && swift build', kind: 'Texte', source: 'Terminal', mono: true },
    { id: 'clip4', title: '#ED6A0C', subtitle: 'Hello · hier', icon: { swatch: '#ed6a0c' }, body: '#ED6A0C', kind: 'Couleur', source: 'Pipette' }
  ].map(item => ({ ...item, primary: 'Coller', secondary: 'Copier', remove: 'Supprimer', kind: 'clip', clipKind: item.kind }));
  const emoji = [
    ['😀', 'Visage souriant'], ['😂', 'Visage riant aux larmes'], ['🥹', 'Visage retenant ses larmes'], ['😍', 'Yeux en cœur'],
    ['🤔', 'Visage pensif'], ['😎', 'Lunettes de soleil'], ['🥳', 'Visage festif'], ['😴', 'Visage endormi'],
    ['👍', 'Pouce levé'], ['👏', 'Applaudissements'], ['🙌', 'Mains levées'], ['🙏', 'Mains jointes'],
    ['🔥', 'Feu'], ['✨', 'Étincelles'], ['🎉', 'Cotillons'], ['💡', 'Ampoule'],
    ['🚀', 'Fusée'], ['⭐️', 'Étoile'], ['❤️', 'Cœur rouge'], ['✅', 'Coche'],
    ['☕️', 'Boisson chaude'], ['🍕', 'Pizza'], ['🌈', 'Arc-en-ciel'], ['🌙', 'Croissant de lune']
  ].map(([char, name]) => ({ char, name, code: 'U+' + [...char][0].codePointAt(0).toString(16).toUpperCase() }));
  const history = ['git status', 'git log --oneline -5', 'swift build', 'npm run dev', 'brew upgrade'];
  const folders = ['Documents', 'Téléchargements', 'Bureau', 'Code', 'Images'];

  const runItem = (cmd, past = false) => ({
    id: (past ? 'hist:' : 'run:') + cmd, title: cmd, subtitle: past ? null : 'Exécuter dans zsh depuis ~',
    icon: { symbol: past ? 'clock' : 'terminal', tint: '#404040' }, accessory: past ? 'Historique' : 'Shell',
    primary: 'Exécuter', secondary: 'Dans Terminal', kind: 'run', command: cmd
  });
  const agentHint = () => [{
    id: 'agent.hint', section: 'Agent', title: 'Demande n’importe quoi à l’IA',
    subtitle: 'Auto : Luna choisit le niveau · « ?? » Recherche & Action · « ??? » Code · ⌘O fichier · ⇧⌘S capture',
    icon: { symbol: 'sparkles', tint: '#af52de' }, primary: 'OK', kind: 'noop'
  }, ...['Comment ouvrir un dossier depuis Hello ?', 'Résumer la page ouverte dans Safari'].map((title, i) => ({
    id: 'chat' + i, section: 'Conversations récentes', title, subtitle: i ? 'Hier' : 'Il y a 3 h',
    icon: { symbol: 'bubbles', tint: '#af52de' }, primary: 'Reprendre', kind: 'agent', request: title
  }))];
  const agentItem = request => ({
    id: 'agent1:' + request, section: 'Agent', title: `Demander à l’IA : ${request}`,
    subtitle: 'Auto : répond ou choisit le niveau', icon: { symbol: 'bolt', tint: '#ffcc00' }, accessory: 'Niveau 1',
    primary: 'Demander', secondary: 'Recherche & Action', tertiary: 'Code', kind: 'agent', request
  });
  const fold = text => text.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();

  function rootItems(query) {
    const q = query.trim();
    if (!q) {
      return [
        ...recents.map(id => ({ ...app(id), section: 'Récents' })),
        ...commands.filter(item => item.suggested).map(item => ({ ...item, section: 'Commandes' }))
      ];
    }
    if (q.startsWith('?')) {
      const request = q.replace(/^\?+/, '').trim();
      return request ? [agentItem(request)] : agentHint();
    }
    if (q.startsWith('>') || q.startsWith('$')) {
      const cmd = q.slice(1).trim();
      const past = history.filter(line => line !== cmd && line.includes(cmd))
        .map((line, i) => ({ ...runItem(line, true), section: i === 0 ? 'Historique' : undefined }));
      return [...(cmd ? [runItem(cmd)] : []), ...past];
    }
    if (/^cd(\s|$)/.test(q)) {
      const part = fold(q.slice(2).trim().replace(/^~\/?/, ''));
      return folders.filter(name => fold(name).startsWith(part)).map(name => ({
        id: 'path:' + name, title: name, subtitle: '~/' + name, icon: { app: 'folder' }, accessory: 'Dossier',
        primary: 'Ouvrir dans le Finder', secondary: 'Ouvrir dans Terminal', kind: 'path', completion: `cd ~/${name}/`
      }));
    }
    const needle = fold(q);
    const score = item => {
      const title = fold(item.title);
      if (title.startsWith(needle)) return 3;
      if (title.split(/\s+/).some(word => word.startsWith(needle))) return 2;
      return title.includes(needle) ? 1 : 0;
    };
    const found = [...apps, ...commands].map(item => [score(item), item]).filter(([s]) => s)
      .sort((a, b) => b[0] - a[0]).map(([, item]) => item);
    const agent = agentItem(q);
    return q.split(' ').length >= 4 || !found.length ? [agent, ...found] : [...found, agent];
  }

  // ——— Jetons de style (Styles.swift › StyleTokens.make) ———
  const fonts = {
    glyph: ['"Red Hat Display", -apple-system, sans-serif', '"Zalando Sans Expanded", "Red Hat Display", sans-serif'],
    atelier: ['"Google Sans Flex", "Red Hat Display", -apple-system, sans-serif', '"Google Sans Flex", "Red Hat Display", sans-serif'],
    mono: ['ui-monospace, "SF Mono", Menlo, monospace', 'ui-monospace, "SF Mono", Menlo, monospace'],
    system: ['-apple-system, BlinkMacSystemFont, "Helvetica Neue", Arial, sans-serif', '-apple-system, BlinkMacSystemFont, "Helvetica Neue", Arial, sans-serif'],
    serif: '"New York", ui-serif, Georgia, "Times New Roman", serif'
  };
  const blurShadow = '0 1px 3px rgba(0,0,0,.22), 0 16px 48px rgba(0,0,0,.38)';

  function makeTokens(style, look, variant) {
    if (style === 'glyph' && look === 'night') {
      const red = '#d94433', line = 'rgba(255,60,40,.58)';
      return {
        kind: 'glyph-night', reveal: 'wave', motion: spring(.36, .78),
        frame: '#000', pane: '#000', paneLine: line, line, lineWidth: '1px', shadow: '6px 6px 0 rgba(255,60,40,.36)',
        radius: 22, rowRadius: 12, cellRadius: 14, chrome: red, ink: red, divider: 'transparent', accent: red, onAccent: '#000', accent2: red,
        sel: red, selInk: '#000', tile: 'transparent', tileInk: red, tileOn: '#000', tileOnInk: red, tileLine: line,
        key: 'transparent', keyInk: red, keyLine: line, pkey: red, pkeyInk: '#000', live: red, toast: red,
        font: fonts.glyph[0], titleFont: fonts.glyph[0], searchFont: fonts.glyph[1], titleWeight: 500, searchWeight: 400,
        markRing: red, markDot: red, sectionRule: 'rgba(255,60,40,.32)', tint: red
      };
    }
    if (style === 'glyph') {
      const dark = look !== 'light';
      const ink = dark ? '#ffffff' : '#111111';
      const selection = dark ? '#f1f1f1' : '#080604';
      const selInk = dark ? '#111111' : '#ffffff';
      const mono = !variant[1];
      const accent = variant[1] || ink;
      const onAccent = variant[2] || (dark ? '#111111' : '#ffffff');
      const frameAccent = mono ? '#ffffff' : accent;
      return {
        kind: 'glyph', reveal: 'wave', motion: spring(.36, .78),
        frame: '#050403', pane: dark ? '#080604' : '#efeeec', paneLine: dark ? 'rgba(255,255,255,.1)' : 'transparent',
        line: 'transparent', lineWidth: '0px', shadow: blurShadow, radius: 22, rowRadius: 12, cellRadius: 14,
        chrome: '#ffffff', ink, divider: 'transparent', accent, onAccent, accent2: accent,
        sel: selection, selInk, tile: dark ? '#242424' : '#e7e5e2', tileInk: ink,
        tileOn: mono ? selInk : accent, tileOnInk: mono ? selection : onAccent, tileLine: 'transparent',
        key: 'rgba(255,255,255,.07)', keyInk: 'rgba(255,255,255,.62)', keyLine: 'rgba(255,255,255,.14)',
        pkey: frameAccent, pkeyInk: mono ? '#050403' : onAccent, live: accent, toast: '#ffffff',
        font: fonts.glyph[0], titleFont: fonts.glyph[0], searchFont: fonts.glyph[1], titleWeight: 600, searchWeight: 500,
        markRing: '#ffffff', markDot: frameAccent
      };
    }
    if (style === 'atelier') {
      const dark = look === 'dark';
      const [primary, secondary] = [variant[1], variant[2]];
      const ink = dark ? '#f4f4f0' : '#111112';
      const card = dark ? '#2c2c31' : '#ffffff';
      return {
        kind: 'atelier', reveal: 'unfold', motion: spring(.32, .8), segmented: true,
        frame: dark ? '#000000' : '#111112', pane: dark ? '#1c1c1f' : '#e3e3dc', paneLine: 'transparent',
        line: 'transparent', lineWidth: '0px', shadow: blurShadow, radius: 30, rowRadius: 22, cellRadius: 28,
        chrome: '#f4f4f0', ink, headerInk: ink, card, divider: 'transparent', accent: primary, onAccent: '#111112', accent2: secondary,
        sel: dark ? primary : '#111112', selInk: dark ? '#111112' : '#f4f4f0',
        tile: secondary, tileInk: '#111112', tileOn: dark ? '#111112' : primary, tileOnInk: dark ? primary : '#111112', tileLine: 'transparent',
        key: '#2c2c2f', keyInk: 'rgba(244,244,240,.85)', keyLine: 'transparent', pkey: primary, pkeyInk: '#111112',
        live: '#ff4f3a', toast: primary, hbtn: primary, hbtnInk: '#111112',
        font: fonts.atelier[0], titleFont: fonts.atelier[0], searchFont: fonts.atelier[1], titleWeight: 600, searchWeight: 500,
        markRing: ink, markDot: secondary
      };
    }
    if (style === 'phosphor') {
      const [green, screen] = [variant[1], variant[2]];
      return {
        kind: 'phosphor', reveal: 'crt', motion: null,
        frame: screen, pane: 'transparent', paneLine: 'transparent', line: rgba(green, .35), lineWidth: '1px', shadow: blurShadow,
        radius: 10, rowRadius: 3, cellRadius: 6, chrome: green, ink: green, divider: rgba(green, .22), accent: green, onAccent: screen, accent2: green,
        sel: green, selInk: screen, tile: 'transparent', tileInk: green, tileOn: 'transparent', tileOnInk: screen, tileLine: 'currentColor',
        key: 'transparent', keyInk: rgba(green, .75), keyLine: rgba(green, .4), pkey: green, pkeyInk: screen, live: green, toast: green,
        font: fonts.mono[0], titleFont: fonts.mono[0], searchFont: fonts.mono[1], titleWeight: 400, searchWeight: 400,
        markRing: green, markDot: green, tint: green
      };
    }
    if (style === 'paper') {
      const night = variant[0] === 'Nuit';
      const ink = night ? '#ede6d8' : '#211c17';
      const vermilion = night ? '#ff7a45' : '#d9480f';
      return {
        kind: 'paper', reveal: 'page', motion: { easing: 'cubic-bezier(.42,0,.58,1)', duration: 200 },
        frame: variant[1], pane: 'transparent', paneLine: 'transparent', line: rgba(ink, .14), lineWidth: '1px', shadow: blurShadow,
        radius: 18, rowRadius: 6, cellRadius: 14, chrome: ink, ink, divider: rgba(ink, .14), accent: vermilion, onAccent: '#ffffff', accent2: vermilion,
        sel: variant[2], selInk: null, bar: vermilion, tile: null, tileLine: 'transparent',
        key: 'transparent', keyInk: rgba(ink, .6), keyLine: rgba(ink, .25), pkey: vermilion, pkeyInk: '#ffffff', live: vermilion, toast: vermilion,
        font: fonts.system[0], titleFont: fonts.serif, searchFont: fonts.serif, titleWeight: 600, searchWeight: 400,
        markRing: ink, markDot: vermilion
      };
    }
    const color = variant[1];
    return {
      kind: 'brutal', reveal: 'slam', motion: spring(.24, .55),
      frame: '#fff4d6', pane: 'transparent', paneLine: 'transparent', line: '#000', lineWidth: '3px', shadow: '8px 8px 0 #000',
      radius: 16, rowRadius: 10, cellRadius: 16, chrome: '#000', ink: '#000', divider: '#000', accent: '#3d6bff', onAccent: '#fff', accent2: '#3d6bff',
      sel: color, selInk: null, tile: null, tileLine: '#000',
      key: '#fff', keyInk: '#000', keyLine: '#000', pkey: variant[0] === 'Jaune' ? '#ff8ad8' : '#ffd84d', pkeyInk: '#000',
      live: '#00b86b', toast: '#3d6bff',
      font: fonts.system[0], titleFont: fonts.system[0], searchFont: fonts.system[1], titleWeight: 700, searchWeight: 800,
      markRing: color, markDot: '#ffd84d'
    };
  }

  let tokens = makeTokens('glyph', 'dark', ['Orange', '#ed6a0c', '#fff']);
  function setStyle(style, look, variant) {
    tokens = makeTokens(style, look, variant);
    panel.dataset.hl = tokens.kind;
    const vars = {
      frame: tokens.frame, pane: tokens.pane, 'pane-line': tokens.paneLine, line: tokens.line, 'line-w': tokens.lineWidth,
      shadow: tokens.shadow, radius: tokens.radius + 'px', 'pane-radius': Math.max(tokens.radius - 8, 8) + 'px',
      'row-r': tokens.rowRadius + 'px', 'cell-r': tokens.cellRadius + 'px', chrome: tokens.chrome, ink: tokens.ink, 'header-ink': tokens.headerInk || tokens.chrome,
      divider: tokens.divider, accent: tokens.accent, 'on-accent': tokens.onAccent, accent2: tokens.accent2,
      sel: tokens.sel, 'sel-ink': tokens.selInk || 'inherit', bar: tokens.bar || 'transparent', card: tokens.card || 'transparent',
      tile: tokens.tile || 'transparent', 'tile-ink': tokens.tileInk || '#fff', 'tile-on': tokens.tileOn || 'transparent',
      'tile-on-ink': tokens.tileOnInk || '#fff', 'tile-line': tokens.tileLine, key: tokens.key, 'key-ink': tokens.keyInk,
      'key-line': tokens.keyLine, pkey: tokens.pkey, 'pkey-ink': tokens.pkeyInk, live: tokens.live, toast: tokens.toast,
      hbtn: tokens.hbtn || 'transparent', 'hbtn-ink': tokens.hbtnInk || 'inherit', font: tokens.font, 'title-font': tokens.titleFont,
      'search-font': tokens.searchFont, 'title-w': tokens.titleWeight, 'search-w': tokens.searchWeight,
      'mark-ring': tokens.markRing, 'mark-dot': tokens.markDot, rule: tokens.sectionRule || 'transparent', tint: tokens.tint || 'transparent',
      motion: tokens.motion ? tokens.motion.easing : 'linear', 'motion-d': tokens.motion ? tokens.motion.duration + 'ms' : '0ms'
    };
    for (const [name, value] of Object.entries(vars)) panel.style.setProperty('--hl-' + name, value);
    drawMark();
    render();
  }

  // ——— Logo animé (Mark.swift) : anneau ouvert, point dans l'ouverture ———
  function drawMark() {
    const r = 31, start = -12.7, span = 295.4;
    const point = angle => [50 + r * Math.cos(angle * Math.PI / 180), 50 + r * Math.sin(angle * Math.PI / 180)];
    const [x0, y0] = point(start), [x1, y1] = point(start + span);
    const arc = `M${x0.toFixed(2)} ${y0.toFixed(2)}A${r} ${r} 0 1 1 ${x1.toFixed(2)} ${y1.toFixed(2)}`;
    const kind = tokens.kind;
    let ring = `<path class="ring" d="${arc}" pathLength="1" stroke="var(--hl-mark-ring)" stroke-width="13"/>`;
    if (kind === 'glyph' || kind === 'glyph-night') {
      // Anneau évidé : le contour de l'anneau plein, au filet fin.
      ring = `<path class="ring" d="${arc}" pathLength="1" stroke="var(--hl-mark-ring)" stroke-width="16"/><path class="ring" d="${arc}" pathLength="1" stroke="var(--hl-frame)" stroke-width="10.4"/>`;
    } else if (kind === 'brutal') {
      ring = `<path class="ring" d="${arc}" pathLength="1" stroke="#000" stroke-width="17"/>` + ring;
    }
    let dot = '<circle class="dot" cx="71.9" cy="28.1" r="6.5" fill="var(--hl-mark-dot)"/>';
    if (kind === 'phosphor') dot = '<rect class="dot" x="68.4" y="21.6" width="7" height="13" fill="var(--hl-mark-dot)"/>';
    if (kind === 'atelier') dot = `<path class="dot" fill="var(--hl-mark-dot)" d="${cookie(71.9, 28.1, 8.5, 9, .16)}"/>`;
    if (kind === 'brutal') dot = '<circle class="dot" cx="71.9" cy="28.1" r="7" fill="#ffd84d" stroke="#000" stroke-width="3"/>';
    markBox.innerHTML = `<svg viewBox="0 0 100 100" fill="none" stroke-linecap="round">${ring}${dot}</svg>`;
  }
  function cookie(cx, cy, radius, lobes, depth) {
    let d = '';
    for (let i = 0; i <= 72; i++) {
      const a = i / 72 * Math.PI * 2 - Math.PI / 2;
      const r = radius * (1 - depth * (1 - Math.cos(lobes * a)) / 2);
      d += (i ? 'L' : 'M') + (cx + r * Math.cos(a)).toFixed(2) + ' ' + (cy + r * Math.sin(a)).toFixed(2);
    }
    return d + 'Z';
  }
  function animateMark() {
    if (!motion()) return;
    const svg = markBox.firstElementChild;
    const dot = svg.querySelector('.dot');
    const pop = spring(.26, .55), draw = spring(.45, .92), turn = spring(.6, .82);
    dot.animate([{ transform: 'scale(0)' }, { transform: 'scale(1)' }], { duration: pop.duration, easing: pop.easing });
    svg.querySelectorAll('.ring').forEach(ring => ring.animate(
      [{ strokeDasharray: '0 1' }, { strokeDasharray: '1 0' }],
      { duration: draw.duration, delay: 100, easing: draw.easing, fill: 'backwards' }));
    if (tokens.kind.startsWith('glyph')) {
      svg.animate([{ transform: 'rotate(-150deg)' }, { transform: 'rotate(0)' }], { duration: turn.duration, easing: turn.easing });
    }
  }

  // ——— État ———
  let mode = 'root';
  let items = [];
  let selection = 0;
  let toastTimer;
  let escapeDeadline = 0;
  let agentTimer;
  let runTimer;
  let hidden = false;

  const modeInfo = {
    apps: ['Applications', 'grid', 'Rechercher une application…'],
    clipboard: ['Presse-papiers', 'clipboard', 'Rechercher dans l’historique…'],
    emoji: ['Emoji & Symboles', 'smile', 'Rechercher un emoji ou un symbole…'],
    output: ['Terminal', 'terminal', ''],
    agent: ['IA', 'sparkles', 'Poser une autre question…']
  };

  function el(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
  }
  function iconNode(icon, selected) {
    const box = el('span', 'hl-icon');
    if (icon.app) box.innerHTML = appIcon(icon.app);
    else if (icon.swatch) box.innerHTML = `<span class="hl-swatch" style="background:${icon.swatch}"></span>`;
    else {
      box.innerHTML = `<span class="hl-tile">${symbol(icon.symbol)}</span>`;
      box.firstElementChild.style.setProperty('--tint', icon.tint);
      if (tokens.kind === 'atelier') box.firstElementChild.innerHTML = `<svg class="hl-cookie" viewBox="0 0 26 26" aria-hidden="true"><path d="${cookie(13, 13, 13, 9, selected ? .16 : 0)}"/></svg>` + symbol(icon.symbol);
    }
    return box;
  }

  // ——— Rendu ———
  function filtered() {
    const q = field.value;
    if (mode === 'root') return rootItems(q);
    if (mode === 'apps') return apps.filter(item => fold(item.title).includes(fold(q.trim())));
    if (mode === 'clipboard') return clips.filter(item => fold(item.title).includes(fold(q.trim())));
    if (mode === 'emoji') return emoji.filter(item => fold(item.name).includes(fold(q.trim())));
    return [];
  }
  function render({ reveal = false } = {}) {
    panel.dataset.mode = mode;
    const info = modeInfo[mode];
    back.hidden = mode === 'root';
    markBox.hidden = mode !== 'root';
    buttons.hidden = mode !== 'root';
    if (info) back.innerHTML = `${symbol('chevron', 'hl-chev')}${symbol(info[1])}<span>${info[0]}</span>`;
    field.placeholder = info ? info[2] : 'Rechercher une app ou une commande…';
    field.hidden = mode === 'output' || (mode === 'agent' && requestBox.dataset.busy === 'true');
    runBox.hidden = mode !== 'output';
    requestBox.hidden = !(mode === 'agent' && requestBox.dataset.busy === 'true');
    if (mode === 'output' || mode === 'agent') { updateHints(); return; }
    items = filtered();
    selection = Math.max(0, Math.min(selection, items.length - 1));
    list.replaceChildren();
    if (!items.length) {
      list.append(emptyState(mode === 'clipboard' ? 'Copiez un élément pour le retrouver ici' : mode === 'emoji' ? 'Aucun caractère trouvé' : 'Aucun résultat'));
    } else if (mode === 'apps' || mode === 'emoji') renderGrid(reveal);
    else if (mode === 'clipboard') renderSplit(reveal);
    else renderList(list, reveal);
    fitHeight();
    updateHints();
  }
  function emptyState(text) {
    const box = el('div', 'hl-empty');
    box.innerHTML = `${symbol(modeInfo[mode]?.[1] || 'sparkles')}<span>${text}</span>`;
    return box;
  }
  function renderList(host, reveal) {
    const stack = el('div', 'hl-list');
    const slider = el('div', 'hl-sel');
    if (!tokens.segmented) stack.append(slider);
    items.forEach((item, index) => {
      const previous = items[index - 1];
      if (item.section && item.section !== previous?.section) {
        stack.append(el('div', 'hl-section', sectionTitle(item.section)));
      }
      stack.append(rowNode(item, index));
    });
    host.append(stack);
    if (tokens.segmented) segment(stack);
    placeSelection(false);
    if (reveal) cascade([...stack.querySelectorAll('.hl-row, .hl-section')]);
  }
  function sectionTitle(text) {
    switch (tokens.kind) {
      case 'phosphor': return '// ' + text.toLowerCase();
      case 'glyph': case 'glyph-night': case 'brutal': return text.toUpperCase();
      default: return text;
    }
  }
  function rowNode(item, index) {
    const row = el('button', 'hl-row');
    row.type = 'button';
    row.dataset.index = index;
    row.setAttribute('aria-label', [item.title, item.subtitle, item.accessory].filter(Boolean).join(', '));
    const text = el('span', 'hl-text');
    const title = el('span', 'hl-title');
    title.append(el('span', 'hl-cursor'), el('span', 'hl-label', item.title));
    text.append(title);
    if (item.subtitle) text.append(el('span', 'hl-sub', item.subtitle));
    row.append(iconNode(item.icon, index === selection), text);
    if (item.accessory) {
      const meta = el('span', 'hl-meta');
      if (item.accessory === 'Ouverte') meta.append(el('i', 'hl-live'));
      meta.append(item.accessory);
      row.append(meta);
    }
    row.addEventListener('pointermove', () => { if (selection !== index) select(index); });
    row.addEventListener('click', () => { select(index); if (mode !== 'clipboard') activate('primary'); });
    return row;
  }
  // Liste segmentée (Atelier) : coins larges aux bords du groupe, serrés entre les lignes.
  function segment(stack) {
    const rows = [...stack.querySelectorAll('.hl-row')];
    rows.forEach((row, i) => {
      const item = items[i];
      row.classList.toggle('first', i === 0 || items[i - 1].section !== item.section);
      row.classList.toggle('last', i === rows.length - 1 || items[i + 1].section !== item.section);
    });
  }
  function renderGrid(reveal) {
    const grid = el('div', mode === 'emoji' ? 'hl-grid hl-emoji' : 'hl-grid');
    const slider = el('div', 'hl-sel');
    grid.append(slider);
    items.forEach((item, index) => {
      const cell = el('button', 'hl-cell');
      cell.type = 'button';
      cell.dataset.index = index;
      if (mode === 'emoji') {
        cell.append(el('span', 'hl-glyph', item.char));
        cell.setAttribute('aria-label', item.name);
      } else {
        const name = el('span', 'hl-cell-name');
        if (item.running) name.append(el('i', 'hl-live'));
        name.append(item.title);
        cell.append(iconNode(item.icon), name);
        cell.setAttribute('aria-label', item.title);
      }
      cell.addEventListener('pointermove', () => { if (selection !== index) select(index); });
      cell.addEventListener('click', () => { select(index); activate('primary'); });
      grid.append(cell);
    });
    list.append(grid);
    if (mode === 'apps') {
      const dots = el('div', 'hl-dots');
      dots.append(el('i', 'on'), el('i'));
      list.append(dots);
    }
    placeSelection(false);
    if (reveal || mode === 'apps') springboard([...grid.querySelectorAll('.hl-cell')], mode === 'apps' ? 5 : 8);
  }
  function renderSplit(reveal) {
    const split = el('div', 'hl-split');
    const left = el('div', 'hl-split-list');
    const preview = el('div', 'hl-preview');
    split.append(left, preview);
    list.append(split);
    renderList(left, reveal);
    showPreview();
  }
  function showPreview() {
    const preview = list.querySelector('.hl-preview');
    const item = items[selection];
    if (!preview || !item) return;
    const body = el('div', item.mono ? 'hl-clip mono' : 'hl-clip');
    if (item.clipKind === 'Couleur') body.innerHTML = `<span class="hl-big-swatch" style="background:${item.body}"></span>${item.body}`;
    else body.textContent = item.body;
    const meta = el('dl', 'hl-meta-rows');
    for (const [label, value] of [['Type', item.clipKind], ['Source', item.source], ['Copié', item.subtitle.split(' · ')[1]]]) {
      meta.append(el('dt', '', label), el('dd', '', value));
    }
    preview.replaceChildren(body, meta);
  }

  // Hauteur du panneau selon les résultats, comme `panelRect` (plafonnée à la taille du panneau).
  function fitHeight() {
    const inner = list.firstElementChild;
    const fixed = mode === 'apps' || mode === 'emoji' || mode === 'clipboard' || mode === 'output' || mode === 'agent';
    const height = fixed ? 360 : Math.min(360, Math.max(64, (inner?.scrollHeight || 64)));
    pane.style.height = height + 'px';
  }

  function rowsOf() { return [...list.querySelectorAll('.hl-row, .hl-cell')]; }
  function placeSelection(animated = true) {
    const nodes = rowsOf();
    nodes.forEach((node, i) => {
      const on = i === selection;
      node.classList.toggle('selected', on);
      node.setAttribute('aria-current', String(on));
      const tile = node.querySelector('.hl-cookie path');
      if (tile) tile.setAttribute('d', cookie(13, 13, 13, 9, on ? .16 : 0));
    });
    const current = nodes[selection];
    const slider = current?.parentElement.querySelector(':scope > .hl-sel');
    if (!current || !slider) return;
    slider.classList.toggle('instant', !animated || !motion() || !tokens.motion);
    slider.style.transform = `translate(${current.offsetLeft}px, ${current.offsetTop}px)`;
    slider.style.width = current.offsetWidth + 'px';
    slider.style.height = current.offsetHeight + 'px';
    slider.style.opacity = '1';
    const scroller = current.closest('.hl-content, .hl-split-list');
    if (scroller) {
      const top = current.offsetTop, bottom = top + current.offsetHeight;
      if (top < scroller.scrollTop + 8) scroller.scrollTop = top - 8;
      else if (bottom > scroller.scrollTop + scroller.clientHeight - 8) scroller.scrollTop = bottom - scroller.clientHeight + 8;
    }
  }
  function select(index) {
    selection = index;
    placeSelection(true);
    if (mode === 'clipboard') showPreview();
    updateHints();
  }

  // ——— Pied de page : toast à gauche, raccourcis à droite (KeyCap) ———
  function hintsFor() {
    if (mode === 'output') return [['Copier la sortie', '↵'], [runBox.dataset.running === 'true' ? 'Arrêter' : 'Relancer', runBox.dataset.running === 'true' ? '⌃C' : '⌘R'], ['Dans Terminal', '⌘↵']];
    if (mode === 'agent') return requestBox.dataset.busy === 'true'
      ? [['Arrière-plan', '⌘W'], ['Annuler', 'esc esc']]
      : [['Copier', '↵'], ['Recherche & Action', '⌘↵'], ['Retour', 'esc esc']];
    if (mode === 'emoji') return [['Coller', '↵'], ['Copier', '⌘↵'], ['Symboles', '⇥']];
    const item = items[selection];
    if (!item) return [];
    const hints = [[item.primary, '↵']];
    if (item.secondary) hints.push([item.secondary, '⌘↵']);
    if (item.tertiary) hints.push([item.tertiary, '⌥↵']);
    if (item.remove) hints.push([item.remove, '⌘⌫']);
    if (item.completion) hints.push(['Compléter', '⇥']);
    return hints;
  }
  function updateHints() {
    hintsBox.replaceChildren(...hintsFor().map(([label, key]) => {
      const hint = el('span', key === '↵' ? 'hl-hint primary' : 'hl-hint');
      hint.append(el('span', '', label), el('kbd', key === '↵' ? 'hl-key primary' : 'hl-key', key));
      return hint;
    }));
    if (mode === 'emoji' && items[selection] && !toastTimer) {
      toastBox.innerHTML = '';
      toastBox.append(el('b', '', items[selection].name), el('span', '', '   ' + items[selection].code));
    } else if (!toastTimer) toastBox.textContent = '';
  }
  function toast(message) {
    clearTimeout(toastTimer);
    toastBox.textContent = message;
    toastBox.classList.add('toast');
    toastTimer = setTimeout(() => { toastTimer = null; toastBox.classList.remove('toast'); updateHints(); }, 2600);
  }

  // ——— Actions ———
  function activate(which) {
    escapeDeadline = 0;
    if (mode === 'emoji') {
      const glyph = items[selection];
      if (glyph) toast(which === 'secondary' ? `${glyph.char} copié` : `${glyph.char} serait collé dans l’app active`);
      return;
    }
    const item = items[selection];
    if (!item) return;
    const label = which === 'secondary' ? item.secondary : which === 'tertiary' ? item.tertiary : item.primary;
    if (!label) return;
    if (which === 'primary' && item.mode) return enter(item.mode);
    if (which === 'primary' && item.kind === 'app') return launch(item);
    if (which === 'primary' && item.kind === 'run') return startRun(item.command);
    if (which === 'primary' && item.kind === 'agent') return startAgent(item.request);
    if (which === 'primary' && item.kind === 'clip') return toast('Collé dans l’app active (démo)');
    if (which === 'primary' && item.kind === 'noop') return;
    toast(`${label} · ${item.title} (démo)`);
  }
  function enter(next) {
    mode = next;
    selection = 0;
    field.value = '';
    render({ reveal: true });
    transitionContent(1);
    field.focus({ preventScroll: true });
  }
  function goBack() {
    clearTimeout(runTimer);
    clearTimeout(agentTimer);
    requestBox.dataset.busy = 'false';
    mode = 'root';
    selection = 0;
    field.value = '';
    render();
    transitionContent(-1);
    field.focus({ preventScroll: true });
  }
  // Changement d'écran : le nouveau glisse depuis le côté (`modeTransition`).
  function transitionContent(side) {
    if (!motion()) return;
    const distance = { glyph: 22, 'glyph-night': 22, atelier: 30, phosphor: 0, paper: 16, brutal: 26 }[tokens.kind];
    const curve = tokens.kind === 'phosphor' ? { easing: 'linear', duration: 60 } : spring(.36, .82);
    list.animate([{ transform: `translateX(${distance * side}px)`, opacity: 0 }, { transform: 'none', opacity: 1 }],
      { duration: curve.duration, easing: curve.easing });
  }

  // Lancement d'une app : la sélection et la barre de recherche prennent sa couleur, puis le panneau s'efface.
  function launch(item) {
    const tint = tokens.kind === 'glyph-night' ? tokens.ink : item.tint;
    panel.style.setProperty('--hl-launch', tint);
    panel.classList.add('launching');
    const close = motion() ? closePanel() : Promise.resolve();
    close.then(() => setTimeout(() => {
      panel.classList.remove('launching');
      open({ light: true });
      toast(`${item.title} s’ouvrirait sur ton Mac (démo)`);
    }, motion() ? 520 : 0));
  }
  function closePanel() {
    const frames = {
      wave: [{ opacity: 1, transform: 'none' }, { opacity: 0, transform: 'scale(.97)' }],
      unfold: [{ opacity: 1, transform: 'none' }, { opacity: 0, transform: 'scale(.96, .9)' }],
      crt: [{ transform: 'none', filter: 'brightness(1)' }, { transform: 'scale(1, .01)', filter: 'brightness(3)', offset: .7 }, { transform: 'scale(0, .01)', filter: 'brightness(3)', opacity: 0 }],
      page: [{ opacity: 1, transform: 'none' }, { opacity: 0, transform: 'perspective(900px) rotateX(10deg) translateY(-6px)' }],
      slam: [{ transform: 'none', boxShadow: 'var(--hl-shadow)' }, { transform: 'translate(6px, 6px)', boxShadow: '2px 2px 0 #000', offset: .4 }, { transform: 'translate(6px, 6px)', boxShadow: '2px 2px 0 #000', opacity: 0 }]
    }[tokens.reveal];
    hidden = true;
    const animation = panel.animate(frames, { duration: 300, delay: 120, easing: 'ease-in', fill: 'forwards' });
    return animation.finished.catch(() => {});
  }

  function startRun(cmd) {
    mode = 'output';
    clearTimeout(runTimer);
    runBox.innerHTML = '';
    runBox.append(el('span', 'hl-run-cmd', '$ ' + cmd), el('span', 'hl-run-status'));
    runBox.dataset.running = 'true';
    runBox.querySelector('.hl-run-status').innerHTML = '<i class="hl-spinner"></i>';
    render();
    const output = el('pre', 'hl-output');
    list.replaceChildren(output);
    fitHeight();
    transitionContent(1);
    const lines = cmd.startsWith('git status')
      ? ['Sur la branche main', 'Votre branche est à jour avec \'origin/main\'.', '', 'Modifications qui ne seront pas validées :', '\tmodifié :         website/dist/app.js', '\tmodifié :         website/dist/styles.css', '', 'aucune modification n\'a été ajoutée à la validation']
      : ['(démo) La commande s’exécuterait dans zsh depuis ~', 'Rien n’est lancé sur cette page.'];
    let i = 0;
    const step = () => {
      if (mode !== 'output') return;
      if (i < lines.length) {
        output.textContent += (i ? '\n' : '') + lines[i++];
        runTimer = setTimeout(step, motion() ? 45 : 0);
      } else {
        runBox.dataset.running = 'false';
        runBox.querySelector('.hl-run-status').innerHTML = `${symbol('check', 'hl-ok')}<span>OK · 0,4 s</span>`;
        updateHints();
      }
    };
    step();
  }
  // Réponses d'exemple : la démo n'envoie rien, elle choisit selon quelques mots de la demande.
  const answers = [
    [/captur|renomm/, 'Pour renommer tes captures d’écran par date, lance ceci dans le dossier Bureau :', 'for f in Capture*.png; do mv "$f" "$(stat -f %SB -t %Y-%m-%d_%H%M%S "$f").png"; done', '⌘ Entrée envoie la commande au terminal de Hello ; rien n’est exécuté sans ton accord.'],
    [/dossier|fichier|cd |ouvr/, 'Tape « cd » suivi du chemin du dossier. Entrée l’ouvre dans le Finder ; ⌘ Entrée le reprend dans ton terminal.', 'cd ~/Documents', 'Tu peux aussi taper « z » et une partie du nom : Hello retrouve les dossiers que tu ouvres souvent.'],
    [/couleur|hex|rgb/, 'Le presse-papiers garde les couleurs copiées avec leur aperçu. Pour convertir un hexadécimal :', '#ED6A0C → rgb(237, 106, 12)', 'Entrée colle la valeur dans l’app au premier plan.'],
    [/./, 'Voici une réponse d’exemple : sur ton Mac, Luna répond ici même, sans quitter le lanceur.', '⌥ Entrée → niveau Code', 'Le niveau 1 répond vite ; Recherche & Action et Code passent la main au fournisseur de ton choix.']
  ];
  function startAgent(request) {
    mode = 'agent';
    requestBox.textContent = request;
    requestBox.dataset.busy = 'true';
    render();
    const view = el('article', 'hl-agent');
    const status = el('div', 'hl-agent-status');
    status.innerHTML = `${symbol('sparkles')}<span>Luna réfléchit…</span>`;
    view.append(el('h3', '', request), status);
    list.replaceChildren(view);
    fitHeight();
    transitionContent(1);
    agentTimer = setTimeout(() => {
      requestBox.dataset.busy = 'false';
      render();
      status.innerHTML = `${symbol('bubbles')}<span>Réponse de Luna · exemple, aucune requête envoyée</span>`;
      const answer = el('div', 'hl-answer');
      const [before, code, after] = (answers.find(([pattern]) => pattern.test(fold(request))) || answers.at(-1)).slice(1);
      answer.append(el('p', '', before), el('code', '', code), el('p', '', after));
      view.append(answer);
      list.replaceChildren(view);
      if (motion()) answer.animate([{ opacity: 0, transform: 'translateY(6px)' }, { opacity: 1, transform: 'none' }], { duration: 260, easing: 'ease-out' });
    }, motion() ? 900 : 0);
  }

  // ——— Ouverture (RevealStyle.open) et effet signature de chaque style ———
  function open({ light = false } = {}) {
    hidden = false;
    panel.getAnimations().forEach(animation => animation.cancel());
    render({ reveal: !light });
    if (!motion()) return;
    animateMark();
    const curves = {
      wave: light ? spring(.22, .9) : spring(.46, .8), unfold: light ? spring(.22, .86) : spring(.44, .72),
      crt: { easing: 'cubic-bezier(.2,.9,.3,1)', duration: light ? 100 : 340 }, page: light ? { easing: 'ease-out', duration: 140 } : spring(.48, .84),
      slam: light ? spring(.2, .75) : spring(.36, .5)
    };
    const frames = {
      wave: [{ opacity: 0, transform: 'translateY(14px) scale(.96)' }, { opacity: 1, transform: 'none' }],
      unfold: [{ opacity: 0, transform: 'scale(.96, .72)' }, { opacity: 1, transform: 'none' }],
      crt: [{ transform: 'scale(1, .01)', filter: 'brightness(3)' }, { transform: 'scale(1, 1)', filter: 'brightness(1.6)', offset: .6 }, { transform: 'none', filter: 'brightness(1)' }],
      page: [{ opacity: 0, transform: 'perspective(900px) rotateX(-16deg) translateY(-8px)' }, { opacity: 1, transform: 'none' }],
      slam: [{ transform: 'translate(-6px, -40px)', boxShadow: '0 0 0 #000' }, { transform: 'none', boxShadow: '8px 8px 0 #000' }]
    }[tokens.reveal];
    const curve = curves[tokens.reveal];
    panel.animate(frames, { duration: curve.duration, easing: curve.easing });
    if (!light) signature();
  }
  function signature() {
    fx.replaceChildren();
    const layer = el('div', 'hl-fx-' + tokens.reveal);
    fx.append(layer);
    const done = () => layer.remove();
    if (tokens.reveal === 'wave') {
      // Une onde de points part du logo et traverse le panneau.
      layer.animate([{ '--wave': '0px', opacity: 1 }, { '--wave': '900px', opacity: 0 }], { duration: 900, easing: 'cubic-bezier(.2,.7,.3,1)' }).onfinish = done;
    } else if (tokens.reveal === 'unfold') {
      layer.animate([{ opacity: 0, transform: 'scale(.94)' }, { opacity: 1, transform: 'none', offset: .35 }, { opacity: 0, transform: 'scale(1.02)' }], { duration: 900, easing: 'ease-out' }).onfinish = done;
    } else if (tokens.reveal === 'crt') {
      layer.animate([{ transform: 'translateY(-10%)' }, { transform: 'translateY(105%)' }], { duration: 520, delay: 200, easing: 'linear', fill: 'backwards' }).onfinish = done;
    } else if (tokens.reveal === 'page') {
      layer.animate([{ transform: 'scaleX(0)', opacity: 1 }, { transform: 'scaleX(1)', opacity: 1, offset: .45 }, { transform: 'scaleX(1)', opacity: 0 }], { duration: 1100, delay: 120, easing: 'ease-out', fill: 'backwards' }).onfinish = done;
    } else {
      const stamp = spring(.36, .62);
      panel.animate([{ boxShadow: '8px 8px 0 #000, 18px 18px 0 var(--hl-sel)' }, { boxShadow: '8px 8px 0 #000, 8px 8px 0 var(--hl-sel)' }], { duration: stamp.duration, delay: 160, easing: stamp.easing });
      done();
    }
  }
  // Arrivée des résultats (RevealItem) : cascade serrée, dans le geste du style.
  function cascade(nodes) {
    if (!motion()) return;
    const kind = tokens.reveal;
    const curve = kind === 'slam' ? spring(.3, .55) : spring(.42, .82);
    nodes.forEach((node, order) => {
      const delay = (60 + Math.min(order, 12) * 34);
      if (kind === 'crt') {
        node.animate([{ opacity: 0 }, { opacity: 0, offset: .99 }, { opacity: 1 }], { duration: 40 + order * 45, fill: 'backwards' });
        return;
      }
      const from = { wave: 'translateY(10px)', unfold: 'translateY(14px) scale(.98)', page: 'translateX(-10px)', slam: 'translateY(-12px) scale(1.04)' }[kind];
      node.animate([{ opacity: 0, transform: from }, { opacity: 1, transform: 'none' }], { duration: curve.duration, delay, easing: curve.easing, fill: 'backwards' });
      if (tokens.kind.startsWith('glyph')) decode(node.querySelector('.hl-label'), delay);
    });
  }
  // Glyphe : les titres se décodent (DecodeText, Motion.swift).
  const ramp = '.:-=+*#%@';
  const noiseGlyphs = 'ABCDEFGHJKLMNPQRSTUVWXYZ0123456789#%&*+=?/';
  function decode(node, delay) {
    if (!node) return;
    const text = node.textContent;
    const duration = Math.min(.3 + text.length * .012, .6) * 1000;
    const start = performance.now() + delay;
    node.style.minWidth = node.offsetWidth + 'px';
    const frame = now => {
      const progress = (now - start) / duration;
      if (!node.isConnected) return;
      if (progress >= 1) { node.textContent = text; node.style.minWidth = ''; return; }
      const tick = Math.floor(Math.max(progress, 0) * 26);
      node.textContent = [...text].map((char, i) => {
        const settle = .4 + .6 * i / text.length;
        const phase = (progress - settle + .4) / .4;
        if (char === ' ' || progress >= settle) return char;
        if (phase < 0) return ' ';
        if (phase < .45) return ramp[Math.min(ramp.length - 1, Math.floor(phase / .45 * ramp.length))];
        return noiseGlyphs[(i * 7 + tick * 13) % noiseGlyphs.length];
      }).join('');
      requestAnimationFrame(frame);
    };
    requestAnimationFrame(frame);
  }
  // Grille : les icônes arrivent du dehors, grossies et floues, du centre vers les bords (SpringboardReveal).
  function springboard(cells, columns) {
    if (!motion()) return;
    const rows = Math.ceil(cells.length / columns);
    const curve = spring(.42, .8);
    cells.forEach((cell, i) => {
      const dx = (i % columns) - (columns - 1) / 2, dy = Math.floor(i / columns) - (rows - 1) / 2;
      const distance = Math.hypot(dx, dy);
      cell.animate([
        { opacity: 0, transform: `translate(${dx * 24}px, ${dy * 24}px) scale(1.5)`, filter: 'blur(6px)' },
        { opacity: 1, transform: 'none', filter: 'blur(0)' }
      ], { duration: curve.duration, delay: distance * 40, easing: curve.easing, fill: 'backwards' });
    });
  }

  // ——— Clavier et souris ———
  function moveSelection(dx, dy) {
    if (!items.length) return;
    const grid = mode === 'apps' || mode === 'emoji';
    const columns = grid ? Math.max(1, Math.round(list.querySelector('.hl-grid').clientWidth / list.querySelector('.hl-cell').offsetWidth)) : 1;
    const step = grid ? dx + dy * columns : dy;
    select((selection + step + items.length) % items.length);
  }
  panel.addEventListener('keydown', event => {
    if (event.key !== 'Escape') escapeDeadline = 0;
    const grid = mode === 'apps' || mode === 'emoji';
    if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
      event.preventDefault();
      moveSelection(0, event.key === 'ArrowDown' ? 1 : -1);
    } else if (grid && (event.key === 'ArrowLeft' || event.key === 'ArrowRight') && document.activeElement !== field) {
      event.preventDefault();
      moveSelection(event.key === 'ArrowRight' ? 1 : -1, 0);
    } else if (event.key === 'Enter') {
      event.preventDefault();
      if (mode === 'output') return toast(runBox.dataset.running === 'true' ? 'Commande en cours' : 'Sortie copiée');
      if (mode === 'agent') return requestBox.dataset.busy === 'true' ? null : toast('Réponse copiée');
      activate(event.metaKey ? 'secondary' : event.altKey ? 'tertiary' : 'primary');
    } else if (event.key === 'Tab' && items[selection]?.completion) {
      event.preventDefault();
      field.value = items[selection].completion;
      render();
    } else if (event.key === 'Escape') {
      event.preventDefault();
      if (event.repeat) return;
      if (mode === 'agent' || mode === 'output') {
        if (performance.now() < escapeDeadline) goBack();
        else { escapeDeadline = performance.now() + 2500; toast('Encore Échap pour revenir'); }
      } else if (field.value) { field.value = ''; selection = 0; render(); }
      else if (mode !== 'root') goBack();
      else if (!hidden) closePanel().then(() => setTimeout(() => open({ light: true }), 400));
    }
  });
  field.addEventListener('input', () => {
    escapeDeadline = 0;
    selection = 0;
    render();
  });
  document.getElementById('search-form').addEventListener('submit', event => event.preventDefault());
  back.addEventListener('click', goBack);
  document.getElementById('show-apps').addEventListener('click', () => enter('apps'));
  buttons.querySelectorAll('[data-demo]').forEach(button => button.addEventListener('click', () => toast(button.dataset.demo)));
  panel.addEventListener('pointerdown', event => {
    if (!event.target.closest('button, input')) field.focus({ preventScroll: true });
  });

  function run(query) {
    clearTimeout(runTimer);
    requestBox.dataset.busy = 'false';
    mode = 'root';
    selection = 0;
    field.value = query;
    render();
    const first = items[0];
    if (first && (first.mode || first.kind === 'run' || first.kind === 'agent')) { selection = 0; activate('primary'); }
    else if (query === '?' || query === 'cd ~/') field.focus({ preventScroll: true });
  }
  function settle() {
    clearTimeout(agentTimer);
    if (mode === 'agent' && requestBox.dataset.busy === 'true') startAgent(requestBox.textContent);
  }

  return { setStyle, open, render, run, settle, icon: symbol };
})();
