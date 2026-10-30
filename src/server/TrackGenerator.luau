-- Процедурная бесконечная трасса: сегменты строятся впереди игроков и удаляются позади.
-- Один и тот же индекс сегмента с тем же seed всегда даёт одинаковую раскладку.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Track = {}

local ORIGIN = Config.trackOrigin()
Track.ORIGIN = ORIGIN

local folder = Instance.new("Folder")
folder.Name = "Track"
folder.Parent = workspace

local segments: { [number]: Model } = {}
local seed = os.time()
local maxBuilt = -1

local function makePart(className: string, props: { [string]: any }): BasePart
	local p = Instance.new(className) :: BasePart
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local function obstacle(part: BasePart, parent: Instance)
	CollectionService:AddTag(part, "Obstacle")
	part.Parent = parent
end

local function addRock(rng: Random, segCF: CFrame, x: number, z: number, parent: Instance)
	local s = rng:NextNumber(5, 9)
	local rock = makePart("Part", {
		Name = "Rock",
		Size = Vector3.new(s, s * 0.8, s),
		CFrame = segCF * CFrame.new(x, s * 0.4 - 0.5, -z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(110, 115, 125),
	})
	obstacle(rock, parent)
end

local function addTree(segCF: CFrame, x: number, z: number, parent: Instance)
	local base = segCF * CFrame.new(x, 0, -z)
	local trunk = makePart("Part", {
		Name = "Trunk",
		Size = Vector3.new(2, 8, 2),
		CFrame = base * CFrame.new(0, 4, 0),
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(105, 70, 40),
	})
	obstacle(trunk, parent)
	local crown = makePart("Part", {
		Name = "Crown",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(9, 9, 9),
		CFrame = base * CFrame.new(0, 11, 0),
		Material = Enum.Material.Grass,
		Color = Color3.fromRGB(40, 110, 60),
	})
	obstacle(crown, parent)
end

local function addRamp(segCF: CFrame, x: number, z: number, parent: Instance)
	-- WedgePart: низкий край спереди (-Z). Разворачиваем на 180°, чтобы игрок въезжал
	-- на низкий край. Если в Studio трамплин стоит «стенкой» к игроку — убери поворот.
	local ramp = makePart("WedgePart", {
		Name = "Ramp",
		Size = Vector3.new(16, 6, 22),
		CFrame = segCF * CFrame.new(x, 3, -z) * CFrame.Angles(0, math.pi, 0),
		Material = Enum.Material.Ice,
		Color = Color3.fromRGB(150, 200, 255),
	})
	ramp.Parent = parent
end

local function addDecorTree(rng: Random, segCF: CFrame, x: number, z: number, parent: Instance)
	local h = rng:NextNumber(10, 22)
	local base = segCF * CFrame.new(x, 0, -z)
	makePart("Part", {
		Name = "DecorTrunk",
		Size = Vector3.new(2, h * 0.4, 2),
		CFrame = base * CFrame.new(0, h * 0.2, 0),
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(95, 65, 40),
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	}).Parent = parent
	-- Ёлка из трёх ярусов, верхний с «снежной шапкой»
	local green = Color3.fromRGB(35, 95 + rng:NextInteger(0, 25), 60)
	for tier = 0, 2 do
		local w = h * (0.6 - tier * 0.17)
		makePart("Part", {
			Name = "DecorCrown",
			Size = Vector3.new(w, h * 0.22, w),
			CFrame = base * CFrame.new(0, h * (0.45 + tier * 0.2), 0) * CFrame.Angles(0, math.rad(tier * 30), 0),
			Material = if tier == 2 then Enum.Material.Snow else Enum.Material.Grass,
			Color = if tier == 2 then Color3.fromRGB(245, 250, 255) else green,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		}).Parent = parent
	end
end

local function addCoin(segCF: CFrame, x: number, z: number, parent: Instance)
	local coin = makePart("Part", {
		Name = "Coin",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 3, 3),
		-- Цилиндр в Roblox вытянут по X; поворачиваем ребром к игроку
		CFrame = segCF * CFrame.new(x, 2.5, -z) * CFrame.Angles(0, math.rad(90), 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 200, 40),
		CanCollide = false,
		CanQuery = false,
	})
	CollectionService:AddTag(coin, "Coin")
	coin.Parent = parent
end

local function buildSegment(i: number)
	local rng = Random.new(seed + i * 7919)
	local L, W = Config.SEGMENT_LENGTH, Config.TRACK_WIDTH
	local segCF = ORIGIN * CFrame.new(0, 0, -i * L)

	local model = Instance.new("Model")
	model.Name = "Segment_" .. i

	makePart("Part", {
		Name = "Floor",
		Size = Vector3.new(W, 4, L),
		CFrame = segCF * CFrame.new(0, -2, -L / 2),
		Material = Enum.Material.Snow,
		Color = if i % 2 == 0 then Color3.fromRGB(240, 245, 255) else Color3.fromRGB(226, 236, 250),
	}).Parent = model

	for _, side in { -1, 1 } do
		makePart("Part", {
			Name = "Rail",
			Size = Vector3.new(2, 6, L),
			CFrame = segCF * CFrame.new(side * (W / 2 + 1), 3, -L / 2),
			Material = Enum.Material.Ice,
			Color = Color3.fromRGB(180, 220, 255),
			Transparency = 0.3,
		}).Parent = model
	end

	-- Декор за бортиками: ёлки по краям, чтобы чувствовалась скорость
	for z = 10, L, 30 do
		for _, side in { -1, 1 } do
			addDecorTree(rng, segCF, side * (W / 2 + rng:NextNumber(8, 30)), z + rng:NextNumber(-8, 8), model)
		end
	end

	-- Препятствия рядами по полосам: в каждом ряду гарантированно остаются свободные полосы
	local lanes = Config.LANES
	local laneW = W / lanes
	local function laneX(lane: number): number
		return -W / 2 + laneW * (lane - 0.5)
	end

	local rowStep = L / Config.ROWS_PER_SEGMENT
	for row = 1, Config.ROWS_PER_SEGMENT do
		local z = rowStep * (row - 0.5)
		local free = {}
		for lane = 1, lanes do
			table.insert(free, lane)
		end

		local isSafe = i < Config.SAFE_SEGMENTS
		if not isSafe then
			-- Сложность растёт с дистанцией, но максимум lanes - 2 занятых полос
			local maxBlocked = math.clamp(1 + i // Config.SEGMENTS_PER_DIFFICULTY, 1, lanes - 2)
			local blocked = rng:NextInteger(1, maxBlocked)

			if rng:NextNumber() < Config.RAMP_CHANCE / Config.ROWS_PER_SEGMENT then
				local idx = rng:NextInteger(1, #free)
				addRamp(segCF, laneX(free[idx]), z, model)
				table.remove(free, idx)
				blocked -= 1
			end

			for _ = 1, blocked do
				local idx = rng:NextInteger(1, #free)
				local x = laneX(free[idx]) + rng:NextNumber(-2, 2)
				if rng:NextNumber() < 0.5 then
					addRock(rng, segCF, x, z, model)
				else
					addTree(segCF, x, z, model)
				end
				table.remove(free, idx)
			end
		end

		-- Линия монет в одной из свободных полос, между рядами
		if rng:NextNumber() < Config.COIN_LINE_CHANCE then
			local lane = free[rng:NextInteger(1, #free)]
			for k = 1, Config.COINS_PER_LINE do
				addCoin(segCF, laneX(lane), z + rowStep * 0.5 * (k / (Config.COINS_PER_LINE + 1)) - rowStep * 0.25, model)
			end
		end
	end

	model.Parent = folder
	segments[i] = model
	maxBuilt = math.max(maxBuilt, i)
end

function Track.ensure(fromIdx: number, toIdx: number)
	for i = math.max(0, fromIdx), toIdx do
		if not segments[i] then
			buildSegment(i)
		end
	end
end

function Track.cleanup(minKeep: number)
	for i, model in segments do
		if i < minKeep then
			model:Destroy()
			segments[i] = nil
		end
	end
end

function Track.needsReset(): boolean
	return maxBuilt > Config.SEGMENTS_AHEAD or segments[0] == nil
end

-- Новая раскладка трассы (когда на трассе никого нет)
function Track.reset()
	for _, model in segments do
		model:Destroy()
	end
	table.clear(segments)
	maxBuilt = -1
	seed = os.time() + math.random(1, 1e6)
	Track.ensure(0, Config.SEGMENTS_AHEAD)
end

-- Позиция относительно трассы: пройденная дистанция, смещение вбок, высота над склоном
function Track.progressOf(pos: Vector3): (number, number, number)
	local rel = ORIGIN:PointToObjectSpace(pos)
	return -rel.Z, rel.X, rel.Y
end

function Track.segmentIndexAt(distance: number): number
	return math.max(0, math.floor(distance / Config.SEGMENT_LENGTH))
end

function Track.buildLobby()
	local start = Config.START_POS
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"

	makePart("Part", {
		Name = "Platform",
		Size = Vector3.new(80, 4, 80),
		CFrame = CFrame.new(start + Vector3.new(0, -2, 40)),
		Material = Enum.Material.Snow,
		Color = Color3.fromRGB(245, 248, 255),
	}).Parent = lobby

	-- Стенка между лобби и склоном: пешком на трассу не выйти
	makePart("Part", {
		Name = "Gate",
		Size = Vector3.new(Config.TRACK_WIDTH + 4, 20, 1),
		CFrame = CFrame.new(start + Vector3.new(0, 10, 0)),
		Material = Enum.Material.Ice,
		Color = Color3.fromRGB(160, 210, 255),
		Transparency = 0.6,
	}).Parent = lobby

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(start + Vector3.new(0, 0.5, 50))
	spawn.Duration = 0
	spawn.Parent = lobby

	lobby.Parent = workspace
end

return Track
