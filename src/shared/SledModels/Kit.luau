-- Обвес по тирам «Саней» (1–10) и боковые ракеты по тиру «Ракеты».

local B = require(script.Parent.Builder)
type Look = B.Look
local STEEL, BLACK, WHITE = B.STEEL, B.BLACK, B.WHITE
local Rockets = require(script.Parent.Rockets)
local Mounts = require(script.Parent.Mounts)
local ROCKETS, buildRocket = Rockets.ROCKETS, Rockets.build
local MOUNTS, SPOILER, SHIELD, BUMPER = Mounts.MOUNTS, Mounts.SPOILER, Mounts.SHIELD, Mounts.BUMPER

local Kit = {}

-- Детали апгрейдов на санках: боковые ракеты по тиру «Ракеты» + обвес по тиру «Саней».
-- Возвращает { x, y, z } сопла правой ракеты (для огня в Effects).
function Kit.extras(parent: Instance, base: CFrame, id: string, sledTier: number, rocketTier: number, accent: Color3, weldTo: BasePart?): Vector3
	local b = B.new(parent, base, weldTo)
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
	-- Тиры 9–10 — за спиной персонажа (у спойлера): камера сзади-сверху, спереди их закрывал аватар
	if sledTier >= 9 then -- сияние: искры и тёплый свет
		local core = b:ball(0.2, CFrame.new(0, back[2] + 0.4, back[1]), WHITE, nil, nil)
		core.Transparency = 1
		local sp = Instance.new("Sparkles")
		sp.SparkleColor = Color3.fromRGB(255, 225, 120)
		sp.Parent = core
	end
	if sledTier >= 10 then -- корона чемпиона над крылом спойлера (крыло на back[2] + 0.42)
		local c = CFrame.new(0, back[2] + 1.05, back[1] + 0.2)
		local gold = Color3.fromRGB(255, 205, 60)
		b:cyl(0.9, 0.3, c.Position, Vector3.yAxis, gold, Enum.Material.SmoothPlastic).Reflectance = 0.3
		for k = 0, 4 do
			local a = k / 5 * math.pi * 2
			b:wedge(Vector3.new(0.12, 0.45, 0.3), c * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.35, -0.4), gold)
		end
		b:ball(0.25, c * CFrame.new(0, 0.3, 0.45), Color3.fromRGB(255, 60, 90), Enum.Material.Neon) -- камень к камере
	end
	return nozzle
end

return Kit
