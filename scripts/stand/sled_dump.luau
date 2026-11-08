--!nolint
-- Выгрузка деталей транспорта для превью (scripts/preview_sleds.py): сцены «модель + обвес тира»,
-- ракеты; на каждую деталь строка D|сцена|класс|форма|меш|size|cframe|цвет|материал|прозрачность|спецмеш.
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

local function f(x) return string.format("%.4f", x) end
local function v(x) return f(x.X) .. "," .. f(x.Y) .. "," .. f(x.Z) end
local function dump(scene, root)
	for _, p in root:GetDescendants() do
		local cls = rawget(p, "_p").ClassName
		if cls == "Beam" then
			local function wp(a)
				return a.Parent.CFrame * a.Position
			end
			print(table.concat({ "B", scene, v(wp(p.Attachment0)), v(wp(p.Attachment1)), f(p.Width0), f(p.Width1) }, "|"))
		end
		if cls == "Part" or cls == "MeshPart" then
			local cf = p.CFrame
			local sm = ""
			for _, c in rawget(p, "_c") do
				if rawget(c, "_p").ClassName == "SpecialMesh" then
					sm = tostring(c.MeshType)
				end
			end
			local name = if cls == "MeshPart" then p.Name else ""
			print(table.concat({ "D", scene, cls, tostring(p.Shape or ""), name, v(p.Size),
				v(cf.Position) .. "," .. v(cf.RightVector) .. "," .. v(cf.UpVector) .. "," .. v(-cf.LookVector),
				f(p.Color.R) .. "," .. f(p.Color.G) .. "," .. f(p.Color.B), tostring(p.Material), f(p.Transparency or 0), sm }, "|"))
		end
	end
end

local RAR = Config.RARITIES
for _, s in Config.SLEDS do
	for _, tier in { 0, 1, 4, 10 } do
		local root = Instance.new("Model")
		local look = { main = s.main, accent = s.accent }
		SledModels.build(root, CFrame.new(), s.id, look, nil, false)
		SledModels.extras(root, CFrame.new(), s.id, tier, ({ [0] = 0, [1] = 1, [4] = 3, [10] = 6 })[tier], s.accent, nil)
		dump(s.id .. ":" .. tier, root)
	end
	-- Gold-редкость (перекраска мешей)
	local root = Instance.new("Model")
	local g = RAR[2]
	SledModels.build(root, CFrame.new(), s.id, { main = g.color, accent = Color3.new(1, 1, 1):Lerp(g.color, 0.35), material = g.material, shine = g.shine }, nil, true)
	dump(s.id .. ":gold", root)
end
for _, t in { 0, 3, 6 } do
	local root = Instance.new("Model")
	SledModels.rocket(root, CFrame.new(), t)
	dump("rocket:" .. t, root)
end
