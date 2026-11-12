-- Меню лобби в стиле мобильного оригинала:
--  • слева колонка «ледяных» плиток-иконок с подписями (Миры, Задания, Сани, Следы, Подарки + стрик);
--  • справа шестерёнка (настройки);
--  • под заголовком — жёлтая плашка сундука с таймером и полоска сессии.
--  Места — Shared/UILayout (общий с HUD/Tutorial и макет-рендером scripts/ui_layout_preview.py);
--  • окна — голубые, с лентой-заголовком и круглым красным крестиком (Shared/UIKit).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local WorldLook = require(ReplicatedStorage.Shared:WaitForChild("WorldLook"))
local UI = require(ReplicatedStorage.Shared:WaitForChild("UIKit"))
local UIFx = require(ReplicatedStorage.Shared:WaitForChild("UIFx"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local hud = player:WaitForChild("PlayerGui"):WaitForChild("HUD")
local root = hud:WaitForChild("Root")
local lobby = root:WaitForChild("Lobby")
-- событие HUD: полёт монет/гемов к верхним счётчикам (см. HUD.client, CurrencyGain)
local currencyGain = script.Parent:WaitForChild("HUD"):WaitForChild("CurrencyGain") :: BindableEvent
-- сообщения — в слое Toasts HUD (поверх окон, масштаб как у HUD, #38)
local toast = script.Parent:WaitForChild("HUD"):WaitForChild("Toast") :: BindableEvent
local C = UI.C
local L = UI.L

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

-- Короткое сообщение («Не хватает монет», «✔ Сани выбраны»): слой Toasts HUD — под полоской
-- сессии (UILayout.toastLobby, 206–256), поверх окон, масштабируется вместе с HUD (#38)
local function say(ok: boolean, text: any)
	if typeof(text) ~= "string" then
		return
	end
	toast:Fire((if ok then "✔ " else "") .. text, 1.8)
end

local function csvSet(attr: string): { [string]: boolean }
	local set = {}
	for id in string.gmatch(player:GetAttribute(attr) or "", "[^,]+") do
		set[id] = true
	end
	return set
end

------------------------------------------------------------------ колонки плиток
-- Плитки 80×80 (≥ 44 px на телефоне) с подписью-плашкой 116×30 (текст 26 → ≥ 14 px, #35):
-- колонка 64–546 по Y, 12–128 по X (UILayout.tiles/TILE_STEP)
local TILES_X, TILES_Y, TILE = L.tiles[4], L.tiles[6], L.tiles[7]
local function tile(order: number, icon: string, caption: string): TextButton
	return UI.tile(lobby, icon, {
		Name = "Tile_" .. icon,
		Position = UDim2.fromOffset(TILES_X, TILES_Y + (order - 1) * L.TILE_STEP),
		Size = UDim2.fromOffset(TILE, TILE),
	}, caption)
end
local worldsBtn = tile(1, "globe", "МИРЫ")
local tasksBtn = tile(2, "tasks", "ЗАДАНИЯ")
local sledsBtn = tile(3, "sled", "САНИ")
local trailsBtn = tile(4, "sparkles", "СЛЕДЫ")
local giftBtn = tile(5, "gift", "ПОДАРКИ")
local tasksBadge = UI.badge(tasksBtn, "!")
tasksBadge.Visible = false
local trailsNew = UI.badge(trailsBtn, "NEW", "green")
-- таймер ближайшего подарка — голубой бейдж в углу плитки (там же красный «N готово»): подпись
-- плитки не перекрывает и сам ≥ 14 px на телефоне
local giftBadge = UI.badge(giftBtn, "!")
giftBadge.Visible = false

-- справа: шестерёнка (кружок) — настройки
-- зона нажатия 84×80 (≥ 44 px на телефоне при масштабе 0.57), кружок 68
local gear = UI.new("TextButton", UI.at(L.gear, { Name = "Gear", Text = "", BackgroundTransparency = 1, Parent = lobby }))
local gearBg = UI.new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(68, 68), BackgroundColor3 = C.navy, BackgroundTransparency = 0.35, Parent = gear })
UI.corner(gearBg, 1000)
UI.stroke(gearBg, 2.5, C.white, 0.3)
UI.icon("gear", { Position = UDim2.fromScale(0.14, 0.14), Size = UDim2.fromScale(0.72, 0.72), Parent = gearBg })
UI.bounce(gear)

-- Полоса наград под заголовком (UILayout.chest/session, y 112–170): слева жёлтая плашка сундука с
-- таймером, справа подарок сессии. Пилюли по 58 (≥ 32 px на телефоне), сундук не выше 112.
local chestPill = UI.new("TextButton", UI.at(L.chest, {
	Name = "Chest",
	Text = "",
	AutoButtonColor = false,
	BackgroundTransparency = 0,
	Parent = lobby,
}))
UI.grad(chestPill, Color3.fromRGB(255, 225, 80), Color3.fromRGB(245, 175, 30))
UI.corner(chestPill, 1000)
UI.stroke(chestPill, 3)
UI.bounce(chestPill)
-- нарисованный сундук вылезает за левый край плашки (как в оригинале), по высоте — в пределах полосы
UI.chest(chestPill, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 16, 0.5, -1), Size = UDim2.fromOffset(64, 56), ZIndex = 4 })
local chestShine = UI.new("Frame", { Position = UDim2.new(0, 40, 0, 4), Size = UDim2.new(1, -60, 0, 5), BackgroundColor3 = C.white, BackgroundTransparency = 0.5, ZIndex = 2, Parent = chestPill })
UI.corner(chestShine, 1000)
local chestInner = UI.new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.new(1, -66, 1, -14), BackgroundColor3 = C.navy, BackgroundTransparency = 0.05, ZIndex = 2, Parent = chestPill })
UI.corner(chestInner, 1000)
-- монетка слева в тёмной капсуле таймера
UI.coin(chestInner, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 4, 0.5, 0), Size = UDim2.fromOffset(34, 34), ZIndex = 3 })
local chestText = UI.text({ Text = "", Position = UDim2.fromOffset(42, 5), Size = UDim2.new(1, -50, 1, -10), ZIndex = 3, Parent = chestInner })

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
	local ok, res = UI.invoke(Remotes.RewardAction, action, arg)
	if typeof(res) == "string" then
		say(ok, res)
	end
	return ok, res
end
-- Сумма награды: из ответа сервера («+500 💰  +15 💎»), иначе — по дельте атрибутов
local function gainAmounts(res: any, before: { [string]: number }): (number, number)
	local coins, gems
	if typeof(res) == "string" then
		coins = tonumber(string.match(res, "%+(%d+)%s*💰"))
		gems = tonumber(string.match(res, "%+(%d+)%s*💎"))
	end
	coins = coins or math.max(0, (player:GetAttribute("Coins") or 0) - before.Coins)
	gems = gems or math.max(0, (player:GetAttribute("Gems") or 0) - before.Gems)
	return coins, gems
end
local function gainFire(coins: number, gems: number, from: Vector2)
	currencyGain:Fire("coin", coins, from)
	currencyGain:Fire("gem", gems, from)
end
-- Награда с анимацией: держим счётчики, спрашиваем сервер, при успехе монеты летят к HUD.
-- onSuccess(fire) — если задан, сам решает, когда запустить полёт (сундук: после открытия).
local function rewardAct(action: string, arg: any?, from: GuiObject, onSuccess: ((() -> ()) -> ())?): boolean
	local fromPos = from.AbsolutePosition + from.AbsoluteSize / 2 -- кнопку могут перерисовать
	local before = { Coins = player:GetAttribute("Coins") or 0, Gems = player:GetAttribute("Gems") or 0 }
	currencyGain:Fire("coin", -1, fromPos) -- «держать» счётчики до ответа сервера
	currencyGain:Fire("gem", -1, fromPos)
	local ok, res = act(action, arg)
	if not ok then
		gainFire(0, 0, fromPos)
		return false
	end
	local coins, gems = gainAmounts(res, before)
	local function fire()
		gainFire(coins, gems, fromPos)
	end
	if onSuccess then
		onSuccess(fire)
	else
		fire()
	end
	return true
end
chestPill.Activated:Connect(function()
	if rewards and rewards.chestAt - serverNow() > 0 then
		UIFx.shakeNo(chestPill) -- ещё закрыт
		return
	end
	local ok = rewardAct("chest", nil, chestPill, function(fire)
		UIFx.openChest(chestPill, fire)
	end)
	if not ok then
		UIFx.shakeNo(chestPill)
	end
end)

------------------------------------------------------------------ Полоска «сессия» (#24)
-- Справа от сундука в полосе наград (UILayout.session 112–170, ширина 280). Шкала 0…SESSION_GOAL_MIN,
-- метка 🎁 на минуте большого подарка. Текст ≤ 15 знаков — кегль ≥ 26 логических (≥ 14 px).
local sfx = script.Parent:WaitForChild("SledController"):WaitForChild("Sfx") :: BindableEvent
local sessionBar = UI.new("TextButton", UI.at(L.session, {
	Name = "Session",
	Text = "",
	AutoButtonColor = false,
	BackgroundColor3 = C.navy,
	BackgroundTransparency = 0.15,
	Visible = false,
	Parent = lobby,
}))
UI.corner(sessionBar, 1000)
UI.stroke(sessionBar, 2.5, C.white, 0.2)
UI.bounce(sessionBar)
local sessionFill = UI.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundTransparency = 0, ZIndex = 2, Parent = sessionBar })
UI.grad(sessionFill, Color3.fromRGB(255, 225, 80), Color3.fromRGB(245, 160, 30))
UI.corner(sessionFill, 1000)
local sessionText = UI.text({ Text = "", Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -28, 1, -20), ZIndex = 4, Parent = sessionBar })
-- метка большого подарка (подарок торчит над полоской, как сундук над плашкой)
local bigMark = UI.icon("gift", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(44, 44), ZIndex = 5, Parent = sessionBar })
local sessionReady = false
local bigOpening = false -- пока идёт анимация открытия, метку не прячем
local function updateSessionBar(elapsed: number)
	local bi = rewards and rewards.big
	local g = bi and Config.PLAYTIME_GIFTS[bi]
	local goal = Config.SESSION_GOAL_MIN * 60
	local bigTaken = g == nil or rewards.gifts[bi] == true
	-- цель достигнута и подарок забран — полоска больше не нужна
	sessionBar.Visible = bigOpening or not (bigTaken and elapsed >= goal)
	sessionFill.Size = UDim2.fromScale(math.clamp(elapsed / goal, 0, 1), 1)
	bigMark.Visible = bigOpening or not bigTaken
	if bigOpening then
		return
	end
	local ready = false
	if g and not bigTaken then
		bigMark.Position = UDim2.fromScale(math.clamp(g.min * 60 / goal, 0.08, 0.92), 0.5)
		local left = g.min * 60 - elapsed
		ready = left <= 0
		-- коротко (≤ 15 знаков): полоска 280 при кегле 26 логических
		sessionText.Text = if ready then "ЗАБЕРИ ПОДАРОК!" else "ПОДАРОК " .. clock(left)
	else
		sessionText.Text = "ЦЕЛЬ · " .. clock(goal - elapsed)
	end
	if ready and not sessionReady then -- момент готовности: вспышка и звук
		UIFx.pulseSelect(sessionBar, "ГОТОВО!")
		UIFx.bump(bigMark, 1.4)
		sfx:Fire("reward")
	end
	sessionReady = ready
end
sessionBar.Activated:Connect(function()
	local bi = rewards and rewards.big
	if not sessionReady or not bi then
		UIFx.shakeNo(sessionBar)
		return
	end
	-- открытие: подарок трясётся → вспышка → монеты и гемы летят в счётчики
	local ok = rewardAct("gift", bi, bigMark, function(fire)
		bigOpening = true
		UIFx.openChest(bigMark, function()
			fire()
			task.delay(0.6, function()
				bigOpening = false
			end)
		end)
	end)
	if not ok then
		UIFx.shakeNo(sessionBar)
	end
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
	for w = 1, math.max(current + 1, #Config.THEMES) do
		local theme = Config.themeOfWorld(w)
		local card = UI.new("Frame", { Size = UDim2.new(0, 200, 1, -6), BackgroundColor3 = C.row, BackgroundTransparency = 0, ZIndex = 33, Parent = worldsList })
		UI.corner(card, 16)
		UI.stroke(card, 3)
		local pic = UI.new("Frame", { Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 130), BackgroundTransparency = 0, ZIndex = 34, Parent = card })
		local col = Config.WORLD_COLORS[theme]
		UI.grad(pic, col:Lerp(Color3.new(1, 1, 1), 0.35), col)
		UI.corner(pic, 12)
		UI.icon(Config.WORLD_IMAGES[theme] or "tree", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromScale(0.62, 0.86), ZIndex = 35, Parent = pic })
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
		elseif player.UserId == game.CreatorId then
			-- владелец игры: проверить любой мир без прохождения
			if farm == w then
				kind, text = "green", "✔ ТЕСТ ЗДЕСЬ"
			else
				kind, text, action, arg = "blue", "▶ ТЕСТ МИРА", "farm", w
			end
		elseif w == current + 1 then
			kind, text, action = "purple", "ПРОПУСК R$" .. Config.PRODUCTS.SkipWorld.price, "skip"
		else
			kind, text = "grey", "Пройди мир " .. (w - 1)
		end
		if w < current and farm ~= w then
			-- подсказка: в пройденном мире уровень не растёт, только монеты
			UI.ink({ Text = "монеты без прогресса", Position = UDim2.new(0, 8, 1, -86), Size = UDim2.new(1, -16, 0, 24), TextTransparency = 0.3, ZIndex = 34, Parent = card })
		end
		local st = UI.button(kind, text, { Position = UDim2.new(0, 10, 1, -58), Size = UDim2.new(1, -20, 0, 48), ZIndex = 34, Parent = card })
		if action then
			st.Activated:Connect(function()
				local ok, msg = UI.invoke(Remotes.WorldAction, action, arg)
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
local function openWorlds()
	drawWorlds()
	-- прокрутка к текущему миру (карточка 200 + отступ 14)
	local current = Config.worldOf(player:GetAttribute("Level") or 1)
	worldsList.CanvasPosition = Vector2.new(math.max(0, (current - 2) * 214), 0)
	open(worldsWin)
end
worldsBtn.Activated:Connect(openWorlds)

------------------------------------------------------------------ Задания дня
local tasksWin, tasksBody = panel("ЗАДАНИЯ ДНЯ", 580, 560)
UI.text({ Text = "ВЫПОЛНИ ВСЕ ЗАДАНИЯ,\nЧТОБЫ ПОЛУЧИТЬ СУНДУК!", Position = UDim2.fromOffset(10, 18), Size = UDim2.new(1, -100, 0, 54), ZIndex = 33, Parent = tasksBody })
local _, setTasksBar = UI.progress(tasksBody, { Position = UDim2.fromOffset(12, 76), Size = UDim2.new(1, -100, 0, 26), ZIndex = 33 })
local chestClaim = UI.new("TextButton", { Text = "", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 34), Size = UDim2.fromOffset(72, 72), BackgroundTransparency = 1, ZIndex = 34, Parent = tasksBody })
local chestIcon = UI.chest(chestClaim, { Position = UDim2.fromOffset(2, 6), Size = UDim2.fromOffset(68, 60), ZIndex = 35 })
local chestDone = UI.icon("check", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1), Size = UDim2.fromOffset(32, 32), Visible = false, ZIndex = 45, Parent = chestClaim })
UI.bounce(chestClaim)
local taskChestReady = false
chestClaim.Activated:Connect(function()
	if not taskChestReady then
		UIFx.shakeNo(chestIcon) -- ещё не все задания / уже открыт
		return
	end
	local ok = rewardAct("taskChest", nil, chestClaim, function(fire)
		UIFx.openChest(chestIcon, fire)
	end)
	if not ok then
		UIFx.shakeNo(chestIcon)
	end
end)
-- список заданий прокручивается (их 6 в день)
local taskRows = scroller(tasksBody, false, 108)
taskRows.Size = UDim2.new(1, 0, 1, -146)
local taskPad = taskRows:FindFirstChildOfClass("UIPadding") :: UIPadding
taskPad.PaddingTop = UDim.new(0, 6)
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
		local row = UI.new("TextButton", { Text = "", AutoButtonColor = false, LayoutOrder = if t.claimed then 100 + i elseif done then i - 100 else i, Size = UDim2.new(1, -6, 0, 92), BackgroundTransparency = 0, ZIndex = 33, Parent = taskRows })
		if done and not t.claimed then
			UI.grad(row, UI.KIND.yellow[1], UI.KIND.yellow[2])
			UI.bounce(row)
			row.Activated:Connect(function()
				rewardAct("task", i, row)
			end)
		else
			row.BackgroundColor3 = C.row
		end
		UI.corner(row, 16)
		UI.stroke(row, 2.5, Color3.fromRGB(120, 170, 225))
		local iconBox = UI.new("Frame", { Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(76, 76), BackgroundColor3 = C.white, BackgroundTransparency = 0.2, ZIndex = 34, Parent = row })
		UI.corner(iconBox, 12)
		local id = t.id
		UI.icon(if t.claimed or done then "check" else (t.icon or TASK_ICONS[id or ""] or "tasks"), { Position = UDim2.fromScale(0.1, 0.1), Size = UDim2.fromScale(0.8, 0.8), ZIndex = 35, Parent = iconBox })
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
	-- кнопка остаётся активной: если сундук не готов — покачивание «нет» вместо открытия
	taskChestReady = claimed == total and not rewards.chestClaimed
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
-- Сверху — стрик дней входа (#25, y 0–214 тела окна), ниже — сетка подарков за время.
-- Вкладка в «Подарках», а не 6-я плитка: слева уже 5 плиток, обе награды — «за возвращение».
-- Окно 760 шириной: 7 карточек дней по 98 с суммами кеглем 24 (на телефоне окно ~0.5 — 12 px;
-- в 640 при 80 на карточку суммы шли кеглем 15 → 8 px).
local giftsWin, giftsBody = panel("ПОДАРКИ", 760, 620)
local giftsArea = scroller(giftsBody, false, 222)
local _, setStreakHead = UI.iconText({ Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 30), Color = C.ink, ZIndex = 33, Parent = giftsBody })
type StreakCard = { frame: Frame, stroke: UIStroke, icon: Frame, done: Frame, setCoins: (string, string?) -> (), setGems: (string, string?) -> (), gemsRow: Frame, coinsRow: Frame }
local streakCards: { StreakCard } = {}
local streakRow = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 126), ZIndex = 33, Parent = giftsBody })
local srl = Instance.new("UIListLayout")
srl.FillDirection = Enum.FillDirection.Horizontal
srl.HorizontalAlignment = Enum.HorizontalAlignment.Center
srl.Padding = UDim.new(0, 6)
srl.SortOrder = Enum.SortOrder.LayoutOrder
srl.Parent = streakRow
for i, r in Config.STREAK_REWARDS do
	-- карточка 98×126: «ДЕНЬ N» 4–28, иконка 30–62, суммы по 28 (кегль 24) 64–92 / 94–122
	local card = UI.new("Frame", { LayoutOrder = i, BackgroundColor3 = C.row, BackgroundTransparency = 0, Size = UDim2.fromOffset(98, 126), ZIndex = 33, Parent = streakRow })
	UI.corner(card, 12)
	local stroke = UI.stroke(card, 2, Color3.fromRGB(120, 170, 225))
	UI.ink({ Text = "ДЕНЬ " .. i, Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 0, 24), ZIndex = 34, Parent = card })
	local main = if r.big then "gift" elseif r.coins then "coin" else "gem"
	local icon = UI.icon(main, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 30), Size = UDim2.fromOffset(32, 32), ZIndex = 34, Parent = card })
	local both = r.coins ~= nil and r.gems ~= nil
	local coinsRow, setCoins = UI.iconText({ Position = UDim2.fromOffset(2, if both then 64 else 78), Size = UDim2.new(1, -4, 0, 28), Color = C.ink, ZIndex = 34, Parent = card })
	local gemsRow, setGems = UI.iconText({ Position = UDim2.fromOffset(2, if both then 94 else 78), Size = UDim2.new(1, -4, 0, 28), Color = C.ink, ZIndex = 34, Parent = card })
	local done = UI.icon("check", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(28, 28), ZIndex = 36, Visible = false, Parent = card })
	streakCards[i] = { frame = card, stroke = stroke, icon = icon, done = done, setCoins = setCoins, setGems = setGems, coinsRow = coinsRow, gemsRow = gemsRow }
end
local streakBtn = UI.button("green", "ЗАБРАТЬ", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 166), Size = UDim2.fromOffset(260, 48), Radius = 10, StrokeThickness = 2, ZIndex = 34, Parent = giftsBody })
-- Предложение спасти серию: поверх стрика, один раз в день пропуска (до награды или отказа)
local saveBox = UI.new("Frame", { BackgroundColor3 = C.row, BackgroundTransparency = 0, Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 184), ZIndex = 40, Visible = false, Parent = giftsBody })
UI.corner(saveBox, 14)
UI.stroke(saveBox, 3, C.gold)
local saveText = UI.ink({ Text = "", TextWrapped = true, Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 0, 80), ZIndex = 41, Parent = saveBox })
local saveYes = UI.button("green", "", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(0.5, -6, 0, 116), Size = UDim2.fromOffset(240, 56), Radius = 10, StrokeThickness = 2, ZIndex = 41, Parent = saveBox })
local saveNo = UI.button("grey", "НЕТ, С 1-ГО ДНЯ", { Position = UDim2.new(0.5, 6, 0, 116), Size = UDim2.fromOffset(240, 56), Radius = 10, StrokeThickness = 2, ZIndex = 41, Parent = saveBox })
saveYes.Activated:Connect(function()
	local ok = act("streakSave")
	if not ok then
		UIFx.shakeNo(saveYes)
	end
end)
saveNo.Activated:Connect(function()
	act("streakDecline")
end)
streakBtn.Activated:Connect(function()
	if not rewardAct("streak", nil, streakBtn) then
		UIFx.shakeNo(streakBtn)
	end
end)
local function streakReady(): boolean
	return rewards ~= nil and rewards.streak ~= nil and not rewards.streak.claimed
end
local function drawStreak()
	local st = rewards and rewards.streak
	if not st then
		return
	end
	local count = math.max(st.count, 1)
	local cur = Config.streakDay(count)
	local level = player:GetAttribute("Level") or 1
	setStreakHead("ДНЕЙ ПОДРЯД: " .. count .. "  · пропуск — с 1-го дня", "fire")
	for i, card in streakCards do
		local coins, gems = Config.streakReward(count - cur + i)
		card.coinsRow.Visible = coins ~= nil
		card.gemsRow.Visible = gems ~= nil
		if coins then
			card.setCoins(UI.money(Config.rewardCoins(coins, level)), "coin")
		end
		if gems then
			card.setGems(tostring(gems), "gem")
		end
		local today = i == cur
		card.done.Visible = i < cur or (today and st.claimed)
		card.stroke.Color = if today then C.gold elseif Config.STREAK_REWARDS[i].big then Color3.fromRGB(255, 170, 60) else Color3.fromRGB(120, 170, 225)
		card.stroke.Thickness = if today then 4 else 2
		card.frame.BackgroundTransparency = if i < cur then 0.35 else 0
	end
	saveBox.Visible = st.save > 0 and not st.claimed
	saveText.Text = string.format("Ты пропустил день! Серия %d дн. сгорела.\nВерни её за гемы — сегодня будет день %d.", st.save, st.save + 1)
	UI.setText(saveYes, "СПАСТИ  " .. st.savePrice, "gem")
end
grid(giftsArea, 128, 124)
type GiftCell = { status: TextButton, setCoins: (string, string?) -> (), setGems: (string, string?) -> (), rows: { Frame } }
local giftCells: { GiftCell } = {}
for i, g in Config.PLAYTIME_GIFTS do
	local cell = UI.new("Frame", { LayoutOrder = i, BackgroundColor3 = C.row, BackgroundTransparency = 0, ZIndex = 33, Parent = giftsArea })
	UI.corner(cell, 14)
	-- большой подарок — золотая рамка (#24)
	UI.stroke(cell, if g.big then 4 else 2.5, if g.big then C.gold else Color3.fromRGB(120, 170, 225))
	-- награда: крупно одна строка, либо две (монеты + гемы)
	local both = g.coins ~= nil and g.gems ~= nil
		-- ячейка 128×124: суммы 6–34 / 36–64 (кегль 24) или одна крупная 12–56, кнопка 70–118 (48)
	local rowCoins, setCoins = UI.iconText({ Position = UDim2.fromOffset(6, if both then 6 else 12), Size = UDim2.new(1, -12, 0, if both then 28 else 44), Color = C.ink, ZIndex = 34, Parent = cell })
	local rowGems, setGems = UI.iconText({ Position = UDim2.fromOffset(6, if both then 36 else 12), Size = UDim2.new(1, -12, 0, if both then 28 else 44), Color = C.ink, ZIndex = 34, Parent = cell })
	local st = UI.button("blue", "", { Position = UDim2.new(0, 8, 1, -54), Size = UDim2.new(1, -16, 0, 48), Radius = 10, StrokeThickness = 2, ZIndex = 34, Parent = cell })
	st.Activated:Connect(function()
		if not rewardAct("gift", i, st) then
			UIFx.shakeNo(st)
		end
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
type Cell = { status: TextButton, model: any, rarity: number, frame: Frame }
local sledCells: { Cell } = {}
-- Выбор саней: вспышка на выбранной карточке, остальные на 0.3 с приглушаются
local function selectSled(chosen: Frame, purchased: boolean, status: TextButton)
	UIFx.pulseSelect(chosen, if purchased then "КУПЛЕНО" else "ВЫБРАНО")
	if purchased then
		UI.pop(status) -- цена «подпрыгивает»
	end
	local dim = Color3.fromRGB(205, 212, 225)
	for _, c in sledCells do
		if c.frame ~= chosen then
			local f = c.frame
			TweenService:Create(f, TweenInfo.new(0.12), { BackgroundColor3 = dim }):Play()
			task.delay(0.3, function()
				TweenService:Create(f, TweenInfo.new(0.25), { BackgroundColor3 = C.white }):Play()
			end)
		end
	end
end
for mi, model in Config.SLEDS do
	-- строка 176: ячейка редкости 118×160 — имя 4–30, образец 32–80, бонус 82–106 (24), кнопка 106–154 (48)
	local row = UI.new("Frame", { LayoutOrder = mi, Size = UDim2.new(1, -8, 0, 176), BackgroundColor3 = C.row, BackgroundTransparency = 0, ZIndex = 33, Parent = sledList })
	UI.corner(row, 16)
	UI.stroke(row, 2.5, Color3.fromRGB(120, 170, 225))
	local head = UI.new("Frame", { Position = UDim2.fromOffset(8, 8), Size = UDim2.new(0, 150, 1, -16), BackgroundTransparency = 0, ZIndex = 34, Parent = row })
	UI.grad(head, Color3.fromRGB(250, 252, 255), Color3.fromRGB(205, 225, 245))
	UI.corner(head, 12)
	UI.icon(model.img, { Position = UDim2.fromOffset(37, 6), Size = UDim2.fromOffset(76, 70), ZIndex = 35, Parent = head })
	UI.ink({ Text = model.name, Position = UDim2.fromOffset(6, 80), Size = UDim2.new(1, -12, 0, 28), ZIndex = 35, Parent = head })
	if model.bonus > 0 then
		local tag = UI.button("green", "+" .. model.bonus .. "% скорости", { Position = UDim2.fromOffset(8, 114), Size = UDim2.new(1, -16, 0, 36), Radius = 8, StrokeThickness = 2, ZIndex = 35, Parent = head })
		tag.Active = false
	end
	for r, rar in Config.RARITIES do
		local cell = UI.new("Frame", { Position = UDim2.new(0, 170 + (r - 1) * 126, 0, 8), Size = UDim2.new(0, 118, 1, -16), BackgroundColor3 = C.white, BackgroundTransparency = 0, ZIndex = 34, Parent = row })
		UI.corner(cell, 12)
		UI.stroke(cell, 2)
		local nameL = UI.text({ Text = rar.name, Position = UDim2.fromOffset(6, 4), Size = UDim2.new(1, -12, 0, 26), TextColor3 = rar.color or C.ink, ZIndex = 35, Parent = cell })
		if rar.color then
			UI.outline(nameL, 1.5)
		end
		local sw = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 32), Size = UDim2.fromOffset(48, 48), BackgroundColor3 = rar.color or Color3.fromRGB(240, 70, 120), BackgroundTransparency = 0, ZIndex = 35, Parent = cell })
		UI.corner(sw, 1000)
		UI.stroke(sw, 2)
		UI.icon(model.img, { Position = UDim2.fromScale(0.12, 0.12), Size = UDim2.fromScale(0.76, 0.76), ZIndex = 36, Parent = sw })
		local total = model.bonus + rar.bonus
		UI.ink({ Text = if total > 0 then "+" .. total .. "%" else "базовые", Position = UDim2.fromOffset(6, 82), Size = UDim2.new(1, -12, 0, 24), TextColor3 = Color3.fromRGB(60, 150, 70), ZIndex = 35, Parent = cell })
		local status = UI.button("blue", "", { Position = UDim2.new(0, 6, 1, -54), Size = UDim2.new(1, -12, 0, 48), Radius = 10, StrokeThickness = 2, ZIndex = 35, Parent = cell })
		status.Activated:Connect(function()
			local key = model.id .. ":" .. r
			local hadIt = csvSet("OwnedSleds")[key] == true
			local ok, res = UI.invoke(Remotes.SledAction, model.id, r)
			say(ok, res)
			if ok then
				selectSled(cell, not hadIt, status)
			else
				UIFx.shakeNo(status)
			end
		end)
		table.insert(sledCells, { status = status, model = model, rarity = r, frame = cell })
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
			kind, text = "green", "✔ ВЫБРАНО" -- как во вспышке выбора (UIFx.pulseSelect); «надеть» — у следов
		elseif owned[key] then
			kind, text = "blue", "ВЫБРАТЬ"
		elseif world < c.model.world then
			kind, text, icon = "grey", "МИР " .. c.model.world, "lock"
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
local function openSleds()
	drawSleds()
	open(sledWin)
end
sledsBtn.Activated:Connect(openSleds)

------------------------------------------------------------------ Следы
-- Слева сетка карточек (UILayout.TRAIL_GRID_W), справа превью выбранного следа (#7)
local trailWin, trailBody = panel("СЛЕДЫ", L.TRAIL_WIN_W, L.TRAIL_WIN_H)
local trailArea = scroller(trailBody, false, 6)
trailArea.Size = UDim2.new(0, L.TRAIL_GRID_W, 1, -6)
grid(trailArea, 142, 176)
local trailCells: { [string]: TextButton } = {}
local trailStrokes: { [string]: UIStroke } = {}
local CARD_EDGE = Color3.fromRGB(120, 170, 225)
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 70)),
	ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 210, 50)),
	ColorSequenceKeypoint.new(0.66, Color3.fromRGB(80, 220, 120)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 90, 255)),
})
-- цвет радуги в точке x ∈ [0, 1) (линейно между ключами RAINBOW)
local function rainbowAt(x: number): Color3
	local kp = RAINBOW.Keypoints
	for k = 1, #kp - 1 do
		local a, b = kp[k], kp[k + 1]
		if x <= b.Time then
			return a.Value:Lerp(b.Value, (x - a.Time) / (b.Time - a.Time))
		end
	end
	return kp[#kp].Value
end

-- Превью справа: небо, снег, иконка текущих саней покачивается, за ней — лента следа из кружков
-- (объект Trail во ViewportFrame не рисуется, поэтому рисуем 2D; кружки не повёрнуты — их обрезает
-- ClipsDescendants сцены). Анимация — только пока окно открыто (RenderStepped подключается на показ).
local TP = Config.TRAIL_PREVIEW
local pv = UI.new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 6), Size = UDim2.new(0, L.TRAIL_PREVIEW_W, 1, -6), BackgroundColor3 = C.row, BackgroundTransparency = 0, ZIndex = 33, Parent = trailBody })
UI.corner(pv, 16)
UI.stroke(pv, 2.5, CARD_EDGE)
local pvName = UI.ink({ Text = "", Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -20, 0, 32), ZIndex = 34, Parent = pv })
local stage = UI.new("Frame", { Position = UDim2.fromOffset(10, 46), Size = UDim2.new(1, -20, 1, -136), BackgroundTransparency = 0, ClipsDescendants = true, ZIndex = 34, Parent = pv })
UI.grad(stage, Color3.fromRGB(120, 185, 250), Color3.fromRGB(205, 232, 255))
UI.corner(stage, 12)
UI.stroke(stage, 2)
-- снег внизу сцены: белая полоса с голубой кромкой
local ground = UI.new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0.36, 0), BackgroundColor3 = C.white, BackgroundTransparency = 0, ZIndex = 35, Parent = stage })
UI.new("Frame", { Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = Color3.fromRGB(170, 205, 240), BackgroundTransparency = 0, ZIndex = 36, Parent = ground })
-- полоски «ветра» (скорость): едут справа налево и появляются снова справа
local windLines: { Frame } = {}
for k = 1, 4 do
	local w = UI.new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(34 + k * 6, 4), BackgroundColor3 = C.white, BackgroundTransparency = 0.35, ZIndex = 35, Parent = stage })
	UI.corner(w, 1000)
	table.insert(windLines, w)
end
-- лента: первый кружок крупный и плотный у саней, дальше мельче и прозрачнее
local blobs: { Frame } = {}
for k = 1, TP.SEGMENTS do
	local f = 1 - (k - 1) / TP.SEGMENTS
	local b = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(18 + 18 * f, 12 + 22 * f), BackgroundTransparency = 0.05 + 0.75 * (1 - f), ZIndex = 37, Parent = stage })
	UI.corner(b, 1000)
	table.insert(blobs, b)
end
local pvSled = UI.icon("donut", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(84, 84), ZIndex = 39, Parent = stage })
local pvBonus = UI.ink({ Text = "", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -48), Size = UDim2.new(1, -20, 0, 30), TextColor3 = Color3.fromRGB(200, 140, 20), ZIndex = 34, Parent = pv })
local pvState = UI.ink({ Text = "", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -12), Size = UDim2.new(1, -20, 0, 30), TextColor3 = Color3.fromRGB(70, 100, 150), ZIndex = 34, Parent = pv })

local previewId = "white"
local function paintPreview()
	local t = Config.trail(previewId)
	pvName.Text = t.name
	pvBonus.Text = if t.bonus > 0 then "+" .. t.bonus .. "% монет" else "без бонуса"
	local cur = player:GetAttribute("Trail") or "white"
	pvState.Text = if t.id == cur then "✔ надет" elseif csvSet("OwnedTrails")[t.id] then "куплен" else "цена " .. UI.money(t.price)
	UI.setIcon(pvSled, Config.sled(player:GetAttribute("Sled")).img)
	for k, b in blobs do
		b.BackgroundColor3 = if t.rainbow then rainbowAt((k - 1) / TP.SEGMENTS) else t.color
	end
	for id, s in trailStrokes do
		s.Color = if id == t.id then C.gold else CARD_EDGE
		s.Thickness = if id == t.id then 4 else 2.5
	end
end
local function previewTrail(id: string)
	if id ~= previewId then
		previewId = id
		paintPreview()
		UI.pop(pvSled)
	end
end

local clock0 = os.clock()
local function stepPreview()
	local time = os.clock() - clock0
	local ph = time * TP.SPEED
	-- сани — на 2/3 ширины и середине высоты сцены (доли — не зависят от масштаба окна)
	pvSled.Position = UDim2.new(0.66, 0, 0.5, TP.BOB * math.sin(ph))
	pvSled.Rotation = -TP.TILT * math.cos(ph)
	local t = Config.trail(previewId)
	for k, b in blobs do
		-- кружок k — там, где сани были «k шагов назад»: та же синусоида с отставанием фазы
		local p = ph - k * TP.LAG
		b.Position = UDim2.new(0.66, -26 - k * TP.SPACING, 0.5, 20 + TP.BOB * math.sin(p))
		if t.rainbow then
			b.BackgroundColor3 = rainbowAt(((k - 1) / TP.SEGMENTS + time * TP.RAINBOW_SPEED) % 1)
		end
	end
	for k, w in windLines do
		-- доля ширины 1.2 → −0.3: полоска выезжает из-за правого края и уходит за левый
		local x = 1.2 - ((time * TP.LINES_SPEED / L.TRAIL_PREVIEW_W + k * 1.5 / #windLines) % 1.5)
		w.Position = UDim2.new(x, 0, 0.1 + 0.11 * k, 0)
	end
end
local previewConn: RBXScriptConnection? = nil
trailWin:GetPropertyChangedSignal("Visible"):Connect(function()
	if trailWin.Visible and not previewConn then
		previewConn = RunService.RenderStepped:Connect(stepPreview)
	elseif not trailWin.Visible and previewConn then
		previewConn:Disconnect()
		previewConn = nil
	end
end)

for i, t in Config.TRAILS do
	local card = UI.new("Frame", { LayoutOrder = i, BackgroundColor3 = C.row, BackgroundTransparency = 0, ZIndex = 33, Parent = trailArea })
	UI.corner(card, 14)
	trailStrokes[t.id] = UI.stroke(card, 2.5, CARD_EDGE)
	-- превью: наведение мышью или тап по карточке (на телефоне)
	card.MouseEnter:Connect(function()
		previewTrail(t.id)
	end)
	card.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			previewTrail(t.id)
		end
	end)
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
	UI.ink({ Text = if t.bonus > 0 then "+" .. t.bonus .. "% монет" else "без бонуса", Position = UDim2.fromOffset(8, 98), Size = UDim2.new(1, -16, 0, 24), TextColor3 = Color3.fromRGB(200, 140, 20), ZIndex = 34, Parent = card })
	local st = UI.button("blue", "", { Position = UDim2.new(0, 10, 1, -54), Size = UDim2.new(1, -20, 0, 48), Radius = 10, StrokeThickness = 2, ZIndex = 34, Parent = card })
	st.Activated:Connect(function()
		previewTrail(t.id)
		say(UI.invoke(Remotes.TrailAction, t.id))
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
	paintPreview()
end
trailsBtn.Activated:Connect(function()
	trailsNew.Visible = false
	previewId = player:GetAttribute("Trail") or "white" -- открываем с надетым следом
	drawTrails()
	open(trailWin)
end)

------------------------------------------------------------------ Настройки (как SETTINGS в оригинале: круглые кнопки-иконки)
local setWin = UI.new("Frame", {
	Name = "Panel_Settings",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.42), -- выше карточек апгрейдов, чтобы их значки не налезали

	Size = UDim2.fromOffset(570, 270), -- 5 кнопок по 84 через 106 (+ подписи 110)
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
toggle("Sfx", "speaker", "Звуки", -212)
toggle("Music", "music", "Музыка", -106)
toggle("Snow", "snowflake", "Снегопад", 0)
toggle("Shadows", "moon", "Тени", 106)
toggle("Ghost", "stopwatch", "Призрак", 212) -- призрак своего рекорда в заезде (#62, client/Ghost)
gear.Activated:Connect(function()
	open(setWin)
end)
-- Тени (SetShadows) применяет PostFX вместе с уровнем графики. Уровень — на эту сессию:
-- АВТО (по «Графике» Roblox и FPS) → НИЗКОЕ → СРЕДНЕЕ → ВЫСОКОЕ
local gfxBtn = UI.button("blue", "", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 206), Size = UDim2.fromOffset(300, 50), ZIndex = 31, Parent = setWin })
local function paintGfx()
	local c = player:GetAttribute("GfxChoice") or 0
	local q = WorldLook.QUALITY[if c > 0 then c else player:GetAttribute("GfxTier") or 3]
	UI.setText(gfxBtn, "ГРАФИКА: " .. (if c > 0 then q.name else "АВТО · " .. q.name))
end
gfxBtn.Activated:Connect(function()
	player:SetAttribute("GfxChoice", ((player:GetAttribute("GfxChoice") or 0) + 1) % (#WorldLook.QUALITY + 1))
end)
player:GetAttributeChangedSignal("GfxChoice"):Connect(paintGfx)
player:GetAttributeChangedSignal("GfxTier"):Connect(paintGfx)
paintGfx()

------------------------------------------------------------------ обновление
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
	drawStreak()
end
player:GetAttributeChangedSignal("Rewards"):Connect(refreshRewards)
refreshRewards()
-- Вернувшийся игрок (серия ≥ 2 или есть что спасти) с неполученной наградой — окно открывается само,
-- один раз за сессию; новичка не отвлекаем от обучения — ему бейдж на 🎁
task.spawn(function()
	while not rewards do
		task.wait(0.5)
	end
	task.wait(2)
	local st = rewards.streak
	if st and not st.claimed and (st.count >= 2 or st.save > 0) and not player:GetAttribute("InRun") and not giftsWin.Visible then
		open(giftsWin)
	end
end)

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
	updateSessionBar(elapsed)
	if streakReady() then
		ready += 1
		UI.setKind(streakBtn, "green")
		UI.setText(streakBtn, "ЗАБРАТЬ")
	else
		UI.setKind(streakBtn, "grey")
		UI.setText(streakBtn, "ЗАВТРА · " .. clock(rewards.resetAt - now))
	end
	-- один бейдж в углу «Подарков»: красный «N» — есть что забрать, голубой — таймер ближайшего
	if ready > 0 then
		UI.setBadge(giftBadge, tostring(ready), "red")
	elseif nextIn then
		UI.setBadge(giftBadge, clock(nextIn), "blue")
	end
	giftBadge.Visible = ready > 0 or nextIn ~= nil
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

-- Станции лобби (#69): вошёл в зону перед порталом «Миры» / лавкой «Сани» — открылось окно.
-- Зоны — детали "Zone" с атрибутом Menu в модели Lobby (Props.worldPortal / shopStall). Срабатывает
-- на входе (не пока стоишь), только когда окна закрыты и не в заезде.
local ZONE_OPEN: { [string]: () -> () } = { worlds = openWorlds, sleds = openSleds }
task.spawn(function()
	local lobbyModel = workspace:WaitForChild("Lobby", 120)
	if not lobbyModel then
		return
	end
	local inside: { [Instance]: boolean } = {}
	local zones: { BasePart } = {}
	local function track(z: Instance)
		if z.Name == "Zone" and z:IsA("BasePart") and z:GetAttribute("Menu") then
			table.insert(zones, z)
		end
	end
	for _, z in lobbyModel:GetDescendants() do
		track(z)
	end
	lobbyModel.DescendantAdded:Connect(track) -- станции ставит Lobby.furnish позже (ждёт меши)
	while true do
		task.wait(Config.LOBBY_ZONE_POLL)
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and not player:GetAttribute("InRun") then
			for _, z in zones do
				local menu = z:GetAttribute("Menu")
				if menu and z.Parent then
					local rel = z.CFrame:PointToObjectSpace(root.Position)
					local size = z.Size
					local isIn = math.abs(rel.X) < size.X / 2 and math.abs(rel.Z) < size.Z / 2 and math.abs(rel.Y) < size.Y
					if isIn and not inside[z] then
						local anyOpen = false
						for _, pnl in panels do
							anyOpen = anyOpen or pnl.Visible
						end
						local fn = ZONE_OPEN[menu]
						if fn and not anyOpen then
							fn()
						end
					end
					inside[z] = isIn
				end
			end
		end
	end
end)
