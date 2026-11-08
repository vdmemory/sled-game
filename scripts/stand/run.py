#!/usr/bin/env python3
"""Стенд сверки: запускает shared-модули (src/shared) в luau CLI на шимах Roblox API и снимает
отпечаток всех построенных инстансов (свойства, атрибуты, порядок детей).

  python3 scripts/stand/run.py [tail.luau] [--src src/shared] [--meshes] [--dump]

tail.luau — сценарий (по умолчанию scripts/stand/sled_fp.luau: все сани × тиры обвеса × ракеты,
ракеты 0–6, рогатка 0–10). --meshes — в ReplicatedStorage есть шаблоны MeshTemplates на все имена
из MeshSpecs (как после загрузки мешей), без флага — фолбэк на Part. --dump — печатать строки
отпечатка (для поиска расхождения). Сверка рефакторинга: прогнать до и после (`--src` на копию
старого src/shared) и сравнить хэши. Нужен luau CLI (scripts/check.sh --install кладёт в .tools/bin).
"""
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent.parent


def node_expr(parts):
    return "SHARED" + "".join(f'["{p}"]' for p in parts)


def module_tree(src: pathlib.Path) -> str:
    out = []

    def fn(np, path):
        body = path.read_text(encoding="utf-8").replace("--!strict", "")
        return f"{node_expr(np)}.__fn = function(script)\n{body}\nend\n"

    def walk(d, parts):
        for name in sorted(os.listdir(d)):
            full = d / name
            if full.is_dir():
                np = parts + [name]
                out.append(f'mkNode({node_expr(parts) if parts else "SHARED"}, "{name}")\n')
                if (full / "init.luau").exists():
                    out.append(fn(np, full / "init.luau"))
                walk(full, np)
            elif name.endswith(".luau") and name != "init.luau":
                base = name[:-5]
                np = parts + [base]
                out.append(f'mkNode({node_expr(parts) if parts else "SHARED"}, "{base}")\n')
                out.append(fn(np, full))

    walk(src, [])
    return "".join(out)


def main():
    args = sys.argv[1:]
    src = ROOT / "src" / "shared"
    tail = HERE / "sled_fp.luau"
    flags = []
    i = 0
    while i < len(args):
        a = args[i]
        if a == "--src":
            src = pathlib.Path(args[i + 1]).resolve()
            i += 1
        elif a in ("--meshes", "--dump"):
            flags.append(a)
        else:
            tail = pathlib.Path(a).resolve()
        i += 1
    prog = (HERE / "shims.luau").read_text(encoding="utf-8")
    prog += f"\nSTAND_MESHES = {'true' if '--meshes' in flags else 'false'}\n"
    prog += f"STAND_DUMP = {'true' if '--dump' in flags else 'false'}\n"
    prog += module_tree(src)
    prog += tail.read_text(encoding="utf-8")
    luau = shutil.which("luau") or str(ROOT / ".tools" / "bin" / "luau")
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False, encoding="utf-8") as f:
        f.write(prog)
        path = f.name
    try:
        r = subprocess.run([luau, path], capture_output=True, text=True)
        sys.stdout.write(r.stdout)
        sys.stderr.write(r.stderr)
        sys.exit(r.returncode)
    finally:
        os.unlink(path)


if __name__ == "__main__":
    main()
