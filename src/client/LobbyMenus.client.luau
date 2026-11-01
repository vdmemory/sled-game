-- Меню лобби в стиле мобильного оригинала:
--  • слева колонка «ледяных» плиток-иконок (Миры, Задания, Сани, Следы, Подарки);
--  • справа шестерёнка, Билет дня, Цвета ватрушки;
--  • под заголовком — жёлтая плашка сундука с таймером;
--  • окна — голубые, с лентой-заголовком и круглым красным крестиком (Shared/UIKit).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UI = require(ReplicatedStorage.Shared:WaitForChild("UIKit"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local hud = player:WaitForChild("PlayerGui"):WaitForChild("HUD")
local root = hud:WaitForChild("Root")
local lobby = root:WaitForChild("Lobby")
local C = UI.C

------------------------------------------------------------------ окна
local panels: { GuiObject } = {}
local function closeAll()
	for _, p in panels do
		p.Visible = false
	end
end
local function panel(title: string, w: number, h: number): (Frame, Frame, TextLabel)
	local p, body, t = UI.panel(hud, title, w, h)
	table.insert(panels, p)
	return p, body, t
end
local function open(p: GuiObject)
	local was = p.Visible
	closeAll()
	if not was then
		p.Visible = true
		UI.pop(p)
	end
end

-- Короткое сообщение под заголовком лобби
local msg = UI.text({
	Text = "",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.2),
	Size = UDim2.fromOffset(520, 46),
	TextColor3 = Color3.fromRGB(255, 225, 90),
	Visible = false,
	ZIndex = 80,
	Parent = hud,
})
UI.outline(msg, 3)
local msgN = 0
local function say(ok: boolean, text: any)
	if typeof(text) ~= "string" then
		return
	end
	msgN += 1
	local my = msgN
	msg.Text = (if ok then "✔ " else "") .. text
	msg.Visible = true
	task.delay(1.8, function()
		if msgN == my then
			msg.Visible = false
		end
	end)
end

local function csvSet(attr: string): { [string]: boolean }
	local set = {}
	for id in string.gmatch(player:GetAttribute(attr) or "", "[^,]+") do
		set[id] = true
	end
	return set
end

------------------------------------------------------------------ колонки плиток
local function column(anchorX: number, x: number): Frame
	local col = UI.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(anchorX, 0),
		Position = UDim2.new(anchorX, x, 0, 70),
		Size = UDim2.fromOffset(88, 520),
		Parent = lobby,
	})
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, 12)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = col
	return col
end
local left = column(0, 18)
local right = column(1, -18)

local function tile(col: Frame, order: number, icon: string): TextButton
	local t = UI.tile(col, icon, { LayoutOrder = order, Size = UDim2.fromOffset(84, 84) })
	return t
end
local worldsBtn = tile(left, 1, "🌍")
local tasksBtn = tile(left, 2, "📋")
local sledsBtn = tile(left, 3, "🛷")
local trailsBtn = tile(left, 4, "✨")
local giftBtn = tile(left, 5, "🎁")
local tasksBadge = UI.badge(tasksBtn, "!")
tasksBadge.Visible = false
local trailsNew = UI.badge(trailsBtn, "NEW", "green")
local giftTimer = UI.text({ Text = "", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 4), Size = UDim2.fromOffset(84, 24), ZIndex = 5, Parent = giftBtn })
local giftBadge = UI.badge(giftBtn, "!")
giftBadge.Visible = false

-- справа: шестерёнка (кружок), билет дня, цвета
local gear = UI.new("TextButton", { Text = "", LayoutOrder = 0, Size = UDim2.fromOffset(84, 60), BackgroundTransparency = 1, Parent = right })
local gearBg = UI.new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(56, 56), BackgroundColor3 = C.navy, BackgroundTransparency = 0.35, Parent = gear })
UI.corner(gearBg, 1000)
UI.stroke(gearBg, 2.5, C.white, 0.3)
UI.text({ Text = "⚙", Position = UDim2.fromScale(0.16, 0.12), Size = UDim2.fromScale(0.68, 0.72), Parent = gearBg })
UI.bounce(gear)
local ticketBtn = tile(right, 1, "🎟")
local ticketBadge = UI.badge(ticketBtn, "!")
ticketBadge.Visible = false
local colorsBtn = tile(right, 2, "🎨")

-- Жёлтая плашка сундука под заголовком
local chestPill = UI.new("TextButton", {
	Text = "",
	AutoButtonColor = false,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 130),
	Size = UDim2.fromOffset(200, 50),
	BackgroundTransparency = 0,
	Parent = lobby,
})
UI.grad(chestPill, Color3.fromRGB(255, 225, 80), Color3.fromRGB(245, 175, 30))
UI.corner(chestPill, 1000)
UI.stroke(chestPill, 3)
UI.bounce(chestPill)
UI.text({ Text = "🧰", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 6, 0.5, -4), Size = UDim2.fromOffset(64, 64), Outline = 0, ZIndex = 3, Parent = chestPill })
local chestInner = UI.new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.new(1, -60, 1, -14), BackgroundColor3 = C.navy, BackgroundTransparency = 0.1, ZIndex = 2, Parent = chestPill })
UI.corner(chestInner, 1000)
local chestText = UI.text({ Text = "", Position = UDim2.fromOffset(8, 3), Size = UDim2.new(1, -16, 1, -6), ZIndex = 3, Parent = chestInner })

------------------------------------------------------------------ награды (состояние с сервера)
local rewards: any = nil
local function readRewards()
	local raw = player:GetAttribute("Rewards")
	if typeof(raw) == "string" then
		local ok, v = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok then
			rewards = v
			rewards.offset = v.now - os.time()
		end
	end
end
local function serverNow(): number
	return os.time() + (if rewards then rewards.offset else 0)
end
local function clock(sec: number): string
	sec = math.max(0, math.floor(sec))
	if sec >= 3600 then
		return string.format("%dч %02dм", sec // 3600, (sec % 3600) // 60)
	end
	return string.format("%d:%02d", sec // 60, sec % 60)
end
local function act(action: string, arg: any?): (boolean, any)
	local ok, res = Remotes.RewardAction:InvokeServer(action, arg)
	if typeof(res) == "string" then
		say(ok, res)
	end
	return ok, res
end
chestPill.Activated:Connect(function()
	act("chest")
end)

------------------------------------------------------------------ Миры
local worldsWin, worldsBody = panel("МИРЫ", 720, 400)
local worldsList = UI.new("ScrollingFrame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 20),
	Size = UDim2.new(1, 0, 1, -20),
	ScrollingDirection = Enum.ScrollingDirection.X,
	AutomaticCanvasSize = Enum.AutomaticSize.X,
	CanvasSize = UDim2.new(),
	ScrollBarThickness = 6,
	ZIndex = 32,
	Parent = worldsBody,
})
local wl = Instance.new("UIListLayout")
wl.FillDirection = Enum.FillDirection.Horizontal
wl.Padding = UDim.new(0, 14)
wl.Parent = worldsList
local function drawWorlds()
	for _, c in worldsList:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local level = player:GetAttribute("Level") or 1
	local best = player:GetAttribute("LevelBest") or 0
	local current = Config.worldOf(level)
	local per = Config.LEVELS_PER_WORLD
	for w = 1, math.max(current + 1, 4) do
		local theme = Config.themeOfWorld(w)
		local card = UI.new("Frame", { Size = UDim2.new(0, 200, 1, -14), BackgroundColor3 = C.row, BackgroundTransparency = 0, ZIndex = 33, Parent = worldsList })
		UI.corner(card, 16)
		UI.stroke(card, 3)
		local pic = UI.new("Frame", { Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 130), BackgroundTransparency = 0, ZIndex = 34, Parent = card })
		local col = Config.WORLD_COLORS[theme]
		UI.grad(pic, col:Lerp(Color3.new(1, 1, 1), 0.35), col)
		UI.corner(pic, 12)
		UI.text({ Text = Config.WORLD_ICONS[theme], Position = UDim2.fromScale(0.25, 0.1), Size = UDim2.fromScale(0.5, 0.8), Outline = 0, ZIndex = 35, Parent = pic })
		local num = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(40, 40), BackgroundTransparency = 0, ZIndex = 36, Parent = card })
		UI.grad(num, UI.KIND.yellow[1], UI.KIND.yellow[2])
		UI.corner(num, 1000)
		UI.stroke(num, 2.5)
		UI.text({ Text = tostring(w), Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 1, -12), ZIndex = 37, Parent = num })
		UI.ink({ Text = Config.worldName(w), Position = UDim2.fromOffset(8, 144), Size = UDim2.new(1, -16, 0, 28), ZIndex = 34, Parent = card })
		local done = math.clamp(level - 1 - (w - 1) * per, 0, per)
		local frac = if w == current then (done + best / 100) / per elseif w < current then 1 else 0
		local _, set = UI.progress(card, { Position = UDim2.fromOffset(14, 180), Size = UDim2.new(1, -28, 0, 24), ZIndex = 34 })
		set(frac, math.floor(frac * 100) .. "%")
		local kind, text
		if w == current then
			kind, text = "green", "✔ ВЫ ЗДЕСЬ"
		elseif w < current then
			kind, text = "yellow", "🏆 ПРОЙДЕН"
		else
			kind, text = "grey", "🔒 Пройди мир " .. (w - 1)
		end
		local st = UI.button(kind, text, { Position = UDim2.new(0, 10, 1, -58), Size = UDim2.new(1, -20, 0, 48), ZIndex = 34, Parent = card })
		st.Active = false
	end
end
worldsBtn.Activated:Connect(function()
	drawWorlds()
	open(worldsWin)
end)

------------------------------------------------------------------ Задания дня
local tasksWin, tasksBody = panel("ЗАДАНИЯ ДНЯ", 540, 540)
UI.text({ Text = "🐧", Position = UDim2.fromOffset(0, 18), Size = UDim2.fromOffset(84, 84), Outline = 0, ZIndex = 33, Parent = tasksBody })
UI.text({ Text = "ВЫПОЛНИ ВСЕ ЗАДАНИЯ,\nЧТОБЫ ПОЛУЧИТЬ СУНДУК!", Position = UDim2.fromOffset(90, 22), Size = UDim2.new(1, -170, 0, 46), ZIndex = 33, Parent = tasksBody })
local _, setTasksBar = UI.progress(tasksBody, { Position = UDim2.fromOffset(92, 74), Size = UDim2.new(1, -170, 0, 24), ZIndex = 33 })
local chestClaim = UI.new("TextButton", { Text = "", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 34), Size = UDim2.fromOffset(72, 72), BackgroundTransparency = 1, ZIndex = 34, Parent = tasksBody })
local chestIcon = UI.text({ Text = "🧰", Size = UDim2.fromScale(1, 1), Outline = 0, ZIndex = 35, Parent = chestClaim })
UI.bounce(chestClaim)
chestClaim.Activated:Connect(function()
	act("taskChest")
end)
local taskRows = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 116), Size = UDim2.new(1, 0, 1, -160), ZIndex = 32, Parent = tasksBody })
local tl = Instance.new("UIListLayout")
tl.Padding = UDim.new(0, 10)
tl.SortOrder = Enum.SortOrder.LayoutOrder
tl.Parent = taskRows
local resetLabel = UI.ink({ Text = "", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.new(1, 0, 0, 30), ZIndex = 33, Parent = tasksBody })

local TASK_ICONS = { runs = "🛷", coins = "💰", distance = "🏔", air = "🪂", flips = "🔄", smash = "💥", best = "🏆" }
local function drawTasks()
	for _, c in taskRows:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	if not rewards then
		return
	end
	local claimed, ready = 0, 0
	for i, t in rewards.tasks do
		local done = t.progress >= t.target
		if t.claimed then
			claimed += 1
		elseif done then
			ready += 1
		end
		local row = UI.new("TextButton", { Text = "", AutoButtonColor = false, LayoutOrder = i, Size = UDim2.new(1, 0, 0, 92), BackgroundTransparency = 0, ZIndex = 33, Parent = taskRows })
		if done and not t.claimed then
			UI.grad(row, UI.KIND.yellow[1], UI.KIND.yellow[2])
			UI.bounce(row)
			row.Activated:Connect(function()
				act("task", i)
			end)
		else
			row.BackgroundColor3 = C.row
		end
		UI.corner(row, 16)
		UI.stroke(row, 2.5, Color3.fromRGB(120, 170, 225))
		local iconBox = UI.new("Frame", { Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(76, 76), BackgroundColor3 = C.white, BackgroundTransparency = 0.2, ZIndex = 34, Parent = row })
		UI.corner(iconBox, 12)
		local id = t.id
		UI.text({ Text = if t.claimed then "✅" elseif done then "✔" else (TASK_ICONS[id or ""] or "📋"), Position = UDim2.fromScale(0.12, 0.12), Size = UDim2.fromScale(0.76, 0.76), Outline = 0, ZIndex = 35, Parent = iconBox })
		if done and not t.claimed then
			UI.ink({ Text = t.text, Position = UDim2.fromOffset(96, 10), Size = UDim2.new(1, -200, 0, 28), ZIndex = 34, Parent = row })
			UI.text({ Text = "ЗАБРАТЬ НАГРАДУ!", Position = UDim2.fromOffset(96, 44), Size = UDim2.new(1, -200, 0, 34), ZIndex = 34, Parent = row })
		else
			UI.ink({ Text = t.text, Position = UDim2.fromOffset(96, 10), Size = UDim2.new(1, -200, 0, 30), ZIndex = 34, Parent = row })
			local _, set = UI.progress(row, { Position = UDim2.fromOffset(100, 50), Size = UDim2.new(1, -210, 0, 26), ZIndex = 34 })
			set(t.progress / t.target, t.progress .. "/" .. t.target)
		end
		UI.text({ Text = if t.claimed then "✔" else "💎 " .. t.gems, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(86, 40), ZIndex = 34, Parent = row })
	end
	local total = #rewards.tasks
	setTasksBar(claimed / total, claimed .. "/" .. total)
	chestIcon.Text = if rewards.chestClaimed then "✅" else "🧰"
	chestClaim.Active = claimed == total and not rewards.chestClaimed
	tasksBadge.Text = tostring(ready)
	tasksBadge.Visible = ready > 0
	if claimed == total and not rewards.chestClaimed then
		tasksBadge.Text = "!"
		tasksBadge.Visible = true
	end
end
tasksBtn.Activated:Connect(function()
	drawTasks()
	open(tasksWin)
end)

------------------------------------------------------------------ Подарки за время в игре
local giftsWin, giftsBody = panel("ПОДАРКИ", 600, 470)
local giftGrid = Instance.new("UIGridLayout")
giftGrid.CellSize = UDim2.fromOffset(128, 112)
giftGrid.CellPadding = UDim2.fromOffset(12, 12)
giftGrid.SortOrder = Enum.SortOrder.LayoutOrder
giftGrid.Parent = giftsBody
UI.pad(giftsBody, 14)
type GiftCell = { status: TextButton, reward: TextLabel }
local giftCells: { GiftCell } = {}
for i, g in Config.PLAYTIME_GIFTS do
	local cell = UI.new("Frame", { LayoutOrder = i, BackgroundColor3 = C.row, BackgroundTransparency = 0, ZIndex = 33, Parent = giftsBody })
	UI.corner(cell, 14)
	UI.stroke(cell, 2.5, Color3.fromRGB(120, 170, 225))
	local reward = UI.ink({ Text = "", Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 0, 52), ZIndex = 34, Parent = cell })
	local st = UI.button("blue", "", { Position = UDim2.new(0, 8, 1, -46), Size = UDim2.new(1, -16, 0, 38), Radius = 10, StrokeThickness = 2, ZIndex = 34, Parent = cell })
	st.Activated:Connect(function()
		act("gift", i)
	end)
	giftCells[i] = { status = st, reward = reward }
end
giftBtn.Activated:Connect(function()
	open(giftsWin)
end)

------------------------------------------------------------------ Билет дня
local ticketWin, ticketBody = panel("БИЛЕТ ДНЯ", 600, 420)
UI.ink({ Text = "Сотри 3 карточки — награды твои!", Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 30), ZIndex = 33, Parent = ticketBody })
local ticketResult: any = nil
local ticketCards: { TextButton } = {}
for i = 1, 3 do
	local c = UI.new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Position = UDim2.new((i - 1) / 3, 6, 0, 58),
		Size = UDim2.new(1 / 3, -12, 0, 220),
		BackgroundTransparency = 0,
		ZIndex = 33,
		Parent = ticketBody,
	})
	UI.grad(c, Color3.fromRGB(255, 220, 110), Color3.fromRGB(235, 165, 45))
	UI.corner(c, 16)
	UI.stroke(c, 3)
	UI.bounce(c)
	local face = UI.text({ Text = "❄", Position = UDim2.fromOffset(10, 20), Size = UDim2.new(1, -20, 1, -40), ZIndex = 34, Parent = c })
	ticketCards[i] = c
	c.Activated:Connect(function()
		if not ticketResult then
			local ok, res = act("scratch")
			if not ok then
				return
			end
			ticketResult = res
		end
		local r = ticketResult[i]
		if r and not c:GetAttribute("Open") then
			c:SetAttribute("Open", true)
			face.Text = r.rarity .. "\n" .. r.text
			local g = c:FindFirstChildOfClass("UIGradient") :: UIGradient
			g.Color = if r.gem then ColorSequence.new(Color3.fromRGB(190, 230, 255), Color3.fromRGB(110, 180, 250)) else ColorSequence.new(Color3.fromRGB(255, 248, 220), Color3.fromRGB(250, 220, 150))
			UI.pop(c)
		end
	end)
	Instance.new("UIScale").Parent = c
end
UI.ink({
	Text = "Шансы: обычная 60% · необычная 25% · редкая 10% · эпическая 4% · легенда 1%",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -4),
	Size = UDim2.new(1, 0, 0, 24),
	TextColor3 = Color3.fromRGB(70, 90, 130),
	ZIndex = 33,
	Parent = ticketBody,
})
ticketBtn.Activated:Connect(function()
	open(ticketWin)
end)

------------------------------------------------------------------ Сани: модели × редкости
local sledWin, sledBody = panel("САНИ", 840, 520)
local sledList = UI.new("ScrollingFrame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 1, -20), AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ScrollBarThickness = 6, ZIndex = 32, Parent = sledBody })
local sl = Instance.new("UIListLayout")
sl.Padding = UDim.new(0, 12)
sl.Parent = sledList
type Cell = { status: TextButton, model: any, rarity: number }
local sledCells: { Cell } = {}
for mi, model in Config.SLEDS do
	local row = UI.new("Frame", { LayoutOrder = mi, Size = UDim2.new(1, -12, 0, 156), BackgroundColor3 = C.row, BackgroundTransparency = 0, ZIndex = 33, Parent = sledList })
	UI.corner(row, 16)
	UI.stroke(row, 2.5, Color3.fromRGB(120, 170, 225))
	local head = UI.new("Frame", { Position = UDim2.fromOffset(8, 8), Size = UDim2.new(0, 150, 1, -16), BackgroundTransparency = 0, ZIndex = 34, Parent = row })
	UI.grad(head, Color3.fromRGB(250, 252, 255), Color3.fromRGB(205, 225, 245))
	UI.corner(head, 12)
	UI.text({ Text = model.icon, Position = UDim2.fromOffset(35, 4), Size = UDim2.fromOffset(80, 66), Outline = 0, ZIndex = 35, Parent = head })
	UI.ink({ Text = model.name, Position = UDim2.fromOffset(6, 72), Size = UDim2.new(1, -12, 0, 28), ZIndex = 35, Parent = head })
	if model.bonus > 0 then
		local tag = UI.button("green", "+" .. model.bonus .. "% скорости", { Position = UDim2.fromOffset(8, 104), Size = UDim2.new(1, -16, 0, 30), Radius = 8, StrokeThickness = 2, ZIndex = 35, Parent = head })
		tag.Active = false
	end
	for r, rar in Config.RARITIES do
		local cell = UI.new("Frame", { Position = UDim2.new(0, 170 + (r - 1) * 126, 0, 8), Size = UDim2.new(0, 118, 1, -16), BackgroundColor3 = C.white, BackgroundTransparency = 0, ZIndex = 34, Parent = row })
		UI.corner(cell, 12)
		UI.stroke(cell, 2)
		local nameL = UI.text({ Text = rar.name, Position = UDim2.fromOffset(6, 4), Size = UDim2.new(1, -12, 0, 24), TextColor3 = rar.color or C.ink, ZIndex = 35, Parent = cell })
		if rar.color then
			UI.outline(nameL, 1.5)
		end
		local sw = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 30), Size = UDim2.fromOffset(50, 50), BackgroundColor3 = rar.color or Color3.fromRGB(240, 70, 120), BackgroundTransparency = 0, ZIndex = 35, Parent = cell })
		UI.corner(sw, 1000)
		UI.stroke(sw, 2)
		UI.text({ Text = model.icon, Position = UDim2.fromScale(0.15, 0.15), Size = UDim2.fromScale(0.7, 0.7), Outline = 0, ZIndex = 36, Parent = sw })
		local total = model.bonus + rar.bonus
		UI.ink({ Text = if total > 0 then "+" .. total .. "%" else "базовые", Position = UDim2.fromOffset(6, 82), Size = UDim2.new(1, -12, 0, 18), TextColor3 = Color3.fromRGB(60, 150, 70), ZIndex = 35, Parent = cell })
		local status = UI.button("blue", "", { Position = UDim2.new(0, 6, 1, -40), Size = UDim2.new(1, -12, 0, 34), Radius = 10, StrokeThickness = 2, ZIndex = 35, Parent = cell })
		status.Activated:Connect(function()
			say(Remotes.SledAction:InvokeServer(model.id, r))
		end)
		table.insert(sledCells, { status = status, model = model, rarity = r })
	end
end
local function drawSleds()
	local owned = csvSet("OwnedSleds")
	local coins = player:GetAttribute("Coins") or 0
	local world = Config.worldOf(player:GetAttribute("Level") or 1)
	local cur, curR = player:GetAttribute("Sled") or "tube", player:GetAttribute("SledRarity") or 1
	for _, c in sledCells do
		local key = c.model.id .. ":" .. c.rarity
		local kind, text
		if c.model.id == cur and c.rarity == curR then
			kind, text = "green", "✔ НАДЕТО"
		elseif owned[key] then
			kind, text = "blue", "НАДЕТЬ"
		elseif world < c.model.world then
			kind, text = "grey", "🔒 мир " .. c.model.world
		elseif c.rarity > 1 and not owned[c.model.id .. ":" .. (c.rarity - 1)] then
			kind, text = "grey", "🔒 " .. UI.money(c.model.prices[c.rarity])
		else
			local price = c.model.prices[c.rarity]
			kind, text = if coins >= price then "yellow" else "grey", "💰 " .. UI.money(price)
		end
		UI.setKind(c.status, kind)
		UI.setText(c.status, text)
	end
end
sledsBtn.Activated:Connect(function()
	drawSleds()
	open(sledWin)
end)

------------------------------------------------------------------ Следы
local trailWin, trailBody = panel("СЛЕДЫ", 660, 500)
local trailGrid = Instance.new("UIGridLayout")
trailGrid.CellSize = UDim2.fromOffset(142, 186)
trailGrid.CellPadding = UDim2.fromOffset(12, 12)
trailGrid.SortOrder = Enum.SortOrder.LayoutOrder
trailGrid.Parent = trailBody
UI.pad(trailBody, 14)
local trailCells: { [string]: TextButton } = {}
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 70)),
	ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 210, 50)),
	ColorSequenceKeypoint.new(0.66, Color3.fromRGB(80, 220, 120)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 90, 255)),
})
for i, t in Config.TRAILS do
	local card = UI.new("Frame", { LayoutOrder = i, BackgroundColor3 = C.row, BackgroundTransparency = 0, ZIndex = 33, Parent = trailBody })
	UI.corner(card, 14)
	UI.stroke(card, 2.5, Color3.fromRGB(120, 170, 225))
	local ribbon = UI.new("Frame", { Position = UDim2.fromOffset(14, 16), Size = UDim2.new(1, -28, 0, 46), BackgroundColor3 = t.color, BackgroundTransparency = 0, ZIndex = 34, Parent = card })
	UI.corner(ribbon, 1000)
	UI.stroke(ribbon, 2)
	if t.rainbow then
		ribbon.BackgroundColor3 = C.white
		local g = Instance.new("UIGradient")
		g.Color = RAINBOW
		g.Parent = ribbon
	end
	UI.ink({ Text = t.name, Position = UDim2.fromOffset(8, 70), Size = UDim2.new(1, -16, 0, 28), ZIndex = 34, Parent = card })
	UI.ink({ Text = if t.bonus > 0 then "+" .. t.bonus .. "% монет" else "без бонуса", Position = UDim2.fromOffset(8, 100), Size = UDim2.new(1, -16, 0, 22), TextColor3 = Color3.fromRGB(200, 140, 20), ZIndex = 34, Parent = card })
	local st = UI.button("blue", "", { Position = UDim2.new(0, 10, 1, -48), Size = UDim2.new(1, -20, 0, 38), Radius = 10, StrokeThickness = 2, ZIndex = 34, Parent = card })
	st.Activated:Connect(function()
		say(Remotes.TrailAction:InvokeServer(t.id))
	end)
	trailCells[t.id] = st
end
local function drawTrails()
	local owned = csvSet("OwnedTrails")
	local coins = player:GetAttribute("Coins") or 0
	local cur = player:GetAttribute("Trail") or "white"
	for _, t in Config.TRAILS do
		local st = trailCells[t.id]
		if t.id == cur then
			UI.setKind(st, "green")
			UI.setText(st, "✔ НАДЕТ")
		elseif owned[t.id] then
			UI.setKind(st, "blue")
			UI.setText(st, "НАДЕТЬ")
		else
			UI.setKind(st, if coins >= t.price then "yellow" else "grey")
			UI.setText(st, "💰 " .. UI.money(t.price))
		end
	end
end
trailsBtn.Activated:Connect(function()
	trailsNew.Visible = false
	drawTrails()
	open(trailWin)
end)

------------------------------------------------------------------ Цвета ватрушки
local colorWin, colorBody = panel("ЦВЕТА ВАТРУШКИ", 640, 440)
local colorGrid = Instance.new("UIGridLayout")
colorGrid.CellSize = UDim2.fromOffset(136, 160)
colorGrid.CellPadding = UDim2.fromOffset(12, 12)
colorGrid.Parent = colorBody
UI.pad(colorBody, 14)
local colorCells: { [string]: TextButton } = {}
for _, skin in Config.SKINS do
	local card = UI.new("Frame", { BackgroundColor3 = C.row, BackgroundTransparency = 0, ZIndex = 33, Parent = colorBody })
	UI.corner(card, 14)
	UI.stroke(card, 2.5, Color3.fromRGB(120, 170, 225))
	local disc = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.fromOffset(62, 62), BackgroundColor3 = skin.tube, BackgroundTransparency = 0, ZIndex = 34, Parent = card })
	UI.corner(disc, 1000)
	UI.stroke(disc, 7, skin.rim)
	UI.ink({ Text = skin.name, Position = UDim2.fromOffset(6, 82), Size = UDim2.new(1, -12, 0, 26), ZIndex = 34, Parent = card })
	local st = UI.button("blue", "", { Position = UDim2.new(0, 8, 1, -46), Size = UDim2.new(1, -16, 0, 38), Radius = 10, StrokeThickness = 2, ZIndex = 34, Parent = card })
	st.Activated:Connect(function()
		say(Remotes.SkinAction:InvokeServer(skin.id))
	end)
	colorCells[skin.id] = st
end
local function drawColors()
	local owned = csvSet("OwnedSkins")
	local coins = player:GetAttribute("Coins") or 0
	local cur = player:GetAttribute("Skin") or "classic"
	for _, skin in Config.SKINS do
		local st = colorCells[skin.id]
		if skin.id == cur then
			UI.setKind(st, "green")
			UI.setText(st, "✔ НАДЕТО")
		elseif owned[skin.id] or skin.price == 0 then
			UI.setKind(st, "blue")
			UI.setText(st, "НАДЕТЬ")
		else
			UI.setKind(st, if coins >= skin.price then "yellow" else "grey")
			UI.setText(st, "💰 " .. UI.money(skin.price))
		end
	end
end
colorsBtn.Activated:Connect(function()
	drawColors()
	open(colorWin)
end)

------------------------------------------------------------------ Настройки (как SETTINGS в оригинале: круглые кнопки-иконки)
local setWin = UI.new("Frame", {
	Name = "Panel_Settings",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(420, 260),
	BackgroundColor3 = Color3.fromRGB(26, 44, 86),
	BackgroundTransparency = 0.05,
	Visible = false,
	ZIndex = 30,
	Parent = hud,
})
UI.corner(setWin, 22)
UI.stroke(setWin, 3, Color3.fromRGB(90, 140, 220))
Instance.new("UIScale").Parent = setWin
table.insert(panels, setWin)
UI.text({ Text = "НАСТРОЙКИ", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(260, 40), ZIndex = 31, Parent = setWin })
UI.closeButton(setWin, function()
	setWin.Visible = false
end)
local function toggle(key: string, icon: string, caption: string, x: number)
	local b = UI.new("TextButton", { Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, x, 0, 76), Size = UDim2.fromOffset(84, 84), BackgroundTransparency = 0, ZIndex = 31, Parent = setWin })
	UI.grad(b, UI.KIND.blue[1], UI.KIND.blue[2])
	UI.corner(b, 1000)
	UI.stroke(b, 3, C.white, 0.2)
	UI.bounce(b)
	UI.text({ Text = icon, Position = UDim2.fromScale(0.18, 0.18), Size = UDim2.fromScale(0.64, 0.64), Outline = 0, ZIndex = 32, Parent = b })
	local slash = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1.05, 0, 0, 8), Rotation = -45, BackgroundColor3 = Color3.fromRGB(235, 60, 60), BackgroundTransparency = 0, ZIndex = 33, Parent = b })
	UI.corner(slash, 1000)
	UI.stroke(slash, 2, C.white)
	UI.text({ Text = caption, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 6), Size = UDim2.fromOffset(110, 24), ZIndex = 32, Parent = b })
	local function paint()
		local on = player:GetAttribute("Set" .. key) ~= false
		slash.Visible = not on
		local g = b:FindFirstChildOfClass("UIGradient") :: UIGradient
		local k = if on then UI.KIND.blue else UI.KIND.grey
		g.Color = ColorSequence.new(k[1], k[2])
	end
	b.Activated:Connect(function()
		local on = player:GetAttribute("Set" .. key) ~= false
		player:SetAttribute("Set" .. key, not on)
		Remotes.SetSetting:FireServer(key, not on)
	end)
	player:GetAttributeChangedSignal("Set" .. key):Connect(paint)
	paint()
end
toggle("Sfx", "🔊", "Звуки", -120)
toggle("Snow", "❄", "Снегопад", 0)
toggle("Shadows", "🌗", "Тени", 120)
gear.Activated:Connect(function()
	open(setWin)
end)
local function applyShadows()
	Lighting.GlobalShadows = player:GetAttribute("SetShadows") ~= false
end
player:GetAttributeChangedSignal("SetShadows"):Connect(applyShadows)
applyShadows()

------------------------------------------------------------------ обновление
for _, attr in { "Coins", "Level", "OwnedSleds", "Sled", "SledRarity", "OwnedTrails", "Trail", "OwnedSkins", "Skin" } do
	player:GetAttributeChangedSignal(attr):Connect(function()
		if sledWin.Visible then
			drawSleds()
		end
		if trailWin.Visible then
			drawTrails()
		end
		if colorWin.Visible then
			drawColors()
		end
	end)
end

local ticketShown = false
local function refreshRewards()
	readRewards()
	if not rewards then
		return
	end
	local level = player:GetAttribute("Level") or 1
	for i, g in Config.PLAYTIME_GIFTS do
		giftCells[i].reward.Text = (if g.coins then "💰 " .. UI.money(Config.rewardCoins(g.coins, level)) else "")
			.. (if g.gems then (if g.coins then "\n" else "") .. "💎 " .. g.gems else "")
	end
	drawTasks()
	ticketBadge.Visible = rewards.ticketReady
	if rewards.ticketReady and not ticketShown and player:GetAttribute("InRun") ~= true then
		ticketShown = true
		task.delay(2, function()
			open(ticketWin)
		end)
	end
end
player:GetAttributeChangedSignal("Rewards"):Connect(refreshRewards)
refreshRewards()

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.5 or not rewards then
		return
	end
	acc = 0
	local now = serverNow()
	local elapsed = now - rewards.sessionStart
	local nextIn: number? = nil
	local ready = 0
	for i, g in Config.PLAYTIME_GIFTS do
		local cell = giftCells[i]
		local leftSec = g.min * 60 - elapsed
		if rewards.gifts[i] then
			UI.setKind(cell.status, "grey")
			UI.setText(cell.status, "✔")
		elseif leftSec <= 0 then
			ready += 1
			UI.setKind(cell.status, "green")
			UI.setText(cell.status, "ЗАБРАТЬ")
		else
			UI.setKind(cell.status, "blue")
			UI.setText(cell.status, clock(leftSec))
			nextIn = if nextIn then math.min(nextIn, leftSec) else leftSec
		end
	end
	giftBadge.Text = tostring(ready)
	giftBadge.Visible = ready > 0
	giftTimer.Text = if ready > 0 then "" elseif nextIn then clock(nextIn) else ""
	local chestLeft = rewards.chestAt - now
	chestText.Text = if chestLeft <= 0 then "ОТКРЫТЬ!" else clock(chestLeft)
	resetLabel.Text = "Обновятся через: 🕒 " .. clock(rewards.resetAt - now)
end)

-- В заезде все окна закрываем
player:GetAttributeChangedSignal("InRun"):Connect(function()
	if player:GetAttribute("InRun") then
		closeAll()
	end
end)
