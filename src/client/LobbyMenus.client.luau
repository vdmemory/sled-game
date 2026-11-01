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
trailsBadge.Text = "скоро"
trailsBadge.Visible = true
tasksBadge.Text = "скоро"
tasksBadge.Visible = true

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
sledsBtn.Activated:Connect(function()
	local was = shop.Visible
	closeAll()
	shop.Visible = not was
end)

------------------------------------------------------------------ Следы и Задания — скоро
local soonWin, soonBody = window("Скоро!", Color3.fromRGB(140, 100, 230), 420, 240)
local soonText = new("TextLabel", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), TextColor3 = DARK, ZIndex = 32, Parent = soonBody })
local soonTitle = soonWin:FindFirstChild("TextLabel", true) :: TextLabel
trailsBtn.Activated:Connect(function()
	soonTitle.Text = "✨ Следы"
	soonText.Text = "Цветные шлейфы за санками\nс бонусом к монетам —\nв следующем обновлении!"
	open(soonWin)
end)
tasksBtn.Activated:Connect(function()
	soonTitle.Text = "📋 Задания"
	soonText.Text = "Ежедневные задания с гемами\nи сундуком за все —\nв следующем обновлении!"
	open(soonWin)
end)

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

-- В заезде все окна закрываем
player:GetAttributeChangedSignal("InRun"):Connect(function()
	if player:GetAttribute("InRun") then
		closeAll()
	end
end)
