-- Корпуса саней из Part (по модели из Config.SLEDS): чертёж в комментарии над каждым builder-ом.
-- Это же — фолбэк, пока нет шаблонов мешей (SledModels/BodyMeshes).

local B = require(script.Parent.Builder)
type Look = B.Look
local WOOD, WOOD_DARK, STEEL, BLACK, WHITE = B.WOOD, B.WOOD_DARK, B.STEEL, B.BLACK, B.WHITE

local Bodies = {}

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

Bodies.BUILDERS = {
	tube = buildTube,
	classic = buildClassic,
	board = buildBoard,
	plane = buildPlane,
	saucer = buildSaucer,
	toboggan = buildToboggan,
	kayak = buildKayak,
	bobsled = buildBobsled,
	snowmobile = buildSnowmobile,
}

return Bodies
