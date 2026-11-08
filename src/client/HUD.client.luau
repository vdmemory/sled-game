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
local UIFx = require(ReplicatedStorage.Shared:WaitForChild("UIFx"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local controller = script.Parent:WaitForChild("SledController")
local state = controller:WaitForChild("State")
local TOUCH = UserInputService.TouchEnabled
local C = UI.C
local L = UI.L -- раскладка лобби (Shared/UILayout)

-- Анимацию нового тира рисует Reveal.client
local upgradeReveal = Instance.new("BindableEvent")
upgradeReveal.Name = "UpgradeReveal"
upgradeReveal.Parent = script
-- Награда валютой: (kind "coin"|"gem", amount, fromGuiOrPos). amount < 0 (или nil) — «держать»
-- счётчик на старом значении (перед запросом к серверу), 0 — отпустить, > 0 — монеты летят к
-- пилюле, счётчик тикает до нового значения. Без события валюта обновляется мгновенно.
local currencyGain = Instance.new("BindableEvent")
currencyGain.Name = "CurrencyGain"
currencyGain.Parent = script

local gui = Instance.new("ScreenGui")
gui.Name = "HUD"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

-- Корень с масштабом: на маленьких экранах (телефон боком) всё уменьшается пропорционально.
-- Масштаб — от области ScreenGui под топбаром Roblox (UI.fitScale, расчёт в Shared/UILayout)
local root = UI.new("Frame", { Name = "Root", BackgroundTransparency = 1, Parent = gui })
UI.fitScale(root, gui)

-- Сообщения («Не хватает монет», «✔ Сани выбраны», «ЗАДАНИЕ ВЫПОЛНЕНО!») — свой ScreenGui выше
-- HUD и окон (#38): видны поверх открытого окна, масштаб — как у корня HUD, место — под полоской
-- сессии (UILayout.toastLobby), в заезде — под подсказкой рогатки (toastRun). LobbyMenus шлёт
-- текст через BindableEvent Toast (text, seconds?).
local toastGui = Instance.new("ScreenGui")
toastGui.Name = "Toasts"
toastGui.ResetOnSpawn = false
toastGui.DisplayOrder = 20 -- выше HUD (0) и Tutorial; ниже DevPanel (30)
toastGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
toastGui.Parent = gui.Parent
local toastRoot = UI.new("Frame", { Name = "Root", BackgroundTransparency = 1, Parent = toastGui })
UI.fitScale(toastRoot, toastGui)
local toastEvent = Instance.new("BindableEvent")
toastEvent.Name = "Toast"
toastEvent.Parent = script

------------------------------------------------------------------ лобби
local lobby = UI.new("Frame", { Name = "Lobby", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = root })

-- Старт: дойти по мостику до края (сервер сажает в сани) или нажать «НАЖМИ, ЧТОБЫ ИГРАТЬ».
-- Тап по всему экрану не используем — иначе на телефоне нельзя ходить по лобби.

-- Верхняя строка (#46): монеты слева, «УРОВЕНЬ N» по центру, гемы справа — одной строкой
local currencyRow = UI.new("Frame", UI.at(L.currencies, {
	Name = "Currencies",
	BackgroundTransparency = 1,
	Parent = root,
}))
-- якорь по центру: бамп при прилёте монет растёт из середины пилюли
local CUR_W, CUR_H = L.CURRENCY_W, L.currencies[8]
local coinsLabel = UI.currency(currencyRow, "coin", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(CUR_W / 2, CUR_H / 2), Size = UDim2.fromOffset(CUR_W, CUR_H) })
local gemsLabel = UI.currency(currencyRow, "gem", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -CUR_W / 2, 0, CUR_H / 2), Size = UDim2.fromOffset(CUR_W, CUR_H) })
local pills = { Coins = coinsLabel.Parent :: GuiObject, Gems = gemsLabel.Parent :: GuiObject }
local currencyLabels = { Coins = coinsLabel, Gems = gemsLabel }
-- «Замороженное» значение счётчика на время полёта монет (nil — показываем атрибут как есть)
local frozen: { [string]: number? } = {}
local shown: { [string]: number } = { Coins = 0, Gems = 0 }
local gainToken: { [string]: number } = { Coins = 0, Gems = 0 }

-- «УРОВЕНЬ N» + мир
local levelTitle = UI.text(UI.at(L.levelTitle, {
	Name = "LevelTitle",
	Text = "УРОВЕНЬ 1",
	Outline = 3,
	Parent = lobby,
}))
-- строка мира 40–66 (текст 26 логических) под строкой валют; полоса наград с 70 (UILayout)
local worldLine = UI.text(UI.at(L.worldLine, {
	Name = "WorldLine",
	Text = "",
	Parent = lobby,
}))

-- «НАЖМИ, ЧТОБЫ ИГРАТЬ» — пульсирует над карточками
-- зона нажатия 520×58 (≥ 32 px высоты на телефоне при ширине ~290 px — порог пилюли MIN_PILL)
local tapText = UI.new("TextButton", UI.at(L.play, {
	Name = "PlayButton", -- client/Tutorial указывает на неё
	Text = "",
	Parent = lobby,
}))
UI.text({ Text = "НАЖМИ, ЧТОБЫ ИГРАТЬ  ▶", Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 1, -16), Outline = 3, Parent = tapText })
local tapScale = Instance.new("UIScale")
tapScale.Parent = tapText
TweenService:Create(tapScale, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.08 }):Play()

-- Карточки апгрейдов: Рогатка / Сани / Доход внизу, Ракета — справа (как в оригинале)
local CARD_STYLE = {
	Launch = { title = "РОГАТКА", pip = Color3.fromRGB(235, 70, 70), btn = { Color3.fromRGB(150, 60, 80), Color3.fromRGB(105, 35, 55) }, art = "bullseye" },
	Sled = { title = "САНИ", pip = Color3.fromRGB(80, 190, 250), btn = { Color3.fromRGB(60, 110, 170), Color3.fromRGB(35, 75, 125) }, art = "sled" },
	Income = { title = "ДОХОД", pip = Color3.fromRGB(250, 190, 50), btn = { Color3.fromRGB(150, 120, 70), Color3.fromRGB(105, 80, 45) }, art = "moneybag" },
	Rocket = { title = "РАКЕТА", pip = Color3.fromRGB(110, 200, 255), btn = { Color3.fromRGB(110, 190, 255), Color3.fromRGB(50, 130, 230) }, art = "rocket" },
}
local notice: (string, number?) -> ()
type Card = { root: TextButton, badge: TextLabel, pips: { Frame }, setPrice: (string, string?) -> (), priceBtn: Frame, effect: TextLabel, art: Frame, style: any }
local cards: { [string]: Card } = {}
-- Число эффекта апгрейда и его формат — чтобы цифра могла «тикать» при покупке
local function effectValue(name: string, lvl: number): number
	if name == "Launch" then
		return Config.launchSpeed(lvl)
	elseif name == "Rocket" then
		return Config.rocketFuel(lvl)
	elseif name == "Income" then
		return Config.incomeMult(lvl)
	end
	return (1 - Config.friction(lvl) / Config.friction(0)) * 100
end
local function effectText(name: string, v: number): string
	if name == "Launch" then
		return tostring(math.floor(v + 0.5)) -- коротко: карточка 164, цифра рядом с иконкой (#46)
	elseif name == "Rocket" then
		-- «сейчас→после покупки» (#47): каждая покупка — следующая ракета
		local lvl = player:GetAttribute("RocketLevel") or 0
		local nxt = Config.upgradeNext("Rocket", lvl)
		if nxt > lvl then
			return string.format("%.1f→%.1fс", v, Config.rocketFuel(nxt))
		end
		return string.format("%.1fс", v)
	elseif name == "Income" then
		return (string.format("x%.2f", v):gsub("%.?0+$", ""))
	end
	return "+" .. math.floor(v + 0.5) .. "%"
end
-- Пока идёт короткая анимация покупки, refresh не перезаписывает цифру эффекта
local effectHold: { [string]: boolean } = {}

local cardsRow = UI.new("Frame", UI.at(L.cards, {
	Name = "Upgrades",
	BackgroundTransparency = 1,
	Parent = lobby,
}))
local cl = Instance.new("UIListLayout")
cl.FillDirection = Enum.FillDirection.Horizontal
cl.Padding = UDim.new(0, 14)
cl.SortOrder = Enum.SortOrder.LayoutOrder
cl.Parent = cardsRow

local function makeCard(name: string, parent: Instance, size: UDim2, order: number, compact: boolean): Card
	local st = CARD_STYLE[name]
	local card = UI.new("TextButton", { Name = "Card_" .. name, Text = "", AutoButtonColor = false, LayoutOrder = order, Size = size, BackgroundTransparency = 0, Parent = parent })
	if compact then
		UI.grad(card, Color3.fromRGB(120, 190, 255), Color3.fromRGB(60, 130, 230))
	else
		UI.grad(card, Color3.fromRGB(52, 70, 112), Color3.fromRGB(32, 46, 80))
	end
	UI.corner(card, 14)
	UI.stroke(card, 3)
	UI.bounce(card)
	-- карточка 164×128 (#46, UILayout.CARD_*): заголовок · иконка + цифра в строку · деления · цена
	UI.text({ Name = "Title", Text = st.title, Position = UDim2.fromOffset(10, 2), Size = UDim2.new(1, -50, 0, L.CARD_TITLE_H), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2, Parent = card })
	-- бейдж уровня (тёмный кружок в углу)
	local badgeBg = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(38, 38), BackgroundColor3 = C.navy, BackgroundTransparency = 0, ZIndex = 5, Parent = card })
	UI.corner(badgeBg, 1000)
	UI.stroke(badgeBg, 2.5, C.white)
	local badge = UI.text({ Text = "0", Position = UDim2.fromOffset(5, 6), Size = UDim2.new(1, -10, 1, -12), ZIndex = 6, Parent = badgeBg })
	-- картинка: иконка слева, цифра эффекта справа — одной строкой
	-- Рогатка/Сани/Доход: иконка слева, цифра эффекта справа — одной строкой.
	-- Ракета (#47): без делений — «текущая ▶ следующая» и топливо «2.1→3.6с» (каждая покупка — новая ракета)
	local artH = if compact then L.ROCKET_ART_H else L.CARD_ART_H
	local art = UI.new("Frame", { Name = "Art", Position = UDim2.fromOffset(8, L.CARD_ART_Y), Size = UDim2.new(1, -16, 0, artH), BackgroundTransparency = 0, ZIndex = 2, Parent = card })
	UI.grad(art, Color3.fromRGB(250, 252, 255), Color3.fromRGB(205, 225, 245))
	UI.corner(art, 10)
	local effect: TextLabel
	if compact then
		UI.icon(st.art, { Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.25, 0, 0, 17), Size = UDim2.fromOffset(26, 26), ZIndex = 3, Parent = art })
		UI.text({ Name = "Arrow", Text = "▶", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.48, 0, 0, 17), Size = UDim2.fromOffset(22, 20), TextColor3 = Color3.fromRGB(60, 130, 230), ZIndex = 3, Parent = art })
		UI.icon(st.art, { Name = "Next", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.73, 0, 0, 16), Size = UDim2.fromOffset(34, 34), ZIndex = 3, Parent = art })
		effect = UI.text({ Text = "", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -2), Size = UDim2.new(1, -8, 0, 26), ZIndex = 4, Parent = art })
	else
		UI.icon(st.art, { Name = "Icon", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0), Size = UDim2.fromOffset(artH - 4, artH - 4), ZIndex = 3, Parent = art })
		effect = UI.text({ Text = "", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.new(1, -(artH + 8), 0, 26), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4, Parent = art })
	end
	-- деления тира
	local pips = {}
	if not compact then
		for i = 1, Config.TIER_SIZE do
			-- деление тира: скруглённый квадратик с тёмной окантовкой и бликом (как в оригинале)
			local pip = UI.new("Frame", {
				Position = UDim2.new((i - 1) / Config.TIER_SIZE, 9 - (i - 1) * 18 / Config.TIER_SIZE, 0, L.CARD_PIP_Y),
				Size = UDim2.new(1 / Config.TIER_SIZE, -5, 0, L.CARD_PIP_H),
				BackgroundColor3 = st.pip,
				BackgroundTransparency = 0,
				ZIndex = 2,
				Parent = card,
			})
			UI.corner(pip, 4)
			UI.stroke(pip, 1.5, Color3.fromRGB(15, 22, 45), 0.2)
			local hl = UI.new("Frame", { Position = UDim2.new(0, 3, 0, 2), Size = UDim2.new(1, -6, 0, 3), BackgroundColor3 = C.white, BackgroundTransparency = 0.6, ZIndex = 3, Parent = pip })
			UI.corner(hl, 2)
			pips[i] = pip
		end
	end
	-- цена одной строкой (вся карточка — кнопка «улучшить», ≥ 70 px на телефоне)
	local btnH = L.CARD_BTN_H
	local priceBtn = UI.new("Frame", { Position = UDim2.new(0, 8, 1, -(btnH + 6)), Size = UDim2.new(1, -16, 0, btnH), BackgroundTransparency = 0, ZIndex = 2, Parent = card })
	local g = UI.grad(priceBtn, st.btn[1], st.btn[2])
	g.Name = "Fill"
	UI.corner(priceBtn, 10)
	UI.stroke(priceBtn, 2)
	local btnShine = UI.new("Frame", { Position = UDim2.new(0, 6, 0, 3), Size = UDim2.new(1, -12, 0, 3), BackgroundColor3 = C.white, BackgroundTransparency = 0.6, ZIndex = 3, Parent = priceBtn })
	UI.corner(btnShine, 1000)
	local _, setPrice = UI.iconText({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -12, 0, btnH - 4), ZIndex = 3, Parent = priceBtn })
	local c = { root = card, badge = badge, pips = pips, setPrice = setPrice, priceBtn = priceBtn, effect = effect, art = art, style = st }
	cards[name] = c
	local buying = false
	card.Activated:Connect(function()
		if buying then
			return
		end
		buying = true
		local oldLvl = player:GetAttribute(name .. "Level") or 0
		effectHold[name] = true
		local ok, msg = Remotes.BuyUpgrade:InvokeServer(name)
		buying = false
		if not ok then
			effectHold[name] = nil
			notice(msg or "Ошибка")
			UIFx.shakeNo(priceBtn)
			return
		end
		-- короткая анимация любого апгрейда (~0.8 с): карточка подпрыгивает, цифра тикает,
		-- новое деление тира загорается
		local newLvl = math.max(player:GetAttribute(name .. "Level") or 0, Config.upgradeNext(name, oldLvl))
		UIFx.bump(card, 1.1)
		UIFx.bump(priceBtn, 1.12)
		controller.Sfx:Fire("coin")
		UIFx.tickNumber(effect, effectValue(name, oldLvl), effectValue(name, newLvl), 0.5, function(v)
			return effectText(name, v)
		end)
		local inTier = if newLvl % Config.TIER_SIZE == 0 then Config.TIER_SIZE else newLvl % Config.TIER_SIZE
		local pip = pips[inTier]
		if pip then
			UIFx.lightUp(pip, st.pip)
		end
		task.delay(0.8, function()
			effectHold[name] = nil
			effect.Text = effectText(name, effectValue(name, player:GetAttribute(name .. "Level") or 0))
		end)
		if msg then
			-- новый тир → большая анимация (Reveal.client)
			upgradeReveal:Fire(name, msg)
		end
	end)
	return c
end

-- Уведомление (тёмная плашка, как «DAILY TASK COMPLETED!») — в слое Toasts: в лобби под полоской
-- сессии (UILayout.toastLobby), в заезде — под подсказкой рогатки (toastRun)
local noticeBox = UI.new("Frame", UI.at(L.toastLobby, {
	Name = "Toast",
	BackgroundColor3 = C.navy,
	BackgroundTransparency = 0.15,
	Visible = false,
	ZIndex = 50,
	Parent = toastRoot,
}))
UI.corner(noticeBox, 16)
UI.stroke(noticeBox, 2, C.white, 0.4)
local noticeText = UI.text({ Text = "", TextWrapped = true, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 1, -16), TextColor3 = Color3.fromRGB(255, 225, 90), ZIndex = 51, Parent = noticeBox })
UI.outline(noticeText, 2)
local noticeN = 0
notice = function(text: string, seconds: number?)
	noticeN += 1
	local my = noticeN
	UI.at(if player:GetAttribute("InRun") then L.toastRun else L.toastLobby, noticeBox :: any)
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
toastEvent.Event:Connect(function(text: string, seconds: number?)
	notice(text, seconds)
end)

for i, name in { "Launch", "Sled", "Income" } do
	makeCard(name, cardsRow, UDim2.fromOffset(L.card[7], L.card[8]), i, false)
end
-- Ракета — отдельная голубая карточка справа (как UPGRADE 💎1 в оригинале), той же высоты, что и ряд
local rocketCard = makeCard("Rocket", lobby, UDim2.fromOffset(L.rocket[7], L.rocket[8]), 0, true)
UI.at(L.rocket, rocketCard.root :: any)

------------------------------------------------------------------ заезд
local runUi = UI.new("Frame", { Name = "Run", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = root })

-- Монеты и гемы за заезд — слева сверху (под кнопками Roblox)
local runCoins = UI.currency(runUi, "coin", { Position = UDim2.fromOffset(34, 64), Size = UDim2.fromOffset(130, 38) })
local gemPill = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(34, 110), Size = UDim2.fromOffset(100, 34), Visible = false, Parent = runUi })
local runGems = UI.currency(gemPill, "gem", { Size = UDim2.fromScale(1, 1) })

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
	Size = UDim2.fromOffset(78, 78), -- ≥ 44 px на телефоне при масштабе корня 0.57
	BackgroundColor3 = C.navy,
	BackgroundTransparency = 0.35,
	Parent = runUi,
})
UI.corner(restartBtn, 1000)
UI.stroke(restartBtn, 3, C.white, 0.3)
UI.icon("flip", { Position = UDim2.fromScale(0.16, 0.16), Size = UDim2.fromScale(0.68, 0.68), Parent = restartBtn })
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
UI.text({ Text = "км/ч", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.62), Size = UDim2.fromOffset(64, 26), Parent = dial })

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
UI.icon("fire", { Position = UDim2.fromScale(0.18, 0.08), Size = UDim2.fromScale(0.64, 0.62), ZIndex = 2, Parent = rocketBtn })
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
	Size = UDim2.fromOffset(22, 300), -- 22 логических ≈ 12 px на телефоне (было 16 → 9 px)
	BackgroundColor3 = C.track,
	BackgroundTransparency = 0.2,
	Parent = runUi,
})
UI.corner(progress, 1000)
UI.stroke(progress, 2, C.white, 0.3)
local progressFill = UI.new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), BackgroundTransparency = 0, Parent = progress })
UI.grad(progressFill, Color3.fromRGB(120, 230, 255), Color3.fromRGB(40, 170, 240))
UI.corner(progressFill, 1000)
UI.icon("flag", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -2), Size = UDim2.fromOffset(34, 34), Parent = progress })
for _, f in Config.GEMS_ON_TRACK do
	UI.icon("gem", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 1 - f), Size = UDim2.fromOffset(34, 34), ZIndex = 3, Parent = progress })
end
local bestMark = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = C.white, BackgroundTransparency = 0, Visible = false, ZIndex = 3, Parent = progress })
UI.corner(bestMark, 1000)
UI.text({ Text = "BEST", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(0, -6, 0.5, 0), Size = UDim2.fromOffset(62, 26), Parent = bestMark }) -- слева от метки: справа край экрана
local pctBubble = UI.text({ Text = "0%", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(0, -6, 1, 0), Size = UDim2.fromOffset(62, 26), TextXAlignment = Enum.TextXAlignment.Right, Parent = progress })

-- Магнит и всплывающие «+N»
local magnetIcon, setMagnet = UI.iconText({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.6, 0), Size = UDim2.fromOffset(120, 40), Parent = runUi })
magnetIcon.Visible = false
-- активные бонусы: щит (до удара) и «x2 монеты» (секунды)
local shieldInd, setShieldInd = UI.iconText({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, -130, 0.6, 0), Size = UDim2.fromOffset(110, 40), Parent = runUi })
setShieldInd("Щит", "shield")
shieldInd.Visible = false
local x2Ind, setX2Ind = UI.iconText({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 130, 0.6, 0), Size = UDim2.fromOffset(110, 40), Color = Color3.fromRGB(255, 215, 70), Outline = 2.5, Parent = runUi })
x2Ind.Visible = false
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
	Size = UDim2.fromOffset(220, 78), -- ≥ 44 px на телефоне (было 64 → 36 px)
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
	Text = if TOUCH
		then "Веди пальцем — руль · 🔥 — ракета · ⤴ — прыжок\nТрюки в полёте сами · жми 🔄 — ещё один в комбо"
		else "A/D — руль · Shift — ракета · Ctrl — прыжок\nТрюки в полёте сами · жми Пробел — ещё один (держи +S / +A/D — свой)",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -16),
	Size = UDim2.fromOffset(760, 52), -- две строки: в одну (24) текст ужимался до ~8 px на телефоне
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

	-- во время полёта монет счётчик держим на старом значении (см. CurrencyGain)
	shown.Coins = frozen.Coins or coins
	shown.Gems = frozen.Gems or gems
	coinsLabel.Text = UI.money(shown.Coins)
	gemsLabel.Text = UI.money(shown.Gems)
	runUi.Visible = inRun
	currencyRow.Visible = not inRun

	local farm = player:GetAttribute("FarmWorld") or 0
	local best = if farm > 0 then 0 else player:GetAttribute("LevelBest") or 0
	if farm > 0 then
		-- фарм пройденного мира: уровень не растёт, вернуться — в окне «Миры»
		levelTitle.Text = "ФАРМ · МИР " .. farm
		worldLine.Text = Config.worldName(farm) .. " · только монеты" -- вернуться — плитка «МИРЫ»
	else
		levelTitle.Text = "УРОВЕНЬ " .. level
		worldLine.Text = (player:GetAttribute("ThemeName") or "") .. " · " .. ((level - 1) % Config.LEVELS_PER_WORLD + 1) .. "/" .. Config.LEVELS_PER_WORLD
			.. (if best > 0 then " · ★ " .. best .. "%" else "") -- коротко: строка 460 при кегле 26
	end

	for name, c in cards do
		local u = Config.UPGRADES[name]
		local lvl = player:GetAttribute(name .. "Level") or 0
		if not effectHold[name] then
			c.effect.Text = effectText(name, effectValue(name, lvl))
		end
		local maxed = lvl >= u.MaxLevel
		if name == "Rocket" then
			-- номер ракеты 1…7 вместо уровня; на максимуме — одна ракета без стрелки
			c.badge.Text = tostring(Config.tierOf(lvl) + 1)
			for _, k in { "Arrow", "Next" } do
				local o = c.art:FindFirstChild(k) :: GuiObject?
				if o then
					o.Visible = not maxed
				end
			end
			local icon = c.art:FindFirstChild("Icon") :: GuiObject?
			if icon then
				icon.Position = if maxed then UDim2.new(0.5, 0, 0, 17) else UDim2.new(0.25, 0, 0, 17)
			end
		else
			c.badge.Text = tostring(lvl)
		end
		local inTier = if lvl > 0 and lvl % Config.TIER_SIZE == 0 then Config.TIER_SIZE else lvl % Config.TIER_SIZE
		for i, pip in c.pips do
			pip.BackgroundColor3 = if i <= inTier then c.style.pip else c.style.pip:Lerp(Color3.fromRGB(30, 40, 70), 0.72)
		end
		local fill = c.priceBtn:FindFirstChild("Fill") :: UIGradient
		if maxed then
			c.setPrice("MAX")
			fill.Color = ColorSequence.new(UI.KIND.grey[1], UI.KIND.grey[2])
		else
			local cost, currency = Config.upgradePrice(name, lvl)
			local have = if currency == "Gems" then gems else coins
			c.setPrice(UI.money(cost), if currency == "Gems" then "gem" else "coin")
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
for _, attr in { "Coins", "Gems", "Level", "LevelBest", "InRun", "Loaded", "ThemeName", "FarmWorld", "LaunchLevel", "RocketLevel", "SledLevel", "IncomeLevel" } do
	player:GetAttributeChangedSignal(attr):Connect(refresh)
end
refresh()

------------------------------------------------------------------ награда валютой: полёт → тик → бамп
local function releaseCurrency(attr: string)
	gainToken[attr] += 1
	frozen[attr] = nil
	refresh()
end
currencyGain.Event:Connect(function(kind: string, amount: number?, from: any)
	local attr = if kind == "gem" then "Gems" else "Coins"
	local label = currencyLabels[attr]
	local pill = pills[attr]
	if amount == nil or amount < 0 then
		-- «держать»: запоминаем, что показано сейчас, и не даём атрибуту обновить счётчик
		if frozen[attr] == nil then
			frozen[attr] = shown[attr]
			gainToken[attr] += 1
			local my = gainToken[attr]
			-- страховка: если отпустить забыли — через 3 с отпускаем сами
			task.delay(3, function()
				if gainToken[attr] == my then
					releaseCurrency(attr)
				end
			end)
		end
		return
	end
	if amount == 0 then
		releaseCurrency(attr)
		return
	end
	local startVal = frozen[attr] or shown[attr]
	frozen[attr] = startVal
	gainToken[attr] += 1
	local my = gainToken[attr]
	local fromPos = if typeof(from) == "Vector2" then from elseif typeof(from) == "Instance" and from:IsA("GuiObject") then from else pill
	UIFx.flyCurrency(kind, fromPos, pill, UIFx.countFor(kind, amount), function(last)
		if gainToken[attr] ~= my then
			return
		end
		controller.Sfx:Fire(if kind == "gem" then "gem" else "coin")
		if not last then
			return
		end
		local target = player:GetAttribute(attr) or 0
		UIFx.tickNumber(label, frozen[attr] or startVal, target, UIFx.T.tick, function(v)
			local n = math.floor(v + 0.5)
			frozen[attr] = n
			return UI.money(n)
		end)
		task.delay(UIFx.T.tick + 0.05, function()
			if gainToken[attr] == my then
				releaseCurrency(attr)
			end
		end)
	end)
end)

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
	local best = if (player:GetAttribute("FarmWorld") or 0) > 0 then 0 else math.floor((player:GetAttribute("LevelBest") or 0) / 100 * L)
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
		setMagnet(tostring(math.ceil(ml)), "magnet")
	end
	shieldInd.Visible = state.ShieldOn.Value
	local x2 = state.X2Left.Value
	x2Ind.Visible = x2 > 0
	if x2 > 0 then
		setX2Ind("x2  " .. math.ceil(x2), "coin")
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
result = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.56), Size = UDim2.fromOffset(380, 340), BackgroundTransparency = 1, Visible = false, ZIndex = 20, Parent = root })
local resultScale = Instance.new("UIScale")
resultScale.Parent = result
local resultTitle = UI.text({ Text = "", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -6), Size = UDim2.fromOffset(460, 52), Outline = 3, ZIndex = 22, Parent = result })
local bestBanner = UI.text({ Text = "", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -58), Size = UDim2.fromOffset(420, 40), TextColor3 = Color3.fromRGB(255, 215, 60), Rotation = -3, ZIndex = 22, Parent = result })
UI.outline(bestBanner, 3)
-- Лист итогов: тёмно-синяя карточка с крупной суммой монет, строками бонуса и гемов
local sheet = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 246), BackgroundTransparency = 0, ZIndex = 20, Parent = result })
UI.grad(sheet, Color3.fromRGB(56, 78, 124), Color3.fromRGB(32, 46, 82))
UI.corner(sheet, 20)
UI.stroke(sheet, 3, C.ink)
local sheetShine = UI.new("Frame", { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 5), BackgroundColor3 = C.white, BackgroundTransparency = 0.7, ZIndex = 21, Parent = sheet })
UI.corner(sheetShine, 1000)
UI.text({ Text = "ТЫ ПОЛУЧИЛ:", Position = UDim2.fromOffset(20, 14), Size = UDim2.new(1, -40, 0, 28), TextColor3 = Color3.fromRGB(190, 215, 250), ZIndex = 21, Parent = sheet })
local _, setRCoins = UI.iconText({ Position = UDim2.fromOffset(20, 50), Size = UDim2.new(1, -40, 0, 46), Outline = 3, ZIndex = 21, Parent = sheet })
local divider = UI.new("Frame", { Position = UDim2.fromOffset(24, 104), Size = UDim2.new(1, -48, 0, 2), BackgroundColor3 = C.white, BackgroundTransparency = 0.8, ZIndex = 21, Parent = sheet })
local _ = divider
local _, setRBonus = UI.iconText({ Position = UDim2.fromOffset(20, 114), Size = UDim2.new(1, -40, 0, 26), ZIndex = 21, Parent = sheet })
local _, setRGems = UI.iconText({ Position = UDim2.fromOffset(20, 146), Size = UDim2.new(1, -40, 0, 26), ZIndex = 21, Parent = sheet })
local rDist = UI.text({ Text = "", Position = UDim2.fromOffset(20, 182), Size = UDim2.new(1, -40, 0, 24), TextColor3 = Color3.fromRGB(190, 215, 250), ZIndex = 21, Parent = sheet })
UI.outline(rDist, 2)
-- строка лидерборда недели и титула (#26, server/Weekly → RunEnded.week)
local rWeek = UI.text({ Text = "", Position = UDim2.fromOffset(20, 210), Size = UDim2.new(1, -40, 0, 22), TextColor3 = Color3.fromRGB(255, 215, 90), ZIndex = 21, Parent = sheet })
UI.outline(rWeek, 2)
local continueBtn = UI.button("blue", "ПРОДОЛЖИТЬ", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 260),
	Size = UDim2.fromOffset(250, 78), -- ≥ 44 px на телефоне
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
	resultTitle.Text = if finished and r.farm
		then "ТРАССА ПРОЙДЕНА!"
		elseif finished then "УРОВЕНЬ " .. r.level .. " ПРОЙДЕН!"
		elseif r.reason == "crash" then "ВРЕЗАЛСЯ!"
		elseif r.reason == "fell" then "УЛЕТЕЛ С ТРАССЫ!"
		elseif r.reason == "stopped" then "ОСТАНОВИЛСЯ"
		elseif r.reason == "cheat" then "ЗАЕЗД НЕ ЗАСЧИТАН"
		else "ЗАЕЗД ОКОНЧЕН"
	bestBanner.Text = if finished then "🎉 ФИНИШ!" elseif r.newBest then "🏆 НОВЫЙ РЕКОРД!" else ""
	setRCoins(UI.money(r.coins) .. (if (r.mult or 1) > 1 then "  x" .. r.mult else ""), "coin")
	setRBonus("Монеты на трассе и трюки: +" .. math.floor(r.bonus or 0), "coin")
	setRGems("+" .. (r.gems or 0), "gem")
	rDist.Text = (r.distance or 0) .. " м  ·  " .. r.percent .. "% уровня"
	local wk = r.week
	local tid, tUntil = player:GetAttribute("Title"), player:GetAttribute("TitleUntil")
	local title = nil
	for _, t in Config.WEEKLY.TITLES do
		if t.id == tid and typeof(tUntil) == "number" and tUntil > workspace:GetServerTimeNow() then
			title = t.icon .. " " .. t.name .. "  ·  "
		end
	end
	rWeek.Text = (title or "") .. (if type(wk) ~= "table" then ""
		elseif wk.excluded then "Неделя: заезд не идёт в табло"
		else string.format("🏆 Неделя: %s · рекорд %d м", if wk.rank then "#" .. wk.rank else "вне топ-100", wk.best or 0))
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
