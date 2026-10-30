-- Трасса уровня для одного игрока: широкий белый снежный склон с мягкими сугробами по краям,
-- ледяными проплешинами, обрывами с жёлтыми трамплинами, препятствиями, ускорителями, монетами
-- и финишем. Профиль уровня детерминирован (seed = номер уровня): одна и та же трасса на каждой
-- попытке, её можно выучить — как в оригинале. Геометрия строится кусками впереди игрока.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Props = require(script.Parent.Props)

local part, deco = Props.part, Props.deco

local Track = {}
Track.__index = Track

------------------------------------------------------------------ поперечный профиль
-- Дно шириной W, по краям — два пояса сугроба: пологий и покруче (мягкий «жёлоб» из снега)
local W = Config.TRACK_WIDTH
local BANKS = { { width = 14, angle = 14 }, { width = 14, angle = 32 } }
local BANK_OUT, BANK_TOP = W / 2, 0
for _, b in BANKS do
	BANK_OUT += b.width * math.cos(math.rad(b.angle))
	BANK_TOP += b.width * math.sin(math.rad(b.angle))
end

local SNOW_FLOOR = Color3.fromRGB(236, 243, 252)
local SNOW_BANK = Color3.fromRGB(246, 249, 255)
local SNOW = Color3.fromRGB(250, 252, 255)

-- Точка на «полке» за сугробом, без наклона (дома и деревья стоят ровно)
local function sidePoint(segCF: CFrame, x: number, z: number): CFrame
	return CFrame.new(segCF:PointToWorldSpace(Vector3.new(x, BANK_TOP, -z)))
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

------------------------------------------------------------------ оформление миров
local function dressSegment(theme: number, rng: Random, cf: CFrame, len: number, m: Instance)
	for _, side in { -1, 1 } do
		local at = function(offset: number, z: number): CFrame
			return sidePoint(cf, side * (BANK_OUT + offset), z)
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
			if rng:NextNumber() < 0.25 then
				Props.cabin(rng, at(26, rng:NextNumber(15, len - 15)), side, m)
			end
			if rng:NextNumber() < 0.5 then
				Props.boulder(rng, at(rng:NextNumber(5, 8), rng:NextNumber(0, len)), m, false, 1.3, false)
			end
			if rng:NextNumber() < 0.15 then
				Props.signpost(rng, at(4, rng:NextNumber(0, len)), m)
			end
		elseif theme == 2 then
			-- Город: припаркованные машины у сугроба, ряд домов с маркизами, высотки сзади, фонари
			for z = 8, len, 16 do
				if rng:NextNumber() < 0.55 then
					local van = rng:NextNumber() < 0.25
					local p = at(4, z) * CFrame.Angles(0, if rng:NextNumber() < 0.5 then 0 else math.pi, 0)
					if van then
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
			for tz = 10, len, 30 do
				Props.tower(rng, at(40 + rng:NextNumber(0, 15), tz), side, m)
			end
			for lz = 20, len, 40 do
				Props.streetLamp(at(9, lz), side, m)
			end
			if rng:NextNumber() < 0.4 then
				Props.hydrant(at(9.5, rng:NextNumber(0, len)), m)
			end
		else
			-- Каньон: слоистые скалы, акации, лагерь с костром, ветряк, водонапорная башня, кактусы
			for z = 10, len, 28 do
				Props.mesa(rng, at(rng:NextNumber(30, 42), z), side, m)
			end
			for z = 5, len, 22 do
				if rng:NextNumber() < 0.7 then
					Props.acacia(rng, at(rng:NextNumber(8, 22), z + rng:NextNumber(-5, 5)), m)
				end
			end
			for _ = 1, 2 do
				if rng:NextNumber() < 0.6 then
					Props.cactus(rng, at(rng:NextNumber(4, 10), rng:NextNumber(0, len)), m)
				end
			end
			local feature = rng:NextNumber()
			if feature < 0.3 then
				Props.camp(rng, at(16, rng:NextNumber(20, len - 20)), m)
			elseif feature < 0.42 then
				Props.windmill(at(20, rng:NextNumber(20, len - 20)), side, m)
			elseif feature < 0.52 then
				Props.waterTower(at(20, rng:NextNumber(20, len - 20)), m)
			elseif feature < 0.65 then
				Props.signpost(rng, at(4, rng:NextNumber(0, len)), m)
			end
		end

		-- Горы на горизонте
		if rng:NextNumber() < 0.6 then
			Props.mountain(rng, at(rng:NextNumber(140, 200), rng:NextNumber(0, len)), theme == 3, m)
		end
	end
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
	local m = Instance.new("Model")
	m.Name = "Start"
	part("Part", {
		Size = Vector3.new(BANK_OUT * 2, 4, 30),
		CFrame = self.origin * CFrame.new(0, -2, 15),
		Material = Enum.Material.Snow,
		Color = SNOW_FLOOR,
	}, m)
	-- Рогатка: деревянные стойки
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

function Track:buildSegment(i: number)
	local seg = self.segments[i + 1]
	if not seg then
		return
	end
	local rng = Random.new(self.level * 104729 + i * 31)
	local cf, len = seg.cf, seg.length
	local m = Instance.new("Model")
	m.Name = "Segment_" .. i

	-- Снежное дно
	part("Part", {
		Name = "Floor",
		Size = Vector3.new(W, 4, len + 2),
		CFrame = cf * CFrame.new(0, -2, -len / 2),
		Material = Enum.Material.Snow,
		Color = SNOW_FLOOR,
	}, m)
	-- Ледяные проплешины на снегу
	for _ = 1, rng:NextInteger(2, 4) do
		local patch = deco({
			Size = Vector3.new(rng:NextNumber(10, 26), 0.1, rng:NextNumber(14, 34)),
			CFrame = cf * CFrame.new(rng:NextNumber(-W / 2 + 8, W / 2 - 8), 0.04, -rng:NextNumber(10, len - 10))
				* CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0),
			Material = Enum.Material.Glacier,
			Color = Color3.fromRGB(150, 200, 240),
			Transparency = 0.15,
		}, m)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = patch
	end
	-- Едва заметные накатанные колеи
	for _, x in { -W * 0.25, W * 0.05, W * 0.3 } do
		deco({
			Size = Vector3.new(0.6, 0.05, len),
			CFrame = cf * CFrame.new(x + rng:NextNumber(-3, 3), 0.03, -len / 2),
			Color = Color3.fromRGB(205, 225, 245),
			Transparency = 0.35,
		}, m)
	end

	-- Сугробы по краям (два пояса), полка за ними и невидимые стенки
	for _, side in { -1, 1 } do
		local x, y = W / 2, 0
		for _, b in BANKS do
			local a = math.rad(b.angle)
			part("Part", {
				Name = "Bank",
				Size = Vector3.new(b.width, 2, len + 2),
				CFrame = cf * CFrame.new(side * x, y, -len / 2) * CFrame.Angles(0, 0, side * a) * CFrame.new(side * b.width / 2, -1, 0),
				Material = Enum.Material.Snow,
				Color = SNOW_BANK,
			}, m)
			x += b.width * math.cos(a)
			y += b.width * math.sin(a)
		end
		-- Мягкая округлая кромка сугроба
		deco({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(len + 3, 6, 6),
			CFrame = cf * CFrame.new(side * (BANK_OUT + 1), BANK_TOP - 1.2, -len / 2) * CFrame.Angles(0, math.rad(90), 0),
			Material = Enum.Material.Snow,
			Color = SNOW,
		}, m)
		part("Part", {
			Name = "Ground",
			Size = Vector3.new(150, 2, len + 2),
			CFrame = cf * CFrame.new(side * (BANK_OUT + 75), BANK_TOP - 1, -len / 2),
			Material = Enum.Material.Snow,
			Color = SNOW,
			CanCollide = false,
		}, m)
		part("Part", {
			Name = "Barrier",
			Size = Vector3.new(2, 40, len + 2),
			CFrame = cf * CFrame.new(side * (BANK_OUT + 2), BANK_TOP + 10, -len / 2),
			Transparency = 1,
			CanQuery = false,
		}, m)
	end

	dressSegment(self.theme, rng, cf, len, m)

	-- Обрыв: жёлтый трамплин в конце + обрыв вниз
	if seg.kind == "kicker" then
		Props.ramp(cf * CFrame.new(0, 0, -(len - 9)), W, 18, 5, m)
		local endPos = cf:PointToWorldSpace(Vector3.new(0, 0, -len))
		deco({
			Size = Vector3.new(BANK_OUT * 2 + 300, Config.KICKER_DROP + 4, 3),
			CFrame = CFrame.new(endPos + Vector3.new(0, -Config.KICKER_DROP / 2 - 2, 1.5)),
			Material = if self.theme == 3 then Enum.Material.Sandstone else Enum.Material.Snow,
			Color = if self.theme == 3 then Color3.fromRGB(205, 150, 110) else Color3.fromRGB(230, 238, 248),
		}, m)
	end

	-- Препятствия, ускорители, монеты
	if seg.kind == "gentle" or seg.kind == "steep" then
		local laneW = W / Config.LANES
		local function laneX(lane: number): number
			return -W / 2 + laneW * (lane - 0.5)
		end
		local maxBlocked = math.clamp(1 + (self.level - 1) // 2 + i // 8, 1, Config.LANES - 2)
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
	end

	-- Финиш: клетчатая арка
	if self.length >= seg.hStart and self.length < seg.hStart + seg.hLen then
		local z = (self.length - seg.hStart) / math.cos(math.rad(seg.angle))
		local fcf = cf * CFrame.new(0, 0, -z)
		local span = BANK_OUT * 2
		for _, side in { -1, 1 } do
			deco({ Size = Vector3.new(2, 26, 2), CFrame = fcf * CFrame.new(side * (span / 2), 13, 0), Color = Color3.fromRGB(240, 240, 240) }, m)
		end
		local cells = 16
		local cw = span / cells
		for c = 0, cells - 1 do
			for r = 0, 1 do
				deco({
					Size = Vector3.new(cw, 2, 0.8),
					CFrame = fcf * CFrame.new(-span / 2 + cw * (c + 0.5), 24 + r * 2, 0),
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
			Size = Vector3.new(BANK_OUT * 2 + 4, 30, 4),
			CFrame = cf * CFrame.new(0, 15, -len),
			Material = Enum.Material.Snow,
			Color = SNOW,
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
		Color = SNOW,
	}, lobby)
	local rng = Random.new(7)
	for x = -40, 40, 20 do
		for _, z in { -40, 40 } do
			Props.pine(rng, CFrame.new(p + Vector3.new(x, 0, z)), lobby)
		end
	end
	Props.snowman(rng, CFrame.new(p + Vector3.new(18, 0, -12)) * CFrame.Angles(0, math.rad(200), 0), lobby)
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
