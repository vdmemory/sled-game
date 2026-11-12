-- Профиль уровня: цепочка кусков (виды, уклоны, повороты, скругления стыков, волны, островки,
-- дороги). Детерминирован по номеру уровня. Часть модуля shared/Track (см. Track/init).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Islands = require(ReplicatedStorage.Shared.Islands)
local Stairs = require(script.Parent.Stairs)
local Fork = require(script.Parent.Fork)

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
	tunnel: string?, -- кусок под сводом тоннеля (#65): "in" / "mid" / "out"
	valley: number?, -- трасса по гребню над долиной с островками: −1 слева, 1 справа, 2 с обеих сторон
	stair: any?, -- трамплин-лестница (#43): ступень плана Track/Stairs (трамплин в конце куска)
	spiral: number?, -- вираж-спираль (#44): направление поворота (1 — влево, −1 — вправо)
	ice: any?, -- ледяной тоннель с кольцами (#44): { half = 1 | 2 } (Track/IceTunnel)
	fork: any?, -- развилка у островков (#42): план моста (Track/Fork) на разгоне, кусках цепочки и приземлении
	open: number?, -- развилка: с этой стороны (−1/1) сечение без бортов — пол уходит к мосту
}

-- После этих кусков стык намеренно разрывный (обрыв, вылет с ускорителя): без скругления
-- (лестница #43: сани в полёте над стыком, баллистика считает склон без переходных кусков)
local BREAK_AFTER = { kicker = true, isleIn = true, isle = true, gap = true, stair = true }

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

-- Гребень над долиной (владелец 2026-11-12, видео референса 613–651 м): с одной стороны трассы
-- (или с обеих) вместо ровной земли — обрыв вниз к долине с островками. Участки — как у тоннелей,
-- но не под сводом: VALLEY_SHARE пути, стороны чередуются (каждый 3-й — с обеих). Случайные числа не
-- тратятся.
local VALLEY_KINDS = { curve = true, gentle = true, steep = true, fillet = true, landing = true }
local function markValleys(segs: { Segment })
	local share = Config.VALLEY_SHARE or 0
	local total = 0
	for _, s in segs do
		if s.kind ~= "lake" then
			total += s.hLen
		end
	end
	if share <= 0 or total <= 0 then
		return
	end
	local runs = {}
	local i = 1
	while i <= #segs do
		local s = segs[i]
		-- приземление развилки (#42) — не над долиной: с одной стороны там пол к мосту
		if VALLEY_KINDS[s.kind] and not s.tunnel and not s.fork and s.hStart >= Config.VALLEY_FROM_H then
			local j, len = i, 0
			while j <= #segs and VALLEY_KINDS[segs[j].kind] and not segs[j].tunnel and not segs[j].fork do
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
	local covered, n = 0, 0
	for _, run in runs do
		if covered >= total * share or run.len < Config.VALLEY_MIN_LEN then
			break
		end
		n += 1
		local side = if n % 3 == 0 then 2 elseif n % 2 == 1 then -1 else 1
		local want = math.min(run.len, Config.VALLEY_MAX_LEN)
		local skip = (run.len - want) / 2
		local acc = 0
		for k = run.a, run.b do
			local s = segs[k]
			if acc + s.hLen > skip and acc < skip + want then
				s.valley = side
				covered += s.hLen
			end
			acc += s.hLen
		end
	end
end

-- Развилка у островков (#42): «бросок» для цепочки chainNo уровня — не Random, а равномерная
-- (низкодисперсная, золотое сечение) последовательность по уровням и цепочкам: доля Config.forkChance
-- выдерживается и на коротком отрезке уровней (в мире из 5 уровней не выпадет «ни одной развилки»).
-- Случайные числа не тратятся — цепочки без развилки не меняются.
function Profile.forkRoll(level: number, chainNo: number): number
	return (level * 0.6180339887 + chainNo * 0.7548776662) % 1
end

local function buildProfile(origin: CFrame, level: number): ({ Segment }, number)
	local rng = Random.new(level * 7919 + 17)
	local isleRng = Random.new(level * 3571 + 7)
	-- новые участки (#43 лестница, #44 вираж и ледяной тоннель): свой генератор — уровни, где их нет,
	-- не меняются
	local featRng = Random.new(level * 6151 + 29)
	-- развилка у островков (#42): номер цепочки на уровне (выбор развилки — Profile.forkRoll)
	local chainNo = 0
	local lastStair: number? = nil
	local lastSpiral: number? = nil
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
	-- target (#73) — поворот-доводка: повернуть к этому курсу (радианы), угол — сколько нужно
	-- (15…CURVE_ANGLE[2]°); случайные числа тратятся как у обычного поворота
	local function curve(target: number?)
		local drift = origin:PointToObjectSpace(pos).X
		local dir
		-- после виража (#44) курс шире MAX_HEADING: сначала возвращаем курс, потом смотрим на снос
		local wide = math.abs(math.deg(yaw)) > Config.MAX_HEADING + 1
		if target then
			dir = if target > yaw then 1 else -1
		elseif not wide and math.abs(drift) > Config.MAX_DRIFT then
			dir = if drift > 0 then 1 else -1 -- поворачиваем обратно к центру (yaw > 0 — влево)
		elseif math.abs(math.deg(yaw)) > Config.MAX_HEADING * 0.5 then
			dir = if yaw > 0 then -1 else 1
		else
			dir = -lastTurn -- змейка: чередуем стороны
		end
		lastTurn = dir
		local total = math.rad(rng:NextNumber(Config.CURVE_ANGLE[1], Config.CURVE_ANGLE[2]))
		local maxYaw = math.rad(Config.MAX_HEADING)
		if target then
			-- первая часть поворота не доворачивает: на неё — ещё кусок
			local need = math.abs(target - yaw) + math.rad(Config.CURVE_STEP) / math.max(1, Config.CURVE_SUBSTEPS)
			total = math.clamp(need, math.rad(Config.CURVE_STEP * 3), math.rad(Config.CURVE_ANGLE[2]))
		end
		local pieces = math.max(3, math.floor(math.deg(total) / Config.CURVE_STEP + 0.5))
		local step = total / pieces * dir
		local pitch = rng:NextNumber(Config.CURVE_PITCH[1], Config.CURVE_PITCH[2])
		local last = segs[#segs]
		if last and (last.kind == "curve" or last.kind == "spiral") then
			pitch = last.angle -- поворот сразу за поворотом — тот же уклон (излом + доворот на одном стыке)
		end
		-- Пол куска поворота — из CURVE_SUBSTEPS частей, каждая довёрнута на шаг / n: ступенька
		-- на краю дна x·sin(шаг/n)·tg(уклон) ≤ 0.2 stud. Борта и декор строит первая часть на весь кусок.
		local sub = math.max(1, Config.CURVE_SUBSTEPS)
		for piece = 1, pieces do
			-- за пределом MAX_HEADING (после виража) поворот к оси разрешён
			local turn = math.abs(yaw + step) <= maxYaw or math.abs(yaw + step) < math.abs(yaw)
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

	-- Жёсткий предел сноса (#73). Прямые куски под курсом сносят трассу вбок на sin(курс)·путь, а
	-- поворот (и MAX_DRIFT в нём) случаен — длинные участки (цепочка островков ~1000 studs, лестница,
	-- волны) уводили трассу на 2000+ studs. Перед куском/участком длиной ahead: если прогноз сноса в
	-- конце (или снос сейчас) дальше DRIFT_LIMIT — поворот-доводка к курсу, который выводит к оси за
	-- max(ahead, STEER_RETURN); не больше двух поворотов подряд. Повороты — обычные куски curve.
	local function steer(ahead: number)
		local lim = Config.DRIFT_LIMIT
		local maxSin = math.sin(math.rad(Config.MAX_HEADING))
		for _ = 1, 2 do
			local x = origin:PointToObjectSpace(pos).X
			local xEnd = x - math.sin(yaw) * ahead -- yaw > 0 — влево, к −X
			if math.abs(xEnd) <= lim and math.abs(x) <= lim then
				return
			end
			local target = math.asin(math.clamp(x / math.max(ahead, Config.STEER_RETURN), -maxSin, maxSin))
			if math.abs(target - yaw) < math.rad(Config.CURVE_STEP) then
				return -- курс уже ведёт к оси: дальше доведут прямые куски
			end
			curve(target)
		end
	end

	-- Вираж-спираль (#44): поворот 120–150° по широкому жёлобу с высокими бортами. Трасса уже смотрит
	-- вбок (|курс| ≥ SPIRAL_MIN_YAW) — поворачиваем через ось в другую сторону не дальше SPIRAL_MAX_HEADING
	-- (назад трасса не уходит), сразу за виражом — обычный поворот обратно к оси. Пол — как у поворота:
	-- CURVE_SUBSTEPS частей на кусок, первая часть не доворачивает (излом уклона и доворот не на одном стыке).
	local function spiral()
		local dir = if yaw > 0 then -1 else 1
		local want = math.rad(featRng:NextNumber(Config.SPIRAL_ANGLE[1], Config.SPIRAL_ANGLE[2]))
		local total = math.min(want, math.abs(yaw) + math.rad(Config.SPIRAL_MAX_HEADING))
		local pieces = math.max(3, math.floor(math.deg(total) / Config.SPIRAL_STEP + 0.5))
		local step = total / pieces * dir
		local pitch = featRng:NextNumber(Config.SPIRAL_PITCH[1], Config.SPIRAL_PITCH[2])
		local last = segs[#segs]
		if last and last.kind == "curve" then
			pitch = last.angle -- сразу за поворотом — тот же уклон (как поворот за поворотом)
		end
		local sub = math.max(1, Config.CURVE_SUBSTEPS)
		for piece = 1, pieces do
			curveIndex += 1
			for k = 1, sub do
				if not (piece == 1 and k == 1) then
					yaw += step / sub
				end
				local extra = { vis = if k == 1 then Config.CURVE_PIECE else 0, ci = curveIndex, spiral = dir }
				if k == 1 then
					add("spiral", pitch, Config.CURVE_PIECE / sub, true, extra)
				else
					push("spiral", pitch, Config.CURVE_PIECE / sub, true, extra)
				end
			end
		end
		lastSpiral = h
		lastTurn = dir
	end

	-- Влезает ли вираж с поворотами обратно в SPIRAL_DRIFT_LIMIT (#73): прогон дуги в худшем случае (наибольший
	-- угол, пологий уклон) и возврата курса до MAX_HEADING / 2 по CURVE_STEP на кусок. Без случайных чисел.
	local function spiralFits(): boolean
		local x = origin:PointToObjectSpace(pos).X
		local y = yaw
		local dir = if y > 0 then -1 else 1
		local total = math.min(math.rad(Config.SPIRAL_ANGLE[2]), math.abs(y) + math.rad(Config.SPIRAL_MAX_HEADING))
		local pieces = math.max(3, math.floor(math.deg(total) / Config.SPIRAL_STEP + 0.5))
		local hl = Config.CURVE_PIECE * math.cos(math.rad(Config.SPIRAL_PITCH[1]))
		local worst = math.abs(x)
		for _ = 1, pieces do
			y += total / pieces * dir
			x -= math.sin(y) * hl
			worst = math.max(worst, math.abs(x))
		end
		local back = math.rad(Config.CURVE_STEP)
		while math.abs(y) > math.rad(Config.MAX_HEADING * 0.5) do
			y -= back * math.sign(y)
			x -= math.sin(y) * hl
			worst = math.max(worst, math.abs(x))
		end
		return worst <= Config.SPIRAL_DRIFT_LIMIT
	end

	-- Волны-бугры (#40): серия «вниз → вверх» — сани ныряют и на гребне слегка подлетают; переходы
	-- между уклонами — те же скругления (излом ≤ SMOOTH_KINK), монеты на каждом гребне
	local function waves()
		local count = isleRng:NextInteger(Config.WAVE_COUNT[1], Config.WAVE_COUNT[2])
		steer(count * (Config.WAVE_DOWN[2] + Config.WAVE_UP[2] + 4 * Config.FILLET_LEN)) -- #73
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
		-- развилка (#42): ледяной мост сбоку (Track/Fork) — доля цепочек Config.forkChance; мост от конца
		-- разгона (уклон ISLE_IN[1]) до начала склона приземления (уклон 18°), иначе развилки нет
		local fork = nil
		chainNo += 1
		local intro = Config.FORK_INTRO >= 1 and level == Config.FORK_FROM_LEVEL and chainNo == 1
		if Profile.forkRoll(level, chainNo) < Config.forkChance(level) or intro then
			fork = Fork.plan(spec, Config.ISLE_IN[1], 18)
		end
		local inLen = if fork then Config.FORK_IN_LEN else Config.ISLE_IN[2]
		local landLen = if fork then Config.FORK_LAND_LEN else 90
		local total = inLen + landLen
		for k, g in spec.gaps do
			total += g.gap + (if spec.isles[k] then spec.isles[k].len else 0)
		end
		-- ледяной тоннель с кольцами-ускорителями перед цепочкой (#44, Track/IceTunnel): разгон перед
		-- прыжками; скорость вылета всё равно задаёт ускоритель островков (окно LaunchMin…LaunchMax)
		local ice = level >= Config.ICE_TUNNEL_FROM_LEVEL and featRng:NextNumber() < Config.ICE_TUNNEL_CHANCE
		if fork then
			ice = false -- перед развилкой — открытый разгон: вывеска и обе ветки видны издалека
		end
		if ice then
			total += Config.ICE_TUNNEL_LEN
		end
		steer(total) -- #73: цепочка идёт по прямой — курс к оси до неё
		if h + total > L - 80 then
			return false
		end
		if fork then
			-- рисковая ветка: монет дугой × FORK_RISK_COINS, FORK_RISK_GEMS гемов; островки уже (зазор до моста)
			for _, g in spec.gaps do
				g.arc = Islands.gapArc(spec.vmin, spec.vmax, g.from, g.gap, g.landMid, Config.ISLE_COINS * Config.FORK_RISK_COINS)
			end
			local gems = math.floor(Config.FORK_RISK_GEMS)
			for j = 1, gems do
				spec.gaps[math.clamp(math.round(j * #spec.gaps / (gems + 1)), 1, #spec.gaps)].riskGem = true
			end
			for _, isle in spec.isles do
				isle.rim = math.min(isle.rim, Config.FORK_ISLE_RIM)
			end
		end
		if ice then
			local half = Config.ICE_TUNNEL_LEN / 2
			add("iceTunnel", Config.ICE_TUNNEL_PITCH, half, true, { tunnel = "in", ice = { half = 1 } })
			add("iceTunnel", Config.ICE_TUNNEL_PITCH, half, true, { tunnel = "out", ice = { half = 2 } })
		end
		add("isleIn", Config.ISLE_IN[1], inLen, nil, if fork then { fork = fork, open = fork.side } else nil)
		if fork then
			-- система цепочки: конец разгона, курс цепочки (островки идут без поворотов)
			fork.origin = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
			fork.h0 = h
		end
		for k, g in spec.gaps do
			push("gap", math.deg(math.atan2(g.drop, g.gap)), math.sqrt(g.gap * g.gap + g.drop * g.drop), false, { isle = g, fork = fork })
			local isle = spec.isles[k]
			if isle then
				push("isle", isle.pitch, isle.len, false, { isle = isle, fork = fork })
			end
		end
		push("landing", 18, landLen, nil, if fork then { fork = fork, open = fork.side } else nil)
		lastIsle = h
		return true
	end

	-- Трамплин-лестница (#43): план — Track/Stairs (баллистика); не строим, если не влезает до финиша
	local function stairs(): boolean
		local spec = Stairs.plan(level, featRng)
		steer(spec.total) -- #73
		if h + spec.total > L - 80 then
			return false
		end
		for _, step in spec.steps do
			add("stair", step.pitch, step.len, false, { stair = step })
		end
		add("stairLand", spec.landPitch, spec.landLen)
		lastStair = h
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
		if forceNext == nil and h > 150 then
			-- #73: жёсткий предел сноса перед обычным куском; у финиша — до конца озера
			steer(if h > L - 600 then math.max(Config.STEER_AHEAD, L - h + 300) else Config.STEER_AHEAD)
		end
		local forcedAt = Config.FORCED_KICKERS[nextForced]
		local roadAt = if nextRoad <= roads then Config.ROAD_AT[nextRoad] else nil
		if forceNext ~= "landing" and roadAt and h >= L * roadAt then
			-- в городе одна из дорог — железнодорожный переезд
			local theme = Config.themeOf(level)
			if theme == 2 and not railDone and nextRoad == 2 then
				-- переезд с обязательным трамплином перед ним (эпик E2): прыжок через пути и поезд,
				-- приземление — сразу за переездом
				add("kicker", 6, 100)
				add("rail", 3, 60)
				forceNext = "landing"
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
			local stairOk = level >= Config.STAIR_FROM_LEVEL and h >= Config.STAIR_FROM_H
				and (lastStair == nil or h - lastStair >= Config.STAIR_MIN_SPACING)
				and (lastIsle == nil or h - lastIsle >= Config.STAIR_ISLE_SPACING)
			if extraIsle and islands() then
				-- построили островки вместо обычного куска
			elseif stairOk and featRng:NextNumber() < Config.stairChance(level) and stairs() then
				-- лестница трамплинов вместо обычного куска
			elseif level >= Config.SPIRAL_FROM_LEVEL and h >= Config.SPIRAL_FROM_H and h < L - 600
				and math.abs(math.deg(yaw)) >= Config.SPIRAL_MIN_YAW
				and (lastSpiral == nil or h - lastSpiral >= Config.SPIRAL_MIN_SPACING)
				-- #73: вираж с поворотами обратно не выводит трассу за SPIRAL_DRIFT_LIMIT. Вираж — S-образный: за
				-- ним трасса уходит в ту сторону, откуда шла (~+240 studs), поэтому прежнее условие «вираж
				-- ведёт к оси» уводило её от оси; теперь решает прогон дуги
				and spiralFits()
				and featRng:NextNumber() < Config.spiralChance(level) then
				spiral()
				-- и сразу обратно: поворотами, пока курс не станет ≤ MAX_HEADING / 2 (не больше трёх)
				for _ = 1, 3 do
					curve()
					if math.abs(math.deg(yaw)) <= Config.MAX_HEADING * 0.5 then
						break
					end
				end
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
	steer(300) -- #73: последний кусок мог быть поворотом от оси — озеро тоже прямая под курсом
	add("lake", 0.5, 300) -- ледяное озеро: после финиша катимся до остановки
	markTunnels(segs)
	markValleys(segs)
	return segs, L
end

Profile.build = buildProfile

return Profile
