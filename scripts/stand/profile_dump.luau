--!nolint
-- Дамп профиля уровней (#75) для scripts/relief_check.py: на уровень — JSON-строка {level, L, segs:[{k kind, a уклон°,
-- l длина, h hStart, hl hLen, y высота начала, t тоннель, c гребень}]}. Диапазон — глобалы ARGS_FROM/ARGS_TO.
--   python3 scripts/stand/run.py scripts/stand/profile_dump.luau
local RS = game:GetService("ReplicatedStorage")
RS.FindFirstChild = function(self, n) return rawget(self, n) end
Config = require(SHARED.Config)
local Profile = require(SHARED.Track.Profile)
local out = {}
for level = tonumber(ARGS_FROM) or 1, tonumber(ARGS_TO) or 45 do
	local segs, L = Profile.build(CFrame.new(0, 0, 0), level)
	local rows = {}
	for _, s in segs do
		table.insert(rows, string.format('{"k":"%s","a":%.3f,"l":%.2f,"h":%.2f,"hl":%.2f,"y":%.2f,"t":%s,"c":%s}',
			s.kind, s.angle, s.length, s.hStart, s.hLen, s.cf.Position.Y, if s.tunnel then '"' .. s.tunnel .. '"' else "null", if s.crest then tostring(s.crest) else "null"))
	end
	print(string.format('{"level":%d,"L":%d,"segs":[%s]}', level, L, table.concat(rows, ",")))
end
