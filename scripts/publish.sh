#!/usr/bin/env bash
# Публикует собранный .rbxl в Roblox через Open Cloud.
# Нужны переменные окружения: ROBLOX_API_KEY, UNIVERSE_ID, PLACE_ID
# Локально:  rojo build -o game.rbxl && ./scripts/publish.sh game.rbxl
set -euo pipefail

FILE="${1:-game.rbxl}"
: "${ROBLOX_API_KEY:?нужен ROBLOX_API_KEY}"
: "${UNIVERSE_ID:?нужен UNIVERSE_ID}"
: "${PLACE_ID:?нужен PLACE_ID}"
VERSION_TYPE="${VERSION_TYPE:-Published}" # Published — сразу в игру
ATTEMPTS="${ATTEMPTS:-6}"

[ -f "$FILE" ] || { echo "Нет файла $FILE"; exit 1; }

# Статическая проверка (scripts/check.sh: luau-lsp с типами Roblox, selene, luau-compile) — до
# публикации: ошибка в коде останавливает деплой. Инструменты check.sh скачивает сам (фиксированные
# версии); если скачать не вышло — предупреждение, деплой продолжается. SKIP_CHECK=1 — пропустить.
if [ -f scripts/check.sh ] && [ -z "${SKIP_CHECK:-}" ]; then
  bash scripts/check.sh || { echo "::error::scripts/check.sh нашёл ошибки — публикация отменена"; exit 1; }
fi

# Иконки интерфейса: новые PNG из assets/ui загружаются в Roblox (нужны права ключа на
# Assets API). Если появились новые ID — пересобираем место, чтобы они попали в игру.
# ID печатаются в лог деплоя; их сохраняют в репозиторий (assets/ui/decals.json).
REBUILD=""
if [ -f scripts/upload_ui_assets.py ] && [ -z "${SKIP_UI_ASSETS:-}" ]; then
  BEFORE=$(cat src/shared/UIDecals.luau 2>/dev/null || true)
  python3 scripts/upload_ui_assets.py || echo "::warning::загрузка иконок не удалась"
  if [ "$BEFORE" != "$(cat src/shared/UIDecals.luau 2>/dev/null || true)" ]; then
    REBUILD=1
    echo "UI_DECALS_JSON_BEGIN"; cat assets/ui/decals.json; echo "UI_DECALS_JSON_END"
  fi
fi

# Меши декора (#45): assets/meshes/*.glb → ассеты Model (Assets API, права те же: asset:read+write).
# Новые ID → src/shared/MeshIds.luau → пересборка; в лог MESH_IDS_JSON_BEGIN/END — их коммитят в
# assets/meshes/meshes.json и MeshIds.luau. Без прав/ошибка — warning, игра строит декор из Part.
if [ -f scripts/upload_meshes.py ] && [ -z "${SKIP_MESHES:-}" ]; then
  BEFORE=$(cat src/shared/MeshIds.luau 2>/dev/null || true)
  python3 scripts/upload_meshes.py || echo "::warning::загрузка мешей не удалась"
  if [ "$BEFORE" != "$(cat src/shared/MeshIds.luau 2>/dev/null || true)" ]; then
    REBUILD=1
    echo "MESH_IDS_JSON_BEGIN"; cat assets/meshes/meshes.json; echo "MESH_IDS_JSON_END"
  fi
fi

# Звуки: assets/audio/sfx_atlas.ogg (атлас, scripts/gen_audio.py) → ассет Audio (права те же: asset:read+write).
# Новый ID → src/shared/AudioIds.luau → пересборка; в лог AUDIO_IDS_JSON_BEGIN/END — их коммитят в
# assets/audio/audio.json и AudioIds.luau. Без прав/лимит — warning, играют встроенные звуки.
if [ -f scripts/upload_audio.py ] && [ -z "${SKIP_AUDIO:-}" ]; then
  BEFORE=$(cat src/shared/AudioIds.luau 2>/dev/null || true)
  python3 scripts/upload_audio.py || echo "::warning::загрузка аудио не удалась"
  if [ "$BEFORE" != "$(cat src/shared/AudioIds.luau 2>/dev/null || true)" ]; then
    REBUILD=1
    echo "AUDIO_IDS_JSON_BEGIN"; cat assets/audio/audio.json 2>/dev/null; echo "AUDIO_IDS_JSON_END"
  fi
fi

if [ -n "$REBUILD" ]; then
  ROJO="$(find "${RUNNER_TEMP:-/tmp}" -type f -name rojo 2>/dev/null | head -n 1)"
  if [ -n "$ROJO" ]; then
    "$ROJO" build default.project.json -o "$FILE" && echo "Пересобрано с новыми ассетами (иконки/меши)"
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
