#!/usr/bin/env python3
"""Генерирует свои 3D-меши декора (#45) кодом: assets/meshes/*.glb + src/shared/MeshSpecs.luau.

Low-poly-стилизация: плоские грани (flat shading) у камня/льда/хвои, гладкие нормали у снега.
Каждый меш строится в «кадре объекта»: Y вверх, начало координат — центр основания на земле,
единица ≈ 1 stud при масштабе 1. MeshPart растягивает меш на свой Size по габаритам, поэтому
в MeshSpecs пишутся габариты (size) и центр габаритов (offset) в кадре объекта — Props/Meshes
ставит MeshPart с Size = size·масштаб и CFrame = основание · offset·масштаб. Так части одного
объекта (хвоя + снег, скала + снежная шапка) совпадают при любом масштабе.

Запуск: python3 scripts/gen_meshes.py  (нужны numpy, trimesh: pip install numpy trimesh)
Детерминирован (свои seed) — перегенерация без изменений формы даёт те же файлы.
Новый меш: функция → MESHES → перегенерировать → деплой загрузит (scripts/upload_meshes.py).
"""
import json
import math
import pathlib

import numpy as np
import trimesh
import trimesh.exchange.gltf

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "meshes"
SPECS_LUAU = ROOT / "src" / "shared" / "MeshSpecs.luau"
TRI_LIMIT = 5000


# ---------------------------------------------------------------- помощники
class Noise:
    """Гладкий псевдошум: сумма синусоид со случайными направлениями (детерминирован по seed)."""

    def __init__(self, seed, octaves=5, freq=1.0):
        r = np.random.default_rng(seed)
        self.terms = []
        for o in range(octaves):
            d = r.normal(size=3)
            d /= np.linalg.norm(d)
            f = freq * (1.9 ** o) * r.uniform(0.8, 1.2)
            self.terms.append((d * f, r.uniform(0, 2 * math.pi), 0.55 ** o))
        self.norm = sum(a for _, _, a in self.terms)

    def __call__(self, p):
        p = np.atleast_2d(p)
        s = np.zeros(len(p))
        for d, ph, a in self.terms:
            s += a * np.sin(p @ d + ph)
        return s / self.norm


def grid_surface(rows, cols, fn, wrap=True):
    """Поверхность по сетке (rows × cols) из fn(i, j) -> (x, y, z); wrap — замкнуть по j."""
    verts = np.array([fn(i, j) for i in range(rows) for j in range(cols)], dtype=float)
    faces = []
    jc = cols if wrap else cols - 1
    for i in range(rows - 1):
        for j in range(jc):
            a = i * cols + j
            b = i * cols + (j + 1) % cols
            c = (i + 1) * cols + j
            d = (i + 1) * cols + (j + 1) % cols
            faces.append([a, c, b])
            faces.append([b, c, d])
    return verts, np.array(faces)


def cap(verts, faces, ring_start, cols, center, up):
    """Закрыть кольцо вершин веером к центру (up=True — нормаль вверх)."""
    verts = np.vstack([verts, center])
    ci = len(verts) - 1
    nf = []
    for j in range(cols):
        a = ring_start + j
        b = ring_start + (j + 1) % cols
        nf.append([ci, b, a] if up else [ci, a, b])
    return verts, np.vstack([faces, nf])


def mesh_of(verts, faces):
    return trimesh.Trimesh(vertices=verts, faces=faces, process=True)


def combine(parts):
    return trimesh.util.concatenate(parts)


def finish(m, flat):
    """Нормали наружу, плоские грани для low-poly (unmerge) или гладкие (merge)."""
    m = m.copy()
    m.remove_unreferenced_vertices()
    m.update_faces(m.nondegenerate_faces())
    if m.is_watertight:
        m.fix_normals()
    elif m.face_normals[:, 1].mean() < 0:  # открытая шапка (снег горы) — лицом вверх
        m.faces = m.faces[:, ::-1]  # (Trimesh.invert в 5.x не сбрасывает кэш нормалей)
    if flat:
        m.unmerge_vertices()
    else:
        m.merge_vertices()
    add_uv(m)
    return m


UV_SCALE = 1.5  # тайлов текстуры материала на единицу кадра объекта


def add_uv(m):
    """Коробочная (triplanar) проекция UV: материалы Roblox (Slate, Snow, Glacier…) на MeshPart
    текстурируются по UV — без них текстура «замирает» в одной точке. Ось проекции — по нормали
    (у плоских граней — нормаль грани, у гладких — вершины)."""
    v = m.vertices
    if len(m.vertices) == len(m.faces) * 3:  # flat: вершины свои у каждой грани
        n = np.repeat(m.face_normals, 3, axis=0)
        order = m.faces.reshape(-1)
        nn = np.zeros_like(v)
        nn[order] = n
    else:
        nn = m.vertex_normals
    ax = np.abs(nn).argmax(axis=1)
    uv = np.where(ax[:, None] == 0, v[:, [2, 1]], np.where(ax[:, None] == 1, v[:, [0, 2]], v[:, [0, 1]]))
    # белый материал без картинки: импорт Roblox не создаёт TextureID, цвет задаёт MeshPart.Color
    mat = trimesh.visual.material.PBRMaterial(baseColorFactor=[255, 255, 255, 255], metallicFactor=0.0, roughnessFactor=1.0)
    m.visual = trimesh.visual.TextureVisuals(uv=uv * UV_SCALE, material=mat)


# ---------------------------------------------------------------- камни
def rock(seed, sub=2, scale=(1.3, 0.85, 1.0), amp=0.22, flat_bottom=-0.25, facet=0.0):
    """Валун: икосфера + шум, низ срезан (стоит на земле), опционально «огранка» плоскостями."""
    s = trimesh.creation.icosphere(subdivisions=sub, radius=1.0)
    v = s.vertices.copy()
    n = Noise(seed, octaves=4, freq=1.4)
    r = 1.0 + amp * n(v * 1.3)
    v = v * r[:, None]
    if facet > 0:  # срезы случайными плоскостями — крупные грани как у стилизованных скал
        rg = np.random.default_rng(seed + 99)
        for _ in range(9):
            d = rg.normal(size=3)
            d[1] = abs(d[1]) * 0.6
            d /= np.linalg.norm(d)
            lim = rg.uniform(0.78, 0.95) * (1 + amp * 0.5)
            t = v @ d
            over = t > lim
            v[over] -= np.outer((t[over] - lim) * facet, d)
    v *= np.array(scale)
    v[:, 1] = np.maximum(v[:, 1], flat_bottom * scale[1])
    v[:, 1] -= v[:, 1].min()
    return mesh_of(v, s.faces)


def crag(seed):
    """Утёс/скала-стена: вытянутая вверх икосфера, слоистые уступы (террасы радиуса по высоте)."""
    s = trimesh.creation.icosphere(subdivisions=3, radius=1.0)
    v = s.vertices.copy()
    n = Noise(seed, octaves=5, freq=1.2)
    y = v[:, 1]
    strata = 0.07 * np.round(np.sin(y * 9.0 + n(v * 0.7) * 2.0) * 1.5) / 1.5  # ступени слоёв
    r = 1.0 + 0.25 * n(v * 1.1) + strata
    v = v * r[:, None]
    taper = 1.0 - 0.35 * np.clip((y + 1) / 2, 0, 1) ** 1.5  # к верху уже
    v[:, 0] *= taper
    v[:, 2] *= taper
    v *= np.array([1.0, 2.1, 0.75])
    v[:, 1] = np.maximum(v[:, 1], -1.4)
    v[:, 1] -= v[:, 1].min()
    return mesh_of(v, s.faces)


# ---------------------------------------------------------------- ёлка с ярусами
PINE_TIERS = [  # (низ яруса, верх яруса, радиус юбки)
    (0.18, 0.52, 0.50),
    (0.38, 0.72, 0.40),
    (0.57, 0.88, 0.30),
    (0.74, 1.00, 0.19),
]
PINE_SEG = 14


def pine_tier(y0, y1, r, k, snow=False):
    """Ярус: конус с волнистой «лапчатой» юбкой (кончики веток опущены) и вогнутым низом."""
    rows = 5
    lobes = 7 + k

    def fn(i, j):
        a = 2 * math.pi * j / PINE_SEG + k * 0.45
        t = i / (rows - 1)  # 0 — верх, 1 — юбка
        if snow:
            t *= 0.62  # снег только на верхней части яруса
        wave = 1 + 0.16 * math.cos(lobes * a) * t ** 2
        rad = r * (t ** 0.85) * wave
        y = y1 - (y1 - y0) * t - 0.05 * t ** 3 * (1 + math.cos(lobes * a)) * (y1 - y0)
        if snow:
            rad = rad * 1.06 + 0.012
            y += 0.02 + (0.03 * math.sin(lobes * a + 1.0) * t if i == rows - 1 else 0)  # капли по краю
        return (rad * math.cos(a), y, rad * math.sin(a))

    v, f = grid_surface(rows, PINE_SEG, fn)
    v[:PINE_SEG] = [0, v[0][1], 0]  # верх в точку
    ring = (rows - 1) * PINE_SEG
    inner = y0 + (y1 - y0) * (0.18 if not snow else 0.40)  # вогнутый низ (или низ снежной шапки)
    v, f = cap(v, f, ring, PINE_SEG, [0, inner, 0], up=False)
    return mesh_of(v, f)


def pine_foliage():
    return combine([pine_tier(y0, y1, r, k) for k, (y0, y1, r) in enumerate(PINE_TIERS)])


def pine_snow():
    return combine([pine_tier(y0, y1, r, k, snow=True) for k, (y0, y1, r) in enumerate(PINE_TIERS)])


# ---------------------------------------------------------------- сугроб
def snowdrift(seed):
    """Сугроб-«подушка»: гладкий купол-эллипс с ветровым гребнем (один склон круче, карниз)."""
    rows, cols = 10, 28
    n = Noise(seed, octaves=3, freq=1.6)

    def fn(i, j):
        a = 2 * math.pi * j / cols
        t = i / (rows - 1)  # 0 — вершина, 1 — край
        ca, sa = math.cos(a), math.sin(a)
        edge = 1 + 0.12 * n(np.array([[ca * 2, 0, sa * 2]]))[0]
        x, z = ca * t * 1.6 * edge, sa * t * 0.8 * edge
        h = (1 - t ** 2) ** 0.75
        h *= 1 + 0.3 * max(0.0, -ca) * (1 - t) * min(1.0, t * 3)  # подветренная сторона выше
        h += 0.06 * n(np.array([[x, 0, z]]))[0] * (1 - t)
        return (x - 0.15, 0.55 * h, z)

    v, f = grid_surface(rows, cols, fn)
    v[:cols] = v[:cols].mean(axis=0)
    ring = (rows - 1) * cols
    v[ring:ring + cols, 1] = -0.05
    v, f = cap(v, f, ring, cols, [-0.15, -0.05, 0], up=False)
    return mesh_of(v, f)


# ---------------------------------------------------------------- лёд
def hex_crystal(h, r, tip, lean, yaw, pos):
    """Шестигранная призма с острой верхушкой."""
    seg = 6
    pts = []
    for y, rad in ((0.0, r), (h, r * 0.92)):
        for j in range(seg):
            a = 2 * math.pi * j / seg
            pts.append((rad * math.cos(a), y, rad * math.sin(a)))
    pts.append((0, h + tip, 0))
    pts.append((0, 0, 0))
    v = np.array(pts)
    f = []
    for j in range(seg):
        a, b = j, (j + 1) % seg
        f += [[a, b + seg, b], [a, a + seg, b + seg]]
        f.append([a + seg, 12, b + seg])
        f.append([a, b, 13])
    rot = trimesh.transformations.euler_matrix(lean[0], yaw, lean[1], "sxyz")[:3, :3]
    v = v @ rot.T + np.array(pos)
    return mesh_of(v, np.array(f))


def ice_crystal(seed):
    rg = np.random.default_rng(seed)
    parts = [hex_crystal(1.0, 0.22, 0.32, (0, 0), 0.3, (0, -0.02, 0))]
    for k in range(6):
        a = 2 * math.pi * k / 6 + rg.uniform(-0.3, 0.3)
        d = rg.uniform(0.22, 0.42)
        h = rg.uniform(0.35, 0.72)
        lean = rg.uniform(0.25, 0.55)
        parts.append(hex_crystal(h, rg.uniform(0.11, 0.17), h * 0.35,
                                 (math.sin(a) * lean, -math.cos(a) * lean), rg.uniform(0, 1),
                                 (math.cos(a) * d, -0.04, math.sin(a) * d)))
    m = combine(parts)
    v = m.vertices.copy()
    v[:, 1] = np.maximum(v[:, 1], 0)
    return mesh_of(v, m.faces)


def ice_chunk(seed):
    return rock(seed, sub=1, scale=(1.15, 1.0, 1.0), amp=0.28, flat_bottom=-0.55, facet=0.6)


# ---------------------------------------------------------------- островок
ISLE_SEG = 22


def isle_rock(seed):
    """Низ парящего островка: перевёрнутый скальный конус с уступами."""
    rows = 9
    n = Noise(seed, octaves=4, freq=1.3)

    def fn(i, j):
        a = 2 * math.pi * j / ISLE_SEG
        t = i / (rows - 1)  # 0 — верх (y=0), 1 — низ
        p = np.array([[math.cos(a) * 1.5, t * 2, math.sin(a) * 1.5]])
        rad = (1.0 - t ** 1.3) * (1 + 0.2 * n(p)[0]) + 0.05
        rad *= 1 + 0.06 * math.copysign(1, math.sin(t * 14)) * t  # уступы слоёв
        return (rad * math.cos(a), -1.7 * t + 0.08 * n(p * 0.7)[0] * t, rad * math.sin(a))

    v, f = grid_surface(rows, ISLE_SEG, fn)
    v[-ISLE_SEG:] = [0.08, -1.85, -0.05]
    v, f = cap(v, f, 0, ISLE_SEG, [0, 0.02, 0], up=True)
    parts = [mesh_of(v, f)]
    # висячие скалы-«сосульки» под краем — силуэт не конус, а рваный камень
    for k, (a, d, ln) in enumerate([(0.6, 0.62, 0.95), (2.4, 0.58, 0.7), (4.1, 0.66, 1.15), (5.3, 0.45, 0.55)]):
        tip = trimesh.creation.cone(radius=0.24 + 0.04 * k % 3, height=ln, sections=6)
        tip.apply_transform(trimesh.transformations.rotation_matrix(math.pi / 2, [1, 0, 0]))  # остриём вниз
        tip.apply_translation([math.cos(a) * d, -0.15, math.sin(a) * d])
        parts.append(tip)
    return combine(parts)


def isle_cap(seed):
    """Верх островка: плавная снежная «подушка» с нависающей кромкой и каплями по краю."""
    rows = 8
    n = Noise(seed, octaves=3, freq=1.8)

    def fn(i, j):
        a = 2 * math.pi * j / ISLE_SEG
        t = i / (rows - 1)
        ca, sa = math.cos(a), math.sin(a)
        rad = 1.1 * math.sin(t * math.pi / 2) * (1 + 0.06 * n(np.array([[ca, 0, sa]]))[0])
        px, pz = ca * rad, sa * rad
        hill = 0.28 * math.exp(-((px + 0.35) ** 2 + (pz - 0.2) ** 2) * 3.0)  # холмик (под ёлку)
        y = 0.22 * math.cos(t * math.pi / 2) ** 0.6 + hill * (1 - t) ** 0.3 + 0.05 * n(np.array([[px, 1, pz]]))[0]
        if i == rows - 1:  # кромка свисает каплями
            y = -0.06 - 0.07 * max(0.0, math.sin(5 * a + 0.7))
        return (rad * ca, y, rad * sa)

    v, f = grid_surface(rows, ISLE_SEG, fn)
    v[:ISLE_SEG] = [0, v[:ISLE_SEG, 1].max(), 0]
    v, f = cap(v, f, (rows - 1) * ISLE_SEG, ISLE_SEG, [0, -0.02, 0], up=False)
    return mesh_of(v, f)


# ---------------------------------------------------------------- арка
def arch(seed):
    """Природная арка: сечение-эллипс протянуто по дуге, у основания толще, с шумом.
    Кадр: ноги в x = ±1, верх свода ≈ y 1, глубина z ±0.25."""
    steps, seg = 26, 10
    n = Noise(seed, octaves=4, freq=2.2)

    def center(t):
        a = math.pi * t
        return np.array([-math.cos(a), math.sin(a) ** 0.85 * 0.92, 0.0]), a

    def fn(i, j):
        t = i / (steps - 1)
        c, a = center(t)
        tangent = np.array([math.sin(a), math.cos(a) * 0.92, 0.0])
        tangent /= np.linalg.norm(tangent)
        normal = np.array([-tangent[1], tangent[0], 0.0])
        thick = 0.12 + 0.2 * (abs(t - 0.5) * 2) ** 3  # у ног толще
        b = 2 * math.pi * j / seg
        off = normal * math.cos(b) * thick + np.array([0, 0, 1.0]) * math.sin(b) * (thick * 1.6 + 0.06)
        p = c + off
        p = p + off * 0.35 * n(p[None, :] * 1.5)[0]
        return tuple(p)

    v, f = grid_surface(steps, seg, fn)
    v, f = cap(v, f, 0, seg, v[:seg].mean(axis=0), up=False)
    last = (steps - 1) * seg
    v, f = cap(v, f, last, seg, v[last:last + seg].mean(axis=0), up=True)
    v[:, 1] = np.maximum(v[:, 1], 0)
    v[:, 1] -= v[:, 1].min()
    return mesh_of(v, f)


def tunnel_vault(seed):
    """Кольцо свода тоннеля (#65): полуэллипс от ног x = ±1 (y 0) до верха y = 1, глубина z ±0.5.
    Кольца ставятся вплотную вдоль куска поворота (z растягивается на длину куска), поэтому сечение
    почти прямоугольное (стыки без щелей), а шум — только по радиусу: внутренняя сторона неровная,
    как стена ледяной пещеры. С внутренней стороны свисают сосульки (эллиптические конусы:
    по z толще — при растяжке кольца вдоль трассы они остаются круглыми)."""
    rg = np.random.default_rng(seed)
    steps, sec = 30, 12
    n = Noise(seed, octaves=4, freq=3.0)

    def arc(t):
        a = math.pi * t
        return np.array([-math.cos(a), math.sin(a), 0.0]), a

    def fn(i, j):
        t = i / (steps - 1)
        c, a = arc(t)
        tangent = np.array([math.sin(a), math.cos(a), 0.0])
        tangent /= np.linalg.norm(tangent)
        normal = np.array([-tangent[1], tangent[0], 0.0])  # наружу от оси тоннеля
        thick = 0.075 + 0.05 * (abs(t - 0.5) * 2) ** 2  # у ног толще
        b = 2 * math.pi * j / sec
        # «скруглённый прямоугольник»: по z почти плоско, по радиусу — толщина
        cz, sr = math.cos(b), math.sin(b)
        z = 0.5 * np.sign(sr) * min(1.0, abs(sr) * 1.6)
        rad = cz * thick
        bump = 0.05 * n(np.array([[c[0] * 1.3, c[1] * 1.3, z * 0.6]]))[0]
        if cz < 0:  # внутренняя поверхность — неровная
            rad += bump
        p = c + normal * rad + np.array([0, 0, z])
        return tuple(p)

    v, f = grid_surface(steps, sec, fn)
    v, f = cap(v, f, 0, sec, v[:sec].mean(axis=0), up=False)
    last = (steps - 1) * sec
    v, f = cap(v, f, last, sec, v[last:last + sec].mean(axis=0), up=True)
    parts = [mesh_of(v, f)]
    # сосульки по своду (без ног: там стены жёлоба)
    for _ in range(9):
        t = rg.uniform(0.18, 0.82)
        c, a = arc(t)
        base = c * (1 - 0.06)  # чуть внутрь от средней линии свода — корень в толще
        z = rg.uniform(-0.38, 0.38)
        length = rg.uniform(0.07, 0.16) * (0.6 + 0.4 * math.sin(a))
        rx, rz = rg.uniform(0.018, 0.028), rg.uniform(0.08, 0.13)
        k = 6
        pts = [(base[0] + rx * math.cos(2 * math.pi * j / k), base[1], z + rz * math.sin(2 * math.pi * j / k)) for j in range(k)]
        pts += [(base[0], base[1] - length, z), (base[0], base[1] + 0.01, z)]
        ff = []
        for j in range(k):
            ff.append([j, (j + 1) % k, k])  # бок к острию
            ff.append([(j + 1) % k, j, k + 1])  # крышка-корень
        parts.append(mesh_of(np.array(pts), np.array(ff)))
    m = combine(parts)
    vv = m.vertices.copy()
    vv[:, 1] = np.maximum(vv[:, 1], 0)
    return mesh_of(vv, m.faces)


# ---------------------------------------------------------------- гора
MTN_RINGS, MTN_SEG = 15, 30
MTN_PEAKS = [((0.10, -0.08), 1.25, 0.8), ((-0.45, 0.25), 0.8, 0.5), ((0.42, 0.38), 0.6, 0.42)]


def mountain_field(seed):
    """Высота горы над диском радиуса 1: мягкий максимум трёх вершин + острые хребты + шум."""
    n = Noise(seed, octaves=5, freq=1.3)

    def h(x, z):
        best = 0.0
        for (px, pz), height, reach in MTN_PEAKS:
            d = math.hypot(x - px, z - pz) / reach
            ang = math.atan2(z - pz, x - px)
            ridge = 1 + 0.22 * abs(math.sin(ang * 2.5 + px * 7)) ** 2  # хребты расходятся от вершины
            v = height * max(0.0, 1 - d / ridge) ** 1.15
            best = max(best, v) + 0.12 * min(best, v)  # мягкий максимум — сёдла между вершинами
        rim = max(0.0, 1 - math.hypot(x, z)) ** 0.35  # к краю диска — в ноль
        return max(0.0, (best + 0.07 * n(np.array([[x * 2.2, 0, z * 2.2]]))[0] * best) * rim)

    return h


def mountain_grid(seed, lift=0.0):
    h = mountain_field(seed)

    def fn(i, j):
        a = 2 * math.pi * j / MTN_SEG
        t = i / (MTN_RINGS - 1)
        x, z = math.cos(a) * t, math.sin(a) * t
        return (x, h(x, z) + lift, z)

    v, f = grid_surface(MTN_RINGS, MTN_SEG, fn)
    v[:MTN_SEG] = v[:MTN_SEG].mean(axis=0)
    return v, f, h


def mountain_rock(seed):
    v, f, _ = mountain_grid(seed)
    ring = (MTN_RINGS - 1) * MTN_SEG
    v[ring:ring + MTN_SEG, 1] = 0
    v, f = cap(v, f, ring, MTN_SEG, [0, 0, 0], up=False)
    return mesh_of(v, f)


def mountain_snow(seed):
    """Снег — те же грани склона выше порога (порог «рвётся» шумом), чуть приподнятые."""
    v, f, _ = mountain_grid(seed, lift=0.02)
    n = Noise(seed + 7, octaves=3, freq=3.0)
    thr = 0.62 + 0.1 * n(v * np.array([1, 0, 1]))
    keep = (v[f, 1] > thr[f]).sum(axis=1) >= 2  # грань со снегом, если ≥ 2 вершины выше порога
    f = f[keep]
    # нижние вершины снежных граней подтягиваем к порогу — край шапки ровнее, без зубцов-«пил»
    return mesh_of(v, f)


# ---------------------------------------------------------------- меза
MESA_LAYERS = [(0.0, 0.34, 1.0), (0.34, 0.6, 0.84), (0.6, 0.82, 0.74), (0.82, 1.0, 0.62)]


def mesa(seed):
    """Столовая гора каньона: вытянутый неровный контур, 4 слоя со своей «изрезанностью»,
    крутые стенки с осыпью у основания слоя, узкие полки, плоская вершина."""
    seg = 30
    shape = Noise(seed, octaves=3, freq=1.2)
    prof = []  # (y, радиус-множитель, номер слоя)
    for k, (y0, y1, r) in enumerate(MESA_LAYERS):
        hgt = y1 - y0
        prof += [(y0, r * 1.06, k), (y0 + hgt * 0.18, r, k), (y0 + hgt * 0.6, r * 0.97, k), (y1 - 0.005, r * 0.95, k)]
    prof.append((1.0, MESA_LAYERS[-1][2] * 0.95, len(MESA_LAYERS) - 1))
    layer_noise = [Noise(seed + 10 + k, octaves=4, freq=2.4) for k in range(len(MESA_LAYERS))]

    def fn(i, j):
        a = 2 * math.pi * j / seg
        y, rad, k = prof[i]
        ca, sa = math.cos(a), math.sin(a)
        big = 1 + 0.14 * shape(np.array([[ca, 0, sa]]))[0]
        cut = 1 + 0.09 * layer_noise[k](np.array([[ca * 1.5, y * 3, sa * 1.5]]))[0]  # овраги стенок
        rr = rad * big * cut
        return (rr * ca * 1.3, y, rr * sa)

    rows = len(prof)
    v, f = grid_surface(rows, seg, fn)
    v, f = cap(v, f, (rows - 1) * seg, seg, [0, 1.0, 0], up=True)
    v, f = cap(v, f, 0, seg, [0, 0, 0], up=False)
    return mesh_of(v, f)


# ---------------------------------------------------------------- лобби (#этап 3): фонарь, подиум, табло, ворота
# Эти меши в настоящих studs (масштаб 1 = размер в лобби), граница — кадр объекта как у остальных.
def frustum(r0, r1, y0, y1, sec, rot=0.0, ox=0.0, oz=0.0):
    """Усечённый конус/призма (sec граней) с крышками; rot — поворот сечения (рад)."""
    def fn(i, j):
        a = 2 * math.pi * j / sec + rot
        r = r0 if i == 0 else r1
        return (ox + r * math.cos(a), y0 if i == 0 else y1, oz + r * math.sin(a))

    v, f = grid_surface(2, sec, fn)
    v, f = cap(v, f, sec, sec, [ox, y1, oz], up=True)
    v, f = cap(v, f, 0, sec, [ox, y0, oz], up=False)
    return mesh_of(v, f)


def box(sx, sy, sz, cx, y0, cz):
    b = trimesh.creation.box(extents=[sx, sy, sz])
    b.apply_translation([cx, y0 + sy / 2, cz])
    return b


def sweep(points, half_h, half_d):
    """Брус прямоугольного сечения вдоль ломаной в плоскости XY (points: [(x, y)]), с торцами."""
    pts = [np.array(p, dtype=float) for p in points]
    n = len(pts)

    def fn(i, j):
        p = pts[i]
        d = pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]
        d /= np.linalg.norm(d)
        nrm = np.array([-d[1], d[0]])  # нормаль в плоскости XY
        su, sd = [(1, 1), (1, -1), (-1, -1), (-1, 1)][j]
        q = p + nrm * half_h * su
        return (q[0], q[1], half_d * sd)

    v, f = grid_surface(n, 4, fn)
    v, f = cap(v, f, 0, 4, v[:4].mean(axis=0), up=False)
    last = (n - 1) * 4
    v, f = cap(v, f, last, 4, v[last:last + 4].mean(axis=0), up=True)
    return mesh_of(v, f)


def lamp_post():
    """Фонарь лобби ~10 studs: тумба, восьмигранный столб, воротник, клетка плафона, крыша-пирамида,
    шарик. Стекло/свет — отдельная неоновая деталь внутри клетки (y 7.5–8.9, Props.lampPost)."""
    parts = [
        box(1.4, 0.5, 1.4, 0, 0, 0),
        box(1.0, 0.35, 1.0, 0, 0.5, 0),
        frustum(0.3, 0.2, 0.85, 7.2, 8, rot=math.pi / 8),
        frustum(0.42, 0.42, 7.2, 7.45, 8, rot=math.pi / 8),
        box(1.35, 0.14, 1.35, 0, 7.45, 0),
    ]
    for sx in (-1, 1):
        for sz in (-1, 1):
            parts.append(box(0.14, 1.45, 0.14, sx * 0.6, 7.55, sz * 0.6))
    parts += [
        box(1.5, 0.16, 1.5, 0, 9.0, 0),
        frustum(1.05, 0.1, 9.16, 9.9, 4, rot=math.pi / 4),
        trimesh.creation.icosphere(subdivisions=1, radius=0.17).apply_translation([0, 10.05, 0]),
    ]
    return combine(parts)


def podium():
    """Подиум витрины: три круглых яруса с фасками (радиус 1, высота 0.62), 28 граней."""
    sec = 28
    tiers = [(1.0, 0.97, 0.0, 0.18), (0.97, 0.91, 0.18, 0.22), (0.86, 0.86, 0.22, 0.42), (0.86, 0.8, 0.42, 0.46),
             (0.76, 0.76, 0.46, 0.58), (0.76, 0.71, 0.58, 0.62)]
    return combine([frustum(r0, r1, y0, y1, sec) for r0, r1, y0, y1 in tiers])


def board_frame():
    """Рама табло 21.6 × 18.6: столбы с пиками, верхняя и нижняя перекладины, двускатная крыша.
    Само табло (SurfaceGui) — плита Part 18 × 10 в проёме y 6–16 (Lobby.board)."""
    parts = []
    for sx in (-1, 1):
        parts += [
            box(2.2, 0.6, 2.2, sx * 9.6, 0, 0),
            box(1.2, 17.0, 1.2, sx * 9.6, 0.6, 0),
            frustum(1.0, 0.05, 17.6, 18.6, 4, rot=math.pi / 4, ox=sx * 9.6),
        ]
    parts += [box(20.4, 1.0, 1.1, 0, 16.0, 0), box(20.4, 0.8, 1.1, 0, 5.2, 0)]
    # двускатная крыша над табло: треугольная призма
    w, y0, y1, d = 10.8, 17.0, 18.4, 1.3
    v = np.array([[-w, y0, -d], [w, y0, -d], [0, y1, -d], [-w, y0, d], [w, y0, d], [0, y1, d]], dtype=float)
    f = np.array([[0, 2, 1], [3, 4, 5], [0, 1, 4], [0, 4, 3], [1, 2, 5], [1, 5, 4], [2, 0, 3], [2, 3, 5]])
    parts.append(mesh_of(v, f))
    return combine(parts)


def start_gate():
    """Ворота старта у входа на мостик: две квадратные колонны с базой и капителью (x ±9.5),
    прямая перемычка y 9.6–10.4 (под ней висит вывеска мира) и выгнутая балка над ней до y 13.4."""
    parts = []
    for sx in (-1, 1):
        x = sx * 9.5
        parts += [
            box(2.8, 1.2, 2.8, x, 0, 0),
            frustum(1.32, 1.08, 1.2, 10.4, 4, rot=math.pi / 4, ox=x),
            box(2.6, 0.7, 2.6, x, 10.4, 0),
            frustum(0.9, 0.12, 11.1, 12.3, 4, rot=math.pi / 4, ox=x),
        ]
    parts.append(box(17.0, 0.8, 1.3, 0, 9.6, 0))
    arc = [(-10.6 + 21.2 * t, 11.2 + 1.9 * math.sin(math.pi * t)) for t in np.linspace(0, 1, 13)]
    parts.append(sweep(arc, 0.55, 0.8))
    return combine(parts)

# ---------------------------------------------------------------- список
# имя → (функция, flat-shading, подпись)
MESHES = {
    "rock_a": (lambda: rock(11, facet=0.5), True, "валун"),
    "rock_b": (lambda: rock(23, scale=(1.0, 1.1, 0.9), amp=0.3, facet=0.7), True, "камень-глыба"),
    "crag": (lambda: crag(5), True, "утёс / скала-стена"),
    "pine_foliage": (pine_foliage, True, "ёлка: хвоя (4 яруса)"),
    "pine_snow": (pine_snow, False, "ёлка: снег на ярусах"),
    "snowdrift": (lambda: snowdrift(3), False, "сугроб"),
    "ice_crystal": (lambda: ice_crystal(8), True, "друза ледяных кристаллов"),
    "ice_chunk": (lambda: ice_chunk(17), True, "ледяная глыба"),
    "isle_rock": (lambda: isle_rock(4), True, "островок: скальный низ"),
    "isle_cap": (lambda: isle_cap(4), False, "островок: снежный верх"),
    "arch": (lambda: arch(9), True, "природная арка"),
    "tunnel_vault": (lambda: tunnel_vault(13), True, "тоннель: кольцо свода с сосульками"),
    "mountain_rock": (lambda: mountain_rock(21), True, "гора: склоны"),
    "mountain_snow": (lambda: mountain_snow(21), False, "гора: снежная шапка"),
    "mesa": (lambda: mesa(31), True, "меза каньона"),
    "lamp_post": (lamp_post, True, "лобби: фонарь на столбе"),
    "podium": (podium, True, "лобби: подиум витрины саней"),
    "board_frame": (board_frame, True, "лобби: рама табло с крышей"),
    "start_gate": (start_gate, True, "лобби: ворота старта"),
}


def build_all():
    out = {}
    for name, (fn, flat, title) in MESHES.items():
        m = finish(fn(), flat)
        assert len(m.faces) <= TRI_LIMIT, f"{name}: {len(m.faces)} треугольников > {TRI_LIMIT}"
        out[name] = (m, title)
    # меши транспорта (сани, обвес, ракеты): уже с нормалями (гладкие с жёсткими рёбрами) — только UV
    from gen_kit_meshes import all_meshes  # noqa: E402  (scripts/ в sys.path — рядом с этим файлом)
    for name, (m, title) in all_meshes().items():
        assert len(m.faces) <= TRI_LIMIT, f"{name}: {len(m.faces)} треугольников > {TRI_LIMIT}"
        add_uv(m)
        out[name] = (m, title)
    return out


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    specs = {}
    for name, (m, title) in build_all().items():
        lo, hi = m.bounds
        size = hi - lo
        center = (hi + lo) / 2
        # нормали явно: у плоских граней — нормаль грани (low-poly), у снега — сглаженные
        (OUT / f"{name}.glb").write_bytes(trimesh.exchange.gltf.export_glb(trimesh.Scene(m), include_normals=True))
        specs[name] = {
            "title": title,
            "tris": int(len(m.faces)),
            "size": [round(float(x), 4) for x in size],
            "offset": [round(float(x), 4) for x in center],
        }
        print(f"{name:14s} {len(m.faces):5d} треуг.  size {np.round(size, 3)}  offset {np.round(center, 3)}  — {title}")
    (OUT / "specs.json").write_text(json.dumps(specs, indent=1, ensure_ascii=False, sort_keys=True) + "\n")
    lines = [
        "-- Сгенерировано scripts/gen_meshes.py: габариты мешей в «кадре объекта» (Y вверх, начало —",
        "-- центр основания на земле, 1 = 1 stud при масштабе 1). size — габариты, offset — центр габаритов.",
        "-- MeshPart растягивает меш на Size, поэтому Props/Meshes ставит Size = size·s, CFrame = база·offset·s.",
        "return {",
    ]
    for name in sorted(specs):
        s, o = specs[name]["size"], specs[name]["offset"]
        lines.append(f"\t{name} = {{ size = Vector3.new({s[0]}, {s[1]}, {s[2]}), offset = Vector3.new({o[0]}, {o[1]}, {o[2]}), tris = {specs[name]['tris']} }},")
    lines.append("}")
    SPECS_LUAU.write_text("\n".join(lines) + "\n")
    print(f"Записано: {len(specs)} мешей → {OUT}, {SPECS_LUAU}")


if __name__ == "__main__":
    main()
