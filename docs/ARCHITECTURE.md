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

409 «Server busy» = плейс открыт в Studio. После деплоя старые серверы живут ~30–45 с — перезаходить
после этого.

## Раскладка (default.project.json)

| Папка | Куда в игре | Что там |
| --- | --- | --- |
| `src/shared` | `ReplicatedStorage.Shared` | `Config` (все числа и баланс, `TUNABLES` для настройки на лету), `UIKit` (дизайн-система, 3D-иконки), `UIFx` (эффекты интерфейса: полёт валюты, тик чисел, вспышка выбора, сундук; только клиент), `SledModels` (модели саней, рогатка по тирам, ракеты по тирам, обвес `extras`), `Track` (генерация трассы: сервер — трассы заездов, клиент — витрина лобби), `SafeLine` (чистая раскладка рядов препятствий с безопасной линией, без Instance — можно гонять в luau CLI), `Props` (low-poly модели ландшафта и препятствий), `Lobby` (`build` — архитектура лобби на сервере, `dress` — декор по миру на клиенте), `UIDecals` (генерируется деплоем: имя иконки → ID декали) |
| `src/server` | `ServerScriptService.Server` | `Main.server` (игроки, заезды, ремоуты, покупки, DevAction), `AntiCheat` (правдоподобие заезда: предел скорости/пути, телепорт, полёт по серверу, проверки `Air`/`Trick`/`Smash`/`PowerUp`), `DataService` (DataStore), `Rewards` (задания, подарки, сундук), `Tuning` (переопределения Config: DataStore `GameConfig_v1` + MessagingService), `Analytics` (AnalyticsService: онбординг, экономика, события заездов — `docs/METRICS.md`), `UIImages.server` (декали → ID картинок через InsertService → атрибуты `ReplicatedStorage.UIImages`) |
| `src/client` | `StarterPlayerScripts.Client` | `SledController` (физика санок, ввод, подбор предметов), `HUD` (лобби/заезд/итог), `LobbyMenus` (окна меню), `DevPanel` (панель владельца), `ConfigSync` (применяет переопределения Config), `Effects` (свет и осадки миров — в заезде по `RunTheme`, в лобби по `LobbyTheme`; частицы, пламя ракеты), `Sounds`, `Traffic` (движение машин), `Reveal` (анимация нового тира «было → стало»), `LobbyScene` (локальная витринная трасса своего мира за мостиком, декор и земля лобби по миру, флаги на ветру), `Tutorial` (подсказки первых заездов: свой ScreenGui `DisplayOrder` 90, опрос 5 Гц атрибутов игрока и `SledController.State` — `AwaitingLaunch`, `Airborne`, `Fuel`, `RocketOn`, `Stick.X`; находит в HUD `PlayButton` и `Card_<апгрейд>`) |

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
5. Сервер раз в 0.2 с считает прогресс (`Track:progressOf`) и пропускает его через
   `AntiCheat.tick` (ниже), строит трассу впереди (`ensureAround`), ловит финиш (дальше скольжение
   по ледяному озеру), вылет, остановку.
6. `endRun` начисляет монеты/гемы, прогресс заданий, шлёт `RunEnded`, через паузу пересоздаёт
   персонажа в лобби.

### Античит (`server/AntiCheat`)
Клиенту отдана физика саней, поэтому всё, что он сообщает, сервер сверяет с правдоподобным.
Состояние — `run.ac` (создаёт `AntiCheat.start` на `Launch`), мягкие нарушения — `run.flags`.
- **Огибающая скорости** `env`: старт = max(рогатка × сила, потолок саней × (1 + бонус), терминал
  ракеты на земле ≈ 217); растёт только от честных источников — полёт по серверу с топливом
  (+тяга), засчитанный ускоритель (`onBoost`), засчитанные трюки (`onTrick`, × тот же буст, что у
  клиента), канистра (`onFuel`); на земле спадает по `AC_DECAY × DRAG × v²`. Предел =
  `env × AC_SPEED_MULT + AC_SPEED_ADD`.
- **`tick`** (в Heartbeat): `run.distance` растёт не быстрее предела × время с прошлого сдвига
  позиции (лаг до `AC_DT_MAX`); путь впереди засчитанного > `AC_LAG_SEC` предела или скорость
  саней > 2 предела — флаг (не чаще `AC_FLAG_COOLDOWN`); сдвиг по горизонтали за тик >
  `AC_TELEPORT_STUDS + предел × dt × AC_TELEPORT_MULT` — `"kill"`. Полёт = луч вниз
  `AC_AIR_HEIGHT` не задел свою трассу (`track.folder`); дольше `AC_MAX_AIR` — флаг.
- **`Air`** — `min(клиент, серверный полёт с прошлого Air + AC_AIR_GRACE)`, сумма ≤ время с
  выстрела; полёта не было — флаг. **`Trick`** — обороты проверяются по серверному полёту с
  прошлого Trick; полёта не было — флаг. **`Smash(model)`** — `Breakable` своей трассы, ближе
  `AC_NEAR_RADIUS + скорость × AC_NEAR_LAG`, один раз на модель. **`PowerUp`** — деталь своей
  трассы, тот же радиус, `Kind` — строка, `Taken` один раз.
- `≥ AC_FLAG_LIMIT` флагов или телепорт → `endRun(player, "cheat")`: наград, уровня, заданий нет,
  `warn` + `Analytics.custom("AntiCheatFlag", flags)`, у клиента «ЗАЕЗД НЕ ЗАСЧИТАН».

Машины, поезда и кабинки канатки (тег `Mover`) двигает каждый клиент сам по серверному времени
(`Traffic.client`) — плавно и одинаково у всех.

### Борта трассы

`Track.buildCrossSection` ставит у каждого куска (кроме жёлоба поворота, где стенками служат
ледяные пояса) по одному невидимому борту с каждой стороны у края дна: `Wall`, `CanCollide`,
`Transparency=1`, `CanQuery=false` (луч санок вниз и `GetPartBoundsInBox` его не видят), наклон
наружу `Config.WALL_TILT`, высота `Config.WALL_HEIGHT` (на приземлении после обрыва — вдвое выше),
отступ `Config.WALL_OFFSET`. Так санки не уезжают на сугроб и не проваливаются на стыке с куском без
сугроба (дорога, озеро). Снаружи остаётся общий `Barrier` у внешней кромки. Если санки всё же
оказались вне трассы, сервер заканчивает заезд как `fell` (`|x| > 2·TRACK_WIDTH` или `y < −60`)
или `stopped` (скорость ниже `STOP_SPEED` дольше `STOP_TIME`).

### Лобби и витрина

Сервер (`Lobby.build` через `Track.buildLobby`) строит общую архитектуру: площадку, плиту спавна,
пирс к обрыву с фонарями и гирляндами, арку-вывеску (`ArchBeam.Sign`), подиумы саней, табло,
костёр, флагштоки (тег `LobbyFlag`, атрибут `BaseCF`), спавн; под стартовой площадкой витрины —
невидимый `PreviewFloor` и зону посадки `LaunchPad` (в `Main.server`). Всё, что зависит от мира,
у каждого игрока своё и не реплицируется: `LobbyScene.client` при входе и при изменении
`Level`/`FarmWorld`/`InRun` (вне заезда) уничтожает старую сцену и строит заново
`Track.new(-1, уровень, 0, previewOrigin, Config.LOBBY_PREVIEW_SEGMENTS)` (папка `TrackPreview`,
только первые N кусков, без стены в конце) и папку `LobbyDecor` (`Lobby.dress(theme)`: деревья,
кактусы, кристаллы, горы, шары, сияние), перекрашивает `LobbyGround`/`PlazaRing`, пишет название
мира на арку и ставит себе атрибут `LobbyTheme` — по нему `Effects.client` плавно
(`Config.LOBBY_LOOK_TWEEN`) меняет небо, дымку, время суток и осадки (снег / пепел у вулкана /
сухо в каньоне и на конфетной горе). Локальная витрина монет не даёт: `SledController` собирает
монеты только рядом со своими санями в заезде (за 2000 studs от лобби).

## Ремоуты (`ReplicatedStorage.Remotes`)

| Имя | Тип | Направление / смысл |
| --- | --- | --- |
| `StartRun` | Event | клиент → начать заезд |
| `Launch` | Event | клиент → выстрел рогатки (сила 0..1) |
| `Crash` | Event | клиент → врезался (сервер делает ragdoll) |
| `Air`, `Trick`, `Smash`, `Crystal`, `CoinGrab` | Event | клиент → время в воздухе, трюки за полёт (`Trick(list { id, count }, airTime)` — сервер проверяет id, count ≤ 5, оборотов ≤ влезающих в серверный полёт), разбил препятствие (`Smash(model)` — модель `Breakable`), кристалл, монета магнитом; проверки — `AntiCheat` |
| `Restart`, `Back` | Event | клиент → заново / в лобби с рогатки |
| `RunEnded` | Event | сервер → итог заезда |
| `TaskDone` | Event | сервер → задание выполнено |
| `SetSetting` | Event | клиент → настройка (Sfx/Music/Snow/Shadows) |
| `PowerUp` | Event | клиент → подобрал бонус (x2, кольцо, магнит, щит, канистра, ускоритель) |
| `BuyUpgrade`, `SledAction`, `TrailAction` | Function | покупки/экипировка |
| `RewardAction` | Function | задания, сундук заданий, подарки, сундук лобби, `streak` (награда дня стрика, раз в UTC-день), `streakSave` (спасти серию за гемы, только в день после пропуска 1 дня и до награды), `streakDecline` |
| `WorldAction` | Function | фарм пройденного мира / возврат / пропуск мира за Robux (владелец — тест любого мира) |
| `TutorialStep` | Event | клиент → шаг обучения `i` показан/пройден (0 — пропустить всё); сервер проверяет целое 0…#`TUTORIAL.STEPS`, ставит бит в `Tutorial` один раз (повтор игнорируется), без наград |
| `DevAction` | Function | только владелец (`UserId == CreatorId`): уровень, валюта, апгрейды, сани, сброс заданий, `sessionShift` (сессия −5 мин, `Rewards.devShiftSession`), `streakNext`/`streakSkip` (дни стрика −1/−2, `Rewards.devStreakShift`), `resetTutorial` (обучение и `Stats.Runs` = 0), `tune` (сохранить переопределения Config для всех) |

## События между клиентскими скриптами (BindableEvent в `HUD`)

| Имя | Кто слушает | Смысл |
| --- | --- | --- |
| `UpgradeReveal(kind, tierName)` | `Reveal` | HUD получил от `BuyUpgrade` имя нового тира → большая анимация «было → стало» |
| `CurrencyGain(kind, amount, from)` | `HUD` | `kind` — `"coin"`/`"gem"`; `amount < 0` — держать счётчик на старом значении (перед запросом к серверу), `0` — отпустить, `> 0` — `UIFx.flyCurrency` из `from` (GuiObject или Vector2) к пилюле, затем `tickNumber` до текущего атрибута. Вызывает `LobbyMenus` после `RewardAction`; без события валюта обновляется мгновенно |

Эффекты (`shared/UIFx`) рисуются в своём ScreenGui `UIFx` с `DisplayOrder` 100 — поверх HUD (0),
DevPanel (30) и Reveal (40); каждый эффект держит не больше одного `RenderStepped`/`Heartbeat`
и отключает его по завершении, созданные инстансы уничтожаются.

## Атрибуты игрока (сервер → клиент)

`Coins`, `Gems`, `Level`, `LevelBest`, `LevelLength`, `ThemeName`, `*Level` (апгрейды), `Sled`, `SledRarity`, `OwnedSleds`, `Trail`, `OwnedTrails`, `Set*` (настройки), `Tutorial` (биты шагов обучения), `Runs` (`Stats.Runs`),
`Rewards` (JSON: задания, подарки, сундук; `sessionStart`, `big` — индекс большого подарка), в заезде — `InRun`, `Launched`, `RunDistance`,
`RunCoins`, `RunGems`, `Combo`, `Finished`. Только у клиента (ставит сам, не реплицируется):
`LobbyTheme` (тема витрины лобби, `LobbyScene` → `Effects`), `LowQuality`.

## Теги CollectionService

`Obstacle`, `Coin`, `Gem`, `Crystal`, `Magnet`, `Boost`, `Mover`, бонусы `Shield`/`X2`/`Fuel`/`Ring`,
`LobbyFlag` (флаги лобби, качает клиент).
У лёгких препятствий — атрибут `Breakable`.

## Настройка на лету

`Config.TUNABLES` — список `{ путь, подпись, группа, min, max, шаг }`. Переопределения `{ путь = число }`
лежат в DataStore `GameConfig_v1` в двух слоях:

| Слой | Ключ DataStore | Атрибут для клиента | Кому |
| --- | --- | --- | --- |
| общий (`scope = "all"`) | `overrides` | `ReplicatedStorage.ConfigOverrides` (JSON) | всем |
| персональный (`scope = "player"`) | `p_<UserId>` | `Player.ConfigOverrides` (JSON) | одному игроку, поверх общего |

Сервер (`Tuning`): `init()` читает общий ключ и применяет `Config.applyOverrides`; `loadPlayer(player)`
при входе читает `p_<UserId>` (pcall, 3 ретрая) и ставит атрибут игроку; `unloadPlayer` при выходе.
`merged(player)` = по умолчанию ← общие ← персональные. Клиент (`ConfigSync`) сливает оба атрибута
сам и пересчитывает при изменении любого из них.

Сервер хранит в `Config` общие значения. Расчёты, которые должны учитывать персональный слой,
оборачиваются в `Tuning.forPlayer(player, fn)`: временно `applyOverrides(merged)`, вызов `fn`,
восстановление общих (pcall + rethrow). Это безопасно только для синхронного `fn` — Luau не
прерывает поток до первого yield, поэтому другие игроки подмены не видят; внутри `fn` нельзя
`task.wait`/DataStore/`InvokeClient`. Повторный вход для того же игрока — просто вызов. Обёрнуто
в `Main.server`: `BuyUpgrade`, `SledAction`, `TrailAction`, расчёт наград в `endRun` (до первого
yield), `Launch` (сила рогатки), монеты за полёт/трюки/разбитые препятствия/кристалл/кольца/x2,
`awardCoin`, радиус магнита, генерация трассы (`Track.new`, `ensureAround`).

Сохранение из панели владельца — `DevAction("tune", overrides, scope, target)` (`target` — UserId
или ник; ник резолвит `Players:GetUserIdFromNameAsync` в pcall) → `Tuning.save(scope, userId,
overrides)` пишет нужный ключ (пустой персональный набор — `RemoveAsync`) и шлёт
`MessagingService` «SledConfigChanged» с `{ scope, userId, job }` — остальные серверы перечитывают
только этот ключ (персональный — если игрок у них онлайн). `DevAction("tuneGet", target)` отдаёт
панели персональный слой игрока (онлайн — из памяти, офлайн — из DataStore). Параметры, которых
нет в переопределениях, равны значениям из кода.

## Иконки интерфейса

`assets/ui/*.png` (Fluent Emoji 3D, MIT) → `scripts/upload_ui_assets.py` в деплое загружает новые
как Decal через Assets API → ID в `assets/ui/decals.json` и `src/shared/UIDecals.luau`
(коммитятся из лога между `UI_DECALS_JSON_BEGIN/END`). В игре `UIImages.server` достаёт ID
картинки из декали, клиент `UI.icon` показывает её после `PreloadAsync`, до того — эмодзи.

## Сохранение (DataStore `SledData_v1`, ключ `u_<UserId>`)

`Coins`, `Gems`, `Level`, `LevelBest`, `LaunchLevel`, `SledLevel`, `IncomeLevel`, `RocketLevel`,
`Sled`/`SledRarity`/`OwnedSleds`, `Trail`/`OwnedTrails`, `Settings` (`Sfx`, `Snow`, `Shadows`,
`Music`), `Daily` (задания дня; `Daily.big` — большой подарок получен сегодня), `ChestAt`, `GiftsClaimed` (подарки за время, сбрасываются при входе), `Streak` (`day` — последний засчитанный UTC-день, `count` — серия, `claimedDay` — день последней награды, `save` — серия, которую можно спасти сегодня; пересчёт в `Rewards.ensure`, недостающие ключи у старых сейвов дополняет `migrate`), `FarmWorld`, `Receipts` (дедуп покупок), `Stats` (Runs, Finishes,
Onboard, Purchases, Playtime — для аналитики), `Tutorial` (биты пройденных шагов `Config.TUTORIAL.STEPS`, порядок не менять; при входе с `Stats.Runs ≥ 3` — все биты). Новые поля добавляются в `DEFAULT` — старые сейвы получают их сами.
Новые поля — в `DEFAULT`, миграции — `migrate()` в `DataService`.

**Сессионная блокировка (#14).** Всё чтение/запись — `UpdateAsync`; в записи служебное поле
`_session = { jobId, ts }` (в памяти профиля его нет). Старые сейвы без `_session` берутся сразу —
формат обратно совместим, миграция не нужна.
- Загрузка: блокировка свободна / наша / старше `Config.DATA_LOCK_STALE` (2 автосейва + 30 с) —
  берём. Чужая живая — ждём её снятия до `DATA_LOCK_WAIT` (30 с, опрос 5 с), затем забираем силой.
- Сохранение (автосейв `DATA_AUTOSAVE`, покупка, выход, `BindToClose`) пишет, только если
  `_session.jobId == game.JobId` (или блокировка снята); иначе запись отменяется, `canSave = false`,
  игрок кикается «Прогресс открыт на другом сервере, перезайди». Записи одного профиля — по очереди.
- Выход и `BindToClose` снимают блокировку (`_session = nil`); после этого профиль не пишется.

**Ошибка загрузки (#16).** 5 попыток с паузой; не вышло — кик «Не удалось загрузить прогресс,
перезайди» (сейв в DataStore не тронут, профиль-заглушка не создаётся). В Studio вместо кика —
игра без сохранения. `ProcessReceipt` выдаёт покупку только при `canSave` и подтверждает только
после успешной записи.
Доска лидеров — `OrderedDataStore` `BestLevel_v1`.
