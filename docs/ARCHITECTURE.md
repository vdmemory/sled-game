# Архитектура

Игра пишется кодом без Roblox Studio: Luau-файлы в репозитории → Rojo собирает place →
GitHub Actions публикует его в Roblox через Open Cloud.

## Деплой

| Что | Где |
| --- | --- |
| Сборка | `rojo build default.project.json -o game.rbxl` (Rojo 7.4.4, `rokit.toml`) |
| Публикация | `scripts/publish.sh` → `POST apis.roblox.com/universes/v1/{universe}/places/{place}/versions?versionType=Published`, ретраи на 409/429/5xx |
| Workflow | `.github/workflows/deploy.yml` (правится только через веб GitHub — у сессии нет scope `workflow`) |
| staging | любой push в `main` → тестовый плейс «Игра на санях [ТЕСТ]» |
| production | тег `v*` → боевой плейс |
| Секреты | `ROBLOX_API_KEY` (репозиторий), `UNIVERSE_ID` / `PLACE_ID` (переменные окружений staging/production) |

409 «Server busy» = плейс открыт в Studio. После деплоя старые серверы живут ~25 с — перезаходить
после этого.

## Раскладка (default.project.json)

| Папка | Куда в игре | Что там |
| --- | --- | --- |
| `src/shared` | `ReplicatedStorage.Shared` | `Config` (все числа и баланс, `TUNABLES` для настройки на лету), `UIKit` (дизайн-система, 3D-иконки), `SledModels` (модели саней, рогатка по тирам, ракеты по тирам, обвес `extras`), `UIDecals` (генерируется деплоем: имя иконки → ID декали) |
| `src/server` | `ServerScriptService.Server` | `Main.server` (игроки, заезды, ремоуты, покупки, DevAction), `Track` (генерация трассы и лобби), `Props` (low-poly модели), `DataService` (DataStore), `Rewards` (задания, подарки, сундук), `Tuning` (переопределения Config: DataStore `GameConfig_v1` + MessagingService), `UIImages.server` (декали → ID картинок через InsertService → атрибуты `ReplicatedStorage.UIImages`) |
| `src/client` | `StarterPlayerScripts.Client` | `SledController` (физика санок, ввод, подбор предметов), `HUD` (лобби/заезд/итог), `LobbyMenus` (окна меню), `DevPanel` (панель владельца), `ConfigSync` (применяет переопределения Config), `Effects` (свет миров, частицы, пламя ракеты), `Sounds`, `Traffic` (движение машин), `Reveal` (анимация нового тира) |

## Как устроен заезд

1. Игрок жмёт «НАЖМИ, ЧТОБЫ ИГРАТЬ» или доходит по мостику до кольца `LaunchPad` → `startRun`.
2. Сервер берёт свободный слот (трассы игроков разнесены по X на `SLOT_SPACING`), строит
   `Track.new(slot, level, bestH)` и санки `makeSled` (невидимое `VehicleSeat` + модель из
   `SledModels` + декор тиров), сажает персонажа.
3. Клиент (`SledController`) видит свои санки в `workspace.Sleds` (атрибут `Owner`), даёт оттянуть
   рогатку → `Launch(power)`. Сервер отпускает санки и отдаёт network ownership клиенту.
4. Физику считает клиент (модель «импульса»: гравитация вдоль склона − трение − сопротивление,
   ракета, ускорители, бонусы саней). Касания препятствий, монет, гемов, кристаллов, магнитов
   ловит клиент и сообщает серверу.
5. Сервер раз в 0.2 с считает прогресс (`Track:progressOf`), строит трассу впереди
   (`ensureAround`), ловит финиш (дальше скольжение по ледяному озеру), вылет, остановку.
6. `endRun` начисляет монеты/гемы, прогресс заданий, шлёт `RunEnded`, через паузу пересоздаёт
   персонажа в лобби.

Машины, поезда и кабинки канатки (тег `Mover`) двигает каждый клиент сам по серверному времени
(`Traffic.client`) — плавно и одинаково у всех.

## Ремоуты (`ReplicatedStorage.Remotes`)

| Имя | Тип | Направление / смысл |
| --- | --- | --- |
| `StartRun` | Event | клиент → начать заезд |
| `Launch` | Event | клиент → выстрел рогатки (сила 0..1) |
| `Crash` | Event | клиент → врезался (сервер делает ragdoll) |
| `Air`, `Trick`, `Smash`, `Crystal`, `CoinGrab` | Event | клиент → время в воздухе, флипы, разбил препятствие, кристалл, монета магнитом |
| `Restart`, `Back` | Event | клиент → заново / в лобби с рогатки |
| `RunEnded` | Event | сервер → итог заезда |
| `TaskDone` | Event | сервер → задание выполнено |
| `SetSetting` | Event | клиент → настройка (Sfx/Snow/Shadows) |
| `PowerUp` | Event | клиент → подобрал бонус (x2, кольцо, магнит, щит, канистра, ускоритель) |
| `BuyUpgrade`, `SledAction`, `TrailAction` | Function | покупки/экипировка |
| `RewardAction` | Function | задания, сундук заданий, подарки, сундук лобби |
| `WorldAction` | Function | фарм пройденного мира / возврат / пропуск мира за Robux (владелец — тест любого мира) |
| `DevAction` | Function | только владелец (`UserId == CreatorId`): уровень, валюта, апгрейды, сани, сброс заданий, `tune` (сохранить переопределения Config для всех) |

## Атрибуты игрока (сервер → клиент)

`Coins`, `Gems`, `Level`, `LevelBest`, `LevelLength`, `ThemeName`, `*Level` (апгрейды), `Sled`, `SledRarity`, `OwnedSleds`, `Trail`, `OwnedTrails`, `Set*` (настройки),
`Rewards` (JSON: задания, подарки, сундук), в заезде — `InRun`, `Launched`, `RunDistance`,
`RunCoins`, `RunGems`, `Combo`, `Finished`.

## Теги CollectionService

`Obstacle`, `Coin`, `Gem`, `Crystal`, `Magnet`, `Boost`, `Mover`, бонусы `Shield`/`X2`/`Fuel`/`Ring`.
У лёгких препятствий — атрибут `Breakable`.

## Настройка на лету

`Config.TUNABLES` — список `{ путь, подпись, группа, min, max, шаг }`. Сервер (`Tuning`) при старте
читает DataStore `GameConfig_v1` → `Config.applyOverrides` → атрибут `ReplicatedStorage.ConfigOverrides`
(JSON); клиент (`ConfigSync`) применяет его к своему `Config`. Сохранение из панели владельца
(`DevAction("tune")`) пишет DataStore и шлёт `MessagingService` «SledConfigChanged» — остальные
серверы перечитывают. Параметры, которых нет в переопределениях, равны значениям из кода.

## Иконки интерфейса

`assets/ui/*.png` (Fluent Emoji 3D, MIT) → `scripts/upload_ui_assets.py` в деплое загружает новые
как Decal через Assets API → ID в `assets/ui/decals.json` и `src/shared/UIDecals.luau`
(коммитятся из лога между `UI_DECALS_JSON_BEGIN/END`). В игре `UIImages.server` достаёт ID
картинки из декали, клиент `UI.icon` показывает её после `PreloadAsync`, до того — эмодзи.

## Сохранение (DataStore `SledData_v1`, ключ `u_<UserId>`)

`Coins`, `Gems`, `Level`, `LevelBest`, `LaunchLevel`, `SledLevel`, `IncomeLevel`, `RocketLevel`,
`Sled`/`SledRarity`/`OwnedSleds`, `Trail`/`OwnedTrails`, `Settings` (`Sfx`, `Snow`, `Shadows`,
`Music`), `Daily` (задания дня), `ChestAt`, `FarmWorld`, `Receipts` (дедуп покупок). Новые поля добавляются в `DEFAULT` — старые сейвы получают их сами.
Если загрузка не удалась, сохранение для игрока отключается (чтобы не затереть прогресс).
Доска лидеров — `OrderedDataStore` `BestLevel_v1`.
