-- Препятствия: уличные (гидрант, знак, барьер, остановка, конусы, бочки), природные (снеговик,
-- валун, кактус, указатель, бревно, поленница) и выбор препятствия по миру (Props.obstacle).
-- Часть shared/Props (см. Props/init).

local Base = require(script.Parent.Base)
local Config = require(script.Parent.Parent.Config)

local Props = Base.Props
local Meshes = Base.Meshes
local part, deco, pick, label, wheels = Base.part, Base.deco, Base.pick, Base.label, Base.wheels
local SNOW, BLACK = Base.SNOW, Base.BLACK
local softBox, lamp, snowCap, WINDOW = Base.softBox, Base.lamp, Base.snowCap, Base.WINDOW

------------------------------------------------------------------ уличные препятствия
function Props.hydrant(base: CFrame, parent: Instance)
	local red = Color3.fromRGB(215, 45, 40)
	part("Part", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 1.6, 1.6), CFrame = base * CFrame.new(0, 1.9, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = red }, parent)
	part("Part", { Shape = Enum.PartType.Ball, Size = Vector3.new(1.7, 1.7, 1.7), CFrame = base * CFrame.new(0, 3.4, 0), Color = red }, parent)
	deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 2.2, 2.2), CFrame = base * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = red }, parent)
	for _, side in { -1, 1 } do
		deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.7, 0.8, 0.8), CFrame = base * CFrame.new(side * 1, 2.4, 0), Color = Color3.fromRGB(240, 200, 60) }, parent)
	end
	deco({ Shape = Enum.PartType.Ball, Size = Vector3.new(3.6, 1.2, 3.6), CFrame = base * CFrame.new(0, 0.2, 0), Material = Enum.Material.Snow, Color = SNOW }, parent)
end

function Props.stopSign(base: CFrame, parent: Instance)
	part("Part", { Size = Vector3.new(0.4, 8, 0.4), CFrame = base * CFrame.new(0, 4, 0), Color = Color3.fromRGB(150, 155, 165), Material = Enum.Material.Metal }, parent)
	local plate = part("Part", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 3.4, 3.4),
		CFrame = base * CFrame.new(0, 8.4, -0.3) * CFrame.Angles(0, math.rad(90), 0),
		Color = Color3.fromRGB(205, 30, 35),
	}, parent)
	-- Белая окантовка
	deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, 3.7, 3.7), CFrame = plate.CFrame * CFrame.new(0.05, 0, 0), Color = Color3.new(1, 1, 1) }, parent)
	local face = deco({ Size = Vector3.new(2.4, 1, 0.05), CFrame = base * CFrame.new(0, 8.4, -0.5), Transparency = 1 }, parent)
	label(face, Enum.NormalId.Front, "STOP", Color3.new(1, 1, 1))
	label(face, Enum.NormalId.Back, "STOP", Color3.new(1, 1, 1))
end

-- Дорожный барьер (референсы 2026-11-11, «мягкий» стиль): козлы из деревянных ног, две доски в
-- оранжево-жёлтую косую полоску, на стойках — оранжевые шары-фонари; доски — коллизия
function Props.barrier(base: CFrame, parent: Instance)
	local wood, orange, yellow = Color3.fromRGB(150, 100, 60), Color3.fromRGB(235, 120, 45), Color3.fromRGB(250, 195, 80)
	for _, x in { -3.4, 3.4 } do
		for _, z in { -0.7, 0.7 } do
			deco({ Size = Vector3.new(0.6, 3.6, 0.6), CFrame = base * CFrame.new(x, 1.7, z) * CFrame.Angles(math.rad(z > 0 and 12 or -12), 0, 0), Material = Enum.Material.Wood, Color = wood }, parent)
		end
		deco({ Size = Vector3.new(0.7, 0.5, 0.7), CFrame = base * CFrame.new(x, 3.95, 0), Color = Color3.fromRGB(130, 130, 140) }, parent)
		local lamp = deco({ Shape = Enum.PartType.Ball, Size = Vector3.one * 1.1, CFrame = base * CFrame.new(x, 4.7, 0), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 160, 60) }, parent)
		lamp.Name = "BarrierLamp"
	end
	for _, y in { 2.0, 3.35 } do
		part("Part", { Size = Vector3.new(8.4, 1.05, 0.5), CFrame = base * CFrame.new(0, y, 0), Color = orange }, parent)
		for k = 0, 4 do -- косые полосы
			deco({ Size = Vector3.new(0.7, 1.25, 0.56), CFrame = base * CFrame.new(-3.4 + k * 1.7, y, 0) * CFrame.Angles(0, 0, math.rad(-35)), Color = yellow }, parent)
		end
	end
	deco({ Size = Vector3.new(8.6, 0.3, 0.7), CFrame = base * CFrame.new(0, 3.95, 0), Material = Enum.Material.Snow, Color = SNOW }, parent)
end

------------------------------------------------------------------ природа
-- Снеговик. scale — масштаб модели (препятствие: Config.SNOWMAN_OBSTACLE_SCALE, #30: лёгкое не выше
-- тяжёлых; декор лобби — 1). Random-вызовы те же при любом масштабе (поворот и цвет шарфа).
function Props.snowman(rng: Random, base: CFrame, parent: Instance, scale: number?)
	local S = scale or 1
	local face = base * CFrame.Angles(0, math.rad(rng:NextNumber(-25, 25)), 0)
	local function at(x: number, y: number, z: number): CFrame
		return face * CFrame.new(x * S, y * S, z * S)
	end
	local rs, ys = { 3.4, 2.5, 1.8 }, { 3.2, 8.2, 12.1 }
	for k = 1, 3 do
		part("Part", { Shape = Enum.PartType.Ball, Size = Vector3.one * rs[k] * 2 * S, CFrame = at(0, ys[k], 0), Material = Enum.Material.Snow, Color = SNOW }, parent)
	end
	-- Пуговицы и глаза
	for _, y in { 7.4, 8.6 } do
		deco({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.6 * S, CFrame = at(0, y, -2.4), Color = BLACK }, parent)
	end
	for _, x in { -0.6, 0.6 } do
		deco({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.45 * S, CFrame = at(x, 12.6, -1.6), Color = BLACK }, parent)
	end
	-- Морковка
	deco({ Size = Vector3.new(0.5, 0.5, 2.2) * S, CFrame = at(0, 12.1, -2.6), Color = Color3.fromRGB(255, 130, 30) }, parent)
	-- Шарф
	local scarf = pick(rng, { Color3.fromRGB(220, 50, 50), Color3.fromRGB(60, 120, 220), Color3.fromRGB(60, 170, 90) })
	deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.9, 3.9, 3.9) * S, CFrame = at(0, 10.4, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = scarf }, parent)
	deco({ Size = Vector3.new(0.9, 2.4, 0.3) * S, CFrame = at(1, 9.3, -1.9) * CFrame.Angles(0, 0, math.rad(-12)), Color = scarf }, parent)
	-- Шляпа-цилиндр
	deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 3.2, 3.2) * S, CFrame = at(0, 13.7, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = BLACK }, parent)
	deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 2.2, 2.2) * S, CFrame = at(0, 14.8, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = BLACK }, parent)
	-- Руки-веточки
	for _, side in { -1, 1 } do
		deco({ Size = Vector3.new(3, 0.3, 0.3) * S, CFrame = at(side * 3.4, 9, 0) * CFrame.Angles(0, 0, math.rad(side * 25)), Color = Color3.fromRGB(110, 75, 45) }, parent)
	end
end

-- Низкополигональный валун: 2–3 повёрнутых блока разных оттенков. Декор (collide == false) с мешами
-- (#45) — скала-меш + снежная шапка (2 детали вместо 4); препятствие — всегда Part (точная коллизия).
function Props.boulder(rng: Random, base: CFrame, parent: Instance, sandy: boolean?, scale: number?, collide: boolean?)
	local s = (scale or 1) * rng:NextNumber(4.5, 6.5)
	local baseColor = if sandy then Color3.fromRGB(205, 140, 95) else Color3.fromRGB(125, 130, 145)
	local rocks = {}
	for k = 1, 3 do -- все Random-вызовы до выбора пути (раскладка куска не зависит от мешей)
		local ox, oz = rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)
		rocks[k] = { ox = ox, oz = oz, ax = rng:NextNumber(-0.4, 0.4), ay = rng:NextNumber(0, math.pi), az = rng:NextNumber(-0.4, 0.4) }
	end
	local mat = if sandy then Enum.Material.Sandstone else Enum.Material.Slate
	if collide == false and Meshes.has("rock_a", "rock_b") then
		local r = rocks[1]
		local c = base * CFrame.Angles(0, r.ay * 2, 0)
		local name = if r.ax > 0 then "rock_a" else "rock_b"
		local sc = Vector3.one * s * (if name == "rock_a" then 0.6 else 0.75)
		local rock = Meshes.place(name, c * CFrame.new(0, -s * 0.08, 0), sc, { Material = mat, Color = Meshes.vary(baseColor, base.Position, 0.1), CastShadow = true }, parent)
		if not sandy and rock then
			deco({ Shape = Enum.PartType.Ball, Size = Vector3.new(s * 1.0, s * 0.28, s * 0.8), CFrame = c * CFrame.new(0, rock.Size.Y - s * 0.12, 0), Material = Enum.Material.Snow, Color = SNOW }, parent)
		end
		return
	end
	local maker = if collide == false then deco else function(props, p)
		return part("Part", props, p)
	end
	for k = 1, 3 do
		local sz = s * (1 - (k - 1) * 0.22)
		local r = rocks[k]
		maker({
			Size = Vector3.new(sz * 1.2, sz * 0.9, sz),
			CFrame = base * CFrame.new(r.ox * s * 0.3, sz * 0.35 + (k - 1) * s * 0.18, r.oz * s * 0.3)
				* CFrame.Angles(r.ax, r.ay, r.az),
			Material = mat,
			Color = baseColor:Lerp(Color3.new(1, 1, 1), (k - 1) * 0.08),
			CastShadow = true,
		}, parent)
	end
	if not sandy then
		deco({ Shape = Enum.PartType.Ball, Size = Vector3.new(s * 1.1, s * 0.35, s * 0.9), CFrame = base * CFrame.new(0, s * 0.95, 0), Material = Enum.Material.Snow, Color = SNOW }, parent)
	end
end

function Props.cactus(rng: Random, base: CFrame, parent: Instance, collide: boolean?)
	local maker = if collide then function(props, p)
		return part("Part", props, p)
	end else deco
	local h = rng:NextNumber(7, 11)
	local green = Color3.fromRGB(85, 155, 80)
	maker({ Size = Vector3.new(2.2, h, 2.2), CFrame = base * CFrame.new(0, h / 2, 0), Material = Enum.Material.Grass, Color = green }, parent)
	for _, side in { -1, 1 } do
		if rng:NextNumber() < 0.8 then
			local y = h * rng:NextNumber(0.35, 0.6)
			maker({ Size = Vector3.new(2.2, 1.4, 1.4), CFrame = base * CFrame.new(side * 1.6, y, 0), Material = Enum.Material.Grass, Color = green }, parent)
			maker({ Size = Vector3.new(1.4, 3, 1.4), CFrame = base * CFrame.new(side * 2.4, y + 1.4, 0), Material = Enum.Material.Grass, Color = green }, parent)
		end
	end
	deco({ Size = Vector3.new(2.4, 0.4, 2.4), CFrame = base * CFrame.new(0, h + 0.2, 0), Material = Enum.Material.Snow, Color = SNOW }, parent)
end

-- Деревянный указатель
function Props.signpost(rng: Random, base: CFrame, parent: Instance, collide: boolean?)
	local wood = Color3.fromRGB(150, 105, 65)
	local maker = if collide then function(props, p)
		return part("Part", props, p)
	end else deco
	maker({ Size = Vector3.new(0.7, 9, 0.7), CFrame = base * CFrame.new(0, 4.5, 0), Material = Enum.Material.Wood, Color = wood }, parent)
	for k = 0, 2 do
		local dir = if rng:NextNumber() < 0.5 then -1 else 1
		maker({
			Size = Vector3.new(3.6, 0.8, 0.3),
			CFrame = base * CFrame.new(dir * 1.2, 7.6 - k * 1.3, 0) * CFrame.Angles(0, math.rad(rng:NextNumber(-20, 20)), 0),
			Material = Enum.Material.WoodPlanks,
			Color = wood:Lerp(Color3.new(1, 1, 1), 0.15),
		}, parent)
	end
end

------------------------------------------------------------------ ещё препятствия из оригинала
-- Грузовик (#68, референс владельца): красная кабина с крупным лобовым, чёрная решётка, круглые
-- фары; серая будка с рёбрами; задние колёса сдвоенные. Коллизия — прежние Part (будка 7 × 8 × 14,
-- кабина 6.8 × 5.4 × 5, 6 шин r 1.5), будка и кабина невидимы — вид рисует декор (Base.softBox).
-- ~42 части (было 19), коллизия 8. rng — один pick, как раньше.
function Props.truck(rng: Random, base: CFrame, parent: Instance)
	local cab = pick(rng, { Color3.fromRGB(215, 55, 50), Color3.fromRGB(230, 90, 45), Color3.fromRGB(60, 110, 200) })
	local grey, rib = Color3.fromRGB(175, 180, 190), Color3.fromRGB(145, 150, 162)
	part("Part", { Size = Vector3.new(7, 8, 14), CFrame = base * CFrame.new(0, 5.6, 2.5), Transparency = 1, CastShadow = false }, parent) -- будка
	part("Part", { Size = Vector3.new(6.8, 5.4, 5), CFrame = base * CFrame.new(0, 3.9, -7), Transparency = 1, CastShadow = false }, parent) -- кабина
	-- кабина: скруглён только верх носа (сзади к ней примыкает будка)
	softBox(base * CFrame.new(0, 3.9, -7), Vector3.new(6.8, 5.4, 5), 1.2, cab, parent, { back = false, shadow = true })
	deco({ Size = Vector3.new(5.8, 1.6, 0.15), CFrame = base * CFrame.new(0, 4.5, -9.55), Color = WINDOW, Reflectance = 0.15 }, parent) -- лобовое
	deco({ Size = Vector3.new(6.9, 1.6, 2.6), CFrame = base * CFrame.new(0, 4.5, -7.2), Color = WINDOW, Reflectance = 0.15 }, parent) -- боковые окна насквозь
	deco({ Size = Vector3.new(3.6, 1.4, 0.15), CFrame = base * CFrame.new(0, 2.4, -9.55), Color = BLACK }, parent) -- решётка
	for _, side in { -1, 1 } do
		lamp(base * CFrame.new(side * 2.6, 2.4, -9.55), 1, Color3.fromRGB(255, 245, 200), parent, true)
		lamp(base * CFrame.new(side * 2.8, 2.4, 9.56), 0.8, Color3.fromRGB(255, 70, 60), parent, true)
	end
	deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(6.6, 0.8, 0.8), CFrame = base * CFrame.new(0, 1.4, -9.45), Color = Color3.fromRGB(95, 100, 112) }, parent) -- бампер
	snowCap(base * CFrame.new(0, 6.6, -7.3), Vector3.new(5.8, 0.6, 3.6), parent)
	-- будка: мягкий серый короб + рёбра насквозь по ширине (видны на обоих бортах), снег сверху
	softBox(base * CFrame.new(0, 5.6, 2.5), Vector3.new(7, 8, 14), 0.7, grey, parent, { shadow = true })
	for _, z in { -2.9, -0.2, 2.5, 5.2, 7.9 } do
		deco({ Size = Vector3.new(7.12, 7.2, 0.35), CFrame = base * CFrame.new(0, 5.4, z), Color = rib }, parent)
	end
	snowCap(base * CFrame.new(0, 9.6, 2.5), Vector3.new(6.4, 0.8, 12.6), parent)
	deco({ Size = Vector3.new(6, 0.6, 18.4), CFrame = base * CFrame.new(0, 1.4, -0.2), Color = Color3.fromRGB(55, 58, 66) }, parent) -- рама
	wheels(base, 3.4, { -6.5, 4, 7.5 }, 1.5, parent)
	for _, z in { 4, 7.5 } do -- сдвоенные задние: внутренняя шина видна сзади и снизу
		for _, side in { -1, 1 } do
			deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 3, 3), CFrame = base * CFrame.new(side * 2.3, 1.5, z), Color = BLACK }, parent)
		end
	end
end

-- Автобусная остановка: навес со стеклянной стенкой и табличкой
function Props.busStop(base: CFrame, parent: Instance)
	local frame = Color3.fromRGB(70, 75, 90)
	for _, x in { -5, 5 } do
		for _, z in { -1.6, 1.6 } do
			part("Part", { Size = Vector3.new(0.4, 7, 0.4), CFrame = base * CFrame.new(x, 3.5, z), Material = Enum.Material.Metal, Color = frame }, parent)
		end
	end
	part("Part", { Size = Vector3.new(11, 0.5, 4), CFrame = base * CFrame.new(0, 7.2, 0), Color = frame }, parent)
	part("Part", { Size = Vector3.new(10, 5, 0.2), CFrame = base * CFrame.new(0, 4, 1.6), Material = Enum.Material.Glass, Color = Color3.fromRGB(180, 215, 240), Transparency = 0.4 }, parent)
	part("Part", { Size = Vector3.new(8, 0.6, 1.4), CFrame = base * CFrame.new(0, 2, 1), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(150, 105, 65) }, parent)
	local sign = deco({ Size = Vector3.new(2.4, 1.4, 0.2), CFrame = base * CFrame.new(4, 8.3, 0), Color = Color3.fromRGB(40, 120, 210) }, parent)
	label(sign, Enum.NormalId.Front, "BUS", Color3.new(1, 1, 1))
	label(sign, Enum.NormalId.Back, "BUS", Color3.new(1, 1, 1))
	deco({ Size = Vector3.new(11.2, 0.6, 4.2), CFrame = base * CFrame.new(0, 7.75, 0), Material = Enum.Material.Snow, Color = SNOW }, parent)
end

-- Дорожные конусы (2–3 штуки): квадратное основание со скруглением, гладкий конус из колец,
-- две белые полосы (референсы 2026-11-11)
function Props.cones(rng: Random, base: CFrame, parent: Instance)
	local orange = Color3.fromRGB(245, 115, 35)
	for k = 1, rng:NextInteger(2, 3) do
		local c = base * CFrame.new((k - 2) * 2.8, 0, rng:NextNumber(-1, 1))
		part("Part", { Size = Vector3.new(2.6, 0.45, 2.6), CFrame = c * CFrame.new(0, 0.22, 0), Color = orange }, parent)
		local n = 7
		for t = 0, n - 1 do
			local d = 1.9 - t * 0.24
			part("Part", {
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.52, d, d),
				CFrame = c * CFrame.new(0, 0.7 + t * 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
				Color = if t == 2 or t == 4 then Color3.fromRGB(250, 245, 235) else orange,
			}, parent)
		end
		deco({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.5, CFrame = c * CFrame.new(0, 4.1, 0), Color = orange }, parent)
	end
end

-- Бочки (по 2–3). Лёгкое (#30): тёплая палитра — оранжевая, медово-деревянная, жёлтая (было
-- красная/синяя/зелёная — красная читалась как «опасно»); pick тот же, Random-вызовов столько же.
function Props.barrels(rng: Random, base: CFrame, parent: Instance)
	local col = pick(rng, { Color3.fromRGB(235, 125, 45), Color3.fromRGB(185, 125, 70), Color3.fromRGB(240, 190, 60) })
	for k = 1, rng:NextInteger(2, 3) do
		local c = base * CFrame.new((k - 2) * 3.2, 0, rng:NextNumber(-1.2, 1.2))
		part("Part", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 3, 3), CFrame = c * CFrame.new(0, 2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = col }, parent)
		for _, y in { 0.9, 3.1 } do
			deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 3.15, 3.15), CFrame = c * CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(60, 60, 65) }, parent)
		end
		deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 2.8, 2.8), CFrame = c * CFrame.new(0, 4.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Snow, Color = SNOW }, parent)
	end
end

-- Поваленное бревно поперёк полосы
function Props.log(rng: Random, base: CFrame, parent: Instance)
	local len = rng:NextNumber(10, 13)
	local c = base * CFrame.Angles(0, rng:NextNumber(-0.25, 0.25), 0)
	part("Part", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(len, 2.6, 2.6), CFrame = c * CFrame.new(0, 1.3, 0), Material = Enum.Material.Wood, Color = Color3.fromRGB(125, 85, 55) }, parent)
	for _, x in { -len / 2, len / 2 } do
		deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 2.3, 2.3), CFrame = c * CFrame.new(x, 1.3, 0), Color = Color3.fromRGB(215, 175, 120) }, parent) -- спил
	end
	deco({ Size = Vector3.new(len * 0.8, 0.5, 1.6), CFrame = c * CFrame.new(0, 2.6, 0), Material = Enum.Material.Snow, Color = SNOW }, parent)
	deco({ Size = Vector3.new(0.6, 2.2, 0.6), CFrame = c * CFrame.new(len * 0.2, 3, 0) * CFrame.Angles(0, 0, math.rad(25)), Material = Enum.Material.Wood, Color = Color3.fromRGB(110, 75, 45) }, parent) -- сучок
end

-- Поленница
function Props.woodpile(base: CFrame, parent: Instance)
	for row = 0, 2 do
		for k = 0, 3 - row do
			-- Полено лежит вдоль трассы: торцы смотрят на игрока
			part("Part", {
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(4.5, 1.6, 1.6),
				CFrame = base * CFrame.new(-2.4 + k * 1.6 + row * 0.8, 0.8 + row * 1.4, 0) * CFrame.Angles(0, math.rad(90), 0),
				Material = Enum.Material.Wood,
				Color = Color3.fromRGB(150 - row * 12, 100, 60),
			}, parent)
			deco({ -- светлый спил
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.1, 1.3, 1.3),
				CFrame = base * CFrame.new(-2.4 + k * 1.6 + row * 0.8, 0.8 + row * 1.4, -2.27) * CFrame.Angles(0, math.rad(90), 0),
				Color = Color3.fromRGB(220, 180, 125),
			}, parent)
		end
	end
	deco({ Size = Vector3.new(6, 0.5, 4.6), CFrame = base * CFrame.new(0, 4.4, 0), Material = Enum.Material.Snow, Color = SNOW }, parent)
end

-- Ящик TNT (#66, референсы 2026-11-11): деревянный ящик с наклейкой TNT, связка красных шашек с
-- таймером и ручка-детонатор сверху. Взрывается от любого удара (client/Sled/Contacts → explode):
-- не авария — сани подбрасывает, скорость падает (щит гасит потерю), монеты как за разбитое
-- (Config.TNT_COINS). Атрибуты Breakable + Explosive ставит Props.obstacle.
function Props.tnt(base: CFrame, parent: Instance)
	local wood = Color3.fromRGB(200, 140, 80)
	part("Part", { Size = Vector3.new(4, 3.4, 4), CFrame = base * CFrame.new(0, 1.7, 0), Material = Enum.Material.WoodPlanks, Color = wood }, parent)
	for _, y in { 0.35, 3.05 } do -- обвязка досками
		deco({ Size = Vector3.new(4.15, 0.5, 4.15), CFrame = base * CFrame.new(0, y, 0), Material = Enum.Material.Wood, Color = wood:Lerp(Color3.new(0, 0, 0), 0.25) }, parent)
	end
	for _, f in { { 0, -2.06, 0 }, { 0, 2.06, math.pi } } do
		local face = deco({ Size = Vector3.new(2.6, 1.1, 0.06), CFrame = base * CFrame.new(f[1], 1.8, f[2]) * CFrame.Angles(0, f[3], 0), Color = Color3.fromRGB(240, 120, 140) }, parent)
		label(face, Enum.NormalId.Front, "TNT", Color3.fromRGB(255, 255, 255))
	end
	-- шашки на крышке
	for k = -1, 1 do
		deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.6, 0.75, 0.75), CFrame = base * CFrame.new(k * 0.78, 3.8, 0) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(215, 55, 60) }, parent)
	end
	deco({ Size = Vector3.new(1.2, 0.5, 0.2), CFrame = base * CFrame.new(0, 4.25, -0.6), Material = Enum.Material.Neon, Color = Color3.fromRGB(90, 255, 120) }, parent) -- таймер
	-- детонатор: шток и рукоятка
	deco({ Size = Vector3.new(0.3, 1.6, 0.3), CFrame = base * CFrame.new(1.3, 4.2, 1.2), Color = Color3.fromRGB(90, 90, 95) }, parent)
	deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.8, 0.45, 0.45), CFrame = base * CFrame.new(1.3, 5, 1.2), Material = Enum.Material.Wood, Color = Color3.fromRGB(120, 75, 45) }, parent)
	deco({ Size = Vector3.new(3.6, 0.35, 3.6), CFrame = base * CFrame.new(0, 3.42, 0), Material = Enum.Material.Snow, Color = SNOW, Transparency = 0.15 }, parent)
end

------------------------------------------------------------------ препятствия по мирам
-- Визуальный код класса (#30, docs/ART_REFERENCES.md «Класс препятствия»):
--  • лёгкое (Breakable: разбивается ракетой/на ускорении) — светлое дерево, снег, картон, тёплые
--    оранжево-жёлтые акценты, округлые формы, не выше тяжёлых соседей мира;
--  • тяжёлое (авария) — тёмное: камень, металл, базальт, шоколад, транспорт + общий маркер —
--    красно-белый пояс-бордюр по контуру основания (Props.heavyMark). Красно-белое у лёгких не
--    используем (бочки и т. п. — тёплые цвета).
-- Пояс — декор (без коллизий, касаний и лучей, без Random): раскладка трассы не меняется.
local MARK_RED, MARK_WHITE = Color3.fromRGB(215, 40, 45), Color3.fromRGB(250, 250, 250)

-- Габарит коллизии модели в осях base (полуширины по X и Z): по деталям с CanCollide (part, не deco)
local function footprint(m: Model, base: CFrame): (number, number)
	local hx, hz = 0, 0
	for _, d in m:GetChildren() do
		if d:IsA("BasePart") and d.CanCollide then
			local c = d.CFrame
			local p = base:PointToObjectSpace(c.Position)
			local ax, ay, az = base:VectorToObjectSpace(c.RightVector), base:VectorToObjectSpace(c.UpVector), base:VectorToObjectSpace(-c.LookVector)
			local s = d.Size / 2
			local ex = math.abs(ax.X) * s.X + math.abs(ay.X) * s.Y + math.abs(az.X) * s.Z
			local ez = math.abs(ax.Z) * s.X + math.abs(ay.Z) * s.Y + math.abs(az.Z) * s.Z
			hx = math.max(hx, math.abs(p.X) + ex)
			hz = math.max(hz, math.abs(p.Z) + ez)
		end
	end
	return hx, hz
end
Props.obstacleFootprint = footprint

-- Маркер тяжёлого: эллипс-бордюр из Config.OBSTACLE_MARK.SEGMENTS кусков, красный/белый через один
function Props.heavyMark(m: Model, base: CFrame, hx: number, hz: number)
	local M = Config.OBSTACLE_MARK
	local n = math.floor(M.SEGMENTS)
	if n < 2 or hx <= 0 or hz <= 0 then
		return
	end
	local a = math.clamp(hx * M.PAD, M.MIN, M.MAX / 2)
	local b = math.clamp(hz * M.PAD, M.MIN, M.MAX / 2)
	-- периметр эллипса (Рамануджан) → длина куска с зазором 10 %
	local per = math.pi * (3 * (a + b) - math.sqrt((3 * a + b) * (a + 3 * b)))
	local len = per / n * 0.9
	for k = 0, n - 1 do
		local t = (k + 0.5) / n * math.pi * 2
		local tx, tz = -a * math.sin(t), b * math.cos(t)
		deco({
			Size = Vector3.new(len, M.HEIGHT, M.WIDTH),
			CFrame = base * CFrame.new(a * math.cos(t), M.HEIGHT / 2, b * math.sin(t)) * CFrame.Angles(0, math.atan2(-tz, tx), 0),
			Color = if k % 2 == 0 then MARK_RED else MARK_WHITE,
		}, m)
	end
end

-- Пятно-тень (#36): тёмный плоский эллипс под препятствием — контраст на светлом дне и в дымке.
-- 1 Part 1 × 0.1 × 1 + SpecialMesh Sphere со Scale до габарита: маленький Size — Contacts.smash не
-- делает из пятна обломок (порог Size.Magnitude > 1.5) и прячет его вместе с моделью. Без Random.
function Props.obstacleShadow(m: Model, base: CFrame, hx: number, hz: number, heavy: boolean)
	local S = Config.OBSTACLE_SHADOW
	local w = math.clamp(hx * S.PAD, S.MIN, S.MAX / 2) * 2
	local d = math.clamp(hz * S.PAD, S.MIN, S.MAX / 2) * 2
	local pad = deco({
		Name = "ObstacleShadow",
		Size = Vector3.new(1, 0.1, 1),
		CFrame = base * CFrame.new(0, 0.06, 0),
		Color = S.COLOR,
		Transparency = if heavy then S.HEAVY else S.LIGHT,
	}, m)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(w, 1, d)
	mesh.Parent = pad
end

-- Карточки видов (#30): вид — роль · класс · высота · цвет · с какого уровня мира (from).
-- Лёгкое = Breakable (ракета/ускоритель разбивают, +SMASH_COINS), тяжёлое = авария.
--  1 Снежный лес:  снеговик — частый «мягкий» блок · лёгкое · 7.9 · снег, тёплый шарф · 1
--                  бревно — низкий барьер поперёк · лёгкое · 3 · дерево · 1
--                  козлы-барьер — заметный блок полосы · лёгкое · 5 · оранжево-жёлтые доски · 1
--                  валун — первое тяжёлое · тяжёлое · 5–7 · серый сланец + пояс · 1
--                  поленница · лёгкое · 4.5 · дерево · 2;  указатель · лёгкое · 9 (тонкий) · дерево · 2
--                  бочки · лёгкое · 4 · оранжевые/жёлтые · 3;  легковушка · тяжёлое · 5 · цветной кузов + пояс · 3
--  2 Ледяной город: гидрант · лёгкое · 4 · красный металл (узкий) · 1;  STOP · лёгкое · 10 (тонкий) · 1
--                  конусы · лёгкое · 4 · оранжевые · 1;  остановка — первое тяжёлое · тяжёлое · 8 · тёмная рама + пояс · 1
--                  барьер, бочки · лёгкие · 2;  легковушка · тяжёлое · 2;  фургон, грузовик · тяжёлые · 3;
--                  TNT — риск-награда (взрыв, не авария) · 3
--  3 Каньон:       кактус · лёгкое · 7–11 · зелёный · 1;  указатель · лёгкое · 1;  валун (песчаник) · тяжёлое · 1
--                  бочки, поленница · лёгкие · 2;  бревно, TNT · 3;  джип · тяжёлое · 3
--  4 Ледяные пещеры: ледяная глыба · лёгкое · 4.5–6 · синий лёд · 1;  снеговик · лёгкое · 1
--                  сталагмит · тяжёлое · 7–11 · тёмный лёд + пояс · 1;  бочки · лёгкое · 2;
--                  валун · тяжёлое · 2;  легковушка · тяжёлое · 3
--  5 Северное сияние: снеговик, ящики · лёгкие · 1;  валун · тяжёлое · 1;  ледяная глыба, бревно · 2;  легковушка · 3
--  6 Снежный вулкан: бревно, бочки · лёгкие · 1;  лавовый камень · тяжёлое · 4–6 · базальт + лава · 1
--                  базальт · тяжёлое · 2;  ящики · лёгкое · 2;  TNT · 3;  джип · тяжёлое · 3
--  7 Конфетная гора: мармеладка · лёгкое (мягкая, была тяжёлым) · 6–8 · пастель · 1;  капкейк · лёгкое · 1
--                  шоколад · тяжёлое (было лёгким: тёмная плитка) · 4 · 1;  снеговик · лёгкое · 2
--                  леденцовая трость · тяжёлое (твёрдая карамель, сама красно-белая) · 7 · 2
-- Веса — прежние: выбор по весам идёт по полному списку (тот же бросок rng, что раньше), поэтому на
-- уровнях, где вид открыт, стоит то же, что и до #30.

-- Возвращает модель-препятствие (все детали потом получают тег Obstacle).
-- stage — ступень ввода видов (Config.obstacleStage(level), nil — всё открыто); row — общая таблица
-- ряда (Track создаёт на каждый ряд): до OBSTACLE_COMBO_FROM ряд держит один класс.
-- Детерминизм: rng — общий Random куска. Вызовы rng те же, что до #30: поворот, разворот, бросок
-- по полному списку и Random-вызовы выбранного вида. Если выбранный вид ещё закрыт, он строится
-- «вхолостую» в модель-черновик (расходует rng ровно как раньше, затем удаляется), а замена
-- строится своим Random от броска — дальнейшие x-сдвиги, ускорители и монеты куска не меняются.
function Props.obstacle(theme: number, rng: Random, base: CFrame, parent: Instance, stage: number?, row: { [string]: any }?): Model
	local m = Instance.new("Model")
	m.Name = "Obstacle"
	-- Машины стоят вдоль трассы (носом вверх или вниз): поперёк грузовик перекрывал 2–3 полосы сразу
	local turned = base * CFrame.Angles(0, if rng:NextNumber() < 0.5 then 0 else math.pi, 0)
	local twisted = base * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0)
	local snowS = Config.SNOWMAN_OBSTACLE_SCALE
	-- { вес, функция(r, p), лёгкое (true | "tnt" | nil = тяжёлое), с уровня мира }
	local options
	if theme == 1 then
		options = {
			{ 24, function(r, p) Props.snowman(r, base, p, snowS) end, true, 1 },
			{ 18, function(r, p) Props.boulder(r, base, p) end, nil, 1 },
			{ 14, function(r, p) Props.log(r, base, p) end, true, 1 },
			{ 10, function(_, p) Props.woodpile(twisted, p) end, true, 2 },
			{ 10, function(_, p) Props.barrier(twisted, p) end, true, 1 },
			{ 12, function(r, p) Props.car(r, turned, p) end, nil, 3 },
			{ 6, function(r, p) Props.signpost(r, base, p, true) end, true, 2 },
			{ 6, function(r, p) Props.barrels(r, twisted, p) end, true, 3 },
		}
	elseif theme == 2 then
		options = {
			{ 24, function(r, p) Props.car(r, turned, p) end, nil, 2 },
			{ 10, function(r, p) Props.van(r, turned, p, r:NextNumber() < 0.5) end, nil, 3 },
			{ 8, function(r, p) Props.truck(r, turned, p) end, nil, 3 },
			{ 8, function(_, p) Props.busStop(twisted, p) end, nil, 1 },
			{ 10, function(_, p) Props.hydrant(base, p) end, true, 1 },
			{ 10, function(_, p) Props.stopSign(base, p) end, true, 1 },
			{ 12, function(r, p) Props.cones(r, twisted, p) end, true, 1 },
			{ 8, function(_, p) Props.barrier(twisted, p) end, true, 2 },
			{ 10, function(r, p) Props.barrels(r, twisted, p) end, true, 2 },
			{ 8, function(_, p) Props.tnt(twisted, p) end, "tnt", 3 },
		}
	elseif theme == 4 then
		options = {
			{ 24, function(r, p) Props.iceBlock(r, base, p) end, true, 1 },
			{ 18, function(r, p) Props.stalagmite(r, base, p) end, nil, 1 },
			{ 14, function(r, p) Props.snowman(r, base, p, snowS) end, true, 1 },
			{ 12, function(r, p) Props.boulder(r, base, p) end, nil, 2 },
			{ 10, function(r, p) Props.barrels(r, twisted, p) end, true, 2 },
			{ 8, function(r, p) Props.car(r, turned, p) end, nil, 3 },
		}
	elseif theme == 5 then
		options = {
			{ 22, function(r, p) Props.snowman(r, base, p, snowS) end, true, 1 },
			{ 18, function(r, p) Props.crates(r, twisted, p) end, true, 1 },
			{ 16, function(r, p) Props.iceBlock(r, base, p) end, true, 2 },
			{ 12, function(r, p) Props.log(r, base, p) end, true, 2 },
			{ 10, function(r, p) Props.boulder(r, base, p) end, nil, 1 },
			{ 8, function(r, p) Props.car(r, turned, p) end, nil, 3 },
		}
	elseif theme == 6 then
		options = {
			{ 26, function(r, p) Props.lavaRock(r, base, p) end, nil, 1 },
			{ 16, function(r, p) Props.basalt(r, base, p) end, nil, 2 },
			{ 14, function(r, p) Props.log(r, base, p) end, true, 1 },
			{ 12, function(r, p) Props.barrels(r, twisted, p) end, true, 1 },
			{ 10, function(r, p) Props.crates(r, twisted, p) end, true, 2 },
			{ 8, function(_, p) Props.tnt(twisted, p) end, "tnt", 3 },
			{ 8, function(r, p) Props.jeep(r, turned, p) end, nil, 3 },
		}
	elseif theme == 7 then
		options = {
			{ 22, function(r, p) Props.gumdrop(r, base, p) end, true, 1 },
			{ 18, function(r, p) Props.cupcake(r, base, p) end, true, 1 },
			{ 16, function(r, p) Props.chocolate(r, base, p) end, nil, 1 },
			{ 14, function(r, p) Props.candyCane(r, base, p, 7, true) end, nil, 2 },
			{ 10, function(r, p) Props.snowman(r, base, p, snowS) end, true, 2 },
		}
	else
		options = {
			{ 22, function(r, p) Props.boulder(r, base, p, true) end, nil, 1 },
			{ 18, function(r, p) Props.cactus(r, base, p, true) end, true, 1 },
			{ 16, function(r, p) Props.jeep(r, turned, p) end, nil, 3 },
			{ 10, function(r, p) Props.signpost(r, base, p, true) end, true, 1 },
			{ 12, function(r, p) Props.barrels(r, twisted, p) end, true, 2 },
			{ 10, function(_, p) Props.woodpile(twisted, p) end, true, 2 },
			{ 8, function(r, p) Props.log(r, base, p) end, true, 3 },
			{ 8, function(_, p) Props.tnt(twisted, p) end, "tnt", 3 },
		}
	end
	local lvl = stage or Config.LEVELS_PER_WORLD
	local rowClass = if row and lvl < Config.OBSTACLE_COMBO_FROM then row.class else nil
	local function heavy(o): boolean
		return o[3] == nil
	end
	local function open(o, keepRow: boolean): boolean
		return o[4] <= lvl and (not keepRow or rowClass == nil or heavy(o) == rowClass)
	end
	local total = 0
	for _, o in options do
		total += o[1]
	end
	local roll = rng:NextNumber() * total
	local chosen
	local left = roll
	for _, o in options do
		left -= o[1]
		if left <= 0 then
			chosen = o
			break
		end
	end
	if chosen and not open(chosen, true) then
		-- холостая сборка: rng расходуется как у выбранного вида до #30
		local scrap = Instance.new("Model")
		chosen[2](rng, scrap)
		scrap:Destroy()
		-- замена — среди открытых видов (того же класса ряда, если он есть), по весам, своим Random
		local list = {}
		local sum = 0
		for _, o in options do
			if open(o, true) then
				table.insert(list, o)
				sum += o[1]
			end
		end
		if #list == 0 then
			for _, o in options do
				if open(o, false) then
					table.insert(list, o)
					sum += o[1]
				end
			end
		end
		local sub = Random.new(math.floor(roll * 1000003) + theme * 7919 + lvl)
		local pickRoll = sub:NextNumber() * sum
		chosen = list[#list]
		for _, o in list do
			pickRoll -= o[1]
			if pickRoll <= 0 then
				chosen = o
				break
			end
		end
		chosen[2](sub, m)
	elseif chosen then
		chosen[2](rng, m)
	end
	if chosen then
		-- Лёгкое можно разбить ракетой или на ускорении
		if chosen[3] then
			m:SetAttribute("Breakable", true)
		end
		if chosen[3] == "tnt" then
			m:SetAttribute("Explosive", true) -- взрывается от любого удара (Contacts.explode)
		end
		m:SetAttribute("Heavy", heavy(chosen)) -- класс для подсказок/аналитики (#30)
		local hx, hz = footprint(m, base)
		Props.obstacleShadow(m, base, hx, hz, heavy(chosen))
		if heavy(chosen) then
			Props.heavyMark(m, base, hx, hz)
		end
		if row and row.class == nil then
			row.class = heavy(chosen)
		end
	end
	m.Parent = parent
	return m
end


return Props
