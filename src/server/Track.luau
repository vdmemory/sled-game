-- Трасса уровня для одного игрока: широкий белый снежный склон с мягкими сугробами по краям,
-- ледяными проплешинами, обрывами с жёлтыми трамплинами, препятствиями, ускорителями, монетами
-- и финишем. Профиль уровня детерминирован (seed = номер уровня): одна и та же трасса на каждой
-- попытке, её можно выучить — как в оригинале. Геометрия строится кусками впереди игрока.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Props = require(script.Parent.Props)
local SledModels = require(ReplicatedStorage.Shared.SledModels)

local part, deco = Props.part, Props.deco

local Track = {}
Track.__index = Track

------------------------------------------------------------------ поперечные профили
-- Снежный склон: дно шириной W и два пояса мягкого сугроба.
-- Ледяной жёлоб (повороты): то же дно, но высокие изогнутые ледяные стенки — как горка в аквапарке.
local W = Config.TRACK_WIDTH
local function profile(banks: { { width: number, angle: number } })
	local out, top = W / 2, 0
	for _, b in banks do
		out += b.width * math.cos(math.rad(b.angle))
		top += b.width * math.sin(math.rad(b.angle))
	end
	return { banks = banks, out = out, top = top }
end
local SNOW_PROFILE = profile({ { width = 14, angle = 14 }, { width = 14, angle = 32 } })
local CHUTE_PROFILE = profile({ { width = 12, angle = 22 }, { width = 14, angle = 48 }, { width = 14, angle = 74 } })
local ROAD_PROFILE = profile({}) -- дорога: ровная площадка без бортов
local LAKE_PROFILE = { banks = {}, out = W * 1.5, top = 0, floorW = W * 3 } -- ледяное озеро после финиша
local BANK_OUT, BANK_TOP = SNOW_PROFILE.out, SNOW_PROFILE.top

local SNOW_FLOOR = Color3.fromRGB(236, 243, 252)
local SNOW_BANK = Color3.fromRGB(246, 249, 255)
local SNOW = Color3.fromRGB(250, 252, 255)

-- Точка на «полке» за краем трассы, без наклона (дома и деревья стоят ровно), лицом вдоль трассы
local function sidePoint(segCF: CFrame, x: number, z: number, top: number?): CFrame
	local p = segCF:PointToWorldSpace(Vector3.new(x, top or BANK_TOP, -z))
	local look = segCF.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	return CFrame.lookAt(p, p + (if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)))
end

local function tagObstacle(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			CollectionService:AddTag(d, "Obstacle")
		end
	end
end

------------------------------------------------------------------ монета
-- Золотая монета: ободок + утопленное поле + выпуклая серединка (детали — дочерние части,
-- клиент вращает их вместе с монетой). Тег Coin только у основы: её касание и засчитывается.
local GOLD = Color3.fromRGB(255, 196, 45)
local GOLD_DARK = Color3.fromRGB(222, 150, 20)
local GOLD_LIGHT = Color3.fromRGB(255, 225, 110)
local function makeCoin(at: CFrame, parent: Instance)
	local cf = at * CFrame.Angles(0, math.rad(90), 0) -- цилиндр вытянут по X: ставим монету лицом к игроку
	local coin = part("Part", {
		Name = "Coin",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.45, 3, 3),
		CFrame = cf,
		Color = GOLD,
		Reflectance = 0.08,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})
	for _, spec in {
		{ size = Vector3.new(0.5, 2.3, 2.3), color = GOLD_DARK },
		{ size = Vector3.new(0.62, 1.1, 1.1), color = GOLD_LIGHT },
	} do
		part("Part", {
			Name = "CoinDetail",
			Shape = Enum.PartType.Cylinder,
			Size = spec.size,
			CFrame = cf,
			Color = spec.color,
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

------------------------------------------------------------------ бонусы: гем, магнит, кристалл
local GEM_BLUE = Color3.fromRGB(80, 190, 255)
local function makeGem(at: CFrame, parent: Instance)
	local gem = part("Part", {
		Name = "Gem",
		Size = Vector3.new(2.2, 2.2, 2.2),
		CFrame = at * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		Color = GEM_BLUE,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})
	local light = Instance.new("PointLight")
	light.Color = GEM_BLUE
	light.Range = 10
	light.Parent = gem
	CollectionService:AddTag(gem, "Gem")
	gem.Parent = parent
end

local function makeMagnet(at: CFrame, parent: Instance)
	local hit = part("Part", {
		Name = "Magnet",
		Size = Vector3.new(4, 4, 4),
		CFrame = at,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	}, parent)
	-- подкова: две половинки (синяя и розовая) + серебряные кончики
	for _, sx in { -1, 1 } do
		deco({ Size = Vector3.new(0.9, 2.6, 0.9), CFrame = at * CFrame.new(sx * 1, 0.2, 0), Color = if sx < 0 then Color3.fromRGB(60, 130, 255) else Color3.fromRGB(255, 90, 170) }, parent)
		deco({ Size = Vector3.new(0.92, 0.6, 0.92), CFrame = at * CFrame.new(sx * 1, -1.3, 0), Color = Color3.fromRGB(220, 225, 235), Material = Enum.Material.Metal }, parent)
	end
	deco({ Size = Vector3.new(2.9, 0.9, 0.9), CFrame = at * CFrame.new(0, 1.5, 0), Color = Color3.fromRGB(160, 110, 220) }, parent)
	CollectionService:AddTag(hit, "Magnet")
end

local function makeCrystal(at: CFrame, rng: Random, parent: Instance)
	local m = Instance.new("Model")
	m.Name = "Crystal"
	for k = 1, 5 do
		local h = rng:NextNumber(5, 10)
		local p = part("Part", {
			Size = Vector3.new(2.2, h, 2.2),
			CFrame = at * CFrame.new(rng:NextNumber(-2, 2), h / 2 - 0.5, rng:NextNumber(-2, 2)) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 3), rng:NextNumber(-0.4, 0.4)),
			Color = Color3.fromRGB(150, 220, 255),
			Material = Enum.Material.Glass,
			Transparency = 0.15,
			Reflectance = 0.2,
			CanCollide = false,
		}, m)
		CollectionService:AddTag(p, "Crystal")
	end
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(150, 220, 255)
	light.Range = 18
	light.Brightness = 2
	light.Parent = m:FindFirstChildWhichIsA("BasePart")
	m.Parent = parent
end

------------------------------------------------------------------ оформление миров
local function dressSegment(theme: number, rng: Random, cf: CFrame, len: number, m: Instance, prof)
	local out, top = prof.out, prof.top
	local density = len / 110 -- короткие куски поворотов получают пропорционально меньше редких объектов
	-- Случайная позиция вдоль куска с отступом от краёв (безопасно и для коротких кусков)
	local function zr(margin: number): number
		if len > margin * 2 then
			return rng:NextNumber(margin, len - margin)
		end
		return len / 2
	end
	for _, side in { -1, 1 } do
		local at = function(offset: number, z: number): CFrame
			return sidePoint(cf, side * (out + offset), z, top)
		end

		if theme == 1 then
			-- Снежный лес: ёлки и «акации» со снегом, иногда хижина, валуны и указатель
			for z = 6, len, 13 do
				local p = at(rng:NextNumber(8, 50), z + rng:NextNumber(-4, 4))
				if rng:NextNumber() < 0.6 then
					Props.pine(rng, p, m)
				else
					Props.acacia(rng, p, m)
				end
			end
			if rng:NextNumber() < 0.25 * density then
				Props.cabin(rng, at(26, zr(15)), side, m)
			end
			if rng:NextNumber() < 0.5 * density then
				Props.boulder(rng, at(rng:NextNumber(5, 8), zr(0)), m, false, 1.3, false)
			end
			if rng:NextNumber() < 0.15 * density then
				Props.signpost(rng, at(4, zr(0)), m)
			end
		elseif theme == 2 then
			-- Город: припаркованные машины, ряд домов с маркизами, высотки сзади, фонари
			for z = 8, len, 16 do
				if rng:NextNumber() < 0.55 then
					local p = at(4, z) * CFrame.Angles(0, if rng:NextNumber() < 0.5 then 0 else math.pi, 0)
					if rng:NextNumber() < 0.25 then
						Props.van(rng, p, m, rng:NextNumber() < 0.4)
					else
						Props.car(rng, p, m)
					end
				end
			end
			local z = 0
			while z < len do
				local w = rng:NextNumber(16, 24)
				Props.house(rng, at(12, z + w / 2), side, w, m)
				z += w + rng:NextNumber(0.5, 3)
			end
			if rng:NextNumber() < 0.8 * len / 30 then
				Props.tower(rng, at(40 + rng:NextNumber(0, 15), zr(0)), side, m)
			end
			if rng:NextNumber() < len / 40 then
				Props.streetLamp(at(9, zr(0)), side, m)
			end
			if rng:NextNumber() < 0.4 * density then
				Props.hydrant(at(9.5, zr(0)), m)
			end
		else
			-- Каньон: слоистые скалы, акации, лагерь с костром, ветряк, водонапорная башня, кактусы
			if rng:NextNumber() < len / 28 then
				Props.mesa(rng, at(rng:NextNumber(30, 42), zr(0)), side, m)
			end
			if rng:NextNumber() < 0.7 * len / 22 then
				Props.acacia(rng, at(rng:NextNumber(8, 22), zr(0)), m)
			end
			if rng:NextNumber() < 1.2 * density then
				Props.cactus(rng, at(rng:NextNumber(4, 10), zr(0)), m)
			end
			local feature = rng:NextNumber() / math.max(density, 0.01)
			if feature < 0.3 then
				Props.camp(rng, at(16, zr(20)), m)
			elseif feature < 0.42 then
				Props.windmill(at(20, zr(20)), side, m)
			elseif feature < 0.52 then
				Props.waterTower(at(20, zr(20)), m)
			elseif feature < 0.65 then
				Props.signpost(rng, at(4, zr(0)), m)
			end
		end

		-- Воздушные шары в небе
		if theme ~= 2 and rng:NextNumber() < 0.12 * density then
			Props.balloon(rng, at(rng:NextNumber(40, 110), zr(0)) * CFrame.new(0, rng:NextNumber(45, 85), 0), m)
		end
		-- Горы на горизонте
		if rng:NextNumber() < 0.6 * density then
			Props.mountain(rng, at(rng:NextNumber(140, 200), zr(0)), theme == 3, m)
		end
	end
end

------------------------------------------------------------------ профиль уровня
-- Трасса — цепочка кусков. У каждого куска свой уклон (pitch) и направление (yaw).
-- Повороты собраны из коротких кусков, каждый чуть довёрнут, и одеты ледяным жёлобом.
type Segment = {
	kind: string,
	angle: number, -- уклон, градусы (вниз > 0)
	yaw: number, -- направление, радианы (0 = -Z)
	length: number,
	cf: CFrame, -- начало куска: центр дна, -Z = вниз по трассе
	hStart: number, -- пройденный путь по горизонтали до начала куска
	hLen: number,
	chute: boolean,
}

local function buildProfile(origin: CFrame, level: number): ({ Segment }, number)
	local rng = Random.new(level * 7919 + 17)
	local L = Config.levelLength(level)
	local segs: { Segment } = {}
	local pos = origin.Position
	local yaw = 0
	local h = 0
	local forceNext: string? = nil
	local lastTurn = 1

	local function add(kind: string, angle: number, length: number, chute: boolean?)
		local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(-math.rad(angle), 0, 0)
		local endPos = cf:PointToWorldSpace(Vector3.new(0, 0, -length))
		local hLen = length * math.cos(math.rad(angle))
		table.insert(segs, {
			kind = kind,
			angle = angle,
			yaw = yaw,
			length = length,
			cf = cf,
			hStart = h,
			hLen = hLen,
			chute = chute == true,
		})
		h += hLen
		pos = endPos
		if kind == "kicker" then
			pos -= Vector3.new(0, Config.KICKER_DROP, 0)
		end
	end

	-- Поворот из коротких кусков. Направление выбираем так, чтобы трасса не уходила далеко вбок
	local function curve()
		local drift = origin:PointToObjectSpace(pos).X
		local dir
		if math.abs(drift) > Config.MAX_DRIFT then
			dir = if drift > 0 then 1 else -1 -- поворачиваем обратно к центру (yaw > 0 — влево)
		elseif math.abs(math.deg(yaw)) > Config.MAX_HEADING * 0.5 then
			dir = if yaw > 0 then -1 else 1
		else
			dir = -lastTurn -- змейка: чередуем стороны
		end
		lastTurn = dir
		local total = math.rad(rng:NextNumber(Config.CURVE_ANGLE[1], Config.CURVE_ANGLE[2]))
		local maxYaw = math.rad(Config.MAX_HEADING)
		local pieces = math.max(3, math.floor(math.deg(total) / Config.CURVE_STEP + 0.5))
		local step = total / pieces * dir
		local pitch = rng:NextNumber(Config.CURVE_PITCH[1], Config.CURVE_PITCH[2])
		for _ = 1, pieces do
			if math.abs(yaw + step) <= maxYaw then
				yaw += step
			end
			add("curve", pitch, Config.CURVE_PIECE, true)
		end
	end

	add("start", 7, 110)
	local nextForced = 1
	local nextRoad = 1
	local roads = Config.roadCount(level)
	local railDone = false
	while h < L do
		local forcedAt = Config.FORCED_KICKERS[nextForced]
		local roadAt = if nextRoad <= roads then Config.ROAD_AT[nextRoad] else nil
		if forceNext ~= "landing" and roadAt and h >= L * roadAt then
			-- в городе одна из дорог — железнодорожный переезд
			local theme = Config.themeOf(level)
			if theme == 2 and not railDone and nextRoad == 2 then
				add("rail", 3, 60)
				railDone = true
			else
				add("road", 3, 60)
			end
			nextRoad += 1
		elseif forceNext == "landing" then
			add("landing", 18, 90)
			forceNext = nil
		elseif forcedAt and h >= L * forcedAt then
			add("kicker", 6, 100)
			forceNext = "landing"
			nextForced += 1
		else
			local t = rng:NextNumber()
			local steep = Config.steepChance(level)
			if h > 220 and t < Config.CURVE_CHANCE then
				curve()
			elseif t < Config.CURVE_CHANCE + steep then
				add("steep", rng:NextNumber(Config.STEEP_ANGLE[1], Config.STEEP_ANGLE[2]), 90)
			elseif t < Config.CURVE_CHANCE + steep + Config.KICKER_CHANCE and h > 250 then
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
	add("lake", 0.5, 300) -- ледяное озеро: после финиша катимся до остановки
	return segs, L
end

------------------------------------------------------------------ класс
function Track.new(slot: number, level: number, bestH: number?, origin: CFrame?)
	local self = setmetatable({}, Track)
	self.level = level
	self.bestH = bestH or 0
	self.theme = Config.themeOf(level)
	self.origin = origin or CFrame.new(Config.TRACKS_ORIGIN + Vector3.new(slot * Config.SLOT_SPACING, 0, 0))
	self.segments, self.length = buildProfile(self.origin, level)
	self.built = {} :: { [number]: Model }
	self.hint = 1
	self.folder = Instance.new("Folder")
	self.folder.Name = if origin then "TrackPreview" else "Track_" .. slot
	self.folder.Parent = workspace
	self:buildStart()
	self:ensureAround(0)
	return self
end

-- Где стоят санки перед запуском (позади рогатки)
function Track:startCFrame(): CFrame
	return self.origin * CFrame.new(0, 1.5, 9)
end

function Track:buildStart()
	local m = Instance.new("Model")
	m.Name = "Start"
	part("Part", {
		Name = "Floor",
		Size = Vector3.new(BANK_OUT * 2, 4, 30),
		CFrame = self.origin * CFrame.new(0, -2, 15),
		Material = Enum.Material.Snow,
		Color = SNOW_FLOOR,
	}, m)
	self.posts = {}
	for _, side in { -1, 1 } do
		local post = part("Part", {
			Size = Vector3.new(1.4, 9, 1.4),
			CFrame = self.origin * CFrame.new(side * 9, 4.5, -1) * CFrame.Angles(0, 0, side * math.rad(-8)),
			Material = Enum.Material.Wood,
			Color = Color3.fromRGB(140, 95, 55),
		}, m)
		local att = Instance.new("Attachment")
		att.Name = "RopeAttachment"
		att.Position = Vector3.new(0, 3.5, 0)
		att.Parent = post
		table.insert(self.posts, post)
	end
	m.Parent = self.folder
end

-- Поперечное сечение: дно + пояса сугроба/льда, полка и невидимые стенки
local ICE_FLOOR = Color3.fromRGB(165, 210, 245)
local ICE_WALL = Color3.fromRGB(130, 190, 240)
local function buildCrossSection(cf: CFrame, len: number, prof, chute: boolean, m: Instance, alt: number)
	-- Куски перекрываются, чтобы на поворотах не было щелей по внешнему краю;
	-- соседние куски чуть сдвинуты по высоте, чтобы перекрытия не мерцали
	local overlap = if chute then 8 else 2
	cf = cf * CFrame.new(0, alt * 0.03, 0)
	local floorW = prof.floorW or W
	local lake = prof == LAKE_PROFILE
	part("Part", {
		Name = "Floor",
		Size = Vector3.new(floorW, 4, len + overlap),
		CFrame = cf * CFrame.new(0, -2, -len / 2),
		Material = if chute or lake then Enum.Material.Glacier else Enum.Material.Snow,
		Color = if lake then Color3.fromRGB(175, 220, 250) elseif chute then ICE_FLOOR else SNOW_FLOOR,
		Reflectance = if chute or lake then 0.12 else 0,
	}, m)
	for _, side in { -1, 1 } do
		local x, y = floorW / 2, 0
		for k, b in prof.banks do
			local a = math.rad(b.angle)
			part("Part", {
				Name = "Bank",
				Size = Vector3.new(b.width, 2, len + overlap),
				CFrame = cf * CFrame.new(side * x, y, -len / 2) * CFrame.Angles(0, 0, side * a) * CFrame.new(side * b.width / 2, -1, 0),
				Material = if chute then Enum.Material.Glacier else Enum.Material.Snow,
				Color = if chute then ICE_WALL:Lerp(Color3.new(1, 1, 1), (k - 1) * 0.12) else SNOW_BANK,
				Reflectance = if chute then 0.1 else 0,
			}, m)
			x += b.width * math.cos(a)
			y += b.width * math.sin(a)
		end
		-- Округлая снежная кромка
		deco({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(len + overlap + 1, 6, 6),
			CFrame = cf * CFrame.new(side * (prof.out + 1), prof.top - 1.2, -len / 2) * CFrame.Angles(0, math.rad(90), 0),
			Material = Enum.Material.Snow,
			Color = SNOW,
		}, m)
		part("Part", {
			Name = "Ground",
			Size = Vector3.new(150, 2, len + overlap),
			CFrame = cf * CFrame.new(side * (prof.out + 75), prof.top - 1, -len / 2),
			Material = Enum.Material.Snow,
			Color = SNOW,
			CanCollide = false,
		}, m)
		part("Part", {
			Name = "Barrier",
			Size = Vector3.new(2, 40, len + overlap),
			CFrame = cf * CFrame.new(side * (prof.out + 2), prof.top + 10, -len / 2),
			Transparency = 1,
			CanQuery = false,
		}, m)
	end
	if chute then
		-- Белые разводы на льду жёлоба (как в трейлере)
		for _, x in { -W * 0.3, -W * 0.05, W * 0.2 } do
			deco({
				Size = Vector3.new(0.8, 0.05, len + overlap),
				CFrame = cf * CFrame.new(x, 0.03, -len / 2),
				Color = Color3.new(1, 1, 1),
				Transparency = 0.45,
			}, m)
		end
	end
end

function Track:buildSegment(i: number)
	local seg = self.segments[i + 1]
	if not seg then
		return
	end
	local rng = Random.new(self.level * 104729 + i * 31)
	local cf, len = seg.cf, seg.length
	local prof = if seg.chute then CHUTE_PROFILE
		elseif seg.kind == "road" or seg.kind == "rail" then ROAD_PROFILE
		elseif seg.kind == "lake" then LAKE_PROFILE
		else SNOW_PROFILE
	local m = Instance.new("Model")
	m.Name = "Segment_" .. i

	buildCrossSection(cf, len, prof, seg.chute, m, i % 2)

	if seg.kind == "road" or seg.kind == "rail" then
		self:buildRoad(seg, rng, m, seg.kind == "rail")
	elseif seg.kind == "lake" then
		-- трещинки и блики на льду
		for _ = 1, 14 do
			deco({
				Size = Vector3.new(rng:NextNumber(6, 20), 0.05, 0.4),
				CFrame = cf * CFrame.new(rng:NextNumber(-W * 1.3, W * 1.3), 0.03, -rng:NextNumber(10, len - 10)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
				Color = Color3.new(1, 1, 1),
				Transparency = 0.4,
			}, m)
		end
	elseif not seg.chute then
		-- Ледяные проплешины на снегу
		for _ = 1, rng:NextInteger(2, 4) do
			local patch = deco({
				Size = Vector3.new(rng:NextNumber(10, 26), 0.06, rng:NextNumber(14, 34)),
				CFrame = cf * CFrame.new(rng:NextNumber(-W / 2 + 8, W / 2 - 8), 0.03, -rng:NextNumber(10, len - 10))
					* CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0),
				Material = Enum.Material.Glacier,
				Color = Color3.fromRGB(150, 200, 240),
				Transparency = 0.2,
			}, m)
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Scale = Vector3.new(1, 0.4, 1)
			mesh.Parent = patch
		end
		for _, x in { -W * 0.25, W * 0.05, W * 0.3 } do
			deco({
				Size = Vector3.new(0.6, 0.05, len),
				CFrame = cf * CFrame.new(x + rng:NextNumber(-3, 3), 0.03, -len / 2),
				Color = Color3.fromRGB(205, 225, 245),
				Transparency = 0.35,
			}, m)
		end
	end

	if seg.kind ~= "road" and seg.kind ~= "rail" then
		dressSegment(self.theme, rng, cf, len, m, prof)
	end

	-- Канатная дорога над местом приземления: кабинки едут поперёк трассы
	if seg.kind == "landing" and self.theme ~= 2 and rng:NextNumber() < Config.GONDOLA_CHANCE then
		local z = 42
		local cableY = 34
		local center = cf * CFrame.new(0, 0, -z)
		local flat = CFrame.lookAt(center.Position, center.Position + Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z))
		for _, side in { -1, 1 } do
			Props.pylon(flat * CFrame.new(side * (BANK_OUT + 8), BANK_TOP, 0), cableY - BANK_TOP, m)
		end
		local cable = flat * CFrame.new(0, cableY, 0)
		deco({ Size = Vector3.new(Config.ROAD_LOOP + 40, 0.3, 0.3), CFrame = cable, Color = Color3.fromRGB(50, 50, 60) }, m)
		local count = 2
		for k = 1, count do
			local g = Props.gondola(rng, cable, m)
			self:setMover(g, cable, 0, if k % 2 == 0 then 1 else -1, 18, Config.ROAD_LOOP, (k - 1) * Config.ROAD_LOOP / count + rng:NextNumber(0, 40))
			tagObstacle(g)
		end
	end

	-- Арка-тоннель над ледяным жёлобом (как в Roblox-референсе)
	if seg.kind == "curve" and i % 9 == 0 then
		local r = prof.out + 3
		for k = 0, 10 do
			local a = math.pi * k / 10
			deco({
				Size = Vector3.new(5, 5, 4),
				CFrame = cf * CFrame.new(math.cos(a) * r, prof.top * 0.3 + math.sin(a) * r * 0.75, -len / 2) * CFrame.Angles(0, 0, a),
				Material = Enum.Material.Ice,
				Color = Color3.fromRGB(120, 170, 225),
			}, m)
		end
	end

	-- Флаг рекорда: где игрок остановился в лучшей попытке
	if self.bestH > 0 and self.bestH >= seg.hStart and self.bestH < seg.hStart + seg.hLen then
		local z = (self.bestH - seg.hStart) / math.cos(math.rad(seg.angle))
		local at = cf * CFrame.new(W / 2 - 4, 0, -z)
		deco({ Size = Vector3.new(0.5, 12, 0.5), CFrame = at * CFrame.new(0, 6, 0), Color = Color3.fromRGB(240, 240, 240) }, m)
		local flag = deco({ Size = Vector3.new(0.2, 3, 5), CFrame = at * CFrame.new(-2.6, 10.3, 0) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(255, 200, 40) }, m)
		local sg = Instance.new("BillboardGui")
		sg.Size = UDim2.fromOffset(120, 40)
		sg.StudsOffset = Vector3.new(0, 3, 0)
		sg.AlwaysOnTop = false
		sg.Parent = flag
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Text = "★ BEST"
		t.TextScaled = true
		t.Font = Enum.Font.FredokaOne
		t.TextColor3 = Color3.fromRGB(255, 220, 60)
		t.TextStrokeTransparency = 0.3
		t.Parent = sg
		-- линия рекорда поперёк трассы
		deco({ Size = Vector3.new(W, 0.08, 1.2), CFrame = cf * CFrame.new(0, 0.05, -z), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 210, 60), Transparency = 0.2 }, m)
	end

	-- Обрыв: жёлтый трамплин в конце + обрыв вниз
	if seg.kind == "kicker" then
		Props.ramp(cf * CFrame.new(0, 0, -(len - 9)), W, 18, 5, m)
		local endPos = cf:PointToWorldSpace(Vector3.new(0, 0, -len))
		deco({
			Size = Vector3.new(BANK_OUT * 2 + 300, Config.KICKER_DROP + 4, 3),
			CFrame = CFrame.lookAt(endPos, endPos + Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)) * CFrame.new(0, -Config.KICKER_DROP / 2 - 2, 1.5),
			Material = if self.theme == 3 then Enum.Material.Sandstone else Enum.Material.Snow,
			Color = if self.theme == 3 then Color3.fromRGB(205, 150, 110) else Color3.fromRGB(230, 238, 248),
		}, m)
	end

	local laneW = W / Config.LANES
	local function laneX(lane: number): number
		return -W / 2 + laneW * (lane - 0.5)
	end

	-- Препятствия и ускорители — на прямых снежных участках
	if seg.kind == "gentle" or seg.kind == "steep" then
		local maxBlocked = math.clamp(1 + (self.level - 1) // 3 + i // 16, 1, 3)
		-- После приземления с обрыва даём место выровняться
		local prev = self.segments[i]
		local safeUntil = if prev and prev.kind == "landing" then 60 else 0
		for row = 1, Config.OBSTACLE_ROWS do
			local z = len * (row - 0.5) / Config.OBSTACLE_ROWS
			local free = {}
			for lane = 1, Config.LANES do
				table.insert(free, lane)
			end
			local h = seg.hStart + z * math.cos(math.rad(seg.angle))
			local count = if h < Config.SAFE_START or z < safeUntil then 0 else rng:NextInteger(0, maxBlocked)
			for _ = 1, count do
				local idx = rng:NextInteger(1, #free)
				local base = cf * CFrame.new(laneX(free[idx]) + rng:NextNumber(-1.5, 1.5), 0, -z)
				tagObstacle(Props.obstacle(self.theme, rng, base, m))
				table.remove(free, idx)
			end
			if rng:NextNumber() < Config.BOOST_CHANCE then
				local idx = rng:NextInteger(1, #free)
				local pad = part("Part", {
					Name = "Boost",
					Size = Vector3.new(laneW - 2, 0.3, 10),
					CFrame = cf * CFrame.new(laneX(free[idx]), 0.15, -(z + 10)),
					Material = Enum.Material.Neon,
					Color = Color3.fromRGB(80, 230, 255),
					CanCollide = false,
				}, m)
				CollectionService:AddTag(pad, "Boost")
				for k = 0, 1 do
					deco({
						Size = Vector3.new(laneW - 5, 0.35, 1.2),
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
	elseif seg.kind == "curve" and i % 2 == 0 then
		-- В жёлобе — дорожка монет, которая «едет» по дуге
		makeCoin(cf * CFrame.new(laneX(3 + (i // 2) % 2), 3, -len / 2), m)
	end

	-- Гемы и кристалл в фиксированных местах уровня, магниты — на прямых
	local cosA = math.cos(math.rad(seg.angle))
	local function zAt(hh: number): number?
		if hh >= seg.hStart and hh < seg.hStart + seg.hLen then
			return (hh - seg.hStart) / cosA
		end
		return nil
	end
	for _, f in Config.GEMS_ON_TRACK do
		local z = zAt(self.length * f)
		if z then
			makeGem(cf * CFrame.new(laneX(rng:NextInteger(2, Config.LANES - 1)), 3, -z), m)
		end
	end
	local zc = zAt(self.length * Config.CRYSTAL_AT)
	if zc then
		makeCrystal(cf * CFrame.new(laneX(rng:NextInteger(2, Config.LANES - 1)), 0, -zc), rng, m)
	end
	if (seg.kind == "gentle" or seg.kind == "steep") and seg.hStart > Config.SAFE_START and rng:NextNumber() < Config.MAGNET_CHANCE then
		makeMagnet(cf * CFrame.new(laneX(rng:NextInteger(1, Config.LANES)), 3, -len * 0.15), m)
	end

	-- Финиш: клетчатая арка
	if self.length >= seg.hStart and self.length < seg.hStart + seg.hLen then
		local z = (self.length - seg.hStart) / math.cos(math.rad(seg.angle))
		local fcf = cf * CFrame.new(0, 0, -z)
		local span = prof.out * 2
		for _, side in { -1, 1 } do
			deco({ Size = Vector3.new(2, 26 + prof.top, 2), CFrame = fcf * CFrame.new(side * (span / 2), 13 + prof.top / 2, 0), Color = Color3.fromRGB(240, 240, 240) }, m)
		end
		local cells = 16
		local cw = span / cells
		for c = 0, cells - 1 do
			for r = 0, 1 do
				deco({
					Size = Vector3.new(cw, 2, 0.8),
					CFrame = fcf * CFrame.new(-span / 2 + cw * (c + 0.5), 24 + prof.top + r * 2, 0),
					Color = if (c + r) % 2 == 0 then Color3.new(0.1, 0.1, 0.1) else Color3.new(1, 1, 1),
				}, m)
			end
			deco({
				Size = Vector3.new(W / cells, 0.1, 3),
				CFrame = fcf * CFrame.new(-W / 2 + (W / cells) * (c + 0.5), 0.05, 0),
				Color = if c % 2 == 0 then Color3.new(0.1, 0.1, 0.1) else Color3.new(1, 1, 1),
			}, m)
		end
	end

	if i == #self.segments - 1 then
		part("Part", {
			Name = "EndWall",
			Size = Vector3.new(prof.out * 2 + 4, 30, 4),
			CFrame = cf * CFrame.new(0, 15, -len),
			Material = Enum.Material.Snow,
			Color = SNOW,
		}, m)
	end

	m.Parent = self.folder
	self.built[i] = m
end

-- Движущийся объект (машина, поезд, кабинка). Двигает клиент по серверному времени —
-- плавно и одинаково у всех. Позиция: path * (s * dir, 0, laneZ), s бежит по кольцу длины loop.
function Track:setMover(model: Model, path: CFrame, laneZ: number, dir: number, speed: number, loop: number, phase: number)
	local yaw = if dir > 0 then -math.pi / 2 else math.pi / 2
	model:SetAttribute("Path", path)
	model:SetAttribute("LaneZ", laneZ)
	model:SetAttribute("Dir", dir)
	model:SetAttribute("Yaw", yaw)
	model:SetAttribute("Speed", speed)
	model:SetAttribute("Loop", loop)
	model:SetAttribute("Phase", phase)
	local t = workspace:GetServerTimeNow()
	local sPos = ((t * speed + phase) % loop) - loop / 2
	model:PivotTo(path * CFrame.new(sPos * dir, 0, laneZ) * CFrame.Angles(0, yaw, 0))
	CollectionService:AddTag(model, "Mover")
end

-- Дорога поперёк трассы с машинами в обе стороны (или ж/д переезд с поездом)
local ASPHALT = Color3.fromRGB(70, 74, 82)
function Track:buildRoad(seg, rng: Random, m: Instance, rail: boolean)
	local cf, len = seg.cf, seg.length
	local road = cf * CFrame.new(0, 0, -len / 2) -- центр дороги; ось X дороги = поперёк трассы
	local span = Config.ROAD_LOOP + 120
	if rail then
		deco({ Size = Vector3.new(span, 0.15, 14), CFrame = road * CFrame.new(0, 0.08, 0), Color = Color3.fromRGB(120, 105, 90), Material = Enum.Material.Pebble }, m)
		for x = -span / 2, span / 2, 3 do
			deco({ Size = Vector3.new(1.2, 0.25, 10), CFrame = road * CFrame.new(x, 0.2, 0), Color = Color3.fromRGB(110, 80, 55), Material = Enum.Material.Wood }, m)
		end
		for _, z in { -3, 3 } do
			deco({ Size = Vector3.new(span, 0.5, 0.5), CFrame = road * CFrame.new(0, 0.5, z), Color = Color3.fromRGB(150, 150, 160), Material = Enum.Material.Metal }, m)
		end
		local train = Props.train(road, m)
		local dir = if rng:NextNumber() < 0.5 then 1 else -1
		self:setMover(train, road, 0, dir, Config.TRAIN_SPEED, Config.TRAIN_LOOP, rng:NextNumber(0, Config.TRAIN_LOOP))
		tagObstacle(train)
		for _, side in { -1, 1 } do
			for _, zz in { -1, 1 } do
				Props.railGate(road * CFrame.new(side * (W / 2 + 4), 0, zz * 9) * CFrame.Angles(0, if zz > 0 then 0 else math.pi, 0), m)
			end
		end
	else
		deco({ Size = Vector3.new(span, 0.15, 22), CFrame = road * CFrame.new(0, 0.08, 0), Color = ASPHALT, Material = Enum.Material.Asphalt }, m)
		for _, z in { -10.4, 10.4 } do
			deco({ Size = Vector3.new(span, 0.18, 0.5), CFrame = road * CFrame.new(0, 0.1, z), Color = Color3.fromRGB(245, 245, 245) }, m)
		end
		for x = -span / 2, span / 2, 9 do
			deco({ Size = Vector3.new(4.5, 0.18, 0.5), CFrame = road * CFrame.new(x, 0.1, 0), Color = Color3.fromRGB(250, 205, 50) }, m)
		end
		-- зебра там, где проходит трасса
		for x = -W / 2 + 3, W / 2 - 3, 4 do
			deco({ Size = Vector3.new(2, 0.2, 7), CFrame = road * CFrame.new(x, 0.11, 13 + 3.5), Color = Color3.fromRGB(245, 245, 245), Transparency = 0.15 }, m)
		end
		local perLane = Config.carsPerLane(self.level)
		for _, lane in { { z = -5.2, dir = 1 }, { z = 5.2, dir = -1 } } do
			local speed = rng:NextNumber(Config.CAR_SPEED[1], Config.CAR_SPEED[2])
			local phase0 = rng:NextNumber(0, Config.ROAD_LOOP)
			for k = 1, perLane do
				local car = Props.traffic(self.theme, rng, road, m)
				local gap = Config.ROAD_LOOP / perLane
				self:setMover(car, road, lane.z, lane.dir, speed, Config.ROAD_LOOP, phase0 + (k - 1) * gap + rng:NextNumber(-gap * 0.2, gap * 0.2))
				tagObstacle(car)
			end
		end
	end
	-- Знаки перед дорогой: стрелки-предупреждения и светофор
	local before = cf * CFrame.new(0, 0, -(len / 2 - 20))
	Props.arrowSign(before * CFrame.new(-(W / 2 + 3), 0, 0) * CFrame.Angles(0, math.pi, 0), -1, m)
	Props.arrowSign(before * CFrame.new(W / 2 + 3, 0, 0) * CFrame.Angles(0, math.pi, 0), 1, m)
	if not rail then
		Props.trafficLight(before * CFrame.new(W / 2 + 6, 0, 4) * CFrame.Angles(0, math.pi, 0), m)
	end
	-- монеты по центру перед дорогой
	for k = 1, 4 do
		makeCoin(cf * CFrame.new(0, 3, -(len / 2 - 6 - k * 5)), m)
	end
end

-- Строим куски впереди игрока и убираем далеко позади (по пройденному пути h)
function Track:ensureAround(h: number)
	for i, seg in self.segments do
		local idx = i - 1
		local startH, endH = seg.hStart, seg.hStart + seg.hLen
		local wanted = endH >= h - Config.KEEP_BEHIND and startH <= h + Config.BUILD_AHEAD
		if wanted and not self.built[idx] then
			self:buildSegment(idx)
		elseif not wanted and self.built[idx] then
			self.built[idx]:Destroy()
			self.built[idx] = nil
		end
	end
end

-- Где игрок на трассе: пройденный путь h, смещение вбок x, высота над дном y.
-- Ищем кусок рядом с прошлым (hint), на который точка проецируется лучше всего.
function Track:progressOf(pos: Vector3): (number, number, number)
	local best, bestScore, bestT, bestRel = nil, math.huge, 0, Vector3.zero
	local from, to = math.max(1, self.hint - 4), math.min(#self.segments, self.hint + 10)
	for i = from, to do
		local seg = self.segments[i]
		local rel = seg.cf:PointToObjectSpace(pos)
		local t = -rel.Z
		if t >= -4 and t <= seg.length + 4 then
			local score = math.abs(rel.X) + math.max(0, -rel.Y) * 0.5
			if score < bestScore then
				best, bestScore, bestT, bestRel = i, score, t, rel
			end
		end
	end
	if not best then
		-- Ещё до старта (позади рогатки) или далеко в полёте — считаем от текущего куска
		local seg = self.segments[self.hint]
		local rel = seg.cf:PointToObjectSpace(pos)
		return seg.hStart + math.clamp(-rel.Z, 0, seg.length) * math.cos(math.rad(seg.angle)), rel.X, rel.Y
	end
	self.hint = best
	local seg = self.segments[best]
	return seg.hStart + math.clamp(bestT, 0, seg.length) * math.cos(math.rad(seg.angle)), bestRel.X, bestRel.Y
end

function Track:destroy()
	self.folder:Destroy()
end

------------------------------------------------------------------ лобби
-- Лобби как в Roblox-референсе: деревянный мостик к рогатке, подиумы с витринными санками,
-- доска лидеров и табло «Следующее обновление».
local function board(name: string, at: CFrame, title: string, parent: Instance): TextLabel
	local m = Instance.new("Model")
	m.Name = name
	for _, sx in { -1, 1 } do
		part("Part", { Size = Vector3.new(1, 16, 1), CFrame = at * CFrame.new(sx * 9, 8, 0.6), Material = Enum.Material.Wood, Color = Color3.fromRGB(120, 80, 45) }, m)
	end
	local panel = part("Part", { Size = Vector3.new(18, 12, 0.6), CFrame = at * CFrame.new(0, 10, 0), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(95, 60, 35) }, m)
	deco({ Size = Vector3.new(18.6, 0.8, 1.4), CFrame = at * CFrame.new(0, 16.3, 0), Material = Enum.Material.Snow, Color = SNOW }, m)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.CanvasSize = Vector2.new(600, 400)
	sg.LightInfluence = 0.3
	sg.Parent = panel
	local head = Instance.new("TextLabel")
	head.BackgroundTransparency = 1
	head.Size = UDim2.new(1, 0, 0, 80)
	head.Font = Enum.Font.FredokaOne
	head.TextScaled = true
	head.TextColor3 = Color3.fromRGB(255, 220, 90)
	head.Text = title
	head.Parent = sg
	local body = Instance.new("TextLabel")
	body.Name = "List"
	body.BackgroundTransparency = 1
	body.Position = UDim2.new(0, 30, 0, 90)
	body.Size = UDim2.new(1, -60, 1, -110)
	body.Font = Enum.Font.FredokaOne
	body.TextScaled = true
	body.TextColor3 = Color3.new(1, 1, 1)
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.Text = "…"
	body.Parent = sg
	m.Parent = parent
	return body
end

-- Витрина: подиум с подсветкой и настоящей моделью саней (как подиумы в Roblox-референсе)
local function showcaseSled(at: CFrame, sledId: string, rarityIdx: number, caption: string, parent: Instance)
	local rarity = Config.RARITIES[rarityIdx]
	local col = rarity.color or Color3.fromRGB(240, 70, 120)
	part("Part", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 13, 13), CFrame = at * CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(235, 240, 250) }, parent)
	local ring = deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 13.6, 13.6), CFrame = at * CFrame.new(0, 1.9, 0) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Neon, Color = col }, parent)
	local holder = Instance.new("Model")
	holder.Name = "Showcase"
	SledModels.build(holder, at * CFrame.new(0, 4, 0) * CFrame.Angles(math.rad(-10), math.rad(30), 0), sledId, {
		main = col,
		accent = Color3.new(1, 1, 1):Lerp(col, 0.35),
		material = rarity.material,
		glow = rarityIdx == 5,
	}, nil, true)
	holder.Parent = parent
	local glow = Instance.new("PointLight")
	glow.Color = col
	glow.Range = 16
	glow.Brightness = 1.5
	glow.Parent = ring
	local anchor = deco({ Size = Vector3.new(1, 1, 1), CFrame = at * CFrame.new(0, 10, 0), Transparency = 1 }, parent)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(220, 50)
	bb.MaxDistance = 90
	bb.Parent = anchor
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.3
	t.Text = caption
	t.Parent = bb
end

function Track.buildLobby()
	local p = Config.LOBBY_POS
	local base = CFrame.new(p)
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"
	-- Площадка лобби заканчивается обрывом: дальше вниз уходит трасса (её видно с мостика)
	part("Part", {
		Size = Vector3.new(150, 4, 90),
		CFrame = base * CFrame.new(0, -2, 5),
		Material = Enum.Material.Snow,
		Color = SNOW,
	}, lobby)
	local rng = Random.new(7)
	for x = -70, 70, 18 do
		Props.pine(rng, base * CFrame.new(x + rng:NextNumber(-4, 4), 0, 48), lobby)
	end
	for z = -36, 40, 18 do
		for _, x in { -70, 70 } do
			Props.pine(rng, base * CFrame.new(x, 0, z + rng:NextNumber(-4, 4)), lobby)
		end
	end
	Props.snowman(rng, base * CFrame.new(-16, 0, 14) * CFrame.Angles(0, math.rad(160), 0), lobby)

	-- Деревянный мостик к старту трассы (как в Roblox-референсе): дойди до края — сядешь в сани
	for z = -6, -60, -3 do
		part("Part", { Size = Vector3.new(14, 0.6, 2.6), CFrame = base * CFrame.new(0, 0.3, z), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(150, 105, 65) }, lobby)
	end
	for _, sx in { -1, 1 } do
		deco({ Size = Vector3.new(0.8, 1, 56), CFrame = base * CFrame.new(sx * 7.4, 1.2, -33), Material = Enum.Material.Wood, Color = Color3.fromRGB(110, 75, 40) }, lobby)
		for z = -6, -60, -8 do
			deco({ Size = Vector3.new(0.6, 2, 0.6), CFrame = base * CFrame.new(sx * 7.4, 1, z), Material = Enum.Material.Wood, Color = Color3.fromRGB(110, 75, 40) }, lobby)
		end
	end
	-- Светящаяся стрелка-указатель у края мостика
	local sign = deco({ Size = Vector3.new(1, 1, 1), CFrame = base * CFrame.new(0, 6, -62), Transparency = 1 }, lobby)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(240, 60)
	bb.MaxDistance = 120
	bb.Parent = sign
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(255, 225, 80)
	t.TextStrokeTransparency = 0.2
	t.Text = "▼ САДИСЬ В САНИ ▼"
	t.Parent = bb

	-- Подиумы с витринными санками
	showcaseSled(base * CFrame.new(-24, 0, -24), "board", 2, "Доска · Gold", lobby)
	showcaseSled(base * CFrame.new(24, 0, -24), "plane", 5, "Сани-самолёт · Galaxy", lobby)

	-- Доска лидеров и табло обновления (лицом к точке появления)
	local lbAt = CFrame.lookAt((base * CFrame.new(34, 0, -10)).Position, p)
	board("Leaderboard", lbAt, "🏆 Лучшие игроки", lobby)
	local upAt = CFrame.lookAt((base * CFrame.new(-34, 0, -10)).Position, p)
	local upText = board("NextUpdate", upAt, "⏳ Следующее обновление", lobby)
	task.spawn(function()
		while lobby.Parent do
			local left = math.max(0, Config.NEXT_UPDATE - os.time())
			upText.TextXAlignment = Enum.TextXAlignment.Center
			upText.Text = if left > 0
				then string.format("%dд %dч %dм\n\nНовый мир и\nновые санки!", left // 86400, (left % 86400) // 3600, (left % 3600) // 60)
				else "Уже скоро!"
			task.wait(30)
		end
	end)

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
