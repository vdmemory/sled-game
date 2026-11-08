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


return Props
