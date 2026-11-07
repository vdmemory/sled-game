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
- **`scripts/check.sh`** — одна команда перед каждым пушем, код выхода ≠ 0 при ошибках:
  1. `rojo sourcemap` → `.tools/sourcemap.json` (карта DataModel: `require(script.Parent.X)`,
     `Shared.Track` → `Track/init.luau` резолвятся);
  2. `luau-lsp analyze --platform=roblox --definitions=globalTypes(None) --sourcemap` — знает
     типы Roblox API: ловит необъявленные переменные (пропавший `C = UI.C` после слияния),
     несуществующие `Enum.X.Y` (`AnalyticsEconomyTransactionType.Reward`), опечатки в свойствах,
     `Shape` у `BasePart`, deprecated API (`LoadCharacter`), циклы require между модулями;
  3. `selene src` по `selene.toml` (`std = "roblox"`, карта API — `roblox.yml`, генерирует
     `selene generate-roblox-std`): неиспользуемые переменные, одинаковые ветки `if` и т. п.;
  4. `luau-compile --null` по каждому файлу — синтаксис, как сборка Open Cloud.
- Инструменты: из `PATH`, иначе из `.tools/bin` (в `.gitignore`); недостающие `check.sh` сам
  скачивает с GitHub releases с фиксированными версиями (rojo 7.4.4, luau-lsp 1.70.1, selene 0.31.0,
  luau 0.746; `globalTypes.None.d.luau` с тега luau-lsp). `scripts/check.sh --install` — только
  поставить. Нет сети и инструмента — шаг пропускается с предупреждением
  (`CHECK_REQUIRE_TOOLS=1` — ошибка).
- **В CI**: `scripts/publish.sh` запускает `check.sh` до публикации (workflow не менялся) —
  ошибка останавливает деплой, `SKIP_CHECK=1` — пропустить. Сеть на раннере есть, инструменты
  скачиваются за секунды.
- Ложное срабатывание глушится точечно и с комментарием: приведение `(x :: any)` в месте
  ошибки (пример: `require` PlayerModule, сужение `trick` в `Sled/Tricks`), правило selene —
  в `selene.toml` с причиной. Массово `--!nolint`/`--!nocheck` не ставить.
- В облачной сессии за прокси selene не может сам скачать карту API (TLS прокси): положить
  `roblox.yml`, сгенерированный из скачанного curl-ом `API-Dump.json`, в корень (в CI не нужно).
- `StyLua` — не подключён (стиль держим вручную по этому документу).
- Сверка генерации трассы до/после рефакторинга — детерминизм по seed: стенд из шимов Roblox
  API запускает `shared/*` в luau CLI и снимает отпечаток всех инстансов уровней, витрины и
  лобби (`docs/CHANGELOG.md`, #17/#18).
- F9 в клиенте (Client/Server логи), `AnalyticsService` для воронки, `MicroProfiler` (Ctrl+F6)
  для FPS.

## Паттерны проекта
- Числа — в `Config` (+ `TUNABLES`), логика — в модулях; shared-код не зависит от серверных
  сервисов.
- Ремоуты создаются в `server/Remotes` (`remote(className, name)`), клиент ждёт
  `ReplicatedStorage:WaitForChild("Remotes")`.
- Новый предмет на трассе: `make*` в `Track/Items` + тег + обработчик в `client/Sled/Contacts` +
  ремоут `PowerUp` + серверный учёт в `server/Pickups`.
- Новый серверный обработчик — в модуле своей зоны (`Runs`/`RunEvents`/`Pickups`/`Shop`/
  `Purchases`/`DevTools`) внутри его `start()`; `Main.server` только вызывает `start()`.
- Новое поле сейва: `DataService.DEFAULT`; удаление — миграция с компенсацией.
- Новая модель транспорта: builder + `BUILDERS` + `MOUNTS` в `SledModels`, запись в
  `Config.SLEDS`, иконка в `assets/ui`.
- Документация с каждым изменением: `CHANGELOG`, при смене правил `GAME_DESIGN`, устройства —
  `ARCHITECTURE`, денег — `BUSINESS`, идей — `IDEAS`, движка для похожих игр — `PLAYBOOK`.
