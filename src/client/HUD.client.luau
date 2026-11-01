-- Интерфейс в стиле мобильного оригинала (Sled Surfers): лобби (валюты, «УРОВЕНЬ N»,
-- «НАЖМИ, ЧТОБЫ ИГРАТЬ», карточки апгрейдов), экран рогатки, HUD заезда и итог «Ты получил».
-- Окна меню (задания, сани, следы, миры…) — в LobbyMenus. Общий стиль — Shared/UIKit.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UI = require(ReplicatedStorage.Shared:WaitForChild("UIKit"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local controller = script.Parent:WaitForChild("SledController")
local state = controller:WaitForChild("State")
local TOUCH = UserInputService.TouchEnabled
local C = UI.C

-- Анимацию нового тира рисует Reveal.client
local upgradeReveal = Instance.new("BindableEvent")
upgradeReveal.Name = "UpgradeReveal"
upgradeReveal.Parent = script

local gui = Instance.new("ScreenGui")
gui.Name = "HUD"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

-- Корень с масштабом: на маленьких экранах (телефон боком) всё уменьшается пропорционально
local root = UI.new("Frame", { Name = "Root", BackgroundTransparency = 1, Parent = gui })
local rootScale = Instance.new("UIScale")
rootScale.Parent = root
local function fitRoot()
	local vp = workspace.CurrentCamera.ViewportSize
	local s = math.clamp(math.min(vp.Y / 660, vp.X / 1000), 0.55, 1)
	rootScale.Scale = s
	root.Size = UDim2.fromScale(1 / s, 1 / s)
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitRoot)
fitRoot()

------------------------------------------------------------------ лобби
local lobby = UI.new("Frame", { Name = "Lobby", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = root })

-- Старт: дойти по мостику до края (сервер сажает в сани) или нажать «НАЖМИ, ЧТОБЫ ИГРАТЬ».
-- Тап по всему экрану не используем — иначе на телефоне нельзя ходить по лобби.

-- Валюты сверху по центру
local currencyRow = UI.new("Frame", {
	Name = "Currencies",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 10),
	Size = UDim2.fromOffset(330, 40),
	Parent = root,
})
local coinsLabel = UI.currency(currencyRow, "💰", { Position = UDim2.fromOffset(20, 0), Size = UDim2.fromOffset(140, 40) })
local gemsLabel = UI.currency(currencyRow, "💎", { Position = UDim2.fromOffset(190, 0), Size = UDim2.fromOffset(140, 40) })

-- «УРОВЕНЬ N» + мир
local levelTitle = UI.text({
	Text = "УРОВЕНЬ 1",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 56),
	Size = UDim2.fromOffset(420, 46),
	Outline = 3,
	Parent = lobby,
})
local worldLine = UI.text({
	Text = "",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 100),
	Size = UDim2.fromOffset(420, 24),
	Parent = lobby,
})

-- «НАЖМИ, ЧТОБЫ ИГРАТЬ» — пульсирует над карточками
local tapText = UI.new("TextButton", {
	Text = "",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -262),
	Size = UDim2.fromOffset(520, 44),
	Parent = lobby,
})
local tapLabel = UI.text({ Text = "НАЖМИ, ЧТОБЫ ИГРАТЬ  ▶", Size = UDim2.fromScale(1, 1), Outline = 3, Parent = tapText })
local tapScale = Instance.new("UIScale")
tapScale.Parent = tapText
TweenService:Create(tapScale, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.08 }):Play()

-- Карточки апгрейдов: Рогатка / Сани / Доход внизу, Ракета — справа (как в оригинале)
local CARD_STYLE = {
	Launch = { title = "РОГАТКА", pip = Color3.fromRGB(235, 70, 70), btn = { Color3.fromRGB(150, 60, 80), Color3.fromRGB(105, 35, 55) }, art = "🎯" },
	Sled = { title = "САНИ", pip = Color3.fromRGB(80, 190, 250), btn = { Color3.fromRGB(60, 110, 170), Color3.fromRGB(35, 75, 125) }, art = "🛷" },
	Income = { title = "ДОХОД", pip = Color3.fromRGB(250, 190, 50), btn = { Color3.fromRGB(150, 120, 70), Color3.fromRGB(105, 80, 45) }, art = "💰" },
	Rocket = { title = "РАКЕТА", pip = Color3.fromRGB(110, 200, 255), btn = { Color3.fromRGB(110, 190, 255), Color3.fromRGB(50, 130, 230) }, art = "🚀" },
}
local notice: (string, number?) -> ()
type Card = { root: TextButton, badge: TextLabel, pips: { Frame }, price: TextLabel, priceBtn: Frame, effect: TextLabel, style: any }
local cards: { [string]: Card } = {}

local cardsRow = UI.new("Frame", {
	Name = "Upgrades",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -14),
	Size = UDim2.fromOffset(3 * 156 + 2 * 14, 240),
	Parent = lobby,
})
local cl = Instance.new("UIListLayout")
cl.FillDirection = Enum.FillDirection.Horizontal
cl.Padding = UDim.new(0, 14)
cl.SortOrder = Enum.SortOrder.LayoutOrder
cl.Parent = cardsRow

local function makeCard(name: string, parent: Instance, size: UDim2, order: number, compact: boolean): Card
	local u = Config.UPGRADES[name]
	local st = CARD_STYLE[name]
	local card = UI.new("TextButton", { Text = "", AutoButtonColor = false, LayoutOrder = order, Size = size, BackgroundTransparency = 0, Parent = parent })
	if compact then
		UI.grad(card, Color3.fromRGB(120, 190, 255), Color3.fromRGB(60, 130, 230))
	else
		UI.grad(card, Color3.fromRGB(52, 70, 112), Color3.fromRGB(32, 46, 80))
	end
	UI.corner(card, 14)
	UI.stroke(card, 3)
	UI.bounce(card)
	if not compact then
		UI.text({ Text = st.title, Position = UDim2.fromOffset(10, 5), Size = UDim2.new(1, -54, 0, 24), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2, Parent = card })
	end
	-- бейдж уровня (тёмный кружок в углу)
	local badgeBg = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(38, 38), BackgroundColor3 = C.navy, BackgroundTransparency = 0, ZIndex = 5, Parent = card })
	UI.corner(badgeBg, 1000)
	UI.stroke(badgeBg, 2.5, C.white)
	local badge = UI.text({ Text = "0", Position = UDim2.fromOffset(5, 6), Size = UDim2.new(1, -10, 1, -12), ZIndex = 6, Parent = badgeBg })
	-- картинка
	local artTop = if compact then 8 else 32
	local artH = if compact then 76 else 112
	local art = UI.new("Frame", { Position = UDim2.fromOffset(8, artTop), Size = UDim2.new(1, -16, 0, artH), BackgroundTransparency = 0, ZIndex = 2, Parent = card })
	UI.grad(art, Color3.fromRGB(250, 252, 255), Color3.fromRGB(205, 225, 245))
	UI.corner(art, 10)
	UI.text({ Text = st.art, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromScale(0.62, 0.7), Outline = 0, ZIndex = 3, Parent = art })
	local effect = UI.text({ Text = "", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -6, 1, -2), Size = UDim2.new(0.8, 0, 0, if compact then 18 else 28), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4, Parent = art })
	-- деления тира
	local pips = {}
	if not compact then
		for i = 1, Config.TIER_SIZE do
			local pip = UI.new("Frame", {
				Position = UDim2.new((i - 1) / Config.TIER_SIZE, 10 - (i - 1) * 20 / Config.TIER_SIZE, 0, artTop + artH + 8),
				Size = UDim2.new(1 / Config.TIER_SIZE, -4, 0, 14),
				BackgroundColor3 = st.pip,
				BackgroundTransparency = 0,
				ZIndex = 2,
				Parent = card,
			})
			UI.corner(pip, 3)
			pips[i] = pip
		end
	end
	-- кнопка «УЛУЧШИТЬ / цена»
	local btnH = if compact then 54 else 58
	local priceBtn = UI.new("Frame", { Position = UDim2.new(0, 8, 1, -(btnH + 8)), Size = UDim2.new(1, -16, 0, btnH), BackgroundTransparency = 0, ZIndex = 2, Parent = card })
	local g = UI.grad(priceBtn, st.btn[1], st.btn[2])
	g.Name = "Fill"
	UI.corner(priceBtn, 10)
	UI.stroke(priceBtn, 2)
	UI.text({ Text = "УЛУЧШИТЬ", Position = UDim2.new(0, 6, 0, 4), Size = UDim2.new(1, -12, 0.45, -2), ZIndex = 3, Parent = priceBtn })
	local price = UI.text({ Text = "", Position = UDim2.new(0, 6, 0.48, 0), Size = UDim2.new(1, -12, 0.48, -4), ZIndex = 3, Parent = priceBtn })
	local c = { root = card, badge = badge, pips = pips, price = price, priceBtn = priceBtn, effect = effect, style = st }
	cards[name] = c
	card.Activated:Connect(function()
		local ok, msg = Remotes.BuyUpgrade:InvokeServer(name)
		if not ok then
			notice(msg or "Ошибка")
		elseif msg then
			notice("✨ ПОЛУЧЕНО: " .. string.upper(msg) .. "!", 2.5)
		end
	end)
	return c
end

-- Уведомление сверху (тёмная плашка, как «DAILY TASK COMPLETED!»)
local noticeBox = UI.new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 132),
	Size = UDim2.fromOffset(440, 54),
	BackgroundColor3 = C.navy,
	BackgroundTransparency = 0.15,
	Visible = false,
	ZIndex = 50,
	Parent = root,
})
UI.corner(noticeBox, 16)
UI.stroke(noticeBox, 2, C.white, 0.4)
local noticeText = UI.text({ Text = "", Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 1, -16), TextColor3 = Color3.fromRGB(255, 225, 90), ZIndex = 51, Parent = noticeBox })
UI.outline(noticeText, 2)
local noticeN = 0
notice = function(text: string, seconds: number?)
	noticeN += 1
	local my = noticeN
	noticeText.Text = text
	noticeBox.Visible = true
	UI.pop(noticeBox)
	task.delay(seconds or 1.6, function()
		if noticeN == my then
			noticeBox.Visible = false
		end
	end)
end
if not noticeBox:FindFirstChildOfClass("UIScale") then
	Instance.new("UIScale").Parent = noticeBox
end

for i, name in { "Launch", "Sled", "Income" } do
	makeCard(name, cardsRow, UDim2.fromOffset(156, 240), i, false)
end
-- Ракета — отдельная голубая карточка справа (как UPGRADE 💎1 в оригинале)
local rocketCard = makeCard("Rocket", lobby, UDim2.fromOffset(130, 170), 0, true)
rocketCard.root.AnchorPoint = Vector2.new(0, 1)
rocketCard.root.Position = UDim2.new(0.5, 3 * 156 / 2 + 14 + 18, 1, -14)

------------------------------------------------------------------ заезд
local runUi = UI.new("Frame", { Name = "Run", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = root })

-- Монеты и гемы за заезд — слева сверху (под кнопками Roblox)
local runCoins = UI.currency(runUi, "💰", { Position = UDim2.fromOffset(34, 64), Size = UDim2.fromOffset(130, 38) })
local gemPill = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(34, 110), Size = UDim2.fromOffset(100, 34), Visible = false, Parent = runUi })
local runGems = UI.currency(gemPill, "💎", { Size = UDim2.fromScale(1, 1) })

-- Дистанция крупно сверху, рекорд и комбо под ней
local distLabel = UI.text({ Text = "", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(300, 56), Outline = 3, Parent = runUi })
local bestLabel = UI.text({ Text = "", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 62), Size = UDim2.fromOffset(240, 24), TextColor3 = Color3.fromRGB(255, 225, 110), Parent = runUi })
UI.outline(bestLabel, 2)
local comboLabel = UI.text({ Text = "", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 90), Size = UDim2.fromOffset(300, 34), TextColor3 = Color3.fromRGB(255, 200, 70), Rotation = -4, Parent = runUi })
UI.outline(comboLabel, 2.5)

-- Перезапуск: тёмный кружок справа сверху
local restartBtn = UI.new("TextButton", {
	Text = "",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -18, 0, 62),
	Size = UDim2.fromOffset(60, 60),
	BackgroundColor3 = C.navy,
	BackgroundTransparency = 0.35,
	Parent = runUi,
})
UI.corner(restartBtn, 1000)
UI.stroke(restartBtn, 3, C.white, 0.3)
UI.text({ Text = "🔄", Position = UDim2.fromScale(0.18, 0.18), Size = UDim2.fromScale(0.64, 0.64), Outline = 0, Parent = restartBtn })
UI.bounce(restartBtn)
restartBtn.Activated:Connect(function()
	Remotes.Restart:FireServer()
end)

-- Спидометр: тёмный круг с голубой дугой
local SPEED_MAX = 160
local dial = UI.new("Frame", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 22, 1, -108),
	Size = UDim2.fromOffset(136, 136),
	BackgroundColor3 = C.navy,
	BackgroundTransparency = 0.45,
	Parent = runUi,
})
UI.corner(dial, 1000)
local dialSegments: { Frame } = {}
local SEGMENTS = 26
for i = 1, SEGMENTS do
	local a = math.rad(135 + (i - 1) / (SEGMENTS - 1) * 270)
	local seg = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, math.cos(a) * 58, 0.5, math.sin(a) * 58),
		Size = UDim2.fromOffset(7, 15),
		Rotation = math.deg(a) + 90,
		BackgroundColor3 = Color3.fromRGB(70, 90, 130),
		BackgroundTransparency = 0,
		Parent = dial,
	})
	UI.corner(seg, 3)
	dialSegments[i] = seg
end
local speedLabel = UI.text({ Text = "0", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.44), Size = UDim2.fromOffset(84, 46), Parent = dial })
UI.text({ Text = "км/ч", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.62), Size = UDim2.fromOffset(60, 20), Parent = dial })

-- Кнопка ракеты под спидометром (оранжевый кружок с огнём) + топливо дугой-полоской
local rocketBtn = UI.new("TextButton", {
	Text = "",
	AutoButtonColor = false,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 1, 8),
	Size = UDim2.fromOffset(78, 78),
	BackgroundTransparency = 0,
	Parent = dial,
})
local rocketFill = UI.grad(rocketBtn, UI.KIND.orange[1], UI.KIND.orange[2])
UI.corner(rocketBtn, 1000)
UI.stroke(rocketBtn, 3, C.white)
UI.text({ Text = "🔥", Position = UDim2.fromScale(0.18, 0.1), Size = UDim2.fromScale(0.64, 0.58), Outline = 0, Parent = rocketBtn })
local fuelTrack = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(0.7, 0, 0, 8), BackgroundColor3 = C.track, BackgroundTransparency = 0, Parent = rocketBtn })
UI.corner(fuelTrack, 1000)
local fuelFill = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 230, 90), BackgroundTransparency = 0, Parent = fuelTrack })
UI.corner(fuelFill, 1000)
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

-- Прогресс справа: тонкая тёмная полоса, голубая заливка, флажок, ромбы гемов, BEST
local progress = UI.new("Frame", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -40, 0.52, 0),
	Size = UDim2.fromOffset(16, 300),
	BackgroundColor3 = C.track,
	BackgroundTransparency = 0.2,
	Parent = runUi,
})
UI.corner(progress, 1000)
UI.stroke(progress, 2, C.white, 0.3)
local progressFill = UI.new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), BackgroundTransparency = 0, Parent = progress })
UI.grad(progressFill, Color3.fromRGB(120, 230, 255), Color3.fromRGB(40, 170, 240))
UI.corner(progressFill, 1000)
UI.text({ Text = "🏁", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -2), Size = UDim2.fromOffset(32, 32), Outline = 0, Parent = progress })
for _, f in Config.GEMS_ON_TRACK do
	UI.text({ Text = "💎", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 1 - f), Size = UDim2.fromOffset(24, 24), Outline = 0, ZIndex = 3, Parent = progress })
end
local bestMark = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = C.white, BackgroundTransparency = 0, Visible = false, ZIndex = 3, Parent = progress })
UI.corner(bestMark, 1000)
UI.text({ Text = "BEST", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, 4, 0.5, 0), Size = UDim2.fromOffset(40, 16), Parent = bestMark })
local pctBubble = UI.text({ Text = "0%", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(0, -6, 1, 0), Size = UDim2.fromOffset(56, 24), TextXAlignment = Enum.TextXAlignment.Right, Parent = progress })

-- Магнит и всплывающие «+N»
local magnetIcon = UI.text({ Text = "🧲", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.6, 0), Size = UDim2.fromOffset(90, 44), Visible = false, Parent = runUi })
local function floater(text: string, color: Color3)
	local f = UI.text({
		Text = text,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, math.random(-50, 50), 0.56, 0),
		Size = UDim2.fromOffset(130, 38),
		TextColor3 = color,
		ZIndex = 6,
		Parent = runUi,
	})
	local s = UI.outline(f, 2)
	TweenService:Create(f, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { Position = f.Position - UDim2.fromOffset(0, 90), TextTransparency = 1 }):Play()
	TweenService:Create(s, TweenInfo.new(0.8), { Transparency = 1 }):Play()
	task.delay(0.85, function()
		f:Destroy()
	end)
end
local lastRunCoins = 0

-- Экран рогатки: полукруглая шкала сверху с процентом, подсказка, синяя кнопка НАЗАД
local gauge = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 40), Size = UDim2.fromOffset(200, 110), BackgroundTransparency = 1, Visible = false, Parent = runUi })
local gaugeSegs: { Frame } = {}
local GSEG = 24
for i = 1, GSEG do
	local a = math.rad(180 + (i - 1) / (GSEG - 1) * 180)
	local seg = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, math.cos(a) * 88, 1, math.sin(a) * 88 - 6),
		Size = UDim2.fromOffset(9, 26),
		Rotation = math.deg(a) + 90,
		BackgroundColor3 = Color3.fromRGB(200, 225, 245),
		BackgroundTransparency = 0.3,
		Parent = gauge,
	})
	UI.corner(seg, 3)
	gaugeSegs[i] = seg
end
local gaugePct = UI.text({ Text = "0%", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.fromOffset(110, 40), Parent = gauge })
local gaugeHint = UI.text({ Text = "", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 10), Size = UDim2.fromOffset(460, 30), Parent = gauge })
local backBtn = UI.button("blue", "НАЗАД", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -26),
	Size = UDim2.fromOffset(200, 64),
	Visible = false,
	Parent = runUi,
})
backBtn.Activated:Connect(function()
	Remotes.Back:FireServer()
end)

-- Плавающий джойстик-кольцо (телефон)
local stick = controller:WaitForChild("Stick")
local ring = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(150, 150), BackgroundTransparency = 1, Visible = false, Parent = gui })
UI.corner(ring, 1000)
UI.stroke(ring, 4, Color3.fromRGB(150, 210, 255), 0.25)
local knob = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(46, 46), BackgroundColor3 = Color3.fromRGB(120, 200, 255), BackgroundTransparency = 0.15, Parent = ring })
UI.corner(knob, 1000)

-- Подсказка управления
local controlsHint = UI.text({
	Text = if TOUCH then "Веди пальцем — руль · 🔥 — ракета · 🔄 в прыжке — флип" else "A/D — руль · Shift — ракета · Пробел в прыжке — флип",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -16),
	Size = UDim2.fromOffset(560, 24),
	TextTransparency = 0.2,
	Visible = false,
	Parent = runUi,
})

-- Крупные всплывашки в заезде («Удар!», «Флип!», «НОВЫЙ РЕКОРД!»)
local toast = UI.text({
	Text = "",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.36, 0),
	Size = UDim2.fromOffset(560, 110),
	TextColor3 = Color3.fromRGB(255, 225, 80),
	Visible = false,
	ZIndex = 8,
	Parent = root,
})
UI.outline(toast, 3)
local toastScale = Instance.new("UIScale")
toastScale.Parent = toast
local toastToken = 0
local function showToast(text: string, seconds: number)
	toastToken += 1
	local my = toastToken
	toast.Text = text
	toast.Visible = true
	toastScale.Scale = 0.6
	TweenService:Create(toastScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(seconds, function()
		if toastToken == my then
			toast.Visible = false
		end
	end)
end

------------------------------------------------------------------ обновление лобби
local function refresh()
	local coins = player:GetAttribute("Coins") or 0
	local gems = player:GetAttribute("Gems") or 0
	local level = player:GetAttribute("Level") or 1
	local inRun = player:GetAttribute("InRun") == true

	coinsLabel.Text = UI.money(coins)
	gemsLabel.Text = UI.money(gems)
	runUi.Visible = inRun
	currencyRow.Visible = not inRun

	levelTitle.Text = "УРОВЕНЬ " .. level
	local best = player:GetAttribute("LevelBest") or 0
	worldLine.Text = (player:GetAttribute("ThemeName") or "") .. " · " .. ((level - 1) % Config.LEVELS_PER_WORLD + 1) .. "/" .. Config.LEVELS_PER_WORLD
		.. (if best > 0 then "  ·  рекорд " .. best .. "%" else "")

	for name, c in cards do
		local u = Config.UPGRADES[name]
		local lvl = player:GetAttribute(name .. "Level") or 0
		c.effect.Text = if name == "Launch"
			then "сила " .. Config.launchSpeed(lvl)
			elseif name == "Rocket" then string.format("%.1fс", Config.rocketFuel(lvl))
			elseif name == "Income" then string.format("x%.2f", Config.incomeMult(lvl)):gsub("%.?0+$", "")
			else "+" .. math.floor((1 - Config.friction(lvl) / Config.friction(0)) * 100 + 0.5) .. "%"
		c.badge.Text = tostring(lvl)
		local inTier = if lvl > 0 and lvl % Config.TIER_SIZE == 0 then Config.TIER_SIZE else lvl % Config.TIER_SIZE
		for i, pip in c.pips do
			pip.BackgroundColor3 = if i <= inTier then c.style.pip else Color3.fromRGB(70, 85, 120)
		end
		local fill = c.priceBtn:FindFirstChild("Fill") :: UIGradient
		if lvl >= u.MaxLevel then
			c.price.Text = "MAX"
			fill.Color = ColorSequence.new(UI.KIND.grey[1], UI.KIND.grey[2])
		else
			local cost, currency = Config.upgradePrice(name, lvl)
			local have = if currency == "Gems" then gems else coins
			c.price.Text = (if currency == "Gems" then "💎 " else "💰 ") .. UI.money(cost)
			if have < cost then
				fill.Color = ColorSequence.new(UI.KIND.grey[1], UI.KIND.grey[2])
			elseif currency == "Gems" and name ~= "Rocket" then
				fill.Color = ColorSequence.new(UI.KIND.blue[1], UI.KIND.blue[2])
			else
				fill.Color = ColorSequence.new(c.style.btn[1], c.style.btn[2])
			end
		end
	end
	bestMark.Visible = best > 0
	bestMark.Position = UDim2.fromScale(0.5, 1 - best / 100)
end
for _, attr in { "Coins", "Gems", "Level", "LevelBest", "InRun", "Loaded", "ThemeName", "LaunchLevel", "RocketLevel", "SledLevel", "IncomeLevel" } do
	player:GetAttributeChangedSignal(attr):Connect(refresh)
end
refresh()

------------------------------------------------------------------ обновление заезда
local recordShown = false
local function updateRun()
	local L = player:GetAttribute("LevelLength") or 1
	local dist = player:GetAttribute("RunDistance") or 0
	local p = math.clamp(dist / L, 0, 1)
	progressFill.Size = UDim2.fromScale(1, p)
	pctBubble.Text = math.floor(p * 100) .. "%"
	pctBubble.Position = UDim2.new(0, -6, 1 - p, 0)
	local c = player:GetAttribute("RunCoins") or 0
	runCoins.Text = UI.money(c)
	if c > lastRunCoins and player:GetAttribute("InRun") then
		floater("+" .. (c - lastRunCoins), Color3.fromRGB(255, 220, 80))
	end
	lastRunCoins = c
	local g = player:GetAttribute("RunGems") or 0
	gemPill.Visible = g > 0
	runGems.Text = tostring(g)
	local combo = player:GetAttribute("Combo") or 0
	local mult = Config.comboMult(combo)
	comboLabel.Text = if combo >= 3 then "КОМБО x" .. combo .. (if mult > 1 then "  · монеты x" .. mult else "") else ""
	distLabel.Text = dist .. " м"
	local best = math.floor((player:GetAttribute("LevelBest") or 0) / 100 * L)
	bestLabel.Text = if best > 0 then "★ " .. best .. " м" else ""
	if not player:GetAttribute("InRun") then
		recordShown = false
	elseif not recordShown and best > 0 and dist > best and player:GetAttribute("Launched") then
		recordShown = true
		showToast("🏆 НОВЫЙ РЕКОРД!", 1.6)
		controller.Sfx:Fire("record")
	end
end
for _, attr in { "RunDistance", "RunCoins", "RunGems", "Combo", "InRun" } do
	player:GetAttributeChangedSignal(attr):Connect(updateRun)
end
Remotes.TaskDone.OnClientEvent:Connect(function(text)
	task.delay(3.8, function() -- после карточки итога
		notice("📋 ЗАДАНИЕ ВЫПОЛНЕНО! " .. text, 2.8)
		controller.Sfx:Fire("reward")
	end)
end)
player:GetAttributeChangedSignal("Finished"):Connect(function()
	if player:GetAttribute("Finished") then
		showToast("🏁 ФИНИШ!", 2)
		controller.Sfx:Fire("finish")
	end
end)
controller:WaitForChild("TrickPopup").Event:Connect(function(text)
	showToast(text, 1)
end)

------------------------------------------------------------------ кадр
local result: Frame -- карточка итога (создаётся ниже)
RunService.RenderStepped:Connect(function()
	-- лобби видно, только когда игрок не в санках (после финиша есть пауза до респауна)
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
	-- и пока открыт итог заезда («Ты получил») — как в оригинале, сначала CONTINUE
	lobby.Visible = player:GetAttribute("Loaded") == true and player:GetAttribute("InRun") ~= true and not seated and not result.Visible
	currencyRow.Visible = lobby.Visible

	local awaiting = state.AwaitingLaunch.Value
	local launched = player:GetAttribute("Launched") == true
	gauge.Visible = awaiting
	distLabel.Visible = not awaiting
	bestLabel.Visible = not awaiting
	backBtn.Visible = awaiting
	controlsHint.Visible = not awaiting and launched
	local pull = state.Meter.Value
	local lit = math.floor(pull * GSEG + 0.5)
	for i, seg in gaugeSegs do
		seg.BackgroundColor3 = if i <= lit then C.cyan else Color3.fromRGB(200, 225, 245)
		seg.BackgroundTransparency = if i <= lit then 0 else 0.35
	end
	gaugePct.Text = math.floor(pull * 100 + 0.5) .. "%"
	gaugeHint.Text = if pull > 0.15 then "ОТПУСТИ!" elseif TOUCH then "Потяни вниз и отпусти 👇" else "Зажми мышь и тяни вниз (или держи Пробел)"

	local kmh = math.floor(state.Speed.Value * 1.1)
	speedLabel.Text = tostring(kmh)
	local litS = math.floor(math.clamp(kmh / SPEED_MAX, 0, 1) * SEGMENTS + 0.5)
	for i, seg in dialSegments do
		seg.BackgroundColor3 = if i > litS then Color3.fromRGB(70, 90, 130) elseif i > SEGMENTS * 0.8 then Color3.fromRGB(255, 130, 60) else C.cyan
	end
	dial.Visible = not awaiting
	local maxFuel = state.FuelMax.Value
	fuelFill.Size = UDim2.fromScale(if maxFuel > 0 then state.Fuel.Value / maxFuel else 0, 1)
	local k = if state.RocketOn.Value then UI.KIND.yellow elseif state.Fuel.Value > 0 then UI.KIND.orange else UI.KIND.grey
	rocketFill.Color = ColorSequence.new(k[1], k[2])
	restartBtn.Visible = launched
	local ml = state.MagnetLeft.Value
	magnetIcon.Visible = ml > 0
	if ml > 0 then
		magnetIcon.Text = "🧲 " .. math.ceil(ml)
	end
	ring.Visible = launched and stick.On.Value
	if ring.Visible then
		local o = stick.Origin.Value
		ring.Position = UDim2.fromOffset(o.X, o.Y)
		knob.Position = UDim2.new(0.5, stick.X.Value * 53, 0.5, 0)
	end
end)

------------------------------------------------------------------ старт заезда
local starting = false
local function start()
	if starting then
		return
	end
	-- если открыто окно меню — тап закрывает его, а не запускает
	for _, w in gui:GetChildren() do
		if w:IsA("Frame") and string.sub(w.Name, 1, 6) == "Panel_" and w.Visible then
			return
		end
	end
	starting = true
	Remotes.StartRun:FireServer()
	task.delay(1, function()
		starting = false
	end)
end
tapText.Activated:Connect(start)

------------------------------------------------------------------ итог заезда («Ты получил»)
result = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.56), Size = UDim2.fromOffset(380, 300), BackgroundTransparency = 1, Visible = false, ZIndex = 20, Parent = root })
local resultScale = Instance.new("UIScale")
resultScale.Parent = result
local resultTitle = UI.text({ Text = "", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -6), Size = UDim2.fromOffset(460, 52), Outline = 3, ZIndex = 22, Parent = result })
local bestBanner = UI.text({ Text = "", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -58), Size = UDim2.fromOffset(420, 40), TextColor3 = Color3.fromRGB(255, 215, 60), Rotation = -3, ZIndex = 22, Parent = result })
UI.outline(bestBanner, 3)
local sheet = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 220), BackgroundColor3 = Color3.fromRGB(95, 106, 126), BackgroundTransparency = 0.12, ZIndex = 20, Parent = result })
UI.corner(sheet, 20)
UI.text({ Text = "Ты получил:", Position = UDim2.fromOffset(20, 12), Size = UDim2.new(1, -40, 0, 32), ZIndex = 21, Parent = sheet })
local rCoins = UI.text({ Text = "", Position = UDim2.fromOffset(20, 52), Size = UDim2.new(1, -40, 0, 40), ZIndex = 21, Parent = sheet })
local rBonus = UI.text({ Text = "", Position = UDim2.fromOffset(20, 98), Size = UDim2.new(1, -40, 0, 30), ZIndex = 21, Parent = sheet })
local rGems = UI.text({ Text = "", Position = UDim2.fromOffset(20, 134), Size = UDim2.new(1, -40, 0, 30), ZIndex = 21, Parent = sheet })
local rDist = UI.text({ Text = "", Position = UDim2.fromOffset(20, 176), Size = UDim2.new(1, -40, 0, 28), TextColor3 = Color3.fromRGB(215, 235, 255), ZIndex = 21, Parent = sheet })
UI.outline(rDist, 2)
local continueBtn = UI.button("blue", "ПРОДОЛЖИТЬ", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 236),
	Size = UDim2.fromOffset(230, 64),
	ZIndex = 22,
	Parent = result,
})
local resultToken = 0
local function hideResult()
	result.Visible = false
end
continueBtn.Activated:Connect(hideResult)

Remotes.RunEnded.OnClientEvent:Connect(function(r)
	resultToken += 1
	local my = resultToken
	local finished = r.reason == "finish"
	resultTitle.Text = if finished
		then "УРОВЕНЬ " .. r.level .. " ПРОЙДЕН!"
		elseif r.reason == "crash" then "ВРЕЗАЛСЯ!"
		elseif r.reason == "fell" then "УЛЕТЕЛ С ТРАССЫ!"
		elseif r.reason == "stopped" then "ОСТАНОВИЛСЯ"
		else "ЗАЕЗД ОКОНЧЕН"
	bestBanner.Text = if finished then "🎉 ФИНИШ!" elseif r.newBest then "🏆 НОВЫЙ РЕКОРД!" else ""
	rCoins.Text = UI.money(r.coins) .. " 💰" .. (if (r.mult or 1) > 1 then "  (x" .. r.mult .. ")" else "")
	rBonus.Text = "Бонус за полёт и трюки: +" .. math.floor(r.bonus or 0) .. " 💰"
	rGems.Text = "+" .. (r.gems or 0) .. " 💎"
	rDist.Text = (r.distance or 0) .. " м  ·  " .. r.percent .. "% уровня"
	result.Visible = true
	resultScale.Scale = 0.7
	TweenService:Create(resultScale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(7, function()
		if resultToken == my then
			hideResult()
		end
	end)
end)
player:GetAttributeChangedSignal("InRun"):Connect(function()
	if player:GetAttribute("InRun") then
		hideResult()
	end
end)
