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
local coinsLabel = label({
	Text = "💰 0",
	TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.new(0, 16, 0, 12),
	Size = UDim2.new(0, 220, 0, 42),
})

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
	Size = UDim2.new(0, 560, 0, 110),
})
local rowLayout = Instance.new("UIListLayout")
rowLayout.FillDirection = Enum.FillDirection.Horizontal
rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
rowLayout.Padding = UDim.new(0, 10)
rowLayout.Parent = upgradesRow

local ICONS = { Launch = "🎯", Rocket = "🚀", Sled = "🛷" }
local upgradeButtons: { [string]: TextButton } = {}
for _, name in Config.UPGRADE_ORDER do
	local b = button("", Color3.fromRGB(60, 120, 220), {
		Parent = upgradesRow,
		Size = UDim2.new(0, 170, 1, 0),
		TextScaled = false,
		TextSize = 20,
		TextWrapped = true,
	})
	upgradeButtons[name] = b
end

-- Всплывашка определена ниже; магазин зовёт её через эту ссылку
local showToastLater = function(_text: string) end

------------------------------------------------------------------ магазин ватрушек
local shopBtn = button("🎨 Ватрушки", Color3.fromRGB(170, 80, 220), {
	Parent = lobby,
	AnchorPoint = Vector2.new(0, 0),
	Position = UDim2.new(0, 16, 0, 64),
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

local runCoins = label({
	Parent = runUi,
	Text = "",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 14),
	Size = UDim2.new(0, 300, 0, 40),
	TextColor3 = Color3.fromRGB(255, 220, 90),
})
local speedLabel = label({
	Parent = runUi,
	Text = "",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 20, 1, -20),
	Size = UDim2.new(0, 200, 0, 46),
	TextXAlignment = Enum.TextXAlignment.Left,
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

-- Топливо ракеты
local fuelBox = frame({
	Parent = runUi,
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -70, 1, -24),
	Size = UDim2.new(0, 220, 0, 22),
	BackgroundColor3 = Color3.fromRGB(40, 50, 70),
	BackgroundTransparency = 0.3,
})
corner(fuelBox, 11)
local fuelFill = frame({ Parent = fuelBox, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 140, 50) })
corner(fuelFill, 11)
label({
	Parent = fuelBox,
	Text = if game:GetService("UserInputService").TouchEnabled then "🚀 топливо" else "🚀 Shift / E",
	Size = UDim2.fromScale(1, 1),
	ZIndex = 2,
})

-- Шкала рогатки
local meterBox = frame({
	Parent = runUi,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -130),
	Size = UDim2.new(0, 420, 0, 34),
	BackgroundColor3 = Color3.fromRGB(230, 90, 80),
	Visible = false,
})
corner(meterBox, 17)
stroke(meterBox, 3)
local meterGrad = Instance.new("UIGradient")
meterGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(230, 80, 70)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(250, 200, 60)),
	ColorSequenceKeypoint.new(0.85, Color3.fromRGB(80, 210, 90)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 230, 90)),
})
meterGrad.Parent = meterBox
local needle = frame({
	Parent = meterBox,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0, 0.5),
	Size = UDim2.new(0, 8, 1, 16),
	BackgroundColor3 = WHITE,
})
corner(needle, 4)
stroke(needle)
local launchBtn = button("🚀 ЗАПУСК!", Color3.fromRGB(255, 120, 40), {
	Parent = meterBox,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 1, 14),
	Size = UDim2.new(0, 240, 0, 64),
	ZIndex = 3,
})
launchBtn.Activated:Connect(function()
	controller.RequestLaunch:Fire()
end)
local meterHint = label({
	Parent = meterBox,
	Text = "Жми ЗАПУСК (или пробел), когда стрелка в зелёной зоне!",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 0, -8),
	Size = UDim2.new(1.3, 0, 0, 30),
})

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

	coinsLabel.Text = "💰 " .. coins
	runUi.Visible = inRun

	levelTitle.Text = "Уровень " .. level .. " · " .. (player:GetAttribute("ThemeName") or "")
	local best = player:GetAttribute("LevelBest") or 0
	levelSub.Text = if best > 0 then "Лучший результат: " .. best .. "% — качайся и доедь до финиша!" else "Доедь до финиша 🏁"
	startBtn.Text = "▶ Поехали!"

	for _, name in Config.UPGRADE_ORDER do
		local b = upgradeButtons[name]
		local u = Config.UPGRADES[name]
		local lvl = player:GetAttribute(name .. "Level") or 0
		local effect = if name == "Launch"
			then string.format("сила %d", Config.launchSpeed(lvl))
			elseif name == "Rocket" then string.format("топливо %.1fс", Config.rocketFuel(lvl))
			else string.format("скольжение %d%%", math.floor((1 - Config.friction(lvl) / Config.friction(0)) * 100 + 0.5))
		if lvl >= u.MaxLevel then
			b.Text = ICONS[name] .. " " .. u.title .. "\nур. " .. lvl .. " · MAX\n" .. effect
			b.BackgroundColor3 = Color3.fromRGB(90, 90, 110)
		else
			local cost = Config.upgradeCost(name, lvl)
			b.Text = ICONS[name] .. " " .. u.title .. "\nур. " .. lvl .. " · " .. effect .. "\n💰 " .. cost
			b.BackgroundColor3 = if coins >= cost then Color3.fromRGB(60, 120, 220) else Color3.fromRGB(75, 85, 115)
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

for _, attr in { "Coins", "Level", "LevelBest", "InRun", "Loaded", "ThemeName", "LaunchLevel", "RocketLevel", "SledLevel", "Skin", "OwnedSkins" } do
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
	runCoins.Text = if c > 0 then "💰 +" .. c else ""
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
	needle.Position = UDim2.fromScale(state.Meter.Value, 0.5)
	speedLabel.Text = math.floor(state.Speed.Value * 1.1) .. " км/ч"
	local maxFuel = state.FuelMax.Value
	fuelFill.Size = UDim2.fromScale(if maxFuel > 0 then state.Fuel.Value / maxFuel else 0, 1)
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
		end
	end)
end

Remotes.RunEnded.OnClientEvent:Connect(function(r)
	local text
	if r.reason == "finish" then
		text = "🏁 Уровень " .. r.level .. " пройден!\n+" .. r.coins .. " 💰"
	else
		local head = if r.reason == "crash"
			then "💥 Врезался"
			elseif r.reason == "fell" then "Улетел с трассы!"
			elseif r.reason == "stopped" then "Остановился"
			else "Заезд окончен"
		text = head .. " на " .. r.percent .. "%\n+" .. r.coins .. " 💰" .. (if r.newBest then "  · 🏆 рекорд!" else "")
	end
	showToast(text, 3.5)
end)

controller:WaitForChild("TrickPopup").Event:Connect(function(text)
	showToast(text, 1)
end)
