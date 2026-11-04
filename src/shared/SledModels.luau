-- Детализированные 3D-модели саней из примитивов Roblox (без загрузки мешей —
-- работает с автодеплоем). Плавные формы собираются из «трубок»: цилиндры между
-- точками + шарики в стыках, поэтому тор ватрушки и изогнутые полозья выглядят гладкими.
--
-- SledModels.build(parent, base, id, look, weldTo?)
--   base   — CFrame центра саней (низ корпуса ≈ base.Y − 0.5), «нос» смотрит по −Z
--   look   — { main: Color3, accent: Color3, material: Enum.Material?, glow: boolean? }
--   weldTo — если задан, детали привариваются к нему (санки в заезде), иначе закреплены (витрина)

local SledModels = {}

type Look = { main: Color3, accent: Color3, material: Enum.Material?, glow: boolean?, shine: number? }

local WOOD = Color3.fromRGB(186, 128, 74)
local WOOD_DARK = Color3.fromRGB(140, 92, 50)
local STEEL = Color3.fromRGB(70, 74, 86)
local BLACK = Color3.fromRGB(32, 34, 40)
local WHITE = Color3.fromRGB(245, 247, 250)

-- Контекст сборки: куда класть, к чему приваривать
local Builder = {}
Builder.__index = Builder

local function newBuilder(parent: Instance, base: CFrame, weldTo: BasePart?)
	return setmetatable({ parent = parent, base = base, weldTo = weldTo, count = 0, main = nil, shine = 0 }, Builder)
end

function Builder:part(shape: Enum.PartType, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, props: { [string]: any }?): BasePart
	local p = Instance.new("Part")
	p.Shape = shape
	p.Size = size
	p.CFrame = self.base * cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = size.Magnitude > 1.5 -- мелкие детали без теней: заметно дешевле на телефонах
	p.Massless = true
	p.CollisionGroup = "Riders"
	if self.main and color == self.main then
		p.Reflectance = self.shine -- глянец корпуса (Gold, Diamond)
	end
	for k, v in props or {} do
		(p :: any)[k] = v
	end
	if self.weldTo then
		p.Anchored = false
		local w = Instance.new("WeldConstraint")
		w.Part0 = self.weldTo
		w.Part1 = p
		w.Parent = p
	else
		p.Anchored = true
	end
	p.Parent = self.parent
	self.count += 1
	return p
end

function Builder:block(size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, props: { [string]: any }?): BasePart
	return self:part(Enum.PartType.Block, size, cf, color, material, props)
end
function Builder:ball(d: number, cf: CFrame, color: Color3, material: Enum.Material?): BasePart
	return self:part(Enum.PartType.Ball, Vector3.new(d, d, d), cf, color, material)
end
-- Цилиндр вдоль оси dir (локальной), центр в pos
function Builder:cyl(d: number, len: number, pos: Vector3, dir: Vector3, color: Color3, material: Enum.Material?): BasePart
	local x = dir.Unit
	local up = if math.abs(x.Y) > 0.95 then Vector3.zAxis else Vector3.yAxis
	local z = x:Cross(up).Unit
	local y = z:Cross(x).Unit
	return self:part(Enum.PartType.Cylinder, Vector3.new(len, d, d), CFrame.fromMatrix(pos, x, y, z), color, material)
end
-- Эллипсоид (шар, растянутый мешем)
function Builder:ellipsoid(size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): BasePart
	local p = self:block(size, cf, color, material)
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Parent = p
	return p
end
function Builder:wedge(size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): BasePart
	local p = self:block(size, cf, color, material)
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Wedge
	m.Parent = p
	return p
end
-- Гладкая «трубка» через точки: цилиндры + шарики в стыках
function Builder:rod(points: { Vector3 }, d: number, color: Color3, material: Enum.Material?)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local len = (b - a).Magnitude
		if len > 0.01 then
			self:cyl(d, len + 0.02, (a + b) / 2, b - a, color, material)
		end
	end
	for i = 1, #points do
		self:ball(d, CFrame.new(points[i]), color, material)
	end
end
-- Тор (кольцо) вокруг локальной оси Y с центром center
function Builder:torus(center: Vector3, R: number, d: number, segments: number, color: Color3, material: Enum.Material?)
	local pts = {}
	for i = 0, segments do
		local a = i / segments * math.pi * 2
		table.insert(pts, center + Vector3.new(math.cos(a) * R, 0, math.sin(a) * R))
	end
	self:rod(pts, d, color, material)
end

------------------------------------------------------------------ ватрушка
-- Надувной тюбинг: толстый гладкий тор, тканевое дно, полоска, две ручки, клапан
local function buildTube(b, look: Look)
	local mat = look.material or Enum.Material.SmoothPlastic
	b:torus(Vector3.new(0, 0.05, 0), 2.85, 2.2, 22, look.main, mat)
	-- светлая полоска по верху тора
	b:torus(Vector3.new(0, 1.02, 0), 2.85, 0.42, 22, look.accent, if look.glow then Enum.Material.Neon else mat)
	-- тканевое дно-«сиденье»
	b:part(Enum.PartType.Cylinder, Vector3.new(0.35, 4.4, 4.4), CFrame.new(0, -0.6, 0) * CFrame.Angles(0, 0, math.rad(90)), look.main:Lerp(BLACK, 0.45), Enum.Material.Fabric)
	-- ручки по бокам: петли из толстого шнура
	for _, sx in { -1, 1 } do
		local x = sx * 2.85
		b:rod({
			Vector3.new(x, 1.0, -0.9),
			Vector3.new(x + sx * 0.25, 1.55, -0.55),
			Vector3.new(x + sx * 0.3, 1.7, 0),
			Vector3.new(x + sx * 0.25, 1.55, 0.55),
			Vector3.new(x, 1.0, 0.9),
		}, 0.28, BLACK, Enum.Material.Fabric)
	end
	-- клапан сзади
	b:cyl(0.35, 0.5, Vector3.new(0, 0.55, 3.75), Vector3.new(0, 0.6, 1), BLACK)
	-- шов по экватору и нижний защитный пояс
	b:torus(Vector3.new(0, 0.05, 0), 3.93, 0.1, 26, look.main:Lerp(BLACK, 0.35), mat)
	b:torus(Vector3.new(0, -0.75, 0), 3.35, 0.28, 24, BLACK, Enum.Material.Rubber)
	-- нашивка-эмблема спереди
	b:part(Enum.PartType.Cylinder, Vector3.new(0.06, 1.1, 1.1), CFrame.new(0, 0.35, -3.93) * CFrame.Angles(0, math.rad(90), 0), WHITE)
	b:part(Enum.PartType.Cylinder, Vector3.new(0.08, 0.7, 0.7), CFrame.new(0, 0.35, -3.95) * CFrame.Angles(0, math.rad(90), 0), look.accent, if look.glow then Enum.Material.Neon else nil)
end

------------------------------------------------------------------ деревянные санки
-- Классические санки: стальные полозья с загнутым носом, стойки, лакированные рейки,
-- передняя дуга-руль и верёвка
local function buildClassic(b, look: Look, painted: boolean)
	local wood = if painted then look.main else WOOD
	local woodMat = if painted then (look.material or Enum.Material.SmoothPlastic) else Enum.Material.Wood
	local runner = if painted then look.accent else Color3.fromRGB(190, 40, 40)
	for _, sx in { -1, 1 } do
		local x = sx * 1.9
		-- полоз: прямой низ и загнутый вверх-назад нос
		local pts = { Vector3.new(x, -0.55, 3.6), Vector3.new(x, -0.62, 1.5), Vector3.new(x, -0.62, -2.6) }
		for k = 0, 6 do
			local a = math.rad(k * 30) -- полукруг радиусом 0.9
			table.insert(pts, Vector3.new(x, -0.62 + 0.9 - math.cos(a) * 0.9, -2.6 - math.sin(a) * 0.9))
		end
		table.insert(pts, Vector3.new(x, 1.0, -1.9))
		b:rod(pts, 0.26, runner, Enum.Material.Metal)
		-- стойки от полоза к настилу
		for _, z in { -1.8, 0, 1.8, 3.2 } do
			b:block(Vector3.new(0.28, 0.75, 0.42), CFrame.new(x, -0.15, z), WOOD_DARK, Enum.Material.Wood)
		end
		-- продольный брус под настилом
		b:block(Vector3.new(0.4, 0.28, 6.0), CFrame.new(x, 0.25, 0.7), wood, woodMat)
	end
	-- рейки настила с зазорами, на концах — болты
	for k = 0, 5 do
		local z = -1.5 + k * 1.0
		b:block(Vector3.new(4.5, 0.2, 0.75), CFrame.new(0, 0.48, z), wood, woodMat)
		for _, sx in { -1, 1 } do
			b:ball(0.14, CFrame.new(sx * 1.9, 0.6, z), STEEL, Enum.Material.Metal)
		end
	end
	-- стальные уголки у стоек и задний бортик
	for _, sx in { -1, 1 } do
		for _, z in { -1.8, 0, 1.8, 3.2 } do
			b:block(Vector3.new(0.34, 0.12, 0.6), CFrame.new(sx * 1.9, -0.47, z), STEEL, Enum.Material.Metal)
		end
	end
	b:block(Vector3.new(4.5, 0.45, 0.25), CFrame.new(0, 0.75, 3.85), WOOD_DARK, Enum.Material.Wood)
	-- передняя поперечина и дуга-руль
	b:block(Vector3.new(4.4, 0.3, 0.5), CFrame.new(0, 0.6, -2.2), WOOD_DARK, Enum.Material.Wood)
	b:rod({ Vector3.new(-1.9, 1.0, -1.9), Vector3.new(-1.2, 1.25, -2.15), Vector3.new(0, 1.32, -2.25), Vector3.new(1.2, 1.25, -2.15), Vector3.new(1.9, 1.0, -1.9) }, 0.24, WOOD_DARK, Enum.Material.Wood)
	-- верёвка: петля от носа
	b:rod({
		Vector3.new(-1.2, 1.2, -2.3),
		Vector3.new(-1.0, 0.9, -3.0),
		Vector3.new(-0.4, 0.75, -3.4),
		Vector3.new(0.4, 0.75, -3.4),
		Vector3.new(1.0, 0.9, -3.0),
		Vector3.new(1.2, 1.2, -2.3),
	}, 0.14, Color3.fromRGB(225, 205, 160), Enum.Material.Fabric)
end

------------------------------------------------------------------ доска
-- Сноуборд: дека с поднятыми скруглёнными носом и хвостом, кант, рисунок, два крепления
local function buildBoard(b, look: Look)
	local mat = look.material or Enum.Material.SmoothPlastic
	local W, T = 3.0, 0.22
	local y = -0.45
	-- центральная часть
	b:block(Vector3.new(W, T, 5.2), CFrame.new(0, y, 0), look.main, mat)
	-- кант (тёмная полоска по краю)
	for _, sx in { -1, 1 } do
		b:block(Vector3.new(0.08, T + 0.04, 5.2), CFrame.new(sx * W / 2, y, 0), BLACK, Enum.Material.Metal)
	end
	-- нос и хвост: наклонная часть + скругление
	for _, sz in { -1, 1 } do
		local tilt = CFrame.new(0, y, sz * 2.6) * CFrame.Angles(sz * math.rad(-18), 0, 0)
		b:block(Vector3.new(W, T, 1.5), tilt * CFrame.new(0, 0, sz * 0.75), look.main, mat)
		b:part(Enum.PartType.Cylinder, Vector3.new(T, W, W), tilt * CFrame.new(0, 0, sz * 1.5) * CFrame.Angles(0, 0, math.rad(90)), look.main, mat)
		for _, sx in { -1, 1 } do
			b:block(Vector3.new(0.08, T + 0.04, 1.5), tilt * CFrame.new(sx * W / 2, 0, sz * 0.75), BLACK, Enum.Material.Metal)
		end
	end
	-- рисунок: две диагональные полосы акцентного цвета
	for _, z in { -1.2, 1.2 } do
		b:block(Vector3.new(W * 0.9, 0.02, 0.35), CFrame.new(0, y + T / 2 + 0.01, z) * CFrame.Angles(0, math.rad(25), 0), look.accent, if look.glow then Enum.Material.Neon else nil)
	end
	-- стомп-пэд между креплениями
	for k = -1, 1 do
		b:block(Vector3.new(0.9, 0.05, 0.14), CFrame.new(0, y + T / 2 + 0.02, k * 0.25), BLACK, Enum.Material.Rubber)
	end
	-- крепления: платформа, задник (хайбэк) и два ремешка
	for _, z in { -1.55, 1.55 } do
		local c = CFrame.new(0, y + T / 2, z) * CFrame.Angles(0, math.rad(if z < 0 then 12 else -12), 0)
		b:block(Vector3.new(1.6, 0.14, 1.1), c * CFrame.new(0, 0.07, 0), BLACK)
		b:block(Vector3.new(1.4, 0.75, 0.16), c * CFrame.new(0, 0.45, 0.55) * CFrame.Angles(math.rad(-12), 0, 0), BLACK)
		for _, dz in { -0.2, 0.25 } do
			b:block(Vector3.new(1.7, 0.18, 0.28), c * CFrame.new(0, 0.38, dz), look.accent:Lerp(BLACK, 0.3))
			b:block(Vector3.new(0.2, 0.22, 0.32), c * CFrame.new(0.75, 0.4, dz), STEEL, Enum.Material.Metal) -- пряжки
		end
		-- болты крепления
		for _, o in { Vector3.new(-0.45, 0.16, -0.3), Vector3.new(0.45, 0.16, -0.3), Vector3.new(-0.45, 0.16, 0.3), Vector3.new(0.45, 0.16, 0.3) } do
			b:ball(0.12, c * CFrame.new(o), STEEL, Enum.Material.Metal)
		end
	end
end

------------------------------------------------------------------ сани-самолёт
-- Маленький самолёт на лыжах: фюзеляж с кабиной, крылья со скруглёнными концами,
-- хвостовое оперение, пропеллер с коком, лыжи на стойках, опознавательные круги
local function buildPlane(b, look: Look)
	local mat = look.material or Enum.Material.SmoothPlastic
	local main, accent = look.main, look.accent
	-- фюзеляж вдоль Z
	b:cyl(2.4, 4.6, Vector3.new(0, 0.2, 0.2), Vector3.zAxis, main, mat)
	b:ellipsoid(Vector3.new(2.4, 2.4, 2.4), CFrame.new(0, 0.2, -2.1), main, mat) -- нос
	b:cyl(1.8, 1.4, Vector3.new(0, 0.35, 3.1), Vector3.zAxis, main, mat)
	b:cyl(1.1, 1.2, Vector3.new(0, 0.5, 4.3), Vector3.zAxis, main, mat)
	b:ball(1.1, CFrame.new(0, 0.5, 4.9), main, mat)
	-- полоса вдоль борта
	for _, sx in { -1, 1 } do
		b:block(Vector3.new(0.06, 0.3, 4.6), CFrame.new(sx * 1.19, 0.2, 0.2), accent, if look.glow then Enum.Material.Neon else nil)
	end
	-- кабина: тёмный проём и лобовое стекло
	b:block(Vector3.new(1.8, 0.1, 2.2), CFrame.new(0, 1.38, 0.3), BLACK)
	b:wedge(Vector3.new(1.9, 0.75, 0.9), CFrame.new(0, 1.65, -1.0) * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(170, 215, 245), Enum.Material.Glass).Transparency = 0.35
	-- крылья (низкоплан) со скруглёнными законцовками и кругами
	b:block(Vector3.new(9, 0.26, 2.0), CFrame.new(0, -0.35, -0.2), accent, mat)
	for _, sx in { -1, 1 } do
		b:part(Enum.PartType.Cylinder, Vector3.new(0.26, 2.0, 2.0), CFrame.new(sx * 4.5, -0.35, -0.2) * CFrame.Angles(0, 0, math.rad(90)), accent, mat)
		b:part(Enum.PartType.Cylinder, Vector3.new(0.05, 1.3, 1.3), CFrame.new(sx * 3.2, -0.2, -0.2) * CFrame.Angles(0, 0, math.rad(90)), WHITE)
		b:part(Enum.PartType.Cylinder, Vector3.new(0.06, 0.6, 0.6), CFrame.new(sx * 3.2, -0.19, -0.2) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(220, 50, 50))
	end
	-- хвостовое оперение
	b:block(Vector3.new(3.4, 0.18, 1.1), CFrame.new(0, 0.55, 4.6), accent, mat)
	b:wedge(Vector3.new(0.2, 1.6, 1.4), CFrame.new(0, 1.35, 4.65), accent, mat)
	-- пропеллер: кок + две лопасти + прозрачный «диск вращения»
	b:ellipsoid(Vector3.new(0.9, 0.9, 1.0), CFrame.new(0, 0.2, -3.35), WHITE)
	for _, a in { 0, 90 } do
		b:block(Vector3.new(0.28, 3.6, 0.12), CFrame.new(0, 0.2, -3.5) * CFrame.Angles(0, 0, math.rad(a + 20)) * CFrame.Angles(0, math.rad(12), 0), BLACK)
	end
	b:part(Enum.PartType.Cylinder, Vector3.new(0.04, 3.8, 3.8), CFrame.new(0, 0.2, -3.55) * CFrame.Angles(0, math.rad(90), 0), WHITE, nil, { Transparency = 0.8, Name = "PropDisc" })
	-- навигационные огни на концах крыльев, выхлопные патрубки, антенна
	b:ball(0.35, CFrame.new(-5.0, -0.35, -0.2), Color3.fromRGB(255, 60, 60), Enum.Material.Neon)
	b:ball(0.35, CFrame.new(5.0, -0.35, -0.2), Color3.fromRGB(60, 255, 120), Enum.Material.Neon)
	for _, sx in { -1, 1 } do
		for k = 0, 1 do
			b:cyl(0.22, 0.5, Vector3.new(sx * 1.15, -0.05 - k * 0.3, -1.4 + k * 0.1), Vector3.new(sx * 0.4, -0.3, 1), STEEL, Enum.Material.Metal)
		end
	end
	b:rod({ Vector3.new(0, 1.4, 1.6), Vector3.new(0, 2.3, 2.3) }, 0.08, BLACK)
	b:block(Vector3.new(1.2, 0.7, 0.3), CFrame.new(0, 1.7, 1.45) * CFrame.Angles(math.rad(10), 0, 0), BLACK, Enum.Material.Fabric) -- спинка кресла
	-- лыжи на стойках
	for _, sx in { -1, 1 } do
		local x = sx * 1.3
		b:rod({ Vector3.new(x, -0.75, 3.0), Vector3.new(x, -0.8, -1.8), Vector3.new(x, -0.6, -2.5), Vector3.new(x, -0.25, -2.75) }, 0.3, STEEL, Enum.Material.Metal)
		b:block(Vector3.new(0.7, 0.1, 5.0), CFrame.new(x, -0.92, 0.4), WHITE)
		for _, z in { -1.0, 1.8 } do
			b:rod({ Vector3.new(x, -0.8, z), Vector3.new(x * 0.6, 0.0, z) }, 0.18, STEEL, Enum.Material.Metal)
		end
	end
end

------------------------------------------------------------------ ледянка
-- Круглая пластиковая «тарелка»: выпуклое дно, толстый бортик, полоска, две ручки-прорези
local function buildSaucer(b, look: Look)
	local mat = look.material or Enum.Material.SmoothPlastic
	b:cyl(5.4, 0.3, Vector3.new(0, -0.5, 0), Vector3.yAxis, look.main, mat)
	b:cyl(4.2, 0.12, Vector3.new(0, -0.62, 0), Vector3.yAxis, look.main:Lerp(BLACK, 0.25), mat) -- выпуклость дна
	b:torus(Vector3.new(0, -0.3, 0), 2.62, 0.5, 26, look.main, mat)
	b:cyl(4.3, 0.04, Vector3.new(0, -0.33, 0), Vector3.yAxis, look.main:Lerp(WHITE, 0.25), mat) -- светлая чаша
	b:torus(Vector3.new(0, -0.3, 0), 1.75, 0.12, 22, look.accent, if look.glow then Enum.Material.Neon else mat)
	for _, sx in { -1, 1 } do
		-- ручка: петля над бортиком
		b:rod({ Vector3.new(sx * 2.55, -0.15, -0.7), Vector3.new(sx * 2.85, 0.25, -0.35), Vector3.new(sx * 2.85, 0.25, 0.35), Vector3.new(sx * 2.55, -0.15, 0.7) }, 0.2, look.accent:Lerp(BLACK, 0.2))
	end
end

------------------------------------------------------------------ тобоган
-- Длинные дощатые сани без полозьев с закрученным носом, верёвочные поручни и подушка
local function buildToboggan(b, look: Look, painted: boolean)
	local wood = if painted then look.main else WOOD
	local mat = if painted then (look.material or Enum.Material.SmoothPlastic) else Enum.Material.Wood
	for k = -2, 2 do
		b:block(Vector3.new(0.5, 0.16, 6.4), CFrame.new(k * 0.53, -0.48, 0.1), if k % 2 == 0 then wood else wood:Lerp(WOOD_DARK, 0.35), mat)
	end
	-- закрученный нос: доски по дуге
	for k = 1, 8 do
		local a = math.rad(k * 26)
		local r = 0.95
		local cf = CFrame.new(0, -0.48 + r - math.cos(a) * r, -3.1 - math.sin(a) * r) * CFrame.Angles(a, 0, 0)
		b:block(Vector3.new(2.66, 0.16, 0.42), cf, wood, mat)
	end
	-- поперечины
	for _, z in { -2.4, -0.6, 1.2, 2.9 } do
		b:block(Vector3.new(2.8, 0.14, 0.3), CFrame.new(0, -0.36, z), WOOD_DARK, Enum.Material.Wood)
	end
	-- верёвочные поручни вдоль бортов
	for _, sx in { -1, 1 } do
		local x = sx * 1.38
		b:rod({ Vector3.new(x, 0.05, -2.6), Vector3.new(x, 0.22, -1.2), Vector3.new(x, 0.05, 0.2), Vector3.new(x, 0.22, 1.6), Vector3.new(x, 0.05, 3.0) }, 0.14, look.accent, Enum.Material.Fabric)
		for _, z in { -2.6, 0.2, 3.0 } do
			b:block(Vector3.new(0.12, 0.45, 0.12), CFrame.new(x, -0.2, z), WOOD_DARK, Enum.Material.Wood)
		end
	end
	-- мягкая подушка-сиденье
	b:block(Vector3.new(2.3, 0.22, 2.6), CFrame.new(0, -0.3, 0.6), look.accent:Lerp(WHITE, 0.15), Enum.Material.Fabric)
end

------------------------------------------------------------------ снежный каяк
-- Обтекаемый корпус, полоса по палубе, кокпит с юбкой, весло поперёк, ручки на носу и корме
local function buildKayak(b, look: Look)
	local mat = look.material or Enum.Material.SmoothPlastic
	b:ellipsoid(Vector3.new(2.5, 1.2, 8.2), CFrame.new(0, -0.15, 0), look.main, mat)
	b:ellipsoid(Vector3.new(2.3, 0.6, 7.6), CFrame.new(0, -0.5, 0), look.main:Lerp(BLACK, 0.2), mat) -- киль
	b:block(Vector3.new(0.35, 0.05, 6.4), CFrame.new(0, 0.44, 0), look.accent, if look.glow then Enum.Material.Neon else mat)
	-- кокпит: тёмный проём + ободок
	b:cyl(1.9, 0.08, Vector3.new(0, 0.42, 0.4), Vector3.yAxis, BLACK)
	b:torus(Vector3.new(0, 0.46, 0.4), 0.95, 0.18, 18, look.accent:Lerp(BLACK, 0.3))
	-- ручки-петли на носу и корме
	for _, z in { -3.9, 3.9 } do
		b:rod({ Vector3.new(-0.25, 0.1, z), Vector3.new(0, 0.3, z + (if z < 0 then -0.25 else 0.25)), Vector3.new(0.25, 0.1, z) }, 0.1, BLACK)
	end
	-- весло поперёк: древко + лопасти
	b:cyl(0.14, 5.6, Vector3.new(0, 0.95, -0.4), Vector3.xAxis, STEEL, Enum.Material.Metal)
	for _, sx in { -1, 1 } do
		b:ellipsoid(Vector3.new(0.12, 0.55, 1.1), CFrame.new(sx * 2.85, 0.95, -0.4) * CFrame.Angles(0, 0, sx * math.rad(15)), look.accent)
	end
end

------------------------------------------------------------------ бобслей
-- Обтекаемая капсула: нос-обтекатель, борта, задняя стенка, полозья, ручки для разгона, номер
local function buildBobsled(b, look: Look)
	local mat = look.material or Enum.Material.SmoothPlastic
	b:block(Vector3.new(2.9, 0.28, 6.2), CFrame.new(0, -0.45, 0.2), look.main:Lerp(BLACK, 0.3), mat) -- дно
	for _, sx in { -1, 1 } do
		b:block(Vector3.new(0.26, 1.05, 5.8), CFrame.new(sx * 1.38, 0.1, 0.3), look.main, mat)
		b:block(Vector3.new(0.28, 0.2, 5.8), CFrame.new(sx * 1.39, 0.2, 0.3), look.accent, if look.glow then Enum.Material.Neon else mat) -- полоса
		-- номер на борту
		b:part(Enum.PartType.Cylinder, Vector3.new(0.05, 0.85, 0.85), CFrame.new(sx * 1.53, 0.05, 1.4), WHITE)
	end
	b:ellipsoid(Vector3.new(2.98, 1.4, 3.0), CFrame.new(0, 0.05, -2.75), look.main, mat) -- нос
	b:block(Vector3.new(2.9, 0.95, 0.25), CFrame.new(0, 0.05, 3.15), look.main, mat) -- корма
	b:wedge(Vector3.new(2.2, 0.5, 0.9), CFrame.new(0, 0.85, -1.7) * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(170, 215, 245), Enum.Material.Glass).Transparency = 0.35
	-- стальные полозья
	for _, sx in { -1, 1 } do
		for _, z in { -2.0, 2.0 } do
			b:rod({ Vector3.new(sx * 1.05, -0.62, z - 1.1), Vector3.new(sx * 1.05, -0.68, z + 1.0), Vector3.new(sx * 1.05, -0.55, z + 1.25) }, 0.16, STEEL, Enum.Material.Metal)
		end
		-- ручки для разгона сзади
		b:rod({ Vector3.new(sx * 1.38, 0.55, 2.6), Vector3.new(sx * 1.75, 0.6, 2.75), Vector3.new(sx * 1.75, 0.6, 3.35) }, 0.13, STEEL, Enum.Material.Metal)
	end
end

------------------------------------------------------------------ снегоход
-- Капот с фарой, ветровое стекло, руль, сиденье, две лыжи спереди и гусеница сзади
local function buildSnowmobile(b, look: Look)
	local mat = look.material or Enum.Material.SmoothPlastic
	-- капот
	b:ellipsoid(Vector3.new(2.3, 1.3, 3.0), CFrame.new(0, 0.25, -2.1), look.main, mat)
	b:block(Vector3.new(2.2, 0.7, 2.2), CFrame.new(0, 0.0, -0.9), look.main, mat)
	b:block(Vector3.new(2.25, 0.18, 2.2), CFrame.new(0, 0.1, -0.9), look.accent, if look.glow then Enum.Material.Neon else mat)
	b:ball(0.55, CFrame.new(0, 0.45, -3.55), Color3.fromRGB(255, 245, 200), Enum.Material.Neon) -- фара
	-- ветровое стекло и руль
	b:wedge(Vector3.new(1.8, 0.9, 0.5), CFrame.new(0, 1.15, -1.55) * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(170, 215, 245), Enum.Material.Glass).Transparency = 0.35
	b:rod({ Vector3.new(-0.95, 1.1, -0.95), Vector3.new(-0.4, 1.0, -1.1), Vector3.new(0.4, 1.0, -1.1), Vector3.new(0.95, 1.1, -0.95) }, 0.13, BLACK)
	for _, sx in { -1, 1 } do
		b:cyl(0.22, 0.4, Vector3.new(sx * 1.1, 1.1, -0.95), Vector3.xAxis, BLACK, Enum.Material.Rubber)
	end
	-- сиденье
	b:block(Vector3.new(1.3, 0.45, 3.0), CFrame.new(0, 0.05, 1.0), BLACK, Enum.Material.Fabric)
	-- гусеница: корпус + протектор
	b:block(Vector3.new(1.7, 0.6, 3.4), CFrame.new(0, -0.45, 1.2), Color3.fromRGB(45, 46, 52), Enum.Material.Rubber)
	for k = 0, 7 do
		b:block(Vector3.new(1.72, 0.12, 0.14), CFrame.new(0, -0.77, -0.35 + k * 0.45), Color3.fromRGB(25, 25, 30), Enum.Material.Rubber)
	end
	-- боковые панели с полосой
	for _, sx in { -1, 1 } do
		b:block(Vector3.new(0.12, 0.55, 3.4), CFrame.new(sx * 0.92, -0.2, 1.1), look.main, mat)
		b:block(Vector3.new(0.13, 0.12, 3.4), CFrame.new(sx * 0.93, -0.05, 1.1), look.accent)
		-- лыжи спереди на стойках
		local x = sx * 1.15
		b:block(Vector3.new(0.45, 0.12, 2.6), CFrame.new(x, -0.72, -2.3), BLACK)
		b:wedge(Vector3.new(0.45, 0.45, 0.6), CFrame.new(x, -0.5, -3.85) * CFrame.Angles(0, math.pi, 0), BLACK)
		b:rod({ Vector3.new(x, -0.65, -2.2), Vector3.new(x * 0.75, 0.0, -1.9) }, 0.14, STEEL, Enum.Material.Metal)
	end
	b:block(Vector3.new(1.2, 0.2, 0.12), CFrame.new(0, 0.05, 2.92), Color3.fromRGB(255, 50, 50), Enum.Material.Neon) -- стоп-сигнал
end

------------------------------------------------------------------ ракеты (апгрейд «Ракета»)
-- Боковые ракеты как в оригинале: корпус, обтекатель-нос, пояски, стабилизаторы, сопло.
-- Каждый тир — свой дизайн: петарда → ракета → турбо → мега → бласт → гиперджет.
local ROCKETS = {
	[0] = { name = "Петарда", body = Color3.fromRGB(215, 55, 45), nose = Color3.fromRGB(245, 235, 210), fin = Color3.fromRGB(245, 235, 210), band = Color3.fromRGB(245, 235, 210), nozzle = Color3.fromRGB(90, 70, 55), d = 0.75, len = 2.3, fins = 2, wick = true },
	[1] = { name = "Ракета", body = Color3.fromRGB(225, 45, 45), nose = WHITE, fin = Color3.fromRGB(55, 110, 225), band = WHITE, nozzle = Color3.fromRGB(55, 110, 225), d = 0.95, len = 2.9, fins = 3 },
	[2] = { name = "Турбо-ракета", body = Color3.fromRGB(205, 210, 220), bodyMat = Enum.Material.Metal, nose = Color3.fromRGB(225, 45, 45), fin = Color3.fromRGB(225, 45, 45), band = Color3.fromRGB(225, 45, 45), nozzle = STEEL, d = 1.05, len = 3.2, fins = 4, intake = true },
	[3] = { name = "Мега-двигатель", body = Color3.fromRGB(45, 95, 215), nose = WHITE, fin = Color3.fromRGB(255, 200, 40), band = WHITE, nozzle = STEEL, d = 1.15, len = 3.5, fins = 4, intake = true, glow = Color3.fromRGB(90, 220, 255), canards = true },
	[4] = { name = "Бласт-двигатель", body = Color3.fromRGB(240, 190, 55), bodyMat = Enum.Material.SmoothPlastic, shine = 0.25, nose = BLACK, fin = BLACK, band = BLACK, nozzle = Color3.fromRGB(60, 60, 70), d = 1.2, len = 3.7, fins = 4, intake = true, glow = Color3.fromRGB(255, 150, 40), canards = true },
	[6] = { name = "Плазменный двигатель", body = WHITE, nose = Color3.fromRGB(120, 230, 255), fin = Color3.fromRGB(90, 230, 255), finMat = Enum.Material.Neon, band = Color3.fromRGB(90, 230, 255), bandMat = Enum.Material.Neon, nozzle = STEEL, d = 1.3, len = 4.2, fins = 3, intake = true, glow = Color3.fromRGB(120, 240, 255), canards = true },
	[5] = { name = "Гиперджет", body = Color3.fromRGB(40, 32, 70), nose = Color3.fromRGB(170, 90, 255), fin = Color3.fromRGB(90, 230, 255), finMat = Enum.Material.Neon, band = Color3.fromRGB(90, 230, 255), bandMat = Enum.Material.Neon, nozzle = BLACK, d = 1.25, len = 3.9, fins = 4, intake = true, glow = Color3.fromRGB(190, 110, 255), canards = true },
}
SledModels.ROCKETS = ROCKETS

-- Одна ракета: центр at, нос смотрит по −Z. Возвращает позицию среза сопла (для огня).
local function buildRocket(b, at: Vector3, tier: number): Vector3
	local r = ROCKETS[math.clamp(tier, 0, 6)]
	local d, len = r.d, r.len
	local front, back = at.Z - len / 2, at.Z + len / 2
	local metal = Enum.Material.Metal
	local function rz(z: number): Vector3
		return Vector3.new(at.X, at.Y, z)
	end
	-- заклёпки по кругу (ряд маленьких шариков вокруг корпуса)
	local function rivets(z: number, n: number)
		for i = 0, n - 1 do
			local a = i / n * math.pi * 2
			b:ball(0.09, CFrame.new(at.X + math.cos(a) * d * 0.52, at.Y + math.sin(a) * d * 0.52, z), STEEL, metal)
		end
	end
	-- корпус: основная труба + чуть уже «шея» под носом (ступенька как у настоящей ракеты)
	local body = b:cyl(d, len * 0.82, rz(at.Z + len * 0.09), Vector3.zAxis, r.body, r.bodyMat)
	body.Reflectance = r.shine or 0
	local neck = b:cyl(d * 0.9, len * 0.2, rz(front + len * 0.1), Vector3.zAxis, r.body, r.bodyMat)
	neck.Reflectance = r.shine or 0
	-- нос: обтекатель + кольцо-стык + наконечник
	b:ellipsoid(Vector3.new(d * 0.9, d * 0.9, d * 1.8), CFrame.new(at.X, at.Y, front), r.nose, if r.nose == BLACK then metal else nil)
	b:cyl(d * 0.95, 0.12, rz(front + 0.02), Vector3.zAxis, r.band, r.bandMat)
	b:ball(d * 0.2, CFrame.new(at.X, at.Y, front - d * 0.86), r.band, r.bandMat)
	-- пояски-хомуты с заклёпками
	for _, k in { -0.18, 0.2 } do
		local z = at.Z + len * k
		b:cyl(d * 1.06, 0.2, rz(z), Vector3.zAxis, r.band, r.bandMat)
		rivets(z, 8)
	end
	-- гоночная полоса сверху (тир 2+), иллюминатор сбоку (тир 1+)
	if tier >= 2 then
		b:block(Vector3.new(d * 0.22, 0.04, len * 0.7), CFrame.new(at.X, at.Y + d / 2 + 0.01, at.Z + len * 0.05), r.band, r.bandMat)
	end
	if tier >= 1 then
		for _, sx in { -1, 1 } do
			local ox = sx * (d / 2 + 0.01)
			b:part(Enum.PartType.Cylinder, Vector3.new(0.05, d * 0.32, d * 0.32), CFrame.new(at.X + ox, at.Y, at.Z - len * 0.02), STEEL, metal)
			b:part(Enum.PartType.Cylinder, Vector3.new(0.06, d * 0.22, d * 0.22), CFrame.new(at.X + ox, at.Y, at.Z - len * 0.02), Color3.fromRGB(150, 210, 255), Enum.Material.Glass)
		end
	end
	if r.wick then -- фитиль у петарды
		b:rod({ rz(at.Z + len * 0.3) + Vector3.new(0, d * 0.4, 0), rz(at.Z + len * 0.38) + Vector3.new(0, d * 0.75, 0), rz(at.Z + len * 0.5) + Vector3.new(0, d * 0.85, 0) }, 0.08, Color3.fromRGB(60, 50, 40), Enum.Material.Fabric)
		b:ball(0.16, CFrame.new(at.X, at.Y + d * 0.88, at.Z + len * 0.52), Color3.fromRGB(255, 170, 60), Enum.Material.Neon)
	end
	if r.intake then -- воздухозаборники по бокам сверху
		for _, sx in { -1, 1 } do
			local c = CFrame.new(at.X + sx * d * 0.32, at.Y + d * 0.4, at.Z - len * 0.02) * CFrame.Angles(0, 0, sx * math.rad(-40))
			b:block(Vector3.new(d * 0.28, d * 0.2, len * 0.32), c, r.band, r.bandMat)
			b:block(Vector3.new(d * 0.18, d * 0.12, 0.05), c * CFrame.new(0, 0, -len * 0.16), BLACK)
		end
	end
	-- сопло-колокол: раструб расширяется ступеньками, внутри тёмный конус и огонёк
	b:cyl(d * 0.9, 0.22, rz(back + 0.06), Vector3.zAxis, STEEL, metal)
	local bell = { { 0.72, 0.22, 0.24 }, { 0.82, 0.18, 0.42 }, { 0.93, 0.16, 0.58 }, { 1.04, 0.1, 0.71 } }
	for _, s in bell do
		b:cyl(d * s[1], s[2], rz(back + s[3]), Vector3.zAxis, r.nozzle, metal)
	end
	b:cyl(d * 0.86, 0.04, rz(back + 0.77), Vector3.zAxis, BLACK)
	b:cyl(d * 0.5, 0.05, rz(back + 0.76), Vector3.zAxis, r.glow or Color3.fromRGB(255, 140, 50), Enum.Material.Neon)
	-- стабилизаторы: крупные стреловидные крылья с окантовкой
	local h = d * 0.95
	local start = if r.fins == 3 then 0 elseif r.fins == 2 then 90 else 45
	for i = 0, r.fins - 1 do
		local a = math.rad(start + i * 360 / r.fins)
		local base = CFrame.new(at.X, at.Y, back - 0.65) * CFrame.Angles(0, 0, a)
		b:wedge(Vector3.new(0.12, h, 1.4), base * CFrame.new(0, d / 2 + h / 2 - 0.05, 0), r.fin, r.finMat)
		-- законцовка
		b:block(Vector3.new(0.16, 0.14, 0.5), base * CFrame.new(0, d / 2 + h - 0.08, 0.45), r.band, r.bandMat)
	end
	if r.canards then -- передние крылышки
		for _, sx in { -1, 1 } do
			b:wedge(Vector3.new(0.1, d * 0.4, 0.7), CFrame.new(at.X, at.Y, front + len * 0.25) * CFrame.Angles(0, 0, sx * math.rad(90)) * CFrame.new(0, d / 2 + d * 0.18, 0), r.fin, r.finMat)
		end
	end
	return Vector3.new(at.X, at.Y, back + 0.78)
end

-- Где у каждой модели саней крепятся ракеты и фары
local MOUNTS = {
	tube = { x = 3.95, y = 0.3, z = 0.6, lights = Vector3.new(1.15, 0.85, -3.3) },
	classic = { x = 2.25, y = 0.45, z = 0.6, lights = Vector3.new(1.4, 0.9, -2.55) },
	board = { x = 1.5, y = -0.15, z = 0.3, lights = Vector3.new(0.85, -0.05, -3.15) },
	plane = { x = 2.75, y = -0.2, z = 0.3, lights = Vector3.new(2.2, -0.3, -1.3), onWing = true },
	saucer = { x = 2.85, y = -0.15, z = 0.3, lights = Vector3.new(0.9, -0.05, -2.6) },
	toboggan = { x = 1.45, y = -0.15, z = 0.8, lights = Vector3.new(0.8, 0.95, -3.75) },
	kayak = { x = 1.25, y = -0.05, z = 1.0, lights = Vector3.new(0.45, 0.3, -3.2) },
	bobsled = { x = 1.55, y = 0.05, z = 0.8, lights = Vector3.new(0.8, 0.25, -4.0) },
	snowmobile = { x = 1.0, y = -0.1, z = 1.3, lights = Vector3.new(0.6, 0.3, -3.3) },
}

-- Где у моделей спойлер (тир 2), обтекатель (тир 3) и золотой бампер (тир 4): { z, y }.
-- Нет записи — деталь этой модели не нужна (у самолёта и снегохода своё стекло и хвост).
local SPOILER = {
	tube = { 3.9, 1.2 }, classic = { 3.7, 1.0 }, board = { 3.3, 0.0 }, saucer = { 2.9, 0.1 },
	toboggan = { 3.3, 0.3 }, kayak = { 3.7, 0.5 }, bobsled = { 3.4, 0.7 }, snowmobile = { 3.0, 0.5 },
}
local SHIELD = {
	tube = { -3.4, 1.4 }, classic = { -2.5, 1.25 }, board = { -2.4, 0.35 }, saucer = { -2.4, 0.45 },
	toboggan = { -2.5, 0.65 }, kayak = { -1.3, 1.05 },
}
local BUMPER = {
	classic = { -3.0, 0.0 }, board = { -3.6, -0.25 }, saucer = { -2.95, -0.3 }, toboggan = { -3.15, -0.3 },
	kayak = { -4.2, -0.2 }, bobsled = { -4.25, -0.3 }, snowmobile = { -3.75, -0.35 }, plane = { -2.9, 0.0 },
}

-- Одна ракета отдельно (витрина апгрейда «Ракета»)
function SledModels.rocket(parent: Instance, base: CFrame, tier: number): Vector3
	local b = newBuilder(parent, base, nil)
	return buildRocket(b, Vector3.zero, tier)
end

-- Детали апгрейдов на санках: боковые ракеты по тиру «Ракеты» + обвес по тиру «Саней».
-- Возвращает { x, y, z } сопла правой ракеты (для огня в Effects).
function SledModels.extras(parent: Instance, base: CFrame, id: string, sledTier: number, rocketTier: number, accent: Color3, weldTo: BasePart?): Vector3
	local b = newBuilder(parent, base, weldTo)
	local m = MOUNTS[id] or MOUNTS.tube
	local r = ROCKETS[math.clamp(rocketTier, 0, 6)]
	local x = if m.onWing then m.x else m.x + r.d / 2 + 0.12
	local y = if m.onWing then m.y + r.d / 2 else m.y
	local nozzle = Vector3.zero
	for _, sx in { -1, 1 } do
		nozzle = buildRocket(b, Vector3.new(sx * x, y, m.z), rocketTier)
		-- кронштейн к корпусу
		if not m.onWing then
			b:block(Vector3.new(0.5, 0.28, 0.9), CFrame.new(sx * (x - r.d / 2 - 0.1), y, m.z), STEEL, Enum.Material.Metal)
		end
	end
	-- Тиры «Саней»: 1 фары, 2 аэро-хвост, 3 обтекатель, 4 золотая отделка, 5 неон
	if sledTier >= 1 then
		for _, sx in { -1, 1 } do
			local p = m.lights * Vector3.new(sx, 1, 1)
			b:ball(0.62, CFrame.new(p), if sledTier >= 4 then Color3.fromRGB(240, 195, 60) else STEEL, Enum.Material.Metal)
			b:ball(0.46, CFrame.new(p + Vector3.new(0, 0, -0.12)), Color3.fromRGB(255, 245, 200), Enum.Material.Neon)
		end
	end
	if sledTier >= 2 and SPOILER[id] then
		local z, yy = SPOILER[id][1], SPOILER[id][2]
		-- спойлер: две стойки + крыло
		for _, sx in { -1, 1 } do
			b:block(Vector3.new(0.18, 0.7, 0.4), CFrame.new(sx * 0.9, yy, z), BLACK)
		end
		-- крыло: скруглённая планка + синие торцевые пластины (как в оригинале)
		b:rod({ Vector3.new(-1.3, yy + 0.42, z + 0.1), Vector3.new(1.3, yy + 0.42, z + 0.1) }, 0.3, accent)
		b:block(Vector3.new(2.6, 0.08, 0.6), CFrame.new(0, yy + 0.42, z + 0.3) * CFrame.Angles(math.rad(-12), 0, 0), accent)
		for _, sx in { -1, 1 } do
			b:block(Vector3.new(0.14, 0.8, 0.85), CFrame.new(sx * 1.4, yy + 0.4, z + 0.2), Color3.fromRGB(50, 70, 190))
		end
	end
	if sledTier >= 3 and SHIELD[id] then
		local z, yy = SHIELD[id][1], SHIELD[id][2]
		local glass = b:block(Vector3.new(3.6, 1.4, 0.18), CFrame.new(0, yy, z) * CFrame.Angles(math.rad(-25), 0, 0), Color3.fromRGB(170, 220, 255), Enum.Material.Glass)
		glass.Transparency = 0.35
		b:block(Vector3.new(3.7, 0.16, 0.24), CFrame.new(0, yy + 0.66, z + 0.3) * CFrame.Angles(math.rad(-25), 0, 0), BLACK)
	end
	if sledTier >= 4 then -- золотой пояс/бампер
		local gold = Color3.fromRGB(240, 195, 60)
		if id == "tube" then
			b:torus(Vector3.new(0, 0.05, 0), 3.95, 0.22, 26, gold, Enum.Material.SmoothPlastic)
		else
			local bp = BUMPER[id] or { -2.9, 0.0 }
			local z, yy = bp[1], bp[2]
			b:rod({ Vector3.new(-1.6, yy, z + 0.4), Vector3.new(-0.8, yy, z), Vector3.new(0.8, yy, z), Vector3.new(1.6, yy, z + 0.4) }, 0.22, gold, Enum.Material.SmoothPlastic)
		end
	end
	if sledTier >= 5 then -- неоновая подсветка снизу
		for _, sx in { -1, 1 } do
			b:block(Vector3.new(0.12, 0.12, 4.5), CFrame.new(sx * (if id == "tube" then 3.0 else 1.6), -0.55, 0.2), accent, Enum.Material.Neon)
		end
	end
	local back = (SPOILER[id] or { 3.0, 0.3 })
	local side = x - r.d / 2 - 0.1 -- борт (там, где кронштейн ракеты)
	if sledTier >= 6 then -- флажок на шесте сзади слева
		local px, pz = -math.min(side, 1.4), back[1] - 0.4
		b:rod({ Vector3.new(px, back[2] - 0.2, pz), Vector3.new(px, back[2] + 3.2, pz) }, 0.12, STEEL, Enum.Material.Metal)
		b:wedge(Vector3.new(0.06, 0.9, 1.3), CFrame.new(px, back[2] + 2.7, pz + 0.65) * CFrame.Angles(0, 0, 0), accent)
		b:ball(0.25, CFrame.new(px, back[2] + 3.3, pz), Color3.fromRGB(255, 215, 70), Enum.Material.Neon)
	end
	if sledTier >= 7 then -- боковые крылья-плавники
		for _, sx in { -1, 1 } do
			b:wedge(Vector3.new(0.12, 0.9, 1.8), CFrame.new(sx * (side + 0.05), y + 0.55, m.z + 0.9) * CFrame.Angles(0, 0, sx * math.rad(-35)), accent)
		end
	end
	if sledTier >= 8 then -- хромированные выхлопные трубы сзади
		for _, sx in { -1, 1 } do
			local p0 = Vector3.new(sx * 0.6, back[2] - 0.3, back[1] - 0.6)
			local pipe = b:cyl(0.32, 1.4, p0 + Vector3.new(0, 0.35, 0.55), Vector3.new(0, 0.5, 1), Color3.fromRGB(215, 220, 230), Enum.Material.Metal)
			pipe.Reflectance = 0.4
			b:cyl(0.24, 0.06, p0 + Vector3.new(0, 0.7, 1.25), Vector3.new(0, 0.5, 1), BLACK)
		end
	end
	if sledTier >= 9 then -- сияние: искры и тёплый свет
		local core = b:ball(0.2, CFrame.new(0, 0.2, 0), WHITE, nil, nil)
		core.Transparency = 1
		local sp = Instance.new("Sparkles")
		sp.SparkleColor = Color3.fromRGB(255, 225, 120)
		sp.Parent = core
	end
	if sledTier >= 10 then -- корона чемпиона спереди
		local lp = m.lights
		local c = CFrame.new(0, lp.Y + 0.55, lp.Z + 0.1)
		local gold = Color3.fromRGB(255, 205, 60)
		b:cyl(0.9, 0.3, c.Position, Vector3.yAxis, gold, Enum.Material.SmoothPlastic).Reflectance = 0.3
		for k = 0, 4 do
			local a = k / 5 * math.pi * 2
			b:wedge(Vector3.new(0.12, 0.45, 0.3), c * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.35, -0.4), gold)
		end
		b:ball(0.25, c * CFrame.new(0, 0.3, -0.45), Color3.fromRGB(255, 60, 90), Enum.Material.Neon)
	end
	return nozzle
end

------------------------------------------------------------------ столбы рогатки (апгрейд «Запуск»)
-- Каждый тир — свой столб, как в оригинале: бревно → стальной кнехт → колонна → гидравлика →
-- золотая колонна с камнем → неоновый обелиск. Вокруг верха намотана резинка.
-- base — центр столба (высота 9, низ на −4.5); резинка крепится на высоте +3.5.
SledModels.ROPE_COLORS = {
	Color3.fromRGB(205, 170, 120), -- 0 верёвка
	Color3.fromRGB(205, 55, 50), -- 1 красный канат
	Color3.fromRGB(215, 185, 140), -- 2 витой бежевый
	Color3.fromRGB(45, 45, 55), -- 3 стальной трос
	Color3.fromRGB(255, 210, 80), -- 4 золотой
	Color3.fromRGB(90, 230, 255), -- 5 неон
	Color3.fromRGB(200, 240, 255), -- 6 ледяной
	Color3.fromRGB(255, 120, 30), -- 7 огненный
	Color3.fromRGB(120, 140, 255), -- 8 электрический
	Color3.fromRGB(255, 255, 255), -- 9 радужный (цвета задаются отдельно)
	Color3.fromRGB(180, 110, 255), -- 10 галактический
}
-- Какие резинки светятся
SledModels.ROPE_GLOW = { [5] = true, [6] = true, [7] = true, [8] = true, [9] = true, [10] = true }

function SledModels.slingshot(parent: Instance, base: CFrame, tier: number)
	local b = newBuilder(parent, base, nil)
	tier = math.clamp(tier, 0, 10)
	local Y = Vector3.yAxis
	local function v(y: number): Vector3
		return Vector3.new(0, y, 0)
	end
	local rope = SledModels.ROPE_COLORS[tier + 1]
	local postR = 0.8 -- радиус там, где намотана резинка
	if tier == 0 then
		-- бревно с корой, срезом сверху и камнями у основания
		local wood, dark = Color3.fromRGB(140, 95, 55), Color3.fromRGB(100, 66, 38)
		b:cyl(1.5, 9, v(0), Y, wood, Enum.Material.Wood)
		for _, y in { -2.6, -0.4, 1.8 } do
			b:cyl(1.58, 0.22, v(y), Y, dark, Enum.Material.Wood)
		end
		b:cyl(1.38, 0.06, v(4.52), Y, Color3.fromRGB(215, 175, 115), Enum.Material.Wood)
		b:cyl(0.8, 0.07, v(4.53), Y, Color3.fromRGB(180, 135, 85), Enum.Material.Wood)
		b:cyl(0.25, 0.08, v(4.54), Y, dark, Enum.Material.Wood)
		-- сучок
		b:rod({ v(0.6) + Vector3.new(0.7, 0, 0), v(1.3) + Vector3.new(1.3, 0, 0.2) }, 0.32, wood, Enum.Material.Wood)
		for i, off in { Vector3.new(1.0, -4.3, 0.5), Vector3.new(-0.9, -4.35, 0.7), Vector3.new(0.2, -4.3, -1.0), Vector3.new(-0.7, -4.4, -0.8) } do
			b:ball(0.9 + i * 0.12, CFrame.new(off), Color3.fromRGB(125, 128, 135), Enum.Material.Slate)
		end
		postR = 0.76
	elseif tier == 1 then
		-- стальной кнехт: фланец с болтами, труба с кольцами, грибовидная шапка
		local steel, dark = Color3.fromRGB(150, 156, 168), Color3.fromRGB(90, 95, 108)
		b:cyl(2.8, 0.35, v(-4.35), Y, dark, Enum.Material.DiamondPlate)
		for i = 0, 5 do
			local a = i / 6 * math.pi * 2
			b:ball(0.22, CFrame.new(math.cos(a) * 1.15, -4.12, math.sin(a) * 1.15), STEEL, Enum.Material.Metal)
		end
		b:cyl(1.6, 8.4, v(-0.1), Y, steel, Enum.Material.Metal)
		for _, y in { -3.7, -1.0, 2.2 } do
			b:cyl(1.85, 0.32, v(y), Y, dark, Enum.Material.Metal)
		end
		b:cyl(2.1, 0.45, v(4.2), Y, dark, Enum.Material.Metal)
		b:ellipsoid(Vector3.new(1.9, 0.8, 1.9), CFrame.new(0, 4.45, 0), steel, Enum.Material.Metal)
	elseif tier == 2 then
		-- колонна (розовая, как в оригинале): плинт, база, каннелюры, капитель, цветные кольца
		local pink, white = Color3.fromRGB(240, 160, 180), Color3.fromRGB(250, 245, 245)
		b:block(Vector3.new(2.7, 0.6, 2.7), CFrame.new(0, -4.2, 0), white, Enum.Material.Marble)
		b:cyl(2.25, 0.4, v(-3.7), Y, white, Enum.Material.Marble)
		b:cyl(1.95, 0.25, v(-3.4), Y, pink)
		b:cyl(1.6, 7.0, v(0), Y, pink)
		for i = 0, 9 do
			local a = i / 10 * math.pi * 2
			b:block(Vector3.new(0.2, 6.6, 0.2), CFrame.new(math.cos(a) * 0.78, 0, math.sin(a) * 0.78) * CFrame.Angles(0, -a, 0), white)
		end
		b:cyl(1.75, 0.22, v(2.55), Y, Color3.fromRGB(220, 50, 60))
		b:cyl(1.75, 0.22, v(2.85), Y, Color3.fromRGB(60, 110, 220))
		b:cyl(2.0, 0.35, v(3.75), Y, pink)
		b:cyl(2.3, 0.3, v(4.05), Y, white, Enum.Material.Marble)
		b:block(Vector3.new(2.6, 0.35, 2.6), CFrame.new(0, 4.35, 0), white, Enum.Material.Marble)
	elseif tier == 3 then
		-- гидравлический силовой столб: корпус с «зеброй», хромированный шток, лампа
		local blue, chrome = Color3.fromRGB(55, 85, 200), Color3.fromRGB(215, 220, 230)
		b:block(Vector3.new(2.6, 2.2, 2.6), CFrame.new(0, -3.4, 0), blue, Enum.Material.Metal)
		for i = 0, 5 do
			b:cyl(2.2, 0.18, v(-2.15 + i * 0.18), Y, if i % 2 == 0 then Color3.fromRGB(250, 200, 30) else BLACK)
		end
		local rodp = b:cyl(1.0, 4.4, v(0.1), Y, chrome, Enum.Material.Metal)
		rodp.Reflectance = 0.35
		b:cyl(1.3, 0.3, v(-1.0), Y, STEEL, Enum.Material.Metal)
		b:cyl(1.8, 2.3, v(3.2), Y, blue, Enum.Material.Metal)
		b:cyl(1.9, 0.18, v(2.4), Y, Color3.fromRGB(90, 230, 255), Enum.Material.Neon)
		b:cyl(1.9, 0.25, v(4.4), Y, STEEL, Enum.Material.Metal)
		b:ball(0.5, CFrame.new(0, 4.65, 0), Color3.fromRGB(255, 70, 60), Enum.Material.Neon)
		postR = 0.92
	elseif tier == 4 then
		-- золотая колонна на мраморе с драгоценным камнем
		local gold, marble = Color3.fromRGB(245, 195, 60), Color3.fromRGB(245, 242, 235)
		b:block(Vector3.new(2.8, 0.7, 2.8), CFrame.new(0, -4.15, 0), marble, Enum.Material.Marble)
		b:cyl(2.3, 0.4, v(-3.6), Y, gold).Reflectance = 0.3
		local shaft = b:cyl(1.6, 7.0, v(0), Y, gold)
		shaft.Reflectance = 0.3
		-- спиральный орнамент вокруг ствола
		local spiral = {}
		for k = 0, 16 do
			local a = k / 16 * math.pi * 4
			table.insert(spiral, Vector3.new(math.cos(a) * 0.82, -3.0 + k * 0.36, math.sin(a) * 0.82))
		end
		b:rod(spiral, 0.14, Color3.fromRGB(255, 240, 170))
		for _, y in { -2.9, 2.6 } do
			b:cyl(1.85, 0.28, v(y), Y, Color3.fromRGB(255, 225, 120)).Reflectance = 0.3
		end
		b:cyl(2.3, 0.45, v(3.85), Y, gold).Reflectance = 0.3
		b:block(Vector3.new(2.5, 0.35, 2.5), CFrame.new(0, 4.25, 0), marble, Enum.Material.Marble)
		local gem = b:block(Vector3.new(0.9, 0.9, 0.9), CFrame.new(0, 5.1, 0) * CFrame.Angles(math.rad(45), 0, math.rad(35)), Color3.fromRGB(80, 200, 255), Enum.Material.Glass)
		gem.Transparency = 0.2
		b:ball(0.45, CFrame.new(0, 5.1, 0), Color3.fromRGB(150, 230, 255), Enum.Material.Neon)
	elseif tier == 6 then
		-- ледяная: прозрачная шестигранная колонна со светящейся сердцевиной и короной сосулек
		local ice = Color3.fromRGB(180, 230, 255)
		b:block(Vector3.new(2.8, 0.7, 2.8), CFrame.new(0, -4.15, 0), Color3.fromRGB(235, 245, 255), Enum.Material.Snow)
		b:cyl(1.8, 8.2, v(-0.1), Y, ice, Enum.Material.Glass).Transparency = 0.25
		b:cyl(0.6, 7.6, v(-0.1), Y, Color3.fromRGB(120, 220, 255), Enum.Material.Neon)
		for i = 0, 5 do
			local a = i / 6 * math.pi * 2
			b:wedge(Vector3.new(0.5, 1.8, 0.7), CFrame.new(math.cos(a) * 0.75, 4.6, math.sin(a) * 0.75) * CFrame.Angles(0, -a, 0), ice, Enum.Material.Ice)
		end
		postR = 0.9
	elseif tier == 7 then
		-- огненная: обсидиан с лавовыми трещинами и чаша с настоящим огнём
		local obs = Color3.fromRGB(35, 28, 30)
		b:block(Vector3.new(2.7, 0.7, 2.7), CFrame.new(0, -4.15, 0), obs, Enum.Material.Basalt)
		b:cyl(1.7, 7.4, v(-0.3), Y, obs, Enum.Material.Basalt)
		for k = 0, 4 do
			b:block(Vector3.new(1.74, 0.16, 0.5), CFrame.new(0, -3 + k * 1.5, 0) * CFrame.Angles(0, k * 1.1, 0.25), Color3.fromRGB(255, 110, 30), Enum.Material.Neon)
		end
		b:cyl(2.6, 0.5, v(3.75), Y, Color3.fromRGB(60, 50, 50), Enum.Material.Metal)
		local coals = b:cyl(2.2, 0.2, v(4.05), Y, Color3.fromRGB(255, 140, 40), Enum.Material.Neon)
		local fire = Instance.new("Fire")
		fire.Size = 6
		fire.Heat = 12
		fire.Parent = coals
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 140, 50)
		light.Range = 14
		light.Parent = coals
		postR = 0.9
	elseif tier == 8 then
		-- техно-пилон: квадратная металлическая стойка, светящиеся линии и парящее кольцо
		local metal = Color3.fromRGB(55, 60, 75)
		b:block(Vector3.new(2.8, 0.6, 2.8), CFrame.new(0, -4.2, 0), metal, Enum.Material.DiamondPlate)
		b:block(Vector3.new(1.6, 8.2, 1.6), CFrame.new(0, -0.1, 0), metal, Enum.Material.Metal)
		for _, f in { Vector3.new(0.81, 0, 0), Vector3.new(-0.81, 0, 0), Vector3.new(0, 0, 0.81), Vector3.new(0, 0, -0.81) } do
			b:block(Vector3.new(if f.X ~= 0 then 0.04 else 0.25, 7.4, if f.Z ~= 0 then 0.04 else 0.25), CFrame.new(f), Color3.fromRGB(90, 160, 255), Enum.Material.Neon)
		end
		b:torus(v(4.6), 1.3, 0.22, 16, Color3.fromRGB(120, 200, 255), Enum.Material.Neon)
		b:block(Vector3.new(1.9, 0.4, 1.9), CFrame.new(0, 4.05, 0), Color3.fromRGB(30, 32, 40), Enum.Material.Metal)
		postR = 1.05
	elseif tier == 9 then
		-- радужная: столбик из разноцветных колец и сияющая звезда
		local rainbow = { Color3.fromRGB(240, 70, 70), Color3.fromRGB(255, 150, 50), Color3.fromRGB(255, 220, 60), Color3.fromRGB(90, 210, 90), Color3.fromRGB(70, 160, 255), Color3.fromRGB(120, 90, 230), Color3.fromRGB(200, 90, 220) }
		b:block(Vector3.new(2.7, 0.6, 2.7), CFrame.new(0, -4.2, 0), WHITE, Enum.Material.SmoothPlastic)
		for k, col in rainbow do
			b:cyl(1.7, 1.12, v(-3.4 + (k - 1) * 1.12), Y, col).Reflectance = 0.15
		end
		local star = b:ball(1.3, CFrame.new(0, 4.9, 0), Color3.fromRGB(255, 230, 90), Enum.Material.Neon)
		local sp = Instance.new("Sparkles")
		sp.SparkleColor = Color3.fromRGB(255, 240, 150)
		sp.Parent = star
		postR = 0.88
	elseif tier >= 10 then
		-- галактическая: тёмно-фиолетовая колонна со звёздами и парящая планета с кольцом
		local dark = Color3.fromRGB(40, 20, 70)
		b:block(Vector3.new(2.7, 0.6, 2.7), CFrame.new(0, -4.2, 0), dark, Enum.Material.Slate)
		local col = b:cyl(1.7, 8.0, v(-0.3), Y, dark, Enum.Material.Glass)
		col.Transparency = 0.1
		local sp = Instance.new("Sparkles")
		sp.SparkleColor = Color3.fromRGB(200, 170, 255)
		sp.Parent = col
		local planet = b:ball(1.6, CFrame.new(0, 5.4, 0), Color3.fromRGB(170, 110, 255), Enum.Material.Neon)
		b:torus(v(5.4), 1.3, 0.14, 18, Color3.fromRGB(255, 220, 120), Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(180, 120, 255)
		light.Range = 14
		light.Parent = planet
		postR = 0.88
	else
		-- неоновый обелиск: тёмный камень, светящиеся кольца, парящий кристалл
		local dark, neon = Color3.fromRGB(32, 26, 55), Color3.fromRGB(90, 230, 255)
		b:block(Vector3.new(2.6, 0.6, 2.6), CFrame.new(0, -4.2, 0), dark, Enum.Material.Slate)
		b:cyl(1.7, 8.0, v(-0.3), Y, dark, Enum.Material.Slate)
		for _, y in { -3.4, -1.2, 1.0, 2.5 } do
			b:cyl(1.8, 0.14, v(y), Y, neon, Enum.Material.Neon)
		end
		b:cyl(2.1, 0.3, v(3.9), Y, dark, Enum.Material.Slate)
		local crystal = b:block(Vector3.new(0.9, 1.6, 0.9), CFrame.new(0, 5.3, 0) * CFrame.Angles(0, math.rad(45), 0), Color3.fromRGB(190, 110, 255), Enum.Material.Neon)
		crystal.Name = "Crystal"
		local light = Instance.new("PointLight")
		light.Color = neon
		light.Range = 12
		light.Brightness = 1.5
		light.Parent = crystal
		postR = 0.85
	end
	-- намотка резинки: три витка у точки крепления
	for i = 0, 2 do
		b:torus(v(3.15 + i * 0.32), postR + 0.08, 0.3, 14, rope, if SledModels.ROPE_GLOW[tier] then Enum.Material.Neon else Enum.Material.Fabric)
	end
end

function SledModels.build(parent: Instance, base: CFrame, id: string, look: Look, weldTo: BasePart?, painted: boolean?): number
	local b = newBuilder(parent, base, weldTo)
	b.main = look.main
	b.shine = look.shine or 0
	if id == "board" then
		buildBoard(b, look)
	elseif id == "saucer" then
		buildSaucer(b, look)
	elseif id == "toboggan" then
		buildToboggan(b, look, painted == true)
	elseif id == "kayak" then
		buildKayak(b, look)
	elseif id == "bobsled" then
		buildBobsled(b, look)
	elseif id == "snowmobile" then
		buildSnowmobile(b, look)
	elseif id == "classic" then
		buildClassic(b, look, painted == true)
	elseif id == "plane" then
		buildPlane(b, look)
	else
		buildTube(b, look)
	end
	return b.count
end

return SledModels
