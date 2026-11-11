-- Трасса уровня для одного игрока: широкий белый снежный склон с мягкими сугробами по краям,
-- ледяными проплешинами, обрывами с жёлтыми трамплинами, препятствиями, ускорителями, монетами
-- и финишем. Профиль уровня детерминирован (seed = номер уровня): одна и та же трасса на каждой
-- попытке, её можно выучить — как в оригинале. Геометрия строится кусками впереди игрока.
-- Модуль разбит на части (папка Track/): Profile — профиль уровня, Sections — поперечные сечения,
-- Dress — оформление миров, Items — монеты и бонусы; здесь — класс трассы (сборка кусков,
-- стриминг, прогресс игрока).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Props = require(ReplicatedStorage.Shared.Props)
local SledModels = require(ReplicatedStorage.Shared.SledModels)
local Lobby = require(ReplicatedStorage.Shared.Lobby)
local SafeLine = require(ReplicatedStorage.Shared.SafeLine)
local Islands = require(ReplicatedStorage.Shared.Islands)
local Profile = require(script.Profile)
local Sections = require(script.Sections)
local Dress = require(script.Dress)
local Items = require(script.Items)
local Tunnel = require(script.Tunnel)

local part, deco = Props.part, Props.deco
local W = Sections.W
local CHUTE_PROFILE, ROAD_PROFILE, LAKE_PROFILE, SNOW_PROFILE = Sections.CHUTE_PROFILE, Sections.ROAD_PROFILE, Sections.LAKE_PROFILE, Sections.SNOW_PROFILE
local BANK_OUT, BANK_TOP = Sections.BANK_OUT, Sections.BANK_TOP
local SNOW_FLOOR, SNOW = Sections.SNOW_FLOOR, Sections.SNOW
local buildProfile, buildCrossSection = Profile.build, Sections.build
local dressSegment, dressTrack = Dress.segment, Dress.track
local tagObstacle = Items.tagObstacle
local makeCoin, makeGem, makeMagnet, makeCrystal = Items.coin, Items.gem, Items.magnet, Items.crystal
local makeShield, makeX2, makeFuel, makeRing = Items.shield, Items.x2, Items.fuel, Items.ring

local Track = {}
Track.__index = Track

------------------------------------------------------------------ класс
-- slot — номер слота игрока (расположение по X); origin — явная точка старта (витрина лобби);
-- maxSegments — витрина: строить только первые N кусков (без стриминга и без стены в конце).
-- Модуль общий: сервер строит трассы заездов, клиент — локальную витрину за мостиком лобби.
function Track.new(slot: number, level: number, bestH: number?, origin: CFrame?, maxSegments: number?)
	local self = setmetatable({}, Track)
	self.level = level
	self.bestH = bestH or 0
	self.theme = Config.themeOf(level)
	self.origin = origin or CFrame.new(Config.TRACKS_ORIGIN + Vector3.new(slot * Config.SLOT_SPACING, 0, 0))
	self.segments, self.length = buildProfile(self.origin, level)
	-- Раскладка рядов препятствий с безопасной линией — один раз на уровень (SafeLine, #29)
	self.rowPlan = SafeLine.plan(self.segments, level)
	self.preview = maxSegments ~= nil
	if maxSegments then
		-- витрина: первые maxSegments «настоящих» кусков (переходы и части пола поворота не считаем)
		local keep, major = #self.segments, 0
		for i, seg in self.segments do
			if seg.kind ~= "fillet" and seg.vis ~= 0 then
				major += 1
				if major > maxSegments then
					keep = i - 1
					break
				end
			end
		end
		for i = #self.segments, keep + 1, -1 do
			self.segments[i] = nil
		end
	end
	self.built = {} :: { [number]: Model }
	self.clears = {} :: { [number]: { any } } -- заливки Terrain по кускам (стираются вместе с куском)
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
			Transparency = 1,
		}, m)
		-- видимый столб (дизайн по тиру рогатки; в заезде Main пересобирает под игрока)
		local look = Instance.new("Folder")
		look.Name = "Look"
		look.Parent = post
		SledModels.slingshot(look, post.CFrame, 0)
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
	local prof = if seg.chute then CHUTE_PROFILE
		elseif seg.kind == "road" or seg.kind == "rail" then ROAD_PROFILE
		elseif seg.kind == "lake" then LAKE_PROFILE
		else SNOW_PROFILE
	local m = Instance.new("Model")
	m.Name = "Segment_" .. i
	-- островки и пропасть (#40) строит shared/Islands; остальное — общее сечение трассы
	local special = seg.kind == "isle" or seg.kind == "gap"
	local visLen = if seg.vis ~= nil then seg.vis else len
	if special then
		local kit = {
			coin = makeCoin,
			shield = makeShield,
			x2 = makeX2,
			fuel = makeFuel,
			magnet = makeMagnet,
			dress = function(dcf: CFrame, dprof)
				dressSegment(self.theme, rng, dcf, len, m, dprof)
			end,
		}
		self.clears[i] = if seg.kind == "isle" then Islands.buildIsle(self, seg, m, rng, kit) else Islands.buildGap(self, seg, m, rng, kit)
	else
		buildCrossSection(cf, len, prof, seg.chute, m, i % 2, self.theme, seg.kind == "landing", seg)
	end
	if seg.kind == "isleIn" then
		Islands.buildIn(self, seg, m)
	end
	dressTrack(self.theme, Random.new(self.level * 7907 + i * 13), seg, m)

	if special or seg.kind == "fillet" or visLen <= 0 then
		-- островки, переходы и части пола поворота: без проплешин и декора обочин
	elseif seg.kind == "road" or seg.kind == "rail" then
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

	if not special and seg.kind ~= "road" and seg.kind ~= "rail" and seg.kind ~= "fillet" and visLen > 0 then
		dressSegment(self.theme, rng, cf, visLen, m, prof)
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

	-- Тоннель (#65): весь поворот под сводом — вид по миру, порталы на входе и выходе (Track/Tunnel)
	if seg.tunnel and visLen > 0 then
		Tunnel.build(self.theme, seg, cf, visLen, prof, m)
	end

	-- Флаг рекорда: где игрок остановился в лучшей попытке
	if not special and self.bestH > 0 and self.bestH >= seg.hStart and self.bestH < seg.hStart + seg.hLen then
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
			Material = if self.theme == 3 then Enum.Material.Sandstone elseif self.theme == 6 then Enum.Material.Basalt else Enum.Material.Snow,
			Color = if self.theme == 3 then Color3.fromRGB(205, 150, 110) elseif self.theme == 6 then Color3.fromRGB(70, 66, 72) elseif self.theme == 7 then Color3.fromRGB(255, 225, 240) else Color3.fromRGB(230, 238, 248),
		}, m)
	end

	local laneW = W / Config.LANES
	local function laneX(lane: number): number
		return -W / 2 + laneW * (lane - 0.5)
	end

	-- Препятствия и ускорители — на прямых снежных участках
	if seg.kind == "gentle" or seg.kind == "steep" then
		-- Занятые полосы и безопасная линия заранее посчитаны в SafeLine.plan (детерминированно)
		local rows = self.rowPlan[i] or {}
		for r, plan in rows do
			local z = plan.z
			for _, lane in plan.blocked do
				local base = cf * CFrame.new(laneX(lane) + rng:NextNumber(-1.5, 1.5), 0, -z)
				tagObstacle(Props.obstacle(self.theme, rng, base, m))
			end
			-- свободные полосы ряда, кроме безопасной (её держим под линию монет)
			local free = {}
			for lane = 1, Config.LANES do
				if lane ~= plan.safe and not table.find(plan.blocked, lane) then
					table.insert(free, lane)
				end
			end
			if #free > 0 and rng:NextNumber() < Config.BOOST_CHANCE then
				local lane = free[rng:NextInteger(1, #free)]
				local pad = part("Part", {
					Name = "Boost",
					Size = Vector3.new(laneW - 2, 0.3, 10),
					CFrame = cf * CFrame.new(laneX(lane), 0.15, -(z + 10)),
					Material = Enum.Material.Neon,
					Color = Color3.fromRGB(80, 230, 255),
					CanCollide = false,
				}, m)
				CollectionService:AddTag(pad, "Boost")
				for k = 0, 1 do
					deco({
						Size = Vector3.new(laneW - 5, 0.35, 1.2),
						CFrame = cf * CFrame.new(laneX(lane), 0.2, -(z + 6 + k * 4)),
						Material = Enum.Material.Neon,
						Color = Color3.new(1, 1, 1),
					}, m)
				end
			end
			-- Линия монет ведёт по безопасной линии от этого ряда к следующему
			local nextRow = rows[r + 1]
			if nextRow and rng:NextNumber() < Config.COIN_LINE_CHANCE then
				local x0, x1 = laneX(plan.safe), laneX(nextRow.safe)
				local step = nextRow.z - z
				for k = 1, Config.COINS_PER_LINE do
					local f = k / (Config.COINS_PER_LINE + 1)
					makeCoin(cf * CFrame.new(x0 + (x1 - x0) * f, 3, -(z + step * f)), m)
				end
			end
		end
	elseif seg.kind == "wave" and seg.crest then
		-- монеты на гребне волны: линия по центру подъёма, чуть выше — ловятся в подлёте
		local lane = 2 + (seg.crest % (Config.LANES - 2))
		for k = 1, 3 do
			makeCoin(cf * CFrame.new(laneX(lane), 3.5, -(len * 0.35 + k * 4)), m)
		end
	elseif seg.kind == "curve" and visLen > 0 and (seg.ci or 0) % 2 == 0 then
		-- В жёлобе — дорожка монет, которая «едет» по дуге
		makeCoin(cf * CFrame.new(laneX(3 + ((seg.ci or 0) // 2) % 2), 3, -visLen / 2), m)
	end

	-- Гемы и кристалл в фиксированных местах уровня, магниты — на прямых
	local cosA = math.cos(math.rad(seg.angle))
	local function zAt(hh: number): number?
		if hh >= seg.hStart and hh < seg.hStart + seg.hLen then
			return (hh - seg.hStart) / cosA
		end
		return nil
	end
	-- над пропастью гем/кристалл висят в вершине дуги монет (ловятся в прыжке)
	local function bonusAt(z: number, y: number): CFrame
		if seg.kind == "gap" then
			local arc = seg.isle.arc
			local p = arc[math.max(1, math.ceil(#arc / 2))]
			local look = cf.LookVector
			local flat = CFrame.lookAt(cf.Position, cf.Position + Vector3.new(look.X, 0, look.Z))
			return flat * CFrame.new(0, (if p then p[2] else 8) + y - 3, -(if p then p[1] else len / 2))
		end
		return cf * CFrame.new(laneX(rng:NextInteger(2, Config.LANES - 1)), y, -z)
	end
	for _, f in Config.GEMS_ON_TRACK do
		local z = zAt(self.length * f)
		if z then
			makeGem(bonusAt(z, 3), m)
		end
	end
	local zc = zAt(self.length * Config.CRYSTAL_AT)
	if zc then
		makeCrystal(bonusAt(zc, 0), rng, m)
	end
	if (seg.kind == "gentle" or seg.kind == "steep") and seg.hStart > Config.SAFE_START and rng:NextNumber() < Config.MAGNET_CHANCE then
		makeMagnet(cf * CFrame.new(laneX(rng:NextInteger(1, Config.LANES)), 3, -len * 0.15), m)
	end
	-- Бонусы: щит, x2, канистра — по одному на кусок; кольца — тройкой по одной полосе
	if (seg.kind == "gentle" or seg.kind == "steep") and seg.hStart > Config.SAFE_START then
		local P = Config.POWERUPS
		local roll = rng:NextNumber()
		local at = cf * CFrame.new(laneX(rng:NextInteger(1, Config.LANES)), 3, -len * 0.55)
		if roll < P.shield.chance then
			makeShield(at, m)
		elseif roll < P.shield.chance + P.x2.chance then
			makeX2(at, m)
		elseif roll < P.shield.chance + P.x2.chance + P.fuel.chance then
			makeFuel(at, m)
		end
		if rng:NextNumber() < P.rings.chance and len > 60 then
			local lane = rng:NextInteger(1, Config.LANES)
			for k = 0, 2 do
				makeRing(cf * CFrame.new(laneX(lane), 0, -(len * 0.3 + k * 14)), m)
			end
		end
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

	if i == #self.segments - 1 and not self.preview then
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
			Islands.clear(self.clears[idx]) -- скалы Terrain островков
			self.clears[idx] = nil
		end
	end
end

-- Где игрок на трассе: пройденный путь h, смещение вбок x, высота над дном y.
-- Ищем кусок рядом с прошлым (hint), на который точка проецируется лучше всего.
function Track:progressOf(pos: Vector3): (number, number, number)
	local best, bestScore, bestT, bestRel = nil, math.huge, 0, Vector3.zero
	-- окно поиска: куски пола поворота и переходы короткие (3–4 studs) — смотрим дальше вперёд
	local from, to = math.max(1, self.hint - 8), math.min(#self.segments, self.hint + 40)
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

-- Куда вернуть сани, вылетевшие с трассы (страховка «мягкий возврат», server/Runs): на дно
-- текущего куска (последний найденный progressOf) ближе к оси, на RESCUE_LIFT над снегом, лицом
-- вниз по склону. Над пропастью островков, на островках и разгоне к ним, на озере после финиша
-- и до рогатки — nil: там падение — честный конец заезда («fell»).
local NO_RESCUE = { gap = true, isle = true, isleIn = true, lake = true, start = true }
function Track:rescueCFrame(pos: Vector3): CFrame?
	local seg = self.segments[self.hint]
	if not seg or NO_RESCUE[seg.kind] then
		return nil
	end
	local rel = seg.cf:PointToObjectSpace(pos)
	local t = math.clamp(-rel.Z, 2, math.max(2, seg.length - 2))
	local x = math.clamp(rel.X, -(W / 2 - Config.RESCUE_INSET), W / 2 - Config.RESCUE_INSET)
	return seg.cf * CFrame.new(x, Config.RESCUE_LIFT, -t)
end

function Track:destroy()
	for idx, c in self.clears do
		Islands.clear(c)
		self.clears[idx] = nil
	end
	self.folder:Destroy()
end

------------------------------------------------------------------ лобби
-- Архитектура лобби живёт в shared/Lobby (Lobby.build — сервер, Lobby.dress — клиент по миру);
-- обёртка оставлена для Main.server.
function Track.buildLobby()
	Lobby.build()
end

return Track
