-- Главный серверный скрипт: игроки, заезды, монеты, апгрейды, трасса.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")

local Config = require(ReplicatedStorage.Shared.Config)
local Track = require(script.Parent.TrackGenerator)
local Data = require(script.Parent.DataService)

------------------------------------------------------------------ Remotes
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local function remote(className: string, name: string): any
	local r = Instance.new(className)
	r.Name = name
	r.Parent = remotes
	return r
end
local StartRun: RemoteEvent = remote("RemoteEvent", "StartRun")
local Crash: RemoteEvent = remote("RemoteEvent", "Crash")
local Trick: RemoteEvent = remote("RemoteEvent", "Trick")
local RunEnded: RemoteEvent = remote("RemoteEvent", "RunEnded")
local BuyUpgrade: RemoteFunction = remote("RemoteFunction", "BuyUpgrade")
remotes.Parent = ReplicatedStorage

------------------------------------------------------------------ Мир
-- Санки и персонажи разных игроков проходят сквозь друг друга
PhysicsService:RegisterCollisionGroup("Riders")
PhysicsService:CollisionGroupSetCollidable("Riders", "Riders", false)

local function setRider(part: Instance)
	if part:IsA("BasePart") then
		part.CollisionGroup = "Riders"
	end
end

local sledsFolder = Instance.new("Folder")
sledsFolder.Name = "Sleds"
sledsFolder.Parent = workspace

Track.buildLobby()
Track.reset()

------------------------------------------------------------------ Игроки
local function syncPlayer(player: Player)
	local d = Data.get(player)
	if not d then
		return
	end
	player:SetAttribute("Coins", d.Coins)
	player:SetAttribute("Best", d.Best)
	player:SetAttribute("SpeedLevel", d.SpeedLevel)
	player:SetAttribute("ControlLevel", d.ControlLevel)
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		(ls :: any)["Рекорд"].Value = math.floor(d.Best);
		(ls :: any)["Монеты"].Value = d.Coins
	end
end

local function onCharacter(character: Model)
	for _, d in character:GetDescendants() do
		setRider(d)
	end
	character.DescendantAdded:Connect(setRider)
end

local function onPlayerAdded(player: Player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local rec = Instance.new("IntValue")
	rec.Name = "Рекорд"
	rec.Parent = ls
	local coins = Instance.new("IntValue")
	coins.Name = "Монеты"
	coins.Parent = ls
	ls.Parent = player

	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end

	Data.load(player)

	if Config.GAMEPASS_X2_COINS ~= 0 then
		local ok, owns = pcall(
			MarketplaceService.UserOwnsGamePassAsync,
			MarketplaceService,
			player.UserId,
			Config.GAMEPASS_X2_COINS
		)
		player:SetAttribute("X2Coins", ok and owns or false)
	end

	syncPlayer(player)
	player:SetAttribute("Loaded", true)
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if purchased and passId == Config.GAMEPASS_X2_COINS then
		player:SetAttribute("X2Coins", true)
	end
end)

------------------------------------------------------------------ Заезды
type Run = {
	sled: VehicleSeat,
	distance: number,
	trickCoins: number,
	lastTrick: number,
	ended: boolean?,
}
local runs: { [Player]: Run } = {}

local function endRun(player: Player, reason: string)
	local run = runs[player]
	if not run or run.ended then
		return
	end
	run.ended = true
	runs[player] = nil

	local dist = math.floor(run.distance)
	local mult = if player:GetAttribute("X2Coins") then 2 else 1
	local earned = (dist // Config.STUDS_PER_COIN + run.trickCoins) * mult
	local newRecord = false

	local d = Data.get(player)
	if d then
		d.Coins += earned
		if dist > d.Best then
			d.Best = dist
			newRecord = true
		end
		syncPlayer(player)
	end

	player:SetAttribute("InRun", false)
	RunEnded:FireClient(player, {
		distance = dist,
		coins = earned,
		newRecord = newRecord,
		reason = reason,
	})

	if run.sled then
		run.sled:Destroy()
	end
	task.delay(1.5, function()
		if player.Parent then
			player:LoadCharacter()
		end
	end)
end

local function makeSled(player: Player): VehicleSeat
	local seat = Instance.new("VehicleSeat")
	seat.Name = "Sled"
	seat.Size = Vector3.new(4, 1, 7)
	seat.Color = Color3.fromRGB(210, 45, 45)
	seat.Material = Enum.Material.SmoothPlastic
	-- VehicleSeat нужен только ради SteerFloat (ввод с клавиатуры/геймпада/тача).
	-- Сам он ничего не двигает — движением управляет SledController на клиенте.
	seat.MaxSpeed = 0
	seat.Torque = 0
	seat.TurnSpeed = 0
	seat.HeadsUpDisplay = false
	seat.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0, 0, 100, 100)
	seat.CollisionGroup = "Riders"
	seat.CFrame = Track.ORIGIN * CFrame.new(math.random(-10, 10), 1.5, -15)

	local att = Instance.new("Attachment")
	att.Parent = seat
	local align = Instance.new("AlignOrientation")
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = att
	align.Responsiveness = 25
	align.MaxTorque = 1e7
	align.CFrame = Track.ORIGIN.Rotation
	align.Parent = seat

	seat:SetAttribute("Owner", player.UserId)
	seat.Parent = sledsFolder
	return seat
end

StartRun.OnServerEvent:Connect(function(player)
	if runs[player] or not player:GetAttribute("Loaded") then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return
	end

	local sled = makeSled(player)
	character:PivotTo(sled.CFrame * CFrame.new(0, 3, 0))
	sled:Sit(humanoid)
	sled:SetNetworkOwner(player) -- физику считает клиент: управление без задержки

	local run: Run = { sled = sled, distance = 0, trickCoins = 0, lastTrick = 0 }
	runs[player] = run
	player:SetAttribute("InRun", true)
	player:SetAttribute("RunDistance", 0)

	sled.Touched:Connect(function(hit)
		if CollectionService:HasTag(hit, "Obstacle") then
			endRun(player, "crash")
		end
	end)
	sled:GetPropertyChangedSignal("Occupant"):Connect(function()
		if not sled.Occupant then
			endRun(player, "left")
		end
	end)
end)

Crash.OnServerEvent:Connect(function(player)
	endRun(player, "crash")
end)

Trick.OnServerEvent:Connect(function(player, flips)
	local run = runs[player]
	if not run or typeof(flips) ~= "number" then
		return
	end
	local now = os.clock()
	if now - run.lastTrick < 1 then -- антиспам
		return
	end
	run.lastTrick = now
	run.trickCoins += math.clamp(math.floor(flips), 0, 3) * Config.COINS_PER_FLIP
end)

BuyUpgrade.OnServerInvoke = function(player, name)
	local u = Config.UPGRADES[name]
	local d = Data.get(player)
	if not u or not d or runs[player] then
		return false, "Недоступно"
	end
	local field = name .. "Level"
	local level = d[field]
	if level >= u.MaxLevel then
		return false, "Максимум"
	end
	local cost = Config.upgradeCost(name, level)
	if d.Coins < cost then
		return false, "Не хватает монет"
	end
	d.Coins -= cost
	d[field] = level + 1
	syncPlayer(player)
	return true
end

------------------------------------------------------------------ Цикл
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.25 then
		return
	end
	acc = 0

	local minIdx, maxIdx = math.huge, -1
	for player, run in runs do
		local sled = run.sled
		if not sled.Parent then
			endRun(player, "left")
			continue
		end
		local dist, x, y = Track.progressOf(sled.Position)
		run.distance = math.max(run.distance, dist)
		player:SetAttribute("RunDistance", math.floor(run.distance))
		if y < -40 or math.abs(x) > Config.TRACK_WIDTH then
			endRun(player, "fell")
			continue
		end
		local idx = Track.segmentIndexAt(dist)
		minIdx = math.min(minIdx, idx)
		maxIdx = math.max(maxIdx, idx)
	end

	if maxIdx >= 0 then
		Track.ensure(minIdx - Config.SEGMENTS_BEHIND, maxIdx + Config.SEGMENTS_AHEAD)
		Track.cleanup(minIdx - Config.SEGMENTS_BEHIND)
	elseif next(runs) == nil and Track.needsReset() then
		Track.reset()
	end
end)

------------------------------------------------------------------ Подключение / выход
Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in Players:GetPlayers() do
	task.spawn(onPlayerAdded, p)
end

Players.PlayerRemoving:Connect(function(player)
	local run = runs[player]
	if run then
		runs[player] = nil
		run.sled:Destroy()
	end
	Data.release(player)
end)

task.spawn(function()
	while true do
		task.wait(120)
		Data.saveAll()
	end
end)

game:BindToClose(function()
	for _, p in Players:GetPlayers() do
		Data.save(p)
	end
end)
