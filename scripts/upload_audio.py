#!/usr/bin/env python3
"""Загружает атлас звуков (assets/audio/sfx_atlas.ogg, синтезирует scripts/gen_audio.py) в Roblox как
ассет Audio через Open Cloud Assets API.

Формат (create.roblox.com/docs/cloud/guides/usage-assets, /docs/audio/assets): POST /assets/v1/assets,
multipart: `request` (JSON: assetType "Audio", displayName, description, creationContext.creator) +
`fileContent` (.ogg, Content-Type audio/ogg). Ограничения: ≤ 7 мин, < 20 МБ, ≤ 48 кГц, mono/stereo;
через Open Cloud — 10 аудио в месяц без ID-верификации, 100 с верификацией; обновлять аудио нельзя —
каждое изменение атласа = новый ассет. Поэтому все звуки в одном файле.

Уже загруженный файл (assets/audio/audio.json: имя → {id, sha}) пропускается; изменился (sha) — грузится
заново. Результат — src/shared/AudioIds.luau (через gen_audio.write_luau), в лог — AUDIO_IDS_JSON_BEGIN/END.
Пока ассета нет/он на модерации, клиент (client/Sounds) играет встроенные rbxasset-звуки — деплой не падает.

Нужно: ROBLOX_API_KEY с Assets API (asset:read + asset:write — те же права, что у иконок и мешей) и ID
владельца (CREATOR_USER_ID или CREATOR_USERNAME).
"""
import json
import pathlib
import sys
import time
import uuid

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from upload_ui_assets import KEY, creator_id, http  # noqa: E402  (тот же HTTP и владелец)
import audio_ids  # noqa: E402  (пути и запись AudioIds.luau, без numpy)

FILES = [audio_ids.ATLAS]
DB = audio_ids.DB

HELP = (
    "Аудио не загружено. Владельцу: (1) create.roblox.com → Creator Dashboard → Open Cloud → API Keys → ключ "
    "из секрета ROBLOX_API_KEY → Access Permissions → Assets API → asset:read и asset:write → Save; "
    "(2) если ответ про лимит/верификацию — пройти ID-верификацию (roblox.com → Settings → Account Info → "
    "Verify My Age) или дождаться нового месяца (10 аудио/30 дней без верификации); (3) либо загрузить "
    "assets/audio/sfx_atlas.ogg вручную: Creator Hub → Creations → Development Items → Audio → Import, "
    "и вписать ID в assets/audio/audio.json (поле id, sha — из лога). Следующий деплой подхватит."
)


sha = audio_ids.file_sha


def upload(path: pathlib.Path, user_id: str):
    boundary = uuid.uuid4().hex
    meta = json.dumps({
        "assetType": "Audio",
        "displayName": f"SledSfx_{path.stem}",
        "description": "Sled game sound effects atlas v2 (CC0 + CC BY 4.0 recordings, scripts/gen_audio.py)",
        "creationContext": {"creator": {"userId": user_id}},
    })
    body = b"".join([
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"request\"\r\n\r\n{meta}\r\n".encode(),
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{path.name}\"\r\n"
        f"Content-Type: audio/ogg\r\n\r\n".encode(),
        path.read_bytes(),
        f"\r\n--{boundary}--\r\n".encode(),
    ])
    code, resp = http("POST", "https://apis.roblox.com/assets/v1/assets", body,
                      {"x-api-key": KEY, "Content-Type": f"multipart/form-data; boundary={boundary}"})
    if code != 200:
        return None, code, f"HTTP {code}: {resp[:300]}"
    j = json.loads(resp)
    op = j.get("path") or ("operations/" + j["operationId"] if j.get("operationId") else None)
    if not op:
        return None, code, f"нет операции в ответе: {resp[:300]}"
    for _ in range(45):
        time.sleep(2)
        code, resp = http("GET", f"https://apis.roblox.com/assets/v1/{op}", headers={"x-api-key": KEY})
        if code == 200:
            j = json.loads(resp)
            if j.get("done"):
                if "response" in j:
                    return int(j["response"]["assetId"]), 200, None
                return None, 200, json.dumps(j.get("error") or j)[:300]
    return None, 0, "таймаут операции"


def main():
    db = json.loads(DB.read_text()) if DB.exists() else {}
    files = [p for p in FILES if p.exists()]
    todo = [p for p in files if p.stem not in db or db[p.stem].get("sha") != sha(p)]
    if todo and not KEY:
        print("::warning::ROBLOX_API_KEY не задан — аудио не загружено (играют встроенные звуки)")
        todo = []
    if todo:
        uid = creator_id()
        print(f"Загружаю {len(todo)} аудио (.ogg) от пользователя {uid}")
        for p in todo:
            aid, code, err = upload(p, uid)
            if aid:
                db[p.stem] = {"id": aid, "sha": sha(p)}
                print(f"  {p.stem}: {aid}")
                continue
            print(f"::warning::аудио {p.stem}: {err}")
            print(f"::warning::{HELP}")
            if code in (401, 403, 429):
                break
        DB.write_text(json.dumps(db, indent=1, sort_keys=True) + "\n")
    audio_ids.write_luau()
    missing = [p.stem for p in files if p.stem not in db or db[p.stem].get("sha") != sha(p)]
    print(f"Аудио с ID: {sum(1 for p in files if p.stem in db and db[p.stem].get('sha') == sha(p))} из {len(files)}")
    if KEY and db:
        for name, rec in sorted(db.items()):
            code, body = http("GET", f"https://apis.roblox.com/assets/v1/assets/{rec['id']}?readMask=moderationResult",
                              headers={"x-api-key": KEY}, attempts=1)  # справочно, без повторов
            st = (json.loads(body).get("moderationResult", {}).get("moderationState", f"HTTP {code}")
                  if code == 200 else f"HTTP {code}: {body[:120]}")
            print(f"Модерация аудио {name} ({rec['id']}): {st}")
    if missing:
        print(f"::warning::Не загружено аудио: {', '.join(missing)} — в игре встроенные звуки")
        return 3
    return 0


if __name__ == "__main__":  # код 3 — не всё загружено (publish.sh предупреждает, деплой идёт)
    try:
        sys.exit(main())
    except SystemExit as e:
        if isinstance(e.code, int):
            raise
        print(f"::warning::{e}")
        sys.exit(3)
    except Exception as e:  # деплой не роняем: без аудио играют встроенные звуки
        print(f"::warning::загрузка аудио: {type(e).__name__}: {e}")
        sys.exit(3)
