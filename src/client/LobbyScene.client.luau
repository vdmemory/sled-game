-- Сцена лобби под свой мир (у каждого игрока своя, ничего не реплицируется):
--  • витринная трасса за мостиком — первые Config.LOBBY_PREVIEW_SEGMENTS кусков трассы текущего
--    уровня (или уровня фарма), построенные локально тем же Track.new, что и трассы заездов;
--  • декор лобби по теме мира (Lobby.dress): деревья/кактусы/кристаллы, акцент у спавна, горы;
--  • земля лобби перекрашивается под мир, вывеска на арке показывает название мира;
--  • флаги на флагштоках качаются «на ветру».
-- Пересобирается при смене уровня/мира (Level, FarmWorld) и по возвращении из заезда (InRun).
-- Освещение и осадки по теме применяет Effects.client по атрибуту LobbyTheme (ставим здесь).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Track = require(Shared:WaitForChild("Track"))
local Lobby = require(Shared:WaitForChild("Lobby"))

local player = Players.LocalPlayer
local previewOrigin = CFrame.new(Config.LOBBY_POS + Vector3.new(0, 0, -70)) -- как LaunchPad в Main.server

local current = nil -- текущая витринная трасса (Track)
local currentLevel: number? = nil
local decor: Folder? = nil

-- Уровень, который увидим за мостиком: текущий или последний уровень фармящегося мира
-- (та же логика, что в Main.startRun)
local function previewLevel(): number
	local level = player:GetAttribute("Level") or 1
	local farm = player:GetAttribute("FarmWorld") or 0
	if farm > 0 and (farm < Config.worldOf(level) or player.UserId == game.CreatorId) then
		return Config.farmLevel(farm)
	end
	return level
end

local function applyGround(theme: number, color: Color3, material: Enum.Material)
	local lobby = workspace:FindFirstChild("Lobby")
	if not lobby then
		return
	end
	local ground = lobby:FindFirstChild("LobbyGround")
	if ground and ground:IsA("BasePart") then
		ground.Color = color
		ground.Material = material
	end
	local beam = lobby:FindFirstChild("ArchBeam")
	local text = beam and beam:FindFirstChild("Sign") and beam.Sign:FindFirstChild("Text")
	if text and text:IsA("TextLabel") then
		text.Text = string.upper(Config.worldName(Config.worldOf(previewLevel()))) .. "  ▼ СТАРТ"
	end
	-- неоновое кольцо плиты спавна — цветом мира
	local ring = lobby:FindFirstChild("PlazaRing")
	if ring and ring:IsA("BasePart") then
		ring.Color = Config.WORLD_COLORS[((theme - 1) % #Config.WORLD_COLORS) + 1]
	end
end

local function rebuild()
	if player:GetAttribute("InRun") then
		return
	end
	local level = previewLevel()
	if level == currentLevel and current then
		return
	end
	-- Старая витрина и декор уничтожаются целиком: теги Coin/Mover снимаются сами (Effects/Traffic
	-- чистят свои таблицы по GetInstanceRemovedSignal)
	if current then
		current:destroy()
		current = nil
	end
	if decor then
		decor:Destroy()
		decor = nil
	end
	currentLevel = level
	local theme = Config.themeOf(level)
	local segments = math.max(1, math.floor(Config.LOBBY_PREVIEW_SEGMENTS))
	current = Track.new(-1, level, 0, previewOrigin, segments)
	local folder = Instance.new("Folder")
	folder.Name = "LobbyDecor"
	local color, material = Lobby.dress(theme, folder)
	folder.Parent = workspace
	decor = folder
	applyGround(theme, color, material)
	player:SetAttribute("LobbyTheme", theme)
end

-- Пересборка откладывается на кадр: при выходе из заезда атрибуты Level/InRun приходят пачкой
local pending = false
local function schedule()
	if pending then
		return
	end
	pending = true
	task.defer(function()
		pending = false
		rebuild()
	end)
end
for _, attr in { "Level", "FarmWorld", "InRun" } do
	player:GetAttributeChangedSignal(attr):Connect(schedule)
end
workspace:WaitForChild("Lobby", 30)
schedule()

------------------------------------------------------------------ Флаги на ветру
-- 4 флага, вращение вокруг точки крепления (атрибут BaseCF от Props.flagpole). Только в лобби.
local flags: { BasePart } = {}
local function addFlag(inst: Instance)
	if inst:IsA("BasePart") and typeof(inst:GetAttribute("BaseCF")) == "CFrame" then
		table.insert(flags, inst)
	end
end
CollectionService:GetInstanceAddedSignal("LobbyFlag"):Connect(addFlag)
for _, f in CollectionService:GetTagged("LobbyFlag") do
	addFlag(f)
end
local wind = 0
RunService.Heartbeat:Connect(function(dt)
	if player:GetAttribute("InRun") or #flags == 0 then
		return
	end
	wind += dt
	for i = #flags, 1, -1 do
		local flag = flags[i]
		if not flag.Parent then
			table.remove(flags, i)
			continue
		end
		local baseCF = flag:GetAttribute("BaseCF") :: CFrame
		local phase = i * 1.3
		local yaw = math.sin(wind * 1.6 + phase) * 0.35 + 0.4
		local flap = math.sin(wind * 4.2 + phase) * 0.08
		flag.CFrame = baseCF * CFrame.Angles(0, yaw, flap) * CFrame.new(3, 0, 0)
	end
end)
