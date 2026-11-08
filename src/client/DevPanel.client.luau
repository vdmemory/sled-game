-- Панель разработчика — видна только владельцу игры (game.CreatorId).
-- Справочник всех вариантов прокачки с 3D-превью по тирам (рогатка, сани каждой модели,
-- ракеты, доход), правила (формулы силы, скорости, цен) и инструменты для проверки:
-- выставить себе уровень, добавить монеты/гемы, перейти на уровень мира, выдать сани,
-- сбросить задания. Правила хранятся в Shared/Config — панель показывает их как есть.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
if player.UserId ~= game.CreatorId then
	return
end

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local UI = require(Shared:WaitForChild("UIKit"))
local C = UI.C
local SledModels = require(Shared:WaitForChild("SledModels"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local gui = Instance.new("ScreenGui")
gui.Name = "DevPanel"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 30
gui.Parent = player:WaitForChild("PlayerGui")

local root = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })

-- Кнопка открытия: тёмный кружок «DEV» под шестерёнкой справа
-- ниже шестерёнки HUD (на ПК она 122–202 px от верха экрана) — не перекрывает её
local openBtn = UI.button("dark", "DEV", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 280), Size = UDim2.fromOffset(64, 40), Radius = 12, Parent = root })

------------------------------------------------------------------ окно
local W, H = 1000, 620
local win = UI.new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.52),
	Size = UDim2.fromOffset(W, H),
	BackgroundColor3 = Color3.fromRGB(24, 32, 54),
	BackgroundTransparency = 0,
	Visible = false,
	ZIndex = 50,
	Parent = root,
})
UI.corner(win, 18)
UI.stroke(win, 3, Color3.fromRGB(90, 140, 220))
local scale = Instance.new("UIScale")
scale.Parent = win
local cam = workspace.CurrentCamera
local function fit()
	local vp = cam.ViewportSize
	scale.Scale = math.min(1, (vp.X - 20) / W, (vp.Y - 30) / H)
end
cam:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
fit()

UI.text({ Text = "ПАНЕЛЬ РАЗРАБОТЧИКА", Position = UDim2.fromOffset(20, 12), Size = UDim2.fromOffset(420, 34), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 51, Parent = win })
local status = UI.text({ Text = "", Position = UDim2.fromOffset(460, 16), Size = UDim2.fromOffset(420, 26), TextColor3 = Color3.fromRGB(150, 230, 150), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 51, Parent = win })
UI.outline(status, 1.5)
UI.closeButton(win, function()
	win.Visible = false
end)

local function dev(action: string, a: any?, b: any?, c: any?)
	local ok, msg = UI.invoke(Remotes.DevAction, action, a, b, c)
	status.TextColor3 = if ok then Color3.fromRGB(150, 230, 150) else Color3.fromRGB(255, 120, 120)
	status.Text = tostring(msg)
end

-- вкладки слева
local tabsCol = UI.new("Frame", { Position = UDim2.fromOffset(14, 58), Size = UDim2.fromOffset(170, H - 72), BackgroundTransparency = 1, ZIndex = 51, Parent = win })
local tl = Instance.new("UIListLayout")
tl.Padding = UDim.new(0, 8)
tl.SortOrder = Enum.SortOrder.LayoutOrder
tl.Parent = tabsCol

local content = UI.new("ScrollingFrame", {
	Position = UDim2.fromOffset(196, 58),
	Size = UDim2.new(1, -210, 1, -72),
	BackgroundColor3 = Color3.fromRGB(32, 44, 72),
	BackgroundTransparency = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 8,
	ZIndex = 51,
	Parent = win,
})
UI.corner(content, 12)
UI.pad(content, 12)
local cl = Instance.new("UIListLayout")
cl.Padding = UDim.new(0, 10)
cl.SortOrder = Enum.SortOrder.LayoutOrder
cl.Parent = content

local function clear()
	for _, c in content:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

local order = 0
local function nextOrder(): number
	order += 1
	return order
end

-- строка-заголовок / пояснение
local function heading(text: string)
	UI.text({ Text = text, LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(255, 215, 90), ZIndex = 52, Parent = content }).TextStrokeTransparency = 0.5
end
local function note(text: string)
	local t = UI.new("TextLabel", {
		Text = text,
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextScaled = false,
		TextSize = 17,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(205, 220, 245),
		Font = Enum.Font.Gotham,
		ZIndex = 52,
		Parent = content,
	})
	return t
end
-- ряд кнопок
local function buttonRow(buttons: { any })
	-- кнопки переносятся на новую строку, если не влезают по ширине (UIGridLayout с авто-высотой)
	local row = UI.new("Frame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 52, Parent = content })
	local rl = Instance.new("UIListLayout")
	rl.FillDirection = Enum.FillDirection.Horizontal
	rl.Wraps = true
	rl.Padding = UDim.new(0, 8)
	rl.Parent = row
	for _, b in buttons do
		local btn = UI.button(b[1], b[2], { Size = UDim2.fromOffset(math.max(100, (utf8.len(b[2]) or 8) * 13 + 24), 40), Radius = 10, StrokeThickness = 2, ZIndex = 53, Parent = row })
		btn.Activated:Connect(b[3])
	end
	return row
end
-- сетка карточек
local function cardGrid(): Frame
	local g = UI.new("Frame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 52, Parent = content })
	local gl = Instance.new("UIGridLayout")
	gl.CellSize = UDim2.fromOffset(176, 250)
	gl.CellPadding = UDim2.fromOffset(10, 10)
	gl.SortOrder = Enum.SortOrder.LayoutOrder
	gl.Parent = g
	return g
end

-- 3D-превью: модель во ViewportFrame с камерой под углом и медленным вращением
local spinning: { { cam: Camera, center: Vector3, dist: number, vp: ViewportFrame } } = {}
local function preview(parent: Instance, build: (Model) -> ()): ViewportFrame
	local vp = UI.new("ViewportFrame", { Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 0, 118), BackgroundColor3 = Color3.fromRGB(200, 225, 250), BackgroundTransparency = 0, Ambient = Color3.fromRGB(170, 175, 195), LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-1, -1.5, -0.8), ZIndex = 53, Parent = parent })
	UI.corner(vp, 10)
	local m = Instance.new("Model")
	build(m)
	m.Parent = vp
	local vcam = Instance.new("Camera")
	vcam.FieldOfView = 40
	vcam.Parent = vp
	vp.CurrentCamera = vcam
	local cf, size = m:GetBoundingBox()
	table.insert(spinning, { cam = vcam, center = cf.Position, dist = size.Magnitude * 0.72 + 1, vp = vp })
	return vp
end
RunService.RenderStepped:Connect(function()
	if not win.Visible then
		return
	end
	local a = os.clock() * 0.5
	for i = #spinning, 1, -1 do
		local s = spinning[i]
		if not s.vp.Parent then
			table.remove(spinning, i)
			continue
		end
		local eye = s.center + Vector3.new(math.sin(a) * s.dist, s.dist * 0.45, math.cos(a) * s.dist)
		s.cam.CFrame = CFrame.lookAt(eye, s.center)
	end
end)

-- Плоская картинка вместо 3D-превью: цветная плашка мира + 3D-иконка (Config.WORLD_IMAGES)
local function worldArt(parent: Instance, theme: number)
	local col = Config.WORLD_COLORS[theme] or C.ribbon
	local pic = UI.new("Frame", { Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 0, 118), BackgroundTransparency = 0, ZIndex = 53, Parent = parent })
	UI.grad(pic, col:Lerp(C.white, 0.35), col)
	UI.corner(pic, 10)
	UI.stroke(pic, 2, col:Lerp(C.ink, 0.4))
	UI.icon(Config.WORLD_IMAGES[theme] or "tree", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(84, 84), ZIndex = 54, Parent = pic })
end

local function card(grid: Frame, idx: number, title: string, lines: { string }, current: boolean, build: ((Model) -> ())?, onApply: (() -> ())?, art: ((Frame) -> ())?)
	local c = UI.new("Frame", { LayoutOrder = idx, BackgroundColor3 = if current then Color3.fromRGB(60, 110, 70) else Color3.fromRGB(46, 62, 98), BackgroundTransparency = 0, ZIndex = 52, Parent = grid })
	UI.corner(c, 12)
	UI.stroke(c, 2, if current then Color3.fromRGB(140, 230, 120) else Color3.fromRGB(90, 120, 175))
	if build then
		preview(c, build)
	elseif art then
		art(c)
	end
	local y = if build or art then 128 else 8
	UI.text({ Text = title, Position = UDim2.fromOffset(6, y), Size = UDim2.new(1, -12, 0, 24), ZIndex = 53, Parent = c })
	for i, line in lines do
		UI.new("TextLabel", { Text = line, Position = UDim2.fromOffset(8, y + 24 + (i - 1) * 18), Size = UDim2.new(1, -16, 0, 18), TextScaled = false, TextSize = 14, Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(200, 215, 240), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 53, Parent = c })
	end
	if onApply then
		local b = UI.button(if current then "green" else "blue", if current then "СЕЙЧАС" else "ПРИМЕНИТЬ", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(1, -16, 0, 32), Radius = 8, StrokeThickness = 2, ZIndex = 53, Parent = c })
		b.Activated:Connect(onApply)
	end
end

local function priceText(name: string, level: number): string
	if level >= Config.UPGRADES[name].MaxLevel then
		return "максимум"
	end
	local cost, cur = Config.upgradePrice(name, level)
	return UI.money(cost) .. (if cur == "Gems" then " 💎" else " 💰")
end

------------------------------------------------------------------ вкладки
local tabs: { [string]: () -> () } = {}
local tabButtons: { [string]: TextButton } = {}
local currentTab = "Рогатка"
local sledPick, rarityPick = "tube", 1

local function tierCount(name: string): number
	return Config.tierOf(Config.UPGRADES[name].MaxLevel) + 1
end
local function levelRange(t: number, name: string): string
	local a = t * Config.TIER_SIZE
	local b = math.min(a + Config.TIER_SIZE - 1, Config.UPGRADES[name].MaxLevel)
	return if a == b then "ур. " .. a else "ур. " .. a .. "–" .. b
end

tabs["Рогатка"] = function()
	heading("Рогатка — " .. tierCount("Launch") .. " тиров, новый вид каждые " .. Config.TIER_SIZE .. " уровней")
	note("Сила выстрела = " .. Config.F.launchBase .. " + " .. Config.F.launchStep .. " × уровень. Цена уровня: " .. Config.UPGRADES.Launch.BaseCost .. " × (1+ур)^" .. Config.UPGRADE_PRICE_POW .. " × " .. Config.UPGRADES.Launch.Growth .. "^ур монет; переход на новый тир — гемы. На каждом тире свои столбы и резинка (Shared/SledModels.slingshot, ROPE_COLORS).")
	local g = cardGrid()
	local cur = Config.tierOf(player:GetAttribute("LaunchLevel") or 0)
	for t = 0, tierCount("Launch") - 1 do
		local lvl = t * Config.TIER_SIZE
		card(g, t, Config.TIERS.Launch[t + 1] or ("Тир " .. t), {
			levelRange(t, "Launch"),
			"сила " .. Config.launchSpeed(lvl) .. "–" .. Config.launchSpeed(math.min(lvl + 4, Config.UPGRADES.Launch.MaxLevel)),
			"цена тира: " .. priceText("Launch", math.max(lvl, 0)),
		}, t == cur, function(m)
			for _, sx in { -1, 1 } do
				SledModels.slingshot(m, CFrame.new(sx * 5, 0, 0) * CFrame.Angles(0, 0, sx * math.rad(-8)), t)
			end
			local rope = Instance.new("Part")
			rope.Anchored = true
			rope.Size = Vector3.new(9, 0.4, 0.4)
			rope.CFrame = CFrame.new(0, 3.5, 0)
			rope.Color = SledModels.ROPE_COLORS[t + 1]
			rope.Material = if SledModels.ROPE_GLOW[t] then Enum.Material.Neon else Enum.Material.Fabric
			rope.Parent = m
		end, function()
			dev("setLevel", "Launch", lvl)
		end)
	end
end

tabs["Сани"] = function()
	heading("Сани — модели, редкости и " .. tierCount("Sled") .. " тиров обвеса")
	note("Скорость: потолок = (" .. Config.F.speedBase .. " + " .. Config.F.speedStep .. " × уровень) × (1 + бонус модели + бонус редкости), трение = " .. Config.F.frictionBase .. " × " .. Config.F.frictionDecay .. "^уровень. Обвес по тиру — Shared/SledModels.extras; у каждой модели свои точки крепления (MOUNTS, SPOILER, SHIELD, BUMPER).")
	-- выбор модели
	local rowModels = {}
	for _, mdl in Config.SLEDS do
		table.insert(rowModels, { if mdl.id == sledPick then "green" else "blue", mdl.name, function()
			sledPick = mdl.id
			tabs.redraw()
		end })
	end
	for i = 1, #rowModels, 4 do
		buttonRow({ table.unpack(rowModels, i, math.min(i + 3, #rowModels)) })
	end
	local rowR = {}
	for r, rar in Config.RARITIES do
		table.insert(rowR, { if r == rarityPick then "green" else "grey", rar.name, function()
			rarityPick = r
			tabs.redraw()
		end })
	end
	buttonRow(rowR)
	local mdl = Config.sled(sledPick)
	local rar = Config.RARITIES[rarityPick]
	note(mdl.name .. ": открывается в мире " .. mdl.world .. ", бонус модели +" .. mdl.bonus .. "%, редкость " .. rar.name .. " +" .. rar.bonus .. "%, цена " .. UI.money(mdl.prices[rarityPick]) .. " 💰")
	buttonRow({ { "yellow", "ВЫДАТЬ И НАДЕТЬ", function()
		dev("giveSled", sledPick, rarityPick)
	end } })
	local g = cardGrid()
	local cur = Config.tierOf(player:GetAttribute("SledLevel") or 0)
	local rocketTier = Config.tierOf(player:GetAttribute("RocketLevel") or 0)
	for t = 0, tierCount("Sled") - 1 do
		local lvl = t * Config.TIER_SIZE
		card(g, t, Config.TIERS.Sled[t + 1] or ("Тир " .. t), {
			levelRange(t, "Sled"),
			"трение −" .. math.floor((1 - Config.friction(lvl) / Config.friction(0)) * 100 + 0.5) .. "%, потолок " .. Config.maxSpeed(lvl),
			"цена тира: " .. priceText("Sled", lvl),
		}, t == cur, function(m)
			local main = rar.color or mdl.main
			local accent = if rarityPick > 1 then Color3.new(1, 1, 1):Lerp(rar.color :: Color3, 0.35) else mdl.accent
			SledModels.build(m, CFrame.new(), mdl.id, { main = main, accent = accent, material = if rarityPick > 1 then rar.material else nil, glow = rarityPick == 5, shine = rar.shine }, nil, rarityPick > 1)
			SledModels.extras(m, CFrame.new(), mdl.id, t, rocketTier, accent, nil)
		end, function()
			dev("setLevel", "Sled", lvl)
		end)
	end
end

tabs["Ракета"] = function()
	heading("Ракета — " .. tierCount("Rocket") .. " видов, каждая покупка — новая ракета (за гемы)")
	note("Без промежуточных уровней (#47): покупка = следующая ракета + анимация «было → стало». Уровень в сейве кратен " .. Config.TIER_SIZE .. " (ракета N = ур. " .. Config.TIER_SIZE .. "×(N−1)). Топливо = " .. Config.F.fuelBase .. " + " .. Config.F.fuelStep .. " × уровень секунд (+" .. Config.F.fuelStep * Config.TIER_SIZE .. " с за ракету). Цены ракет 2–7: " .. table.concat(Config.ROCKET_TIER_PRICES, ", ") .. " 💎 (сумма прежних цен 5 уровней, всего 165) — Настройка → «Прокачка». Старые сейвы: уровни сверх границы тира откатаны, их гемы возвращены. Вид: корпус, нос, пояски, стабилизаторы, сопло (Shared/SledModels.ROCKETS); пламя у тиров 5+ голубое (Effects).")
	local g = cardGrid()
	local cur = Config.tierOf(player:GetAttribute("RocketLevel") or 0)
	for t = 0, tierCount("Rocket") - 1 do
		local lvl = t * Config.TIER_SIZE
		card(g, t, Config.TIERS.Rocket[t + 1] or ("Тир " .. t), {
			"ракета " .. (t + 1) .. " · ур. " .. lvl,
			string.format("топливо %.1f с", Config.rocketFuel(lvl)),
			"следующая: " .. priceText("Rocket", lvl),
		}, t == cur, function(m)
			SledModels.rocket(m, CFrame.Angles(0, math.rad(90), 0), t)
		end, function()
			dev("setLevel", "Rocket", lvl)
		end)
	end
end

tabs["Доход"] = function()
	heading("Доход — множитель монет за заезд")
	note("Множитель = 1 + " .. Config.F.incomeStep .. " × уровень. Цена уровня: " .. Config.UPGRADES.Income.BaseCost .. " × (1+ур)^" .. Config.UPGRADE_PRICE_POW .. " × " .. Config.UPGRADES.Income.Growth .. "^ур монет; переход на новый тир — гемы.")
	local g = cardGrid()
	local cur = Config.tierOf(player:GetAttribute("IncomeLevel") or 0)
	for t = 0, tierCount("Income") - 1 do
		local lvl = t * Config.TIER_SIZE
		card(g, t, Config.TIERS.Income[t + 1] or ("Тир " .. t), {
			levelRange(t, "Income"),
			string.format("монеты x%.2f–x%.2f", Config.incomeMult(lvl), Config.incomeMult(math.min(lvl + 4, Config.UPGRADES.Income.MaxLevel))),
			"цена тира: " .. priceText("Income", lvl),
		}, t == cur, nil, function()
			dev("setLevel", "Income", lvl)
		end)
	end
end

tabs["Миры"] = function()
	heading("Миры — " .. #Config.THEMES .. " тем по " .. Config.LEVELS_PER_WORLD .. " уровней, дальше по кругу")
	note("Длина уровня растёт с номером; на каждом мире свои декорации, препятствия и освещение (Track.dressSegment, Props.obstacle, Effects LOOKS). «Перейти» ставит текущий уровень (прогресс!), для просмотра без изменений есть «ТЕСТ МИРА» в окне «Миры».")
	local g = cardGrid()
	local curWorld = Config.worldOf(player:GetAttribute("Level") or 1)
	for w = 1, #Config.THEMES * 2 do
		local first = (w - 1) * Config.LEVELS_PER_WORLD + 1
		card(g, w, w .. ". " .. Config.worldName(w), {
			"уровни " .. first .. "–" .. (first + Config.LEVELS_PER_WORLD - 1),
			"длина 1-го: " .. Config.levelLength(first) .. " м",
			"финиш: +" .. Config.finishBonus(first) .. " 💰",
		}, w == curWorld, nil, function()
			dev("setWorldLevel", first)
		end, function(c)
			worldArt(c, Config.themeOfWorld(w))
		end)
	end
end

tabs["Бонусы"] = function()
	heading("Бонусы на трассе")
	local P = Config.POWERUPS
	note("Щит — шанс " .. P.shield.chance * 100 .. "% на прямом куске: одно столкновение без аварии.")
	note("x2 монеты — шанс " .. P.x2.chance * 100 .. "%: монеты на трассе ×2 на " .. P.x2.time .. " с.")
	note("Канистра — шанс " .. P.fuel.chance * 100 .. "%: полный бак ракеты.")
	note("Кольца — шанс " .. P.rings.chance * 100 .. "%: 3 кольца подряд, +" .. P.rings.coins .. " монет за каждое.")
	note("Магнит — шанс " .. Config.MAGNET_CHANCE * 100 .. "%, " .. Config.MAGNET_TIME .. " с, радиус " .. Config.MAGNET_RADIUS .. ".  Ускоритель — +" .. Config.BOOST_ADD .. " к скорости.  Кристалл — +" .. Config.CRYSTAL_COINS .. " монет и гем.")
	heading("Задания дня — " .. #Config.TASK_POOL .. " видов, " .. Config.TASKS_PER_DAY .. " в день")
	for _, t in Config.TASK_POOL do
		note("• " .. Config.taskText(t, t.targets[1]) .. "  (цель " .. t.targets[1] .. "–" .. t.targets[2] .. ", " .. t.gems .. " 💎" .. (if t.max then ", лучший заезд" else "") .. ")")
	end
end

-- Трюки в воздухе: карточки из Config.TRICKS + формула комбо (числа — вкладка «Настройка»)
tabs["Трюки"] = function()
	heading("Трюки в полёте — Config.TRICKS")
	do
		local tiers = {}
		for _, p in Config.AUTO_TRICK_PLANS do
			local names = {}
			for _, id in p.options[1] do
				table.insert(names, Config.TRICKS[id].name)
			end
			table.insert(tiers, "≥ " .. p.air .. " с — " .. table.concat(names, " + "))
		end
		note("Режим: " .. (if Config.AUTO_TRICKS >= 1 then "АВТО-трюки (AUTO_TRICKS = 1)" else "только ручные (AUTO_TRICKS = 0)") .. ". Авто: когда сани выше " .. Config.AC_AIR_HEIGHT .. " studs над снегом, по предсказанному полёту выбирается ярус: " .. table.concat(tiers, "; ") .. ". С вероятностью " .. Config.AUTO_TRICK_RANDOM * 100 .. "% — другой вариант яруса. Вращение " .. Config.AUTO_TRICK_MIN_SPEED .. "–" .. Config.AUTO_TRICK_MAX_SPEED .. " рад/с подгоняется, чтобы закончить за " .. Config.AUTO_TRICK_MARGIN .. " с до касания; не успел — трюк не засчитан, без «Падения». Нажатие во время авто-трюка — ещё один (не повторяющийся) трюк в комбо.")
	end
	note("Ручной режим (бонус к авто): в воздухе Пробел / 🔄: держать — вращение (какое — решает руль в момент нажатия), короткий тап — грэб, два тапа — разворот. Завершённые трюки копятся за полёт и начисляются при чистом приземлении; недокрученный ручной трюк = «Падение» (скорость × " .. Config.OBSTACLE_SLOWDOWN .. ", монеты за полёт сгорают).")
	local g = cardGrid()
	for i, id in Config.TRICK_ORDER do
		local t = Config.TRICKS[id]
		card(g, i, t.name, {
			"Ввод: " .. t.input,
			"Монет: " .. t.coins .. "   Буст: ×" .. t.boost,
			"Мин. в воздухе: " .. t.minAir .. " с",
			"Ось: " .. (if t.kind == "pitch" then (if (t.dir or -1) < 0 then "сальто назад" else "сальто вперёд") elseif t.kind == "roll" then "продольная (бочка)" elseif t.kind == "yaw" then "вертикальная (360°)" else "без вращения"),
		}, false, nil, nil, function(c)
			local pic = UI.new("Frame", { Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 0, 118), BackgroundTransparency = 0, ZIndex = 53, Parent = c })
			UI.grad(pic, Color3.fromRGB(120, 190, 255), Color3.fromRGB(60, 130, 230))
			UI.corner(pic, 10)
			UI.icon(t.icon, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(84, 84), ZIndex = 54, Parent = pic })
		end)
	end
	local m = Config.TRICK_COMBO_MULT
	note(string.format("Комбо: монеты за полёт = Σ(монеты × число) × множитель за число РАЗНЫХ трюков: 1 → ×%s, 2 → ×%s, 3+ → ×%s. Буст скорости перемножается за каждый трюк. Пример: Сальто + Бочка = (%d + %d) × %s = %d монет.", m[1], m[2], m[3], Config.TRICKS.flip.coins, Config.TRICKS.roll.coins, m[2], math.floor((Config.TRICKS.flip.coins + Config.TRICKS.roll.coins) * m[2])))
	note("Прыжок с земли (Ctrl / W / ⤴): вверх " .. Config.JUMP_SPEED .. " studs/с ≈ " .. string.format("%.1f", Config.JUMP_SPEED ^ 2 / (2 * workspace.Gravity)) .. " studs высоты, пауза " .. Config.JUMP_COOLDOWN .. " с. Перелетаются конусы, бревно, барьер, бочки; машины и снеговик — нет. Вращение " .. Config.FLIP_SPEED .. " рад/с → оборот за " .. string.format("%.2f", 2 * math.pi / Config.FLIP_SPEED) .. " с.")
end

------------------------------------------------------------------ Проверка UI под телефон (#34)
-- Обходит видимый интерфейс (кроме панели DEV): кнопки меньше пальца и текст мельче нормы — в
-- логических пикселях (размер ÷ произведение UIScale предков), пороги UIKit: в корне HUD/Tutorial
-- кнопка ≥ MIN_TOUCH 77, текст ≥ MIN_TEXT 25 (≈ 44 / 14 px на телефоне); в окнах (Panel_*) кнопка
-- ≥ 48, текст ≥ 24. Окна открываются по очереди сами. Запускать в эмуляторе телефона Studio
-- (844×390, 667×375) или на телефоне; список — в окне и в F9 (Client).
local function scaleOf(o: Instance): number
	local s = 1
	local p: Instance? = o
	while p and not p:IsA("LayerCollector") do
		local us = p:FindFirstChildOfClass("UIScale")
		if us then
			s *= us.Scale
		end
		p = p.Parent
	end
	return s
end
local function shown(o: GuiObject): boolean
	local p: Instance? = o
	while p and not p:IsA("LayerCollector") do
		if p:IsA("GuiObject") and not p.Visible then
			return false
		end
		p = p.Parent
	end
	return p ~= nil and (p :: ScreenGui).Enabled
end
local function panelOf(o: Instance): Instance?
	local p: Instance? = o
	while p and not p:IsA("LayerCollector") do
		if string.sub(p.Name, 1, 6) == "Panel_" then
			return p
		end
		p = p.Parent
	end
	return nil
end
local function auditVisible(found: { [string]: string })
	for _, sg in player.PlayerGui:GetChildren() do
		if not sg:IsA("ScreenGui") or sg == gui or not sg.Enabled then
			continue
		end
		for _, d in sg:GetDescendants() do
			if not d:IsA("GuiObject") or not shown(d) then
				continue
			end
			local k = scaleOf(d)
			local inPanel = panelOf(d) ~= nil
			local minTouch = if inPanel then UI.MIN_TOUCH_PANEL else UI.MIN_TOUCH
			local minText = if inPanel then UI.MIN_TEXT_PANEL else UI.MIN_TEXT
			local path = d:GetFullName():gsub("^.-PlayerGui%.", "")
			if d:IsA("GuiButton") and d.Active then
				local w, h = d.AbsoluteSize.X / k, d.AbsoluteSize.Y / k
				if math.min(w, h) < minTouch - 0.5 then
					found[path] = string.format("кнопка %d×%d < %d (%d px)", w, h, minTouch, math.min(d.AbsoluteSize.X, d.AbsoluteSize.Y))
				end
			end
			if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" and d.TextTransparency < 0.9 then
				local _, nl = string.gsub(d.Text, "\n", "")
				local px = d.TextBounds.Y / (nl + 1)
				if px > 0.5 and px / k < minText - 0.5 then
					found[path] = string.format("текст %d < %d (%d px): «%s»", px / k, minText, px, string.sub(d.Text, 1, 24))
				end
			end
		end
	end
end
local function auditUI(done: (string) -> ())
	task.spawn(function()
		local wasOpen = win.Visible
		win.Visible = false
		local found: { [string]: string } = {}
		task.wait(0.3)
		auditVisible(found)
		-- окна по очереди (содержимое — каким его оставили последний раз; размеры не зависят)
		local hud = player.PlayerGui:FindFirstChild("HUD")
		for _, w in (if hud then hud:GetChildren() else {}) do
			if w:IsA("GuiObject") and string.sub(w.Name, 1, 6) == "Panel_" and not w.Visible then
				w.Visible = true
				task.wait(0.15)
				auditVisible(found)
				w.Visible = false
			end
		end
		local lines = {}
		for path, what in found do
			table.insert(lines, path .. " — " .. what)
		end
		table.sort(lines)
		local vp = workspace.CurrentCamera.ViewportSize
		local head = string.format("Проверка UI %d×%d: %s", vp.X, vp.Y, if #lines == 0 then "всё ок" else #lines .. " замечаний")
		print("[UI-check] " .. head)
		for _, l in lines do
			print("[UI-check] " .. l)
		end
		win.Visible = wasOpen
		done(head .. (if #lines > 0 then "\n" .. table.concat(lines, "\n", 1, math.min(#lines, 40)) else ""))
	end)
end

tabs["Инструменты"] = function()
	heading("Интерфейс")
	local report = nil :: TextLabel?
	buttonRow({
		{ "blue", "Проверить UI (телефон)", function()
			auditUI(function(text)
				if report and report.Parent then
					report.Text = text
				end
			end)
		end },
	})
	report = note("Кнопки < 77 логических (44 px на телефоне) и текст < 25 (14 px); в окнах — 48 и 24. Запусти в эмуляторе 844×390 и 667×375: окна откроются по очереди, список — здесь и в F9.")
	heading("Валюта")
	buttonRow({
		{ "yellow", "+10 000 монет", function() dev("add", "Coins", 10000) end },
		{ "yellow", "+1 000 000 монет", function() dev("add", "Coins", 1000000) end },
		{ "blue", "+100 гемов", function() dev("add", "Gems", 100) end },
		{ "red", "Обнулить монеты", function() dev("add", "Coins", -1e12) end },
	})
	heading("Прокачка")
	buttonRow({
		{ "green", "Всё на максимум", function()
			for name, u in Config.UPGRADES do
				dev("setLevel", name, u.MaxLevel)
			end
		end },
		{ "grey", "Всё на 0", function()
			for name in Config.UPGRADES do
				dev("setLevel", name, 0)
			end
		end },
	})
	heading("Награды")
	buttonRow({
		{ "purple", "Сбросить задания, подарки и сундук", function() dev("resetDaily") end },
		{ "blue", "+5 мин сессии", function() dev("sessionShift") end },
		{ "blue", "Стрик: следующий день", function() dev("streakNext") end },
		{ "blue", "Стрик: пропуск дня", function() dev("streakSkip") end },
		{ "grey", "Сбросить обучение (и счётчик заездов)", function() dev("resetTutorial") end },
	})
	heading("Лидерборд недели")
	buttonRow({
		{ "yellow", "Титул: выдать себе топ-1", function() dev("weeklyTitle", 1) end },
		{ "grey", "Титул: топ-2", function() dev("weeklyTitle", 2) end },
		{ "orange", "Титул: топ-3", function() dev("weeklyTitle", 3) end },
		{ "red", "Титул: снять", function() dev("weeklyTitle", 0) end },
		{ "blue", "Табло: обновить сейчас", function() dev("weeklyRefresh") end },
	})
	note("Все действия меняют только твой профиль. Сервер проверяет, что ты — владелец игры; другим игрокам панель не видна и не работает.")
end

-- Настройка параметров игры: правка → сохранить (DataStore, все сервера).
-- Область: «для всех» (общий слой), «только я» / «игрок …» (персональный слой поверх общего).
local HttpService = game:GetService("HttpService")
local pending: { [string]: number }? = nil
local scope: "all" | "me" | "player" = "all"
local targetText = "" -- UserId или ник для области «игрок»
local targetInfo: { userId: number, name: string }? = nil -- кого нашли по targetText
local tuneGen = 0 -- отсекает устаревшие ответы сервера при перерисовке

local function decodeOverrides(raw: any): { [string]: number }
	local ok, data = pcall(HttpService.JSONDecode, HttpService, if typeof(raw) == "string" then raw else "{}")
	return if ok and type(data) == "table" then data else {}
end
local function globalOverrides(): { [string]: number }
	return decodeOverrides(ReplicatedStorage:GetAttribute("ConfigOverrides"))
end
local function fmt(v: number, step: number): string
	local dec = if step >= 1 then 0 elseif step >= 0.1 then 1 elseif step >= 0.01 then 2 else 3
	return string.format("%." .. dec .. "f", v)
end
local SCOPE_SAVE = { all = "СОХРАНИТЬ ДЛЯ ВСЕХ", me = "СОХРАНИТЬ ДЛЯ МЕНЯ", player = "СОХРАНИТЬ ДЛЯ ИГРОКА" }

-- Аргументы DevAction("tune"/"tuneGet") для текущей области
local function scopeArgs(): (string, any)
	if scope == "all" then
		return "all", nil
	elseif scope == "me" then
		return "player", player.UserId
	end
	return "player", targetText
end

-- Персональный слой для текущей области: «только я» — из своего атрибута, «игрок» — с сервера
-- (ник резолвит сервер, игрок может быть офлайн). Возвращает (набор, ошибка?)
local function loadPending(): ({ [string]: number }?, string?)
	if scope == "all" then
		return table.clone(globalOverrides()), nil
	elseif scope == "me" then
		targetInfo = { userId = player.UserId, name = player.Name }
		return table.clone(decodeOverrides(player:GetAttribute("ConfigOverrides"))), nil
	end
	targetInfo = nil
	if targetText == "" then
		return nil, "Укажи UserId или ник игрока"
	end
	local ok, res = UI.invoke(Remotes.DevAction, "tuneGet", targetText)
	if not ok or type(res) ~= "table" then
		return nil, tostring(res)
	end
	targetInfo = { userId = res.userId, name = res.name }
	return table.clone(res.overrides or {}), nil
end

tabs["Настройка"] = function()
	tuneGen += 1
	local gen = tuneGen
	heading("Настройка игры — меняется без перевыпуска")
	note("Область: «для всех» — общие значения на всех серверах; «только я» / «игрок» — персональный слой поверх общих (для проверки баланса на одном игроке). Измени значения (− / + или введи число) и сохрани. Жёлтым — отличается от базового значения.")
	-- выбор области
	local scopeRow = buttonRow({
		{ if scope == "all" then "green" else "dark", "ДЛЯ ВСЕХ", function()
			scope, pending = "all", nil
			tabs.redraw()
		end },
		{ if scope == "me" then "green" else "dark", "ТОЛЬКО Я", function()
			scope, pending = "me", nil
			tabs.redraw()
		end },
		{ if scope == "player" then "green" else "dark", "ИГРОК", function()
			scope, pending = "player", nil
			tabs.redraw()
		end },
	})
	local targetBox = UI.new("TextBox", { Text = targetText, PlaceholderText = "UserId или ник", Size = UDim2.fromOffset(220, 40), BackgroundColor3 = Color3.fromRGB(20, 28, 48), BackgroundTransparency = 0, TextScaled = false, TextSize = 17, Font = Enum.Font.GothamBold, TextColor3 = Color3.new(1, 1, 1), PlaceholderColor3 = Color3.fromRGB(120, 135, 165), ClearTextOnFocus = false, ZIndex = 53, Parent = scopeRow })
	UI.corner(targetBox, 10)
	targetBox.FocusLost:Connect(function()
		local text = string.gsub(targetBox.Text, "^%s+", "")
		text = string.gsub(text, "%s+$", "")
		if text ~= targetText then
			targetText, pending = text, nil
			if scope == "player" then
				tabs.redraw()
			end
		end
	end)

	local loadErr: string? = nil
	if not pending then
		local loading = if scope == "player" and targetText ~= "" then note("Загружаю настройки игрока…") else nil
		local loaded, err = loadPending()
		if gen ~= tuneGen then
			return -- пока ждали сервер, вкладку перерисовали (другая область/вкладка)
		end
		pending, loadErr = loaded, err
		if loading then
			loading:Destroy()
		end
	end
	local p = pending or {}
	pending = p
	local personal = scope ~= "all"
	-- базовый слой: для персональных областей — общие значения, для «всех» — значения из кода
	local base = if personal then globalOverrides() else {}
	local function baseOf(path: string): number
		return base[path] or Config.TUNABLE_DEFAULTS[path]
	end
	if loadErr then
		note("⚠ " .. loadErr).TextColor3 = Color3.fromRGB(255, 150, 150)
	elseif personal and targetInfo then
		note(string.format("Персональные настройки: %s (%d). Показаны эффективные значения; меняется только персональный слой, «базово» — общее значение.", targetInfo.name, targetInfo.userId))
	end

	local buttons = {
		{ "green", SCOPE_SAVE[scope], function()
			local sc, target = scopeArgs()
			dev("tune", p, sc, target)
			pending = nil
			task.delay(0.3, tabs.redraw)
		end },
		{ "grey", "ОТМЕНИТЬ ПРАВКИ", function()
			pending = nil
			tabs.redraw()
		end },
	}
	if personal then
		table.insert(buttons, { "red", "СБРОСИТЬ ПЕРСОНАЛЬНЫЕ", function()
			local sc, target = scopeArgs()
			dev("tune", {}, sc, target)
			pending = nil
			task.delay(0.3, tabs.redraw)
		end })
	else
		table.insert(buttons, { "red", "ВСЁ ПО УМОЛЧАНИЮ", function()
			pending = {}
			tabs.redraw()
		end })
	end
	buttonRow(buttons)
	local counter = note("")
	local function recount()
		local n = 0
		for _ in p do
			n += 1
		end
		counter.Text = (if personal then "Персональных параметров: " else "Изменено параметров: ") .. n .. (if n > 0 then " — не забудь сохранить" else "")
	end
	recount()
	local group = ""
	for _, tn in Config.TUNABLES do
		local path, label, grp, lo, hi, step = tn[1], tn[2], tn[3], tn[4], tn[5], tn[6]
		if grp ~= group then
			group = grp
			heading(grp)
		end
		local def = baseOf(path)
		local val = p[path] or def
		local row = UI.new("Frame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = if p[path] then Color3.fromRGB(90, 80, 40) else Color3.fromRGB(42, 56, 90), BackgroundTransparency = 0, ZIndex = 52, Parent = content })
		UI.corner(row, 8)
		UI.new("TextLabel", { Text = label, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -330, 1, 0), TextScaled = false, TextSize = 16, Font = Enum.Font.GothamMedium, TextColor3 = Color3.fromRGB(225, 235, 250), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 53, Parent = row })
		UI.new("TextLabel", { Text = (if personal then "базово " else "по умолч. ") .. fmt(def, step), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -230, 0.5, 0), Size = UDim2.fromOffset(100, 20), TextScaled = false, TextSize = 13, Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(150, 165, 195), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 53, Parent = row })
		local box = UI.new("TextBox", { Text = fmt(val, step), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -52, 0.5, 0), Size = UDim2.fromOffset(110, 30), BackgroundColor3 = Color3.fromRGB(20, 28, 48), BackgroundTransparency = 0, TextScaled = false, TextSize = 17, Font = Enum.Font.GothamBold, TextColor3 = Color3.new(1, 1, 1), ClearTextOnFocus = false, ZIndex = 53, Parent = row })
		UI.corner(box, 6)
		local function setV(nv: number)
			nv = math.clamp(math.floor(nv / step + 0.5) * step, lo, hi)
			if math.abs(nv - def) < step / 2 then
				p[path] = nil
			else
				p[path] = nv
			end
			box.Text = fmt(nv, step)
			row.BackgroundColor3 = if p[path] then Color3.fromRGB(90, 80, 40) else Color3.fromRGB(42, 56, 90)
			recount()
		end
		box.FocusLost:Connect(function()
			local nv = tonumber((string.gsub(box.Text, ",", ".")))
			setV(nv or (p[path] or def))
		end)
		for _, d in { -1, 1 } do
			local b = UI.button(if d < 0 then "dark" else "blue", if d < 0 then "−" else "+", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, if d < 0 then -168 else -8, 0.5, 0), Size = UDim2.fromOffset(38, 30), Radius = 6, StrokeThickness = 1.5, ZIndex = 53, Parent = row })
			b.Activated:Connect(function()
				setV((p[path] or def) + d * step)
			end)
		end
	end
end

------------------------------------------------------------------ Звуки (#52)
-- Все звуки игры по группам. ▶ играет через Sounds (BindableEvent «SoundTest») — тот же код и та же
-- громкость из Config.SOUND, что в игре. −/+ меняют громкость сразу (локально), «Сохранить для всех» пишет
-- их в TUNABLES «Звук: события» (как вкладка «Настройка»).
local SoundService = game:GetService("SoundService")
local AudioIds = require(Shared:WaitForChild("AudioSet")) :: any
local SOUND_GROUPS = {
	{ "Интерфейс", { "click", "open", "deny", "buy" } },
	{ "Награды", { "claim", "chest", "ready", "task", "reveal", "tierup", "finish", "record" } },
	{ "Трасса: подбор и бонусы", { "coin", "gem", "crystal", "shield", "shieldhit", "x2", "magnet", "fuel", "ring", "boost", "spring" } },
	{ "Действия", { "launch", "jump", "land", "spin", "flip", "wipe", "smash", "crash", "fall", "rocket_on", "rocket_off", "horn" } },
	{ "Лупы (звучат, пока включены)", { "wind", "snow", "ice", "hard", "rocket", "stretch", "car", "train" } },
}
local LOOP_SET = { wind = true, snow = true, ice = true, hard = true, rocket = true, stretch = true, car = true, train = true }
local soundPending: { [string]: number } = {} -- путь TUNABLES → новая громкость (ещё не сохранено)
local loopOn: string? = nil
local loopF = 1 -- доля скорости для проверки лупов (1 = loopFullSpeed)
local soundTest: BindableEvent? = nil

local function testSound(cmd: string, a: any?, b: any?, c: any?)
	if not soundTest then
		local sc = script.Parent:FindFirstChild("Sounds")
		soundTest = sc and sc:FindFirstChild("SoundTest") :: BindableEvent?
	end
	if soundTest then
		soundTest:Fire(cmd, a, b, c)
	else
		status.TextColor3 = Color3.fromRGB(255, 120, 120)
		status.Text = "Sounds ещё не запущен"
	end
end

local function soundSource(name: string): string
	local lib = Config.SOUND.library[name]
	if lib and lib > 0 then
		return "Roblox ID " .. lib
	end
	local r = AudioIds.regions[name]
	if not r then
		return "встроенный rbxasset"
	end
	if SoundService:GetAttribute("SoundSource") == "atlas" then
		return "атлас v2 · " .. tostring(r[4] or "")
	end
	return (if (AudioIds.atlas or 0) == 0 then "встроенный (атлас не загружен) · " else "встроенный (атлас грузится) · ") .. tostring(r[4] or "")
end

tabs["Звуки"] = function()
	heading("Звуки игры — как в игре")
	note("▶ — сыграть один раз тем же кодом, что в игре (с текущей громкостью канала и звука). Лупы: ▶/■ и доля скорости — громкость и тон скольжения/ветра зависят от скорости. Источник: Roblox ID (Config.SOUND.library) → атлас v2 (записи CC0/CC BY, assets/audio) → встроенные звуки, пока атлас не загружен. Громкость −/+ слышна сразу; сохранить — кнопкой ниже (это TUNABLES «Звук: события»), каналы и музыка — во вкладке «Настройка».")
	local n = 0
	for _ in soundPending do
		n += 1
	end
	buttonRow({
		{ "green", "СОХРАНИТЬ ДЛЯ ВСЕХ" .. (if n > 0 then " (" .. n .. ")" else ""), function()
			local merged = globalOverrides()
			for path, v in soundPending do
				merged[path] = v
			end
			dev("tune", merged, "all")
			table.clear(soundPending)
			task.delay(0.3, tabs.redraw)
		end },
		{ "grey", "ОТМЕНИТЬ ПРАВКИ", function()
			local g = globalOverrides()
			for path in soundPending do
				Config.setPath(path, g[path] or Config.TUNABLE_DEFAULTS[path])
			end
			table.clear(soundPending)
			tabs.redraw()
		end },
	})
	-- музыка
	heading("Музыка — Config.MUSIC_IDS (громкость " .. Config.MUSIC_VOLUME .. ", в заезде ×" .. Config.MUSIC_RUN_MULT .. ")")
	local mus = { { "dark", "КАК В ИГРЕ", function()
		testSound("music", nil)
	end }, { "blue", "ЛОББИ", function()
		testSound("music", 0)
	end } }
	for w = 1, #Config.THEMES do
		table.insert(mus, { "blue", "МИР " .. w, function()
			testSound("music", w)
		end })
	end
	buttonRow(mus)
	note("Треки: " .. table.concat(Config.MUSIC_IDS, ", ") .. " — первый в лобби, в заезде по миру. Не загрузился ни один — тихая «музыкальная шкатулка».")
	-- скорость для лупов
	heading("Скорость для проверки лупов")
	local speeds = {}
	for _, fr in { 0.1, 0.25, 0.5, 0.75, 1 } do
		table.insert(speeds, { if math.abs(loopF - fr) < 0.01 then "yellow" else "dark", string.format("%d%% · %d", fr * 100, fr * Config.SOUND.loopFullSpeed), function()
			loopF = fr
			if loopOn then
				testSound("loop", loopOn, true, loopF)
			end
			tabs.redraw()
		end })
	end
	buttonRow(speeds)

	for _, grp in SOUND_GROUPS do
		heading(grp[1])
		for _, name in grp[2] do
			local spec = Config.SOUND.sfx[name]
			if not spec then
				continue
			end
			local path = "SOUND.sfx." .. name .. ".1"
			local row = UI.new("Frame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = if soundPending[path] then Color3.fromRGB(90, 80, 40) else Color3.fromRGB(42, 56, 90), BackgroundTransparency = 0, ZIndex = 52, Parent = content })
			UI.corner(row, 8)
			UI.new("TextLabel", { Text = name, Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(110, 40), TextScaled = false, TextSize = 16, Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(255, 255, 255), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 53, Parent = row })
			UI.new("TextLabel", { Text = soundSource(name) .. "  ·  " .. spec[2], Position = UDim2.fromOffset(122, 0), Size = UDim2.new(1, -470, 1, 0), TextScaled = false, TextSize = 13, TextWrapped = true, Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(170, 190, 220), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 53, Parent = row })
			local vol = UI.new("TextLabel", { Text = string.format("%.2f", spec[1]), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -176, 0.5, 0), Size = UDim2.fromOffset(50, 30), TextScaled = false, TextSize = 17, Font = Enum.Font.GothamBold, TextColor3 = Color3.new(1, 1, 1), ZIndex = 53, Parent = row })
			for _, d in { -1, 1 } do
				local b = UI.button(if d < 0 then "dark" else "blue", if d < 0 then "−" else "+", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, if d < 0 then -228 else -134, 0.5, 0), Size = UDim2.fromOffset(36, 30), Radius = 6, StrokeThickness = 1.5, ZIndex = 53, Parent = row })
				b.Activated:Connect(function()
					local nv = math.clamp(math.floor((spec[1] + d * 0.05) * 20 + 0.5) / 20, 0, 1)
					Config.setPath(path, nv) -- слышно сразу: Sounds читает громкость при каждом проигрывании
					local base = globalOverrides()[path] or Config.TUNABLE_DEFAULTS[path]
					soundPending[path] = if math.abs(nv - base) < 0.025 then nil else nv
					vol.Text = string.format("%.2f", nv)
					row.BackgroundColor3 = if soundPending[path] then Color3.fromRGB(90, 80, 40) else Color3.fromRGB(42, 56, 90)
				end)
			end
			local isLoop = LOOP_SET[name] == true
			local playing = isLoop and loopOn == name
			local play = UI.button(if playing then "red" else "green", if isLoop then (if playing then "■" else "▶ луп") else "▶", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(110, 30), Radius = 6, StrokeThickness = 1.5, ZIndex = 53, Parent = row })
			play.Activated:Connect(function()
				if not isLoop then
					testSound("sfx", name)
					return
				end
				if loopOn then
					testSound("loop", loopOn, false)
				end
				loopOn = if loopOn == name then nil else name
				if loopOn then
					testSound("loop", loopOn, true, loopF)
				end
				tabs.redraw()
			end)
		end
	end
end
-- закрыли окно или ушли с вкладки — луп и выбор трека не должны звучать дальше
local function stopSoundTests()
	if loopOn then
		testSound("loop", loopOn, false)
		loopOn = nil
	end
	testSound("music", nil)
end
win:GetPropertyChangedSignal("Visible"):Connect(function()
	if not win.Visible then
		stopSoundTests()
	end
end)

local TAB_ORDER = { "Рогатка", "Сани", "Ракета", "Доход", "Миры", "Бонусы", "Трюки", "Звуки", "Настройка", "Инструменты" }
function tabs.redraw()
	clear()
	order = 0
	table.clear(spinning)
	for name, b in tabButtons do
		UI.setKind(b, if name == currentTab then "yellow" else "dark")
	end
	tabs[currentTab]()
end
for i, name in TAB_ORDER do
	local b = UI.button("dark", name, { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 46), Radius = 10, ZIndex = 52, Parent = tabsCol })
	tabButtons[name] = b
	b.Activated:Connect(function()
		if currentTab == "Звуки" and name ~= "Звуки" then
			stopSoundTests()
		end
		currentTab = name
		tabs.redraw()
	end)
end

openBtn.Activated:Connect(function()
	win.Visible = not win.Visible
	if win.Visible then
		tabs.redraw()
	end
end)
-- после изменения уровней перерисовываем (подсветка «СЕЙЧАС»)
for _, attr in { "LaunchLevel", "SledLevel", "RocketLevel", "IncomeLevel", "Level", "Sled", "SledRarity" } do
	player:GetAttributeChangedSignal(attr):Connect(function()
		if win.Visible then
			task.defer(tabs.redraw)
		end
	end)
end
