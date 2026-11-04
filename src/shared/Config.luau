-- Все настройки игры в одном месте. Меняй числа здесь — код трогать не нужно.
-- Баланс подобран симуляцией: уровень 1 без апгрейдов ≈ 40%, с ~6–8 покупками каждого ≈ финиш.

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
	return math.floor(base * (1 + (level - 1) * 0.25))
end
-- Ежедневные задания: 3 в день из пула (выбор детерминирован по номеру дня)
Config.TASK_POOL = {
	{ id = "runs", text = "Сделай %d заездов", targets = { 5, 8 }, gems = 3 },
	{ id = "coins", text = "Собери %d монет", targets = { 300, 800 }, gems = 4 },
	{ id = "distance", text = "Проедь %d м всего", targets = { 3000, 8000 }, gems = 4 },
	{ id = "air", text = "Пробудь в воздухе %d с", targets = { 15, 40 }, gems = 5 },
	{ id = "flips", text = "Сделай %d флипов", targets = { 3, 8 }, gems = 5 },
	{ id = "smash", text = "Разбей %d препятствий", targets = { 5, 15 }, gems = 4 },
	{ id = "best", text = "Побей свой рекорд %d раз", targets = { 1, 2 }, gems = 5 },
}
Config.TASKS_PER_DAY = 3
Config.TASK_CHEST_COINS = 300 -- сундук за все задания (× rewardCoins) + гемы
Config.TASK_CHEST_GEMS = 8
-- Подарки за время в игре (минуты с захода), как сетка «Подарки» в референсе
Config.PLAYTIME_GIFTS = {
	{ min = 1, coins = 60 },
	{ min = 3, gems = 2 },
	{ min = 5, coins = 125 },
	{ min = 8, gems = 3 },
	{ min = 12, coins = 200 },
	{ min = 16, coins = 250, gems = 2 },
	{ min = 20, coins = 300 },
	{ min = 25, gems = 5 },
	{ min = 30, coins = 450 },
	{ min = 40, gems = 6 },
	{ min = 50, coins = 700 },
	{ min = 60, coins = 1000, gems = 10 },
}
-- Сундук в лобби раз в 4 часа
Config.CHEST_INTERVAL = 4 * 3600
Config.CHEST_COINS = 250
Config.CHEST_GEMS = 3

------------------------------------------------------------------ ФИЗИКА САНОК
Config.GRAVITY_ALONG = 60 -- «игровая» гравитация вдоль склона
Config.DRAG = 0.0012 -- сопротивление воздуха (× v²)
Config.STOP_SPEED = 3 -- ниже этой скорости...
Config.STOP_TIME = 1.5 -- ...столько секунд = остановился
Config.STEER_SPEED = 45 -- максимальная боковая скорость
Config.STEER_RESPONSE = 6 -- как быстро боковая скорость догоняет руль (инерция)
Config.WALL_PULL = 140 -- борта жёлоба скатывают обратно к центру
Config.STEER_TILT = 18 -- наклон ватрушки в повороте (градусы)
Config.OBSTACLE_SLOWDOWN = 0.6 -- скорость × это при ударе
Config.BOOST_ADD = 18 -- ускоритель на льду
Config.RAMP_MIN_SPEED = 30 -- на трамплине не медленнее этого (не застрянешь)
Config.RAMP_LIFT = 0.45 -- подброс с трамплина (доля скорости вверх)
Config.ROCKET_THRUST = 40
Config.FLIP_SPEED = 9 -- рад/с
Config.FLIP_BOOST = 1.12 -- × скорость за чистый флип

------------------------------------------------------------------ АПГРЕЙДЫ
-- 4 апгрейда как в оригинале. Ракета качается за гемы, остальные — за монеты.
-- Каждые TIER_SIZE уровней — новый «тир»: меняется вид рогатки/санок, а переход на него стоит гемы.
Config.TIER_SIZE = 5
Config.UPGRADES = {
	Launch = { title = "Рогатка", icon = "🎯", color = Color3.fromRGB(225, 80, 70), BaseCost = 25, Growth = 1.18, MaxLevel = 50 },
	Sled = { title = "Сани", icon = "🛷", color = Color3.fromRGB(60, 130, 230), BaseCost = 35, Growth = 1.18, MaxLevel = 50 },
	Income = { title = "Доход", icon = "💰", color = Color3.fromRGB(235, 165, 35), BaseCost = 60, Growth = 1.2, MaxLevel = 50 },
	Rocket = { title = "Ракета", icon = "🚀", color = Color3.fromRGB(240, 115, 45), MaxLevel = 30, gems = true },
}
Config.UPGRADE_ORDER = { "Launch", "Sled", "Income", "Rocket" }

-- Названия тиров (показываются при получении: «ПОЛУЧЕНА СТАЛЬНАЯ РОГАТКА!»)
Config.TIERS = {
	Launch = { "Деревянная рогатка", "Стальная рогатка", "Мега-рогатка", "Силовая рогатка", "Золотая рогатка", "Неоновая рогатка" },
	Sled = { "Обычные санки", "Фары", "Спойлер", "Обтекатель", "Золотая отделка", "Неоновые санки" },
	Income = { "Копилка", "Мешок монет", "Сундук", "Сейф", "Банк", "Золотой банк" },
	Rocket = { "Петарда", "Ракета", "Турбо-ракета", "Мега-двигатель", "Бласт-двигатель", "Гиперджет" },
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

function Config.launchSpeed(level: number): number
	return 48 + 6 * level
end
function Config.rocketFuel(level: number): number
	return 0.6 + 0.3 * level -- секунд
end
function Config.friction(level: number): number
	return 9.5 * 0.965 ^ level
end
function Config.maxSpeed(level: number): number
	return 100 + 5 * level
end
function Config.incomeMult(level: number): number
	return 1 + 0.15 * level
end

-- Цена следующего уровня: (сколько, валюта "Coins" | "Gems")
function Config.upgradePrice(name: string, level: number): (number, string)
	local u = Config.UPGRADES[name]
	if u.gems then
		return 1 + level // 3, "Gems"
	end
	if level > 0 and level % Config.TIER_SIZE == 0 then
		return 1 + level // (Config.TIER_SIZE * 2), "Gems" -- переход на новый тир
	end
	return math.floor(u.BaseCost * u.Growth ^ level), "Coins"
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
Config.COINS_PER_FLIP = 15
function Config.finishBonus(level: number): number
	return 100 * level
end
Config.GAMEPASS_X2_COINS = 0 -- ID геймпасса «x2 монеты» (0 = выкл)

return Config
