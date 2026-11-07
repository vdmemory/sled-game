-- Общий стиль интерфейса — как в мобильном оригинале:
--  • белый жирный текст с тёмной обводкой;
--  • объёмные кнопки (градиент сверху светлее) с тёмной окантовкой и «пружинкой»;
--  • голубые «ледяные» окна с лентой-заголовком и круглым красным крестиком;
--  • тёмно-синие полупрозрачные плашки валют с иконкой, вылезающей за край.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = {}

UI.FONT = Enum.Font.FredokaOne
UI.C = {
	white = Color3.new(1, 1, 1),
	ink = Color3.fromRGB(22, 34, 64), -- обводка и тёмный текст
	navy = Color3.fromRGB(28, 40, 72),
	panel = Color3.fromRGB(214, 234, 252), -- тело окна
	panelEdge = Color3.fromRGB(244, 250, 255),
	row = Color3.fromRGB(232, 243, 254), -- строки внутри окна
	ribbon = Color3.fromRGB(52, 120, 220),
	track = Color3.fromRGB(38, 56, 96),
	fill = Color3.fromRGB(60, 170, 255),
	cyan = Color3.fromRGB(70, 210, 255),
	gold = Color3.fromRGB(255, 205, 60),
}
-- Цвета кнопок: верх / низ градиента
UI.KIND = {
	blue = { Color3.fromRGB(95, 175, 255), Color3.fromRGB(40, 115, 225) },
	green = { Color3.fromRGB(140, 225, 85), Color3.fromRGB(65, 170, 45) },
	yellow = { Color3.fromRGB(255, 225, 90), Color3.fromRGB(245, 170, 30) },
	red = { Color3.fromRGB(255, 110, 100), Color3.fromRGB(215, 45, 45) },
	purple = { Color3.fromRGB(190, 120, 255), Color3.fromRGB(125, 65, 220) },
	orange = { Color3.fromRGB(255, 170, 70), Color3.fromRGB(240, 105, 35) },
	grey = { Color3.fromRGB(190, 196, 210), Color3.fromRGB(135, 142, 160) },
	dark = { Color3.fromRGB(70, 90, 135), Color3.fromRGB(40, 55, 95) },
	ice = { Color3.fromRGB(245, 251, 255), Color3.fromRGB(190, 222, 250) },
}

local CUSTOM = { Outline = true, Radius = true, StrokeThickness = true, Align = true, Color = true }

function UI.new(class: string, props: { [string]: any }?): any
	local o = Instance.new(class)
	if o:IsA("GuiObject") then
		(o :: any).BorderSizePixel = 0
	end
	if o:IsA("TextLabel") or o:IsA("TextButton") then
		local t = o :: any
		t.Font = UI.FONT
		t.TextColor3 = UI.C.white
		t.TextScaled = true
		t.BackgroundTransparency = 1
	end
	for k, v in props or {} do
		if k ~= "Parent" and not CUSTOM[k] then
			(o :: any)[k] = v
		end
	end
	if props and props.Parent then
		o.Parent = props.Parent
	end
	return o
end

function UI.corner(o: GuiObject, r: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = if r and r >= 1000 then UDim.new(0.5, 0) else UDim.new(0, r or 12)
	c.Parent = o
	return c
end

function UI.stroke(o: GuiObject, thickness: number?, color: Color3?, transparency: number?)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 2
	s.Color = color or UI.C.ink
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = o
	return s
end

-- Обводка текста (как у всех надписей оригинала)
function UI.outline(o: TextLabel | TextButton, thickness: number?)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 2
	s.Color = UI.C.ink
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Parent = o
	return s
end

function UI.grad(o: GuiObject, top: Color3, bottom: Color3)
	o.BackgroundColor3 = UI.C.white
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(top, bottom)
	g.Parent = o
	return g
end

function UI.pad(o: GuiObject, px: number)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.Parent = o
	return p
end

-- Белый текст с обводкой
function UI.text(props: { [string]: any }): TextLabel
	local t = UI.new("TextLabel", props)
	if props.TextColor3 == nil or props.TextColor3 == UI.C.white then
		UI.outline(t, props.Outline or 2)
	end
	return t
end
-- Тёмный текст без обводки (внутри светлых окон)
function UI.ink(props: { [string]: any }): TextLabel
	props.TextColor3 = props.TextColor3 or UI.C.ink
	return UI.new("TextLabel", props)
end

-- «Пружинка» при нажатии
function UI.bounce(b: GuiButton)
	local scale = b:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = b
	b.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.07), { Scale = 0.92 }):Play()
	end)
	local function up()
		TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	b.MouseButton1Up:Connect(up)
	b.MouseLeave:Connect(up)
end

-- Объёмная кнопка: градиент, тёмная окантовка, светлая полоска сверху, текст с обводкой
function UI.button(kind: string, text: string, props: { [string]: any }): TextButton
	local b = UI.new("TextButton", props)
	b.Text = ""
	b.AutoButtonColor = false
	b.BackgroundTransparency = 0
	local k = UI.KIND[kind] or UI.KIND.blue
	local g = UI.grad(b, k[1], k[2])
	g.Name = "Fill"
	UI.corner(b, props.Radius or 14)
	UI.stroke(b, props.StrokeThickness or 3)
	local shine = UI.new("Frame", {
		Name = "Shine",
		BackgroundColor3 = UI.C.white,
		BackgroundTransparency = 0.6,
		Position = UDim2.new(0, 6, 0, 3),
		Size = UDim2.new(1, -12, 0, 4),
		ZIndex = b.ZIndex + 1,
		Parent = b,
	})
	UI.corner(shine, 1000)
	UI.text({
		Name = "Label",
		Text = text,
		Position = UDim2.new(0, 8, 0, 4),
		Size = UDim2.new(1, -16, 1, -8),
		ZIndex = b.ZIndex + 2,
		Parent = b,
	})
	UI.bounce(b)
	return b
end
function UI.setKind(b: GuiObject, kind: string)
	local g = b:FindFirstChild("Fill") :: UIGradient?
	local k = UI.KIND[kind] or UI.KIND.blue
	if g then
		g.Color = ColorSequence.new(k[1], k[2])
	end
end
-- Текст кнопки; с icon — иконка + текст в строку (цены «[монета] 600» вместо «💰 600»)
local iconSetters = setmetatable({}, { __mode = "k" })
function UI.setText(b: GuiObject, text: string, icon: string?)
	local l = b:FindFirstChild("Label") :: TextLabel?
	local set = iconSetters[b]
	if icon and not set then
		local h = if b.Size.Y.Offset > 0 then b.Size.Y.Offset - 14 else 22
		local _, setter = UI.iconText({ Name = "IconText", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -12, 0, h), ZIndex = b.ZIndex + 2, Parent = b })
		iconSetters[b] = setter
		set = setter
	end
	local holder = b:FindFirstChild("IconText")
	if icon and set then
		set(text, icon)
		if holder then
			holder.Visible = true
		end
		if l then
			l.Visible = false
		end
	else
		if holder then
			holder.Visible = false
		end
		if l then
			l.Visible = true
			l.Text = text
		end
	end
end

-- Круглый красный крестик (как в оригинале)
function UI.closeButton(parent: GuiObject, onClick: () -> ()): TextButton
	local b = UI.new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(50, 50),
		BackgroundTransparency = 0,
		ZIndex = parent.ZIndex + 10,
		Parent = parent,
	})
	UI.grad(b, UI.KIND.red[1], UI.KIND.red[2])
	UI.corner(b, 1000)
	UI.stroke(b, 3, UI.C.white)
	UI.text({ Text = "X", Position = UDim2.fromScale(0.22, 0.18), Size = UDim2.fromScale(0.56, 0.64), ZIndex = b.ZIndex + 1, Parent = b })
	UI.bounce(b)
	b.Activated:Connect(onClick)
	return b
end

-- Окно: голубое тело, белая кромка, лента-заголовок посередине сверху, круглый крестик.
-- Возвращает (окно, тело, лента-текст)
function UI.panel(parent: Instance, title: string, w: number, h: number, z: number?): (Frame, Frame, TextLabel)
	local zi = z or 30
	local root = UI.new("Frame", {
		Name = "Panel_" .. title,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(w, h),
		BackgroundTransparency = 0,
		Visible = false,
		ZIndex = zi,
		Parent = parent,
	})
	UI.grad(root, UI.C.panelEdge, UI.C.panel)
	UI.corner(root, 22)
	UI.stroke(root, 4, UI.C.ink)
	local inner = UI.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(5, 5),
		Size = UDim2.new(1, -10, 1, -10),
		ZIndex = zi,
		Parent = root,
	})
	UI.corner(inner, 18)
	UI.stroke(inner, 2, UI.C.white, 0.2)
	local scale = Instance.new("UIScale")
	scale.Parent = root
	local cam = workspace.CurrentCamera
	local function fit()
		local vp = cam.ViewportSize
		scale.Scale = math.min(1, (vp.X - 24) / w, (vp.Y - 60) / (h + 30))
	end
	cam:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	fit()
	-- лента
	local ribbon = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 2),
		Size = UDim2.fromOffset(math.min(w - 120, 360), 54),
		BackgroundTransparency = 0,
		ZIndex = zi + 3,
		Parent = root,
	})
	UI.grad(ribbon, Color3.fromRGB(85, 160, 250), UI.C.ribbon)
	UI.corner(ribbon, 12)
	UI.stroke(ribbon, 3)
	local titleLabel = UI.text({
		Text = title,
		Position = UDim2.new(0, 14, 0, 7),
		Size = UDim2.new(1, -28, 1, -14),
		ZIndex = zi + 4,
		Parent = ribbon,
	})
	UI.closeButton(root, function()
		root.Visible = false
	end)
	local body = UI.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 44),
		Size = UDim2.new(1, -36, 1, -60),
		ZIndex = zi + 1,
		Parent = root,
	})
	return root, body, titleLabel
end

-- Полоса прогресса: тёмная дорожка, голубая заливка, белый текст «34/40»
function UI.progress(parent: Instance, props: { [string]: any }): (Frame, (number, string?) -> ())
	local track = UI.new("Frame", props)
	track.BackgroundColor3 = UI.C.track
	track.BackgroundTransparency = 0
	UI.corner(track, 1000)
	UI.stroke(track, 2)
	local fill = UI.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundTransparency = 0, ZIndex = track.ZIndex + 1, Parent = track })
	UI.grad(fill, Color3.fromRGB(110, 210, 255), Color3.fromRGB(40, 140, 240))
	UI.corner(fill, 1000)
	local label = UI.text({ Text = "", Position = UDim2.new(0, 4, 0, 1), Size = UDim2.new(1, -8, 1, -2), ZIndex = track.ZIndex + 2, Parent = track })
	track.Parent = parent
	local function set(frac: number, text: string?)
		fill.Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1)
		fill.Visible = frac > 0.001
		label.Text = text or ""
	end
	return track, set
end

-- Плашка валюты: тёмно-синяя, иконка-кружок вылезает слева
-- Нарисованная монета: золотой круг с ободком, внутренним кольцом и звездой
function UI.coin(parent: Instance, props: { [string]: any }): Frame
	local c = UI.new("Frame", props)
	c.BackgroundTransparency = 0
	c.Parent = parent
	UI.grad(c, Color3.fromRGB(255, 230, 90), Color3.fromRGB(240, 160, 20))
	UI.corner(c, 1000)
	UI.stroke(c, 2.5, Color3.fromRGB(150, 85, 10))
	local inner = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.7, 0.7), BackgroundTransparency = 0, ZIndex = c.ZIndex + 1, Parent = c })
	UI.grad(inner, Color3.fromRGB(250, 195, 40), Color3.fromRGB(255, 225, 95))
	UI.corner(inner, 1000)
	UI.stroke(inner, 1.5, Color3.fromRGB(205, 130, 20))
	UI.new("TextLabel", { Text = "★", TextColor3 = Color3.fromRGB(255, 245, 190), Position = UDim2.fromScale(0.12, 0.08), Size = UDim2.fromScale(0.76, 0.8), ZIndex = c.ZIndex + 2, Parent = inner })
	-- блик
	local shine = UI.new("Frame", { Position = UDim2.fromScale(0.2, 0.12), Size = UDim2.fromScale(0.28, 0.16), Rotation = -30, BackgroundColor3 = UI.C.white, BackgroundTransparency = 0.35, ZIndex = c.ZIndex + 3, Parent = c })
	UI.corner(shine, 1000)
	return c
end

-- Нарисованный сундук: деревянный корпус и крышка, металлические полосы и замок
function UI.chest(parent: Instance, props: { [string]: any }): Frame
	local box = UI.new("Frame", props)
	box.BackgroundTransparency = 1
	box.Parent = parent
	local z = box.ZIndex
	local wood1, wood2 = Color3.fromRGB(205, 130, 60), Color3.fromRGB(150, 85, 35)
	local metal1, metal2 = Color3.fromRGB(225, 230, 240), Color3.fromRGB(140, 150, 170)
	local ink = Color3.fromRGB(60, 35, 20)
	-- корпус
	local body = UI.new("Frame", { Position = UDim2.fromScale(0.04, 0.42), Size = UDim2.fromScale(0.92, 0.54), BackgroundTransparency = 0, ZIndex = z + 1, Parent = box })
	UI.grad(body, wood1, wood2)
	UI.corner(body, 6)
	UI.stroke(body, 2.5, ink)
	-- крышка (скруглённая сверху)
	local lid = UI.new("Frame", { Position = UDim2.fromScale(0.04, 0.06), Size = UDim2.fromScale(0.92, 0.42), BackgroundTransparency = 0, ZIndex = z + 2, Parent = box })
	UI.grad(lid, Color3.fromRGB(225, 150, 75), wood1)
	local lc = Instance.new("UICorner")
	lc.CornerRadius = UDim.new(0.45, 0)
	lc.Parent = lid
	UI.stroke(lid, 2.5, ink)
	-- доски крышки
	local plank = UI.new("Frame", { Position = UDim2.fromScale(0.08, 0.45), Size = UDim2.fromScale(0.84, 0.06), BackgroundColor3 = wood2, BackgroundTransparency = 0.3, ZIndex = z + 3, Parent = lid })
	local _ = plank
	-- металлические полосы по краям и окантовка крышки
	for _, x in { 0.1, 0.78 } do
		for _, part in { { lid, 0 }, { body, 0 } } do
			local band = UI.new("Frame", { Position = UDim2.fromScale(x, 0), Size = UDim2.new(0.12, 0, 1, 0), BackgroundTransparency = 0, ZIndex = z + 4, Parent = part[1] })
			UI.grad(band, metal1, metal2)
			UI.stroke(band, 1.5, ink)
		end
	end
	local rim = UI.new("Frame", { Position = UDim2.fromScale(0.02, 0.4), Size = UDim2.fromScale(0.96, 0.1), BackgroundTransparency = 0, ZIndex = z + 5, Parent = box })
	UI.grad(rim, metal1, metal2)
	UI.corner(rim, 3)
	UI.stroke(rim, 1.5, ink)
	-- замок
	local lock = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromScale(0.2, 0.3), BackgroundTransparency = 0, ZIndex = z + 6, Parent = box })
	UI.grad(lock, metal1, metal2)
	UI.corner(lock, 4)
	UI.stroke(lock, 1.5, ink)
	local hole = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromScale(0.3, 0.3), BackgroundColor3 = ink, BackgroundTransparency = 0, ZIndex = z + 7, Parent = lock })
	UI.corner(hole, 1000)
	return box
end

-- Плашка валюты как в оригинале: тёмная капсула, крупная иконка вылезает слева,
-- белое число с обводкой. icon = "coin" рисует монету, иначе — эмодзи.
function UI.currency(parent: Instance, icon: string, props: { [string]: any }): TextLabel
	local f = UI.new("Frame", props)
	f.BackgroundColor3 = UI.C.navy
	f.BackgroundTransparency = 0.15
	UI.corner(f, 1000)
	UI.stroke(f, 2, Color3.fromRGB(10, 18, 40), 0.3)
	f.Parent = parent
	local h = if props.Size and props.Size.Y.Offset > 0 then props.Size.Y.Offset else 38
	local d = math.floor(h * 1.25)
	UI.icon(icon, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 6, 0.5, 0), Size = UDim2.fromOffset(d + 6, d + 6), ZIndex = f.ZIndex + 2, Parent = f })
	return UI.text({ Text = "0", Position = UDim2.new(0, d / 2 + 12, 0, 5), Size = UDim2.new(1, -(d / 2 + 22), 1, -10), Outline = 2.5, ZIndex = f.ZIndex + 1, Parent = f })
end

-- Плитка меню как в оригинале: голубой квадрат с градиентом, светлой рамкой и бликом
function UI.tile(parent: Instance, icon: string, props: { [string]: any }): TextButton
	local b = UI.new("TextButton", props)
	b.Text = ""
	b.AutoButtonColor = false
	b.BackgroundTransparency = 0
	UI.grad(b, Color3.fromRGB(205, 238, 255), Color3.fromRGB(140, 200, 245))
	UI.corner(b, 18)
	UI.stroke(b, 3.5, Color3.fromRGB(235, 248, 255))
	b.Parent = parent
	-- внешняя тёмная окантовка (вторая рамка чуть больше плитки)
	local edge = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 7, 1, 7), BackgroundTransparency = 1, ZIndex = b.ZIndex, Parent = b })
	UI.corner(edge, 21)
	UI.stroke(edge, 2, Color3.fromRGB(70, 120, 185), 0.2)
	-- блик в верхней половине
	local shine = UI.new("Frame", { Position = UDim2.fromOffset(6, 5), Size = UDim2.new(1, -12, 0.42, 0), BackgroundColor3 = UI.C.white, BackgroundTransparency = 0.55, ZIndex = b.ZIndex + 1, Parent = b })
	UI.corner(shine, 14)
	local sg = Instance.new("UIGradient")
	sg.Rotation = 90
	sg.Transparency = NumberSequence.new(0.1, 1)
	sg.Parent = shine
	UI.icon(icon, { Name = "Icon", Position = UDim2.fromScale(0.1, 0.08), Size = UDim2.fromScale(0.8, 0.8), ZIndex = b.ZIndex + 2, Parent = b })
	UI.bounce(b)
	return b
end
function UI.badge(parent: GuiObject, text: string, kind: string?): TextLabel
	local f = UI.new("TextLabel", {
		Text = text,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(if #text > 2 then 66 else 32, 30),
		BackgroundTransparency = 0,
		ZIndex = parent.ZIndex + 5,
		Parent = parent,
	})
	local k = UI.KIND[kind or "red"]
	UI.grad(f, k[1], k[2])
	UI.corner(f, 1000)
	UI.stroke(f, 2.5, UI.C.white).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	UI.outline(f, 1.5)
	-- текст с запасом внутри плашки: обводка букв не вылезает за край
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, 8)
	p.PaddingRight = UDim.new(0, 8)
	p.PaddingTop = UDim.new(0, 5)
	p.PaddingBottom = UDim.new(0, 5)
	p.Parent = f
	return f
end

-- Всплывающее открытие окна
function UI.pop(o: GuiObject)
	local s = o:FindFirstChildOfClass("UIScale")
	if not s then
		return
	end
	local target = s.Scale
	s.Scale = target * 0.8
	TweenService:Create(s, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = target }):Play()
end

function UI.money(n: number): string
	local s
	if n >= 1000000 then
		s = string.format("%.1fM", n / 1000000)
	elseif n >= 1000 then
		s = string.format("%.1fK", n / 1000)
	else
		return tostring(n)
	end
	return (string.gsub(s, "%.0([KM])", "%1"))
end

-- ВЕРХНИЙ РЕГИСТР с кириллицей (string.upper в Roblox меняет только латиницу)
function UI.upper(s: string): string
	local out = {}
	for _, c in utf8.codes(s) do
		if c >= 0x430 and c <= 0x44F then
			c -= 0x20
		elseif c == 0x451 then
			c = 0x401
		elseif c >= 97 and c <= 122 then
			c -= 32
		end
		table.insert(out, utf8.char(c))
	end
	return table.concat(out)
end

------------------------------------------------------------------ 3D-иконки (Fluent Emoji)
-- Картинки грузит деплой (assets/ui → декали), сервер отдаёт ID в ReplicatedStorage.UIImages.
-- Пока картинки нет или она не загрузилась — показываем эмодзи-заглушку (или нарисованную монету).
UI.EMOJI = {
	coin = "💰", gem = "💎", globe = "🌍", tasks = "📋", sled = "🛷", sparkles = "✨", gift = "🎁",
	gear = "⚙", palette = "🎨", bullseye = "🎯", moneybag = "💰", rocket = "🚀", fire = "🔥",
	flip = "🔄", flag = "🏁", magnet = "🧲", trophy = "🏆", check = "✅", lock = "🔒", party = "🎉",
	tree = "🌲", city = "🏙", cactus = "🌵", mountain = "🏔", parachute = "🪂", smash = "💥",
	speaker = "🔊", music = "🎵", snowflake = "❄", moon = "🌗", donut = "🍩", snowboard = "🏂",
	plane = "✈", star = "⭐", bolt = "⚡", stopwatch = "⏱", hourglass = "⏳", ice = "🧊", ringbuoy = "🛟",
	shield = "🛡", saucer = "🥏", canoe = "🛶", racecar = "🏎", scooter = "🛵", aurora = "🌌", volcano = "🌋",
	candy = "🍭", fuel = "⛽", toboggan = "🪵", ring = "💍",
}
local imagesFolder: Folder? = nil
local waiting: { () -> () } = {}
-- Загрузку проверяем через ContentProvider (свойство IsLoaded у невидимых картинок не меняется)
local loaded: { [string]: boolean } = {}
local function preloadAll(f: Instance)
	local ids = {}
	for k, v in f:GetAttributes() do
		if string.sub(k, 1, 1) ~= "_" and typeof(v) == "string" and loaded[v] == nil then
			loaded[v] = false
			table.insert(ids, v)
		end
	end
	if #ids == 0 then
		return
	end
	task.spawn(function()
		pcall(function()
			game:GetService("ContentProvider"):PreloadAsync(ids, function(id, status)
				if status == Enum.AssetFetchStatus.Success then
					loaded[id] = true
				end
			end)
		end)
		for _, fn in waiting do
			fn()
		end
	end)
end
task.spawn(function()
	local f = ReplicatedStorage:WaitForChild("UIImages", 60)
	if f then
		imagesFolder = f :: Folder
		preloadAll(f)
		f.AttributeChanged:Connect(function()
			preloadAll(f)
		end)
		task.delay(20, function()
			local n = 0
			for k in f:GetAttributes() do
				if string.sub(k, 1, 1) ~= "_" then
					n += 1
				end
			end
			local ok = 0
			for _, v in loaded do
				if v then
					ok += 1
				end
			end
			print("[UIImages] картинок:", n, "загружено:", ok, "ошибка:", f:GetAttribute("_err"))
		end)
		for _, fn in waiting do
			fn()
		end
		f.AttributeChanged:Connect(function()
			for _, fn in waiting do
				fn()
			end
		end)
	end
end)

function UI.icon(name: string, props: { [string]: any }): Frame
	local f = UI.new("Frame", props)
	f.BackgroundTransparency = 1
	local z = f.ZIndex
	-- заглушки: нарисованная монета для "coin", эмодзи для остального (иконку можно менять на лету)
	local drawnCoin = UI.coin(f, { Name = "FallbackCoin", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.86, 0.86), ZIndex = z })
	local emoji = UI.new("TextLabel", { Name = "Fallback", Text = "", Size = UDim2.fromScale(1, 1), ZIndex = z, Parent = f })
	local img = UI.new("ImageLabel", { Name = "Image", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Fit, ImageTransparency = 1, ZIndex = z, Parent = f })
	f:SetAttribute("Icon", name)
	local apply
	function apply()
		local n = f:GetAttribute("Icon")
		local id = imagesFolder and n and imagesFolder:GetAttribute(n)
		if typeof(id) == "string" then
			if img.Image ~= id then
				img.Image = id
			end
		else
			img.Image = ""
		end
		-- показываем картинку только когда она реально загрузилась
		local ready = img.Image ~= "" and (loaded[img.Image] == true or img.IsLoaded)
		img.ImageTransparency = if ready then 0 else 1
		drawnCoin.Visible = not ready and n == "coin"
		emoji.Visible = not ready and n ~= "coin"
		emoji.Text = UI.EMOJI[n] or ""
	end
	img:GetPropertyChangedSignal("IsLoaded"):Connect(apply)
	f:GetAttributeChangedSignal("Icon"):Connect(apply)
	table.insert(waiting, apply)
	f.Destroying:Connect(function()
		local i = table.find(waiting, apply)
		if i then
			table.remove(waiting, i)
		end
	end)
	apply()
	f.Parent = props.Parent
	return f
end
function UI.setIcon(f: Instance, name: string)
	f:SetAttribute("Icon", name)
end

-- Иконка + число в строку, по центру (цены, награды): set(текст, иконка?)
function UI.iconText(props: { [string]: any }): (Frame, (string, string?) -> ())
	local f = UI.new("Frame", props)
	f.BackgroundTransparency = 1
	local h = if props.Size then props.Size.Y.Offset else 24
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.HorizontalAlignment = props.Align or Enum.HorizontalAlignment.Center
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.Padding = UDim.new(0, 4)
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = f
	local icon = UI.icon("coin", { LayoutOrder = 1, Size = UDim2.fromOffset(h + 2, h + 2), ZIndex = f.ZIndex + 1, Parent = f })
	local label = UI.new("TextLabel", {
		LayoutOrder = 2,
		Text = "",
		TextScaled = false,
		TextSize = math.floor(h * 0.86),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, h),
		TextColor3 = props.Color or UI.C.white,
		ZIndex = f.ZIndex + 1,
		Parent = f,
	})
	if props.Outline or (props.Color or UI.C.white) == UI.C.white then
		UI.outline(label, props.Outline or 2)
	end
	local function set(text: string, iconName: string?)
		label.Text = text
		icon.Visible = iconName ~= nil
		if iconName then
			UI.setIcon(icon, iconName)
		end
	end
	set("", "coin")
	f.Parent = props.Parent
	return f, set
end

return UI
