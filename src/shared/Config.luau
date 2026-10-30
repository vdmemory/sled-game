-- Все настройки игры в одном месте. Меняй числа здесь — код трогать не нужно.
-- Баланс подобран симуляцией: уровень 1 без апгрейдов ≈ 40%, с ~6–8 покупками каждого ≈ финиш.

local Config = {}

------------------------------------------------------------------ МИР
Config.LOBBY_POS = Vector3.new(0, 3000, 400) -- лобби
Config.TRACKS_ORIGIN = Vector3.new(0, 3000, 0) -- старт трассы игрока в слоте 0
Config.SLOT_SPACING = 480 -- расстояние между трассами разных игроков (по X)

------------------------------------------------------------------ ТРАССА (жёлоб)
Config.TRACK_WIDTH = 64 -- ширина дна жёлоба (широкая ледяная «улица», как в оригинале)
Config.WALL_WIDTH = 18 -- ширина наклонных бортов
Config.WALL_ANGLE = 35 -- наклон бортов (градусы)
Config.LANES = 6 -- полосы для препятствий; в ряду всегда свободно минимум 2
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
Config.STEER_SPEED = 40 -- максимальная боковая скорость
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
