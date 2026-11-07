-- Транспорт: машины, фургоны, джип, живой трафик дорог (автобус, такси, полиция, поезд),
-- канатная дорога, знаки и шлагбаум у дороги. Часть shared/Props (см. Props/init).

local Base = require(script.Parent.Base)

local Props = Base.Props
local part, deco, pick, label, wheels = Base.part, Base.deco, Base.pick, Base.label, Base.wheels
local SNOW, BLACK, GLASS = Base.SNOW, Base.BLACK, Base.GLASS

------------------------------------------------------------------ транспорт
local CAR_COLORS = {
	Color3.fromRGB(215, 55, 50),
	Color3.fromRGB(55, 110, 200),
	Color3.fromRGB(245, 190, 50),
	Color3.fromRGB(235, 235, 240),
	Color3.fromRGB(90, 170, 110),
	Color3.fromRGB(70, 75, 90),
}


-- Легковушка. base — точка на земле, «нос» машины смотрит по -Z base
function Props.car(rng: Random, base: CFrame, parent: Instance, color: Color3?)
	local c = color or pick(rng, CAR_COLORS)
	part("Part", { Size = Vector3.new(6.2, 2.2, 12), CFrame = base * CFrame.new(0, 2.1, 0), Color = c }, parent)
	part("Part", { Size = Vector3.new(5.8, 2.2, 6.4), CFrame = base * CFrame.new(0, 4.3, 0.6), Color = c }, parent)
	-- Стёкла: лента вокруг кабины + лобовое
	deco({ Size = Vector3.new(5.9, 1.4, 5.4), CFrame = base * CFrame.new(0, 4.4, 0.6), Color = GLASS, Material = Enum.Material.Glass, Reflectance = 0.3 }, parent)
	deco({ Size = Vector3.new(5.2, 1.5, 0.3), CFrame = base * CFrame.new(0, 4.4, -2.65), Color = GLASS, Material = Enum.Material.Glass, Reflectance = 0.3 }, parent)
	-- Фары и стопы
	for _, side in { -1, 1 } do
		deco({ Size = Vector3.new(1.2, 0.6, 0.2), CFrame = base * CFrame.new(side * 2.2, 2.5, -6.05), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 245, 200) }, parent)
		deco({ Size = Vector3.new(1.2, 0.6, 0.2), CFrame = base * CFrame.new(side * 2.2, 2.5, 6.05), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 60, 60) }, parent)
	end
	deco({ Size = Vector3.new(5.4, 0.5, 0.3), CFrame = base * CFrame.new(0, 1.4, -6.1), Color = Color3.fromRGB(150, 150, 160) }, parent) -- бампер
	deco({ Size = Vector3.new(6, 0.5, 6.2), CFrame = base * CFrame.new(0, 5.65, 0.6), Material = Enum.Material.Snow, Color = SNOW }, parent) -- снег на крыше
	wheels(base, 3.05, { -3.8, 3.8 }, 1.2, parent)
end

-- Фургон / скорая
function Props.van(rng: Random, base: CFrame, parent: Instance, ambulance: boolean?)
	local c = if ambulance then Color3.fromRGB(245, 245, 248) else pick(rng, { Color3.fromRGB(70, 110, 190), Color3.fromRGB(240, 240, 240), Color3.fromRGB(230, 150, 50) })
	part("Part", { Size = Vector3.new(6.6, 6.4, 9.5), CFrame = base * CFrame.new(0, 4.4, 1.8), Color = c }, parent) -- кузов
	part("Part", { Size = Vector3.new(6.4, 4.4, 4.4), CFrame = base * CFrame.new(0, 3.4, -5.1), Color = c }, parent) -- кабина
	deco({ Size = Vector3.new(5.6, 1.8, 0.3), CFrame = base * CFrame.new(0, 4.4, -7.35), Color = GLASS, Material = Enum.Material.Glass, Reflectance = 0.3 }, parent)
	deco({ Size = Vector3.new(6.5, 1.6, 3), CFrame = base * CFrame.new(0, 4.5, -5.1), Color = GLASS, Material = Enum.Material.Glass }, parent)
	if ambulance then
		for _, side in { -1, 1 } do
			deco({ Size = Vector3.new(0.2, 0.9, 9.3), CFrame = base * CFrame.new(side * 3.35, 3, 1.8), Color = Color3.fromRGB(220, 40, 40) }, parent)
			deco({ Size = Vector3.new(0.2, 2.6, 0.8), CFrame = base * CFrame.new(side * 3.35, 5.4, 2.4), Color = Color3.fromRGB(220, 40, 40) }, parent)
			deco({ Size = Vector3.new(0.2, 0.8, 2.6), CFrame = base * CFrame.new(side * 3.35, 5.4, 2.4), Color = Color3.fromRGB(220, 40, 40) }, parent)
		end
		deco({ Size = Vector3.new(2.4, 0.6, 0.8), CFrame = base * CFrame.new(0, 7.9, -1.5), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 50, 50) }, parent) -- мигалка
	end
	deco({ Size = Vector3.new(6.4, 0.5, 9.3), CFrame = base * CFrame.new(0, 7.85, 1.8), Material = Enum.Material.Snow, Color = SNOW }, parent)
	wheels(base, 3.25, { -4.8, 4 }, 1.4, parent)
end

-- Джип для каньона
function Props.jeep(rng: Random, base: CFrame, parent: Instance)
	local c = pick(rng, { Color3.fromRGB(200, 170, 90), Color3.fromRGB(110, 120, 80), Color3.fromRGB(190, 70, 50) })
	part("Part", { Size = Vector3.new(6.6, 3, 11), CFrame = base * CFrame.new(0, 2.8, 0), Color = c }, parent)
	part("Part", { Size = Vector3.new(6.4, 2.6, 6.5), CFrame = base * CFrame.new(0, 5.6, 1), Color = c }, parent)
	deco({ Size = Vector3.new(6.5, 1.6, 5.6), CFrame = base * CFrame.new(0, 5.7, 1), Color = GLASS, Material = Enum.Material.Glass }, parent)
	deco({ Size = Vector3.new(5.6, 1.7, 0.3), CFrame = base * CFrame.new(0, 5.7, -2.3), Color = GLASS, Material = Enum.Material.Glass }, parent)
	deco({ Size = Vector3.new(5, 0.4, 5.5), CFrame = base * CFrame.new(0, 7.1, 1), Color = BLACK }, parent) -- багажник
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

function Props.bus(rng: Random, base: CFrame, parent: Instance)
	local c = pick(rng, { Color3.fromRGB(235, 70, 60), Color3.fromRGB(245, 190, 45), Color3.fromRGB(60, 130, 210) })
	part("Part", { Size = Vector3.new(7.4, 7, 26), CFrame = base * CFrame.new(0, 4.6, 0), Color = c }, parent)
	deco({ Size = Vector3.new(7.5, 2.2, 22), CFrame = base * CFrame.new(0, 5.6, 0.8), Color = GLASS, Material = Enum.Material.Glass, Reflectance = 0.25 }, parent)
	deco({ Size = Vector3.new(6.4, 2.6, 0.3), CFrame = base * CFrame.new(0, 5.4, -13.05), Color = GLASS, Material = Enum.Material.Glass, Reflectance = 0.3 }, parent)
	deco({ Size = Vector3.new(7.5, 0.7, 26.1), CFrame = base * CFrame.new(0, 2.6, 0), Color = Color3.fromRGB(240, 240, 245) }, parent)
	deco({ Size = Vector3.new(7.2, 0.5, 25), CFrame = base * CFrame.new(0, 8.35, 0), Material = Enum.Material.Snow, Color = SNOW }, parent)
	wheels(base, 3.55, { -9, 8 }, 1.6, parent)
end

function Props.taxi(rng: Random, base: CFrame, parent: Instance)
	Props.car(rng, base, parent, Color3.fromRGB(250, 200, 40))
	local sign = deco({ Size = Vector3.new(2.4, 0.9, 1), CFrame = base * CFrame.new(0, 6.3, 0.6), Color = Color3.fromRGB(30, 30, 35) }, parent)
	label(sign, Enum.NormalId.Front, "TAXI", Color3.fromRGB(255, 220, 60))
	label(sign, Enum.NormalId.Back, "TAXI", Color3.fromRGB(255, 220, 60))
	for k = -2, 2 do -- шашечки
		deco({ Size = Vector3.new(0.15, 0.6, 1), CFrame = base * CFrame.new(3.12, 2.6, k * 2), Color = if k % 2 == 0 then BLACK else Color3.new(1, 1, 1) }, parent)
		deco({ Size = Vector3.new(0.15, 0.6, 1), CFrame = base * CFrame.new(-3.12, 2.6, k * 2), Color = if k % 2 == 0 then BLACK else Color3.new(1, 1, 1) }, parent)
	end
end

function Props.police(rng: Random, base: CFrame, parent: Instance)
	Props.car(rng, base, parent, Color3.fromRGB(240, 242, 248))
	for _, side in { -1, 1 } do
		deco({ Size = Vector3.new(0.15, 1, 8), CFrame = base * CFrame.new(side * 3.12, 2.3, 0), Color = Color3.fromRGB(40, 70, 170) }, parent)
	end
	deco({ Size = Vector3.new(1.4, 0.6, 1), CFrame = base * CFrame.new(-0.75, 6.1, 0.6), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 50, 50) }, parent)
	deco({ Size = Vector3.new(1.4, 0.6, 1), CFrame = base * CFrame.new(0.75, 6.1, 0.6), Material = Enum.Material.Neon, Color = Color3.fromRGB(60, 110, 255) }, parent)
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

-- Поезд: локомотив + вагоны, тянется по +Z от base (едет носом по -Z)
function Props.train(base: CFrame, parent: Instance): Model
	local m = vehicleModel("Train")
	local loco = Color3.fromRGB(200, 50, 45)
	part("Part", { Size = Vector3.new(8, 9, 20), CFrame = base * CFrame.new(0, 6, 0), Color = loco }, m)
	part("Part", { Size = Vector3.new(7, 4, 6), CFrame = base * CFrame.new(0, 3.5, -12), Color = loco }, m)
	deco({ Size = Vector3.new(6.5, 2.4, 0.3), CFrame = base * CFrame.new(0, 8, -10.05), Color = GLASS, Material = Enum.Material.Glass, Reflectance = 0.3 }, m)
	deco({ Size = Vector3.new(8.1, 1, 20.1), CFrame = base * CFrame.new(0, 3.5, 0), Color = Color3.fromRGB(245, 200, 50) }, m)
	deco({ Size = Vector3.new(1.6, 1, 0.3), CFrame = base * CFrame.new(0, 5, -15.1), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 245, 200) }, m)
	for k = 1, 3 do
		local z = 2 + k * 22
		part("Part", { Size = Vector3.new(8, 8, 20), CFrame = base * CFrame.new(0, 5.5, z), Color = Color3.fromRGB(60, 120, 90) }, m)
		deco({ Size = Vector3.new(8.1, 2, 16), CFrame = base * CFrame.new(0, 6.5, z), Color = GLASS, Material = Enum.Material.Glass }, m)
		deco({ Size = Vector3.new(7.8, 0.5, 19.5), CFrame = base * CFrame.new(0, 9.75, z), Material = Enum.Material.Snow, Color = SNOW }, m)
	end
	for z = -8, 74, 11 do
		for _, side in { -1, 1 } do
			deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 2.4, 2.4), CFrame = base * CFrame.new(side * 3.4, 1.2, z), Color = BLACK }, m)
		end
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
