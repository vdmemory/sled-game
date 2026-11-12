-- Декор обочин: деревья, постройки, фонари, ветряк, водонапорная башня, горы на горизонте,
-- трамплин, воздушный шар. Часть shared/Props (см. Props/init).

local Base = require(script.Parent.Base)

local Props = Base.Props
local Meshes = Base.Meshes
local part, deco, pick = Base.part, Base.deco, Base.pick
local SNOW, BLACK, GLASS = Base.SNOW, Base.BLACK, Base.GLASS

------------------------------------------------------------------ декор: деревья и постройки
-- Ёлка. Меш (#45): ярусы хвои с «лапами» + снег на ярусах, ствол — Part (3 детали вместо 7).
-- Все Random-вызовы — до выбора пути: раскладка куска (препятствия, монеты) не зависит от мешей.
function Props.pine(rng: Random, base: CFrame, parent: Instance)
	local h = rng:NextNumber(14, 28)
	local green = Color3.fromRGB(40, 100 + rng:NextInteger(0, 30), 65)
	local turns = { rng:NextNumber(0, 90), rng:NextNumber(0, 90), rng:NextNumber(0, 90) }
	local trunk = Meshes.vary(Color3.fromRGB(95, 65, 40), base.Position, 0.1)
	if Meshes.has("pine_foliage", "pine_snow") then
		local c = base * CFrame.Angles(0, math.rad(turns[1] * 4), 0)
		local s = Vector3.new(h * 0.62, h, h * 0.62)
		deco({ Size = Vector3.new(1.6, h * 0.3, 1.6), CFrame = c * CFrame.new(0, h * 0.15, 0), Material = Enum.Material.Wood, Color = trunk }, parent)
		Meshes.place("pine_foliage", c, s, { Color = Meshes.vary(green, base.Position, 0.12), CastShadow = true }, parent)
		Meshes.place("pine_snow", c, s, { Material = Enum.Material.Snow, Color = SNOW }, parent)
		return
	end
	deco({ Size = Vector3.new(2, h * 0.4, 2), CFrame = base * CFrame.new(0, h * 0.2, 0), Material = Enum.Material.Wood, Color = trunk }, parent)
	for tier = 0, 2 do
		local w = h * (0.6 - tier * 0.17)
		deco({
			Size = Vector3.new(w, h * 0.22, w),
			CFrame = base * CFrame.new(0, h * (0.45 + tier * 0.2), 0) * CFrame.Angles(0, math.rad(tier * 30 + turns[tier + 1]), 0),
			Color = green,
			CastShadow = true,
		}, parent)
		deco({ -- снег на каждом ярусе
			Size = Vector3.new(w * 0.85, h * 0.05, w * 0.85),
			CFrame = base * CFrame.new(0, h * (0.45 + tier * 0.2) + h * 0.12, 0) * CFrame.Angles(0, math.rad(tier * 30 + 15), 0),
			Material = Enum.Material.Snow,
			Color = SNOW,
		}, parent)
	end
end

-- «Акация»: изогнутый ствол и плоская широкая крона со снежной шапкой (как в оригинале)
function Props.acacia(rng: Random, base: CFrame, parent: Instance)
	local h = rng:NextNumber(10, 16)
	local lean = math.rad(rng:NextNumber(-15, 15))
	local trunk = Color3.fromRGB(150, 95, 65)
	deco({ Size = Vector3.new(1.4, h * 0.6, 1.4), CFrame = base * CFrame.new(0, h * 0.3, 0) * CFrame.Angles(0, 0, lean), Material = Enum.Material.Wood, Color = trunk }, parent)
	deco({ Size = Vector3.new(1.1, h * 0.45, 1.1), CFrame = base * CFrame.new(math.sin(lean) * -h * 0.3 + 1, h * 0.75, 0) * CFrame.Angles(0, 0, lean - 0.5), Material = Enum.Material.Wood, Color = trunk }, parent)
	local green = Color3.fromRGB(95 + rng:NextInteger(0, 30), 160 + rng:NextInteger(0, 25), 80)
	local w = rng:NextNumber(11, 16)
	for k = 0, 1 do
		deco({
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(w * (1 - k * 0.3), w * 0.32, w * (1 - k * 0.3)),
			CFrame = base * CFrame.new(rng:NextNumber(-1.5, 1.5), h + k * w * 0.12, rng:NextNumber(-1.5, 1.5)),
			Color = green:Lerp(Color3.new(1, 1, 1), k * 0.06),
			CastShadow = true,
		}, parent)
	end
	deco({ Shape = Enum.PartType.Ball, Size = Vector3.new(w * 0.85, w * 0.2, w * 0.85), CFrame = base * CFrame.new(0, h + w * 0.2, 0), Material = Enum.Material.Snow, Color = SNOW }, parent)
end

function Props.cabin(rng: Random, base: CFrame, side: number, parent: Instance)
	local wood = Color3.fromRGB(140, 90, 55)
	local w, d, h = 14, 12, 7
	local c = base * CFrame.Angles(0, if side > 0 then math.rad(-90) else math.rad(90), 0) -- фасадом к трассе
	deco({ Size = Vector3.new(w, h, d), CFrame = c * CFrame.new(0, h / 2, 0), Material = Enum.Material.WoodPlanks, Color = wood, CastShadow = true }, parent)
	for _, s in { -1, 1 } do
		deco({ Size = Vector3.new(w + 1.5, 4.5, d / 2 + 1), CFrame = c * CFrame.new(0, h + 2.25, s * (d / 4 + 0.5)) * CFrame.Angles(0, if s > 0 then 0 else math.pi, 0), Color = Color3.fromRGB(150, 60, 50) }, parent, "WedgePart")
		deco({ Size = Vector3.new(w + 1.7, 0.6, d / 2 + 1.2), CFrame = c * CFrame.new(0, h + 2.6, s * (d / 4 + 0.5)) * CFrame.Angles(s * math.rad(-40), 0, 0), Material = Enum.Material.Snow, Color = SNOW }, parent)
	end
	deco({ Size = Vector3.new(2.6, 4.5, 0.2), CFrame = c * CFrame.new(-3, 2.25, -d / 2 - 0.05), Color = Color3.fromRGB(90, 55, 35) }, parent)
	deco({ Size = Vector3.new(2.8, 2.2, 0.2), CFrame = c * CFrame.new(3, 4, -d / 2 - 0.05), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 210, 140) }, parent)
	if rng:NextNumber() < 0.6 then
		deco({ Size = Vector3.new(1.6, 4, 1.6), CFrame = c * CFrame.new(4, h + 3.5, 2), Material = Enum.Material.Brick, Color = Color3.fromRGB(150, 80, 70) }, parent)
	end
end

local HOUSE_COLORS = {
	Color3.fromRGB(245, 200, 70),
	Color3.fromRGB(230, 110, 80),
	Color3.fromRGB(120, 200, 180),
	Color3.fromRGB(235, 160, 90),
	Color3.fromRGB(240, 235, 220),
	Color3.fromRGB(150, 185, 230),
}
-- Невысокий городской дом с витриной, маркизой и окнами (фасадом к трассе)
function Props.house(rng: Random, base: CFrame, side: number, w: number, parent: Instance)
	local floors = rng:NextInteger(2, 3)
	local h = floors * 9
	local d = rng:NextNumber(16, 22)
	local col = pick(rng, HOUSE_COLORS)
	local out = side -- наружу от трассы
	deco({ Size = Vector3.new(d, h, w), CFrame = base * CFrame.new(out * d / 2, h / 2, 0), Color = col, CastShadow = true }, parent)
	-- Окна по этажам (фасад смотрит к трассе: x = 0)
	for f = 1, floors do
		local n = math.max(2, math.floor(w / 7))
		for k = 1, n do
			local z = -w / 2 + (k - 0.5) * (w / n)
			if f == 1 then
				deco({ Size = Vector3.new(0.3, 4, w / n - 1.5), CFrame = base * CFrame.new(-out * 0.1, 3, z), Material = Enum.Material.Glass, Color = Color3.fromRGB(150, 200, 235), Reflectance = 0.2 }, parent)
			else
				deco({ Size = Vector3.new(0.3, 3.4, 3), CFrame = base * CFrame.new(-out * 0.1, (f - 1) * 9 + 4.5, z), Material = Enum.Material.Glass, Color = GLASS, Reflectance = 0.25 }, parent)
			end
		end
	end
	-- Полосатая маркиза над витриной
	local stripes = 6
	local awning = pick(rng, { Color3.fromRGB(220, 60, 60), Color3.fromRGB(60, 140, 90), Color3.fromRGB(60, 110, 200) })
	for k = 0, stripes - 1 do
		deco({
			Size = Vector3.new(3.4, 0.25, w / stripes),
			CFrame = base * CFrame.new(-out * 1.5, 6.2, -w / 2 + (k + 0.5) * w / stripes) * CFrame.Angles(0, 0, out * math.rad(-20)),
			Color = if k % 2 == 0 then awning else Color3.new(1, 1, 1),
		}, parent)
	end
	deco({ Size = Vector3.new(d + 1, 1.2, w + 1), CFrame = base * CFrame.new(out * d / 2, h + 0.6, 0), Material = Enum.Material.Snow, Color = SNOW }, parent)
	if rng:NextNumber() < 0.5 then -- балкон
		deco({ Size = Vector3.new(2.5, 0.4, w * 0.6), CFrame = base * CFrame.new(-out * 1.2, 9.2, 0), Color = Color3.new(1, 1, 1) }, parent)
		deco({ Size = Vector3.new(0.2, 1.6, w * 0.6), CFrame = base * CFrame.new(-out * 2.3, 10.2, 0), Color = Color3.new(1, 1, 1), Transparency = 0.2 }, parent)
	end
end

-- Высотка на заднем плане
function Props.tower(rng: Random, base: CFrame, side: number, parent: Instance)
	local w, d, h = rng:NextNumber(18, 28), rng:NextNumber(18, 28), rng:NextNumber(60, 140)
	local glassy = rng:NextNumber() < 0.5
	deco({
		Size = Vector3.new(d, h, w),
		CFrame = base * CFrame.new(side * d / 2, h / 2, 0),
		Material = if glassy then Enum.Material.Glass else Enum.Material.SmoothPlastic,
		Color = if glassy then Color3.fromRGB(130, 175, 220) else pick(rng, { Color3.fromRGB(150, 155, 170), Color3.fromRGB(190, 190, 200), Color3.fromRGB(120, 130, 150) }),
		Reflectance = if glassy then 0.25 else 0,
		CastShadow = true,
	}, parent)
	for f = 1, math.floor(h / 10) do
		deco({ Size = Vector3.new(0.3, 3, w - 3), CFrame = base * CFrame.new(-side * 0.1, f * 10 - 4, 0), Material = Enum.Material.Glass, Color = GLASS, Reflectance = 0.3 }, parent)
	end
	deco({ Size = Vector3.new(d + 1, 1.2, w + 1), CFrame = base * CFrame.new(side * d / 2, h + 0.6, 0), Material = Enum.Material.Snow, Color = SNOW }, parent)
end

function Props.streetLamp(base: CFrame, side: number, parent: Instance)
	local pole = Color3.fromRGB(60, 65, 80)
	deco({ Size = Vector3.new(0.7, 16, 0.7), CFrame = base * CFrame.new(0, 8, 0), Material = Enum.Material.Metal, Color = pole }, parent)
	deco({ Size = Vector3.new(4, 0.5, 0.5), CFrame = base * CFrame.new(-side * 2, 16, 0), Material = Enum.Material.Metal, Color = pole }, parent)
	deco({ Size = Vector3.new(1.6, 0.8, 1.2), CFrame = base * CFrame.new(-side * 4, 15.7, 0), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 240, 200) }, parent)
end

-- Палатка + костёр (каньон)
function Props.camp(rng: Random, base: CFrame, parent: Instance)
	local tent = pick(rng, { Color3.fromRGB(240, 140, 50), Color3.fromRGB(70, 120, 200), Color3.fromRGB(200, 70, 60), Color3.fromRGB(230, 190, 80) })
	local c = base * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	for _, s in { -1, 1 } do
		deco({ Size = Vector3.new(8, 6, 4), CFrame = c * CFrame.new(0, 3, s * 2) * CFrame.Angles(0, if s > 0 then 0 else math.pi, 0), Color = tent, CastShadow = true }, parent, "WedgePart")
	end
	deco({ Size = Vector3.new(0.3, 3.5, 2.4), CFrame = c * CFrame.new(-4.05, 1.75, 0), Color = tent:Lerp(Color3.new(0, 0, 0), 0.4) }, parent)
	-- Костёр рядом
	local fire = c * CFrame.new(-9, 0, 3)
	for k = 0, 2 do
		deco({ Size = Vector3.new(3, 0.6, 0.6), CFrame = fire * CFrame.new(0, 0.4, 0) * CFrame.Angles(0, math.rad(k * 60), 0), Material = Enum.Material.Wood, Color = Color3.fromRGB(110, 70, 40) }, parent)
	end
	for k = 0, 5 do
		deco({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, CFrame = fire * CFrame.new(math.cos(k) * 1.8, 0.3, math.sin(k) * 1.8), Material = Enum.Material.Slate, Color = Color3.fromRGB(120, 120, 125) }, parent)
	end
	local flame = deco({ Size = Vector3.new(1.2, 1.8, 1.2), CFrame = fire * CFrame.new(0, 1.4, 0) * CFrame.Angles(0, 0.5, 0), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 140, 40) }, parent)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 160, 80)
	light.Range = 14
	light.Brightness = 1.5
	light.Parent = flame
end

-- Ветряк на ажурной вышке (каньон)
function Props.windmill(base: CFrame, side: number, parent: Instance)
	local metal = Color3.fromRGB(110, 90, 75)
	local h = 30
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			deco({ Size = Vector3.new(0.6, h, 0.6), CFrame = base * CFrame.new(x * 2, h / 2, z * 2) * CFrame.Angles(z * math.rad(-4), 0, x * math.rad(4)), Material = Enum.Material.Metal, Color = metal }, parent)
		end
	end
	for k = 1, 4 do
		deco({ Size = Vector3.new(4.6 - k * 0.6, 0.3, 0.3), CFrame = base * CFrame.new(0, k * 6, -2 + k * 0.25) * CFrame.Angles(0, 0, math.rad(if k % 2 == 0 then 30 else -30)), Material = Enum.Material.Metal, Color = metal }, parent)
	end
	local hub = base * CFrame.new(0, h + 1, 0) * CFrame.Angles(0, if side > 0 then math.rad(-90) else math.rad(90), 0)
	deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 10, 10), CFrame = hub * CFrame.new(0, 0, -1) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.new(1, 1, 1) }, parent)
	deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.7, 10.8, 10.8), CFrame = hub * CFrame.new(0, 0, -0.9) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(210, 50, 50) }, parent)
	for k = 0, 5 do
		deco({ Size = Vector3.new(0.4, 4.6, 1), CFrame = hub * CFrame.new(0, 0, -1.3) * CFrame.Angles(0, 0, math.rad(k * 60)) * CFrame.new(0, 2.6, 0), Color = Color3.fromRGB(240, 240, 240) }, parent)
	end
	deco({ Size = Vector3.new(1, 1.6, 6), CFrame = hub * CFrame.new(0, 0, 2.5), Color = metal }, parent) -- хвост
end

-- Водонапорная башня (каньон / лес)
function Props.waterTower(base: CFrame, parent: Instance)
	local wood = Color3.fromRGB(150, 110, 75)
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			deco({ Size = Vector3.new(0.8, 16, 0.8), CFrame = base * CFrame.new(x * 3.5, 8, z * 3.5), Material = Enum.Material.Wood, Color = wood }, parent)
		end
	end
	deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(8, 10, 10), CFrame = base * CFrame.new(0, 20, 0) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.WoodPlanks, Color = wood, CastShadow = true }, parent)
	deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.6, 10.6, 10.6), CFrame = base * CFrame.new(0, 24.6, 0) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Snow, Color = SNOW }, parent)
end

------------------------------------------------------------------ горы на горизонте
-- Гора на горизонте. Меш (#45): три вершины с хребтами и рваной снежной шапкой (2 детали, как было,
-- но силуэт горы вместо повёрнутого куба). sandy — каньон: песчаник, снег тот же.
function Props.mountain(rng: Random, base: CFrame, sandy: boolean, parent: Instance, tint: Color3?)
	local s = rng:NextNumber(90, 170)
	local yaw = rng:NextNumber(0, math.pi)
	local rockMat = if sandy then Enum.Material.Sandstone else Enum.Material.Slate
	local rockCol = Meshes.vary(tint or (if sandy then Color3.fromRGB(205, 145, 100) else Color3.fromRGB(125, 140, 165)), base.Position, 0.08)
	if Meshes.has("mountain_rock", "mountain_snow") then
		local c = base * CFrame.new(0, -s * 0.06, 0) * CFrame.Angles(0, yaw * 2, 0)
		local sc = Vector3.new(s * 0.85, s * 0.8, s * 0.85)
		Meshes.place("mountain_rock", c, sc, { Material = rockMat, Color = rockCol }, parent)
		Meshes.place("mountain_snow", c, sc, { Material = Enum.Material.Snow, Color = SNOW }, parent)
		return
	end
	local rot = CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45))
	deco({
		Size = Vector3.one * s,
		CFrame = base * CFrame.new(0, -s * 0.15, 0) * rot,
		Material = rockMat,
		Color = rockCol,
	}, parent)
	local peak = s * 0.866 - s * 0.15
	local cs = s * 0.32
	deco({
		Size = Vector3.one * cs,
		CFrame = base * CFrame.new(0, peak - cs * 0.866 + 0.5, 0) * rot,
		Material = Enum.Material.Snow,
		Color = SNOW,
	}, parent)
end

-- Слоистая столовая гора каньона. Меш (#45): 4 неровных слоя с оврагами и полками (1 деталь
-- вместо 3–8). Random-вызовы слоёв делаются и в пути меша — раскладка куска та же.
function Props.mesa(rng: Random, base: CFrame, side: number, parent: Instance)
	local h = rng:NextNumber(40, 110)
	local layers = {}
	local y = 0
	while y < h do
		local lh = rng:NextNumber(12, 24)
		local w = rng:NextNumber(26, 40) - #layers * 2
		local d = rng:NextNumber(24, 36)
		local turn = rng:NextNumber(-0.15, 0.15)
		table.insert(layers, { y = y, lh = lh, w = w, d = d, turn = turn })
		y += lh
	end
	local sand = Meshes.vary(Color3.fromRGB(225, 160, 110), base.Position, 0.07)
	if Meshes.has("mesa") then
		local w0 = layers[1].w
		local c = base * CFrame.new(side * (w0 / 2 + 2), -1, 0) * CFrame.Angles(0, math.pi / 2 + layers[1].turn * 3, 0)
		Meshes.place("mesa", c, Vector3.new(w0 * 0.55, y, layers[1].d * 0.6), { Material = Enum.Material.Sandstone, Color = sand, CastShadow = true }, parent)
		return
	end
	for k, l in layers do
		local shade = 0.85 + ((k - 1) % 2) * 0.12
		deco({
			Size = Vector3.new(l.w, l.lh, l.d),
			CFrame = base * CFrame.new(side * (l.w / 2 + (k - 1) * 1.5), l.y + l.lh / 2, 0) * CFrame.Angles(0, l.turn, 0),
			Material = Enum.Material.Sandstone,
			Color = Color3.new(sand.R * shade, sand.G * shade, sand.B * shade),
			CastShadow = true,
		}, parent)
	end
	deco({ Size = Vector3.new(22, 1.2, 26), CFrame = base * CFrame.new(side * (11 + #layers * 1.5), y + 0.6, 0), Material = Enum.Material.Snow, Color = SNOW }, parent)
end

------------------------------------------------------------------ трамплин: жёлтый с чёрными шевронами
function Props.ramp(cf: CFrame, width: number, length: number, height: number, parent: Instance): BasePart
	-- WedgePart: низкий край спереди (-Z); разворачиваем, чтобы въезжать на низкий край
	local ramp = part("WedgePart", {
		Name = "Ramp",
		Size = Vector3.new(width, height, length),
		CFrame = cf * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, math.pi, 0),
		Color = Color3.fromRGB(250, 200, 40),
	}, parent)
	-- Шевроны на наклонной поверхности
	local slope = math.atan2(height, length)
	local surface = cf * CFrame.new(0, height / 2 + 0.06, 0) * CFrame.Angles(slope, 0, 0)
	for k = -1, 1 do
		for _, s in { -1, 1 } do
			deco({
				Size = Vector3.new(width * 0.32, 0.12, 1.4),
				CFrame = surface * CFrame.new(s * width * 0.14, 0, k * length * 0.28) * CFrame.Angles(0, s * math.rad(-30), 0),
				Color = BLACK,
			}, parent)
		end
	end
	return ramp
end

-- Воздушный шар в небе
function Props.balloon(rng: Random, base: CFrame, parent: Instance)
	local cols = { Color3.fromRGB(230, 70, 60), Color3.fromRGB(250, 200, 50), Color3.fromRGB(80, 160, 230), Color3.fromRGB(110, 200, 120) }
	local c1, c2 = pick(rng, cols), pick(rng, cols)
	deco({ Shape = Enum.PartType.Ball, Size = Vector3.new(14, 16, 14), CFrame = base * CFrame.new(0, 12, 0), Color = c1 }, parent)
	deco({ Shape = Enum.PartType.Ball, Size = Vector3.new(14.4, 6, 14.4), CFrame = base * CFrame.new(0, 13, 0), Color = c2 }, parent)
	deco({ Size = Vector3.new(3, 2.4, 3), CFrame = base * CFrame.new(0, 0, 0), Color = Color3.fromRGB(150, 105, 60), Material = Enum.Material.Wood }, parent)
end


------------------------------------------------------------------ Обвязка трассы (#70, референсы 2026-11-11)
local FENCE_WOOD = Color3.fromRGB(176, 122, 72)
local FENCE_SNOW = Color3.fromRGB(250, 252, 255)

-- Деревянный заборчик вдоль трассы: столбики со снежной «шапкой»-шаром и две жерди. cf — начало
-- куска (−Z вдоль трассы), x — смещение от оси, len — длина, step — шаг столбиков. Без Random.
function Props.fenceRun(cf: CFrame, x: number, len: number, step: number, parent: Instance)
	local n = math.max(1, math.floor(len / step))
	for k = 0, n do
		local z = -len * k / n
		deco({ Size = Vector3.new(0.9, 3.4, 0.9), CFrame = cf * CFrame.new(x, 1.5, z), Material = Enum.Material.Wood, Color = FENCE_WOOD }, parent)
		deco({ Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 0.8, 1.4), CFrame = cf * CFrame.new(x, 3.35, z), Material = Enum.Material.Snow, Color = FENCE_SNOW }, parent)
	end
	for _, y in { 1.3, 2.5 } do
		deco({ Size = Vector3.new(0.45, 0.45, len), CFrame = cf * CFrame.new(x, y, -len / 2), Material = Enum.Material.Wood, Color = FENCE_WOOD:Lerp(Color3.new(0, 0, 0), 0.12) }, parent)
	end
	deco({ Size = Vector3.new(0.7, 0.25, len), CFrame = cf * CFrame.new(x, 2.85, -len / 2), Material = Enum.Material.Snow, Color = FENCE_SNOW }, parent)
end

-- Подвесной мост из досок и каната (декор над пропастью). a, b — точки опор (центр настила),
-- width — ширина настила; провис — SAG от длины. Без Random.
function Props.ropeBridge(a: Vector3, b: Vector3, width: number, parent: Instance)
	local d = b - a
	local flat = Vector3.new(d.X, 0, d.Z)
	if flat.Magnitude < 1 then
		return
	end
	local frame = CFrame.lookAt(a, a + flat.Unit)
	local len = d.Magnitude
	local sag = len * 0.08
	local n = math.max(4, math.floor(len / 2.4))
	local function at(t: number): Vector3
		return a + d * t - Vector3.new(0, sag * 4 * t * (1 - t), 0)
	end
	for k = 0, n do
		local t = k / n
		local p = at(t)
		local cfp = CFrame.lookAt(p, p + flat.Unit)
		deco({ Size = Vector3.new(width + (k % 3) * 0.4, 0.4, 1.7), CFrame = cfp * CFrame.Angles(0, 0, (k % 2 - 0.5) * 0.06), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(200, 150, 100):Lerp(Color3.fromRGB(150, 100, 60), k % 2 * 0.4) }, parent)
	end
	-- канаты-перила и подвесы
	for _, sx in { -1, 1 } do
		local prev = at(0) + frame.RightVector * sx * (width / 2) + Vector3.new(0, 3, 0)
		for k = 1, n do
			local t = k / n
			local p = at(t) + frame.RightVector * sx * (width / 2) + Vector3.new(0, 3 + sag * 4 * t * (1 - t) * 0.5, 0)
			local mid, dd = (prev + p) / 2, p - prev
			deco({ Size = Vector3.new(0.25, 0.25, dd.Magnitude + 0.1), CFrame = CFrame.lookAt(mid, p), Color = Color3.fromRGB(215, 180, 120) }, parent)
			if k % 2 == 0 then
				local deck = at(t) + frame.RightVector * sx * (width / 2)
				deco({ Size = Vector3.new(0.15, (p - deck).Magnitude, 0.15), CFrame = CFrame.lookAt((p + deck) / 2, p) * CFrame.Angles(math.rad(90), 0, 0), Color = Color3.fromRGB(215, 180, 120) }, parent)
			end
			prev = p
		end
		-- столбы на концах с канатными кольцами
		for _, e in { a, b } do
			local post = e + frame.RightVector * sx * (width / 2 + 0.6)
			deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(9, 1.3, 1.3), CFrame = CFrame.new(post + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Wood, Color = FENCE_WOOD }, parent)
			deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 1.7, 1.7), CFrame = CFrame.new(post + Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(215, 180, 120) }, parent)
			deco({ Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 0.8, 1.6), CFrame = CFrame.new(post + Vector3.new(0, 5.6, 0)), Material = Enum.Material.Snow, Color = FENCE_SNOW }, parent)
		end
	end
end

return Props
