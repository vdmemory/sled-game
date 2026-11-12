-- Трамплин-лестница (#43): ритм «прыжок-прыжок-ПРЫЖОК». По пологому склону STAIR_PITCH стоят 3–4
-- трамплина нарастающей высоты (STAIR_HEIGHT 2.5 → 5), обрыва нет — после каждого садимся на тот же
-- склон до следующего трамплина; после последнего (большого, как у кикера) — склон приземления.
--
--   вид сбоку:  разгон ⟋ · · · ⟋⟋ · · · ⟋⟋⟋ · · · · · ╲ склон приземления (stairLand)
--
-- Как устроено:
--   Profile  → Stairs.plan(level, rng): трамплины, длины кусков, дуги монет (баллистика Islands);
--              куски "stair" (трамплин в конце куска) × n → "stairLand".
--   Track    → Stairs.build: трамплин, флажки, монеты по дуге, x2 в вершине последней дуги.
--
-- Достижимость и монеты — как у островков (shared/Islands): трамплин задаёт скорость вылета в окне
-- [v, v · STAIR_SPREAD] (атрибуты LaunchMin/LaunchMax/Lift у Ramp, их читает SledController), v —
-- «типичная скорость уровня» Config.stairSpeed. Длина следующего куска — так, что при верхней скорости,
-- позднем отрыве и ракете весь полёт садимся до его трамплина − STAIR_END_MARGIN (не перелетаем
-- ступеньку). Монеты дугой — только там, где их ловят все крайние траектории окна (Islands.coinArc).
-- Препятствий, бонусов-кубов, безопасной линии и тоннелей/долин на этих кусках нет (Profile/SafeLine).
-- Скорость вылета ≤ STAIR_SPEED[2] · STAIR_SPREAD ниже предела античита (≥ maxSpeed(0) · AC_SPEED_MULT +
-- AC_SPEED_ADD), полёт ≤ 1.3 с ≪ AC_MAX_AIR — честный заезд флагов не получает.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Props = require(ReplicatedStorage.Shared.Props)
local Islands = require(ReplicatedStorage.Shared.Islands)

local deco = Props.deco
local W = Config.TRACK_WIDTH

local Stairs = {}

export type Step = {
	k: number,
	n: number,
	final: boolean,
	ramp: { number }, -- { длина, высота, подброс }
	len: number, -- длина куска (разгон/посадка + трамплин в конце)
	vmin: number,
	vmax: number,
	pitch: number,
	minLand: number, -- дальность при 0.97·v и раннем отрыве (x от конца куска)
	maxLand: number, -- при верхней скорости, позднем отрыве и ракете
	arc: { { number } }, -- монеты: { x, y } от верха пола в конце куска
	x2: { number }?, -- { x, y, высота датчика } — вершина последней дуги
}
export type Plan = { steps: { Step }, landPitch: number, landLen: number, total: number }

-- Монеты дугой: участок, где все крайние траектории окна проходят в окне подбора (Islands.coinArc,
-- частая выборка до средней посадки), и на нём count монет поровну, не чаще STAIR_COIN_STEP.
function Stairs.arc(vmin: number, vmax: number, pitch: number, mid: number, count: number, ramp: { number }): { { number } }
	local probe = Islands.coinArc(vmin, vmax, pitch, 0, mid * 0.9, Config.STAIR_COIN_PROBE, ramp)
	if #probe == 0 then
		return probe
	end
	local a, b = probe[1][1], probe[#probe][1]
	local n = math.max(1, math.min(count, math.floor((b - a) / Config.STAIR_COIN_STEP) + 1))
	if n == 1 then
		return { probe[math.max(1, math.ceil(#probe / 2))] }
	end
	return Islands.coinArc(vmin, vmax, pitch, a, b, n, ramp)
end

-- План лестницы. Чистая баллистика, без Instance. total — длина по склону (для проверки «влезает до
-- финиша»).
function Stairs.plan(level: number, rng: Random): Plan
	local vmin, vmax = Config.stairSpeed(level)
	local n = if level >= Config.STAIR_FOUR_LEVEL then rng:NextInteger(3, 4) else 3
	local pitch = Config.STAIR_PITCH
	local thrust = Config.ROCKET_THRUST
	local steps: { Step } = {}
	local total = 0
	local prevMax: number? = nil
	for k = 1, n do
		local f = (k - 1) / math.max(1, n - 1)
		local H = Config.STAIR_HEIGHT[1] + (Config.STAIR_HEIGHT[2] - Config.STAIR_HEIGHT[1]) * f
		local ramp = { H * Config.STAIR_RAMP_RATIO, H, Config.STAIR_LIFT[1] + (Config.STAIR_LIFT[2] - Config.STAIR_LIFT[1]) * f }
		local final = k == n
		local run = if prevMax == nil
			then Config.STAIR_RUNUP
			else math.max(rng:NextNumber(Config.STAIR_GAP[1], Config.STAIR_GAP[2]), prevMax + Config.STAIR_END_MARGIN)
		local slope = if final then Config.STAIR_LAND_PITCH else pitch
		local lo = Islands.landX(vmin * Config.ISLE_SLACK, pitch, true, 0, 0, 0, slope, ramp) or 0
		local hi = Islands.landX(vmax, pitch, false, thrust, 0, 0, slope, ramp) or lo
		local mid = Islands.landX((vmin + vmax) / 2, pitch, false, 0, 0, 0, slope, ramp) or lo
		local count = if final then Config.STAIR_COINS_TOP else Config.STAIR_COINS
		local arc = Stairs.arc(vmin, vmax, pitch, mid, count, ramp)
		local step: Step = {
			k = k,
			n = n,
			final = final,
			ramp = ramp,
			len = run + ramp[1],
			vmin = vmin,
			vmax = vmax,
			pitch = pitch,
			minLand = lo,
			maxLand = hi,
			arc = arc,
		}
		if final and #arc > 0 then
			-- x2 — вместо монеты, ближайшей к вершине средней траектории (там все траектории окна
			-- проходят в полосе ≤ 9 studs); датчик по высоте накрывает полосу с запасом
			local x0, _, vx, vy = Islands.takeoff((vmin + vmax) / 2, pitch, false, ramp)
			local ax = x0 + vx * vy / workspace.Gravity
			local best = 1
			for j, p in arc do
				if math.abs(p[1] - ax) < math.abs(arc[best][1] - ax) then
					best = j
				end
			end
			local p = table.remove(arc, best)
			step.x2 = { p[1], p[2], Config.STAIR_X2_HIT }
		end
		table.insert(steps, step)
		total += step.len
		prevMax = hi
	end
	local landLen = math.max(Config.STAIR_LAND_LEN, (prevMax or 0) + Config.STAIR_LAND_MARGIN)
	total += landLen
	return { steps = steps, landPitch = Config.STAIR_LAND_PITCH, landLen = landLen, total = total }
end

-- Геометрия и предметы куска "stair": трамплин в конце (окно скорости), флажки у кромки, монеты по
-- дуге полёта, на последнем — x2 в вершине дуги в золотом кольце. kit — make* из Track/Items.
function Stairs.build(theme: number, seg, m: Instance, kit)
	local step: Step = seg.stair
	local cf, len = seg.cf, seg.length
	local RL, RH = step.ramp[1], step.ramp[2]
	local ramp = Props.ramp(cf * CFrame.new(0, 0, -(len - RL / 2)), W, RL, RH, m)
	ramp:SetAttribute("LaunchMin", step.vmin)
	ramp:SetAttribute("LaunchMax", step.vmax)
	ramp:SetAttribute("Lift", step.ramp[3])
	-- флажки цвета мира по бокам кромки: их число = номер ступени (1, 2, 3…) — ритм читается издалека
	local accent = Islands.accent(theme)
	for j = 1, step.k do
		for _, side in { -1, 1 } do
			Islands.pennant(cf * CFrame.new(side * (W / 2 + 4 + (j - 1) * 3), 1.5, -(len - RL) - (j - 1) * 2), accent, 4 + step.k, m)
		end
	end
	-- монеты по дуге: кадр — верх пола в конце куска, без наклона, вперёд по трассе
	local endPos = cf:PointToWorldSpace(Vector3.new(0, 0, -len))
	local look = cf.LookVector
	local flat = CFrame.lookAt(endPos, endPos + Vector3.new(look.X, 0, look.Z))
	for _, p in step.arc do
		kit.coin(flat * CFrame.new(0, p[2], -p[1]), m)
	end
	if step.x2 then
		local at = flat * CFrame.new(0, step.x2[2], -step.x2[1])
		kit.x2(at, m, Vector3.new(9, step.x2[3], 6))
		-- золотое кольцо вокруг (декор): видно, куда лететь
		local r, cnt = 5.5, 16
		for j = 0, cnt - 1 do
			local a = j / cnt * math.pi * 2
			deco({ Size = Vector3.new(0.7, 2.3, 0.7), CFrame = at * CFrame.new(math.cos(a) * r, math.sin(a) * r, 0) * CFrame.Angles(0, 0, a), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 205, 60) }, m)
		end
	end
end

-- Где висит гем/кристалл, попавший на кусок лестницы: в середине дуги монет (ловится в прыжке)
function Stairs.bonusAt(seg, y: number): CFrame?
	local step: Step = seg.stair
	local p = step.arc[math.max(1, math.ceil(#step.arc / 2))]
	if not p then
		return nil
	end
	local endPos = seg.cf:PointToWorldSpace(Vector3.new(0, 0, -seg.length))
	local look = seg.cf.LookVector
	return CFrame.lookAt(endPos, endPos + Vector3.new(look.X, 0, look.Z)) * CFrame.new(0, p[2] + y - 3, -p[1])
end

return Stairs
