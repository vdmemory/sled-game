# Инженерный стандарт (читают все агенты)

## Документация — где искать, прежде чем писать
- Официальные доки: https://create.roblox.com/docs (Engine API reference, guides). Актуальные
  страницы доступны агентам через Context7 (`resolve-library-id` → `query-docs`, библиотека
  Roblox Creator Docs) — сверяйся там, а не по памяти: API меняется (deprecated-методы,
  новые сервисы).
- Luau: https://luau.org/ (синтаксис, типы, `--!strict`, производительность) и
  https://create.roblox.com/docs/luau.
- DevForum (https://devforum.roblox.com) — Announcements, Scripting Support, Creator Roadmap;
  Release notes (https://create.roblox.com/docs/release-notes).
- Open Cloud: https://create.roblox.com/docs/cloud (publish, assets, DataStore API).
- Rojo: https://rojo.space/docs; Rokit: https://github.com/rojo-rbx/rokit.
- Политики: https://en.help.roblox.com/hc/en-us/articles/203313410 (Community Standards),
  монетизация — https://create.roblox.com/docs/production/monetization.

## Luau — как пишем
- Типы там, где они ловят ошибки: сигнатуры функций, таблицы конфигурации (`Config`), remote-
  обработчики (`player: Player`, явная проверка `typeof(arg) == "number"`). Экзотические
  аннотации (`{ { string, () -> () } }`) не компилируются в Open Cloud-сборке — `{ any }`.
- `task.*` вместо `wait`/`spawn`/`delay`; `pcall` вокруг DataStore, MessagingService,
  InsertService, MarketplaceService, HttpService; ретраи с экспоненциальной паузой.
- Циклы `for _, x in t do` (без `ipairs`/`pairs`, Luau поддерживает обобщённую итерацию);
  `string.format`, `utf8.len` для русского текста; `math.clamp`, `math.round`.
- Сервер — авторитет. Клиент шлёт события, сервер проверяет диапазон/частоту и начисляет.
  Network ownership отдаётся клиенту для физики своих саней — всё, что он сообщает, должно
  быть правдоподобно — это делает `server/AntiCheat` (предел скорости по огибающей, телепорт,
  полёт по серверу, «рядом ли» предмет); новое событие с наградой — через его проверки.
- Инстансы: `Instance.new` + свойства + `Parent` последним; `CollectionService` теги вместо
  поиска по имени; `Attributes` для данных, видимых клиенту; `Destroy()` и отключение
  `RBXScriptConnection` при конце заезда/смерти персонажа.
- Производительность: `Heartbeat`/`RenderStepped` без обхода `workspace`; стриминг трассы
  (`BUILD_AHEAD`/`KEEP_BEHIND`); минимум Part-ов, `CastShadow` только крупным, `Massless` +
  `CanCollide=false` для декора; UI не пересоздаётся в цикле; `ContentProvider:PreloadAsync`
  для картинок.
- Open Cloud publish не принимает Union, SurfaceAppearance, EditableImage/Mesh, BaseWrap.
  Обход: свои меши генерировать кодом и загружать отдельными ассетами через Open Cloud Assets API
  (в `scripts/publish.sh`, по образцу `upload_ui_assets.py`), в месте — `MeshPart` с `MeshId`; рельеф —
  Smooth Terrain из кода.

## Инструменты проверки
- `luau-compile --null <файл>` — синтаксис (путь в `CLAUDE.md`); `luau-analyze` — типы и
  предупреждения (ложные срабатывания на Roblox-глобалы — игнорировать `Unknown global`,
  остальное чинить).
- `selene` и `StyLua` — если установлены (`rokit add`), стиль и линт по `selene.toml`/
  `stylua.toml`; иначе — ручное соблюдение этого документа.
- F9 в клиенте (Client/Server логи), `AnalyticsService` для воронки, `MicroProfiler` (Ctrl+F6)
  для FPS.

## Паттерны проекта
- Числа — в `Config` (+ `TUNABLES`), логика — в модулях; shared-код не зависит от серверных
  сервисов.
- Ремоуты создаются в `Main.server` (`remote(className, name)`), клиент ждёт
  `ReplicatedStorage:WaitForChild("Remotes")`.
- Новый предмет на трассе: `make*` в `Track` + тег + обработчик в `SledController` + ремоут
  `PowerUp` + серверный учёт в `Main`.
- Новое поле сейва: `DataService.DEFAULT`; удаление — миграция с компенсацией.
- Новая модель транспорта: builder + `BUILDERS` + `MOUNTS` в `SledModels`, запись в
  `Config.SLEDS`, иконка в `assets/ui`.
- Документация с каждым изменением: `CHANGELOG`, при смене правил `GAME_DESIGN`, устройства —
  `ARCHITECTURE`, денег — `BUSINESS`, идей — `IDEAS`, движка для похожих игр — `PLAYBOOK`.
