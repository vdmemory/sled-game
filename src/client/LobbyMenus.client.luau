-- Меню лобби в стиле мобильного оригинала:
--  • слева колонка «ледяных» плиток-иконок (Миры, Задания, Сани, Следы, Подарки);
--  • справа шестерёнка и Цвета ватрушки;
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
-- Прокручиваемая область внутри окна: всё содержимое обрезается рамкой окна,
-- внутренний отступ не даёт обводкам и значкам карточек упираться в край
local function scroller(body: GuiObject, horizontal: boolean?, top: number?): ScrollingFrame
	local sf = UI.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, top or 0),
		Size = UDim2.new(1, 0, 1, -(top or 0)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = if horizontal then Enum.AutomaticSize.X else Enum.AutomaticSize.Y,
		ScrollingDirection = if horizontal then Enum.ScrollingDirection.X else Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Color3.fromRGB(90, 130, 190),
		ZIndex = 32,
		Parent = body,
	})
	local pad = UI.pad(sf, 12)
	pad.PaddingTop = UDim.new(0, 14) -- место под круглые номера/значки у верхнего края карточек
	return sf
end
local function grid(parent: Instance, w: number, h: number): UIGridLayout
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.fromOffset(w, h)
	g.CellPadding = UDim2.fromOffset(12, 12)
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.HorizontalAlignment = Enum.HorizontalAlignment.Center
	g.Parent = parent
	return g
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
local worldsBtn = tile(left, 1, "globe")
local tasksBtn = tile(left, 2, "tasks")
local sledsBtn = tile(left, 3, "sled")
local trailsBtn = tile(left, 4, "sparkles")
local giftBtn = tile(left, 5, "gift")
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
UI.icon("gear", { Position = UDim2.fromScale(0.14, 0.14), Size = UDim2.fromScale(0.72, 0.72), Parent = gearBg })
UI.bounce(gear)
local colorsBtn = tile(right, 1, "palette")

-- Жёлтая плашка сундука под заголовком
local chestPill = UI.new("TextButton", {
	Text = "",
	AutoButtonColor = false,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 130),
	Size = UDim2.fromOffset(230, 50),
	BackgroundTransparency = 0,
	Parent = lobby,
})
UI.grad(chestPill, Color3.fromRGB(255, 225, 80), Color3.fromRGB(245, 175, 30))
UI.corner(chestPill, 1000)
UI.stroke(chestPill, 3)
UI.bounce(chestPill)
-- нарисованный сундук вылезает за левый край плашки (как в оригинале)
UI.chest(chestPill, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 14, 0.5, -6), Size = UDim2.fromOffset(78, 70), ZIndex = 4 })
local chestShine = UI.new("Frame", { Position = UDim2.new(0, 40, 0, 4), Size = UDim2.new(1, -60, 0, 5), BackgroundColor3 = C.white, BackgroundTransparency = 0.5, ZIndex = 2, Parent = chestPill })
UI.corner(chestShine, 1000)
local chestInner = UI.new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.new(1, -66, 1, -14), BackgroundColor3 = C.navy, BackgroundTransparency = 0.05, ZIndex = 2, Parent = chestPill })
UI.corner(chestInner, 1000)
-- монетка слева в тёмной капсуле таймера
UI.coin(chestInner, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0), Size = UDim2.fromOffset(28, 28), ZIndex = 3 })
local chestText = UI.text({ Text = "", Position = UDim2.fromOffset(34, 3), Size = UDim2.new(1, -40, 1, -6), ZIndex = 3, Parent = chestInner })

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
local worldsList = scroller(worldsBody, true, 6)
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
		local card = UI.new("Frame", { Size = UDim2.new(0, 200, 1, -6), BackgroundColor3 = C.row, BackgroundTransparency = 0, ZIndex = 33, Parent = worldsList })
		UI.corner(card, 16)
		UI.stroke(card, 3)
		local pic = UI.new("Frame", { Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 130), BackgroundTransparency = 0, ZIndex = 34, Parent = card })
		local col = Config.WORLD_COLORS[theme]
		UI.grad(pic, col:Lerp(Color3.new(1, 1, 1), 0.35), col)
		UI.corner(pic, 12)
		UI.icon(({ "tree", "city", "cactus" })[theme] or "tree", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromScale(0.62, 0.86), ZIndex = 35, Parent = pic })
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
		-- Кнопка: фармить пройденный мир / вернуться в текущий / пропустить следующий за Robux
		local farm = player:GetAttribute("FarmWorld") or 0
		local kind, text, action, arg
		if w == current then
			if farm == 0 then
				kind, text = "green", "✔ ВЫ ЗДЕСЬ"
			else
				kind, text, action, arg = "blue", "▶ ВЕРНУТЬСЯ", "farm", 0
			end
		elseif w < current then
			if farm == w then
				kind, text = "green", "✔ ФАРМИШЬ ЗДЕСЬ"
			else
				kind, text, action, arg = "yellow", "▶ ФАРМИТЬ", "farm", w
			end
		elseif w == current + 1 then
			kind, text, action = "purple", "ПРОПУСК R$" .. Config.PRODUCTS.SkipWorld.price, "skip"
		else
			kind, text = "grey", "Пройди мир " .. (w - 1)
		end
		if w < current and farm ~= w then
			-- подсказка: в пройденном мире уровень не растёт, только монеты
			UI.ink({ Text = "монеты без прогресса", Position = UDim2.new(0, 8, 1, -82), Size = UDim2.new(1, -16, 0, 20), TextTransparency = 0.3, ZIndex = 34, Parent = card })
		end
		local st = UI.button(kind, text, { Position = UDim2.new(0, 10, 1, -58), Size = UDim2.new(1, -20, 0, 48), ZIndex = 34, Parent = card })
		if action then
			st.Activated:Connect(function()
				local ok, msg = Remotes.WorldAction:InvokeServer(action, arg)
				if typeof(msg) == "string" then
					say(ok, msg)
				end
				if ok and action == "farm" then
					worldsWin.Visible = false
				end
			end)
		else
			st.Active = false
		end
	end
end
player:GetAttributeChangedSignal("FarmWorld"):Connect(function()
	if worldsWin.Visible then
		drawWorlds()
	end
end)
worldsBtn.Activated:Connect(function()
	drawWorlds()
	-- прокрутка к текущему миру (карточка 200 + отступ 14)
	local current = Config.worldOf(player:GetAttribute("Level") or 1)
	worldsList.CanvasPosition = Vector2.new(math.max(0, (current - 2) * 214), 0)
	open(worldsWin)
end)

------------------------------------------------------------------ Задания дня
local tasksWin, tasksBody = panel("ЗАДАНИЯ ДНЯ", 540, 540)
UI.text({ Text = "ВЫПОЛНИ ВСЕ ЗАДАНИЯ,\nЧТОБЫ ПОЛУЧИТЬ СУНДУК!", Position = UDim2.fromOffset(10, 22), Size = UDim2.new(1, -100, 0, 46), ZIndex = 33, Parent = tasksBody })
local _, setTasksBar = UI.progress(tasksBody, { Position = UDim2.fromOffset(12, 74), Size = UDim2.new(1, -100, 0, 24), ZIndex = 33 })
local chestClaim = UI.new("TextButton", { Text = "", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 34), Size = UDim2.fromOffset(72, 72), BackgroundTransparency = 1, ZIndex = 34, Parent = tasksBody })
local chestIcon = UI.chest(chestClaim, { Position = UDim2.fromOffset(2, 6), Size = UDim2.fromOffset(68, 60), ZIndex = 35 })
local chestDone = UI.icon("check", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1), Size = UDim2.fromOffset(32, 32), Visible = false, ZIndex = 45, Parent = chestClaim })
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

local TASK_ICONS = { runs = "sled", coins = "coin", distance = "mountain", air = "parachute", flips = "flip", smash = "smash", best = "trophy" }
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
		UI.icon(if t.claimed or done then "check" else (TASK_ICONS[id or ""] or "tasks"), { Position = UDim2.fromScale(0.1, 0.1), Size = UDim2.fromScale(0.8, 0.8), ZIndex = 35, Parent = iconBox })
		if done and not t.claimed then
			UI.ink({ Text = t.text, Position = UDim2.fromOffset(96, 10), Size = UDim2.new(1, -200, 0, 28), ZIndex = 34, Parent = row })
			UI.text({ Text = "ЗАБРАТЬ НАГРАДУ!", Position = UDim2.fromOffset(96, 44), Size = UDim2.new(1, -200, 0, 34), ZIndex = 34, Parent = row })
		else
			UI.ink({ Text = t.text, Position = UDim2.fromOffset(96, 10), Size = UDim2.new(1, -200, 0, 30), ZIndex = 34, Parent = row })
			local _, set = UI.progress(row, { Position = UDim2.fromOffset(100, 50), Size = UDim2.new(1, -210, 0, 26), ZIndex = 34 })
			set(t.progress / t.target, t.progress .. "/" .. t.target)
		end
		local _, setReward = UI.iconText({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(86, 34), ZIndex = 34, Parent = row })
		if t.claimed then
			setReward("", "check")
		else
			setReward(tostring(t.gems), "gem")
		end
	end
	local total = #rewards.tasks
	setTasksBar(claimed / total, claimed .. "/" .. total)
	chestDone.Visible = rewards.chestClaimed == true
	local _ = chestIcon
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
local giftsWin, giftsBody = panel("ПОДАРКИ", 640, 470)
local giftsArea = scroller(giftsBody, false, 6)
grid(giftsArea, 128, 112)
type GiftCell = { status: TextButton, setCoins: (string, string?) -> (), setGems: (string, string?) -> (), rows: { Frame } }
local giftCells: { GiftCell } = {}
for i, g in Config.PLAYTIME_GIFTS do
	local cell = UI.new("Frame", { LayoutOrder = i, BackgroundColor3 = C.row, BackgroundTransparency = 0, ZIndex = 33, Parent = giftsArea })
	UI.corner(cell, 14)
	UI.stroke(cell, 2.5, Color3.fromRGB(120, 170, 225))
	-- награда: крупно одна строка, либо две (монеты + гемы)
	local both = g.coins ~= nil and g.gems ~= nil
	local rowCoins, setCoins = UI.iconText({ Position = UDim2.fromOffset(6, if both then 6 else 12), Size = UDim2.new(1, -12, 0, if both then 24 else 40), Color = C.ink, ZIndex = 34, Parent = cell })
	local rowGems, setGems = UI.iconText({ Position = UDim2.fromOffset(6, if both then 32 else 12), Size = UDim2.new(1, -12, 0, if both then 24 else 40), Color = C.ink, ZIndex = 34, Parent = cell })
	local st = UI.button("blue", "", { Position = UDim2.new(0, 8, 1, -46), Size = UDim2.new(1, -16, 0, 38), Radius = 10, StrokeThickness = 2, ZIndex = 34, Parent = cell })
	st.Activated:Connect(function()
		act("gift", i)
	end)
	giftCells[i] = { status = st, setCoins = setCoins, setGems = setGems, rows = { rowCoins, rowGems } }
end
giftBtn.Activated:Connect(function()
	open(giftsWin)
end)

------------------------------------------------------------------ Сани: модели × редкости
local sledWin, sledBody = panel("САНИ", 880, 520)
local sledList = scroller(sledBody, false, 6)
local sl = Instance.new("UIListLayout")
sl.Padding = UDim.new(0, 12)
sl.Parent = sledList
type Cell = { status: TextButton, model: any, rarity: number }
local sledCells: { Cell } = {}
for mi, model in Config.SLEDS do
	local row = UI.new("Frame", { LayoutOrder = mi, Size = UDim2.new(1, -8, 0, 156), BackgroundColor3 = C.row, BackgroundTransparency = 0, ZIndex = 33, Parent = sledList })
	UI.corner(row, 16)
	UI.stroke(row, 2.5, Color3.fromRGB(120, 170, 225))
	local head = UI.new("Frame", { Position = UDim2.fromOffset(8, 8), Size = UDim2.new(0, 150, 1, -16), BackgroundTransparency = 0, ZIndex = 34, Parent = row })
	UI.grad(head, Color3.fromRGB(250, 252, 255), Color3.fromRGB(205, 225, 245))
	UI.corner(head, 12)
	UI.icon(model.img, { Position = UDim2.fromOffset(37, 4), Size = UDim2.fromOffset(76, 66), ZIndex = 35, Parent = head })
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
		UI.icon(model.img, { Position = UDim2.fromScale(0.12, 0.12), Size = UDim2.fromScale(0.76, 0.76), ZIndex = 36, Parent = sw })
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
		local icon: string? = nil
		if c.model.id == cur and c.rarity == curR then
			kind, text = "green", "✔ НАДЕТО"
		elseif owned[key] then
			kind, text = "blue", "НАДЕТЬ"
		elseif world < c.model.world then
			kind, text, icon = "grey", "мир " .. c.model.world, "lock"
		elseif c.rarity > 1 and not owned[c.model.id .. ":" .. (c.rarity - 1)] then
			kind, text, icon = "grey", UI.money(c.model.prices[c.rarity]), "lock"
		else
			local price = c.model.prices[c.rarity]
			kind, text = if coins >= price then "yellow" else "grey", UI.money(price)
			icon = "coin"
		end
		UI.setKind(c.status, kind)
		UI.setText(c.status, text, icon)
	end
end
sledsBtn.Activated:Connect(function()
	drawSleds()
	open(sledWin)
end)

------------------------------------------------------------------ Следы
local trailWin, trailBody = panel("СЛЕДЫ", 700, 500)
local trailArea = scroller(trailBody, false, 6)
grid(trailArea, 142, 176)
local trailCells: { [string]: TextButton } = {}
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 70)),
	ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 210, 50)),
	ColorSequenceKeypoint.new(0.66, Color3.fromRGB(80, 220, 120)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 90, 255)),
})
for i, t in Config.TRAILS do
	local card = UI.new("Frame", { LayoutOrder = i, BackgroundColor3 = C.row, BackgroundTransparency = 0, ZIndex = 33, Parent = trailArea })
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
			UI.setText(st, UI.money(t.price), "coin")
		end
	end
end
trailsBtn.Activated:Connect(function()
	trailsNew.Visible = false
	drawTrails()
	open(trailWin)
end)

------------------------------------------------------------------ Цвета ватрушки
local colorWin, colorBody = panel("ЦВЕТА ВАТРУШКИ", 680, 460)
local colorArea = scroller(colorBody, false, 6)
grid(colorArea, 136, 160)
local colorCells: { [string]: TextButton } = {}
for _, skin in Config.SKINS do
	local card = UI.new("Frame", { BackgroundColor3 = C.row, BackgroundTransparency = 0, ZIndex = 33, Parent = colorArea })
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
			UI.setText(st, UI.money(skin.price), "coin")
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
	Position = UDim2.fromScale(0.5, 0.42), -- выше карточек апгрейдов, чтобы их значки не налезали

	Size = UDim2.fromOffset(470, 260),
	BackgroundColor3 = Color3.fromRGB(26, 44, 86),
	BackgroundTransparency = 0,
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
	UI.icon(icon, { Position = UDim2.fromScale(0.17, 0.17), Size = UDim2.fromScale(0.66, 0.66), ZIndex = 32, Parent = b })
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
toggle("Sfx", "speaker", "Звуки", -159)
toggle("Music", "music", "Музыка", -53)
toggle("Snow", "snowflake", "Снегопад", 53)
toggle("Shadows", "moon", "Тени", 159)
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

local function refreshRewards()
	readRewards()
	if not rewards then
		return
	end
	local level = player:GetAttribute("Level") or 1
	for i, g in Config.PLAYTIME_GIFTS do
		local cell = giftCells[i]
		cell.rows[1].Visible = g.coins ~= nil
		cell.rows[2].Visible = g.gems ~= nil
		if g.coins then
			cell.setCoins(UI.money(Config.rewardCoins(g.coins, level)), "coin")
		end
		if g.gems then
			cell.setGems(tostring(g.gems), "gem")
		end
	end
	drawTasks()
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
			UI.setText(cell.status, "ПОЛУЧЕНО")
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
	resetLabel.Text = "Обновятся через " .. clock(rewards.resetAt - now)
end)

-- В заезде все окна закрываем
player:GetAttributeChangedSignal("InRun"):Connect(function()
	if player:GetAttribute("InRun") then
		closeAll()
	end
end)
