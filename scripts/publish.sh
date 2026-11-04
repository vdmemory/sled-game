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

# Иконки интерфейса: новые PNG из assets/ui загружаются в Roblox (нужны права ключа на
# Assets API). Если появились новые ID — пересобираем место, чтобы они попали в игру.
# ID печатаются в лог деплоя; их сохраняют в репозиторий (assets/ui/decals.json).
if [ -f scripts/upload_ui_assets.py ] && [ -z "${SKIP_UI_ASSETS:-}" ]; then
  BEFORE=$(cat src/shared/UIDecals.luau 2>/dev/null || true)
  python3 scripts/upload_ui_assets.py || echo "::warning::загрузка иконок не удалась"
  if [ "$BEFORE" != "$(cat src/shared/UIDecals.luau 2>/dev/null || true)" ]; then
    ROJO="$(find "${RUNNER_TEMP:-/tmp}" -type f -name rojo 2>/dev/null | head -n 1)"
    if [ -n "$ROJO" ]; then
      "$ROJO" build default.project.json -o "$FILE" && echo "Пересобрано с новыми иконками"
    fi
    echo "UI_DECALS_JSON_BEGIN"; cat assets/ui/decals.json; echo "UI_DECALS_JSON_END"
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
