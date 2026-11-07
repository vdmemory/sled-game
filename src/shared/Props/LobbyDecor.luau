-- «Живые» детали лобби: костёр, флагшток (качается на ветру), гирлянда флажков.
-- Часть shared/Props (см. Props/init).

local Base = require(script.Parent.Base)

local Props = Base.Props
local deco = Base.deco

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


return Props
