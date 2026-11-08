--!nolint
-- Отпечаток транспорта (SledModels): все 9 моделей (обычная и «крашеная» редкость), обвес по
-- тирам 0–10 × ракеты 0–6, ракеты 0–6 отдельно, рогатка 0–10. Обход дерева инстансов в порядке
-- детей, все свойства и атрибуты (числа с точностью 1e-4) → хэш на группу.
-- STAND_MESHES — шаблоны MeshTemplates есть на все имена MeshSpecs (как после загрузки мешей).

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
local PARTCLS = { Part = true, MeshPart = true, WedgePart = true }
local function walk(inst, depth)
	local p = rawget(inst, "_p")
	local line = depth .. "|" .. sortedKV(p, SKIP) .. "|" .. sortedKV(rawget(inst, "_a"))
	mix(line)
	count += 1
	if PARTCLS[p.ClassName] then
		parts += 1
	end
	if lines then
		table.insert(lines, line)
	end
	for _, c in rawget(inst, "_c") do
		walk(c, depth + 1)
	end
end
local tot1, tot2 = 0, 0
local function group(name, fn)
	h1, h2, count, parts = 0, 0, 0, 0
	local root = Instance.new("Model")
	local extra = fn(root)
	if extra ~= nil then
		mix(ser(extra))
	end
	-- дерево без корня: инстансов = всё, что построено
	for _, c in rawget(root, "_c") do
		walk(c, 0)
	end
	print(string.format("%-28s инстансов %5d частей %4d хэш %010d-%010d", name, count, parts, h1, h2))
	if lines then
		for _, l in lines do
			print("D " .. l)
		end
		table.clear(lines)
	end
	tot1 = (tot1 * 7 + h1) % 4294967291
	tot2 = (tot2 * 11 + h2) % 2147483629
	return count, parts
end

------------------------------------------------------------------ сценарии
local BASE = CFrame.new(10, 5, -20) * CFrame.Angles(0.1, 0.7, -0.05)
local GOLD = Config.RARITIES[2]
local perf = {}
for _, s in Config.SLEDS do
	for _, painted in { false, true } do
		group(s.id .. (if painted then " gold" else "") .. " build", function(root)
			local look = if painted
				then { main = GOLD.color, accent = Color3.new(1, 1, 1):Lerp(GOLD.color, 0.35), material = GOLD.material, glow = false, shine = GOLD.shine }
				else { main = s.main, accent = s.accent }
			return SledModels.build(root, BASE, s.id, look, nil, painted)
		end)
	end
	-- как в заезде: приварка к сиденью, тир 0 и 10
	for _, tier in { 0, 10 } do
		local n, np = group(s.id .. " ride t" .. tier, function(root)
			local seat = Instance.new("VehicleSeat")
			seat.Parent = root
			SledModels.build(seat, BASE, s.id, { main = s.main, accent = s.accent }, seat, false)
			return SledModels.extras(seat, BASE, s.id, tier, if tier == 0 then 0 else 6, s.accent, seat)
		end)
		perf[s.id .. tier] = { n, np }
	end
	for tier = 0, 10 do
		for rt = 0, 6 do
			group(s.id .. " extras s" .. tier .. " r" .. rt, function(root)
				return SledModels.extras(root, BASE, s.id, tier, rt, s.accent, nil)
			end)
		end
	end
end
for t = 0, 6 do
	group("rocket " .. t, function(root)
		return SledModels.rocket(root, BASE, t)
	end)
end
for t = 0, 10 do
	group("slingshot " .. t, function(root)
		return SledModels.slingshot(root, BASE, t)
	end)
end
print("--- инстансов на сани в заезде (модель + обвес + ракеты; инстансы / части)")
for _, s in Config.SLEDS do
	local a, b = perf[s.id .. 0], perf[s.id .. 10]
	print(string.format("%-11s тир 0: %4d / %3d   тир 10 + ракета 6: %4d / %3d", s.id, a[1], a[2], b[1], b[2]))
end
print(string.format("ИТОГО хэш %010d-%010d", tot1, tot2))
