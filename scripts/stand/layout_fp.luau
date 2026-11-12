--!nolint
-- Отпечаток РАСКЛАДКИ трасс (#30/#36): как track_fp, но содержимое моделей «Obstacle» (вид препятствия,
-- маркеры класса, пятно-тень) пропускается; вместо него в хэш идут место вызова Props.obstacle (base) и
-- состояние Random куска после вызова — совпадение до/после доказывает: места препятствий, безопасная
-- линия, ускорители, монеты и весь декор не изменились, а rng препятствие расходует как раньше.
--   python3 scripts/stand/run.py scripts/stand/layout_fp.luau [--src <копия старого src/shared>]
-- Уровни 1–STAND_LEVELS (по умолчанию 35 = все 7 миров).
------------------------------------------------------------------ шаблоны мешей
local RS = game:GetService("ReplicatedStorage")
RS.FindFirstChild = function(self, n) return rawget(self, n) end
do
	local InstMT = getmetatable(workspace)
	InstMT.Clone = function(t)
		local c = Instance.new(rawget(t, "_p").ClassName)
		for k, v in rawget(t, "_p") do
			if k ~= "Parent" then rawget(c, "_p")[k] = v end
		end
		return c
	end
end
if STAND_MESHES then
	local folder = Instance.new("Folder")
	folder.Name = "MeshTemplates"
	folder.Parent = workspace
	for name in require(SHARED.MeshSpecs) do
		local mp = Instance.new("MeshPart")
		mp.Name = name
		mp.Parent = folder
	end
	rawset(RS, "MeshTemplates", folder)
end
Config = require(SHARED.Config)
local SledModels = require(SHARED.SledModels)

------------------------------------------------------------------ отпечаток
local h1, h2, count, parts = 0, 0, 0, 0
local lines = if STAND_DUMP then {} else nil
local function mix(s)
	for i = 1, #s do
		local c = string.byte(s, i)
		h1 = (h1 * 31 + c) % 4294967291
		h2 = (h2 * 131 + c + i) % 2147483629
	end
end
local function num(x)
	local s = string.format("%.4f", x)
	return if s == "-0.0000" then "0.0000" else s
end
local function ser(v)
	local t = type(v)
	if t == "number" then
		return num(v)
	elseif t == "string" or t == "boolean" or t == "nil" then
		return tostring(v)
	elseif t == "table" then
		if rawget(v, "X") ~= nil and rawget(v, "Z") ~= nil then
			return "V(" .. num(v.X) .. "," .. num(v.Y) .. "," .. num(v.Z) .. ")"
		elseif rawget(v, "p") ~= nil and rawget(v, "r") ~= nil then
			return "CF(" .. ser(v.p) .. ser(v.r) .. ser(v.u) .. ser(v.b) .. ")"
		elseif rawget(v, "R") ~= nil then
			return "C(" .. num(v.R) .. "," .. num(v.G) .. "," .. num(v.B) .. ")"
		elseif rawget(v, "_p") ~= nil then
			return "I:" .. tostring(rawget(v, "_p").Name)
		end
		return "tbl"
	end
	return t
end
local function sortedKV(tbl, skip)
	local keys = {}
	for k in tbl do
		if not skip or not skip[k] then
			table.insert(keys, tostring(k))
		end
	end
	table.sort(keys)
	local out = {}
	for _, k in keys do
		table.insert(out, k .. "=" .. ser(tbl[k]))
	end
	return table.concat(out, ";")
end
local SKIP = { Parent = true }
------------------------------------------------------------------ трассы: отпечаток кусков без арок рубежей
local Track = require(SHARED.Track)
local SKIPNAME = { Milestone = true, Obstacle = true }
local Props = require(SHARED.Props)
local origObstacle = Props.obstacle
local OBST = 0
Props.obstacle = function(theme, rng, base, parent, ...)
	local m = origObstacle(theme, rng, base, parent, ...)
	OBST += 1
	mix("obst" .. ser(base) .. tostring(rawget(rng, "s")))
	return m
end
local function walk2(inst, depth)
	local p = rawget(inst, "_p")
	if SKIPNAME[p.Name] then
		MILES = (MILES or 0) + 1
		return
	end
	local line = depth .. "|" .. sortedKV(p, SKIP) .. "|" .. sortedKV(rawget(inst, "_a"))
	mix(line)
	count += 1
	if lines then table.insert(lines, line) end
	for _, c in rawget(inst, "_c") do
		walk2(c, depth + 1)
	end
end
local LEVELS = tonumber(STAND_LEVELS) or 35
local T1, T2 = 0, 0
for level = 1, LEVELS do
	h1, h2, count = 0, 0, 0
	MILES = 0
	OBST = 0
	local tr = Track.new(0, level, 0)
	local seen = {}
	local h = 0
	while h <= tr.length + 400 do
		tr:ensureAround(h)
		for idx, m in tr.built do
			if not seen[idx] then
				seen[idx] = true
				mix("seg" .. idx)
				walk2(m, 0)
			end
		end
		h += 60
	end
	for i, seg in tr.segments do
		mix(i .. ser(seg.cf) .. num(seg.hStart) .. num(seg.hLen) .. tostring(seg.kind))
	end
	print(string.format("уровень %2d длина %5d инстансов %6d препятствий %4d хэш %010d-%010d", level, tr.length, count, OBST, h1, h2))
	T1 = (T1 * 7 + h1) % 4294967291
	T2 = (T2 * 11 + h2) % 2147483629
	tr:destroy()
end
print(string.format("ИТОГО хэш %010d-%010d", T1, T2))
