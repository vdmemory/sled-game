# Архитектура

Игра пишется кодом без Roblox Studio: Luau-файлы в репозитории → Rojo собирает place →
GitHub Actions публикует его в Roblox через Open Cloud.

## Деплой

| Что | Где |
| --- | --- |
| Сборка | `rojo build default.project.json -o game.rbxl` (Rojo 7.4.4, `rokit.toml`) |
| Публикация | `scripts/publish.sh` → `POST apis.roblox.com/universes/v1/{universe}/places/{place}/versions?versionType=Published`, ретраи на 409/429/5xx. Нет `game.rbxl` — собирает сам (rojo из PATH / `.tools/bin`, ставит `check.sh` с `curl --retry`) |
| Ассеты при деплое (#22) | `upload_ui_assets.py` → `upload_meshes.py` → `upload_audio.py`: код 3 = загружено не всё → аннотация `warning` + строка в Summary (в игре фолбэк). Новые ID → пересборка; пересборка не удалась → публикация **отменяется** (`ALLOW_STALE_BUILD=1` — публиковать старую). Новые ID не закоммичены (`git status` по `assets/**/*.json`, `src/shared/*Ids.luau`) → JSON в лог и Summary, job **красный после публикации** (иначе следующий деплой загрузит их заново; аудио — 10/мес; `ASSET_IDS_UNCOMMITTED_OK=1` — только warning). HTTP-повторы (`upload_ui_assets.http`): GET — при 0/429/5xx, POST создания ассета — только 429/503 (повтор после таймаута мог бы создать дубликат) |
| Workflow | `.github/workflows/deploy.yml` (правится только через веб GitHub — у сессии нет scope `workflow`) |
| staging | любой push в `main` → тестовый плейс «Игра на санях [ТЕСТ]» |
| production | тег `v*` → боевой плейс |
| Секреты | `ROBLOX_API_KEY` (репозиторий), `UNIVERSE_ID` / `PLACE_ID` (переменные окружений staging/production) |

409 «Server busy» = плейс открыт в Studio. После деплоя старые серверы живут ~30–45 с — перезаходить
после этого.

## Раскладка (default.project.json)

| Папка | Куда в игре | Что там |
| --- | --- | --- |
| `src/shared` | `ReplicatedStorage.Shared` | `Config` (все числа и баланс, `TUNABLES` для настройки на лету), `UIKit` (дизайн-система, 3D-иконки), `WorldLook` (пресеты света и пост-обработки миров, уровни графики), `UIFx` (эффекты интерфейса: полёт валюты, тик чисел, вспышка выбора, сундук; только клиент), `SledModels/` (транспорт: корпуса саней мешами с фолбэком на Part, обвес тиров `extras`, ракеты, рогатка; см. «Карта модулей»), `Track/` (генерация трассы: сервер — трассы заездов, клиент — витрина лобби; см. «Карта модулей»), `SafeLine` (чистая раскладка рядов препятствий с безопасной линией, без Instance — можно гонять в luau CLI), `Islands` (островки над пропастью #40: баллистика прыжков без Instance + постройка островков, ускорителей, пропасти, скал Terrain), `Props/` (low-poly модели ландшафта и препятствий, фасад `Props.*`), `Lobby` (`PLAN` — чертёж, `build` + `furnish` — архитектура лобби на сервере, `dress` — декор по миру и `showcase` — витрина саней на клиенте), `LobbyPodium` (пьедестал топ-3 недели, #48), `UILayout` (раскладка лобби-UI и минимальные размеры; читает и `scripts/ui_layout_preview.py`), `DailyTasks` (набор заданий дня, чистые функции, #32), `Week` (ISO-неделя по UTC для лидерборда, #26), `Meshes` (шаблоны мешей декора, #45), `AudioSet` (активный набор звуков по `Config.SOUND_SET`: `AudioSetV1` — статический v1, `AudioIds` — генерируемый v2), генерируемые деплоем `UIDecals` (имя иконки → ID декали), `MeshIds`/`MeshSpecs`, `AudioIds` |
| `src/server` | `ServerScriptService.Server` | `Main.server` (только порядок запуска и связывание) + `Remotes`, `Environment`, `Sleds`, `PlayerState`, `Runs`, `RunEvents`, `Pickups`, `Shop`, `Purchases`, `DevTools`, `Podium`, `MeshAssets.server` (см. «Карта модулей»), `AntiCheat` (правдоподобие заезда: предел скорости/пути, телепорт, полёт по серверу, проверки `Air`/`Trick`/`Smash`/`PowerUp`), `DataService` (DataStore), `Rewards` (задания, подарки, сундук, стрик), `Weekly` (лидерборд недели — см. ниже), `Tuning` (переопределения Config: DataStore `GameConfig_v1` + MessagingService), `Analytics` (AnalyticsService: онбординг, экономика, события заездов — `docs/METRICS.md`), `UIImages.server` (декали → ID картинок через InsertService → атрибуты `ReplicatedStorage.UIImages`) |
| `src/client` | `StarterPlayerScripts.Client` | `SledController` (посадка и кадр физики санок) + `Sled/` (`State`, `Input`, `Launch`, `Tricks`, `Contacts` — см. «Карта модулей»), `HUD` (лобби/заезд/итог), `LobbyMenus` (окна меню), `DevPanel` (панель владельца), `ConfigSync` (применяет переопределения Config), `Effects` (осадки миров — в заезде по `RunTheme`, в лобби по `LobbyTheme`; частицы, пламя ракеты; детектор FPS → `AutoLowFps`), `PostFX` (свет и пост-обработка миров по пресетам `shared/WorldLook`: Lighting, Atmosphere, Clouds, Sky, ColorCorrection, Bloom, SunRays, DepthOfField — с твином; уровень графики 1–3 → атрибут `GfxTier`; виньетка скорости), `Sounds` (все звуки и музыка: каналы SoundGroup, набор `shared/AudioSet`, лупы, ducking — см. «Звук»), `Traffic` (движение машин), `Reveal` (анимация нового тира «было → стало»), `LobbyScene` (локальная витринная трасса своего мира за мостиком, декор и земля лобби по миру, витрина саней на подиумах с вращением `BulkMoveTo`, камера спавна, флаги на ветру, корона пьедестала топ-3), `WeeklyBoard` (табло лидеров и титулы над головой — только отображение `WeeklyBoard`/`WeeklyMe`/`Title`), `Tutorial` (подсказки первых заездов: свой ScreenGui `DisplayOrder` 90, опрос 5 Гц атрибутов игрока и `SledController.State` — `AwaitingLaunch`, `Airborne`, `Fuel`, `RocketOn`, `Stick.X`; находит в HUD `PlayButton` и `Card_<апгрейд>`) |

## Карта модулей (после разбиения #17/#18, строки — 2026-11-09)

Порог — файл ≤ ~600 строк. Папка с `init.luau` в Rojo — ModuleScript с дочерними модулями:
`require(Shared.Track)` / `require(Shared.Props)` по-прежнему отдают весь API.
Сейчас выше порога (кандидаты на разбиение, `IDEAS` #55): `Config` 1177, `DevPanel` 957,
`LobbyMenus` 937, `HUD` 891, `UIKit` 758, `Sounds` 682, `Runs` 670.

| Модуль | Строк | Что внутри |
| --- | --- | --- |
| `server/Main.server` | 84 | порядок запуска: `Tuning.init` → ремоуты в `ReplicatedStorage` → `Sleds.setup` (группа `Riders`, `workspace.Sleds`) → `Environment.setup` (свет) → `Track.buildLobby` → `Weekly.start` → `Podium.start` → `*.start()` обработчиков → `Runs.startLoop` (Heartbeat) → игроки, автосейв, `BindToClose` |
| `server/Remotes` | 38 | все ремоуты (папка `Remotes`); `Remotes.folder` кладёт в `ReplicatedStorage` Main |
| `server/Environment` | 48 | Lighting, облака, цветокоррекция, bloom |
| `server/Sleds` | 145 | `makeSled` (сиденье, модель/редкость/тиры, след, ракеты, крепления), `ragdoll`, `setRider` |
| `server/PlayerState` | 158 | `sync` (профиль → атрибуты), `onPlayerAdded`, `postLevel` (OrderedDataStore `BestLevel_v1`), `TutorialStep`, `SetSetting` |
| `server/Runs` | 670 | `runs`/`slots`/`ending`, `startRun`, `endRun` (награды, задания, неделя, `RunEnded`, `respawn`), зона посадки `LaunchPad`, `Restart`/`Back`, `rescueCheck` (мягкий возврат), Heartbeat (сторож персонажа, прогресс, античит, финиш, остановка, вылет), таймаут без выстрела `IDLE_LAUNCH_TIMEOUT` → `endRun("idle")` (#20, custom-событие `RunIdle`), `onLeave`/`endAll` (выход/закрытие сервера посреди заезда → `endRun(..., leaving)` до `Data.release`/сохранения, #21, custom `RunLeft` с % трассы; события — `docs/METRICS.md`) |
| `server/RunEvents` | 215 | `Launch`, `Air`, `Crash`, `Smash`, `Trick` |
| `server/Pickups` | 188 | монеты (касание, магнит `CoinGrab`, комбо), `PowerUp` (x2, кольца, канистра, ускорители), гемы, кристалл |
| `server/Podium` | 304 | пьедестал топ-3 недели (#48): аватары `CreateHumanoidModelFromUserIdAsync` (pcall, манекен при ошибке, кэш `PODIUM.CACHE`), поза/анимации на серверном `Animator`, таблички, «?» пустых ступеней; по смене `ReplicatedStorage.WeeklyBoard` |
| `server/Shop` | 186 | `SledAction`, `TrailAction`, `RewardAction`, `BuyUpgrade`, `WorldAction` |
| `server/Purchases` | 71 | геймпасс x2, `PRODUCT_HANDLERS`, `ProcessReceipt` (дедуп чеков) |
| `server/DevTools` | 110 | `DevAction` (только `game.CreatorId`) |
| `client/SledController` | 415 | посадка/высадка, кадр физики (скорость вдоль склона, руль, подсадка, прыжок, приземление) |
| `client/Sled/State` | 133 | общее состояние санок (`st.speed`, `st.sled`, `st.trick`…) и объекты под контроллером (`State`, `Sfx`, `RequestLaunch`, `RocketInput`, `TrickPopup`) |
| `client/Sled/Input` | 109 | руль: клавиатура, PlayerModule, свайп с кольцом (`Stick`) |
| `client/Sled/Launch` | 117 | рогатка: натяжение, выстрел `Launch(power)` |
| `client/Sled/Tricks` | 345 | ручные и авто-трюки, `Tricks.land` (итог полёта), `Tricks.air` (кадр в воздухе), кнопки прыжка/ракеты |
| `client/Sled/Contacts` | 386 | касания (авария, разбивание, щит, бонусы, гемы, кристалл, ускорители), `Contacts.scan` (монеты по отрезку пути, магнит) |
| `shared/Track/init` | 574 | класс трассы: `new`, `buildStart`, `buildSegment`, `buildRoad`, `setMover`, `ensureAround`, `progressOf`, `rescueCFrame`, `destroy` |
| `shared/DailyTasks` | 140 | задания дня игрока (#32): `baseSet(day)` (общий набор дня), `forPlayer(day, d)`, `revalidate(set, day, d, keep)` — замена невыполнимого (`Config.taskAvailable`), `describe`. Чистые функции; проверка — `scripts/stand/daily_tasks.luau` |
| `shared/Track/Profile` | 244 | `buildProfile` — цепочка кусков уровня (тип `Segment`) |
| `shared/Track/Sections` | 189 | профили сечений, цвета снега, `sidePoint`, поперечное сечение куска |
| `shared/Track/Dress` | 324 | оформление миров вдоль трассы и разметка на ней |
| `shared/Track/Items` | 189 | монеты, гемы, магнит, бонусы, кристалл, `tagObstacle` |
| `shared/Track/Valley` | 150 | гребень над долиной: `build` — обрыв, дно, островки по миру; `prune` — убрать декор обочины над обрывом; участки помечает `Profile` (`seg.valley`) |
| `shared/Track/Tunnel` | 140 | тоннель над поворотом (#65): `build` — кольцо свода (меш `tunnel_vault` или блоки), порталы, свет, вид по миру; куски помечает `Profile` (`seg.tunnel`) |
| `shared/Props/init` | 16 | фасад: подключает модули категорий, отдаёт таблицу `Props` |
| `shared/Props/Base` | 103 | `part`, `deco`, `pick`, надписи, колёса, общие цвета |
| `shared/Props/Vehicles` | 219 | машины, трафик, поезд, канатка, знаки |
| `shared/Props/Obstacles` | 357 | препятствия и `Props.obstacle(theme, …)` |
| `shared/Props/Decor` | 309 | деревья, постройки, горы, трамплин, шар |
| `shared/Props/Worlds` | 257 | модели миров 4–7 |
| `shared/Props/LobbyDecor` | 320 | костёр, флагшток, гирлянда; меши лобби: `lampPost`, `podium`, `boardFrame`, `startGate` (фолбэк — Part); станции кольца (#69): `worldPortal`, `shopStall` (деталь `Zone` с атрибутом `Menu`), `tent`, `hangLamp`, `snowCap` |
| `shared/UILayout` | 84 | места и размеры лобби-UI (`{ ax, ay, sx, ox, sy, oy, w, h }`), `DESIGN_W/H`, `MIN_TOUCH`/`MIN_PILL`/`MIN_TEXT` (+ для окон) |
| `shared/Meshes` | 107 | меши декора (#45): `has(...)` (все шаблоны есть и `MESH_DECOR` = 1), `waitFor(имена, таймаут)` (ждать шаблоны с ID в `MeshIds`), `place(имя, основание, масштаб, свойства, родитель)`, `vary` (разброс оттенка по позиции) |
| `shared/SledModels/init` | 73 | фасад транспорта (прежний API): `build` (корпус: меши `BodyMeshes`, если все шаблоны модели есть, иначе Part `Bodies`), `extras`, `rocket`, `slingshot`, `ROCKETS`, `MOUNTS`, `ROPE_*`, `MESHES` (все меши транспорта — витрина ждёт их) |
| `shared/SledModels/Builder` | 161 | сборка: `part`/`block`/`cyl`/`rod`/`torus`…, `mesh(имя, цвет, материал, кадр, масштаб)` — MeshPart из `MeshTemplates` с теми же свойствами (без коллизий, `Massless`, приварка), `meshesReady(имена)` (+ `Config.MESH_SLEDS`, `MESH_SLED_FLIP`) |
| `shared/SledModels/Bodies` | 332 | корпуса 9 моделей из Part (фолбэк) |
| `shared/SledModels/BodyMeshes` | 164 | корпуса из мешей: `MODELS[id]` = { меш, роль } (роль → цвет/материал: `main`, `accent`, `wood`, `steel`, `rubber`, `glass`…), детали-Part поверх (кок и круги самолёта, номер бобслея, фара снегохода) |
| `shared/SledModels/Mounts` | 41 | точки крепления: `MOUNTS` (ракеты, фары, габариты `tail`, неон), `SPOILER`, `SHIELD`, `BUMPER` |
| `shared/SledModels/Kit` | 232 | `extras`: ракеты + обвес тиров 1–10 (меши `kit_*`, `trim_<модель>` или Part), свет фар (SpotLight + Beam), чек-лист «что видно с камеры» |
| `shared/SledModels/Rockets` | 162 | `ROCKETS[0..6]`, `build` (меши `rocket_*` или Part), срез сопла для `Effects` |
| `shared/SledModels/Slingshot` | 214 | столбы рогатки по тирам 0–10, `ROPE_COLORS`, `ROPE_GLOW` |
| `shared/MeshSpecs`, `shared/MeshIds` | — | генерируются: габариты мешей (`scripts/gen_meshes.py`), имя → ID ассета Model (деплой) |
| `shared/AudioIds` | — | генерируется (`scripts/gen_audio.py`/`upload_audio.py`): ID аудио-атласа v2 (0 — ещё не загружен) и куски `{начало, длина, луп}` |
| `shared/AudioSetV1` | 51 | статический набор v1 (синтез, атлас 85020498524123) в том же формате `{ atlas, regions }`; не перегенерируется |
| `shared/AudioSet` | 15 | выбор набора по `Config.SOUND_SET` (0 — встроенные `rbxasset` с регионами v1, 1 — v1, 2 — v2 из `AudioIds`); читается при старте клиента (`Sounds`, `DevPanel`) — смена набора требует перезахода |
| `server/MeshAssets.server` | 44 | `InsertService:LoadAsset(MeshIds)` → шаблоны MeshPart в `ReplicatedStorage.MeshTemplates` |

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
   по ледяному озеру), вылет, остановку. Сторож: персонаж заезда удалён/пересоздан или не сидит
   в санках дольше `RUN_UNSEATED_MAX` → `endRun("left")`. Страховка `rescueCheck`: ниже дна куска
   на `RESCUE_DEPTH`, за барьером или дольше `RESCUE_OUT_TIME` снаружи борта → `Rescue` клиенту
   с точкой `Track:rescueCFrame(pos)` (nil над пропастью/островками/озером → там `fell`).
6. `endRun` начисляет монеты/гемы, прогресс заданий, шлёт `RunEnded`, через паузу убирает санки и
   трассу и пересоздаёт персонажа в лобби (`respawn`: `LoadCharacterAsync` в pcall, до 3 попыток).
   `ending[player]` снимается только после пересоздания — иначе `StartRun`/зона посадки во время
   загрузки сажали в новые санки старого персонажа (#50: «на старте без персонажа, только сани»).
   Пока игрок в `ending`, проверка «упал с лобби» его не переносит (PivotTo унёс бы и сани).

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
  прошлого Trick; полёта не было — флаг. **`Smash(model)`** — `Breakable` (TNT ещё и `Explosive` — `Contacts.explode`, сервер начисляет `TNT_COINS`) своей трассы, ближе
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

Чертёж — `Lobby.PLAN` (координаты от `Config.LOBBY_POS`, схема сверху — в комментарии над ним).
Станции стоят по эллипсу `PLAN.hub` (#69); `Lobby.STATIONS` — занятые зоны, `Lobby.free(x, z, r)` /
`Lobby.pushOut` не дают декору мира (`Lobby.dress`) встать внутрь кольца или на станцию. Портал
«Миры» и лавка «Сани» — модели `WorldPortal`/`SledStall` с деталью `Zone` (атрибут `Menu` =
`worlds`/`sleds`); `client/LobbyMenus` раз в `LOBBY_ZONE_POLL` с проверяет вход персонажа в зону и
открывает окно (только на входе, окна закрыты, не в заезде).
Сервер строит в два шага. `Lobby.build` (через `Track.buildLobby`, сразу): земля, плита-хаб,
дорожка с шевронами, мостик, маяк старта, спавн, Terrain (скальный массив под площадкой и гряда
задника — `Rock`, только z ≥ −38). `Lobby.furnish` (в `task.spawn`, после
`Meshes.waitFor(Lobby.MESHES, 15 с)` — шаблоны мешей грузятся асинхронно): ворота старта с вывеской
(`ArchBeam.Sign`), фонари, подиумы `PodiumL`/`PodiumR` (атрибут `Top` — кадр верха, `BillboardGui`
подписи), табло `Leaderboard`/`NextUpdate`, костёр, флаги (тег `LobbyFlag`, атрибут `BaseCF`),
гирлянды; ставит атрибут `Furnished` у модели `Lobby`. Под стартовой площадкой витрины —
невидимый `PreviewFloor` и зона посадки `LaunchPad` (в `server/Runs`). Всё, что зависит от мира,
у каждого игрока своё и не реплицируется: `LobbyScene.client` при входе и при изменении
`Level`/`FarmWorld`/`InRun` (вне заезда) уничтожает старую сцену и строит заново
`Track.new(-1, уровень, 0, previewOrigin, Config.LOBBY_PREVIEW_SEGMENTS)` (папка `TrackPreview`,
только первые N кусков, без стены в конце) и папку `LobbyDecor` (`Lobby.dress(theme)`: деревья,
кактусы, кристаллы, горы, шары, сияние), перекрашивает `LobbyGround`/`PlazaRing`, пишет название
мира на ворота, ставит витрину саней (`Lobby.showcase` на подиумы: слева — следующие сани для
покупки, справа — «мечта»; вращение — один `workspace:BulkMoveTo` на все детали, 30 Гц), по
`Furnished` и по загрузке мешей (`Meshes.waitFor`) пересобирается один раз, наводит камеру спавна
(`LOBBY_CAM_PITCH`/`LOBBY_CAM_ZOOM`; зум — временным `CameraMinZoomDistance`) и ставит себе атрибут
`LobbyTheme` — по нему `PostFX.client` плавно
(`Config.LOBBY_LOOK_TWEEN`) меняет свет, небо, дымку, облака и цветокоррекцию (пресет мира +
`WorldLook.LOBBY`), а `Effects.client` — осадки (снег / пепел у вулкана /
сухо в каньоне и на конфетной горе). Локальная витрина монет не даёт: `SledController` собирает
монеты только рядом со своими санями в заезде (за 2000 studs от лобби).

## Ремоуты (`ReplicatedStorage.Remotes`)

RemoteFunction клиент вызывает **только** через `UI.invoke(remote, ...)` (`shared/UIKit`, #19): `pcall` +
таймаут `Config.INVOKE_TIMEOUT` (12 с); ошибка сервера → `false, "Ошибка сервера, попробуй ещё раз"`,
нет ответа → `false, "Сервер не отвечает…"` (+ `warn`), поздний ответ отбрасывается. Обработчики
отвечают `(ok, сообщение | данные)` — клиент показывает сообщение тостом, флаги кнопок сбрасываются.
`RunEnded` с `reason = "idle"` (#20) — без карточки итогов, только сообщение.

| Имя | Тип | Направление / смысл |
| --- | --- | --- |
| `StartRun` | Event | клиент → начать заезд |
| `Launch` | Event | клиент → выстрел рогатки (сила 0..1) |
| `Crash` | Event | клиент → врезался (сервер делает ragdoll) |
| `Air`, `Trick`, `Smash`, `Crystal`, `CoinGrab` | Event | клиент → время в воздухе, трюки за полёт (`Trick(list { id, count }, airTime)` — сервер проверяет id, count ≤ 5, оборотов ≤ влезающих в серверный полёт), разбил препятствие (`Smash(model)` — модель `Breakable`), кристалл, монета магнитом; проверки — `AntiCheat` |
| `Restart`, `Back` | Event | клиент → заново / в лобби с рогатки |
| `RunEnded` | Event | сервер → итог заезда |
| `TaskDone` | Event | сервер → задание выполнено |
| `Rescue` | Event | сервер → мягкий возврат: `(CFrame на дне куска, доля скорости)`; клиент переставляет свои санки, сбрасывает полёт и трюки (#50) |
| `SetSetting` | Event | клиент → настройка (Sfx/Music/Snow/Shadows) |
| `PowerUp` | Event | клиент → подобрал бонус (x2, кольцо, магнит, щит, канистра, ускоритель) |
| `BuyUpgrade`, `SledAction`, `TrailAction` | Function | покупки/экипировка |
| `RewardAction` | Function | задания, сундук заданий, подарки, сундук лобби, `streak` (награда дня стрика, раз в UTC-день), `streakSave` (спасти серию за гемы, только в день после пропуска 1 дня и до награды), `streakDecline` |
| `WorldAction` | Function | фарм пройденного мира / возврат / пропуск мира за Robux (владелец — тест любого мира) |
| `TutorialStep` | Event | клиент → шаг обучения `i` показан/пройден (0 — пропустить всё); сервер проверяет целое 0…#`TUTORIAL.STEPS`, ставит бит в `Tutorial` один раз (повтор игнорируется), без наград |
| `DevAction` | Function | только владелец (`UserId == CreatorId`): уровень, валюта, апгрейды, сани, сброс заданий, `weeklyTitle` (титул себе 1..3, 0 — снять), `weeklyRefresh` (табло сейчас), `sessionShift` (сессия −5 мин, `Rewards.devShiftSession`), `streakNext`/`streakSkip` (дни стрика −1/−2, `Rewards.devStreakShift`), `resetTutorial` (обучение и `Stats.Runs` = 0), `tune` (сохранить переопределения Config для всех) |

### Раскладка лобби-UI и макет-рендер

Все места и размеры лобби-UI — `shared/UILayout` (`UI.L`, `UI.at(spec, props)`). Масштаб корня
HUD, Tutorial и слоя сообщений — `UI.fitScale(frame, gui)`: от `AbsoluteSize` ScreenGui (уже без
топбара Roblox и выреза телефона), `clamp(min(H/580, W/1000), 0.55, 1)` — логическая высота корня
≥ 565 на любом экране. Сообщения (`Toast`) — отдельный ScreenGui `Toasts` (`DisplayOrder` 20, выше
окон HUD). `scripts/ui_layout_preview.py` читает `UILayout`, `Lobby.PLAN`, `LOBBY_CAM_*`, строит схему
на 6 экранах с проекцией 3D-лобби камерой спавна и проверяет пересечения, размеры (кнопка ≥ 44 px,
пилюля ≥ 32 px, текст ≥ 14 px) и что мостик/кольцо/маяк не закрыты UI и аватаром > 50% (код выхода 1
при замечаниях) → `assets/store/lobby_layout.png`. В игре то же проверяет кнопка DEV → «Инструменты»
→ «Проверить UI (телефон)» (обход видимого UI и всех окон в логических единицах).

## События между клиентскими скриптами (BindableEvent в `HUD`)

| Имя | Кто слушает | Смысл |
| --- | --- | --- |
| `UpgradeReveal(kind, tierName)` | `Reveal` | HUD получил от `BuyUpgrade` имя нового тира → большая анимация «было → стало» |
| `Toast(text, seconds?)` | `HUD` | сообщение в слое `Toasts` (в лобби — `UILayout.toastLobby`, в заезде — `toastRun`); шлёт `LobbyMenus.say` и сам `HUD.notice` |
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

## Меши декора (#45)

Open Cloud publish не принимает Union/EditableMesh, а MeshId у MeshPart из скрипта не ставится —
поэтому меши загружаются отдельными ассетами и клонируются из шаблонов.

| Шаг | Где | Что |
| --- | --- | --- |
| 1. Форма | `scripts/gen_meshes.py` (numpy + trimesh, локально) | 14 мешей → `assets/meshes/*.glb` (Y вверх, начало — центр основания; нормали плоские у камня/льда/хвои, гладкие у снега; UV коробочной проекцией — для текстур материалов; белый материал без картинки — цвет даёт `MeshPart.Color`), `specs.json`, `src/shared/MeshSpecs.luau` (size, offset). Детерминирован |
| 2. Превью | `scripts/preview_meshes.py` | `assets/meshes/preview.png` — смотреть глазами после каждой правки формы |
| 3. Загрузка | `scripts/upload_meshes.py` из `publish.sh` | `POST assets/v1/assets`, `assetType: "Model"`, `.glb` (`model/gltf-binary`) → операция → `assetId`; новые и изменённые (sha) → `assets/meshes/meshes.json` (`{ имя: { id, sha } }`) и `MeshIds.luau`, пересборка места, в лог `MESH_IDS_JSON_BEGIN/END` (закоммитить оба файла), статус модерации. 401/403 — warning с инструкцией по правам ключа, деплой идёт дальше. `SKIP_MESHES=1` — пропустить |
| 4. Шаблоны | `server/MeshAssets.server` | `LoadAsset(id)` (3 попытки) → первый `MeshPart` → `ReplicatedStorage.MeshTemplates/<имя>` (без коллизий/лучей/касаний); ошибка — `warn` + атрибут `_err` у папки |
| 5. Постройка | `shared/Meshes.place` из `Props` и `Track/Dress` | `Clone` шаблона, `Size = size·масштаб`, `CFrame = основание·offset·масштаб` — части одного объекта (хвоя + снег) совпадают при любом масштабе |

**Меши транспорта** (тот же пайплайн): `scripts/gen_sled_meshes.py` (корпуса 9 моделей, 43 меша) и
`scripts/gen_kit_meshes.py` (обвес `kit_*` 10, кромки тира 4 `trim_<модель>` 9, ракеты `rocket_*` 8)
на общей геометрии `scripts/sled_geom.py` (лофт сечений, протяжка профиля по кривой, тела вращения,
профиль NACA); подключены в `gen_meshes.py` (`all_meshes()`) — `.glb` в `assets/meshes`, габариты в
`MeshSpecs`. Кадр — кадр саней (X вправо, Y вверх, нос по −Z, 0 — центр сиденья) или точки крепления
детали; нормали гладкие с жёсткими рёбрами > 38° (`smooth_shade`). Модель разбита на меши по цветам
(MeshPart.Color красит целиком; VertexColor импорт glTF поддерживает, но он умножается на Color и
не даёт перекрашивать по редкости). `SledModels` клонирует шаблоны через `Builder:mesh` (приварка к
сиденью, `Massless`, без коллизий); модель/обвес/ракета включаются мешами целиком (`meshesReady`),
иначе — Part. Превью — `scripts/preview_sleds.py`: собирает сани настоящим кодом `SledModels` в
стенде luau (`scripts/stand`, `sled_dump.luau`), ставит `.glb` и Part-примитивы, рисует z-буфером
(`sleds_preview.png`, `tiers_camera_preview.png`, `rockets_preview.png` в `assets/meshes`).
Стенд сверки `python3 scripts/stand/run.py [--meshes] [--src …]` — отпечаток всех инстансов
моделей × тиров × ракет, рогатки; таблица инстансов на сани в заезде.

Фолбэк декора: `Meshes.has` → false, пока нет хоть одного шаблона объекта (или `MESH_DECOR` = 0), — `Props`
строит прежнюю модель из Part. Сервер (трасса) и клиент (витрина, декор лобби) решают сами по
`MeshTemplates`; куски, построенные до загрузки шаблонов, остаются из Part. Все `Random`-вызовы
моделей делаются до выбора пути, слои кадра берут свой `Random` от позиции куска — раскладка
препятствий, монет и бонусов от мешей не зависит (стенд luau: отпечаток всего, кроме чистого декора,
совпадает 1:1 с мешами и без на 70 уровнях; ни один меш не заходит в коридор трассы, кроме арки
над ней). Меши — только декор; ходовая часть и препятствия — Part (точная коллизия).

## Звук (#49, v2 #52, `client/Sounds`)

| Шаг | Где | Что |
| --- | --- | --- |
| 1. Сборка | `scripts/gen_audio.py` (numpy/scipy + ffmpeg/libvorbis, локально) | 43 звука из записей `assets/audio/sources/` (обрезка, фильтры, скорость, микс, грануляция лупов) + немного синтеза → один атлас `assets/audio/sfx_atlas_v2.ogg` (mono 44.1 кГц, паузы 0.12 с), `atlas.json` (имя → start/len/loop/src/пик/RMS), `src/shared/AudioIds.luau` (`regions[имя] = { start, len, loop, src }`); `--preview` → `assets/audio/preview.png`. Детерминирован (seed, bitexact Ogg). Выравнивание: one-shot RMS −16 dBFS, лупы −22; проверки: пик one-shot после Vorbis ≤ −1 dBFS, длина UI-звуков |
| 2. Загрузка | `scripts/upload_audio.py` из `publish.sh` (пути — `scripts/audio_ids.py`, без numpy) | `POST assets/v1/assets`, `assetType: "Audio"`, `audio/ogg` → операция → `assetId` → `assets/audio/audio.json` (`{ sfx_atlas_v2: { id, sha } }`; `sfx_atlas` — v1, история) и `AudioIds.atlas`, пересборка места, лог `AUDIO_IDS_JSON_BEGIN/END` (закоммитить оба). `SKIP_AUDIO=1` — пропустить. Ошибка — warning с инструкцией владельцу |
| 3. Игра | `client/Sounds` | `Config.SOUND.library[имя]` (ID Creator Store) — весь ассет; иначе `AudioSet.atlas > 0` (набор по `Config.SOUND_SET`, по умолчанию v1) → проба `PreloadAsync` (15 с) → звуки на атлас: `PlaybackRegionsEnabled` + `PlaybackRegion` (кусок), лупы ещё `LoopRegion`; иначе `FALLBACK` (встроенные `rbxasset://sounds/*`). Атрибут `SoundService.SoundSource` = `atlas`/`builtin` |

Почему атлас: Open Cloud даёт 10 аудио/мес без ID-верификации (100 с ней), аудио нельзя обновлять —
отдельные файлы съели бы лимит за одну правку.

Устройство `client/Sounds`: `SoundGroup` Music/SFX/UI/Ambience в `SoundService` (громкость каждый кадр =
`Config.SOUND.groups` × выключатель `SetSfx`/`SetMusic` × ducking для Music); пул `Sound` на событие
(копий — `Config.SOUND.sfx[имя][3]`, по кругу); `play(имя, высота, громкость)` с разбросом тона.
Входы: `controller.Sfx:Fire(имя, [число])` (BindableEvent из `Sled/State`; старые `hit`/`reward` —
синонимы `crash`/`ready`); хук `UIKit.sfx` (ставит Sounds; зовут `UI.pop` → `open`, `UIFx.shakeNo` →
`deny`, `openChest` → `chest`, `flyCurrency` → `claim`); `Activated` любой `GuiButton` в PlayerGui →
`click` (не в заезде); `RunEnded.reason == "fell"` → `fall`. Опросы: `Sled/State` (`sled`, `airborne`,
`lateral`, `trick.angle`, `crashed`, `pulling`) и `SledController.State` (`Speed`, `RocketOn`, `Meter`,
`AwaitingLaunch`) — лупы ветра/поверхности (луч вниз раз в 0.12 с, `RaycastResult.Material`), ракеты,
натяжения; вуш вращения трюка; поджиг/выключение ракеты. Машины/поезда (`Mover`, модели `Vehicle`/
`Train`): раз в 0.4 с 3 ближайших в радиусе получают 3D-луп мотора (`Sound` в их Part,
`InverseTapered`), гудок — 3D из машины. Музыка: треки `MUSIC_IDS` грузятся по очереди, лобби —
первый, заезд — `2 + (RunTheme−1) % (n−1)`, кроссфейд `MUSIC_FADE` (Pause/Resume).
Громкость звука берётся из `Config.SOUND.sfx[имя][1]` при каждом проигрывании (лупы — каждый кадр), поэтому
правки TUNABLES «Звук: события» и −/+ в DEV слышны сразу. Проверка владельцем: `Sounds` создаёт (только для
`CreatorId`) BindableEvent `SoundTest` под собой — `("sfx", имя)` → тот же `onEvent`; `("loop", имя, вкл, f)` →
`devLoop` в кадре микса (луп как на скорости `f`·`loopFullSpeed`, даже в лобби; `car`/`train` — 2D-копия);
`("music", nil|0|N)` → `devMusic` в `musicTarget`. Вкладка DEV → «Звуки» (`DevPanel`) зовёт только его.

## Иконки интерфейса

`assets/ui/*.png` (Fluent Emoji 3D, MIT) → `scripts/upload_ui_assets.py` в деплое загружает новые
как Decal через Assets API → ID в `assets/ui/decals.json` и `src/shared/UIDecals.luau`
(коммитятся из лога между `UI_DECALS_JSON_BEGIN/END`). В игре `UIImages.server` достаёт ID
картинки из декали, клиент `UI.icon` показывает её после `PreloadAsync`, до того — эмодзи.

## Сохранение (DataStore `SledData_v1`, ключ `u_<UserId>`)

`Coins`, `Gems`, `Level`, `LevelBest`, `LaunchLevel`, `SledLevel`, `IncomeLevel`, `RocketLevel`,
`Sled`/`SledRarity`/`OwnedSleds`, `Trail`/`OwnedTrails`, `Settings` (`Sfx`, `Snow`, `Shadows`,
`Music`), `Daily` (задания дня: `day`, `set` — набор игрока `{ {id, target} }`, фиксируется в начале дня и перепроверяется при входе (#32; у сейвов без `set` — общий набор дня + замена невыполнимого), `progress` по id, `claimed` по номеру слота, `chest`; `Daily.big` — большой подарок получен сегодня), `ChestAt`, `GiftsClaimed` (подарки за время, сбрасываются при входе), `Streak` (`day` — последний засчитанный UTC-день, `count` — серия, `claimedDay` — день последней награды, `save` — серия, которую можно спасти сегодня; пересчёт в `Rewards.ensure`, недостающие ключи у старых сейвов дополняет `migrate`), `FarmWorld`, `Receipts` (дедуп покупок), `Stats` (Runs, Finishes,
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
- **Пьедестал топ-3 (#48):** `shared/LobbyPodium.build` (из `Lobby.furnish`) ставит модель
  `workspace.Lobby.Top3`: ступени, «?» (`EmptyAnchor<N>/Empty<N>`), корона (`Crown`, атрибут
  `BaseCF` — вращает `client/LobbyScene`), атрибуты `Slot1..3` (CFrame верха ступени лицом к спавну)
  и `Scale`. `server/Podium` слушает `WeeklyBoard`, берёт доску `Config.PODIUM.BOARD` (`clean`):
  тот же игрок на месте — меняется только табличка, новый — `CreateHumanoidModelFromUserIdAsync` (без
  скриптов, без коллизий, корень заякорен, `ScaleTo`), ноги ставятся на ступень по `GetBoundingBox`.
  Запросов к DataStore не добавляет; веб-запрос аватара — только при смене игрока в топ-3.
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
