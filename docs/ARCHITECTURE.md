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
| `src/shared` | `ReplicatedStorage.Shared` | `Config` (все числа и баланс, `TUNABLES` для настройки на лету), `UIKit` (дизайн-система, 3D-иконки), `WorldLook` (пресеты света и пост-обработки миров, уровни графики), `UIFx` (эффекты интерфейса: полёт валюты, тик чисел, вспышка выбора, сундук; только клиент), `SledModels` (модели саней, рогатка по тирам, ракеты по тирам, обвес `extras`), `Track` (генерация трассы: сервер — трассы заездов, клиент — витрина лобби), `SafeLine` (чистая раскладка рядов препятствий с безопасной линией, без Instance — можно гонять в luau CLI), `Islands` (островки над пропастью #40: баллистика прыжков без Instance + постройка островков, ускорителей, пропасти, скал Terrain), `Props` (low-poly модели ландшафта и препятствий), `Lobby` (`build` — архитектура лобби на сервере, `dress` — декор по миру на клиенте), `UIDecals` (генерируется деплоем: имя иконки → ID декали) |
| `src/server` | `ServerScriptService.Server` | `Main.server` (игроки, заезды, ремоуты, покупки, DevAction), `AntiCheat` (правдоподобие заезда: предел скорости/пути, телепорт, полёт по серверу, проверки `Air`/`Trick`/`Smash`/`PowerUp`), `DataService` (DataStore), `Rewards` (задания, подарки, сундук), `Tuning` (переопределения Config: DataStore `GameConfig_v1` + MessagingService), `Analytics` (AnalyticsService: онбординг, экономика, события заездов — `docs/METRICS.md`), `UIImages.server` (декали → ID картинок через InsertService → атрибуты `ReplicatedStorage.UIImages`) |
| `src/shared` | `ReplicatedStorage.Shared` | `Config` (все числа и баланс, `TUNABLES` для настройки на лету), `UIKit` (дизайн-система, 3D-иконки), `UIFx` (эффекты интерфейса: полёт валюты, тик чисел, вспышка выбора, сундук; только клиент), `SledModels` (модели саней, рогатка по тирам, ракеты по тирам, обвес `extras`), `Track/` (генерация трассы: сервер — трассы заездов, клиент — витрина лобби; см. «Карта модулей»), `SafeLine` (чистая раскладка рядов препятствий с безопасной линией, без Instance — можно гонять в luau CLI), `Islands` (островки над пропастью #40: баллистика прыжков без Instance + постройка островков, ускорителей, пропасти, скал Terrain), `Props/` (low-poly модели ландшафта и препятствий, фасад `Props.*`), `Lobby` (`build` — архитектура лобби на сервере, `dress` — декор по миру на клиенте), `UIDecals` (генерируется деплоем: имя иконки → ID декали) |
| `src/server` | `ServerScriptService.Server` | `Main.server` (только порядок запуска и связывание) + `Remotes`, `Environment`, `Sleds`, `PlayerState`, `Runs`, `RunEvents`, `Pickups`, `Shop`, `Purchases`, `DevTools` (см. «Карта модулей»), `AntiCheat` (правдоподобие заезда: предел скорости/пути, телепорт, полёт по серверу, проверки `Air`/`Trick`/`Smash`/`PowerUp`), `DataService` (DataStore), `Rewards` (задания, подарки, сундук), `Tuning` (переопределения Config: DataStore `GameConfig_v1` + MessagingService), `Analytics` (AnalyticsService: онбординг, экономика, события заездов — `docs/METRICS.md`), `UIImages.server` (декали → ID картинок через InsertService → атрибуты `ReplicatedStorage.UIImages`) |
| `src/client` | `StarterPlayerScripts.Client` | `SledController` (посадка и кадр физики санок) + `Sled/` (`State`, `Input`, `Launch`, `Tricks`, `Contacts` — см. «Карта модулей»), `HUD` (лобби/заезд/итог), `LobbyMenus` (окна меню), `DevPanel` (панель владельца), `ConfigSync` (применяет переопределения Config), `Effects` (осадки миров — в заезде по `RunTheme`, в лобби по `LobbyTheme`; частицы, пламя ракеты; детектор FPS → `AutoLowFps`), `PostFX` (свет и пост-обработка миров по пресетам `shared/WorldLook`: Lighting, Atmosphere, Clouds, Sky, ColorCorrection, Bloom, SunRays, DepthOfField — с твином; уровень графики 1–3 → атрибут `GfxTier`; виньетка скорости), `Sounds`, `Traffic` (движение машин), `Reveal` (анимация нового тира «было → стало»), `LobbyScene` (локальная витринная трасса своего мира за мостиком, декор и земля лобби по миру, флаги на ветру), `Tutorial` (подсказки первых заездов: свой ScreenGui `DisplayOrder` 90, опрос 5 Гц атрибутов игрока и `SledController.State` — `AwaitingLaunch`, `Airborne`, `Fuel`, `RocketOn`, `Stick.X`; находит в HUD `PlayButton` и `Card_<апгрейд>`) |

## Карта модулей (после разбиения #17/#18, строки — 2026-11-08)

Порог — файл ≤ ~600 строк. Папка с `init.luau` в Rojo — ModuleScript с дочерними модулями:
`require(Shared.Track)` / `require(Shared.Props)` по-прежнему отдают весь API.

| Модуль | Строк | Что внутри |
| --- | --- | --- |
| `server/Main.server` | 81 | порядок запуска: `Tuning.init` → ремоуты в `ReplicatedStorage` → `Sleds.setup` (группа `Riders`, `workspace.Sleds`) → `Environment.setup` (свет) → `Track.buildLobby` → `Weekly.start` → `*.start()` обработчиков → `Runs.startLoop` (Heartbeat) → игроки, автосейв, `BindToClose` |
| `server/Remotes` | 37 | все ремоуты (папка `Remotes`); `Remotes.folder` кладёт в `ReplicatedStorage` Main |
| `server/Environment` | 48 | Lighting, облака, цветокоррекция, bloom |
| `server/Sleds` | 145 | `makeSled` (сиденье, модель/редкость/тиры, след, ракеты, крепления), `ragdoll`, `setRider` |
| `server/PlayerState` | 158 | `sync` (профиль → атрибуты), `onPlayerAdded`, `postLevel` (OrderedDataStore `BestLevel_v1`), `TutorialStep`, `SetSetting` |
| `server/Runs` | 532 | `runs`/`slots`/`ending`, `startRun`, `endRun` (награды, задания, неделя, `RunEnded`), зона посадки `LaunchPad`, `Restart`/`Back`, Heartbeat (прогресс, античит, финиш, остановка), `onLeave` |
| `server/RunEvents` | 215 | `Launch`, `Air`, `Crash`, `Smash`, `Trick` |
| `server/Pickups` | 188 | монеты (касание, магнит `CoinGrab`, комбо), `PowerUp` (x2, кольца, канистра, ускорители), гемы, кристалл |
| `server/Shop` | 185 | `SledAction`, `TrailAction`, `RewardAction`, `BuyUpgrade`, `WorldAction` |
| `server/Purchases` | 71 | геймпасс x2, `PRODUCT_HANDLERS`, `ProcessReceipt` (дедуп чеков) |
| `server/DevTools` | 109 | `DevAction` (только `game.CreatorId`) |
| `client/SledController` | 384 | посадка/высадка, кадр физики (скорость вдоль склона, руль, подсадка, прыжок, приземление) |
| `client/Sled/State` | 133 | общее состояние санок (`st.speed`, `st.sled`, `st.trick`…) и объекты под контроллером (`State`, `Sfx`, `RequestLaunch`, `RocketInput`, `TrickPopup`) |
| `client/Sled/Input` | 109 | руль: клавиатура, PlayerModule, свайп с кольцом (`Stick`) |
| `client/Sled/Launch` | 117 | рогатка: натяжение, выстрел `Launch(power)` |
| `client/Sled/Tricks` | 345 | ручные и авто-трюки, `Tricks.land` (итог полёта), `Tricks.air` (кадр в воздухе), кнопки прыжка/ракеты |
| `client/Sled/Contacts` | 386 | касания (авария, разбивание, щит, бонусы, гемы, кристалл, ускорители), `Contacts.scan` (монеты по отрезку пути, магнит) |
| `shared/Track/init` | 558 | класс трассы: `new`, `buildStart`, `buildSegment`, `buildRoad`, `setMover`, `ensureAround`, `progressOf`, `destroy` |
| `shared/Track/Profile` | 244 | `buildProfile` — цепочка кусков уровня (тип `Segment`) |
| `shared/Track/Sections` | 167 | профили сечений, цвета снега, `sidePoint`, поперечное сечение куска |
| `shared/Track/Dress` | 231 | оформление миров вдоль трассы и разметка на ней |
| `shared/Track/Items` | 189 | монеты, гемы, магнит, бонусы, кристалл, `tagObstacle` |
| `shared/Props/init` | 16 | фасад: подключает модули категорий, отдаёт таблицу `Props` |
| `shared/Props/Base` | 100 | `part`, `deco`, `pick`, надписи, колёса, общие цвета |
| `shared/Props/Vehicles` | 207 | машины, трафик, поезд, канатка, знаки |
| `shared/Props/Obstacles` | 337 | препятствия и `Props.obstacle(theme, …)` |
| `shared/Props/Decor` | 271 | деревья, постройки, горы, трамплин, шар |
| `shared/Props/Worlds` | 234 | модели миров 4–7 |
| `shared/Props/LobbyDecor` | 103 | костёр, флагшток, гирлянда |

Зависимости сервера без циклов: `Remotes`, `Sleds` ← `PlayerState` ← `Runs` ← `RunEvents`,
`Pickups`, `Shop`, `Purchases`, `DevTools` ← `Main`. Клиент: `State` ← `Input`, `Launch` ←
`Tricks`; `State` ← `Contacts`; все ← `SledController` (вызывает `State.init(script)` до require
остальных). Цикл require `luau-lsp` показывает ошибкой (`scripts/check.sh`).

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

### Профиль трассы, гладкость и островки (#40)
- `Track.buildProfile` собирает куски через `add` (скругляет стык: переходные куски `fillet`,
  если уклон меняется больше `SMOOTH_KINK`) или `push` (как есть — после обрыва/ускорителя).
  У куска: `vis` — длина визуальной части сечения (поворот: борта/декор строит 1-я из
  `CURVE_SUBSTEPS` частей пола, остальные — только `Floor`), `yawJoint`/`floorAhead` — пол
  заходит вперёд на 1 stud перед стыком со сменой направления. Пол (`Floor`) — без сдвига по
  высоте и встык; визуальные части — с перекрытием и сдвигом 0.03 (от мерцания).
- `shared/Islands`: чистая баллистика (`takeoff`, `landX`, `coinArc`, `plan` — без Instance) +
  постройка (`buildIn`, `buildIsle`, `buildGap`, `buildLauncher`). Куски `isleIn` → `gap` →
  `isle` … → `gap` → `landing`; у `isle`/`gap` в `seg.isle` план. Ускоритель — `Ramp` с атрибутами
  `LaunchMin`/`LaunchMax`/`Lift` (читает `SledController`: окно скорости вылета, подброс) и
  дорожка `Boost` перед ним (обычный ускоритель: +`BOOST_ADD`, `PowerUp` → `AntiCheat.onBoost`).
- **Smooth Terrain** (скалы под островками, стены каньона) — только на сервере и не в витрине:
  каждая заливка запоминается в `track.clears[i]`, при выходе куска из стриминга и в
  `Track:destroy` стирается `FillBlock(Air)` (`Islands.clear`). Луч античита (`Include` папки
  трассы) Terrain не видит; луч санок видит, но скалы ниже траекторий. Пропасть без коллизий —
  падение заканчивает заезд как `fell` (`y < −60`).
- `Track:progressOf` ищет кусок в окне hint −8…+40 (куски пола поворота и переходы короткие).
- `SafeLine.plan` пропускает `fillet` при проверке «после приземления первые 60 studs чистые».
- `SledController`: «подсадка» на ступеньку ≤ `STEP_UP_MAX` впереди (луч из `STEP_PROBE`, та же
  нормаль ±1.5°) — сани поднимаются по нормали до удара о торец. Код трюков не менялся.
- Проверки (luau CLI + шимы Roblox-API с настоящей CFrame-математикой): `scratchpad/smooth/` —
  `check_tail.luau` (стыки ур. 1–30), `isle_tail.luau` (баллистика ур. 1–50), `parts_tail.luau`
  (Part-ы на кусок и в окне стриминга); сборка `python3 build.py <src/shared> <tail>`.

### Лобби и витрина

Сервер (`Lobby.build` через `Track.buildLobby`) строит общую архитектуру: площадку, плиту спавна,
пирс к обрыву с фонарями и гирляндами, арку-вывеску (`ArchBeam.Sign`), подиумы саней, табло,
костёр, флагштоки (тег `LobbyFlag`, атрибут `BaseCF`), спавн; под стартовой площадкой витрины —
невидимый `PreviewFloor` и зону посадки `LaunchPad` (в `server/Runs`). Всё, что зависит от мира,
у каждого игрока своё и не реплицируется: `LobbyScene.client` при входе и при изменении
`Level`/`FarmWorld`/`InRun` (вне заезда) уничтожает старую сцену и строит заново
`Track.new(-1, уровень, 0, previewOrigin, Config.LOBBY_PREVIEW_SEGMENTS)` (папка `TrackPreview`,
только первые N кусков, без стены в конце) и папку `LobbyDecor` (`Lobby.dress(theme)`: деревья,
кактусы, кристаллы, горы, шары, сияние), перекрашивает `LobbyGround`/`PlazaRing`, пишет название
мира на арку и ставит себе атрибут `LobbyTheme` — по нему `PostFX.client` плавно
(`Config.LOBBY_LOOK_TWEEN`) меняет свет, небо, дымку, облака и цветокоррекцию (пресет мира +
`WorldLook.LOBBY`), а `Effects.client` — осадки (снег / пепел у вулкана /
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
| `DevAction` | Function | только владелец (`UserId == CreatorId`): уровень, валюта, апгрейды, сани, сброс заданий, `weeklyTitle` (титул себе 1..3, 0 — снять), `weeklyRefresh` (табло сейчас), `sessionShift` (сессия −5 мин, `Rewards.devShiftSession`), `streakNext`/`streakSkip` (дни стрика −1/−2, `Rewards.devStreakShift`), `resetTutorial` (обучение и `Stats.Runs` = 0), `tune` (сохранить переопределения Config для всех) |

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
`RunCoins`, `RunGems`, `Combo`, `Finished`; лидерборд недели — `Title`, `TitleUntil`, `WeeklyMe` (JSON), у
`ReplicatedStorage` — `WeeklyBoard` (JSON). Только у клиента (ставит сам, не реплицируется):
`LobbyTheme` (тема витрины лобби, `LobbyScene` → `PostFX`/`Effects`), `GfxChoice` (выбор графики в ⚙:
0 авто, 1–3; на сессию), `AutoLowFps` (`Effects`: FPS < `GRAPHICS.FPS_LOW`), `GfxTier` (итоговый уровень
1–3, `PostFX` → `Effects`, `LobbyMenus`).

## Графика
`default.project.json` → `Lighting.Technology = Future` (из скриптов не ставится). Сервер (`Main`)
создаёт Atmosphere, ColorCorrection, Bloom, `Terrain.Clouds`; клиент (`PostFX`) локально создаёт
`PostFX_SunRays`, `PostFX_DOF`, `PostFX_Sky` и твинит все свойства под пресет мира
(`shared/WorldLook.PRESETS`, × `Config.GRAPHICS`). Уровни `WorldLook.QUALITY`: 1 — Soft-свет
(`LightingStyle`), без теней, Bloom, лучей, облаков и DOF, частицы × 0.3; 2 — Realistic, без DOF,
частицы × 0.7; 3 — всё. Авто: `SavedQualityLevel` (0 → телефон 2 / ПК 3; 1–3 → 1; 4–7 → 2; 8–10 → 3),
`AutoLowFps` → 1. Ручной выбор в ⚙ важнее авто. DOF на телефонах движок не рисует.

## Теги CollectionService

`Obstacle`, `Coin`, `Gem`, `Crystal`, `Magnet`, `Boost` (в т.ч. дорожка перед ускорителем
островков), `Mover`, бонусы `Shield`/`X2`/`Fuel`/`Ring`,
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
в `server/Shop` (`BuyUpgrade`, `SledAction`, `TrailAction`) и `server/Runs` (расчёт наград в `endRun` (до первого
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
Доска лидеров «всё время» — `OrderedDataStore` `BestLevel_v1` (пишет `PlayerState.postLevel`). Поля
лидерборда недели (#26): `Title` (id из `Config.WEEKLY.TITLES`, `""` — нет), `TitleUntil` (unix,
сброс недели), `TitleWeek` (неделя, в которую титул проверен), `WeekPlay = { key, worlds["N"],
clean }` (где игрок попал в доски на неделе `key`); `migrate` чинит типы и дополняет `WeekPlay`.

## Лидерборд недели (#26, `server/Weekly`, `client/WeeklyBoard`, `shared/Week`)

| Хранилище | Тип | Ключ / значение |
| --- | --- | --- |
| `LB_W<год>-<нед>_<мир>` | OrderedDataStore | `u_<UserId>` → лучшая дистанция за заезд в мире (UpdateAsync max) |
| `LB_W<год>-<нед>_clean` | OrderedDataStore | `u_<UserId>` → чистые финиши недели (IncrementAsync) |
| `BestLevel_v1` | OrderedDataStore | `u_<UserId>` → уровень (всё время) |
| `WeeklyWinners_v1` | DataStore | `W<год>-<нед>` → `{ ["w<N>"] = { UserId топ-3 }, clean = {…} }` |

Неделя — ISO 8601 по UTC (`Week.key/start/reset/prevKey`, проверено на 53-й неделе и стыке лет).
- `Weekly.onRun` (из `endRun`, синхронно) — результат в очередь в памяти; запись — не чаще
  `WEEKLY.WRITE_EVERY` (30 с) на игрока, на выходе и в `BindToClose` — сразу; ошибка — обратно в
  очередь. Фильтр: `farm`, `cheat`, `run.flags ≥ MAX_FLAGS`, `dist > (сейчас − launchTime) ×
  MAX_AVG_SPEED` → не пишется, custom `CheatSuspect`. `dist ≤ track.length` и прирост пути за тик
  уже ограничивает `AntiCheat.tick`.
- Раз в `REFRESH` (60 с) сервер берёт первые 100 записей досок `all`, `clean` и миров, где сейчас
  есть игроки этого сервера, кладёт топ-10 с никами в `ReplicatedStorage.WeeklyBoard` (JSON) и
  каждому — `Player.WeeklyMe` (JSON: мир, очки и места; место считается по сотне с учётом свежего
  своего счёта, вне сотни — нет). Свои очки недели — `GetAsync` один раз на мир/неделю.
- Титул: при входе / в цикле, если `TitleWeek ≠` текущей и прошло `WINNERS_DELAY` (180 с) после
  сброса — для досок из `WeekPlay` прошлой недели берётся топ-3 из `WeeklyWinners_v1`; если доски
  там нет, первый сервер считает её (`GetSortedAsync(…, 3)`) и пишет `UpdateAsync` без перезаписи
  чужого — все серверы выдают одно и то же. Атрибуты `Title`/`TitleUntil`, custom `TitleAwarded`
  (значение — место). Клиент рисует плашку `BillboardGui` (UIKit) в своём `PlayerGui` над
  головой игроков не в заезде; табло (`Leaderboard`: `Head`, `List`, `Me`) заполняет локально.
- Перед каждым запросом — `GetRequestBudgetForRequestType` с запасом `BUDGET_RESERVE`; нет
  бюджета — пропуск до следующего цикла.

**Бюджет (лимиты на сервер в минуту: GetSorted 5 + 2·N, GetAsync 60 + 10·N, Set/Update/Increment
60 + 10·N; ключ — 1 запись / 6 с):**

| Запросы/мин | 1 игрок | 50 игроков | Лимит 1 / 50 |
| --- | --- | --- | --- |
| GetSortedAsync: 2 + число разных миров игроков (≤ 40 при уровне ≤ 200) | 3 | ≤ 42 (обычно 2 + 7) | 7 / 105 |
| GetAsync: свои очки 2 на вход + 1 на новый мир, победители 1 раз в неделю | ≤ 3 | ≤ 100 (50 входов за минуту) | 70 / 560 |
| Update/Increment досок: ≤ 2 за 30 с на игрока | ≤ 4 | ≤ 200 | 70 / 560 (вместе с автосейвами 25/мин и `BestLevel`) |
| Раз в неделю: топ-3 по доскам из `WeekPlay` | ≤ 1 + миры | ≤ 1 + миры, с бюджет-гардом | — |
