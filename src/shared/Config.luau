-- Все настройки игры в одном месте. Меняй числа здесь — код трогать не нужно.
-- Баланс подобран симуляцией: уровень 1 без апгрейдов ≈ 35–40%, с ~6–8 покупками каждого ≈ финиш.
-- Экономика апгрейдов (#31): модель scratchpad econ_sim.py + phys.py, таблица в docs/GAME_DESIGN.md → «Экономика».

local Config = {}

------------------------------------------------------------------ МИР
Config.LOBBY_POS = Vector3.new(-2000, 3000, 400) -- лобби (в стороне от трасс игроков: за мостиком видна своя «витринная» трасса)
Config.TRACKS_ORIGIN = Vector3.new(0, 3000, 0) -- старт трассы игрока в слоте 0
Config.SLOT_SPACING = 1000 -- расстояние между трассами разных игроков (по X); трассы петляют

------------------------------------------------------------------ ТРАССА (жёлоб)
Config.TRACK_WIDTH = 80 -- ширина снежного дна (широкий склон / улица, как в оригинале)
Config.LANES = 6 -- полосы для препятствий; в ряду всегда свободно минимум 2
Config.BUILD_AHEAD = 650 -- строим трассу на столько studs вперёд от игрока
Config.KEEP_BEHIND = 150 -- и держим столько позади

-- СОХРАНЕНИЯ (DataService; не баланс — не в TUNABLES)
Config.DATA_AUTOSAVE = 120 -- секунд между автосейвами
Config.DATA_LOCK_WAIT = 30 -- сколько ждать, пока другой сервер снимет блокировку сейва
Config.DATA_LOCK_STALE = 2 * Config.DATA_AUTOSAVE + 30 -- блокировка старше этого (сервер упал) — забираем сразу

-- Невидимые борта по краям дна (чтобы санки не вылетали боком с поворотов и после обрывов).
-- Один борт на кусок с каждой стороны: CanCollide, прозрачный, CanQuery=false (луч санок вниз его
-- не видит). Наклон наружу — санки скатываются обратно, а не прилипают. В жёлобе поворота борта
-- не ставятся: там стенками служат сами ледяные пояса (74°) и общий Barrier.
Config.WALL_HEIGHT = 12 -- высота борта, studs
Config.WALL_TILT = 15 -- наклон наружу, градусы
Config.WALL_OFFSET = 1.5 -- насколько борт стоит дальше края дна, studs

-- Лобби: витринная трасса своего мира строится у каждого игрока локально (client/LobbyScene)
Config.LOBBY_PREVIEW_SEGMENTS = 4 -- сколько первых кусков трассы показывать за мостиком (декорация)
Config.LOBBY_LOOK_TWEEN = 1 -- сек: плавная смена освещения лобби при смене мира

-- ГРАФИКА (client/PostFX; пресеты миров — shared/WorldLook). Множители поверх пресетов.
Config.GRAPHICS = {
	BLOOM = 1, -- × интенсивности Bloom всех миров (0 — выкл)
	DOF = 1, -- × силы размытия дали в заезде (0 — выкл)
	SATURATION = 1, -- × насыщенности ColorCorrection
	SUNRAYS = 1, -- × силы солнечных лучей
	CONTRAST_MIN = 0.12, -- контраст кадра не ниже (читаемость препятствий)
	RUN_TWEEN = 1.5, -- сек: переход света при старте/конце заезда
	VIGNETTE_MAX = 0.45, -- непрозрачность виньетки скорости на краях (0 — выкл)
	VIGNETTE_FROM = 80, -- скорость, с которой виньетка появляется
	VIGNETTE_FULL = 170, -- скорость полной виньетки
	FPS_LOW = 40, -- авто-качество: FPS ниже — «Низкое» (два окна по 3 с подряд)
}

-- Повороты: ледяной жёлоб, который петляет (как в трейлере оригинала)
Config.CURVE_CHANCE = 0.3 -- шанс поворота вместо прямого участка
Config.CURVE_ANGLE = { 30, 55 } -- градусов на один поворот
Config.CURVE_STEP = 5 -- градусов на один кусок поворота
Config.CURVE_PIECE = 14 -- длина куска поворота (studs)
Config.CURVE_PITCH = { 8, 11 } -- уклон в поворотах (до 11°: ступенька на краю дна на стыках пола ≤ 0.2, #40)
Config.MAX_HEADING = 50 -- трасса не уходит дальше ±этого от общего направления
Config.MAX_DRIFT = 140 -- и не уплывает вбок дальше этого (studs)

-- Время в воздухе
Config.AIR_COINS_PER_SEC = 12
Config.AIR_MIN_TIME = 0.6

-- Длина уровня по горизонтали (studs)
function Config.levelLength(level: number): number
	return 1200 + (level - 1) * 450
end

-- Доля крутых участков (они разгоняют), уменьшается с уровнем
function Config.steepChance(level: number): number
	return math.max(0.14, 0.28 - 0.02 * (level - 1))
end
Config.KICKER_CHANCE = 0.12 -- обрыв с трамплином
Config.KICKER_DROP = 22 -- высота обрыва
Config.GENTLE_ANGLE = { 2.5, 5 } -- пологие участки: тут трение побеждает гравитацию
Config.STEEP_ANGLE = { 12, 16 }

-- Препятствия, ускорители, монеты
Config.OBSTACLE_ROWS = 2 -- рядов препятствий на прямой участок
Config.SAFE_START = 220 -- первые N studs после старта без препятствий
Config.BOOST_CHANCE = 0.1 -- ускоритель в ряду (≈ 1 на 3 сегмента)
Config.FORCED_KICKERS = { 0.35, 0.7 } -- обязательные обрывы на этих долях уровня
Config.COIN_LINE_CHANCE = 0.5
-- Безопасная линия (#29, shared/SafeLine): в каждом ряду одна полоса гарантированно свободна, и между
-- соседними рядами она смещается только настолько, насколько успевает игрок на maxSpeed уровня
Config.SAFE_LINE_REACTION = 0.3 -- реакция игрока, с
Config.SAFE_LINE_MARGIN = 1.2 -- запас ×: время манёвра берётся с запасом (габарит препятствия, неточность)
Config.SAFE_LINE_MAX_SHIFT = 2 -- больше этого полос между рядами линия не смещается

-- Дороги поперёк трассы с движущимися машинами (как в оригинале)
Config.ROAD_AT = { 0.12, 0.42, 0.72 } -- доли уровня, где могут быть дороги
function Config.roadCount(level: number): number
	return math.min(#Config.ROAD_AT, 1 + (level - 1) // 2)
end
function Config.carsPerLane(level: number): number
	return math.min(4, 2 + (level - 1) // 3)
end
Config.ROAD_LOOP = 360 -- длина «кольца» полосы (studs): машина уезжает за край и возвращается
Config.CAR_SPEED = { 38, 55 } -- studs/с
Config.TRAIN_SPEED = 80
Config.TRAIN_LOOP = 1400
Config.GONDOLA_CHANCE = 0.6 -- канатка над приземлением после обрыва
Config.SMASH_COINS = 5 -- за разбитое препятствие (ракетой или на ускорителе)
Config.FINISH_GLIDE_MAX = 8 -- сек: после финиша катимся по ледяному озеру до остановки
Config.COINS_PER_LINE = 5

-- Гладкость трассы (#40): ходовая часть без ступенек и изломов (docs/GAME_DESIGN.md → «Гладкость»).
-- Стык кусков с разным уклоном получает переходные куски («скругление»): излом на стыке ≤ SMOOTH_KINK.
-- Пол поворота дробится на CURVE_SUBSTEPS кусков (поворот дна на CURVE_STEP / n за стык): ступенька
-- на краю дна x·sin(шаг)·tg(уклон) ≤ 0.2 stud. Остаточные ступеньки (борта жёлоба) сани проходят
-- «подсадкой» (SledController): ступенька до STEP_UP_MAX впереди — сани поднимаются без удара.
Config.SMOOTH_KINK = 2 -- градусов: больше — между кусками вставляются переходные
Config.FILLET_LEN = 4 -- studs: длина одного переходного куска
Config.CURVE_SUBSTEPS = 8 -- кусков пола на один кусок поворота
Config.STEP_UP_MAX = 1.2 -- studs: ступенька впереди не выше этого — подсадка без потери скорости
Config.STEP_PROBE = 3.2 -- studs: где впереди центра саней ищем ступеньку (+ путь за кадр)

-- Островки над пропастью (#40, shared/Islands): трамплин-ускоритель с края → цепочка 3–6 островков
-- → приземление на склон. Ускоритель задаёт скорость вылета в окне [isleSpeed, × ISLE_SPEED_SPREAD]:
-- зазоры и длины островков посчитаны баллистикой так, что при нижней скорости долетаешь с запасом
-- ISLE_LAND_MARGIN, а при верхней (и с ракетой весь полёт) не перелетаешь островок.
Config.ISLE_FROM_LEVEL = 2 -- первый уровень с островками (1-й — обучение)
Config.ISLE_AT = 0.52 -- обязательная цепочка на этой доле уровня (с ISLE_FROM_LEVEL)
Config.ISLE_CHANCE_BASE = 0.03 -- шанс доп. цепочки вместо обычного куска на ISLE_FROM_LEVEL…
Config.ISLE_CHANCE_STEP = 0.004 -- …растёт за уровень…
Config.ISLE_CHANCE_MAX = 0.07 -- …до этого
Config.ISLE_MIN_SPACING = 400 -- studs между цепочками
Config.ISLE_COUNT = { 3, 6 } -- островков в цепочке: от / до (растёт с уровнем, см. isleCount)
Config.ISLE_SPEED = { 80, 120 } -- скорость вылета с ускорителя: на ISLE_FROM_LEVEL / потолок
Config.ISLE_SPEED_STEP = 2.5 -- + studs/с за уровень
Config.ISLE_SPEED_SPREAD = 1.2 -- окно ускорителя: [v, v · это]
Config.ISLE_LIFT = 0.45 -- подброс ускорителя (доля скорости по нормали, как RAMP_LIFT)
Config.ISLE_RAMP = { 14, 4.5 } -- длина / высота трамплина-ускорителя, studs
Config.ISLE_PITCH = { 2, 5 } -- уклон островка, градусы
Config.ISLE_LEN = { 60, 95 } -- длина островка (если баллистика не требует длиннее), studs
Config.ISLE_RIM = { 10, 20 } -- островок шире коридора (борта ±W/2) на столько с каждой стороны
Config.ISLE_DROP = { -3, 12 } -- следующий островок ниже на столько (минус — выше), studs
Config.ISLE_FINAL_DROP = { 8, 16 } -- склон приземления после цепочки ниже последнего островка
Config.ISLE_GAP_MIN = 18 -- самый узкий зазор, studs
Config.ISLE_GAP_FILL = 0.6 -- зазор не меньше этой доли дальности при нижней скорости
Config.ISLE_LAND_MARGIN = 14 -- при нижней скорости садимся не ближе этого к краю, studs
Config.ISLE_END_MARGIN = 6 -- при верхней скорости + ракета садимся не дальше начала трамплина − это
Config.ISLE_SLACK = 0.97 -- нижняя скорость в расчёте × это (гашение буста на кадре трамплина)
Config.ISLE_IN = { 4, 70 } -- кусок-разгон перед первым прыжком: уклон, длина
Config.ISLE_BONUS_CHANCE = 0.5 -- бонус (щит/x2/канистра/магнит) на островке
Config.ISLE_COINS = 7 -- монет дугой над пропастью
function Config.isleChance(level: number): number
	if level < Config.ISLE_FROM_LEVEL then
		return 0
	end
	return math.min(Config.ISLE_CHANCE_MAX, Config.ISLE_CHANCE_BASE + Config.ISLE_CHANCE_STEP * (level - Config.ISLE_FROM_LEVEL))
end
-- Островков в цепочке: 3 на первых уровнях, +1 каждые 4 уровня до 6; разброс −1
function Config.isleCount(level: number): (number, number)
	local hi = math.clamp(Config.ISLE_COUNT[1] + (level - Config.ISLE_FROM_LEVEL) // 4, Config.ISLE_COUNT[1], Config.ISLE_COUNT[2])
	return math.max(Config.ISLE_COUNT[1], hi - 1), hi
end
function Config.isleSpeed(level: number): (number, number)
	local v = math.min(Config.ISLE_SPEED[2], Config.ISLE_SPEED[1] + Config.ISLE_SPEED_STEP * math.max(0, level - Config.ISLE_FROM_LEVEL))
	return v, v * Config.ISLE_SPEED_SPREAD
end

-- Волны-бугры (#40): серия «спуск WAVE_DOWN → подъём WAVE_UP» со скруглёнными стыками
Config.WAVE_FROM_LEVEL = 3
Config.WAVE_CHANCE = 0.05 -- вместо обычного куска (свой генератор, раскладка уровня не сдвигается)
Config.WAVE_COUNT = { 3, 4 } -- гребней в серии
Config.WAVE_DOWN = { 10, 14 } -- спуск: уклон, длина
Config.WAVE_UP = { -3, 10 } -- подъём: уклон (минус — вверх), длина

-- Оформление обычных кусков (#40, art): цветные кромки дна, флажки-слалом по бортам, ледяные арки
Config.EDGE_STRIPES = true -- цветные полосы вдоль края дна (цвет мира)
Config.SLALOM_CHANCE = 0.45 -- флажки-слалом на бортах пологого/крутого куска
Config.ARCH_CHANCE = 0.12 -- большая арка над трассой на пологом куске («вау» в поле зрения)

-- Свои меши декора (#45, shared/Meshes): 1 — меши, если шаблоны загружены; 0 — всё из Part (как до #45).
-- Слои кадра ниже ставятся только мешами (без шаблонов их нет — старый вид, инстансов не прибавляется).
-- Шансы — на сторону куска длиной 110 studs (короче — пропорционально меньше).
Config.MESH_DECOR = 1
Config.DECOR_DRIFT_CHANCE = 0.8 -- ближний план: сугробы/дюны у внешнего края бортов
Config.DECOR_MID_CHANCE = 0.55 -- средний план: скалы/утёсы в 55–95 studs от трассы
Config.DECOR_FAR_CHANCE = 0.35 -- дальний план: второй ряд гор в 240–320 studs
Config.DECOR_WOW_CHANCE = 0.18 -- «вау»: парящий островок с ёлкой / каменная арка в поле зрения

-- Миры по уровням (по кругу)
Config.THEMES = {
	{
		name = "Снежный лес",
		floor = Color3.fromRGB(140, 195, 240),
		wall = Color3.fromRGB(95, 160, 225),
		ground = Color3.fromRGB(225, 235, 245),
	},
	{
		name = "Ледяной город",
		floor = Color3.fromRGB(120, 185, 235),
		wall = Color3.fromRGB(80, 145, 215),
		ground = Color3.fromRGB(215, 225, 238),
	},
	{
		name = "Каньон",
		floor = Color3.fromRGB(150, 200, 240),
		wall = Color3.fromRGB(110, 170, 230),
		ground = Color3.fromRGB(225, 195, 155),
	},
	{
		name = "Ледяные пещеры",
		floor = Color3.fromRGB(150, 215, 245),
		wall = Color3.fromRGB(90, 175, 235),
		ground = Color3.fromRGB(200, 230, 248),
	},
	{
		name = "Северное сияние",
		floor = Color3.fromRGB(125, 170, 225),
		wall = Color3.fromRGB(80, 120, 200),
		ground = Color3.fromRGB(205, 220, 240),
	},
	{
		name = "Снежный вулкан",
		floor = Color3.fromRGB(150, 190, 230),
		wall = Color3.fromRGB(110, 150, 210),
		ground = Color3.fromRGB(70, 66, 72),
	},
	{
		name = "Конфетная гора",
		floor = Color3.fromRGB(245, 185, 220),
		wall = Color3.fromRGB(230, 130, 195),
		ground = Color3.fromRGB(255, 232, 245),
	},
}

-- Мир = LEVELS_PER_WORLD уровней одной темы. 7 миров: лес → город → каньон → пещеры →
-- северное сияние → вулкан → конфетная гора, дальше по кругу («Снежный лес II» и т. д.)
Config.LEVELS_PER_WORLD = 5
Config.WORLD_ICONS = { "🌲", "🏙", "🌵", "🧊", "🌌", "🌋", "🍭" }
Config.WORLD_IMAGES = { "tree", "city", "cactus", "ice", "aurora", "volcano", "candy" } -- 3D-иконки (UI.icon)
Config.WORLD_COLORS = {
	Color3.fromRGB(70, 150, 220),
	Color3.fromRGB(120, 110, 220),
	Color3.fromRGB(225, 135, 60),
	Color3.fromRGB(80, 190, 230),
	Color3.fromRGB(40, 60, 130),
	Color3.fromRGB(200, 70, 50),
	Color3.fromRGB(235, 110, 190),
}
function Config.worldOf(level: number): number
	return (level - 1) // Config.LEVELS_PER_WORLD + 1
end
function Config.themeOfWorld(world: number): number
	return ((world - 1) % #Config.THEMES) + 1
end
function Config.themeOf(level: number): number
	return Config.themeOfWorld(Config.worldOf(level))
end
function Config.worldName(world: number): string
	local base = Config.THEMES[Config.themeOfWorld(world)].name
	local lap = (world - 1) // #Config.THEMES
	return if lap > 0 then base .. " " .. string.rep("I", lap + 1) else base
end

-- Табло «Следующее обновление» в лобби (UTC)
Config.NEXT_UPDATE = os.time({ year = 2026, month = 11, day = 15, hour = 12 })

------------------------------------------------------------------ БОНУСЫ НА ТРАССЕ
-- Подбираемые бонусы (тег PowerUp, атрибут Kind): шанс появиться на прямом участке
Config.POWERUPS = {
	shield = { chance = 0.07, name = "Щит" }, -- одно столкновение без аварии
	x2 = { chance = 0.07, name = "x2 монеты", time = 10 }, -- монеты на трассе ×2 на 10 с
	fuel = { chance = 0.09, name = "Канистра" }, -- полный бак ракеты
	rings = { chance = 0.12, name = "Кольца", coins = 10 }, -- 3 золотых кольца подряд, +10 за каждое
}
Config.MAGNET_CHANCE = 0.12 -- магнит на прямом участке
Config.MAGNET_TIME = 8 -- сек
Config.MAGNET_RADIUS = 32 -- studs
Config.GEMS_ON_TRACK = { 0.3, 0.62, 0.9 } -- где лежат гемы (доли уровня)
Config.CRYSTAL_AT = 0.5 -- ледяной кристалл (разбей — монеты + гем)
Config.CRYSTAL_COINS = 60
Config.COMBO_WINDOW = 1.3 -- сек между монетами, чтобы комбо не сбросилось
function Config.comboMult(combo: number): number
	return math.min(3, 1 + combo // 5) -- каждые 5 монет подряд +1 к множителю (до x3)
end

------------------------------------------------------------------ НАГРАДЫ (удержание)
-- Монетные награды растут с уровнем, чтобы оставаться полезными
function Config.rewardCoins(base: number, level: number): number
	return math.floor(base * (1 + (level - 1) * (if Config.F then Config.F.rewardGrowth else 0.25)))
end
-- Стрик: день цикла 1..7 по длине серии, награда (монеты с бонусом цикла — до rewardCoins), цена спасения
function Config.streakDay(count: number): number
	return (math.max(count, 1) - 1) % #Config.STREAK_REWARDS + 1
end
function Config.streakReward(count: number): (number?, number?)
	local r = Config.STREAK_REWARDS[Config.streakDay(count)]
	local coins = r.coins
	if coins and count > #Config.STREAK_REWARDS then
		coins = math.floor(coins * Config.STREAK_CYCLE_MULT)
	end
	return coins, r.gems
end
function Config.streakSavePrice(count: number): number
	return Config.STREAK_SAVE_GEMS + Config.STREAK_SAVE_STEP * (Config.streakDay(count) - 1)
end
-- Ежедневные задания: 3 в день из пула (выбор детерминирован по номеру дня)
-- Задания дня. max = true — считается лучший результат одного заезда, а не сумма.
-- icon — имя 3D-иконки (UI.icon). Каждый день выбирается TASKS_PER_DAY разных заданий.
Config.TASK_POOL = {
	-- заезды и дистанция
	{ id = "runs", text = "Сделай %d %s", forms = { "заезд", "заезда", "заездов" }, targets = { 5, 10 }, gems = 3, icon = "sled" },
	{ id = "distance", text = "Проедь %d м всего", targets = { 3000, 9000 }, gems = 4, icon = "mountain" },
	{ id = "distanceRun", text = "Проедь %d м за один заезд", targets = { 500, 1200 }, gems = 5, icon = "flag", max = true },
	{ id = "finish", text = "Доедь до финиша %d раз", targets = { 1, 3 }, gems = 6, icon = "flag" },
	{ id = "best", text = "Побей свой рекорд %d раз", targets = { 1, 2 }, gems = 5, icon = "trophy" },
	{ id = "farm", text = "Сделай %d %s в пройденном мире", forms = { "заезд", "заезда", "заездов" }, targets = { 2, 4 }, gems = 4, icon = "tree" },
	-- монеты и награды
	{ id = "coins", text = "Собери %d %s", forms = { "монету", "монеты", "монет" }, targets = { 300, 900 }, gems = 4, icon = "coin" },
	{ id = "coinsRun", text = "Заработай %d %s за один заезд", forms = { "монету", "монеты", "монет" }, targets = { 150, 400 }, gems = 5, icon = "moneybag", max = true },
	{ id = "combo", text = "Собери комбо x%d", targets = { 8, 20 }, gems = 5, icon = "star", max = true },
	{ id = "gems", text = "Подбери %d %s на трассе", forms = { "гем", "гема", "гемов" }, targets = { 3, 8 }, gems = 5, icon = "gem" },
	{ id = "crystal", text = "Разбей %d %s", forms = { "ледяной кристалл", "ледяных кристалла", "ледяных кристаллов" }, targets = { 1, 3 }, gems = 5, icon = "ice" },
	-- трюки и скорость
	{ id = "air", text = "Пробудь в воздухе %d с", targets = { 15, 45 }, gems = 5, icon = "parachute" },
	{ id = "airRun", text = "Пробудь в воздухе %d с за один заезд", targets = { 6, 15 }, gems = 5, icon = "parachute", max = true },
	{ id = "flips", text = "Сделай %d сальто", targets = { 3, 10 }, gems = 5, icon = "flip" },
	{ id = "speed", text = "Разгонись до %d км/ч", targets = { 100, 160 }, gems = 5, icon = "stopwatch", max = true }, -- км/ч = studs/с × 1.1; без ракеты терминал 70–113, 200 требовал Сани ≥ 34 ур.
	{ id = "smash", text = "Разбей %d %s", forms = { "препятствие", "препятствия", "препятствий" }, targets = { 5, 15 }, gems = 4, icon = "smash" },
	{ id = "boosts", text = "Проедь по %d %s", forms = { "ускорителю", "ускорителям", "ускорителям" }, targets = { 4, 12 }, gems = 4, icon = "bolt" },
	-- бонусы на трассе
	{ id = "magnet", text = "Подбери %d %s", forms = { "магнит", "магнита", "магнитов" }, targets = { 2, 5 }, gems = 4, icon = "magnet" },
	{ id = "shield", text = "Подбери %d %s", forms = { "щит", "щита", "щитов" }, targets = { 1, 3 }, gems = 5, icon = "shield" },
	{ id = "x2", text = "Подбери %d %s", forms = { "бонус x2", "бонуса x2", "бонусов x2" }, targets = { 1, 3 }, gems = 5, icon = "coin" },
	{ id = "fuel", text = "Подбери %d %s", forms = { "канистру", "канистры", "канистр" }, targets = { 1, 4 }, gems = 4, icon = "fuel" },
	{ id = "rings", text = "Пролети через %d %s", forms = { "золотое кольцо", "золотых кольца", "золотых колец" }, targets = { 3, 12 }, gems = 5, icon = "ring" },
	-- лобби
	{ id = "upgrades", text = "Улучши что-нибудь %d раз", targets = { 2, 6 }, gems = 4, icon = "rocket" },
	{ id = "gifts", text = "Забери %d %s за игру", forms = { "подарок", "подарка", "подарков" }, targets = { 2, 4 }, gems = 3, icon = "gift" },
	{ id = "chest", text = "Открой сундук в лобби", targets = { 1, 1 }, gems = 3, icon = "gift" },
	-- аккуратность и магазин
	{ id = "cleanFinish", text = "Доедь до финиша без аварии %d %s", forms = { "раз", "раза", "раз" }, targets = { 1, 3 }, gems = 7, icon = "check" },
	{ id = "cleanRun", text = "Проедь %d м за один заезд без аварии", targets = { 400, 1000 }, gems = 5, icon = "ringbuoy", max = true },
	{ id = "magnetCoins", text = "Притяни магнитом %d %s", forms = { "монету", "монеты", "монет" }, targets = { 20, 60 }, gems = 4, icon = "magnet" },
	{ id = "rareRuns", text = "Сделай %d %s на санях Gold или редче", forms = { "заезд", "заезда", "заездов" }, targets = { 3, 7 }, gems = 5, icon = "sparkles" },
	{ id = "buySled", text = "Купи %d %s саней", forms = { "редкость", "редкости", "редкостей" }, targets = { 1, 3 }, gems = 5, icon = "saucer" },
}
Config.TASKS_PER_DAY = 6

-- Число + слово в нужной форме: 1 заезд, 3 заезда, 5 заездов
function Config.plural(n: number, forms: { string }): string
	local n10, n100 = n % 10, n % 100
	if n10 == 1 and n100 ~= 11 then
		return forms[1]
	elseif n10 >= 2 and n10 <= 4 and (n100 < 12 or n100 > 14) then
		return forms[2]
	end
	return forms[3]
end
function Config.taskText(t, target: number): string
	if t.forms then
		return string.format(t.text, target, Config.plural(target, t.forms))
	end
	return string.format(t.text, target)
end
Config.TASK_CHEST_COINS = 500 -- сундук за все задания (× rewardCoins) + гемы
Config.TASK_CHEST_GEMS = 15
-- Подарки за время в игре (минуты с захода), как сетка «Подарки» в референсе
Config.PLAYTIME_GIFTS = {
	{ min = 1, gems = 2 }, -- 1-я минута — гемы: монеты тут дали бы лишнюю покупку до 2-го заезда (#31)
	{ min = 3, coins = 60 },
	{ min = 5, coins = 80 },
	{ min = 7, gems = 3 }, -- было 8: не «съедает» ожидание большого подарка
	-- «Большой подарок» (#24): цель «досидеть до 10 минут»; раз в день (Daily.big), не фармится
	-- перезаходом. 600 монет × rewardCoins ≈ 40% следующего апгрейда на 10-й минуте (кривая #31)
	{ min = 10, coins = 600, gems = 5, big = true },
	{ min = 14, coins = 120 }, -- было 12
	{ min = 16, coins = 150, gems = 2 },
	{ min = 20, coins = 200 },
	{ min = 25, gems = 5 },
	{ min = 30, coins = 450 },
	{ min = 40, gems = 6 },
	{ min = 50, coins = 700 },
	{ min = 60, coins = 1000, gems = 10 },
}
-- Сундук в лобби раз в 4 часа
Config.CHEST_INTERVAL = 4 * 3600
Config.CHEST_COINS = 75 -- доступен сразу: 75 + 1-й заезд ≈ одна покупка, не пять (#31)
Config.CHEST_GEMS = 3
-- Стрик дней входа (#25): день = os.time() // 86400 (UTC, как у заданий). Награда за день цикла 1..7,
-- монеты × rewardCoins; дни 1–6 — 100…400 (меньше Большого подарка 600 + 5 💎), 7-й — крупный: 600 + 25 💎.
-- Неделя: 2000 монет-базы + 35 💎 — повод зайти, а не замена заездов (кривая #31 не сдвигается)
Config.STREAK_REWARDS = {
	{ coins = 100 },
	{ coins = 150, gems = 2 },
	{ coins = 200 },
	{ coins = 250, gems = 3 },
	{ coins = 300 },
	{ coins = 400, gems = 5 },
	{ coins = 600, gems = 25, big = true },
}
Config.STREAK_CYCLE_MULT = 1.25 -- монеты со 2-го цикла (дни 8+), не накапливается
Config.STREAK_SAVE_GEMS = 10 -- спасение стрика после пропуска 1 дня: цена, если серия была 1 день
Config.STREAK_SAVE_STEP = 2 -- +💎 за каждый следующий день цикла серии (6 дней → 20, 7 → 22)
Config.SESSION_GOAL_MIN = 13 -- цель полоски «сессия» в лобби (минуты с захода, #24)
Config.SESSION_CHECK_SEC = 5 -- как часто сервер проверяет «сессия ≥ 10 мин» для аналитики
Config.DEV_SESSION_SHIFT = 5 * 60 -- DEV «+5 мин сессии»

------------------------------------------------------------------ ФИЗИКА САНОК
Config.GRAVITY_ALONG = 60 -- «игровая» гравитация вдоль склона
Config.DRAG = 0.0012 -- сопротивление воздуха (× v²)
Config.STOP_SPEED = 3 -- ниже этой скорости...
Config.STOP_TIME = 1.5 -- ...столько секунд = остановился
Config.STEER_SPEED = 45 -- максимальная боковая скорость (на скорости до STEER_REF_SPEED)
Config.STEER_REF_SPEED = 100 -- выше этой скорости руль растёт пропорционально ей: время смены полосы постоянно
Config.STEER_RESPONSE = 7 -- как быстро боковая скорость догоняет руль (инерция)
-- Боковая скорость руля на текущей скорости (docs/GAME_DESIGN.md → «Скорость и руль»)
function Config.steerSpeed(speed: number): number
	return Config.STEER_SPEED * math.max(1, speed / math.max(1, Config.STEER_REF_SPEED))
end
Config.WALL_PULL = 140 -- борта жёлоба скатывают обратно к центру
Config.STEER_TILT = 18 -- наклон ватрушки в повороте (градусы)
Config.OBSTACLE_SLOWDOWN = 0.6 -- скорость × это при ударе
Config.BOOST_ADD = 18 -- ускоритель на льду
Config.RAMP_MIN_SPEED = 30 -- на трамплине не медленнее этого (не застрянешь)
Config.RAMP_LIFT = 0.45 -- подброс с трамплина (доля скорости вверх)
Config.ROCKET_THRUST = 40
Config.FLIP_SPEED = 9 -- рад/с: скорость вращения во всех трюках (сальто, бочка, разворот)

-- Прыжок с земли (кнопка «Прыжок»): подброс вверх; высота = v² / (2·196.2) ≈ 4 studs при 40.
-- Перелетаются низкие препятствия (конусы 1.3, бревно 2.6, барьер 3.2, бочки 3.5), но не
-- гидрант (4.3), машины (крыша 5.4) и снеговик (13.9) — высоты из server/Props.
Config.JUMP_SPEED = 40 -- studs/с вверх
Config.JUMP_COOLDOWN = 0.6 -- сек между прыжками
Config.JUMP_GROUND_DIST = 1.3 -- после прыжка «в воздухе», пока центр саней выше этого над снегом (обычно ~0.5)

------------------------------------------------------------------ ТРЮКИ (в воздухе)
-- Клиент копит завершённые трюки за один полёт и при приземлении шлёт список серверу.
-- kind: pitch (вокруг поперечной оси, dir −1 назад / +1 вперёд), roll (вокруг продольной),
-- yaw (вокруг вертикали, направление движения не меняется), grab (без вращения — наклон саней).
-- minAir — минимальное время в воздухе (с), coins — монет за один, boost — × скорость при чистом приземлении.
Config.TRICK_ORDER = { "flip", "frontflip", "roll", "spin", "grab" }
Config.TRICKS = {
	flip = { name = "Сальто", input = "держать Пробел / 🔄", coins = 15, boost = 1.12, minAir = 0, icon = "flip", kind = "pitch", dir = -1 },
	frontflip = { name = "Переднее сальто", input = "Пробел + S/↓ (руль вперёд)", coins = 20, boost = 1.15, minAir = 0, icon = "flip", kind = "pitch", dir = 1 },
	roll = { name = "Бочка", input = "Пробел + A/D (руль вбок)", coins = 20, boost = 1.12, minAir = 0, icon = "sparkles", kind = "roll" },
	spin = { name = "Разворот 360", input = "Пробел дважды в воздухе", coins = 25, boost = 1.1, minAir = 0, icon = "star", kind = "yaw" },
	grab = { name = "Грэб", input = "короткий тап Пробела (< 0.2 с)", coins = 8, boost = 1.0, minAir = 0.4, icon = "parachute", kind = "grab" },
}
Config.TRICK_COMBO_MULT = { 1, 1.5, 2 } -- множитель монет за 1 / 2 / 3+ разных трюков в одном полёте
Config.TRICK_MAX_COUNT = 5 -- больше одного трюка одного вида за полёт сервер не засчитывает
Config.TRICK_TAP_TIME = 0.2 -- сек: короче — «грэб», дольше — вращение
Config.TRICK_DOUBLE_TAP = 0.35 -- сек между нажатиями для «разворота»
Config.GRAB_TIME = 0.5 -- сек: сколько длится наклон саней в грэбе
function Config.trickComboMult(distinct: number): number
	local m = Config.TRICK_COMBO_MULT
	return m[math.clamp(distinct, 1, #m)]
end
-- Авто-трюки (#39, как в Sled Surfers): в полёте трюк запускается сам. Клиент, как только сани
-- поднялись выше AC_AIR_HEIGHT над снегом (значит, полёт видит и сервер), предсказывает время
-- полёта по вертикальной скорости и высоте над трассой (луч вниз под санями и на AUTO_TRICK_LOOKAHEAD
-- с вперёд) и берёт последний ярус AUTO_TRICK_PLANS, чей air ≤ предсказанного: options[1] — по
-- умолчанию, с вероятностью AUTO_TRICK_RANDOM — случайный другой вариант. Скорость вращения
-- авто-трюка каждый кадр подбирается так, чтобы оборот закончился за AUTO_TRICK_MARGIN до касания
-- (в пределах AUTO_TRICK_MIN_SPEED…MAX_SPEED); не успел — трюк молча не засчитывается, «Падения» нет.
-- Нажатие Пробела/🔄 во время авто-трюка добавляет в комбо ещё один, ещё не сделанный трюк.
Config.AUTO_TRICKS = 1 -- 1 — авто-трюки включены, 0 — только ручные (как до #39)
Config.AUTO_TRICK_PLANS = {
	{ air = 0.5, options = { { "grab" }, { "spin" } } }, -- короткий полёт: грэб / разворот
	{ air = 0.9, options = { { "flip" }, { "frontflip" }, { "roll" } } }, -- сальто
	{ air = 1.5, options = { { "flip", "grab" }, { "roll", "grab" }, { "frontflip", "spin" } } },
	{ air = 2.2, options = { { "flip", "roll", "grab" }, { "frontflip", "spin", "grab" }, { "roll", "flip", "grab" } } },
}
Config.AUTO_TRICK_RANDOM = 0.3 -- доля полётов, где вместо варианта по умолчанию — случайный другой
Config.AUTO_TRICK_MARGIN = 0.12 -- с: оборот заканчивается не позже чем за столько до касания
Config.AUTO_TRICK_MIN_SPEED = 6 -- рад/с: медленнее не крутим (длинный полёт — плавный трюк)
Config.AUTO_TRICK_MAX_SPEED = 22 -- рад/с: быстрее не докручиваем (оборот за 0.29 с)
Config.AUTO_TRICK_SAFE_AIR = 0.7 -- оборотов в плане ≤ maxRotations(предсказанный полёт × это): запас к серверному полёту
Config.AUTO_TRICK_RAY = 120 -- studs: луч вниз для высоты над трассой
Config.AUTO_TRICK_LOOKAHEAD = 0.4 -- с: где по горизонтали мерить второй луч (наклон трассы впереди)
Config.AUTO_TRICK_UNKNOWN_AIR = 0.6 -- с: оценка остатка полёта, если луч не нашёл снег (обрыв глубже луча)

-- Сколько полных оборотов физически влезает в полёт (для серверной проверки)
function Config.maxRotations(airTime: number): number
	return 1 + math.floor(math.max(0, airTime) * Config.FLIP_SPEED / (2 * math.pi))
end

------------------------------------------------------------------ АПГРЕЙДЫ
-- 4 апгрейда как в оригинале. Ракета качается за гемы, остальные — за монеты.
-- Каждые TIER_SIZE уровней — новый «тир»: меняется вид рогатки/санок, а переход на него стоит гемы.
Config.TIER_SIZE = 5
Config.UPGRADES = {
	Launch = { title = "Рогатка", icon = "🎯", color = Color3.fromRGB(225, 80, 70), BaseCost = 100, Growth = 1.01, MaxLevel = 50 },
	Sled = { title = "Сани", icon = "🛷", color = Color3.fromRGB(60, 130, 230), BaseCost = 130, Growth = 1.01, MaxLevel = 50 },
	Income = { title = "Доход", icon = "💰", color = Color3.fromRGB(235, 165, 35), BaseCost = 180, Growth = 1.02, MaxLevel = 50 },
	Rocket = { title = "Ракета", icon = "🚀", color = Color3.fromRGB(240, 115, 45), MaxLevel = 30, gems = true },
}
Config.UPGRADE_ORDER = { "Launch", "Sled", "Income", "Rocket" }

-- Названия тиров (показываются при получении: «ПОЛУЧЕНА СТАЛЬНАЯ РОГАТКА!»)
-- Названия тиров: новый тир каждые TIER_SIZE уровней (рогатка/сани/доход — до 50 ур., ракета — до 30)
Config.TIERS = {
	Launch = {
		"Деревянная рогатка", "Стальная рогатка", "Мега-рогатка", "Силовая рогатка", "Золотая рогатка", "Неоновая рогатка",
		"Ледяная рогатка", "Огненная рогатка", "Техно-рогатка", "Радужная рогатка", "Галактическая рогатка",
	},
	Sled = {
		"Обычные санки", "Фары", "Спойлер", "Обтекатель", "Золотой бампер", "Неоновая подсветка",
		"Флажок", "Боковые крылья", "Хромированные выхлопы", "Сияние", "Корона чемпиона",
	},
	Income = {
		"Копилка", "Мешок монет", "Сундук", "Сейф", "Банк", "Золотой банк",
		"Монетный двор", "Сокровищница", "Алмазный сейф", "Золотая гора", "Империя монет",
	},
	Rocket = { "Петарда", "Ракета", "Турбо-ракета", "Мега-двигатель", "Бласт-двигатель", "Гиперджет", "Плазменный двигатель" },
}
-- Фоновая музыка: пробуем по порядку, первая загрузившаяся играет по кругу.
-- Свой трек: залить аудио в Creator Hub и поставить его ID первым.
Config.MUSIC_IDS = { 125871106395463, 132489602913551, 140520386514181 }
Config.MUSIC_VOLUME = 0.16

function Config.tierOf(level: number): number
	return level // Config.TIER_SIZE
end
function Config.tierName(name: string, level: number): string
	local list = Config.TIERS[name]
	return list[math.min(Config.tierOf(level) + 1, #list)]
end

-- Коэффициенты формул прокачки (настраиваются в панели разработчика)
Config.F = {
	launchBase = 48, launchStep = 6, -- сила рогатки = база + шаг × уровень
	fuelBase = 0.6, fuelStep = 0.3, -- топливо ракеты, сек
	frictionBase = 9.5, frictionDecay = 0.965, -- трение = база × спад^уровень
	speedBase = 100, speedStep = 5, -- потолок скорости: наклон на 0-м уровне (studs/с за уровень)
	speedSoftCap = 200, -- асимптота потолка: выше него потолок не поднимется ни на каком уровне
	incomeStep = 0.15, -- множитель монет = 1 + шаг × уровень
	finishPerLevel = 100, -- бонус за финиш = это × уровень
	rewardGrowth = 0.25, -- рост монетных наград с уровнем
}
function Config.launchSpeed(level: number): number
	return Config.F.launchBase + Config.F.launchStep * level
end
function Config.rocketFuel(level: number): number
	return Config.F.fuelBase + Config.F.fuelStep * level -- секунд
end
function Config.friction(level: number): number
	return Config.F.frictionBase * Config.F.frictionDecay ^ level
end
-- Потолок скорости с убывающим ростом: стартует как base + step·level, но плавно упирается в
-- speedSoftCap (0 → 100, 10 → 139, 20 → 163, 30 → 177, 50 → 191 при 100/5/200).
-- Расчёт и таблица «уровень → скорость → время смены полосы» — docs/GAME_DESIGN.md.
function Config.maxSpeed(level: number): number
	local base, step, cap = Config.F.speedBase, Config.F.speedStep, Config.F.speedSoftCap
	local span = cap - base
	if span <= 0 or step <= 0 then
		return base -- кап ниже базы или нулевой шаг: потолок не растёт
	end
	return cap - span * math.exp(-step * level / span)
end
function Config.incomeMult(level: number): number
	return 1 + Config.F.incomeStep * level
end

-- Цена следующего уровня: (сколько, валюта "Coins" | "Gems").
-- Монеты: BaseCost × (1 + уровень)^UPGRADE_PRICE_POW × Growth^уровень. Степенная часть дорожает
-- быстро в начале (×4, ×2.3, ×1.8 …) и полого к концу — как растёт доход за заезд; Growth — хвост.
-- Модель (#31): 1-я покупка после 1-го заезда, далее раз в 2–4 заезда, лестница 3×50 ≈ 60 ч игры.
Config.UPGRADE_PRICE_POW = 2
function Config.upgradePrice(name: string, level: number): (number, string)
	local u = Config.UPGRADES[name]
	if u.gems then
		return 1 + level // 3, "Gems"
	end
	if level > 0 and level % Config.TIER_SIZE == 0 then
		return 1 + level // (Config.TIER_SIZE * 2), "Gems" -- переход на новый тир
	end
	return math.floor(u.BaseCost * (1 + level) ^ Config.UPGRADE_PRICE_POW * u.Growth ^ level), "Coins"
end
-- совместимость со старым кодом
function Config.upgradeCost(name: string, level: number): number
	return (Config.upgradePrice(name, level))
end

------------------------------------------------------------------ ГЕМЫ
Config.GEMS_FINISH = 3 -- за пройденный уровень
Config.GEMS_NEW_BEST = 1 -- за новый рекорд на уровне
Config.GEMS_FARM_FINISH = 1 -- финиш в уже пройденном мире (фарм): уровень не растёт

-- Robux-товары (Developer Products). Владелец создаёт их в Creator Dashboard
-- (Monetization → Developer Products) и вписывает сюда ID; при id = 0 кнопка покажет «скоро».
Config.PRODUCTS = {
	SkipWorld = { id = 0, price = 49 }, -- пропуск текущего мира: сразу на 1-й уровень следующего
}

-- Уровень, на котором едем при фарме мира (последний, самый длинный уровень мира)
function Config.farmLevel(world: number): number
	return world * Config.LEVELS_PER_WORLD
end

------------------------------------------------------------------ СКИНЫ ВАТРУШЕК (за монеты)
-- tube — основной цвет, rim — бортик, neon — светится

------------------------------------------------------------------ САНИ С РЕДКОСТЯМИ (как в Roblox-референсе)
-- Модель открывается с миром; у каждой 5 редкостей. Редкость покупается по порядку и даёт +% скорости.
Config.RARITIES = {
	{ name = "Обычная", bonus = 0 },
	{ name = "Gold", bonus = 2, color = Color3.fromRGB(245, 195, 60), material = Enum.Material.SmoothPlastic, shine = 0.25 },
	{ name = "Diamond", bonus = 4, color = Color3.fromRGB(160, 225, 255), material = Enum.Material.Glass, shine = 0.2 },
	{ name = "Ruby", bonus = 7, color = Color3.fromRGB(220, 40, 70), material = Enum.Material.SmoothPlastic, shine = 0.15 },
	-- Galaxy: тёмно-фиолетовый глянец, светятся только акценты (иначе неон «съедает» детали модели)
	{ name = "Galaxy", bonus = 10, color = Color3.fromRGB(95, 45, 200), material = Enum.Material.SmoothPlastic, shine = 0.2 },
}
-- Сани: модель открывается с миром; main/accent — цвета обычной редкости
Config.SLEDS = {
	{ id = "tube", name = "Ватрушка", icon = "🍩", img = "donut", world = 1, bonus = 0, prices = { 0, 300, 900, 2400, 6000 }, main = Color3.fromRGB(240, 70, 120), accent = Color3.fromRGB(255, 160, 195) },
	{ id = "saucer", name = "Ледянка", icon = "🥏", img = "saucer", world = 1, bonus = 2, prices = { 250, 700, 1800, 4500, 10000 }, main = Color3.fromRGB(60, 150, 245), accent = Color3.fromRGB(255, 220, 70) },
	{ id = "board", name = "Доска", icon = "🏂", img = "snowboard", world = 1, bonus = 3, prices = { 700, 1500, 3500, 8000, 18000 }, main = Color3.fromRGB(70, 130, 230), accent = Color3.fromRGB(255, 200, 60) },
	{ id = "toboggan", name = "Тобоган", icon = "🪵", img = "toboggan", world = 2, bonus = 5, prices = { 2500, 5500, 12000, 25000, 50000 }, main = Color3.fromRGB(196, 132, 76), accent = Color3.fromRGB(200, 50, 50) },
	{ id = "classic", name = "Деревянные санки", icon = "🛷", img = "sled", world = 2, bonus = 6, prices = { 4000, 8000, 16000, 32000, 60000 }, main = Color3.fromRGB(186, 128, 74), accent = Color3.fromRGB(190, 40, 40) },
	{ id = "kayak", name = "Снежный каяк", icon = "🛶", img = "canoe", world = 3, bonus = 8, prices = { 9000, 18000, 36000, 72000, 140000 }, main = Color3.fromRGB(250, 170, 40), accent = Color3.fromRGB(40, 60, 90) },
	{ id = "plane", name = "Сани-самолёт", icon = "✈", img = "plane", world = 3, bonus = 10, prices = { 15000, 30000, 60000, 120000, 240000 }, main = Color3.fromRGB(225, 55, 55), accent = Color3.fromRGB(245, 245, 250) },
	{ id = "bobsled", name = "Бобслей", icon = "🏎", img = "racecar", world = 4, bonus = 13, prices = { 30000, 60000, 120000, 240000, 480000 }, main = Color3.fromRGB(40, 90, 210), accent = Color3.fromRGB(240, 240, 250) },
	{ id = "snowmobile", name = "Снегоход", icon = "🛵", img = "scooter", world = 5, bonus = 17, prices = { 70000, 140000, 280000, 560000, 1100000 }, main = Color3.fromRGB(230, 200, 30), accent = Color3.fromRGB(30, 32, 40) },
}
function Config.sled(id: string?)
	for _, s in Config.SLEDS do
		if s.id == id then
			return s
		end
	end
	return Config.SLEDS[1]
end
-- Общий бонус скорости (доля): модель + редкость
function Config.sledBonus(id: string?, rarity: number?): number
	local s = Config.sled(id)
	local r = Config.RARITIES[math.clamp(rarity or 1, 1, #Config.RARITIES)]
	return (s.bonus + r.bonus) / 100
end

------------------------------------------------------------------ СЛЕДЫ (шлейф за санками, +% монет)
Config.TRAILS = {
	{ id = "white", name = "Снежный", color = Color3.fromRGB(235, 245, 255), bonus = 0, price = 0 },
	{ id = "orange", name = "Апельсин", color = Color3.fromRGB(255, 150, 50), bonus = 10, price = 600 },
	{ id = "yellow", name = "Солнце", color = Color3.fromRGB(255, 225, 60), bonus = 15, price = 1500 },
	{ id = "green", name = "Лайм", color = Color3.fromRGB(110, 230, 90), bonus = 25, price = 4000 },
	{ id = "blue", name = "Океан", color = Color3.fromRGB(70, 150, 255), bonus = 30, price = 9000 },
	{ id = "purple", name = "Аметист", color = Color3.fromRGB(170, 90, 255), bonus = 35, price = 16000 },
	{ id = "pink", name = "Фламинго", color = Color3.fromRGB(255, 110, 190), bonus = 45, price = 30000 },
	{ id = "rainbow", name = "Радуга", color = Color3.fromRGB(255, 80, 80), bonus = 60, price = 60000, rainbow = true },
}
function Config.trail(id: string?)
	for _, t in Config.TRAILS do
		if t.id == id then
			return t
		end
	end
	return Config.TRAILS[1]
end

------------------------------------------------------------------ ЭКОНОМИКА
Config.STUDS_PER_COIN = 4
Config.COIN_PICKUP_VALUE = 3
-- Монеты за трюки — в Config.TRICKS[id].coins (× Config.trickComboMult за разные трюки в полёте)
function Config.finishBonus(level: number): number
	return Config.F.finishPerLevel * level
end
Config.GAMEPASS_X2_COINS = 0 -- ID геймпасса «x2 монеты» (0 = выкл)

------------------------------------------------------------------ АНТИЧИТ (server/AntiCheat)
-- Санки считает клиент (network ownership), сервер проверяет правдоподобие. Предел скорости —
-- «огибающая» env: максимум скорости, который честный игрок мог набрать к этому моменту.
--   старт: max(рогатка launchSpeed(L) — до ~348 на 50 ур., потолок саней maxSpeed × (1 + бонус)
--   — до 200 × 1.27, терминал ракеты на земле √((ROCKET_THRUST + GRAVITY_ALONG·sin16°) / DRAG)
--   ≈ 217: выше него ракета на земле не разгоняет — сопротивление сильнее тяги);
--   + (тяга + гравитация) × время полёта, пока есть топливо (в воздухе сопротивления нет);
--   + BOOST_ADD за каждый засчитанный ускоритель; × буст трюков (тот же, что у клиента);
--   на земле спадает не быстрее AC_DECAY × DRAG × v² (честные сани тормозят быстрее).
-- Предел прогресса за тик = (env × AC_SPEED_MULT + AC_SPEED_ADD) × dt. Моделирование
-- (scratchpad: уровни 0/10/30/50, бонус 0/27 %, ракета, цепочки трамплинов, сальто ×2.25,
-- ускорители, канистры): честная скорость ≤ 1.93 env, отставание засчитанного пути ≤ 0.3 с
-- предела — при допуске AC_LAG_SEC = 1.5 с флагов нет.
Config.AC_SPEED_MULT = 1.25 -- запас на рывки репликации и боковой руль (до 1.1 × скорости)
Config.AC_SPEED_ADD = 30 -- studs/с: трамплин держит не меньше RAMP_MIN_SPEED = 30
Config.AC_DECAY = 0.5 -- доля сопротивления DRAG·v², на которую спадает огибающая на земле
Config.AC_LAG_SEC = 1.5 -- флаг, если реальный путь ушёл вперёд засчитанного больше, чем на столько секунд предела
-- Телепорт = заезд окончен: сдвиг по горизонтали за тик > AC_TELEPORT_STUDS + предел × dt ×
-- AC_TELEPORT_MULT. На 0 ур. за тик 0.2 с это 150 + 301·0.2·2 ≈ 270 studs, на 50 ур. ≈ 336 —
-- перенос на 500 studs ловится; честный рывок даже при 1.93 env — не больше 0.39 env за тик.
Config.AC_TELEPORT_STUDS = 150
Config.AC_TELEPORT_MULT = 2
Config.AC_DT_MAX = 3 -- сек: дольше «заморозки» позиции (лаг) не накапливаем допуск
-- Полёт по серверу: луч вниз от саней до трассы длиннее AC_AIR_HEIGHT. Центр саней на снегу
-- ~0.5 над поверхностью (на борту жёлоба 74° ≈ 1.8 по вертикали); прыжок поднимает на ~4
-- (JUMP_SPEED² / 2g). Самый короткий честный полёт с наградой — грэб, 0.4 с: на ровном он выше
-- 2.5 studs ≈ 0.24 с (≥ 1 серверный тик 0.2 с); полёт 0.6 с (AIR_MIN_TIME) — ≈ 0.51 с (≥ 2 тика).
-- Монеты за полёт = min(время клиента, полёт по серверу + AC_AIR_GRACE).
Config.AC_AIR_HEIGHT = 2.5
Config.AC_AIR_GRACE = 0.4 -- сек: взлёт/посадка ниже порога + шаг тика 0.2 с
-- Дольше этого в воздухе без земли — флаг (полёт-чит). Честный худший случай — трамплин на 50 ур.:
-- вверх 0.45·348 ≈ 157 studs/с, обрыв 22 + склон 16° уходит вниз → ≈ 2.8 с.
Config.AC_MAX_AIR = 6
-- Бонус/препятствие засчитываем, если оно ближе AC_NEAR_RADIUS + скорость × AC_NEAR_LAG:
-- серверная позиция саней отстаёт от клиентской на пинг (на 350 studs/с за 0.2 с это 70 studs).
Config.AC_NEAR_RADIUS = 30
Config.AC_NEAR_LAG = 0.3
Config.AC_FLAG_LIMIT = 6 -- столько мягких нарушений за заезд = заезд не засчитан
Config.AC_FLAG_COOLDOWN = 2 -- сек: одно и то же нарушение по позиции считаем не чаще

------------------------------------------------------------------ ЛИДЕРБОРД НЕДЕЛИ (#26, server/Weekly)
-- Неделя ISO по UTC (shared/Week), сброс в понедельник 00:00 UTC. Доски (OrderedDataStore, ключ
-- u_<UserId>): лучшая дистанция за заезд в мире N — LB_W<год>-<нед>_<N>; чистые финиши недели —
-- LB_W<год>-<нед>_clean. Топ-3 прошлой недели — титул на неделю (WeeklyWinners_v1).
-- Бюджет запросов — docs/ARCHITECTURE.md → «Лидерборд недели».
Config.WEEKLY = {
	REFRESH = 60, -- с: опрос досок и обновление табло
	WRITE_EVERY = 30, -- с: запись игрока в доски не чаще (лимит ключа — 1 запись / 6 с)
	FLUSH_TICK = 5, -- с: проверка очереди записей
	PAGE = 100, -- записей с доски за один запрос (место игрока — в первой сотне)
	SHOW = 10, -- строк на табло
	MAX_FLAGS = 2, -- заезд с ≥ стольких флагов античита в доску не идёт (≥ AC_FLAG_LIMIT — уже «cheat»)
	MAX_AVG_SPEED = 400, -- studs/с: путь ≤ время с выстрела × это (страховка поверх AntiCheat)
	BUDGET_RESERVE = 2, -- запросов в бюджете DataStore оставляем остальным системам
	WINNERS_DELAY = 180, -- с после сброса: ждём последние записи прошлой недели, потом считаем топ-3
	PAGE_SEC = 8, -- с: смена страницы табло (неделя мира → чистые финиши → всё время)
	-- по месту в прошлой неделе (лучшее из досок, где игрок играл); kind — цвет плашки UI.KIND
	TITLES = {
		{ id = "gold", name = "Чемпион недели", icon = "👑", kind = "yellow" },
		{ id = "silver", name = "Серебро недели", icon = "🥈", kind = "grey" },
		{ id = "bronze", name = "Бронза недели", icon = "🥉", kind = "orange" },
	},
}

------------------------------------------------------------------ НАСТРОЙКА В ИГРЕ
-- Параметры, которые владелец меняет в панели разработчика (вкладка «Настройка»).
-- Изменения хранятся в DataStore и применяются на всех серверах без перевыпуска игры.
-- { путь в Config, подпись, группа, мин, макс, шаг }
-- Обучение первых заездов (#27, client/Tutorial): одна подсказка за раз, исчезает по действию.
-- Порядок = номер бита в сейве (DataService.Tutorial) — НЕ переставлять, только дописывать в конец.
-- where: "lobby" | "run"; pc/touch — текст для клавиатуры и для телефона (≤ 6 слов).
Config.TUTORIAL = {
	MAX_RUNS = 3, -- с этого заезда подсказок нет (в заезде — с MAX_RUNS-го, в лобби — после него)
	IDLE = 5, -- с бездействия в лобби до подсказки «к саням»
	HOLD = 7, -- с: подсказка в заезде висит не дольше (потом считается показанной)
	GAP = 2.5, -- с: пауза между подсказками
	STEER_AHEAD = 40, -- studs до первого ряда препятствий (SAFE_START): показать «руль»
	PULSE = 2.2, -- с: период подсветки карточки апгрейда
	STEPS = {
		{ id = "play", where = "lobby", icon = "sled", pc = "Иди к саням или жми ▼", touch = "Иди к саням или жми ▼" },
		{ id = "launch", where = "run", icon = "bullseye", pc = "Зажми мышь, тяни, отпусти!", touch = "Тяни вниз и отпусти!" },
		{ id = "steer", where = "run", icon = "sled", pc = "A / D — объезжай камни!", touch = "Веди пальцем — объезжай!" },
		{ id = "jump", where = "run", icon = "bolt", pc = "Ctrl — прыжок!", touch = "Жми ⤴ — прыжок!" },
		{ id = "flip", where = "run", icon = "flip", pc = "Трюки сами! Жми Пробел — ещё один", touch = "Трюки сами! Жми 🔄 — ещё один" },
		{ id = "rocket", where = "run", icon = "fire", pc = "Shift — ракета ломает ящики!", touch = "Жми 🔥 — ракета ломает ящики!" },
		{ id = "upgrade", where = "lobby", icon = "star", pc = "Улучши — полетишь дальше!", touch = "Улучши — полетишь дальше!" },
		{ id = "again", where = "lobby", icon = "flag", pc = "Поехали ещё! Жми ▼", touch = "Поехали ещё! Жми ▼" },
	},
}

Config.TUNABLES = {
	{ "F.launchBase", "Рогатка: сила на 0 ур.", "Прокачка", 10, 200, 1 },
	{ "F.launchStep", "Рогатка: + силы за уровень", "Прокачка", 1, 20, 0.5 },
	{ "UPGRADES.Launch.BaseCost", "Рогатка: цена 1-го ур.", "Прокачка", 5, 1000, 5 },
	{ "UPGRADES.Launch.Growth", "Рогатка: рост цены ×", "Прокачка", 1.01, 1.5, 0.01 },
	{ "F.speedBase", "Сани: потолок скорости на 0 ур.", "Прокачка", 50, 300, 5 },
	{ "F.speedStep", "Сани: + потолка за уровень (на 0 ур.)", "Прокачка", 0, 20, 0.5 },
	{ "F.speedSoftCap", "Сани: асимптота потолка", "Прокачка", 100, 400, 5 },
	{ "F.frictionBase", "Сани: трение на 0 ур.", "Прокачка", 1, 30, 0.5 },
	{ "F.frictionDecay", "Сани: спад трения за ур.", "Прокачка", 0.8, 1, 0.005 },
	{ "UPGRADES.Sled.BaseCost", "Сани: цена 1-го ур.", "Прокачка", 5, 1000, 5 },
	{ "UPGRADES.Sled.Growth", "Сани: рост цены ×", "Прокачка", 1.01, 1.5, 0.01 },
	{ "F.incomeStep", "Доход: + множителя за ур.", "Прокачка", 0.01, 1, 0.01 },
	{ "UPGRADES.Income.BaseCost", "Доход: цена 1-го ур.", "Прокачка", 5, 2000, 5 },
	{ "UPGRADES.Income.Growth", "Доход: рост цены ×", "Прокачка", 1.01, 1.5, 0.01 },
	{ "UPGRADE_PRICE_POW", "Апгрейды: степень цены (1+ур)^x", "Прокачка", 0, 4, 0.1 },
	{ "F.fuelBase", "Ракета: топливо на 0 ур., с", "Прокачка", 0.1, 5, 0.1 },
	{ "F.fuelStep", "Ракета: + топлива за ур., с", "Прокачка", 0.05, 2, 0.05 },
	{ "ROCKET_THRUST", "Ракета: тяга", "Прокачка", 5, 150, 1 },

	{ "STUDS_PER_COIN", "Studs за 1 монету дистанции", "Экономика", 1, 20, 1 },
	{ "COIN_PICKUP_VALUE", "Монета на трассе = N", "Экономика", 1, 50, 1 },
	{ "F.finishPerLevel", "Финиш: монет × уровень", "Экономика", 0, 1000, 10 },
	{ "F.rewardGrowth", "Рост наград с уровнем", "Экономика", 0, 2, 0.05 },
	{ "GEMS_FINISH", "Гемов за финиш", "Экономика", 0, 50, 1 },
	{ "GEMS_NEW_BEST", "Гемов за рекорд", "Экономика", 0, 20, 1 },
	{ "GEMS_FARM_FINISH", "Гемов за финиш (фарм)", "Экономика", 0, 20, 1 },
	{ "CRYSTAL_COINS", "Кристалл: монет", "Экономика", 0, 500, 5 },
	{ "SMASH_COINS", "Разбил препятствие: монет", "Экономика", 0, 100, 1 },
	{ "TRICKS.flip.coins", "Сальто: монет", "Экономика", 0, 200, 1 },
	{ "TRICKS.frontflip.coins", "Переднее сальто: монет", "Экономика", 0, 200, 1 },
	{ "TRICKS.roll.coins", "Бочка: монет", "Экономика", 0, 200, 1 },
	{ "TRICKS.spin.coins", "Разворот 360: монет", "Экономика", 0, 200, 1 },
	{ "TRICKS.grab.coins", "Грэб: монет", "Экономика", 0, 100, 1 },
	{ "TRICK_COMBO_MULT.2", "Комбо трюков: × за 2-й", "Экономика", 1, 5, 0.1 },
	{ "TRICK_COMBO_MULT.3", "Комбо трюков: × за 3-й", "Экономика", 1, 10, 0.1 },
	{ "AIR_COINS_PER_SEC", "Полёт: монет в секунду", "Экономика", 0, 100, 1 },

	{ "MAGNET_CHANCE", "Магнит: шанс на кусок", "Бонусы", 0, 1, 0.01 },
	{ "MAGNET_TIME", "Магнит: длительность, с", "Бонусы", 1, 30, 1 },
	{ "MAGNET_RADIUS", "Магнит: радиус", "Бонусы", 5, 100, 1 },
	{ "BOOST_CHANCE", "Ускоритель: шанс в ряду", "Бонусы", 0, 1, 0.01 },
	{ "BOOST_ADD", "Ускоритель: + скорости", "Бонусы", 0, 80, 1 },
	{ "POWERUPS.shield.chance", "Щит: шанс", "Бонусы", 0, 1, 0.01 },
	{ "POWERUPS.x2.chance", "x2 монеты: шанс", "Бонусы", 0, 1, 0.01 },
	{ "POWERUPS.x2.time", "x2 монеты: длительность, с", "Бонусы", 1, 60, 1 },
	{ "POWERUPS.fuel.chance", "Канистра: шанс", "Бонусы", 0, 1, 0.01 },
	{ "POWERUPS.rings.chance", "Кольца: шанс", "Бонусы", 0, 1, 0.01 },
	{ "POWERUPS.rings.coins", "Кольца: монет за кольцо", "Бонусы", 0, 200, 1 },

	{ "TASKS_PER_DAY", "Заданий в день", "Награды", 1, 12, 1 },
	{ "TASK_CHEST_COINS", "Сундук заданий: монет", "Награды", 0, 10000, 50 },
	{ "TASK_CHEST_GEMS", "Сундук заданий: гемов", "Награды", 0, 200, 1 },
	{ "CHEST_COINS", "Сундук в лобби: монет", "Награды", 0, 10000, 25 },
	{ "CHEST_GEMS", "Сундук в лобби: гемов", "Награды", 0, 100, 1 },
	{ "PLAYTIME_GIFTS.5.min", "Большой подарок: минута", "Награды", 1, 60, 1 },
	{ "PLAYTIME_GIFTS.5.coins", "Большой подарок: монет", "Награды", 0, 10000, 50 },
	{ "PLAYTIME_GIFTS.5.gems", "Большой подарок: гемов", "Награды", 0, 100, 1 },
	{ "SESSION_GOAL_MIN", "Цель сессии, мин", "Награды", 1, 60, 1 },
	{ "STREAK_REWARDS.1.coins", "Стрик: день 1, монет", "Награды", 0, 10000, 25 },
	{ "STREAK_REWARDS.2.coins", "Стрик: день 2, монет", "Награды", 0, 10000, 25 },
	{ "STREAK_REWARDS.3.coins", "Стрик: день 3, монет", "Награды", 0, 10000, 25 },
	{ "STREAK_REWARDS.4.coins", "Стрик: день 4, монет", "Награды", 0, 10000, 25 },
	{ "STREAK_REWARDS.5.coins", "Стрик: день 5, монет", "Награды", 0, 10000, 25 },
	{ "STREAK_REWARDS.6.coins", "Стрик: день 6, монет", "Награды", 0, 10000, 25 },
	{ "STREAK_REWARDS.7.coins", "Стрик: день 7, монет", "Награды", 0, 10000, 25 },
	{ "STREAK_REWARDS.7.gems", "Стрик: день 7, гемов", "Награды", 0, 200, 1 },
	{ "STREAK_CYCLE_MULT", "Стрик: множитель монет со 2-й недели", "Награды", 1, 3, 0.05 },
	{ "STREAK_SAVE_GEMS", "Спасение стрика: гемов (день 1)", "Награды", 0, 200, 1 },
	{ "STREAK_SAVE_STEP", "Спасение стрика: +гемов за день", "Награды", 0, 50, 1 },

	{ "TUTORIAL.IDLE", "Обучение: бездействие до подсказки, с", "Обучение", 1, 30, 1 },
	{ "TUTORIAL.HOLD", "Обучение: подсказка висит, с", "Обучение", 2, 20, 0.5 },
	{ "TUTORIAL.GAP", "Обучение: пауза между подсказками, с", "Обучение", 0, 10, 0.5 },

	{ "OBSTACLE_ROWS", "Рядов препятствий на кусок", "Трасса", 0, 6, 1 },
	{ "SAFE_START", "Без препятствий первые, studs", "Трасса", 0, 1000, 10 },
	{ "COIN_LINE_CHANCE", "Шанс линии монет", "Трасса", 0, 1, 0.05 },
	{ "SAFE_LINE_REACTION", "Безопасная линия: реакция, с", "Трасса", 0, 1, 0.05 },
	{ "SAFE_LINE_MARGIN", "Безопасная линия: запас времени ×", "Трасса", 1, 3, 0.05 },
	{ "SAFE_LINE_MAX_SHIFT", "Безопасная линия: макс. сдвиг, полос", "Трасса", 0, 4, 1 },
	{ "CURVE_CHANCE", "Шанс поворота", "Трасса", 0, 1, 0.05 },
	{ "KICKER_CHANCE", "Шанс обрыва с трамплином", "Трасса", 0, 1, 0.01 },
	{ "GRAVITY_ALONG", "Гравитация вдоль склона", "Трасса", 10, 200, 1 },
	{ "STEER_SPEED", "Руль: боковая скорость", "Трасса", 10, 120, 1 },
	{ "STEER_REF_SPEED", "Руль: растёт со скорости выше", "Трасса", 30, 400, 5 },
	{ "STEER_RESPONSE", "Руль: отзывчивость", "Трасса", 2, 20, 0.5 },
	{ "OBSTACLE_SLOWDOWN", "Удар/падение: скорость ×", "Трасса", 0, 1, 0.05 },
	{ "JUMP_SPEED", "Прыжок: скорость вверх", "Трасса", 10, 80, 1 },
	{ "JUMP_COOLDOWN", "Прыжок: пауза, с", "Трасса", 0, 3, 0.1 },
	{ "FLIP_SPEED", "Трюки: скорость вращения, рад/с", "Трасса", 3, 20, 0.5 },
	{ "TRICKS.flip.boost", "Сальто: буст ×", "Трасса", 1, 1.5, 0.01 },
	{ "TRICKS.frontflip.boost", "Переднее сальто: буст ×", "Трасса", 1, 1.5, 0.01 },
	{ "TRICKS.roll.boost", "Бочка: буст ×", "Трасса", 1, 1.5, 0.01 },
	{ "TRICKS.spin.boost", "Разворот: буст ×", "Трасса", 1, 1.5, 0.01 },
	{ "TRICKS.grab.minAir", "Грэб: мин. время в воздухе, с", "Трасса", 0, 2, 0.1 },
	{ "AUTO_TRICKS", "Авто-трюки: 1 вкл / 0 выкл", "Трасса", 0, 1, 1 },
	{ "AUTO_TRICK_PLANS.1.air", "Авто-трюк: грэб/разворот от полёта, с", "Трасса", 0.2, 3, 0.05 },
	{ "AUTO_TRICK_PLANS.2.air", "Авто-трюк: сальто от полёта, с", "Трасса", 0.3, 4, 0.05 },
	{ "AUTO_TRICK_PLANS.3.air", "Авто-трюк: комбо из 2 от полёта, с", "Трасса", 0.5, 5, 0.05 },
	{ "AUTO_TRICK_PLANS.4.air", "Авто-трюк: комбо из 3 от полёта, с", "Трасса", 0.8, 6, 0.05 },
	{ "AUTO_TRICK_RANDOM", "Авто-трюк: доля случайного варианта", "Трасса", 0, 1, 0.05 },
	{ "AUTO_TRICK_MARGIN", "Авто-трюк: запас до касания, с", "Трасса", 0, 0.5, 0.01 },
	{ "AUTO_TRICK_MIN_SPEED", "Авто-трюк: мин. вращение, рад/с", "Трасса", 2, 20, 0.5 },
	{ "AUTO_TRICK_MAX_SPEED", "Авто-трюк: макс. вращение, рад/с", "Трасса", 6, 40, 0.5 },
	{ "AUTO_TRICK_SAFE_AIR", "Авто-трюк: доля полёта для лимита оборотов", "Античит", 0.3, 1, 0.05 },
	{ "WALL_HEIGHT", "Невидимый борт: высота", "Трасса", 0, 40, 1 },
	{ "WALL_TILT", "Невидимый борт: наклон наружу, °", "Трасса", 0, 45, 1 },
	{ "WALL_OFFSET", "Невидимый борт: отступ от края дна", "Трасса", 0, 20, 0.5 },
	{ "LOBBY_PREVIEW_SEGMENTS", "Лобби: кусков витринной трассы", "Трасса", 1, 10, 1 },
	{ "SMOOTH_KINK", "Гладкость: макс. излом на стыке, °", "Трасса", 0.5, 20, 0.5 },
	{ "STEP_UP_MAX", "Гладкость: подсадка на ступеньку, studs", "Трасса", 0, 4, 0.1 },
	{ "SLALOM_CHANCE", "Оформление: флажки-слалом", "Трасса", 0, 1, 0.05 },
	{ "ARCH_CHANCE", "Оформление: арка над трассой", "Трасса", 0, 1, 0.01 },
	{ "MESH_DECOR", "Меши декора: 1 — вкл, 0 — Part", "Графика", 0, 1, 1 },
	{ "DECOR_DRIFT_CHANCE", "Декор: сугробы у бортов (меши)", "Графика", 0, 2, 0.05 },
	{ "DECOR_MID_CHANCE", "Декор: скалы среднего плана (меши)", "Графика", 0, 2, 0.05 },
	{ "DECOR_FAR_CHANCE", "Декор: дальние горы (меши)", "Графика", 0, 2, 0.05 },
	{ "DECOR_WOW_CHANCE", "Декор: «вау»-объект (меши)", "Графика", 0, 1, 0.01 },
	{ "WAVE_CHANCE", "Волны-бугры: шанс серии", "Трасса", 0, 1, 0.01 },
	{ "WAVE_FROM_LEVEL", "Волны-бугры: с уровня", "Трасса", 1, 50, 1 },
	{ "ISLE_FROM_LEVEL", "Островки: с уровня", "Острова", 1, 50, 1 },
	{ "ISLE_AT", "Островки: обязательная цепочка на доле уровня", "Острова", 0.2, 0.9, 0.01 },
	{ "ISLE_CHANCE_BASE", "Островки: шанс доп. цепочки", "Острова", 0, 0.5, 0.005 },
	{ "ISLE_CHANCE_STEP", "Островки: + шанс за уровень", "Острова", 0, 0.05, 0.001 },
	{ "ISLE_CHANCE_MAX", "Островки: макс. шанс", "Острова", 0, 0.5, 0.005 },
	{ "ISLE_COUNT.1", "Островки: в цепочке от", "Острова", 1, 10, 1 },
	{ "ISLE_COUNT.2", "Островки: в цепочке до", "Острова", 1, 10, 1 },
	{ "ISLE_SPEED.1", "Островки: скорость вылета на 1-м уровне", "Острова", 40, 250, 5 },
	{ "ISLE_SPEED.2", "Островки: потолок скорости вылета", "Острова", 40, 250, 5 },
	{ "ISLE_SPEED_STEP", "Островки: + скорость за уровень", "Острова", 0, 20, 0.5 },
	{ "ISLE_SPEED_SPREAD", "Островки: окно скорости ×", "Острова", 1, 2, 0.05 },
	{ "ISLE_LIFT", "Островки: подброс ускорителя", "Острова", 0.1, 1, 0.05 },
	{ "ISLE_LAND_MARGIN", "Островки: запас долёта, studs", "Острова", 2, 60, 1 },
	{ "ISLE_GAP_MIN", "Островки: мин. зазор, studs", "Острова", 4, 100, 1 },
	{ "ISLE_BONUS_CHANCE", "Островки: шанс бонуса", "Острова", 0, 1, 0.05 },

	{ "AC_SPEED_MULT", "Предел скорости: × огибающей", "Античит", 1, 3, 0.05 },
	{ "AC_SPEED_ADD", "Предел скорости: + studs/с", "Античит", 0, 200, 5 },
	{ "AC_DECAY", "Спад огибающей: доля сопротивления", "Античит", 0, 1, 0.05 },
	{ "AC_LAG_SEC", "Флаг: отставание пути, с предела", "Античит", 0.5, 10, 0.1 },
	{ "AC_TELEPORT_STUDS", "Телепорт: сдвиг за тик, studs", "Античит", 50, 2000, 10 },
	{ "AC_TELEPORT_MULT", "Телепорт: × предела за тик", "Античит", 1, 10, 0.5 },
	{ "AC_DT_MAX", "Лаг: макс. пауза позиции, с", "Античит", 0.5, 10, 0.5 },
	{ "AC_AIR_HEIGHT", "Полёт: высота над трассой", "Античит", 1, 10, 0.5 },
	{ "AC_AIR_GRACE", "Полёт: запас к серверному, с", "Античит", 0, 2, 0.1 },
	{ "AC_MAX_AIR", "Полёт: флаг дольше, с", "Античит", 2, 30, 0.5 },
	{ "AC_NEAR_RADIUS", "Бонус/препятствие: радиус", "Античит", 10, 200, 5 },
	{ "AC_NEAR_LAG", "Радиус: + скорость × с", "Античит", 0, 1, 0.05 },
	{ "AC_FLAG_LIMIT", "Флагов до отмены заезда", "Античит", 1, 50, 1 },
	{ "AC_FLAG_COOLDOWN", "Флаг по позиции: не чаще, с", "Античит", 0.2, 10, 0.2 },
	{ "WEEKLY.MAX_FLAGS", "Неделя: флагов до исключения", "Лидерборд", 1, 50, 1 },
	{ "WEEKLY.MAX_AVG_SPEED", "Неделя: макс. средняя скорость", "Лидерборд", 100, 2000, 10 },
	{ "WEEKLY.WRITE_EVERY", "Неделя: запись игрока раз в, с", "Лидерборд", 10, 300, 5 },
	{ "WEEKLY.REFRESH", "Неделя: обновление табло, с", "Лидерборд", 30, 600, 10 },
	{ "WEEKLY.PAGE_SEC", "Табло: смена страницы, с", "Лидерборд", 3, 30, 1 },

	{ "GRAPHICS.BLOOM", "Bloom: × интенсивности", "Графика", 0, 2, 0.05 },
	{ "GRAPHICS.DOF", "Размытие дали: × силы", "Графика", 0, 3, 0.05 },
	{ "GRAPHICS.SATURATION", "Насыщенность: ×", "Графика", 0, 2, 0.05 },
	{ "GRAPHICS.SUNRAYS", "Солнечные лучи: ×", "Графика", 0, 3, 0.05 },
	{ "GRAPHICS.CONTRAST_MIN", "Контраст: не ниже", "Графика", 0, 0.5, 0.01 },
	{ "GRAPHICS.VIGNETTE_MAX", "Виньетка скорости: макс.", "Графика", 0, 0.9, 0.05 },
	{ "GRAPHICS.VIGNETTE_FROM", "Виньетка: со скорости", "Графика", 0, 300, 5 },
	{ "GRAPHICS.VIGNETTE_FULL", "Виньетка: полная на скорости", "Графика", 10, 400, 5 },
}
Config.TUNABLE_DEFAULTS = {} :: { [string]: number }

-- Значение по пути "A.B.C" (числовой сегмент — индекс массива: "TRICK_COMBO_MULT.2")
local function pathKey(part: string): any
	return tonumber(part) or part
end
function Config.getPath(path: string): any
	local t: any = Config
	for part in string.gmatch(path, "[^%.]+") do
		if type(t) ~= "table" then
			return nil
		end
		t = t[pathKey(part)]
	end
	return t
end
function Config.setPath(path: string, value: any)
	local parts = string.split(path, ".")
	local t: any = Config
	for i = 1, #parts - 1 do
		t = t[pathKey(parts[i])]
		if type(t) ~= "table" then
			return
		end
	end
	t[pathKey(parts[#parts])] = value
end
for _, tn in Config.TUNABLES do
	Config.TUNABLE_DEFAULTS[tn[1]] = Config.getPath(tn[1])
end
-- Применить словарь изменений { путь = число } (неизвестные пути и нечисла пропускаются)
function Config.applyOverrides(overrides: { [string]: any })
	for _, tn in Config.TUNABLES do
		local path = tn[1]
		local v = overrides[path]
		if typeof(v) == "number" then
			Config.setPath(path, math.clamp(v, tn[4], tn[5]))
		else
			Config.setPath(path, Config.TUNABLE_DEFAULTS[path])
		end
	end
end

return Config
