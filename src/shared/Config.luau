-- Все настройки игры в одном месте. Меняй числа здесь — код трогать не нужно.

local Config = {}

-- ТРАССА
Config.SLOPE_DEG = 18 -- уклон склона в градусах
Config.START_POS = Vector3.new(0, 2000, 0) -- верхняя точка трассы (лобби рядом)
Config.SEGMENT_LENGTH = 120 -- длина одного куска трассы
Config.TRACK_WIDTH = 60
Config.SEGMENTS_AHEAD = 8 -- сколько сегментов строить впереди самого быстрого игрока
Config.SEGMENTS_BEHIND = 3 -- сколько оставлять позади самого медленного
Config.SAFE_SEGMENTS = 2 -- первые сегменты без препятствий
Config.RAMP_CHANCE = 0.5 -- шанс трамплина на сегменте
Config.LANES = 5 -- трасса делится на полосы; в ряду всегда свободно минимум 2
Config.ROWS_PER_SEGMENT = 4 -- рядов препятствий на сегмент
Config.SEGMENTS_PER_DIFFICULTY = 5 -- каждые N сегментов в ряду может быть на 1 препятствие больше
Config.COIN_LINE_CHANCE = 0.6 -- шанс линии монет в ряду
Config.COINS_PER_LINE = 4

-- САНКИ
Config.BASE_SPEED = 70 -- макс. скорость без апгрейдов (studs/с)
Config.SPEED_PER_LEVEL = 6
Config.ACCELERATION = 25
Config.BASE_STEER = 28 -- боковая скорость
Config.STEER_PER_LEVEL = 3
Config.FLIP_SPEED = 9 -- скорость вращения во флипе (рад/с)
Config.FLIP_BOOST = 1.3 -- множитель скорости после чистого флипа
Config.FLIP_BOOST_TIME = 1.5 -- секунд

-- ЭКОНОМИКА
Config.STUDS_PER_COIN = 10 -- 1 монета за каждые N studs
Config.COINS_PER_FLIP = 25
Config.COIN_PICKUP_VALUE = 3 -- за одну монетку на трассе
Config.UPGRADES = {
	Speed = { BaseCost = 50, Growth = 1.6, MaxLevel = 30 },
	Control = { BaseCost = 40, Growth = 1.55, MaxLevel = 20 },
}
-- ID геймпасса «x2 монеты» из Creator Hub. 0 = выключено.
Config.GAMEPASS_X2_COINS = 0

function Config.trackOrigin(): CFrame
	-- Поворот вокруг X на -уклон: «вперёд» (-Z) смотрит вниз по склону
	return CFrame.new(Config.START_POS) * CFrame.Angles(math.rad(-Config.SLOPE_DEG), 0, 0)
end

function Config.upgradeCost(name: string, level: number): number
	local u = Config.UPGRADES[name]
	return math.floor(u.BaseCost * u.Growth ^ level)
end

function Config.maxSpeed(level: number): number
	return Config.BASE_SPEED + level * Config.SPEED_PER_LEVEL
end

function Config.steerSpeed(level: number): number
	return Config.BASE_STEER + level * Config.STEER_PER_LEVEL
end

return Config
