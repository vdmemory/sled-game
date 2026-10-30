-- Интерфейс: кнопка старта, дистанция, монеты, апгрейды, итоги заезда.
-- Весь UI создаётся кодом — потом можно заменить на свой ScreenGui из Studio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local controller = script.Parent:WaitForChild("SledController")

local gui = Instance.new("ScreenGui")
gui.Name = "HUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = player:WaitForChild("PlayerGui")

local FONT = Enum.Font.FredokaOne

local function round(inst: GuiObject, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = inst
end

local function label(props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.4
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
	b.TextColor3 = Color3.new(1, 1, 1)
	b.BackgroundColor3 = color
	b.AutoButtonColor = true
	for k, v in props do
		(b :: any)[k] = v
	end
	round(b, 12)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = b
	b.Parent = props.Parent or gui
	return b
end

-- Монеты (всегда видны)
local coinsLabel = label({
	Name = "Coins",
	Text = "🪙 0",
	TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.new(0, 16, 0, 12),
	Size = UDim2.new(0, 220, 0, 40),
})

-- Дистанция (во время заезда)
local distLabel = label({
	Name = "Distance",
	Text = "0 м",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 12),
	Size = UDim2.new(0, 360, 0, 56),
	Visible = false,
})

-- Кнопка старта
local startBtn = button("▶ Поехали!", Color3.fromRGB(40, 170, 90), {
	Name = "Start",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -24),
	Size = UDim2.new(0, 260, 0, 64),
})

-- Панель апгрейдов
local panel = Instance.new("Frame")
panel.Name = "Upgrades"
panel.AnchorPoint = Vector2.new(1, 0.5)
panel.Position = UDim2.new(1, -12, 0.5, 0)
panel.Size = UDim2.new(0, 230, 0, 150)
panel.BackgroundColor3 = Color3.fromRGB(20, 40, 70)
panel.BackgroundTransparency = 0.25
round(panel, 14)
panel.Parent = gui
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 8)
list.HorizontalAlignment = Enum.HorizontalAlignment.Center
list.VerticalAlignment = Enum.VerticalAlignment.Center
list.Parent = panel

local upgradeButtons: { [string]: TextButton } = {}
local UPGRADE_NAMES = { Speed = "Скорость", Control = "Управление" }
for _, name in { "Speed", "Control" } do
	upgradeButtons[name] = button("", Color3.fromRGB(60, 120, 220), {
		Name = name,
		Size = UDim2.new(1, -16, 0, 60),
		Parent = panel,
	})
end

-- Всплывающее сообщение (итоги, трюки, ошибки)
local toast = label({
	Name = "Toast",
	Text = "",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.35, 0),
	Size = UDim2.new(0, 420, 0, 120),
	TextColor3 = Color3.fromRGB(255, 230, 90),
	Visible = false,
})
local toastToken = 0
local function showToast(text: string, seconds: number)
	toastToken += 1
	local my = toastToken
	toast.Text = text
	toast.Visible = true
	toast.Size = UDim2.new(0, 300, 0, 86)
	TweenService:Create(toast, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = UDim2.new(0, 420, 0, 120) })
		:Play()
	task.delay(seconds, function()
		if toastToken == my then
			toast.Visible = false
		end
	end)
end

------------------------------------------------------------------ Обновление
local function refresh()
	local coins = player:GetAttribute("Coins") or 0
	local inRun = player:GetAttribute("InRun") == true
	local loaded = player:GetAttribute("Loaded") == true

	coinsLabel.Text = "🪙 " .. coins .. "   🏆 " .. (player:GetAttribute("Best") or 0) .. " м"
	distLabel.Visible = inRun
	startBtn.Visible = loaded and not inRun
	panel.Visible = loaded and not inRun

	for name, btn in upgradeButtons do
		local level = player:GetAttribute(name .. "Level") or 0
		local max = Config.UPGRADES[name].MaxLevel
		if level >= max then
			btn.Text = UPGRADE_NAMES[name] .. " MAX"
			btn.BackgroundColor3 = Color3.fromRGB(90, 90, 110)
		else
			local cost = Config.upgradeCost(name, level)
			btn.Text = UPGRADE_NAMES[name] .. " " .. (level + 1) .. " · " .. cost .. "🪙"
			btn.BackgroundColor3 = if coins >= cost then Color3.fromRGB(60, 120, 220) else Color3.fromRGB(70, 80, 110)
		end
	end
end

for _, attr in { "Coins", "Best", "InRun", "Loaded", "SpeedLevel", "ControlLevel" } do
	player:GetAttributeChangedSignal(attr):Connect(refresh)
end
local function updateRun()
	local coins = player:GetAttribute("RunCoins") or 0
	distLabel.Text = (player:GetAttribute("RunDistance") or 0) .. " м" .. (if coins > 0 then "  🪙" .. coins else "")
end
player:GetAttributeChangedSignal("RunDistance"):Connect(updateRun)
player:GetAttributeChangedSignal("RunCoins"):Connect(updateRun)
refresh()

------------------------------------------------------------------ Действия
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

for name, btn in upgradeButtons do
	btn.Activated:Connect(function()
		local ok, msg = Remotes.BuyUpgrade:InvokeServer(name)
		if not ok then
			showToast(msg or "Ошибка", 1.2)
		end
	end)
end

Remotes.RunEnded.OnClientEvent:Connect(function(result)
	local lines = {}
	if result.reason == "crash" then
		table.insert(lines, "💥 Врезался!")
	elseif result.reason == "fell" then
		table.insert(lines, "Улетел с трассы!")
	end
	table.insert(lines, result.distance .. " м  ·  +" .. result.coins .. "🪙")
	if result.newRecord then
		table.insert(lines, "🏆 Новый рекорд!")
	end
	showToast(table.concat(lines, "\n"), 3)
end)

controller:WaitForChild("TrickPopup").Event:Connect(function(flips)
	showToast((if flips > 1 then "Флип x" .. flips else "Флип") .. "! Буст ⚡", 1.2)
end)
