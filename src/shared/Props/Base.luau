-- Общие помощники моделей (часть shared/Props, см. Props/init): part/deco, цвета, pick, надпись
-- на грани, колёса. Таблица Props здесь создаётся, модули категорий дописывают в неё модели.

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
				Size = Vector3.new(1.2, r, r),
				CFrame = base * CFrame.new(side * halfW, r, z),
				Color = Color3.fromRGB(190, 195, 205),
			}, parent)
		end
	end
end

return {
	Props = Props,
	part = part,
	deco = deco,
	pick = pick,
	label = label,
	wheels = wheels,
	SNOW = SNOW,
	BLACK = BLACK,
	GLASS = GLASS,
}
