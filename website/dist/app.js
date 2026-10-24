'use strict';

const root = document.documentElement;
const $ = selector => document.querySelector(selector);
const launcher = $('#launcher');
const variantSelect = $('#variant');
const appearanceSelect = $('#appearance');
const reduceMotion = matchMedia('(prefers-reduced-motion: reduce)');
let preferences = {};
try { preferences = JSON.parse(localStorage.getItem('hello-site') || '{}') || {}; } catch { /* Stockage facultatif. */ }
const themes = {
  atelier: { name: 'Atelier Expressif', detail: 'Listes segmentées, formes souples et deux accents.', label: 'Palette', appearances: ['dark', 'light'], variants: [
    ['Lime / Lavande', '#d4f54a', '#b7aef7'], ['Orange / Ciel', '#ff6a2b', '#8fd3ff'], ['Rose / Menthe', '#ff5fa2', '#7ff0c4'],
    ['Jaune / Outremer', '#ffd23f', '#7d95ff'], ['Rouge / Sable', '#ff4f3a', '#efe2c4'], ['Accent macOS', '#93b8ff', '#c6daff'] ] },
  glyph: { name: 'Atelier Glyphe', detail: 'Noir chaud, accent unique et sélection inversée.', label: 'Accent', appearances: ['dark', 'light', 'night'], variants: [
    ['Orange', '#ed6a0c', '#fff'], ['Ambre', '#efb85c', '#111'], ['Vert', '#78dd8b', '#111'],
    ['Corail', '#ff6c67', '#111'], ['Violet', '#a25bff', '#fff'], ['Mono', null, null] ] },
  phosphor: { name: 'Phosphore', detail: 'Écran cathodique, caractères fixes et sélection inversée.', label: 'Phosphore', variants: [
    ['Vert P1', '#4bff88', '#040a06'], ['Ambre P3', '#ffb43a', '#0b0702'], ['Blanc P4', '#e6eeff', '#05070b'], ['Cyan', '#3be8ff', '#02090c'] ] },
  paper: { name: 'Papier', detail: 'Titres à empattements, filets fins et marque-page.', label: 'Papier', variants: [
    ['Crème', '#f4efe6', '#e8dfce'], ['Ivoire', '#fbfaf5', '#efece2'], ['Nuit', '#1e1b17', '#2e2923'] ] },
  brutal: { name: 'Néo-brutal', detail: 'Contours noirs, ombres pleines et couleurs franches.', label: 'Sélection', variants: [
    ['Rose', '#ff8ad8'], ['Jaune', '#ffd84d'], ['Bleu', '#7cb8ff'], ['Vert', '#7be495'] ] }
};
let theme = Object.hasOwn(themes, preferences.theme) ? preferences.theme : 'glyph';
let appearance = ['dark', 'light', 'night'].includes(preferences.appearance) ? preferences.appearance : 'dark';
let motionOn = preferences.motion !== false;
let variants = preferences.variants && typeof preferences.variants === 'object' ? preferences.variants : {};
let notificationTimer;
let themeTransition;
let transitionRevision = 0;

let tourRunning = false;
let tourFrame;
let tourReturn;
let tourShow;
let tourVeil;
let tourLooks;
let tourTier = 'full';
const easeInOut = x => x < .5 ? 4 * x ** 3 : 1 - (-2 * x + 2) ** 3 / 2;
const easeOutBack = x => 1 + 2.4 * (x - 1) ** 3 + 1.4 * (x - 1) ** 2;
const clamp01 = x => Math.min(1, Math.max(0, x));
// Comète de points de l’Atelier Glyphe : des points qui courent sur une forme qui change, tête à l’accent.
const cometSamples = 120;
const fromInside = inside => angle => {
  const c = Math.cos(angle), s = Math.sin(angle);
  let r = 0;
  while (r < 2 && inside(r * c, r * s)) r += .02;
  let low = Math.max(0, r - .02), high = r;
  for (let i = 0; i < 14; i++) { const mid = (low + high) / 2; if (inside(mid * c, mid * s)) low = mid; else high = mid; }
  return (low + high) / 2;
};
function roundedPolygon(sides, rounding, start = -Math.PI / 2) {
  const corners = Array.from({ length: sides }, (_, i) => {
    const a = start + i * 2 * Math.PI / sides;
    return [Math.cos(a) * (1 - rounding), Math.sin(a) * (1 - rounding)];
  });
  return (x, y) => {
    let inside = true, far = -1e9, near = 1e9;
    corners.forEach(([ax, ay], i) => {
      const [bx, by] = corners[(i + 1) % sides];
      let nx = by - ay, ny = ax - bx;
      const length = Math.hypot(nx, ny); nx /= length; ny /= length;
      if (nx * ax + ny * ay < 0) { nx = -nx; ny = -ny; }
      const edge = (x - ax) * nx + (y - ay) * ny;
      if (edge > 0) inside = false;
      far = Math.max(far, edge);
      const ex = bx - ax, ey = by - ay, t = clamp01(((x - ax) * ex + (y - ay) * ey) / (ex * ex + ey * ey));
      near = Math.min(near, Math.hypot(x - ax - ex * t, y - ay - ey * t));
    });
    return (inside ? far : near) < rounding * .8;
  };
}
const pixelated = test => fromInside((x, y) => Math.abs(x) <= 1 && Math.abs(y) <= 1
  && test((Math.floor((x + 1) * 4) + .5) / 4 - 1, (Math.floor((y + 1) * 4) + .5) / 4 - 1));
function cometPoints(radius, turn = 0) {
  const points = new Float32Array(cometSamples * 2);
  let x0 = 9, x1 = -9, y0 = 9, y1 = -9;
  for (let i = 0; i < cometSamples; i++) {
    const angle = i / cometSamples * Math.PI * 2 - Math.PI / 2, r = radius(angle - turn);
    const x = r * Math.cos(angle), y = r * Math.sin(angle);
    points[2 * i] = x; points[2 * i + 1] = y;
    x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y);
  }
  const cx = (x0 + x1) / 2, cy = (y0 + y1) / 2, size = 2 / Math.max(x1 - x0, y1 - y0);
  for (let i = 0; i < cometSamples; i++) { points[2 * i] = (points[2 * i] - cx) * size; points[2 * i + 1] = (points[2 * i + 1] - cy) * size; }
  return points;
}
// Même suite que la charte : cookie 9, carré, trèfle, pilule, soleil, cercle pixel, triangle, cookie 4.
const cometShapes = [
  [a => 1 + .065 * Math.cos(9 * a)],
  [fromInside(roundedPolygon(4, .3, Math.PI / 4))],
  [a => .58 + .42 * Math.abs(Math.cos(2 * a)) ** .55, Math.PI / 4],
  [fromInside((x, y) => Math.hypot(x - Math.max(-.48, Math.min(.48, x)), y) < .52)],
  [a => .91 + .18 * ((1 + Math.cos(8 * a)) / 2) ** 1.6],
  [pixelated((u, v) => u * u + v * v < .86)],
  [fromInside(roundedPolygon(3, .32))],
  [a => 1 + .14 * Math.cos(4 * a), Math.PI / 4]
].map(([radius, turn]) => cometPoints(radius, turn));
function comet(host, { count = 24, size = 3.4, span = .82, swap = 520 } = {}) {
  host.innerHTML = `<svg class="comet" viewBox="0 0 100 100" aria-hidden="true">${'<circle r="1"/>'.repeat(count)}</svg>`;
  const dots = [...host.firstElementChild.children];
  dots[count - 1].classList.add('head');
  let shape = 0, from = cometShapes[0], swapped = 0, morphStart = 0, offset = 0, turn = 0, last = 0;
  const current = from.slice();
  return now => {
    const dt = last ? Math.min(.05, (now - last) / 1000) : 0;
    last = now;
    swapped ||= now;
    offset = (offset + dt * .62) % 1;
    turn += dt * 36;
    if (now - swapped > swap) {
      swapped = morphStart = now;
      shape = (shape + 1) % cometShapes.length;
      from = current.slice();
    }
    const elapsed = (now - morphStart) / 1000;
    const p = elapsed >= settle(.62, 800) ? 1 : springAt(elapsed, .62, 800);
    const target = cometShapes[shape];
    for (let i = 0; i < cometSamples * 2; i++) current[i] = from[i] + (target[i] - from[i]) * p;
    const r = turn * Math.PI / 180, cos = Math.cos(r), sin = Math.sin(r);
    dots.forEach((dot, i) => {
      const f = i / (count - 1), u = ((f * span + offset) % 1) * cometSamples;
      const i0 = Math.floor(u) % cometSamples, i1 = (i0 + 1) % cometSamples, t = u - Math.floor(u);
      const x = current[2 * i0] + (current[2 * i1] - current[2 * i0]) * t;
      const y = current[2 * i0 + 1] + (current[2 * i1 + 1] - current[2 * i0 + 1]) * t;
      dot.setAttribute('cx', (50 + (x * cos - y * sin) * 40).toFixed(2));
      dot.setAttribute('cy', (50 + (x * sin + y * cos) * 40).toFixed(2));
      dot.setAttribute('r', (size * (.32 + .68 * f ** 1.3)).toFixed(2));
      dot.setAttribute('opacity', (.1 + .9 * f ** 1.6).toFixed(2));
    });
  };
}

// Toutes les combinaisons proposées sur le web, regroupées par style pour que le défilé reste lisible.
const combinations = ['glyph', 'atelier', 'paper', 'brutal', 'phosphor'].flatMap(name => {
  const config = themes[name];
  return (config.appearances || [null]).flatMap(look => name === 'glyph' && look === 'night'
    ? [[name, look, 0]]
    : config.variants.map((_, index) => [name, look, index]));
});
// Hélice : 12 cartes par tour, 3 tours. Rotation 1,9 s, repli 0,42 s.
const tourSpin = 1900;
const tourCollapse = 420;
const tourAngle = Math.PI * 2 / 12;

// Relève les vraies couleurs calculées de chaque combinaison, sans peindre entre deux,
// puis range les sombres avant les claires pour que la page ne clignote pas entre les deux.
function captureLooks() {
  const labels = { dark: 'Sombre', light: 'Clair', night: 'Nuit' };
  const saved = { theme, appearance, variants: { ...variants } };
  const looks = combinations.map(([name, look, index]) => {
    theme = name; variants[name] = index; if (look) appearance = look;
    commitTheme();
    const page = getComputedStyle(root);
    const panel = getComputedStyle(launcher);
    const list = getComputedStyle($('.hl-pane'));
    const value = property => page.getPropertyValue(property).trim();
    const short = document.querySelector(`[data-theme="${name}"] span`).textContent;
    const variant = look === 'night' && name === 'glyph' ? 'Nuit' : themes[name].variants[index][0];
    return {
      name,
      combination: [name, look, index],
      dark: page.colorScheme !== 'light',
      label: [short, variant, look && look !== 'night' ? labels[look] : ''].filter(Boolean).join(' · '),
      colors: {
        frame: panel.backgroundColor, ink: panel.color, shadow: panel.boxShadow, list: list.backgroundColor, 'list-ink': list.color,
        surface: value('--surface'), line: value('--line'), accent: value('--accent'), secondary: value('--secondary') || value('--accent'),
        selection: value('--selection'), 'on-selection': value('--on-selection'),
        radius: value('--radius'), row: value('--row-radius'), display: getComputedStyle($('#hero-title')).fontFamily
      }
    };
  }).sort((a, b) => b.dark - a.dark);
  ({ theme, appearance, variants } = saved);
  commitTheme();
  return looks;
}
function comboCard(look) {
  const card = el('div', 'combo-card');
  card.dataset.kind = look.name;
  for (const [name, value] of Object.entries(look.colors)) card.style.setProperty(`--k-${name}`, value);
  const bar = el('div', 'cc-bar');
  bar.append(el('i'), el('span'));
  const rows = el('div', 'cc-list');
  for (let i = 0; i < 3; i++) {
    const row = el('div', i ? 'cc-row' : 'cc-row selected');
    row.append(el('i'), el('span'));
    rows.append(row);
  }
  card.append(bar, rows, el('div', 'cc-name', look.label));
  return card;
}
function celebrate(x, y) {
  const finale = el('div', 'combo-finale');
  finale.setAttribute('aria-hidden', 'true');
  finale.style.left = `${x}px`;
  finale.style.top = `${y}px`;
  const ring = el('i');
  const label = el('b', '', `${combinations.length} combinaisons`);
  finale.append(ring, label);
  document.body.append(finale);
  ring.animate([{ transform: 'scale(.15)', opacity: 1 }, { transform: 'scale(5)', opacity: 0 }], { duration: 760, easing: 'cubic-bezier(.16,1,.3,1)', fill: 'both' });
  label.animate([
    { transform: 'scale(.4)', opacity: 0 }, { transform: 'scale(1.12)', opacity: 1, offset: .18 },
    { transform: 'scale(1)', opacity: 1, offset: .3 }, { transform: 'translateY(-36px) scale(.96)', opacity: 0 }
  ], { duration: 1500, easing: 'cubic-bezier(.22,.8,.2,1)', fill: 'both' }).onfinish = () => finale.remove();
}
// Hélice de mini-lanceurs autour de (x, y). place() la pose : position = carte de face, spread de 0 (repliée) à 1.
function buildHelix(x, y) {
  const scale = Math.min(1, Math.max(.5, innerWidth / 1100));
  const radius = 380 * scale;
  const rise = 15 * scale;
  const show = el('div', 'combo-show');
  show.setAttribute('aria-hidden', 'true');
  show.style.perspectiveOrigin = `${x}px ${y}px`;
  const stage = el('div', 'combo-stage');
  stage.style.left = `${x}px`;
  stage.style.top = `${y}px`;
  const cards = tourLooks.map(comboCard);
  const count = el('div', 'combo-count');
  const number = el('b', '', '01');
  count.append(number, el('span', '', 'combinaisons'));
  stage.append(count, ...cards);
  show.append(stage);
  document.body.append(show);
  function place(position, spread, progress, fade) {
    const swing = Math.sin(Math.PI * progress);
    stage.style.transform = `rotateX(${-16 * swing}deg) rotateZ(${-6 * swing}deg)`;
    cards.forEach((card, i) => {
      const offset = i - position;
      const angle = offset * tourAngle;
      const ring = radius * spread;
      const lift = offset * rise * spread;
      const focus = Math.max(0, 1 - Math.abs(offset));
      const depth = (Math.cos(angle) + 1) / 2;
      card.style.transform = `translate3d(${Math.sin(angle) * ring}px,${lift}px,${(Math.cos(angle) - 1) * ring}px) rotateY(${angle}rad) scale(${scale * (.4 + .6 * spread) * (1 + .25 * focus)})`;
      card.style.opacity = fade * clamp01(spread * 1.6) * (.15 + .85 * depth) * clamp01(1.3 - Math.abs(lift) / (280 * scale));
    });
    count.style.transform = `translate(-50%,-50%) translateY(${-80 * scale}px) translateZ(${-radius * spread}px) scale(${scale * (.6 + .4 * spread)})`;
    count.style.opacity = fade * clamp01(spread * 1.4);
  }
  return { show, number, place };
}
function stopTour(restore = false, origin) {
  cancelAnimationFrame(tourFrame);
  if (!tourRunning) return;
  tourRunning = false;
  delete root.dataset.tour;
  tourShow?.remove();
  tourVeil?.cancel();
  if (restore) { ({ theme, appearance, variants } = tourReturn); applyTheme(true, origin); }
  $('#tour-status').textContent = 'Essaie Hello';
}
function startTour() {
  stopTour(true);
  if (!motionEnabled()) return;
  transitionRevision++;
  themeTransition?.skipTransition();
  tourReturn = { theme, appearance, variants: { ...variants } };
  tourRunning = true;
  const bounds = launcher.getBoundingClientRect();
  const x = bounds.left + bounds.width / 2;
  const y = bounds.top + bounds.height / 2;
  tourLooks ??= captureLooks();

  root.dataset.tour = tourTier === 'lite' ? 'lite' : '';
  const helix = buildHelix(x, y);
  tourShow = helix.show;
  tourVeil = launcher.animate([{ opacity: 1, transform: 'none' }, { opacity: 0, transform: 'scale(.9)' }], { duration: 220, easing: 'ease-in', fill: 'forwards' });

  const status = $('#tour-status');
  let shown = -1;
  let start;
  function frame(now) {
    start ??= now;
    const t = now - start;
    if (t >= tourSpin + tourCollapse - 260) {
      stopTour(true, launcher);
      celebrate(x, y);
      status.textContent = `${combinations.length} combinaisons · à toi de choisir`;
      return;
    }
    const progress = Math.min(1, t / tourSpin);
    const position = (combinations.length - 1) * easeInOut(progress);
    // Les cartes jaillissent du lanceur, tournent, puis s’y replient.
    const spread = t < 480 ? easeOutBack(t / 480) : Math.max(0, 1 - clamp01((t - tourSpin + 260) / tourCollapse) ** 2);
    helix.place(position, spread, progress, clamp01(t / 140));

    const step = Math.round(position);
    if (step !== shown) {
      const [name, look, index] = tourLooks[step].combination;
      theme = name;
      variants[name] = index;
      if (look) appearance = look;
      commitTheme();
      helix.number.textContent = String(step + 1).padStart(2, '0');
      status.textContent = `${String(step + 1).padStart(2, '0')} / ${combinations.length} · ${themes[name].name}`;
      shown = step;
    }
    tourFrame = requestAnimationFrame(frame);
  }
  tourFrame = requestAnimationFrame(frame);
}
document.addEventListener('pointerdown', () => stopTour(true), { capture: true });
document.addEventListener('keydown', () => stopTour(true), { capture: true });
addEventListener('wheel', () => stopTour(true), { passive: true });
function savePreferences() {
  try { localStorage.setItem('hello-site', JSON.stringify({ theme, appearance, motion: motionOn, variants })); } catch { /* Navigation privée. */ }
}
function motionEnabled() { return motionOn && !reduceMotion.matches; }

function springAt(t, z, k) {
  const w = Math.sqrt(k);
  const wd = w * Math.sqrt(1 - z * z);
  return 1 - Math.exp(-z * w * t) * (Math.cos(wd * t) + z * w / wd * Math.sin(wd * t));
}
const settle = (z, k) => Math.min(1.4, -Math.log(.003) / (z * Math.sqrt(k)));
// Même ressort par défaut que la charte fournie : amortissement .78, raideur 380.
function springCurve(z = .78, k = 380) {
  const duration = settle(z, k);
  const values = Array.from({ length: 45 }, (_, i) => i === 44 ? 1 : +springAt(i / 44 * duration, z, k).toFixed(4));
  return { easing: `linear(${values.join(',')})`, duration: duration * 1000 };
}
const spring = springCurve();
if (CSS.supports('transition-timing-function', spring.easing)) {
  root.style.setProperty('--spring', spring.easing);
  root.style.setProperty('--duration', `${spring.duration}ms`);
}
function applyTheme(replay = false, origin) {
  const revision = ++transitionRevision;
  themeTransition?.skipTransition();
  if (!replay || !motionEnabled() || !document.startViewTransition) {
    commitTheme();
    if (replay) Launcher.open();
    return;
  }
  // Le point de départ suit le bouton choisi, ou le lanceur à la fin du défilé ; le nouveau thème traverse la page.
  const bounds = (origin || document.querySelector(`[data-theme="${theme}"]`)).getBoundingClientRect();
  root.style.setProperty('--reveal-x', `${bounds.left + bounds.width / 2}px`);
  root.style.setProperty('--reveal-y', `${bounds.top + bounds.height / 2}px`);
  root.style.setProperty('--reveal-radius', `${Math.hypot(innerWidth, innerHeight)}px`);
  // Le lanceur joue son ouverture dans le nouveau thème, à l'intérieur de la révélation.
  themeTransition = document.startViewTransition(() => {
    if (revision === transitionRevision) { commitTheme(); Launcher.open(); }
  });
  // Un changement rapide ou un onglet masqué peut annuler la capture.
  themeTransition.ready.catch(() => {});
  themeTransition.finished.catch(() => {});
}
function commitTheme() {
  const config = themes[theme];
  root.dataset.style = theme;
  const validAppearances = config.appearances || [];
  const activeAppearance = validAppearances.includes(appearance) ? appearance : validAppearances[0] || 'dark';
  root.dataset.appearance = activeAppearance;
  let index = Number(variants[theme]);
  if (!Number.isInteger(index) || index < 0 || index >= config.variants.length) index = 0;
  variants[theme] = index;
  variantSelect.replaceChildren(...config.variants.map((variant, i) => new Option(variant[0], String(i))));
  variantSelect.value = String(index);
  $('#variant-label').textContent = config.label;
  $('#style-name').textContent = config.name;
  $('#style-detail').textContent = config.detail;
  $('.appearance-control').hidden = !validAppearances.length;
  appearanceSelect.replaceChildren(...validAppearances.map(value => new Option({ dark: 'Sombre', light: 'Clair', night: 'Nuit' }[value], value)));
  appearanceSelect.value = activeAppearance;
  variantSelect.disabled = theme === 'glyph' && activeAppearance === 'night';
  for (const variable of ['--accent', '--on-accent', '--secondary', '--bg', '--surface', '--well', '--ink', '--soft', '--muted', '--line', '--selection', '--on-selection']) root.style.removeProperty(variable);
  const [, first, second] = config.variants[index];
  const set = (name, value) => root.style.setProperty(name, value);
  if (theme === 'glyph' && activeAppearance !== 'night') {
    set('--accent', first || (activeAppearance === 'light' ? '#111' : '#f1f1f1'));
    set('--on-accent', second || (activeAppearance === 'light' ? '#fff' : '#111'));
  } else if (theme === 'atelier') {
    set('--accent', first); set('--secondary', second);

  } else if (theme === 'phosphor') {
    for (const name of ['--ink', '--soft', '--accent', '--selection']) set(name, first);
    set('--muted', `color-mix(in srgb, ${first} 78%, ${second})`);
    for (const name of ['--bg', '--surface', '--on-selection', '--on-accent']) set(name, second);
    set('--line', `${first}60`);
  } else if (theme === 'paper') {
    root.dataset.appearance = index === 2 ? 'night' : 'light';
    set('--bg', first); set('--surface', first); set('--well', second); set('--selection', second);
  } else if (theme === 'brutal') {
    set('--accent', first); set('--selection', first);
  }
  Launcher.setStyle(theme, root.dataset.appearance, config.variants[index]);
  document.querySelectorAll('[data-theme]').forEach(button => button.setAttribute('aria-pressed', String(button.dataset.theme === theme)));
  $('meta[name="theme-color"]').content = getComputedStyle(root).getPropertyValue('--frame').trim();
  if (!tourRunning) savePreferences();
}

function el(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
}

function notify(message) {
  clearTimeout(notificationTimer);
  const notification = $('#notification');
  notification.textContent = message; notification.hidden = false;
  notificationTimer = setTimeout(() => { notification.hidden = true; }, 3200);
}

document.querySelectorAll('[data-theme]').forEach(button => button.addEventListener('click', () => { theme = button.dataset.theme; applyTheme(true); }));
variantSelect.addEventListener('change', () => { variants[theme] = Number(variantSelect.value); applyTheme(true); });
appearanceSelect.addEventListener('change', () => { appearance = appearanceSelect.value; applyTheme(true); });
$('#replay').addEventListener('click', startTour);
function applyMotion() {
  root.dataset.motion = motionEnabled() ? 'on' : 'off';
  $('#motion').setAttribute('aria-pressed', String(motionEnabled()));
  $('#motion').title = motionEnabled() ? 'Couper les animations' : 'Activer les animations';
  if (!motionEnabled()) {
    stopTour(true);
    themeTransition?.skipTransition();
    Launcher.settle();
  }
}
$('#motion').addEventListener('click', () => {
  if (reduceMotion.matches) { notify('Les animations sont désactivées par les réglages d’accessibilité du système.'); return; }
  motionOn = !motionOn; applyMotion(); savePreferences();
});
reduceMotion.addEventListener('change', applyMotion);
document.querySelectorAll('[data-query]').forEach(button => button.addEventListener('click', () => Launcher.run(button.dataset.query)));
// Mini banc d’essai : la comète tourne pendant qu’on mesure la cadence d’affichage avec la vraie hélice
// en charge sous l’écran de démarrage. Le résultat choisit la version du défilé.
const boot = $('#boot');
let bootRunning = false;
function closeBoot(fast = false) {
  if (boot.hidden) return;
  bootRunning = false;
  boot.style.pointerEvents = 'none';
  const easing = 'cubic-bezier(.75,0,.15,1)';
  boot.animate([{ transform: 'none', borderRadius: '0' }, { transform: 'translateY(-104%)', borderRadius: '0 0 32px 32px' }], { duration: fast ? 380 : 760, easing, fill: 'forwards' }).onfinish = () => { boot.hidden = true; };
  $('.boot-in').animate([{ transform: 'none', opacity: 1 }, { transform: 'translateY(40px) scale(.9)', opacity: 0 }], { duration: fast ? 260 : 500, easing, fill: 'forwards' });
}
function verdict(gaps) {
  const sorted = gaps.slice(4).sort((a, b) => a - b);
  const median = sorted[sorted.length >> 1] || 1000 / 60;
  const hz = Math.round(1000 / median);
  const onTime = sorted.filter(gap => gap < median * 1.5).length / Math.max(1, sorted.length);
  const tier = onTime >= .9 && hz >= 45 ? 'full' : onTime >= .7 ? 'lite' : 'simple';
  return { hz, onTime, tier };
}
function runBoot() {
  boot.classList.remove('fallback');
  if (!motionEnabled()) { boot.hidden = true; return Promise.resolve(null); }
  bootRunning = true;
  const tick = comet($('#boot-loader'));
  const number = $('#boot-n');
  const bar = $('#boot-bar');
  const start = performance.now();
  tourLooks ??= captureLooks();
  const helix = buildHelix(innerWidth / 2, innerHeight / 2);
  const gaps = [];
  let last;
  let result;
  return new Promise(resolve => {
    function frame(now) {
      if (!bootRunning) { helix.show.remove(); resolve(null); return; }
      tick(now);
      if (!result) {
        if (last) gaps.push(now - last);
        last = now;
        const p = clamp01((now - start) / 1100);
        const eased = 1 - (1 - p) ** 2.4;
        number.textContent = String(Math.round(eased * 100)).padStart(3, '0');
        bar.style.width = `${eased * 100}%`;
        helix.place(p * (combinations.length - 1), 1, p, 1);
        if (p === 1) {
          helix.show.remove();
          result = verdict(gaps);
          result.end = now;
          $('#boot-label').innerHTML = `${result.hz} Hz · ${Math.round(result.onTime * 100)} % fluide<br>${{ full: 'Spectacle complet', lite: 'Version allégée', simple: 'Version simple' }[result.tier]}`;
        }
      } else if (now - result.end > 420) { resolve(result); return; }
      requestAnimationFrame(frame);
    }
    requestAnimationFrame(frame);
  });
}
function skipBoot() { if (bootRunning) closeBoot(true); }
document.addEventListener('pointerdown', skipBoot, { capture: true });
document.addEventListener('keydown', skipBoot, { capture: true });

applyTheme(); applyMotion();
runBoot().then(result => {
  if (!result) return;
  tourTier = result.tier;
  closeBoot();
  if (result.tier === 'simple') $('#tour-status').textContent = `${combinations.length} combinaisons · Revoir les thèmes`;
  else startTour();
});
