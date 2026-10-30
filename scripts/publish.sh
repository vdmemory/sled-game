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
