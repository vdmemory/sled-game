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

	if i >= Config.SAFE_SEGMENTS then
		local count = math.min(2 + i // 4, 9)
		for _ = 1, count do
			local x = rng:NextNumber(-W / 2 + 5, W / 2 - 5)
			local z = rng:NextNumber(6, L - 6)
			if rng:NextNumber() < 0.5 then
				addRock(rng, segCF, x, z, model)
			else
				addTree(segCF, x, z, model)
			end
		end
		if rng:NextNumber() < Config.RAMP_CHANCE then
			addRamp(segCF, rng:NextNumber(-W / 2 + 10, W / 2 - 10), rng:NextNumber(20, L - 30), model)
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
