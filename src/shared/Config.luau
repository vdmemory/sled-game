-- Все настройки игры в одном месте. Меняй числа здесь — код трогать не нужно.
-- Баланс подобран симуляцией: уровень 1 без апгрейдов ≈ 40%, с ~6–8 покупками каждого ≈ финиш.

local Config = {}

------------------------------------------------------------------ МИР
Config.LOBBY_POS = Vector3.new(0, 3000, 400) -- лобби
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
}

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
	Sled = { "Обычные санки", "Боковые ускорители", "Аэро-хвост", "Обтекатель", "Золотая отделка", "Неоновые санки" },
	Income = { "Копилка", "Мешок монет", "Сундук", "Сейф", "Банк", "Золотой банк" },
	Rocket = { "Петарда", "Ракета", "Турбо-ракета", "Мега-двигатель", "Бласт-двигатель", "Гиперджет" },
}
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

------------------------------------------------------------------ СКИНЫ ВАТРУШЕК (за монеты)
-- tube — основной цвет, rim — бортик, neon — светится
Config.SKINS = {
	{ id = "classic", name = "Классика", price = 0, tube = Color3.fromRGB(240, 70, 120), rim = Color3.fromRGB(255, 130, 170) },
	{ id = "ice", name = "Льдинка", price = 150, tube = Color3.fromRGB(90, 170, 240), rim = Color3.fromRGB(200, 235, 255) },
	{ id = "lime", name = "Лайм", price = 300, tube = Color3.fromRGB(120, 210, 60), rim = Color3.fromRGB(230, 255, 120) },
	{ id = "melon", name = "Арбуз", price = 600, tube = Color3.fromRGB(235, 60, 70), rim = Color3.fromRGB(50, 150, 60) },
	{ id = "night", name = "Ночь", price = 900, tube = Color3.fromRGB(35, 40, 70), rim = Color3.fromRGB(120, 140, 255), neon = true },
	{ id = "lava", name = "Лава", price = 1500, tube = Color3.fromRGB(60, 20, 15), rim = Color3.fromRGB(255, 110, 20), neon = true },
	{ id = "gold", name = "Золото", price = 3000, tube = Color3.fromRGB(240, 190, 50), rim = Color3.fromRGB(255, 240, 150), metal = true },
	{ id = "galaxy", name = "Галактика", price = 6000, tube = Color3.fromRGB(80, 30, 140), rim = Color3.fromRGB(255, 120, 255), neon = true },
}
function Config.skin(id: string?)
	for _, s in Config.SKINS do
		if s.id == id then
			return s
		end
	end
	return Config.SKINS[1]
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
