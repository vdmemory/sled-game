-- Профиль уровня: цепочка кусков (виды, уклоны, повороты, скругления стыков, волны, островки,
-- дороги). Детерминирован по номеру уровня. Часть модуля shared/Track (см. Track/init).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Islands = require(ReplicatedStorage.Shared.Islands)

local Profile = {}

------------------------------------------------------------------ профиль уровня
-- Трасса — цепочка кусков. У каждого куска свой уклон (pitch) и направление (yaw).
-- Повороты собраны из коротких кусков, каждый чуть довёрнут, и одеты ледяным жёлобом.
export type Segment = {
	kind: string,
	angle: number, -- уклон, градусы (вниз > 0)
	yaw: number, -- направление, радианы (0 = -Z)
	length: number,
	cf: CFrame, -- начало куска: центр дна, -Z = вниз по трассе
	hStart: number, -- пройденный путь по горизонтали до начала куска
	hLen: number,
	chute: boolean,
	yawJoint: boolean?, -- направление сменилось на стыке с прошлым куском
	floorAhead: boolean?, -- на следующем стыке сменится направление: пол заходит вперёд на 1 stud
	vis: number?, -- длина визуальной части сечения (борта, кромка, земля) от начала куска; 0 — только пол
	ci: number?, -- номер «визуального» куска поворота (для арок и монет)
	isle: any?, -- островки: план островка / зазора (shared/Islands)
	crest: any?, -- волна: номер гребня (подъём) или false (спуск)
	tunnel: string?, -- кусок поворота под сводом тоннеля (#65): "in" / "mid" / "out"
}

-- После этих кусков стык намеренно разрывный (обрыв, вылет с ускорителя): без скругления
local BREAK_AFTER = { kicker = true, isleIn = true, isle = true, gap = true }

-- Тоннели (#65, владелец 2026-11-12: «как минимум 20% длины трассы»). После постройки профиля
-- выбираются непрерывные участки «наземных» кусков (повороты, пологие, крутые, скругления — без
-- трамплинов, приземлений, островков, волн, дорог, озера: там сани в воздухе или своя сцена) и
-- помечаются seg.tunnel = "in" / "mid" / "out", пока под сводом не окажется TUNNEL_SHARE пути.
-- Сначала длинные участки (каждый — не длиннее TUNNEL_MAX_LEN, середина участка), короче
-- TUNNEL_MIN_LEN не берутся. Случайные числа не тратятся — раскладка уровня не меняется.
local TUNNEL_KINDS = { curve = true, gentle = true, steep = true, fillet = true }
local function markTunnels(segs: { Segment })
	local total = 0
	for _, s in segs do
		if s.kind ~= "lake" then
			total += s.hLen
		end
	end
	local share = Config.TUNNEL_SHARE or 0
	if share <= 0 or total <= 0 then
		return
	end
	-- непрерывные участки допустимых кусков после TUNNEL_FROM_H
	local runs = {}
	local i = 1
	while i <= #segs do
		if TUNNEL_KINDS[segs[i].kind] and segs[i].hStart >= Config.TUNNEL_FROM_H then
			local j, len = i, 0
			while j <= #segs and TUNNEL_KINDS[segs[j].kind] do
				len += segs[j].hLen
				j += 1
			end
			table.insert(runs, { a = i, b = j - 1, len = len })
			i = j
		else
			i += 1
		end
	end
	table.sort(runs, function(x, y)
		return if x.len == y.len then x.a < y.a else x.len > y.len
	end)
	local covered = 0
	for _, run in runs do
		if covered >= total * share or run.len < Config.TUNNEL_MIN_LEN then
			break
		end
		-- середина участка длиной не больше TUNNEL_MAX_LEN (и не больше недостающего, но ≥ MIN)
		local want = math.min(run.len, Config.TUNNEL_MAX_LEN, math.max(Config.TUNNEL_MIN_LEN, total * share - covered + 40))
		local skip = (run.len - want) / 2
		local acc, first, last = 0, nil :: number?, nil :: number?
		for k = run.a, run.b do
			local s = segs[k]
			if acc + s.hLen > skip and acc < skip + want then
				first = first or k
				last = k
				covered += s.hLen
			end
			acc += s.hLen
		end
		if first and last then
			-- первый и последний куски с видимой частью — порталы
			local vfirst, vlast = nil :: number?, nil :: number?
			for k = first, last do
				local v = segs[k].vis
				if v == nil or v > 0 then
					vfirst = vfirst or k
					vlast = k
				end
				segs[k].tunnel = "mid"
			end
			if vfirst then
				segs[vfirst].tunnel = "in"
			end
			if vlast and vlast ~= vfirst then
				segs[vlast].tunnel = "out"
			end
		end
	end
end

local function buildProfile(origin: CFrame, level: number): ({ Segment }, number)
	local rng = Random.new(level * 7919 + 17)
	local isleRng = Random.new(level * 3571 + 7)
	local curveIndex = 0
	local lastIsle: number? = nil
	local L = Config.levelLength(level)
	local segs: { Segment } = {}
	local pos = origin.Position
	local yaw = 0
	local h = 0
	local forceNext: string? = nil
	local lastTurn = 1
	local prevAngle = 0 -- стартовая площадка ровная
	local prevYaw = 0

	-- Кусок как есть (без скругления стыка)
	local function push(kind: string, angle: number, length: number, chute: boolean?, extra: { [string]: any }?): Segment
		local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(-math.rad(angle), 0, 0)
		local endPos = cf:PointToWorldSpace(Vector3.new(0, 0, -length))
		local hLen = length * math.cos(math.rad(angle))
		local seg: Segment = {
			kind = kind,
			angle = angle,
			yaw = yaw,
			length = length,
			cf = cf,
			hStart = h,
			hLen = hLen,
			chute = chute == true,
			yawJoint = math.abs(yaw - prevYaw) > 1e-6,
		}
		if extra then
			for k, v in extra do
				(seg :: any)[k] = v
			end
		end
		if seg.yawJoint and segs[#segs] then
			-- клин по внешнему краю поворота закрывает пол прошлого куска: там, где новый кусок
			-- выше, продолжение прошлого прячется под ним, где ниже — сани сходят на него вниз
			segs[#segs].floorAhead = true
		end
		table.insert(segs, seg)
		h += hLen
		pos = endPos
		prevAngle, prevYaw = angle, yaw
		if kind == "kicker" then
			pos -= Vector3.new(0, Config.KICKER_DROP, 0)
		end
		return seg
	end

	-- Кусок со скруглённым стыком (#40): если уклон меняется больше SMOOTH_KINK, перед куском
	-- встают переходные куски длиной FILLET_LEN с промежуточными уклонами — излом на каждом
	-- стыке ≤ SMOOTH_KINK, сани не «втыкаются» в склон и не подлетают на изломе.
	local function add(kind: string, angle: number, length: number, chute: boolean?, extra: { [string]: any }?): Segment
		local last = segs[#segs]
		if not (last and BREAK_AFTER[last.kind]) then
			local d = angle - prevAngle
			local n = math.ceil(math.abs(d) / math.max(0.1, Config.SMOOTH_KINK) - 1e-6) - 1
			local a0 = prevAngle
			local iceRun = chute == true or (last ~= nil and last.chute)
			for j = 1, n do
				push("fillet", a0 + d * j / (n + 1), Config.FILLET_LEN, iceRun)
			end
		end
		return push(kind, angle, length, chute, extra)
	end

	-- Поворот из коротких кусков. Направление выбираем так, чтобы трасса не уходила далеко вбок
	local function curve()
		local drift = origin:PointToObjectSpace(pos).X
		local dir
		if math.abs(drift) > Config.MAX_DRIFT then
			dir = if drift > 0 then 1 else -1 -- поворачиваем обратно к центру (yaw > 0 — влево)
		elseif math.abs(math.deg(yaw)) > Config.MAX_HEADING * 0.5 then
			dir = if yaw > 0 then -1 else 1
		else
			dir = -lastTurn -- змейка: чередуем стороны
		end
		lastTurn = dir
		local total = math.rad(rng:NextNumber(Config.CURVE_ANGLE[1], Config.CURVE_ANGLE[2]))
		local maxYaw = math.rad(Config.MAX_HEADING)
		local pieces = math.max(3, math.floor(math.deg(total) / Config.CURVE_STEP + 0.5))
		local step = total / pieces * dir
		local pitch = rng:NextNumber(Config.CURVE_PITCH[1], Config.CURVE_PITCH[2])
		local last = segs[#segs]
		if last and last.kind == "curve" then
			pitch = last.angle -- поворот сразу за поворотом — тот же уклон (излом + доворот на одном стыке)
		end
		-- Пол куска поворота — из CURVE_SUBSTEPS частей, каждая довёрнута на шаг / n: ступенька
		-- на краю дна x·sin(шаг/n)·tg(уклон) ≤ 0.2 stud. Борта и декор строит первая часть на весь кусок.
		local sub = math.max(1, Config.CURVE_SUBSTEPS)
		for piece = 1, pieces do
			local turn = math.abs(yaw + step) <= maxYaw
			curveIndex += 1
			for k = 1, sub do
				-- первая часть поворота не доворачивает: на стыке, где меняется уклон, направление
				-- не меняется (иначе ступеньки складываются на краю дна)
				if turn and not (piece == 1 and k == 1) then
					yaw += step / sub
				end
				local extra = { vis = if k == 1 then Config.CURVE_PIECE else 0, ci = curveIndex }
				if k == 1 then
					add("curve", pitch, Config.CURVE_PIECE / sub, true, extra)
				else
					push("curve", pitch, Config.CURVE_PIECE / sub, true, extra)
				end
			end
		end
	end

	-- Волны-бугры (#40): серия «вниз → вверх» — сани ныряют и на гребне слегка подлетают; переходы
	-- между уклонами — те же скругления (излом ≤ SMOOTH_KINK), монеты на каждом гребне
	local function waves()
		local count = isleRng:NextInteger(Config.WAVE_COUNT[1], Config.WAVE_COUNT[2])
		for k = 1, count do
			add("wave", Config.WAVE_DOWN[1], Config.WAVE_DOWN[2], false, { crest = false })
			add("wave", Config.WAVE_UP[1], Config.WAVE_UP[2], false, { crest = k })
		end
	end

	-- Островки над пропастью (#40): разгон с ускорителем → [зазор → островок] × n → зазор →
	-- склон приземления. План — Islands.plan (баллистика, свой seed). Не строим, если цепочка не
	-- помещается до финиша. Ответ: построили ли.
	local function islands(): boolean
		local spec = Islands.plan(level, isleRng)
		local total = Config.ISLE_IN[2] + 90
		for k, g in spec.gaps do
			total += g.gap + (if spec.isles[k] then spec.isles[k].len else 0)
		end
		if h + total > L - 80 then
			return false
		end
		add("isleIn", Config.ISLE_IN[1], Config.ISLE_IN[2])
		for k, g in spec.gaps do
			push("gap", math.deg(math.atan2(g.drop, g.gap)), math.sqrt(g.gap * g.gap + g.drop * g.drop), false, { isle = g })
			local isle = spec.isles[k]
			if isle then
				push("isle", isle.pitch, isle.len, false, { isle = isle })
			end
		end
		push("landing", 18, 90)
		lastIsle = h
		return true
	end

	add("start", 7, 110)
	local nextForced = 1
	-- островки: свой генератор (не сдвигает раскладку остальных кусков уровня)
	local isleOn = level >= Config.ISLE_FROM_LEVEL
	local isleNext: number? = if isleOn then L * Config.ISLE_AT else nil
	local nextRoad = 1
	local roads = Config.roadCount(level)
	local railDone = false
	while h < L do
		local forcedAt = Config.FORCED_KICKERS[nextForced]
		local roadAt = if nextRoad <= roads then Config.ROAD_AT[nextRoad] else nil
		if forceNext ~= "landing" and roadAt and h >= L * roadAt then
			-- в городе одна из дорог — железнодорожный переезд
			local theme = Config.themeOf(level)
			if theme == 2 and not railDone and nextRoad == 2 then
				add("rail", 3, 60)
				railDone = true
			else
				add("road", 3, 60)
			end
			nextRoad += 1
		elseif forceNext == "landing" then
			add("landing", 18, 90)
			forceNext = nil
		elseif isleNext and h >= isleNext then
			isleNext = nil
			if not islands() then
				add("gentle", rng:NextNumber(Config.GENTLE_ANGLE[1], Config.GENTLE_ANGLE[2]), 120)
			end
		elseif forcedAt and h >= L * forcedAt then
			add("kicker", 6, 100)
			forceNext = "landing"
			nextForced += 1
		else
			local t = rng:NextNumber()
			local steep = Config.steepChance(level)
			-- доп. цепочка островков (шанс растёт с уровнем, не чаще ISLE_MIN_SPACING)
			local extraIsle = isleOn and isleRng:NextNumber() < Config.isleChance(level)
				and lastIsle ~= nil and h - lastIsle >= Config.ISLE_MIN_SPACING
			if extraIsle and islands() then
				-- построили островки вместо обычного куска
			elseif level >= Config.WAVE_FROM_LEVEL and h > 300 and isleRng:NextNumber() < Config.WAVE_CHANCE then
				waves()
			elseif h > 220 and t < Config.CURVE_CHANCE then
				curve()
			elseif t < Config.CURVE_CHANCE + steep then
				add("steep", rng:NextNumber(Config.STEEP_ANGLE[1], Config.STEEP_ANGLE[2]), 90)
			elseif t < Config.CURVE_CHANCE + steep + Config.KICKER_CHANCE and h > 250 then
				add("kicker", 6, 100)
				forceNext = "landing"
			else
				add("gentle", rng:NextNumber(Config.GENTLE_ANGLE[1], Config.GENTLE_ANGLE[2]), 120)
			end
		end
	end
	if forceNext == "landing" then
		add("landing", 18, 90)
	end
	add("lake", 0.5, 300) -- ледяное озеро: после финиша катимся до остановки
	markTunnels(segs)
	return segs, L
end

Profile.build = buildProfile

return Profile
