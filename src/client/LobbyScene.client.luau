-- Сцена лобби под свой мир (у каждого игрока своя, ничего не реплицируется):
--  • витринная трасса за мостиком — первые Config.LOBBY_PREVIEW_SEGMENTS кусков трассы текущего
--    уровня (или уровня фарма), построенные локально тем же Track.new, что и трассы заездов;
--  • декор лобби по теме мира (Lobby.dress): деревья/кактусы/кристаллы, акцент у спавна, горы,
--    утёсы задника;
--  • земля лобби перекрашивается под мир, вывеска на воротах старта — название мира;
--  • витрина саней на подиумах (Lobby.showcase): слева — следующие сани, которые игрок может
--    купить, справа — «мечта» (топовая модель в Galaxy); медленно вращаются;
--  • камера спавна сзади-сверху под углом Config.LOBBY_CAM_PITCH — путь к старту по центру кадра;
--  • флаги на флагштоках качаются «на ветру».
-- Пересобирается при смене уровня/мира (Level, FarmWorld) и по возвращении из заезда (InRun), а
-- также один раз, когда догрузились меши (декор, собранный до них, был из Part).
-- Освещение и осадки по теме применяет Effects.client по атрибуту LobbyTheme (ставим здесь).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Track = require(Shared:WaitForChild("Track"))
local Lobby = require(Shared:WaitForChild("Lobby"))
local Meshes = require(Shared:WaitForChild("Meshes"))
local SledModels = require(Shared:WaitForChild("SledModels"))

local player = Players.LocalPlayer
local previewOrigin = CFrame.new(Config.LOBBY_POS + Vector3.new(0, 0, -70)) -- как LaunchPad в server/Runs

local current = nil -- текущая витринная трасса (Track)
local currentLevel: number? = nil
local decor: Folder? = nil
local lobbyModel = workspace:WaitForChild("Lobby", 30)

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

local function applyGround(theme: number, color: Color3?, material: Enum.Material?)
	local lobby = workspace:FindFirstChild("Lobby")
	if not lobby then
		return
	end
	local ground = lobby:FindFirstChild("LobbyGround")
	if color and material and ground and ground:IsA("BasePart") then
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

------------------------------------------------------------------ Витрина саней на подиумах
-- Слева — что купить дальше (следующая редкость своих саней, иначе следующая модель), справа —
-- «мечта»: самая дорогая модель в Galaxy, которой ещё нет. Подпись — имя, редкость, цена.
type Show = { holder: Model, parts: { BasePart }, offsets: { CFrame }, pivot: CFrame, phase: number }
local shows: { Show } = {}
local showKey = ""

local function owned(): { [string]: boolean }
	local set = {}
	for id in string.gmatch(player:GetAttribute("OwnedSleds") or "", "[^,]+") do
		set[id] = true
	end
	return set
end
local function money(n: number): string
	return if n >= 1000 then (string.format("%.1fK", n / 1000):gsub("%.0K", "K")) else tostring(n)
end
local function nextSled(): (any, number)
	local own = owned()
	local world = Config.worldOf(player:GetAttribute("Level") or 1)
	local cur, curR = player:GetAttribute("Sled") or "tube", player:GetAttribute("SledRarity") or 1
	for _, m in Config.SLEDS do
		if m.id == cur then
			for r = curR + 1, #Config.RARITIES do
				if not own[m.id .. ":" .. r] then
					return m, r
				end
			end
		end
	end
	for _, m in Config.SLEDS do
		if not own[m.id .. ":1"] and m.world <= world then
			return m, 1
		end
	end
	for _, m in Config.SLEDS do
		if not own[m.id .. ":1"] then
			return m, 1
		end
	end
	return Config.SLEDS[#Config.SLEDS], #Config.RARITIES
end
local function dreamSled(): any
	local own = owned()
	for i = #Config.SLEDS, 1, -1 do
		local m = Config.SLEDS[i]
		if not own[m.id .. ":" .. #Config.RARITIES] then
			return m
		end
	end
	return Config.SLEDS[#Config.SLEDS]
end

local function clearShows()
	for _, s in shows do
		s.holder:Destroy()
	end
	table.clear(shows)
end
local function addShow(holder: Model?)
	if not holder then
		return
	end
	local pivot = holder:GetAttribute("Pivot") :: CFrame
	local s: Show = { holder = holder, parts = {}, offsets = {}, pivot = pivot, phase = #shows * 1.7 }
	for _, d in holder:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			table.insert(s.parts, d)
			table.insert(s.offsets, pivot:ToObjectSpace(d.CFrame))
		end
	end
	table.insert(shows, s)
end
local function rebuildShowcase(force: boolean?)
	local lobby = workspace:FindFirstChild("Lobby")
	local left = lobby and lobby:FindFirstChild("PodiumL")
	local right = lobby and lobby:FindFirstChild("PodiumR")
	if not left or not right or not decor then
		return
	end
	local nm, nr = nextSled()
	local dm = dreamSled()
	local key = nm.id .. nr .. dm.id
	if key == showKey and #shows > 0 and not force then
		return
	end
	showKey = key
	clearShows()
	local rarity = Config.RARITIES[nr]
	local price = nm.prices[nr] or 0
	local lockText = if Config.worldOf(player:GetAttribute("Level") or 1) < nm.world then "мир " .. nm.world else money(price) .. " монет"
	addShow(Lobby.showcase(left, nm.id, nr, "ДАЛЬШЕ: " .. nm.name .. " · " .. rarity.name .. "\n" .. lockText, decor :: Folder))
	addShow(Lobby.showcase(right, dm.id, #Config.RARITIES, "МЕЧТА: " .. dm.name .. " · " .. Config.RARITIES[#Config.RARITIES].name, decor :: Folder))
end

------------------------------------------------------------------ сборка сцены
local builtWithMeshes = false
local function rebuild(force: boolean?)
	if player:GetAttribute("InRun") then
		return
	end
	local level = previewLevel()
	if level == currentLevel and current and not force then
		rebuildShowcase()
		return
	end
	-- Старая витрина и декор уничтожаются целиком: теги Coin/Mover снимаются сами (Effects/Traffic
	-- чистят свои таблицы по GetInstanceRemovedSignal)
	if current then
		current:destroy()
		current = nil
	end
	clearShows()
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
	builtWithMeshes = Meshes.has("crag", "pine_foliage", "mountain_rock")
	local color, material = Lobby.dress(theme, folder)
	folder.Parent = workspace
	decor = folder
	applyGround(theme, color, material)
	rebuildShowcase(true)
	player:SetAttribute("LobbyTheme", theme)
end

-- Пересборка откладывается на кадр: при выходе из заезда атрибуты Level/InRun приходят пачкой
local pending, pendingForce = false, false
local function schedule(force: boolean?)
	pendingForce = pendingForce or force == true
	if pending then
		return
	end
	pending = true
	task.defer(function()
		pending = false
		local f = pendingForce
		pendingForce = false
		rebuild(f)
	end)
end
for _, attr in { "Level", "FarmWorld", "InRun" } do
	player:GetAttributeChangedSignal(attr):Connect(function()
		schedule()
	end)
end
-- витрина: купил/выбрал сани — на левом подиуме следующие
for _, attr in { "OwnedSleds", "Sled", "SledRarity" } do
	player:GetAttributeChangedSignal(attr):Connect(function()
		if not player:GetAttribute("InRun") then
			task.defer(rebuildShowcase)
		end
	end)
end
schedule()
-- сервер ставит мебель (ворота, подиумы, табло) после загрузки мешей — подхватываем вывеску и витрину
if lobbyModel then
	lobbyModel:GetAttributeChangedSignal("Furnished"):Connect(function()
		task.defer(function()
			applyGround(Config.themeOf(previewLevel()))
			rebuildShowcase(true)
		end)
	end)
end
-- меши декора догрузились после первой сборки — пересобираем один раз (горы, ёлки, утёсы — мешами)
task.spawn(function()
	if Meshes.waitFor({ "crag", "pine_foliage", "mountain_rock" }, 40) and not builtWithMeshes then
		schedule(true)
	end
end)
-- меши саней (корпуса, обвес, ракеты) догрузились после первой витрины — пересобираем её один раз
task.spawn(function()
	if Meshes.has(table.unpack(SledModels.MESHES)) then
		return
	end
	if Meshes.waitFor(SledModels.MESHES, 60) and not player:GetAttribute("InRun") then
		rebuildShowcase(true)
	end
end)

------------------------------------------------------------------ Камера спавна
-- Сзади-сверху: наклон LOBBY_CAM_PITCH (−12°) и зум LOBBY_CAM_ZOOM (16) подобраны макетом
-- scripts/ui_layout_preview.py — мостик, кольцо посадки и маяк старта видны над головой своего
-- аватара и под полосой наград. Ставится один раз после появления/возврата из заезда; дальше
-- камерой управляет игрок. Зум: временно поднимаем CameraMinZoomDistance — модуль камеры
-- отодвигается и остаётся там, когда минимум возвращаем.
local function aimCamera()
	task.delay(0.35, function()
		local cam = workspace.CurrentCamera
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not cam or not hrp or player:GetAttribute("InRun") or cam.CameraType ~= Enum.CameraType.Custom then
			return
		end
		if (hrp.Position - Config.LOBBY_POS).Magnitude > 40 then
			return -- не на плите-хабе (уже ушёл гулять) — не дёргаем камеру
		end
		local zoom = math.clamp(Config.LOBBY_CAM_ZOOM, player.CameraMinZoomDistance, player.CameraMaxZoomDistance)
		local prevMin = player.CameraMinZoomDistance
		player.CameraMinZoomDistance = zoom
		local focus = hrp.Position + Vector3.new(0, 1.5, 0)
		local dir = (CFrame.Angles(math.rad(Config.LOBBY_CAM_PITCH), 0, 0)).LookVector -- к −Z, вниз
		cam.CFrame = CFrame.lookAt(focus - dir * zoom, focus)
		task.delay(0.25, function()
			player.CameraMinZoomDistance = prevMin
		end)
	end)
end
player.CharacterAdded:Connect(aimCamera)
player:GetAttributeChangedSignal("InRun"):Connect(function()
	if not player:GetAttribute("InRun") then
		aimCamera()
	end
end)
if player.Character then
	aimCamera()
end

------------------------------------------------------------------ Анимация: флаги и витрина
-- Флаги: вращение вокруг точки крепления (атрибут BaseCF от Props.flagpole). Витрина: поворот
-- вокруг вертикали ~25°/с, лёгкое покачивание; BulkMoveTo — один вызов на все детали саней,
-- ~30 раз в секунду. Только в лобби.
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
local wind, spinAcc = 0, 0
local bulkParts: { BasePart } = {}
local bulkCFs: { CFrame } = {}
RunService.Heartbeat:Connect(function(dt)
	if player:GetAttribute("InRun") then
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
	spinAcc += dt
	if spinAcc < 1 / 30 or #shows == 0 then
		return
	end
	spinAcc = 0
	table.clear(bulkParts)
	table.clear(bulkCFs)
	for _, s in shows do
		local cf = s.pivot * CFrame.new(0, math.sin(wind * 1.2 + s.phase) * 0.25, 0) * CFrame.Angles(0, wind * 0.45 + s.phase, 0)
		for k, p in s.parts do
			table.insert(bulkParts, p)
			table.insert(bulkCFs, cf * s.offsets[k])
		end
	end
	workspace:BulkMoveTo(bulkParts, bulkCFs, Enum.BulkMoveMode.FireCFrameChanged)
end)

------------------------------------------------------------------ Корона пьедестала топ-3 (#48)
-- Корона над 1-м местом (shared/Lobby → top3Podium, атрибут BaseCF) медленно вращается и покачивается.
-- Только в лобби, ~30 раз в секунду, один PivotTo на 11 деталей.
task.spawn(function()
	local lobby = workspace:WaitForChild("Lobby", 60)
	local top3 = lobby and lobby:WaitForChild("Top3", 60)
	local crown = top3 and top3:WaitForChild("Crown", 10) :: Model?
	local baseCF = crown and crown:GetAttribute("BaseCF")
	if not crown or typeof(baseCF) ~= "CFrame" then
		return
	end
	local t, acc = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		t += dt
		acc += dt
		if acc < 1 / 30 or player:GetAttribute("InRun") or not crown.Parent then
			return
		end
		acc = 0
		crown:PivotTo(baseCF * CFrame.new(0, math.sin(t * 1.5) * 0.25, 0) * CFrame.Angles(0, t * 0.9, 0))
	end)
end)
