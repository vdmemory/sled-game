#!/usr/bin/env python3
"""Синтез всех звуковых эффектов игры кодом (numpy/scipy) → один «атлас» assets/audio/sfx_atlas.ogg.

Почему атлас: Open Cloud разрешает загрузить через ключ всего 10 аудио в месяц без ID-верификации
(100 — с верификацией; create.roblox.com/docs/cloud/guides/usage-assets). Все звуки лежат в одном
файле подряд с паузами, клиент играет нужный кусок через Sound.PlaybackRegion, лупы — через
Sound.LoopRegion. Карта кусков (start/len, loop) → assets/audio/atlas.json и src/shared/AudioIds.luau.

Всё синтезировано здесь же — без чужих сэмплов, лицензия CC0 (assets/audio/README.md).
Пики one-shot нормализуются в −1.5 dBFS до кодирования (после Vorbis ≤ −1 dBFS проверяется),
UI-звуки ≤ 0.25 с. Лупы склеиваются кроссфейдом и сами по себе бесшовные.

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

rng = np.random.default_rng(20261108)  # детерминизм: один и тот же атлас при каждом запуске


# ------------------------------------------------------------------ примитивы
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
    elif shape == "saw":
        x = sum(np.sin(k * ph) / k * bright ** (k - 1) for k in range(1, 16))
    elif shape == "brass":
        x = sum(np.sin(k * ph) / k ** 1.2 for k in range(1, 10))
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


C5, E5, G5, A5, B5, C6, D6, E6, G6, C7 = (note(x) for x in (3, 7, 10, 12, 14, 15, 17, 19, 22, 27))


def karplus(freq, dur, damp=0.996):
    n = int(dur * SR)
    p = int(SR / freq)
    buf = rng.uniform(-1, 1, p)
    out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % p]
        buf[i % p] = damp * 0.5 * (buf[i % p] + buf[(i + 1) % p])
    return out


def clicks(dur, rate, lo, hi, amp_jitter=0.7):
    """Случайные короткие щелчки (хруст снега, обломки)."""
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


# ------------------------------------------------------------------ звуки
S = {}  # имя → (сигнал, loop: bool, описание)


def add(name, x, desc, loop=False):
    S[name] = (np.asarray(x, dtype=np.float64), loop, desc)


# --- UI (≤ 0.25 с)
add("click", mix((sine_sweep(1500, 700, 0.05) * env(0.05, a=0.001, curve=7), 0, 1),
                 (hp(noise(0.01), 3000) * env(0.01, a=0.0005), 0, 0.25)),
    "мягкий деревянный «ток»: синус 1.5→0.7 кГц, 50 мс")
add("open", mix((sweep_bp(noise(0.16), 500, 4000, q=2) * env(0.16, a=0.06, curve=3), 0, 0.6),
                (tone(note(7), 0.08, "sine", curve=4), 0.06, 0.5),
                (tone(note(14), 0.12, "sine", curve=5), 0.1, 0.6)),
    "открытие окна: короткий вуш вверх + блип E5→B5, 0.22 с")
add("deny", mix((tone(note(-5), 0.09, "square", bright=0.35, curve=2), 0, 0.7),
                (tone(note(-9), 0.12, "square", bright=0.35, curve=3), 0.1, 0.7)),
    "«нет»: два глухих низких тона вниз (E4→C4), 0.22 с")
add("buy", mix((hp(noise(0.012), 2500) * env(0.012, a=0.0005), 0, 0.5),
               (bell(note(22), 0.22, decay=0.12), 0.0, 0.6),
               (bell(note(27), 0.19, decay=0.1), 0.05, 0.7)),
    "покупка: «дзынь-дзынь» кассы, два колокольчика G6→C7, 0.25 с")

# --- награды в лобби
sparkle = mix(*[(bell(rng.uniform(2500, 5000), 0.18, decay=0.05), rng.uniform(0, 0.25), rng.uniform(0.2, 0.5)) for _ in range(9)], length=0.45)
add("claim", mix((sweep_bp(noise(0.3), 800, 6000, q=2) * env(0.3, a=0.12, curve=3), 0, 0.5), (sparkle, 0.05, 0.6)),
    "забрать награду: вуш вверх + рассыпанные искорки, 0.5 с")
rattle = mix(*[(lp(noise(0.035), 2500) * env(0.035, a=0.001, curve=6), i * 0.06, 0.8) for i in range(5)])
add("chest", mix((rattle, 0, 0.8),
                 (sine_sweep(140, 60, 0.18) * env(0.18, a=0.002, curve=5), 0.38, 0.9),
                 (sweep_bp(noise(0.35), 1500, 8000, q=2) * env(0.35, a=0.005, curve=4), 0.38, 0.45),
                 (bell(C6, 0.5), 0.4, 0.5), (bell(E6, 0.5), 0.43, 0.4), (bell(G6, 0.5), 0.46, 0.4), (bell(C7, 0.55), 0.5, 0.35)),
    "сундук: дребезг крышки (5 стуков) → хлопок и аккорд колокольчиков C-E-G-C, 1.05 с")
add("ready", mix((bell(G5, 0.5), 0, 0.6), (bell(C6, 0.6), 0.12, 0.7), (sparkle, 0.12, 0.4)),
    "подарок готов: два колокольчика G5→C6 и искорки, 0.7 с")
add("task", mix((tone(C5, 0.15, "square", bright=0.4), 0, 0.4), (tone(E5, 0.15, "square", bright=0.4), 0.09, 0.4),
                (tone(G5, 0.4, "square", bright=0.4, curve=3), 0.18, 0.45), (bell(C7, 0.4), 0.18, 0.25)),
    "задание выполнено: короткое арпеджио C-E-G (мягкий квадрат) + звон, 0.6 с")
riser = sweep_bp(pink(1.0), 300, 7000, q=1.5) * np.linspace(0, 1, int(SR * 1.0)) ** 2
add("reveal", mix((riser, 0, 0.8), (sine_sweep(110, 440, 1.0) * np.linspace(0, 1, int(SR * 1.0)) ** 2 * 0.4, 0, 1)),
    "новый тир, вход: нарастающий шумовой «райзер» 0.3→7 кГц с тоном 110→440 Гц, 1.0 с")
chord = mix(*[(tone(f, 1.4, "brass", a=0.01, curve=2.5), 0, 0.3) for f in (C5, E5, G5, C6)])
add("tierup", mix((lp(noise(0.08), 400) * env(0.08, a=0.001), 0, 0.8), (chord, 0, 1), (sparkle, 0.05, 0.5), (bell(C7, 0.9), 0.05, 0.3)),
    "новый тир, смена модели: удар + мажорный аккорд C (медь) + искры, 1.4 с")

# --- подбор на трассе
add("coin", mix((tone(B5, 0.07, "square", bright=0.25, a=0.001, curve=1.5), 0, 0.55),
                (tone(E6, 0.16, "square", bright=0.25, a=0.001, curve=4), 0.06, 0.55)),
    "монета: классический «бли-инь» B5→E6, 0.22 с (серия поднимает тон, см. Sounds)")
add("gem", mix((bell(note(31), 0.5, partials=((1, 1), (2.0, 0.35), (3.01, 0.2), (4.2, 0.1)), decay=0.25), 0, 0.7),
               (bell(note(38), 0.4, decay=0.15), 0.05, 0.35)),
    "гем: стеклянный колокольчик ~2.8 кГц с отзвуком, 0.55 с")
shards = clicks(0.5, 160, 3000, 11000) * env(0.5, a=0.001, curve=5)
add("crystal", mix((hp(noise(0.06), 2000) * env(0.06, a=0.0005), 0, 0.7), (shards, 0, 1.4),
                   *[(bell(rng.uniform(2200, 4200), 0.4, decay=0.1), rng.uniform(0, 0.15), 0.3) for _ in range(5)]),
    "ледяной кристалл: хрусткий звон стекла — щелчок + россыпь осколков + 5 тонких звонов, 0.6 с")
t = t_(0.6)
shimmer = np.sin(2 * np.pi * np.cumsum(350 * 2 ** (1.3 * t / 0.6) * (1 + 0.02 * np.sin(2 * np.pi * 18 * t))) / SR)
add("shield", mix((shimmer * env(0.6, a=0.05, curve=3) * (0.7 + 0.3 * np.sin(2 * np.pi * 14 * t)), 0, 0.6),
                  (bell(E6, 0.4), 0.2, 0.3)),
    "щит: «пузырь» — синус 350→860 Гц с тремоло 14 Гц, мягкий звон в конце, 0.6 с")
add("shieldhit", mix((sine_sweep(220, 90, 0.2) * env(0.2, a=0.001, curve=5), 0, 0.5),
                     (hp(noise(0.25), 3000) * env(0.25, a=0.001, curve=6), 0, 0.8),
                     (bell(note(19), 0.35, decay=0.08), 0, 0.4), (bell(note(26), 0.35, decay=0.06), 0.01, 0.3)),
    "щит спас: глухой удар + лопнувшее стекло, 0.4 с")
add("x2", mix((tone(C6, 0.1, "square", bright=0.3, curve=3), 0, 0.45), (tone(G6, 0.1, "square", bright=0.3, curve=3), 0.08, 0.45),
              (tone(C7, 0.3, "square", bright=0.3, curve=4), 0.16, 0.45), (sparkle, 0.1, 0.4)),
    "x2 монеты: быстрое восхождение C6-G6-C7 + искры, 0.55 с")
t = t_(0.6)
wob = signal.sawtooth(2 * np.pi * np.cumsum(220 * 2 ** (1.4 * t / 0.6)) / SR)
add("magnet", lp(wob * (0.55 + 0.45 * np.sin(2 * np.pi * 11 * t)), 2200) * env(0.6, a=0.02, curve=2.5),
    "магнит: «вуом-вуом» — пила 220→580 Гц с вибрацией 11 Гц через фильтр, 0.6 с")
glug = mix(*[(np.sin(2 * np.pi * np.cumsum(np.linspace(f, f * 1.7, int(0.07 * SR))) / SR) * env(0.07, a=0.003, curve=4), d, 0.7)
             for f, d in ((180, 0), (230, 0.09), (290, 0.18))])
add("fuel", mix((glug, 0, 1), (hp(noise(0.015), 2000) * env(0.015, a=0.0005), 0.33, 0.6), (bell(note(19), 0.25, decay=0.08), 0.33, 0.35)),
    "канистра: три «бульк» вверх + щелчок крышки, 0.55 с")
add("ring", mix((sweep_bp(noise(0.45), 600, 3500, q=2.5) * env(0.45, a=0.15, curve=3), 0, 0.7), (bell(E6, 0.5), 0.12, 0.45), (bell(B5, 0.5), 0.12, 0.3)),
    "кольцо: воздушный вуш + мягкий звон E6/B5, 0.6 с")
t = t_(0.5)
add("boost", mix((lp(signal.sawtooth(2 * np.pi * np.cumsum(180 * 2 ** (2.6 * t / 0.5)) / SR), 5000) * env(0.5, a=0.005, curve=3), 0, 0.45),
                 (sweep_bp(noise(0.5), 400, 5000, q=2) * env(0.5, a=0.02, curve=2.5), 0, 0.8)),
    "ускоритель: электрический «вжжух» — пила 180→1100 Гц + шумовой вуш, 0.5 с")
t = t_(0.55)
boing = np.sin(2 * np.pi * np.cumsum((140 + 260 * (t / 0.55) ** 0.5) * (1 + 0.12 * np.sin(2 * np.pi * 22 * t) * np.exp(-t * 4))) / SR)
add("spring", mix((boing * env(0.55, a=0.002, curve=3), 0, 0.8), (sweep_bp(noise(0.4), 500, 3000, q=2) * env(0.4, a=0.05, curve=3), 0.1, 0.35)),
    "трамплин островка: пружинное «бойнг» 140→400 Гц с дрожью + вуш, 0.55 с")

# --- рогатка, прыжки, трюки
add("launch", mix((karplus(98, 0.6, damp=0.993) * env(0.6, a=0.001, curve=3), 0, 0.9),
                  (sweep_bp(noise(0.55), 300, 2500, q=1.8) * env(0.55, a=0.03, curve=2.5), 0.03, 0.9),
                  (lp(noise(0.03), 600) * env(0.03, a=0.0005), 0, 0.7)),
    "выстрел рогатки: «тванг» резинки (щипок струны 98 Гц) + вуш отлёта, 0.65 с")
add("jump", mix((lp(noise(0.08), 1800) * env(0.08, a=0.002, curve=5), 0, 0.6),
                (sine_sweep(220, 520, 0.12) * env(0.12, a=0.002, curve=4), 0.01, 0.5)),
    "прыжок: снежный «пф» + короткий блип вверх 220→520 Гц, 0.14 с")
add("land", mix((sine_sweep(180, 70, 0.2) * env(0.2, a=0.001, curve=5), 0, 0.5),
                (lp(noise(0.3), 2500) * env(0.3, a=0.002, curve=5), 0, 0.9),
                (clicks(0.2, 300, 800, 4000) * env(0.2, a=0.001, curve=4), 0, 1.6)),
    "приземление: снежный «пумф» — шум до 2.5 кГц + хруст + удар 180→70 Гц, 0.3 с")
add("spin", sweep_bp(noise(0.32), 500, 2200, q=3) * np.sin(np.linspace(0, np.pi, int(0.32 * SR))) ** 2,
    "вращение трюка: воздушный свист-вуш, 0.32 с")
add("flip", mix((tone(G5, 0.1, "square", bright=0.35, curve=3), 0, 0.4), (tone(C6, 0.3, "square", bright=0.35, curve=3.5), 0.08, 0.45),
                (bell(G6, 0.3), 0.08, 0.25)),
    "трюк засчитан: «та-да» G5→C6; в комбо тон выше на кварту за каждый трюк")
wah = bp(signal.sawtooth(2 * np.pi * np.cumsum(np.linspace(420, 160, int(0.4 * SR))) / SR), 200, 1600) * env(0.4, a=0.01, curve=2)
add("wipe", mix((sine_sweep(170, 70, 0.25) * env(0.25, a=0.001, curve=4), 0, 0.45), (lp(noise(0.35), 2000) * env(0.35, a=0.002, curve=4), 0, 0.9),
                (wah, 0.05, 0.6)),
    "неудачное приземление трюка: шлепок в снег + сползающее «уа-а» 420→160 Гц, 0.45 с")
add("smash", mix((sine_sweep(200, 80, 0.15) * env(0.15, a=0.001, curve=4), 0, 0.4),
                 (lp(noise(0.3), 4000) * env(0.3, a=0.001, curve=6), 0, 1.0),
                 (clicks(0.4, 120, 600, 3500) * env(0.4, a=0.001, curve=3), 0.02, 3.0)),
    "разбил препятствие: короткий удар + громкий хруст и разлёт обломков (щелчки 0.6–3.5 кГц), 0.42 с")
add("crash", mix((sine_sweep(160, 50, 0.4) * env(0.4, a=0.001, curve=3), 0, 0.5),
                 (lp(brown(0.6), 1200) * env(0.6, a=0.001, curve=4), 0, 0.6),
                 (lp(noise(0.3), 5000) * env(0.3, a=0.0005, curve=5), 0, 1.0),
                 (clicks(0.7, 80, 500, 3000) * env(0.7, a=0.001, curve=2.5), 0.05, 3.0),
                 (tone(note(-12), 0.35, "square", bright=0.4, curve=3), 0.12, 0.45)),
    "авария: тяжёлый удар 160→50 Гц, шумовой хлопок, хруст и разлёт обломков, «бонк» A3, 0.75 с")
t = t_(1.3)
add("fall", np.sin(2 * np.pi * np.cumsum(1400 * (160 / 1400) ** (t / 1.3)) / SR) * env(1.3, a=0.02, curve=1.5) * 0.6
    + sweep_bp(noise(1.3), 2500, 300, q=2) * env(1.3, a=0.2, curve=2) * 0.4,
    "падение в пропасть: мультяшный свист вниз 1.4 кГц→160 Гц + ветер, 1.3 с")
add("rocket_on", mix((lp(noise(0.08), 1200) * env(0.08, a=0.001), 0, 0.25), (sweep_bp(pink(0.5), 200, 3000, q=1.2) * env(0.5, a=0.02, curve=1.5), 0, 6)),
    "ракета: поджиг — хлопок + нарастающее шипение, 0.5 с")
add("rocket_off", mix(*[(lp(noise(0.06), 1500) * env(0.06, a=0.001, curve=5), d, g) for d, g in ((0, 0.8), (0.12, 0.55), (0.22, 0.35), (0.3, 0.2))]),
    "ракета: «пых-пых» — четыре затухающих хлопка, 0.4 с")
add("finish", mix((tone(C5, 0.14, "brass", curve=2), 0, 0.35), (tone(E5, 0.14, "brass", curve=2), 0.12, 0.35),
                  (tone(G5, 0.14, "brass", curve=2), 0.24, 0.35),
                  *[(tone(f, 1.2, "brass", a=0.01, curve=2.2), 0.36, 0.28) for f in (C5, E5, G5, C6)],
                  (sparkle, 0.36, 0.5), (bell(C7, 1.0), 0.36, 0.2)),
    "финиш: фанфара C-E-G → аккорд до-мажор (медь) + искры, 1.6 с")
add("record", mix((bell(G5, 0.6), 0, 0.5), (bell(B5, 0.6), 0.08, 0.5), (bell(D6, 0.6), 0.16, 0.5), (bell(G6, 0.9), 0.24, 0.6), (sparkle, 0.24, 0.5)),
    "рекорд: сияющее арпеджио колокольчиков G-B-D-G + искры, 1.15 с")
add("horn", lp(tone(note(-4), 0.22, "square", bright=0.6, a=0.01, curve=0.5) + tone(note(0), 0.22, "square", bright=0.6, a=0.01, curve=0.5), 1800) * 0.5,
    "гудок машины: два тона F4+A4 (мягкий квадрат), 0.22 с — играется дважды «би-бип»")


# --- лупы (2 с, бесшовные; частоты LFO кратны 0.5 Гц)
def lfo(dur, hz, depth, phase=0.0):
    return 1 - depth + depth * 0.5 * (1 + np.sin(2 * np.pi * hz * t_(dur) + phase))


L = 2.25  # длина сырья, после loopify (−0.25 с) — 2.0 с
add("wind", loopify(bp(pink(L), 250, 1400) * lfo(L, 0.5, 0.5) + bp(pink(L), 1200, 3500) * lfo(L, 1.0, 0.6, 1.3) * 0.3),
    "луп ветра: розовый шум 250–1400 Гц с порывами (0.5 и 1 Гц), 2.0 с", loop=True)
add("snow", loopify(lp(pink(L), 2600) * 0.8 + clicks(L, 900, 1500, 6000) * 0.9 + bp(noise(L), 3000, 7000) * 0.12),
    "луп снега: мягкое «шшш» + мелкий хруст (импульсы 1.5–6 кГц), 2.0 с", loop=True)
add("ice", loopify(hp(pink(L), 2500) * 0.6 + bp(noise(L), 5000, 9000) * 0.25 * lfo(L, 2.0, 0.3)
                   + sum(np.sin(2 * np.pi * f * t_(L)) * 0.02 for f in (1760.0, 2637.0))),
    "луп льда: гладкое высокое шипение лезвия 2.5–9 кГц с тонким звенящим призвуком, 2.0 с", loop=True)
add("hard", loopify(lp(clicks(L, 4000, 200, 2500), 2500) * 1.4 + lp(brown(L), 180) * 0.6 + bp(noise(L), 600, 1800) * 0.12),
    "луп асфальта/камня: шершавый рокот — плотные щелчки гравия + низкий гул, 2.0 с", loop=True)
add("rocket", loopify(lp(brown(L), 700) * 0.9 + bp(pink(L), 600, 4000) * 0.5 * lfo(L, 8.0, 0.25) + clicks(L, 300, 800, 4000) * 0.5),
    "луп ракеты: рёв — бурый шум до 700 Гц + шипение с дрожью 8 Гц + треск, 2.0 с", loop=True)
add("stretch", loopify(bp(signal.sawtooth(2 * np.pi * 70 * t_(L)) * lfo(L, 6.0, 0.6), 150, 900) * 0.7 + bp(noise(L), 400, 1500) * 0.15),
    "луп натяжения рогатки: скрип резинки — пила 70 Гц через полосу 150–900 с дрожью 6 Гц, 2.0 с (тон растёт с натяжением)", loop=True)
add("car", loopify(lp(tone(82, L, "saw", a=0.0001, curve=0, bright=0.8) * lfo(L, 4.0, 0.2), 1300) + lp(brown(L), 400) * 0.3),
    "луп мотора машины (3D): пила 82 Гц с гармониками до 1.3 кГц, лёгкая «раскачка» 4 Гц + шум, 2.0 с", loop=True)
clack = mix(*[(lp(noise(0.05), 2500) * env(0.05, a=0.0005, curve=6), d, 1) for d in (0.1, 0.32, 1.1, 1.32)], length=L)
add("train", loopify(lp(brown(L), 220) * 0.8 + clack * 0.9 + lp(tone(41, L, "saw", a=0.0001, curve=0), 300) * 0.3),
    "луп поезда (3D): гул рельсов + «тук-тук… тук-тук» стыков, 2.0 с", loop=True)

UI_NAMES = {"click", "open", "deny", "buy"}


# ------------------------------------------------------------------ сборка атласа
def normalize(x, peak_db=PEAK_DB):
    x = x - np.mean(x)
    return x / (np.abs(x).max() + 1e-12) * 10 ** (peak_db / 20)


def build():
    OUT.mkdir(parents=True, exist_ok=True)
    chunks, regions, pos = [], {}, GAP
    chunks.append(np.zeros(int(GAP * SR)))
    for name, (x, loop, desc) in S.items():
        if not loop:
            x = fade_out(x.copy(), 0.008)
        x = normalize(x, -3.0 if loop else PEAK_DB)  # лупы чуть тише: их громкость ведёт код
        dur = len(x) / SR
        if name in UI_NAMES:
            assert dur <= 0.25 + 1e-6, f"{name}: UI-звук {dur:.3f} с > 0.25 с"
        regions[name] = {"start": round(pos, 4), "len": round(dur, 4), "loop": loop, "desc": desc}
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
        r["peak_db"] = round(20 * np.log10(np.abs(dec[a:b]).max() + 1e-12), 2)
        if not r["loop"]:
            assert r["peak_db"] <= -1.0, f"{name}: пик после Vorbis {r['peak_db']} dBFS > −1"
    MAP.write_text(json.dumps({"file": ATLAS.name, "sr": SR, "length": round(len(full) / SR, 3), "regions": regions},
                              ensure_ascii=False, indent=1) + "\n")
    write_luau(regions)
    print(f"Атлас: {ATLAS.relative_to(ROOT)} — {len(regions)} звуков, {len(full) / SR:.1f} с, {ATLAS.stat().st_size // 1024} КБ")
    return regions, dec


def decode(path):
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", str(path), "-f", "s16le", "-ac", "1", "-ar", str(SR), "-"],
                         check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype="<i2").astype(np.float64) / 32768


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
        aw.set_title(f"{name}  {r['len']:.2f} с  пик {r['peak_db']} dB" + ("  [луп]" if r["loop"] else ""), fontsize=8)
        aw.tick_params(labelsize=6)
        asp.specgram(x + 1e-9, NFFT=512, Fs=SR, noverlap=384, cmap="magma", vmin=-120)
        asp.set_ylim(0, 12000)
        asp.tick_params(labelsize=6)
    for j in range(len(names), rows * cols):
        axes[(j // cols) * 2][j % cols].axis("off")
        axes[(j // cols) * 2 + 1][j % cols].axis("off")
    fig.suptitle("Синтезированные звуки (sfx_atlas.ogg, после Vorbis): волна (красное — −1 dBFS) и спектрограмма 0–12 кГц", fontsize=11)
    fig.tight_layout(rect=(0, 0, 1, 0.985))
    png = OUT / "preview.png"
    fig.savefig(png, dpi=80)
    print(f"Сводка: {png}")


if __name__ == "__main__":
    regs, decoded = build()
    if "--preview" in sys.argv:
        preview(regs, decoded)
