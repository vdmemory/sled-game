-- Общий стиль интерфейса — как в мобильном оригинале:
--  • белый жирный текст с тёмной обводкой;
--  • объёмные кнопки (градиент сверху светлее) с тёмной окантовкой и «пружинкой»;
--  • голубые «ледяные» окна с лентой-заголовком и круглым красным крестиком;
--  • тёмно-синие полупрозрачные плашки валют с иконкой, вылезающей за край.

local TweenService = game:GetService("TweenService")

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

local CUSTOM = { Outline = true, Radius = true, StrokeThickness = true }

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
	local label = UI.text({
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
function UI.setText(b: GuiObject, text: string)
	local l = b:FindFirstChild("Label") :: TextLabel?
	if l then
		l.Text = text
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
	for _, side in { -1, 1 } do -- «хвостики» ленты
		local tail = UI.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(if side < 0 then 0 else 1, side * 10, 0.5, 8),
			Size = UDim2.fromOffset(30, 34),
			BackgroundColor3 = Color3.fromRGB(35, 90, 180),
			ZIndex = zi + 2,
			Parent = ribbon,
		})
		UI.corner(tail, 6)
		UI.stroke(tail, 3)
	end
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
function UI.currency(parent: Instance, icon: string, props: { [string]: any }): TextLabel
	local f = UI.new("Frame", props)
	f.BackgroundColor3 = UI.C.navy
	f.BackgroundTransparency = 0.25
	UI.corner(f, 1000)
	f.Parent = parent
	UI.text({ Text = icon, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 4, 0.5, 0), Size = UDim2.fromOffset(46, 46), ZIndex = f.ZIndex + 2, Parent = f })
	return UI.text({ Text = "0", Position = UDim2.new(0, 30, 0, 6), Size = UDim2.new(1, -40, 1, -12), ZIndex = f.ZIndex + 1, Parent = f })
end

-- Квадратная «ледяная» плитка-иконка (левая/правая колонка лобби)
function UI.tile(parent: Instance, icon: string, props: { [string]: any }): TextButton
	local b = UI.new("TextButton", props)
	b.Text = ""
	b.AutoButtonColor = false
	b.BackgroundTransparency = 0
	UI.grad(b, UI.KIND.ice[1], UI.KIND.ice[2])
	UI.corner(b, 16)
	UI.stroke(b, 3, Color3.fromRGB(90, 150, 220))
	b.Parent = parent
	UI.text({ Name = "Icon", Text = icon, Position = UDim2.fromScale(0.12, 0.1), Size = UDim2.fromScale(0.76, 0.76), ZIndex = b.ZIndex + 1, Parent = b })
	UI.bounce(b)
	return b
end

-- Бейдж в углу (NEW, %, !, число)
function UI.badge(parent: GuiObject, text: string, kind: string?): TextLabel
	local f = UI.new("TextLabel", {
		Text = text,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(if #text > 2 then 54 else 30, 28),
		BackgroundTransparency = 0,
		ZIndex = parent.ZIndex + 5,
		Parent = parent,
	})
	local k = UI.KIND[kind or "red"]
	UI.grad(f, k[1], k[2])
	UI.corner(f, 1000)
	UI.stroke(f, 2, UI.C.white)
	UI.outline(f, 1.5)
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

return UI
