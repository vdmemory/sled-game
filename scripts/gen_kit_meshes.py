"""Меши обвеса тиров, золотой кромки по контуру (тир 4) и ракет — часть пайплайна мешей транспорта
(см. scripts/gen_sled_meshes.py, подключено в scripts/gen_meshes.py). all_meshes() — все меши транспорта."""
import math

import numpy as np

from gen_sled_meshes import BODIES, bob_section
from sled_geom import PI, airfoil, ball, box, join, loft, place, prism, rbox, rect, revolve, ring_path, rot, shade, solid, \
    superellipse, sweep, tube, xform


# ================================================================ обвес по тирам (Kit)
def kit_meshes():
    """Обвес «Саней» (кадр детали: начало — точка крепления, нос по −Z):
    фара (корпус с хромовым ободом и кронштейном; линза и свет — Part/SpotLight), спойлер (крыло
    с перевёрнутым профилем + «лебединые шеи» и торцевые пластины), ветровой обтекатель (гнутое
    стекло + рамка), бампер (труба с кронштейнами), флажок (волнистая ткань), боковое крыло
    (стреловидный плавник с профилем), хромированный выхлоп (гнутая труба с раструбом), корона."""
    out = {}
    # фара: корпус-«стакан» вдоль Z, открытая сторона (обод) к −Z, центр линзы — в 0
    lamp = revolve([(0, -0.34), (0.22, -0.32), (0.3, -0.2), (0.31, 0.0), (0.35, 0.1), (0.35, 0.2), (0.27, 0.2), (0.25, 0.14), (0, 0.15)], seg=20)
    lamp = xform(place(lamp, axis="z"), np.diag([1, 1, 1]), (0, 0, 0))
    lamp.vertices[:, 2] *= -1  # открытая сторона к носу (−Z)
    lamp.faces = lamp.faces[:, ::-1]
    bracket = box(0.14, 0.32, 0.18, c=(0, -0.4, 0.12))
    out["kit_headlamp"] = (shade(join([solid(lamp), bracket])), "обвес: корпус фары")
    # спойлер: крыло на высоте 0.42, хорда 0.8, перевёрнутый профиль с углом атаки
    rs = []
    a = math.radians(-10)
    for k in range(13):
        x = -1.45 + 2.9 * k / 12
        sec = airfoil(0.8, 0.12, seg=14)
        rs.append([(x, 0.42 - (v * math.cos(a) + (u - 0.2) * math.sin(a)), (u - 0.2) * math.cos(a) - v * math.sin(a) - 0.1) for u, v in sec])
    out["kit_spoiler"] = (shade(loft(rs)), "обвес: крыло спойлера")
    mount = []
    for sx in (-1, 1):
        mount.append(tube([(sx * 0.85, -0.35, 0.05), (sx * 0.85, 0.05, -0.05), (sx * 0.85, 0.3, 0.05), (sx * 0.85, 0.45, 0.2)], 0.07, seg=8))
        mount.append(prism([(-0.55, -0.12), (0.45, -0.18), (0.5, 0.42), (-0.4, 0.38)], 0.07,
                           lambda u, v, w, sx=sx: (sx * 1.47 + w, 0.42 + v, u)))
    out["kit_spoiler_mount"] = (shade(join(mount)), "обвес: стойки и пластины спойлера")
    # обтекатель: гнутое стекло (дуга в плане), завал назад 25°
    pts = []
    for k in range(13):
        t = -0.85 + 1.7 * k / 12
        pts.append((1.9 * math.sin(t), 0.0, 0.5 * (1 - math.cos(t))))
    R25 = rot(math.radians(-25), 0, 0)
    out["kit_shield"] = (shade(xform(sweep(pts, rect(0.04, 0.7), up=(0, 0, -1)), R25)), "обвес: стекло обтекателя")
    top = sweep([(x, y + 0.7, z) for x, y, z in pts], superellipse(0.08, 0.07, 0.07, n=3, seg=8), up=(0, 1, 0))
    low = sweep([(x, y - 0.72, z) for x, y, z in pts], rect(0.06, 0.06), up=(0, 1, 0))
    out["kit_shield_frame"] = (shade(xform(join([top, low]), R25)), "обвес: рамка обтекателя")
    # бампер: гнутая труба по носу + два кронштейна назад
    bp = [(-1.65, 0.0, 0.55), (-1.5, 0.0, 0.2), (-1.1, 0.0, 0.0), (0, 0.0, -0.12), (1.1, 0.0, 0.0), (1.5, 0.0, 0.2), (1.65, 0.0, 0.55)]
    bumper = [tube(bp, 0.14, seg=12, up=(0, 1, 0), scale=[(1.35, 1.0)] * len(bp))]
    for sx in (-1, 1):
        bumper.append(tube([(sx * 0.8, 0, 0.0), (sx * 0.8, 0, 0.6)], 0.07, seg=8))
        bumper.append(ball(0.17, c=(sx * 1.65, 0, 0.55), sub=1))
    out["kit_bumper"] = (shade(join(bumper)), "обвес: бампер")
    # флажок: полотнище 1.3 × 0.9 с волной, кромка у шеста в 0 (вниз по −Y, назад по +Z)
    rs = []
    for k in range(11):
        t = k / 10
        z = 1.3 * t
        x = 0.12 * math.sin(t * PI * 2.2) * t
        sag = -0.12 * t * t
        bot = sag - 0.9 + 0.15 * t
        rs.append([(x - 0.03, sag, z), (x - 0.03, bot, z), (x + 0.03, bot, z), (x + 0.03, sag, z)])
    out["kit_flag"] = (shade(loft(rs), 60), "обвес: полотнище флажка")
    # боковое крыло: стреловидный плавник в плоскости YZ, корень в 0, толщина по X
    rs = []
    for k in range(7):
        t = k / 6
        ch = 1.8 - 1.0 * t
        rs.append([(v, 0.9 * t, -0.9 + 0.9 * t + u) for u, v in airfoil(ch, 0.14, seg=12)])
    out["kit_wing"] = (shade(loft(rs)), "обвес: боковое крыло")
    # выхлоп: колено от корпуса назад-вверх, раструб на конце
    path = [(0, 0, -0.2), (0, 0.05, 0.25), (0, 0.22, 0.65), (0, 0.45, 1.0), (0, 0.62, 1.3)]
    pipe = tube(path, 0.16, seg=14, scale=[1, 1, 1, 1.12, 1.25])
    tip = place(revolve([(0, -0.02), (0.21, -0.02), (0.25, 0.12), (0.17, 0.12), (0.16, 0.06), (0, 0.06)], seg=14), axis="z")
    ang = math.atan2(0.17, 0.3)
    out["kit_exhaust"] = (shade(join([pipe, xform(tip, rot(-ang, 0, 0), (0, 0.62, 1.3))])), "обвес: хромированный выхлоп")
    # корона: обруч с пятью зубцами и шариками
    parts = [revolve([(0, 0.0), (0.46, 0.0), (0.48, 0.05), (0.47, 0.25), (0.5, 0.3), (0.44, 0.3), (0.41, 0.05), (0, 0.05)], seg=30)]
    for k in range(5):
        t = 2 * PI * k / 5 + PI / 2
        c, s = math.cos(t), math.sin(t)
        parts.append(prism([(-0.17, 0.28), (0.17, 0.28), (0.0, 0.72)], 0.08,
                           lambda u, v, w, c=c, s=s: (c * (0.455 + w) - s * u, v, s * (0.455 + w) + c * u)))
        parts.append(ball(0.07, c=(c * 0.455, 0.76, s * 0.455), sub=1))
    out["kit_crown"] = (shade(join(parts)), "обвес: корона")
    return out


# ================================================================ золотая кромка по контуру (тир 4, #33)
def trim_meshes():
    """Блестящая кромка по контуру каждой модели (тир 4): видна сверху-сзади с камеры заезда."""
    prof = superellipse(0.09, 0.07, 0.05, n=3, seg=8)

    def loop(pts):
        return shade(sweep(pts, prof, up=(0, 1, 0), closed=True))

    def rrect(hx, z0, z1, y, r=0.35, n=6):
        pts = []
        for cx, cz, a0 in ((hx - r, z1 - r, 0), (-(hx - r), z1 - r, PI / 2), (-(hx - r), z0 + r, PI), (hx - r, z0 + r, 1.5 * PI)):
            for k in range(n):
                a = a0 + PI / 2 * k / (n - 1)
                pts.append((cx + r * math.cos(a), y, cz + r * math.sin(a)))
        return pts

    def side_loop(fn, z0, z1, n=22):
        """Замкнутый контур из правого борта x = fn(z) → (x, y) и его зеркала."""
        right = []
        for k in range(n):
            z = z0 + (z1 - z0) * k / (n - 1)
            x, y = fn(z)
            right.append((x, y, z))
        return right + [(-x, y, z) for x, y, z in right[::-1][1:-1]]

    def board_side(z):
        az = abs(z)
        w = (1.38 + 0.17 * (az / 2.9) ** 2) if az <= 2.9 else 1.55 * math.sqrt(max(0.0, 1 - ((az - 2.9) / 1.4) ** 2))
        return max(w, 0.12) + 0.02, -0.45 + 0.95 * max(0.0, (az - 2.75) / 1.55) ** 1.8 + 0.1

    def kayak_side(z):
        s = 2 * (z + 4.4) / 8.6 - 1
        return 1.27 * max(0.0, 1 - s * s) ** 0.62 + 0.04, 0.34 + 0.22 * s * s

    def bob_side(z):
        W, T, B, F = bob_section(z)
        return W - 0.08, T + 0.03

    def plane_side(z):  # не используется: у самолёта кромка по крылу
        return 0, 0

    out = {
        "trim_tube": loop(ring_path(3.95, 0.05, n=40)),
        "trim_saucer": loop(ring_path(2.6, -0.04, n=40)),
        "trim_board": loop(side_loop(board_side, -4.15, 4.15, 26)),
        "trim_toboggan": loop(rrect(1.38, -3.0, 3.3, -0.38)),
        "trim_classic": loop(rrect(2.32, -1.92, 3.95, 0.6)),
        "trim_kayak": loop(side_loop(kayak_side, -4.0, 3.85, 26)),
        "trim_bobsled": loop(side_loop(bob_side, -1.3, 2.95, 20)),
        "trim_snowmobile": loop(rrect(1.0, -0.35, 2.98, 0.06, r=0.3)),
    }
    # самолёт: передняя и задняя кромки крыла (крыло y −0.38, носок z −1.25, хорда 2.2 → 1.5)
    front, back = [], []
    for k in range(25):
        x = -5.15 + 10.3 * k / 24
        t = abs(x) / 5.3
        ch = 2.2 - 0.7 * t
        y = -0.38 + abs(x) * 0.05 + 0.03
        dz = (2.2 - ch) * 0.25
        front.append((x, y, -1.25 + dz + 0.02))
        back.append((x, y, -1.25 + dz + ch - 0.05))
    out["trim_plane"] = loop(front + back[::-1])
    return {k: (v, "кромка тира 4: " + k[5:]) for k, v in out.items()}


# ================================================================ ракеты (Rockets)
def rocket_meshes():
    """Боковая ракета (референс: модельные ракеты Estes, «Восток»): корпус с шеей и сужением к соплу,
    оживальный обтекатель, сопло-колокол с горловиной и полостью, стреловидные стабилизаторы
    (2/3/4 — по тиру) с законцовками, передние «утки», хомут с заклёпками. Единицы d = 1
    (MeshPart масштабируется по d тира); корпус — L = 3.1 (у тиров 3.0–3.2 d).
    Кадры: корпус — центр ракеты; нос — срез корпуса спереди; сопло и стабилизаторы — срез сзади."""
    L = 3.1
    out = {}
    body = revolve([(0, -L / 2), (0.45, -L / 2), (0.45, -0.31 * L), (0.5, -0.29 * L), (0.5, 0.44 * L), (0.47, L / 2), (0, L / 2)], seg=24)
    out["rocket_body"] = (shade(place(body, axis="z"), 30), "ракета: корпус")
    og = [(0.45 * (1 - k / 9) ** 0.62 * (1 + 0.25 * (k / 9) * (1 - k / 9)), -1.0 * k / 9) for k in range(10)]
    nose = revolve([(0, 0.05), (0.45, 0.05)] + og[1:-1] + [(0, -1.0)], seg=24)
    out["rocket_nose"] = (shade(place(nose, axis="z"), 50), "ракета: обтекатель")
    bell = revolve([(0, 0.32), (0.27, 0.34), (0.43, 0.77), (0.52, 0.78), (0.48, 0.45), (0.37, 0.2), (0.45, 0.06), (0.45, -0.05), (0, -0.05)], seg=24)
    out["rocket_bell"] = (shade(place(bell, axis="z"), 35), "ракета: сопло")

    def fins(n, start):
        parts = []
        poly = [(-1.38, 0.47), (-0.02, 0.47), (0.12, 1.42), (-0.5, 1.42)]
        for i in range(n):
            a = math.radians(start + i * 360 / n)
            dx, dy = -math.sin(a), math.cos(a)  # +Y, повёрнутый на a вокруг Z (как CFrame.Angles(0, 0, a))
            px, py = math.cos(a), math.sin(a)
            parts.append(prism(poly, 0.11, lambda z, r, w, dx=dx, dy=dy, px=px, py=py: (dx * r + px * w, dy * r + py * w, z)))
            parts.append(rbox(0.15, 0.13, 0.62, c=(dx * 1.42, dy * 1.42, -0.2), n=3, seg=8, rows=2))
        return shade(join(parts))

    out["rocket_fins2"] = (fins(2, 90), "ракета: 2 стабилизатора")
    out["rocket_fins3"] = (fins(3, 0), "ракета: 3 стабилизатора")
    out["rocket_fins4"] = (fins(4, 45), "ракета: 4 стабилизатора")
    can = [prism([(-0.35, 0.45), (0.35, 0.45), (0.1, 0.85), (-0.2, 0.85)], 0.09, lambda z, r, w, sx=sx: (sx * r, w, z)) for sx in (-1, 1)]
    out["rocket_canards"] = (shade(join(can)), "ракета: передние крылышки")
    band = [place(revolve([(0, -0.1), (0.53, -0.1), (0.55, -0.07), (0.55, 0.07), (0.53, 0.1), (0, 0.1)], seg=24), axis="z")]
    for i in range(8):
        a = 2 * PI * i / 8
        band.append(ball(0.05, c=(math.cos(a) * 0.55, math.sin(a) * 0.55, 0), sub=0))
    out["rocket_band"] = (shade(join(band)), "ракета: хомут с заклёпками")
    return out


def all_meshes():
    """Все меши транспорта: имя → (меш, подпись)."""
    out = {}
    for fn in BODIES.values():
        out.update(fn())
    out.update(kit_meshes())
    out.update(trim_meshes())
    out.update(rocket_meshes())
    return out
