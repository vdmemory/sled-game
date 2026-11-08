--!nolint
-- Шимы Roblox-API для запуска shared/Track (+Props, SafeLine, Islands, Config) в luau CLI:
-- настоящая математика Vector3/CFrame, Instance-заглушки со счётом Part-ов, Terrain-заглушка.

------------------------------------------------------------------ Vector3
local V = {}
V.__index = V
local function v3(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V)
end
V.__add = function(a, b) return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V.__sub = function(a, b) return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V.__unm = function(a) return v3(-a.X, -a.Y, -a.Z) end
V.__mul = function(a, b)
	if type(a) == "number" then return v3(a * b.X, a * b.Y, a * b.Z) end
	if type(b) == "number" then return v3(a.X * b, a.Y * b, a.Z * b) end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V.__div = function(a, b)
	if type(b) == "number" then return v3(a.X / b, a.Y / b, a.Z / b) end
	return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V.__index = function(t, k)
	if k == "Magnitude" then return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z) end
	if k == "Unit" then
		local m = math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z)
		return if m > 0 then v3(t.X / m, t.Y / m, t.Z / m) else v3(0, 0, 0)
	end
	return V[k]
end
function V.Dot(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
function V.Cross(a, b) return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end
function V.Lerp(a, b, t) return a + (b - a) * t end
Vector3 = { new = v3, one = v3(1, 1, 1), zero = v3(0, 0, 0), yAxis = v3(0, 1, 0), xAxis = v3(1, 0, 0), zAxis = v3(0, 0, 1) }

------------------------------------------------------------------ CFrame (p + столбцы R, U, B; LookVector = −B)
local C = {}
local function cf(p, r, u, b)
	return setmetatable({ p = p, r = r, u = u, b = b }, C)
end
local function rotv(c, v) -- поворот вектора
	return c.r * v.X + c.u * v.Y + c.b * v.Z
end
C.__index = function(t, k)
	if k == "Position" then return t.p end
	if k == "LookVector" then return -t.b end
	if k == "RightVector" then return t.r end
	if k == "UpVector" then return t.u end
	if k == "X" then return t.p.X end
	if k == "Y" then return t.p.Y end
	if k == "Z" then return t.p.Z end
	return C[k]
end
C.__mul = function(a, b)
	if getmetatable(b) == V then
		return a.p + rotv(a, b)
	end
	return cf(a.p + rotv(a, b.p), rotv(a, b.r), rotv(a, b.u), rotv(a, b.b))
end
C.__add = function(a, v) return cf(a.p + v, a.r, a.u, a.b) end
C.__sub = function(a, v) return cf(a.p - v, a.r, a.u, a.b) end
function C.Inverse(a)
	-- транспонированная матрица
	local r = v3(a.r.X, a.u.X, a.b.X)
	local u = v3(a.r.Y, a.u.Y, a.b.Y)
	local b = v3(a.r.Z, a.u.Z, a.b.Z)
	local inv = cf(v3(0, 0, 0), r, u, b)
	inv.p = -(rotv(inv, a.p))
	return inv
end
function C.PointToWorldSpace(a, v) return a * v end
function C.PointToObjectSpace(a, v) return a:Inverse() * v end
function C.VectorToWorldSpace(a, v) return rotv(a, v) end
function C.VectorToObjectSpace(a, v) return rotv(a:Inverse(), v) end
function C.Lerp(a, b, t) return cf(a.p:Lerp(b.p, t), a.r, a.u, a.b) end
function C.ToWorldSpace(a, b) return a * b end
local I = cf(v3(0, 0, 0), v3(1, 0, 0), v3(0, 1, 0), v3(0, 0, 1))
local function angles(rx, ry, rz)
	local function Rx(t) local c, s = math.cos(t), math.sin(t); return cf(v3(0, 0, 0), v3(1, 0, 0), v3(0, c, s), v3(0, -s, c)) end
	local function Ry(t) local c, s = math.cos(t), math.sin(t); return cf(v3(0, 0, 0), v3(c, 0, -s), v3(0, 1, 0), v3(s, 0, c)) end
	local function Rz(t) local c, s = math.cos(t), math.sin(t); return cf(v3(0, 0, 0), v3(c, s, 0), v3(-s, c, 0), v3(0, 0, 1)) end
	return Rx(rx or 0) * Ry(ry or 0) * Rz(rz or 0)
end
CFrame = {
	new = function(x, y, z)
		if x == nil then return I end
		if type(x) == "table" then return cf(x, I.r, I.u, I.b) end
		return cf(v3(x, y, z), I.r, I.u, I.b)
	end,
	Angles = angles,
	fromEulerAnglesXYZ = angles,
	lookAt = function(at, target, up)
		up = up or v3(0, 1, 0)
		local look = (target - at).Unit
		local r = look:Cross(up).Unit
		if r.Magnitude < 1e-6 then r = v3(1, 0, 0) end
		local u = r:Cross(look)
		return cf(at, r, u, -look)
	end,
	fromAxisAngle = function(axis, a)
		axis = axis.Unit
		local function rot(v)
			return v * math.cos(a) + axis:Cross(v) * math.sin(a) + axis * (axis:Dot(v) * (1 - math.cos(a)))
		end
		return cf(v3(0, 0, 0), rot(v3(1, 0, 0)), rot(v3(0, 1, 0)), rot(v3(0, 0, 1)))
	end,
	identity = I,
}

------------------------------------------------------------------ прочие типы — заглушки
local function proxy(): any
	return setmetatable({}, {
		__index = function() return proxy() end,
		__call = function() return proxy() end,
	})
end
-- Color3: сравнение по значению (как в Roblox) и настоящий Lerp
local CM = {}
local function c3(r, g, b) return setmetatable({ R = r, G = g, B = b }, CM) end
CM.__index = { Lerp = function(a, b, t) return c3(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t) end }
CM.__eq = function(a, b) return math.abs(a.R - b.R) < 1e-6 and math.abs(a.G - b.G) < 1e-6 and math.abs(a.B - b.B) < 1e-6 end
Color3 = {
	fromRGB = function(r, g, b) return c3(r / 255, g / 255, b / 255) end,
	new = c3,
	fromHSV = function() return c3(1, 1, 1) end,
}
Enum = proxy()
UDim2 = proxy()
UDim = proxy()
NumberSequence = proxy()
NumberSequenceKeypoint = proxy()
ColorSequence = proxy()
ColorSequenceKeypoint = proxy()
NumberRange = proxy()
Vector2 = proxy()
PhysicalProperties = proxy()
Region3 = proxy()

------------------------------------------------------------------ Random (детерминированный, как в safeline)
Random = {}
Random.__index = Random
function Random.new(seed)
	local s = math.floor(math.abs(seed)) % 2147483647
	if s == 0 then s = 1 end
	return setmetatable({ s = s }, Random)
end
function Random:u()
	self.s = (self.s * 48271) % 2147483647
	return self.s / 2147483647
end
function Random:NextInteger(a, b)
	return a + math.min(b - a, math.floor(self:u() * (b - a + 1)))
end
function Random:NextNumber(a, b)
	local lo, hi = a or 0, b or 1
	return lo + (hi - lo) * self:u()
end

------------------------------------------------------------------ Instance
STATS = { parts = 0, byName = {}, all = {} }
local PARTS = { Part = true, WedgePart = true, VehicleSeat = true, CornerWedgePart = true, TrussPart = true, MeshPart = true }
local Inst = {}
Inst.__index = function(t, k)
	local m = rawget(Inst, k)
	if m then return m end
	local props = rawget(t, "_p")
	return props[k]
end
Inst.__newindex = function(t, k, v)
	local props = rawget(t, "_p")
	if k == "Parent" then
		local old = props.Parent
		if old then
			local ch = rawget(old, "_c")
			for i, c in ch do if c == t then table.remove(ch, i) break end end
		end
		props.Parent = v
		if v then table.insert(rawget(v, "_c"), t) end
		return
	end
	props[k] = v
end
function Inst.IsA(t, cls)
	local cn = rawget(t, "_p").ClassName
	if cls == "BasePart" then return PARTS[cn] == true end
	return cn == cls
end
function Inst.GetChildren(t) return table.clone(rawget(t, "_c")) end
function Inst.GetDescendants(t)
	local out = {}
	local function walk(x)
		for _, c in rawget(x, "_c") do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(t)
	return out
end
function Inst.FindFirstChildWhichIsA(t, cls)
	for _, c in rawget(t, "_c") do if c:IsA(cls) then return c end end
	return nil
end
function Inst.FindFirstChildOfClass(t, cls) return Inst.FindFirstChildWhichIsA(t, cls) end
function Inst.FindFirstChild(t, name)
	for _, c in rawget(t, "_c") do if c.Name == name then return c end end
	return nil
end
function Inst.SetAttribute(t, k, v) rawget(t, "_a")[k] = v end
function Inst.GetAttribute(t, k) return rawget(t, "_a")[k] end
function Inst.Destroy(t) t.Parent = nil; rawset(t, "_dead", true) end
function Inst.PivotTo(t, c) rawget(t, "_p").Pivot = c end
function Inst.GetPivot(t) return rawget(t, "_p").Pivot or CFrame.new() end
function Inst.Clone(t) return t end
Instance = {
	new = function(cls, parent)
		local t = setmetatable({ _p = { ClassName = cls, Name = cls }, _c = {}, _a = {} }, Inst)
		if PARTS[cls] then
			t._p.CanCollide = true
			t._p.CanQuery = true
			STATS.parts += 1
			table.insert(STATS.all, t)
		end
		if parent then t.Parent = parent end
		return t
	end,
}

------------------------------------------------------------------ сервисы
TERRAIN_CALLS = {}
local terrain = setmetatable({}, { __index = function(_, k)
	return function(_, ...)
		table.insert(TERRAIN_CALLS, { k, ... })
	end
end })
workspace = Instance.new("Workspace")
rawget(workspace, "_p").Gravity = 196.2
rawget(workspace, "_p").Terrain = terrain
function Inst.GetServerTimeNow() return 0 end
SHARED = {}
local services = {
	ReplicatedStorage = { Shared = SHARED },
	CollectionService = { AddTag = function() end, HasTag = function() return false end, GetTagged = function() return {} end },
	RunService = { IsServer = function() return true end, IsClient = function() return false end, IsStudio = function() return false end },
}
game = { GetService = function(_, name) return services[name] or proxy() end, CreatorId = 0 }
require = function(x) return x end
task = { spawn = function() end, delay = function() end, wait = function() end, defer = function() end }

------------------------------------------------------------------ сверка до/после: именованные Enum, теги, дерево модулей
local function enumOf(kind)
	return setmetatable({}, { __index = function(t, k)
		local v = "Enum." .. kind .. "." .. tostring(k)
		rawset(t, k, v)
		return v
	end })
end
Enum = setmetatable({}, { __index = function(t, k)
	local e = enumOf(k)
	rawset(t, k, e)
	return e
end })
local CS = game:GetService("CollectionService")
CS.AddTag = function(_, inst, tag)
	local a = rawget(inst, "_a")
	if a then
		a["__tag_" .. tag] = true
	end
end
CS.HasTag = function(_, inst, tag)
	local a = rawget(inst, "_a")
	return a ~= nil and a["__tag_" .. tag] == true
end
function mkNode(parent, name)
	local n = { Name = name, Parent = parent }
	parent[name] = n
	return n
end
local CFMT = getmetatable(CFrame.new())
CFrame.fromMatrix = function(pos, x, y, z)
	return setmetatable({ p = pos, r = x, u = y, b = z or x:Cross(y) }, CFMT)
end
local CACHE = {}
require = function(x)
	if type(x) == "table" and rawget(x, "__fn") then
		if CACHE[x] == nil then
			CACHE[x] = x.__fn(x)
		end
		return CACHE[x]
	end
	error("require: неизвестный модуль " .. tostring(x and x.Name))
end
