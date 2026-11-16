#!/usr/bin/env python3
"""Сверка карты модулей docs/ARCHITECTURE.md с кодом (идея #87). Только предупреждения, код выхода 0.
  python3 scripts/arch_lint.py         — строки «| `путь` | N |» против wc -l (расхождение > 15 % и > 20 строк),
                                         файлы > 600 строк, не названные в абзаце «Сейчас выше порога»
  python3 scripts/arch_lint.py --fix   — переписать числа в таблице по коду (абзац «выше порога» — руками)
"""
import pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
DOC = ROOT / "docs" / "ARCHITECTURE.md"
LIMIT = 600


def lines_of(mod: str):
    for suffix in (".luau", ".client.luau", ".server.luau"):
        f = ROOT / "src" / (mod + suffix)
        if f.exists():
            return sum(1 for _ in f.open(encoding="utf-8"))
    return None


def main():
    text = DOC.read_text(encoding="utf-8")
    warns = []
    def row(m):
        mod, n = m.group(1), int(m.group(2))
        actual = lines_of(mod)
        if actual is None:
            warns.append(f"карта модулей: нет файла src/{mod}")
        elif abs(actual - n) > max(20, 0.15 * n):
            warns.append(f"карта модулей: `{mod}` {n} строк в доке, {actual} в коде")
        return f"| `{mod}` | {actual if actual is not None else n} |"
    fixed = re.sub(r"^\| `([^`|]+)` \| (\d+) \|", row, text, flags=re.M)
    above = text.split("Сейчас выше порога", 1)[1].split("\n\n", 1)[0] if "Сейчас выше порога" in text else ""
    for f in sorted(ROOT.glob("src/**/*.luau")):
        n = sum(1 for _ in f.open(encoding="utf-8"))
        name = f.parent.name if f.stem == "init" else f.stem.split(".")[0]
        if n > LIMIT and f"`{name}`" not in above:
            warns.append(f"файл > {LIMIT} строк не назван в «Сейчас выше порога»: src/{f.relative_to(ROOT / 'src')} ({n})")
    if "--fix" in sys.argv and fixed != text:
        DOC.write_text(fixed, encoding="utf-8")
        print("arch_lint: числа в карте модулей обновлены")
    for w in warns:
        print(f"::warning::{w}" if "GITHUB_ACTIONS" in __import__("os").environ else f"ВНИМАНИЕ: {w}")
    print(f"arch_lint: {len(warns)} предупреждений")


if __name__ == "__main__":
    main()
