-- Главный серверный скрипт: игроки, уровни, рогатка, заезды, монеты, апгрейды.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage.Shared.Config)
local Track = require(script.Parent.Track)
local Data = require(script.Parent.DataService)
local Rewards = require(script.Parent.Rewards)

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
local Launch: RemoteEvent = remote("RemoteEvent", "Launch")
local Crash: RemoteEvent = remote("RemoteEvent", "Crash")
local Air: RemoteEvent = remote("RemoteEvent", "Air")
local Trick: RemoteEvent = remote("RemoteEvent", "Trick")
local RunEnded: RemoteEvent = remote("RemoteEvent", "RunEnded")
local Restart: RemoteEvent = remote("RemoteEvent", "Restart") -- ⟳ в заезде: закончить и сразу новый
local Back: RemoteEvent = remote("RemoteEvent", "Back") -- BACK у рогатки: вернуться в лобби
local Smash: RemoteEvent = remote("RemoteEvent", "Smash") -- разбил препятствие ракетой/на ускорителе
local SetSetting: RemoteEvent = remote("RemoteEvent", "SetSetting") -- настройки: звуки, снег, тени
local RewardAction: RemoteFunction = remote("RemoteFunction", "RewardAction") -- задания, билет, подарки, сундук
local TaskDone: RemoteEvent = remote("RemoteEvent", "TaskDone") -- «задание выполнено!»
local Crystal: RemoteEvent = remote("RemoteEvent", "Crystal") -- разбил ледяной кристалл
local CoinGrab: RemoteEvent = remote("RemoteEvent", "CoinGrab") -- монету притянул магнит
local BuyUpgrade: RemoteFunction = remote("RemoteFunction", "BuyUpgrade")
local SkinAction: RemoteFunction = remote("RemoteFunction", "SkinAction")
remotes.Parent = ReplicatedStorage

------------------------------------------------------------------ Мир
PhysicsService:RegisterCollisionGroup("Riders")
PhysicsService:CollisionGroupSetCollidable("Riders", "Riders", false)

local function setRider(p: Instance)
	if p:IsA("BasePart") then
		p.CollisionGroup = "Riders"
	end
end

local sledsFolder = Instance.new("Folder")
sledsFolder.Name = "Sleds"
sledsFolder.Parent = workspace

-- Солнечный зимний день
Lighting.ClockTime = 14.5
Lighting.Brightness = 2
Lighting.ExposureCompensation = -0.35 -- снег не пересвечивается
Lighting.Ambient = Color3.fromRGB(100, 115, 140)
Lighting.OutdoorAmbient = Color3.fromRGB(120, 140, 170)
Lighting.EnvironmentDiffuseScale = 1
Lighting.EnvironmentSpecularScale = 1
Lighting.GlobalShadows = true
do
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.25
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(190, 220, 255)
	atmosphere.Decay = Color3.fromRGB(110, 160, 230)
	atmosphere.Glare = 0.3
	atmosphere.Haze = 0.5 -- меньше дымки: небо насыщенно-голубое, как в оригинале
	atmosphere.Parent = Lighting

	-- Объёмные облака (встроенные в Terrain, ассеты не нужны)
	local clouds = Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.6
	clouds.Color = Color3.fromRGB(255, 255, 255)
	clouds.Parent = workspace.Terrain
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Brightness = -0.02
	cc.Contrast = 0.18
	cc.Saturation = 0.25
	cc.TintColor = Color3.fromRGB(240, 248, 255)
	cc.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.4
	bloom.Size = 18
	bloom.Threshold = 2
	bloom.Parent = Lighting
end

Track.buildLobby()

------------------------------------------------------------------ Игроки
local function syncPlayer(player: Player)
	local d = Data.get(player)
	if not d then
		return
	end
	for _, key in { "Coins", "Gems", "Level", "LevelBest", "LaunchLevel", "RocketLevel", "SledLevel", "IncomeLevel" } do
		player:SetAttribute(key, d[key])
	end
	player:SetAttribute("LevelLength", Config.levelLength(d.Level))
	player:SetAttribute("Skin", d.Skin)
	local owned = {}
	for id in d.OwnedSkins do
		table.insert(owned, id)
	end
	player:SetAttribute("OwnedSkins", table.concat(owned, ","))
	player:SetAttribute("ThemeName", Config.worldName(Config.worldOf(d.Level)))
	for key, v in d.Settings do
		player:SetAttribute("Set" .. key, v)
	end
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		(ls :: any)["Уровень"].Value = d.Level;
		(ls :: any)["Монеты"].Value = d.Coins
	end
end

local function onCharacter(character: Model)
	for _, d in character:GetDescendants() do
		setRider(d)
	end
	character.DescendantAdded:Connect(setRider)
end

------------------------------------------------------------------ Доска лидеров (лучший уровень)
local DataStoreService = game:GetService("DataStoreService")
local okBoard, levelBoard = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, "BestLevel_v1")
local function postLevel(player: Player, level: number)
	if okBoard then
		task.spawn(pcall, levelBoard.SetAsync, levelBoard, "u_" .. player.UserId, level)
	end
end
local boardGui: TextLabel? = nil
task.spawn(function()
	local lobby = workspace:WaitForChild("Lobby", 30)
	local board = lobby and lobby:FindFirstChild("Leaderboard")
	boardGui = board and board:FindFirstChild("List", true) :: TextLabel?
	while okBoard and boardGui do
		local ok, pages = pcall(levelBoard.GetSortedAsync, levelBoard, false, 10)
		if ok then
			local lines = {}
			for rank, entry in pages:GetCurrentPage() do
				local id = tonumber(string.sub(entry.key, 3)) or 0
				local okName, name = pcall(Players.GetNameFromUserIdAsync, Players, id)
				table.insert(lines, string.format("%d. %s — ур. %d", rank, if okName then name else "?", entry.value))
			end
			boardGui.Text = if #lines > 0 then table.concat(lines, "\n") else "Пока пусто — будь первым!"
		end
		task.wait(60)
	end
end)

local function onPlayerAdded(player: Player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	for _, name in { "Уровень", "Монеты" } do
		local v = Instance.new("IntValue")
		v.Name = name
		v.Parent = ls
	end
	ls.Parent = player

	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end

	Data.load(player)
	if Config.GAMEPASS_X2_COINS ~= 0 then
		local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, Config.GAMEPASS_X2_COINS)
		player:SetAttribute("X2Coins", ok and owns or false)
	end
	syncPlayer(player)
	player:SetAttribute("Loaded", true)
	local d0 = Data.get(player)
	if d0 then
		postLevel(player, d0.Level)
	end
	Rewards.onJoin(player)
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if purchased and passId == Config.GAMEPASS_X2_COINS then
		player:SetAttribute("X2Coins", true)
	end
end)

------------------------------------------------------------------ Слоты трасс (у каждого игрока своя)
local slots: { [number]: Player } = {}
local function takeSlot(player: Player): number
	local i = 0
	while slots[i] do
		i += 1
	end
	slots[i] = player
	return i
end

------------------------------------------------------------------ Заезды
type Run = {
	track: any,
	slot: number,
	sled: VehicleSeat,
	ropes: { Instance },
	launched: boolean,
	distance: number,
	bonusCoins: number,
	lastTrick: number,
	slowTime: number,
	startTime: number,
	launchTime: number?,
	crashed: boolean?,
	finishedAt: number?,
	smashes: number?,
	airTotal: number?,
	flips: number?,
	gems: number?,
	combo: number?,
	lastCoin: number?,
	crystal: boolean?,
	lastAir: number?,
	ended: boolean?,
}
local runs: { [Player]: Run } = {}

local startRun: (Player) -> ()

local function endRun(player: Player, reason: string)
	local run = runs[player]
	if not run or run.ended then
		return
	end
	run.ended = true
	runs[player] = nil

	local d = Data.get(player)
	local level = d and d.Level or 1
	local L = run.track.length
	local finished = reason == "finish"
	local dist = math.min(run.distance, L)
	local pct = math.floor(dist / L * 100)
	local mult = (if player:GetAttribute("X2Coins") then 2 else 1) * Config.incomeMult(d and d.IncomeLevel or 0)
	local earned = math.floor((math.floor(dist / Config.STUDS_PER_COIN) + run.bonusCoins + (if finished then Config.finishBonus(level) else 0)) * mult)
	local newBest = false
	local gems = 0

	if d then
		d.Coins += earned
		if finished then
			d.Level += 1
			d.LevelBest = 0
			gems += Config.GEMS_FINISH
			postLevel(player, d.Level)
		elseif pct > d.LevelBest and reason ~= "restart" and reason ~= "back" then
			d.LevelBest = pct
			newBest = true
			gems += Config.GEMS_NEW_BEST
		end
		gems += run.gems or 0
		d.Gems += gems
		local done = Rewards.onRun(player, {
			runs = if reason == "back" or reason == "restart" then 0 else 1,
			coins = earned,
			distance = math.floor(dist),
			air = math.floor(run.airTotal or 0),
			flips = run.flips or 0,
			smash = run.smashes or 0,
			best = if newBest or finished then 1 else 0,
		})
		syncPlayer(player)
		for _, text in done do
			TaskDone:FireClient(player, text)
		end
	end

	player:SetAttribute("InRun", false)
	player:SetAttribute("Launched", false)
	local quiet = reason == "back" or reason == "restart"
	if not quiet then
		RunEnded:FireClient(player, {
			reason = reason,
			percent = if finished then 100 else pct,
			coins = earned,
			bonus = run.bonusCoins * mult,
			distance = math.floor(dist),
			length = L,
			level = level,
			newBest = newBest,
			mult = math.floor(mult * 100 + 0.5) / 100,
			gems = gems,
		})
	end

	task.delay(if finished then 2.5 elseif quiet then 0.1 else 1.5, function()
		run.sled:Destroy()
		run.track:destroy()
		if slots[run.slot] == player then
			slots[run.slot] = nil
		end
		if player.Parent then
			player:LoadCharacter()
			if reason == "restart" then
				task.wait(0.3)
				startRun(player)
			end
		end
	end)
end

local function makeSled(player: Player, cf: CFrame): VehicleSeat
	-- Сиденье — плоская невидимая плита (на ней сидит персонаж и она скользит по льду),
	-- а «ватрушка» — два приваренных декоративных цилиндра
	local seat = Instance.new("VehicleSeat")
	seat.Name = "Sled"
	seat.Size = Vector3.new(5, 1, 5)
	seat.Transparency = 1
	seat.MaxSpeed = 0
	seat.Torque = 0
	seat.TurnSpeed = 0
	seat.HeadsUpDisplay = false
	seat.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0, 0, 100, 100)
	seat.CollisionGroup = "Riders"
	seat.CFrame = cf
	seat.Anchored = true

	local d = Data.get(player)
	local skin = Config.skin(d and d.Skin)
	for _, spec in {
		{ name = "Tube", size = Vector3.new(1.4, 7, 7), color = skin.tube, y = -0.1, glow = false },
		{ name = "Rim", size = Vector3.new(1.2, 7.8, 7.8), color = skin.rim, y = 0.5, glow = skin.neon },
	} do
		local p = Instance.new("Part")
		p.Name = spec.name
		p.Shape = Enum.PartType.Cylinder
		p.Size = spec.size
		p.Color = spec.color
		p.Material = if spec.glow
			then Enum.Material.Neon
			elseif skin.metal then Enum.Material.Foil
			else Enum.Material.SmoothPlastic
		p.Reflectance = if skin.metal then 0.25 else 0
		p.CanCollide = false
		p.CanQuery = false
		p.Massless = true
		p.CollisionGroup = "Riders"
		-- Цилиндр в Roblox вытянут по X; кладём его «блином»
		p.CFrame = seat.CFrame * CFrame.new(0, spec.y, 0) * CFrame.Angles(0, 0, math.rad(90))
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = seat
		weld.Part1 = p
		weld.Parent = p
		p.Parent = seat
	end

	-- Тиры апгрейда «Сани»: санки обрастают деталями (как MEGA THRUSTER / AERO TAIL в оригинале)
	local tier = Config.tierOf(d and d.SledLevel or 0)
	local function deco(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Shape = shape or Enum.PartType.Block
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CollisionGroup = "Riders"
		p.CFrame = seat.CFrame * offset
		local w = Instance.new("WeldConstraint")
		w.Part0 = seat
		w.Part1 = p
		w.Parent = p
		p.Parent = seat
		return p
	end
	local metal = Color3.fromRGB(70, 75, 90)
	if tier >= 1 then -- боковые ускорители
		for _, sx in { -1, 1 } do
			deco("Booster", Vector3.new(3, 1.1, 1.1), CFrame.new(sx * 4.1, 0.4, 1) * CFrame.Angles(0, math.rad(90), 0), metal, Enum.Material.Metal, Enum.PartType.Cylinder)
			deco("Nozzle", Vector3.new(0.4, 0.8, 0.8), CFrame.new(sx * 4.1, 0.4, 2.6) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(255, 140, 40), Enum.Material.Neon, Enum.PartType.Cylinder)
		end
	end
	if tier >= 2 then -- аэро-хвост
		local fin = deco("Fin", Vector3.new(0.3, 2, 2.2), CFrame.new(0, 1.6, 3.4), skin.rim)
		local wedge = Instance.new("SpecialMesh")
		wedge.MeshType = Enum.MeshType.Wedge
		wedge.Parent = fin
	end
	if tier >= 3 then -- обтекатель спереди
		deco("Shield", Vector3.new(4, 1.6, 0.25), CFrame.new(0, 1.4, -3.4) * CFrame.Angles(math.rad(-25), 0, 0), Color3.fromRGB(170, 220, 255), Enum.Material.Glass).Transparency = 0.35
	end
	if tier >= 4 then -- золотая отделка
		deco("Trim", Vector3.new(0.35, 8.1, 8.1), CFrame.new(0, 0.95, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(240, 195, 60), Enum.Material.Foil, Enum.PartType.Cylinder)
	end
	if tier >= 5 then -- неон
		local glow = Instance.new("PointLight")
		glow.Color = skin.rim
		glow.Range = 12
		glow.Brightness = 2
		glow.Parent = seat
	end

	-- Ориентация задаётся с клиента (по нормали склона)
	local att = Instance.new("Attachment")
	att.Name = "AlignAttachment"
	att.Parent = seat
	local align = Instance.new("AlignOrientation")
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = att
	align.Responsiveness = 30
	align.MaxTorque = 1e7
	align.CFrame = cf.Rotation
	align.Parent = seat

	local ropeAtt = Instance.new("Attachment")
	ropeAtt.Name = "RopeAttachment"
	ropeAtt.Position = Vector3.new(0, 0, 0)
	ropeAtt.Parent = seat

	seat:SetAttribute("Owner", player.UserId)
	seat.Parent = sledsFolder
	return seat
end

startRun = function(player: Player)
	if runs[player] or not player:GetAttribute("Loaded") then
		return
	end
	local d = Data.get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not d or not character or not humanoid or humanoid.Health <= 0 then
		return
	end

	local slot = takeSlot(player)
	local track = Track.new(slot, d.Level, d.LevelBest / 100 * Config.levelLength(d.Level))
	local startCF = track:startCFrame()
	local sled = makeSled(player, startCF)

	-- Тиры рогатки: столбы меняют материал (дерево → сталь → красная → сила → золото → неон)
	local POST_STYLES = {
		{ Color3.fromRGB(140, 95, 55), Enum.Material.Wood },
		{ Color3.fromRGB(150, 155, 165), Enum.Material.DiamondPlate },
		{ Color3.fromRGB(210, 60, 60), Enum.Material.SmoothPlastic },
		{ Color3.fromRGB(70, 90, 200), Enum.Material.Metal },
		{ Color3.fromRGB(240, 195, 60), Enum.Material.Foil },
		{ Color3.fromRGB(90, 220, 255), Enum.Material.Neon },
	}
	local ltier = math.min(Config.tierOf(d.LaunchLevel) + 1, #POST_STYLES)
	for _, post in track.posts do
		post.Color = POST_STYLES[ltier][1]
		post.Material = POST_STYLES[ltier][2]
	end
	local ropeColor = if ltier >= 5 then Color3.fromRGB(255, 220, 90) elseif ltier >= 2 then Color3.fromRGB(70, 70, 80) else Color3.fromRGB(200, 160, 110)

	-- Резинка рогатки
	local ropes = {}
	for _, post in track.posts do
		local beam = Instance.new("Beam")
		beam.Attachment0 = post.RopeAttachment
		beam.Attachment1 = sled.RopeAttachment
		beam.Width0 = 0.5
		beam.Width1 = 0.5
		beam.Color = ColorSequence.new(ropeColor)
		beam.FaceCamera = true
		beam.Segments = 1
		beam.Parent = sled
		table.insert(ropes, beam)
	end

	character:PivotTo(startCF * CFrame.new(0, 3, 0))
	sled:Sit(humanoid)

	local run: Run = {
		track = track,
		slot = slot,
		sled = sled,
		ropes = ropes,
		launched = false,
		distance = 0,
		bonusCoins = 0,
		lastTrick = 0,
		slowTime = 0,
		startTime = os.clock(),
	}
	runs[player] = run
	player:SetAttribute("InRun", true)
	player:SetAttribute("Launched", false)
	player:SetAttribute("RunDistance", 0)
	player:SetAttribute("RunCoins", 0)
	player:SetAttribute("Finished", false)
	player:SetAttribute("RunGems", 0)
	player:SetAttribute("Combo", 0)

	sled:GetPropertyChangedSignal("Occupant"):Connect(function()
		-- при аварии персонаж вылетает из санок сам — это не «вышел»
		if not sled.Occupant and not run.crashed then
			endRun(player, "left")
		end
	end)
end
StartRun.OnServerEvent:Connect(startRun)

SetSetting.OnServerEvent:Connect(function(player, key, value)
	local d = Data.get(player)
	if not d or typeof(key) ~= "string" or typeof(value) ~= "boolean" or d.Settings[key] == nil then
		return
	end
	d.Settings[key] = value
	player:SetAttribute("Set" .. key, value)
end)

RewardAction.OnServerInvoke = function(player, action, arg)
	local ok, res
	if action == "task" then
		ok, res = Rewards.claimTask(player, arg)
	elseif action == "taskChest" then
		ok, res = Rewards.claimTaskChest(player)
	elseif action == "scratch" then
		ok, res = Rewards.scratch(player)
	elseif action == "gift" then
		ok, res = Rewards.claimGift(player, arg)
	elseif action == "chest" then
		ok, res = Rewards.openChest(player)
	else
		return false, "?"
	end
	syncPlayer(player)
	return ok, res
end

Restart.OnServerEvent:Connect(function(player)
	local run = runs[player]
	if run and not run.ended then
		endRun(player, "restart")
	end
end)
Back.OnServerEvent:Connect(function(player)
	local run = runs[player]
	if run and not run.launched and not run.ended then
		endRun(player, "back")
	end
end)

-- Ragdoll: суставы персонажа → шарниры, чтобы он кувыркался после аварии (видно всем)
local function ragdoll(character: Model)
	local hum = character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.BreakJointsOnDeath = false
		hum.RequiresNeck = false
	end
	for _, m in character:GetDescendants() do
		if m:IsA("Motor6D") and m.Part0 and m.Part1 and m.Name ~= "RootJoint" and m.Name ~= "Root" then
			local a0 = Instance.new("Attachment")
			a0.CFrame = m.C0
			a0.Parent = m.Part0
			local a1 = Instance.new("Attachment")
			a1.CFrame = m.C1
			a1.Parent = m.Part1
			local bs = Instance.new("BallSocketConstraint")
			bs.Attachment0 = a0
			bs.Attachment1 = a1
			bs.LimitsEnabled = true
			bs.UpperAngle = 70
			bs.TwistLimitsEnabled = true
			bs.TwistLowerAngle = -45
			bs.TwistUpperAngle = 45
			bs.Parent = m.Parent
			m.Enabled = false
		end
	end
end

-- Игрок отпустил рогатку: power 0..1 — насколько сильно оттянул резинку
Launch.OnServerEvent:Connect(function(player, power)
	local run = runs[player]
	local d = Data.get(player)
	if not run or run.launched or not d or typeof(power) ~= "number" then
		return
	end
	power = math.clamp(power, 0.25, 1)
	run.launched = true
	run.launchTime = os.clock()
	for _, r in run.ropes do
		r:Destroy()
	end
	local sled = run.sled
	sled:SetAttribute("LaunchSpeed", Config.launchSpeed(d.LaunchLevel) * power)
	sled.Anchored = false
	-- дальше физику считает клиент: мгновенный отклик
	local ok, err = pcall(sled.SetNetworkOwner, sled, player)
	if not ok then
		warn("[Launch] SetNetworkOwner: " .. tostring(err))
	end
	player:SetAttribute("Launched", true)
end)

-- Air time: монеты за время в полёте (с ограничением, чтобы не накручивали)
Air.OnServerEvent:Connect(function(player, seconds)
	local run = runs[player]
	if not run or not run.launched or run.crashed or typeof(seconds) ~= "number" then
		return
	end
	local now = os.clock()
	if now - (run.lastAir or 0) < 0.8 or seconds < Config.AIR_MIN_TIME then
		return
	end
	run.lastAir = now
	run.airTotal = (run.airTotal or 0) + math.min(seconds, 6)
	local add = math.floor(math.min(seconds, 4) * Config.AIR_COINS_PER_SEC)
	run.bonusCoins += add
	player:SetAttribute("RunCoins", (player:GetAttribute("RunCoins") or 0) + add)
end)

-- Врезался: даём кувырку доиграть на экране, потом заканчиваем заезд
Crash.OnServerEvent:Connect(function(player)
	local run = runs[player]
	if not run or not run.launched or run.crashed then
		return
	end
	run.crashed = true
	if run.finishedAt then
		-- после финишной арки авария уже не страшна: уровень пройден
		task.delay(1.2, function()
			if runs[player] == run then
				endRun(player, "finish")
			end
		end)
	end
	-- выкидываем персонажа из санок и превращаем в ragdoll
	local weld = run.sled:FindFirstChild("SeatWeld")
	if weld then
		weld:Destroy()
	end
	if player.Character then
		ragdoll(player.Character)
	end
	task.delay(2.2, function()
		if runs[player] == run then
			endRun(player, "crash")
		end
	end)
end)

Smash.OnServerEvent:Connect(function(player)
	local run = runs[player]
	if not run or not run.launched or run.crashed then
		return
	end
	run.smashes = (run.smashes or 0) + 1
	if run.smashes > 40 then
		return
	end
	run.bonusCoins += Config.SMASH_COINS
	player:SetAttribute("RunCoins", (player:GetAttribute("RunCoins") or 0) + Config.SMASH_COINS)
end)

Trick.OnServerEvent:Connect(function(player, flips)
	local run = runs[player]
	if not run or typeof(flips) ~= "number" then
		return
	end
	local now = os.clock()
	if now - run.lastTrick < 1 then
		return
	end
	run.lastTrick = now
	run.flips = (run.flips or 0) + math.clamp(math.floor(flips), 0, 3)
	local add = math.clamp(math.floor(flips), 0, 3) * Config.COINS_PER_FLIP
	run.bonusCoins += add
	player:SetAttribute("RunCoins", (player:GetAttribute("RunCoins") or 0) + add)
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
	local cost, currency = Config.upgradePrice(name, level)
	if d[currency] < cost then
		return false, if currency == "Gems" then "Не хватает гемов 💎" else "Не хватает монет"
	end
	d[currency] -= cost
	d[field] = level + 1
	syncPlayer(player)
	-- новый тир → клиент покажет «ПОЛУЧЕНО: …»
	if (level + 1) % Config.TIER_SIZE == 0 then
		return true, Config.tierName(name, level + 1)
	end
	return true
end

-- Скины: купить (если не куплен) или надеть
SkinAction.OnServerInvoke = function(player, id)
	local d = Data.get(player)
	if not d or typeof(id) ~= "string" or runs[player] then
		return false, "Недоступно"
	end
	local skin = Config.skin(id)
	if skin.id ~= id then
		return false, "Нет такого скина"
	end
	if not d.OwnedSkins[id] then
		if d.Coins < skin.price then
			return false, "Не хватает монет"
		end
		d.Coins -= skin.price
		d.OwnedSkins[id] = true
	end
	d.Skin = id
	syncPlayer(player)
	return true
end

------------------------------------------------------------------ Монетки на трассе
local function playerFromHit(hit: BasePart): Player?
	local owner = hit:GetAttribute("Owner") or (hit.Parent and hit.Parent:GetAttribute("Owner"))
	if owner then
		return Players:GetPlayerByUserId(owner)
	end
	local model = hit:FindFirstAncestorOfClass("Model")
	return model and Players:GetPlayerFromCharacter(model)
end

-- Монета с комбо: подряд (без пауз) — множитель растёт
local function awardCoin(player: Player, run: Run)
	local now = os.clock()
	run.combo = if now - (run.lastCoin or 0) < Config.COMBO_WINDOW then (run.combo or 0) + 1 else 1
	run.lastCoin = now
	local value = Config.COIN_PICKUP_VALUE * Config.comboMult(run.combo or 1)
	run.bonusCoins += value
	player:SetAttribute("RunCoins", (player:GetAttribute("RunCoins") or 0) + value)
	player:SetAttribute("Combo", run.combo)
end

local function takeCoin(coin: BasePart)
	coin:SetAttribute("Taken", true)
	coin.Transparency = 1
	coin.CanTouch = false
	for _, detail in coin:GetChildren() do
		if detail:IsA("BasePart") then
			detail.Transparency = 1
		end
	end
end

-- Магнит: клиент притягивает монеты и сообщает; проверяем, что монета рядом с санками
CoinGrab.OnServerEvent:Connect(function(player, coin)
	local run = runs[player]
	if not run or run.ended or typeof(coin) ~= "Instance" or not coin:IsA("BasePart") then
		return
	end
	if not CollectionService:HasTag(coin, "Coin") or coin:GetAttribute("Taken") then
		return
	end
	if (coin.Position - run.sled.Position).Magnitude > Config.MAGNET_RADIUS + 25 then
		return
	end
	takeCoin(coin)
	awardCoin(player, run)
end)

-- Гем на трассе
CollectionService:GetInstanceAddedSignal("Gem"):Connect(function(gem)
	if not gem:IsA("BasePart") then
		return
	end
	gem.Touched:Connect(function(hit)
		if gem:GetAttribute("Taken") then
			return
		end
		local player = playerFromHit(hit)
		local run = player and runs[player]
		if not run or run.ended then
			return
		end
		gem:SetAttribute("Taken", true)
		gem.Transparency = 1
		gem.CanTouch = false
		run.gems = (run.gems or 0) + 1
		player:SetAttribute("RunGems", run.gems)
	end)
end)

-- Ледяной кристалл: клиент разбивает его касанием, сервер начисляет (один раз за заезд)
Crystal.OnServerEvent:Connect(function(player, part)
	local run = runs[player]
	if not run or run.ended or run.crystal or typeof(part) ~= "Instance" or not CollectionService:HasTag(part, "Crystal") then
		return
	end
	if (part.Position - run.sled.Position).Magnitude > 30 then
		return
	end
	run.crystal = true
	run.bonusCoins += Config.CRYSTAL_COINS
	run.gems = (run.gems or 0) + 1
	player:SetAttribute("RunCoins", (player:GetAttribute("RunCoins") or 0) + Config.CRYSTAL_COINS)
	player:SetAttribute("RunGems", run.gems)
end)

local function setupCoin(coin: Instance)
	if not coin:IsA("BasePart") then
		return
	end
	coin.Touched:Connect(function(hit)
		if coin:GetAttribute("Taken") then
			return
		end
		local player = playerFromHit(hit)
		local run = player and runs[player]
		if not run or run.ended then
			return
		end
		coin:SetAttribute("Taken", true)
		coin.Transparency = 1
		coin.CanTouch = false
		for _, detail in coin:GetChildren() do
			if detail:IsA("BasePart") then
				detail.Transparency = 1
			end
		end
		awardCoin(player, run)
	end)
end
CollectionService:GetInstanceAddedSignal("Coin"):Connect(setupCoin)

------------------------------------------------------------------ Цикл: прогресс, остановка, финиш
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.2 then
		return
	end
	local step = acc
	acc = 0

	for player, run in runs do
		local sled = run.sled
		if not sled.Parent then
			endRun(player, "left")
			continue
		end
		local track = run.track
		local h, x, y = track:progressOf(sled.Position)
		run.distance = math.max(run.distance, h)
		player:SetAttribute("RunDistance", math.floor(math.min(run.distance, track.length)))

		track:ensureAround(math.max(0, run.distance))

		if not run.launched or run.crashed then
			continue
		end
		if run.distance >= track.length and not run.finishedAt then
			-- Финишная арка пройдена: дальше скользим по ледяному озеру до остановки
			run.finishedAt = os.clock()
			player:SetAttribute("Finished", true)
		end
		if run.finishedAt then
			local slow = sled.AssemblyLinearVelocity.Magnitude < Config.STOP_SPEED * 2
			if slow or os.clock() - run.finishedAt > Config.FINISH_GLIDE_MAX then
				endRun(player, "finish")
			end
		elseif y < -60 or math.abs(x) > Config.TRACK_WIDTH * 2 then
			endRun(player, "fell")
		else
			-- Первые 2 секунды после выстрела не считаем (передача управления по сети)
			if os.clock() - (run.launchTime or 0) > 2 and sled.AssemblyLinearVelocity.Magnitude < Config.STOP_SPEED then
				run.slowTime += step
			else
				run.slowTime = 0
			end
			if run.slowTime >= Config.STOP_TIME or os.clock() - run.startTime > 240 then
				endRun(player, "stopped")
			end
		end
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
		run.track:destroy()
		slots[run.slot] = nil
	end
	Rewards.onLeave(player)
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
