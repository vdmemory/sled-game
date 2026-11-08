-- Обучение первых заездов (#27): одна крупная подсказка за раз (иконка + ≤ 6 слов), исчезает по
-- действию игрока, по тапу или по таймеру. Шаги, тексты и тайминги — Config.TUTORIAL; пройденные
-- шаги — биты атрибута Tutorial (сейв, сервер), отчёт серверу — ремоут TutorialStep (0 — пропустить всё).
-- Триггеры: атрибуты игрока (Loaded, InRun, Launched, RunDistance, Runs, Coins, *Level) и
-- SledController.State (AwaitingLaunch, Airborne, Fuel, RocketOn), Stick.X — руль пальцем.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UI = require(ReplicatedStorage.Shared:WaitForChild("UIKit"))
local UIFx = require(ReplicatedStorage.Shared:WaitForChild("UIFx"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local TutorialStep: RemoteEvent = Remotes:WaitForChild("TutorialStep") :: RemoteEvent

local player = Players.LocalPlayer
local controller = script.Parent:WaitForChild("SledController")
local state = controller:WaitForChild("State")
local stickX = controller:WaitForChild("Stick"):WaitForChild("X")
local TOUCH = UserInputService.TouchEnabled
local T = Config.TUTORIAL
local STEPS = T.STEPS
local ALL = 2 ^ #STEPS - 1
local idx: { [string]: number } = {}
for i, s in STEPS do
	idx[s.id] = i
end

------------------------------------------------------------------ интерфейс
local gui = Instance.new("ScreenGui")
gui.Name = "Tutorial"
gui.ResetOnSpawn = false
gui.DisplayOrder = 90
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

-- Масштаб как у HUD (UI.fitScale, телефон боком ≈ 0.55–0.57): позиции — в логических пикселях HUD
local root = UI.new("Frame", { Name = "Root", BackgroundTransparency = 1, Parent = gui })
local rootScale = UI.fitScale(root, gui)

-- Плашка: [иконка][текст] + справа «Пропустить» (обе 80 высотой — ≥ 44 px на телефоне). Места —
-- Shared/UILayout: в заезде под комбо (tutorialRun 132–212, рогатка — tutorialLaunch 196–276), в
-- лобби над «НАЖМИ, ЧТОБЫ ИГРАТЬ» (tutorialLobby −378…−298, между полосой наград и «ИГРАТЬ» даже
-- на корне 565). Ширина 720 — не задевает подписи плиток слева (до x 134) даже на 4:3.
local group = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(UI.L.tutorialLobby[7], UI.L.tutorialLobby[8]), BackgroundTransparency = 1, Visible = false, Parent = root })
local groupScale = Instance.new("UIScale")
groupScale.Parent = group
local panel = UI.new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.new(1, -(UI.L.TUTORIAL_SKIP_W + 10), 1, 0), BackgroundTransparency = 0.05, Parent = group })
UI.grad(panel, Color3.fromRGB(52, 70, 112), Color3.fromRGB(32, 46, 80))
UI.corner(panel, 16)
UI.stroke(panel, 3, UI.C.gold)
local icon = UI.icon("star", { Position = UDim2.fromOffset(10, 12), Size = UDim2.fromOffset(54, 54), Parent = panel })
local label = UI.text({ Text = "", Position = UDim2.fromOffset(72, 12), Size = UDim2.new(1, -84, 1, -24), Outline = 3, Parent = panel })
local maxSize = Instance.new("UITextSizeConstraint")
maxSize.MaxTextSize = 36 -- ≥ 28 логических → ≥ 16 px на телефоне
maxSize.Parent = label
local skip = UI.button("grey", "Пропустить", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, UI.L.TUTORIAL_SKIP_W, 1, 0), Parent = group })

-- Рука-указатель (жест на телефоне / на кнопку или карточку) — вне масштаба, в пикселях экрана
local hand = UI.new("TextLabel", { Text = "👆", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(60, 60), Visible = false, ZIndex = 5, Parent = gui })
local handTween: Tween? = nil

------------------------------------------------------------------ состояние
local mask = 0 -- локальная копия (с учётом ещё не подтверждённых сервером шагов)
local current: number? = nil
local shownAt, closedAt = 0, -math.huge
local lobbyIdleFrom = os.clock()
local levelsAtShow = 0
local lastPulse = 0
local airFrom = 0

local function bit(i: number): number
	return 2 ^ (i - 1)
end
local function isDone(i: number): boolean
	if i == idx.jump and Config.JUMP_ENABLED < 1 then
		return true -- прыжок выключен: шаг считается пройденным, следующие подсказки не ждут его
	end
	return bit32.btest(mask, bit(i))
end
local function syncMask()
	mask = bit32.bor(mask, player:GetAttribute("Tutorial") or 0)
end
player:GetAttributeChangedSignal("Tutorial"):Connect(function()
	-- сервер может и обнулить (DEV «Сбросить обучение») — тогда берём как есть
	local v = player:GetAttribute("Tutorial") or 0
	mask = if v == 0 then 0 else bit32.bor(mask, v)
end)
syncMask()

local function levelsSum(): number
	local n = 0
	for name in Config.UPGRADES do
		n += player:GetAttribute(name .. "Level") or 0
	end
	return n
end

local function hudLobby(): GuiObject?
	local hud = player.PlayerGui:FindFirstChild("HUD")
	local r = hud and hud:FindFirstChild("Root")
	return r and r:FindFirstChild("Lobby") :: GuiObject?
end
local function panelOpen(): boolean
	local hud = player.PlayerGui:FindFirstChild("HUD")
	for _, w in if hud then hud:GetChildren() else {} do
		if w:IsA("Frame") and string.sub(w.Name, 1, 6) == "Panel_" and w.Visible then
			return true
		end
	end
	return false
end
local function inLobby(): boolean
	local l = hudLobby()
	return l ~= nil and l.Visible and not panelOpen()
end
local function inRun(): boolean
	return player:GetAttribute("InRun") == true
end

-- Самая дешёвая карточка за монеты (Рогатка на старте): её подсвечиваем
local function cheapestCard(): (GuiObject?, boolean)
	local best, bestCost = nil, math.huge
	for _, name in Config.UPGRADE_ORDER do
		local u = Config.UPGRADES[name]
		local lvl = player:GetAttribute(name .. "Level") or 0
		if lvl < u.MaxLevel then
			local cost, currency = Config.upgradePrice(name, lvl)
			if currency == "Coins" and cost < bestCost then
				best, bestCost = name, cost
			end
		end
	end
	local l = hudLobby()
	local card = best and l and l:FindFirstChild("Card_" .. best, true) :: GuiObject?
	return card, (player:GetAttribute("Coins") or 0) >= bestCost
end
local function playButton(): GuiObject?
	local l = hudLobby()
	return l and l:FindFirstChild("PlayButton") :: GuiObject?
end

------------------------------------------------------------------ показ
local function stopHand()
	if handTween then
		handTween:Cancel()
		handTween = nil
	end
	hand.Visible = false
end

-- Рука у цели (над карточкой — вниз, слева от кнопки — вправо) или жест (dx, dy) в центре экрана
local function pointAt(target: GuiObject?, gesture: Vector2?)
	stopHand()
	local vp = workspace.CurrentCamera.ViewportSize
	local s = rootScale.Scale
	hand.Size = UDim2.fromOffset(64 * s, 64 * s)
	local from, to
	if target then
		local p, sz = target.AbsolutePosition, target.AbsoluteSize
		if target.Name == "PlayButton" then
			hand.Text = "👉"
			from = Vector2.new(p.X + sz.X * 0.12 - 40 * s, p.Y + sz.Y / 2)
			to = from + Vector2.new(18 * s, 0)
		else
			hand.Text = "👇"
			from = Vector2.new(p.X + sz.X / 2, p.Y + 30 * s)
			to = from + Vector2.new(0, 16 * s)
		end
	elseif gesture then
		hand.Text = "👆"
		from = Vector2.new(vp.X / 2, vp.Y * 0.72) - gesture * s / 2
		to = from + gesture * s
	else
		return
	end
	hand.Position = UDim2.fromOffset(from.X, from.Y)
	hand.Visible = true
	handTween = TweenService:Create(hand, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = UDim2.fromOffset(to.X, to.Y) })
	;(handTween :: Tween):Play()
end

local function show(i: number)
	local s = STEPS[i]
	current = i
	shownAt = os.clock()
	levelsAtShow = levelsSum()
	lastPulse = 0
	UI.setIcon(icon, s.icon)
	label.Text = if TOUCH then s.touch else s.pc
	-- рогатка: под шкалой силы и её подписью
	UI.at(if s.where == "lobby" then UI.L.tutorialLobby elseif s.id == "launch" then UI.L.tutorialLaunch else UI.L.tutorialRun, group :: any)
	group.Visible = true
	groupScale.Scale = 0.6
	TweenService:Create(groupScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	if s.id == "play" or s.id == "again" then
		pointAt(playButton())
	elseif s.id == "upgrade" then
		pointAt((cheapestCard()))
	elseif TOUCH and s.id == "steer" then
		pointAt(nil, Vector2.new(160, 0))
	elseif TOUCH and s.id == "launch" then
		pointAt(nil, Vector2.new(0, 120))
	else
		stopHand()
	end
end

-- done = true: шаг засчитан (сервер запомнит); false — просто убрать (покажем в следующий раз)
local function hide(done: boolean)
	local i = current
	if not i then
		return
	end
	current = nil
	closedAt = os.clock()
	group.Visible = false
	stopHand()
	if done and not isDone(i) then
		mask = bit32.bor(mask, bit(i))
		TutorialStep:FireServer(i)
	end
end

local function markDone(i: number)
	if not isDone(i) then
		mask = bit32.bor(mask, bit(i))
		TutorialStep:FireServer(i)
	end
end

panel.Activated:Connect(function()
	hide(true)
end)
skip.Activated:Connect(function()
	hide(false)
	mask = ALL
	TutorialStep:FireServer(0)
end)
UserInputService.InputBegan:Connect(function()
	lobbyIdleFrom = os.clock()
end)

------------------------------------------------------------------ правила шагов
-- want(i): пора показать шаг i; finish(i): действие выполнено (→ засчитать); keep(i): контекст жив
local function runsDone(): number
	return player:GetAttribute("Runs") or 0
end
local function runHints(): boolean
	return inRun() and runsDone() < T.MAX_RUNS - 1
end
local function launched(): boolean
	return player:GetAttribute("Launched") == true
end
local function steering(): boolean
	return math.abs(stickX.Value) > 0.3
		or UserInputService:IsKeyDown(Enum.KeyCode.A)
		or UserInputService:IsKeyDown(Enum.KeyCode.D)
		or UserInputService:IsKeyDown(Enum.KeyCode.Left)
		or UserInputService:IsKeyDown(Enum.KeyCode.Right)
end

local RULES: { [string]: { want: () -> boolean, finish: () -> boolean, keep: () -> boolean } } = {
	play = {
		want = function()
			return inLobby() and runsDone() == 0 and os.clock() - lobbyIdleFrom >= T.IDLE
		end,
		finish = inRun,
		keep = inLobby,
	},
	launch = {
		want = function()
			return runHints() and state.AwaitingLaunch.Value
		end,
		finish = launched,
		keep = inRun,
	},
	steer = {
		want = function()
			return runHints() and launched() and (player:GetAttribute("RunDistance") or 0) >= Config.SAFE_START - T.STEER_AHEAD
		end,
		finish = steering,
		keep = inRun,
	},
	jump = {
		want = function()
			return Config.JUMP_ENABLED >= 1 and runHints() and launched() and isDone(idx.steer) and not state.Airborne.Value
		end,
		finish = function()
			return state.Airborne.Value
		end,
		keep = inRun,
	},
	flip = {
		-- первый настоящий полёт (трамплин/обрыв), а не кочка: в воздухе ≥ 0.25 с
		want = function()
			return runHints() and isDone(idx.jump) and state.Airborne.Value and os.clock() - airFrom >= 0.25
		end,
		finish = function()
			return UserInputService:IsKeyDown(Enum.KeyCode.Space) or not state.Airborne.Value
		end,
		keep = inRun,
	},
	rocket = {
		want = function()
			return runHints() and launched() and isDone(idx.jump) and state.Fuel.Value > 0 and not state.Airborne.Value
		end,
		finish = function()
			return state.RocketOn.Value
		end,
		keep = inRun,
	},
	upgrade = {
		want = function()
			if not inLobby() or runsDone() < 1 or runsDone() >= T.MAX_RUNS then
				return false
			end
			local card, affordable = cheapestCard()
			return card ~= nil and affordable
		end,
		finish = function()
			return levelsSum() > levelsAtShow
		end,
		keep = inLobby,
	},
	again = {
		want = function()
			return inLobby() and runsDone() >= 1 and runsDone() < T.MAX_RUNS and isDone(idx.upgrade)
		end,
		finish = inRun,
		keep = inLobby,
	},
}

state.Airborne.Changed:Connect(function(v)
	if v then
		airFrom = os.clock()
	end
end)

-- 5 раз в секунду: дёшево, без Heartbeat
while true do
	task.wait(0.2)
	if mask == ALL or player:GetAttribute("Loaded") ~= true then
		if current then
			hide(false)
		end
		continue
	end
	-- первый заезд начат сам (дошёл до саней) — «к саням» больше не нужен
	if inRun() and not isDone(idx.play) then
		if current == idx.play then
			hide(true)
		else
			markDone(idx.play)
		end
	end
	local i = current
	if i then
		local s = STEPS[i]
		local rule = RULES[s.id]
		-- выполнено, либо в заезде показали достаточно — второй раз не навязываем
		if rule.finish() or (s.where == "run" and os.clock() - shownAt >= T.HOLD) then
			hide(true)
		elseif not rule.keep() then
			hide(false)
		elseif s.id == "upgrade" and os.clock() - lastPulse >= T.PULSE then
			lastPulse = os.clock()
			local card = cheapestCard()
			if card then
				UIFx.pulseSelect(card, "УЛУЧШИ!")
			end
		end
	elseif os.clock() - closedAt >= T.GAP or (state.AwaitingLaunch.Value and not isDone(idx.launch)) then
		for n, s in STEPS do
			if not isDone(n) and RULES[s.id].want() then
				show(n)
				break
			end
		end
	end
end
