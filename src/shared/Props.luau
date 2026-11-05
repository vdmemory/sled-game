-- Модели для трассы в стилизованном low-poly духе: препятствия и декор трёх миров.
-- Всё собирается из примитивов Roblox (без загрузки ассетов), поэтому работает с автодеплоем.

local Props = {}

------------------------------------------------------------------ helpers
local function part(className: string, props: { [string]: any }, parent: Instance?): BasePart
	local p = Instance.new(className) :: BasePart
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	-- Шар с неравными размерами Roblox рисует круглым — делаем настоящий эллипсоид через меш
	if props.Shape == Enum.PartType.Ball then
		local s = p.Size
		if math.abs(s.X - s.Y) > 0.01 or math.abs(s.Y - s.Z) > 0.01 then
			p.Shape = Enum.PartType.Block
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = p
		end
	end
	if parent then
		p.Parent = parent
	end
	return p
end
Props.part = part

-- Декоративная деталь: не мешает физике и лучам
local function deco(props: { [string]: any }, parent: Instance, className: string?): BasePart
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	if props.CastShadow == nil then
		props.CastShadow = false
	end
	return part(className or "Part", props, parent)
end
Props.deco = deco

local SNOW = Color3.fromRGB(250, 252, 255)
local BLACK = Color3.fromRGB(35, 35, 40)
local GLASS = Color3.fromRGB(60, 90, 130)

local function pick<T>(rng: Random, list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

-- Надпись на грани детали
local function label(p: BasePart, face: Enum.NormalId, text: string, color: Color3, bg: Color3?)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.CanvasSize = Vector2.new(200, 200)
	sg.LightInfluence = 1
	sg.Parent = p
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = if bg then 0 else 1
	t.BackgroundColor3 = bg or Color3.new()
	t.TextColor3 = color
	t.TextScaled = true
	t.Font = Enum.Font.GothamBlack
	t.Text = text
	t.Parent = sg
end

------------------------------------------------------------------ транспорт
local CAR_COLORS = {
	Color3.fromRGB(215, 55, 50),
	Color3.fromRGB(55, 110, 200),
	Color3.fromRGB(245, 190, 50),
	Color3.fromRGB(235, 235, 240),
	Color3.fromRGB(90, 170, 110),
	Color3.fromRGB(70, 75, 90),
}

local function wheels(base: CFrame, halfW: number, zs: { number }, r: number, parent: Instance)
	for _, z in zs do
		for _, side in { -1, 1 } do
			part("Part", {
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1.1, r * 2, r * 2),
				CFrame = base * CFrame.new(side * halfW, r, z),
				Color = BLACK,
			}, parent)
			deco({ -- колпак
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1.2, r, r),
				CFrame = base * CFrame.new(side * halfW, r, z),
				Color = Color3.fromRGB(190, 195, 205),
			}, parent)
		end
	end
end

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

-- Дорожный барьер в красно-белую полоску
function Props.barrier(base: CFrame, parent: Instance)
	for _, x in { -3.6, 3.6 } do
		part("Part", { Size = Vector3.new(0.4, 3.2, 1.6), CFrame = base * CFrame.new(x, 1.6, 0), Color = Color3.fromRGB(120, 120, 130) }, parent)
	end
	for i = 0, 5 do
		part("Part", {
			Size = Vector3.new(1.4, 1.1, 0.4),
			CFrame = base * CFrame.new(-3.5 + i * 1.4, 2.8, 0),
			Color = if i % 2 == 0 then Color3.fromRGB(220, 40, 40) else Color3.new(1, 1, 1),
		}, parent)
	end
	deco({ Size = Vector3.new(8.4, 0.3, 0.6), CFrame = base * CFrame.new(0, 3.45, 0), Material = Enum.Material.Snow, Color = SNOW }, parent)
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

-- Низкополигональный валун: 2–3 повёрнутых блока разных оттенков
function Props.boulder(rng: Random, base: CFrame, parent: Instance, sandy: boolean?, scale: number?, collide: boolean?)
	local s = (scale or 1) * rng:NextNumber(4.5, 6.5)
	local baseColor = if sandy then Color3.fromRGB(205, 140, 95) else Color3.fromRGB(125, 130, 145)
	local maker = if collide == false then deco else function(props, p)
		return part("Part", props, p)
	end
	for k = 1, 3 do
		local sz = s * (1 - (k - 1) * 0.22)
		maker({
			Size = Vector3.new(sz * 1.2, sz * 0.9, sz),
			CFrame = base * CFrame.new(rng:NextNumber(-1, 1) * s * 0.3, sz * 0.35 + (k - 1) * s * 0.18, rng:NextNumber(-1, 1) * s * 0.3)
				* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, math.pi), rng:NextNumber(-0.4, 0.4)),
			Material = if sandy then Enum.Material.Sandstone else Enum.Material.Slate,
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

-- Дорожные конусы (2–3 штуки)
function Props.cones(rng: Random, base: CFrame, parent: Instance)
	for k = 1, rng:NextInteger(2, 3) do
		local c = base * CFrame.new((k - 2) * 2.6, 0, rng:NextNumber(-1, 1))
		part("Part", { Size = Vector3.new(2.4, 0.4, 2.4), CFrame = c * CFrame.new(0, 0.2, 0), Color = Color3.fromRGB(240, 110, 30) }, parent)
		for t = 0, 3 do
			local w = 1.6 - t * 0.35
			part("Part", {
				Size = Vector3.new(w, 0.9, w),
				CFrame = c * CFrame.new(0, 0.85 + t * 0.9, 0),
				Color = if t == 1 then Color3.new(1, 1, 1) else Color3.fromRGB(245, 120, 35),
			}, parent)
		end
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
			break
		end
	end
	m.Parent = parent
	return m
end

------------------------------------------------------------------ декор: деревья и постройки
function Props.pine(rng: Random, base: CFrame, parent: Instance)
	local h = rng:NextNumber(14, 28)
	deco({ Size = Vector3.new(2, h * 0.4, 2), CFrame = base * CFrame.new(0, h * 0.2, 0), Material = Enum.Material.Wood, Color = Color3.fromRGB(95, 65, 40) }, parent)
	local green = Color3.fromRGB(40, 100 + rng:NextInteger(0, 30), 65)
	for tier = 0, 2 do
		local w = h * (0.6 - tier * 0.17)
		deco({
			Size = Vector3.new(w, h * 0.22, w),
			CFrame = base * CFrame.new(0, h * (0.45 + tier * 0.2), 0) * CFrame.Angles(0, math.rad(tier * 30 + rng:NextNumber(0, 90)), 0),
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
function Props.mountain(rng: Random, base: CFrame, sandy: boolean, parent: Instance, tint: Color3?)
	local s = rng:NextNumber(90, 170)
	local rot = CFrame.Angles(0, rng:NextNumber(0, math.pi), 0) * CFrame.Angles(math.rad(45), 0, math.rad(45))
	deco({
		Size = Vector3.one * s,
		CFrame = base * CFrame.new(0, -s * 0.15, 0) * rot,
		Material = if sandy then Enum.Material.Sandstone else Enum.Material.Slate,
		Color = tint or (if sandy then Color3.fromRGB(205, 145, 100) else Color3.fromRGB(125, 140, 165)),
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

-- Слоистая столовая гора каньона
function Props.mesa(rng: Random, base: CFrame, side: number, parent: Instance)
	local h = rng:NextNumber(40, 110)
	local y, layer = 0, 0
	while y < h do
		local lh = rng:NextNumber(12, 24)
		local shade = 0.85 + (layer % 2) * 0.12
		local w = rng:NextNumber(26, 40) - layer * 2
		deco({
			Size = Vector3.new(w, lh, rng:NextNumber(24, 36)),
			CFrame = base * CFrame.new(side * (w / 2 + layer * 1.5), y + lh / 2, 0) * CFrame.Angles(0, rng:NextNumber(-0.15, 0.15), 0),
			Material = Enum.Material.Sandstone,
			Color = Color3.fromRGB(math.floor(225 * shade), math.floor(160 * shade), math.floor(110 * shade)),
			CastShadow = true,
		}, parent)
		y += lh
		layer += 1
	end
	deco({ Size = Vector3.new(22, 1.2, 26), CFrame = base * CFrame.new(side * (11 + layer * 1.5), y + 0.6, 0), Material = Enum.Material.Snow, Color = SNOW }, parent)
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

-- Воздушный шар в небе
function Props.balloon(rng: Random, base: CFrame, parent: Instance)
	local cols = { Color3.fromRGB(230, 70, 60), Color3.fromRGB(250, 200, 50), Color3.fromRGB(80, 160, 230), Color3.fromRGB(110, 200, 120) }
	local c1, c2 = pick(rng, cols), pick(rng, cols)
	deco({ Shape = Enum.PartType.Ball, Size = Vector3.new(14, 16, 14), CFrame = base * CFrame.new(0, 12, 0), Color = c1 }, parent)
	deco({ Shape = Enum.PartType.Ball, Size = Vector3.new(14.4, 6, 14.4), CFrame = base * CFrame.new(0, 13, 0), Color = c2 }, parent)
	deco({ Size = Vector3.new(3, 2.4, 3), CFrame = base * CFrame.new(0, 0, 0), Color = Color3.fromRGB(150, 105, 60), Material = Enum.Material.Wood }, parent)
end

------------------------------------------------------------------ Мир 4: Ледяные пещеры
local ICE = Color3.fromRGB(170, 225, 250)
local ICE_DEEP = Color3.fromRGB(90, 170, 230)
-- Ледяная глыба (препятствие, разбивается)
function Props.iceBlock(rng: Random, base: CFrame, parent: Instance)
	local s = rng:NextNumber(4.5, 6)
	part("Part", { Size = Vector3.new(s * 1.2, s, s), CFrame = base * CFrame.new(0, s / 2, 0) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0), Material = Enum.Material.Glass, Color = ICE, Transparency = 0.25 }, parent)
	deco({ Size = Vector3.new(s * 0.7, s * 0.6, s * 0.55), CFrame = base * CFrame.new(0, s / 2, 0), Material = Enum.Material.Ice, Color = ICE_DEEP }, parent)
	deco({ Size = Vector3.new(s * 1.1, 0.4, s * 0.9), CFrame = base * CFrame.new(0, s + 0.1, 0), Material = Enum.Material.Snow, Color = SNOW }, parent)
end
-- Сталагмит: сужающаяся ледяная колонна
function Props.stalagmite(rng: Random, base: CFrame, parent: Instance, collide: boolean?)
	local h = rng:NextNumber(7, 11)
	local maker = if collide == false then deco else function(pr, pa) return part("Part", pr, pa) end
	for k = 0, 3 do
		local w = (4 - k) * 0.9
		maker({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(h / 4 + 0.2, w, w), CFrame = base * CFrame.new(0, h / 8 + k * h / 4, 0) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Ice, Color = ICE:Lerp(ICE_DEEP, k * 0.2) }, parent)
	end
end
-- Друза кристаллов: светящиеся остроконечные призмы
function Props.crystalCluster(rng: Random, base: CFrame, parent: Instance)
	local col = pick(rng, { Color3.fromRGB(120, 220, 255), Color3.fromRGB(190, 140, 255), Color3.fromRGB(140, 255, 220) })
	for _ = 1, rng:NextInteger(4, 7) do
		local h = rng:NextNumber(4, 11)
		local c = base * CFrame.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3)) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 6), rng:NextNumber(-0.5, 0.5))
		deco({ Size = Vector3.new(1.4, h, 1.4), CFrame = c * CFrame.new(0, h / 2, 0), Material = Enum.Material.Neon, Color = col, Transparency = 0.15 }, parent)
		deco({ Size = Vector3.new(1, 1, 1), CFrame = c * CFrame.new(0, h, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)), Material = Enum.Material.Neon, Color = col, Transparency = 0.15 }, parent)
	end
end
-- Ледяная скала-стена вдоль трассы с сосульками
function Props.iceCliff(rng: Random, base: CFrame, side: number, parent: Instance)
	local h = rng:NextNumber(18, 34)
	local w = rng:NextNumber(16, 26)
	deco({ Size = Vector3.new(14, h, w), CFrame = base * CFrame.new(side * 7, h / 2, 0) * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), 0), Material = Enum.Material.Glacier, Color = ICE }, parent)
	deco({ Size = Vector3.new(15, 2, w + 1), CFrame = base * CFrame.new(side * 7, h + 0.5, 0), Material = Enum.Material.Snow, Color = SNOW }, parent)
	for k = 1, 4 do
		local z = (k - 2.5) * w / 4
		local ih = rng:NextNumber(2, 5)
		deco({ Size = Vector3.new(0.8, ih, 0.8), CFrame = base * CFrame.new(side * 0.6, h * 0.6 - ih / 2, z), Material = Enum.Material.Ice, Color = ICE }, parent)
	end
end

------------------------------------------------------------------ Мир 5: Северное сияние
-- Иглу: снежный купол из «кирпичей», вход-туннель и тёплый свет внутри
function Props.igloo(rng: Random, base: CFrame, parent: Instance)
	local r = rng:NextNumber(8, 11)
	deco({ Shape = Enum.PartType.Ball, Size = Vector3.new(r * 2, r * 1.6, r * 2), CFrame = base, Material = Enum.Material.Snow, Color = SNOW }, parent)
	for k = 1, 3 do -- швы между рядами «кирпичей»
		deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, r * 2 * math.cos(math.rad(k * 22)) + 0.2, r * 2 * math.cos(math.rad(k * 22)) + 0.2), CFrame = base * CFrame.new(0, r * 0.8 * math.sin(math.rad(k * 22)), 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(205, 220, 240) }, parent)
	end
	local door = base * CFrame.Angles(0, rng:NextNumber(0, 6), 0)
	deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(5, 5, 5), CFrame = door * CFrame.new(0, 1.5, -r) * CFrame.Angles(0, math.rad(90), 0), Material = Enum.Material.Snow, Color = SNOW }, parent)
	local hole = deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 3.4, 3.4), CFrame = door * CFrame.new(0, 1.5, -r - 2.5) * CFrame.Angles(0, math.rad(90), 0), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 180, 90) }, parent)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 170, 80)
	light.Range = 16
	light.Brightness = 2
	light.Parent = hole
end
-- Полярное сияние: широкие полупрозрачные светящиеся ленты высоко в небе
function Props.aurora(rng: Random, base: CFrame, parent: Instance)
	local col = pick(rng, { Color3.fromRGB(80, 255, 160), Color3.fromRGB(120, 200, 255), Color3.fromRGB(190, 120, 255) })
	local yaw = rng:NextNumber(0, math.pi)
	for k = 0, 5 do
		local c = base * CFrame.Angles(0, yaw, 0) * CFrame.new(k * 34 - 85, math.sin(k * 1.3) * 10, math.cos(k * 0.9) * 18) * CFrame.Angles(0, math.sin(k) * 0.5, 0)
		deco({ Size = Vector3.new(36, 60, 0.5), CFrame = c, Material = Enum.Material.Neon, Color = col:Lerp(Color3.fromRGB(190, 120, 255), k / 8), Transparency = 0.72 }, parent)
	end
end
-- Фонарь на столбе (тёплый свет в ночи)
function Props.lantern(base: CFrame, parent: Instance)
	deco({ Size = Vector3.new(0.5, 7, 0.5), CFrame = base * CFrame.new(0, 3.5, 0), Material = Enum.Material.Wood, Color = Color3.fromRGB(90, 60, 40) }, parent)
	local glow = deco({ Size = Vector3.new(1.3, 1.6, 1.3), CFrame = base * CFrame.new(0, 7.6, 0), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 190, 90) }, parent)
	deco({ Size = Vector3.new(1.7, 0.3, 1.7), CFrame = base * CFrame.new(0, 8.5, 0), Color = BLACK }, parent)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 180, 90)
	light.Range = 22
	light.Brightness = 1.6
	light.Parent = glow
end
-- Штабель ящиков (препятствие, разбивается)
function Props.crates(rng: Random, base: CFrame, parent: Instance)
	for k = 1, rng:NextInteger(2, 4) do
		local c = base * CFrame.new((k - 2) * 2.6 + rng:NextNumber(-0.4, 0.4), if k == 4 then 4.4 else 1.5, rng:NextNumber(-0.6, 0.6)) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0)
		part("Part", { Size = Vector3.new(3, 3, 3), CFrame = c, Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(170, 120, 70) }, parent)
		deco({ Size = Vector3.new(3.1, 0.4, 3.1), CFrame = c * CFrame.new(0, 1.55, 0), Material = Enum.Material.Snow, Color = SNOW }, parent)
	end
end

------------------------------------------------------------------ Мир 6: Снежный вулкан
local BASALT = Color3.fromRGB(55, 52, 58)
local LAVA = Color3.fromRGB(255, 110, 30)
-- Лавовый камень: тёмная глыба со светящимися трещинами
function Props.lavaRock(rng: Random, base: CFrame, parent: Instance)
	local s = rng:NextNumber(4.5, 6.5)
	local c = base * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3))
	part("Part", { Size = Vector3.new(s * 1.2, s * 0.85, s), CFrame = c * CFrame.new(0, s * 0.4, 0), Material = Enum.Material.Basalt, Color = BASALT }, parent)
	for _ = 1, 3 do
		deco({ Size = Vector3.new(s * 1.22, 0.25, 0.3), CFrame = c * CFrame.new(0, s * rng:NextNumber(0.2, 0.7), rng:NextNumber(-s / 2, s / 2)) * CFrame.Angles(0, 0, rng:NextNumber(-0.4, 0.4)), Material = Enum.Material.Neon, Color = LAVA }, parent)
	end
end
-- Базальтовые столбы (шестигранники)
function Props.basalt(rng: Random, base: CFrame, parent: Instance, collide: boolean?)
	local maker = if collide == false then deco else function(pr, pa) return part("Part", pr, pa) end
	for k = 1, rng:NextInteger(3, 5) do
		local h = rng:NextNumber(3, 9)
		maker({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 2.4, 2.4), CFrame = base * CFrame.new((k - 3) * 2.1, h / 2, rng:NextNumber(-1, 1)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Basalt, Color = BASALT:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.3)) }, parent)
		deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 2.2, 2.2), CFrame = base * CFrame.new((k - 3) * 2.1, h + 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Snow, Color = SNOW }, parent)
	end
end
-- Лавовое озерцо с каменным бортом и свечением
function Props.lavaPool(rng: Random, base: CFrame, parent: Instance)
	local r = rng:NextNumber(10, 18)
	deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, r * 2 + 3, r * 2 + 3), CFrame = base * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Basalt, Color = BASALT }, parent)
	local lava = deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.3, r * 2, r * 2), CFrame = base * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Neon, Color = LAVA }, parent)
	local light = Instance.new("PointLight")
	light.Color = LAVA
	light.Range = 30
	light.Brightness = 2
	light.Parent = lava
	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(80, 75, 80)
	smoke.Opacity = 0.15
	smoke.RiseVelocity = 6
	smoke.Size = 6
	smoke.Parent = lava
end
-- Обгоревшее дерево
function Props.charredTree(rng: Random, base: CFrame, parent: Instance)
	local h = rng:NextNumber(10, 18)
	local dark = Color3.fromRGB(40, 34, 32)
	deco({ Size = Vector3.new(1.4, h, 1.4), CFrame = base * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, rng:NextNumber(-0.1, 0.1)), Material = Enum.Material.Wood, Color = dark }, parent)
	for k = 1, 3 do
		local y = h * (0.45 + k * 0.15)
		local a = rng:NextNumber(0, 6)
		deco({ Size = Vector3.new(0.6, h * 0.3, 0.6), CFrame = base * CFrame.new(0, y, 0) * CFrame.Angles(0, a, math.rad(45)) * CFrame.new(0, h * 0.13, 0), Material = Enum.Material.Wood, Color = dark }, parent)
	end
end
-- Вулкан на горизонте: тёмный конус, снежные склоны, светящийся кратер и дым
function Props.volcano(rng: Random, base: CFrame, parent: Instance)
	local s = rng:NextNumber(110, 170)
	for k = 0, 3 do
		local w = s * (1.6 - k * 0.32)
		deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(s * 0.26, w, w), CFrame = base * CFrame.new(0, s * 0.13 + k * s * 0.24 - s * 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Material = if k < 2 then Enum.Material.Snow else Enum.Material.Basalt, Color = if k < 2 then SNOW:Lerp(BASALT, 0.25 * k) else BASALT }, parent)
	end
	local crater = deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, s * 0.42, s * 0.42), CFrame = base * CFrame.new(0, s * 0.85, 0) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Neon, Color = LAVA }, parent)
	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(70, 65, 70)
	smoke.Opacity = 0.3
	smoke.RiseVelocity = 12
	smoke.Size = 30
	smoke.Parent = crater
end

------------------------------------------------------------------ Мир 7: Конфетная гора
local CANDY = { Color3.fromRGB(255, 120, 180), Color3.fromRGB(120, 210, 255), Color3.fromRGB(255, 220, 90), Color3.fromRGB(150, 230, 120), Color3.fromRGB(200, 140, 255) }
-- Леденцовая трость: красно-белые полоски и крюк
function Props.candyCane(rng: Random, base: CFrame, parent: Instance, h: number?, collide: boolean?)
	h = h or rng:NextNumber(10, 16)
	local maker = if collide then function(pr, pa) return part("Part", pr, pa) end else deco
	local c = base * CFrame.Angles(0, rng:NextNumber(0, 6), 0)
	local n = math.floor((h :: number) / 1.4)
	for k = 0, n - 1 do
		maker({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.42, 1.3, 1.3), CFrame = c * CFrame.new(0, 0.7 + k * 1.4, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = if k % 2 == 0 then Color3.fromRGB(230, 40, 50) else Color3.new(1, 1, 1) }, parent)
	end
	local top = (h :: number) - 0.2
	for k = 0, 6 do -- крюк
		local a = math.rad(k * 30)
		deco({ Shape = Enum.PartType.Ball, Size = Vector3.one * 1.35, CFrame = c * CFrame.new(1.6 - math.cos(a) * 1.6, top + math.sin(a) * 1.6, 0), Color = if k % 2 == 0 then Color3.fromRGB(230, 40, 50) else Color3.new(1, 1, 1) }, parent)
	end
end
-- Леденец на палочке
function Props.lollipop(rng: Random, base: CFrame, parent: Instance)
	local h = rng:NextNumber(9, 15)
	local r = rng:NextNumber(3, 5)
	deco({ Size = Vector3.new(0.6, h, 0.6), CFrame = base * CFrame.new(0, h / 2, 0), Color = Color3.new(1, 1, 1) }, parent)
	local face = base * CFrame.new(0, h + r * 0.8, 0) * CFrame.Angles(0, rng:NextNumber(0, 6), 0)
	local a, b = pick(rng, CANDY), pick(rng, CANDY)
	for k = 0, 3 do
		deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8 + k * 0.02, r * 2 * (1 - k * 0.22), r * 2 * (1 - k * 0.22)), CFrame = face * CFrame.Angles(0, math.rad(90), 0), Color = if k % 2 == 0 then a else b }, parent)
	end
end
-- Пряничный домик с глазурью на крыше
function Props.gingerHouse(rng: Random, base: CFrame, side: number, parent: Instance)
	local w, h = rng:NextNumber(10, 14), rng:NextNumber(7, 9)
	local c = base * CFrame.Angles(0, if side > 0 then -math.pi / 2 else math.pi / 2, 0)
	local ginger = Color3.fromRGB(175, 105, 55)
	deco({ Size = Vector3.new(w, h, w * 0.8), CFrame = c * CFrame.new(0, h / 2, 0), Color = ginger }, parent)
	for _, sx in { -1, 1 } do
		deco({ Size = Vector3.new(w * 0.62, 0.8, w * 0.9), CFrame = c * CFrame.new(sx * w * 0.24, h + w * 0.18, 0) * CFrame.Angles(0, 0, sx * math.rad(-38)), Color = ginger:Lerp(Color3.new(0, 0, 0), 0.15) }, parent)
		deco({ Size = Vector3.new(w * 0.62, 0.35, 0.5), CFrame = c * CFrame.new(sx * w * 0.24, h + w * 0.18 + 0.2, -w * 0.45) * CFrame.Angles(0, 0, sx * math.rad(-38)), Color = Color3.new(1, 1, 1) }, parent) -- глазурь
	end
	deco({ Size = Vector3.new(w * 0.22, h * 0.5, 0.3), CFrame = c * CFrame.new(0, h * 0.25, -w * 0.41), Color = Color3.fromRGB(110, 60, 30) }, parent)
	for k = 1, 4 do
		deco({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, CFrame = c * CFrame.new((k - 2.5) * w * 0.22, h * 0.82, -w * 0.41), Color = CANDY[k] }, parent)
	end
end
-- Мармеладка-«капля» (препятствие)
function Props.gumdrop(rng: Random, base: CFrame, parent: Instance)
	local s = rng:NextNumber(4.5, 6)
	local col = pick(rng, CANDY)
	part("Part", { Shape = Enum.PartType.Ball, Size = Vector3.new(s * 1.2, s * 1.3, s * 1.2), CFrame = base * CFrame.new(0, s * 0.4, 0), Color = col, Material = Enum.Material.Glass, Transparency = 0.1 }, parent)
	for _ = 1, 6 do -- сахарные крупинки
		deco({ Size = Vector3.one * 0.35, CFrame = base * CFrame.new(rng:NextNumber(-s / 2, s / 2), s * rng:NextNumber(0.5, 0.95), rng:NextNumber(-s / 2, s / 2)), Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon }, parent)
	end
end
-- Капкейк: стаканчик, крем, вишенка (препятствие, разбивается)
function Props.cupcake(rng: Random, base: CFrame, parent: Instance)
	part("Part", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 4.6, 4.6), CFrame = base * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = pick(rng, CANDY) }, parent)
	part("Part", { Shape = Enum.PartType.Ball, Size = Vector3.new(5.2, 3.4, 5.2), CFrame = base * CFrame.new(0, 3.6, 0), Color = Color3.fromRGB(255, 240, 245) }, parent)
	deco({ Shape = Enum.PartType.Ball, Size = Vector3.one * 1.2, CFrame = base * CFrame.new(0, 5.5, 0), Color = Color3.fromRGB(220, 30, 50) }, parent)
end
-- Плитка шоколада (препятствие, разбивается)
function Props.chocolate(rng: Random, base: CFrame, parent: Instance)
	local c = base * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0)
	part("Part", { Size = Vector3.new(7, 4, 1.4), CFrame = c * CFrame.new(0, 2, 0), Color = Color3.fromRGB(95, 55, 30) }, parent)
	for x = -1, 1 do
		for y = 0, 1 do
			deco({ Size = Vector3.new(2, 1.6, 0.3), CFrame = c * CFrame.new(x * 2.2, 1.1 + y * 1.8, -0.75), Color = Color3.fromRGB(115, 70, 40) }, parent)
		end
	end
	deco({ Size = Vector3.new(7.1, 1.6, 1.5), CFrame = c * CFrame.new(0, 0.8, 0), Color = Color3.fromRGB(240, 60, 90) }, parent) -- обёртка
end

------------------------------------------------------------------ Лобби: «живые» детали
-- Костёр с кольцом камней, тремя брёвнами-скамейками, искрами, дымом и тёплым светом
function Props.campfire(base: CFrame, parent: Instance)
	for k = 0, 2 do
		deco({ Size = Vector3.new(3.6, 0.7, 0.7), CFrame = base * CFrame.new(0, 0.45, 0) * CFrame.Angles(0, math.rad(k * 60), math.rad(8)), Material = Enum.Material.Wood, Color = Color3.fromRGB(110, 70, 40) }, parent)
	end
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		deco({ Shape = Enum.PartType.Ball, Size = Vector3.new(1.3, 0.9, 1.1), CFrame = base * CFrame.new(math.cos(a) * 2.4, 0.3, math.sin(a) * 2.4) * CFrame.Angles(0, a, 0), Material = Enum.Material.Slate, Color = Color3.fromRGB(120, 120, 128) }, parent)
	end
	local flame = deco({ Size = Vector3.new(1.4, 2.2, 1.4), CFrame = base * CFrame.new(0, 1.6, 0) * CFrame.Angles(0, 0.6, 0), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 150, 40) }, parent)
	deco({ Size = Vector3.new(0.8, 1.2, 0.8), CFrame = base * CFrame.new(0, 2.6, 0) * CFrame.Angles(0, 1.3, 0), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 230, 120) }, parent)
	local att = Instance.new("Attachment")
	att.Position = Vector3.new(0, 1.2, 0)
	att.Parent = flame
	local fire = Instance.new("ParticleEmitter")
	fire.Texture = "rbxasset://textures/particles/fire_main.dds"
	fire.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 90, 30))
	fire.LightEmission = 0.8
	fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0.3) })
	fire.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	fire.Lifetime = NumberRange.new(0.5, 0.9)
	fire.Speed = NumberRange.new(3, 5)
	fire.SpreadAngle = Vector2.new(12, 12)
	fire.Rate = 14
	fire.Parent = att
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 200, 90))
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.25, 0)
	sparks.Lifetime = NumberRange.new(0.8, 1.6)
	sparks.Speed = NumberRange.new(5, 9)
	sparks.SpreadAngle = Vector2.new(25, 25)
	sparks.Acceleration = Vector3.new(1.5, 2, 0)
	sparks.Rate = 6
	sparks.Parent = att
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(190, 190, 195))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 5) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(2, 3.5)
	smoke.Speed = NumberRange.new(2, 3)
	smoke.Acceleration = Vector3.new(1, 0.5, 0)
	smoke.Rate = 2
	smoke.Parent = att
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 170, 90)
	light.Range = 20
	light.Brightness = 1.6
	light.Parent = flame
	-- брёвна-скамейки вокруг
	for k = 0, 2 do
		local a = math.rad(k * 120 + 60)
		deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(7, 1.4, 1.4), CFrame = base * CFrame.new(math.cos(a) * 6, 0.7, math.sin(a) * 6) * CFrame.Angles(0, -a, 0), Material = Enum.Material.Wood, Color = Color3.fromRGB(130, 85, 50), CastShadow = true }, parent)
	end
end

-- Флагшток с флагом. Флаг помечен тегом LobbyFlag и атрибутом BaseCF — клиент качает его «на ветру»
function Props.flagpole(base: CFrame, color: Color3, parent: Instance, height: number?)
	local h = height or 16
	deco({ Size = Vector3.new(0.5, h, 0.5), CFrame = base * CFrame.new(0, h / 2, 0), Material = Enum.Material.Metal, Color = Color3.fromRGB(225, 228, 235) }, parent)
	deco({ Shape = Enum.PartType.Ball, Size = Vector3.one * 1.1, CFrame = base * CFrame.new(0, h + 0.4, 0), Material = Enum.Material.Metal, Color = Color3.fromRGB(255, 205, 60) }, parent)
	local flagCF = base * CFrame.new(0.25, h - 2.2, 0)
	local flag = deco({ Size = Vector3.new(6, 3.6, 0.2), CFrame = flagCF * CFrame.new(3, 0, 0), Color = color }, parent)
	flag.Name = "Flag"
	flag:SetAttribute("BaseCF", flagCF) -- точка крепления: вращение вокруг неё
	game:GetService("CollectionService"):AddTag(flag, "LobbyFlag")
	return flag
end

-- Гирлянда из треугольных флажков между двумя точками (провисает дугой)
function Props.garland(from: Vector3, to: Vector3, parent: Instance, rng: Random?)
	local cols = { Color3.fromRGB(240, 80, 90), Color3.fromRGB(255, 205, 60), Color3.fromRGB(80, 180, 240), Color3.fromRGB(110, 210, 120), Color3.fromRGB(240, 130, 200) }
	local d = to - from
	local n = math.max(2, math.floor(d.Magnitude / 3.2))
	local prev = from
	for k = 1, n do
		local t = k / n
		local p = from + d * t - Vector3.new(0, math.sin(t * math.pi) * d.Magnitude * 0.06, 0)
		local seg = p - prev
		local mid = (p + prev) / 2
		local rope = CFrame.lookAt(mid, mid + seg.Unit)
		deco({ Size = Vector3.new(0.12, 0.12, seg.Magnitude), CFrame = rope, Color = Color3.fromRGB(90, 70, 50) }, parent)
		if k < n then
			local col = if rng then cols[rng:NextInteger(1, #cols)] else cols[(k % #cols) + 1]
			deco({ Size = Vector3.new(1.6, 2.2, 0.15), CFrame = CFrame.lookAt(p, p + Vector3.new(seg.X, 0, seg.Z).Unit) * CFrame.new(0, -1.15, 0) * CFrame.Angles(0, math.rad(90), 0), Color = col }, parent, "WedgePart")
		end
		prev = p
	end
end

return Props
