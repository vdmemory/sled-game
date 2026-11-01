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
| `src/shared` | `ReplicatedStorage.Shared` | `Config` (все числа и баланс), `UIKit` (стиль интерфейса), `SledModels` (3D-модели саней) |
| `src/server` | `ServerScriptService.Server` | `Main.server` (игроки, заезды, ремоуты), `Track` (генерация трассы и лобби), `Props` (low-poly модели), `DataService` (DataStore), `Rewards` (задания, подарки, сундук) |
| `src/client` | `StarterPlayerScripts.Client` | `SledController` (физика санок, ввод), `HUD` (лобби/заезд/итог), `LobbyMenus` (окна меню), `Effects`, `Sounds`, `Traffic` (движение машин) |

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
| `BuyUpgrade`, `SkinAction`, `SledAction`, `TrailAction` | Function | покупки/экипировка |
| `RewardAction` | Function | задания, сундук заданий, подарки, сундук лобби |

## Атрибуты игрока (сервер → клиент)

`Coins`, `Gems`, `Level`, `LevelBest`, `LevelLength`, `ThemeName`, `*Level` (апгрейды), `Skin`,
`OwnedSkins`, `Sled`, `SledRarity`, `OwnedSleds`, `Trail`, `OwnedTrails`, `Set*` (настройки),
`Rewards` (JSON: задания, подарки, сундук), в заезде — `InRun`, `Launched`, `RunDistance`,
`RunCoins`, `RunGems`, `Combo`, `Finished`.

## Теги CollectionService

`Obstacle`, `Coin`, `Gem`, `Crystal`, `Magnet`, `Boost`, `Mover`. У лёгких препятствий —
атрибут `Breakable`.

## Сохранение (DataStore `SledData_v1`, ключ `u_<UserId>`)

`Coins`, `Gems`, `Level`, `LevelBest`, `LaunchLevel`, `SledLevel`, `IncomeLevel`, `RocketLevel`,
`Skin`/`OwnedSkins`, `Sled`/`SledRarity`/`OwnedSleds`, `Trail`/`OwnedTrails`, `Settings`, `Daily`
(задания дня), `ChestAt`. Новые поля добавляются в `DEFAULT` — старые сейвы получают их сами.
Если загрузка не удалась, сохранение для игрока отключается (чтобы не затереть прогресс).
Доска лидеров — `OrderedDataStore` `BestLevel_v1`.
