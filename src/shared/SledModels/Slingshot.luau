-- Рогатка (апгрейд «Запуск», тиры 0–10): столб тира + намотка резинки; цвета резинки по тирам.

local B = require(script.Parent.Builder)
type Look = B.Look
local STEEL, BLACK, WHITE = B.STEEL, B.BLACK, B.WHITE

local Slingshot = {}

------------------------------------------------------------------ столбы рогатки (апгрейд «Запуск»)
-- Каждый тир — свой столб, как в оригинале: бревно → стальной кнехт → колонна → гидравлика →
-- золотая колонна с камнем → неоновый обелиск. Вокруг верха намотана резинка.
-- base — центр столба (высота 9, низ на −4.5); резинка крепится на высоте +3.5.
Slingshot.ROPE_COLORS = {
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
Slingshot.ROPE_GLOW = { [5] = true, [6] = true, [7] = true, [8] = true, [9] = true, [10] = true }

function Slingshot.build(parent: Instance, base: CFrame, tier: number)
	local b = B.new(parent, base, nil)
	tier = math.clamp(tier, 0, 10)
	local Y = Vector3.yAxis
	local function v(y: number): Vector3
		return Vector3.new(0, y, 0)
	end
	local rope = Slingshot.ROPE_COLORS[tier + 1]
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
		b:torus(v(3.15 + i * 0.32), postR + 0.08, 0.3, 14, rope, if Slingshot.ROPE_GLOW[tier] then Enum.Material.Neon else Enum.Material.Fabric)
	end
end

return Slingshot
