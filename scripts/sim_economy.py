#!/usr/bin/env python3
"""Симуляция экономики и прогрессии (#6): заезды → монеты/гемы → апгрейды → уровни и миры.

Числа читаются из src/shared/Config.luau (мини-парсер Lua-литералов ниже). Формулы Config-функций
(launchSpeed, friction, maxSpeed, upgradePrice, rewardCoins, roadCount, …) повторены здесь — у
каждой комментарий со ссылкой на функцию в Config. Это МОДЕЛЬ, не замер: калибровать по
событиям Analytics.economy и RunPercent (docs/METRICS.md).

Модель заезда (детерминированный проход + вероятность аварии):
  • трасса уровня — как Track/Profile.build (старт, повороты, крутые/пологие, обрывы, дороги,
    островки с ISLE_FROM_LEVEL, волны с WAVE_FROM_LEVEL), свой seed на уровень (трасса фиксирована,
    как в игре, но раскладка не совпадает 1:1 — генератор Python, не Roblox Random);
  • 1D-физика SledController: a = GRAVITY_ALONG·sin(уклон) − friction(Сани)·(1−бонус) − DRAG·v²,
    потолок maxSpeed(Сани)·(1+бонус) (выше — гаснет 30 studs/с²), старт launchSpeed(Рогатка)·сила
    натяжки, ракета — ROCKET_THRUST на rocketFuel(Ракета) с; стоп при v < STOP_SPEED;
  • обрыв — баллистика (RAMP_LIFT, KICKER_DROP, склон 18°, g = 196.2): время в воздухе → монеты
    AIR_COINS_PER_SEC и авто-трюки AUTO_TRICK_PLANS (монеты, буст скорости);
  • авария: в каждом ряду препятствий (OBSTACLE_ROWS на прямой, занятость как SafeLine.plan) и на
    дороге (carsPerLane) — шанс промаха профиля игрока × (v/100)^1.5; авария = конец заезда;
  • «мягкие» удары (#60): щит/TNT — CALIB soft_share на аварию, скорость × keepSpeed (устойчивость Саней).
Экономика: монеты = (путь/STUDS_PER_COIN + монеты на трассе/полёт/трюки/кристалл + finishBonus) ×
incomeMult × след; гемы — финиш/рекорд/на трассе/кристалл; подарки за время, сундук лобби, задания
дня + сундук заданий, стрик. Игрок жадный: после заезда покупает доступную покупку с лучшим
«+ожидаемых монет за заезд / цена» (монеты и гемы — отдельно), повторяет, пока есть что купить.

Запуск:  python3 scripts/sim_economy.py               — таблицы в stdout
         python3 scripts/sim_economy.py --write       — + обновить авто-блок docs/ECONOMY_SIM.md
         python3 scripts/sim_economy.py --levels 20   — сколько уровней гнать (по умолчанию 35 = 7 миров)
         python3 scripts/sim_economy.py --variants 9  — раскладок трассы на уровень (медиана, по умолчанию 5)
         python3 scripts/sim_economy.py --summary --set F.finishPerLevel=60 --set UPGRADE_PRICE_POW=2.4
                                                      — сценарий «что если» (Config не меняется)
         python3 scripts/sim_economy.py --summary --decel 5 --miss 2   — чувствительность к калибровке
         python3 scripts/sim_economy.py --summary --soft 1 --set F.stabilityMax=0      — без устойчивости (#60)
"""
from __future__ import annotations

import argparse
import math
import os
import random
import re
import sys
from bisect import bisect_left

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIG_PATH = os.path.join(ROOT, "src", "shared", "Config.luau")
DOC_PATH = os.path.join(ROOT, "docs", "ECONOMY_SIM.md")
AUTO_BEGIN = "<!-- AUTO:BEGIN (scripts/sim_economy.py --write) -->"
AUTO_END = "<!-- AUTO:END -->"

# ============================================================== парсер Config.luau
# Понимает литералы, которые встречаются в Config: числа, строки, true/false/nil, таблицы
# { a = 1, "x", { … } }, простую арифметику чисел (4 * 3600). Вызовы (Color3.fromRGB(…)),
# ссылки на другие поля и function … end — пропускаются (значение None).

_TOKEN = re.compile(r"""
    (?P<ws>\s+|--\[\[.*?\]\]|--[^\n]*)
  | (?P<num>0x[0-9a-fA-F]+|\d+\.\d*(?:[eE][-+]?\d+)?|\.\d+(?:[eE][-+]?\d+)?|\d+(?:[eE][-+]?\d+)?)
  | (?P<str>"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*')
  | (?P<name>[A-Za-z_][A-Za-z_0-9]*)
  | (?P<op>::|\.\.|==|~=|<=|>=|//|[{}()\[\],=.+\-*/^%<>:#;])
""", re.S | re.X)


def _tokens(src: str, pos: int):
    while pos < len(src):
        m = _TOKEN.match(src, pos)
        if not m:
            pos += 1
            continue
        pos = m.end()
        kind = m.lastgroup
        if kind == "ws":
            continue
        yield kind, m.group(kind), pos


class _P:
    def __init__(self, src: str, pos: int):
        self.it = _tokens(src, pos)
        self.buf = []

    def peek(self):
        if not self.buf:
            self.buf.append(next(self.it, (None, None, None)))
        return self.buf[0]

    def take(self):
        t = self.peek()
        self.buf.pop(0)
        return t

    def skip_balanced(self, open_, close):
        depth = 1
        while depth:
            k, v, _ = self.take()
            if k is None:
                return
            if v == open_:
                depth += 1
            elif v == close:
                depth -= 1

    def skip_function(self):
        depth = 1  # уже съели «function»
        while depth:
            k, v, _ = self.take()
            if k is None:
                return
            if k == "name" and v in ("function", "if", "do"):
                depth += 1
            elif k == "name" and v == "end":
                depth -= 1
            elif k == "name" and v in ("for", "while"):
                depth += 1
                while True:  # «for … do» / «while … do» — один блок
                    k2, v2, _ = self.take()
                    if k2 is None or v2 == "do":
                        break

    def atom(self):
        k, v, _ = self.take()
        if v == "{":
            return self.table()
        if v == "(":
            x = self.expr()
            self.take()  # )
            return x
        if v == "-":
            x = self.atom()
            return -x if isinstance(x, (int, float)) else None
        if k == "num":
            return int(v, 16) if v.startswith("0x") else (float(v) if any(c in v for c in ".eE") else int(v))
        if k == "str":
            return v[1:-1]
        if k == "name":
            if v == "true":
                return True
            if v == "false":
                return False
            if v == "nil":
                return None
            if v == "function":
                self.skip_function()
                return None
            # имя / поле / вызов: съедаем цепочку a.b.c(…)[…]
            while True:
                nk, nv, _ = self.peek()
                if nv in (".", ":"):
                    self.take()
                    self.take()
                elif nv == "(":
                    self.take()
                    self.skip_balanced("(", ")")
                elif nv == "[":
                    self.take()
                    self.skip_balanced("[", "]")
                else:
                    break
            return None
        return None

    def expr(self):
        x = self.term()
        while self.peek()[1] in ("+", "-"):
            op = self.take()[1]
            y = self.term()
            x = (x + y if op == "+" else x - y) if _isnum(x) and _isnum(y) else None
        while self.peek()[1] == "::":  # приведение типа Luau: «{} :: { … }»
            self.take()
            self.type_skip()
        return x

    def type_skip(self):
        k, v, _ = self.take()
        if v == "{":
            self.skip_balanced("{", "}")
        elif v == "(":
            self.skip_balanced("(", ")")

    def term(self):
        x = self.factor()
        while self.peek()[1] in ("*", "/", "//", "%"):
            op = self.take()[1]
            y = self.factor()
            if _isnum(x) and _isnum(y):
                x = {"*": x * y, "/": x / y if y else None, "//": x // y if y else None, "%": x % y if y else None}[op]
            else:
                x = None
        return x

    def factor(self):
        x = self.atom()
        if self.peek()[1] == "^":
            self.take()
            y = self.factor()
            x = x ** y if _isnum(x) and _isnum(y) else None
        return x

    def table(self):
        arr, d = [], {}
        while True:
            k, v, _ = self.peek()
            if k is None:
                break
            if v == "}":
                self.take()
                break
            if v in (",", ";"):
                self.take()
                continue
            if k == "name" and v not in ("true", "false", "nil", "function"):
                # «key = value»?
                self.take()
                if self.peek()[1] == "=":
                    self.take()
                    d[v] = self.expr()
                    continue
                self.buf.insert(0, (k, v, None))  # не ключ — вернуть токен
            if v == "[":
                self.take()
                key = self.expr()
                self.take()  # ]
                self.take()  # =
                d[key] = self.expr()
                continue
            arr.append(self.expr())
        if d and arr:
            for i, x in enumerate(arr):
                d[i + 1] = x
            return d
        return d if d else arr


def _isnum(x):
    return isinstance(x, (int, float)) and not isinstance(x, bool)


def load_config(path: str = CONFIG_PATH) -> dict:
    """Все верхнеуровневые `Config.NAME = <литерал>` → dict (последнее присваивание побеждает)."""
    src = open(path, encoding="utf-8").read()
    cfg = {"_src": src}
    for m in re.finditer(r"^Config\.([A-Z_][A-Za-z0-9_]*)\s*=\s*", src, re.M):
        try:
            val = _P(src, m.end()).expr()
        except Exception:  # noqa: BLE001 — неразобранное поле просто пропускаем
            val = None
        if val is not None:
            cfg[m.group(1)] = val
    return cfg


def _fn_numbers(src: str, name: str) -> list[float]:
    """Числа из тела `function Config.<name>(…) … end` (для формул levelLength/steepChance)."""
    m = re.search(r"function Config\." + name + r"\(.*?\n(.*?)\nend", src, re.S)
    if not m:
        raise SystemExit(f"Config.{name} не найдена в Config.luau")
    return [float(x) for x in re.findall(r"(?<![A-Za-z_])\d+(?:\.\d+)?", m.group(1))]


# ============================================================== формулы Config (зеркало)
class Rules:
    def __init__(self, c: dict):
        self.c = c
        src = c["_src"]
        F = c["F"]
        self.F = F
        # Config.levelLength: return A + (level - 1) * B
        a, _one, b = _fn_numbers(src, "levelLength")[:3]
        self._len = c.get("_levelLength", (a, b))  # --set levelLength.step=… подменяет только в модели
        # Config.steepChance: math.max(MIN, START - STEP * (level - 1))
        nums = _fn_numbers(src, "steepChance")
        self._steep = (nums[0], nums[1], nums[2])
        self.U = c["UPGRADES"]
        self.tier = c["TIER_SIZE"]

    # Config.levelLength
    def level_length(self, lv):
        return self._len[0] + (lv - 1) * self._len[1]

    # Config.steepChance
    def steep_chance(self, lv):
        lo, start, step = self._steep
        return max(lo, start - step * (lv - 1))

    # Config.roadCount / carsPerLane
    def road_count(self, lv):
        return min(len(self.c["ROAD_AT"]), 1 + (lv - 1) // max(1, self.c["ROAD_EVERY_LEVELS"]))

    def cars_per_lane(self, lv):
        return min(self.c["CARS_MAX"], 1 + (lv - 1) // max(1, self.c["CARS_EVERY_LEVELS"]))

    # Config.launchSpeed / rocketFuel / friction / maxSpeed / incomeMult / finishBonus
    def launch(self, l):
        return self.F["launchBase"] + self.F["launchStep"] * l

    def fuel(self, l):
        return self.F["fuelBase"] + self.F["fuelStep"] * l

    def friction(self, l):
        return self.F["frictionBase"] * self.F["frictionDecay"] ** l

    def max_speed(self, l):
        b, s, cap = self.F["speedBase"], self.F["speedStep"], self.F["speedSoftCap"]
        span = cap - b
        if span <= 0 or s <= 0:
            return b
        return cap - span * math.exp(-s * l / span)

    def income(self, l):
        return 1 + self.F["incomeStep"] * l

    # Config.stability / keepSpeed (#60): потеря скорости от удара × (1 − устойчивость Саней)
    def stability(self, l):
        return min(max(self.F.get("stabilityStep", 0) * max(0, l), 0), max(0, self.F.get("stabilityMax", 0)))

    def keep(self, k, l):
        return 1 - (1 - k) * (1 - self.stability(l))

    def finish_bonus(self, lv):
        return self.F["finishPerLevel"] * lv

    # Config.rewardCoins
    def reward(self, base, lv):
        return math.floor(base * (1 + (lv - 1) * self.F["rewardGrowth"]))

    # Config.upgradePrice → (цена, "C"|"G"); Config.upgradeNext — шаг ракеты
    def price(self, name, l):
        u = self.U[name]
        if l >= u["MaxLevel"]:
            return None
        if u.get("gems"):
            lst = self.c["ROCKET_TIER_PRICES"]
            return lst[min(max(l // self.tier + 1, 1), len(lst)) - 1], "G"
        if l > 0 and l % self.tier == 0:
            return 1 + l // (self.tier * 2), "G"
        return math.floor(u["BaseCost"] * (1 + l) ** self.c["UPGRADE_PRICE_POW"] * u["Growth"] ** l), "C"

    def next_level(self, name, l):
        step = self.U[name].get("step") or 1
        return min((l // step + 1) * step, self.U[name]["MaxLevel"])

    # Config.worldOf
    def world_of(self, lv):
        return (lv - 1) // self.c["LEVELS_PER_WORLD"] + 1

    # Config.isleCount / isleSpeed
    def isle_count(self, lv):
        lo, hi = self.c["ISLE_COUNT"]
        h = min(max(lo + (lv - self.c["ISLE_FROM_LEVEL"]) // 4, lo), hi)
        return max(lo, h - 1), h

    def isle_speed(self, lv):
        a, b = self.c["ISLE_SPEED"]
        v = min(b, a + self.c["ISLE_SPEED_STEP"] * max(0, lv - self.c["ISLE_FROM_LEVEL"]))
        return v, v * self.c["ISLE_SPEED_SPREAD"]

    def isle_chance(self, lv):
        c = self.c
        if lv < c["ISLE_FROM_LEVEL"]:
            return 0
        return min(c["ISLE_CHANCE_MAX"], c["ISLE_CHANCE_BASE"] + c["ISLE_CHANCE_STEP"] * (lv - c["ISLE_FROM_LEVEL"]))

    # Config.trickComboMult
    def trick_mult(self, n):
        m = self.c["TRICK_COMBO_MULT"]
        return m[min(max(n, 1), len(m)) - 1]


G_WORLD = 196.2  # workspace.Gravity по умолчанию (баллистика полёта; в Config нет)

# Калибровка модели (не Config). 1D-физика идеальна: нет руля, трения о борта жёлоба, неточных линий,
# поэтому без поправки она доезжает уровень 1 уже с 2/2 апгрейдами. extra_decel — добавка к трению
# (studs/с²), подобранная под ориентир Config/GAME_DESIGN «уровень 1 без апгрейдов ≈ 35–40 %, с ~6–8
# покупками каждого ≈ финиш» (средний игрок). Перекалибровать по RunPercent/RunFinished из аналитики.
CALIB = {"extra_decel": 3.0, "soft_share": 0.25}
# soft_share (#60) — сколько «касаний» ряда (тот же шанс, что у аварии) на каждую аварию ещё и не
# смертельны: щит принял удар (SHIELD_HIT_SLOW), TNT (TNT_SLOW). Скорость × 1 − p·soft·потеря, где
# потерю уменьшает устойчивость «Саней» (Config.keepSpeed). Не откалибровано — оценка: щит в ~7 %
# рядов, TNT — 8 из ~40 весов препятствий в 3 мирах. «Падение» (ручной трюк) модель не крутит.


# ============================================================== профили игроков
PROFILES = {
    # power — сила натяжки рогатки (Launch(power), 0..1); miss — шанс задеть занятую полосу ряда на
    # 100 studs/с (шанс аварии в ряду = E[занятых полос]/LANES × miss × (v/100)^1.5; на дороге —
    # miss × 0.5 × машин на полосе × (v/100)^1.5; не откалибровано — см. RunCrashed/RunFinished); pick — доля подобранных монет/бонусов; tasks — доля выполненных заданий дня;
    # overhead — с на лобби/рогатку/итоги между заездами; session — мин; per_day — сессий в день;
    # rocket — "start" (жмёт сразу) или "smart" (на пологих, где сани тормозят)
    "casual": dict(name="Казуал", power=0.70, miss=0.12, pick=0.40, tasks=0.5, overhead=25, session=12, per_day=1, rocket="start"),
    "average": dict(name="Средний", power=0.85, miss=0.06, pick=0.60, tasks=0.8, overhead=15, session=20, per_day=2, rocket="smart"),
    "skilled": dict(name="Опытный", power=0.95, miss=0.025, pick=0.80, tasks=1.0, overhead=10, session=30, per_day=2, rocket="smart"),
}


# ============================================================== трасса уровня
def build_track(R: Rules, lv: int, variant: int = 0):
    """Список кусков (kind, уклон°, длина вдоль склона, доп.) по логике Track/Profile.build.
    variant — другая случайная раскладка того же уровня (генератор Python ≠ Roblox Random, поэтому
    итог усредняется по нескольким раскладкам, а не берётся одна)."""
    c = R.c
    rng = random.Random(lv * 7919 + 17 + variant * 1000003)
    irng = random.Random(lv * 3571 + 7 + variant * 999983)
    L = R.level_length(lv)
    segs, h = [], 0.0
    last_isle = None

    def add(kind, ang, ln, **ex):
        nonlocal h
        segs.append((kind, ang, ln, h, ex))
        h += ln * math.cos(math.radians(ang))

    def islands():
        nonlocal last_isle
        lo, hi = R.isle_count(lv)
        n = irng.randint(lo, hi)
        isle_len = sum(c["ISLE_LEN"]) / 2
        total = c["ISLE_IN"][1] + 90 + n * (isle_len + 40)
        if h + total > L - 80:
            return False
        add("isleIn", c["ISLE_IN"][0], c["ISLE_IN"][1])
        for _ in range(n):
            add("gap", 4, 40)  # зазор ~ ISLE_GAP_MIN…0.6·дальность: летим, не едем
            add("isle", sum(c["ISLE_PITCH"]) / 2, isle_len)
        add("gap", 6, 40)
        add("landing", 18, 90)
        last_isle = h
        return True

    add("start", 7, 110)
    forced = list(c["FORCED_KICKERS"])
    roads = list(c["ROAD_AT"][:R.road_count(lv)])
    isle_next = L * c["ISLE_AT"] if lv >= c["ISLE_FROM_LEVEL"] else None
    force_landing = False
    while h < L:
        if not force_landing and roads and h >= L * roads[0]:
            roads.pop(0)
            add("road", 3, 60)
        elif force_landing:
            add("landing", 18, 90)
            force_landing = False
        elif isle_next is not None and h >= isle_next:
            isle_next = None
            if not islands():
                add("gentle", rng.uniform(*c["GENTLE_ANGLE"]), 120)
        elif forced and h >= L * forced[0]:
            forced.pop(0)
            add("kicker", 6, 100)
            force_landing = True
        else:
            t = rng.random()
            steep = R.steep_chance(lv)
            extra = lv >= c["ISLE_FROM_LEVEL"] and irng.random() < R.isle_chance(lv) and last_isle is not None and h - last_isle >= c["ISLE_MIN_SPACING"]
            if extra and islands():
                pass
            elif lv >= c["WAVE_FROM_LEVEL"] and h > 300 and irng.random() < c["WAVE_CHANCE"]:
                for _ in range(irng.randint(*c["WAVE_COUNT"])):
                    add("wave", c["WAVE_DOWN"][0], c["WAVE_DOWN"][1])
                    add("wave_up", c["WAVE_UP"][0], c["WAVE_UP"][1])
            elif h > 220 and t < c["CURVE_CHANCE"]:
                pitch = rng.uniform(*c["CURVE_PITCH"])
                pieces = max(3, round(rng.uniform(*c["CURVE_ANGLE"]) / c["CURVE_STEP"]))
                for k in range(pieces):
                    add("curve", pitch, c["CURVE_PIECE"], coin=(k % 2 == 1))
            elif t < c["CURVE_CHANCE"] + steep:
                add("steep", rng.uniform(*c["STEEP_ANGLE"]), 90)
            elif t < c["CURVE_CHANCE"] + steep + c["KICKER_CHANCE"] and h > 250:
                add("kicker", 6, 100)
                force_landing = True
            else:
                add("gentle", rng.uniform(*c["GENTLE_ANGLE"]), 120)
    if force_landing:
        add("landing", 18, 90)
    # занятость рядов препятствий — как SafeLine.plan: maxBlocked = 1 + (ур−1)//GROW_LEVELS + i//GROW_SEGS
    out = []
    for i, (kind, ang, ln, hs, ex) in enumerate(segs):
        if kind in ("gentle", "steep") and hs >= c["SAFE_START"]:
            mb = min(3, 1 + (lv - 1) // max(1, c["OBSTACLE_GROW_LEVELS"]) + i // max(1, c["OBSTACLE_GROW_SEGS"]))
            mb = min(mb, c["LANES"] - 2)
            ex = dict(ex, blocked=c["OBSTACLE_ROW_CHANCE"] * mb / 2)  # E[занятых полос в ряду]
        out.append((kind, ang, ln, hs, ex))
    return out, L


def flight(v, lift_angle_deg, lift, drop, slope_deg=18.0):
    """Время полёта с трамплина: вылет v·(cosθ − lift·sinθ, sinθ + lift·cosθ), земля ниже на
    drop + x·tan(склон). Возвращает (время, горизонталь)."""
    th = math.radians(lift_angle_deg)
    vx = v * (math.cos(th) - lift * math.sin(th))
    vy = v * (math.sin(th) + lift * math.cos(th))
    tan = math.tan(math.radians(slope_deg))
    t = 0.0
    while t < 6:
        t += 0.01
        y = vy * t - 0.5 * G_WORLD * t * t
        if y <= -(drop + vx * t * tan):
            break
    return t, vx * t


# ============================================================== один заезд (проход)
DS = 10.0  # шаг интегрирования по пути, studs


class RunCurve:
    """Ожидаемый ход заезда при заданных апгрейдах: по точкам пути — время, вероятность «ещё не
    врезался», монеты и гемы, накопленные к этой точке; конец — финиш или остановка."""

    __slots__ = ("h", "t", "S", "coins", "gems", "end", "finished", "L", "air")


def simulate_run(R: Rules, lv, up, sled_bonus, prof, variant=0, track_cache={}):
    c = R.c
    if (lv, variant) not in track_cache:
        track_cache[(lv, variant)] = build_track(R, lv, variant)
    segs, L = track_cache[(lv, variant)]
    lL, sL, rL = up["Launch"], up["Sled"], up["Rocket"]
    fr = R.friction(sL) * (1 - sled_bonus) + CALIB["extra_decel"]
    cap = R.max_speed(sL) * (1 + sled_bonus)
    k = c["DRAG"]
    g = c["GRAVITY_ALONG"]
    v = R.launch(lL) * prof["power"]
    fuel = R.fuel(rL)
    pick, miss = prof["pick"], prof["miss"]
    # средняя потеря «мягкого» удара (щит / TNT) с устойчивостью Саней
    soft_loss = 1 - R.keep((c["TNT_SLOW"] + c["SHIELD_HIT_SLOW"]) / 2, sL)
    cv = c["COIN_PICKUP_VALUE"] * 1.15  # среднее комбо (линия 5 монет: comboMult ≈ 1–2)
    h = t = air_total = 0.0
    surv = 1.0
    coins = gems = 0.0  # монеты/гемы «с трассы» (без пути и финиша)
    H, T, S, Cc, Gg = [0.0], [0.0], [1.0], [0.0], [0.0]
    gem_marks = sorted([L * f for f in c["GEMS_ON_TRACK"]] + [L * c["CRYSTAL_AT"]])
    gi = 0
    finished = False
    stopped = False
    plans = c["AUTO_TRICK_PLANS"]

    def tricks_for(air):
        best = None
        for p in plans:
            if p["air"] <= air:
                best = p
        if not best:
            return 0, 1.0
        ids = best["options"][0]
        coins_ = sum(c["TRICKS"][i]["coins"] for i in ids) * R.trick_mult(len(set(ids)))
        boost = 1.0
        for i in ids:
            boost *= c["TRICKS"][i]["boost"]
        return coins_, boost

    def do_air(air):
        nonlocal coins, air_total
        air_total += air
        if air >= c["AIR_MIN_TIME"]:
            coins += math.floor(min(air, 4) * c["AIR_COINS_PER_SEC"])
        tc, boost = tricks_for(air)
        coins += tc
        return boost

    def risk(p_hit):
        nonlocal surv
        surv *= max(0.0, 1 - p_hit)

    for kind, ang, ln, hs, ex in segs:
        if stopped or finished:
            break
        sin, cos = math.sin(math.radians(ang)), math.cos(math.radians(ang))
        if kind == "gap":
            # перелёт между островками (ускоритель на краю задаёт v в окне isleSpeed)
            lo, hi = R.isle_speed(lv)
            v = min(max(v, lo), hi)
            at, _ = flight(v, math.degrees(math.atan2(c["ISLE_RAMP"][1], c["ISLE_RAMP"][0])) - 3, c["ISLE_LIFT"], 3, 0)
            v *= do_air(at)
            coins += c["ISLE_COINS"] * pick * cv
            h += ln * cos
            t += at
            H.append(h); T.append(t); S.append(surv); Cc.append(coins); Gg.append(gems)
            continue
        if kind == "isleIn":
            lo, hi = R.isle_speed(lv)
            v = min(max(v, lo), hi)
        if kind == "kicker":
            v = max(v, c["RAMP_MIN_SPEED"])
        if kind in ("gentle", "steep"):
            rows = c["OBSTACLE_ROWS"]
            # ускоритель в свободной полосе ряда: заезжаем с долей pick
            v += c["BOOST_ADD"] * c["BOOST_CHANCE"] * rows * pick
            if hs >= c["SAFE_START"]:
                coins += c["COIN_LINE_CHANCE"] * max(0, rows - 1) * c["COINS_PER_LINE"] * pick * cv
                coins += c["POWERUPS"]["rings"]["chance"] * 3 * c["POWERUPS"]["rings"]["coins"] * pick
                # канистра = полный бак (не сверх него): в среднем + шанс × подбор × бак, но не выше бака
                fuel = min(R.fuel(rL), fuel + c["POWERUPS"]["fuel"]["chance"] * pick * R.fuel(rL))
        if kind == "wave_up":
            coins += 3 * pick * cv
        if kind == "curve" and ex.get("coin"):
            coins += pick * cv
        if kind == "road":
            # машины поперёк: шанс аварии × машин на полосе
            risk(miss * 0.5 * R.cars_per_lane(lv) * (max(v, 30) / 100) ** 1.5)
        s = 0.0
        rows_left = c["OBSTACLE_ROWS"] if "blocked" in ex else 0
        row_at = [ln * (r + 0.5) / max(1, rows_left) for r in range(rows_left)]
        while s < ln:
            ds = min(DS, ln - s)
            a = g * sin - fr
            rocket = fuel > 0 and (prof["rocket"] == "start" or a < 0 or v < cap * 0.6)
            if rocket:
                a += c["ROCKET_THRUST"]
            v2 = v * v + 2 * (a - k * v * v) * ds
            if v2 <= c["STOP_SPEED"] ** 2:
                # остановились: добираем путь до нуля скорости и выходим
                if a - k * v * v < 0:
                    rem = v * v / (2 * (k * v * v - a))
                    h += min(rem, ds) * cos
                    t += (min(rem, ds) / max(v, 1)) * 2 + c["STOP_TIME"]
                stopped = True
                break
            nv = math.sqrt(v2)
            dt = ds / ((v + nv) / 2)
            if rocket:
                fuel -= dt
            if nv > cap and not rocket:
                nv = max(cap, nv - 30 * dt)
            v = nv
            s += ds
            h += ds * cos
            t += dt
            while row_at and s >= row_at[0]:
                row_at.pop(0)
                # ряд препятствий: E[занятых полос] / полос × промах × скорость
                p_row = ex["blocked"] / c["LANES"] * miss * (v / 100) ** 1.5
                risk(p_row)
                v *= 1 - min(1.0, p_row * CALIB["soft_share"]) * soft_loss  # щит / TNT (#60)
            while gi < len(gem_marks) and h >= gem_marks[gi]:
                is_crystal = abs(gem_marks[gi] - L * c["CRYSTAL_AT"]) < 1e-6
                if is_crystal:
                    coins += c["CRYSTAL_COINS"] * pick
                    gems += pick
                else:
                    gems += pick
                gi += 1
            if h >= L:
                finished = True
                break
            H.append(h); T.append(t); S.append(surv); Cc.append(coins); Gg.append(gems)
        if kind == "kicker" and not stopped and not finished:
            at, ax = flight(v, 6 + 14, c["RAMP_LIFT"], c["KICKER_DROP"])
            v *= do_air(at)
            t += at
            h += ax
            H.append(h); T.append(t); S.append(surv); Cc.append(coins); Gg.append(gems)
    r = RunCurve()
    r.h, r.t, r.S, r.coins, r.gems = H, T, S, Cc, Gg
    r.end = min(h, L)
    r.finished = finished
    r.L = L
    r.air = air_total
    return r


def sample_run(r: RunCurve, u: float):
    """Случайный исход: авария там, где «выживание» S упало ниже u (иначе конец прохода)."""
    # S убывает → ищем первую точку S < u
    lo, hi = 0, len(r.S)
    while lo < hi:
        mid = (lo + hi) // 2
        if r.S[mid] < u:
            hi = mid
        else:
            lo = mid + 1
    if lo < len(r.S):
        i = lo
        return min(r.h[i], r.L), r.t[i], r.coins[i], r.gems[i], False, True
    return r.end, r.t[-1], r.coins[-1], r.gems[-1], r.finished, False


def expected(R, r: RunCurve, lv, mult):
    """Ожидаемые монеты за заезд (для жадного выбора покупки)."""
    e = 0.0
    prev = 1.0
    for i in range(1, len(r.S)):
        p = prev - r.S[i]  # шанс аварии на этом шаге
        if p > 0:
            e += p * (r.h[i] / R.c["STUDS_PER_COIN"] + r.coins[i])
        prev = r.S[i]
    fin = R.finish_bonus(lv) if r.finished else 0
    e += prev * (r.end / R.c["STUDS_PER_COIN"] + r.coins[-1] + fin)
    return e * mult, prev if r.finished else 0.0


# ============================================================== игрок
class Player:
    def __init__(self, R: Rules, prof: dict, seed: int, variant: int = 0):
        self.R, self.p = R, prof
        self.variant = variant
        self.rng = random.Random(seed)
        self.up = {n: 0 for n in R.c["UPGRADE_ORDER"]}
        self.coins = 0
        self.gems = 0
        self.level = 1
        self.best = 0
        self.sleds = {("tube", 1)}  # Ватрушка обычная — бесплатно (prices[1] = 0)
        self.trail = 0  # индекс в TRAILS
        self.cache = {}

    def sled_bonus(self):
        c = self.R.c
        best = 0
        for sid, rar in self.sleds:
            s = next(x for x in c["SLEDS"] if x["id"] == sid)
            best = max(best, s["bonus"] + c["RARITIES"][rar - 1]["bonus"])
        return best / 100

    def mult(self, up=None, trail=None):
        c = self.R.c
        up = up or self.up
        tr = c["TRAILS"][self.trail if trail is None else trail]
        return self.R.income(up["Income"]) * (1 + tr["bonus"] / 100)

    def curve(self, up=None, sb=None, lv=None):
        up = up or self.up
        sb = self.sled_bonus() if sb is None else sb
        lv = lv or self.level
        key = (lv, up["Launch"], up["Sled"], up["Rocket"], round(sb, 3))
        if key not in self.cache:
            self.cache[key] = simulate_run(self.R, lv, up, sb, self.p, self.variant)
        return self.cache[key]

    def value(self, up=None, sb=None, trail=None):
        return expected(self.R, self.curve(up, sb), self.level, self.mult(up, trail))[0]

    def candidates(self):
        """(валюта, цена, прирост ожидаемых монет, применить)"""
        R, c = self.R, self.R.c
        base = self.value()
        out = []
        for n in c["UPGRADE_ORDER"]:
            pr = R.price(n, self.up[n])
            if not pr:
                continue
            nu = dict(self.up)
            nu[n] = R.next_level(n, self.up[n])
            gain = self.value(up=nu) - base
            if n == "Income" or n == "Launch" or n == "Sled":
                gain = max(gain, 1e-6)  # покупка всегда «полезна» (апгрейд виден, игрок его берёт)
            out.append((pr[1], pr[0], gain, ("up", n, nu[n])))
        world = R.world_of(self.level)
        cur = self.sled_bonus()
        for s in c["SLEDS"]:
            if s["world"] > world:
                continue
            owned = max([r for sid, r in self.sleds if sid == s["id"]] or [0])
            if owned >= len(s["prices"]):
                continue
            nb = (s["bonus"] + c["RARITIES"][owned]["bonus"]) / 100
            if nb <= cur:
                continue
            gain = self.value(sb=nb) - base
            out.append(("C", s["prices"][owned], gain, ("sled", s["id"], owned + 1)))
        if self.trail + 1 < len(c["TRAILS"]):
            t = c["TRAILS"][self.trail + 1]
            out.append(("C", t["price"], self.value(trail=self.trail + 1) - base, ("trail", self.trail + 1)))
        return out

    def shop(self):
        bought = []
        while True:
            cands = [x for x in self.candidates() if x[2] > 0 and x[1] <= (self.coins if x[0] == "C" else self.gems)]
            if not cands:
                return bought
            # лучшее «прирост / цена» среди доступного; гемы и монеты сравниваются внутри своей валюты
            cur, price, gain, act = max(cands, key=lambda x: (x[0] == "C", x[2] / max(1, x[1])))
            if cur == "C":
                self.coins -= price
            else:
                self.gems -= price
            if act[0] == "up":
                self.up[act[1]] = act[2]
                bought.append(act[1][0] if cur == "C" else act[1][0].lower() + "💎")
            elif act[0] == "sled":
                self.sleds.add((act[1], act[2]))
                bought.append("s")
            else:
                self.trail = act[1]
                bought.append("t")


def play(R: Rules, key: str, max_level: int, seed: int = 7, hours_cap: float = 400, variant: int = 0):
    """Гонит игрока профиля key до max_level+1 (или hours_cap ч игры). → (заезды, уровни, снимки)."""
    c = R.c
    prof = PROFILES[key]
    P = Player(R, prof, seed + variant, variant)
    econ_at = {}  # уровень → номер заезда на уровне, с которого апгрейдов хватает доехать без аварии
    gifts = c["PLAYTIME_GIFTS"]
    pool = c["TASK_POOL"]
    task_gems = sum(t["gems"] for t in pool) / len(pool)
    play_t = 0.0
    runs = 0
    day = 0
    log = []  # по заезду
    levels = {}  # уровень → dict
    lv_start_run, lv_start_t = 0, 0.0
    lv_coins = 0
    snaps = []
    snap_marks = [5, 10, 20, 30, 60, 120, 240, 480, 960, 1920, 3840]
    while P.level <= max_level and play_t < hours_cap * 3600:
        # день: стрик, сундук лобби (если между сессиями ≥ CHEST_INTERVAL — каждая сессия), задания
        streak = c["STREAK_REWARDS"][day % len(c["STREAK_REWARDS"])]
        cm = c["STREAK_CYCLE_MULT"] if day >= len(c["STREAK_REWARDS"]) else 1
        # новичку окно стрика само не открывается, сундук он находит после 1-го заезда: в первую
        # сессию эти награды забираются после заезда 1 (pending), дальше — при входе
        pending = [(R.reward(math.floor(streak.get("coins", 0) * cm), P.level), streak.get("gems", 0))]
        day_runs = 0
        tasks_paid = False
        big_taken = False
        for sess in range(prof["per_day"]):
            s_t = 0.0
            pending.append((R.reward(c["CHEST_COINS"], P.level), c["CHEST_GEMS"]))
            if runs > 0:
                for pc, pg in pending:
                    P.coins += pc
                    P.gems += pg
                pending = []
            gi = 0
            P.shop()
            while s_t < prof["session"] * 60 and P.level <= max_level:
                curve = P.curve()
                if P.level not in econ_at and curve.finished:
                    econ_at[P.level] = runs - lv_start_run + 1
                dist, rt, tc, tg, fin, crashed = sample_run(curve, P.rng.random())
                lv = P.level
                earned = math.floor((math.floor(dist / c["STUDS_PER_COIN"]) + tc + (R.finish_bonus(lv) if fin else 0)) * P.mult())
                pct = math.floor(dist / curve.L * 100)
                g = round(tg)
                if fin:
                    g += c["GEMS_FINISH"]
                elif pct > P.best:
                    g += c["GEMS_NEW_BEST"]
                    P.best = pct
                P.coins += earned
                P.gems += g
                lv_coins += earned
                runs += 1
                day_runs += 1
                dt = rt + prof["overhead"] + (c["FINISH_GLIDE_MAX"] if fin else 2)
                s_t += dt
                play_t += dt
                while gi < len(gifts) and s_t >= gifts[gi]["min"] * 60:
                    gf = gifts[gi]
                    if not (gf.get("big") and big_taken):
                        P.coins += R.reward(gf.get("coins", 0), P.level)
                        P.gems += gf.get("gems", 0)
                        big_taken = big_taken or bool(gf.get("big"))
                    gi += 1
                # задания дня: доля tasks выполняется к середине игрового дня (~6 заездов)
                if not tasks_paid and day_runs >= 6:
                    done = round(c["TASKS_PER_DAY"] * prof["tasks"])
                    P.gems += round(done * task_gems)
                    if done >= c["TASKS_PER_DAY"]:
                        P.coins += R.reward(c["TASK_CHEST_COINS"], P.level)
                        P.gems += c["TASK_CHEST_GEMS"]
                    tasks_paid = True
                for pc, pg in pending:
                    P.coins += pc
                    P.gems += pg
                pending = []
                bought = P.shop()
                log.append(dict(run=runs, t=play_t, lv=lv, pct=pct, earned=earned, fin=fin, bought="".join(bought), up=dict(P.up)))
                if fin:
                    n = runs - lv_start_run
                    levels[lv] = dict(runs=n, econ=econ_at.get(lv, n), minutes=(play_t - lv_start_t) / 60, cum_runs=runs, cum_min=play_t / 60,
                                      coins_run=lv_coins / n, up=dict(P.up), sb=P.sled_bonus(), trail=P.trail,
                                      day=day + 1)
                    P.level += 1
                    P.best = 0
                    lv_start_run, lv_start_t, lv_coins = runs, play_t, 0
                while snap_marks and play_t >= snap_marks[0] * 60:
                    snaps.append(dict(min=snap_marks.pop(0), run=runs, lv=P.level, up=dict(P.up), coins_run=earned,
                                      sb=P.sled_bonus(), trail=P.trail))
        day += 1
    return dict(log=log, levels=levels, snaps=snaps, player=P, hours=play_t / 3600, days=day)


# ============================================================== отчёт
TARGET = (3, 5)  # цель: финиш уровня за 3–5 заездов (#6)


def fmt_up(up):
    return f"{up['Launch']}/{up['Sled']}/{up['Income']}/{up['Rocket'] // 5 + 1}"


def fmt_min(m):
    if m < 90:
        return f"{m:.0f} мин"
    return f"{m / 60:.1f} ч"


def _med(xs):
    xs = sorted(xs)
    return xs[len(xs) // 2] if xs else None


def report(R: Rules, max_level: int, variants: int = 5):
    c = R.c
    res = {k: [play(R, k, max_level, variant=v) for v in range(variants)] for k in PROFILES}
    INF = float("inf")

    def lv_stat(k, lv, field):
        vals = [(r["levels"][lv][field] if lv in r["levels"] else INF) for r in res[k]]
        return _med(vals)

    def cum_stat(k, lv, field):
        vals = [(r["levels"][lv][field] if lv in r["levels"] else INF) for r in res[k]]
        return _med(vals)

    out = []
    w = out.append
    w(f"Сгенерировано `python3 scripts/sim_economy.py --write` из `src/shared/Config.luau` "
      f"(уровней: {max_level}, раскладок трассы на уровень: {variants}, цель — финиш за {TARGET[0]}–{TARGET[1]} заездов). "
      f"Это модель, не замер; числа — медиана по раскладкам.")
    w("")
    w("**Профили:** " + "; ".join(
        f"{p['name']} — натяжка {p['power']:.0%}, промах {p['miss']}, подбор {p['pick']:.0%}, задания {p['tasks']:.0%}, "
        f"{p['session']} мин × {p['per_day']}/день, {p['overhead']} с между заездами" for p in PROFILES.values()))
    w("")
    # --- сводка заездов на уровень
    w(f"### Заездов до финиша уровня (★ — стена: больше {TARGET[1]}; ◦ — меньше {TARGET[0]})")
    w("")
    w("Ячейка: **заездов до финиша** (из них до заезда, с которого апгрейдов хватает доехать без аварии) · минут на уровень.")
    w("")
    w("| ур. | мир | длина | " + " | ".join(p["name"] for p in PROFILES.values()) + " |")
    w("| --- | --- | --- | " + " | ".join("---" for _ in PROFILES) + " |")
    for lv in range(1, max_level + 1):
        cells = []
        for k in PROFILES:
            n = lv_stat(k, lv, "runs")
            if n == INF:
                cells.append("не дошёл")
                continue
            e = lv_stat(k, lv, "econ")
            m = lv_stat(k, lv, "minutes")
            mark = " ★" if n > TARGET[1] else (" ◦" if n < TARGET[0] else "")
            cells.append(f"**{n}**{mark} ({e}) · {fmt_min(m)}")
        w(f"| {lv} | {R.world_of(lv)} | {R.level_length(lv):.0f} | " + " | ".join(cells) + " |")
    w("")
    # --- миры
    w("### Миры: заездов и игрового времени на мир, всего с начала, день")
    w("")
    w("| мир | " + " | ".join(p["name"] for p in PROFILES.values()) + " |")
    w("| --- | " + " | ".join("---" for _ in PROFILES) + " |")
    lpw = c["LEVELS_PER_WORLD"]
    for wd in range(1, R.world_of(max_level) + 1):
        cells = []
        for k in PROFILES:
            nr, mins, tot, days = [], [], [], []
            for r in res[k]:
                L = r["levels"].get(wd * lpw)
                prev = r["levels"].get((wd - 1) * lpw)
                if not L or (wd > 1 and not prev):
                    nr.append(INF); mins.append(INF); tot.append(INF); days.append(INF)
                    continue
                nr.append(L["cum_runs"] - (prev["cum_runs"] if prev else 0))
                mins.append(L["cum_min"] - (prev["cum_min"] if prev else 0))
                tot.append(L["cum_min"])
                days.append(L["day"])
            if _med(nr) == INF:
                cells.append("не дошёл")
                continue
            cells.append(f"{_med(nr)} заездов · {fmt_min(_med(mins))} (всего {fmt_min(_med(tot))}, день {_med(days)})")
        w(f"| {wd} {c['THEMES'][(wd - 1) % len(c['THEMES'])]['name']} | " + " | ".join(cells) + " |")
    w("")
    # --- подробно по профилям (раскладка 0)
    for k, p in PROFILES.items():
        r = res[k][0]
        w(f"### {p['name']}: по уровням (раскладка 0)")
        w("")
        w("| ур. | заездов | время на ур. | всего заездов | всего игры | монет/заезд | Р/С/Д/№ ракеты после финиша | бонус саней / след |")
        w("| --- | --- | --- | --- | --- | --- | --- | --- |")
        for lv in range(1, max_level + 1):
            L = r["levels"].get(lv)
            if not L:
                break
            star = " ★" if L["runs"] > TARGET[1] else ""
            w(f"| {lv} | {L['runs']}{star} | {fmt_min(L['minutes'])} | {L['cum_runs']} | {fmt_min(L['cum_min'])} | "
              f"{L['coins_run']:.0f} | {fmt_up(L['up'])} | +{L['sb'] * 100:.0f}% / {c['TRAILS'][L['trail']]['name']} |")
        w("")
        w(f"Апгрейды по времени ({p['name']}, раскладка 0):")
        w("")
        w("| минута игры | заездов | уровень | Р/С/Д/№ ракеты | монет за последний заезд | бонус саней / след |")
        w("| --- | --- | --- | --- | --- | --- |")
        for sn in r["snaps"]:
            w(f"| {sn['min']} | {sn['run']} | {sn['lv']} | {fmt_up(sn['up'])} | {sn['coins_run']} | +{sn['sb'] * 100:.0f}% / {c['TRAILS'][sn['trail']]['name']} |")
        w("")
        first = [x for x in r["log"] if x["t"] <= 20 * 60]
        buys = [x for x in first if x["bought"]]
        n_buys = sum(len(x["bought"].replace("💎", "")) for x in first)
        gaps = [b["run"] - a["run"] for a, b in zip(buys, buys[1:])]
        w(f"Первые 20 мин: {len(first)} заездов, {n_buys} покупок, заездов между покупками — "
          f"медиана {_med(gaps) if gaps else '—'}, максимум {max(gaps) if gaps else '—'}. "
          f"Первые 12 заездов (№: % уровня, монет, [покупки: L/S/I — Рогатка/Сани/Доход, строчная+💎 — тир или ракета, s — сани, t — след]): " +
          ", ".join(f"{x['run']}: {x['pct']}%{'✔' if x['fin'] else ''} {x['earned']} [{x['bought'] or '—'}]" for x in r["log"][:12]))
        w("")
    # --- стены
    w(f"### Стены (медиана заездов на уровень > {TARGET[1]})")
    w("")
    for k, p in PROFILES.items():
        walls, easy = [], []
        for lv in range(1, max_level + 1):
            n = lv_stat(k, lv, "runs")
            if n == INF:
                break
            if n > TARGET[1]:
                walls.append((lv, n, lv_stat(k, lv, "econ")))
            elif n < TARGET[0]:
                easy.append(lv)
        hours = _med([r["hours"] for r in res[k]])
        days = _med([r["days"] for r in res[k]])
        top = _med([max(r["levels"]) + 1 if r["levels"] else 1 for r in res[k]])
        w(f"- **{p['name']}**: уровень {top} за {hours:.1f} ч игры ({days} дн.); стены: " +
          (", ".join(f"ур. {lv} — {n} (апгрейдов хватило с {e}-го)" for lv, n, e in walls) or "нет") +
          f"; меньше {TARGET[0]} заездов: {len(easy)} из {max_level} уровней.")
    w("")
    return "\n".join(out), res


def summary(R: Rules, max_level: int, variants: int = 5) -> str:
    """Короткая сводка для сравнения сценариев (--set): по профилю — доля уровней в цели, медианы."""
    lpw = R.c["LEVELS_PER_WORLD"]
    rows = []
    for k, p in PROFILES.items():
        rs = [play(R, k, max_level, variant=v) for v in range(variants)]
        per = []
        for lv in range(1, max_level + 1):
            per.append(_med([r["levels"][lv]["runs"] if lv in r["levels"] else float("inf") for r in rs]))
        inside = sum(TARGET[0] <= n <= TARGET[1] for n in per)
        walls = sum(n > TARGET[1] for n in per)

        def world_t(wd):
            m = _med([r["levels"][wd * lpw]["cum_min"] if wd * lpw in r["levels"] else float("inf") for r in rs])
            return fmt_min(m) if m != float("inf") else "—"
        bands = []
        for a, b in ((1, 5), (6, 15), (16, max_level)):
            xs = [n for n in per[a - 1:b] if n != float("inf")]
            bands.append(f"{sum(xs) / len(xs):.1f}" if xs else "—")
        rows.append(f"| {p['name']} | {inside}/{max_level} | {walls} | {' / '.join(bands)} | "
                    f"{world_t(1)} / {world_t(3)} / {world_t(R.world_of(max_level))} |")
    head = ("| профиль | уровней в 3–5 | стен > 5 | ср. заездов на ур. 1–5 / 6–15 / 16+ | время до конца мира 1 / 3 / последнего |\n"
            "| --- | --- | --- | --- | --- |")
    return head + "\n" + "\n".join(rows)


def apply_set(cfg: dict, expr: str):
    """--set F.finishPerLevel=60 / UPGRADES.Income.BaseCost=300 / UPGRADE_PRICE_POW=2.4 — только в модели."""
    path, val = expr.split("=", 1)
    if path in ("levelLength.base", "levelLength.step"):
        base, step = cfg.get("_levelLength") or tuple(_fn_numbers(cfg["_src"], "levelLength")[i] for i in (0, 2))
        cfg["_levelLength"] = (float(val), step) if path.endswith("base") else (base, float(val))
        return
    keys = path.split(".")
    node = cfg
    for k in keys[:-1]:
        node = node[int(k) - 1] if isinstance(node, list) else node[k]
    last = keys[-1]
    v = float(val)
    v = int(v) if v.is_integer() and "." not in val else v
    if isinstance(node, list):
        node[int(last) - 1] = v
    else:
        if last not in node:
            raise SystemExit(f"--set: нет поля {path} в Config")
        node[last] = v


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--levels", type=int, default=35)
    ap.add_argument("--variants", type=int, default=5, help="раскладок трассы на уровень (медиана)")
    ap.add_argument("--write", action="store_true", help="обновить авто-блок docs/ECONOMY_SIM.md")
    ap.add_argument("--set", action="append", default=[], metavar="ПОЛЕ=ЧИСЛО",
                    help="подменить число Config только в модели (можно несколько): F.finishPerLevel=60")
    ap.add_argument("--decel", type=float, help=f"калибровка: добавка к трению, studs/с² (сейчас {CALIB['extra_decel']})")
    ap.add_argument("--miss", type=float, default=1.0, help="множитель шанса аварии всех профилей")
    ap.add_argument("--soft", type=float, help=f"калибровка: «мягких» ударов (щит/TNT) на одну аварию (сейчас {CALIB['soft_share']})")
    ap.add_argument("--summary", action="store_true", help="только короткая сводка (сравнение сценариев)")
    a = ap.parse_args()
    cfg = load_config()
    for e in a.set:
        apply_set(cfg, e)
    if a.decel is not None:
        CALIB["extra_decel"] = a.decel
    if a.soft is not None:
        CALIB["soft_share"] = a.soft
    for p in PROFILES.values():
        p["miss"] *= a.miss
    R = Rules(cfg)
    if a.summary:
        print(summary(R, a.levels, a.variants))
        return
    if a.set or a.decel is not None or a.soft is not None or a.miss != 1.0:
        if a.write:
            raise SystemExit("--write только с числами Config как есть (без --set/--decel/--soft/--miss)")
    text, _ = report(R, a.levels, a.variants)
    print(text)
    if a.write:
        body = AUTO_BEGIN + "\n" + text + "\n" + AUTO_END
        if os.path.exists(DOC_PATH):
            doc = open(DOC_PATH, encoding="utf-8").read()
            if AUTO_BEGIN in doc and AUTO_END in doc:
                doc = doc[: doc.index(AUTO_BEGIN)] + body + doc[doc.index(AUTO_END) + len(AUTO_END):]
            else:
                doc = doc.rstrip() + "\n\n" + body + "\n"
        else:
            doc = "# Симуляция экономики\n\n" + body + "\n"
        open(DOC_PATH, "w", encoding="utf-8").write(doc)
        print(f"\n→ {os.path.relpath(DOC_PATH, ROOT)}", file=sys.stderr)


if __name__ == "__main__":
    main()
