-- Свои 3D-меши декора (#45): скалы, ёлка, сугроб, лёд, островок, арка, гора, меза.
-- Пайплайн: scripts/gen_meshes.py (форма, габариты → MeshSpecs) → деплой scripts/upload_meshes.py
-- (Open Cloud Assets API, Model из .glb → ID в MeshIds) → сервер MeshAssets.server достаёт MeshPart
-- через InsertService:LoadAsset и кладёт шаблоны в ReplicatedStorage.MeshTemplates (видит и клиент:
-- витрина и декор лобби). MeshId у MeshPart из скрипта не ставится — поэтому шаблон + Clone.
--
-- Фолбэк: пока шаблона нет (ключ без прав, модерация, не догрузился, Config.MESH_DECOR = 0) —
-- Meshes.has → false, и Props строит прежнюю модель из Part. Игра не ломается.
-- Меши только для декора (без коллизий и лучей): ходовая часть и препятствия — Part (точная коллизия).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(script.Parent.Config)
local Specs = require(script.Parent.MeshSpecs)
local Ids = require(script.Parent.MeshIds)

local Meshes = {}
Meshes.FOLDER = "MeshTemplates"

local cached: Instance? = nil
local function templates(): Instance?
	if cached and cached.Parent then
		return cached
	end
	cached = ReplicatedStorage:FindFirstChild(Meshes.FOLDER)
	return cached
end

-- Есть ли все шаблоны (объект из нескольких мешей включается целиком или не включается)
function Meshes.has(...: string): boolean
	if (Config.MESH_DECOR or 0) < 0.5 then
		return false
	end
	local f = templates()
	if not f then
		return false
	end
	for _, name in { ... } do
		if not f:FindFirstChild(name) or not Specs[name] then
			return false
		end
	end
	return true
end

-- Дождаться шаблонов (MeshAssets.server грузит их асинхронно после старта): ждём только меши, у
-- которых есть ID в MeshIds (без ID — не загружен деплоем, сразу фолбэк из Part), не дольше
-- timeout секунд. true — все дождались.
function Meshes.waitFor(names: { string }, timeout: number): boolean
	if (Config.MESH_DECOR or 0) < 0.5 then
		return false
	end
	local want = {}
	for _, n in names do
		if (Ids :: any)[n] ~= nil then
			table.insert(want, n)
		end
	end
	local t0 = os.clock()
	while not Meshes.has(table.unpack(want)) do
		if os.clock() - t0 > timeout then
			return false
		end
		task.wait(0.25)
	end
	return #want == #names
end

-- Поставить меш объекта: base — основание объекта на земле (кадр объекта из gen_meshes.py),
-- scale — масштаб по осям объекта (1 = габариты из MeshSpecs). Декор: без коллизий, лучей, касаний.
-- props — свойства поверх (Color, Material, Transparency, CastShadow …). Нет шаблона — nil.
function Meshes.place(name: string, base: CFrame, scale: Vector3, props: { [string]: any }, parent: Instance): BasePart?
	local f = templates()
	local tpl = f and f:FindFirstChild(name)
	local spec = Specs[name]
	if not tpl or not spec then
		return nil
	end
	local p = (tpl :: Instance):Clone() :: BasePart
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Size = spec.size * scale
	p.CFrame = base * CFrame.new(spec.offset * scale)
	p.Parent = parent
	return p
end

-- Небольшой разброс оттенка без Random (по позиции): однотипный декор не «штампованный», а
-- раскладка препятствий/монет (общий Random куска) не сдвигается. amt — доля яркости (0.08 = ±8%).
function Meshes.vary(c: Color3, at: Vector3, amt: number): Color3
	local x = math.sin(at.X * 12.9898 + at.Y * 78.233 + at.Z * 37.719) * 43758.5453
	local u = x - math.floor(x)
	local y = math.sin(at.X * 63.7264 + at.Z * 10.873 + 4.1) * 24634.6345
	local w = y - math.floor(y)
	local k = 1 + (u - 0.5) * 2 * amt
	local warm = (w - 0.5) * amt * 0.5 -- лёгкий сдвиг тёплый/холодный
	return Color3.new(math.clamp(c.R * k + warm, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k - warm, 0, 1))
end

return Meshes
