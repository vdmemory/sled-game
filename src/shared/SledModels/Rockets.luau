-- Ракеты (апгрейд «Ракета», тиры 0–6): ROCKETS — вид по тиру, build — одна ракета, возвращает сопло.

local B = require(script.Parent.Builder)
type Look = B.Look
local STEEL, BLACK, WHITE = B.STEEL, B.BLACK, B.WHITE

local Rockets = {}

-- Боковые ракеты как в оригинале: корпус, обтекатель-нос, пояски, стабилизаторы, сопло.
-- Каждый тир — свой дизайн: петарда → ракета → турбо → мега → бласт → гиперджет.
local ROCKETS = {
	[0] = { name = "Петарда", body = Color3.fromRGB(215, 55, 45), nose = Color3.fromRGB(245, 235, 210), fin = Color3.fromRGB(245, 235, 210), band = Color3.fromRGB(245, 235, 210), nozzle = Color3.fromRGB(90, 70, 55), d = 0.75, len = 2.3, fins = 2, wick = true },
	[1] = { name = "Ракета", body = Color3.fromRGB(225, 45, 45), nose = WHITE, fin = Color3.fromRGB(55, 110, 225), band = WHITE, nozzle = Color3.fromRGB(55, 110, 225), d = 0.95, len = 2.9, fins = 3 },
	[2] = { name = "Турбо-ракета", body = Color3.fromRGB(205, 210, 220), bodyMat = Enum.Material.Metal, nose = Color3.fromRGB(225, 45, 45), fin = Color3.fromRGB(225, 45, 45), band = Color3.fromRGB(225, 45, 45), nozzle = STEEL, d = 1.05, len = 3.2, fins = 4, intake = true },
	[3] = { name = "Мега-двигатель", body = Color3.fromRGB(45, 95, 215), nose = WHITE, fin = Color3.fromRGB(255, 200, 40), band = WHITE, nozzle = STEEL, d = 1.15, len = 3.5, fins = 4, intake = true, glow = Color3.fromRGB(90, 220, 255), canards = true },
	[4] = { name = "Бласт-двигатель", body = Color3.fromRGB(240, 190, 55), bodyMat = Enum.Material.SmoothPlastic, shine = 0.25, nose = BLACK, fin = BLACK, band = BLACK, nozzle = Color3.fromRGB(60, 60, 70), d = 1.2, len = 3.7, fins = 4, intake = true, glow = Color3.fromRGB(255, 150, 40), canards = true },
	[6] = { name = "Плазменный двигатель", body = WHITE, nose = Color3.fromRGB(120, 230, 255), fin = Color3.fromRGB(90, 230, 255), finMat = Enum.Material.Neon, band = Color3.fromRGB(90, 230, 255), bandMat = Enum.Material.Neon, nozzle = STEEL, d = 1.3, len = 4.2, fins = 3, intake = true, glow = Color3.fromRGB(120, 240, 255), canards = true },
	[5] = { name = "Гиперджет", body = Color3.fromRGB(40, 32, 70), nose = Color3.fromRGB(170, 90, 255), fin = Color3.fromRGB(90, 230, 255), finMat = Enum.Material.Neon, band = Color3.fromRGB(90, 230, 255), bandMat = Enum.Material.Neon, nozzle = BLACK, d = 1.25, len = 3.9, fins = 4, intake = true, glow = Color3.fromRGB(190, 110, 255), canards = true },
}
Rockets.ROCKETS = ROCKETS

-- Одна ракета: центр at, нос смотрит по −Z. Возвращает позицию среза сопла (для огня).
local function buildParts(b, at: Vector3, tier: number): Vector3
	local r = ROCKETS[math.clamp(tier, 0, 6)]
	local d, len = r.d, r.len
	local front, back = at.Z - len / 2, at.Z + len / 2
	local metal = Enum.Material.Metal
	local function rz(z: number): Vector3
		return Vector3.new(at.X, at.Y, z)
	end
	-- заклёпки по кругу (ряд маленьких шариков вокруг корпуса)
	local function rivets(z: number, n: number)
		for i = 0, n - 1 do
			local a = i / n * math.pi * 2
			b:ball(0.09, CFrame.new(at.X + math.cos(a) * d * 0.52, at.Y + math.sin(a) * d * 0.52, z), STEEL, metal)
		end
	end
	-- корпус: основная труба + чуть уже «шея» под носом (ступенька как у настоящей ракеты)
	local body = b:cyl(d, len * 0.82, rz(at.Z + len * 0.09), Vector3.zAxis, r.body, r.bodyMat)
	body.Reflectance = r.shine or 0
	local neck = b:cyl(d * 0.9, len * 0.2, rz(front + len * 0.1), Vector3.zAxis, r.body, r.bodyMat)
	neck.Reflectance = r.shine or 0
	-- нос: обтекатель + кольцо-стык + наконечник
	b:ellipsoid(Vector3.new(d * 0.9, d * 0.9, d * 1.8), CFrame.new(at.X, at.Y, front), r.nose, if r.nose == BLACK then metal else nil)
	b:cyl(d * 0.95, 0.12, rz(front + 0.02), Vector3.zAxis, r.band, r.bandMat)
	b:ball(d * 0.2, CFrame.new(at.X, at.Y, front - d * 0.86), r.band, r.bandMat)
	-- пояски-хомуты с заклёпками
	for _, k in { -0.18, 0.2 } do
		local z = at.Z + len * k
		b:cyl(d * 1.06, 0.2, rz(z), Vector3.zAxis, r.band, r.bandMat)
		rivets(z, 8)
	end
	-- гоночная полоса сверху (тир 2+), иллюминатор сбоку (тир 1+)
	if tier >= 2 then
		b:block(Vector3.new(d * 0.22, 0.04, len * 0.7), CFrame.new(at.X, at.Y + d / 2 + 0.01, at.Z + len * 0.05), r.band, r.bandMat)
	end
	if tier >= 1 then
		for _, sx in { -1, 1 } do
			local ox = sx * (d / 2 + 0.01)
			b:part(Enum.PartType.Cylinder, Vector3.new(0.05, d * 0.32, d * 0.32), CFrame.new(at.X + ox, at.Y, at.Z - len * 0.02), STEEL, metal)
			b:part(Enum.PartType.Cylinder, Vector3.new(0.06, d * 0.22, d * 0.22), CFrame.new(at.X + ox, at.Y, at.Z - len * 0.02), Color3.fromRGB(150, 210, 255), Enum.Material.Glass)
		end
	end
	if r.wick then -- фитиль у петарды
		b:rod({ rz(at.Z + len * 0.3) + Vector3.new(0, d * 0.4, 0), rz(at.Z + len * 0.38) + Vector3.new(0, d * 0.75, 0), rz(at.Z + len * 0.5) + Vector3.new(0, d * 0.85, 0) }, 0.08, Color3.fromRGB(60, 50, 40), Enum.Material.Fabric)
		b:ball(0.16, CFrame.new(at.X, at.Y + d * 0.88, at.Z + len * 0.52), Color3.fromRGB(255, 170, 60), Enum.Material.Neon)
	end
	if r.intake then -- воздухозаборники по бокам сверху
		for _, sx in { -1, 1 } do
			local c = CFrame.new(at.X + sx * d * 0.32, at.Y + d * 0.4, at.Z - len * 0.02) * CFrame.Angles(0, 0, sx * math.rad(-40))
			b:block(Vector3.new(d * 0.28, d * 0.2, len * 0.32), c, r.band, r.bandMat)
			b:block(Vector3.new(d * 0.18, d * 0.12, 0.05), c * CFrame.new(0, 0, -len * 0.16), BLACK)
		end
	end
	-- сопло-колокол: раструб расширяется ступеньками, внутри тёмный конус и огонёк
	b:cyl(d * 0.9, 0.22, rz(back + 0.06), Vector3.zAxis, STEEL, metal)
	local bell = { { 0.72, 0.22, 0.24 }, { 0.82, 0.18, 0.42 }, { 0.93, 0.16, 0.58 }, { 1.04, 0.1, 0.71 } }
	for _, s in bell do
		b:cyl(d * s[1], s[2], rz(back + s[3]), Vector3.zAxis, r.nozzle, metal)
	end
	b:cyl(d * 0.86, 0.04, rz(back + 0.77), Vector3.zAxis, BLACK)
	b:cyl(d * 0.5, 0.05, rz(back + 0.76), Vector3.zAxis, r.glow or Color3.fromRGB(255, 140, 50), Enum.Material.Neon)
	-- стабилизаторы: крупные стреловидные крылья с окантовкой
	local h = d * 0.95
	local start = if r.fins == 3 then 0 elseif r.fins == 2 then 90 else 45
	for i = 0, r.fins - 1 do
		local a = math.rad(start + i * 360 / r.fins)
		local base = CFrame.new(at.X, at.Y, back - 0.65) * CFrame.Angles(0, 0, a)
		b:wedge(Vector3.new(0.12, h, 1.4), base * CFrame.new(0, d / 2 + h / 2 - 0.05, 0), r.fin, r.finMat)
		-- законцовка
		b:block(Vector3.new(0.16, 0.14, 0.5), base * CFrame.new(0, d / 2 + h - 0.08, 0.45), r.band, r.bandMat)
	end
	if r.canards then -- передние крылышки
		for _, sx in { -1, 1 } do
			b:wedge(Vector3.new(0.1, d * 0.4, 0.7), CFrame.new(at.X, at.Y, front + len * 0.25) * CFrame.Angles(0, 0, sx * math.rad(90)) * CFrame.new(0, d / 2 + d * 0.18, 0), r.fin, r.finMat)
		end
	end
	return Vector3.new(at.X, at.Y, back + 0.78)
end

-- Меши ракеты (scripts/gen_kit_meshes.py → rocket_*): единицы d = 1, корпус L = 3.1 d
Rockets.MESHES = { "rocket_body", "rocket_nose", "rocket_bell", "rocket_fins2", "rocket_fins3", "rocket_fins4", "rocket_canards", "rocket_band" }
local MESH_LEN = 3.1

-- Та же ракета из мешей: корпус с шеей, оживальный нос, хомуты с заклёпками, сопло-колокол с
-- полостью, стреловидные стабилизаторы; мелкие детали (иллюминаторы, заборники, фитиль, огонёк) — Part.
-- ~12–18 деталей вместо ~50 из Part. Срез сопла — там же (back + 0.78), пламя Effects не сдвигается.
local function buildMesh(b, at: Vector3, tier: number): Vector3
	local r = ROCKETS[math.clamp(tier, 0, 6)]
	local d, len = r.d, r.len
	local front, back = at.Z - len / 2, at.Z + len / 2
	local metal = Enum.Material.Metal
	local sd = Vector3.new(d, d, 1)
	local body = b:mesh("rocket_body", r.body, r.bodyMat, CFrame.new(at), Vector3.new(d, d, len / MESH_LEN))
	if body then
		body.Reflectance = r.shine or 0
	end
	b:mesh("rocket_nose", r.nose, if r.nose == BLACK then metal else nil, CFrame.new(at.X, at.Y, front), Vector3.new(d, d, d))
	b:ball(d * 0.13, CFrame.new(at.X, at.Y, front - d * 0.96), r.band, r.bandMat)
	b:cyl(d * 0.95, 0.12, Vector3.new(at.X, at.Y, front + 0.02), Vector3.zAxis, r.band, r.bandMat)
	for _, k in { -0.18, 0.2 } do
		b:mesh("rocket_band", r.band, r.bandMat, CFrame.new(at.X, at.Y, at.Z + len * k), sd)
	end
	if tier >= 2 then
		b:block(Vector3.new(d * 0.22, 0.04, len * 0.7), CFrame.new(at.X, at.Y + d / 2 + 0.01, at.Z + len * 0.05), r.band, r.bandMat)
	end
	if tier >= 1 then
		for _, sx in { -1, 1 } do
			local ox = sx * (d / 2 + 0.01)
			b:part(Enum.PartType.Cylinder, Vector3.new(0.05, d * 0.32, d * 0.32), CFrame.new(at.X + ox, at.Y, at.Z - len * 0.02), STEEL, metal)
			b:part(Enum.PartType.Cylinder, Vector3.new(0.06, d * 0.22, d * 0.22), CFrame.new(at.X + ox, at.Y, at.Z - len * 0.02), Color3.fromRGB(150, 210, 255), Enum.Material.Glass)
		end
	end
	if r.wick then -- фитиль у петарды
		b:rod({ Vector3.new(at.X, at.Y + d * 0.4, at.Z + len * 0.3), Vector3.new(at.X, at.Y + d * 0.75, at.Z + len * 0.38), Vector3.new(at.X, at.Y + d * 0.85, at.Z + len * 0.5) }, 0.08, Color3.fromRGB(60, 50, 40), Enum.Material.Fabric)
		b:ball(0.16, CFrame.new(at.X, at.Y + d * 0.88, at.Z + len * 0.52), Color3.fromRGB(255, 170, 60), Enum.Material.Neon)
	end
	if r.intake then -- воздухозаборники по бокам сверху
		for _, sx in { -1, 1 } do
			local c = CFrame.new(at.X + sx * d * 0.32, at.Y + d * 0.4, at.Z - len * 0.02) * CFrame.Angles(0, 0, sx * math.rad(-40))
			b:block(Vector3.new(d * 0.28, d * 0.2, len * 0.32), c, r.band, r.bandMat)
			b:block(Vector3.new(d * 0.18, d * 0.12, 0.05), c * CFrame.new(0, 0, -len * 0.16), BLACK)
		end
	end
	b:mesh("rocket_bell", r.nozzle, metal, CFrame.new(at.X, at.Y, back), sd)
	b:cyl(d * 0.5, 0.05, Vector3.new(at.X, at.Y, back + 0.36), Vector3.zAxis, r.glow or Color3.fromRGB(255, 140, 50), Enum.Material.Neon)
	b:mesh("rocket_fins" .. math.clamp(r.fins, 2, 4), r.fin, r.finMat, CFrame.new(at.X, at.Y, back), sd)
	if r.canards then
		b:mesh("rocket_canards", r.fin, r.finMat, CFrame.new(at.X, at.Y, front + len * 0.25), sd)
	end
	return Vector3.new(at.X, at.Y, back + 0.78)
end

-- Одна ракета: центр at, нос смотрит по −Z. Возвращает позицию среза сопла (для огня).
function Rockets.build(b, at: Vector3, tier: number): Vector3
	if B.meshesReady(Rockets.MESHES) then
		return buildMesh(b, at, tier)
	end
	return buildParts(b, at, tier)
end

return Rockets
