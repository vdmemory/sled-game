-- Транспорт: машины, фургоны, джип, живой трафик дорог (автобус, такси, полиция, поезд),
-- канатная дорога, знаки и шлагбаум у дороги. Часть shared/Props (см. Props/init).
--
-- Стиль трафика — «мягкий пластилин» по референсам владельца (#68, docs/ART_REFERENCES.md):
-- скруглённые кузова (Base.softBox: низ + верх + цилиндры-скругления), крупные светло-голубые
-- окна, чёрная решётка, круглые фары, колёса с белым колпаком. Коллизию по-прежнему несут прежние
-- Part (те же размеры и места, теперь невидимые: Transparency = 1), весь вид — deco без коллизии
-- и без запросов (CanQuery/CanTouch = false), поэтому столкновения и «шапка» легковушки прежние.
-- Порядок и число вызовов rng в каждой функции — как до #68 (rng участка общий с раскладкой).

local Config = require(script.Parent.Parent.Config)
local Base = require(script.Parent.Base)

local Props = Base.Props
local part, deco, pick, label, wheels = Base.part, Base.deco, Base.pick, Base.label, Base.wheels
local softBox, pill, lamp, snowCap = Base.softBox, Base.pill, Base.lamp, Base.snowCap
local BLACK, GLASS, WINDOW = Base.BLACK, Base.GLASS, Base.WINDOW

local HEAD = Color3.fromRGB(255, 245, 200) -- фары
local TAIL = Color3.fromRGB(255, 70, 60) -- стопы
local BUMPER = Color3.fromRGB(95, 100, 112)
local WHITE = Color3.fromRGB(245, 245, 248)

-- Невидимая часть коллизии: прежний размер и место, вид рисует декор
local function hitbox(size: Vector3, cf: CFrame, parent: Instance, name: string?): BasePart
	return part("Part", { Name = name, Size = size, CFrame = cf, Transparency = 1, CastShadow = false }, parent)
end

------------------------------------------------------------------ транспорт
-- Цвет и силуэт легковушки: хэтчбек (кабина до кормы) или седан (кабина посередине, багажник).
-- 6 записей, как прежний список цветов (pick — один вызов rng).
local CAR_STYLES = {
	{ color = Color3.fromRGB(55, 120, 215), hatch = true }, -- синий хэтчбек (референс)
	{ color = Color3.fromRGB(250, 200, 45), hatch = false }, -- жёлтый седан (референс)
	{ color = Color3.fromRGB(220, 60, 55), hatch = true },
	{ color = Color3.fromRGB(240, 240, 245), hatch = false },
	{ color = Color3.fromRGB(95, 180, 105), hatch = true },
	{ color = Color3.fromRGB(245, 140, 50), hatch = false },
}

-- Легковушка. base — точка на земле, «нос» машины смотрит по -Z base.
-- Габарит 6.2 × 5.4 × 12 (колёса r 1.2 на z ±3.8), ~31 часть: коллизия 7 (кузов, кабина, 4 шины,
-- «шапка»), кузов softBox r 0.8, кабина softBox r 0.9–1.0, окна лентой насквозь (видны с обеих
-- сторон одной частью), решётка, круглые фары/стопы, бамперы-цилиндры, снежная подушка.
-- color задан (такси, полиция) — всегда седан.
function Props.car(rng: Random, base: CFrame, parent: Instance, color: Color3?)
	local style = if color then { color = color, hatch = false } else pick(rng, CAR_STYLES)
	local c = style.color
	hitbox(Vector3.new(6.2, 2.2, 12), base * CFrame.new(0, 2.1, 0), parent)
	hitbox(Vector3.new(5.8, 2.2, 6.4), base * CFrame.new(0, 4.3, 0.6), parent)
	softBox(base * CFrame.new(0, 2.1, 0), Vector3.new(6.2, 2.2, 12), 0.8, c, parent, { shadow = true })
	-- кабина: седан — над серединой (z −2.6…3.8), хэтчбек — до кормы (z −2.2…6)
	local cz, cl = 0.6, 6.4
	if style.hatch then
		cz, cl = 1.9, 8.2
	end
	softBox(base * CFrame.new(0, 4.3, cz), Vector3.new(5.8, 2.2, cl), if style.hatch then 1 else 0.9, c, parent, { shadow = true })
	deco({ Size = Vector3.new(5.9, 1.1, cl - 1.4), CFrame = base * CFrame.new(0, 4.2, cz), Color = WINDOW, Reflectance = 0.15 }, parent) -- боковые окна
	deco({ Size = Vector3.new(5.95, 1.1, 0.3), CFrame = base * CFrame.new(0, 4.2, cz + 0.3), Color = c }, parent) -- средняя стойка
	deco({ Size = Vector3.new(5, 1.1, 0.15), CFrame = base * CFrame.new(0, 4.1, cz - cl / 2 - 0.05), Color = WINDOW, Reflectance = 0.15 }, parent) -- лобовое
	deco({ Size = Vector3.new(4.6, 1, 0.15), CFrame = base * CFrame.new(0, 4.1, cz + cl / 2 + 0.05), Color = WINDOW, Reflectance = 0.15 }, parent) -- заднее
	deco({ Size = Vector3.new(3.4, 0.7, 0.15), CFrame = base * CFrame.new(0, 1.9, -6.05), Color = BLACK }, parent) -- решётка
	for _, side in { -1, 1 } do
		lamp(base * CFrame.new(side * 2.2, 2, -6.05), 0.9, HEAD, parent, true)
		lamp(base * CFrame.new(side * 2.3, 2.1, 6.05), 0.7, TAIL, parent, true)
	end
	for _, z in { -6, 6 } do -- бамперы
		deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(5.6, 0.6, 0.6), CFrame = base * CFrame.new(0, 1.2, z), Color = BUMPER }, parent)
	end
	snowCap(base * CFrame.new(0, 5.4, cz), Vector3.new(5.2, 0.6, cl - 1.6), parent)
	wheels(base, 3.05, { -3.8, 3.8 }, 1.2, parent)
	-- Невидимая «шапка» до CAR_HITBOX_H: прыжок (≈ 6.4 studs) выше крыши (5.4), но легковушку
	-- по-прежнему не перепрыгнуть — её видят Touched и GetPartBoundsInBox санок, не физика
	local capTop = math.max(5.4, Config.CAR_HITBOX_H)
	part("Part", {
		Name = "Hitbox",
		Size = Vector3.new(6.2, capTop - 3.2, 12),
		CFrame = base * CFrame.new(0, (capTop + 3.2) / 2, 0),
		Transparency = 1,
		CanCollide = false,
		CastShadow = false,
	}, parent)
end

-- Фургон / скорая. Референс — зелёный фургон с багажником на крыше и полосами по борту.
-- Габарит 6.6 × 7.6 × 13.85 (кабина z −7.3…−2.9, кузов z −2.95…6.55), ~34 части: коллизия 6
-- (кузов, кабина, 4 шины), кузов softBox r 1.2, кабина softBox r 1 (скруглён только нос),
-- окна (лобовое, кабина и кузов лентой насквозь, заднее), 2 белые полосы через оба блока,
-- багажник-«пилюля» со снегом; у скорой вместо багажника — красная полоса, крест и мигалка.
function Props.van(rng: Random, base: CFrame, parent: Instance, ambulance: boolean?)
	local c = if ambulance then WHITE else pick(rng, { Color3.fromRGB(90, 175, 95), Color3.fromRGB(60, 150, 120), Color3.fromRGB(70, 130, 210) })
	hitbox(Vector3.new(6.6, 6.4, 9.5), base * CFrame.new(0, 4.4, 1.8), parent) -- кузов
	hitbox(Vector3.new(6.4, 4.4, 4.4), base * CFrame.new(0, 3.4, -5.1), parent) -- кабина
	softBox(base * CFrame.new(0, 4.4, 1.8), Vector3.new(6.6, 6.4, 9.5), 1.2, c, parent, { shadow = true })
	softBox(base * CFrame.new(0, 3.4, -5.1), Vector3.new(6.4, 4.4, 4.4), 1, c, parent, { back = false, shadow = true })
	deco({ Size = Vector3.new(5.4, 1.8, 0.15), CFrame = base * CFrame.new(0, 4.2, -7.33), Color = WINDOW, Reflectance = 0.15 }, parent) -- лобовое
	deco({ Size = Vector3.new(6.5, 1.6, 2.6), CFrame = base * CFrame.new(0, 4.2, -5), Color = WINDOW, Reflectance = 0.15 }, parent) -- окна кабины
	deco({ Size = Vector3.new(6.7, 1.6, 4.6), CFrame = base * CFrame.new(0, 5.6, -0.2), Color = WINDOW, Reflectance = 0.15 }, parent) -- окна салона
	deco({ Size = Vector3.new(5, 1.6, 0.15), CFrame = base * CFrame.new(0, 5.6, 6.6), Color = WINDOW, Reflectance = 0.15 }, parent) -- заднее
	if ambulance then
		local red = Color3.fromRGB(220, 40, 40)
		deco({ Size = Vector3.new(6.7, 0.9, 13.8), CFrame = base * CFrame.new(0, 3, -0.4), Color = red }, parent) -- полоса
		deco({ Size = Vector3.new(6.7, 2.2, 0.7), CFrame = base * CFrame.new(0, 5.4, 4.2), Color = red }, parent) -- крест
		deco({ Size = Vector3.new(6.7, 0.7, 2.2), CFrame = base * CFrame.new(0, 5.4, 4.2), Color = red }, parent)
		pill(base * CFrame.new(0, 7.85, -1.2), Vector3.new(2.4, 0.6, 1.2), Color3.fromRGB(255, 50, 50), parent, Enum.Material.Neon) -- мигалка
		snowCap(base * CFrame.new(0, 7.6, 2.4), Vector3.new(5.6, 0.6, 6.6), parent)
	else
		for _, y in { 2.8, 3.6 } do -- полосы по борту (насквозь: видны с обеих сторон)
			deco({ Size = Vector3.new(6.7, 0.4, 13.8), CFrame = base * CFrame.new(0, y, -0.4), Color = WHITE }, parent)
		end
		pill(base * CFrame.new(0, 8.1, 1.8), Vector3.new(4.6, 1, 5.6), Color3.fromRGB(60, 65, 78), parent) -- багажник
		snowCap(base * CFrame.new(0, 8.6, 1.8), Vector3.new(4, 0.5, 4.8), parent)
	end
	deco({ Size = Vector3.new(3.4, 0.8, 0.15), CFrame = base * CFrame.new(0, 2.2, -7.35), Color = BLACK }, parent) -- решётка
	for _, side in { -1, 1 } do
		lamp(base * CFrame.new(side * 2.4, 2.4, -7.35), 1, HEAD, parent, true)
		lamp(base * CFrame.new(side * 2.6, 3, 6.6), 0.8, TAIL, parent, true)
	end
	deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(6, 0.7, 0.7), CFrame = base * CFrame.new(0, 1.4, -7.3), Color = BUMPER }, parent)
	wheels(base, 3.25, { -4.8, 4 }, 1.4, parent)
end

-- Джип для каньона: высокий мягкий кузов, багажник, запаска сзади. ~27 частей, коллизия 6.
function Props.jeep(rng: Random, base: CFrame, parent: Instance)
	local c = pick(rng, { Color3.fromRGB(205, 175, 95), Color3.fromRGB(115, 130, 85), Color3.fromRGB(200, 80, 55) })
	hitbox(Vector3.new(6.6, 3, 11), base * CFrame.new(0, 2.8, 0), parent)
	hitbox(Vector3.new(6.4, 2.6, 6.5), base * CFrame.new(0, 5.6, 1), parent)
	softBox(base * CFrame.new(0, 2.8, 0), Vector3.new(6.6, 3, 11), 0.8, c, parent, { shadow = true })
	softBox(base * CFrame.new(0, 5.6, 1), Vector3.new(6.4, 2.6, 6.5), 0.7, c, parent, { shadow = true })
	deco({ Size = Vector3.new(6.5, 1.3, 5), CFrame = base * CFrame.new(0, 5.5, 1), Color = WINDOW, Reflectance = 0.15 }, parent)
	deco({ Size = Vector3.new(5.4, 1.3, 0.15), CFrame = base * CFrame.new(0, 5.5, -2.3), Color = WINDOW, Reflectance = 0.15 }, parent)
	deco({ Size = Vector3.new(5, 0.4, 5.5), CFrame = base * CFrame.new(0, 7.1, 1), Color = BLACK }, parent) -- багажник
	deco({ Size = Vector3.new(3.6, 1, 0.15), CFrame = base * CFrame.new(0, 3, -5.55), Color = BLACK }, parent) -- решётка
	for _, side in { -1, 1 } do
		lamp(base * CFrame.new(side * 2.5, 3.2, -5.55), 1, HEAD, parent, true)
	end
	deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(6.2, 0.7, 0.7), CFrame = base * CFrame.new(0, 1.6, -5.5), Color = BUMPER }, parent)
	deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.9, 2.6, 2.6), CFrame = base * CFrame.new(0, 3.2, 5.95) * CFrame.Angles(0, math.rad(90), 0), Color = BLACK }, parent) -- запаска
	deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 1.4, 1.4), CFrame = base * CFrame.new(0, 3.2, 5.95) * CFrame.Angles(0, math.rad(90), 0), Color = WHITE }, parent)
	wheels(base, 3.3, { -3.6, 3.6 }, 1.5, parent)
end

------------------------------------------------------------------ живой трафик (двигает клиент, см. Traffic.client)
-- Все модели ниже строятся вокруг base (точка на земле, «нос» по -Z) и получают WorldPivot = base.
local function vehicleModel(name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	return m
end

-- Автобус: длинный мягкий кузов, лента окон, белая юбка, снег на крыше. ~21 часть, коллизия 5.
function Props.bus(rng: Random, base: CFrame, parent: Instance)
	local c = pick(rng, { Color3.fromRGB(235, 70, 60), Color3.fromRGB(245, 190, 45), Color3.fromRGB(60, 130, 210) })
	hitbox(Vector3.new(7.4, 7, 26), base * CFrame.new(0, 4.6, 0), parent)
	softBox(base * CFrame.new(0, 4.6, 0), Vector3.new(7.4, 7, 26), 1.6, c, parent, { shadow = true })
	deco({ Size = Vector3.new(7.5, 2.2, 21), CFrame = base * CFrame.new(0, 5.6, 0.8), Color = WINDOW, Reflectance = 0.15 }, parent)
	deco({ Size = Vector3.new(6.4, 2.4, 0.15), CFrame = base * CFrame.new(0, 5.2, -13.05), Color = WINDOW, Reflectance = 0.15 }, parent)
	deco({ Size = Vector3.new(5.6, 1.6, 0.15), CFrame = base * CFrame.new(0, 5.6, 13.05), Color = WINDOW, Reflectance = 0.15 }, parent)
	deco({ Size = Vector3.new(7.5, 0.7, 26.1), CFrame = base * CFrame.new(0, 2.6, 0), Color = WHITE }, parent)
	deco({ Size = Vector3.new(4, 0.7, 0.15), CFrame = base * CFrame.new(0, 2.4, -13.1), Color = BLACK }, parent)
	for _, side in { -1, 1 } do
		lamp(base * CFrame.new(side * 2.8, 2.4, -13.1), 1, HEAD, parent, true)
	end
	snowCap(base * CFrame.new(0, 8.1, 0), Vector3.new(6.6, 0.8, 22), parent)
	wheels(base, 3.55, { -9, 8 }, 1.6, parent)
end

function Props.taxi(rng: Random, base: CFrame, parent: Instance)
	Props.car(rng, base, parent, Color3.fromRGB(250, 200, 40))
	local sign = deco({ Size = Vector3.new(2.4, 0.9, 1), CFrame = base * CFrame.new(0, 6, 0.6), Color = Color3.fromRGB(30, 30, 35) }, parent)
	label(sign, Enum.NormalId.Front, "TAXI", Color3.fromRGB(255, 220, 60))
	label(sign, Enum.NormalId.Back, "TAXI", Color3.fromRGB(255, 220, 60))
	-- шашечки: белая полоса и чёрные клетки насквозь кузова — видны с обеих сторон
	deco({ Size = Vector3.new(6.25, 0.6, 5), CFrame = base * CFrame.new(0, 2.3, 0), Color = Color3.new(1, 1, 1) }, parent)
	for _, z in { -2, 0, 2 } do
		deco({ Size = Vector3.new(6.3, 0.6, 1), CFrame = base * CFrame.new(0, 2.3, z), Color = BLACK }, parent)
	end
end

function Props.police(rng: Random, base: CFrame, parent: Instance)
	Props.car(rng, base, parent, Color3.fromRGB(240, 242, 248))
	deco({ Size = Vector3.new(6.25, 0.9, 8), CFrame = base * CFrame.new(0, 2, 0), Color = Color3.fromRGB(40, 70, 170) }, parent) -- полоса насквозь
	deco({ Size = Vector3.new(1.4, 0.6, 1), CFrame = base * CFrame.new(-0.75, 5.85, 0.6), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 50, 50) }, parent)
	deco({ Size = Vector3.new(1.4, 0.6, 1), CFrame = base * CFrame.new(0.75, 5.85, 0.6), Material = Enum.Material.Neon, Color = Color3.fromRGB(60, 110, 255) }, parent)
end

-- Случайная машина для дороги (с весами под мир)
function Props.traffic(theme: number, rng: Random, base: CFrame, parent: Instance): Model
	local m = vehicleModel("Vehicle")
	local r = rng:NextNumber()
	if theme == 3 then
		if r < 0.35 then Props.jeep(rng, base, m)
		elseif r < 0.6 then Props.truck(rng, base, m)
		elseif r < 0.8 then Props.bus(rng, base, m)
		else Props.car(rng, base, m) end
	else
		if r < 0.28 then Props.car(rng, base, m)
		elseif r < 0.44 then Props.taxi(rng, base, m)
		elseif r < 0.56 then Props.police(rng, base, m)
		elseif r < 0.68 then Props.van(rng, base, m, true)
		elseif r < 0.84 then Props.truck(rng, base, m)
		else Props.bus(rng, base, m) end
	end
	m.WorldPivot = base
	m.Parent = parent
	return m
end

-- Поезд: локомотив + 3 вагона, тянется по +Z от base (едет носом по -Z).
-- Коллизия — прежние 5 Part (локомотив 8 × 9 × 20, низкий нос 7 × 4 × 6 на z −12, вагоны 8 × 8 × 20
-- на z 24/46/68), невидимые; вид — один из двух составов из референсов (#68):
--   скоростной — белый с красным низом, округлый нос из двух эллипсоидов, лента окон;
--   тепловоз — красная кабина и капоты с белой крышей, площадка с перилами, синие вагоны с углём.
-- Какой — по месту переезда (без rng: rng участка общий с раскладкой препятствий).
local TRAIN_RED = Color3.fromRGB(215, 55, 50)
local TRAIN_DARK = Color3.fromRGB(60, 62, 72)
local RAIL_GREY = Color3.fromRGB(215, 215, 222)
local WAGONS = { 24, 46, 68 }

-- Колёсные пары: цилиндр насквозь по ширине (одна часть = два колеса), по 2 тележки × 2 оси
local function axles(base: CFrame, zc: number, bogies: { number }, parent: Instance, hub: boolean)
	for _, bz in bogies do
		for _, dz in { -1.2, 1.2 } do
			local cf = base * CFrame.new(0, 1.1, zc + bz + dz)
			deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(7.4, 2.2, 2.2), CFrame = cf, Color = BLACK }, parent)
			if hub then
				deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(7.5, 1.2, 1.2), CFrame = cf, Color = WHITE }, parent)
			end
		end
	end
end

local function fastTrain(base: CFrame, m: Instance)
	-- локомотив: красный низ, белый мягкий верх, нос — белый эллипсоид поверх красного
	deco({ Size = Vector3.new(8, 3.5, 20), CFrame = base * CFrame.new(0, 3.25, 0), Color = TRAIN_RED, CastShadow = true }, m)
	softBox(base * CFrame.new(0, 7.75, 0), Vector3.new(8, 5.5, 20), 2, WHITE, m, { shadow = true })
	deco({ Shape = Enum.PartType.Ball, Size = Vector3.new(7.8, 7.5, 13), CFrame = base * CFrame.new(0, 5.5, -10), Color = WHITE, CastShadow = true }, m)
	deco({ Shape = Enum.PartType.Ball, Size = Vector3.new(8.1, 4.2, 11.6), CFrame = base * CFrame.new(0, 3.2, -9.4), Color = TRAIN_RED }, m)
	deco({ Shape = Enum.PartType.Ball, Size = Vector3.new(5.2, 2.4, 5), CFrame = base * CFrame.new(0, 8, -13.6), Color = WINDOW, Reflectance = 0.15 }, m) -- кабина машиниста
	deco({ Size = Vector3.new(8.1, 1.6, 15), CFrame = base * CFrame.new(0, 7.6, 1), Color = WINDOW, Reflectance = 0.15 }, m)
	deco({ Size = Vector3.new(8.1, 0.35, 19.9), CFrame = base * CFrame.new(0, 6.2, 0), Color = TRAIN_RED }, m)
	for _, side in { -1, 1 } do
		deco({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.9, 0.9), CFrame = base * CFrame.new(side * 2.2, 4.4, -15), Color = HEAD, Material = Enum.Material.Neon }, m)
	end
	snowCap(base * CFrame.new(0, 10.5, 0.5), Vector3.new(7, 0.8, 15.5), m)
	axles(base, 0, { -6.5, 6.5 }, m, false)
	for _, z in WAGONS do
		deco({ Size = Vector3.new(8, 3, 20), CFrame = base * CFrame.new(0, 3, z), Color = TRAIN_RED, CastShadow = true }, m)
		softBox(base * CFrame.new(0, 7, z), Vector3.new(8, 5, 20), 1.6, WHITE, m, { shadow = true })
		deco({ Size = Vector3.new(8.1, 1.6, 16), CFrame = base * CFrame.new(0, 6.8, z), Color = WINDOW, Reflectance = 0.15 }, m)
		deco({ Size = Vector3.new(8.1, 0.35, 19.9), CFrame = base * CFrame.new(0, 5.3, z), Color = TRAIN_RED }, m)
		snowCap(base * CFrame.new(0, 9.5, z), Vector3.new(7.2, 0.8, 16.5), m)
		axles(base, z, { -6.5, 6.5 }, m, false)
	end
end

local function dieselTrain(base: CFrame, m: Instance)
	-- площадка во всю длину локомотива (z −15…10)
	deco({ Size = Vector3.new(8, 0.7, 25), CFrame = base * CFrame.new(0, 2.15, -2.5), Color = TRAIN_DARK, CastShadow = true }, m)
	softBox(base * CFrame.new(0, 5.5, 3.25), Vector3.new(6.6, 6, 13.5), 1, TRAIN_RED, m, { top = WHITE, shadow = true }) -- длинный капот
	softBox(base * CFrame.new(0, 6.5, -6.75), Vector3.new(7.4, 8, 6.5), 1.2, TRAIN_RED, m, { top = WHITE, shadow = true }) -- кабина
	softBox(base * CFrame.new(0, 4, -12.5), Vector3.new(6.6, 3, 5), 0.8, TRAIN_RED, m, { back = false }) -- короткий капот
	deco({ Size = Vector3.new(6.7, 0.5, 24.9), CFrame = base * CFrame.new(0, 3.6, -2.45), Color = WHITE }, m) -- полоса
	deco({ Size = Vector3.new(6, 2.2, 0.15), CFrame = base * CFrame.new(0, 8.2, -10.08), Color = WINDOW, Reflectance = 0.15 }, m)
	deco({ Size = Vector3.new(7.5, 2, 3.8), CFrame = base * CFrame.new(0, 8.2, -6.6), Color = WINDOW, Reflectance = 0.15 }, m)
	deco({ Size = Vector3.new(3.4, 1.4, 0.15), CFrame = base * CFrame.new(0, 3.9, -15.08), Color = BLACK }, m) -- решётка
	for _, side in { -1, 1 } do
		lamp(base * CFrame.new(side * 2.3, 3.9, -15.08), 0.9, HEAD, m, true)
		-- поручни: верхняя труба по краю площадки
		deco({ Size = Vector3.new(0.22, 0.22, 24.4), CFrame = base * CFrame.new(side * 3.85, 4.3, -2.45), Color = RAIL_GREY }, m)
	end
	-- стойки перил: брусок насквозь по ширине, середина спрятана в капоте/кабине — видны две стойки
	for _, z in { -14.3, -10.3, -3, 2, 6.5, 9.6 } do
		deco({ Size = Vector3.new(7.9, 1.8, 0.22), CFrame = base * CFrame.new(0, 3.4, z), Color = RAIL_GREY }, m)
	end
	deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 0.8, 0.8), CFrame = base * CFrame.new(0, 9, 1) * CFrame.Angles(0, 0, math.rad(90)), Color = BLACK }, m) -- выхлоп
	for _, bz in { -9, 6 } do -- тележки
		deco({ Size = Vector3.new(7.6, 1, 5), CFrame = base * CFrame.new(0, 1.4, bz), Color = TRAIN_DARK }, m)
	end
	axles(base, 0, { -9, 6 }, m, true)
	-- синие вагоны-полувагоны с горкой угля и снегом
	local blue = Color3.fromRGB(55, 110, 200)
	for _, z in WAGONS do
		softBox(base * CFrame.new(0, 4.75, z), Vector3.new(8, 6.5, 20), 0.8, blue, m, { shadow = true })
		for _, dz in { -5, 0, 5 } do -- рёбра
			deco({ Size = Vector3.new(8.1, 6, 0.4), CFrame = base * CFrame.new(0, 4.6, z + dz), Color = Color3.fromRGB(40, 85, 165) }, m)
		end
		deco({ Shape = Enum.PartType.Ball, Size = Vector3.new(7.2, 3, 18.4), CFrame = base * CFrame.new(0, 8, z), Color = Color3.fromRGB(40, 40, 45) }, m) -- уголь
		snowCap(base * CFrame.new(0, 9.1, z), Vector3.new(5.6, 1.2, 14), m)
		axles(base, z, { -6.5, 6.5 }, m, false)
	end
end

function Props.train(base: CFrame, parent: Instance): Model
	local m = vehicleModel("Train")
	hitbox(Vector3.new(8, 9, 20), base * CFrame.new(0, 6, 0), m)
	hitbox(Vector3.new(7, 4, 6), base * CFrame.new(0, 3.5, -12), m)
	for _, z in WAGONS do
		hitbox(Vector3.new(8, 8, 20), base * CFrame.new(0, 5.5, z), m)
	end
	local p = base.Position
	if math.floor((p.X + p.Z) / 10) % 2 == 0 then
		fastTrain(base, m)
	else
		dieselTrain(base, m)
	end
	m.WorldPivot = base
	m.Parent = parent
	return m
end

-- Кабинка канатной дороги: base — точка на тросе
function Props.gondola(rng: Random, base: CFrame, parent: Instance): Model
	local m = vehicleModel("Gondola")
	local c = pick(rng, { Color3.fromRGB(225, 60, 55), Color3.fromRGB(245, 190, 45), Color3.fromRGB(70, 140, 220) })
	deco({ Size = Vector3.new(0.5, 4, 0.5), CFrame = base * CFrame.new(0, -2, 0), Color = Color3.fromRGB(90, 95, 105), Material = Enum.Material.Metal }, m)
	part("Part", { Size = Vector3.new(6, 6, 6), CFrame = base * CFrame.new(0, -7, 0), Color = c }, m)
	deco({ Size = Vector3.new(6.1, 2.4, 5), CFrame = base * CFrame.new(0, -6.2, 0), Color = GLASS, Material = Enum.Material.Glass, Reflectance = 0.25 }, m)
	deco({ Size = Vector3.new(6.4, 0.6, 6.4), CFrame = base * CFrame.new(0, -3.8, 0), Color = Color3.fromRGB(240, 240, 245) }, m)
	m.WorldPivot = base
	m.Parent = parent
	return m
end

function Props.pylon(base: CFrame, height: number, parent: Instance)
	local metal = Color3.fromRGB(110, 115, 125)
	for _, sx in { -1, 1 } do
		deco({ Size = Vector3.new(0.8, height, 0.8), CFrame = base * CFrame.new(sx * 1.6, height / 2, 0) * CFrame.Angles(0, 0, sx * math.rad(-3)), Color = metal, Material = Enum.Material.Metal }, parent)
	end
	deco({ Size = Vector3.new(6, 0.8, 1.2), CFrame = base * CFrame.new(0, height, 0), Color = metal, Material = Enum.Material.Metal }, parent)
	for y = 6, height - 4, 6 do
		deco({ Size = Vector3.new(3.6, 0.4, 0.4), CFrame = base * CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(35)), Color = metal }, parent)
	end
end

-- Знак «стрелка» (красный круг) и светофор у дороги
function Props.arrowSign(base: CFrame, dir: number, parent: Instance)
	deco({ Size = Vector3.new(0.5, 7, 0.5), CFrame = base * CFrame.new(0, 3.5, 0), Color = Color3.fromRGB(150, 155, 165) }, parent)
	local disc = deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 3.6, 3.6), CFrame = base * CFrame.new(0, 7.6, 0) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(220, 50, 45) }, parent)
	label(disc, Enum.NormalId.Left, if dir > 0 then ">" else "<", Color3.new(1, 1, 1))
	label(disc, Enum.NormalId.Right, if dir > 0 then "<" else ">", Color3.new(1, 1, 1))
end

function Props.trafficLight(base: CFrame, parent: Instance)
	deco({ Size = Vector3.new(0.6, 9, 0.6), CFrame = base * CFrame.new(0, 4.5, 0), Color = Color3.fromRGB(60, 60, 70) }, parent)
	deco({ Size = Vector3.new(1.6, 4.2, 1.2), CFrame = base * CFrame.new(0, 10, 0), Color = Color3.fromRGB(35, 35, 40) }, parent)
	for k, col in { Color3.fromRGB(255, 60, 50), Color3.fromRGB(255, 200, 40), Color3.fromRGB(60, 220, 90) } do
		deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 1, 1), CFrame = base * CFrame.new(0, 11.4 - (k - 1) * 1.3, -0.6) * CFrame.Angles(0, math.rad(90), 0), Color = col, Material = if k == 1 then Enum.Material.Neon else Enum.Material.SmoothPlastic }, parent)
	end
end

-- Шлагбаум переезда
function Props.railGate(base: CFrame, parent: Instance)
	deco({ Size = Vector3.new(0.8, 5, 0.8), CFrame = base * CFrame.new(0, 2.5, 0), Color = Color3.fromRGB(240, 240, 240) }, parent)
	for _, sx in { -0.8, 0.8 } do
		deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 1, 1), CFrame = base * CFrame.new(sx, 5.6, -0.5) * CFrame.Angles(0, math.rad(90), 0), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 50, 40) }, parent)
	end
	for k = 0, 5 do -- поднятая стрела в красно-белую полоску
		deco({ Size = Vector3.new(0.4, 1.6, 0.4), CFrame = base * CFrame.new(0, 6 + k * 1.6, 0.6), Color = if k % 2 == 0 then Color3.fromRGB(220, 40, 40) else Color3.new(1, 1, 1) }, parent)
	end
end


return Props
