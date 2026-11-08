-- Пьедестал топ-3 недели в лобби (#48): 3D-аватары лидеров доски Config.PODIUM.BOARD на ступенях
-- модели workspace.Lobby.Top3 (строит shared/LobbyPodium из Lobby.furnish, точки — атрибуты Slot1..3).
--   Podium.start() — ждёт пьедестал, слушает ReplicatedStorage.WeeklyBoard (его раз в WEEKLY.REFRESH
--   публикует server/Weekly), расставляет аватары; цикл взмахов 2-го/3-го места.
-- Аватар: Players:CreateHumanoidModelFromUserIdAsync в pcall (ошибка или тестовый id — манекен по
-- умолчанию), кэш по userId (CACHE): если на месте тот же игрок — модель не трогаем, меняется только
-- табличка; поменялись местами — переставляем готовые модели. Анимации на серверном Animator
-- реплицируются всем клиентам. Аватары без коллизий и лучей, корень заякорен.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local LobbyPodium = require(ReplicatedStorage.Shared.LobbyPodium)

local P = Config.PODIUM
local MEDAL_ICONS = { "👑", "🥈", "🥉" }

local Podium = {}

local podium: Model? = nil
local cache: { [number]: Model } = {} -- userId → готовая модель (в т. ч. не стоящая на ступени)
local onStep: { [number]: number } = {} -- место → userId (0 — пусто)
local busy, dirty = false, false

local function decode(s: any): any
	if typeof(s) ~= "string" then
		return nil
	end
	local ok, r = pcall(HttpService.JSONDecode, HttpService, s)
	return if ok then r else nil
end

-- Масштаб аватаров (атрибут Scale пьедестала = Lobby.PLAN.top3[4])
local function scaleOf(m: Model?): number
	local sc = m and m:GetAttribute("Scale")
	return if typeof(sc) == "number" then sc else 1
end

-- Модель «как статуя»: без скриптов, без физики (кроме Motor6D-анимации), без имени Roblox над головой
local function prepare(model: Model, scale: number)
	for _, d in model:GetDescendants() do
		if d:IsA("BaseScript") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
		end
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		hum.BreakJointsOnDeath = false
		hum.RequiresNeck = false
		if not hum:FindFirstChildOfClass("Animator") then
			Instance.new("Animator").Parent = hum
		end
	end
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.Anchored = true
	end
	if scale ~= 1 then
		pcall(model.ScaleTo, model, scale)
	end
end

local function avatarFor(userId: number, scale: number): Model?
	local m = cache[userId]
	if m then
		return m
	end
	local ok, model = false, nil
	if userId > 0 then
		ok, model = pcall(Players.CreateHumanoidModelFromUserIdAsync, Players, userId)
	end
	if not ok or typeof(model) ~= "Instance" then
		-- манекен: аватар по умолчанию (тестовые id в Studio, сбой веб-API аватаров)
		ok, model = pcall(Players.CreateHumanoidModelFromDescriptionAsync, Players, Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	end
	if not ok or typeof(model) ~= "Instance" or not model:IsA("Model") then
		return nil
	end
	prepare(model, scale)
	model.Name = "Avatar_" .. userId
	cache[userId] = model
	return model
end

local function animTrack(model: Model, kind: string): AnimationTrack?
	local hum = model:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if not hum or not animator then
		return nil
	end
	local key = "Track_" .. kind
	local set = P.ANIM[hum.RigType.Name] or P.ANIM.R15
	local anim = model:FindFirstChild(key) :: Animation?
	if not anim then
		anim = Instance.new("Animation")
		anim.Name = key
		anim.AnimationId = "rbxassetid://" .. set[kind]
		anim.Parent = model
	end
	local ok, track = pcall(animator.LoadAnimation, animator, anim :: Animation)
	return if ok then track else nil
end

-- Поза по месту: 1-е — «ура» по кругу, 2–3 — стойка (взмах — в цикле start)
local function pose(model: Model, place: number)
	local hum = model:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if animator then
		for _, t in animator:GetPlayingAnimationTracks() do
			t:Stop(0.2)
		end
	end
	local track = animTrack(model, if place == 1 then "win" else "idle")
	if track then
		track.Looped = true
		track:Play(0.3)
	end
end

-- Табличка над головой: «👑 1 · Ник» и очки; размер в studs — издалека таблички не наезжают
local function plate(model: Model, place: number, name: string, value: any)
	local head = model:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local bb = head:FindFirstChild("PodiumPlate") :: BillboardGui?
	if not bb then
		local g = Instance.new("BillboardGui")
		g.Name = "PodiumPlate"
		g.Size = UDim2.fromScale(5.2, 1.9) -- studs
		g.StudsOffsetWorldSpace = Vector3.new(0, 2.1 * scaleOf(podium), 0)
		g.MaxDistance = P.MAX_DIST
		local f = Instance.new("Frame")
		f.Name = "Bg"
		f.Size = UDim2.fromScale(1, 1)
		f.BackgroundColor3 = Color3.fromRGB(28, 40, 72)
		f.BackgroundTransparency = 0.25
		f.Parent = g
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.3, 0)
		c.Parent = f
		local st = Instance.new("UIStroke")
		st.Name = "Stroke"
		st.Thickness = 2
		st.Parent = f
		for i, nm in { "Name", "Value" } do
			local t = Instance.new("TextLabel")
			t.Name = nm
			t.BackgroundTransparency = 1
			t.Position = UDim2.fromScale(0.04, if i == 1 then 0.04 else 0.58)
			t.Size = UDim2.fromScale(0.92, if i == 1 then 0.56 else 0.38)
			t.Font = Enum.Font.FredokaOne
			t.TextScaled = true
			t.TextColor3 = if i == 1 then Color3.new(1, 1, 1) else Color3.fromRGB(255, 225, 110)
			t.Parent = f
		end
		g.Parent = head
		bb = g
	end
	local f = (bb :: BillboardGui):FindFirstChild("Bg") :: Frame
	local stroke = f:FindFirstChild("Stroke") :: UIStroke
	stroke.Color = LobbyPodium.MEDALS[place]
	local nameLabel = f:FindFirstChild("Name") :: TextLabel
	nameLabel.Text = MEDAL_ICONS[place] .. " " .. place .. " · " .. tostring(name)
	local valueLabel = f:FindFirstChild("Value") :: TextLabel
	valueLabel.Text = if typeof(value) == "number" then tostring(math.floor(value)) .. " ✔ чистых финишей" else ""
end

local function setEmpty(place: number, empty: boolean)
	local anchor = podium and podium:FindFirstChild("EmptyAnchor" .. place)
	local bb = anchor and anchor:FindFirstChild("Empty" .. place) :: BillboardGui?
	if bb then
		bb.Enabled = empty
	end
end

local function doUpdate(m: Model)
	local pub = decode(ReplicatedStorage:GetAttribute("WeeklyBoard"))
	local top = (pub and pub.boards and pub.boards[P.BOARD]) or {}
	local scale = scaleOf(m)
	local folder = m:FindFirstChild("Avatars") or m
	local want: { [number]: number } = {}
	for place = 1, 3 do
		local e = top[place]
		want[place] = if typeof(e) == "table" and typeof(e.id) == "number" then e.id else 0
	end
	-- снимаем со ступеней тех, кого там больше нет (модель остаётся в кэше)
	for place = 1, 3 do
		local id = onStep[place] or 0
		if id ~= 0 and want[place] ~= id then
			local old = cache[id]
			if old then
				old.Parent = nil
			end
			onStep[place] = 0
		end
	end
	for place = 1, 3 do
		local id = want[place]
		local e = top[place]
		if id == 0 then
			setEmpty(place, true)
			continue
		end
		local model = avatarFor(id, scale) -- yield только для нового игрока
		local slot = m:GetAttribute("Slot" .. place)
		if model and typeof(slot) == "CFrame" then
			if onStep[place] ~= id then
				-- ноги на верх ступени: высота корня над низом модели (пока поза стоячая)
				model:PivotTo(CFrame.new())
				local bb, size = model:GetBoundingBox()
				local lift = model:GetPivot().Position.Y - (bb.Position.Y - size.Y / 2)
				model:PivotTo(slot * CFrame.new(0, lift, 0))
				model.Parent = folder
				onStep[place] = id
				pose(model, place)
			end
			plate(model, place, e.n or "?", e.v)
			setEmpty(place, false)
		else
			setEmpty(place, true)
		end
	end
	-- кэш: держим стоящих на ступенях + до CACHE остальных
	local n = 0
	for id, model in cache do
		local standing = id == onStep[1] or id == onStep[2] or id == onStep[3]
		if not standing then
			n += 1
			if n > P.CACHE - 3 then
				model:Destroy()
				cache[id] = nil
			end
		end
	end
end

-- Раз в WEEKLY.REFRESH (смена атрибута WeeklyBoard). Пока грузится аватар (yield), новые вызовы
-- только ставят флаг — проход повторится с актуальным топом.
local function update()
	local m = podium
	if not m then
		return
	end
	if busy then
		dirty = true
		return
	end
	busy = true
	repeat
		dirty = false
		local ok, err = pcall(doUpdate, m)
		if not ok then
			warn("[Podium] " .. tostring(err))
		end
	until not dirty
	busy = false
end

function Podium.start()
	task.spawn(function()
		local lobby = workspace:WaitForChild("Lobby", 120)
		local m = lobby and lobby:WaitForChild("Top3", 120) -- мебель ставится после загрузки мешей
		if not m or not m:IsA("Model") then
			warn("[Podium] нет пьедестала Top3 в лобби")
			return
		end
		podium = m
		ReplicatedStorage:GetAttributeChangedSignal("WeeklyBoard"):Connect(function()
			task.spawn(update)
		end)
		update()
		-- 2-е и 3-е место по очереди машут рукой
		local turn = 2
		while m.Parent do
			task.wait(P.WAVE_EVERY)
			local id = onStep[turn] or 0
			local model = id ~= 0 and cache[id]
			if model and model.Parent then
				local track = animTrack(model, "wave")
				if track then
					track.Looped = false
					track.Priority = Enum.AnimationPriority.Action
					track:Play(0.2)
					track.Stopped:Once(function()
						track:Destroy()
					end)
				end
			end
			turn = if turn == 2 then 3 else 2
		end
	end)
end

return Podium
