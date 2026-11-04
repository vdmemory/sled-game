#!/usr/bin/env python3
"""Отчёт по analytics/metrics.csv и analytics/events.csv → analytics/REPORT.md.

Считает последние значения, дельты к предыдущему периоду и к 7 периодам назад, производные
(DAU/CCU, ARPDAU, конверсия), подставляет события рядом с датами и отмечает, что ниже целей из
docs/BUSINESS.md. Запуск: python3 scripts/metrics_report.py
"""
import csv
import pathlib
from datetime import date

ROOT = pathlib.Path(__file__).resolve().parent.parent
M = ROOT / "analytics" / "metrics.csv"
E = ROOT / "analytics" / "events.csv"
OUT = ROOT / "analytics" / "REPORT.md"
DEVEX, FEE = 0.0038, 0.7
TARGETS = {"d1": 0.30, "d7": 0.12, "d30": 0.05, "session_min": 8, "likes_pct": 85, "conversion": 0.015, "arpdau_usd": 0.01}
COLS = ["visits", "dau", "ccu_peak", "new_users", "d1", "d7", "d30", "session_min", "likes_pct",
        "robux_earned", "robux_creator_rewards", "payers", "conversion", "arpdau_usd", "premium_playtime_score"]


def num(v):
    try:
        return float(v) if v not in ("", None) else None
    except ValueError:
        return None


def fmt(k, v):
    if v is None:
        return "—"
    if k in ("d1", "d7", "d30", "conversion"):
        return f"{v * 100:.1f}%"
    if k == "arpdau_usd":
        return f"${v:.4f}"
    return f"{v:g}"


def delta(a, b):
    if a is None or b is None or b == 0:
        return ""
    d = (a - b) / abs(b) * 100
    return f"{d:+.0f}%"


def main():
    rows = list(csv.DictReader(M.open(encoding="utf-8"))) if M.exists() else []
    events = list(csv.DictReader(E.open(encoding="utf-8"))) if E.exists() else []
    rows.sort(key=lambda r: r["date"])
    for r in rows:  # производные
        dau, rob, cr, payers = num(r.get("dau")), num(r.get("robux_earned")), num(r.get("robux_creator_rewards")), num(r.get("payers"))
        if num(r.get("conversion")) is None and dau and payers is not None:
            r["conversion"] = payers / dau
        if num(r.get("arpdau_usd")) is None and dau and (rob is not None or cr is not None):
            r["arpdau_usd"] = ((rob or 0) * FEE + (cr or 0)) * DEVEX / dau
    out = [f"# Отчёт по метрикам — {date.today()}", "", "Генерируется `scripts/metrics_report.py`; источник — `analytics/metrics.csv`, `analytics/events.csv`.", ""]
    if not rows:
        out += ["**Данных пока нет.** Заполни `analytics/metrics.csv` по `docs/METRICS.md`.", ""]
    else:
        last, prev = rows[-1], (rows[-2] if len(rows) > 1 else {})
        week = rows[-8] if len(rows) > 7 else {}
        out += [f"## Последний снимок: {last['date']} ({last.get('period','day')}), источник: {last.get('source','')}", "",
                "| Метрика | Значение | к пред. | к −7 | Цель | |", "| --- | --- | --- | --- | --- | --- |"]
        for k in COLS:
            v = num(last.get(k)); t = TARGETS.get(k)
            flag = "" if v is None or t is None else ("✅" if v >= t else "⚠️ ниже цели")
            out.append(f"| {k} | {fmt(k, v)} | {delta(v, num(prev.get(k)))} | {delta(v, num(week.get(k)))} | {fmt(k, t) if t is not None else ''} | {flag} |")
        dau, ccu = num(last.get("dau")), num(last.get("ccu_peak"))
        if dau and ccu:
            out.append(f"\nDAU/CCU = {dau / ccu:.1f} (ориентир ≈ 4).")
        out += ["", "## Тренд (последние 14 снимков)", "", "| дата | dau | d1 | d7 | session | robux | arpdau | события |", "| --- | --- | --- | --- | --- | --- | --- | --- |"]
        for r in rows[-14:]:
            ev = "; ".join(e["description"] for e in events if e["date"] == r["date"])
            out.append(f"| {r['date']} | {fmt('dau', num(r.get('dau')))} | {fmt('d1', num(r.get('d1')))} | {fmt('d7', num(r.get('d7')))} | {fmt('session_min', num(r.get('session_min')))} | {fmt('robux_earned', num(r.get('robux_earned')))} | {fmt('arpdau_usd', num(r.get('arpdau_usd')))} | {ev} |")
        out.append("")
    out += ["## Журнал событий (последние 20)", "", "| дата | тип | что | ссылка |", "| --- | --- | --- | --- |"]
    for e in events[-20:]:
        out.append(f"| {e['date']} | {e['type']} | {e['description']} | {e.get('ref','')} |")
    OUT.write_text("\n".join(out) + "\n", encoding="utf-8")
    print(f"→ {OUT.relative_to(ROOT)}: {len(rows)} снимков, {len(events)} событий")


if __name__ == "__main__":
    main()
