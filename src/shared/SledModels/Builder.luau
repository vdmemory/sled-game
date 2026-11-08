-- Помощник сборки моделей транспорта из Part: куда класть, к чему приваривать, «трубки» и торы
-- из цилиндров с шариками в стыках; MeshPart из шаблонов (Builder:mesh) — с теми же свойствами.

local B = {}

export type Look = { main: Color3, accent: Color3, material: Enum.Material?, glow: boolean?, shine: number? }

B.WOOD = Color3.fromRGB(186, 128, 74)
B.WOOD_DARK = Color3.fromRGB(140, 92, 50)
B.STEEL = Color3.fromRGB(70, 74, 86)
B.BLACK = Color3.fromRGB(32, 34, 40)
B.WHITE = Color3.fromRGB(245, 247, 250)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(script.Parent.Parent.Config)
local Specs = require(script.Parent.Parent.MeshSpecs)

-- Контекст сборки: куда класть, к чему приваривать
local Builder = {}
Builder.__index = Builder

function B.new(parent: Instance, base: CFrame, weldTo: BasePart?)
	return setmetatable({ parent = parent, base = base, weldTo = weldTo, count = 0, main = nil, shine = 0 }, Builder)
end

-- Шаблоны мешей (server/MeshAssets кладёт MeshPart в ReplicatedStorage.MeshTemplates)
local function templates(): Instance?
	return ReplicatedStorage:FindFirstChild("MeshTemplates")
end

-- Есть ли все шаблоны мешей (модель/деталь включается мешами целиком или строится из Part).
-- Config.MESH_SLEDS = 0 — всегда Part (как до мешей транспорта).
function B.meshesReady(names: { string }): boolean
	if (Config.MESH_SLEDS or 0) < 0.5 then
		return false
	end
	local f = templates()
	if not f then
		return false
	end
	for _, n in names do
		if not f:FindFirstChild(n) or not (Specs :: any)[n] then
			return false
		end
	end
	return true
end

function Builder:part(shape: Enum.PartType, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, props: { [string]: any }?): BasePart
	local p = Instance.new("Part")
	p.Shape = shape
	p.Size = size
	p.CFrame = self.base * cf
	return self:finish(p, size, color, material, props)
end

-- MeshPart из шаблона: cf — кадр детали (начало координат меша из scripts/gen_*_meshes.py),
-- scale — масштаб по осям детали. Свойства — как у Part (без коллизий, Massless, приварка).
-- Нет шаблона — nil (вызывающий заранее проверяет B.meshesReady).
function Builder:mesh(name: string, color: Color3, material: Enum.Material?, cf: CFrame?, scale: Vector3?, props: { [string]: any }?): BasePart?
	local f = templates()
	local tpl = f and f:FindFirstChild(name)
	local spec = (Specs :: any)[name]
	if not tpl or not spec then
		return nil
	end
	local s = scale or Vector3.one
	local p = (tpl :: Instance):Clone() :: BasePart
	p.Size = spec.size * s
	local at = (cf or CFrame.identity) * CFrame.new(spec.offset * s)
	if (Config.MESH_SLED_FLIP or 0) > 0.5 then
		at *= CFrame.Angles(0, math.pi, 0) -- страховка: импорт развернул нос меша (модели симметричны по X)
	end
	p.CFrame = self.base * at
	return self:finish(p, p.Size, color, material, props)
end

function Builder:finish(p: BasePart, size: Vector3, color: Color3, material: Enum.Material?, props: { [string]: any }?): BasePart
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = size.Magnitude > 1.5 -- мелкие детали без теней: заметно дешевле на телефонах
	p.Massless = true
	p.CollisionGroup = "Riders"
	if self.main and color == self.main then
		p.Reflectance = self.shine -- глянец корпуса (Gold, Diamond)
	end
	for k, v in (props or {}) :: { [string]: any } do
		(p :: any)[k] = v
	end
	if self.weldTo then
		p.Anchored = false
		local w = Instance.new("WeldConstraint")
		w.Part0 = self.weldTo
		w.Part1 = p
		w.Parent = p
	else
		p.Anchored = true
	end
	p.Parent = self.parent
	self.count += 1
	return p
end

function Builder:block(size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, props: { [string]: any }?): BasePart
	return self:part(Enum.PartType.Block, size, cf, color, material, props)
end
function Builder:ball(d: number, cf: CFrame, color: Color3, material: Enum.Material?): BasePart
	return self:part(Enum.PartType.Ball, Vector3.new(d, d, d), cf, color, material)
end
-- Цилиндр вдоль оси dir (локальной), центр в pos
function Builder:cyl(d: number, len: number, pos: Vector3, dir: Vector3, color: Color3, material: Enum.Material?): BasePart
	local x = dir.Unit
	local up = if math.abs(x.Y) > 0.95 then Vector3.zAxis else Vector3.yAxis
	local z = x:Cross(up).Unit
	local y = z:Cross(x).Unit
	return self:part(Enum.PartType.Cylinder, Vector3.new(len, d, d), CFrame.fromMatrix(pos, x, y, z), color, material)
end
-- Эллипсоид (шар, растянутый мешем)
function Builder:ellipsoid(size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): BasePart
	local p = self:block(size, cf, color, material)
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Parent = p
	return p
end
function Builder:wedge(size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): BasePart
	local p = self:block(size, cf, color, material)
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Wedge
	m.Parent = p
	return p
end
-- Гладкая «трубка» через точки: цилиндры + шарики в стыках
function Builder:rod(points: { Vector3 }, d: number, color: Color3, material: Enum.Material?)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local len = (b - a).Magnitude
		if len > 0.01 then
			self:cyl(d, len + 0.02, (a + b) / 2, b - a, color, material)
		end
	end
	for i = 1, #points do
		self:ball(d, CFrame.new(points[i]), color, material)
	end
end
-- Тор (кольцо) вокруг локальной оси Y с центром center
function Builder:torus(center: Vector3, R: number, d: number, segments: number, color: Color3, material: Enum.Material?)
	local pts = {}
	for i = 0, segments do
		local a = i / segments * math.pi * 2
		table.insert(pts, center + Vector3.new(math.cos(a) * R, 0, math.sin(a) * R))
	end
	self:rod(pts, d, color, material)
end

return B
