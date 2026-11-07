-- Античит заезда: санки считает клиент (network ownership после Launch), сервер проверяет,
-- что сообщённое правдоподобно. Пороги и их расчёт — Config, раздел «АНТИЧИТ».
--
--   AntiCheat.start(run, player, d, power)  — на Launch (внутри Tuning.forPlayer): огибающая скорости
--   AntiCheat.tick(run, player, pos, dt, h) — в Heartbeat (внутри Tuning.forPlayer): засчитывает
--       путь не быстрее предела, копит серверный полёт; → nil | "flag" | "kill"
--   AntiCheat.air / trickAir                — сколько секунд полёта засчитать по серверу
--   AntiCheat.near                          — бонус/препятствие рядом с серверной позицией саней
--   AntiCheat.onTrick / onBoost / onFuel    — события, поднимающие огибающую (честный разгон)
--   AntiCheat.flag(run, player, why)        — мягкое нарушение; → "flag" | "kill" (≥ AC_FLAG_LIMIT)
--
-- Мягкие нарушения обрезают начисление и копят run.flags; «kill» — Main заканчивает заезд
-- как "cheat" (без наград). Состояние — в run.ac, живёт и умирает вместе с заездом.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local AntiCheat = {}

local SIN_STEEP = math.sin(math.rad(Config.STEEP_ANGLE[2])) -- самый крутой склон трассы

-- Тяга ракеты + гравитация вдоль самого крутого склона: сколько studs/с² может добавить ракета
local function rocketAcc(): number
	return Config.ROCKET_THRUST + Config.GRAVITY_ALONG * SIN_STEEP
end

function AntiCheat.start(run: any, player: Player, d: any, power: number)
	local sled: VehicleSeat = run.sled
	local bonus = sled:GetAttribute("SledBonus") or 0
	local launch = Config.launchSpeed(d.LaunchLevel or 0) * math.clamp(power, 0, 1)
	local cap = Config.maxSpeed(d.SledLevel or 0) * (1 + bonus)
	local rocketTerminal = math.sqrt(rocketAcc() / math.max(Config.DRAG, 1e-6))
	local floor = math.max(launch, cap, rocketTerminal)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { run.track.folder }
	params.RespectCanCollide = true -- монеты и препятствия (CanCollide = false) луч не видит
	run.flags = 0
	run.ac = {
		floor = floor,
		env = floor,
		fuel = Config.rocketFuel(d.RocketLevel or 0), -- секунд ракеты, которые ещё можно сжечь в воздухе
		fuelMax = Config.rocketFuel(d.RocketLevel or 0),
		lastPos = sled.Position,
		lastMove = os.clock(),
		airNow = 0, -- текущий непрерывный полёт по серверу, с
		airBank = 0, -- полёт с прошлого засчитанного Air
		trickBank = 0, -- полёт с прошлого засчитанного Trick
		airUsed = 0, -- всего засчитано по Air
		airFlagged = 0, -- сколько раз по AC_MAX_AIR уже флажили этот полёт
		lastFlag = {} :: { [string]: number },
		smashed = {} :: { [Instance]: boolean },
		ray = params,
	}
end

-- Текущий предел скорости, studs/с
local function limit(ac: any): number
	return ac.env * Config.AC_SPEED_MULT + Config.AC_SPEED_ADD
end

function AntiCheat.flag(run: any, player: Player, why: string): string
	run.flags = (run.flags or 0) + 1
	warn(string.format("[AntiCheat] %s (%d): %s, флаг %d/%d", player.Name, player.UserId, why, run.flags, Config.AC_FLAG_LIMIT))
	return if run.flags >= Config.AC_FLAG_LIMIT then "kill" else "flag"
end

-- Флаг по позиции не чаще AC_FLAG_COOLDOWN на вид нарушения (одно залипание ≠ шесть флагов)
local function flagOnce(run: any, player: Player, kind: string, why: string): string?
	local ac = run.ac
	local now = os.clock()
	if now - (ac.lastFlag[kind] or -math.huge) < Config.AC_FLAG_COOLDOWN then
		return nil
	end
	ac.lastFlag[kind] = now
	return AntiCheat.flag(run, player, why)
end

-- Худший из двух вердиктов
local function worst(a: string?, b: string?): string?
	if a == "kill" or b == "kill" then
		return "kill"
	end
	return a or b
end

function AntiCheat.tick(run: any, player: Player, pos: Vector3, dt: number, h: number): string?
	local ac = run.ac
	if not ac or not run.launched then
		run.distance = math.max(run.distance, h) -- до выстрела санки заякорены и принадлежат серверу
		return nil
	end
	local now = os.clock()
	local verdict: string? = nil

	-- 1. Полёт по серверной позиции: луч вниз до геометрии своей трассы
	local airborne = not run.crashed
		and workspace:Raycast(pos, Vector3.new(0, -Config.AC_AIR_HEIGHT, 0), ac.ray) == nil
	if airborne then
		if ac.airNow == 0 and ac.fuel > 0 then
			ac.env += rocketAcc() * math.min(Config.AC_AIR_GRACE, ac.fuel) -- взлёт ниже порога
		end
		ac.airNow += dt
		ac.airBank += dt
		ac.trickBank += dt
		if ac.fuel > 0 then
			local burn = math.min(dt, ac.fuel)
			ac.fuel -= burn
			ac.env += rocketAcc() * burn -- в воздухе ракета разгоняет без сопротивления
		end
		if not run.finishedAt and ac.airNow > Config.AC_MAX_AIR * (ac.airFlagged + 1) then
			ac.airFlagged += 1
			verdict = worst(verdict, AntiCheat.flag(run, player, string.format("в воздухе %.1f с", ac.airNow)))
		end
	else
		ac.airNow = 0
		ac.airFlagged = 0
		if ac.env > ac.floor then
			-- dv/dt = −k·v² точно: v / (1 + k·v·t) (явный шаг на больших скоростях проскакивал бы пол)
			local k = Config.AC_DECAY * Config.DRAG
			ac.env = math.max(ac.floor, math.min(ac.env, ac.env / (1 + k * ac.env * dt) + rocketAcc() * dt))
		end
	end

	-- 2. Позиция «заморожена» (лаг репликации) — ждём, допуск копится по времени
	local moved = pos - ac.lastPos
	if moved.Magnitude < 0.01 then
		return verdict
	end
	local span = math.min(now - ac.lastMove, Config.AC_DT_MAX)
	ac.lastPos = pos
	ac.lastMove = now
	local lim = limit(ac)

	-- 3. Телепорт: сдвиг по горизонтали за тик сильно больше предела — заезд не засчитан
	local flat = Vector3.new(moved.X, 0, moved.Z).Magnitude
	if flat > Config.AC_TELEPORT_STUDS + lim * span * Config.AC_TELEPORT_MULT then
		warn(string.format("[AntiCheat] %s (%d): телепорт %.0f studs за %.2f с (предел %.0f studs/с)", player.Name, player.UserId, flat, span, lim))
		return "kill"
	end

	-- 4. Путь вдоль трассы: засчитываем не быстрее предела; отставание > AC_LAG_SEC — флаг
	if h > run.distance then
		run.distance = math.min(h, run.distance + lim * span)
	end
	if h - run.distance > lim * Config.AC_LAG_SEC then
		verdict = worst(verdict, flagOnce(run, player, "dist", string.format("путь %.0f впереди засчитанного (предел %.0f studs/с)", h - run.distance, lim)))
	end

	-- 5. Скорость, которую сообщают сами санки (по горизонтали)
	local v = run.sled.AssemblyLinearVelocity
	local vFlat = Vector3.new(v.X, 0, v.Z).Magnitude
	if vFlat > lim * Config.AC_TELEPORT_MULT then
		verdict = worst(verdict, flagOnce(run, player, "speed", string.format("скорость %.0f > %.0f", vFlat, lim * Config.AC_TELEPORT_MULT)))
	end
	return verdict
end

-- Air: (сколько секунд засчитать — 0, если ничего; видел ли сервер полёт вообще). Не больше полёта
-- по серверу с прошлого Air + запас и не больше времени с выстрела в сумме.
function AntiCheat.air(run: any, seconds: number): (number, boolean)
	local ac = run.ac
	if not ac then
		return 0, true
	end
	local server = ac.airBank
	ac.airBank = 0
	if server <= 0 then
		return 0, false
	end
	local sinceLaunch = os.clock() - (run.launchTime or os.clock())
	local sec = math.min(seconds, server + Config.AC_AIR_GRACE, math.max(0, sinceLaunch - ac.airUsed))
	if sec < Config.AIR_MIN_TIME then
		return 0, true
	end
	ac.airUsed += sec
	return sec, true
end

-- Trick: время полёта для проверки оборотов = min(клиент, полёт по серверу с прошлого Trick + запас);
-- nil — сервер не видел полёта (трюки на земле)
function AntiCheat.trickAir(run: any, airTime: number): number?
	local ac = run.ac
	if not ac or ac.trickBank <= 0 then
		return nil
	end
	local air = math.min(airTime, ac.trickBank + Config.AC_AIR_GRACE)
	ac.trickBank = 0
	return air
end

-- Предмет рядом с серверной позицией саней (с поправкой на отставание репликации)
function AntiCheat.near(run: any, at: Vector3): boolean
	local sled: VehicleSeat = run.sled
	local speed = sled.AssemblyLinearVelocity.Magnitude
	if run.ac then
		speed = math.min(speed, limit(run.ac)) -- скорость саней сообщает клиент — не даём раздуть радиус
	end
	return (at - sled.Position).Magnitude <= Config.AC_NEAR_RADIUS + speed * Config.AC_NEAR_LAG
end

-- Препятствие с атрибутом Breakable своей трассы, ещё не разбитое в этом заезде
function AntiCheat.canSmash(run: any, model: any): boolean
	local ac = run.ac
	if not ac or typeof(model) ~= "Instance" or not model:IsA("Model") or ac.smashed[model] then
		return false
	end
	if model:GetAttribute("Breakable") ~= true or not model:IsDescendantOf(run.track.folder) then
		return false
	end
	if not AntiCheat.near(run, model:GetPivot().Position) then
		return false
	end
	ac.smashed[model] = true
	return true
end

-- Честный разгон: буст трюков (× скорости), ускоритель (+BOOST_ADD), канистра (топливо заново)
function AntiCheat.onTrick(run: any, boost: number)
	if run.ac and boost > 1 then
		run.ac.env *= boost
	end
end
function AntiCheat.onBoost(run: any)
	if run.ac then
		run.ac.env += Config.BOOST_ADD
	end
end
function AntiCheat.onFuel(run: any)
	if run.ac then
		run.ac.fuel = run.ac.fuelMax
	end
end

return AntiCheat
