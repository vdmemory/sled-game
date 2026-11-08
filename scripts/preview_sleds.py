#!/usr/bin/env python3
"""Превью транспорта в PNG: собирает модели настоящим кодом SledModels (стенд luau, scripts/stand),
ставит MeshPart из assets/meshes/*.glb и Part-примитивы и рисует программным z-буфером.

  python3 scripts/preview_sleds.py [out_dir] [--parts]

out_dir (по умолчанию assets/meshes): sleds_preview.png — 9 моделей, колонки: тир 0 (3/4 спереди),
тир 10 + ракета 6 (3/4 спереди), тир 10 с камеры заезда (сзади-сверху, с манекеном персонажа),
Gold-редкость; rockets_preview.png — ракеты тиров 0/3/6. --parts — без мешей (Part-фолбэк).
Нужны numpy, trimesh, Pillow и luau CLI (scripts/check.sh --install).
"""
import math
import pathlib
import subprocess
import sys

import numpy as np
import trimesh
from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
MESH_DIR = ROOT / "assets" / "meshes"

# ---------------------------------------------------------------- сцены из стенда
def load_scenes(meshes=True):
    cmd = [sys.executable, str(ROOT / "scripts" / "stand" / "run.py"), str(ROOT / "scripts" / "stand" / "sled_dump.luau")]
    if meshes:
        cmd.append("--meshes")
    out = subprocess.run(cmd, capture_output=True, text=True)
    if out.returncode != 0:
        sys.exit(out.stderr or out.stdout)
    scenes = {}
    for line in out.stdout.splitlines():
        if line.startswith("B|"):  # луч фар (Beam): концы и ширины
            _, scene, a, b, w0, w1 = line.split("|")
            scenes.setdefault(scene, []).append({
                "cls": "Beam", "p0": np.array([float(x) for x in a.split(",")]), "p1": np.array([float(x) for x in b.split(",")]),
                "w0": float(w0), "w1": float(w1), "color": np.array([1.0, 0.96, 0.78]), "mat": "Neon", "tr": 0.6,
            })
            continue
        if not line.startswith("D|"):
            continue
        _, scene, cls, shape, name, size, cf, col, mat, tr, sm = line.split("|")
        cfv = [float(x) for x in cf.split(",")]
        scenes.setdefault(scene, []).append({
            "cls": cls, "shape": shape.split(".")[-1], "name": name,
            "size": np.array([float(x) for x in size.split(",")]),
            "pos": np.array(cfv[:3]), "R": np.array(cfv[3:12]).reshape(3, 3).T,
            "color": np.array([float(x) for x in col.split(",")]), "mat": mat.split(".")[-1],
            "tr": float(tr), "sm": sm.split(".")[-1],
        })
    return scenes


# ---------------------------------------------------------------- геометрия деталей
_glb = {}


def glb(name):
    if name not in _glb:
        m = trimesh.load(MESH_DIR / f"{name}.glb", force="mesh")
        lo, hi = m.bounds
        ext = np.maximum(hi - lo, 1e-6)
        _glb[name] = (m.vertices - (lo + hi) / 2) / ext, m.faces, m.vertex_normals * ext
    return _glb[name]


_prim = {}


def prim(kind):
    if kind not in _prim:
        if kind == "Block":
            m = trimesh.creation.box(extents=[1, 1, 1])
        elif kind in ("Ball", "Sphere"):
            m = trimesh.creation.icosphere(subdivisions=2, radius=0.5)
        elif kind == "Cylinder":
            m = trimesh.creation.cylinder(radius=0.5, height=1, sections=20)
            m.apply_transform(trimesh.transformations.rotation_matrix(math.pi / 2, [0, 1, 0]))
        elif kind == "Wedge":
            v = np.array([[-.5, -.5, -.5], [.5, -.5, -.5], [-.5, -.5, .5], [.5, -.5, .5], [-.5, .5, .5], [.5, .5, .5]])
            f = np.array([[0, 1, 3], [0, 3, 2], [2, 3, 5], [2, 5, 4], [0, 4, 5], [0, 5, 1], [0, 2, 4], [1, 5, 3]])
            m = trimesh.Trimesh(v, f, process=True)
            trimesh.repair.fix_normals(m)
        m = m.copy()
        if kind != "Ball" and kind != "Sphere":
            m = m.unmerge_vertices() or m
        _prim[kind] = (m.vertices.copy(), m.faces.copy(), m.vertex_normals.copy())
    return _prim[kind]


def part_tris(p):
    """Мировые треугольники детали: (verts (n,3,3), normals (n,3,3))."""
    size = p["size"]
    if p["cls"] == "MeshPart":
        v, f, n = glb(p["name"])
        v = v * size
        n = n / np.maximum(size, 1e-6)
    else:
        kind = p["sm"] if p["sm"] in ("Sphere", "Wedge") else p["shape"]
        if kind == "Ball":
            size = np.full(3, size.min())
        if kind == "Cylinder":
            d = min(size[1], size[2])
            size = np.array([size[0], d, d])
        v, f, n = prim(kind)
        v = v * size
        n = n / np.maximum(size, 1e-6)
    R = p["R"]
    wv = v @ R.T + p["pos"]
    wn = n @ R.T
    wn /= np.linalg.norm(wn, axis=1, keepdims=True) + 1e-9
    return wv[f], wn[f]


def mannequin():
    """Персонаж R6, сидящий на сиденье (верх сиденья y = 0.5)."""
    gray = np.array([0.62, 0.64, 0.7])
    skin = np.array([0.95, 0.8, 0.62])
    out = []

    def blk(sz, pos, col):
        out.append({"cls": "Part", "shape": "Block", "sm": "", "name": "", "size": np.array(sz), "pos": np.array(pos),
                    "R": np.eye(3), "color": col, "mat": "SmoothPlastic", "tr": 0.0})

    blk([2, 2, 1], [0, 1.5 + 1, 0.4], np.array([0.25, 0.45, 0.85]))
    blk([1.2, 1.2, 1.2], [0, 4.1, 0.4], skin)
    for sx in (-1, 1):
        blk([1, 1, 2], [sx * 0.5, 1.0, -0.6], gray)
        blk([1, 2, 1], [sx * 1.5, 2.6, 0.2], skin)
    return out


# ---------------------------------------------------------------- растеризатор
LIGHT = np.array([-0.45, 0.8, -0.4])
LIGHT /= np.linalg.norm(LIGHT)


def render(parts, eye, target, W=420, H=320, fov=38, bg=(214, 228, 242), ss=2):
    w, h = W * ss, H * ss
    fwd = target - eye
    fwd /= np.linalg.norm(fwd)
    right = np.cross(fwd, [0, 1, 0])
    right /= np.linalg.norm(right)
    up = np.cross(right, fwd)
    fl = 0.5 * h / math.tan(math.radians(fov) / 2)
    img = np.zeros((h, w, 3))
    img[:] = np.array(bg) / 255
    zbuf = np.full((h, w), np.inf)
    opaque, trans = [], []
    for p in parts:
        if p["cls"] == "Beam":  # лента, развёрнутая к камере (FaceCamera)
            d = p["p1"] - p["p0"]
            side = np.cross(d, eye - (p["p0"] + p["p1"]) / 2)
            side /= np.linalg.norm(side) + 1e-9
            a0, a1 = p["p0"] - side * p["w0"] / 2, p["p0"] + side * p["w0"] / 2
            b0, b1 = p["p1"] - side * p["w1"] / 2, p["p1"] + side * p["w1"] / 2
            tv = np.array([[a0, a1, b1], [a0, b1, b0]])
            nn = np.cross(d, side)
            trans.append((p, tv, np.array([[nn, nn, nn], [nn, nn, nn]])))
            continue
        tv, tn = part_tris(p)
        (trans if p["tr"] > 0.05 or p["mat"] == "Glass" else opaque).append((p, tv, tn))
    view = eye

    def shade_col(p, n, pos):
        c = p["color"]
        if p["mat"] == "Neon":
            return np.clip(c * 1.15 + 0.08, 0, 1)
        lam = max(0.0, float(np.dot(n, LIGHT)))
        amb = 0.42 + 0.18 * n[1]
        col = c * (amb + 0.62 * lam)
        if p["mat"] in ("Metal", "Foil", "Glass") or p["mat"] == "SmoothPlastic":
            vdir = view - pos
            vdir /= np.linalg.norm(vdir) + 1e-9
            hv = LIGHT + vdir
            hv /= np.linalg.norm(hv)
            k = {"Metal": (0.5, 30), "Foil": (0.7, 40), "Glass": (0.6, 60), "SmoothPlastic": (0.18, 24)}[p["mat"]]
            col = col + k[0] * max(0.0, float(np.dot(n, hv))) ** k[1]
        return np.clip(col, 0, 1)

    def raster(p, tv, tn, blend):
        cam = np.stack([(tv - eye) @ right, (tv - eye) @ up, (tv - eye) @ fwd], axis=-1)
        for tri, nrm, wtri in zip(cam, tn, tv):
            z = tri[:, 2]
            if (z < 0.1).any():
                continue
            sx = w / 2 + fl * tri[:, 0] / z
            sy = h / 2 - fl * tri[:, 1] / z
            x0, x1 = int(max(0, math.floor(sx.min()))), int(min(w - 1, math.ceil(sx.max())))
            y0, y1 = int(max(0, math.floor(sy.min()))), int(min(h - 1, math.ceil(sy.max())))
            if x0 > x1 or y0 > y1:
                continue
            area = (sx[1] - sx[0]) * (sy[2] - sy[0]) - (sx[2] - sx[0]) * (sy[1] - sy[0])
            if abs(area) < 1e-9:
                continue
            gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
            w0 = ((sx[1] - gx) * (sy[2] - gy) - (sx[2] - gx) * (sy[1] - gy)) / area
            w1 = ((sx[2] - gx) * (sy[0] - gy) - (sx[0] - gx) * (sy[2] - gy)) / area
            w2 = 1 - w0 - w1
            inside = (w0 >= -1e-6) & (w1 >= -1e-6) & (w2 >= -1e-6)
            if not inside.any():
                continue
            iz = w0 / z[0] + w1 / z[1] + w2 / z[2]
            depth = 1 / np.maximum(iz, 1e-9)
            sub = zbuf[y0:y1 + 1, x0:x1 + 1]
            m = inside & (depth < sub)
            if not m.any():
                continue
            n = nrm.mean(axis=0)
            n /= np.linalg.norm(n) + 1e-9
            # нормаль к камере (двусторонние ткань/стекло)
            if np.dot(n, eye - wtri.mean(axis=0)) < 0:
                n = -n
            col = shade_col(p, n, wtri.mean(axis=0))
            region = img[y0:y1 + 1, x0:x1 + 1]
            if blend:
                a = 0.45 if p["mat"] == "Glass" else max(0.0, 1 - p["tr"])
                region[m] = region[m] * (1 - a) + col * a
            else:
                region[m] = col
                sub[m] = depth[m]

    for p, tv, tn in opaque:
        raster(p, tv, tn, False)
    for p, tv, tn in trans:
        if p["tr"] < 0.97:
            raster(p, tv, tn, True)
    im = Image.fromarray((img * 255).astype(np.uint8)).resize((W, H), Image.LANCZOS)
    return im


def bbox(parts):
    pts = np.vstack([part_tris(p)[0].reshape(-1, 3) for p in parts if p["cls"] != "Beam"])
    return pts.min(axis=0), pts.max(axis=0)


def view_front(parts, W, H):
    lo, hi = bbox(parts)
    c = (lo + hi) / 2
    r = np.linalg.norm(hi - lo) / 2
    eye = c + np.array([-0.75, 0.55, -1.0]) / np.linalg.norm([-0.75, 0.55, -1.0]) * r * 2.9
    return render(parts, eye, c, W, H)


def view_game(parts, W, H):
    # камера заезда: сзади-сверху, чуть сбоку
    eye = np.array([1.5, 9.5, 17.0])
    return render(parts + mannequin(), eye, np.array([0, 1.2, -1.5]), W, H, fov=42)


def font(sz):
    for p in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf"):
        try:
            return ImageFont.truetype(p, sz)
        except OSError:
            pass
    return ImageFont.load_default()


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    out = pathlib.Path(args[0]) if args else MESH_DIR
    out.mkdir(parents=True, exist_ok=True)
    meshes = "--parts" not in sys.argv
    scenes = load_scenes(meshes)
    sys.path.insert(0, str(ROOT / "scripts"))
    W, H = 360, 270
    suffix = "" if meshes else "_parts"
    ids = [s for s in ["tube", "saucer", "board", "toboggan", "classic", "kayak", "plane", "bobsled", "snowmobile"] if f"{s}:0" in scenes]

    def sheet(rows, cols, path):
        head = 30
        im = Image.new("RGB", (W * len(cols), head + H * len(rows)), (255, 255, 255))
        dr = ImageDraw.Draw(im)
        for j, (title, _) in enumerate(cols):
            dr.text((j * W + 8, 6), title, fill=(30, 30, 40), font=font(16))
        for i, s in enumerate(rows):
            for j, (_, fn) in enumerate(cols):
                im.paste(fn(s), (j * W, head + i * H))
            dr.text((8, head + i * H + 6), s, fill=(20, 20, 30), font=font(18))
            print("готово:", s, flush=True)
        im.save(path)

    sheet(ids, [("тир 0", lambda s: view_front(scenes[f"{s}:0"], W, H)),
                ("тир 10 + ракета 6", lambda s: view_front(scenes[f"{s}:10"], W, H)),
                ("тир 10, камера заезда", lambda s: view_game(scenes[f"{s}:10"], W, H)),
                ("Gold (редкость)", lambda s: view_front(scenes[f"{s}:gold"], W, H))], out / f"sleds_preview{suffix}.png")
    # #33: каждый следующий тир отличим с камеры заезда (сзади-сверху)
    sheet([s for s in ("tube", "board", "bobsled") if s in ids],
          [(f"тир {t}, камера заезда", lambda s, t=t: view_game(scenes[f"{s}:{t}"], W, H)) for t in (0, 1, 4, 10)],
          out / f"tiers_camera_preview{suffix}.png")
    rk = [k for k in ("rocket:0", "rocket:3", "rocket:6") if k in scenes]
    rs = Image.new("RGB", (W * len(rk), H), (255, 255, 255))
    for j, k in enumerate(rk):
        rs.paste(view_front(scenes[k], W, H), (j * W, 0))
        ImageDraw.Draw(rs).text((j * W + 8, 6), k.replace(":", " тир "), fill=(20, 20, 30), font=font(18))
    rs.save(out / f"rockets_preview{suffix}.png")
    print("Записано:", out / f"sleds_preview{suffix}.png", out / f"rockets_preview{suffix}.png")


if __name__ == "__main__":
    main()
