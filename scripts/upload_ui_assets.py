#!/usr/bin/env python3
"""Загружает иконки интерфейса (assets/ui/*.png) в Roblox как Decal через Open Cloud.

Уже загруженные (assets/ui/decals.json) пропускаются. Результат — src/shared/UIDecals.luau
({ имя = decalId }). Картинку из decal-а сервер достаёт в игре через InsertService
(server/UIImages), поэтому здесь нужен только ID декали.

Нужно: ROBLOX_API_KEY с правами Assets API (asset:read + asset:write) и ID владельца
(CREATOR_USER_ID или CREATOR_USERNAME — тогда ID берём из публичного users.roblox.com).
Ошибки не роняют деплой: игра показывает эмодзи вместо отсутствующих картинок.
"""
import json
import os
import pathlib
import sys
import time
import urllib.error
import urllib.request
import uuid

ROOT = pathlib.Path(__file__).resolve().parent.parent
ICONS = ROOT / "assets" / "ui"
DB = ICONS / "decals.json"
OUT = ROOT / "src" / "shared" / "UIDecals.luau"
KEY = os.environ.get("ROBLOX_API_KEY", "")


def http(method, url, data=None, headers=None):
    req = urllib.request.Request(url, data=data, method=method, headers=headers or {})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.status, r.read().decode()
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode(errors="replace")
    except (urllib.error.URLError, TimeoutError) as e:  # сеть/таймаут: не роняем цикл, уже загруженные ID сохранятся
        return 0, str(e)


def creator_id():
    if os.environ.get("CREATOR_USER_ID"):
        return os.environ["CREATOR_USER_ID"]
    name = os.environ.get("CREATOR_USERNAME", "vdmemor1")
    code, body = http("POST", "https://users.roblox.com/v1/usernames/users",
                      json.dumps({"usernames": [name], "excludeBannedUsers": True}).encode(),
                      {"Content-Type": "application/json"})
    if code == 200 and json.loads(body).get("data"):
        return str(json.loads(body)["data"][0]["id"])
    raise SystemExit(f"не удалось узнать ID пользователя {name}: HTTP {code} {body[:200]}")


def upload(path: pathlib.Path, user_id: str):
    boundary = uuid.uuid4().hex
    meta = json.dumps({
        "assetType": "Decal",
        "displayName": f"SledUI_{path.stem}",
        "description": "Sled game UI icon (Fluent Emoji, MIT)",
        "creationContext": {"creator": {"userId": user_id}},
    })
    body = b"".join([
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"request\"\r\n\r\n{meta}\r\n".encode(),
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{path.name}\"\r\n"
        f"Content-Type: image/png\r\n\r\n".encode(),
        path.read_bytes(),
        f"\r\n--{boundary}--\r\n".encode(),
    ])
    code, resp = http("POST", "https://apis.roblox.com/assets/v1/assets", body,
                      {"x-api-key": KEY, "Content-Type": f"multipart/form-data; boundary={boundary}"})
    if code != 200:
        return None, f"HTTP {code}: {resp[:300]}"
    op = json.loads(resp).get("path") or json.loads(resp).get("operationId")
    for _ in range(30):
        time.sleep(2)
        code, resp = http("GET", f"https://apis.roblox.com/assets/v1/{op}", headers={"x-api-key": KEY})
        if code == 200:
            j = json.loads(resp)
            if j.get("done"):
                if "response" in j:
                    return int(j["response"]["assetId"]), None
                return None, json.dumps(j.get("error") or j)[:300]
    return None, "таймаут операции"


def write_luau(ids):
    lines = ["-- Сгенерировано scripts/upload_ui_assets.py: имя иконки → ID декали (Fluent Emoji 3D, MIT)", "return {"]
    for k in sorted(ids):
        lines.append(f"\t{k} = {ids[k]},")
    lines.append("}")
    OUT.write_text("\n".join(lines) + "\n")


def main():
    ids = json.loads(DB.read_text()) if DB.exists() else {}
    todo = [p for p in sorted(ICONS.glob("*.png")) if p.stem not in ids]
    if todo and not KEY:
        print("::warning::ROBLOX_API_KEY не задан — новые иконки не загружены")
        todo = []
    if todo:
        uid = creator_id()
        print(f"Загружаю {len(todo)} иконок от пользователя {uid}")
        fails = 0
        for p in todo:
            aid, err = upload(p, uid)
            if aid:
                ids[p.stem] = aid
                print(f"  {p.stem}: {aid}")
            else:
                fails += 1
                print(f"::warning::{p.stem}: {err}")
                if fails >= 3 and not ids:
                    print("::warning::Загрузка не работает (проверьте права ключа: Assets API read+write). Пропускаю.")
                    break
        DB.write_text(json.dumps(ids, indent=1, sort_keys=True) + "\n")
    write_luau(ids)
    print(f"Иконок с ID: {len(ids)}")
    # статус модерации (новые картинки Roblox показывает только после одобрения)
    if KEY and ids:
        states = {}
        for name, aid in sorted(ids.items()):
            code, body = http("GET", f"https://apis.roblox.com/assets/v1/assets/{aid}?readMask=moderationResult", headers={"x-api-key": KEY})
            st = json.loads(body).get("moderationResult", {}).get("moderationState", f"HTTP {code}") if code == 200 else f"HTTP {code}: {body[:120]}"
            states.setdefault(st, []).append(name)
        for st, names in states.items():
            print(f"Модерация {st}: {len(names)} — {', '.join(names[:8])}")


if __name__ == "__main__":
    try:
        main()
    except SystemExit as e:
        print(f"::warning::{e}")
        if not OUT.exists():
            write_luau({})
        sys.exit(0)
