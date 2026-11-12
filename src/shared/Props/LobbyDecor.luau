-- «Живые» детали лобби: костёр, флагшток (качается на ветру), гирлянда флажков; фонарь, подиум
-- витрины, рама табло, ворота старта — своими мешами (gen_meshes.py: lamp_post, podium,
-- board_frame, start_gate) с фолбэком на Part, пока меш не загружен. Часть shared/Props.

local Base = require(script.Parent.Base)

local Props = Base.Props
local deco = Base.deco
local Meshes = Base.Meshes
local IRON = Color3.fromRGB(48, 52, 66)
local WOOD = Color3.fromRGB(120, 80, 45)
local WARM = Color3.fromRGB(255, 190, 90)

------------------------------------------------------------------ Лобби: «живые» детали
-- Костёр с кольцом камней, тремя брёвнами-скамейками, искрами, дымом и тёплым светом
function Props.campfire(base: CFrame, parent: Instance)
	for k = 0, 2 do
		deco({ Size = Vector3.new(3.6, 0.7, 0.7), CFrame = base * CFrame.new(0, 0.45, 0) * CFrame.Angles(0, math.rad(k * 60), math.rad(8)), Material = Enum.Material.Wood, Color = Color3.fromRGB(110, 70, 40) }, parent)
	end
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		deco({ Shape = Enum.PartType.Ball, Size = Vector3.new(1.3, 0.9, 1.1), CFrame = base * CFrame.new(math.cos(a) * 2.4, 0.3, math.sin(a) * 2.4) * CFrame.Angles(0, a, 0), Material = Enum.Material.Slate, Color = Color3.fromRGB(120, 120, 128) }, parent)
	end
	local flame = deco({ Size = Vector3.new(1.4, 2.2, 1.4), CFrame = base * CFrame.new(0, 1.6, 0) * CFrame.Angles(0, 0.6, 0), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 150, 40) }, parent)
	deco({ Size = Vector3.new(0.8, 1.2, 0.8), CFrame = base * CFrame.new(0, 2.6, 0) * CFrame.Angles(0, 1.3, 0), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 230, 120) }, parent)
	local att = Instance.new("Attachment")
	att.Position = Vector3.new(0, 1.2, 0)
	att.Parent = flame
	local fire = Instance.new("ParticleEmitter")
	fire.Texture = "rbxasset://textures/particles/fire_main.dds"
	fire.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 90, 30))
	fire.LightEmission = 0.8
	fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0.3) })
	fire.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	fire.Lifetime = NumberRange.new(0.5, 0.9)
	fire.Speed = NumberRange.new(3, 5)
	fire.SpreadAngle = Vector2.new(12, 12)
	fire.Rate = 14
	fire.Parent = att
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 200, 90))
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.25, 0)
	sparks.Lifetime = NumberRange.new(0.8, 1.6)
	sparks.Speed = NumberRange.new(5, 9)
	sparks.SpreadAngle = Vector2.new(25, 25)
	sparks.Acceleration = Vector3.new(1.5, 2, 0)
	sparks.Rate = 6
	sparks.Parent = att
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(190, 190, 195))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 5) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(2, 3.5)
	smoke.Speed = NumberRange.new(2, 3)
	smoke.Acceleration = Vector3.new(1, 0.5, 0)
	smoke.Rate = 2
	smoke.Parent = att
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 170, 90)
	light.Range = 20
	light.Brightness = 1.6
	light.Parent = flame
	-- брёвна-скамейки вокруг
	for k = 0, 2 do
		local a = math.rad(k * 120 + 60)
		deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(7, 1.4, 1.4), CFrame = base * CFrame.new(math.cos(a) * 6, 0.7, math.sin(a) * 6) * CFrame.Angles(0, -a, 0), Material = Enum.Material.Wood, Color = Color3.fromRGB(130, 85, 50), CastShadow = true }, parent)
	end
end

-- Флагшток с флагом. Флаг помечен тегом LobbyFlag и атрибутом BaseCF — клиент качает его «на ветру»
function Props.flagpole(base: CFrame, color: Color3, parent: Instance, height: number?)
	local h = height or 16
	deco({ Size = Vector3.new(0.5, h, 0.5), CFrame = base * CFrame.new(0, h / 2, 0), Material = Enum.Material.Metal, Color = Color3.fromRGB(225, 228, 235) }, parent)
	deco({ Shape = Enum.PartType.Ball, Size = Vector3.one * 1.1, CFrame = base * CFrame.new(0, h + 0.4, 0), Material = Enum.Material.Metal, Color = Color3.fromRGB(255, 205, 60) }, parent)
	local flagCF = base * CFrame.new(0.25, h - 2.2, 0)
	local flag = deco({ Size = Vector3.new(6, 3.6, 0.2), CFrame = flagCF * CFrame.new(3, 0, 0), Color = color }, parent)
	flag.Name = "Flag"
	flag:SetAttribute("BaseCF", flagCF) -- точка крепления: вращение вокруг неё
	game:GetService("CollectionService"):AddTag(flag, "LobbyFlag")
	return flag
end

-- Гирлянда из треугольных флажков между двумя точками (провисает дугой)
function Props.garland(from: Vector3, to: Vector3, parent: Instance, rng: Random?)
	local cols = { Color3.fromRGB(240, 80, 90), Color3.fromRGB(255, 205, 60), Color3.fromRGB(80, 180, 240), Color3.fromRGB(110, 210, 120), Color3.fromRGB(240, 130, 200) }
	local d = to - from
	local n = math.max(2, math.floor(d.Magnitude / 3.2))
	local prev = from
	for k = 1, n do
		local t = k / n
		local p = from + d * t - Vector3.new(0, math.sin(t * math.pi) * d.Magnitude * 0.06, 0)
		local seg = p - prev
		local mid = (p + prev) / 2
		local rope = CFrame.lookAt(mid, mid + seg.Unit)
		deco({ Size = Vector3.new(0.12, 0.12, seg.Magnitude), CFrame = rope, Color = Color3.fromRGB(90, 70, 50) }, parent)
		if k < n then
			local col = if rng then cols[rng:NextInteger(1, #cols)] else cols[(k % #cols) + 1]
			deco({ Size = Vector3.new(1.6, 2.2, 0.15), CFrame = CFrame.lookAt(p, p + Vector3.new(seg.X, 0, seg.Z).Unit) * CFrame.new(0, -1.15, 0) * CFrame.Angles(0, math.rad(90), 0), Color = col }, parent, "WedgePart")
		end
		prev = p
	end
end

------------------------------------------------------------------ Лобби: меши архитектуры
-- Фонарь на столбе (~10 studs): чугунный меш + тёплое «стекло» Neon внутри клетки + свет.
-- Без меша — прежний деревянный фонарь (Props.lantern). Возвращает деталь-свечение.
function Props.lampPost(base: CFrame, parent: Instance): BasePart?
	if not Meshes.has("lamp_post") then
		Props.lantern(base, parent)
		return nil
	end
	Meshes.place("lamp_post", base, Vector3.one, { Material = Enum.Material.Metal, Color = IRON, CastShadow = true }, parent)
	local glow = deco({ Size = Vector3.new(0.95, 1.3, 0.95), CFrame = base * CFrame.new(0, 8.25, 0), Material = Enum.Material.Neon, Color = WARM, Transparency = 0.1 }, parent)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 180, 90)
	light.Range = 18
	light.Brightness = 1.4
	light.Parent = glow
	return glow
end

-- Подиум витрины: ступенчатый круглый меш (радиус r, высота 2.2) + неоновое кольцо цвета редкости
-- и прожектор сверху. Возвращает кадр верха подиума (куда ставить сани).
function Props.podium(base: CFrame, r: number, color: Color3, parent: Instance): CFrame
	local h = 2.2
	local stone = Color3.fromRGB(225, 230, 242)
	if Meshes.has("podium") then
		Meshes.place("podium", base, Vector3.new(r, h / 0.62, r), { Material = Enum.Material.Marble, Color = stone, CastShadow = true }, parent)
	else
		deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, r * 2, r * 2), CFrame = base * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = stone, CastShadow = true }, parent)
	end
	-- кольцо на кромке среднего яруса (0.42–0.46 высоты меша)
	deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.35, r * 1.76, r * 1.76), CFrame = base * CFrame.new(0, h * 0.7, 0) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Neon, Color = color }, parent)
	-- прожектор: невидимая точка над подиумом, светит вниз (тени выключены — дёшево)
	local lamp = deco({ Name = "Spot", Size = Vector3.one, CFrame = base * CFrame.new(0, 16, 0) * CFrame.Angles(math.rad(-90), 0, 0), Transparency = 1 }, parent)
	local spot = Instance.new("SpotLight")
	spot.Color = color:Lerp(Color3.new(1, 1, 1), 0.5)
	spot.Angle = 45
	spot.Range = 22
	spot.Brightness = 3
	spot.Shadows = false
	spot.Face = Enum.NormalId.Front
	spot.Parent = lamp
	return base * CFrame.new(0, h, 0)
end

-- Рама табло 21.6 × 18.6 (меш) вокруг проёма 18 × 10 на высоте 6–16; без меша — два столба
-- и снежная полоса. at — основание, лицом (LookVector) к зрителю.
function Props.boardFrame(at: CFrame, parent: Instance)
	if Meshes.has("board_frame") then
		Meshes.place("board_frame", at, Vector3.one, { Material = Enum.Material.Wood, Color = WOOD, CastShadow = true }, parent)
		-- снег на скатах крыши (две тонкие плиты по скатам 17.0 → 18.4 на полуширине 10.8)
		for _, sx in { -1, 1 } do
			deco({ Size = Vector3.new(10.9, 0.35, 2.7), CFrame = at * CFrame.new(sx * 5.4, 17.95, 0) * CFrame.Angles(0, 0, sx * -math.atan2(1.4, 10.8)), Material = Enum.Material.Snow, Color = Color3.fromRGB(250, 252, 255) }, parent)
		end
		return
	end
	for _, sx in { -1, 1 } do
		deco({ Size = Vector3.new(1, 17, 1), CFrame = at * CFrame.new(sx * 9.6, 8.5, 0.6), Material = Enum.Material.Wood, Color = WOOD, CastShadow = true }, parent)
	end
	deco({ Size = Vector3.new(19.6, 0.8, 1.4), CFrame = at * CFrame.new(0, 16.4, 0), Material = Enum.Material.Snow, Color = Color3.fromRGB(250, 252, 255) }, parent)
end

-- Ворота старта у входа на мостик: две колонны, перемычка и выгнутая балка (меш), на капителях —
-- светящиеся шары; под перемычкой висит вывеска мира (возвращается — текст ставит клиент).
-- Проход 17 studs шириной, низ вывески на 7.4 (персонаж ~5 проходит).
function Props.startGate(at: CFrame, parent: Instance): BasePart
	if Meshes.has("start_gate") then
		Meshes.place("start_gate", at, Vector3.one, { Material = Enum.Material.Wood, Color = WOOD, CastShadow = true }, parent)
	else
		for _, sx in { -1, 1 } do
			deco({ Size = Vector3.new(2, 11, 2), CFrame = at * CFrame.new(sx * 9.5, 5.5, 0), Material = Enum.Material.Wood, Color = WOOD, CastShadow = true }, parent)
		end
		deco({ Size = Vector3.new(21, 1.2, 1.4), CFrame = at * CFrame.new(0, 11.4, 0), Material = Enum.Material.WoodPlanks, Color = WOOD }, parent)
	end
	for _, sx in { -1, 1 } do
		deco({ Shape = Enum.PartType.Ball, Size = Vector3.one * 1.6, CFrame = at * CFrame.new(sx * 9.5, 12.9, 0), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 215, 80) }, parent)
	end
	return deco({ Name = "ArchBeam", Size = Vector3.new(13, 2.4, 0.5), CFrame = at * CFrame.new(0, 8.6, 0.3), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(95, 60, 35) }, parent)
end

------------------------------------------------------------------ Лобби: станции по кругу (#69)
-- Референсы владельца 2026-11-11 (docs/ART_REFERENCES.md): мягкие скруглённые формы, тёплое дерево,
-- снежные шапки с сосульками, свечение только смысловое (портал, фонарь, окно лавки).
local SNOWC = Color3.fromRGB(250, 252, 255)

-- Снежная шапка на горизонтальной кромке: плита + округлые наплывы + капли-сосульки
local function snowCap(cf: CFrame, w: number, d: number, parent: Instance)
	deco({ Size = Vector3.new(w + 0.4, 0.5, d + 0.4), CFrame = cf * CFrame.new(0, 0.25, 0), Material = Enum.Material.Snow, Color = SNOWC }, parent)
	local n = math.max(2, math.floor(w / 3))
	for k = 1, n do
		local x = -w / 2 + (k - 0.5) * w / n
		deco({ Shape = Enum.PartType.Ball, Size = Vector3.new(2.2, 1.1, d * 0.9), CFrame = cf * CFrame.new(x, 0.45, 0), Material = Enum.Material.Snow, Color = SNOWC }, parent)
		if k % 2 == 1 then
			deco({ Size = Vector3.new(0.35, 0.9, 0.35), CFrame = cf * CFrame.new(x + 0.6, -0.4, -d / 2 - 0.05), Material = Enum.Material.Ice, Color = Color3.fromRGB(205, 232, 252), Transparency = 0.1 }, parent)
		end
	end
end
Props.snowCap = snowCap

-- Портал «Миры»: тёмная деревянная рама с крышей-шапкой, внутри — светящаяся жёлтая арка и
-- мерцающая «плёнка»; подошёл — открылось окно миров (зона — деталь "Zone", атрибут Menu = "worlds",
-- её читает client/LobbyMenus). at — основание, лицом к зрителю. Проём 10 × 13.
function Props.worldPortal(at: CFrame, parent: Instance): BasePart
	local frame = Color3.fromRGB(70, 50, 38)
	for _, sx in { -1, 1 } do
		deco({ Size = Vector3.new(2.2, 15, 2.2), CFrame = at * CFrame.new(sx * 6.6, 7.5, 0), Material = Enum.Material.Wood, Color = frame, CastShadow = true }, parent)
		deco({ Size = Vector3.new(3.2, 1.2, 3.2), CFrame = at * CFrame.new(sx * 6.6, 0.6, 0), Material = Enum.Material.Slate, Color = Color3.fromRGB(120, 125, 135) }, parent)
	end
	deco({ Size = Vector3.new(16.6, 1.8, 3), CFrame = at * CFrame.new(0, 15.6, 0), Material = Enum.Material.Wood, Color = frame, CastShadow = true }, parent)
	snowCap(at * CFrame.new(0, 16.5, 0), 16.6, 3, parent)
	-- светящаяся арка: полукольцо из коротких Neon-брусков + прямые стойки
	local n, r, cy = 9, 5, 9.6
	for k = 0, n - 1 do
		local a0, a1 = math.pi * k / n, math.pi * (k + 1) / n
		local x0, y0, x1, y1 = math.cos(a0) * r, math.sin(a0) * r, math.cos(a1) * r, math.sin(a1) * r
		local dx, dy = x1 - x0, y1 - y0
		deco({ Size = Vector3.new(math.sqrt(dx * dx + dy * dy) + 0.3, 0.7, 0.7), CFrame = at * CFrame.new((x0 + x1) / 2, cy + (y0 + y1) / 2, 0) * CFrame.Angles(0, 0, math.atan2(dy, dx)), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 205, 60) }, parent)
	end
	for _, sx in { -1, 1 } do
		deco({ Size = Vector3.new(0.7, cy, 0.7), CFrame = at * CFrame.new(sx * r, cy / 2, 0), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 205, 60) }, parent)
	end
	local film = deco({ Name = "Film", Size = Vector3.new(r * 2 - 0.6, cy + r - 0.6, 0.2), CFrame = at * CFrame.new(0, (cy + r) / 2, 0), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 235, 150), Transparency = 0.6 }, parent)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 210, 110)
	light.Range = 22
	light.Brightness = 2
	light.Parent = film
	-- зона входа перед порталом (невидимая, без коллизий)
	local zone = deco({ Name = "Zone", Size = Vector3.new(10, 6, 7), CFrame = at * CFrame.new(0, 3, -3), Transparency = 1 }, parent)
	zone:SetAttribute("Menu", "worlds")
	return deco({ Name = "Sign", Size = Vector3.new(9, 2.2, 0.4), CFrame = at * CFrame.new(0, 15.6, -1.7), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(95, 60, 35) }, parent)
end

-- Лавка «Сани»: прилавок, 4 столба, полосатый навес, вывеска, снег на крыше; зона перед прилавком
-- (Menu = "sleds") открывает окно саней. at — основание, лицом (−Z) к зрителю. 12 × 7.
function Props.shopStall(at: CFrame, parent: Instance): BasePart
	local wood, cream = Color3.fromRGB(150, 98, 55), Color3.fromRGB(250, 236, 205)
	deco({ Size = Vector3.new(11, 3.4, 3), CFrame = at * CFrame.new(0, 1.7, -1.5), Material = Enum.Material.WoodPlanks, Color = wood, CastShadow = true }, parent)
	deco({ Size = Vector3.new(11.6, 0.4, 3.6), CFrame = at * CFrame.new(0, 3.6, -1.5), Material = Enum.Material.Wood, Color = Color3.fromRGB(120, 78, 42) }, parent)
	deco({ Size = Vector3.new(11, 7, 0.6), CFrame = at * CFrame.new(0, 3.5, 3), Material = Enum.Material.WoodPlanks, Color = cream, CastShadow = true }, parent)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			deco({ Size = Vector3.new(0.8, 8, 0.8), CFrame = at * CFrame.new(sx * 5.6, 4, sz * 3), Material = Enum.Material.Wood, Color = wood }, parent)
		end
	end
	-- навес: полосы через одну, наклон к зрителю, «фестоны» по краю
	local cols = { Color3.fromRGB(225, 70, 70), cream }
	for k = 0, 5 do
		local x = -5.5 + 11 / 6 * (k + 0.5)
		deco({ Size = Vector3.new(11 / 6, 0.35, 7.6), CFrame = at * CFrame.new(x, 8.4, -0.4) * CFrame.Angles(math.rad(-14), 0, 0), Color = cols[k % 2 + 1] }, parent)
		deco({ Shape = Enum.PartType.Ball, Size = Vector3.new(11 / 6, 1.2, 0.5), CFrame = at * CFrame.new(x, 7.3, -4.2), Color = cols[k % 2 + 1] }, parent)
	end
	snowCap(at * CFrame.new(0, 9.05, 0.6) * CFrame.Angles(math.rad(-14), 0, 0), 11, 5, parent)
	local glow = deco({ Size = Vector3.new(9, 0.25, 0.25), CFrame = at * CFrame.new(0, 7.4, -3.4), Material = Enum.Material.Neon, Color = WARM }, parent)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 190, 110)
	light.Range = 14
	light.Brightness = 1.2
	light.Parent = glow
	local zone = deco({ Name = "Zone", Size = Vector3.new(11, 6, 5), CFrame = at * CFrame.new(0, 3, -5.5), Transparency = 1 }, parent)
	zone:SetAttribute("Menu", "sleds")
	return deco({ Name = "Sign", Size = Vector3.new(8, 2, 0.4), CFrame = at * CFrame.new(0, 10.6, -0.2), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(95, 60, 35) }, parent)
end

-- Палатка у костра (оранжевый тент, колышки, свёрнутый спальник)
function Props.tent(at: CFrame, parent: Instance)
	local tent = Color3.fromRGB(240, 140, 50)
	for _, s in { -1, 1 } do
		deco({ Size = Vector3.new(8, 6, 4), CFrame = at * CFrame.new(0, 3, s * 2) * CFrame.Angles(0, if s > 0 then 0 else math.pi, 0), Color = tent, CastShadow = true }, parent, "WedgePart")
	end
	deco({ Size = Vector3.new(0.3, 3.5, 2.4), CFrame = at * CFrame.new(-4.05, 1.75, 0), Color = tent:Lerp(Color3.new(0, 0, 0), 0.45) }, parent)
	deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.6, 1.2, 1.2), CFrame = at * CFrame.new(-6, 0.6, 2.4), Color = Color3.fromRGB(80, 150, 210) }, parent)
	snowCap(at * CFrame.new(0, 5.9, 0), 8, 1, parent)
end

-- Фонарь «виселица»: деревянный столб на каменной плите, кронштейн и висящий тёплый фонарь
function Props.hangLamp(at: CFrame, parent: Instance)
	deco({ Size = Vector3.new(2.4, 0.6, 2.4), CFrame = at * CFrame.new(0, 0.3, 0), Material = Enum.Material.Slate, Color = Color3.fromRGB(150, 155, 165) }, parent)
	deco({ Size = Vector3.new(0.9, 10, 0.9), CFrame = at * CFrame.new(0, 5.3, 0), Material = Enum.Material.Wood, Color = WOOD, CastShadow = true }, parent)
	deco({ Size = Vector3.new(0.7, 0.7, 3.2), CFrame = at * CFrame.new(0, 9.8, -1.4), Material = Enum.Material.Wood, Color = WOOD }, parent)
	snowCap(at * CFrame.new(0, 10.25, -1.4), 0.9, 3.2, parent)
	deco({ Size = Vector3.new(0.12, 1, 0.12), CFrame = at * CFrame.new(0, 9, -2.6), Color = Color3.fromRGB(200, 170, 110) }, parent)
	deco({ Size = Vector3.new(1.3, 0.3, 1.3), CFrame = at * CFrame.new(0, 8.4, -2.6), Color = IRON }, parent)
	local glow = deco({ Size = Vector3.new(1, 1.4, 1), CFrame = at * CFrame.new(0, 7.5, -2.6), Material = Enum.Material.Neon, Color = WARM }, parent)
	deco({ Size = Vector3.new(1.1, 0.25, 1.1), CFrame = at * CFrame.new(0, 6.7, -2.6), Color = IRON }, parent)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 180, 90)
	light.Range = 16
	light.Brightness = 1.3
	light.Parent = glow
end

------------------------------------------------------------------ Сезонный декор (эпик E11)
-- Новогодняя ёлка: ярусы-шестигранники, снег на «юбках», шары-огоньки по кругу ярусов, звезда
function Props.newYearTree(base: CFrame, parent: Instance)
	local h = 26
	local green = Color3.fromRGB(40, 120, 70)
	deco({ Size = Vector3.new(2.4, 5, 2.4), CFrame = base * CFrame.new(0, 2.5, 0), Material = Enum.Material.Wood, Color = Color3.fromRGB(95, 65, 40) }, parent)
	local bulbs = { Color3.fromRGB(255, 70, 70), Color3.fromRGB(255, 210, 60), Color3.fromRGB(80, 200, 255), Color3.fromRGB(120, 240, 120), Color3.fromRGB(240, 120, 255) }
	for t = 0, 3 do
		local w = h * (0.62 - t * 0.13)
		local y = h * (0.28 + t * 0.18)
		for k = 0, 2 do
			deco({ Size = Vector3.new(w, h * 0.16, w * 0.58), CFrame = base * CFrame.new(0, y, 0) * CFrame.Angles(0, k * math.pi / 3, 0), Color = green, CastShadow = t == 0 }, parent)
		end
		snowCap(base * CFrame.new(0, y + h * 0.08, 0), w * 0.6, w * 0.5, parent)
		local n = 7 - t
		for k = 1, n do
			local a = 2 * math.pi * k / n + t
			deco({ Shape = Enum.PartType.Ball, Size = Vector3.one * 1.1, CFrame = base * CFrame.new(math.cos(a) * w * 0.45, y - h * 0.05, math.sin(a) * w * 0.45), Material = Enum.Material.Neon, Color = bulbs[(k + t) % #bulbs + 1] }, parent)
		end
	end
	local star = deco({ Size = Vector3.new(2.6, 2.6, 0.6), CFrame = base * CFrame.new(0, h * 0.98, 0) * CFrame.Angles(0, 0, math.rad(45)), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 215, 80) }, parent)
	deco({ Size = Vector3.new(2.6, 2.6, 0.6), CFrame = base * CFrame.new(0, h * 0.98, 0), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 215, 80) }, parent)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 220, 140)
	light.Range = 20
	light.Brightness = 1.5
	light.Parent = star
end

-- Коробка-подарок с лентой крест-накрест и бантом
function Props.giftBox(base: CFrame, size: number, color: Color3, parent: Instance)
	local ribbon = Color3.fromRGB(255, 230, 120)
	deco({ Size = Vector3.one * size, CFrame = base * CFrame.new(0, size / 2, 0), Color = color, CastShadow = true }, parent)
	deco({ Size = Vector3.new(size * 0.2, size + 0.05, size + 0.05), CFrame = base * CFrame.new(0, size / 2, 0), Color = ribbon }, parent)
	deco({ Size = Vector3.new(size + 0.05, size + 0.05, size * 0.2), CFrame = base * CFrame.new(0, size / 2, 0), Color = ribbon }, parent)
	for _, a in { -0.6, 0.6 } do
		deco({ Shape = Enum.PartType.Ball, Size = Vector3.new(size * 0.35, size * 0.25, size * 0.2), CFrame = base * CFrame.new(0, size + size * 0.1, 0) * CFrame.Angles(0, 0, a), Color = ribbon }, parent)
	end
end

return Props
