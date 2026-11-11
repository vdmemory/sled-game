-- Тоннель над ледяным поворотом (#65): свод из колец вдоль каждого куска поворота + порталы на
-- входе и выходе. Вид по миру (снег, лёд, камень каньона, базальт с лавой, розовый лёд).
-- Только декор: без коллизий и лучей (Props.deco / Meshes.place) — физика саней, камера и
-- раскладка уровня не меняются. Какие повороты под сводом — решает Profile (seg.tunnel).
-- Часть модуля shared/Track (см. Track/init); референсы — docs/ART_REFERENCES.md.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Props = require(ReplicatedStorage.Shared.Props)
local Meshes = require(ReplicatedStorage.Shared.Meshes)

local Sections = require(script.Parent.Sections)

local deco = Props.deco

local Tunnel = {}

type Look = { mat: Enum.Material, col: Color3, light: Color3?, icicles: boolean, lava: boolean?, transp: number? }

-- Вид свода по миру (номер темы Config.THEMES)
local LOOKS: { [number]: Look } = {
	[1] = { mat = Enum.Material.Snow, col = Color3.fromRGB(236, 243, 252), light = Color3.fromRGB(170, 215, 255), icicles = true },
	[2] = { mat = Enum.Material.Ice, col = Color3.fromRGB(140, 198, 242), light = Color3.fromRGB(120, 210, 255), icicles = true, transp = 0.05 },
	[3] = { mat = Enum.Material.Sandstone, col = Color3.fromRGB(196, 128, 88), light = Color3.fromRGB(255, 190, 120), icicles = false },
	[4] = { mat = Enum.Material.Glacier, col = Color3.fromRGB(110, 185, 240), light = Color3.fromRGB(90, 220, 255), icicles = true, transp = 0.05 },
	[5] = { mat = Enum.Material.Ice, col = Color3.fromRGB(150, 205, 240), light = Color3.fromRGB(120, 255, 200), icicles = true, transp = 0.05 },
	[6] = { mat = Enum.Material.Basalt, col = Color3.fromRGB(62, 58, 66), light = Color3.fromRGB(255, 120, 40), icicles = false, lava = true },
	[7] = { mat = Enum.Material.Ice, col = Color3.fromRGB(255, 195, 228), light = Color3.fromRGB(255, 160, 220), icicles = true, transp = 0.05 },
}

-- Кольцо из блоков (фолбэк без меша): полуэллипс от ног (±r, 0) до верха (0, h) в кадре base
local function ringParts(base: CFrame, r: number, h: number, depth: number, look: Look, parent: Instance)
	local n = math.max(6, math.floor(Config.TUNNEL_RING_BLOCKS or 12))
	local thick = Config.TUNNEL_THICK
	local px, py = -r, 0
	for k = 1, n do
		local a = math.pi * k / n
		local x, y = -math.cos(a) * r, math.sin(a) * h
		local dx, dy = x - px, y - py
		deco({
			Size = Vector3.new(math.sqrt(dx * dx + dy * dy) + thick * 0.6, thick, depth),
			CFrame = base * CFrame.new((px + x) / 2, (py + y) / 2, 0) * CFrame.Angles(0, 0, math.atan2(dy, dx)),
			Material = look.mat,
			Color = look.col,
			Transparency = look.transp or 0,
		}, parent)
		px, py = x, y
	end
end

-- Сосульки фолбэка: тонкие ледяные «сталактиты» у верха свода
local function icicleParts(base: CFrame, r: number, h: number, depth: number, rng: Random, parent: Instance)
	for _ = 1, 3 do
		local a = math.pi * rng:NextNumber(0.25, 0.75)
		local len = rng:NextNumber(3, 7)
		local x, y = -math.cos(a) * r * 0.97, math.sin(a) * h * 0.97 - Config.TUNNEL_THICK / 2
		deco({
			Size = Vector3.new(1.1, len, 1.1),
			CFrame = base * CFrame.new(x, y - len / 2, rng:NextNumber(-depth / 3, depth / 3)),
			Material = Enum.Material.Ice,
			Color = Color3.fromRGB(205, 232, 252),
			Transparency = 0.1,
		}, parent)
	end
end

-- Свод над куском трассы. cf — начало куска (центр дна, −Z вниз по трассе), visLen — длина видимой
-- части, prof — сечение (out — край полки, top — высота кромки), index — номер куска (свет).
-- Верх свода на одной высоте над дном для любого сечения (жёлоб поворота и снежные прямые): ноги
-- стоят на кромке своего сечения, подъём = кромка жёлоба + TUNNEL_HEIGHT − своя кромка. Длинный кусок
-- (прямая 90–120 studs) делится на кольца не длиннее TUNNEL_RING_LEN — сосульки меша не растягиваются.
function Tunnel.build(theme: number, seg, cf: CFrame, visLen: number, prof, parent: Instance, index: number)
	local look = LOOKS[theme] or LOOKS[1]
	local r = prof.out + Config.TUNNEL_SIDE
	local h = math.max(12, Sections.CHUTE_PROFILE.top + Config.TUNNEL_HEIGHT - prof.top)
	local n = math.max(1, math.ceil(visLen / Config.TUNNEL_RING_LEN))
	local step = visLen / n
	-- соседний кусок может быть довёрнут (повороты — на CURVE_STEP): с внешней стороны у ног щель
	-- r·tg(шаг) — кольцо длиннее своего шага, внутренняя сторона просто перекрывается
	local depth = step + r * math.tan(math.rad(Config.CURVE_STEP)) + 2
	local rng = Random.new(math.floor(cf.Position.X * 7 + cf.Position.Z * 13) % 100000) -- свой: раскладка уровня не сдвигается
	for k = 1, n do
		local base = cf * CFrame.new(0, prof.top, -step * (k - 0.5))
		local ring: BasePart? = nil
		if Meshes.has("tunnel_vault") then
			ring = Meshes.place("tunnel_vault", base, Vector3.new(r, h, depth), {
				Material = look.mat,
				Color = Meshes.vary(look.col, base.Position, 0.05),
				Transparency = look.transp or 0,
			}, parent)
		end
		if not ring then
			ringParts(base, r, h, depth, look, parent)
			if look.icicles then
				icicleParts(base, r, h, depth, rng, parent)
			end
		end
		-- лавовые прожилки по своду (вулкан): тонкие Neon-полосы вдоль, видны снизу
		if look.lava then
			for _, a in { 0.32, 0.5, 0.68 } do
				local ang = math.pi * a
				local x, y = -math.cos(ang) * r * 0.93, math.sin(ang) * h * 0.93 - Config.TUNNEL_THICK / 2
				deco({
					Size = Vector3.new(0.5, 0.5, depth * 0.8),
					CFrame = base * CFrame.new(x, y, 0) * CFrame.Angles(0, 0, ang),
					Material = Enum.Material.Neon,
					Color = Color3.fromRGB(255, 110, 30),
				}, parent)
			end
		end
	end
	-- свет внутри: один источник на TUNNEL_LIGHT_EVERY кусков (бюджет телефона)
	local every = math.max(1, math.floor(Config.TUNNEL_LIGHT_EVERY))
	if look.light and index % every == 0 then
		local holder = deco({ Size = Vector3.new(1, 1, 1), CFrame = cf * CFrame.new(0, prof.top + h * 0.55, -visLen / 2), Transparency = 1 }, parent)
		local light = Instance.new("PointLight")
		light.Color = look.light
		light.Range = Config.TUNNEL_LIGHT_RANGE
		light.Brightness = Config.TUNNEL_LIGHT_BRIGHT
		light.Shadows = false
		light.Parent = holder
	end
	-- порталы: толстая арка на входе и выходе (видно издалека, что впереди тоннель)
	if seg.tunnel == "in" or seg.tunnel == "out" then
		local z = if seg.tunnel == "in" then 0 else -visLen
		local pr, ph = r + 3, h + 5
		local at = cf * CFrame.new(0, prof.top - 2, z)
		local placed = Meshes.has("arch")
			and Meshes.place("arch", at, Vector3.new(pr / 1.05, ph / 1.03, 9 / 1.27), {
				Material = look.mat,
				Color = Meshes.vary(look.col, at.Position, 0.08),
				Transparency = look.transp or 0,
				CastShadow = true,
			}, parent)
		if not placed then
			ringParts(at, pr, ph, 6, look, parent)
		end
	end
end

return Tunnel
