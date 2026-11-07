#!/usr/bin/env bash
# Статическая проверка всего Luau-кода одной командой:
#   1) rojo sourcemap      — карта DataModel (чтобы require(script.Parent.X) резолвился);
#   2) luau-lsp analyze    — типы Roblox API (globalTypes): неизвестные глобалы/переменные после
#                            слияний, несуществующие Enum.X.Y, опечатки в свойствах, deprecated API;
#   3) selene              — линт по selene.toml (std = roblox);
#   4) luau-compile --null — синтаксис каждого файла (как сборка Open Cloud).
# Ненулевой код выхода, если хоть один шаг нашёл ошибку.
#
#   scripts/check.sh              — проверить src/
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
  if curl -sSfL --retry 2 -o "$tmp/a.zip" "$url" && unzip_to "$tmp/a.zip" "$tmp/x"; then
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
    luau-compile) fetch_zip "$gh/luau-lang/luau/releases/download/$LUAU_VERSION/luau-ubuntu.zip" ;;
  esac
  command -v "$name" >/dev/null
}

DEFS="$TOOLS/globalTypes-$LUAU_LSP_VERSION.d.luau"
need_defs() {
  [ -s "$DEFS" ] && return 0
  curl -sSfL --retry 2 -o "$DEFS.part" \
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
  for t in rojo luau-lsp selene luau-compile; do need "$t" || echo "не удалось поставить $t"; done
  need_defs || echo "не удалось скачать globalTypes"
  exit 0
fi

mapfile -t FILES < <(find src -name '*.luau' | sort)

# 1–2. sourcemap + luau-lsp analyze
if need rojo && need luau-lsp && need_defs; then
  SOURCEMAP="$TOOLS/sourcemap.json"
  rojo sourcemap default.project.json -o "$SOURCEMAP" >/dev/null
  echo "== luau-lsp analyze (${#FILES[@]} файлов)"
  OUT="$(luau-lsp analyze --platform=roblox --definitions="$DEFS" --sourcemap="$SOURCEMAP" \
    --formatter=gnu src 2>&1)"
  RC=$?
  ISSUES="$(printf '%s\n' "$OUT" | grep -vE '^\[(INFO|WARN)\]')"
  if [ "$RC" -ne 0 ] || [ -n "$ISSUES" ]; then
    printf '%s\n' "$ISSUES" | sed "s#^$PWD/##"
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

if [ "$FAIL" -ne 0 ]; then
  echo "check.sh: НАЙДЕНЫ ОШИБКИ"
  exit 1
fi
echo "check.sh: OK"
