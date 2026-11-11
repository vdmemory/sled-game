-- Препятствия: уличные (гидрант, знак, барьер, остановка, конусы, бочки), природные (снеговик,
-- валун, кактус, указатель, бревно, поленница) и выбор препятствия по миру (Props.obstacle).
-- Часть shared/Props (см. Props/init).

local Base = require(script.Parent.Base)

local Props = Base.Props
local Meshes = Base.Meshes
local part, deco, pick, label, wheels = Base.part, Base.deco, Base.pick, Base.label, Base.wheels
local SNOW, BLACK, GLASS = Base.SNOW, Base.BLACK, Base.GLASS

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
function Props.snowman(rng: Random, base: CFrame, parent: Instance)
	local face = base * CFrame.Angles(0, math.rad(rng:NextNumber(-25, 25)), 0)
	local rs, ys = { 3.4, 2.5, 1.8 }, { 3.2, 8.2, 12.1 }
	for k = 1, 3 do
		part("Part", { Shape = Enum.PartType.Ball, Size = Vector3.one * rs[k] * 2, CFrame = face * CFrame.new(0, ys[k], 0), Material = Enum.Material.Snow, Color = SNOW }, parent)
	end
	-- Пуговицы и глаза
	for _, y in { 7.4, 8.6 } do
		deco({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.6, CFrame = face * CFrame.new(0, y, -2.4), Color = BLACK }, parent)
	end
	for _, x in { -0.6, 0.6 } do
		deco({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.45, CFrame = face * CFrame.new(x, 12.6, -1.6), Color = BLACK }, parent)
	end
	-- Морковка
	deco({ Size = Vector3.new(0.5, 0.5, 2.2), CFrame = face * CFrame.new(0, 12.1, -2.6), Color = Color3.fromRGB(255, 130, 30) }, parent)
	-- Шарф
	local scarf = pick(rng, { Color3.fromRGB(220, 50, 50), Color3.fromRGB(60, 120, 220), Color3.fromRGB(60, 170, 90) })
	deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.9, 3.9, 3.9), CFrame = face * CFrame.new(0, 10.4, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = scarf }, parent)
	deco({ Size = Vector3.new(0.9, 2.4, 0.3), CFrame = face * CFrame.new(1, 9.3, -1.9) * CFrame.Angles(0, 0, math.rad(-12)), Color = scarf }, parent)
	-- Шляпа-цилиндр
	deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 3.2, 3.2), CFrame = face * CFrame.new(0, 13.7, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = BLACK }, parent)
	deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 2.2, 2.2), CFrame = face * CFrame.new(0, 14.8, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = BLACK }, parent)
	-- Руки-веточки
	for _, side in { -1, 1 } do
		deco({ Size = Vector3.new(3, 0.3, 0.3), CFrame = face * CFrame.new(side * 3.4, 9, 0) * CFrame.Angles(0, 0, math.rad(side * 25)), Color = Color3.fromRGB(110, 75, 45) }, parent)
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
-- Грузовик-фургон
function Props.truck(rng: Random, base: CFrame, parent: Instance)
	local cab = pick(rng, { Color3.fromRGB(60, 110, 200), Color3.fromRGB(210, 60, 50), Color3.fromRGB(240, 240, 240) })
	part("Part", { Size = Vector3.new(7, 8, 14), CFrame = base * CFrame.new(0, 5.6, 2.5), Color = Color3.fromRGB(235, 235, 240) }, parent) -- будка
	part("Part", { Size = Vector3.new(6.8, 5.4, 5), CFrame = base * CFrame.new(0, 3.9, -7), Color = cab }, parent)
	deco({ Size = Vector3.new(6, 2, 0.3), CFrame = base * CFrame.new(0, 5, -9.55), Material = Enum.Material.Glass, Color = GLASS, Reflectance = 0.3 }, parent)
	deco({ Size = Vector3.new(6.9, 1.8, 3.2), CFrame = base * CFrame.new(0, 5, -7.2), Material = Enum.Material.Glass, Color = GLASS }, parent)
	for _, side in { -1, 1 } do
		deco({ Size = Vector3.new(0.15, 2.4, 10), CFrame = base * CFrame.new(side * 3.55, 6, 2.5), Color = cab }, parent) -- полоса на будке
	end
	deco({ Size = Vector3.new(6.8, 0.5, 13.8), CFrame = base * CFrame.new(0, 9.85, 2.5), Material = Enum.Material.Snow, Color = SNOW }, parent)
	wheels(base, 3.4, { -6.5, 4, 7.5 }, 1.5, parent)
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

-- Бочки (по 2–3, иногда одна на боку)
function Props.barrels(rng: Random, base: CFrame, parent: Instance)
	local col = pick(rng, { Color3.fromRGB(200, 60, 45), Color3.fromRGB(60, 110, 190), Color3.fromRGB(80, 140, 80) })
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
-- Возвращает модель-препятствие (все детали потом получают тег Obstacle)
function Props.obstacle(theme: number, rng: Random, base: CFrame, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = "Obstacle"
	-- Машины стоят вдоль или поперёк; остальное слегка развёрнуто
	-- Машины стоят вдоль трассы (носом вверх или вниз): поперёк грузовик перекрывал 2–3 полосы сразу
	local turned = base * CFrame.Angles(0, if rng:NextNumber() < 0.5 then 0 else math.pi, 0)
	local twisted = base * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0)
	-- Взвешенный выбор: { вес, функция }
	local options
	if theme == 1 then
		options = {
			{ 24, function() Props.snowman(rng, base, m) end , true },
			{ 18, function() Props.boulder(rng, base, m) end },
			{ 14, function() Props.log(rng, base, m) end , true },
			{ 10, function() Props.woodpile(twisted, m) end , true },
			{ 10, function() Props.barrier(twisted, m) end , true },
			{ 12, function() Props.car(rng, turned, m) end },
			{ 6, function() Props.signpost(rng, base, m, true) end , true },
			{ 6, function() Props.barrels(rng, twisted, m) end , true },
		}
	elseif theme == 2 then
		options = {
			{ 24, function() Props.car(rng, turned, m) end },
			{ 10, function() Props.van(rng, turned, m, rng:NextNumber() < 0.5) end },
			{ 8, function() Props.truck(rng, turned, m) end },
			{ 8, function() Props.busStop(twisted, m) end },
			{ 10, function() Props.hydrant(base, m) end , true },
			{ 10, function() Props.stopSign(base, m) end , true },
			{ 12, function() Props.cones(rng, twisted, m) end , true },
			{ 8, function() Props.barrier(twisted, m) end , true },
			{ 10, function() Props.barrels(rng, twisted, m) end , true },
			{ 8, function() Props.tnt(twisted, m) end , "tnt" },
		}
	elseif theme == 4 then
		options = {
			{ 24, function() Props.iceBlock(rng, base, m) end , true },
			{ 18, function() Props.stalagmite(rng, base, m) end },
			{ 14, function() Props.snowman(rng, base, m) end , true },
			{ 12, function() Props.boulder(rng, base, m) end },
			{ 10, function() Props.barrels(rng, twisted, m) end , true },
			{ 8, function() Props.car(rng, turned, m) end },
		}
	elseif theme == 5 then
		options = {
			{ 22, function() Props.snowman(rng, base, m) end , true },
			{ 18, function() Props.crates(rng, twisted, m) end , true },
			{ 16, function() Props.iceBlock(rng, base, m) end , true },
			{ 12, function() Props.log(rng, base, m) end , true },
			{ 10, function() Props.boulder(rng, base, m) end },
			{ 8, function() Props.car(rng, turned, m) end },
		}
	elseif theme == 6 then
		options = {
			{ 26, function() Props.lavaRock(rng, base, m) end },
			{ 16, function() Props.basalt(rng, base, m) end },
			{ 14, function() Props.log(rng, base, m) end , true },
			{ 12, function() Props.barrels(rng, twisted, m) end , true },
			{ 10, function() Props.crates(rng, twisted, m) end , true },
			{ 8, function() Props.tnt(twisted, m) end , "tnt" },
			{ 8, function() Props.jeep(rng, turned, m) end },
		}
	elseif theme == 7 then
		options = {
			{ 22, function() Props.gumdrop(rng, base, m) end },
			{ 18, function() Props.cupcake(rng, base, m) end , true },
			{ 16, function() Props.chocolate(rng, base, m) end , true },
			{ 14, function() Props.candyCane(rng, base, m, 7, true) end , true },
			{ 10, function() Props.snowman(rng, base, m) end , true },
		}
	else
		options = {
			{ 22, function() Props.boulder(rng, base, m, true) end },
			{ 18, function() Props.cactus(rng, base, m, true) end , true },
			{ 16, function() Props.jeep(rng, turned, m) end },
			{ 10, function() Props.signpost(rng, base, m, true) end , true },
			{ 12, function() Props.barrels(rng, twisted, m) end , true },
			{ 10, function() Props.woodpile(twisted, m) end , true },
			{ 8, function() Props.log(rng, base, m) end , true },
			{ 8, function() Props.tnt(twisted, m) end , "tnt" },
		}
	end
	local total = 0
	for _, o in options do
		total += o[1]
	end
	local roll = rng:NextNumber() * total
	for _, o in options do
		roll -= o[1]
		if roll <= 0 then
			o[2]()
			-- Лёгкое можно разбить ракетой или на ускорении (o[3] = true)
			if o[3] then
				m:SetAttribute("Breakable", true)
			end
			if o[3] == "tnt" then
				m:SetAttribute("Explosive", true) -- взрывается от любого удара (Contacts.explode)
			end
			break
		end
	end
	m.Parent = parent
	return m
end


return Props
