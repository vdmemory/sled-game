#!/usr/bin/env python3
"""Проверка продольного рельефа «волны» (#75): точный профиль уровней (стенд scripts/stand/profile_dump.luau,
тот же Track/Profile.build, что в игре) + 1D-физика SledController (как scripts/sim_economy.py:
a = GRAVITY_ALONG·sin(уклон) − friction(Сани) − DRAG·v², потолок maxSpeed, SLOW_BRAKE ниже SLOW_BRAKE_SPEED,
ракета ROCKET_THRUST на rocketFuel с от старта, стоп при v < STOP_SPEED; полёты с обрывов/зазоров не
моделируются — скорость переносится).

Что проверяет:
  • доли пути по видам рельефа (спуски / выкаты / подъёмы / особые; повороты и дороги отдельно) и цели
    Config.reliefShare(уровень); число подъёмов и максимальный излом профиля (разница уклонов соседних кусков);
  • «подъём не стена»: эталонные сани мира (Config.RELIEF_REF_UPGRADE, мир 1 — без апгрейдов), входящие в
    спуск перед подъёмом не медленнее CLIMB_REF_SPEED, доходят до гребня с ≥ CLIMB_MIN_SPEED; плюс честный
    прогон без апгрейдов от выстрела (где остановка; остановка на подъёме = ошибка, если вход в спуск был
    ≥ CLIMB_REF_SPEED);
  • след скорости для набора апгрейдов (по умолчанию как в видео оригинала: рогатка 30, сани 29, ракета 9).

  python3 scripts/relief_check.py                       # уровни 1–45, сводка
  python3 scripts/relief_check.py --levels 1-10 --trace 2 --png out.png   # след скорости и картинка профиля ур. 2
  python3 scripts/relief_check.py --dump profiles.jsonl # не гнать стенд, взять готовый дамп
  python3 scripts/relief_check.py --up 30,29,9 --trace 2
"""
from __future__ import annotations

import argparse
import json
import math
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "scripts"))
from sim_economy import Rules, load_config  # noqa: E402

RELIEF_OF = {
    "steep": "descent", "gentle": "runout", "climb": "climb", "landing": "descent", "stairLand": "descent",
    "kicker": "special", "stair": "special", "isleIn": "special", "gap": "special", "isle": "special",
    "spiral": "special", "iceTunnel": "special",
}
AIR_KINDS = {"gap", "isle"}  # в полёте / на ускорителе островков — скорость не считаем


def dump_profiles(lo: int, hi: int) -> list[dict]:
    """Запускает стенд profile_dump.luau на диапазон уровней, возвращает профили."""
    tail = open(os.path.join(ROOT, "scripts", "stand", "profile_dump.luau"), encoding="utf-8").read()
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False, encoding="utf-8") as f:
        f.write(f"ARGS_FROM={lo} ARGS_TO={hi}\n" + tail)
        path = f.name
    try:
        r = subprocess.run([sys.executable, os.path.join(ROOT, "scripts", "stand", "run.py"), path], capture_output=True, text=True, check=True)
    finally:
        os.unlink(path)
    return [json.loads(line) for line in r.stdout.splitlines() if line.startswith("{")]


def shares(prof: dict) -> dict:
    by = {"descent": 0.0, "runout": 0.0, "climb": 0.0, "special": 0.0, "curve": 0.0, "road": 0.0, "other": 0.0}
    total = 0.0
    for s in prof["segs"]:
        k = s["k"]
        if k == "lake":
            continue
        total += s["hl"]
        cat = RELIEF_OF.get(k)
        if cat:
            by[cat] += s["hl"]
        elif k == "curve":
            by["curve"] += s["hl"]
        elif k in ("road", "rail"):
            by["road"] += s["hl"]
        else:
            by["other"] += s["hl"]  # старт, переходы
    relief = sum(by[c] for c in ("descent", "runout", "climb", "special"))
    return {"total": total, "relief": relief, "by": by}


def max_kink(prof: dict) -> float:
    worst, prev = 0.0, None
    for s in prof["segs"]:
        if prev is not None and prev["k"] not in ("kicker", "isleIn", "isle", "gap", "stair"):
            worst = max(worst, abs(s["a"] - prev["a"]))
        prev = s
    return worst


def simulate(R: Rules, prof: dict, launch: int, sled: int, rocket: int, power: float = 1.0, rocket_at_start: bool = True,
             ref_floor: float | None = None):
    """Прогон по профилю. Возвращает (точки (h, v, t), остановка h|None, события подъёмов:
    [(h подъёма, v на входе в спуск, v на гребне, прошёл)]). ref_floor — скорость, не ниже которой сани
    входят в каждый спуск (режим эталона Config: CLIMB_REF_SPEED)."""
    c = R.c
    g, k = c["GRAVITY_ALONG"], c["DRAG"]
    fr = R.friction(sled)
    cap = R.max_speed(sled)
    thrust = c["ROCKET_THRUST"]
    fuel = R.fuel(rocket) if rocket_at_start else 0.0
    sb_speed, sb = c["SLOW_BRAKE_SPEED"], c["SLOW_BRAKE"]
    stop_speed = c["STOP_SPEED"]
    v = R.launch(launch) * power
    h = t = 0.0
    pts = [(0.0, v, 0.0)]
    stopped = None
    climbs = []
    v_descent_in = None
    segs = prof["segs"]
    i = 0
    while i < len(segs):
        s = segs[i]
        kind, ang, ln = s["k"], s["a"], s["l"]
        if kind == "lake":
            break
        # эталонный режим: в спуск (с первого переходного куска перед ним) — не медленнее ref_floor
        if ref_floor is not None and kind in ("steep", "fillet") and i > 0 and segs[i - 1]["k"] not in ("fillet", "steep"):
            j = i
            while j < len(segs) and segs[j]["k"] == "fillet":
                j += 1
            if j < len(segs) and segs[j]["k"] == "steep":
                v = max(v, ref_floor)
        if kind == "steep" and (i == 0 or segs[i - 1]["k"] != "steep"):
            v_descent_in = v
        if kind in AIR_KINDS:
            h += s["hl"]
            t += s["hl"] / max(v, 10)
            i += 1
            continue
        if kind in ("kicker", "landing", "stairLand"):
            v = max(v, c["RAMP_MIN_SPEED"])  # трамплин держит скорость, полёт её не теряет
        sin, cos = math.sin(math.radians(ang)), math.cos(math.radians(ang))
        ds = 0.5
        sdone = 0.0
        pad = c["CREST_PAD"] if kind == "climb" else 0.0  # плита гребня: скорость не теряется, не ниже RAMP_MIN_SPEED
        v_crest = None
        while sdone < ln:
            if pad > 0 and sdone >= ln - pad:
                v_crest = v
                v = max(v, c["RAMP_MIN_SPEED"])
                t += (ln - sdone) / v
                sdone = ln
                break
            step = min(ds, ln - sdone)
            a = g * sin - fr - k * v * v
            if fuel > 0:
                a += thrust
            elif a < 0 and v < sb_speed:
                a -= sb * (1 - v / sb_speed)
            v2 = v * v + 2 * a * step
            if v2 <= stop_speed ** 2:
                stopped = h + sdone * cos
                if kind == "climb":
                    climbs.append((s["h"], v_descent_in, 0.0, False))
                pts.append((stopped, 0.0, t + c["STOP_TIME"]))
                return pts, stopped, climbs
            nv = math.sqrt(v2)
            dt = step / ((v + nv) / 2)
            if fuel > 0:
                fuel -= dt
            if nv > cap and fuel <= 0:
                nv = max(cap, nv - 30 * dt)
            v = nv
            sdone += step
            t += dt
            pts.append((h + sdone * cos, v, t))
        h += s["hl"]
        if kind == "climb":
            vc = v_crest if v_crest is not None else v
            climbs.append((s["h"], v_descent_in, vc, vc >= c["CLIMB_MIN_SPEED"] - 0.5))  # допуск 0.5: шаг интегрирования
        i += 1
    return pts, stopped, climbs


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--levels", default="1-45")
    ap.add_argument("--dump", help="готовый дамп профилей (jsonl), иначе запускается стенд")
    ap.add_argument("--trace", type=int, help="уровень, для которого печатать след скорости")
    ap.add_argument("--up", default="30,29,9", help="апгрейды для следа: рогатка,сани,ракета (по умолчанию как в видео)")
    ap.add_argument("--png", help="картинка: профиль (высота) и след скорости уровня --trace")
    args = ap.parse_args()
    lo, hi = (int(x) for x in args.levels.split("-")) if "-" in args.levels else (int(args.levels),) * 2
    R = Rules(load_config())
    c = R.c
    if args.dump:
        profiles = [p for p in (json.loads(l) for l in open(args.dump, encoding="utf-8") if l.startswith("{")) if lo <= p["level"] <= hi]
    else:
        profiles = dump_profiles(lo, hi)
    per = c["LEVELS_PER_WORLD"]
    ref_ups = c["RELIEF_REF_UPGRADE"]
    fails = 0
    agg = {"descent": 0.0, "runout": 0.0, "climb": 0.0, "special": 0.0, "curve": 0.0, "road": 0.0, "other": 0.0, "total": 0.0}
    print("ур. мир  L     спуск выкат подъём особые | повор. дороги | подъёмов  излом°  эталон: мин. на гребне  | эталон от выстрела: стоп")
    for p in profiles:
        lv = p["level"]
        world = (lv - 1) // per + 1
        sh = shares(p)
        for kk in agg:
            agg[kk] += sh["by"].get(kk, 0.0) if kk != "total" else sh["total"]
        rel = max(1.0, sh["relief"])
        n_climb = sum(1 for s in p["segs"] if s["k"] == "climb")
        kink = max_kink(p)
        ref = ref_ups[min(world, len(ref_ups)) - 1]
        # эталон: сани мира, в каждый спуск — не медленнее CLIMB_REF_SPEED
        _, _, climbs = simulate(R, p, ref, ref, 0, rocket_at_start=False, ref_floor=c["CLIMB_REF_SPEED"])
        worst = min((cl[2] for cl in climbs), default=float("nan"))
        bad = [cl for cl in climbs if not cl[3]]
        # честный прогон эталонных саней мира от выстрела (мир 1 — без апгрейдов, как у нового игрока; ракета 0)
        _, stop0, climbs0 = simulate(R, p, ref, ref, 0)
        wall = [cl for cl in climbs0 if not cl[3] and cl[1] is not None and cl[1] >= c["CLIMB_REF_SPEED"]]
        flag = ""
        if bad:
            flag += f"  ПОДЪЁМ-СТЕНА (эталон) ×{len(bad)}"
            fails += 1
        if wall:
            flag += f"  стоп на подъёме (эталон от выстрела) ×{len(wall)}"
            fails += 1
        if kink > c["SMOOTH_KINK"] + 1e-6:
            flag += f"  излом {kink:.2f} > {c['SMOOTH_KINK']}"
            fails += 1
        b = sh["by"]
        print(f"{lv:3d} {world:3d} {p['L']:5d}  {b['descent']/rel:5.0%} {b['runout']/rel:5.0%} {b['climb']/rel:5.0%} {b['special']/rel:5.0%}  | "
              f"{b['curve']/sh['total']:5.0%} {b['road']/sh['total']:5.0%}  | {n_climb:8d}  {kink:5.2f}   {worst:6.1f} studs/с"
              f"{'':12s}| {('%.0f (%.0f%%)' % (stop0, stop0 / p['L'] * 100)) if stop0 is not None else 'финиш'}{flag}")
    rel = max(1.0, sum(agg[kk] for kk in ("descent", "runout", "climb", "special")))
    print(f"Итого по рельефу: спуски {agg['descent']/rel:.0%}, выкаты {agg['runout']/rel:.0%}, подъёмы {agg['climb']/rel:.0%}, особые {agg['special']/rel:.0%}"
          f" (от всего пути: повороты {agg['curve']/agg['total']:.0%}, дороги {agg['road']/agg['total']:.0%}, старт/переходы {agg['other']/agg['total']:.0%})")
    if args.trace:
        p = next((x for x in profiles if x["level"] == args.trace), None)
        if not p:
            sys.exit(f"уровень {args.trace} не в диапазоне")
        L_, S_, Rk = (int(x) for x in args.up.split(","))
        pts, stop, climbs = simulate(R, p, L_, S_, Rk)
        kmh = c["KMH_PER_STUD"]
        print(f"\nСлед скорости ур. {args.trace}: рогатка {L_}, сани {S_} (трение {R.friction(S_):.2f}, потолок {R.max_speed(S_):.0f}), ракета {Rk} "
              f"({R.fuel(Rk):.2f} с); {'остановка на %.0f м (%.0f%%)' % (stop, stop / p['L'] * 100) if stop is not None else 'финиш'}, "
              f"время {pts[-1][2]:.0f} с")
        vmax = max(v for _, v, _ in pts)
        print(f"  макс. {vmax:.0f} studs/с = {vmax*kmh:.0f} км/ч; по 100 studs пути (км/ч):")
        row = []
        nxt = 0
        for hh, v, _ in pts:
            if hh >= nxt:
                row.append(f"{v*kmh:4.0f}")
                nxt += 100
        for i in range(0, len(row), 20):
            print("   " + " ".join(row[i:i + 20]))
        print("  подъёмы: " + ", ".join(f"{cl[0]:.0f} м: вход в спуск {cl[1]*kmh:.0f} → гребень {cl[2]*kmh:.0f} км/ч" for cl in climbs))
        # последние 6 с до остановки
        if stop is not None:
            tend = pts[-1][2]
            tail = [(hh, v, t) for hh, v, t in pts if t >= tend - 6]
            print("  последние 6 с: " + " ".join(f"{v*kmh:.0f}" for hh, v, t in tail[::max(1, len(tail) // 8)]) + " км/ч")
        if args.png:
            import matplotlib
            matplotlib.use("Agg")
            import matplotlib.pyplot as plt

            xs, ys = [], []
            for s in p["segs"]:
                if s["k"] == "lake":
                    break
                xs.append(s["h"])
                ys.append(s["y"])
            last = [s for s in p["segs"] if s["k"] != "lake"][-1]
            xs.append(last["h"] + last["hl"])
            ys.append(last["y"] - last["l"] * math.sin(math.radians(last["a"])))
            fig, ax1 = plt.subplots(figsize=(16, 6))
            ax1.plot(xs, ys, color="#3a6ea5", lw=2, label="высота дна (studs)")
            for s in p["segs"]:
                if s["k"] == "climb":
                    ax1.axvspan(s["h"], s["h"] + s["hl"], color="#f2b134", alpha=0.35, lw=0)
                elif s["k"] == "steep":
                    ax1.axvspan(s["h"], s["h"] + s["hl"], color="#8ecae6", alpha=0.25, lw=0)
                elif s["k"] in ("kicker", "stair", "isle", "gap", "isleIn", "spiral"):
                    ax1.axvspan(s["h"], s["h"] + s["hl"], color="#c77dff", alpha=0.25, lw=0)
                elif s["k"] == "curve":
                    ax1.axvspan(s["h"], s["h"] + s["hl"], color="#999999", alpha=0.15, lw=0)
            ax1.set_xlabel("путь по горизонтали, studs (м)")
            ax1.set_ylabel("высота, studs")
            ax1.set_aspect("auto")
            ax2 = ax1.twinx()
            ax2.plot([hh for hh, _, _ in pts], [v * kmh for _, v, _ in pts], color="#d62828", lw=1.5, label=f"скорость, км/ч (рогатка {L_}, сани {S_}, ракета {Rk})")
            ax2.axhspan(50, 60, color="#d62828", alpha=0.08, lw=0)
            ax2.axhspan(95, 106, color="#d62828", alpha=0.08, lw=0)
            ax2.set_ylabel("км/ч")
            ax2.set_ylim(0, max(130, vmax * kmh * 1.05))
            ax1.set_title(f"Уровень {args.trace}: профиль (синий) и след скорости (красный). Жёлтое — подъёмы, голубое — спуски, лиловое — особые, серое — повороты. "
                          f"Полосы: 50–60 и 95–106 км/ч — ориентиры видео")
            h1, l1 = ax1.get_legend_handles_labels()
            h2, l2 = ax2.get_legend_handles_labels()
            ax1.legend(h1 + h2, l1 + l2, loc="lower left")
            fig.tight_layout()
            fig.savefig(args.png, dpi=110)
            print(f"  PNG: {args.png}")
    if fails:
        print(f"relief_check: ОШИБОК {fails}")
        sys.exit(1)
    print("relief_check: OK")


if __name__ == "__main__":
    main()
