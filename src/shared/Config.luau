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

-- Повороты: ледяной жёлоб, который петляет (как в трейлере оригинала)
Config.CURVE_CHANCE = 0.3 -- шанс поворота вместо прямого участка
Config.CURVE_ANGLE = { 30, 55 } -- градусов на один поворот
Config.CURVE_STEP = 5 -- градусов на один кусок поворота
Config.CURVE_PIECE = 14 -- длина куска поворота (studs)
Config.CURVE_PITCH = { 8, 12 } -- уклон в поворотах
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
	{ min = 8, gems = 3 },
	{ min = 12, coins = 120 },
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

------------------------------------------------------------------ НАСТРОЙКА В ИГРЕ
-- Параметры, которые владелец меняет в панели разработчика (вкладка «Настройка»).
-- Изменения хранятся в DataStore и применяются на всех серверах без перевыпуска игры.
-- { путь в Config, подпись, группа, мин, макс, шаг }
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

	{ "OBSTACLE_ROWS", "Рядов препятствий на кусок", "Трасса", 0, 6, 1 },
	{ "SAFE_START", "Без препятствий первые, studs", "Трасса", 0, 1000, 10 },
	{ "COIN_LINE_CHANCE", "Шанс линии монет", "Трасса", 0, 1, 0.05 },
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
	{ "WALL_HEIGHT", "Невидимый борт: высота", "Трасса", 0, 40, 1 },
	{ "WALL_TILT", "Невидимый борт: наклон наружу, °", "Трасса", 0, 45, 1 },
	{ "WALL_OFFSET", "Невидимый борт: отступ от края дна", "Трасса", 0, 20, 0.5 },
	{ "LOBBY_PREVIEW_SEGMENTS", "Лобби: кусков витринной трассы", "Трасса", 1, 10, 1 },
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
