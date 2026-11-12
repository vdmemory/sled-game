-- Задание недели (#56): какая цель и какой эксклюзивный след на неделе ISO, текст цели.
-- Чистые функции без сервисов (сервер — server/Rewards; проверка — scripts/stand/weekly_quest.luau).
-- Неделя и её ключ — shared/Week (тот же ключ W<год>-<нед>, что у досок недели LB_W…).

local Config = require(script.Parent.Config)
local Week = require(script.Parent.Week)

local WeeklyQuest = {}

local WEEK = 7 * 86400

export type Entry = { key: string, id: string, target: number, trail: string }

local function poolById(id: string)
	for _, q in Config.WEEKLY_QUEST.POOL do
		if q.id == id then
			return q
		end
	end
	return nil
end
WeeklyQuest.poolById = poolById

-- Номер недели от 1970 (детерминированная ротация, одинаковая у всех игроков и серверов)
function WeeklyQuest.index(t: number): number
	return Week.start(t) // WEEK
end

-- Цель и след недели, в которую попадает t
function WeeklyQuest.forWeek(t: number): Entry
	local n = WeeklyQuest.index(t)
	local pool, trails = Config.WEEKLY_QUEST.POOL, Config.WEEKLY_QUEST.TRAILS
	local q = pool[n % #pool + 1]
	return { key = Week.key(t), id = q.id, target = q.target, trail = trails[n % #trails + 1] }
end

-- Текст цели: «Сделай 60 заездов»
function WeeklyQuest.text(id: string, target: number): string
	local q = poolById(id)
	if not q then
		return "—"
	end
	return Config.taskText(q, target)
end

-- Сколько этапов Config.WEEKLY_QUEST.STEPS пройдено при прогрессе p из target (0..#STEPS)
function WeeklyQuest.stepOf(p: number, target: number): number
	local n = 0
	for i, pct in Config.WEEKLY_QUEST.STEPS do
		if p * 100 >= pct * target then
			n = i
		end
	end
	return n
end

return WeeklyQuest
