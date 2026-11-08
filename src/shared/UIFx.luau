-- Эффекты интерфейса («juice» как в мобильных казуалках): полёт монет к счётчику,
-- тикающие числа, вспышка выбора, открытие сундука, «нет»-покачивание, бамп.
-- Только клиент (нужен PlayerGui). Всё на TweenService / одном RenderStepped на эффект,
-- ничего не блокирует ввод, созданные инстансы уничтожаются по окончании.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UIKit"))

local UIFx = {}

-- Длительности (сек) и размеры — в одном месте
UIFx.T = {
	burst = 0.26, -- разлёт веером из точки
	flyMin = 0.42, -- полёт к цели
	flyJitter = 0.14,
	flyStagger = 0.045, -- разброс стартов между иконками
	bump = 0.28,
	tick = 0.45,
	stampHold = 0.7,
	shake = 0.055, -- один поворот сундука
	flash = 0.35,
}
UIFx.ICON = 36 -- пиксели летящей иконки

local function tween(o: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

------------------------------------------------------------------ слой поверх всех окон
local overlayRoot: Frame? = nil
local function layer(): Frame
	if overlayRoot and overlayRoot.Parent then
		return overlayRoot
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "UIFx"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100 -- выше HUD (0), DevPanel (30) и Reveal (40)
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local root = UI.new("Frame", { Name = "Root", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
	overlayRoot = root
	return root
end

-- Экранная точка → позиция внутри слоя (не зависит от GuiInset: вычитаем позицию самого слоя)
local function toLayer(root: Frame, p: Vector2): UDim2
	local o = root.AbsolutePosition
	return UDim2.fromOffset(p.X - o.X, p.Y - o.Y)
end
local function center(g: GuiObject): Vector2
	return g.AbsolutePosition + g.AbsoluteSize / 2
end
local function onScreen(g: GuiObject?): boolean
	if not g or not g:IsDescendantOf(game) then
		return false
	end
	local o: Instance? = g
	while o and o:IsA("GuiObject") do
		if not o.Visible then
			return false
		end
		o = o.Parent
	end
	return true
end
local function scaleOf(g: GuiObject): UIScale
	local s = g:FindFirstChildOfClass("UIScale")
	if not s then
		s = Instance.new("UIScale")
		s.Parent = g
	end
	return s :: UIScale
end

------------------------------------------------------------------ бамп цели (1 → 1.15 → 1)
function UIFx.bump(g: GuiObject, amount: number?)
	local s = scaleOf(g)
	local base = 1
	s.Scale = base * (amount or 1.15)
	tween(s, UIFx.T.bump, { Scale = base }, Enum.EasingStyle.Back)
end

------------------------------------------------------------------ сколько иконок за сумму
function UIFx.countFor(kind: string, amount: number): number
	if amount <= 0 then
		return 0
	end
	if kind == "gem" then
		return math.clamp(3 + amount // 2, 3, 10)
	end
	return math.clamp(5 + amount // 60, 5, 12)
end

-- Квадратичная кривая Безье
local function bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: number): Vector2
	local u = 1 - t
	return p0 * (u * u) + p1 * (2 * u * t) + p2 * (t * t)
end

------------------------------------------------------------------ полёт валюты к счётчику
-- kind: "coin" | "gem"; from: кнопка/точка старта; to: пилюля-счётчик; count: число иконок
-- (1–12); onArrive(last) вызывается на каждое прибытие, last = true для последней.
function UIFx.flyCurrency(kind: string, from: GuiObject | Vector2, to: GuiObject, count: number, onArrive: ((boolean) -> ())?)
	local n = math.clamp(math.floor(count), 1, 12)
	if UI.sfx then UI.sfx("claim") end
	if not onScreen(to) then
		-- цели не видно (например, идёт заезд) — считаем, что всё прилетело сразу
		if onArrive then
			onArrive(true)
		end
		return
	end
	local root = layer()
	local start: Vector2 = if typeof(from) == "Vector2" then from elseif onScreen(from :: GuiObject) then center(from :: GuiObject) else center(to) + Vector2.new(0, 120)
	local iconName = if kind == "gem" then "gem" else "coin"
	type Item = { gui: Frame, scale: UIScale, p1: Vector2, ctrl: Vector2, t0: number, dur: number, done: boolean }
	local items: { Item } = {}
	local now = os.clock()
	for i = 1, n do
		local gui = UI.icon(iconName, { AnchorPoint = Vector2.new(0.5, 0.5), Position = toLayer(root, start), Size = UDim2.fromOffset(UIFx.ICON, UIFx.ICON), Parent = root })
		local s = scaleOf(gui)
		s.Scale = 0.2
		-- веер: угол по кругу + случайный радиус
		local a = (i / n) * math.pi * 2 + math.random() * 0.5
		local r = 34 + math.random() * 56
		local p1 = start + Vector2.new(math.cos(a) * r, math.sin(a) * r * 0.8)
		tween(gui, UIFx.T.burst, { Position = toLayer(root, p1) }, Enum.EasingStyle.Back)
		tween(s, UIFx.T.burst, { Scale = 1 }, Enum.EasingStyle.Back)
		local dur = UIFx.T.flyMin + math.random() * UIFx.T.flyJitter
		local t0 = now + UIFx.T.burst + 0.04 + (i - 1) * UIFx.T.flyStagger
		-- контрольная точка дуги: середина пути, смещённая вверх и вбок
		local side = if i % 2 == 0 then 1 else -1
		local ctrl = (p1 + center(to)) / 2 + Vector2.new(side * (60 + math.random() * 90), -(80 + math.random() * 80))
		table.insert(items, { gui = gui, scale = s, p1 = p1, ctrl = ctrl, t0 = t0, dur = dur, done = false })
	end
	local left = n
	local conn: RBXScriptConnection
	local function finish(item: Item)
		if item.done then
			return
		end
		item.done = true
		item.gui:Destroy()
		left -= 1
		if to.Parent then
			UIFx.bump(to, if left == 0 then 1.18 else 1.08)
		end
		if onArrive then
			onArrive(left == 0)
		end
		if left == 0 then
			conn:Disconnect()
		end
	end
	conn = RunService.RenderStepped:Connect(function()
		if not to.Parent or not root.Parent then
			-- цель пропала — убираем всё, сообщаем о прибытии
			for _, it in items do
				finish(it)
			end
			if conn.Connected then
				conn:Disconnect()
			end
			return
		end
		local t = os.clock()
		local target = center(to)
		for _, it in items do
			if it.done then
				continue
			end
			local k = (t - it.t0) / it.dur
			if k < 0 then
				continue
			end
			if k >= 1 then
				finish(it)
				continue
			end
			local e = k * k -- разгон к цели
			it.gui.Position = toLayer(root, bezier(it.p1, it.ctrl, target, e))
			it.scale.Scale = 1 - 0.35 * e
		end
	end)
end

------------------------------------------------------------------ тикающее число
-- Плавно (ease-out) меняет текст label от from до to за duration; fmt получает дробное
-- промежуточное значение (округляй внутри fmt), в конце — ровно to. Новый тик на той же
-- метке отменяет предыдущий. Возвращает функцию отмены.
local ticks: { [TextLabel]: number } = setmetatable({}, { __mode = "k" }) :: any
function UIFx.tickNumber(label: TextLabel, from: number, to: number, duration: number, fmt: (number) -> string): () -> ()
	local token = (ticks[label] or 0) + 1
	ticks[label] = token
	if duration <= 0 or from == to then
		label.Text = fmt(to)
		return function() end
	end
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		if ticks[label] ~= token or not label.Parent then
			conn:Disconnect()
			return
		end
		local a = math.min((os.clock() - t0) / duration, 1)
		local e = 1 - (1 - a) ^ 3
		label.Text = fmt(if a >= 1 then to else from + (to - from) * e)
		if a >= 1 then
			conn:Disconnect()
		end
	end)
	return function()
		if ticks[label] == token then
			ticks[label] = token + 1
			conn:Disconnect()
		end
	end
end

------------------------------------------------------------------ вспышка выбора
-- Кольцо-обводка вспыхивает, карточка «подпрыгивает», штамп «ВЫБРАНО» прилетает и оседает.
function UIFx.pulseSelect(frame: GuiObject, stampText: string?)
	-- кольцо: отдельная рамка поверх карточки (у карточки уже может быть своя UIStroke)
	local ringBox = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = frame.ZIndex + 29, Parent = frame })
	local corner = frame:FindFirstChildOfClass("UICorner")
	UI.corner(ringBox, if corner then corner.CornerRadius.Offset else 14)
	local ring = UI.stroke(ringBox, 1, UI.C.gold, 0)
	tween(ring, 0.16, { Thickness = 7 }, Enum.EasingStyle.Back)
	task.delay(0.16, function()
		tween(ring, 0.45, { Thickness = 2, Transparency = 1 })
	end)
	task.delay(0.65, function()
		ringBox:Destroy()
	end)
	-- pop карточки
	local s = scaleOf(frame)
	s.Scale = 1.08
	tween(s, 0.32, { Scale = 1 }, Enum.EasingStyle.Back)
	-- штамп
	local stamp = UI.text({
		Text = stampText or "ВЫБРАНО",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 8, 0, 34),
		TextColor3 = UI.C.gold,
		Rotation = -8,
		Outline = 3,
		ZIndex = frame.ZIndex + 30,
		Parent = frame,
	})
	local ss = Instance.new("UIScale")
	ss.Scale = 2.4
	ss.Parent = stamp
	stamp.TextTransparency = 1
	tween(ss, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(stamp, 0.12, { TextTransparency = 0 })
	task.delay(0.3 + UIFx.T.stampHold, function()
		tween(stamp, 0.2, { TextTransparency = 1 })
		local outline = stamp:FindFirstChildOfClass("UIStroke")
		if outline then
			tween(outline, 0.2, { Transparency = 1 })
		end
		task.delay(0.22, function()
			stamp:Destroy()
		end)
	end)
end

------------------------------------------------------------------ сундук
local busyChests: { [GuiObject]: boolean } = setmetatable({}, { __mode = "k" }) :: any
-- Тряска (4 быстрых поворота ±6°), подскок, вспышка; onBurst — в момент вспышки.
function UIFx.openChest(chest: GuiObject, onBurst: () -> ())
	if busyChests[chest] then
		return
	end
	busyChests[chest] = true
	if UI.sfx then UI.sfx("chest") end
	local baseRot = chest.Rotation
	local s = scaleOf(chest)
	task.spawn(function()
		for _, r in { 6, -6, 6, -6, 0 } do
			local tw = tween(chest, UIFx.T.shake, { Rotation = baseRot + r }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			tw.Completed:Wait()
		end
		if not chest.Parent then
			busyChests[chest] = nil
			return
		end
		-- подскок
		tween(s, 0.14, { Scale = 1.22 }, Enum.EasingStyle.Back)
		task.wait(0.12)
		-- вспышка: белый круг из центра сундука
		local root = layer()
		local c = center(chest)
		local d = math.max(chest.AbsoluteSize.X, chest.AbsoluteSize.Y)
		local flash = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = toLayer(root, c), Size = UDim2.fromOffset(d * 0.4, d * 0.4), BackgroundColor3 = UI.C.white, BackgroundTransparency = 0.05, Parent = root })
		UI.corner(flash, 1000)
		tween(flash, UIFx.T.flash, { Size = UDim2.fromOffset(d * 2.6, d * 2.6), BackgroundTransparency = 1 })
		task.delay(UIFx.T.flash + 0.05, function()
			flash:Destroy()
		end)
		tween(s, 0.3, { Scale = 1 }, Enum.EasingStyle.Elastic)
		busyChests[chest] = nil
		onBurst()
	end)
end

-- Короткое покачивание «нет» (сундук ещё закрыт, кнопка недоступна)
function UIFx.shakeNo(g: GuiObject)
	if busyChests[g] then
		return
	end
	busyChests[g] = true
	if UI.sfx then UI.sfx("deny") end
	local baseRot = g.Rotation
	task.spawn(function()
		for _, r in { -5, 5, -3, 3, 0 } do
			tween(g, 0.05, { Rotation = baseRot + r }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut).Completed:Wait()
		end
		busyChests[g] = nil
	end)
end

------------------------------------------------------------------ вспышка квадратика (деление тира)
-- Квадратик «загорается»: белый → свой цвет, scale 1.5 → 1
function UIFx.lightUp(pip: GuiObject, color: Color3)
	local s = scaleOf(pip)
	s.Scale = 1.5
	pip.BackgroundColor3 = UI.C.white
	tween(s, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(pip, 0.4, { BackgroundColor3 = color })
end

return UIFx
