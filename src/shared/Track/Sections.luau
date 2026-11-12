-- Поперечные сечения трассы: профили (снежная чаша #74, ледяной жёлоб, дорога, озеро), цвета снега,
-- точка на «полке» за краем трассы и само сечение куска (дно, пояса склона, кромка, земля, барьер).
-- Часть модуля shared/Track (см. Track/init).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Props = require(ReplicatedStorage.Shared.Props)

local Profile = require(script.Parent.Profile)

local part, deco = Props.part, Props.deco

type Segment = Profile.Segment

local Sections = {}

------------------------------------------------------------------ поперечные профили
-- Снежный склон-чаша (#74, Config.BOWL): дно шириной W и два ездовых пояса того же снега — пологий
-- (BANK1) и крутой (BANK2); за ними ровная полка (декор) и невидимый барьер. Видимых стенок нет,
-- к центру сани возвращает сам склон (WALL_PULL в SledController).
-- Ледяной жёлоб (повороты, вираж, ледяной тоннель): тот же первый пояс (изо льда — на стыке
-- чаша↔жёлоб поверхность одна и та же), дальше высокие изогнутые ледяные стенки — как горка в
-- аквапарке.
local W = Config.TRACK_WIDTH
local BOWL = Config.BOWL
local function profile(banks: { { width: number, angle: number } })
	local out, top = W / 2, 0
	for _, b in banks do
		out += b.width * math.cos(math.rad(b.angle))
		top += b.width * math.sin(math.rad(b.angle))
	end
	return { banks = banks, out = out, top = top }
end
local BANK1 = { width = BOWL.BANK1_W, angle = BOWL.BANK1_ANGLE }
local SNOW_PROFILE = profile({ BANK1, { width = BOWL.BANK2_W, angle = BOWL.BANK2_ANGLE } })
local CHUTE_PROFILE = profile({ BANK1, { width = 14, angle = 48 }, { width = 14, angle = 74 } })
-- Вираж-спираль (#44): тот же жёлоб (ходовая часть и первые пояса совпадают — стык без ступеньки) и
-- ещё один почти отвесный пояс снаружи — борт выше, на вираже не вылетишь
local SPIRAL_PROFILE = profile({ BANK1, { width = 14, angle = 48 }, { width = 14, angle = 74 }, { width = Config.SPIRAL_WALL[1], angle = Config.SPIRAL_WALL[2] } })
local ROAD_PROFILE = profile({}) -- дорога: ровная площадка без бортов
local LAKE_PROFILE = { banks = {}, out = W * 1.5, top = 0, floorW = W * 3 } -- ледяное озеро после финиша
local BANK_OUT, BANK_TOP = SNOW_PROFILE.out, SNOW_PROFILE.top
-- Ездовая ширина чаши за краем дна (до барьера): дно + оба пояса — Track.rideSpan / sideOut / спасение
local BOWL_OUT = BANK_OUT - W / 2

local SNOW_FLOOR = Color3.fromRGB(236, 243, 252)
local SNOW_BANK = Color3.fromRGB(246, 249, 255)
local SNOW = Color3.fromRGB(250, 252, 255)

-- Точка на «полке» за краем трассы, без наклона (дома и деревья стоят ровно), лицом вдоль трассы
local function sidePoint(segCF: CFrame, x: number, z: number, top: number?): CFrame
	local p = segCF:PointToWorldSpace(Vector3.new(x, top or BANK_TOP, -z))
	local look = segCF.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	return CFrame.lookAt(p, p + (if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)))
end

-- Поперечное сечение: дно + пояса сугроба/льда, полка и невидимые стенки
local ICE_FLOOR = Color3.fromRGB(165, 210, 245)
local ICE_WALL = Color3.fromRGB(130, 190, 240)
-- seg.vis — длина визуальной части (борта, кромка, земля, барьер) от начала куска: поворот и
-- переход строят её одним куском на несколько частей пола; 0 — только пол (и невидимые борта).
-- Цвет снежного дна мира (конфетная гора — розоватый); плита гребня (#75) того же цвета
function Sections.floorColor(theme: number): Color3
	return if theme == 7 then SNOW_FLOOR:Lerp(Color3.fromRGB(255, 170, 215), 0.35) else SNOW_FLOOR
end

local function buildCrossSection(cf: CFrame, len: number, prof, chute: boolean, m: Instance, alt: number, theme: number, landing: boolean?, seg: Segment?)
	-- Визуальные части перекрываются, чтобы на поворотах не было щелей по внешнему краю;
	-- соседние куски чуть сдвинуты по высоте, чтобы перекрытия не мерцали.
	-- Пол (ходовая часть, #40) — без сдвига и встык: верх соседних полов совпадает на стыке, и
	-- нет ни ступенек 0.03, ни «губы» перекрытия на изломе. Только перед стыком, где сменится
	-- направление (поворот), пол заходит вперёд на 1 stud — закрыть клин по внешнему краю.
	-- жёлоб: щель по внешнему краю поворота out·tg(шаг) ≈ 9 на вираже; переходные куски (4 studs) — меньше
	local fillet = seg ~= nil and seg.kind == "fillet"
	-- (снег — 4: закрыть клин последней части пола поворота перед снежным куском, ~63·sin 2° ≈ 2.2)
	local overlap = if chute then (if fillet then 4 else 12) else 4
	local floorCF = cf
	local ahead = if seg and seg.floorAhead then 1 else 0
	local visLen = if seg and seg.vis ~= nil then seg.vis else len
	cf = cf * CFrame.new(0, alt * 0.03, 0)
	local floorW = prof.floorW or W
	local lake = prof == LAKE_PROFILE
	-- цвета мира: в конфетной горе снег розоватый, у вулкана земля — тёмный базальт
	local themeCfg = Config.THEMES[theme] or Config.THEMES[1]
	local snowFloor = Sections.floorColor(theme)
	local snowBank = if theme == 7 then SNOW_BANK:Lerp(Color3.fromRGB(255, 170, 215), 0.3) else SNOW_BANK
	local groundMat = if theme == 3 then Enum.Material.Sand elseif theme == 6 then Enum.Material.Basalt else Enum.Material.Snow
	part("Part", {
		Name = "Floor",
		Size = Vector3.new(floorW, 4, len + ahead),
		CFrame = floorCF * CFrame.new(0, -2, -(len + ahead) / 2),
		Material = if chute or lake then Enum.Material.Glacier else Enum.Material.Snow,
		Color = if lake then Color3.fromRGB(175, 220, 250) elseif chute then ICE_FLOOR else snowFloor,
		Reflectance = if chute or lake then 0.12 else 0,
	}, m)
	-- переходный кусок без визуальной части: свои борта (сугроб/лёд по краю) есть, кромку и
	-- землю держит первый кусок перехода
	local bankLen = if fillet then len else visLen
	-- первый (ездовой) пояс жёлоба — половинами куска поворота (seg.bank, Profile.bankHalf): на части
	-- пола с seg.bank строится только он, остальные пояса, кромка и земля — с первой части на весь кусок
	local bank1Len = if chute and seg and seg.bank then seg.bank else nil
	if bank1Len and bankLen == 0 then
		bankLen = bank1Len
	end
	-- Дорога/переезд: снаружи невидимого борта — невидимый сугроб того же профиля, что у снежных
	-- кусков, и барьер там же, где у них. Сани, выехавшие за борт с ледяного жёлоба (у жёлоба
	-- бортов нет), катятся по сугробу снаружи борта; раньше у дороги сугроб обрывался и они
	-- падали за карту (баг «вылет у дороги»). Видимая дорога и машины не меняются.
	local road = prof == ROAD_PROFILE
	local guard = if road then SNOW_PROFILE else prof
	-- Невидимый борт у края дна (Config.WALL_*) — только там, где за дном трассы нет: озеро (шире
	-- трассы), разгон к островкам isleIn (дальше — пропасть: воронка от края чаши к краю дна, затем
	-- борт). На чаше (#74) бортов нет: пояса склона — ездовые, страховка — барьер за ними. В жёлобе
	-- бортами служат сами ледяные пояса. Дорога/переезд: невидимые пояса той же чаши — стык с
	-- соседними снежными кусками без ступеньки (сани с пояса едут над асфальтом по невидимому снегу).
	local kind = if seg then seg.kind else nil
	local wallH = Config.WALL_HEIGHT * (if landing then 2 else 1)
	local needWall = not chute and wallH > 0 and (lake or kind == "isleIn")
	local funnel = kind == "isleIn" and not lake
	for _, side in { -1, 1 } do
		if seg and seg.open == side then
			continue -- развилка (#42): с этой стороны пол уходит к мосту, борта и обочину строит Track/Fork
		end
		local x, y = floorW / 2, 0
		if bankLen > 0 then
			for k, b in guard.banks do
				local a = math.rad(b.angle)
				local bl = if k == 1 and bank1Len then bank1Len else bankLen
				if k > 1 and visLen <= 0 and not fillet then
					break -- часть пола поворота с seg.bank: только первый пояс
				end
				-- плита пояса заходит назад, под плиту прошлого куска (щель клина поворота закрывает следующая
				-- плита), и не выступает вперёд: иначе на переходе круче→положе её край висел бы над
				-- следующей плитой — уступ на ездовом поясе (#74)
				part("Part", {
					Name = "Bank",
					Size = Vector3.new(b.width, 2, bl + overlap),
					CFrame = cf * CFrame.new(side * x, y, -bl / 2 + overlap / 2) * CFrame.Angles(0, 0, side * a) * CFrame.new(side * b.width / 2, -1, 0),
					Material = if chute then Enum.Material.Glacier else Enum.Material.Snow,
					Color = if chute then ICE_WALL:Lerp(Color3.new(1, 1, 1), (k - 1) * 0.12) else snowBank,
					Reflectance = if chute then 0.1 else 0,
					Transparency = if road then 1 else 0,
					CastShadow = not road,
				}, m)
				x += b.width * math.cos(a)
				y += b.width * math.sin(a)
			end
		end
		if visLen > 0 then
			-- Округлая снежная кромка
			deco({
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(visLen + overlap + 1, 6, 6),
				CFrame = cf * CFrame.new(side * (prof.out + 1), prof.top - 1.2, -visLen / 2) * CFrame.Angles(0, math.rad(90), 0),
				Material = Enum.Material.Snow,
				Color = SNOW,
			}, m)
			-- над долиной (seg.valley) с этой стороны — только полка до обрыва (обрыв строит Track/Valley)
			local valley = seg ~= nil and seg.valley ~= nil and (seg.valley == side or seg.valley == 2)
			local gw = if valley then Config.VALLEY_SHOULDER + 2 else 150
			part("Part", {
				Name = "Ground",
				Size = Vector3.new(gw, 2, visLen + overlap),
				CFrame = cf * CFrame.new(side * (prof.out + gw / 2), prof.top - 1, -visLen / 2),
				Material = groundMat,
				Color = if theme == 1 or theme == 2 then SNOW else themeCfg.ground,
				CanCollide = false,
			}, m)
			part("Part", {
				Name = "Barrier",
				Size = Vector3.new(2, BOWL.BARRIER_H, visLen + overlap),
				CFrame = cf * CFrame.new(side * (guard.out + 2), guard.top + BOWL.BARRIER_H / 4, -visLen / 2),
				Transparency = 1,
				CanQuery = false,
			}, m)
		end
		-- CanQuery=false у невидимых бортов — луч санок вниз и GetPartBoundsInBox их не видят;
		-- наклон наружу — скатываешься, а не прилипаешь.
		if lake then
			-- Озеро шире трассы: его край за барьером прошлого куска закрыт поперечным барьером
			-- (иначе на озере за бортом — карман, который сзади обрывается в пустоту)
			local x0 = BANK_OUT + 1
			local bw = prof.out + 3 - x0
			part("Part", {
				Name = "Barrier",
				Size = Vector3.new(bw, 40, 2),
				CFrame = floorCF * CFrame.new(side * (x0 + bw / 2), 10, 1),
				Transparency = 1,
				CanQuery = false,
				CastShadow = false,
			}, m)
		end
		if needWall then
			local tilt = math.rad(Config.WALL_TILT)
			local xEnd = floorW / 2 + Config.WALL_OFFSET
			local z0 = 0
			if funnel then
				-- воронка: от края чаши в начале куска к краю дна за FUNNEL_LEN (сани, въехавшие на пояс,
				-- сводятся на дно до прыжка); высотой до верха поясов — на втором поясе её не перелететь
				z0 = math.min(BOWL.FUNNEL_LEN, len - 4)
				local p0 = Vector3.new(side * (BANK_OUT + 0.3), 0, 1)
				local p1 = Vector3.new(side * xEnd, 0, -z0)
				local line = CFrame.lookAt((p0 + p1) / 2, p1)
				local fh = BANK_TOP + wallH + 2
				part("Part", {
					Name = "Wall",
					Size = Vector3.new(0.6, fh, (p1 - p0).Magnitude + 1),
					CFrame = cf * line * CFrame.Angles(0, 0, -side * tilt) * CFrame.new(0, fh / 2 - 1.5, 0),
					Transparency = 1,
					CanQuery = false,
					CastShadow = false,
				}, m)
			end
			part("Part", {
				Name = "Wall",
				Size = Vector3.new(0.6, wallH + 2, len - z0 + 2),
				CFrame = cf * CFrame.new(side * xEnd, -1.5, -(z0 + len) / 2)
					* CFrame.Angles(0, 0, -side * tilt) * CFrame.new(0, (wallH + 2) / 2, 0),
				Transparency = 1,
				CanQuery = false,
				CastShadow = false,
			}, m)
		end
	end
	if chute and visLen > 0 and not fillet then
		-- Белые разводы на льду жёлоба (как в трейлере)
		for _, x in { -W * 0.3, -W * 0.05, W * 0.2 } do
			deco({
				Size = Vector3.new(0.8, 0.05, visLen + overlap),
				CFrame = cf * CFrame.new(x, 0.03, -visLen / 2),
				Color = Color3.new(1, 1, 1),
				Transparency = 0.45,
			}, m)
		end
	end
end

Sections.W = W
Sections.SNOW_PROFILE = SNOW_PROFILE
Sections.CHUTE_PROFILE = CHUTE_PROFILE
Sections.SPIRAL_PROFILE = SPIRAL_PROFILE
Sections.ROAD_PROFILE = ROAD_PROFILE
Sections.LAKE_PROFILE = LAKE_PROFILE
Sections.BANK_OUT, Sections.BANK_TOP = BANK_OUT, BANK_TOP
Sections.BOWL_OUT = BOWL_OUT
Sections.SNOW_FLOOR, Sections.SNOW_BANK, Sections.SNOW = SNOW_FLOOR, SNOW_BANK, SNOW
Sections.sidePoint = sidePoint
Sections.build = buildCrossSection

return Sections
