#!/usr/bin/env python3
"""Звуки игры v2 (#52): реальные записи (CC0 / CC BY 4.0) + синтез там, где он уместен → один «атлас»
assets/audio/sfx_atlas_v2.ogg.

Почему атлас: Open Cloud разрешает загрузить через ключ всего 10 аудио в месяц без ID-верификации
(100 — с верификацией; create.roblox.com/docs/cloud/guides/usage-assets), и загруженное аудио нельзя
обновить. Все звуки лежат в одном файле подряд с паузами, клиент играет нужный кусок через
Sound.PlaybackRegion, лупы — через Sound.LoopRegion. Карта кусков (start/len, loop, src) →
assets/audio/atlas.json и src/shared/AudioIds.luau.

Источники — assets/audio/sources/ (лицензии и авторы — assets/audio/README.md):
  kenney/    — Kenney «Impact Sounds» и «RPG Audio», CC0 (реальные фоли-записи);
  oculus/    — Oculus Audio Pack 1 (© 2015 Oculus VR, LLC), CC BY 4.0 — нужна строка в титрах;
  freesound/ — felix.blume, «Wind on bushes…» (freesound.org/s/711106), CC0.
Синтез (numpy/scipy) остался только для райзера нового тира, свиста падения, хлопков ракеты, гудка
и как тонкий слой «звона» поверх записей монет/колец.

Громкость: one-shot выравниваются по средней громкости звучащей части (RMS −16 dBFS), пик ≤ −1.5 dBFS
до кодирования (после Vorbis ≤ −1 dBFS проверяется); лупы — RMS −22 dBFS, их громкость ведёт код
(Config.SOUND). Лупы склеиваются кроссфейдом и сами по себе бесшовные. Скольжение по снегу/льду/
асфальту — не шум, а грануляция реальных записей (сотни коротких кусочков хруста снега, скрежета
волочения), поэтому не повторяется и не звучит как «белый шум».

    python3 scripts/gen_audio.py            # атлас + atlas.json + AudioIds.luau (id сохраняется)
    python3 scripts/gen_audio.py --preview  # ещё PNG-сводка волн/спектрограмм (assets/audio/preview.png)
"""
import json
import pathlib
import subprocess
import sys
import tempfile
import wave

import numpy as np
from scipy import signal

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from audio_ids import ATLAS, MAP, OUT, ROOT, write_luau  # noqa: E402

SR = 44100
GAP = 0.12  # тишина между кусками, с
PEAK_DB = -1.5
RMS_SHOT = -16.0  # средняя громкость звучащей части one-shot
RMS_LOOP = -22.0  # лупы тише: их громкость ведёт код
SRC = OUT / "sources"

rng = np.random.default_rng(20261108)  # детерминизм: один и тот же атлас при каждом запуске


# ------------------------------------------------------------------ примитивы синтеза
def t_(dur):
    return np.arange(int(dur * SR)) / SR


def env(dur, a=0.005, d=None, curve=4.0):
    """Атака a, затем экспоненциальный спад до конца (curve — крутизна)."""
    n = int(dur * SR)
    na = max(1, int(a * SR))
    e = np.ones(n)
    e[:na] = np.linspace(0, 1, na)
    rest = n - na
    if rest > 0:
        e[na:] = np.exp(-curve * np.linspace(0, 1, rest)) if d is None else np.exp(-np.arange(rest) / SR / d)
    return e


def fade_out(x, sec=0.01):
    n = min(len(x), int(sec * SR))
    if n:
        x[-n:] *= np.linspace(1, 0, n)
    return x


def fade_in(x, sec=0.002):
    n = min(len(x), int(sec * SR))
    if n:
        x[:n] *= np.linspace(0, 1, n)
    return x


def sine_sweep(f0, f1, dur, kind="exp"):
    t = t_(dur)
    f = f0 * (f1 / f0) ** (t / dur) if kind == "exp" else f0 + (f1 - f0) * t / dur
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def noise(dur):
    return rng.standard_normal(int(dur * SR))


def pink(dur):
    n = int(dur * SR)
    w = np.fft.rfft(rng.standard_normal(n))
    f = np.fft.rfftfreq(n, 1 / SR)
    f[0] = 1
    return np.fft.irfft(w / np.sqrt(f), n)


def brown(dur):
    x = np.cumsum(rng.standard_normal(int(dur * SR)))
    x = signal.lfilter([1, -1], [1, -0.995], x)  # убрать дрейф
    return x / (np.abs(x).max() + 1e-9)


def bp(x, lo, hi, order=2):
    sos = signal.butter(order, [lo, hi], "bandpass", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def lp(x, f, order=2):
    return signal.sosfilt(signal.butter(order, f, "lowpass", fs=SR, output="sos"), x)


def hp(x, f, order=2):
    return signal.sosfilt(signal.butter(order, f, "highpass", fs=SR, output="sos"), x)


def sweep_bp(x, f0, f1, q=3.0, steps=48):
    """Полосовой фильтр, центр которого плывёт f0→f1 (по блокам) — «вуш»."""
    out = np.zeros_like(x)
    n = len(x)
    edges = np.linspace(0, n, steps + 1).astype(int)
    zi = None
    for i in range(steps):
        fc = f0 * (f1 / f0) ** (i / (steps - 1))
        bw = fc / q
        sos = signal.butter(2, [max(20, fc - bw / 2), min(SR / 2 - 100, fc + bw / 2)], "bandpass", fs=SR, output="sos")
        if zi is None or zi.shape[0] != sos.shape[0]:
            zi = np.zeros((sos.shape[0], 2))
        seg, zi = signal.sosfilt(sos, x[edges[i]:edges[i + 1]], zi=zi)
        out[edges[i]:edges[i + 1]] = seg
    return out


def bell(freq, dur, partials=((1, 1), (2.76, 0.4), (5.4, 0.2), (8.9, 0.08)), decay=None):
    """Колокольчик: негармонические обертоны, верхние гаснут быстрее."""
    t = t_(dur)
    x = np.zeros_like(t)
    for ratio, amp in partials:
        d = (decay or dur / 3) / ratio ** 0.5
        x += amp * np.sin(2 * np.pi * freq * ratio * t) * np.exp(-t / d)
    return x * env(dur, a=0.002, curve=0.5)


def tone(freq, dur, shape="sine", a=0.004, curve=5.0, bright=0.5):
    t = t_(dur)
    ph = 2 * np.pi * freq * t
    if shape == "sine":
        x = np.sin(ph)
    elif shape == "square":  # мягкий «квадрат» из нечётных гармоник
        x = sum(np.sin(k * ph) / k * bright ** ((k - 1) / 2) for k in range(1, 12, 2))
    else:
        raise ValueError(shape)
    return x * env(dur, a=a, curve=curve)


def mix(*parts, length=None):
    """parts: (сигнал, задержка_с, громкость)."""
    n = length and int(length * SR) or max(int(d * SR) + len(s) for s, d, _ in parts)
    out = np.zeros(n)
    for s, d, g in parts:
        i = int(d * SR)
        m = min(len(s), n - i)
        if m > 0:
            out[i:i + m] += s[:m] * g
    return out


def note(n):  # полутоны от A4
    return 440.0 * 2 ** (n / 12)


def clicks(dur, rate, lo, hi, amp_jitter=0.7):
    """Случайные короткие щелчки (треск)."""
    n = int(dur * SR)
    x = np.zeros(n)
    k = rng.poisson(rate * dur)
    for i in rng.integers(0, n, k):
        x[i] = rng.uniform(1 - amp_jitter, 1) * rng.choice([-1, 1])
    return bp(x, lo, hi)


def loopify(x, xfade=0.25):
    """Бесшовный луп: хвост длиной xfade накладывается на начало (равномощный кроссфейд)."""
    n = int(xfade * SR)
    body, tail = x[:-n].copy(), x[-n:]
    w = np.linspace(0, np.pi / 2, n)
    body[:n] = body[:n] * np.sin(w) + tail * np.cos(w)
    return body


def lfo(dur, hz, depth, phase=0.0):
    return 1 - depth + depth * 0.5 * (1 + np.sin(2 * np.pi * hz * t_(dur) + phase))


# ------------------------------------------------------------------ записи
def decode(path):
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", str(path), "-f", "s16le", "-ac", "1", "-ar", str(SR), "-"],
                         check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype="<i2").astype(np.float64) / 32768


_cache = {}


def load(rel):
    if rel not in _cache:
        x = decode(SRC / rel)
        _cache[rel] = x - np.mean(x)
    return _cache[rel].copy()


def speed(x, r):
    """Смена скорости (r > 1 — выше и короче), как Sound.PlaybackSpeed."""
    if r == 1.0:
        return x
    return np.interp(np.arange(0, len(x) - 1, r), np.arange(len(x)), x)


def active(x, db=-45.0):
    """Индексы начала и конца звучащей части (огибающая выше пика + db)."""
    e = np.convolve(np.abs(x), np.ones(220) / 220, "same")
    idx = np.where(e > e.max() * 10 ** (db / 20))[0]
    return (int(idx[0]), int(idx[-1]) + 1) if len(idx) else (0, len(x))


def rec(rel, start=0.0, dur=None, rate=1.0, hpf=None, lpf=None, fade=0.02, trim_db=-48.0):
    """Кусок записи: с start (с), длиной dur (или до конца звучания), с фильтрами и короткими фейдами."""
    x = load(rel)[int(start * SR):]
    x = speed(x, rate)
    if dur:
        x = x[:int(dur * SR)]
    else:
        a, b = active(x, trim_db)
        x = x[:b]
    if hpf:
        x = hp(x, hpf)
    if lpf:
        x = lp(x, lpf)
    return fade_out(fade_in(x.copy()), fade)


def unit(x):
    return x / (np.sqrt(np.mean(x[slice(*active(x, -30))] ** 2)) + 1e-12)


def granular(sources, dur, density, glen=(0.04, 0.1), pitch=(0.92, 1.08), gain=(0.5, 1.0), db=-30.0):
    """Текстура из коротких кусочков записей (грануляция): density кусочков в секунду, у каждого своя
    длина, тон и громкость; окно Ханна — без щелчков. Источники берутся только из звучащей части."""
    pool = []
    for s in sources:
        x = unit(s)
        a, b = active(x, db)
        pool.append(x[a:b])
    n = int(dur * SR)
    out = np.zeros(n)
    for _ in range(rng.poisson(density * dur)):
        src = pool[rng.integers(len(pool))]
        L = int(rng.uniform(*glen) * SR)
        r = rng.uniform(*pitch)
        need = int(L * r) + 2
        if len(src) <= need:
            continue
        o = rng.integers(0, len(src) - need)
        g = speed(src[o:o + need], r)[:L] * np.hanning(L) * rng.uniform(*gain) * rng.choice([-1, 1])
        p = rng.integers(0, n)
        m = min(L, n - p)
        out[p:p + m] += g[:m]
        if m < L:  # хвост — в начало: текстура сразу бесшовная по кругу
            out[:L - m] += g[m:]
    return out


# ------------------------------------------------------------------ звуки
S = {}  # имя → (сигнал, loop: bool, описание, источник)
OC, KE, FS, SY = "Oculus CC BY", "Kenney CC0", "felix.blume CC0", "синтез"


def add(name, x, desc, src, loop=False, rms=None):
    S[name] = (np.asarray(x, dtype=np.float64), loop, desc, src, rms)


def o(n, **k):
    return rec(f"oculus/{n}.ogg", **k)


def k(n, **kw):
    return rec(f"kenney/{n}.ogg", **kw)


SNOW_RUN = [o(f"FEETHmn_ShoeSnowRun_OS_0{i}") for i in range(1, 6)]
SNOW_WALK = [o(f"FEETHmn_ShoeSnowWalk_OS_0{i}") for i in (1, 2, 4)]
SNOW_K = [k(f"footstep_snow_00{i}") for i in range(5)]
WOOD_L = [k(f"impact_wood_light_00{i}") for i in range(5)]


def debris(dur, n, gain=0.5, spread=0.35):
    """Разлёт обломков: несколько лёгких деревянных стуков с затуханием."""
    parts = []
    for i in range(n):
        d = spread * (i / max(1, n - 1)) ** 1.3 + rng.uniform(0, 0.03)
        parts.append((speed(WOOD_L[rng.integers(5)], rng.uniform(0.9, 1.25)), d, gain * (1 - 0.6 * i / n)))
    return mix(*parts, length=dur)


# --- UI
add("click", o("UIClick_CasualPopsConfirm_OS_01", dur=0.16, fade=0.04),
    "клик кнопки: мягкий «поп» (Casual Pops Confirm), 0.16 с", OC)
add("open", o("UIClick_CasualOpen_OS_01", dur=0.36, fade=0.08),
    "открытие окна: «поп-вжик» вверх (Casual Open), 0.36 с", OC)
add("deny", o("UIAlert_CasualPopsError_OS_01", dur=0.34, fade=0.06),
    "«нет»: двойной глухой поп вниз (Casual Pops Error), 0.34 с", OC)
add("buy", mix((k("handleCoins", start=0.04, dur=0.45, fade=0.12), 0, 1.0), (bell(note(22), 0.3, decay=0.1), 0.02, 0.05)),
    "покупка: горсть настоящих монет в ладони + тихий «дзынь», 0.45 с", KE + " + " + SY)

# --- награды в лобби
add("claim", o("UIMisc_BelltreeUp_OS_01", dur=0.9, fade=0.4),
    "забрать награду: глиссандо «бель-три» вверх (настоящий инструмент), 0.9 с", OC)
add("chest", mix((o("OBJLug_CaseOpen_OS_01", dur=0.36), 0, 1.0), (k("handleCoins", start=0.04, dur=0.5, fade=0.15), 0.22, 0.9),
                 (o("UIMisc_BelltreeUp_OS_01", dur=0.8, fade=0.4), 0.25, 0.45)),
    "сундук: щелчок замков и крышка кейса → звон монет и «бель-три», 1.05 с", OC + " + " + KE)
add("ready", o("UIAlert_Notification_OS_02", dur=0.7, fade=0.3),
    "подарок готов: светлое уведомление-колокольчик, 0.7 с", OC)
add("task", o("MUSCStngr_LevelUpMallet_OS_01", dur=1.9, fade=0.5),
    "задание выполнено: стингер на маримбе «level up», 1.9 с", OC)
riser = sweep_bp(pink(1.0), 300, 7000, q=1.5) * np.linspace(0, 1, int(SR * 1.0)) ** 2
add("reveal", mix((riser, 0, 0.8), (sine_sweep(110, 440, 1.0) * np.linspace(0, 1, int(SR * 1.0)) ** 2 * 0.4, 0, 1)),
    "новый тир, вход: нарастающий «райзер» 0.3→7 кГц с тоном 110→440 Гц, 1.0 с", SY)
add("tierup", o("MUSCStngr_LevelUpOrchestral_OS_01", dur=1.6, fade=0.4),
    "новый тир, смена модели: оркестровый стингер «level up», 1.6 с", OC)

# --- подбор на трассе
coin_hit = o("OBJCoin_CoinDrop_OS_01", dur=0.2, fade=0.08)
add("coin", mix((coin_hit, 0, 1.0), (bell(note(26), 0.25, decay=0.07), 0.0, 0.06)),
    "монета: звон настоящей монеты + еле слышный «дзынь» для читаемости, 0.25 с (серия поднимает тон)", OC + " + " + SY)
add("gem", mix((k("impact_glass_light_000"), 0, 1.0), (speed(k("impact_glass_light_001"), 1.5), 0.05, 0.6),
               (bell(note(31), 0.45, partials=((1, 1), (2.0, 0.35), (3.01, 0.2)), decay=0.15), 0.0, 0.03)),
    "гем: двойной «тинь» стекла (записи) с лёгким отзвуком, 0.45 с", KE + " + " + SY)
add("crystal", mix((o("GLASBrk_WindowPaneSmallBreak_OS_01", dur=0.55, fade=0.2), 0, 1.0), (k("impact_glass_medium_000"), 0, 0.5)),
    "ледяной кристалл: лопнуло маленькое стекло — хруст и осколки, 0.55 с", OC + " + " + KE)
add("shield", o("MAGSpel_MagicSpell_OS_01", start=0.05, dur=1.1, fade=0.5),
    "щит: мерцающее «заклинание» — включение защиты, 1.1 с", OC)
add("shieldhit", mix((k("impact_metal_heavy_000"), 0, 0.8), (k("impact_glass_medium_000"), 0.01, 1.0), (k("impact_soft_heavy_000", lpf=400), 0, 0.6)),
    "щит спас: удар по металлу + лопнувшее стекло, 0.4 с", KE)
add("x2", o("UIMisc_Powerup_OS_01", dur=1.1, fade=0.4),
    "x2 монеты: восходящий «пауэр-ап», 1.1 с", OC)
add("magnet", o("UIMisc_Powerup_OS_02", dur=0.9, rate=0.85, fade=0.4),
    "магнит: «пауэр-ап» ниже тоном, 0.9 с", OC)
add("fuel", mix((o("WATRBubl_WaterBubbles_LOOP_01", start=0.3, dur=0.45, fade=0.15, lpf=3000), 0, 1.0), (k("metalClick"), 0.4, 0.8)),
    "канистра: бульканье жидкости + щелчок крышки, 0.65 с", OC + " + " + KE)
add("ring", mix((o("WHSH_WhooshSmall_OS_01"), 0, 1.0), (bell(note(19), 0.5, decay=0.18), 0.08, 0.12), (bell(note(14), 0.5, decay=0.18), 0.08, 0.08)),
    "кольцо: воздушный вуш (запись) + мягкий звон E6/B5, 0.55 с", OC + " + " + SY)
add("boost", mix((o("WHSH_WhooshMedium_OS_03", rate=0.75), 0, 1.0), (o("WHSH_WhooshMedium_OS_02", rate=1.15), 0.08, 0.7)),
    "ускоритель: двойной мощный вуш (записи), 0.4 с", OC)
add("spring", o("TOONBoing_BounceCartoony_OS_01", dur=0.5, fade=0.15),
    "трамплин островка: пружинное «бойнг», 0.5 с", OC)

# --- рогатка, прыжки, трюки
add("launch", mix((k("impact_plank_medium_000", dur=0.2), 0, 0.7), (o("WHSH_WhooshMedium_OS_02", rate=0.7), 0.02, 1.0),
                  (k("creak3", rate=1.6), 0, 0.5)),
    "выстрел рогатки: щелчок деревянной рамы + скрип отпущенной резины + вуш отлёта, 0.4 с", KE + " + " + OC)
add("jump", mix((SNOW_RUN[2][:int(0.16 * SR)], 0, 1.0), (o("WHSH_WhooshSmall_OS_01", rate=1.3), 0.03, 0.6)),
    "прыжок: толчок по снегу (хруст) + короткий вуш, 0.2 с", OC)
add("land", mix((o("FEETHmn_ShoeSnowLand_OS_02"), 0, 1.0), (k("impact_soft_heavy_000", lpf=500), 0, 0.5)),
    "приземление: настоящий снежный «пумф» — хруст наста + мягкий удар, 0.35 с", OC + " + " + KE)
add("spin", o("SWSH_Swoosh_OS_02", dur=0.42, fade=0.12),
    "вращение трюка: свист рассекаемого воздуха, 0.4 с", OC)
add("flip", o("UIClick_CasualMusicalConfirm_OS_01", dur=0.55, fade=0.25),
    "трюк засчитан: короткое музыкальное «та-да»; в комбо — на кварту выше за трюк", OC)
add("wipe", mix((k("impact_soft_heavy_001"), 0, 0.9), (o("FEETHmn_ShoeSnowLand_OS_01"), 0, 1.0),
                (o("UIAlert_CasualMusicalError_OS_01", dur=0.7, fade=0.3), 0.08, 0.35)),
    "трюк сорван: шлепок в снег + сползающая музыкальная «ошибка», 0.8 с", KE + " + " + OC)
add("smash", mix((k("impact_wood_heavy_000"), 0, 1.0), (k("impact_plank_medium_001", dur=0.3), 0.01, 0.6),
                 (o("FEETHmn_ShoeSnowLand_OS_01"), 0.0, 0.6), (debris(0.6, 5, 0.45), 0.06, 1.0)),
    "разбил препятствие: удар по дереву + разлёт щепок + снег, 0.65 с", KE + " + " + OC)
add("crash", mix((k("impact_punch_heavy_000"), 0, 1.0), (k("impact_wood_heavy_001"), 0.0, 0.8), (k("impact_metal_heavy_000"), 0.02, 0.5),
                 (o("FEETHmn_ShoeSnowLand_OS_02"), 0.03, 0.8), (debris(0.8, 6, 0.4, 0.5), 0.08, 1.0)),
    "авария: тяжёлый удар корпусом + дерево и металл, снег, разлёт обломков, 0.9 с", KE + " + " + OC)
t = t_(1.3)
fall_wind = rec("freesound/felix.blume_711106_wind_cut.ogg", start=2.0, dur=1.3, hpf=300, lpf=3000) * env(1.3, a=0.25, curve=1.5)
add("fall", mix((np.sin(2 * np.pi * np.cumsum(1400 * (160 / 1400) ** (t / 1.3)) / SR) * env(1.3, a=0.02, curve=1.5), 0, 0.25),
                (unit(fall_wind) * 0.12, 0, 1.0)),
    "падение в пропасть: порыв ветра (запись) + тихий свист вниз 1.4 кГц→160 Гц, 1.3 с", FS + " + " + SY)
add("rocket_on", mix((lp(noise(0.08), 1200) * env(0.08, a=0.001), 0, 0.25), (sweep_bp(pink(0.5), 200, 3000, q=1.2) * env(0.5, a=0.02, curve=1.5), 0, 6),
                     (o("WHSH_WhooshMedium_OS_03", rate=0.6), 0, 0.5)),
    "ракета: поджиг — хлопок + нарастающее шипение и вуш, 0.5 с", SY + " + " + OC)
add("rocket_off", mix(*[(lp(noise(0.06), 1500) * env(0.06, a=0.001, curve=5), d, g) for d, g in ((0, 0.8), (0.12, 0.55), (0.22, 0.35), (0.3, 0.2))]),
    "ракета: «пых-пых» — четыре затухающих хлопка, 0.4 с", SY)
add("finish", o("MUSCStngr_VictoryOrchestral_OS_01", dur=2.3, fade=0.5),
    "финиш: оркестровая фанфара победы, 2.3 с", OC)
add("record", o("MUSCStngr_VictoryMallet_OS_01", dur=2.4, fade=0.6),
    "рекорд: победный стингер на маримбе, 2.4 с", OC)
add("horn", lp(tone(note(-4), 0.22, "square", bright=0.6, a=0.01, curve=0.5) + tone(note(0), 0.22, "square", bright=0.6, a=0.01, curve=0.5), 1800) * 0.5,
    "гудок машины: два тона F4+A4, 0.22 с — играется дважды «би-бип»", SY)

# --- лупы (бесшовные)
wind = rec("freesound/felix.blume_711106_wind_cut.ogg", dur=16.0, hpf=110, lpf=2200, fade=0.001)
add("wind", loopify(wind, 1.0),
    "луп ветра: настоящий ветер с порывами (felix.blume, Freesound 711106, CC0), без верхов >2.2 кГц, 15 с", FS, loop=True)

LS = 5.4  # длина сырья лупов скольжения (после loopify 5 с)
snow_tex = granular(SNOW_RUN + SNOW_WALK + SNOW_K, LS, 55, glen=(0.05, 0.14), pitch=(0.85, 1.05))
snow_body = granular(SNOW_K + SNOW_WALK, LS, 18, glen=(0.15, 0.3), pitch=(0.7, 0.85))
add("snow", loopify(lp(snow_tex, 5000, 4) * 0.8 + lp(snow_body, 1500) * 0.6, 0.4),
    "луп снега: полозья по снегу — грануляция записей хруста снега (55 кусочков/с) + мягкий низ, 5 с", OC + " + " + KE, loop=True)
ice_tex = granular(SNOW_RUN, LS, 45, glen=(0.03, 0.08), pitch=(1.0, 1.25), gain=(0.3, 0.8))
ice_crk = granular([k("impact_glass_light_000"), k("impact_glass_light_001")], LS, 2.5, glen=(0.03, 0.06), pitch=(1.2, 1.8), gain=(0.2, 0.5))
add("ice", loopify(lp(hp(ice_tex, 2500), 7000, 4) * 0.9 + hp(ice_crk, 2000) * 0.25 + lp(snow_body, 1200) * 0.25, 0.4),
    "луп льда: лёгкий шелест лезвия (грануляция снега 2.5–7 кГц) + редкий треск льда, 5 с", OC + " + " + KE, loop=True)
drag = o("WOODFric_LargeWoodMetalDrag_OS_01", start=0.1, dur=2.5)
hard_tex = granular([drag], LS, 24, glen=(0.2, 0.4), pitch=(0.85, 1.1))
hard_grv = granular([o(f"FEETHmn_ShoeConcreteRun_OS_0{i}") for i in (1, 2, 3)], LS, 30, glen=(0.02, 0.06), pitch=(0.8, 1.1), gain=(0.2, 0.6))
add("hard", loopify(lp(hard_tex, 4000) + lp(hard_grv, 3500) * 0.5, 0.4),
    "луп асфальта/камня/дерева: скрежет волочения (запись) + шорох гравия, 5 с", OC, loop=True)
L = 3.3
roar = speed(rec("freesound/felix.blume_711106_wind_cut.ogg", start=4.0, dur=6.0, lpf=1200, fade=0.001), 0.55)[:int(L * SR)]
add("rocket", loopify(unit(roar) * 0.7 + unit(lp(brown(L), 300)) * 0.5 + clicks(L, 300, 800, 4000) * 1.5, 0.3),
    "луп ракеты: рёв — замедленная запись ветра + низкий гул + треск, 3 с", FS + " + " + SY, loop=True)
creaks = [k("creak1"), k("creak2"), k("creak3")]
add("stretch", loopify(lp(granular(creaks, L, 14, glen=(0.15, 0.35), pitch=(0.8, 1.0)), 3500), 0.3),
    "луп натяжения рогатки: скрип натягиваемой резины/дерева (грануляция записей скрипа), 3 с (тон растёт с натяжением)", KE, loop=True)
add("car", o("VEHCar_CarEngineSlow_LOOP_01", dur=None, fade=0.001, trim_db=-90),
    "луп мотора машины (3D): запись двигателя на холостых, 4.2 с", OC, loop=True)
add("train", loopify(o("TRNElec_TrainPassby_OS_01_cut", dur=9.0, fade=0.001), 0.6),
    "луп поезда (3D): ровный участок записи проезда электрички — гул и стыки, 8.4 с", OC, loop=True)

UI_MAX = {"click": 0.2, "open": 0.5, "deny": 0.5, "buy": 0.5}


# ------------------------------------------------------------------ сборка атласа
def normalize(x, loop, rms=None):
    x = x - np.mean(x)
    target = rms if rms is not None else (RMS_LOOP if loop else RMS_SHOT)
    a, b = (0, len(x)) if loop else active(x, -30)
    g = 10 ** (target / 20) / (np.sqrt(np.mean(x[a:b] ** 2)) + 1e-12)
    peak_cap = 10 ** ((-3.0 if loop else PEAK_DB) / 20) / (np.abs(x).max() + 1e-12)
    return x * min(g, peak_cap)


def build():
    OUT.mkdir(parents=True, exist_ok=True)
    chunks, regions, pos = [], {}, GAP
    chunks.append(np.zeros(int(GAP * SR)))
    for name, (x, loop, desc, src, rms) in S.items():
        if not loop:
            x = fade_out(x.copy(), 0.008)
        x = normalize(x, loop, rms)
        dur = len(x) / SR
        if name in UI_MAX:
            assert dur <= UI_MAX[name] + 1e-6, f"{name}: UI-звук {dur:.3f} с > {UI_MAX[name]} с"
        regions[name] = {"start": round(pos, 4), "len": round(dur, 4), "loop": loop, "src": src, "desc": desc}
        chunks.append(x)
        chunks.append(np.zeros(int(GAP * SR)))
        pos += dur + GAP
    full = np.concatenate(chunks)
    with tempfile.TemporaryDirectory() as td:
        wav = pathlib.Path(td) / "atlas.wav"
        with wave.open(str(wav), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((np.clip(full, -1, 1) * 32767).astype("<i2").tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "6",
                        "-map_metadata", "-1", "-fflags", "+bitexact", "-flags:a", "+bitexact", str(ATLAS)], check=True)
    dec = decode(ATLAS)
    for name, r in regions.items():
        a, b = int(r["start"] * SR), int((r["start"] + r["len"]) * SR)
        seg = dec[a:b]
        r["peak_db"] = round(20 * np.log10(np.abs(seg).max() + 1e-12), 2)
        r["rms_db"] = round(20 * np.log10(np.sqrt(np.mean(seg ** 2)) + 1e-12), 1)
        if not r["loop"]:
            assert r["peak_db"] <= -1.0, f"{name}: пик после Vorbis {r['peak_db']} dBFS > −1"
    MAP.write_text(json.dumps({"file": ATLAS.name, "sr": SR, "length": round(len(full) / SR, 3), "regions": regions},
                              ensure_ascii=False, indent=1) + "\n")
    write_luau(regions)
    print(f"Атлас: {ATLAS.relative_to(ROOT)} — {len(regions)} звуков, {len(full) / SR:.1f} с, {ATLAS.stat().st_size // 1024} КБ")
    return regions, dec


def preview(regions, dec):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    names = list(regions)
    cols = 4
    rows = (len(names) + cols - 1) // cols
    fig, axes = plt.subplots(rows * 2, cols, figsize=(cols * 4.2, rows * 2.7), gridspec_kw={"height_ratios": [1, 1.4] * rows})
    for i, name in enumerate(names):
        r = regions[name]
        a, b = int(r["start"] * SR), int((r["start"] + r["len"]) * SR)
        x = dec[a:b]
        aw, asp = axes[(i // cols) * 2][i % cols], axes[(i // cols) * 2 + 1][i % cols]
        tt = np.arange(len(x)) / SR
        aw.plot(tt, x, lw=0.4, color="#2b6cb0")
        aw.axhline(10 ** (-1 / 20), color="#e53e3e", lw=0.5, ls="--")
        aw.axhline(-(10 ** (-1 / 20)), color="#e53e3e", lw=0.5, ls="--")
        aw.set_ylim(-1, 1)
        aw.set_xlim(0, max(tt[-1], 0.01))
        aw.set_title(f"{name}  {r['len']:.2f} с  пик {r['peak_db']}  rms {r['rms_db']}" + ("  [луп]" if r["loop"] else ""), fontsize=8)
        aw.tick_params(labelsize=6)
        asp.specgram(x + 1e-9, NFFT=512, Fs=SR, noverlap=384, cmap="magma", vmin=-120)
        asp.set_ylim(0, 12000)
        asp.tick_params(labelsize=6)
    for j in range(len(names), rows * cols):
        axes[(j // cols) * 2][j % cols].axis("off")
        axes[(j // cols) * 2 + 1][j % cols].axis("off")
    fig.suptitle("Звуки v2 (sfx_atlas_v2.ogg, после Vorbis): волна (красное — −1 dBFS) и спектрограмма 0–12 кГц", fontsize=11)
    fig.tight_layout(rect=(0, 0, 1, 0.985))
    png = OUT / "preview.png"
    fig.savefig(png, dpi=80)
    print(f"Сводка: {png}")


if __name__ == "__main__":
    regs, decoded = build()
    if "--preview" in sys.argv:
        preview(regs, decoded)
