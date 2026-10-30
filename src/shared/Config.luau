-- Все настройки игры в одном месте. Меняй числа здесь — код трогать не нужно.
-- Баланс подобран симуляцией: уровень 1 без апгрейдов ≈ 40%, с ~6–8 покупками каждого ≈ финиш.

local Config = {}

------------------------------------------------------------------ МИР
Config.LOBBY_POS = Vector3.new(0, 3000, 400) -- лобби
Config.TRACKS_ORIGIN = Vector3.new(0, 3000, 0) -- старт трассы игрока в слоте 0
Config.SLOT_SPACING = 320 -- расстояние между трассами разных игроков (по X)

------------------------------------------------------------------ ТРАССА (жёлоб)
Config.TRACK_WIDTH = 36 -- ширина дна жёлоба
Config.WALL_WIDTH = 14 -- ширина наклонных бортов
Config.WALL_ANGLE = 40 -- наклон бортов (градусы)
Config.LANES = 4 -- полосы для препятствий; в ряду всегда свободно минимум 2
Config.SEGMENTS_AHEAD = 7
Config.SEGMENTS_BEHIND = 2

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
Config.OBSTACLE_ROWS = 3 -- рядов на сегмент
Config.BOOST_CHANCE = 0.1 -- ускоритель в ряду (≈ 1 на 3 сегмента)
Config.FORCED_KICKERS = { 0.35, 0.7 } -- обязательные обрывы на этих долях уровня
Config.COIN_LINE_CHANCE = 0.5
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
Config.STEER_SPEED = 32
Config.OBSTACLE_SLOWDOWN = 0.6 -- скорость × это при ударе
Config.BOOST_ADD = 18 -- ускоритель на льду
Config.RAMP_MIN_SPEED = 30 -- на трамплине не медленнее этого (не застрянешь)
Config.RAMP_LIFT = 0.45 -- подброс с трамплина (доля скорости вверх)
Config.ROCKET_THRUST = 40
Config.FLIP_SPEED = 9 -- рад/с
Config.FLIP_BOOST = 1.12 -- × скорость за чистый флип

------------------------------------------------------------------ АПГРЕЙДЫ
Config.UPGRADES = {
	Launch = { title = "Рогатка", BaseCost = 25, Growth = 1.22, MaxLevel = 40 },
	Rocket = { title = "Ракета", BaseCost = 30, Growth = 1.22, MaxLevel = 40 },
	Sled = { title = "Санки", BaseCost = 35, Growth = 1.22, MaxLevel = 40 },
}
Config.UPGRADE_ORDER = { "Launch", "Rocket", "Sled" }

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
function Config.upgradeCost(name: string, level: number): number
	local u = Config.UPGRADES[name]
	return math.floor(u.BaseCost * u.Growth ^ level)
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
