-- Оформление миров вдоль трассы: обочины по теме мира (dressSegment) и разметка/«вау» на самой
-- трассе (dressTrack: кромки, флажки-слалом, арка). Часть модуля shared/Track (см. Track/init).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Props = require(ReplicatedStorage.Shared.Props)
local Islands = require(ReplicatedStorage.Shared.Islands)
local Sections = require(script.Parent.Sections)

local deco = Props.deco
local Meshes = require(ReplicatedStorage.Shared.Meshes)
local W, SNOW_PROFILE, BANK_OUT, BANK_TOP = Sections.W, Sections.SNOW_PROFILE, Sections.BANK_OUT, Sections.BANK_TOP
local sidePoint = Sections.sidePoint

local Dress = {}
local dressLayers: (theme: number, cf: CFrame, len: number, prof: any, m: Instance) -> ()

------------------------------------------------------------------ оформление миров
local function dressSegment(theme: number, rng: Random, cf: CFrame, len: number, m: Instance, prof)
	local out, top = prof.out, prof.top
	local density = len / 110 -- короткие куски поворотов получают пропорционально меньше редких объектов
	-- Случайная позиция вдоль куска с отступом от краёв (безопасно и для коротких кусков)
	local function zr(margin: number): number
		if len > margin * 2 then
			return rng:NextNumber(margin, len - margin)
		end
		return len / 2
	end
	for _, side in { -1, 1 } do
		local at = function(offset: number, z: number): CFrame
			return sidePoint(cf, side * (out + offset), z, top)
		end

		if theme == 1 then
			-- Снежный лес: ёлки и «акации» со снегом, иногда хижина, валуны и указатель
			for z = 6, len, 13 do
				local p = at(rng:NextNumber(8, 50), z + rng:NextNumber(-4, 4))
				if rng:NextNumber() < 0.6 then
					Props.pine(rng, p, m)
				else
					Props.acacia(rng, p, m)
				end
			end
			if rng:NextNumber() < 0.25 * density then
				Props.cabin(rng, at(26, zr(15)), side, m)
			end
			if rng:NextNumber() < 0.5 * density then
				Props.boulder(rng, at(rng:NextNumber(5, 8), zr(0)), m, false, 1.3, false)
			end
			if rng:NextNumber() < 0.15 * density then
				Props.signpost(rng, at(4, zr(0)), m)
			end
		elseif theme == 2 then
			-- Город: припаркованные машины, ряд домов с маркизами, высотки сзади, фонари
			for z = 8, len, 16 do
				if rng:NextNumber() < 0.55 then
					local p = at(4, z) * CFrame.Angles(0, if rng:NextNumber() < 0.5 then 0 else math.pi, 0)
					if rng:NextNumber() < 0.25 then
						Props.van(rng, p, m, rng:NextNumber() < 0.4)
					else
						Props.car(rng, p, m)
					end
				end
			end
			local z = 0
			while z < len do
				local w = rng:NextNumber(16, 24)
				Props.house(rng, at(12, z + w / 2), side, w, m)
				z += w + rng:NextNumber(0.5, 3)
			end
			if rng:NextNumber() < 0.8 * len / 30 then
				Props.tower(rng, at(40 + rng:NextNumber(0, 15), zr(0)), side, m)
			end
			if rng:NextNumber() < len / 40 then
				Props.streetLamp(at(9, zr(0)), side, m)
			end
			if rng:NextNumber() < 0.4 * density then
				Props.hydrant(at(9.5, zr(0)), m)
			end
		elseif theme == 4 then
			-- Ледяные пещеры: ледяные скалы со сосульками, друзы светящихся кристаллов, сталагмиты
			if rng:NextNumber() < len / 26 then
				Props.iceCliff(rng, at(rng:NextNumber(14, 24), zr(0)), side, m)
			end
			if rng:NextNumber() < 0.9 * density then
				Props.crystalCluster(rng, at(rng:NextNumber(5, 14), zr(0)), m)
			end
			if rng:NextNumber() < 1.0 * density then
				Props.stalagmite(rng, at(rng:NextNumber(4, 12), zr(0)), m, false)
			end
			if rng:NextNumber() < 0.3 * density then
				Props.pine(rng, at(rng:NextNumber(26, 40), zr(0)), m)
			end
		elseif theme == 5 then
			-- Северное сияние: ночная тундра, иглу, фонари, редкие ёлки, ленты сияния в небе
			for z = 10, len, 24 do
				if rng:NextNumber() < 0.6 then
					Props.pine(rng, at(rng:NextNumber(12, 45), z + rng:NextNumber(-4, 4)), m)
				end
			end
			if rng:NextNumber() < 0.35 * density then
				Props.igloo(rng, at(rng:NextNumber(22, 32), zr(12)), m)
			end
			if rng:NextNumber() < len / 45 then
				Props.lantern(at(5, zr(0)), m)
			end
			if rng:NextNumber() < 0.5 * density then
				Props.boulder(rng, at(rng:NextNumber(6, 10), zr(0)), m, false, 1.2, false)
			end
			if rng:NextNumber() < 0.35 * density then
				Props.aurora(rng, at(rng:NextNumber(90, 160), zr(0)) * CFrame.new(0, rng:NextNumber(110, 150), 0), m)
			end
		elseif theme == 6 then
			-- Снежный вулкан: базальтовые столбы, лавовые озёра, обгоревшие деревья, вулкан вдали
			if rng:NextNumber() < 1.0 * density then
				Props.basalt(rng, at(rng:NextNumber(6, 14), zr(0)), m, false)
			end
			if rng:NextNumber() < 0.45 * density then
				Props.lavaPool(rng, at(rng:NextNumber(26, 40), zr(10)), m)
			end
			for z = 8, len, 18 do
				if rng:NextNumber() < 0.5 then
					Props.charredTree(rng, at(rng:NextNumber(10, 40), z), m)
				end
			end
			if rng:NextNumber() < 0.12 * density then
				Props.volcano(rng, at(rng:NextNumber(170, 230), zr(0)), m)
			end
		elseif theme == 7 then
			-- Конфетная гора: леденцовые трости, леденцы, пряничные домики, мармелад
			for z = 8, len, 14 do
				local p = at(rng:NextNumber(8, 40), z + rng:NextNumber(-3, 3))
				if rng:NextNumber() < 0.5 then
					Props.candyCane(rng, p, m)
				else
					Props.lollipop(rng, p, m)
				end
			end
			if rng:NextNumber() < 0.3 * density then
				Props.gingerHouse(rng, at(26, zr(15)), side, m)
			end
			if rng:NextNumber() < 0.6 * density then
				Props.gumdrop(rng, at(rng:NextNumber(5, 9), zr(0)), m)
			end
		else
			-- Каньон: слоистые скалы, акации, лагерь с костром, ветряк, водонапорная башня, кактусы
			if rng:NextNumber() < len / 28 then
				Props.mesa(rng, at(rng:NextNumber(30, 42), zr(0)), side, m)
			end
			if rng:NextNumber() < 0.7 * len / 22 then
				Props.acacia(rng, at(rng:NextNumber(8, 22), zr(0)), m)
			end
			if rng:NextNumber() < 1.2 * density then
				Props.cactus(rng, at(rng:NextNumber(4, 10), zr(0)), m)
			end
			local feature = rng:NextNumber() / math.max(density, 0.01)
			if feature < 0.3 then
				Props.camp(rng, at(16, zr(20)), m)
			elseif feature < 0.42 then
				Props.windmill(at(20, zr(20)), side, m)
			elseif feature < 0.52 then
				Props.waterTower(at(20, zr(20)), m)
			elseif feature < 0.65 then
				Props.signpost(rng, at(4, zr(0)), m)
			end
		end

		-- Воздушные шары в небе
		if (theme == 1 or theme == 3 or theme == 7) and rng:NextNumber() < 0.12 * density then
			Props.balloon(rng, at(rng:NextNumber(40, 110), zr(0)) * CFrame.new(0, rng:NextNumber(45, 85), 0), m)
		end
		-- Горы на горизонте
		if rng:NextNumber() < 0.6 * density then
			local tint = ({ [4] = Color3.fromRGB(150, 200, 235), [5] = Color3.fromRGB(70, 85, 120), [6] = Color3.fromRGB(60, 56, 62), [7] = Color3.fromRGB(235, 160, 210) })[theme]
			Props.mountain(rng, at(rng:NextNumber(140, 200), zr(0)), theme == 3, m, tint)
		end
	end
	dressLayers(theme, cf, len, prof, m)
end

------------------------------------------------------------------ слои кадра из мешей (#45)
-- Поверх обочин мира, только мешами (без шаблонов слоёв нет — вид и число инстансов как до #45):
--   ближний план — сугробы/дюны у внешнего края бортов (мягкий переход трасса → мир);
--   средний — скалы/утёсы в 55–95 studs; дальний — второй ряд гор в 240–320 studs;
--   «вау» — парящий островок с ёлкой (снежные миры, конфетная гора) или каменная арка (каньон,
--   вулкан) в поле зрения камеры. Свой Random от позиции куска — общий Random куска (препятствия,
--   монеты, бонусы) не сдвигается. Декор спокойнее препятствий: приглушённые цвета, без Neon.
local DRIFT = { -- мир → цвет, материал сугроба/дюны (город — без: там дома и машины)
	[1] = { Color3.fromRGB(245, 249, 255), Enum.Material.Snow },
	[3] = { Color3.fromRGB(222, 170, 120), Enum.Material.Sand },
	[4] = { Color3.fromRGB(225, 240, 252), Enum.Material.Snow },
	[5] = { Color3.fromRGB(215, 225, 245), Enum.Material.Snow },
	[6] = { Color3.fromRGB(200, 196, 200), Enum.Material.Snow },
	[7] = { Color3.fromRGB(255, 225, 240), Enum.Material.SmoothPlastic },
}
local CRAG = { -- мир → цвет, материал скал среднего плана
	[1] = { Color3.fromRGB(120, 130, 150), Enum.Material.Slate },
	[3] = { Color3.fromRGB(196, 120, 80), Enum.Material.Sandstone },
	[4] = { Color3.fromRGB(160, 210, 240), Enum.Material.Glacier },
	[5] = { Color3.fromRGB(80, 92, 125), Enum.Material.Slate },
	[6] = { Color3.fromRGB(58, 54, 60), Enum.Material.Basalt },
	[7] = { Color3.fromRGB(230, 170, 215), Enum.Material.SmoothPlastic },
}
local MTN_TINT = { [4] = Color3.fromRGB(150, 200, 235), [5] = Color3.fromRGB(70, 85, 120), [6] = Color3.fromRGB(60, 56, 62), [7] = Color3.fromRGB(235, 160, 210) }

function dressLayers(theme: number, cf: CFrame, len: number, prof, m: Instance)
	if theme == 2 or not Meshes.has("snowdrift") then
		return
	end
	local p0 = cf.Position
	local lr = Random.new((math.floor(p0.X * 7.13 + p0.Y * 3.71 + p0.Z * 11.37) % 2147483647) + theme)
	local density = len / 110
	local out, top = prof.out, prof.top
	for _, side in { -1, 1 } do
		local function at(offset: number, z: number): CFrame
			return sidePoint(cf, side * (out + offset), z, top)
		end
		local function zr(): number
			return lr:NextNumber(0, len)
		end
		-- ближний план: сугробы вдоль борта, длинной стороной вдоль трассы
		local drift = DRIFT[theme]
		for z = lr:NextNumber(4, 20), len, 36 do
			if lr:NextNumber() < Config.DECOR_DRIFT_CHANCE * 0.6 then
				local l = lr:NextNumber(9, 18)
				local c = at(lr:NextNumber(1, 6), z) * CFrame.Angles(0, math.pi / 2 + lr:NextNumber(-0.25, 0.25), 0)
				Meshes.place("snowdrift", c * CFrame.new(0, -0.6, 0), Vector3.new(l / 3.17, lr:NextNumber(3, 5.5) / 0.72, l * 0.32), { Material = drift[2], Color = Meshes.vary(drift[1], c.Position, 0.04) }, m)
			end
		end
		-- средний план: утёс + валун у подножия
		local crag = CRAG[theme]
		if crag and Meshes.has("crag", "rock_b") and lr:NextNumber() < Config.DECOR_MID_CHANCE * density then
			local c = at(lr:NextNumber(55, 95), zr()) * CFrame.Angles(0, lr:NextNumber(0, math.pi * 2), 0)
			local h = lr:NextNumber(24, 48)
			local col = Meshes.vary(crag[1], c.Position, 0.1)
			Meshes.place("crag", c * CFrame.new(0, -1.5, 0), Vector3.new(h * 0.32, h / 3.46, h * 0.3), { Material = crag[2], Color = col, CastShadow = true }, m)
			local r = lr:NextNumber(5, 9)
			Meshes.place("rock_b", c * CFrame.new(h * 0.35, -0.8, h * 0.1), Vector3.one * r, { Material = crag[2], Color = Meshes.vary(col, c.Position + Vector3.one, 0.1), CastShadow = true }, m)
		end
		-- средний план (#67, референсы): скалы и кристаллы мира — худу/«стол» в каньоне, глыбы с лавой
		-- в вулкане, светящиеся кристаллы в пещерах, валуны со снегом и ярусные/пушистые ёлки в снежных
		if lr:NextNumber() < Config.DECOR_ROCKS_CHANCE * density then
			local c = at(lr:NextNumber(14, 60), zr())
			local roll = lr:NextNumber()
			if theme == 3 then
				if roll < 0.35 then
					Props.tableRock(lr, c * CFrame.Angles(0, lr:NextNumber(0, math.pi), 0), m)
				else
					Props.hoodoo(lr, c, m)
				end
			elseif theme == 6 then
				Props.lavaSpire(lr, c, m)
			elseif theme == 4 then
				Props.crystalSpire(lr, c, m)
			elseif theme ~= 2 and theme ~= 7 then
				if roll < 0.4 then
					Props.snowBoulder(lr, c, m)
				elseif roll < 0.7 then
					Props.tierPine(lr, c, m)
				else
					Props.fluffyPine(lr, c, m)
				end
			end
		end
		-- дальний план: второй ряд гор
		if Meshes.has("mountain_rock", "mountain_snow") and lr:NextNumber() < Config.DECOR_FAR_CHANCE * density then
			Props.mountain(lr, at(lr:NextNumber(240, 320), zr()) * CFrame.new(0, -10, 0), theme == 3, m, MTN_TINT[theme])
		end
		-- «вау»: парящий островок с ёлкой или каменная арка
		if lr:NextNumber() < Config.DECOR_WOW_CHANCE * density then
			if (theme == 3 or theme == 6) and Meshes.has("arch") then
				local c = at(lr:NextNumber(60, 110), zr()) * CFrame.Angles(0, lr:NextNumber(-0.6, 0.6), 0)
				local s = lr:NextNumber(26, 40)
				Meshes.place("arch", c * CFrame.new(0, -2, 0), Vector3.new(s, s * 0.9, s * 0.45), { Material = crag[2], Color = Meshes.vary(crag[1], c.Position, 0.06), CastShadow = true }, m)
			elseif Meshes.has("isle_rock", "isle_cap") and theme ~= 3 and theme ~= 6 then
				local c = at(lr:NextNumber(70, 130), zr()) * CFrame.new(0, lr:NextNumber(40, 75), 0) * CFrame.Angles(0, lr:NextNumber(0, math.pi * 2), 0)
				local s = lr:NextNumber(12, 20)
				local sc = Vector3.new(s, s * 1.1, s)
				local capCol = if theme == 7 then Color3.fromRGB(255, 215, 235) else Color3.fromRGB(250, 252, 255)
				Meshes.place("isle_rock", c, sc, { Material = crag[2], Color = Meshes.vary(crag[1], c.Position, 0.08), CastShadow = true }, m)
				Meshes.place("isle_cap", c, sc, { Material = if theme == 7 then Enum.Material.SmoothPlastic else Enum.Material.Snow, Color = capCol }, m)
				if theme ~= 7 then
					Props.pine(lr, c * CFrame.new(-0.35 * s, 0.4 * s, 0.2 * s), m)
				end
			end
		end
	end
end

------------------------------------------------------------------ разметка и «вау» на трассе (#40, art)
-- Поверх обочин мира: цветные кромки дна (цвет мира) — трасса читается как дорожка и скорость
-- видна по бегущим полосам; флажки-слалом на сугробах по бокам (ритм, не на дне — препятствий
-- не закрывают); иногда большая арка над пологим куском. Свой Random — раскладка препятствий,
-- монет и бонусов куска не сдвигается.
local function dressTrack(theme: number, rng: Random, seg, m: Instance)
	local kind = seg.kind
	local straight = kind == "gentle" or kind == "steep" or kind == "start" or kind == "landing" or kind == "kicker" or kind == "isleIn" or kind == "climb" or kind == "stair" or kind == "stairLand"
	if not straight then
		return
	end
	local cf, len = seg.cf, seg.length
	local accent = Islands.accent(theme)
	if Config.EDGE_STRIPES then
		for _, side in { -1, 1 } do
			deco({ Size = Vector3.new(1.4, 0.06, len), CFrame = cf * CFrame.new(side * (W / 2 - 2.2), 0.03, -len / 2), Color = accent, Transparency = 0.1 }, m)
		end
	end
	if (kind == "gentle" or kind == "steep") and rng:NextNumber() < Config.SLALOM_CHANCE then
		-- на первом поясе чаши (Config.BOWL.BANK1_ANGLE), 6 studs за краем дна; цвета чередуются по сторонам
		local bankY = 6 * math.tan(math.rad(SNOW_PROFILE.banks[1].angle))
		local k = 0
		for z = 14, len - 8, 32 do
			k += 1
			for _, side in { -1, 1 } do
				local col = if (k + (if side > 0 then 1 else 0)) % 2 == 0 then accent else Color3.fromRGB(245, 245, 250)
				Islands.pennant(cf * CFrame.new(side * (W / 2 + 6), bankY, -z) * CFrame.Angles(0, if side > 0 then math.pi else 0, 0), col, 5, m)
			end
		end
	end
	if kind == "gentle" and seg.hStart > Config.SAFE_START and rng:NextNumber() < Config.ARCH_CHANCE and not seg.tunnel then -- в тоннеле арка ушла бы в свод
		-- большая арка: ледяной свод над всей шириной чаши (декор, сквозь неё едем), ноги на полке за
		-- поясами. Меш (#45) — 1 деталь вместо 13 блоков; без шаблона — блоки полукругом, как раньше.
		local r = BANK_OUT + 4
		local base = BANK_TOP - 4
		local z = len * rng:NextNumber(0.35, 0.65)
		local iceCol = if theme == 7 then Color3.fromRGB(255, 190, 225) elseif theme == 3 then Color3.fromRGB(230, 170, 120) else Color3.fromRGB(150, 205, 245)
		if Meshes.has("arch") then
			local span = r * 2 / 2.1 -- ноги арки в x ≈ ±1.05 кадра меша
			Meshes.place("arch", cf * CFrame.new(0, base, -z), Vector3.new(span, (r * 0.6 + 7) / 1.03, 7 / 1.27), { Material = Enum.Material.Ice, Color = Meshes.vary(iceCol, cf.Position, 0.05), Transparency = 0.05, CastShadow = true }, m)
			return
		end
		for j = 0, 12 do
			local a = math.pi * j / 12
			deco({
				Size = Vector3.new(7, 6, 5),
				CFrame = cf * CFrame.new(math.cos(a) * r, base + 2 + math.sin(a) * r * 0.6, -z) * CFrame.Angles(0, 0, a),
				Material = Enum.Material.Ice,
				Color = if j % 4 == 0 then accent else iceCol,
				Transparency = 0.05,
				CastShadow = true,
			}, m)
		end
	end
end

Dress.segment = dressSegment
Dress.track = dressTrack

return Dress
