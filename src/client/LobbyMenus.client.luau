-- Меню лобби в стиле Roblox-референса: колонка 2×2 слева (Миры, Сани, Следы, Задания),
-- шестерёнка настроек, единый стиль окон (цветная шапка + красный крестик).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local hud = player:WaitForChild("PlayerGui"):WaitForChild("HUD")
local lobby = hud:WaitForChild("Lobby")
local shop = hud:WaitForChild("Shop") :: GuiObject

local FONT = Enum.Font.FredokaOne
local WHITE = Color3.new(1, 1, 1)
local DARK = Color3.fromRGB(30, 45, 80)

------------------------------------------------------------------ helpers
local function corner(inst: GuiObject, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = inst
end
local function stroke(inst: GuiObject, t: number?)
	local s = Instance.new("UIStroke")
	s.Thickness = t or 2
	s.Color = Color3.fromRGB(20, 40, 70)
	s.Transparency = 0.2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = inst
end
local function new(class: string, props: { [string]: any }): any
	local o = Instance.new(class)
	if o:IsA("GuiObject") then
		(o :: any).BorderSizePixel = 0
	end
	if o:IsA("TextLabel") or o:IsA("TextButton") then
		(o :: any).Font = FONT;
		(o :: any).TextColor3 = WHITE;
		(o :: any).TextScaled = true
	end
	for k, v in props do
		(o :: any)[k] = v
	end
	return o
end
-- «Пружинка» при нажатии, как у кнопок в референсе
local function bouncy(b: GuiButton)
	local scale = Instance.new("UIScale")
	scale.Parent = b
	b.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.08), { Scale = 0.92 }):Play()
	end)
	local function up()
		TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	b.MouseButton1Up:Connect(up)
	b.MouseLeave:Connect(up)
end

------------------------------------------------------------------ окна
local windows: { GuiObject } = {}
local function closeAll()
	for _, w in windows do
		w.Visible = false
	end
	shop.Visible = false
end

-- Окно: цветная шапка с заголовком, красный крестик, белое тело. Возвращает (окно, тело)
local function window(title: string, color: Color3, w: number, h: number): (Frame, Frame)
	local root = new("Frame", {
		Name = "Win_" .. title,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = Color3.fromRGB(240, 245, 255),
		Visible = false,
		ZIndex = 30,
		Parent = hud,
	})
	corner(root, 20)
	stroke(root, 4)
	local scale = Instance.new("UIScale")
	scale.Parent = root
	local function fit()
		local vp = workspace.CurrentCamera.ViewportSize
		scale.Scale = math.min(1, (vp.X - 24) / w, (vp.Y - 24) / h)
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	fit()
	local head = new("Frame", { Size = UDim2.new(1, 0, 0, 58), BackgroundColor3 = color, ZIndex = 31, Parent = root })
	corner(head, 20)
	new("Frame", { Position = UDim2.new(0, 0, 1, -20), Size = UDim2.new(1, 0, 0, 20), BackgroundColor3 = color, ZIndex = 31, Parent = head })
	new("TextLabel", { Text = title, BackgroundTransparency = 1, Position = UDim2.new(0, 60, 0, 10), Size = UDim2.new(1, -120, 1, -18), ZIndex = 32, Parent = head })
	local x = new("TextButton", {
		Text = "X",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 8, 0, -8),
		Size = UDim2.fromOffset(48, 48),
		BackgroundColor3 = Color3.fromRGB(230, 70, 65),
		ZIndex = 33,
		Parent = root,
	})
	corner(x, 14)
	stroke(x, 3)
	bouncy(x)
	x.Activated:Connect(function()
		root.Visible = false
	end)
	local body = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 16, 0, 70), Size = UDim2.new(1, -32, 1, -84), ZIndex = 31, Parent = root })
	table.insert(windows, root)
	return root, body
end

local function open(win: GuiObject)
	local was = win.Visible
	closeAll()
	if not was then
		win.Visible = true
		local s = win:FindFirstChildOfClass("UIScale") :: UIScale
		local target = s.Scale
		s.Scale = target * 0.8
		TweenService:Create(s, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = target }):Play()
	end
end

------------------------------------------------------------------ колонка кнопок слева
local column = new("Frame", {
	Name = "LeftColumn",
	BackgroundTransparency = 1,
	Position = UDim2.new(0, 16, 0, 110),
	Size = UDim2.fromOffset(170, 240),
	Parent = lobby,
})
local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.fromOffset(80, 80)
grid.CellPadding = UDim2.fromOffset(10, 10)
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = column

local function tile(order: number, icon: string, text: string, color: Color3): (TextButton, TextLabel)
	local b = new("TextButton", { Text = "", LayoutOrder = order, BackgroundColor3 = color, AutoButtonColor = true, Parent = column })
	corner(b, 16)
	stroke(b, 3)
	bouncy(b)
	new("TextLabel", { Text = icon, BackgroundTransparency = 1, Position = UDim2.new(0.15, 0, 0.06, 0), Size = UDim2.fromScale(0.7, 0.55), Parent = b })
	new("TextLabel", { Text = text, BackgroundTransparency = 1, Position = UDim2.new(0.05, 0, 0.62, 0), Size = UDim2.fromScale(0.9, 0.3), TextStrokeTransparency = 0.4, Parent = b })
	local badge = new("TextLabel", {
		Text = "",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 6, 0, -6),
		Size = UDim2.fromOffset(44, 20),
		BackgroundColor3 = Color3.fromRGB(230, 70, 65),
		Visible = false,
		Parent = b,
	})
	corner(badge, 10)
	return b, badge
end

local worldsBtn = tile(1, "🌍", "Миры", Color3.fromRGB(70, 150, 220))
local sledsBtn = tile(2, "🛷", "Сани", Color3.fromRGB(230, 90, 140))
local trailsBtn, trailsBadge = tile(3, "✨", "Следы", Color3.fromRGB(140, 100, 230))
local tasksBtn, tasksBadge = tile(4, "📋", "Задания", Color3.fromRGB(240, 160, 40))



-- Шестерёнка настроек справа сверху
local gear = new("TextButton", {
	Text = "⚙",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 60),
	Size = UDim2.fromOffset(50, 50),
	BackgroundColor3 = Color3.fromRGB(60, 80, 120),
	Parent = lobby,
})
corner(gear, 25)
stroke(gear, 3)
bouncy(gear)

------------------------------------------------------------------ Миры
local worldsWin, worldsBody = window("🌍 Миры", Color3.fromRGB(70, 150, 220), 700, 380)
local worldsList = new("ScrollingFrame", {
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
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

local function refreshWorlds()
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
		local color = Config.WORLD_COLORS[theme]
		local card = new("Frame", { Size = UDim2.new(0, 200, 1, -12), BackgroundColor3 = WHITE, ZIndex = 33, Parent = worldsList })
		corner(card, 16)
		stroke(card, 3)
		local pic = new("Frame", { Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 120), BackgroundColor3 = color, ZIndex = 34, Parent = card })
		corner(pic, 12)
		new("TextLabel", { Text = Config.WORLD_ICONS[theme], BackgroundTransparency = 1, Position = UDim2.fromScale(0.25, 0.1), Size = UDim2.fromScale(0.5, 0.8), ZIndex = 35, Parent = pic })
		local num = new("TextLabel", { Text = tostring(w), Position = UDim2.fromOffset(-6, -6), Size = UDim2.fromOffset(36, 36), BackgroundColor3 = Color3.fromRGB(255, 205, 60), TextColor3 = DARK, ZIndex = 36, Parent = card })
		corner(num, 18)
		stroke(num, 2)
		new("TextLabel", { Text = Config.worldName(w), BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 134), Size = UDim2.new(1, -16, 0, 30), TextColor3 = DARK, ZIndex = 34, Parent = card })
		-- прогресс мира: пройденные уровни + текущий рекорд
		local done = math.clamp(level - 1 - (w - 1) * per, 0, per)
		local frac = if w == current then (done + best / 100) / per elseif w < current then 1 else 0
		local bar = new("Frame", { Position = UDim2.fromOffset(14, 172), Size = UDim2.new(1, -28, 0, 22), BackgroundColor3 = Color3.fromRGB(205, 215, 235), ZIndex = 34, Parent = card })
		corner(bar, 11)
		local fill = new("Frame", { Size = UDim2.fromScale(frac, 1), BackgroundColor3 = Color3.fromRGB(70, 170, 255), ZIndex = 35, Parent = bar })
		corner(fill, 11)
		new("TextLabel", { Text = math.floor(frac * 100) .. "%", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), TextStrokeTransparency = 0.4, ZIndex = 36, Parent = bar })
		local status, sColor
		if w == current then
			status, sColor = "✔ ВЫ ЗДЕСЬ", Color3.fromRGB(70, 190, 90)
		elseif w < current then
			status, sColor = "🏆 ПРОЙДЕН", Color3.fromRGB(240, 175, 40)
		else
			status, sColor = "🔒 Пройди мир " .. (w - 1), Color3.fromRGB(150, 155, 170)
		end
		local st = new("TextLabel", { Text = status, Position = UDim2.new(0, 10, 1, -54), Size = UDim2.new(1, -20, 0, 44), BackgroundColor3 = sColor, ZIndex = 34, Parent = card })
		corner(st, 12)
		stroke(st, 2)
	end
end
worldsBtn.Activated:Connect(function()
	refreshWorlds()
	open(worldsWin)
end)

------------------------------------------------------------------ Сани (магазин ватрушек из HUD)
local function csvSet(attr: string): { [string]: boolean }
	local set = {}
	for id in string.gmatch(player:GetAttribute(attr) or "", "[^,]+") do
		set[id] = true
	end
	return set
end
local function money(n: number): string
	if n >= 1000000 then
		return string.format("%.1fM", n / 1000000)
	elseif n >= 10000 then
		return string.format("%.0fK", n / 1000)
	elseif n >= 1000 then
		return string.format("%.1fK", n / 1000)
	end
	return tostring(n)
end
local function say(ok: boolean, msg: any)
	if typeof(msg) == "string" then
		local t = hud:FindFirstChild("MenuToast") :: TextLabel?
		if not t then
			t = new("TextLabel", { Name = "MenuToast", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.18), Size = UDim2.fromOffset(460, 50), BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(255, 230, 90), TextStrokeTransparency = 0.3, ZIndex = 60, Parent = hud })
		end
		local label = t :: TextLabel
		label.Text = (if ok then "✔ " else "") .. msg
		label.Visible = true
		task.delay(1.8, function()
			if label.Text == (if ok then "✔ " else "") .. msg then
				label.Visible = false
			end
		end)
	end
end

------------------------------------------------------------------ Сани: модели × редкости (как в референсе)
local sledWin, sledBody = window("🛷 Сани", Color3.fromRGB(230, 90, 140), 820, 500)
local colorsTab = new("TextButton", { Text = "🎨 Цвета ватрушки", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -60, 0, -58), Size = UDim2.fromOffset(200, 40), BackgroundColor3 = Color3.fromRGB(170, 80, 220), ZIndex = 33, Parent = sledBody })
corner(colorsTab, 12)
stroke(colorsTab, 2)
bouncy(colorsTab)
colorsTab.Activated:Connect(function()
	closeAll()
	shop.Visible = true
end)
local sledList = new("ScrollingFrame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ScrollBarThickness = 6, ZIndex = 32, Parent = sledBody })
local sl = Instance.new("UIListLayout")
sl.Padding = UDim.new(0, 12)
sl.Parent = sledList
type Cell = { btn: TextButton, model: any, rarity: number }
local sledCells: { Cell } = {}
for mi, model in Config.SLEDS do
	local row = new("Frame", { LayoutOrder = mi, Size = UDim2.new(1, -12, 0, 150), BackgroundColor3 = Color3.fromRGB(225, 232, 248), ZIndex = 33, Parent = sledList })
	corner(row, 16)
	local head = new("Frame", { Position = UDim2.fromOffset(8, 8), Size = UDim2.new(0, 150, 1, -16), BackgroundColor3 = WHITE, ZIndex = 34, Parent = row })
	corner(head, 12)
	new("TextLabel", { Text = model.icon, BackgroundTransparency = 1, Position = UDim2.fromOffset(35, 6), Size = UDim2.fromOffset(80, 64), ZIndex = 35, Parent = head })
	new("TextLabel", { Text = model.name, BackgroundTransparency = 1, Position = UDim2.fromOffset(6, 72), Size = UDim2.new(1, -12, 0, 26), TextColor3 = DARK, ZIndex = 35, Parent = head })
	local tag = new("TextLabel", { Text = "+" .. model.bonus .. "% скорости", Position = UDim2.fromOffset(10, 102), Size = UDim2.new(1, -20, 0, 24), BackgroundColor3 = Color3.fromRGB(70, 190, 90), ZIndex = 35, Parent = head })
	corner(tag, 8)
	if model.bonus == 0 then
		tag.Visible = false
	end
	for r, rar in Config.RARITIES do
		local cell = new("TextButton", {
			Text = "",
			Position = UDim2.new(0, 170 + (r - 1) * 124, 0, 8),
			Size = UDim2.new(0, 116, 1, -16),
			BackgroundColor3 = WHITE,
			AutoButtonColor = true,
			ZIndex = 34,
			Parent = row,
		})
		corner(cell, 12)
		stroke(cell, 2)
		new("TextLabel", { Text = rar.name, BackgroundTransparency = 1, Position = UDim2.fromOffset(6, 4), Size = UDim2.new(1, -12, 0, 22), TextColor3 = rar.color or DARK, TextStrokeTransparency = 0.6, ZIndex = 35, Parent = cell })
		local sw = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 30), Size = UDim2.fromOffset(46, 46), BackgroundColor3 = rar.color or Color3.fromRGB(240, 70, 120), ZIndex = 35, Parent = cell })
		corner(sw, 23)
		new("TextLabel", { Text = model.icon, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 36, Parent = sw })
		local total = model.bonus + rar.bonus
		new("TextLabel", { Text = if total > 0 then "+" .. total .. "%" else "базовые", BackgroundTransparency = 1, Position = UDim2.fromOffset(6, 78), Size = UDim2.new(1, -12, 0, 18), TextColor3 = Color3.fromRGB(70, 150, 90), TextStrokeTransparency = 1, ZIndex = 35, Parent = cell })
		local status = new("TextLabel", { Name = "Status", Text = "", Position = UDim2.new(0, 6, 1, -32), Size = UDim2.new(1, -12, 0, 26), BackgroundColor3 = Color3.fromRGB(70, 190, 90), ZIndex = 35, Parent = cell })
		corner(status, 8)
		cell.Activated:Connect(function()
			say(Remotes.SledAction:InvokeServer(model.id, r))
		end)
		table.insert(sledCells, { btn = cell, model = model, rarity = r })
	end
end
local function drawSleds()
	local owned = csvSet("OwnedSleds")
	local coins = player:GetAttribute("Coins") or 0
	local world = Config.worldOf(player:GetAttribute("Level") or 1)
	local cur, curR = player:GetAttribute("Sled") or "tube", player:GetAttribute("SledRarity") or 1
	for _, c in sledCells do
		local status = c.btn:FindFirstChild("Status") :: TextLabel
		local key = c.model.id .. ":" .. c.rarity
		if c.model.id == cur and c.rarity == curR then
			status.Text, status.BackgroundColor3 = "✔ Надето", Color3.fromRGB(70, 190, 90)
		elseif owned[key] then
			status.Text, status.BackgroundColor3 = "Надеть", Color3.fromRGB(80, 150, 240)
		elseif world < c.model.world then
			status.Text, status.BackgroundColor3 = "🔒 мир " .. c.model.world, Color3.fromRGB(150, 155, 170)
		elseif c.rarity > 1 and not owned[c.model.id .. ":" .. (c.rarity - 1)] then
			status.Text, status.BackgroundColor3 = "🔒 " .. money(c.model.prices[c.rarity]), Color3.fromRGB(150, 155, 170)
		else
			local price = c.model.prices[c.rarity]
			status.Text = "💰 " .. money(price)
			status.BackgroundColor3 = if coins >= price then Color3.fromRGB(240, 170, 40) else Color3.fromRGB(150, 155, 170)
		end
	end
end
sledsBtn.Activated:Connect(function()
	drawSleds()
	open(sledWin)
end)

------------------------------------------------------------------ Следы (+% монет)
local trailWin, trailBody = window("✨ Следы", Color3.fromRGB(140, 100, 230), 640, 470)
local trailGrid = Instance.new("UIGridLayout")
trailGrid.CellSize = UDim2.fromOffset(140, 170)
trailGrid.CellPadding = UDim2.fromOffset(12, 12)
trailGrid.SortOrder = Enum.SortOrder.LayoutOrder
trailGrid.Parent = trailBody
local trailCells: { [string]: TextLabel } = {}
for i, t in Config.TRAILS do
	local card = new("TextButton", { Text = "", LayoutOrder = i, BackgroundColor3 = WHITE, ZIndex = 33, Parent = trailBody })
	corner(card, 14)
	stroke(card, 2)
	local ribbon = new("Frame", { Position = UDim2.fromOffset(14, 14), Size = UDim2.new(1, -28, 0, 44), BackgroundColor3 = t.color, ZIndex = 34, Parent = card })
	corner(ribbon, 22)
	if t.rainbow then
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 70)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 210, 50)),
			ColorSequenceKeypoint.new(0.66, Color3.fromRGB(80, 220, 120)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 90, 255)),
		})
		g.Parent = ribbon
		ribbon.BackgroundColor3 = WHITE
	end
	new("TextLabel", { Text = t.name, BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 64), Size = UDim2.new(1, -16, 0, 26), TextColor3 = DARK, ZIndex = 34, Parent = card })
	new("TextLabel", { Text = if t.bonus > 0 then "+" .. t.bonus .. "% монет" else "без бонуса", BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 92), Size = UDim2.new(1, -16, 0, 22), TextColor3 = Color3.fromRGB(200, 150, 30), TextStrokeTransparency = 1, ZIndex = 34, Parent = card })
	local st = new("TextLabel", { Text = "", Position = UDim2.new(0, 10, 1, -40), Size = UDim2.new(1, -20, 0, 30), BackgroundColor3 = Color3.fromRGB(70, 190, 90), ZIndex = 34, Parent = card })
	corner(st, 10)
	trailCells[t.id] = st
	card.Activated:Connect(function()
		say(Remotes.TrailAction:InvokeServer(t.id))
	end)
end
local function drawTrails()
	local owned = csvSet("OwnedTrails")
	local coins = player:GetAttribute("Coins") or 0
	local cur = player:GetAttribute("Trail") or "white"
	for _, t in Config.TRAILS do
		local st = trailCells[t.id]
		if t.id == cur then
			st.Text, st.BackgroundColor3 = "✔ Надет", Color3.fromRGB(70, 190, 90)
		elseif owned[t.id] then
			st.Text, st.BackgroundColor3 = "Надеть", Color3.fromRGB(80, 150, 240)
		else
			st.Text = "💰 " .. money(t.price)
			st.BackgroundColor3 = if coins >= t.price then Color3.fromRGB(240, 170, 40) else Color3.fromRGB(150, 155, 170)
		end
	end
end
trailsBtn.Activated:Connect(function()
	drawTrails()
	open(trailWin)
end)
for _, attr in { "Coins", "Level", "OwnedSleds", "Sled", "SledRarity", "OwnedTrails", "Trail" } do
	player:GetAttributeChangedSignal(attr):Connect(function()
		if sledWin.Visible then
			drawSleds()
		end
		if trailWin.Visible then
			drawTrails()
		end
	end)
end





------------------------------------------------------------------ Настройки
local setWin, setBody = window("⚙ Настройки", Color3.fromRGB(60, 80, 120), 420, 320)
local setList = Instance.new("UIListLayout")
setList.Padding = UDim.new(0, 12)
setList.Parent = setBody
local function toggleRow(key: string, text: string)
	local row = new("Frame", { Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = Color3.fromRGB(225, 232, 248), ZIndex = 32, Parent = setBody })
	corner(row, 14)
	new("TextLabel", { Text = text, BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 10), Size = UDim2.new(0.6, 0, 1, -20), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = DARK, ZIndex = 33, Parent = row })
	local sw = new("TextButton", { Text = "", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(110, 40), ZIndex = 33, Parent = row })
	corner(sw, 20)
	stroke(sw, 2)
	bouncy(sw)
	local function paint()
		local on = player:GetAttribute("Set" .. key) ~= false
		sw.Text = if on then "ВКЛ" else "ВЫКЛ"
		sw.BackgroundColor3 = if on then Color3.fromRGB(70, 190, 90) else Color3.fromRGB(150, 155, 170)
	end
	sw.Activated:Connect(function()
		local on = player:GetAttribute("Set" .. key) ~= false
		player:SetAttribute("Set" .. key, not on) -- сразу, сервер сохранит
		Remotes.SetSetting:FireServer(key, not on)
	end)
	player:GetAttributeChangedSignal("Set" .. key):Connect(paint)
	paint()
end
toggleRow("Sfx", "🔊 Звуки")
toggleRow("Snow", "❄ Снегопад")
toggleRow("Shadows", "🌗 Тени")
gear.Activated:Connect(function()
	open(setWin)
end)

-- Тени применяем у себя (снег и звук читают атрибуты Effects/Sounds)
local function applyShadows()
	Lighting.GlobalShadows = player:GetAttribute("SetShadows") ~= false
end
player:GetAttributeChangedSignal("SetShadows"):Connect(applyShadows)
applyShadows()

------------------------------------------------------------------ награды (состояние с сервера)
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local rewards: any = nil
local function readRewards()
	local raw = player:GetAttribute("Rewards")
	if typeof(raw) == "string" then
		local ok, v = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok then
			rewards = v
			rewards.offset = v.now - os.time() -- поправка часов клиента к серверу
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

local toastLabel = new("TextLabel", {
	Text = "",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.3),
	Size = UDim2.fromOffset(460, 90),
	BackgroundTransparency = 1,
	TextColor3 = Color3.fromRGB(255, 230, 90),
	TextStrokeTransparency = 0.3,
	Visible = false,
	ZIndex = 60,
	Parent = hud,
})
local toastN = 0
local function toast(text: string)
	toastN += 1
	local my = toastN
	toastLabel.Text = text
	toastLabel.Visible = true
	task.delay(2, function()
		if toastN == my then
			toastLabel.Visible = false
		end
	end)
end
local function act(action: string, arg: any?): (boolean, any)
	local ok, res = Remotes.RewardAction:InvokeServer(action, arg)
	if typeof(res) == "string" then
		toast(res)
	end
	return ok, res
end

------------------------------------------------------------------ Задания
local tasksWin, tasksBody = window("📋 Задания дня", Color3.fromRGB(240, 160, 40), 520, 460)
local taskRows = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -110), ZIndex = 32, Parent = tasksBody })
local tl = Instance.new("UIListLayout")
tl.Padding = UDim.new(0, 10)
tl.Parent = taskRows
local chestRow = new("Frame", { Position = UDim2.new(0, 0, 1, -96), Size = UDim2.new(1, 0, 0, 60), BackgroundColor3 = Color3.fromRGB(255, 205, 70), ZIndex = 32, Parent = tasksBody })
corner(chestRow, 14)
stroke(chestRow, 2)
new("TextLabel", { Text = "🧰", BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 6), Size = UDim2.fromOffset(48, 48), ZIndex = 33, Parent = chestRow })
local chestText = new("TextLabel", { Text = "", BackgroundTransparency = 1, Position = UDim2.fromOffset(62, 10), Size = UDim2.new(1, -200, 1, -20), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = DARK, ZIndex = 33, Parent = chestRow })
local chestBtn = new("TextButton", { Text = "", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(120, 42), ZIndex = 33, Parent = chestRow })
corner(chestBtn, 12)
stroke(chestBtn, 2)
bouncy(chestBtn)
chestBtn.Activated:Connect(function()
	act("taskChest")
end)
local resetLabel = new("TextLabel", { Text = "", BackgroundTransparency = 1, Position = UDim2.new(0, 0, 1, -30), Size = UDim2.new(1, 0, 0, 26), TextColor3 = Color3.fromRGB(110, 120, 140), ZIndex = 32, Parent = tasksBody })

local function drawTasks()
	for _, c in taskRows:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	if not rewards then
		return
	end
	local readyCount = 0
	for i, t in rewards.tasks do
		local row = new("Frame", { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 74), BackgroundColor3 = Color3.fromRGB(225, 232, 248), ZIndex = 33, Parent = taskRows })
		corner(row, 14)
		new("TextLabel", { Text = t.text, BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -170, 0, 28), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = DARK, ZIndex = 34, Parent = row })
		local bar = new("Frame", { Position = UDim2.fromOffset(14, 42), Size = UDim2.new(1, -170, 0, 20), BackgroundColor3 = Color3.fromRGB(190, 200, 225), ZIndex = 34, Parent = row })
		corner(bar, 10)
		local fill = new("Frame", { Size = UDim2.fromScale(math.clamp(t.progress / t.target, 0, 1), 1), BackgroundColor3 = Color3.fromRGB(70, 170, 255), ZIndex = 35, Parent = bar })
		corner(fill, 10)
		new("TextLabel", { Text = t.progress .. "/" .. t.target, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), TextStrokeTransparency = 0.4, ZIndex = 36, Parent = bar })
		local done = t.progress >= t.target
		local b = new("TextButton", {
			Text = if t.claimed then "✔" elseif done then "ЗАБРАТЬ\n💎 " .. t.gems else "💎 " .. t.gems,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(130, 54),
			BackgroundColor3 = if t.claimed then Color3.fromRGB(150, 155, 170) elseif done then Color3.fromRGB(70, 190, 90) else Color3.fromRGB(80, 150, 240),
			AutoButtonColor = done and not t.claimed,
			ZIndex = 34,
			Parent = row,
		})
		corner(b, 12)
		stroke(b, 2)
		if done and not t.claimed then
			readyCount += 1
			bouncy(b)
			b.Activated:Connect(function()
				act("task", i)
			end)
		end
	end
	local allClaimed = true
	for _, t in rewards.tasks do
		allClaimed = allClaimed and t.claimed
	end
	chestText.Text = if rewards.chestClaimed then "Сундук открыт — приходи завтра!" else "Выполни все задания — получи сундук"
	chestBtn.Text = if rewards.chestClaimed then "✔" elseif allClaimed then "ОТКРЫТЬ" else "🔒"
	chestBtn.BackgroundColor3 = if allClaimed and not rewards.chestClaimed then Color3.fromRGB(70, 190, 90) else Color3.fromRGB(150, 155, 170)
	tasksBadge.Text = if readyCount > 0 then "!" .. readyCount else ""
	tasksBadge.Visible = readyCount > 0
end
tasksBtn.Activated:Connect(function()
	drawTasks()
	open(tasksWin)
end)

------------------------------------------------------------------ Подарки за время в игре
local giftBtn = new("TextButton", {
	Text = "",
	LayoutOrder = 5,
	Size = UDim2.fromOffset(170, 50),
	Position = UDim2.new(0, 16, 0, 290),
	BackgroundColor3 = Color3.fromRGB(70, 190, 90),
	Parent = lobby,
})
corner(giftBtn, 16)
stroke(giftBtn, 3)
bouncy(giftBtn)
local giftText = new("TextLabel", { Text = "🎁", BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 6), Size = UDim2.new(1, -16, 1, -12), Parent = giftBtn })
local giftsWin, giftsBody = window("🎁 Подарки", Color3.fromRGB(230, 90, 110), 560, 440)
local giftGrid = Instance.new("UIGridLayout")
giftGrid.CellSize = UDim2.fromOffset(118, 96)
giftGrid.CellPadding = UDim2.fromOffset(10, 10)
giftGrid.SortOrder = Enum.SortOrder.LayoutOrder
giftGrid.Parent = giftsBody
local giftCells: { { btn: TextButton, status: TextLabel, reward: TextLabel } } = {}
for i, g in Config.PLAYTIME_GIFTS do
	local cell = new("TextButton", { Text = "", LayoutOrder = i, BackgroundColor3 = Color3.fromRGB(225, 232, 248), ZIndex = 33, Parent = giftsBody })
	corner(cell, 14)
	stroke(cell, 2)
	local reward = (if g.coins then "💰 " .. g.coins else "") .. (if g.gems then (if g.coins then "\n" else "") .. "💎 " .. g.gems else "")
	local rewardLabel = new("TextLabel", { Text = reward, BackgroundTransparency = 1, Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 0, 52), TextColor3 = DARK, ZIndex = 34, Parent = cell })
	local st = new("TextLabel", { Text = "", Position = UDim2.new(0, 8, 1, -32), Size = UDim2.new(1, -16, 0, 26), BackgroundColor3 = Color3.fromRGB(150, 155, 170), ZIndex = 34, Parent = cell })
	corner(st, 8)
	cell.Activated:Connect(function()
		act("gift", i)
	end)
	giftCells[i] = { btn = cell, status = st, reward = rewardLabel }
end
giftBtn.Activated:Connect(function()
	open(giftsWin)
end)

------------------------------------------------------------------ Сундук в лобби (раз в 4 часа)
local chestLobby = new("TextButton", {
	Text = "",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 100),
	Size = UDim2.fromOffset(190, 46),
	BackgroundColor3 = Color3.fromRGB(255, 190, 60),
	Parent = lobby,
})
corner(chestLobby, 16)
stroke(chestLobby, 3)
bouncy(chestLobby)
local chestLobbyText = new("TextLabel", { Text = "", BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 5), Size = UDim2.new(1, -16, 1, -10), TextColor3 = DARK, Parent = chestLobby })
chestLobby.Activated:Connect(function()
	act("chest")
end)

------------------------------------------------------------------ Скретч-билет дня
local ticketWin, ticketBody = window("🎟 Билет дня", Color3.fromRGB(240, 130, 50), 560, 400)
new("TextLabel", { Text = "Сотри 3 карточки — награды твои!", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), TextColor3 = DARK, ZIndex = 32, Parent = ticketBody })
local ticketCards: { TextButton } = {}
local ticketResult: any = nil
for i = 1, 3 do
	local c = new("TextButton", {
		Text = "❄",
		Position = UDim2.new((i - 1) / 3, 6, 0, 40),
		Size = UDim2.new(1 / 3, -12, 0, 190),
		BackgroundColor3 = Color3.fromRGB(240, 190, 70),
		ZIndex = 33,
		Parent = ticketBody,
	})
	corner(c, 14)
	stroke(c, 3)
	bouncy(c)
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
		if r and c:GetAttribute("Open") ~= true then
			c:SetAttribute("Open", true)
			c.Text = r.rarity .. "\n" .. r.text
			c.TextColor3 = DARK
			c.BackgroundColor3 = if r.gem then Color3.fromRGB(150, 210, 255) else Color3.fromRGB(255, 240, 190)
		end
	end)
end
new("TextLabel", {
	Text = "Шансы: обычная 60% · необычная 25% · редкая 10% · эпическая 4% · легенда 1%",
	BackgroundTransparency = 1,
	Position = UDim2.new(0, 0, 1, -40),
	Size = UDim2.new(1, 0, 0, 30),
	TextColor3 = Color3.fromRGB(110, 120, 140),
	ZIndex = 32,
	Parent = ticketBody,
})

-- Обновление таймеров и бейджей
local ticketShown = false
local function refreshRewards()
	readRewards()
	-- монетные награды растут с уровнем — показываем реальные суммы
	local level = player:GetAttribute("Level") or 1
	for i, g in Config.PLAYTIME_GIFTS do
		giftCells[i].reward.Text = (if g.coins then "💰 " .. Config.rewardCoins(g.coins, level) else "")
			.. (if g.gems then (if g.coins then "\n" else "") .. "💎 " .. g.gems else "")
	end
	if not rewards then
		return
	end
	if tasksWin.Visible then
		drawTasks()
	else
		local ready = 0
		for _, t in rewards.tasks do
			if t.progress >= t.target and not t.claimed then
				ready += 1
			end
		end
		tasksBadge.Text = if ready > 0 then "!" .. ready else ""
		tasksBadge.Visible = ready > 0
	end
	-- билет дня показываем сам при заходе, если он доступен
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
		local left = g.min * 60 - elapsed
		if rewards.gifts[i] then
			cell.status.Text = "✔"
			cell.status.BackgroundColor3 = Color3.fromRGB(150, 155, 170)
		elseif left <= 0 then
			ready += 1
			cell.status.Text = "ЗАБРАТЬ"
			cell.status.BackgroundColor3 = Color3.fromRGB(70, 190, 90)
		else
			cell.status.Text = clock(left)
			cell.status.BackgroundColor3 = Color3.fromRGB(80, 150, 240)
			nextIn = if nextIn then math.min(nextIn, left) else left
		end
	end
	giftText.Text = if ready > 0 then "🎁 Забрать! (" .. ready .. ")" elseif nextIn then "🎁 " .. clock(nextIn) else "🎁 Всё собрано"
	giftBtn.BackgroundColor3 = if ready > 0 then Color3.fromRGB(70, 190, 90) else Color3.fromRGB(90, 110, 150)
	local chestLeft = rewards.chestAt - now
	chestLobbyText.Text = if chestLeft <= 0 then "🧰 Открыть сундук!" else "🧰 " .. clock(chestLeft)
	chestLobby.BackgroundColor3 = if chestLeft <= 0 then Color3.fromRGB(255, 190, 60) else Color3.fromRGB(200, 205, 220)
	resetLabel.Text = "Новые задания через " .. clock(rewards.resetAt - now)
end)

-- В заезде все окна закрываем
player:GetAttributeChangedSignal("InRun"):Connect(function()
	if player:GetAttribute("InRun") then
		closeAll()
	end
end)
