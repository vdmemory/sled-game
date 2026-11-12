-- Общие помощники моделей (часть shared/Props, см. Props/init): part/deco, цвета, pick, надпись
-- на грани, колёса. Таблица Props здесь создаётся, модули категорий дописывают в неё модели.

local Meshes = require(script.Parent.Parent.Meshes)

local Props = {}

------------------------------------------------------------------ helpers
local function part(className: string, props: { [string]: any }, parent: Instance?): BasePart
	local p = Instance.new(className) :: BasePart
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	-- Шар с неравными размерами Roblox рисует круглым — делаем настоящий эллипсоид через меш
	if props.Shape == Enum.PartType.Ball then
		local s = p.Size
		if math.abs(s.X - s.Y) > 0.01 or math.abs(s.Y - s.Z) > 0.01 then
			p.Shape = Enum.PartType.Block
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = p
		end
	end
	if parent then
		p.Parent = parent
	end
	return p
end
Props.part = part

-- Декоративная деталь: не мешает физике и лучам
local function deco(props: { [string]: any }, parent: Instance, className: string?): BasePart
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	if props.CastShadow == nil then
		props.CastShadow = false
	end
	return part(className or "Part", props, parent)
end
Props.deco = deco

local SNOW = Color3.fromRGB(250, 252, 255)
local BLACK = Color3.fromRGB(35, 35, 40)
local GLASS = Color3.fromRGB(60, 90, 130)

local function pick<T>(rng: Random, list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

-- Надпись на грани детали
local function label(p: BasePart, face: Enum.NormalId, text: string, color: Color3, bg: Color3?)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.CanvasSize = Vector2.new(200, 200)
	sg.LightInfluence = 1
	sg.Parent = p
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = if bg then 0 else 1
	t.BackgroundColor3 = bg or Color3.new()
	t.TextColor3 = color
	t.TextScaled = true
	t.Font = Enum.Font.GothamBlack
	t.Text = text
	t.Parent = sg
end

-- Колёса: шина — Part с коллизией (как раньше), белый колпак на ~60% диаметра — «игрушечное» колесо
-- из референсов (#68)
local HUB = Color3.fromRGB(245, 245, 240)
local function wheels(base: CFrame, halfW: number, zs: { number }, r: number, parent: Instance)
	for _, z in zs do
		for _, side in { -1, 1 } do
			part("Part", {
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1.1, r * 2, r * 2),
				CFrame = base * CFrame.new(side * halfW, r, z),
				Color = BLACK,
			}, parent)
			deco({ -- колпак
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1.2, r * 1.2, r * 1.2),
				CFrame = base * CFrame.new(side * halfW, r, z),
				Color = HUB,
			}, parent)
		end
	end
end

------------------------------------------------------------------ «мягкий» транспорт (#68)
-- Кузова трафика в стиле «пластилин»: коллизию несут прежние Part (их делаем невидимыми), вид —
-- декор без коллизии. Окна крупные светло-голубые, решётка чёрная, фары круглые.
local WINDOW = Color3.fromRGB(150, 205, 240)

-- Короб со скруглёнными верхними рёбрами поперёк машины (переднее/заднее — их видно сбоку, а
-- трафик проезжает поперёк трассы). 4 части: низ во всю длину, верхний слой короче на r,
-- 2 цилиндра-скругления. opts: front/back = false — ребро не скруглять; top — цвет верха (крыша);
-- shadow — отбрасывать тень (только крупным).
local function softBox(cf: CFrame, size: Vector3, r: number, color: Color3, parent: Instance, opts: { [string]: any }?)
	local o = opts or {}
	local front, back = o.front ~= false, o.back ~= false
	local top = o.top or color
	local hy = size.Y / 2
	deco({ Size = Vector3.new(size.X, size.Y - r, size.Z), CFrame = cf * CFrame.new(0, -r / 2, 0), Color = color, CastShadow = o.shadow == true }, parent)
	local z0 = -size.Z / 2 + (if front then r else 0)
	local z1 = size.Z / 2 - (if back then r else 0)
	deco({ Size = Vector3.new(size.X, r, z1 - z0), CFrame = cf * CFrame.new(0, hy - r / 2, (z0 + z1) / 2), Color = top, CastShadow = o.shadow == true }, parent)
	-- цилиндры чуть утоплены, чтобы их нижняя половина не мерцала на гранях низа
	local ends = {}
	if front then
		table.insert(ends, z0 + 0.02)
	end
	if back then
		table.insert(ends, z1 - 0.02)
	end
	for _, z in ends do
		deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(size.X - 0.04, r * 2, r * 2), CFrame = cf * CFrame.new(0, hy - r, z), Color = top }, parent)
	end
end

-- «Пилюля» вдоль Z: брусок + полукруглые торцы (багажник на крыше, мигалка). size.Y — диаметр торцов.
local function pill(cf: CFrame, size: Vector3, color: Color3, parent: Instance, material: Enum.Material?)
	local d = size.Y
	deco({ Size = Vector3.new(size.X, d, size.Z - d), CFrame = cf, Color = color, Material = material }, parent)
	for _, s in { -1, 1 } do
		deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(size.X, d, d), CFrame = cf * CFrame.new(0, 0, s * (size.Z - d) / 2), Color = color, Material = material }, parent)
	end
end

-- Круглая фара/фонарь, смотрит по оси Z base (диск-цилиндр, повернутый на 90° по Y)
local function lamp(cf: CFrame, d: number, color: Color3, parent: Instance, neon: boolean?)
	deco({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.25, d, d),
		CFrame = cf * CFrame.Angles(0, math.rad(90), 0),
		Color = color,
		Material = if neon then Enum.Material.Neon else nil,
	}, parent)
end

-- Снежная «подушка» на крыше: приплюснутый эллипсоид, утоплен наполовину
local function snowCap(cf: CFrame, size: Vector3, parent: Instance)
	deco({ Shape = Enum.PartType.Ball, Size = size, CFrame = cf, Material = Enum.Material.Snow, Color = SNOW }, parent)
end

return {
	Props = Props,
	Meshes = Meshes, -- свои меши декора (#45): has/place/vary, фолбэк — модели из Part
	part = part,
	deco = deco,
	pick = pick,
	label = label,
	wheels = wheels,
	softBox = softBox,
	pill = pill,
	lamp = lamp,
	snowCap = snowCap,
	WINDOW = WINDOW,
	SNOW = SNOW,
	BLACK = BLACK,
	GLASS = GLASS,
}
