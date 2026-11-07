-- Состояние игрока: синхронизация профиля в атрибуты (syncPlayer), вход (leaderstats, профиль,
-- геймпасс, награды), доска лидеров «лучший уровень», шаги обучения и настройки.

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Data = require(script.Parent.DataService)
local Rewards = require(script.Parent.Rewards)
local Tuning = require(script.Parent.Tuning)
local Analytics = require(script.Parent.Analytics)
local Weekly = require(script.Parent.Weekly)
local Remotes = require(script.Parent.Remotes)
local Sleds = require(script.Parent.Sleds)

local setRider = Sleds.setRider
local SetSetting: RemoteEvent = Remotes.SetSetting
local TutorialStep: RemoteEvent = Remotes.TutorialStep

local PlayerState = {}

local TUTORIAL_ALL = 2 ^ #Config.TUTORIAL.STEPS - 1 -- все шаги обучения пройдены
local function syncPlayer(player: Player)
	local d = Data.get(player)
	if not d then
		return
	end
	for _, key in { "Coins", "Gems", "Level", "LevelBest", "LaunchLevel", "RocketLevel", "SledLevel", "IncomeLevel" } do
		player:SetAttribute(key, d[key])
	end
	if not player:GetAttribute("InRun") then -- в заезде длину задаёт трасса (фарм — другой уровень)
		player:SetAttribute("LevelLength", Config.levelLength(d.Level))
	end
	player:SetAttribute("ThemeName", Config.worldName(Config.worldOf(d.Level)))
	-- фарм: пройденный мир, в котором сейчас катаемся (0 — текущий)
	if (d.FarmWorld or 0) >= Config.worldOf(d.Level) and player.UserId ~= game.CreatorId then
		d.FarmWorld = 0
	end
	player:SetAttribute("FarmWorld", d.FarmWorld or 0)
	player:SetAttribute("Sled", d.Sled)
	player:SetAttribute("SledRarity", d.SledRarity)
	local ownedSleds = {}
	for k in d.OwnedSleds do
		table.insert(ownedSleds, k)
	end
	player:SetAttribute("OwnedSleds", table.concat(ownedSleds, ","))
	player:SetAttribute("Trail", d.Trail)
	local ownedTrails = {}
	for k in d.OwnedTrails do
		table.insert(ownedTrails, k)
	end
	player:SetAttribute("OwnedTrails", table.concat(ownedTrails, ","))
	player:SetAttribute("Tutorial", d.Tutorial or 0) -- client/Tutorial
	player:SetAttribute("Runs", (d.Stats and d.Stats.Runs) or 0)
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

	if not Data.load(player) or not player.Parent then -- вышел, пока грузился профиль, или кикнут (ошибка загрузки)
		return
	end
	Tuning.loadPlayer(player) -- персональные настройки владельца для этого игрока (атрибут ConfigOverrides)
	local d0 = Data.get(player)
	if d0 then
		Analytics.onboarding(player, d0, 1)
		if ((d0.Stats and d0.Stats.Runs) or 0) >= Config.TUTORIAL.MAX_RUNS then
			d0.Tutorial = TUTORIAL_ALL -- старые игроки: обучение не нужно
		end
		player:SetAttribute("JoinedAt", os.clock())
	end
	if Config.GAMEPASS_X2_COINS ~= 0 then
		local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, Config.GAMEPASS_X2_COINS)
		player:SetAttribute("X2Coins", ok and owns or false)
	end
	syncPlayer(player)
	player:SetAttribute("Loaded", true)
	if d0 then
		postLevel(player, d0.Level)
	end
	Rewards.onJoin(player)
	Weekly.onJoin(player)
end

function PlayerState.start()
	-- Обучение (client/Tutorial): клиент сообщает показанный шаг. Бит ставится один раз, поэтому
	-- спам безвреден (≤ N+1 событий аналитики за всю жизнь игрока); награды за шаги нет.
	TutorialStep.OnServerEvent:Connect(function(player, step)
		local d = Data.get(player)
		if not d or typeof(step) ~= "number" or step ~= step // 1 or step < 0 or step > #Config.TUTORIAL.STEPS then
			return
		end
		local mask = d.Tutorial or 0
		local new = if step == 0 then TUTORIAL_ALL else bit32.bor(mask, 2 ^ (step - 1))
		if new == mask then
			return
		end
		d.Tutorial = new
		player:SetAttribute("Tutorial", new)
		if step == 0 then
			Analytics.custom(player, "TutorialSkip", (d.Stats and d.Stats.Runs) or 0)
		else
			Analytics.custom(player, "TutorialStep", step)
		end
	end)

	SetSetting.OnServerEvent:Connect(function(player, key, value)
		local d = Data.get(player)
		if not d or typeof(key) ~= "string" or typeof(value) ~= "boolean" or d.Settings[key] == nil then
			return
		end
		d.Settings[key] = value
		player:SetAttribute("Set" .. key, value)
	end)
end

PlayerState.TUTORIAL_ALL = TUTORIAL_ALL
PlayerState.sync = syncPlayer
PlayerState.postLevel = postLevel
PlayerState.onPlayerAdded = onPlayerAdded

return PlayerState
