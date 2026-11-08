"""Геометрия для мешей транспорта (scripts/gen_sled_meshes.py): лофт сечений, протяжка профиля по
кривой, тела вращения, призмы, профиль крыла. Всё в кадре саней Roblox: X вправо, Y вверх, нос по −Z.
Каждый примитив — замкнутое тело (watertight) с нормалями наружу; открытые поверхности
ориентируются по опорной точке (orient_from)."""
import math

import numpy as np
import trimesh

PI = math.pi


def M(v, f):
    return trimesh.Trimesh(np.asarray(v, float), np.asarray(f, int), process=False)


def _grid(rows, cols, wrap_cols, wrap_rows=False):
    f = []
    jc = cols if wrap_cols else cols - 1
    ir = rows if wrap_rows else rows - 1
    for i in range(ir):
        i2 = (i + 1) % rows
        for j in range(jc):
            j2 = (j + 1) % cols
            a, b, c, d = i * cols + j, i * cols + j2, i2 * cols + j, i2 * cols + j2
            f += [[a, b, d], [a, d, c]]
    return f


def solid(m):
    """Склеить вершины, убрать вырожденные грани, развернуть нормали наружу."""
    m.merge_vertices()
    m.update_faces(m.nondegenerate_faces())
    m.remove_unreferenced_vertices()
    trimesh.repair.fix_normals(m)
    return m


def orient_from(m, ref):
    """Открытая поверхность: грань смотрит от опорной точки ref(центр грани) наружу."""
    c = m.triangles_center
    n = m.face_normals
    r = np.array([ref(p) for p in c])
    bad = np.einsum("ij,ij->i", n, c - r) < 0
    f = m.faces.copy()
    f[bad] = f[bad][:, ::-1]
    return M(m.vertices, f)


def loft(rings, caps=True, closed_ring=True):
    """Поверхность через кольца сечений (одинаковое число точек), с крышками-веерами."""
    rings = [np.asarray(r, float) for r in rings]
    rows, cols = len(rings), len(rings[0])
    v = np.vstack(rings)
    f = _grid(rows, cols, closed_ring)
    if caps:
        v = list(v)
        for idx in (0, rows - 1):
            ring = rings[idx]
            v.append(ring.mean(axis=0))
            ci = len(v) - 1
            s = idx * cols
            for j in range(cols):
                f.append([ci, s + (j + 1) % cols, s + j])
    m = M(v, f)
    return solid(m) if caps and closed_ring else m


# ---------------------------------------------------------------- сечения (2D-кольца)
def superellipse(w, top, bot, n=2.5, nb=None, seg=24):
    """Кольцо в плоскости (x, y): полуширина w, верх top, низ bot (вниз от 0), степень n (2 — эллипс,
    больше — ближе к прямоугольнику); nb — степень низа. Против часовой стрелки с +X."""
    nb = nb or n
    out = []
    for j in range(seg):
        a = 2 * PI * j / seg
        c, s = math.cos(a), math.sin(a)
        x = w * math.copysign(abs(c) ** (2 / (n if s >= 0 else nb)), c)
        y = (top if s >= 0 else bot) * math.copysign(abs(s) ** (2 / (n if s >= 0 else nb)), s)
        out.append((x, y))
    return out


def circle(r, seg=12):
    return [(r * math.cos(2 * PI * j / seg), r * math.sin(2 * PI * j / seg)) for j in range(seg)]


def ellipse(a, b, seg=12):
    return [(a * math.cos(2 * PI * j / seg), b * math.sin(2 * PI * j / seg)) for j in range(seg)]


def rect(a, b):
    return [(a, b), (-a, b), (-a, -b), (a, -b)]


def airfoil(chord, thick, seg=16, lead=0.0):
    """Симметричный профиль NACA 00xx в плоскости (u — вдоль хорды от носка, v — толщина).
    lead — смещение носка по u. Кольцо против часовой."""
    t = thick / chord
    half = seg // 2
    xs = [(1 - math.cos(PI * k / half)) / 2 for k in range(half + 1)]
    yt = [5 * t * (0.2969 * math.sqrt(x) - 0.126 * x - 0.3516 * x ** 2 + 0.2843 * x ** 3 - 0.1036 * x ** 4) for x in xs]
    upper = [(lead + x * chord, y * chord) for x, y in zip(xs, yt)]
    lower = [(lead + x * chord, -y * chord) for x, y in zip(xs[1:-1], yt[1:-1])][::-1]
    ring = upper[::-1] + lower  # от хвоста по верху к носку и обратно по низу
    return ring


def ring3(sec, z=0.0, cx=0.0, cy=0.0):
    """2D-сечение (x, y) → 3D-кольцо в плоскости z."""
    return [(cx + x, cy + y, z) for x, y in sec]


# ---------------------------------------------------------------- протяжка по кривой
def frames(path, up=None, closed=False):
    """Касательные и нормали вдоль ломаной: up — вектор (или функция точки) «верха» сечения,
    иначе параллельный перенос."""
    p = np.asarray(path, float)
    n = len(p)
    T = np.zeros_like(p)
    for i in range(n):
        a = p[(i - 1) % n] if (closed or i > 0) else p[i]
        b = p[(i + 1) % n] if (closed or i < n - 1) else p[i]
        d = b - a
        T[i] = d / (np.linalg.norm(d) + 1e-12)
    N = np.zeros_like(p)
    if up is not None:
        for i in range(n):
            u = np.asarray(up(p[i]) if callable(up) else up, float)
            u = u - np.dot(u, T[i]) * T[i]
            N[i] = u / (np.linalg.norm(u) + 1e-12)
    else:
        ref = np.array([0, 1, 0.0]) if abs(T[0][1]) < 0.9 else np.array([1, 0, 0.0])
        N[0] = ref - np.dot(ref, T[0]) * T[0]
        N[0] /= np.linalg.norm(N[0])
        for i in range(1, n):
            v = N[i - 1] - np.dot(N[i - 1], T[i]) * T[i]
            N[i] = v / (np.linalg.norm(v) + 1e-12)
    Bn = np.cross(T, N)
    return p, T, N, Bn


def sweep(path, prof, up=None, closed=False, scale=None, caps=True):
    """Профиль prof (кольцо (u, v): u — по нормали N, v — по бинормали B) вдоль пути.
    scale — множитель профиля в каждой точке (число, (su, sv) или список)."""
    p, T, N, Bn = frames(path, up, closed)
    rings = []
    for i in range(len(p)):
        s = scale[i] if isinstance(scale, (list, tuple, np.ndarray)) else (scale or 1.0)
        su, sv = (s, s) if np.isscalar(s) else s
        rings.append([p[i] + N[i] * u * su + Bn[i] * v * sv for u, v in prof])
    if closed:
        rows, cols = len(rings), len(prof)
        m = M(np.vstack(rings), _grid(rows, cols, True, wrap_rows=True))
        return solid(m)
    return loft(rings, caps=caps)


def tube(path, r, seg=10, closed=False, up=None, scale=None):
    return sweep(path, circle(r, seg), up=up, closed=closed, scale=scale)


def arc(center, r, a0, a1, n, plane="xz", y=0.0):
    """Точки дуги: plane xz — вокруг Y (y фиксирован), yz — в плоскости YZ (x = center[0])."""
    out = []
    for k in range(n):
        a = a0 + (a1 - a0) * k / (n - 1)
        if plane == "xz":
            out.append((center[0] + r * math.cos(a), y, center[2] + r * math.sin(a)))
        else:
            out.append((center[0], center[1] + r * math.cos(a), center[2] + r * math.sin(a)))
    return out


def ring_path(R, y=0.0, n=32, cz=0.0, rz=None):
    rz = rz or R
    return [(R * math.cos(2 * PI * k / n), y, cz + rz * math.sin(2 * PI * k / n)) for k in range(n)]


# ---------------------------------------------------------------- простые тела
def revolve(profile, seg=32, y_axis=True):
    """Тело вращения вокруг Y: profile — [(r, y)] от оси снизу до оси сверху (замкнутый контур)."""
    rings = []
    for r, y in profile:
        rings.append([(r * math.cos(2 * PI * j / seg), y, r * math.sin(2 * PI * j / seg)) for j in range(seg)])
    m = loft(rings, caps=True)
    return m


def box(sx, sy, sz, c=(0, 0, 0)):
    b = trimesh.creation.box(extents=[sx, sy, sz])
    b.apply_translation(c)
    return b


def rbox(sx, sy, sz, c=(0, 0, 0), n=5, seg=20, rows=6):
    """Скруглённый брусок: лофт сверхэллипсов вдоль Z с закруглёнными торцами."""
    rings = []
    for k in range(rows + 1):
        t = -1 + 2 * k / rows
        e = (1 - abs(t) ** n) ** (1 / n)
        rings.append(ring3(superellipse(sx / 2 * (0.6 + 0.4 * e), sy / 2 * (0.7 + 0.3 * e), sy / 2 * (0.7 + 0.3 * e), n=n, seg=seg),
                           z=c[2] + t * sz / 2, cx=c[0], cy=c[1]))
    return loft(rings)


def cyl(r, h, c=(0, 0, 0), axis="y", seg=16, r2=None):
    """Цилиндр (или усечённый конус до r2) вдоль оси с центром c."""
    r2 = r if r2 is None else r2
    prof = [(0, -h / 2), (r, -h / 2), (r2, h / 2), (0, h / 2)]
    m = revolve(prof, seg)
    return place(m, c, axis)


def ball(r, c=(0, 0, 0), sub=2, scale=(1, 1, 1)):
    s = trimesh.creation.icosphere(subdivisions=sub, radius=r)
    s.apply_scale(scale)
    s.apply_translation(c)
    return s


def place(m, c=(0, 0, 0), axis="y", rot=None):
    """Ось Y примитива → axis (x/y/z), затем поворот rot (матрица 3×3) и перенос в c."""
    m = m.copy()
    if axis == "x":
        m.apply_transform(trimesh.transformations.rotation_matrix(-PI / 2, [0, 0, 1]))
    elif axis == "z":
        m.apply_transform(trimesh.transformations.rotation_matrix(PI / 2, [1, 0, 0]))
    if rot is not None:
        T = np.eye(4)
        T[:3, :3] = rot
        m.apply_transform(T)
    m.apply_translation(c)
    return m


def rot(ax, ay, az):
    """Матрица поворота как CFrame.Angles(ax, ay, az) в Roblox (X, затем Y, затем Z, внутренние)."""
    def Rx(t):
        c, s = math.cos(t), math.sin(t)
        return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])

    def Ry(t):
        c, s = math.cos(t), math.sin(t)
        return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])

    def Rz(t):
        c, s = math.cos(t), math.sin(t)
        return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])

    return Rx(ax) @ Ry(ay) @ Rz(az)


def xform(m, R=None, t=(0, 0, 0)):
    m = m.copy()
    T = np.eye(4)
    if R is not None:
        T[:3, :3] = R
    T[:3, 3] = t
    m.apply_transform(T)
    return m


def prism(poly, thick, to3d):
    """Призма из выпуклого многоугольника poly [(a, b)] толщиной thick; to3d(a, b, w) → (x, y, z)."""
    n = len(poly)
    v = [to3d(a, b, -thick / 2) for a, b in poly] + [to3d(a, b, thick / 2) for a, b in poly]
    f = []
    for k in range(1, n - 1):
        f.append([0, k + 1, k])
        f.append([n, n + k, n + k + 1])
    for k in range(n):
        k2 = (k + 1) % n
        f += [[k, k2, n + k2], [k, n + k2, n + k]]
    return solid(M(v, f))


def mirror_x(m):
    mm = m.copy()
    mm.vertices = mm.vertices * np.array([-1, 1, 1])
    mm.faces = mm.faces[:, ::-1]
    return mm


def both(m):
    """Деталь и её зеркальная копия по X."""
    return [m, mirror_x(m)]


def join(parts):
    flat = []
    for p in parts:
        if isinstance(p, (list, tuple)):
            flat += list(p)
        else:
            flat.append(p)
    return trimesh.util.concatenate(flat)


def shade(m, angle_deg=38):
    """Гладкие нормали с жёсткими рёбрами острее angle_deg (кромки, торцы — чёткие)."""
    m = m.copy()
    m.update_faces(m.nondegenerate_faces())
    m.remove_unreferenced_vertices()
    s = trimesh.graph.smooth_shade(m, angle=math.radians(angle_deg), facet_minarea=None)
    return trimesh.Trimesh(s.vertices, s.faces, process=False)
