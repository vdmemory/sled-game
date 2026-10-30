-- Трасса уровня для одного игрока: ледяной жёлоб с перепадами уклона, обрывами,
-- препятствиями-тормозами, ускорителями, монетами и финишем.
-- Профиль уровня детерминирован (seed = номер уровня): одна и та же трасса на каждой попытке,
-- её можно выучить — как в оригинале. Геометрия строится кусками впереди игрока.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Track = {}
Track.__index = Track

local W = Config.TRACK_WIDTH
local WALL_A = math.rad(Config.WALL_ANGLE)
local WALL_W = Config.WALL_WIDTH
local WALL_TOP = WALL_W * math.sin(WALL_A) -- высота верха бортов над дном
local WALL_OUT = W / 2 + WALL_W * math.cos(WALL_A) -- внешний край бортов

------------------------------------------------------------------ helpers
local function part(className: string, props: { [string]: any }, parent: Instance?): BasePart
	local p = Instance.new(className) :: BasePart
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	if parent then
		p.Parent = parent
	end
	return p
end

local function decorPart(props: { [string]: any }, parent: Instance): BasePart
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	props.CastShadow = props.CastShadow or false
	return part("Part", props, parent)
end

-- Точка на «полке» рядом с жёлобом, без наклона (чтобы дома и ёлки стояли ровно)
local function sidePoint(segCF: CFrame, x: number, z: number): CFrame
	local p = segCF:PointToWorldSpace(Vector3.new(x, WALL_TOP, -z))
	return CFrame.new(p)
end

------------------------------------------------------------------ декор по мирам
local function decorTree(rng: Random, base: CFrame, parent: Instance)
	local h = rng:NextNumber(12, 26)
	decorPart({
		Size = Vector3.new(2, h * 0.4, 2),
		CFrame = base * CFrame.new(0, h * 0.2, 0),
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(95, 65, 40),
	}, parent)
	local green = Color3.fromRGB(35, 95 + rng:NextInteger(0, 30), 60)
	for tier = 0, 2 do
		local w = h * (0.6 - tier * 0.17)
		decorPart({
			Size = Vector3.new(w, h * 0.22, w),
			CFrame = base * CFrame.new(0, h * (0.45 + tier * 0.2), 0) * CFrame.Angles(0, math.rad(tier * 30 + rng:NextNumber(0, 90)), 0),
			Material = if tier == 2 then Enum.Material.Snow else Enum.Material.Grass,
			Color = if tier == 2 then Color3.fromRGB(245, 250, 255) else green,
		}, parent)
	end
end

local BUILDING_COLORS = {
	Color3.fromRGB(120, 160, 200),
	Color3.fromRGB(200, 120, 110),
	Color3.fromRGB(230, 200, 150),
	Color3.fromRGB(150, 150, 170),
	Color3.fromRGB(110, 180, 170),
}
local function decorBuilding(rng: Random, base: CFrame, parent: Instance)
	local w, d, h = rng:NextNumber(16, 28), rng:NextNumber(16, 28), rng:NextNumber(30, 90)
	local glass = rng:NextNumber() < 0.4
	decorPart({
		Size = Vector3.new(w, h, d),
		CFrame = base * CFrame.new(0, h / 2, 0),
		Material = if glass then Enum.Material.Glass else Enum.Material.SmoothPlastic,
		Color = if glass then Color3.fromRGB(110, 170, 220) else BUILDING_COLORS[rng:NextInteger(1, #BUILDING_COLORS)],
		Reflectance = if glass then 0.2 else 0,
		CastShadow = true,
	}, parent)
	decorPart({
		Size = Vector3.new(w + 1, 1.5, d + 1),
		CFrame = base * CFrame.new(0, h + 0.75, 0),
		Material = Enum.Material.Snow,
		Color = Color3.fromRGB(245, 250, 255),
	}, parent)
end

local function decorRock(rng: Random, base: CFrame, parent: Instance)
	local s = rng:NextNumber(14, 40)
	decorPart({
		Size = Vector3.new(s, s * rng:NextNumber(0.8, 1.8), s * rng:NextNumber(0.7, 1.2)),
		CFrame = base * CFrame.new(0, s * 0.4, 0) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi), rng:NextNumber(-0.3, 0.3)),
		Material = Enum.Material.Sandstone,
		Color = Color3.fromRGB(205, 150 + rng:NextInteger(0, 30), 110),
		CastShadow = true,
	}, parent)
	if rng:NextNumber() < 0.3 then -- кактус
		local cactus = base * CFrame.new(rng:NextNumber(-10, 10), 0, rng:NextNumber(-10, 10))
		decorPart({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(10, 2.4, 2.4),
			CFrame = cactus * CFrame.new(0, 5, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Material = Enum.Material.Grass,
			Color = Color3.fromRGB(70, 140, 70),
		}, parent)
	end
end

local DECOR = { decorTree, decorBuilding, decorRock }

------------------------------------------------------------------ окружение (стилизованный low-poly)
-- Округлое дерево со снежной шапкой
local function decorRoundTree(rng: Random, base: CFrame, parent: Instance)
	local h = rng:NextNumber(10, 18)
	decorPart({
		Size = Vector3.new(1.6, h * 0.5, 1.6),
		CFrame = base * CFrame.new(0, h * 0.25, 0),
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(130, 85, 55),
	}, parent)
	local green = Color3.fromRGB(80 + rng:NextInteger(0, 30), 150 + rng:NextInteger(0, 30), 70)
	local r = h * 0.45
	decorPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * r * 2,
		CFrame = base * CFrame.new(0, h * 0.6, 0),
		Material = Enum.Material.SmoothPlastic,
		Color = green,
		CastShadow = true,
	}, parent)
	decorPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * r * 1.4,
		CFrame = base * CFrame.new(r * 0.5, h * 0.75, r * 0.3),
		Material = Enum.Material.SmoothPlastic,
		Color = green:Lerp(Color3.new(1, 1, 1), 0.08),
	}, parent)
	decorPart({ -- снег сверху
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(r * 1.5, r * 0.6, r * 1.5),
		CFrame = base * CFrame.new(0, h * 0.6 + r * 0.8, 0),
		Material = Enum.Material.Snow,
		Color = Color3.fromRGB(250, 252, 255),
	}, parent)
end

-- Ограждение вдоль кромки: металлические перила (город) или деревянный забор (лес, каньон)
local function fence(cf: CFrame, len: number, side: number, metal: boolean, parent: Instance)
	local x = side * (WALL_OUT + 5)
	local color = if metal then Color3.fromRGB(200, 205, 215) else Color3.fromRGB(150, 100, 60)
	local material = if metal then Enum.Material.Metal else Enum.Material.WoodPlanks
	local step = if metal then 8 else 12
	for z = 0, len, step do
		decorPart({
			Size = Vector3.new(0.5, 4, 0.5),
			CFrame = sidePoint(cf, x, z) * CFrame.new(0, 2, 0),
			Material = material,
			Color = color,
		}, parent)
	end
	for _, y in (if metal then { 3.7, 2 } else { 3.2, 1.6 }) do
		decorPart({
			Size = Vector3.new(0.35, if metal then 0.35 else 0.6, len),
			CFrame = cf * CFrame.new(x, WALL_TOP + y, -len / 2),
			Material = material,
			Color = color,
		}, parent)
	end
end

-- Фонарь
local function streetLamp(base: CFrame, side: number, parent: Instance)
	local pole = Color3.fromRGB(70, 75, 90)
	decorPart({ Size = Vector3.new(0.7, 16, 0.7), CFrame = base * CFrame.new(0, 8, 0), Material = Enum.Material.Metal, Color = pole }, parent)
	decorPart({ Size = Vector3.new(4, 0.5, 0.5), CFrame = base * CFrame.new(-side * 2, 16, 0), Material = Enum.Material.Metal, Color = pole }, parent)
	decorPart({ Size = Vector3.new(1.6, 0.8, 1.2), CFrame = base * CFrame.new(-side * 4, 15.7, 0), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 240, 200) }, parent)
end

-- Дом с полосами окон на фасаде к трассе и снегом на крыше
local function cityBuilding(rng: Random, base: CFrame, side: number, w: number, parent: Instance)
	local d, h = rng:NextNumber(18, 30), rng:NextNumber(35, 110)
	local glassy = rng:NextNumber() < 0.35
	local body = if glassy then Color3.fromRGB(120, 175, 225) else BUILDING_COLORS[rng:NextInteger(1, #BUILDING_COLORS)]
	local center = base * CFrame.new(side * d / 2, h / 2, 0)
	decorPart({
		Size = Vector3.new(d, h, w),
		CFrame = center,
		Material = if glassy then Enum.Material.Glass else Enum.Material.SmoothPlastic,
		Color = body,
		Reflectance = if glassy then 0.25 else 0,
		CastShadow = true,
	}, parent)
	-- Окна: горизонтальные ленты на стороне, обращённой к трассе
	local floors = math.floor(h / 9)
	for f = 1, floors do
		decorPart({
			Size = Vector3.new(0.4, 2.6, w - 3),
			CFrame = base * CFrame.new(-side * 0.1, f * 9 - 3, 0),
			Material = Enum.Material.Glass,
			Color = if glassy then Color3.fromRGB(200, 230, 255) else Color3.fromRGB(70, 110, 160),
			Reflectance = 0.3,
		}, parent)
	end
	decorPart({
		Size = Vector3.new(d + 1, 1.5, w + 1),
		CFrame = base * CFrame.new(side * d / 2, h + 0.75, 0),
		Material = Enum.Material.Snow,
		Color = Color3.fromRGB(250, 252, 255),
	}, parent)
end

-- Скальная стена каньона: несколько слоёв песчаника
local function canyonCliff(rng: Random, base: CFrame, side: number, parent: Instance)
	local h = rng:NextNumber(40, 110)
	local y = 0
	local layer = 0
	while y < h do
		local lh = rng:NextNumber(12, 24)
		local shade = 0.85 + (layer % 2) * 0.12
		local w = rng:NextNumber(26, 40) - layer * 2
		decorPart({
			Size = Vector3.new(w, lh, rng:NextNumber(24, 36)),
			CFrame = base * CFrame.new(side * (w / 2 + layer * 1.5), y + lh / 2, 0) * CFrame.Angles(0, rng:NextNumber(-0.15, 0.15), 0),
			Material = Enum.Material.Sandstone,
			Color = Color3.fromRGB(math.floor(225 * shade), math.floor(160 * shade), math.floor(110 * shade)),
			CastShadow = true,
		}, parent)
		y += lh
		layer += 1
	end
	-- Снег на макушке
	decorPart({
		Size = Vector3.new(22, 1.2, 26),
		CFrame = base * CFrame.new(side * (11 + layer * 1.5), y + 0.6, 0),
		Material = Enum.Material.Snow,
		Color = Color3.fromRGB(250, 250, 255),
	}, parent)
end

-- Горы на горизонте: повёрнутый «ромбом» блок + снежная шапка
local function mountain(rng: Random, base: CFrame, rock: Color3, cap: Color3?, parent: Instance)
	local s = rng:NextNumber(90, 170)
	local rot = CFrame.Angles(0, rng:NextNumber(0, math.pi), 0) * CFrame.Angles(math.rad(45), 0, math.rad(45))
	decorPart({
		Size = Vector3.one * s,
		CFrame = base * CFrame.new(0, -s * 0.15, 0) * rot,
		Material = Enum.Material.Slate,
		Color = rock,
	}, parent)
	if cap then
		local peak = s * 0.866 - s * 0.15 -- верхняя вершина куба на диагонали
		local cs = s * 0.32
		decorPart({
			Size = Vector3.one * cs,
			CFrame = base * CFrame.new(0, peak - cs * 0.866 + 0.5, 0) * rot,
			Material = Enum.Material.Snow,
			Color = cap,
		}, parent)
	end
end

local function dressSegment(theme: number, rng: Random, cf: CFrame, len: number, m: Instance)
	for _, side in { -1, 1 } do
		-- Ограждение
		fence(cf, len, side, theme == 2, m)

		if theme == 1 then
			-- Снежный лес: густой ряд ёлок и круглых деревьев
			for z = 6, len, 14 do
				local x = side * (WALL_OUT + rng:NextNumber(10, 45))
				local base = sidePoint(cf, x, z + rng:NextNumber(-4, 4))
				if rng:NextNumber() < 0.55 then
					decorTree(rng, base, m)
				else
					decorRoundTree(rng, base, m)
				end
			end
		elseif theme == 2 then
			-- Ледяной город: плотная застройка у самой трассы, фонари
			local z = 0
			while z < len do
				local w = rng:NextNumber(16, 26)
				cityBuilding(rng, sidePoint(cf, side * (WALL_OUT + 14), z + w / 2), side, w, m)
				z += w + rng:NextNumber(1, 4)
			end
			for lz = 10, len, 40 do
				streetLamp(sidePoint(cf, side * (WALL_OUT + 8), lz), side, m)
			end
		else
			-- Каньон: слоистые скалы, кактусы, камни
			for z = 10, len, 28 do
				canyonCliff(rng, sidePoint(cf, side * (WALL_OUT + rng:NextNumber(18, 30)), z), side, m)
			end
			-- Кактус на полке у забора
			if rng:NextNumber() < 0.6 then
				local base = sidePoint(cf, side * (WALL_OUT + 11), rng:NextNumber(0, len))
				local green = Color3.fromRGB(80, 150, 75)
				decorPart({ Size = Vector3.new(2.4, 9, 2.4), CFrame = base * CFrame.new(0, 4.5, 0), Material = Enum.Material.Grass, Color = green }, m)
				decorPart({ Size = Vector3.new(4, 1.6, 1.6), CFrame = base * CFrame.new(1.6, 5, 0), Material = Enum.Material.Grass, Color = green }, m)
				decorPart({ Size = Vector3.new(1.6, 3.5, 1.6), CFrame = base * CFrame.new(3, 6.5, 0), Material = Enum.Material.Grass, Color = green }, m)
			end
		end

		-- Горы на горизонте
		if rng:NextNumber() < 0.6 then
			local rock = if theme == 3 then Color3.fromRGB(200, 140, 95) else Color3.fromRGB(125, 140, 165)
			local cap = if theme == 3 then nil else Color3.fromRGB(245, 248, 255)
			mountain(rng, sidePoint(cf, side * (WALL_OUT + rng:NextNumber(150, 220)), rng:NextNumber(0, len)), rock, cap, m)
		end
	end
end

------------------------------------------------------------------ препятствия (тормозят, не убивают)
local function tagObstacle(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			CollectionService:AddTag(d, "Obstacle")
		end
	end
end

local function obstacleSnowman(base: CFrame, model: Model)
	for k, r in { 3.2, 2.4, 1.7 } do
		part("Part", {
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * r * 2,
			CFrame = base * CFrame.new(0, ({ 3.2, 8.2, 12.1 })[k], 0),
			Material = Enum.Material.Snow,
			Color = Color3.fromRGB(250, 252, 255),
		}, model)
	end
	part("Part", {
		Size = Vector3.new(0.6, 0.6, 2),
		CFrame = base * CFrame.new(0, 12.1, 2),
		Color = Color3.fromRGB(255, 140, 40),
	}, model)
end

local CAR_COLORS = { Color3.fromRGB(220, 60, 60), Color3.fromRGB(60, 120, 220), Color3.fromRGB(240, 200, 60), Color3.fromRGB(240, 240, 240) }
local function obstacleCar(base: CFrame, model: Model, rng: Random)
	local color = CAR_COLORS[rng:NextInteger(1, #CAR_COLORS)]
	part("Part", { Size = Vector3.new(6, 3, 11), CFrame = base * CFrame.new(0, 2, 0), Color = color, Material = Enum.Material.SmoothPlastic }, model)
	part("Part", { Size = Vector3.new(5.6, 2.4, 6), CFrame = base * CFrame.new(0, 4.6, 0.5), Color = Color3.fromRGB(150, 200, 240), Material = Enum.Material.Glass, Transparency = 0.2 }, model)
	part("Part", { Size = Vector3.new(6.2, 0.6, 6.2), CFrame = base * CFrame.new(0, 6, 0.5), Material = Enum.Material.Snow, Color = Color3.new(1, 1, 1) }, model)
end

local function obstacleRock(base: CFrame, model: Model, rng: Random)
	local s = rng:NextNumber(5, 7)
	part("Part", {
		Size = Vector3.new(s, s * 0.8, s),
		CFrame = base * CFrame.new(0, s * 0.4, 0) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(115, 120, 130),
	}, model)
end

local function obstacleSign(base: CFrame, model: Model)
	part("Part", { Size = Vector3.new(0.6, 8, 0.6), CFrame = base * CFrame.new(0, 4, 0), Color = Color3.fromRGB(120, 120, 120), Material = Enum.Material.Metal }, model)
	part("Part", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 5, 5),
		CFrame = base * CFrame.new(0, 8.5, 0) * CFrame.Angles(0, math.rad(90), 0),
		Color = Color3.fromRGB(210, 40, 40),
	}, model)
end

local OBSTACLES_BY_THEME = {
	{ obstacleSnowman, obstacleRock, obstacleSign },
	{ obstacleCar, obstacleSign, obstacleSnowman },
	{ obstacleRock, obstacleCar, obstacleSign },
}

------------------------------------------------------------------ монета
-- Золотая монета: ободок + утопленное поле + выпуклая серединка (детали — дочерние части,
-- клиент вращает их вместе с монетой). Тег Coin только у основы: её касание и засчитывается.
local GOLD = Color3.fromRGB(255, 196, 45)
local GOLD_DARK = Color3.fromRGB(222, 150, 20)
local GOLD_LIGHT = Color3.fromRGB(255, 225, 110)
local function makeCoin(at: CFrame, parent: Instance)
	-- Цилиндр в Roblox вытянут по X; разворачиваем монету лицом к игроку
	local cf = at * CFrame.Angles(0, math.rad(90), 0)
	local coin = part("Part", {
		Name = "Coin",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.45, 3, 3),
		CFrame = cf,
		Material = Enum.Material.SmoothPlastic,
		Color = GOLD,
		Reflectance = 0.35,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})
	for _, spec in {
		{ size = Vector3.new(0.5, 2.3, 2.3), color = GOLD_DARK, refl = 0.2 }, -- поле
		{ size = Vector3.new(0.62, 1.1, 1.1), color = GOLD_LIGHT, refl = 0.45 }, -- выпуклая серединка
	} do
		part("Part", {
			Name = "CoinDetail",
			Shape = Enum.PartType.Cylinder,
			Size = spec.size,
			CFrame = cf,
			Material = Enum.Material.SmoothPlastic,
			Color = spec.color,
			Reflectance = spec.refl,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
		}, coin)
	end
	CollectionService:AddTag(coin, "Coin")
	coin.Parent = parent
	return coin
end

------------------------------------------------------------------ профиль уровня
type Segment = {
	kind: string,
	angle: number,
	length: number,
	cf: CFrame,
	hStart: number,
	hLen: number,
	yStart: number,
	yEnd: number,
}

local function buildProfile(origin: CFrame, level: number): ({ Segment }, number)
	local rng = Random.new(level * 7919 + 17)
	local L = Config.levelLength(level)
	local segs: { Segment } = {}
	local pos = origin.Position
	local h = 0
	local forceNext: string? = nil

	local function add(kind: string, angle: number, length: number)
		local cf = CFrame.new(pos) * CFrame.Angles(-math.rad(angle), 0, 0)
		local endPos = cf:PointToWorldSpace(Vector3.new(0, 0, -length))
		local hLen = length * math.cos(math.rad(angle))
		table.insert(segs, {
			kind = kind,
			angle = angle,
			length = length,
			cf = cf,
			hStart = h,
			hLen = hLen,
			yStart = pos.Y,
			yEnd = endPos.Y,
		})
		h += hLen
		pos = endPos
		if kind == "kicker" then
			pos -= Vector3.new(0, Config.KICKER_DROP, 0)
		end
	end

	add("start", 7, 110)
	local nextForced = 1
	while h < L do
		local forcedAt = Config.FORCED_KICKERS[nextForced]
		if forceNext == "landing" then
			add("landing", 18, 90)
			forceNext = nil
		elseif forcedAt and h >= L * forcedAt then
			add("kicker", 6, 100)
			forceNext = "landing"
			nextForced += 1
		else
			local t = rng:NextNumber()
			local steep = Config.steepChance(level)
			if t < steep then
				add("steep", rng:NextNumber(Config.STEEP_ANGLE[1], Config.STEEP_ANGLE[2]), 90)
			elseif t < steep + Config.KICKER_CHANCE and h > 250 then
				add("kicker", 6, 100)
				forceNext = "landing"
			else
				add("gentle", rng:NextNumber(Config.GENTLE_ANGLE[1], Config.GENTLE_ANGLE[2]), 120)
			end
		end
	end
	if forceNext == "landing" then
		add("landing", 18, 90)
	end
	-- Выкат после финиша
	add("runout", 1, 120)
	add("runout", -4, 80)
	return segs, L
end

------------------------------------------------------------------ класс
function Track.new(slot: number, level: number)
	local self = setmetatable({}, Track)
	self.level = level
	self.theme = ((level - 1) % #Config.THEMES) + 1
	self.origin = CFrame.new(Config.TRACKS_ORIGIN + Vector3.new(slot * Config.SLOT_SPACING, 0, 0))
	self.segments, self.length = buildProfile(self.origin, level)
	self.built = {} :: { [number]: Model }
	self.folder = Instance.new("Folder")
	self.folder.Name = "Track_" .. slot
	self.folder.Parent = workspace
	self:buildStart()
	self:ensure(0, Config.SEGMENTS_AHEAD)
	return self
end

-- Где стоят санки перед запуском (позади рогатки)
function Track:startCFrame(): CFrame
	return self.origin * CFrame.new(0, 1.5, 9)
end

function Track:buildStart()
	local theme = Config.THEMES[self.theme]
	local m = Instance.new("Model")
	m.Name = "Start"
	-- Площадка под рогаткой
	part("Part", {
		Size = Vector3.new(W + 10, 4, 30),
		CFrame = self.origin * CFrame.new(0, -2, 15),
		Material = Enum.Material.Ice,
		Color = theme.floor,
	}, m)
	-- Стойки рогатки
	self.posts = {}
	for _, side in { -1, 1 } do
		local post = part("Part", {
			Size = Vector3.new(1.4, 9, 1.4),
			CFrame = self.origin * CFrame.new(side * 9, 4.5, -1) * CFrame.Angles(0, 0, side * math.rad(-8)),
			Material = Enum.Material.Wood,
			Color = Color3.fromRGB(120, 80, 45),
		}, m)
		local att = Instance.new("Attachment")
		att.Name = "RopeAttachment"
		att.Position = Vector3.new(0, 3.5, 0)
		att.Parent = post
		table.insert(self.posts, post)
	end
	m.Parent = self.folder
end

function Track:buildSegment(i: number)
	local seg = self.segments[i + 1]
	if not seg then
		return
	end
	local rng = Random.new(self.level * 104729 + i * 31)
	local theme = Config.THEMES[self.theme]
	local cf, len = seg.cf, seg.length
	local m = Instance.new("Model")
	m.Name = "Segment_" .. i

	-- Дно жёлоба
	part("Part", {
		Name = "Floor",
		Size = Vector3.new(W, 4, len + 2),
		CFrame = cf * CFrame.new(0, -2, -len / 2),
		Material = Enum.Material.Glacier, -- лёд с трещинами, как в оригинале
		Color = theme.floor,
		Reflectance = 0.08,
	}, m)
	-- Накатанные полосы на льду — видно скорость
	for _, x in { -W * 0.3, -W * 0.1, W * 0.1, W * 0.3 } do
		decorPart({
			Size = Vector3.new(0.5, 0.05, len),
			CFrame = cf * CFrame.new(x + rng:NextNumber(-2, 2), 0.03, -len / 2),
			Material = Enum.Material.SmoothPlastic,
			Color = Color3.new(1, 1, 1),
			Transparency = 0.55,
		}, m)
	end
	-- Наклонные борта, полка сверху и невидимые стенки
	for _, side in { -1, 1 } do
		part("Part", {
			Name = "Wall",
			Size = Vector3.new(WALL_W, 2, len + 2),
			CFrame = cf * CFrame.new(side * W / 2, 0, -len / 2) * CFrame.Angles(0, 0, side * WALL_A) * CFrame.new(side * WALL_W / 2, -1, 0),
			Material = Enum.Material.Glacier,
			Color = theme.wall,
		}, m)
		-- Снежная кромка по верху борта (округлый сугроб)
		decorPart({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(len + 3, 7, 7),
			CFrame = cf * CFrame.new(side * (WALL_OUT + 1.5), WALL_TOP - 0.5, -len / 2) * CFrame.Angles(0, math.rad(90), 0),
			Material = Enum.Material.Snow,
			Color = Color3.fromRGB(250, 252, 255),
		}, m)
		part("Part", {
			Name = "Ground",
			Size = Vector3.new(140, 2, len + 2),
			CFrame = cf * CFrame.new(side * (WALL_OUT + 70), WALL_TOP - 1, -len / 2),
			Material = if self.theme == 3 then Enum.Material.Sand else Enum.Material.Snow,
			Color = theme.ground,
			CanCollide = false,
		}, m)
		part("Part", {
			Name = "Barrier",
			Size = Vector3.new(2, 40, len + 2),
			CFrame = cf * CFrame.new(side * (WALL_OUT + 1), WALL_TOP + 10, -len / 2),
			Transparency = 1,
			CanQuery = false,
		}, m)
	end

	-- Окружение мира: ограждения, дома/ёлки/скалы, горы на горизонте
	dressSegment(self.theme, rng, cf, len, m)

	-- Обрыв: трамплин в конце + скала вниз
	if seg.kind == "kicker" then
		part("WedgePart", {
			Name = "Ramp",
			Size = Vector3.new(W, 5, 16),
			CFrame = cf * CFrame.new(0, 2.5, -(len - 8)) * CFrame.Angles(0, math.pi, 0),
			Material = Enum.Material.Ice,
			Color = Color3.fromRGB(140, 200, 255),
		}, m)
		local endPos = cf:PointToWorldSpace(Vector3.new(0, 0, -len))
		decorPart({
			Size = Vector3.new(WALL_OUT * 2 + 280, Config.KICKER_DROP + 4, 3),
			CFrame = CFrame.new(endPos + Vector3.new(0, -Config.KICKER_DROP / 2 - 2, 1.5)),
			Material = if self.theme == 3 then Enum.Material.Sandstone else Enum.Material.Glacier,
			Color = if self.theme == 3 then Color3.fromRGB(200, 150, 110) else Color3.fromRGB(170, 210, 240),
		}, m)
	end

	-- Препятствия, ускорители, монеты
	if seg.kind == "gentle" or seg.kind == "steep" then
		local laneW = W / Config.LANES
		local function laneX(lane: number): number
			return -W / 2 + laneW * (lane - 0.5)
		end
		local maxBlocked = math.clamp(1 + (self.level - 1) // 2 + i // 8, 1, Config.LANES - 2)
		local kinds = OBSTACLES_BY_THEME[self.theme]
		for row = 1, Config.OBSTACLE_ROWS do
			local z = len * (row - 0.5) / Config.OBSTACLE_ROWS
			local free = {}
			for lane = 1, Config.LANES do
				table.insert(free, lane)
			end
			-- Первые метры после старта без препятствий: успеть разогнаться и сориентироваться
			local h = seg.hStart + z * math.cos(math.rad(seg.angle))
			local count = if h < Config.SAFE_START then 0 else rng:NextInteger(0, maxBlocked)
			for _ = 1, count do
				local idx = rng:NextInteger(1, #free)
				local om = Instance.new("Model")
				om.Name = "Obstacle"
				local base = cf * CFrame.new(laneX(free[idx]) + rng:NextNumber(-1.5, 1.5), 0, -z)
				kinds[rng:NextInteger(1, #kinds)](base, om, rng)
				tagObstacle(om)
				om.Parent = m
				table.remove(free, idx)
			end
			if rng:NextNumber() < Config.BOOST_CHANCE then
				local idx = rng:NextInteger(1, #free)
				local pad = part("Part", {
					Name = "Boost",
					Size = Vector3.new(laneW - 1.5, 0.3, 10),
					CFrame = cf * CFrame.new(laneX(free[idx]), 0.15, -(z + 10)),
					Material = Enum.Material.Neon,
					Color = Color3.fromRGB(80, 230, 255),
					CanCollide = false,
				}, m)
				CollectionService:AddTag(pad, "Boost")
				-- Стрелки на ускорителе
				for k = 0, 1 do
					decorPart({
						Size = Vector3.new(laneW - 4, 0.35, 1.2),
						CFrame = cf * CFrame.new(laneX(free[idx]), 0.2, -(z + 6 + k * 4)),
						Material = Enum.Material.Neon,
						Color = Color3.new(1, 1, 1),
					}, m)
				end
				table.remove(free, idx)
			end
			if rng:NextNumber() < Config.COIN_LINE_CHANCE and row < Config.OBSTACLE_ROWS then
				local lane = free[rng:NextInteger(1, #free)]
				local step = len / Config.OBSTACLE_ROWS
				for k = 1, Config.COINS_PER_LINE do
					makeCoin(cf * CFrame.new(laneX(lane), 3, -(z + step * k / (Config.COINS_PER_LINE + 1))), m)
				end
			end
		end
	end

	-- Финиш
	if self.length >= seg.hStart and self.length < seg.hStart + seg.hLen then
		local z = (self.length - seg.hStart) / math.cos(math.rad(seg.angle))
		local fcf = cf * CFrame.new(0, 0, -z)
		for _, side in { -1, 1 } do
			decorPart({
				Size = Vector3.new(2, 22, 2),
				CFrame = fcf * CFrame.new(side * (WALL_OUT + 1), 11, 0),
				Color = Color3.fromRGB(240, 240, 240),
				Material = Enum.Material.SmoothPlastic,
			}, m)
		end
		local cells = 12
		local cw = (WALL_OUT * 2 + 2) / cells
		for c = 0, cells - 1 do
			for r = 0, 1 do
				decorPart({
					Size = Vector3.new(cw, 2, 0.8),
					CFrame = fcf * CFrame.new(-WALL_OUT - 1 + cw * (c + 0.5), 20 + r * 2, 0),
					Color = if (c + r) % 2 == 0 then Color3.new(0.1, 0.1, 0.1) else Color3.new(1, 1, 1),
					Material = Enum.Material.SmoothPlastic,
				}, m)
			end
			decorPart({
				Size = Vector3.new(W / cells, 0.1, 3),
				CFrame = fcf * CFrame.new(-W / 2 + (W / cells) * (c + 0.5), 0.05, 0),
				Color = if c % 2 == 0 then Color3.new(0.1, 0.1, 0.1) else Color3.new(1, 1, 1),
				Material = Enum.Material.SmoothPlastic,
			}, m)
		end
	end

	-- Конец трассы: стенка
	if i == #self.segments - 1 then
		part("Part", {
			Name = "EndWall",
			Size = Vector3.new(WALL_OUT * 2 + 4, 30, 4),
			CFrame = cf * CFrame.new(0, 15, -len),
			Material = Enum.Material.Snow,
			Color = Color3.new(1, 1, 1),
		}, m)
	end

	m.Parent = self.folder
	self.built[i] = m
end

function Track:ensure(fromIdx: number, toIdx: number)
	for i = math.max(0, fromIdx), math.min(toIdx, #self.segments - 1) do
		if not self.built[i] then
			self:buildSegment(i)
		end
	end
end

function Track:cleanup(minKeep: number)
	for i, model in self.built do
		if i < minKeep then
			model:Destroy()
			self.built[i] = nil
		end
	end
end

-- Пройденная дистанция по горизонтали, смещение вбок и высота над дном
function Track:progressOf(pos: Vector3): (number, number, number)
	local rel = self.origin:PointToObjectSpace(pos)
	local h = -rel.Z
	return h, rel.X, pos.Y - self:floorYAt(h)
end

function Track:segmentIndexAt(h: number): number
	for i, seg in self.segments do
		if h < seg.hStart + seg.hLen then
			return i - 1
		end
	end
	return #self.segments - 1
end

function Track:floorYAt(h: number): number
	local seg = self.segments[self:segmentIndexAt(math.max(0, h)) + 1]
	local t = math.clamp((h - seg.hStart) / seg.hLen, 0, 1)
	return seg.yStart + (seg.yEnd - seg.yStart) * t
end

function Track:destroy()
	self.folder:Destroy()
end

------------------------------------------------------------------ лобби
function Track.buildLobby()
	local p = Config.LOBBY_POS
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"
	part("Part", {
		Size = Vector3.new(90, 4, 90),
		CFrame = CFrame.new(p + Vector3.new(0, -2, 0)),
		Material = Enum.Material.Snow,
		Color = Color3.fromRGB(245, 248, 255),
	}, lobby)
	for x = -40, 40, 20 do
		for _, z in { -40, 40 } do
			decorTree(Random.new(x * 7 + z), CFrame.new(p + Vector3.new(x, 0, z)), lobby)
		end
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(p + Vector3.new(0, 0.5, 0))
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = lobby
	lobby.Parent = workspace
end

return Track
