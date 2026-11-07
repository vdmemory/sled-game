// Генерация иконок опыта (A/B, #28): SVG-сцены кодом → PNG 512×512 через Playwright/Chromium.
// Запуск из корня репозитория: node assets/store/render.js
// Палитра — UIKit.C / UIKit.KIND (src/shared/UIKit.luau). Шрифт — Inter Display Black (SIL OFL).
const fs = require("fs");
const path = require("path");
const { chromium } = require("playwright");

const OUT = __dirname;
const NAME = "SLED RUSH"; // рабочее название (одинаковое в обоих вариантах — тестируем картинку)

// Палитра из UIKit
const C = {
  white: "#FFFFFF", ink: "#162240", navy: "#1C2848", panel: "#D6EAFC", edge: "#F4FAFF",
  ribbon: "#3478DC", fill: "#3CAAFF", cyan: "#46D2FF", gold: "#FFCD3C",
  goldDk: "#F5AA1E", red: "#FF6E64", redDk: "#D72D2D", purple: "#BE78FF", purpleDk: "#7D41DC",
  orange: "#FFAA46", orangeDk: "#F06923", green: "#8CE155", greenDk: "#41AA2D",
  ice: "#BEDEFA", pink: "#FF6EB4", pinkDk: "#D23C8C",
};
const S = `stroke="${C.ink}" stroke-linejoin="round" stroke-linecap="round"`;

// Толстая конечность с обводкой: сначала ink шире, потом цвет
const limb = (pts, color, w = 18) => {
  const d = "M" + pts.map((p) => p.join(",")).join(" L");
  return `<path d="${d}" fill="none" stroke="${C.ink}" stroke-width="${w + 10}" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="${d}" fill="none" stroke="${color}" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round"/>`;
};

// Персонаж-болванка (блочный, без лица известного персонажа). Локальные координаты: (0,0) — сиденье.
function dummy({ arms }) {
  const armsUp = limb([[-2, -74], [-26, -112], [-38, -150]], C.gold) + limb([[14, -74], [40, -110], [58, -146]], C.gold);
  const armsGrip = limb([[-2, -72], [36, -62], [74, -48]], C.gold) + limb([[14, -74], [52, -70], [86, -58]], C.gold);
  return `
  ${limb([[4, -8], [54, -10], [72, 18]], C.ribbon, 22)}
  ${arms === "up" ? armsUp : ""}
  <rect x="-24" y="-86" width="44" height="80" rx="8" fill="${C.orange}" ${S} stroke-width="5"/>
  <path d="M-24,-46 h44 v30 a10 10 0 0 1 -10 10 h-24 a10 10 0 0 1 -10 -10z" fill="${C.orangeDk}" opacity=".55"/>
  <rect x="-30" y="-142" width="58" height="54" rx="12" fill="${C.gold}" ${S} stroke-width="5"/>
  <rect x="-30" y="-142" width="58" height="16" rx="8" fill="#FFE68C" opacity=".8"/>
  <ellipse cx="8" cy="-117" rx="4.5" ry="7" fill="${C.ink}"/>
  <ellipse cx="22" cy="-117" rx="4.5" ry="7" fill="${C.ink}"/>
  <path d="M2,-103 Q15,-92 27,-104" fill="#fff" ${S} stroke-width="4"/>
  ${arms === "grip" ? armsGrip : ""}`;
}

const tree = (x, y, s, dark = false) => {
  const g = dark ? "#2E8A3A" : C.greenDk, l = dark ? "#41AA2D" : "#5CC23E";
  return `<g transform="translate(${x},${y}) scale(${s})">
    <rect x="-7" y="-10" width="14" height="22" fill="#8A5A2B" ${S} stroke-width="4"/>
    <polygon points="0,-120 -42,-50 42,-50" fill="${l}" ${S} stroke-width="5"/>
    <polygon points="0,-120 0,-50 42,-50" fill="${g}"/>
    <polygon points="0,-90 -54,-6 54,-6" fill="${l}" ${S} stroke-width="5"/>
    <polygon points="0,-90 0,-6 54,-6" fill="${g}"/>
    <polygon points="0,-120 -42,-50 42,-50" fill="none" ${S} stroke-width="5"/>
    <polygon points="-14,-104 0,-120 14,-104 4,-100 -6,-98" fill="#fff"/>
  </g>`;
};

const coin = (x, y, r, rot = 0) => `<g transform="translate(${x},${y}) rotate(${rot}) scale(.62,1)">
  <circle r="${r}" fill="${C.goldDk}" ${S} stroke-width="${r * 0.28}"/>
  <circle r="${r * 0.68}" fill="${C.gold}"/>
  <rect x="${-r * 0.16}" y="${-r * 0.42}" width="${r * 0.32}" height="${r * 0.84}" rx="3" fill="#FFF0A8"/></g>`;

// Название: толстая обводка ink + заливка, тень
const title = (y, fill1, fill2, size = 82) => `
  <defs><linearGradient id="tg" x1="0" y1="0" x2="0" y2="1">
    <stop offset=".1" stop-color="${fill1}"/><stop offset=".9" stop-color="${fill2}"/></linearGradient></defs>
  <g font-family="Inter Display" font-weight="900" font-size="${size}" text-anchor="middle" letter-spacing="-1">
    <text x="258" y="${y + 7}" fill="${C.ink}" stroke="${C.ink}" stroke-width="22" stroke-linejoin="round">${NAME}</text>
    <text x="256" y="${y}" fill="url(#tg)" stroke="${C.ink}" stroke-width="16" stroke-linejoin="round" paint-order="stroke">${NAME}</text>
    <text x="256" y="${y}" fill="url(#tg)">${NAME}</text>
  </g>`;

const rays = (cx, cy, n, color, op) => {
  let s = "";
  for (let i = 0; i < n; i++) {
    const a = (i / n) * Math.PI * 2, b = a + Math.PI / n;
    s += `<polygon points="${cx},${cy} ${cx + 800 * Math.cos(a)},${cy + 800 * Math.sin(a)} ${cx + 800 * Math.cos(b)},${cy + 800 * Math.sin(b)}"/>`;
  }
  return `<g fill="${color}" opacity="${op}">${s}</g>`;
};

const burst = (cx, cy, r1, r2, n, fill, sw = 6, rot = 0) => {
  const p = [];
  for (let i = 0; i < n * 2; i++) {
    const r = i % 2 ? r2 * (0.8 + 0.2 * ((i * 7) % 3) / 2) : r1, a = rot + (i / (n * 2)) * Math.PI * 2;
    p.push(`${(cx + r * Math.cos(a)).toFixed(1)},${(cy + r * Math.sin(a)).toFixed(1)}`);
  }
  return `<polygon points="${p.join(" ")}" fill="${fill}" ${S} stroke-width="${sw}"/>`;
};

// ---------- Вариант A «Полёт»: ватрушка в прыжке с трамплина ----------
function iconA() {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
  <defs>
    <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="${C.ribbon}"/><stop offset=".55" stop-color="${C.cyan}"/><stop offset="1" stop-color="${C.edge}"/></linearGradient>
    <radialGradient id="glow" cx="300" cy="190" r="200" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#fff" stop-opacity=".75"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient>
  </defs>
  <rect width="512" height="512" fill="url(#sky)"/>
  ${rays(300, 190, 14, "#fff", 0.16)}
  <circle cx="300" cy="190" r="200" fill="url(#glow)"/>
  <!-- горы -->
  <polygon points="-10,330 90,210 170,300 250,230 360,330" fill="${C.panel}" ${S} stroke-width="5"/>
  <polygon points="90,210 110,300 170,300" fill="${C.ice}"/><polygon points="250,230 270,330 360,330" fill="${C.ice}"/>
  <polygon points="300,340 420,200 530,320 530,340" fill="${C.panel}" ${S} stroke-width="5"/>
  <polygon points="420,200 440,340 530,330 530,320" fill="${C.ice}"/>
  <!-- склон -->
  <polygon points="-10,350 200,390 520,330 520,520 -10,520" fill="#fff" ${S} stroke-width="6"/>
  <polygon points="200,390 520,330 520,400 330,420" fill="${C.edge}"/>
  <polygon points="-10,430 140,470 60,520 -10,520" fill="${C.ice}" opacity=".7"/>
  <polygon points="330,420 520,400 520,470" fill="${C.ice}" opacity=".7"/>
  ${tree(470, 352, 0.95)}${tree(32, 360, 1.05)}${tree(500, 300, 0.6, true)}${tree(-6, 300, 0.7, true)}
  <!-- трамплин -->
  <g transform="translate(0,-26)">
  <polygon points="40,410 168,348 176,384 52,440" fill="${C.goldDk}" ${S} stroke-width="6"/>
  <polygon points="40,410 168,348 160,330 34,392" fill="${C.gold}" ${S} stroke-width="6"/>
  <polygon points="60,392 150,350 152,356 62,398" fill="#FFF0A8"/>
  <!-- взрыв снега у края трамплина -->
  ${burst(175, 330, 30, 66, 9, "#fff", 6, 0.3)}
  <circle cx="132" cy="296" r="11" fill="#fff" ${S} stroke-width="4"/><circle cx="214" cy="286" r="8" fill="#fff" ${S} stroke-width="4"/>
  <circle cx="108" cy="330" r="7" fill="#fff" ${S} stroke-width="4"/>
  </g>
  <!-- дуга полёта -->
  <path d="M170,290 Q178,232 214,214" fill="none" stroke="#fff" stroke-width="10" stroke-linecap="round" stroke-dasharray="2 22" opacity=".95"/>
  <!-- монеты веером -->
  ${coin(380, 120, 22, 15)}${coin(430, 178, 19, 25)}${coin(400, 246, 17, 35)}${coin(348, 66, 16, 5)}
  <!-- ватрушка + персонаж (наклон — сальто) -->
  <g transform="translate(290,212) rotate(-18) scale(1.18)">
    <ellipse cx="0" cy="22" rx="106" ry="48" fill="${C.pinkDk}" ${S} stroke-width="7"/>
    <ellipse cx="0" cy="12" rx="106" ry="44" fill="${C.pink}" ${S} stroke-width="7"/>
    <ellipse cx="0" cy="8" rx="50" ry="16" fill="${C.pinkDk}" ${S} stroke-width="5"/>
    <path d="M-80,-6 Q-30,-28 40,-26" fill="none" stroke="#FFC2E0" stroke-width="9" stroke-linecap="round"/>
    <g transform="translate(-6,10)">${dummy({ arms: "up" })}</g>
    <path d="M-106,12 Q-110,38 -60,58" fill="none" stroke="${C.ink}" stroke-width="7"/>
  </g>
  ${title(486, "#FFF6C8", C.gold)}
</svg>`;
}

// ---------- Вариант B «Рогатка»: запуск саней, диагональ снизу-слева вверх-вправо ----------
function iconB() {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
  <defs>
    <linearGradient id="skyB" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="${C.purpleDk}"/><stop offset=".5" stop-color="${C.purple}"/><stop offset=".85" stop-color="${C.orange}"/></linearGradient>
    <radialGradient id="glowB" cx="330" cy="190" r="230" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#FFE68C" stop-opacity=".9"/><stop offset="1" stop-color="#FFE68C" stop-opacity="0"/></radialGradient>
  </defs>
  <rect width="512" height="512" fill="url(#skyB)"/>
  <circle cx="330" cy="190" r="230" fill="url(#glowB)"/>
  ${rays(330, 190, 16, "#fff", 0.13)}
  <!-- склон -->
  <polygon points="-10,380 260,330 520,370 520,520 -10,520" fill="#fff" ${S} stroke-width="6"/>
  <polygon points="260,330 520,370 520,430 380,400" fill="${C.ice}" opacity=".8"/>
  ${tree(470, 384, 0.8)}${tree(420, 360, 0.55, true)}
  <!-- линии скорости вдоль диагонали -->
  <g stroke="#fff" stroke-linecap="round" opacity=".9">
    <line x1="40" y1="250" x2="150" y2="200" stroke-width="9"/>
    <line x1="70" y1="300" x2="210" y2="236" stroke-width="12"/>
    <line x1="30" y1="190" x2="110" y2="152" stroke-width="7"/>
    <line x1="150" y1="330" x2="230" y2="294" stroke-width="7"/>
    <line x1="250" y1="120" x2="330" y2="84" stroke-width="6"/>
  </g>
  <!-- снежный шлейф за санями -->
  <path d="M110,380 Q170,300 250,262 L262,300 Q190,330 150,400 Z" fill="#fff" opacity=".75"/>
  ${burst(176, 352, 22, 40, 8, "#fff", 5, 0.2)}
  <!-- рогатка: крупная развилка слева-снизу, тяжи ещё натянуты к корме саней -->
  <g transform="translate(-34,6)">
    <path d="M110,520 L110,400 L58,300 M110,400 L170,304" fill="none" stroke="${C.ink}" stroke-width="46" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M110,520 L110,400 L58,300 M110,400 L170,304" fill="none" stroke="#A8692E" stroke-width="32" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M102,500 L102,404 L62,326" fill="none" stroke="#D08A48" stroke-width="9" stroke-linecap="round"/>
    <rect x="44" y="286" width="30" height="26" rx="6" fill="${C.redDk}" ${S} stroke-width="5" transform="rotate(-28 59 299)"/>
    <rect x="156" y="290" width="30" height="26" rx="6" fill="${C.redDk}" ${S} stroke-width="5" transform="rotate(28 171 303)"/>
  </g>
  <g fill="none" stroke-linecap="round">
    <path d="M24,306 Q110,300 190,280" stroke="${C.ink}" stroke-width="18"/><path d="M24,306 Q110,300 190,280" stroke="${C.red}" stroke-width="9"/>
    <path d="M136,310 Q166,290 190,280" stroke="${C.ink}" stroke-width="18"/><path d="M136,310 Q166,290 190,280" stroke="${C.red}" stroke-width="9"/>
    <rect x="176" y="266" width="26" height="30" rx="7" fill="#8A5A2B" stroke="${C.ink}" stroke-width="5" transform="rotate(-24 189 281)"/>
  </g>
  <!-- сани + персонаж, крупный план, нос вверх-вправо -->
  <g transform="translate(316,198) rotate(-24) scale(1.15)">
    <!-- полозья с большим завитком -->
    <path d="M-120,40 L92,40 Q146,40 146,-6 Q146,-38 116,-38 Q98,-38 100,-20" fill="none" stroke="${C.ink}" stroke-width="22" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M-120,40 L92,40 Q146,40 146,-6 Q146,-38 116,-38 Q98,-38 100,-20" fill="none" stroke="${C.gold}" stroke-width="12" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M-120,40 L92,40" fill="none" stroke="#FFF0A8" stroke-width="3" transform="translate(0,-3)"/>
    <path d="M-80,40 v-26 M-10,40 v-26 M60,40 v-26" stroke="${C.ink}" stroke-width="14" stroke-linecap="round"/>
    <path d="M-80,40 v-26 M-10,40 v-26 M60,40 v-26" stroke="${C.goldDk}" stroke-width="6" stroke-linecap="round"/>
    <!-- деревянная дека из реек -->
    <polygon points="-130,16 114,16 128,-6 -122,-6" fill="${C.redDk}" ${S} stroke-width="7"/>
    <polygon points="-122,-6 128,-6 120,-18 -116,-18" fill="${C.red}" ${S} stroke-width="6"/>
    <path d="M-70,-18 l-4,34 M-10,-18 l-2,34 M50,-18 l0,34" stroke="${C.ink}" stroke-width="4" opacity=".55"/>
    <!-- верёвка к завитку -->
    <path d="M100,-22 Q70,-40 44,-54" fill="none" stroke="${C.ink}" stroke-width="9" stroke-linecap="round"/>
    <path d="M100,-22 Q70,-40 44,-54" fill="none" stroke="#fff" stroke-width="4" stroke-linecap="round"/>
    <g transform="translate(-44,-14)">${dummy({ arms: "grip" })}</g>
  </g>
  <!-- искры-звёзды -->
  ${burst(442, 96, 6, 22, 4, "#fff", 4)}${burst(470, 168, 4, 14, 4, "#FFF0A8", 3)}${burst(388, 60, 4, 12, 4, "#fff", 3)}
  ${title(486, "#FFFFFF", C.cyan)}
</svg>`;
}

(async () => {
  const icons = { icon_a: iconA(), icon_b: iconB() };
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 512, height: 512 } });
  for (const [name, svg] of Object.entries(icons)) {
    fs.writeFileSync(path.join(OUT, name + ".svg"), svg);
    await page.setContent(`<html><body style="margin:0">${svg}</body></html>`);
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: path.join(OUT, name + ".png"), clip: { x: 0, y: 0, width: 512, height: 512 } });
  }
  await browser.close();
  console.log("ok");
})();
