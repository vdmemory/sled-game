-- Интерфейс: лобби (старт уровня, апгрейды), шкала рогатки, прогресс до финиша,
-- топливо ракеты, всплывашки и итоги заезда. Всё создаётся кодом.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local controller = script.Parent:WaitForChild("SledController")
local state = controller:WaitForChild("State")

local gui = Instance.new("ScreenGui")
gui.Name = "HUD"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local FONT = Enum.Font.FredokaOne
local WHITE = Color3.new(1, 1, 1)

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
	s.Parent = inst
end
local function frame(props: { [string]: any }): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in props do
		(f :: any)[k] = v
	end
	f.Parent = props.Parent or gui
	return f
end
local function label(props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextColor3 = WHITE
	l.TextStrokeTransparency = 0.5
	l.TextScaled = true
	for k, v in props do
		(l :: any)[k] = v
	end
	l.Parent = props.Parent or gui
	return l
end
local function button(text: string, color: Color3, props: { [string]: any }): TextButton
	local b = Instance.new("TextButton")
	b.Text = text
	b.Font = FONT
	b.TextScaled = true
	b.TextColor3 = WHITE
	b.BackgroundColor3 = color
	b.AutoButtonColor = true
	for k, v in props do
		(b :: any)[k] = v
	end
	corner(b, 14)
	stroke(b, 3)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = b
	b.Parent = props.Parent or gui
	return b
end

------------------------------------------------------------------ всегда видно
-- Валюты слева сверху (сразу правее кнопок Roblox)
local currencyBar = frame({
	BackgroundTransparency = 1,
	Position = UDim2.new(0, 16, 0, 60),
	Size = UDim2.new(0, 380, 0, 40),
})
local function pill(x: number, color: Color3): TextLabel
	local f = frame({ Parent = currencyBar, Position = UDim2.new(0, x, 0, 0), Size = UDim2.new(0, 170, 1, 0), BackgroundColor3 = color, BackgroundTransparency = 0.15 })
	corner(f, 20)
	stroke(f, 2)
	return label({ Parent = f, Text = "", Position = UDim2.new(0, 12, 0, 4), Size = UDim2.new(1, -24, 1, -8), TextXAlignment = Enum.TextXAlignment.Left })
end
local coinsLabel = pill(0, Color3.fromRGB(220, 160, 30))
local gemsLabel = pill(180, Color3.fromRGB(70, 140, 235))

------------------------------------------------------------------ лобби
local lobby = frame({ Name = "Lobby", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })

local levelTitle = label({
	Parent = lobby,
	Text = "Уровень 1",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 14),
	Size = UDim2.new(0, 420, 0, 52),
})
local levelSub = label({
	Parent = lobby,
	Text = "",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 64),
	Size = UDim2.new(0, 420, 0, 28),
	TextColor3 = Color3.fromRGB(220, 235, 255),
})

local startBtn = button("▶ Поехали!", Color3.fromRGB(40, 175, 90), {
	Parent = lobby,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -24),
	Size = UDim2.new(0, 280, 0, 70),
})

local upgradesRow = frame({
	Parent = lobby,
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -106),
	Size = UDim2.new(0, 600, 0, 168),
})
local rowLayout = Instance.new("UIListLayout")
rowLayout.FillDirection = Enum.FillDirection.Horizontal
rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
rowLayout.Padding = UDim.new(0, 10)
rowLayout.Parent = upgradesRow

-- Карточки апгрейдов как в оригинале/референсе: шапка, иконка, бейдж уровня, деления тира, цена
type Card = { root: TextButton, badge: TextLabel, pips: { Frame }, price: TextLabel, priceBox: Frame, effect: TextLabel }
local upgradeButtons: { [string]: TextButton } = {}
local cards: { [string]: Card } = {}
for _, name in Config.UPGRADE_ORDER do
	local u = Config.UPGRADES[name]
	local root = Instance.new("TextButton")
	root.Text = ""
	root.AutoButtonColor = true
	root.Size = UDim2.new(0, 140, 1, 0)
	root.BackgroundColor3 = u.color
	root.Parent = upgradesRow
	corner(root, 16)
	stroke(root, 3)
	label({ Parent = root, Text = u.title, Position = UDim2.new(0, 8, 0, 4), Size = UDim2.new(1, -40, 0, 24), TextXAlignment = Enum.TextXAlignment.Left })
	local body = frame({ Parent = root, Position = UDim2.new(0, 6, 0, 30), Size = UDim2.new(1, -12, 0, 76), BackgroundColor3 = Color3.fromRGB(250, 245, 240) })
	corner(body, 12)
	label({ Parent = body, Text = u.icon, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.new(0, 50, 0, 44) })
	local effect = label({ Parent = body, Text = "", Position = UDim2.new(0, 4, 0, 50), Size = UDim2.new(1, -8, 0, 20), TextColor3 = Color3.fromRGB(70, 80, 100), TextStrokeTransparency = 1 })
	local badgeBg = frame({ Parent = root, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 4, 0, -6), Size = UDim2.new(0, 34, 0, 34), BackgroundColor3 = WHITE })
	corner(badgeBg, 17)
	stroke(badgeBg, 2)
	local badge = label({ Parent = badgeBg, Text = "0", Size = UDim2.fromScale(1, 1), TextColor3 = Color3.fromRGB(30, 40, 60), TextStrokeTransparency = 1 })
	local pips = {}
	for i = 1, Config.TIER_SIZE do
		local pip = frame({
			Parent = root,
			Position = UDim2.new((i - 1) / Config.TIER_SIZE, 8 - (i - 1) * 16 / Config.TIER_SIZE, 0, 110),
			Size = UDim2.new(1 / Config.TIER_SIZE, -4, 0, 8),
			BackgroundColor3 = WHITE,
		})
		corner(pip, 3)
		pips[i] = pip
	end
	local priceBox = frame({ Parent = root, Position = UDim2.new(0, 6, 1, -46), Size = UDim2.new(1, -12, 0, 40), BackgroundColor3 = Color3.fromRGB(70, 190, 90) })
	corner(priceBox, 12)
	stroke(priceBox, 2)
	local price = label({ Parent = priceBox, Text = "", Position = UDim2.new(0, 6, 0, 4), Size = UDim2.new(1, -12, 1, -8) })
	upgradeButtons[name] = root
	cards[name] = { root = root, badge = badge, pips = pips, price = price, priceBox = priceBox, effect = effect }
end

-- Всплывашка определена ниже; магазин зовёт её через эту ссылку
local showToastLater = function(_text: string) end

------------------------------------------------------------------ магазин ватрушек
local shopBtn = button("🎨 Ватрушки", Color3.fromRGB(170, 80, 220), {
	Parent = lobby,
	AnchorPoint = Vector2.new(0, 0),
	Position = UDim2.new(0, 16, 0, 112),
	Size = UDim2.new(0, 170, 0, 48),
})

local shop = frame({
	Name = "Shop",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0, 620, 0, 400),
	BackgroundColor3 = Color3.fromRGB(25, 45, 80),
	BackgroundTransparency = 0.05,
	Visible = false,
	ZIndex = 10,
})
corner(shop, 18)
stroke(shop, 3)
local shopScale = Instance.new("UIScale")
shopScale.Parent = shop
local function fitShop()
	local vp = workspace.CurrentCamera.ViewportSize
	shopScale.Scale = math.min(1, (vp.X - 32) / 620, (vp.Y - 40) / 400)
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitShop)
fitShop()

label({ Parent = shop, Text = "🎨 Ватрушки", Position = UDim2.new(0, 20, 0, 12), Size = UDim2.new(0, 300, 0, 40), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11 })
local closeBtn = button("X", Color3.fromRGB(200, 70, 70), {
	Parent = shop,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 12),
	Size = UDim2.new(0, 44, 0, 44),
	ZIndex = 11,
})
local grid = Instance.new("ScrollingFrame")
grid.BackgroundTransparency = 1
grid.BorderSizePixel = 0
grid.Position = UDim2.new(0, 16, 0, 64)
grid.Size = UDim2.new(1, -32, 1, -80)
grid.ScrollBarThickness = 6
grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
grid.CanvasSize = UDim2.new()
grid.ZIndex = 11
grid.Parent = shop
local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0, 136, 0, 150)
gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
gridLayout.Parent = grid

local skinCards: { [string]: { card: TextButton, status: TextLabel } } = {}
for _, skin in Config.SKINS do
	local card = Instance.new("TextButton")
	card.Text = ""
	card.AutoButtonColor = true
	card.BackgroundColor3 = Color3.fromRGB(45, 70, 115)
	card.ZIndex = 12
	card.Parent = grid
	corner(card, 14)
	-- Превью: круг-ватрушка с бортиком
	local disc = frame({
		Parent = card,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.new(0, 64, 0, 64),
		BackgroundColor3 = skin.tube,
		ZIndex = 13,
	})
	corner(disc, 32)
	local rim = Instance.new("UIStroke")
	rim.Thickness = 7
	rim.Color = skin.rim
	rim.Parent = disc
	label({ Parent = card, Text = skin.name, Position = UDim2.new(0, 6, 0, 84), Size = UDim2.new(1, -12, 0, 26), ZIndex = 13 })
	local status = label({ Parent = card, Text = "", Position = UDim2.new(0, 6, 0, 114), Size = UDim2.new(1, -12, 0, 26), ZIndex = 13 })
	skinCards[skin.id] = { card = card, status = status }

	card.Activated:Connect(function()
		local ok, msg = Remotes.SkinAction:InvokeServer(skin.id)
		if not ok then
			showToastLater(msg or "Ошибка")
		end
	end)
end

shopBtn.Activated:Connect(function()
	shop.Visible = not shop.Visible
end)
closeBtn.Activated:Connect(function()
	shop.Visible = false
end)

------------------------------------------------------------------ заезд
local runUi = frame({ Name = "Run", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false })

-- Монеты за заезд — плашка слева сверху (под кнопками Roblox)
local coinPill = frame({
	Parent = runUi,
	Position = UDim2.new(0, 16, 0, 64),
	Size = UDim2.new(0, 150, 0, 40),
	BackgroundColor3 = Color3.fromRGB(35, 50, 90),
	BackgroundTransparency = 0.25,
})
corner(coinPill, 20)
local runCoins = label({
	Parent = coinPill,
	Text = "💰 0",
	Position = UDim2.new(0, 10, 0, 4),
	Size = UDim2.new(1, -20, 1, -8),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(255, 220, 90),
})
-- Пройденная дистанция крупно сверху по центру + рекорд под ней, как в оригинале
local distLabel = label({
	Parent = runUi,
	Text = "",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 14),
	Size = UDim2.new(0, 260, 0, 52),
})
local bestLabel = label({
	Parent = runUi,
	Text = "",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 64),
	Size = UDim2.new(0, 220, 0, 24),
	TextColor3 = Color3.fromRGB(255, 225, 120),
})

-- Круглый спидометр слева снизу: дуга из сегментов + цифра
local SPEED_MAX = 160 -- км/ч на полной дуге
local dial = frame({
	Parent = runUi,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 18, 1, -104),
	Size = UDim2.new(0, 130, 0, 130),
	BackgroundColor3 = Color3.fromRGB(30, 45, 80),
	BackgroundTransparency = 0.35,
})
corner(dial, 65)
local dialSegments: { Frame } = {}
local SEGMENTS = 22
for i = 1, SEGMENTS do
	-- дуга 240° от левого-нижнего к правому-нижнему
	local a = math.rad(150 + (i - 1) / (SEGMENTS - 1) * 240)
	local seg = frame({
		Parent = dial,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, math.cos(a) * 54, 0.5, math.sin(a) * 54),
		Size = UDim2.new(0, 6, 0, 13),
		Rotation = math.deg(a) + 90,
		BackgroundColor3 = Color3.fromRGB(80, 100, 140),
	})
	corner(seg, 3)
	dialSegments[i] = seg
end
local speedLabel = label({
	Parent = dial,
	Text = "0",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.45),
	Size = UDim2.new(0, 80, 0, 44),
})
label({
	Parent = dial,
	Text = "км/ч",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.64),
	Size = UDim2.new(0, 60, 0, 18),
	TextTransparency = 0.2,
})

-- Прогресс до финиша (вертикальная шкала справа)
local progress = frame({
	Parent = runUi,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -24, 0.5, 0),
	Size = UDim2.new(0, 26, 0, 320),
	BackgroundColor3 = Color3.fromRGB(230, 240, 255),
	BackgroundTransparency = 0.2,
})
corner(progress, 13)
stroke(progress)
local progressFill = frame({
	Parent = progress,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.fromScale(1, 0),
	BackgroundColor3 = Color3.fromRGB(70, 170, 255),
})
corner(progressFill, 13)
local bestMark = frame({
	Parent = progress,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Size = UDim2.new(1, 12, 0, 4),
	BackgroundColor3 = Color3.fromRGB(255, 200, 40),
	Visible = false,
})
label({ Parent = progress, Text = "🏁", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -4), Size = UDim2.new(0, 36, 0, 36) })
local pctBubble = label({
	Parent = progress,
	Text = "0%",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(0, -8, 1, 0),
	Size = UDim2.new(0, 70, 0, 30),
	TextXAlignment = Enum.TextXAlignment.Right,
})

-- Кнопка ракеты под спидометром (держи — летишь) + столбик топлива рядом
local rocketBtn = Instance.new("TextButton")
rocketBtn.Text = ""
rocketBtn.AutoButtonColor = false
rocketBtn.AnchorPoint = Vector2.new(0.5, 0)
rocketBtn.Position = UDim2.new(0.5, 0, 1, 8)
rocketBtn.Size = UDim2.new(0, 72, 0, 72)
rocketBtn.BackgroundColor3 = Color3.fromRGB(255, 120, 40)
rocketBtn.Parent = dial
corner(rocketBtn, 36)
stroke(rocketBtn, 3)
label({ Parent = rocketBtn, Text = "🚀", Position = UDim2.fromScale(0.18, 0.12), Size = UDim2.fromScale(0.64, 0.5) })
label({
	Parent = rocketBtn,
	Text = if game:GetService("UserInputService").TouchEnabled then "ракета" else "Shift",
	Position = UDim2.fromScale(0.1, 0.6),
	Size = UDim2.fromScale(0.8, 0.26),
})
local rocketInput = controller:WaitForChild("RocketInput")
rocketBtn.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		rocketInput:Fire(true)
	end
end)
rocketBtn.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		rocketInput:Fire(false)
	end
end)
local fuelBox = frame({
	Parent = dial,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(1, 12, 1, 80),
	Size = UDim2.new(0, 16, 0, 150),
	BackgroundColor3 = Color3.fromRGB(30, 45, 80),
	BackgroundTransparency = 0.25,
})
corner(fuelBox, 8)
stroke(fuelBox)
local fuelFill = frame({
	Parent = fuelBox,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(255, 160, 50),
})
corner(fuelFill, 8)

-- ⟳ Заново (справа сверху, как в оригинале) и BACK у рогатки
local restartBtn = button("⟳", Color3.fromRGB(70, 90, 140), {
	Parent = runUi,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 64),
	Size = UDim2.new(0, 56, 0, 56),
})
restartBtn.Activated:Connect(function()
	Remotes.Restart:FireServer()
end)
local backBtn = button("НАЗАД", Color3.fromRGB(60, 130, 230), {
	Parent = runUi,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -24),
	Size = UDim2.new(0, 170, 0, 56),
	Visible = false,
})
backBtn.Activated:Connect(function()
	Remotes.Back:FireServer()
end)

-- Плавающий джойстик-кольцо для телефона (появляется под пальцем)
local stick = controller:WaitForChild("Stick")
local ring = frame({
	Parent = runUi,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Size = UDim2.new(0, 150, 0, 150),
	BackgroundTransparency = 1,
	Visible = false,
})
corner(ring, 75)
local ringStroke = Instance.new("UIStroke")
ringStroke.Thickness = 4
ringStroke.Color = Color3.fromRGB(120, 200, 255)
ringStroke.Transparency = 0.3
ringStroke.Parent = ring
local knob = frame({
	Parent = ring,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0, 44, 0, 44),
	BackgroundColor3 = Color3.fromRGB(120, 200, 255),
	BackgroundTransparency = 0.2,
})
corner(knob, 22)

-- Шкала натяжения рогатки (как в оригинале: тянешь вниз — полоса наполняется, отпускаешь — выстрел)
local meterBox = frame({
	Parent = runUi,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 70),
	Size = UDim2.new(0, 340, 0, 30),
	BackgroundColor3 = Color3.fromRGB(35, 50, 90),
	Visible = false,
})
corner(meterBox, 15)
stroke(meterBox, 3)
local meterFill = frame({ Parent = meterBox, Size = UDim2.fromScale(0, 1), BackgroundColor3 = WHITE })
corner(meterFill, 15)
local meterGrad = Instance.new("UIGradient")
meterGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 70)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(255, 140, 50)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(240, 70, 60)),
})
meterGrad.Parent = meterFill
local meterPct = label({ Parent = meterBox, Text = "0%", Size = UDim2.fromScale(1, 1), ZIndex = 2 })
local meterHint = label({
	Parent = meterBox,
	Text = "",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 1, 10),
	Size = UDim2.new(1.4, 0, 0, 34),
	TextSize = 26,
})
local TOUCH = game:GetService("UserInputService").TouchEnabled

-- Подсказка управления
local controlsHint = label({
	Parent = runUi,
	Text = if game:GetService("UserInputService").TouchEnabled
		then "Веди пальцем ←→ — руль · 🚀 — ракета · 🔄 в прыжке — флип"
		else "A/D — руль · Shift — ракета · Пробел в прыжке — флип",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -60),
	Size = UDim2.new(0, 520, 0, 26),
	TextTransparency = 0.15,
	Visible = false,
})

------------------------------------------------------------------ всплывашки
local toast = label({
	Text = "",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.42, 0),
	Size = UDim2.new(0, 520, 0, 130),
	TextColor3 = Color3.fromRGB(255, 230, 90),
	Visible = false,
	ZIndex = 5,
})
local toastToken = 0
local function showToast(text: string, seconds: number)
	toastToken += 1
	local my = toastToken
	toast.Text = text
	toast.Visible = true
	toast.Size = UDim2.new(0, 360, 0, 90)
	TweenService:Create(toast, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = UDim2.new(0, 520, 0, 130) }):Play()
	task.delay(seconds, function()
		if toastToken == my then
			toast.Visible = false
		end
	end)
end
showToastLater = function(text: string)
	showToast(text, 1.2)
end

------------------------------------------------------------------ обновление
local function refresh()
	local coins = player:GetAttribute("Coins") or 0
	local level = player:GetAttribute("Level") or 1
	local inRun = player:GetAttribute("InRun") == true
	local loaded = player:GetAttribute("Loaded") == true

	local gems = player:GetAttribute("Gems") or 0
	coinsLabel.Text = "💰 " .. coins
	gemsLabel.Text = "💎 " .. gems
	runUi.Visible = inRun
	currencyBar.Visible = not inRun

	levelTitle.Text = "Уровень " .. level .. " · " .. (player:GetAttribute("ThemeName") or "")
	local best = player:GetAttribute("LevelBest") or 0
	levelSub.Text = if best > 0 then "Лучший результат: " .. best .. "% — качайся и доедь до финиша!" else "Доедь до финиша 🏁"
	startBtn.Text = "▶ Поехали!"

	for _, name in Config.UPGRADE_ORDER do
		local c = cards[name]
		local u = Config.UPGRADES[name]
		local lvl = player:GetAttribute(name .. "Level") or 0
		c.effect.Text = if name == "Launch"
			then string.format("сила %d", Config.launchSpeed(lvl))
			elseif name == "Rocket" then string.format("топливо %.1fс", Config.rocketFuel(lvl))
			elseif name == "Income" then string.format("x%.2f", Config.incomeMult(lvl))
			else string.format("скольжение %d%%", math.floor((1 - Config.friction(lvl) / Config.friction(0)) * 100 + 0.5))
		c.badge.Text = tostring(lvl)
		-- деления: сколько уровней набрано в текущем тире
		local inTier = if lvl > 0 and lvl % Config.TIER_SIZE == 0 then Config.TIER_SIZE else lvl % Config.TIER_SIZE
		for i, pip in c.pips do
			pip.BackgroundColor3 = if i <= inTier then WHITE else Color3.fromRGB(40, 40, 60)
			pip.BackgroundTransparency = if i <= inTier then 0 else 0.5
		end
		if lvl >= u.MaxLevel then
			c.price.Text = "MAX"
			c.priceBox.BackgroundColor3 = Color3.fromRGB(110, 110, 130)
		else
			local cost, currency = Config.upgradePrice(name, lvl)
			local have = if currency == "Gems" then gems else coins
			c.price.Text = (if currency == "Gems" then "💎 " else "💰 ") .. cost
			c.priceBox.BackgroundColor3 = if have < cost
				then Color3.fromRGB(120, 125, 140)
				elseif currency == "Gems" then Color3.fromRGB(80, 150, 240)
				else Color3.fromRGB(70, 190, 90)
		end
	end

	bestMark.Visible = best > 0
	bestMark.Position = UDim2.fromScale(0.5, 1 - best / 100)

	-- Магазин ватрушек
	local equipped = player:GetAttribute("Skin") or "classic"
	local owned = {}
	for id in string.gmatch(player:GetAttribute("OwnedSkins") or "classic", "[^,]+") do
		owned[id] = true
	end
	for _, skin in Config.SKINS do
		local c = skinCards[skin.id]
		if skin.id == equipped then
			c.status.Text = "✅ Надето"
			c.card.BackgroundColor3 = Color3.fromRGB(40, 140, 90)
		elseif owned[skin.id] then
			c.status.Text = "Надеть"
			c.card.BackgroundColor3 = Color3.fromRGB(45, 70, 115)
		else
			c.status.Text = "💰 " .. skin.price
			c.card.BackgroundColor3 = if coins >= skin.price then Color3.fromRGB(45, 70, 115) else Color3.fromRGB(55, 60, 80)
		end
	end
	if inRun then
		shop.Visible = false
	end
end

for _, attr in { "Coins", "Gems", "Level", "LevelBest", "InRun", "Loaded", "ThemeName", "LaunchLevel", "RocketLevel", "SledLevel", "IncomeLevel", "Skin", "OwnedSkins" } do
	player:GetAttributeChangedSignal(attr):Connect(refresh)
end
refresh()

local function updateRun()
	local L = player:GetAttribute("LevelLength") or 1
	local p = math.clamp((player:GetAttribute("RunDistance") or 0) / L, 0, 1)
	progressFill.Size = UDim2.fromScale(1, p)
	pctBubble.Text = math.floor(p * 100) .. "%"
	pctBubble.Position = UDim2.new(0, -8, 1 - p, 0)
	local c = player:GetAttribute("RunCoins") or 0
	runCoins.Text = "💰 " .. c
	distLabel.Text = (player:GetAttribute("RunDistance") or 0) .. " м"
	local best = math.floor((player:GetAttribute("LevelBest") or 0) / 100 * L)
	bestLabel.Text = if best > 0 then "★ " .. best .. " м" else ""
end
player:GetAttributeChangedSignal("RunDistance"):Connect(updateRun)
player:GetAttributeChangedSignal("RunCoins"):Connect(updateRun)
player:GetAttributeChangedSignal("InRun"):Connect(updateRun)

-- Кадр: шкала рогатки, скорость, топливо
RunService.RenderStepped:Connect(function()
	-- Лобби показываем, только когда игрок уже не сидит в санках (после финиша есть пауза до респауна)
	local seated = false
	local sleds = workspace:FindFirstChild("Sleds")
	if sleds then
		for _, s in sleds:GetChildren() do
			if s:GetAttribute("Owner") == player.UserId then
				seated = true
				break
			end
		end
	end
	lobby.Visible = player:GetAttribute("Loaded") == true and player:GetAttribute("InRun") ~= true and not seated

	local awaiting = state.AwaitingLaunch.Value
	meterBox.Visible = awaiting
	controlsHint.Visible = not awaiting and player:GetAttribute("Launched") == true
	local pull = state.Meter.Value
	meterFill.Size = UDim2.fromScale(pull, 1)
	meterPct.Text = math.floor(pull * 100 + 0.5) .. "%"
	meterHint.Text = if pull > 0.15
		then "ОТПУСТИ!"
		elseif TOUCH then "Потяни вниз и отпусти 👇"
		else "Зажми мышь и тяни вниз (или держи Пробел)"
	local launched = player:GetAttribute("Launched") == true
	local kmh = math.floor(state.Speed.Value * 1.1)
	speedLabel.Text = tostring(kmh)
	local lit = math.floor(math.clamp(kmh / SPEED_MAX, 0, 1) * SEGMENTS + 0.5)
	for i, seg in dialSegments do
		seg.BackgroundColor3 = if i > lit
			then Color3.fromRGB(80, 100, 140)
			elseif i > SEGMENTS * 0.75 then Color3.fromRGB(255, 120, 60)
			else Color3.fromRGB(110, 220, 255)
	end
	dial.Visible = not awaiting
	local maxFuel = state.FuelMax.Value
	fuelFill.Size = UDim2.fromScale(1, if maxFuel > 0 then state.Fuel.Value / maxFuel else 0)
	rocketBtn.BackgroundColor3 = if state.RocketOn.Value
		then Color3.fromRGB(255, 190, 60)
		elseif state.Fuel.Value > 0 then Color3.fromRGB(255, 120, 40)
		else Color3.fromRGB(110, 110, 130)
	restartBtn.Visible = launched
	backBtn.Visible = awaiting
	ring.Visible = launched and stick.On.Value
	if ring.Visible then
		local o = stick.Origin.Value
		ring.Position = UDim2.fromOffset(o.X, o.Y)
		knob.Position = UDim2.new(0.5, stick.X.Value * 53, 0.5, 0)
	end
end)

------------------------------------------------------------------ действия
local starting = false
startBtn.Activated:Connect(function()
	if starting then
		return
	end
	starting = true
	Remotes.StartRun:FireServer()
	task.delay(1, function()
		starting = false
	end)
end)

for name, b in upgradeButtons do
	b.Activated:Connect(function()
		local ok, msg = Remotes.BuyUpgrade:InvokeServer(name)
		if not ok then
			showToast(msg or "Ошибка", 1.2)
		elseif msg then
			showToast("✨ ПОЛУЧЕНО:\n" .. string.upper(msg) .. "!", 2.5)
		end
	end)
end

-- Карточка итога заезда (как «You got» в оригинале)
local card = frame({
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0, 400, 0, 330),
	BackgroundColor3 = Color3.fromRGB(245, 248, 255),
	Visible = false,
	ZIndex = 20,
})
corner(card, 22)
stroke(card, 4)
local cardHead = frame({ Parent = card, Size = UDim2.new(1, 0, 0, 62), BackgroundColor3 = Color3.fromRGB(60, 130, 230), ZIndex = 21 })
corner(cardHead, 22)
local cardTitle = label({ Parent = cardHead, Text = "", Position = UDim2.new(0, 16, 0, 8), Size = UDim2.new(1, -32, 1, -16), ZIndex = 22 })
local DARK = Color3.fromRGB(30, 45, 80)
local cardDist = label({ Parent = card, Text = "", Position = UDim2.new(0, 20, 0, 74), Size = UDim2.new(1, -40, 0, 46), TextColor3 = DARK, TextStrokeTransparency = 1, ZIndex = 21 })
local cardBar = frame({ Parent = card, Position = UDim2.new(0, 40, 0, 128), Size = UDim2.new(1, -80, 0, 14), BackgroundColor3 = Color3.fromRGB(200, 210, 230), ZIndex = 21 })
corner(cardBar, 7)
local cardBarFill = frame({ Parent = cardBar, Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(70, 170, 255), ZIndex = 22 })
corner(cardBarFill, 7)
local cardCoins = frame({ Parent = card, Position = UDim2.new(0, 40, 0, 156), Size = UDim2.new(1, -80, 0, 54), BackgroundColor3 = Color3.fromRGB(255, 236, 170), ZIndex = 21 })
corner(cardCoins, 14)
local cardCoinsText = label({ Parent = cardCoins, Text = "", Position = UDim2.new(0, 10, 0, 6), Size = UDim2.new(1, -20, 1, -12), TextColor3 = Color3.fromRGB(150, 95, 10), TextStrokeTransparency = 1, ZIndex = 22 })
local cardBonus = label({ Parent = card, Text = "", Position = UDim2.new(0, 20, 0, 216), Size = UDim2.new(1, -40, 0, 24), TextColor3 = Color3.fromRGB(90, 105, 140), TextStrokeTransparency = 1, ZIndex = 21 })
local cardBtn = button("Забрать", Color3.fromRGB(70, 190, 90), {
	Parent = card,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -16),
	Size = UDim2.new(0, 200, 0, 58),
	ZIndex = 22,
})
local bestBanner = label({
	Parent = card,
	Text = "🏆 НОВЫЙ РЕКОРД!",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 0, -8),
	Size = UDim2.new(0, 360, 0, 48),
	TextColor3 = Color3.fromRGB(255, 215, 60),
	Rotation = -3,
	Visible = false,
	ZIndex = 23,
})
local cardToken = 0
local function hideCard()
	card.Visible = false
end
cardBtn.Activated:Connect(hideCard)

Remotes.RunEnded.OnClientEvent:Connect(function(r)
	cardToken += 1
	local my = cardToken
	local finished = r.reason == "finish"
	cardTitle.Text = if finished
		then "🏁 Уровень " .. r.level .. " пройден!"
		elseif r.reason == "crash" then "💥 Врезался!"
		elseif r.reason == "fell" then "Улетел с трассы!"
		elseif r.reason == "stopped" then "Остановился"
		else "Заезд окончен"
	cardHead.BackgroundColor3 = if finished then Color3.fromRGB(70, 190, 90) elseif r.reason == "crash" then Color3.fromRGB(230, 90, 80) else Color3.fromRGB(60, 130, 230)
	cardDist.Text = (r.distance or 0) .. " м  ·  " .. r.percent .. "%"
	cardBarFill.Size = UDim2.fromScale(0, 1)
	TweenService:Create(cardBarFill, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(r.percent / 100, 1) }):Play()
	cardCoinsText.Text = "💰 +" .. r.coins .. (if (r.mult or 1) > 1 then "  (x" .. r.mult .. ")" else "") .. (if (r.gems or 0) > 0 then "   💎 +" .. r.gems else "")
	cardBonus.Text = if (r.bonus or 0) > 0 then "из них за монеты, полёт и трюки: +" .. r.bonus else ""
	bestBanner.Visible = r.newBest == true or finished
	bestBanner.Text = if finished then "🎉 ФИНИШ!" else "🏆 НОВЫЙ РЕКОРД!"
	card.Size = UDim2.new(0, 300, 0, 250)
	card.Visible = true
	TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Size = UDim2.new(0, 400, 0, 330) }):Play()
	task.delay(7, function()
		if cardToken == my then
			hideCard()
		end
	end)
end)
player:GetAttributeChangedSignal("InRun"):Connect(function()
	if player:GetAttribute("InRun") then
		hideCard()
	end
end)

controller:WaitForChild("TrickPopup").Event:Connect(function(text)
	showToast(text, 1)
end)
