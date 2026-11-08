--!nolint
-- Проверка #32: задания дня для новичка (уровень 1, мир 1, Сани 0, только Ватрушка обычная) —
-- 60 дней подряд все задания набора выполнимы (Config.taskAvailable); у игрока мира 2 с Gold —
-- задания farm/rareRuns могут выпадать; набор детерминирован; revalidate не трогает полученные слоты.
--   python3 scripts/stand/run.py scripts/stand/daily_tasks.luau
-- RNG шимов не совпадает с Roblox Random — проверяется алгоритм, а не конкретные наборы дней.

local Config = require(SHARED.Config)
local DailyTasks = require(SHARED.DailyTasks)

local newbie = { Level = 1, SledLevel = 0, SledRarity = 1, OwnedSleds = { ["tube:1"] = true } }
local vet = { Level = 7, SledLevel = 12, SledRarity = 2, OwnedSleds = { ["tube:1"] = true, ["tube:2"] = true } }

local fails, replaced, seen = 0, 0, {}
local DAY0 = 20400
for day = DAY0, DAY0 + 59 do
	local base = DailyTasks.baseSet(day)
	local set = DailyTasks.forPlayer(day, newbie)
	assert(#set == Config.TASKS_PER_DAY, "размер набора")
	local ids = {}
	for i, e in set do
		local t = DailyTasks.poolById(e.id)
		if not Config.taskAvailable(t, newbie, e.target) then
			fails += 1
			print("НЕВЫПОЛНИМО", day, i, e.id, e.target)
		end
		assert(not ids[e.id], "повтор задания в наборе")
		ids[e.id] = true
		if e.id ~= base[i].id or e.target ~= base[i].target then
			replaced += 1
		end
	end
	-- детерминизм
	local again = DailyTasks.forPlayer(day, newbie)
	for i, e in set do
		assert(again[i].id == e.id and again[i].target == e.target, "набор не детерминирован")
	end
	for _, e in DailyTasks.forPlayer(day, vet) do
		seen[e.id] = true
	end
end
-- revalidate: полученный слот (keep) не меняется, даже если невыполним
local set = { { id = "farm", target = 2 }, { id = "speed", target = 160 }, { id = "runs", target = 5 } }
local changed = DailyTasks.revalidate(set, DAY0, newbie, function(i) return i == 1 end)
assert(set[1].id == "farm", "полученный слот заменён")
assert(set[2].id == "speed" and set[2].target == 100, "speed 160 → 100 для новичка")
assert(set[3].id == "runs" and set[3].target == 5, "выполнимый слот изменён")
assert(#changed == 1, "лишние замены")
local set2 = { { id = "rareRuns", target = 3 } }
DailyTasks.revalidate(set2, DAY0, newbie)
assert(set2[1].id ~= "rareRuns", "rareRuns без Gold не заменён")

print(string.format("60 дней, новичок: невыполнимых %d, слотов заменено/понижено %d; у ветерана встречались farm=%s rareRuns=%s",
	fails, replaced, tostring(seen.farm == true), tostring(seen.rareRuns == true)))
if fails > 0 then
	error("есть невыполнимые задания")
end
print("daily_tasks: OK")
