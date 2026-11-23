#!/usr/bin/env bash
# Статическая проверка всего Luau-кода одной командой:
#   1) rojo sourcemap      — карта DataModel (чтобы require(script.Parent.X) резолвился);
#   2) luau-lsp analyze    — типы Roblox API (globalTypes): неизвестные глобалы/переменные после
#                            слияний, несуществующие Enum.X.Y, опечатки в свойствах, deprecated API;
#   3) selene              — линт по selene.toml (std = roblox);
#   4) luau-compile --null — синтаксис каждого файла (как сборка Open Cloud);
#   5) scripts/arch_lint.py — карта модулей docs/ARCHITECTURE.md против кода (только предупреждение);
#   6) --stands: быстрые стенды scripts/stand (luau CLI исполняет src/shared на шимах Roblox API —
#      ловит то, чего статика не видит: nil-индексы, расхождение Config ↔ Track, невыполнимые
#      задания): daily_tasks, weekly_quest, sled_fp (только «отработал без ошибки»), track_forks.
#      ≈ 30 с; publish.sh включает его в CI (идея #127).
# Ненулевой код выхода, если хоть один шаг нашёл ошибку.
#
#   scripts/check.sh              — проверить src/
#   scripts/check.sh --stands     — то же + стенды (шаг 6)
#   scripts/check.sh --install    — только поставить инструменты в .tools/ и выйти
#
# Инструменты ищутся в PATH, затем в .tools/bin; недостающие скачиваются с GitHub releases
# (фиксированные версии ниже) в .tools/ (в .gitignore). Нет сети и инструмента —
# шаг пропускается с предупреждением (CHECK_REQUIRE_TOOLS=1 — тогда это ошибка).
set -uo pipefail
cd "$(dirname "$0")/.."

ROJO_VERSION="7.4.4"
LUAU_LSP_VERSION="1.70.1"
SELENE_VERSION="0.31.0"
LUAU_VERSION="0.746"

TOOLS="${CHECK_TOOLS_DIR:-$PWD/.tools}"
BIN="$TOOLS/bin"
mkdir -p "$BIN"
export PATH="$PATH:$BIN"

warn() { if [ -n "${GITHUB_ACTIONS:-}" ]; then echo "::warning::$*"; else echo "ВНИМАНИЕ: $*"; fi; }

unzip_to() { # архив каталог
  if command -v unzip >/dev/null; then unzip -o -q "$1" -d "$2"; else python3 -m zipfile -e "$1" "$2"; fi
}

fetch_zip() { # url → распаковать в $BIN
  local url="$1" tmp
  tmp="$(mktemp -d)"
  if curl -sSfL --retry 5 --retry-delay 3 --retry-all-errors -o "$tmp/a.zip" "$url" && unzip_to "$tmp/a.zip" "$tmp/x"; then
    find "$tmp/x" -type f -exec chmod +x {} \; -exec mv -f {} "$BIN/" \;
    rm -rf "$tmp"
    return 0
  fi
  rm -rf "$tmp"
  return 1
}

need() { # имя → 0, если инструмент есть (или удалось поставить)
  local name="$1"
  command -v "$name" >/dev/null && return 0
  local gh="https://github.com"
  case "$name" in
    rojo) fetch_zip "$gh/rojo-rbx/rojo/releases/download/v$ROJO_VERSION/rojo-$ROJO_VERSION-linux-x86_64.zip" ;;
    luau-lsp) fetch_zip "$gh/JohnnyMorganz/luau-lsp/releases/download/$LUAU_LSP_VERSION/luau-lsp-linux-x86_64.zip" ;;
    selene) fetch_zip "$gh/Kampfkarren/selene/releases/download/$SELENE_VERSION/selene-$SELENE_VERSION-linux.zip" ;;
    luau-compile | luau) fetch_zip "$gh/luau-lang/luau/releases/download/$LUAU_VERSION/luau-ubuntu.zip" ;; # один zip: luau, luau-compile, luau-analyze
  esac
  command -v "$name" >/dev/null
}

DEFS="$TOOLS/globalTypes-$LUAU_LSP_VERSION.d.luau"
need_defs() {
  [ -s "$DEFS" ] && return 0
  curl -sSfL --retry 5 --retry-delay 3 --retry-all-errors -o "$DEFS.part" \
    "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/$LUAU_LSP_VERSION/scripts/globalTypes.None.d.luau" &&
    mv "$DEFS.part" "$DEFS"
}

# Карта Roblox API для selene: roblox.yml в корне (в .gitignore), раз в сутки обновляется
need_selene_std() {
  if [ -s roblox.yml ] && [ -z "$(find roblox.yml -mmin +1440 2>/dev/null)" ]; then
    return 0
  fi
  selene generate-roblox-std >/dev/null 2>&1 && return 0
  [ -s roblox.yml ] # старая карта лучше, чем никакой
}

FAIL=0
missing() {
  if [ -n "${CHECK_REQUIRE_TOOLS:-}" ]; then
    echo "ОШИБКА: нет инструмента: $*"
    FAIL=1
  else
    warn "нет инструмента ($*) — шаг пропущен"
  fi
}

if [ "${1:-}" = "--install" ]; then
  for t in rojo luau-lsp selene luau-compile luau; do need "$t" || echo "не удалось поставить $t"; done
  need_defs || echo "не удалось скачать globalTypes"
  exit 0
fi
STANDS=0
[ "${1:-}" = "--stands" ] && STANDS=1

mapfile -t FILES < <(find src -name '*.luau' | sort)

# 1–2. sourcemap + luau-lsp analyze
if need rojo && need luau-lsp && need_defs; then
  SOURCEMAP="$TOOLS/sourcemap.json"
  rojo sourcemap default.project.json -o "$SOURCEMAP" >/dev/null
  echo "== luau-lsp analyze (${#FILES[@]} файлов)"
  OUT="$(luau-lsp analyze --platform=roblox --definitions="$DEFS" --sourcemap="$SOURCEMAP" \
    --formatter=gnu src 2>&1)"
  RC=$?
  ISSUES="$(printf '%s\n' "$OUT" | grep -vE '^\[(INFO|WARN)\]' | sed "s#$PWD/##g")"
  if [ "$RC" -ne 0 ] || [ -n "$ISSUES" ]; then
    printf '%s\n' "$ISSUES"
    echo "luau-lsp: $(printf '%s\n' "$ISSUES" | grep -cE '^src/.*: [A-Za-z]+: ') замечаний"
    FAIL=1
  else
    echo "luau-lsp: чисто"
  fi
else
  missing "rojo / luau-lsp / globalTypes"
fi

# 3. selene
if need selene && need_selene_std; then
  echo "== selene"
  if selene --display-style quiet src; then :; else FAIL=1; fi
else
  missing "selene / roblox.yml"
fi

# 4. luau-compile — синтаксис
if need luau-compile; then
  echo "== luau-compile"
  BAD=0
  for f in "${FILES[@]}"; do
    luau-compile --null "$f" >/dev/null || { echo "  синтаксис: $f"; BAD=1; }
  done
  [ "$BAD" -eq 0 ] && echo "luau-compile: ${#FILES[@]} файлов без ошибок" || FAIL=1
else
  missing "luau-compile"
fi

# 5. карта модулей в ARCHITECTURE.md против wc -l — предупреждение, не ошибка (идея #87)
echo "== arch_lint"
python3 scripts/arch_lint.py || warn "arch_lint не запустился"

# 6. стенды (--stands): shared-код исполняется в luau CLI (scripts/stand/run.py + shims.luau) — идея #127.
# Падает только на реальной ошибке стенда (error()/assert/рантайм в src/shared); нет luau или
# python3 — как у остальных шагов: предупреждение (CHECK_REQUIRE_TOOLS=1 — ошибка).
if [ "$STANDS" -eq 1 ]; then
  echo "== стенды (scripts/stand)"
  if need luau && command -v python3 >/dev/null; then
    for s in daily_tasks weekly_quest sled_fp track_forks; do
      T0=$(date +%s)
      if OUT="$(python3 scripts/stand/run.py "scripts/stand/$s.luau" 2>&1)"; then
        echo "  $s: OK ($(( $(date +%s) - T0 )) с) — $(printf '%s\n' "$OUT" | grep -v '^$' | tail -n 1)"
      else
        printf '%s\n' "$OUT" | tail -n 25
        echo "  $s: ОШИБКА"
        FAIL=1
      fi
    done
  else
    missing "luau / python3 (стенды)"
  fi
fi

if [ "$FAIL" -ne 0 ]; then
  echo "check.sh: НАЙДЕНЫ ОШИБКИ"
  exit 1
fi
echo "check.sh: OK"
