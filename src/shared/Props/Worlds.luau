-- Модели миров 4–7: ледяные пещеры, северное сияние, снежный вулкан, конфетная гора.
-- Часть shared/Props (см. Props/init).

local Base = require(script.Parent.Base)

local Props = Base.Props
local Meshes = Base.Meshes
local part, deco, pick = Base.part, Base.deco, Base.pick
local SNOW, BLACK = Base.SNOW, Base.BLACK

------------------------------------------------------------------ Мир 4: Ледяные пещеры
local ICE = Color3.fromRGB(170, 225, 250)
local ICE_DEEP = Color3.fromRGB(90, 170, 230)
-- Ледяная глыба (препятствие, разбивается)
function Props.iceBlock(rng: Random, base: CFrame, parent: Instance)
	local s = rng:NextNumber(4.5, 6)
	part("Part", { Size = Vector3.new(s * 1.2, s, s), CFrame = base * CFrame.new(0, s / 2, 0) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0), Material = Enum.Material.Glass, Color = ICE, Transparency = 0.25 }, parent)
	deco({ Size = Vector3.new(s * 0.7, s * 0.6, s * 0.55), CFrame = base * CFrame.new(0, s / 2, 0), Material = Enum.Material.Ice, Color = ICE_DEEP }, parent)
	deco({ Size = Vector3.new(s * 1.1, 0.4, s * 0.9), CFrame = base * CFrame.new(0, s + 0.1, 0), Material = Enum.Material.Snow, Color = SNOW }, parent)
end
-- Сталагмит: сужающаяся ледяная колонна
function Props.stalagmite(rng: Random, base: CFrame, parent: Instance, collide: boolean?)
	local h = rng:NextNumber(7, 11)
	local maker = if collide == false then deco else function(pr, pa) return part("Part", pr, pa) end
	for k = 0, 3 do
		local w = (4 - k) * 0.9
		maker({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(h / 4 + 0.2, w, w), CFrame = base * CFrame.new(0, h / 8 + k * h / 4, 0) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Ice, Color = ICE:Lerp(ICE_DEEP, k * 0.2) }, parent)
	end
end
-- Друза кристаллов: светящиеся остроконечные призмы. Меш (#45): шестигранная друза одним MeshPart
-- (1 деталь вместо 8–14). Random-вызовы — как у модели из Part.
function Props.crystalCluster(rng: Random, base: CFrame, parent: Instance)
	local col = pick(rng, { Color3.fromRGB(120, 220, 255), Color3.fromRGB(190, 140, 255), Color3.fromRGB(140, 255, 220) })
	local list = {}
	for k = 1, rng:NextInteger(4, 7) do
		local h = rng:NextNumber(4, 11)
		local x, z = rng:NextNumber(-3, 3), rng:NextNumber(-3, 3)
		list[k] = { h = h, x = x, z = z, a = rng:NextNumber(-0.5, 0.5), b = rng:NextNumber(0, 6), c = rng:NextNumber(-0.5, 0.5) }
	end
	if Meshes.has("ice_crystal") then
		local s = 4 + list[1].h * 0.5
		Meshes.place("ice_crystal", base * CFrame.Angles(0, list[1].b, 0), Vector3.new(s, s * 1.15, s), { Material = Enum.Material.Neon, Color = Meshes.vary(col, base.Position, 0.08), Transparency = 0.15 }, parent)
		return
	end
	for _, k in list do
		local c = base * CFrame.new(k.x, 0, k.z) * CFrame.Angles(k.a, k.b, k.c)
		deco({ Size = Vector3.new(1.4, k.h, 1.4), CFrame = c * CFrame.new(0, k.h / 2, 0), Material = Enum.Material.Neon, Color = col, Transparency = 0.15 }, parent)
		deco({ Size = Vector3.new(1, 1, 1), CFrame = c * CFrame.new(0, k.h, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)), Material = Enum.Material.Neon, Color = col, Transparency = 0.15 }, parent)
	end
end
-- Ледяная скала-стена вдоль трассы с сосульками. Меш (#45): утёс со слоями из ледника (1 деталь
-- вместо 6); Random-вызовы — как у модели из Part.
function Props.iceCliff(rng: Random, base: CFrame, side: number, parent: Instance)
	local h = rng:NextNumber(18, 34)
	local w = rng:NextNumber(16, 26)
	local turn = rng:NextNumber(-0.2, 0.2)
	local icicles = {}
	for k = 1, 4 do
		icicles[k] = rng:NextNumber(2, 5)
	end
	local ice = Meshes.vary(ICE, base.Position, 0.06)
	if Meshes.has("crag") then
		local c = base * CFrame.new(side * 7, -1, 0) * CFrame.Angles(0, math.pi / 2 + turn, 0)
		Meshes.place("crag", c, Vector3.new(w / 1.6, (h + 2) / 3.46, 14 / 1.3), { Material = Enum.Material.Glacier, Color = ice, CastShadow = true }, parent)
		return
	end
	deco({ Size = Vector3.new(14, h, w), CFrame = base * CFrame.new(side * 7, h / 2, 0) * CFrame.Angles(0, turn, 0), Material = Enum.Material.Glacier, Color = ice }, parent)
	deco({ Size = Vector3.new(15, 2, w + 1), CFrame = base * CFrame.new(side * 7, h + 0.5, 0), Material = Enum.Material.Snow, Color = SNOW }, parent)
	for k, ih in icicles do
		local z = (k - 2.5) * w / 4
		deco({ Size = Vector3.new(0.8, ih, 0.8), CFrame = base * CFrame.new(side * 0.6, h * 0.6 - ih / 2, z), Material = Enum.Material.Ice, Color = ICE }, parent)
	end
end

------------------------------------------------------------------ Мир 5: Северное сияние
-- Иглу: снежный купол из «кирпичей», вход-туннель и тёплый свет внутри
function Props.igloo(rng: Random, base: CFrame, parent: Instance)
	local r = rng:NextNumber(8, 11)
	deco({ Shape = Enum.PartType.Ball, Size = Vector3.new(r * 2, r * 1.6, r * 2), CFrame = base, Material = Enum.Material.Snow, Color = SNOW }, parent)
	for k = 1, 3 do -- швы между рядами «кирпичей»
		deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, r * 2 * math.cos(math.rad(k * 22)) + 0.2, r * 2 * math.cos(math.rad(k * 22)) + 0.2), CFrame = base * CFrame.new(0, r * 0.8 * math.sin(math.rad(k * 22)), 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(205, 220, 240) }, parent)
	end
	local door = base * CFrame.Angles(0, rng:NextNumber(0, 6), 0)
	deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(5, 5, 5), CFrame = door * CFrame.new(0, 1.5, -r) * CFrame.Angles(0, math.rad(90), 0), Material = Enum.Material.Snow, Color = SNOW }, parent)
	local hole = deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 3.4, 3.4), CFrame = door * CFrame.new(0, 1.5, -r - 2.5) * CFrame.Angles(0, math.rad(90), 0), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 180, 90) }, parent)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 170, 80)
	light.Range = 16
	light.Brightness = 2
	light.Parent = hole
end
-- Полярное сияние: широкие полупрозрачные светящиеся ленты высоко в небе
function Props.aurora(rng: Random, base: CFrame, parent: Instance)
	local col = pick(rng, { Color3.fromRGB(80, 255, 160), Color3.fromRGB(120, 200, 255), Color3.fromRGB(190, 120, 255) })
	local yaw = rng:NextNumber(0, math.pi)
	for k = 0, 5 do
		local c = base * CFrame.Angles(0, yaw, 0) * CFrame.new(k * 34 - 85, math.sin(k * 1.3) * 10, math.cos(k * 0.9) * 18) * CFrame.Angles(0, math.sin(k) * 0.5, 0)
		deco({ Size = Vector3.new(36, 60, 0.5), CFrame = c, Material = Enum.Material.Neon, Color = col:Lerp(Color3.fromRGB(190, 120, 255), k / 8), Transparency = 0.72 }, parent)
	end
end
-- Фонарь на столбе (тёплый свет в ночи)
function Props.lantern(base: CFrame, parent: Instance)
	deco({ Size = Vector3.new(0.5, 7, 0.5), CFrame = base * CFrame.new(0, 3.5, 0), Material = Enum.Material.Wood, Color = Color3.fromRGB(90, 60, 40) }, parent)
	local glow = deco({ Size = Vector3.new(1.3, 1.6, 1.3), CFrame = base * CFrame.new(0, 7.6, 0), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 190, 90) }, parent)
	deco({ Size = Vector3.new(1.7, 0.3, 1.7), CFrame = base * CFrame.new(0, 8.5, 0), Color = BLACK }, parent)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 180, 90)
	light.Range = 22
	light.Brightness = 1.6
	light.Parent = glow
end
-- Штабель ящиков (препятствие, разбивается)
function Props.crates(rng: Random, base: CFrame, parent: Instance)
	for k = 1, rng:NextInteger(2, 4) do
		local c = base * CFrame.new((k - 2) * 2.6 + rng:NextNumber(-0.4, 0.4), if k == 4 then 4.4 else 1.5, rng:NextNumber(-0.6, 0.6)) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0)
		part("Part", { Size = Vector3.new(3, 3, 3), CFrame = c, Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(170, 120, 70) }, parent)
		deco({ Size = Vector3.new(3.1, 0.4, 3.1), CFrame = c * CFrame.new(0, 1.55, 0), Material = Enum.Material.Snow, Color = SNOW }, parent)
	end
end

------------------------------------------------------------------ Мир 6: Снежный вулкан
local BASALT = Color3.fromRGB(55, 52, 58)
local LAVA = Color3.fromRGB(255, 110, 30)
-- Лавовый камень: тёмная глыба со светящимися трещинами
function Props.lavaRock(rng: Random, base: CFrame, parent: Instance)
	local s = rng:NextNumber(4.5, 6.5)
	local c = base * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3))
	part("Part", { Size = Vector3.new(s * 1.2, s * 0.85, s), CFrame = c * CFrame.new(0, s * 0.4, 0), Material = Enum.Material.Basalt, Color = BASALT }, parent)
	for _ = 1, 3 do
		deco({ Size = Vector3.new(s * 1.22, 0.25, 0.3), CFrame = c * CFrame.new(0, s * rng:NextNumber(0.2, 0.7), rng:NextNumber(-s / 2, s / 2)) * CFrame.Angles(0, 0, rng:NextNumber(-0.4, 0.4)), Material = Enum.Material.Neon, Color = LAVA }, parent)
	end
end
-- Базальтовые столбы (шестигранники)
function Props.basalt(rng: Random, base: CFrame, parent: Instance, collide: boolean?)
	local maker = if collide == false then deco else function(pr, pa) return part("Part", pr, pa) end
	for k = 1, rng:NextInteger(3, 5) do
		local h = rng:NextNumber(3, 9)
		maker({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 2.4, 2.4), CFrame = base * CFrame.new((k - 3) * 2.1, h / 2, rng:NextNumber(-1, 1)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Basalt, Color = BASALT:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.3)) }, parent)
		deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 2.2, 2.2), CFrame = base * CFrame.new((k - 3) * 2.1, h + 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Snow, Color = SNOW }, parent)
	end
end
-- Лавовое озерцо с каменным бортом и свечением
function Props.lavaPool(rng: Random, base: CFrame, parent: Instance)
	local r = rng:NextNumber(10, 18)
	deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, r * 2 + 3, r * 2 + 3), CFrame = base * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Basalt, Color = BASALT }, parent)
	local lava = deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.3, r * 2, r * 2), CFrame = base * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Neon, Color = LAVA }, parent)
	local light = Instance.new("PointLight")
	light.Color = LAVA
	light.Range = 30
	light.Brightness = 2
	light.Parent = lava
	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(80, 75, 80)
	smoke.Opacity = 0.15
	smoke.RiseVelocity = 6
	smoke.Size = 6
	smoke.Parent = lava
end
-- Обгоревшее дерево
function Props.charredTree(rng: Random, base: CFrame, parent: Instance)
	local h = rng:NextNumber(10, 18)
	local dark = Color3.fromRGB(40, 34, 32)
	deco({ Size = Vector3.new(1.4, h, 1.4), CFrame = base * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, rng:NextNumber(-0.1, 0.1)), Material = Enum.Material.Wood, Color = dark }, parent)
	for k = 1, 3 do
		local y = h * (0.45 + k * 0.15)
		local a = rng:NextNumber(0, 6)
		deco({ Size = Vector3.new(0.6, h * 0.3, 0.6), CFrame = base * CFrame.new(0, y, 0) * CFrame.Angles(0, a, math.rad(45)) * CFrame.new(0, h * 0.13, 0), Material = Enum.Material.Wood, Color = dark }, parent)
	end
end
-- Вулкан на горизонте: тёмный конус, снежные склоны, светящийся кратер и дым
function Props.volcano(rng: Random, base: CFrame, parent: Instance)
	local s = rng:NextNumber(110, 170)
	for k = 0, 3 do
		local w = s * (1.6 - k * 0.32)
		deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(s * 0.26, w, w), CFrame = base * CFrame.new(0, s * 0.13 + k * s * 0.24 - s * 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Material = if k < 2 then Enum.Material.Snow else Enum.Material.Basalt, Color = if k < 2 then SNOW:Lerp(BASALT, 0.25 * k) else BASALT }, parent)
	end
	local crater = deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, s * 0.42, s * 0.42), CFrame = base * CFrame.new(0, s * 0.85, 0) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Neon, Color = LAVA }, parent)
	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(70, 65, 70)
	smoke.Opacity = 0.3
	smoke.RiseVelocity = 12
	smoke.Size = 30
	smoke.Parent = crater
end

------------------------------------------------------------------ Мир 7: Конфетная гора
local CANDY = { Color3.fromRGB(255, 120, 180), Color3.fromRGB(120, 210, 255), Color3.fromRGB(255, 220, 90), Color3.fromRGB(150, 230, 120), Color3.fromRGB(200, 140, 255) }
-- Леденцовая трость: красно-белые полоски и крюк
function Props.candyCane(rng: Random, base: CFrame, parent: Instance, h: number?, collide: boolean?)
	h = h or rng:NextNumber(10, 16)
	local maker = if collide then function(pr, pa) return part("Part", pr, pa) end else deco
	local c = base * CFrame.Angles(0, rng:NextNumber(0, 6), 0)
	local n = math.floor((h :: number) / 1.4)
	for k = 0, n - 1 do
		maker({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.42, 1.3, 1.3), CFrame = c * CFrame.new(0, 0.7 + k * 1.4, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = if k % 2 == 0 then Color3.fromRGB(230, 40, 50) else Color3.new(1, 1, 1) }, parent)
	end
	local top = (h :: number) - 0.2
	for k = 0, 6 do -- крюк
		local a = math.rad(k * 30)
		deco({ Shape = Enum.PartType.Ball, Size = Vector3.one * 1.35, CFrame = c * CFrame.new(1.6 - math.cos(a) * 1.6, top + math.sin(a) * 1.6, 0), Color = if k % 2 == 0 then Color3.fromRGB(230, 40, 50) else Color3.new(1, 1, 1) }, parent)
	end
end
-- Леденец на палочке
function Props.lollipop(rng: Random, base: CFrame, parent: Instance)
	local h = rng:NextNumber(9, 15)
	local r = rng:NextNumber(3, 5)
	deco({ Size = Vector3.new(0.6, h, 0.6), CFrame = base * CFrame.new(0, h / 2, 0), Color = Color3.new(1, 1, 1) }, parent)
	local face = base * CFrame.new(0, h + r * 0.8, 0) * CFrame.Angles(0, rng:NextNumber(0, 6), 0)
	local a, b = pick(rng, CANDY), pick(rng, CANDY)
	for k = 0, 3 do
		deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8 + k * 0.02, r * 2 * (1 - k * 0.22), r * 2 * (1 - k * 0.22)), CFrame = face * CFrame.Angles(0, math.rad(90), 0), Color = if k % 2 == 0 then a else b }, parent)
	end
end
-- Пряничный домик с глазурью на крыше
function Props.gingerHouse(rng: Random, base: CFrame, side: number, parent: Instance)
	local w, h = rng:NextNumber(10, 14), rng:NextNumber(7, 9)
	local c = base * CFrame.Angles(0, if side > 0 then -math.pi / 2 else math.pi / 2, 0)
	local ginger = Color3.fromRGB(175, 105, 55)
	deco({ Size = Vector3.new(w, h, w * 0.8), CFrame = c * CFrame.new(0, h / 2, 0), Color = ginger }, parent)
	for _, sx in { -1, 1 } do
		deco({ Size = Vector3.new(w * 0.62, 0.8, w * 0.9), CFrame = c * CFrame.new(sx * w * 0.24, h + w * 0.18, 0) * CFrame.Angles(0, 0, sx * math.rad(-38)), Color = ginger:Lerp(Color3.new(0, 0, 0), 0.15) }, parent)
		deco({ Size = Vector3.new(w * 0.62, 0.35, 0.5), CFrame = c * CFrame.new(sx * w * 0.24, h + w * 0.18 + 0.2, -w * 0.45) * CFrame.Angles(0, 0, sx * math.rad(-38)), Color = Color3.new(1, 1, 1) }, parent) -- глазурь
	end
	deco({ Size = Vector3.new(w * 0.22, h * 0.5, 0.3), CFrame = c * CFrame.new(0, h * 0.25, -w * 0.41), Color = Color3.fromRGB(110, 60, 30) }, parent)
	for k = 1, 4 do
		deco({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, CFrame = c * CFrame.new((k - 2.5) * w * 0.22, h * 0.82, -w * 0.41), Color = CANDY[k] }, parent)
	end
end
-- Мармеладка-«капля» (препятствие)
function Props.gumdrop(rng: Random, base: CFrame, parent: Instance)
	local s = rng:NextNumber(4.5, 6)
	local col = pick(rng, CANDY)
	part("Part", { Shape = Enum.PartType.Ball, Size = Vector3.new(s * 1.2, s * 1.3, s * 1.2), CFrame = base * CFrame.new(0, s * 0.4, 0), Color = col, Material = Enum.Material.Glass, Transparency = 0.1 }, parent)
	for _ = 1, 6 do -- сахарные крупинки
		deco({ Size = Vector3.one * 0.35, CFrame = base * CFrame.new(rng:NextNumber(-s / 2, s / 2), s * rng:NextNumber(0.5, 0.95), rng:NextNumber(-s / 2, s / 2)), Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon }, parent)
	end
end
-- Капкейк: стаканчик, крем, вишенка (препятствие, разбивается)
function Props.cupcake(rng: Random, base: CFrame, parent: Instance)
	part("Part", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 4.6, 4.6), CFrame = base * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = pick(rng, CANDY) }, parent)
	part("Part", { Shape = Enum.PartType.Ball, Size = Vector3.new(5.2, 3.4, 5.2), CFrame = base * CFrame.new(0, 3.6, 0), Color = Color3.fromRGB(255, 240, 245) }, parent)
	deco({ Shape = Enum.PartType.Ball, Size = Vector3.one * 1.2, CFrame = base * CFrame.new(0, 5.5, 0), Color = Color3.fromRGB(220, 30, 50) }, parent)
end
-- Плитка шоколада (препятствие, разбивается)
function Props.chocolate(rng: Random, base: CFrame, parent: Instance)
	local c = base * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0)
	part("Part", { Size = Vector3.new(7, 4, 1.4), CFrame = c * CFrame.new(0, 2, 0), Color = Color3.fromRGB(95, 55, 30) }, parent)
	for x = -1, 1 do
		for y = 0, 1 do
			deco({ Size = Vector3.new(2, 1.6, 0.3), CFrame = c * CFrame.new(x * 2.2, 1.1 + y * 1.8, -0.75), Color = Color3.fromRGB(115, 70, 40) }, parent)
		end
	end
	deco({ Size = Vector3.new(7.1, 1.6, 1.5), CFrame = c * CFrame.new(0, 0.8, 0), Color = Color3.fromRGB(240, 60, 90) }, parent) -- обёртка
end


return Props
