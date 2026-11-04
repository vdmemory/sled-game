#!/usr/bin/env python3
"""Забирает метрики игры из Open Cloud Analytics Query API (бета) и дописывает analytics/metrics.csv.

Нужно: ROBLOX_ANALYTICS_KEY (API-ключ с правом universe-analytics → universe.analytics:read на этот
опыт) и UNIVERSE_ID. Берём последние DAYS дней (по умолчанию 8 — с запасом), по одной строке на
день; уже существующие даты перезаписываем свежими значениями (ретеншн D7/D30 дозреет позже).
Запуск: ROBLOX_ANALYTICS_KEY=... UNIVERSE_ID=... python3 scripts/fetch_metrics.py [--print]
--print — после обновления напечатать весь CSV между METRICS_CSV_BEGIN/END (так его читают из лога
GitHub Actions: деплой-workflow вызывает скрипт из publish.sh, а недельная задача забирает CSV из лога
и коммитит — у сессий Claude нет права менять workflows). ANALYTICS_UNIVERSE_ID, если задан,
имеет приоритет над UNIVERSE_ID (метрики production при деплое на staging).
Документация: create.roblox.com/docs/cloud/guides/analytics/metrics. Каждый сбой метрики —
предупреждение, не падение: пустая ячейка лучше нуля.
"""
import csv
import datetime as dt
import json
import os
import pathlib
import sys
import time
import urllib.error
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
CSV = ROOT / "analytics" / "metrics.csv"
KEY = os.environ.get("ROBLOX_ANALYTICS_KEY") or os.environ.get("ROBLOX_API_KEY", "")
def _cfg_universe() -> str:
    try:
        v = json.loads((ROOT / "analytics" / "config.json").read_text()).get("analytics_universe_id") or 0
        return str(v) if int(v) > 0 else ""
    except (OSError, ValueError):
        return ""


UNIVERSE = os.environ.get("ANALYTICS_UNIVERSE_ID") or _cfg_universe() or os.environ.get("UNIVERSE_ID", "")
DAYS = int(os.environ.get("DAYS", "8"))
API = f"https://apis.roblox.com/analytics-query-api/v1/universes/{UNIVERSE}/metrics"
DEVEX, FEE = 0.0038, 0.7

COLUMNS = ["date", "period", "visits", "dau", "ccu_peak", "new_users", "d1", "d7", "d30", "session_min",
           "likes_pct", "robux_earned", "robux_creator_rewards", "payers", "conversion", "arpdau_usd",
           "premium_playtime_score", "source", "note"]
# колонка CSV → метрика API (granularity OneDay). Доли ретеншна API отдаёт в процентах или долях —
# нормализуем в доли (см. norm()).
METRICS = {
    "visits": "Visits",
    "dau": "DailyActiveUsers",
    "ccu_peak": "PeakConcurrentPlayers",
    "d1": "ForwardD1Retention",
    "d7": "ForwardD7Retention",
    "d30": "ForwardD30Retention",
    "session_min": "AverageSessionLengthMinutes",
    "robux_earned": "DailyRevenue",
    "payers": "PayingUsers",
    "conversion": "PayingUsersCVR",
}


def http(method, url, body=None):
    req = urllib.request.Request(url, data=json.dumps(body).encode() if body is not None else None, method=method,
                                 headers={"x-api-key": KEY, "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.status, json.loads(r.read().decode() or "{}")
    except urllib.error.HTTPError as e:
        return e.code, {"error": e.read().decode(errors="replace")[:300]}


def query(metric, start, end):
    code, j = http("POST", API, {"metric": metric, "granularity": "OneDay",
                                 "startTime": start.strftime("%Y-%m-%dT00:00:00Z"),
                                 "endTime": end.strftime("%Y-%m-%dT00:00:00Z")})
    if code not in (200, 202):
        raise RuntimeError(f"{metric}: HTTP {code} {j.get('error', j)}")
    for _ in range(30):
        if j.get("done") or "response" in j:  # маленькие запросы приходят сразу, иногда без done
            break
        path = j.get("path") or j.get("operationPath") or j.get("name")
        if not path:
            raise RuntimeError(f"{metric}: неожиданный ответ без path: {json.dumps(j)[:200]}")
        time.sleep(2)
        code, j = http("GET", f"https://apis.roblox.com/{str(path).lstrip('/')}")
        if code != 200:
            raise RuntimeError(f"{metric}: опрос операции HTTP {code} {j.get('error', j)}")
    if j.get("error"):
        raise RuntimeError(f"{metric}: {json.dumps(j['error'])[:200]}")
    out = {}
    for series in (j.get("response") or {}).get("values", []):
        for p in series.get("dataPoints", []):
            day = p["time"][:10]
            out[day] = float(p["value"]) if p.get("value") is not None else None
    return out


def norm(col, v):
    if v is None:
        return None
    if col in ("d1", "d7", "d30", "conversion") and v > 1:  # проценты → доли
        return round(v / 100, 4)
    return v


def main():
    if not KEY or not UNIVERSE:
        print("::warning::ROBLOX_ANALYTICS_KEY / UNIVERSE_ID не заданы — метрики не собраны")
        return 0
    today = dt.datetime.now(dt.timezone.utc).date()
    start, end = today - dt.timedelta(days=DAYS), today  # end исключительно: сегодняшний неполный день не берём
    rows = {r["date"]: r for r in csv.DictReader(CSV.open(encoding="utf-8"))} if CSV.exists() else {}
    fresh = {}
    for col, metric in METRICS.items():
        try:
            series = query(metric, start, end)
        except Exception as e:  # noqa: BLE001 — любая ошибка метрики = пустая ячейка
            print(f"::warning::{e}")
            continue
        for day, v in series.items():
            fresh.setdefault(day, {})[col] = norm(col, v)
        time.sleep(2.2)  # лимит 30 POST/мин
    if not fresh and os.environ.get("UNIVERSE_ID") and os.environ["UNIVERSE_ID"] != UNIVERSE and not os.environ.get("_FALLBACK"):
        # боевой опыт ещё пуст (не выпущен) — берём метрики опыта, куда деплоим (staging)
        print(f"::warning::у опыта {UNIVERSE} нет данных — беру метрики опыта {os.environ['UNIVERSE_ID']}")
        os.environ["ANALYTICS_UNIVERSE_ID"] = os.environ["UNIVERSE_ID"]
        os.environ["_FALLBACK"] = "1"
        import subprocess
        return subprocess.call([sys.executable, __file__] + sys.argv[1:], env=os.environ)
    if not fresh:
        print("::warning::API не вернул ни одной метрики (нет данных или нет доступа к бете)")
        return 0
    for day, vals in sorted(fresh.items()):
        r = rows.get(day) or {c: "" for c in COLUMNS}
        r.update({"date": day, "period": "day", "source": "open-cloud-analytics"})
        for col, v in vals.items():
            if v is not None:
                r[col] = f"{v:g}"
        dau = float(r["dau"]) if r.get("dau") else None
        if dau and r.get("robux_earned"):
            r["arpdau_usd"] = f"{float(r['robux_earned']) * FEE * DEVEX / dau:.5f}"
        rows[day] = r
    with CSV.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=COLUMNS)
        w.writeheader()
        for day in sorted(rows):
            w.writerow({c: rows[day].get(c, "") for c in COLUMNS})
    print(f"Обновлено дней: {len(fresh)} ({min(fresh)} … {max(fresh)}); всего строк: {len(rows)}")
    if "--print" in sys.argv:
        print("METRICS_CSV_BEGIN")
        print(CSV.read_text(encoding="utf-8").rstrip("\n"))
        print("METRICS_CSV_END")
    return 0


if __name__ == "__main__":
    sys.exit(main())
