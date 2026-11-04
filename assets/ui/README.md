# Иконки интерфейса

3D-иконки из [Microsoft Fluent Emoji](https://github.com/microsoft/fluentui-emoji) (лицензия MIT,
см. `LICENSE-FluentEmoji.txt`), 256×256 PNG.

Деплой (`scripts/upload_ui_assets.py`) загружает новые PNG в Roblox как декали и записывает ID в
`decals.json` и `src/shared/UIDecals.luau`. В игре сервер (`UIImages.server`) получает из декалей
ID картинок, а интерфейс (`UI.icon`) показывает их; пока картинки нет — эмодзи-заглушку.

Добавить иконку: положить `имя.png` сюда, добавить эмодзи-заглушку в `UI.EMOJI`, использовать
`UI.icon("имя", …)`. Ключу ROBLOX_API_KEY нужны права Assets API (asset:read, asset:write).
