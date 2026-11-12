--!nolint
-- Проверка #56: задание недели — ротация по неделям ISO (ключ как у досок недели), детерминизм,
-- все цели и следы существуют, следы недели эксклюзивные, этапы 25/50/75 %.
--   python3 scripts/stand/run.py scripts/stand/weekly_quest.luau

local Config = require(SHARED.Config)
local Week = require(SHARED.Week)
local WeeklyQuest = require(SHARED.WeeklyQuest)

local WEEK = 7 * 86400
local t0 = os.time({ year = 2026, month = 11, day = 9, hour = 0 }) -- пн, W2026-46 (ЛОКАЛЬНОЕ время шима не важно)
t0 = Week.start(t0 + 86400 * 2)
local seen, trails = {}, {}
local prev = nil
for k = 0, 23 do
	local t = t0 + k * WEEK
	local e = WeeklyQuest.forWeek(t)
	assert(e.key == Week.key(t), "ключ недели = Week.key")
	-- вся неделя (пн 00:00 … вс 23:59:59) — одна цель
	local last = WeeklyQuest.forWeek(t + WEEK - 1)
	assert(last.key == e.key and last.id == e.id and last.trail == e.trail, "цель меняется внутри недели")
	assert(WeeklyQuest.forWeek(t + WEEK).key ~= e.key, "сброс в понедельник")
	assert(WeeklyQuest.poolById(e.id), "цель из пула")
	local tr = Config.trail(e.trail)
	assert(tr.id == e.trail and tr.exclusive and tr.price == 0, "след недели — эксклюзивный из TRAILS: " .. e.trail)
	if prev then
		assert(prev.id ~= e.id, "цель повторяется две недели подряд")
	end
	prev = e
	seen[e.id] = true
	trails[e.trail] = true
	print(e.key, e.id, e.target, e.trail, WeeklyQuest.text(e.id, e.target))
end
for _, q in Config.WEEKLY_QUEST.POOL do
	assert(seen[q.id], "цель не выпала за 24 недели: " .. q.id)
end
for _, id in Config.WEEKLY_QUEST.TRAILS do
	assert(trails[id], "след не выпал: " .. id)
end
-- ключ ISO на стыке лет: 2026-12-31 (чт) → W2026-53, 2027-01-04 (пн) → W2027-01
assert(Week.key(os.time({ year = 2026, month = 12, day = 31, hour = 12 })) == "W2026-53", Week.key(os.time({ year = 2026, month = 12, day = 31, hour = 12 })))
assert(Week.key(os.time({ year = 2027, month = 1, day = 4, hour = 12 })) == "W2027-01", "W2027-01")
-- этапы
assert(WeeklyQuest.stepOf(0, 60) == 0 and WeeklyQuest.stepOf(14, 60) == 0 and WeeklyQuest.stepOf(15, 60) == 1)
assert(WeeklyQuest.stepOf(30, 60) == 2 and WeeklyQuest.stepOf(59, 60) == 3 and WeeklyQuest.stepOf(60, 60) == 3)
-- эксклюзивные следы не продаются за 0: цена 0 только у стартового и эксклюзивных
for _, t in Config.TRAILS do
	assert(t.price > 0 or t.id == "white" or t.exclusive, "бесплатный неэксклюзивный след " .. t.id)
end
print("weekly_quest: OK")
