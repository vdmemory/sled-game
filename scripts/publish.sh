#!/usr/bin/env bash
# Публикует собранный .rbxl в Roblox через Open Cloud.
# Нужны переменные окружения: ROBLOX_API_KEY, UNIVERSE_ID, PLACE_ID
# Локально:  rojo build -o game.rbxl && ./scripts/publish.sh game.rbxl
# (нет game.rbxl — скрипт соберёт сам: rojo из PATH или .tools/bin, его ставит check.sh с повторами)
#
# Переключатели: SKIP_CHECK, SKIP_UI_ASSETS, SKIP_MESHES, SKIP_AUDIO, SKIP_METRICS — пропустить шаг;
# ALLOW_STALE_BUILD=1 — публиковать, даже если пересборка с новыми ID не удалась;
# ASSET_IDS_UNCOMMITTED_OK=1 — незакоммиченные новые ID ассетов только предупреждение, не ошибка.
set -euo pipefail

FILE="${1:-game.rbxl}"
: "${ROBLOX_API_KEY:?нужен ROBLOX_API_KEY}"
: "${UNIVERSE_ID:?нужен UNIVERSE_ID}"
: "${PLACE_ID:?нужен PLACE_ID}"
VERSION_TYPE="${VERSION_TYPE:-Published}" # Published — сразу в игру
ATTEMPTS="${ATTEMPTS:-6}"

annot() { # уровень заголовок текст → аннотация GitHub (видна на странице run) + строка в Summary
  if [ -n "${GITHUB_ACTIONS:-}" ]; then echo "::$1 title=$2::$3"; else echo "[$1] $2: $3"; fi
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then printf -- '- **%s** — %s\n' "$2" "$3" >>"$GITHUB_STEP_SUMMARY"; fi
  return 0
}

# Rojo: PATH → .tools/bin (ставит check.sh, curl --retry) → $RUNNER_TEMP (ставит workflow).
find_rojo() {
  if command -v rojo 2>/dev/null; then return 0; fi
  if [ -x .tools/bin/rojo ]; then echo "$PWD/.tools/bin/rojo"; return 0; fi
  find "${RUNNER_TEMP:-/tmp}" -type f -name rojo -perm -u+x 2>/dev/null | head -n 1 | grep .
}
ensure_rojo() {
  ROJO="$(find_rojo || true)"
  if [ -z "$ROJO" ]; then
    bash scripts/check.sh --install >/dev/null 2>&1 || true
    ROJO="$(find_rojo || true)"
  fi
  [ -n "$ROJO" ]
}

if [ ! -f "$FILE" ]; then
  if ensure_rojo && "$ROJO" build default.project.json -o "$FILE"; then
    echo "Собрано: $FILE"
  else
    echo "Нет файла $FILE, собрать не удалось (rojo: ${ROJO:-не найден})"
    exit 1
  fi
fi

# Статическая проверка (scripts/check.sh: luau-lsp с типами Roblox, selene, luau-compile) — до
# публикации: ошибка в коде останавливает деплой. Инструменты check.sh скачивает сам (фиксированные
# версии); если скачать не вышло — предупреждение, деплой продолжается. SKIP_CHECK=1 — пропустить.
if [ -f scripts/check.sh ] && [ -z "${SKIP_CHECK:-}" ]; then
  bash scripts/check.sh || { echo "::error::scripts/check.sh нашёл ошибки — публикация отменена"; exit 1; }
fi

# ---- Ассеты: иконки (assets/ui/*.png → Decal), меши (#45, assets/meshes/*.glb → Model),
# аудио (assets/audio/sfx_atlas_v2.ogg → Audio). Права ключа: Assets API asset:read + asset:write.
# Каждый upload_*.py пишет ID в assets/**/*.json и src/shared/*Ids.luau; код 3 — часть не загружена
# (в игре фолбэк). Новые ID → место пересобирается (иначе ушёл бы game.rbxl без них — пересборка не
# удалась → публикация отменяется). Новые ID надо закоммитить (блок *_JSON_BEGIN/END в логе и в
# Summary): незакоммиченные загружаются заново при каждом деплое (аудио — лимит 10 в месяц!),
# поэтому job с незакоммиченными ID падает ПОСЛЕ успешной публикации — чтобы это заметили сразу.
REBUILD=""
ASSET_FAILS=()
UNCOMMITTED=()
dirty() { # файл отличается от закоммиченного (вне git-репозитория — считаем чистым)
  git rev-parse --git-dir >/dev/null 2>&1 && [ -n "$(git status --porcelain -- "$1" 2>/dev/null)" ]
}
upload_assets() { # что скрипт файл_luau файл_json метка_лога фолбэк_в_игре
  local name="$1" script="$2" luau="$3" json="$4" tag="$5" fallback="$6" before rc=0
  [ -f "$script" ] || return 0
  before="$(cat "$luau" 2>/dev/null || true)"
  python3 "$script" || rc=$?
  if [ "$rc" -ne 0 ]; then
    ASSET_FAILS+=("$name")
    annot warning "Загружены не все $name" "в игре $fallback; причина и что сделать — в логе шага выше"
  fi
  if [ "$before" != "$(cat "$luau" 2>/dev/null || true)" ]; then REBUILD=1; fi
  if dirty "$json" || dirty "$luau"; then
    UNCOMMITTED+=("$json" "$luau")
    echo "${tag}_JSON_BEGIN"; cat "$json" 2>/dev/null || true; echo "${tag}_JSON_END"
    if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
      { echo "### Новые ID ($name): закоммить \`$json\` и \`$luau\`"
        echo '```json'; cat "$json" 2>/dev/null || true; echo '```'; } >>"$GITHUB_STEP_SUMMARY"
    fi
  fi
}
if [ -z "${SKIP_UI_ASSETS:-}" ]; then
  upload_assets "иконки" scripts/upload_ui_assets.py src/shared/UIDecals.luau assets/ui/decals.json \
    UI_DECALS "эмодзи вместо картинок"
fi
if [ -z "${SKIP_MESHES:-}" ]; then
  upload_assets "меши" scripts/upload_meshes.py src/shared/MeshIds.luau assets/meshes/meshes.json \
    MESH_IDS "декор из Part"
fi
if [ -z "${SKIP_AUDIO:-}" ]; then
  upload_assets "аудио" scripts/upload_audio.py src/shared/AudioIds.luau assets/audio/audio.json \
    AUDIO_IDS "встроенные звуки"
fi

if [ -n "$REBUILD" ]; then
  if ensure_rojo && "$ROJO" build default.project.json -o "$FILE"; then
    echo "Пересобрано с новыми ID ассетов"
  elif [ -n "${ALLOW_STALE_BUILD:-}" ]; then
    annot warning "Опубликовано без новых ассетов" "пересборка не удалась (rojo: ${ROJO:-не найден}), ALLOW_STALE_BUILD=1"
  else
    annot error "Пересборка с новыми ассетами не удалась" "rojo: ${ROJO:-не найден}; публикация отменена, иначе в игру ушла бы сборка без новых ID. ALLOW_STALE_BUILD=1 — публиковать старую"
    exit 1
  fi
fi

# Метрики (Open Cloud Analytics Query API, бета): CSV печатается в лог между METRICS_CSV_BEGIN/END,
# недельная задача (docs/WEEKLY.md) забирает его из лога и коммитит. Нужно право ключа
# universe-analytics:read; без него — warning, деплой продолжается.
if [ -f scripts/fetch_metrics.py ] && [ -z "${SKIP_METRICS:-}" ]; then
  ROBLOX_ANALYTICS_KEY="${ROBLOX_ANALYTICS_KEY:-$ROBLOX_API_KEY}" DAYS="${METRICS_DAYS:-8}" \
    python3 scripts/fetch_metrics.py --print || echo "::warning::метрики не собраны"
fi

URL="https://apis.roblox.com/universes/v1/${UNIVERSE_ID}/places/${PLACE_ID}/versions?versionType=${VERSION_TYPE}"

for attempt in $(seq 1 "$ATTEMPTS"); do
  RESPONSE=$(curl -sS -w '\n%{http_code}' -X POST "$URL" \
    -H "x-api-key: ${ROBLOX_API_KEY}" \
    -H "Content-Type: application/octet-stream" \
    --data-binary @"$FILE") || RESPONSE=$'curl error\n000'

  BODY=$(echo "$RESPONSE" | head -n -1)
  CODE=$(echo "$RESPONSE" | tail -n 1)

  if [ "$CODE" = "200" ]; then
    echo "Опубликовано: $BODY"
    if [ "${#ASSET_FAILS[@]}" -gt 0 ]; then
      annot warning "Опубликовано без части ассетов" "${ASSET_FAILS[*]} — см. предупреждения выше"
    fi
    if [ "${#UNCOMMITTED[@]}" -gt 0 ]; then
      MSG="закоммить ${UNCOMMITTED[*]} (содержимое — в логе *_JSON_BEGIN/END и в Summary), иначе следующий деплой загрузит их заново (аудио: лимит 10 в месяц)"
      if [ -n "${ASSET_IDS_UNCOMMITTED_OK:-}" ]; then
        annot warning "Новые ID ассетов не в репозитории" "$MSG"
      else
        annot error "Опубликовано, но новые ID ассетов не в репозитории" "$MSG"
        exit 1
      fi
    fi
    exit 0
  fi

  # 409 (сервер занят), 429 (лимит), 5xx и сетевые ошибки — временные, пробуем ещё
  case "$CODE" in
    409|429|5*|000)
      WAIT=$((attempt * 20))
      echo "Попытка $attempt/$ATTEMPTS: HTTP $CODE: $BODY. Повтор через ${WAIT}с..."
      sleep "$WAIT"
      ;;
    *)
      echo "Ошибка публикации (HTTP $CODE): $BODY"
      [ "$CODE" = "401" ] || [ "$CODE" = "403" ] && echo "Проверь ROBLOX_API_KEY: права universe-places → Write для этого опыта и разрешённые IP."
      exit 1
      ;;
  esac
done

echo "Не удалось опубликовать после $ATTEMPTS попыток"
exit 1
