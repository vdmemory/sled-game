-- Поперечные сечения трассы: профили (снег, ледяной жёлоб, дорога, озеро), цвета снега, точка на
-- «полке» за краем трассы и само сечение куска (пол, борта, кромка, земля, невидимые стенки).
-- Часть модуля shared/Track (см. Track/init).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Props = require(ReplicatedStorage.Shared.Props)

local Profile = require(script.Parent.Profile)

local part, deco = Props.part, Props.deco

type Segment = Profile.Segment

local Sections = {}

------------------------------------------------------------------ поперечные профили
-- Снежный склон: дно шириной W и два пояса мягкого сугроба.
-- Ледяной жёлоб (повороты): то же дно, но высокие изогнутые ледяные стенки — как горка в аквапарке.
local W = Config.TRACK_WIDTH
local function profile(banks: { { width: number, angle: number } })
	local out, top = W / 2, 0
	for _, b in banks do
		out += b.width * math.cos(math.rad(b.angle))
		top += b.width * math.sin(math.rad(b.angle))
	end
	return { banks = banks, out = out, top = top }
end
local SNOW_PROFILE = profile({ { width = 14, angle = 14 }, { width = 14, angle = 32 } })
local CHUTE_PROFILE = profile({ { width = 12, angle = 22 }, { width = 14, angle = 48 }, { width = 14, angle = 74 } })
local ROAD_PROFILE = profile({}) -- дорога: ровная площадка без бортов
local LAKE_PROFILE = { banks = {}, out = W * 1.5, top = 0, floorW = W * 3 } -- ледяное озеро после финиша
local BANK_OUT, BANK_TOP = SNOW_PROFILE.out, SNOW_PROFILE.top

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
local function buildCrossSection(cf: CFrame, len: number, prof, chute: boolean, m: Instance, alt: number, theme: number, landing: boolean?, seg: Segment?)
	-- Визуальные части перекрываются, чтобы на поворотах не было щелей по внешнему краю;
	-- соседние куски чуть сдвинуты по высоте, чтобы перекрытия не мерцали.
	-- Пол (ходовая часть, #40) — без сдвига и встык: верх соседних полов совпадает на стыке, и
	-- нет ни ступенек 0.03, ни «губы» перекрытия на изломе. Только перед стыком, где сменится
	-- направление (поворот), пол заходит вперёд на 1 stud — закрыть клин по внешнему краю.
	local overlap = if chute then 8 else 2
	local floorCF = cf
	local ahead = if seg and seg.floorAhead then 1 else 0
	local visLen = if seg and seg.vis ~= nil then seg.vis else len
	cf = cf * CFrame.new(0, alt * 0.03, 0)
	local floorW = prof.floorW or W
	local lake = prof == LAKE_PROFILE
	-- цвета мира: в конфетной горе снег розоватый, у вулкана земля — тёмный базальт
	local themeCfg = Config.THEMES[theme] or Config.THEMES[1]
	local snowFloor = if theme == 7 then SNOW_FLOOR:Lerp(Color3.fromRGB(255, 170, 215), 0.35) else SNOW_FLOOR
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
	local fillet = seg ~= nil and seg.kind == "fillet"
	local bankLen = if fillet then len else visLen
	for _, side in { -1, 1 } do
		local x, y = floorW / 2, 0
		if bankLen > 0 then
			for k, b in prof.banks do
				local a = math.rad(b.angle)
				part("Part", {
					Name = "Bank",
					Size = Vector3.new(b.width, 2, bankLen + overlap),
					CFrame = cf * CFrame.new(side * x, y, -bankLen / 2) * CFrame.Angles(0, 0, side * a) * CFrame.new(side * b.width / 2, -1, 0),
					Material = if chute then Enum.Material.Glacier else Enum.Material.Snow,
					Color = if chute then ICE_WALL:Lerp(Color3.new(1, 1, 1), (k - 1) * 0.12) else snowBank,
					Reflectance = if chute then 0.1 else 0,
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
			part("Part", {
				Name = "Ground",
				Size = Vector3.new(150, 2, visLen + overlap),
				CFrame = cf * CFrame.new(side * (prof.out + 75), prof.top - 1, -visLen / 2),
				Material = groundMat,
				Color = if theme == 1 or theme == 2 then SNOW else themeCfg.ground,
				CanCollide = false,
			}, m)
			part("Part", {
				Name = "Barrier",
				Size = Vector3.new(2, 40, visLen + overlap),
				CFrame = cf * CFrame.new(side * (prof.out + 2), prof.top + 10, -visLen / 2),
				Transparency = 1,
				CanQuery = false,
			}, m)
		end
		-- Невидимый борт у края дна (Config.WALL_*): санки больше не уезжают на сугроб и не
		-- проваливаются там, где у соседнего куска сугроба нет (дорога, озеро, приземление).
		-- В жёлобе бортами служат сами ледяные пояса. На приземлении после обрыва борт вдвое выше:
		-- санки прилетают сверху и не должны перелететь его. CanQuery=false — луч санок вниз и
		-- GetPartBoundsInBox его не видят; наклон наружу — скатываешься, а не прилипаешь.
		local wallH = Config.WALL_HEIGHT * (if landing then 2 else 1)
		if not chute and wallH > 0 then
			local tilt = math.rad(Config.WALL_TILT)
			part("Part", {
				Name = "Wall",
				Size = Vector3.new(0.6, wallH + 2, len + 2),
				CFrame = cf * CFrame.new(side * (floorW / 2 + Config.WALL_OFFSET), -1.5, -len / 2)
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
Sections.ROAD_PROFILE = ROAD_PROFILE
Sections.LAKE_PROFILE = LAKE_PROFILE
Sections.BANK_OUT, Sections.BANK_TOP = BANK_OUT, BANK_TOP
Sections.SNOW_FLOOR, Sections.SNOW_BANK, Sections.SNOW = SNOW_FLOOR, SNOW_BANK, SNOW
Sections.sidePoint = sidePoint
Sections.build = buildCrossSection

return Sections
