-- Обвес по тирам «Саней» (1–10) и боковые ракеты по тиру «Ракеты».
-- Детали — меши (scripts/gen_kit_meshes.py: kit_*, trim_<модель>), пока их нет — Part (как до мешей).
--
-- Что видно с камеры заезда (сзади-сверху; аватар закрывает центр и нос саней) — #33:
--   1 фары     — пятно света на снегу впереди (SpotLight) и луч вперёд (Beam) + красные габариты сзади
--   2 спойлер  — крыло с торцевыми пластинами за спиной
--   3 обтекатель — стекло по бокам от персонажа (у моделей без своего стекла)
--   4 золото   — блестящая кромка по контуру корпуса (trim_<модель>) и золотые кронштейны ракет
--   5 неон     — светящиеся полосы по бортам и подсветка снега
--   6 флажок   — шест с полотнищем слева сзади
--   7 крылья   — плавники по бортам у ракет
--   8 выхлопы  — хромированные трубы за спиной
--   9 сияние   — искры и тёплый свет у спойлера
--  10 корона   — над крылом спойлера, камень смотрит в камеру

local B = require(script.Parent.Builder)
local Config = require(script.Parent.Parent.Config)
local STEEL, BLACK, WHITE = B.STEEL, B.BLACK, B.WHITE
local Rockets = require(script.Parent.Rockets)
local Mounts = require(script.Parent.Mounts)
local ROCKETS, buildRocket = Rockets.ROCKETS, Rockets.build
local MOUNTS, SPOILER, SHIELD, BUMPER = Mounts.MOUNTS, Mounts.SPOILER, Mounts.SHIELD, Mounts.BUMPER

local Kit = {}

local GOLD = Color3.fromRGB(240, 195, 60)
local LAMP = Color3.fromRGB(255, 245, 200)
local CHROME = Color3.fromRGB(215, 220, 230)

Kit.MESHES = { "kit_headlamp", "kit_spoiler", "kit_spoiler_mount", "kit_shield", "kit_shield_frame", "kit_bumper", "kit_flag", "kit_wing", "kit_exhaust", "kit_crown" }

local function meshNames(id: string): { string }
	local out = table.clone(Kit.MESHES)
	table.insert(out, "trim_" .. id)
	return out
end

-- Свет фар: SpotLight из правой линзы + луч (Beam) от середины между фарами вперёд-вниз
local function headlightBeam(lens: BasePart, base: CFrame, lights: Vector3)
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Right -- ось линзы (локальная +X) смотрит вперёд-вниз
	spot.Angle = Config.HEADLIGHT_ANGLE
	spot.Range = Config.HEADLIGHT_RANGE
	spot.Brightness = Config.HEADLIGHT_BRIGHTNESS
	spot.Color = LAMP
	spot.Shadows = false
	spot.Parent = lens
	local mid = base * Vector3.new(0, lights.Y, lights.Z - 0.3)
	local far = base * Vector3.new(0, lights.Y - 1.6, lights.Z - 13)
	local a0 = Instance.new("Attachment")
	a0.Name = "BeamStart"
	a0.Position = lens.CFrame:PointToObjectSpace(mid)
	a0.Parent = lens
	local a1 = Instance.new("Attachment")
	a1.Name = "BeamEnd"
	a1.Position = lens.CFrame:PointToObjectSpace(far)
	a1.Parent = lens
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Width0 = math.abs(lights.X) * 2 + 0.5
	beam.Width1 = 7
	beam.FaceCamera = true
	beam.Color = ColorSequence.new(LAMP)
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Segments = 1
	beam.Parent = lens
end

-- Детали апгрейдов на санках: боковые ракеты по тиру «Ракеты» + обвес по тиру «Саней».
-- Возвращает { x, y, z } сопла правой ракеты (для огня в Effects).
function Kit.extras(parent: Instance, base: CFrame, id: string, sledTier: number, rocketTier: number, accent: Color3, weldTo: BasePart?): Vector3
	local b = B.new(parent, base, weldTo)
	local m = MOUNTS[id] or MOUNTS.tube
	local r = ROCKETS[math.clamp(rocketTier, 0, 6)]
	local mesh = B.meshesReady(meshNames(id))
	local x = if m.onWing then m.x else m.x + r.d / 2 + 0.12
	local y = if m.onWing then m.y + r.d / 2 else m.y
	local nozzle = Vector3.zero
	for _, sx in { -1, 1 } do
		nozzle = buildRocket(b, Vector3.new(sx * x, y, m.z), rocketTier)
		-- кронштейн к корпусу (тир 4+ — золотой: виден сзади, #33)
		if not m.onWing then
			if sledTier >= 4 then
				b:block(Vector3.new(0.5, 0.28, 0.9), CFrame.new(sx * (x - r.d / 2 - 0.1), y, m.z), GOLD, Enum.Material.Foil)
			else
				b:block(Vector3.new(0.5, 0.28, 0.9), CFrame.new(sx * (x - r.d / 2 - 0.1), y, m.z), STEEL, Enum.Material.Metal)
			end
		end
	end
	-- 1 фары: корпус с ободом + линза, свет на снег и луч; красные габариты у спойлера
	if sledTier >= 1 then
		local lens: BasePart? = nil
		for _, sx in { -1, 1 } do
			local p = m.lights * Vector3.new(sx, 1, 1)
			local shell = if sledTier >= 4 then GOLD else STEEL
			if mesh then
				b:mesh("kit_headlamp", shell, if sledTier >= 4 then Enum.Material.Foil else Enum.Material.Metal, CFrame.new(p))
				local l = b:part(Enum.PartType.Cylinder, Vector3.new(0.08, 0.5, 0.5), CFrame.new(p + Vector3.new(0, 0, -0.17)) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, 0, math.rad(-8)), LAMP, Enum.Material.Neon)
				lens = if sx > 0 then l else lens
			else
				b:ball(0.62, CFrame.new(p), shell, Enum.Material.Metal)
				local l = b:ball(0.46, CFrame.new(p + Vector3.new(0, 0, -0.12)) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, 0, math.rad(-8)), LAMP, Enum.Material.Neon)
				lens = if sx > 0 then l else lens
			end
		end
		if lens then
			headlightBeam(lens, base, m.lights)
		end
		for _, sx in { -1, 1 } do
			local t = m.tail * Vector3.new(sx, 1, 1)
			b:block(Vector3.new(0.4, 0.26, 0.1), CFrame.new(t + Vector3.new(0, 0, -0.04)), BLACK)
			b:block(Vector3.new(0.32, 0.2, 0.08), CFrame.new(t + Vector3.new(0, 0, 0.02)), Color3.fromRGB(255, 40, 40), Enum.Material.Neon)
		end
	end
	-- 2 спойлер
	if sledTier >= 2 and SPOILER[id] then
		local z, yy = SPOILER[id][1], SPOILER[id][2]
		if mesh then
			b:mesh("kit_spoiler", accent, Enum.Material.SmoothPlastic, CFrame.new(0, yy, z))
			b:mesh("kit_spoiler_mount", BLACK, Enum.Material.SmoothPlastic, CFrame.new(0, yy, z))
		else
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
	end
	-- 3 обтекатель
	if sledTier >= 3 and SHIELD[id] then
		local z, yy = SHIELD[id][1], SHIELD[id][2]
		if mesh then
			b:mesh("kit_shield", Color3.fromRGB(170, 220, 255), Enum.Material.Glass, CFrame.new(0, yy, z), nil, { Transparency = 0.35 })
			b:mesh("kit_shield_frame", BLACK, Enum.Material.SmoothPlastic, CFrame.new(0, yy, z))
		else
			local glass = b:block(Vector3.new(3.6, 1.4, 0.18), CFrame.new(0, yy, z) * CFrame.Angles(math.rad(-25), 0, 0), Color3.fromRGB(170, 220, 255), Enum.Material.Glass)
			glass.Transparency = 0.35
			b:block(Vector3.new(3.7, 0.16, 0.24), CFrame.new(0, yy + 0.66, z + 0.3) * CFrame.Angles(math.rad(-25), 0, 0), BLACK)
		end
	end
	-- 4 золото: кромка по контуру (видна сверху) + бампер спереди
	if sledTier >= 4 then
		if mesh then
			b:mesh("trim_" .. id, GOLD, Enum.Material.Foil, nil, nil, { Reflectance = 0.2 })
			if id ~= "tube" and id ~= "plane" then
				local bp = BUMPER[id] or { -2.9, 0.0 }
				b:mesh("kit_bumper", GOLD, Enum.Material.Foil, CFrame.new(0, bp[2], bp[1]), nil, { Reflectance = 0.2 })
			end
		elseif id == "tube" then
			b:torus(Vector3.new(0, 0.05, 0), 3.95, 0.22, 26, GOLD, Enum.Material.SmoothPlastic)
		else
			local bp = BUMPER[id] or { -2.9, 0.0 }
			local z, yy = bp[1], bp[2]
			b:rod({ Vector3.new(-1.6, yy, z + 0.4), Vector3.new(-0.8, yy, z), Vector3.new(0.8, yy, z), Vector3.new(1.6, yy, z + 0.4) }, 0.22, GOLD, Enum.Material.SmoothPlastic)
		end
	end
	-- 5 неоновая подсветка по бортам снизу
	if sledTier >= 5 then
		for _, sx in { -1, 1 } do
			b:block(Vector3.new(0.12, 0.12, 4.5), CFrame.new(sx * (m.neon or 1.6), -0.55, 0.2), accent, Enum.Material.Neon)
		end
	end
	local back = (SPOILER[id] or { 3.0, 0.3 })
	local side = x - r.d / 2 - 0.1 -- борт (там, где кронштейн ракеты)
	-- 6 флажок на шесте сзади слева
	if sledTier >= 6 then
		local px, pz = -math.min(side, 1.4), back[1] - 0.4
		b:rod({ Vector3.new(px, back[2] - 0.2, pz), Vector3.new(px, back[2] + 3.2, pz) }, 0.12, STEEL, Enum.Material.Metal)
		if mesh then
			b:mesh("kit_flag", accent, Enum.Material.Fabric, CFrame.new(px, back[2] + 3.1, pz + 0.05))
		else
			b:wedge(Vector3.new(0.06, 0.9, 1.3), CFrame.new(px, back[2] + 2.7, pz + 0.65) * CFrame.Angles(0, 0, 0), accent)
		end
		b:ball(0.25, CFrame.new(px, back[2] + 3.3, pz), Color3.fromRGB(255, 215, 70), Enum.Material.Neon)
	end
	-- 7 боковые крылья-плавники
	if sledTier >= 7 then
		for _, sx in { -1, 1 } do
			if mesh then
				b:mesh("kit_wing", accent, Enum.Material.SmoothPlastic, CFrame.new(sx * (side + 0.05), y + 0.1, m.z + 0.9) * CFrame.Angles(0, 0, sx * math.rad(-35)))
			else
				b:wedge(Vector3.new(0.12, 0.9, 1.8), CFrame.new(sx * (side + 0.05), y + 0.55, m.z + 0.9) * CFrame.Angles(0, 0, sx * math.rad(-35)), accent)
			end
		end
	end
	-- 8 хромированные выхлопные трубы сзади
	if sledTier >= 8 then
		for _, sx in { -1, 1 } do
			local p0 = Vector3.new(sx * 0.6, back[2] - 0.3, back[1] - 0.6)
			if mesh then
				b:mesh("kit_exhaust", CHROME, Enum.Material.Metal, CFrame.new(p0), nil, { Reflectance = 0.4 })
				b:cyl(0.26, 0.06, p0 + Vector3.new(0, 0.66, 1.36), Vector3.new(0, 0.5, 0.9), BLACK)
			else
				local pipe = b:cyl(0.32, 1.4, p0 + Vector3.new(0, 0.35, 0.55), Vector3.new(0, 0.5, 1), CHROME, Enum.Material.Metal)
				pipe.Reflectance = 0.4
				b:cyl(0.24, 0.06, p0 + Vector3.new(0, 0.7, 1.25), Vector3.new(0, 0.5, 1), BLACK)
			end
		end
	end
	-- Тиры 9–10 — за спиной персонажа (у спойлера): камера сзади-сверху, спереди их закрывал аватар
	if sledTier >= 9 then -- сияние: искры и тёплый свет
		local core = b:ball(0.2, CFrame.new(0, back[2] + 0.4, back[1]), WHITE, nil)
		core.Transparency = 1
		local sp = Instance.new("Sparkles")
		sp.SparkleColor = Color3.fromRGB(255, 225, 120)
		sp.Parent = core
	end
	if sledTier >= 10 then -- корона чемпиона над крылом спойлера (крыло на back[2] + 0.42)
		local c = CFrame.new(0, back[2] + 1.05, back[1] + 0.2)
		local gold = Color3.fromRGB(255, 205, 60)
		if mesh then
			b:mesh("kit_crown", gold, Enum.Material.Foil, c * CFrame.new(0, -0.15, 0), nil, { Reflectance = 0.25 })
		else
			b:cyl(0.9, 0.3, c.Position, Vector3.yAxis, gold, Enum.Material.SmoothPlastic).Reflectance = 0.3
			for k = 0, 4 do
				local a = k / 5 * math.pi * 2
				b:wedge(Vector3.new(0.12, 0.45, 0.3), c * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.35, -0.4), gold)
			end
		end
		b:ball(0.25, c * CFrame.new(0, 0.3, 0.45), Color3.fromRGB(255, 60, 90), Enum.Material.Neon) -- камень к камере
	end
	return nozzle
end

return Kit
