-- Детализированные 3D-модели саней из примитивов Roblox (без загрузки мешей —
-- работает с автодеплоем). Плавные формы собираются из «трубок»: цилиндры между
-- точками + шарики в стыках, поэтому тор ватрушки и изогнутые полозья выглядят гладкими.
--
-- SledModels.build(parent, base, id, look, weldTo?)
--   base   — CFrame центра саней (низ корпуса ≈ base.Y − 0.5), «нос» смотрит по −Z
--   look   — { main: Color3, accent: Color3, material: Enum.Material?, glow: boolean? }
--   weldTo — если задан, детали привариваются к нему (санки в заезде), иначе закреплены (витрина)

local SledModels = {}

type Look = { main: Color3, accent: Color3, material: Enum.Material?, glow: boolean? }

local WOOD = Color3.fromRGB(186, 128, 74)
local WOOD_DARK = Color3.fromRGB(140, 92, 50)
local STEEL = Color3.fromRGB(70, 74, 86)
local BLACK = Color3.fromRGB(32, 34, 40)
local WHITE = Color3.fromRGB(245, 247, 250)

-- Контекст сборки: куда класть, к чему приваривать
local Builder = {}
Builder.__index = Builder

local function newBuilder(parent: Instance, base: CFrame, weldTo: BasePart?)
	return setmetatable({ parent = parent, base = base, weldTo = weldTo, count = 0 }, Builder)
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
	p.CastShadow = true
	p.Massless = true
	p.CollisionGroup = "Riders"
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
	-- рейки настила с зазорами
	for k = 0, 5 do
		b:block(Vector3.new(4.5, 0.2, 0.75), CFrame.new(0, 0.48, -1.5 + k * 1.0), wood, woodMat)
	end
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
	-- крепления: платформа, задник (хайбэк) и два ремешка
	for _, z in { -1.55, 1.55 } do
		local c = CFrame.new(0, y + T / 2, z) * CFrame.Angles(0, math.rad(if z < 0 then 12 else -12), 0)
		b:block(Vector3.new(1.6, 0.14, 1.1), c * CFrame.new(0, 0.07, 0), BLACK)
		b:block(Vector3.new(1.4, 0.75, 0.16), c * CFrame.new(0, 0.45, 0.55) * CFrame.Angles(math.rad(-12), 0, 0), BLACK)
		for _, dz in { -0.2, 0.25 } do
			b:block(Vector3.new(1.7, 0.18, 0.28), c * CFrame.new(0, 0.38, dz), look.accent:Lerp(BLACK, 0.3))
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

function SledModels.build(parent: Instance, base: CFrame, id: string, look: Look, weldTo: BasePart?, painted: boolean?): number
	local b = newBuilder(parent, base, weldTo)
	if id == "board" then
		buildBoard(b, look)
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
