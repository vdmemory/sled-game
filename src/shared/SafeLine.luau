-- Безопасная линия (issue #29): раскладка рядов препятствий уровня с гарантированным проездом.
-- Чистая логика без Instance — общая для Track (сервер и витрина лобби) и расчётной проверки.
--
-- Правило: в каждом ряду есть «безопасная полоса», которую препятствия не занимают. Между двумя
-- соседними непустыми рядами (в том числе через стык кусков и через участки без препятствий)
-- безопасная полоса смещается не больше чем на maxShift(gap, v) полос, где v = Config.maxSpeed
-- уровня, gap — путь между рядами, а смена n полос с места вместе с реакцией успевает:
--   SAFE_LINE_REACTION + SAFE_LINE_MARGIN · shiftTime(n, v) ≤ gap / v.
-- Остальные занятые полосы выбираются случайно среди прочих, число занятых — как раньше.
-- Раскладка считается один раз на уровень своим Random (seed от уровня) → детерминирована и не
-- зависит от порядка стриминга кусков.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local SafeLine = {}

export type Row = { z: number, blocked: { number }, safe: number }

-- Время смены n полос с места: боковая скорость догоняет руль S = steerSpeed(v) с инерцией
-- k = STEER_RESPONSE (как в SledController): x(t) = S·(t − (1 − e^(−kt))/k).
function SafeLine.shiftTime(n: number, v: number): number
	if n <= 0 then
		return 0
	end
	local d = n * Config.TRACK_WIDTH / Config.LANES
	local S, k = Config.steerSpeed(v), math.max(0.1, Config.STEER_RESPONSE)
	local lo, hi = 0, 10
	for _ = 1, 40 do
		local t = (lo + hi) / 2
		if S * (t - (1 - math.exp(-k * t)) / k) < d then
			lo = t
		else
			hi = t
		end
	end
	return hi
end

-- Сколько полос можно сменить между рядами на расстоянии gap при скорости v
function SafeLine.maxShift(gap: number, v: number): number
	local avail = gap / math.max(1, v)
	local n = 0
	while n < Config.SAFE_LINE_MAX_SHIFT and n < Config.LANES - 1 do
		if Config.SAFE_LINE_REACTION + Config.SAFE_LINE_MARGIN * SafeLine.shiftTime(n + 1, v) > avail then
			break
		end
		n += 1
	end
	return n
end

-- segs — профиль уровня (kind, length, angle, hStart). Ответ: rows[i] для куска с индексом i
-- (0-based, как в Track:buildSegment) — список рядов по порядку.
function SafeLine.plan(segs: { any }, level: number): { [number]: { Row } }
	local rng = Random.new(level * 15485863 + 101)
	local lanes = Config.LANES
	local v = Config.maxSpeed(level)
	local safe = rng:NextInteger(math.max(1, lanes // 2), math.min(lanes, lanes // 2 + 1))
	local lastAt = -math.huge -- путь вдоль трассы до последнего непустого ряда
	local along = 0
	local out = {}
	for j, seg in segs do
		if seg.kind == "gentle" or seg.kind == "steep" then
			local i = j - 1
			local maxBlocked = math.clamp(1 + (level - 1) // 3 + i // 16, 1, 3)
			maxBlocked = math.min(maxBlocked, lanes - 2) -- в ряду свободно ≥ 2
			local prev = segs[j - 1]
			local safeUntil = if prev and prev.kind == "landing" then 60 else 0
			local rows = {}
			for row = 1, Config.OBSTACLE_ROWS do
				local z = seg.length * (row - 0.5) / Config.OBSTACLE_ROWS
				local h = seg.hStart + z * math.cos(math.rad(seg.angle))
				local count = if h < Config.SAFE_START or z < safeUntil then 0 else rng:NextInteger(0, maxBlocked)
				local blocked = {}
				if count > 0 then
					local n = SafeLine.maxShift(along + z - lastAt, v)
					local lo, hi = math.max(1, safe - n), math.min(lanes, safe + n)
					safe = rng:NextInteger(lo, hi)
					lastAt = along + z
					local free = {}
					for lane = 1, lanes do
						if lane ~= safe then
							table.insert(free, lane)
						end
					end
					for _ = 1, count do
						table.insert(blocked, table.remove(free, rng:NextInteger(1, #free)))
					end
				end
				table.insert(rows, { z = z, blocked = blocked, safe = safe })
			end
			out[i] = rows
		end
		along += seg.length
	end
	return out
end

return SafeLine
