"""Пути аудио-атласа и запись src/shared/AudioIds.luau — без numpy (нужно и в CI, и генератору).

AudioIds.luau = id загруженного атласа (если sha в audio.json совпадает с текущим файлом, иначе 0)
+ карта кусков из assets/audio/atlas.json.
"""
import hashlib
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "audio"
ATLAS = OUT / "sfx_atlas.ogg"
MAP = OUT / "atlas.json"  # куски атласа (пишет scripts/gen_audio.py)
DB = OUT / "audio.json"  # id загруженного атласа (пишет scripts/upload_audio.py)
LUAU = ROOT / "src" / "shared" / "AudioIds.luau"


def file_sha(p: pathlib.Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()[:16] if p.exists() else ""


def write_luau(regions=None):
    if regions is None:
        regions = json.loads(MAP.read_text())["regions"]
    db = json.loads(DB.read_text()) if DB.exists() else {}
    rec = db.get(ATLAS.stem) or {}
    aid = rec.get("id", 0) if rec.get("sha") == file_sha(ATLAS) else 0  # другой файл — старый id не подходит
    lines = ["-- Сгенерировано scripts/gen_audio.py / upload_audio.py: атлас звуков (assets/audio/sfx_atlas.ogg).",
             "-- atlas = ID аудио-ассета (0 — ещё не загружен: играют встроенные rbxasset-звуки, см. client/Sounds).",
             "-- regions: имя → { начало, длина (с), луп } — Sound.PlaybackRegion / LoopRegion.",
             "return {", f"\tatlas = {aid},", "\tregions = {"]
    for k, r in regions.items():
        lines.append(f"\t\t{k} = {{ {r['start']}, {r['len']}, {'true' if r['loop'] else 'false'} }},")
    lines += ["\t},", "}"]
    LUAU.write_text("\n".join(lines) + "\n")
