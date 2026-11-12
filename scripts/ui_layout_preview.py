#!/usr/bin/env python3
"""Макет-рендер лобби без Roblox: раскладка UI + 3D-лобби камерой спавна → PNG и проверки.

Читает константы прямо из кода:
  • src/shared/UILayout.luau — места и размеры элементов лобби-UI (HUD, LobbyMenus, Tutorial);
  • src/shared/Lobby.luau → Lobby.PLAN — чертёж лобби (дорожка, ворота, мостик, подиумы, табло…);
  • src/shared/Config.luau → LOBBY_CAM_PITCH — наклон камеры спавна.
Для каждого экрана считает область под топбаром Roblox (58 px) и вырезом телефона, масштаб корня
(как UI.fitScale), переводит логические пиксели в экранные, проецирует 3D-лобби камерой Roblox по
умолчанию (сзади-сверху, FOV 70, наклон LOBBY_CAM_PITCH и зум LOBBY_CAM_ZOOM — их ставит
client/LobbyScene на спавне) и рисует всё на одной схеме.

Проверки (печатаются и пишутся на PNG, код выхода 1 при ошибках):
  1. пересечения постоянных элементов UI (кроме «своих» пар: плитка и её подпись/бейдж и т. п.);
     временные слои (сообщение, подсказка обучения) не должны задевать сундук/валюты/заголовок/
     карточки/плитки;
  2. размеры под палец: кнопки ≥ 44 px, текст ≥ 14 px (кегль оценивается по длине типичного текста);
  3. путь к старту (мостик, кольцо посадки, маяк старта) закрыт плашками UI и самим игроком
     (камера сзади!) не больше чем на 50%; витрины и табло — плашками UI не больше 35% (текст без подложки
     не считается); вывеска мира — только для сведения.

Запуск: python3 scripts/ui_layout_preview.py [out.png]   (по умолчанию assets/store/lobby_layout.png)
Нужен Pillow.
"""
import json
import math
import os
import pathlib
import re
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "assets" / "store" / "lobby_layout.png"
TOPBAR = 58  # GuiService:GetGuiInset() с топбаром Roblox 2024+
CHAR_W = 0.64  # ширина заглавной кириллицы в долях кегля (Roblox подменяет FredokaOne для кириллицы)
MIN_PX_TOUCH, MIN_PX_TEXT = 44, 14
COVER_MAX = 0.35

# ------------------------------------------------------------------ чтение констант из кода
NUM = r"-?\d+(?:\.\d+)?"


def read_layout():
    src = (ROOT / "src/shared/UILayout.luau").read_text(encoding="utf-8")
    lay = {}
    for m in re.finditer(r"^L\.(\w+)\s*=\s*\{([^}]*)\}", src, re.M):
        lay[m.group(1)] = [float(x) for x in re.findall(NUM, m.group(2))]
    for m in re.finditer(r"^L\.([A-Z_]+)\s*=\s*(" + NUM + ")", src, re.M):
        lay[m.group(1)] = float(m.group(2))
    return lay


def read_plan():
    src = (ROOT / "src/shared/Lobby.luau").read_text(encoding="utf-8")
    block = re.search(r"Lobby\.PLAN = \{(.*?)\n\}", src, re.S).group(1)
    plan = {}
    for m in re.finditer(r"^\s*(\w+)\s*=\s*\{([^}]*)\}", block, re.M):
        plan[m.group(1)] = [float(x) for x in re.findall(NUM, m.group(2))]
    return plan


def read_cfg(name):
    src = (ROOT / "src/shared/Config.luau").read_text(encoding="utf-8")
    return float(re.search(r"Config\." + name + r"\s*=\s*(" + NUM + ")", src).group(1))


def read_pitch():
    return read_cfg("LOBBY_CAM_PITCH")


L = read_layout()
PLAN = read_plan()
PITCH = read_pitch()
# подбор без правки кода: PLAN_JSON='{"boardR": [27, -38]}' PITCH=-8 python3 scripts/ui_layout_preview.py
if os.environ.get("PLAN_JSON"):
    PLAN.update(json.loads(os.environ["PLAN_JSON"]))
if os.environ.get("PITCH"):
    PITCH = float(os.environ["PITCH"])
ZOOM = float(os.environ.get("ZOOM") or read_cfg("LOBBY_CAM_ZOOM"))

# ------------------------------------------------------------------ экраны
# имя, viewport W×H, safe-insets (верх с топбаром, лево, право, низ)
SCREENS = [
    ("ПК 1000×660", 1000, 660, (TOPBAR, 0, 0, 0)),
    ("Android 844×390", 844, 390, (TOPBAR, 0, 0, 0)),
    ("iPhone 14 844×390 (вырез)", 844, 390, (TOPBAR, 47, 47, 21)),
    ("iPhone SE 667×375", 667, 375, (TOPBAR, 0, 0, 0)),
    ("iPad 1024×768 (4:3)", 1024, 768, (TOPBAR, 0, 0, 0)),
    ("Full HD 1920×1080", 1920, 1080, (TOPBAR, 0, 0, 0)),
]


def fit_scale(aw, ah):
    return max(L["SCALE_MIN"], min(1.0, min(ah / L["DESIGN_H"], aw / L["DESIGN_W"])))


# ------------------------------------------------------------------ элементы UI (логические)
def rect(spec, pw, ph):
    ax, ay, sx, ox, sy, oy, w, h = spec
    x = sx * pw + ox - ax * w
    y = sy * ph + oy - ay * h
    return [x, y, x + w, y + h]


def child(parent, spec):
    """Прямоугольник внутри родителя (spec в координатах родителя)."""
    pw, ph = parent[2] - parent[0], parent[3] - parent[1]
    r = rect(spec, pw, ph)
    return [r[0] + parent[0], r[1] + parent[1], r[2] + parent[0], r[3] + parent[1]]


def elements(pw, ph):
    """Список: (ключ, rect, вид, подпись, текст для оценки кегля, высота текста)
    вид: panel — плашка (закрывает 3D), btn — кнопка-плашка, hit — зона нажатия без подложки (текст),
    text — текст без подложки, transient — временный слой (сообщение, подсказка)."""
    E = []

    def add(key, r, kind, label, sample=None, text_h=None, text_w=None):
        E.append(dict(key=key, r=r, kind=kind, label=label, sample=sample, text_h=text_h, text_w=text_w))

    cur = rect(L["currencies"], pw, ph)
    cw_ = L["CURRENCY_W"]  # одна строка: монеты слева, «УРОВЕНЬ N» в центре, гемы справа (#46)
    add("coins", [cur[0], cur[1], cur[0] + cw_, cur[3]], "panel", "монеты", "12.5K", 28, cw_ - 45)
    add("gems", [cur[2] - cw_, cur[1], cur[2], cur[3]], "panel", "гемы", "1.2K", 28, cw_ - 45)
    add("title", rect(L["levelTitle"], pw, ph), "text", "УРОВЕНЬ N", "УРОВЕНЬ 35", 38)
    wl = rect(L["worldLine"], pw, ph)
    add("world", wl, "text", "строка мира", "Северное сияние · 3/5 · ★ 64%", 26)
    ch = rect(L["chest"], pw, ph)
    add("chest", ch, "btn", "сундук", "ОТКРЫТЬ!", ch[3] - ch[1] - 24, ch[2] - ch[0] - 116)
    add("chestArt", [ch[0] - 16, ch[1] + 1, ch[0] + 48, ch[3] - 1], "deco", "")
    se = rect(L["session"], pw, ph)
    add("session", se, "btn", "подарок сессии", "ПОДАРОК 12:59", se[3] - se[1] - 20, se[2] - se[0] - 28)
    add("toast", rect(L["toastLobby"], pw, ph), "transient", "сообщение (Toasts)", "Не хватает монет: 1.2K", 27, 432)
    tut = rect(L["tutorialLobby"], pw, ph)
    sk = L["TUTORIAL_SKIP_W"]
    add("tutorial", [tut[0], tut[1], tut[2] - sk - 10, tut[3]], "transient", "подсказка обучения", "Улучши — полетишь дальше!", 36, tut[2] - tut[0] - sk - 94)
    add("tutorialSkip", [tut[2] - sk, tut[1], tut[2], tut[3]], "transient", "Пропустить", "ПРОПУСТИТЬ", tut[3] - tut[1] - 8, sk - 16)
    pl = rect(L["play"], pw, ph)
    add("play", pl, "hit", "НАЖМИ, ЧТОБЫ ИГРАТЬ", "НАЖМИ, ЧТОБЫ ИГРАТЬ  ▶", pl[3] - pl[1] - 16)
    cr = rect(L["cards"], pw, ph)
    cw = L["card"][6]
    bh = L["CARD_BTN_H"]
    for i, name in enumerate(["РОГАТКА", "САНИ", "ДОХОД"]):
        x = cr[0] + i * (cw + 14)
        add(f"card{i}", [x, cr[1], x + cw, cr[3]], "btn", name, "РОГАТКА", L["CARD_TITLE_H"], cw - 50)
        # иконка 42 слева, цифра эффекта справа в одну строку («+45%», «x2.25», «348»)
        ay = cr[1] + L["CARD_ART_Y"]
        add(f"cardFx{i}", [x + 56, ay, x + cw - 8, ay + L["CARD_ART_H"]], "sub", "", "+45%", 26, cw - 72)
        add(f"cardBtn{i}", [x + 8, cr[3] - bh - 6, x + cw - 8, cr[3] - 6], "sub", "", "12.5K", bh - 4, cw - 70)
    rk = rect(L["rocket"], pw, ph)
    add("rocket", rk, "btn", "РАКЕТА", "РАКЕТА", L["CARD_TITLE_H"], rk[2] - rk[0] - 50)
    add("rocketFx", [rk[0] + 8, rk[1] + 62, rk[2] - 8, rk[1] + 88], "sub", "", "2.1→3.6с", 26, rk[2] - rk[0] - 16)
    add("rocketBtn", [rk[0] + 8, rk[3] - bh - 6, rk[2] - 8, rk[3] - 6], "sub", "", "48", bh - 4, rk[2] - rk[0] - 70)
    tx, ty, ts = L["tiles"][3], L["tiles"][5], L["tiles"][6]
    for i, name in enumerate(["МИРЫ", "ЗАДАНИЯ", "САНИ", "СЛЕДЫ", "ПОДАРКИ"]):
        t = [tx, ty + i * L["TILE_STEP"], tx + ts, ty + i * L["TILE_STEP"] + ts]
        add(f"tile{i}", t, "btn", "", None)
        cap = child(t, L["tileLabel"])
        add(f"cap{i}", cap, "sub", name, name, cap[3] - cap[1] - 4, cap[2] - cap[0] - 12)
        if name in ("ЗАДАНИЯ", "СЛЕДЫ", "ПОДАРКИ"):
            txt = {"ЗАДАНИЯ": "!", "СЛЕДЫ": "NEW", "ПОДАРКИ": "2:31"}[name]
            bw = max(34, 18 + len(txt) * 16)
            b = L["tileBadge"]
            cx, cy = t[0] + b[2] * ts + b[3], t[1] + b[4] * ts + b[5]
            add(f"badge{i}", [cx - bw / 2, cy - 17, cx + bw / 2, cy + 17], "sub", "", txt, 26, bw - 16)
    add("gear", rect(L["gear"], pw, ph), "btn", "⚙", None)
    # язычок сворачивания апгрейдов (#11); в свёрнутом виде «ИГРАТЬ» — на playCollapsed (ниже карточек нет)
    add("upgradesTab", rect(L["upgradesTab"], pw, ph), "btn", "▼", None)
    return E


# ------------------------------------------------------------------ 3D: проекция камерой спавна
def cam_basis():
    p = math.radians(PITCH)
    fwd = (0.0, math.sin(p), -math.cos(p))
    up = (0.0, math.cos(p), math.sin(p))
    right = (1.0, 0.0, 0.0)
    focus = (0.0, 4.5, 0.0)  # корень персонажа (y 3) + 1.5
    pos = tuple(focus[i] - fwd[i] * ZOOM for i in range(3))
    return pos, fwd, up, right


CAM = cam_basis()


def project(pt, vw, vh):
    pos, fwd, up, right = CAM
    d = [pt[i] - pos[i] for i in range(3)]
    z = sum(d[i] * fwd[i] for i in range(3))
    if z <= 0.5:
        return None
    x = sum(d[i] * right[i] for i in range(3))
    y = sum(d[i] * up[i] for i in range(3))
    t = math.tan(math.radians(35))
    return (vw / 2 + x / z / t * vh / 2, vh / 2 - y / z / t * vh / 2)


def box_pts(cx, cz, hx, hz, y0, y1, yaw=0.0):
    c, s = math.cos(yaw), math.sin(yaw)
    out = []
    for dx in (-hx, hx):
        for dz in (-hz, hz):
            for y in (y0, y1):
                out.append((cx + dx * c + dz * s, y, cz - dx * s + dz * c))
    return out


def cyl_pts(cx, cz, r, y0, y1, n=16):
    return [(cx + r * math.cos(a), y, cz + r * math.sin(a)) for a in [2 * math.pi * k / n for k in range(n)] for y in (y0, y1)]


def hull(pts):
    pts = sorted(set(pts))
    if len(pts) < 3:
        return pts

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    lo, hi = [], []
    for p in pts:
        while len(lo) >= 2 and cross(lo[-2], lo[-1], p) <= 0:
            lo.pop()
        lo.append(p)
    for p in reversed(pts):
        while len(hi) >= 2 and cross(hi[-2], hi[-1], p) <= 0:
            hi.pop()
        hi.append(p)
    return lo[:-1] + hi[:-1]


def facing_yaw(x, z):
    """Поворот табло лицом к спавну (0, 0)."""
    return math.atan2(-x, -z)


def scene_objects():
    P = PLAN
    objs = []  # (ключ, подпись, 3D-точки, цвет, проверять)
    px, z0, z1, hw = P["path"]
    objs.append(("path", "дорожка", box_pts(px, (z0 + z1) / 2, hw, (z0 - z1) / 2, 0.45, 0.5), (150, 160, 185), "info"))
    qx, q0, q1, qw = P["pier"]
    objs.append(("pier", "мостик", box_pts(qx, (q0 + q1) / 2, qw, (q0 - q1) / 2, 0.3, 1.7), (175, 125, 75), "path"))
    rx, rz, rr = P["ring"]
    objs.append(("ring", "кольцо посадки", cyl_pts(rx, rz, rr, 0.6, 0.7), (90, 220, 255), "path"))
    bx, bz, bh = P["beacon"]
    objs.append(("beacon", "маяк старта", cyl_pts(bx, bz, 1.4, 0.6, bh, 8), (120, 235, 255), "path"))
    gx, gz, sy = P["gate"]
    for sx in (-1, 1):
        objs.append((f"gatePost{sx}", "", box_pts(gx + sx * 9.5, gz, 1.3, 1.3, 0, 12.3), (130, 88, 50), False))
    objs.append(("gateBeam", "", box_pts(gx, gz, 10.6, 0.8, 9.6, 13.4), (130, 88, 50), False))
    objs.append(("sign", "вывеска мира", box_pts(gx, gz + 0.3, 6.5, 0.25, sy - 1.2, sy + 1.2), (255, 220, 90), "info"))
    for key in ("podiumL", "podiumR"):
        x, z, r = P[key]
        objs.append((key, "подиум", cyl_pts(x, z, r, 0, 2.2), (225, 230, 245), False))
        objs.append((key + "Sled", "витрина саней", box_pts(x, z, 3.5, 4.5, 2.2, 7.0), (170, 110, 255) if x > 0 else (255, 200, 60), True))
    for key, name in (("boardL", "табло: обновление"), ("boardR", "табло: лидеры")):
        x, z = P[key]
        objs.append((key, name, box_pts(x, z, 10.8, 0.6, 0, 18.6, facing_yaw(x, z)), (120, 80, 45), True))
    if "top3" in P:  # пьедестал топ-3 недели (#48): ступени 2-1-3 и аватары на них, лицом к спавну
        tx, tz, tw, ts = P["top3"][0], P["top3"][1], P["top3"][2], P["top3"][3]
        yaw = facing_yaw(tx, tz)
        c, s_ = math.cos(yaw), math.sin(yaw)
        pts = []
        for lx, sh in ((-tw, P["top3H"][1]), (0, P["top3H"][0]), (tw, P["top3H"][2])):
            sx_, sz_ = tx + lx * c, tz - lx * s_
            pts += box_pts(sx_, sz_, tw / 2, 2.0, 0, sh, yaw)
            pts += box_pts(sx_, sz_, 1.1 * ts, 0.6 * ts, sh, sh + (5.5 + 1.5) * ts, yaw)  # аватар R15 + табличка
        # корона над 1-м местом — как в Lobby.top3Podium
        cy = 0.5 + P["top3H"][0] + 8.4 * ts
        pts += box_pts(tx, tz, 0.9, 0.9, cy - 0.3, cy + 1.2, yaw)
        objs.append(("top3", "пьедестал топ-3", pts, (255, 215, 80), True))
    f = P["flags"]
    for i in range(0, len(f), 2):
        objs.append((f"flag{i}", "", box_pts(f[i], f[i + 1], 0.3, 0.3, 0, 15 if f[i + 1] < 0 else 18), (230, 230, 240), False))
    lm = P["lamps"]
    for i in range(0, len(lm), 2):
        objs.append((f"lamp{i}", "", box_pts(lm[i], lm[i + 1], 0.4, 0.4, 0, 10), (60, 64, 80), False))
    objs.append(("avatar", "игрок", AVATAR, (240, 120, 120), False))
    return objs


# Аватар на точке появления (R15 ~5.5 studs на плите 0.45): камера сзади — он закрывает центр кадра,
# путь должен читаться НАД его головой (поэтому камера спавна смотрит под углом вниз)
AVATAR = box_pts(0, 0, 1.1, 0.6, 0.45, 6.0)
COVER_PATH = 0.5  # путь: дорожка у ног всегда за игроком и карточками — смотрим мостик, кольцо, маяк


# ------------------------------------------------------------------ рендер одного экрана
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FONT_B = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def font(size, bold=False):
    try:
        return ImageFont.truetype(FONT_B if bold else FONT, size)
    except OSError:
        return ImageFont.load_default()


COLORS = {
    "panel": ((28, 40, 72, 215), (255, 255, 255)),
    "btn": ((70, 140, 230, 200), (255, 255, 255)),
    "sub": ((22, 34, 64, 230), (255, 255, 255)),
    "hit": ((255, 255, 255, 30), (255, 230, 120)),
    "text": ((255, 255, 255, 25), (255, 255, 255)),
    "transient": ((255, 170, 40, 110), (255, 200, 80)),
    "deco": ((205, 130, 60, 160), (120, 70, 30)),
}
OPAQUE = {"panel", "btn", "sub", "deco"}
OWN = [("chest", "chestArt"), ("rocket", "rocketFx"), ("rocket", "rocketBtn")] + [(f"tile{i}", f"cap{i}") for i in range(5)] + [(f"tile{i}", f"badge{i}") for i in range(5)] + [(f"card{i}", f"cardBtn{i}") for i in range(3)] + [(f"card{i}", f"cardFx{i}") for i in range(3)]
TRANSIENT_MUST_AVOID = {"chest", "chestArt", "coins", "gems", "title", "world", "card0", "card1", "card2", "rocket", "play", "gear"} | {f"tile{i}" for i in range(5)} | {f"cap{i}" for i in range(5)}


def inter(a, b):
    return max(0, min(a[2], b[2]) - max(a[0], b[0])) * max(0, min(a[3], b[3]) - max(a[1], b[1]))


def render_screen(name, vw, vh, ins):
    top, left, right, bottom = ins
    aw, ah = vw - left - right, vh - top - bottom
    s = fit_scale(aw, ah)
    pw, ph = aw / s, ah / s
    E = elements(pw, ph)
    issues, notes = [], []

    def phys(r):
        return [left + r[0] * s, top + r[1] * s, left + r[2] * s, top + r[3] * s]

    # 1. пересечения
    byk = {e["key"]: e for e in E}
    keys = list(byk)
    for i, a in enumerate(keys):
        for b in keys[i + 1:]:
            ea, eb = byk[a], byk[b]
            if (a, b) in OWN or (b, a) in OWN:
                continue
            if a.startswith("cardBtn") or b.startswith("cardBtn") or a.startswith("cardFx") or b.startswith("cardFx"):
                continue
            if inter(ea["r"], eb["r"]) <= 1:
                continue
            ta, tb = ea["kind"] == "transient", eb["kind"] == "transient"
            if ta and tb:
                continue
            if ta or tb:
                other = b if ta else a
                if other in TRANSIENT_MUST_AVOID:
                    issues.append(f"{byk[a]['label'] or a} × {byk[b]['label'] or b}: перекрытие")
                continue
            if {a, b} == {"title", "world"}:
                continue
            issues.append(f"{ea['label'] or a} × {eb['label'] or b}: перекрытие")
        # за рамками экрана
        r = phys(byk[a]["r"])
        if r[0] < 0 or r[1] < top - 1 or r[2] > vw or r[3] > vh - bottom + 1:
            if byk[a]["kind"] != "deco":
                issues.append(f"{byk[a]['label'] or a}: за рамкой безопасной зоны")
    # 2. размеры
    for e in E:
        r = phys(e["r"])
        if e["kind"] in ("btn", "hit") or e["key"] == "tutorialSkip":
            w_, h_ = r[2] - r[0], r[3] - r[1]
            pill = w_ >= 2.5 * h_
            need = (L["MIN_PILL"] if pill else L["MIN_TOUCH"]) * s
            need = min(need, MIN_PX_TOUCH) if not pill else need
            if min(w_, h_) < need - 0.5:
                issues.append(f"{e['label'] or e['key']}: {'пилюля' if pill else 'кнопка'} {min(w_, h_):.0f} px < {need:.0f}")
        if e["sample"]:
            wlog = e["text_w"] or (e["r"][2] - e["r"][0])
            size = min(e["text_h"] or (e["r"][3] - e["r"][1]), wlog / (len(e["sample"]) * CHAR_W))
            px = size * s
            if px < MIN_PX_TEXT - 0.3:
                issues.append(f"«{e['sample']}»: текст {px:.1f} px < {MIN_PX_TEXT}")
    # 3. 3D
    W, H = vw, vh
    img = Image.new("RGBA", (W, H), (150, 200, 240, 255))
    d = ImageDraw.Draw(img, "RGBA")
    # небо/земля по горизонту
    hz = project((0, 4.5 + 1000 * math.tan(0), -100000), W, H)
    hy = hz[1] if hz else H * 0.4
    d.rectangle([0, hy, W, H], fill=(236, 242, 250, 255))
    d.line([0, hy, W, hy], fill=(160, 175, 200, 255), width=1)
    ui_mask = Image.new("L", (W, H), 0)
    md = ImageDraw.Draw(ui_mask)
    for e in E:
        if e["kind"] in OPAQUE:
            md.rectangle(phys(e["r"]), fill=255)
    cover = {}
    objs = scene_objects()
    av = hull([q for q in (project(pt, W, H) for pt in AVATAR) if q])
    path_mask = ui_mask.copy()
    ImageDraw.Draw(path_mask).polygon(av, fill=255)
    # дальние сначала
    objs.sort(key=lambda o: -sum(-p[2] for p in o[2]) / len(o[2]))
    for key, label, pts, col, check in objs:
        pp = [project(p, W, H) for p in pts]
        pp = [p for p in pp if p]
        if len(pp) < 3:
            continue
        h = hull(pp)
        d.polygon(h, fill=col + (235,), outline=(60, 60, 70, 255))
        if check:
            m = Image.new("L", (W, H), 0)
            ImageDraw.Draw(m).polygon(h, fill=255)
            area = sum(1 for v in m.get_flattened_data() if v)
            if area == 0:
                continue
            occ = path_mask if check == "path" else ui_mask
            both = sum(1 for a, b in zip(m.get_flattened_data(), occ.get_flattened_data()) if a and b)
            onscreen = sum(1 for x, y in h if 0 <= x <= W and 0 <= y <= H)
            frac = both / area
            prev = cover.get(label)
            cover[label] = max(prev or 0, frac)
            if frac > (COVER_PATH if check == "path" else COVER_MAX) and check != "info":
                issues.append(f"3D «{label}» закрыт {'UI и игроком' if check == 'path' else 'плашками UI'} на {frac:.0%}")
            if onscreen == 0:
                notes.append(f"3D «{label}» вне кадра")
            cx = sum(x for x, _ in h) / len(h)
            cy = sum(y for _, y in h) / len(h)
            if label and 0 < cx < W and 0 < cy < H:
                d.text((cx, cy), label, fill=(20, 20, 30, 255), font=font(max(9, int(11 * W / 1000 + 2))), anchor="mm")
    # safe area и топбар
    d.rectangle([0, 0, W, top], fill=(20, 24, 34, 190))
    d.text((8, top / 2), "топбар Roblox", fill=(200, 200, 210), font=font(12), anchor="lm")
    if left:
        d.rectangle([0, 0, left, H], fill=(20, 24, 34, 120))
        d.rectangle([W - right, 0, W, H], fill=(20, 24, 34, 120))
    if bottom:
        d.rectangle([0, H - bottom, W, H], fill=(20, 24, 34, 120))
    # UI поверх
    order = ["deco", "text", "hit", "panel", "btn", "sub", "transient"]
    for kind in order:
        for e in E:
            if e["kind"] != kind:
                continue
            r = phys(e["r"])
            fill, ink = COLORS[kind]
            if kind == "transient":
                d.rectangle(r, fill=fill, outline=(255, 140, 0, 255), width=2)
            elif kind in ("text", "hit"):
                d.rectangle(r, fill=fill, outline=ink + (200,), width=1)
            else:
                d.rounded_rectangle(r, radius=max(2, int(6 * s)), fill=fill, outline=(255, 255, 255, 230), width=1)
            lab = e["label"]
            if lab:
                fs = max(8, min(int((r[3] - r[1]) * 0.55), 15))
                d.text(((r[0] + r[2]) / 2, (r[1] + r[3]) / 2), lab, fill=ink + (255,), font=font(fs, True), anchor="mm")
    # мобильные зоны: прыжок справа снизу (на телефоне)
    if min(vw, vh) <= 500:
        j = [vw - 95 - right, vh - 90 - bottom, vw - 25 - right, vh - 20 - bottom]
        d.ellipse(j, outline=(255, 80, 80, 255), width=2)
        d.text(((j[0] + j[2]) / 2, (j[1] + j[3]) / 2), "прыжок", fill=(255, 80, 80, 255), font=font(10), anchor="mm")
    hdr = f"{name}: область {aw}×{ah}, масштаб {s:.3f}, корень {pw:.0f}×{ph:.0f} лог."
    return img, hdr, issues, notes, cover


# ------------------------------------------------------------------ окна (масштаб UI.panel)
WINDOWS = [  # имя, ширина, высота, мин. кнопка, мин. текст (логические, из LobbyMenus/UIKit)
    ("САНИ", 880, 520, 48, 24),
    ("ПОДАРКИ", 760, 620, 48, 24),
    ("ЗАДАНИЯ", 580, 688, 64, 24),  # +128 — карточка задания недели (#56); подпись следа 24
    ("МИРЫ", 720, 400, 48, 24),
    ("СЛЕДЫ", int(L["TRAIL_WIN_W"]), int(L["TRAIL_WIN_H"]), 48, 24),
    ("НАСТРОЙКИ", 470, 270, 50, 24),
]


def window_table():
    rows = []
    for nm, vw, vh, _ in [(s[0], s[1], s[2], s[3]) for s in SCREENS]:
        cells = []
        for wn, w, h, btn, txt in WINDOWS:
            k = min(1, (vw - 24) / w, (vh - 60) / (h + 30))
            ok = btn >= L["MIN_TOUCH_PANEL"] and txt >= L["MIN_TEXT_PANEL"]
            cells.append(f"{wn} ×{k:.2f}: кнопка {btn * k:.0f}px, текст {txt * k:.0f}px{'' if ok else ' (!)'}")
        rows.append((nm, cells))
    return rows


def main():
    shots, all_issues = [], []
    for name, vw, vh, ins in SCREENS:
        img, hdr, issues, notes, cover = render_screen(name, vw, vh, ins)
        shots.append((img, hdr, issues, notes, cover))
        all_issues += [f"[{name}] {i}" for i in issues]
    # лист: экраны в 2 колонки, высота экрана приводится к 360
    cellW, cellH = 760, 470
    cols = 2
    rows_n = (len(shots) + cols - 1) // cols
    tbl = window_table()
    sheetH = 90 + rows_n * cellH + 40 + 22 * (len(tbl) + 1) + 30
    sheet = Image.new("RGB", (cols * cellW + 20, sheetH), (24, 30, 44))
    d = ImageDraw.Draw(sheet)
    title = f"Лобби: раскладка UI + 3D-путь камерой спавна (наклон {PITCH:.0f}°, зум {ZOOM:.0f}) — {'OK' if not all_issues else str(len(all_issues)) + ' замечаний'}"
    d.text((14, 12), title, fill=(255, 225, 90), font=font(22, True))
    d.text((14, 44), "синие — кнопки/плашки, тёмные — подписи и бейджи, рамка — текст без подложки, оранжевые — временные слои; "
           "под UI — проекция 3D-лобби (дорожка, ворота, мостик, кольцо, подиумы, табло)", fill=(190, 205, 230), font=font(13))
    d.text((14, 64), "Источник: src/shared/UILayout.luau, Lobby.PLAN, Config.LOBBY_CAM_PITCH · scripts/ui_layout_preview.py",
           fill=(150, 165, 190), font=font(12))
    for i, (img, hdr, issues, notes, cover) in enumerate(shots):
        cx, cy = 10 + (i % cols) * cellW, 90 + (i // cols) * cellH
        k = min((cellW - 20) / img.width, 360 / img.height)
        im = img.resize((int(img.width * k), int(img.height * k)), Image.LANCZOS)
        sheet.paste(im.convert("RGB"), (cx, cy + 24))
        d.text((cx, cy + 4), hdr, fill=(235, 240, 250), font=font(14, True))
        y = cy + 24 + im.height + 4
        cv = ", ".join(f"{k2} {v:.0%}" for k2, v in cover.items() if k2)
        d.text((cx, y), ("✔ без пересечений и мелочи" if not issues else "✘ " + "; ".join(issues))[:120], fill=(140, 230, 140) if not issues else (255, 120, 110), font=font(12))
        d.text((cx, y + 18), ("закрыто UI: " + cv)[:125], fill=(190, 205, 230), font=font(11))
    y = 90 + rows_n * cellH + 10
    d.text((14, y), "Окна (UI.panel ужимается своим UIScale): мин. кнопка / текст на экране", fill=(255, 225, 90), font=font(15, True))
    for j, (nm, cells) in enumerate(tbl):
        d.text((14, y + 24 + j * 22), f"{nm}: " + " · ".join(c.split(":")[0] + c.split(":", 1)[1].replace("кнопка", "").replace("текст", "/") for c in cells)[:230],
               fill=(205, 215, 235), font=font(12))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT)
    print(f"PNG: {OUT}")
    for img, hdr, issues, notes, cover in shots:
        print(hdr)
        for c, v in cover.items():
            if c:
                print(f"   закрыто UI: {c} {v:.0%}")
        for n in notes:
            print("   заметка:", n)
    if all_issues:
        print("ЗАМЕЧАНИЯ:")
        for i in all_issues:
            print("  -", i)
        sys.exit(1)
    print("Раскладка чистая.")


if __name__ == "__main__":
    main()
