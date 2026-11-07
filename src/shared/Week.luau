-- Неделя ISO 8601 по UTC (#26): ключ "W2026-45", начало (пн 00:00 UTC) и момент сброса.
-- Чистые функции без сервисов — общий модуль (сервер: доски/титулы, клиент: таймер), гоняется в luau CLI.

local Week = {}

local DAY = 86400

-- Понедельник 00:00 UTC недели, в которую попадает t (1970-01-01 — четверг)
function Week.start(t: number): number
	local d = t // DAY
	local wd = (d + 3) % 7 -- 0 = понедельник
	return (d - wd) * DAY
end

-- Следующий сброс (понедельник 00:00 UTC)
function Week.reset(t: number): number
	return Week.start(t) + 7 * DAY
end

-- Ключ недели: ISO-год берётся по четвергу этой недели (29.12–03.01 могут относиться к соседнему году)
function Week.key(t: number): string
	local th = os.date("!*t", Week.start(t) + 3 * DAY) :: any
	return string.format("W%d-%02d", th.year, (th.yday - 1) // 7 + 1)
end

function Week.prevKey(t: number): string
	return Week.key(Week.start(t) - DAY)
end

return Week
