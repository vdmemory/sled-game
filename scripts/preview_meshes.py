#!/usr/bin/env python3
"""Превью мешей декора (#45): лист PNG с объектами в цветах игры (матплотлиб, ламбертовский свет).

Запуск: python3 scripts/preview_meshes.py [out.png]   (по умолчанию assets/meshes/preview.png)
Составные объекты (хвоя + снег, скала + шапка) рисуются вместе, как их собирает Props/Meshes.
"""
import pathlib
import sys

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402
from mpl_toolkits.mplot3d.art3d import Poly3DCollection  # noqa: E402

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import gen_meshes  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "assets" / "meshes" / "preview.png"

C = {
    "rock": (0.50, 0.53, 0.60), "snow": (0.97, 0.98, 1.0), "pine": (0.16, 0.42, 0.27),
    "ice": (0.62, 0.86, 0.98), "crystal": (0.50, 0.85, 1.0), "sand": (0.86, 0.60, 0.42),
    "trunk": (0.37, 0.25, 0.16),
}
# объект → [(меш, цвет)]
OBJECTS = [
    ("Валун", [("rock_a", C["rock"])]),
    ("Глыба", [("rock_b", C["rock"])]),
    ("Утёс", [("crag", C["rock"])]),
    ("Ёлка", [("pine_foliage", C["pine"]), ("pine_snow", C["snow"])]),
    ("Сугроб", [("snowdrift", C["snow"])]),
    ("Кристаллы", [("ice_crystal", C["crystal"])]),
    ("Ледяная глыба", [("ice_chunk", C["ice"])]),
    ("Островок", [("isle_rock", C["rock"]), ("isle_cap", C["snow"])]),
    ("Арка", [("arch", C["ice"])]),
    ("Гора", [("mountain_rock", C["rock"]), ("mountain_snow", C["snow"])]),
    ("Меза", [("mesa", C["sand"])]),
]
LIGHT = np.array([-0.45, 0.8, -0.4])
LIGHT /= np.linalg.norm(LIGHT)


def shade(m, color):
    tri = m.vertices[m.faces]
    n = m.face_normals
    lam = np.clip(n @ LIGHT, 0, 1)
    sky = 0.5 + 0.5 * n[:, 1]  # небесный заполняющий свет
    k = 0.32 + 0.55 * lam + 0.18 * sky
    cols = np.clip(np.outer(k, color), 0, 1)
    return tri, cols


def main():
    built = gen_meshes.build_all()
    cols_n = 4
    rows_n = (len(OBJECTS) + cols_n - 1) // cols_n
    fig = plt.figure(figsize=(cols_n * 4, rows_n * 4), dpi=110)
    fig.patch.set_facecolor((0.80, 0.88, 0.96))
    for idx, (title, parts) in enumerate(OBJECTS):
        ax = fig.add_subplot(rows_n, cols_n, idx + 1, projection="3d")
        ax.set_facecolor((0.80, 0.88, 0.96))
        allv, alltri, allcol = [], [], []
        tris = 0
        for name, color in parts:
            m = built[name][0]
            tri, cols = shade(m, color)
            alltri.append(tri[:, :, [0, 2, 1]])  # Y вверх в игре → Z вверх в matplotlib
            allcol.append(cols)
            allv.append(m.vertices[:, [0, 2, 1]])
            tris += len(m.faces)
        # одна коллекция на объект — matplotlib сортирует грани по глубине вместе (снег поверх хвои)
        cols = np.vstack(allcol)
        pc = Poly3DCollection(np.concatenate(alltri), facecolors=cols, edgecolors=cols, linewidths=0.15)
        ax.add_collection3d(pc)
        v = np.vstack(allv)
        c = (v.max(0) + v.min(0)) / 2
        r = (v.max(0) - v.min(0)).max() / 2 * 0.9
        ax.set_xlim(c[0] - r, c[0] + r)
        ax.set_ylim(c[1] - r, c[1] + r)
        ax.set_zlim(c[2] - r, c[2] + r)
        ax.set_box_aspect((1, 1, 1))
        ax.view_init(elev=18, azim=-60)
        ax.set_axis_off()
        ax.set_title(f"{title}  ({tris} треуг.)", fontsize=11)
    plt.subplots_adjust(left=0, right=1, bottom=0, top=0.93, wspace=0, hspace=0.08)
    fig.suptitle("Меши декора #45 (scripts/gen_meshes.py)", fontsize=14)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(OUT)
    print(f"Превью: {OUT}")


if __name__ == "__main__":
    main()
