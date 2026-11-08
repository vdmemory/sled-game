-- Набор заданий дня для игрока (#32): только выполнимые для него задания.
-- Чистые функции без сервисов (сервер — server/Rewards; проверка — scripts/stand/daily_tasks.luau).
--
-- 1. Базовый набор дня — как раньше: Config.TASKS_PER_DAY заданий из Config.TASK_POOL, детерминированно
--    по номеру дня (у всех игроков одинаковый).
-- 2. Слот, невыполнимый для игрока (Config.taskAvailable: needWorld/needLevel/needRare/needSpeed/need),
--    сначала пробует ступени цели ниже, затем заменяется детерминированно (rng от дня и номера слота)
--    другим выполнимым заданием из пула. Номер слота сохраняется (Daily.claimed хранится по индексу).
-- 3. Набор фиксируется в сейве (Daily.set) в начале дня: рост игрока в течение дня его не меняет.
--    При входе набор проверяется заново (revalidate): невыполнимые и ещё не полученные слоты заменяются.

local Config = require(script.Parent.Config)

local DailyTasks = {}

export type Entry = { id: string, target: number }

local function poolById(id: string)
	for _, t in Config.TASK_POOL do
		if t.id == id then
			return t
		end
	end
	return nil
end
DailyTasks.poolById = poolById

-- Три ступени цели: targets[1], середина, targets[2]
local function tierTarget(t, k: number): number
	return t.targets[1] + k * math.floor((t.targets[2] - t.targets[1]) / 2)
end

-- Цель ступени k или ниже, выполнимая для игрока (nil — ни одна)
local function fitTarget(t, d, k: number): number?
	for kk = k, 0, -1 do
		local target = tierTarget(t, kk)
		if Config.taskAvailable(t, d, target) then
			return target
		end
	end
	return nil
end

-- Базовый набор дня (одинаковый у всех) — тот же выбор, что был до #32
function DailyTasks.baseSet(day: number): { Entry }
	local rng = Random.new(day * 7349 + 11)
	local pool = table.clone(Config.TASK_POOL)
	local out = {}
	for _ = 1, math.min(Config.TASKS_PER_DAY, #pool) do
		local t = table.remove(pool, rng:NextInteger(1, #pool))
		table.insert(out, { id = t.id, target = tierTarget(t, rng:NextInteger(0, 2)) })
	end
	return out
end

-- Замена для слота i: выполнимое задание не из used (детерминированно по дню и слоту)
local function replacement(day: number, i: number, d, used: { [string]: boolean }): Entry?
	local rng = Random.new(day * 7349 + 11 + i * 1009)
	local pool = {}
	for _, t in Config.TASK_POOL do
		if not used[t.id] then
			table.insert(pool, t)
		end
	end
	while #pool > 0 do
		local t = table.remove(pool, rng:NextInteger(1, #pool))
		local target = fitTarget(t, d, rng:NextInteger(0, 2))
		if target then
			return { id = t.id, target = target }
		end
	end
	return nil
end

-- Слот выполним? Если нет — пробует ступень ниже того же задания (цель только уменьшается).
local function fixEntry(e: Entry, d): Entry?
	local t = poolById(e.id)
	if not t then
		return nil
	end
	if Config.taskAvailable(t, d, e.target) then
		return e
	end
	for k = 2, 0, -1 do
		local target = tierTarget(t, k)
		if target < e.target and Config.taskAvailable(t, d, target) then
			return { id = e.id, target = target }
		end
	end
	return nil
end

-- Проверить набор (на месте): невыполнимые слоты, кроме keep(i) == true (уже получены), заменяются.
-- Возвращает список номеров заменённых слотов.
function DailyTasks.revalidate(set: { Entry }, day: number, d, keep: ((number) -> boolean)?): { number }
	local used = {}
	for _, e in set do
		used[e.id] = true
	end
	local changed = {}
	for i, e in set do
		if keep and keep(i) then
			continue
		end
		local fixed = fixEntry(e, d)
		if fixed then
			if fixed.target ~= e.target then
				set[i] = fixed
				table.insert(changed, i)
			end
			continue
		end
		local r = replacement(day, i, d, used)
		if r then
			used[e.id] = nil
			used[r.id] = true
			set[i] = r
			table.insert(changed, i)
		end
	end
	return changed
end

-- Набор дня для игрока: базовый + замены невыполнимого
function DailyTasks.forPlayer(day: number, d): { Entry }
	local set = DailyTasks.baseSet(day)
	DailyTasks.revalidate(set, day, d)
	return set
end

-- Полное описание задания для клиента/прогресса (nil — задания больше нет в пуле)
function DailyTasks.describe(e: Entry)
	local t = poolById(e.id)
	if not t then
		return nil
	end
	return { id = t.id, text = Config.taskText(t, e.target), target = e.target, gems = t.gems, max = t.max, icon = t.icon }
end

return DailyTasks
