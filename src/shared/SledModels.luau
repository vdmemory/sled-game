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
	p.CastShadow = true
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

------------------------------------------------------------------ ракеты (апгрейд «Ракета»)
-- Боковые ракеты как в оригинале: корпус, обтекатель-нос, пояски, стабилизаторы, сопло.
-- Каждый тир — свой дизайн: петарда → ракета → турбо → мега → бласт → гиперджет.
local ROCKETS = {
	[0] = { name = "Петарда", body = Color3.fromRGB(215, 55, 45), nose = Color3.fromRGB(245, 235, 210), fin = Color3.fromRGB(245, 235, 210), band = Color3.fromRGB(245, 235, 210), nozzle = Color3.fromRGB(90, 70, 55), d = 0.75, len = 2.3, fins = 2, wick = true },
	[1] = { name = "Ракета", body = Color3.fromRGB(225, 45, 45), nose = WHITE, fin = Color3.fromRGB(55, 110, 225), band = WHITE, nozzle = Color3.fromRGB(55, 110, 225), d = 0.95, len = 2.9, fins = 3 },
	[2] = { name = "Турбо-ракета", body = Color3.fromRGB(205, 210, 220), bodyMat = Enum.Material.Metal, nose = Color3.fromRGB(225, 45, 45), fin = Color3.fromRGB(225, 45, 45), band = Color3.fromRGB(225, 45, 45), nozzle = STEEL, d = 1.05, len = 3.2, fins = 4, intake = true },
	[3] = { name = "Мега-двигатель", body = Color3.fromRGB(45, 95, 215), nose = WHITE, fin = Color3.fromRGB(255, 200, 40), band = WHITE, nozzle = STEEL, d = 1.15, len = 3.5, fins = 4, intake = true, glow = Color3.fromRGB(90, 220, 255), canards = true },
	[4] = { name = "Бласт-двигатель", body = Color3.fromRGB(240, 190, 55), bodyMat = Enum.Material.SmoothPlastic, shine = 0.25, nose = BLACK, fin = BLACK, band = BLACK, nozzle = Color3.fromRGB(60, 60, 70), d = 1.2, len = 3.7, fins = 4, intake = true, glow = Color3.fromRGB(255, 150, 40), canards = true },
	[5] = { name = "Гиперджет", body = Color3.fromRGB(40, 32, 70), nose = Color3.fromRGB(170, 90, 255), fin = Color3.fromRGB(90, 230, 255), finMat = Enum.Material.Neon, band = Color3.fromRGB(90, 230, 255), bandMat = Enum.Material.Neon, nozzle = BLACK, d = 1.25, len = 3.9, fins = 4, intake = true, glow = Color3.fromRGB(190, 110, 255), canards = true },
}
SledModels.ROCKETS = ROCKETS

-- Одна ракета: центр at, нос смотрит по −Z. Возвращает позицию среза сопла (для огня).
local function buildRocket(b, at: Vector3, tier: number): Vector3
	local r = ROCKETS[math.clamp(tier, 0, 5)]
	local d, len = r.d, r.len
	local back = at.Z + len / 2
	-- корпус
	local body = b:cyl(d, len, at, Vector3.zAxis, r.body, r.bodyMat)
	body.Reflectance = r.shine or 0
	-- нос: вытянутый обтекатель + наконечник
	b:ellipsoid(Vector3.new(d, d, d * 1.7), CFrame.new(at.X, at.Y, at.Z - len / 2), r.nose, if r.nose == BLACK then Enum.Material.Metal else nil)
	b:ball(d * 0.22, CFrame.new(at.X, at.Y, at.Z - len / 2 - d * 0.82), r.band, r.bandMat)
	-- пояски
	for _, k in { -0.28, 0.12 } do
		b:cyl(d * 1.04, 0.16, at + Vector3.new(0, 0, len * k), Vector3.zAxis, r.band, r.bandMat)
	end
	if r.wick then -- фитиль у петарды
		b:rod({ at + Vector3.new(0, d * 0.4, len * 0.3), at + Vector3.new(0, d * 0.75, len * 0.38), at + Vector3.new(0, d * 0.85, len * 0.5) }, 0.08, Color3.fromRGB(60, 50, 40), Enum.Material.Fabric)
	end
	if r.intake then -- воздухозаборник сверху
		b:block(Vector3.new(d * 0.35, d * 0.22, len * 0.35), CFrame.new(at.X, at.Y + d * 0.52, at.Z - len * 0.05), BLACK, Enum.Material.Metal)
	end
	-- сопло: раструб + тёмная дыра + (у старших тиров) светящееся кольцо
	b:cyl(d * 0.82, 0.55, Vector3.new(at.X, at.Y, back + 0.22), Vector3.zAxis, r.nozzle, Enum.Material.Metal)
	b:cyl(d * 0.95, 0.18, Vector3.new(at.X, at.Y, back + 0.5), Vector3.zAxis, r.nozzle, Enum.Material.Metal)
	b:cyl(d * 0.6, 0.06, Vector3.new(at.X, at.Y, back + 0.6), Vector3.zAxis, BLACK)
	if r.glow then
		b:cyl(d * 0.42, 0.07, Vector3.new(at.X, at.Y, back + 0.62), Vector3.zAxis, r.glow, Enum.Material.Neon)
	end
	-- стабилизаторы: треугольные крылышки в хвосте
	local h = d * 0.75
	local start = if r.fins == 3 then 0 elseif r.fins == 2 then 90 else 45
	for i = 0, r.fins - 1 do
		local a = math.rad(start + i * 360 / r.fins)
		local cf = CFrame.new(at.X, at.Y, back - 0.55) * CFrame.Angles(0, 0, a) * CFrame.new(0, d / 2 + h / 2 - 0.05, 0)
		b:wedge(Vector3.new(0.12, h, 1.1), cf, r.fin, r.finMat)
	end
	if r.canards then -- маленькие передние крылышки
		for _, sx in { -1, 1 } do
			b:wedge(Vector3.new(0.1, d * 0.35, 0.6), CFrame.new(at.X, at.Y, at.Z - len * 0.3) * CFrame.Angles(0, 0, sx * math.rad(90)) * CFrame.new(0, d / 2 + d * 0.15, 0), r.fin, r.finMat)
		end
	end
	return Vector3.new(at.X, at.Y, back + 0.6)
end

-- Где у каждой модели саней крепятся ракеты и фары
local MOUNTS = {
	tube = { x = 3.95, y = 0.3, z = 0.6, lights = Vector3.new(1.15, 0.85, -3.3) },
	classic = { x = 2.25, y = 0.45, z = 0.6, lights = Vector3.new(1.4, 0.9, -2.55) },
	board = { x = 1.5, y = -0.15, z = 0.3, lights = Vector3.new(0.85, -0.05, -3.15) },
	plane = { x = 2.75, y = -0.2, z = 0.3, lights = Vector3.new(2.2, -0.3, -1.3), onWing = true },
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
	local r = ROCKETS[math.clamp(rocketTier, 0, 5)]
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
	if sledTier >= 2 and id ~= "plane" then
		local z = if id == "tube" then 3.9 elseif id == "classic" then 3.7 else 3.3
		local yy = if id == "tube" then 1.2 elseif id == "classic" then 1.0 else 0.0
		-- спойлер: две стойки + крыло
		for _, sx in { -1, 1 } do
			b:block(Vector3.new(0.18, 0.7, 0.4), CFrame.new(sx * 0.9, yy, z), BLACK)
		end
		b:block(Vector3.new(2.6, 0.14, 0.7), CFrame.new(0, yy + 0.4, z + 0.1) * CFrame.Angles(math.rad(-10), 0, 0), accent)
		for _, sx in { -1, 1 } do
			b:block(Vector3.new(0.1, 0.45, 0.8), CFrame.new(sx * 1.3, yy + 0.45, z + 0.1), accent)
		end
	end
	if sledTier >= 3 and id ~= "plane" then
		local z = if id == "tube" then -3.4 elseif id == "classic" then -2.5 else -2.4
		local yy = if id == "tube" then 1.4 elseif id == "classic" then 1.25 else 0.35
		local glass = b:block(Vector3.new(3.6, 1.4, 0.18), CFrame.new(0, yy, z) * CFrame.Angles(math.rad(-25), 0, 0), Color3.fromRGB(170, 220, 255), Enum.Material.Glass)
		glass.Transparency = 0.35
		b:block(Vector3.new(3.7, 0.16, 0.24), CFrame.new(0, yy + 0.66, z + 0.3) * CFrame.Angles(math.rad(-25), 0, 0), BLACK)
	end
	if sledTier >= 4 then -- золотой пояс/бампер
		local gold = Color3.fromRGB(240, 195, 60)
		if id == "tube" then
			b:torus(Vector3.new(0, 0.05, 0), 3.95, 0.22, 26, gold, Enum.Material.SmoothPlastic)
		else
			local z = if id == "classic" then -3.0 elseif id == "board" then -3.6 else -2.9
			local yy = if id == "board" then -0.25 else 0.0
			b:rod({ Vector3.new(-1.6, yy, z + 0.4), Vector3.new(-0.8, yy, z), Vector3.new(0.8, yy, z), Vector3.new(1.6, yy, z + 0.4) }, 0.22, gold, Enum.Material.SmoothPlastic)
		end
	end
	if sledTier >= 5 then -- неоновая подсветка снизу
		for _, sx in { -1, 1 } do
			b:block(Vector3.new(0.12, 0.12, 4.5), CFrame.new(sx * (if id == "tube" then 3.0 else 1.6), -0.55, 0.2), accent, Enum.Material.Neon)
		end
	end
	return nozzle
end

function SledModels.build(parent: Instance, base: CFrame, id: string, look: Look, weldTo: BasePart?, painted: boolean?): number
	local b = newBuilder(parent, base, weldTo)
	b.main = look.main
	b.shine = look.shine or 0
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
