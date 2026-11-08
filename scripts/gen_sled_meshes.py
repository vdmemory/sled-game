#!/usr/bin/env python3
"""Меши транспорта: корпуса 9 моделей саней, обвес тиров, ракеты (SledModels/BodyMeshes, Kit, Rockets).

Подключён к scripts/gen_meshes.py (тот же пайплайн: .glb в assets/meshes → деплой загружает
scripts/upload_meshes.py → MeshIds → server/MeshAssets → ReplicatedStorage.MeshTemplates).
Кадр — кадр саней: X вправо, Y вверх, нос по −Z, 0 — центр невидимого сиденья 5×1×5 (персонаж
сидит на y = +0.5, днище ≈ −0.5…−0.9). Меш красится целиком через MeshPart.Color, поэтому модель
разбита на части по цветам: корпус (main), детали (accent), металл/резина/стекло — нейтрально.
Обвес и ракеты — в своём кадре (начало — точка крепления, см. SledModels/Mounts).
Чертежи (референсы реальных объектов) — в docstring каждой функции и в docs/GAME_DESIGN.md.
"""
import math

import numpy as np

from sled_geom import (PI, airfoil, arc, ball, both, box, circle, cyl, ellipse, join, loft, orient_from, place, prism,
                       rbox, rect, revolve, ring3, ring_path, rot, shade, superellipse, sweep, tube, xform, M, solid)

TRI_BUDGET = 6000  # треугольников на модель (все её меши вместе)


def smoothstep(t):
    t = min(max(t, 0.0), 1.0)
    return t * t * (3 - 2 * t)


# ================================================================ 1. ватрушка (tube)
def tube_meshes():
    """Надувная ватрушка (snow tube, референс: тюбинги 100–120 см с ПВХ-дном и нейлоновыми ручками):
    толстый тор R 2.85 / r 1.1 (центр y 0.05, внешний Ø 7.9), верх — цветной чехол, низ — чёрное
    усиленное дно; тканевое сиденье в отверстии; лента по верху и эмблема спереди (accent);
    две ручки-петли из стропы по бокам, ниппель сзади."""
    R, r, y0 = 2.85, 1.1, 0.05
    n_u = 40

    def part(a0, a1, nv, rr=r):
        prof = [(rr * math.cos(a0 + (a1 - a0) * k / (nv - 1)), rr * math.sin(a0 + (a1 - a0) * k / (nv - 1)) * 0.94) for k in range(nv)]
        rings = []
        for i in range(n_u):
            t = 2 * PI * i / n_u
            d = np.array([math.cos(t), 0, math.sin(t)])
            rings.append([np.array([0, y0, 0]) + d * (R + u) + np.array([0, v, 0]) for u, v in prof])
        rows, cols = n_u, nv
        f = []
        for i in range(rows):
            i2 = (i + 1) % rows
            for j in range(cols - 1):
                a, b, c, dd = i * cols + j, i * cols + j + 1, i2 * cols + j, i2 * cols + j + 1
                f += [[a, b, dd], [a, dd, c]]
        m = M(np.vstack(rings), f)

        def ref(p):
            q = np.array([p[0], 0, p[2]])
            q = q / (np.linalg.norm(q) + 1e-9) * R
            return np.array([q[0], y0, q[2]])

        return orient_from(m, ref)

    top = part(math.radians(-28), math.radians(208), 15)  # цветной чехол сверху и по бокам
    base = part(math.radians(208), math.radians(332), 7)  # чёрное дно
    # сиденье: провисающая ткань в отверстии
    seat = revolve([(0, -0.62), (1.0, -0.6), (1.6, -0.5), (1.95, -0.3), (1.95, -0.18), (1.55, -0.38), (0.9, -0.48), (0, -0.5)], seg=28)
    # лента по верху и эмблема спереди
    stripe = sweep(ring_path(R, y0 + r * 0.94 + 0.005, n=n_u), rect(0.3, 0.035), up=(0, 1, 0), closed=True)
    emblem = xform(cyl(0.55, 0.08, axis="z", seg=20), rot(math.radians(-18), 0, 0), (0, y0 + 0.35, -(R + r * 0.9)))
    # ручки: стропа петлёй + накладки, ниппель с колпачком сзади
    straps = []
    for sx in (-1, 1):
        x = sx * (R + 0.35)
        loop = [(x, 0.95, -0.95), (x + sx * 0.32, 1.35, -0.7), (x + sx * 0.42, 1.62, 0.0), (x + sx * 0.32, 1.35, 0.7), (x, 0.95, 0.95)]
        straps.append(sweep(loop, rect(0.03, 0.17), up=(sx, 0.4, 0)))
        for z in (-0.95, 0.95):
            straps.append(rbox(0.5, 0.06, 0.5, c=(x - sx * 0.05, 0.92, z), n=4, seg=12, rows=3))
    valve = [cyl(0.16, 0.35, c=(0, y0 + r * 0.9, R + 0.25), axis="y", seg=12), cyl(0.21, 0.18, c=(0, y0 + r * 0.9 + 0.25, R + 0.25), seg=12)]
    return {
        "sled_tube_top": (shade(top), "ватрушка: цветной чехол"),
        "sled_tube_base": (shade(base), "ватрушка: чёрное дно"),
        "sled_tube_seat": (shade(seat), "ватрушка: тканевое сиденье"),
        "sled_tube_trim": (shade(join([stripe, emblem])), "ватрушка: лента и эмблема"),
        "sled_tube_strap": (shade(join(straps + valve)), "ватрушка: ручки и ниппель"),
    }


# ================================================================ 2. ледянка (saucer)
def saucer_meshes():
    """Ледянка-тарелка (plastic snow saucer Ø 65–80 см): выпуклое дно с кольцевым ребром, толстый
    закатанный бортик, неглубокая чаша; два литых ручки-хвата по бокам. Ø 5.5, низ y −0.72."""
    body = revolve([(0, -0.74), (0.9, -0.73), (1.0, -0.7), (1.1, -0.73), (2.1, -0.66), (2.55, -0.56), (2.74, -0.42),
                    (2.8, -0.26), (2.74, -0.12), (2.6, -0.06), (2.44, -0.1), (2.36, -0.22), (2.1, -0.32), (1.4, -0.39), (0, -0.42)], seg=44)
    dish = revolve([(0, -0.415), (1.5, -0.38), (2.08, -0.315), (2.2, -0.29), (2.08, -0.3), (1.5, -0.365), (0, -0.4)], seg=44)
    ring = sweep(ring_path(1.75, -0.36, n=40), rect(0.12, 0.025), up=(0, 1, 0), closed=True)
    grips = []
    for sx in (-1, 1):
        pts = [(sx * 2.45, -0.12, -0.75), (sx * 2.78, 0.2, -0.45), (sx * 2.86, 0.26, 0.0), (sx * 2.78, 0.2, 0.45), (sx * 2.45, -0.12, 0.75)]
        grips.append(tube(pts, 0.11, seg=10, up=(0, 1, 0), scale=[(1, 1.3)] * 5))
    return {
        "sled_saucer_body": (shade(body), "ледянка: корпус"),
        "sled_saucer_dish": (shade(dish), "ледянка: светлая чаша"),
        "sled_saucer_trim": (shade(join([ring] + grips)), "ледянка: кольцо и ручки"),
    }


# ================================================================ 3. доска (board)
def board_meshes():
    """Сноуборд-твин (референс: all-mountain 155 см): длина 8.6, ширина 3.1 в контактных точках,
    сайдкат (талия 2.75), рокер — нос и хвост поднимаются на 0.9; чёрная скользяк-кромка; два
    крепления (база, хилкап, хайбэк, два стрепа accent) под ±12°, стомп-пэд, графика полосами."""
    Y, L, flat = -0.45, 4.3, 2.75

    def rise(z):
        t = max(0.0, (abs(z) - flat) / (L - flat))
        return 0.95 * t ** 1.8

    def half_w(z):
        a = abs(z)
        if a <= 2.9:
            return 1.38 + 0.17 * (a / 2.9) ** 2  # сайдкат
        return 1.55 * math.sqrt(max(0.0, 1 - ((a - 2.9) / 1.4) ** 2))

    def plate(th, grow, dy, n_sec=56):
        rings = []
        for k in range(n_sec + 1):
            z = -L + 2 * L * k / n_sec
            w = max(half_w(z) + grow, 0.03)
            tt = th * (1 - 0.35 * smoothstep((abs(z) - 3.2) / 1.1))
            rings.append(ring3(superellipse(w, tt / 2, tt / 2, n=8, seg=14), z=z, cy=Y + rise(z) + dy))
        return loft(rings)

    deck = plate(0.2, 0.0, 0.0)
    base = plate(0.06, 0.035, -0.115)
    bind, acc = [], []
    for z in (-1.55, 1.55):
        R = rot(0, math.radians(12 if z < 0 else -12), 0)
        top = Y + 0.1

        def P(x, y, zz):
            return tuple(np.array([0, top, z]) + R @ np.array([x, y, zz]))

        bind.append(xform(rbox(1.05, 0.12, 1.25, n=4, seg=16, rows=4), R, P(0, 0.06, 0)))
        # хилкап (дуга сзади) и хайбэк (наклонная спинка)
        heel = [P(0.55 * math.cos(a), 0.3, 0.45 + 0.25 * math.sin(a)) for a in np.linspace(0, PI, 9)]
        bind.append(sweep(heel, rect(0.06, 0.22), up=(0, 1, 0)))
        hb = [P(0.48 * math.cos(a), 0.55, 0.62 + 0.2 * math.sin(a)) for a in np.linspace(0.15, PI - 0.15, 9)]
        bind.append(sweep(hb, rect(0.05, 0.38), up=tuple(R @ np.array([0, 0.97, 0.25]))))
        for dz, w in ((-0.3, 0.2), (0.22, 0.26)):
            strap = [P(0.62 * math.cos(a), 0.14 + 0.42 * math.sin(a), dz) for a in np.linspace(0, PI, 11)]
            acc.append(sweep(strap, rect(0.05, w / 2), up=lambda p, c=np.array(P(0, 0.14, dz)): p - c))
            bind.append(xform(rbox(0.16, 0.2, 0.3, n=3, seg=10, rows=2), R, P(0.6, 0.3, dz)))  # пряжка
    for k in (-1, 0, 1):
        bind.append(box(0.85, 0.05, 0.1, c=(0, Y + 0.12, k * 0.22)))
    # графика: две косые полосы на плоской части деки
    for z in (-0.55, 0.55):
        acc.append(xform(box(2.5, 0.02, 0.3), rot(0, math.radians(25), 0), (0, Y + 0.105, z)))
    for z in (-3.35, 3.35):
        acc.append(xform(box(1.6, 0.02, 0.18), rot(math.radians(-22 if z < 0 else 22), 0, 0), (0, Y + rise(z) + 0.11, z)))
    return {
        "sled_board_deck": (shade(deck), "доска: дека с сайдкатом и рокером"),
        "sled_board_base": (shade(base), "доска: скользяк и кант"),
        "sled_board_bind": (shade(join(bind)), "доска: крепления"),
        "sled_board_accent": (shade(join(acc)), "доска: стрепы и графика"),
    }


# ================================================================ 4. тобоган (toboggan)
def toboggan_meshes():
    """Канадский тобоган (референс: деревянный toboggan 6–8 футов): 5 досок-ламелей с зазорами,
    передний загиб «завиток» R 0.95 на 208°, стяжка завитка, поперечины, стойки с верёвочными
    поручнями вдоль бортов, мягкая подушка-сиденье."""
    Y, z_front, z_back, rc = -0.48, -3.1, 3.3, 0.95

    def plank_path():
        pts = [(0, Y, z) for z in np.linspace(z_back, z_front, 14)]
        for a in np.linspace(0, math.radians(208), 22)[1:]:
            pts.append((0, Y + rc - math.cos(a) * rc, z_front - math.sin(a) * rc))
        return pts

    path = plank_path()
    planks_a, planks_b = [], []
    for k in range(-2, 3):
        pts = [(k * 0.53, y, z) for _, y, z in path]
        # нормаль к доске — к центру завитка на дуге, вверх на прямой
        def up(p):
            if p[2] > z_front + 1e-6:
                return (0, 1, 0)
            c = np.array([p[0], Y + rc, z_front])
            return c - np.array(p)

        m = sweep(pts, superellipse(0.08, 0.245, 0.245, n=6, seg=10), up=up)
        (planks_a if k % 2 == 0 else planks_b).append(m)
    frame = []
    for z in (-2.4, -0.6, 1.2, 2.9):
        frame.append(rbox(2.85, 0.13, 0.3, c=(0, Y + 0.14, z), n=4, seg=12, rows=3))
    a_end = math.radians(200)
    frame.append(cyl(0.12, 2.9, c=(0, Y + rc - math.cos(a_end) * rc + 0.1, z_front - math.sin(a_end) * rc), axis="x", seg=12))
    rope = []
    for sx in (-1, 1):
        x = sx * 1.38
        for z in (-2.6, 0.2, 3.0):
            frame.append(rbox(0.13, 0.5, 0.13, c=(x, Y + 0.38, z), n=4, seg=8, rows=2))
        pts = []
        for z in np.linspace(-2.6, 3.0, 21):
            seg_t = ((z + 2.6) / 2.8) % 1.0
            pts.append((x, Y + 0.62 - 0.17 * math.sin(PI * seg_t), z))
        rope.append(tube(pts, 0.07, seg=8))
    # верёвка-поводок от завитка
    lead = [(-1.2, 1.15, -2.65), (-0.9, 0.95, -3.6), (-0.3, 0.8, -4.0), (0.3, 0.8, -4.0), (0.9, 0.95, -3.6), (1.2, 1.15, -2.65)]
    rope.append(tube(lead, 0.065, seg=8))
    pad = rbox(2.3, 0.26, 2.6, c=(0, Y + 0.22, 0.6), n=3, seg=20, rows=6)
    return {
        "sled_tob_planks_a": (shade(join(planks_a)), "тобоган: доски (светлые)"),
        "sled_tob_planks_b": (shade(join(planks_b)), "тобоган: доски (тёмные)"),
        "sled_tob_frame": (shade(join(frame)), "тобоган: поперечины, стойки, стяжка"),
        "sled_tob_rope": (shade(join(rope)), "тобоган: верёвочные поручни"),
        "sled_tob_pad": (shade(pad), "тобоган: подушка"),
    }


# ================================================================ 5. деревянные санки (classic)
def classic_meshes():
    """Классические санки (референс: Flexible Flyer / «Чунга» со стальными полозьями): полозья —
    стальная полоса, загнутая спереди полукругом R 0.9 и чуть вверх сзади; деревянные стойки-копылья,
    продольные брусья, 6 лакированных реек со скруглёнными торцами, задний бортик, передняя
    поперечина и дуга-руль, болты и уголки, верёвка-поводок."""
    runners, frame, slats, metal, rope = [], [], [], [], []
    for sx in (-1, 1):
        x = sx * 1.9
        pts = [(x, -0.4, 3.75), (x, -0.55, 3.45), (x, -0.62, 2.8)]
        pts += [(x, -0.62, z) for z in np.linspace(2.2, -2.6, 8)]
        for a in np.linspace(0, PI, 13)[1:]:
            pts.append((x, -0.62 + 0.9 - math.cos(a) * 0.9, -2.6 - math.sin(a) * 0.9))
        pts += [(x, 1.12, -2.25), (x, 1.0, -1.9)]
        runners.append(sweep(pts, superellipse(0.09, 0.075, 0.075, n=4, seg=10), up=(1, 0, 0)))
        for z in (-1.8, 0.0, 1.8, 3.2):
            # копыл: сужающаяся стойка от полоза к брусу
            frame.append(cyl(0.2, 0.75, c=(x, -0.17, z), seg=10, r2=0.14))
            metal.append(box(0.36, 0.1, 0.62, c=(x, -0.5, z)))
        frame.append(rbox(0.42, 0.3, 6.1, c=(x, 0.24, 0.7), n=5, seg=14, rows=8))
    for k in range(6):
        z = -1.5 + k * 1.0
        slats.append(rbox(4.6, 0.2, 0.78, c=(0, 0.48, z), n=4, seg=16, rows=4))
        for sx in (-1, 1):
            metal.append(ball(0.09, c=(sx * 1.9, 0.59, z), sub=1))
    frame.append(rbox(4.5, 0.42, 0.26, c=(0, 0.77, 3.85), n=4, seg=14, rows=3))
    frame.append(rbox(4.4, 0.3, 0.5, c=(0, 0.6, -2.2), n=4, seg=14, rows=3))
    bar = [(-1.95, 1.0, -1.9), (-1.6, 1.2, -2.1), (-0.8, 1.3, -2.22), (0, 1.33, -2.25), (0.8, 1.3, -2.22), (1.6, 1.2, -2.1), (1.95, 1.0, -1.9)]
    frame.append(tube(bar, 0.13, seg=10))
    lead = [(-1.25, 1.22, -2.3), (-1.05, 0.95, -3.0), (-0.45, 0.78, -3.45), (0.45, 0.78, -3.45), (1.05, 0.95, -3.0), (1.25, 1.22, -2.3)]
    rope.append(tube(lead, 0.07, seg=8))
    return {
        "sled_classic_runner": (shade(join(runners)), "санки: стальные полозья"),
        "sled_classic_slats": (shade(join(slats)), "санки: рейки настила"),
        "sled_classic_frame": (shade(join(frame)), "санки: копылья, брусья, руль"),
        "sled_classic_metal": (shade(join(metal)), "санки: болты и уголки"),
        "sled_classic_rope": (shade(join(rope)), "санки: верёвка"),
    }


# ================================================================ 6. каяк (kayak)
def kayak_meshes():
    """Каяк (референс: туристический sit-in 3–3.5 м): длинный корпус 8.6 с острыми носом и кормой,
    седловатость (оконечности выше), скруглённая палуба и V-образное днище с килем, овальный кокпит с
    комингсом и юбкой, полоса и резинки по палубе, весло поперёк, ручки-тогглы."""
    zf, zb = -4.4, 4.2

    def prm(z):
        t = (z - zf) / (zb - zf)  # 0 нос … 1 корма
        s = 2 * t - 1
        full = max(0.0, 1 - s * s)
        w = 1.27 * full ** 0.62 + 0.02
        sheer = 0.4 + 0.22 * s * s
        depth = 0.62 * full ** 0.45 + 0.03
        cy = -0.12 + 0.18 * s * s
        return w, sheer, depth, cy

    rings = []
    for k in range(49):
        z = zf + (zb - zf) * k / 48
        w, sheer, depth, cy = prm(z)
        rings.append(ring3(superellipse(w, sheer - cy, depth, n=2.3, nb=1.7, seg=26), z=z, cy=cy))
    hull = loft(rings)
    trim = []
    strip = []
    for k in range(37):
        z = -3.6 + 7.2 * k / 36
        w, sheer, depth, cy = prm(z)
        strip.append((0, sheer + 0.012, z))
    trim.append(sweep(strip, rect(0.02, 0.18), up=(0, 1, 0)))
    # лопасти весла (ложки)
    for sx in (-1, 1):
        blade = rbox(0.1, 0.62, 1.15, n=3, seg=14, rows=6)
        trim.append(xform(blade, rot(0, 0, sx * math.radians(15)), (sx * 2.9, 0.98, -0.4)))
    black = []
    coam = [(0.66 * math.cos(a), 0.47, 0.45 + 1.0 * math.sin(a)) for a in np.linspace(0, 2 * PI, 33)[:-1]]
    black.append(sweep(coam, superellipse(0.07, 0.08, 0.06, n=3, seg=8), up=(0, 1, 0), closed=True))
    black.append(xform(revolve([(0, 0.4), (0.6, 0.42), (0.62, 0.47), (0, 0.45)], seg=28), np.diag([1, 1, 1.62]), (0, 0, 0.45)))
    for z in (-2.6, -2.1, 2.3, 2.8):
        w, sheer, depth, cy = prm(z)
        black.append(box(2 * w * 0.86, 0.04, 0.05, c=(0, sheer, z)))  # резинки
    for z, dz in ((zf + 0.35, -0.25), (zb - 0.35, 0.25)):
        w, sheer, depth, cy = prm(z)
        black.append(tube([(-0.2, sheer - 0.05, z), (0, sheer + 0.16, z + dz), (0.2, sheer - 0.05, z)], 0.055, seg=8))
    paddle = cyl(0.075, 5.4, c=(0, 0.98, -0.4), axis="x", seg=10)
    return {
        "sled_kayak_hull": (shade(hull), "каяк: корпус"),
        "sled_kayak_trim": (shade(join(trim)), "каяк: полоса и лопасти"),
        "sled_kayak_black": (shade(join(black)), "каяк: комингс, юбка, резинки"),
        "sled_kayak_paddle": (shade(paddle), "каяк: древко весла"),
    }


# ================================================================ 7. сани-самолёт (plane)
def plane_meshes():
    """Лёгкий самолёт на лыжах (референс: Piper Super Cub на лыжах / учебный низкоплан): обтекаемый
    фюзеляж с капотом и сужением к хвосту, открытая кабина с козырьком, низкое крыло с профилем и
    скруглёнными законцовками (размах 10.6), стабилизатор и киль, двухлопастный винт, лыжи с
    загнутыми носками на V-стойках, выхлопные патрубки."""
    rings = []
    zs = np.linspace(-3.15, 5.05, 40)
    for z in zs:
        if z < -2.0:
            t = (z + 3.15) / 1.15
            r = 0.5 + 0.7 * math.sqrt(max(0.0, 1 - (1 - t) ** 2))
        elif z < 1.6:
            r = 1.2
        else:
            t = (z - 1.6) / 3.45
            r = 1.2 - 0.9 * t ** 1.15
        cy = 0.2 + 0.32 * smoothstep((z - 1.4) / 3.6)
        rings.append(ring3(superellipse(r, r, r * 0.95, n=2.3, seg=24), z=z, cy=cy))
    body = loft(rings)

    def wing(span, chord_root, chord_tip, thick, y, z_lead, dihedral=0.0, n=14):
        rs = []
        for k in range(n + 1):
            x = -span / 2 + span * k / n
            t = abs(x) / (span / 2)
            tip = math.sqrt(max(0.0, 1 - max(0.0, (t - 0.86) / 0.14) ** 2))
            ch = (chord_root + (chord_tip - chord_root) * t) * max(tip, 0.08)
            sec = airfoil(ch, thick * max(tip, 0.25), seg=16)
            dz = (chord_root - ch) * 0.25
            rs.append([(x, y + abs(x) * dihedral + v, z_lead + dz + u) for u, v in sec])
        return loft(rs)

    accent = [wing(10.6, 2.2, 1.5, 0.3, -0.38, -1.25, dihedral=0.05), wing(3.6, 1.15, 0.8, 0.14, 0.62, 4.15)]
    fin = []
    for k in range(9):
        t = k / 8
        ch = 1.5 - 0.75 * t
        sec = airfoil(ch, 0.14, seg=14)
        fin.append([(v, 0.65 + t * 1.55, 3.85 + 0.6 * t + u) for u, v in sec])
    accent.append(loft(fin))
    glass = []
    shield = []
    for k in range(9):
        a = -PI * 0.42 + PI * 0.84 * k / 8
        shield.append((0.9 * math.sin(a), 1.3 + 0.62 * math.cos(a) * 0.5, -0.95 + 0.25 * math.cos(a)))
    glass.append(sweep(shield, rect(0.03, 0.34), up=(0, 0.6, -1)))
    black = []
    coam = [(0.82 * math.cos(a), 1.36, 0.35 + 1.15 * math.sin(a)) for a in np.linspace(0, 2 * PI, 29)[:-1]]
    black.append(sweep(coam, superellipse(0.07, 0.07, 0.07, n=3, seg=8), up=(0, 1, 0), closed=True))
    black.append(revolve([(0, 1.3), (0.8, 1.31), (0.8, 1.36), (0, 1.35)], seg=24).apply_scale([1, 1, 1]))
    black[-1] = xform(black[-1], np.diag([1, 1, 1.42]), (0, 0, 0.35))
    black.append(xform(rbox(1.2, 0.75, 0.25, n=3, seg=12, rows=3), rot(math.radians(10), 0, 0), (0, 1.72, 1.45)))
    for a in (20, 200):
        bl = []
        for k in range(9):
            t = k / 8
            ch = 0.42 - 0.22 * t
            sec = airfoil(ch, 0.06, seg=10)
            tw = math.radians(28 - 18 * t)
            rr = 0.25 + 1.6 * t
            pts = []
            for u, v in sec:
                lu = u - ch * 0.3
                pts.append((lu * math.cos(tw), rr, lu * math.sin(tw) + v))
            bl.append(pts)
        blade = loft(bl)
        black.append(xform(blade, rot(0, 0, math.radians(a)) @ rot(PI / 2, 0, 0) @ rot(-PI / 2, 0, 0), (0, 0.2, -3.5)))
    white = []
    metal = []
    for sx in (-1, 1):
        x = sx * 1.35
        pts = []
        for k in range(26):
            z = 3.0 - 5.6 * k / 25
            y = -0.93 + 0.5 * max(0.0, (-1.6 - z) / 1.0) ** 2
            pts.append((x, y, z))
        white.append(sweep(pts, superellipse(0.36, 0.06, 0.06, n=6, seg=12), up=(0, 1, 0)))
        for z in (-1.0, 1.8):
            metal.append(tube([(x, -0.86, z), (x * 0.55, 0.0, z - 0.15)], 0.08, seg=8))
            metal.append(tube([(x, -0.86, z), (x * 0.55, 0.0, z + 0.25)], 0.06, seg=8))
        for k in range(2):
            metal.append(tube([(sx * 1.05, -0.05 - k * 0.3, -1.55 + k * 0.1), (sx * 1.35, -0.25 - k * 0.3, -1.0 + k * 0.1)], 0.09, seg=8))
    metal.append(tube([(0, 1.4, 1.65), (0, 2.25, 2.3)], 0.04, seg=6))
    return {
        "sled_plane_body": (shade(body), "самолёт: фюзеляж"),
        "sled_plane_wing": (shade(join(accent)), "самолёт: крыло, стабилизатор, киль"),
        "sled_plane_glass": (shade(join(glass)), "самолёт: козырёк кабины"),
        "sled_plane_black": (shade(join(black)), "самолёт: кабина, кресло, винт"),
        "sled_plane_ski": (shade(join(white)), "самолёт: лыжи"),
        "sled_plane_metal": (shade(join(metal)), "самолёт: стойки и патрубки"),
    }


# ================================================================ 8. бобслей (bobsled)
def bob_section(z):
    """Параметры сечения бобслея: полуширина, верх борта, низ, уровень пола (= верх — закрыто)."""
    zf, zb = -4.3, 3.3
    if z < -1.5:
        t = (z - zf) / (-1.5 - zf)  # 0 нос … 1 начало кокпита
        e = math.sqrt(max(0.0, 1 - (1 - t) ** 2))
        W = 0.18 + 1.3 * e
        T = -0.05 + 0.72 * smoothstep(t * 1.05)
        B = -0.5 + 0.35 * (1 - t) ** 2
        F = T
    else:
        W = 1.48 - 0.06 * smoothstep((z - 1.5) / 1.8)
        T = 0.67 - 0.1 * smoothstep((z + 1.5) / 1.2) + 0.05 * smoothstep((z - 2.4) / 0.9)
        B = -0.5
        F = T if z > 3.0 else -0.28
        if -1.5 <= z < -1.2:
            F = T - (T + 0.28) * smoothstep((z + 1.5) / 0.3)
    return W, T, B, F


def bobsled_meshes():
    """Бобслей-двойка (референс: болид IBSF, карбоновый кокпит-обтекатель): низкий скруглённый нос,
    открытый сверху кокпит со стенками (заваливаются внутрь), закрытая корма, 4 стальных конька на
    стойках, выдвижные ручки разгона сзади, гоночные полосы по бортам и по носу, номер на борту."""
    zf, zb = -4.3, 3.3
    th = 0.16
    rings = []
    nz = 46
    for k in range(nz + 1):
        z = zf + (zb - zf) * k / nz
        W, T, B, F = bob_section(z)
        outer = superellipse(W, 0.0001, T - B, n=3.0, seg=28)[14:]  # нижняя половина: от (−W,T) к (W,T)
        outer = [(x, T + y) for x, y in outer] + [(W, T)]
        iw = max(W - th, 0.01)
        inner = [(W * 0.97, T + 0.02), (iw, T), (iw, F), (iw * 0.33, F), (-iw * 0.33, F), (-iw, F), (-iw, T), (-W * 0.97, T + 0.02)]
        rings.append(ring3([(-W, T)] + outer + inner, z=z))
    body = loft(rings)
    stripes = []
    for sx in (-1, 1):
        pts, ups = [], []
        for k in range(30):
            z = -3.9 + 7.0 * k / 29
            W, T, B, F = bob_section(z)
            y = T - 0.22 * (T - B) / 1.17
            xx = W * (1 - ((T - y) / (T - B)) ** 3) ** (1 / 3) + 0.012
            pts.append((sx * xx, y, z))
        stripes.append(sweep(pts, rect(0.02, 0.12), up=(sx, 0, 0)))
    nose = []
    for k in range(20):
        z = -4.15 + 2.6 * k / 19
        W, T, B, F = bob_section(z)
        nose.append((0, T + 0.012, z))
    stripes.append(sweep(nose, rect(0.02, 0.2), up=(0, 1, 0)))
    metal = []
    for sx in (-1, 1):
        x = sx * 1.08
        for z in (-2.0, 2.0):
            pts = [(x, -0.66, z - 1.15), (x, -0.72, z - 0.6), (x, -0.73, z + 0.6), (x, -0.68, z + 1.05), (x, -0.55, z + 1.3)]
            metal.append(sweep(pts, superellipse(0.04, 0.09, 0.09, n=4, seg=8), up=(1, 0, 0)))
            for dz in (-0.7, 0.7):
                metal.append(box(0.12, 0.3, 0.16, c=(x, -0.55, z + dz)))
        bar = [(sx * 1.42, 0.5, 2.55), (sx * 1.78, 0.56, 2.7), (sx * 1.8, 0.6, 3.05), (sx * 1.8, 0.6, 3.45)]
        metal.append(tube(bar, 0.07, seg=8))
        metal.append(cyl(0.11, 0.35, c=(sx * 1.8, 0.6, 3.5), axis="z", seg=10))
    inner = rbox(2.5, 0.05, 4.2, c=(0, -0.25, 0.85), n=6, seg=16, rows=5)
    return {
        "sled_bob_body": (shade(body, 50), "бобслей: обтекатель-кокпит"),
        "sled_bob_stripe": (shade(join(stripes)), "бобслей: гоночные полосы"),
        "sled_bob_metal": (shade(join(metal)), "бобслей: коньки и ручки"),
        "sled_bob_inner": (shade(inner), "бобслей: пол кокпита"),
    }


# ================================================================ 9. снегоход (snowmobile)
def snowmobile_meshes():
    """Снегоход (референс: спортивный Ski-Doo / Lynx): острый капот с воздухозаборниками, ветровое
    стекло дугой, руль на стойке, сиденье с подъёмом сзади, туннель над гусеницей, подножки, гусеница
    с грунтозацепами на катках, две лыжи с загнутыми носками на стойках подвески, бампер и брызговик."""
    hood = []
    rings = []
    for k in range(31):
        z = -3.75 + 3.55 * k / 30
        t = (z + 3.75) / 3.55
        W = 0.25 + 0.92 * math.sqrt(max(0.0, 1 - (1 - min(t * 1.25, 1)) ** 2))
        top = -0.1 + 1.0 * smoothstep(t * 1.1) - 0.1 * smoothstep((t - 0.75) / 0.25)
        bot = -0.42 + 0.12 * (1 - t) ** 2
        cy = (top + bot) / 2
        rings.append(ring3(superellipse(W, top - cy, cy - bot, n=2.8, nb=4, seg=26), z=z, cy=cy))
    hood.append(loft(rings))
    hood.append(rbox(1.92, 0.42, 3.3, c=(0, -0.18, 1.3), n=6, seg=18, rows=6))  # туннель
    accent = []
    for sx in (-1, 1):
        accent.append(rbox(0.5, 0.08, 2.6, c=(sx * 1.18, -0.36, 0.95), n=5, seg=12, rows=5))  # подножки
        pts = []
        for k in range(14):
            z = -3.3 + 2.6 * k / 13
            t = (z + 3.75) / 3.55
            W = 0.25 + 0.92 * math.sqrt(max(0.0, 1 - (1 - min(t * 1.25, 1)) ** 2))
            pts.append((sx * (W * 0.93 + 0.03), 0.02 + 0.15 * t, z))
        accent.append(sweep(pts, rect(0.025, 0.1), up=(sx, 0.3, 0)))
        accent.append(xform(rbox(0.1, 0.25, 0.7, n=3, seg=10, rows=3), rot(0, 0, sx * 0.3), (sx * 0.88, 0.62, -2.05)))  # воздухозаборник
    accent.append(tube([(-0.85, -0.25, -3.55), (-0.5, -0.05, -3.95), (0.5, -0.05, -3.95), (0.85, -0.25, -3.55)], 0.07, seg=8))
    accent.append(box(1.5, 0.55, 0.06, c=(0, -0.62, 3.05)))  # брызговик
    glass = []
    pts = []
    for k in range(11):
        a = -PI * 0.4 + PI * 0.8 * k / 10
        pts.append((0.95 * math.sin(a), 0.98 + 0.12 * math.cos(a), -1.75 + 0.38 * math.cos(a)))
    glass.append(sweep(pts, rect(0.025, 0.36), up=(0, 0.8, -0.65)))
    seat = []
    rs = []
    for k in range(17):
        z = -0.45 + 2.9 * k / 16
        t = k / 16
        top = 0.28 + 0.12 * smoothstep((t - 0.6) / 0.4)
        rs.append(ring3(superellipse(0.68 - 0.08 * t, top - 0.02, 0.2, n=4, nb=8, seg=18), z=z, cy=0.02))
    seat.append(loft(rs))
    for sx in (-1, 1):
        seat.append(cyl(0.11, 0.42, c=(sx * 1.08, 1.12, -1.02), axis="x", seg=10))  # грипсы
    track = []
    belt = []
    for k in range(48):
        a = 2 * PI * k / 48
        # «стадион» в плоскости YZ: прямые сверху/снизу, полукруги на концах
        Lh, rr, zc, yc = 1.3, 0.32, 1.25, -0.48
        per = 4 * Lh + 2 * PI * rr
        s = per * k / 48
        if s < 2 * Lh:
            p = (yc - rr, zc - Lh + s)
        elif s < 2 * Lh + PI * rr:
            b = (s - 2 * Lh) / rr
            p = (yc - rr * math.cos(b), zc + Lh + rr * math.sin(b))
        elif s < 4 * Lh + PI * rr:
            p = (yc + rr, zc + Lh - (s - 2 * Lh - PI * rr))
        else:
            b = (s - 4 * Lh - PI * rr) / rr
            p = (yc + rr * math.cos(b), zc - Lh - rr * math.sin(b))
        belt.append((0, p[0], p[1]))
    track.append(sweep(belt, rect(0.06, 0.8), up=lambda q: np.array([0, q[1] + 0.48, q[2] - 1.25]) * np.array([0, 1, 0.25]), closed=True))
    for k in range(13):
        z = -0.0 + 2.5 * k / 12
        track.append(box(1.62, 0.09, 0.1, c=(0, -0.86, z)))
    ski = []
    metal = []
    for sx in (-1, 1):
        x = sx * 1.18
        pts = []
        for k in range(20):
            z = -1.0 - 2.9 * k / 19
            y = -0.76 + 0.45 * max(0.0, (z + 3.2) / -0.7) ** 2
            pts.append((x, y, z))
        ski.append(sweep(pts, superellipse(0.24, 0.05, 0.05, n=6, seg=12), up=(0, 1, 0)))
        ski.append(box(0.06, 0.08, 2.0, c=(x, -0.83, -2.1)))
        metal.append(tube([(x, -0.7, -2.15), (x * 0.78, -0.15, -1.85)], 0.08, seg=8))
        metal.append(tube([(x, -0.7, -2.15), (x * 0.6, -0.3, -2.6)], 0.06, seg=8))
        for z in (0.35, 1.25, 2.15):
            metal.append(cyl(0.2, 0.18, c=(sx * 0.55, -0.62, z), axis="x", seg=12))
    metal.append(tube([(-1.0, 1.12, -1.02), (-0.5, 1.02, -1.15), (0.5, 1.02, -1.15), (1.0, 1.12, -1.02)], 0.065, seg=8))
    metal.append(tube([(0, 0.55, -1.3), (0, 1.02, -1.15)], 0.08, seg=8))
    metal.append(tube([(-0.9, -0.25, 2.95), (-0.9, 0.05, 3.2), (0.9, 0.05, 3.2), (0.9, -0.25, 2.95)], 0.06, seg=8))
    return {
        "sled_snow_hood": (shade(join(hood)), "снегоход: капот и туннель"),
        "sled_snow_accent": (shade(join(accent)), "снегоход: подножки, полосы, бампер"),
        "sled_snow_glass": (shade(join(glass)), "снегоход: ветровое стекло"),
        "sled_snow_seat": (shade(join(seat)), "снегоход: сиденье и грипсы"),
        "sled_snow_track": (shade(join(track)), "снегоход: гусеница"),
        "sled_snow_ski": (shade(join(ski)), "снегоход: лыжи"),
        "sled_snow_metal": (shade(join(metal)), "снегоход: руль, подвеска, катки"),
    }


BODIES = {
    "tube": tube_meshes, "saucer": saucer_meshes, "board": board_meshes, "toboggan": toboggan_meshes,
    "classic": classic_meshes, "kayak": kayak_meshes, "plane": plane_meshes, "bobsled": bobsled_meshes,
    "snowmobile": snowmobile_meshes,
}
