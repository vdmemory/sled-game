-- Корпуса саней из своих мешей (scripts/gen_sled_meshes.py; чертежи — в docstring там же и в
-- docs/GAME_DESIGN.md → «Сани: модели»). Модель разбита на меши по цветам: корпус (main), детали
-- (accent), металл/резина/стекло/дерево — нейтрально; MeshPart.Color красит меш целиком, поэтому
-- редкость (Gold/Diamond/…) перекрашивает корпус и детали, а металл и резина остаются.
-- Мелкие светящиеся/особые детали (фара, номера, круги на крыльях) — Part поверх мешей.
-- Нет хоть одного шаблона модели — SledModels строит её из Part (Bodies).

local B = require(script.Parent.Builder)
type Look = B.Look
local WOOD, WOOD_DARK, STEEL, BLACK, WHITE = B.WOOD, B.WOOD_DARK, B.STEEL, B.BLACK, B.WHITE

local BodyMeshes = {}

local GLASS = Color3.fromRGB(170, 215, 245)
local RUBBER = Color3.fromRGB(38, 39, 45)
local ROPE = Color3.fromRGB(225, 205, 160)

-- Роль меша → цвет и материал по виду модели (look) и «крашеной» редкости (painted)
local function paint(role: string, look: Look, painted: boolean): (Color3, Enum.Material, { [string]: any }?)
	local mat = look.material or Enum.Material.SmoothPlastic
	local accentMat = if look.glow then Enum.Material.Neon else mat
	local wood = if painted then look.main else WOOD
	local woodMat = if painted then mat else Enum.Material.Wood
	if role == "main" then
		return look.main, mat, nil
	elseif role == "accent" then
		return look.accent, accentMat, nil
	elseif role == "accentPlain" then -- акцент без неона (ручки, стрепы)
		return look.accent:Lerp(BLACK, 0.2), Enum.Material.SmoothPlastic, nil
	elseif role == "light" then
		return look.main:Lerp(WHITE, 0.25), mat, nil
	elseif role == "seat" then
		return look.main:Lerp(BLACK, 0.45), Enum.Material.Fabric, nil
	elseif role == "pad" then
		return look.accent:Lerp(WHITE, 0.15), Enum.Material.Fabric, nil
	elseif role == "rope" then
		return look.accent, Enum.Material.Fabric, nil
	elseif role == "wood" then
		return wood, woodMat, nil
	elseif role == "woodAlt" then
		return wood:Lerp(WOOD_DARK, 0.35), woodMat, nil
	elseif role == "woodDark" then
		return WOOD_DARK, Enum.Material.Wood, nil
	elseif role == "runner" then
		return if painted then look.accent else Color3.fromRGB(190, 40, 40), Enum.Material.Metal, nil
	elseif role == "steel" then
		return STEEL, Enum.Material.Metal, nil
	elseif role == "rubber" then
		return RUBBER, Enum.Material.Rubber, nil
	elseif role == "fabric" then
		return BLACK, Enum.Material.Fabric, nil
	elseif role == "beige" then
		return ROPE, Enum.Material.Fabric, nil
	elseif role == "glass" then
		return GLASS, Enum.Material.Glass, { Transparency = 0.35 }
	elseif role == "white" then
		return WHITE, Enum.Material.SmoothPlastic, nil
	end
	return BLACK, Enum.Material.SmoothPlastic, nil
end

-- Меши каждой модели: { имя, роль }. Порядок — от крупного к мелкому.
local MODELS: { [string]: { { string } } } = {
	tube = { { "sled_tube_top", "main" }, { "sled_tube_base", "rubber" }, { "sled_tube_seat", "seat" }, { "sled_tube_trim", "accent" }, { "sled_tube_strap", "fabric" } },
	saucer = { { "sled_saucer_body", "main" }, { "sled_saucer_dish", "light" }, { "sled_saucer_trim", "accentPlain" } },
	board = { { "sled_board_deck", "main" }, { "sled_board_base", "black" }, { "sled_board_bind", "black" }, { "sled_board_accent", "accent" } },
	toboggan = { { "sled_tob_planks_a", "wood" }, { "sled_tob_planks_b", "woodAlt" }, { "sled_tob_frame", "woodDark" }, { "sled_tob_rope", "rope" }, { "sled_tob_pad", "pad" } },
	classic = { { "sled_classic_slats", "wood" }, { "sled_classic_runner", "runner" }, { "sled_classic_frame", "woodDark" }, { "sled_classic_metal", "steel" }, { "sled_classic_rope", "beige" } },
	kayak = { { "sled_kayak_hull", "main" }, { "sled_kayak_trim", "accent" }, { "sled_kayak_black", "black" }, { "sled_kayak_paddle", "steel" } },
	plane = { { "sled_plane_body", "main" }, { "sled_plane_wing", "accent" }, { "sled_plane_glass", "glass" }, { "sled_plane_black", "black" }, { "sled_plane_ski", "white" }, { "sled_plane_metal", "steel" } },
	bobsled = { { "sled_bob_body", "main" }, { "sled_bob_stripe", "accent" }, { "sled_bob_metal", "steel" }, { "sled_bob_inner", "black" } },
	snowmobile = { { "sled_snow_hood", "main" }, { "sled_snow_accent", "accent" }, { "sled_snow_glass", "glass" }, { "sled_snow_seat", "fabric" }, { "sled_snow_track", "rubber" }, { "sled_snow_ski", "black" }, { "sled_snow_metal", "steel" } },
}
BodyMeshes.MODELS = MODELS

-- Имена всех мешей корпусов (для ожидания загрузки в лобби)
function BodyMeshes.names(): { string }
	local out = {}
	for _, list in MODELS do
		for _, e in list do
			table.insert(out, e[1])
		end
	end
	table.sort(out)
	return out
end

function BodyMeshes.ids(): { string }
	local out = {}
	for id in MODELS do
		table.insert(out, id)
	end
	table.sort(out)
	return out
end

local function meshNames(id: string): { string }
	local out = {}
	local list = MODELS[id]
	if list then
		for _, e in list do
			table.insert(out, e[1])
		end
	end
	return out
end

function BodyMeshes.ready(id: string): boolean
	return MODELS[id] ~= nil and B.meshesReady(meshNames(id))
end

-- Номер на борту бобслея: белый круг + цифра (SurfaceGui на торце цилиндра)
local function numberDisc(b, x: number, face: Enum.NormalId)
	local disc = b:part(Enum.PartType.Cylinder, Vector3.new(0.05, 0.85, 0.85), CFrame.new(x, 0.1, 1.2), WHITE)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.CanvasSize = Vector2.new(100, 100)
	gui.LightInfluence = 1
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = "7"
	t.TextScaled = true
	t.Font = Enum.Font.GothamBlack
	t.TextColor3 = BLACK
	t.Parent = gui
	gui.Parent = disc
end

-- Детали поверх мешей (Part): свет, номера, опознавательные круги
local DETAILS: { [string]: (any, Look) -> () } = {
	plane = function(b, _look)
		b:ellipsoid(Vector3.new(0.9, 0.9, 1.0), CFrame.new(0, 0.2, -3.4), WHITE) -- кок винта
		b:part(Enum.PartType.Cylinder, Vector3.new(0.04, 3.8, 3.8), CFrame.new(0, 0.2, -3.6) * CFrame.Angles(0, math.rad(90), 0), WHITE, nil, { Transparency = 0.8, Name = "PropDisc" })
		for _, sx in { -1, 1 } do
			local y = -0.38 + 3.2 * 0.05 + 0.16
			b:part(Enum.PartType.Cylinder, Vector3.new(0.04, 1.3, 1.3), CFrame.new(sx * 3.2, y, -0.25) * CFrame.Angles(0, 0, math.rad(90)), WHITE)
			b:part(Enum.PartType.Cylinder, Vector3.new(0.05, 0.6, 0.6), CFrame.new(sx * 3.2, y + 0.005, -0.25) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(220, 50, 50))
		end
		b:ball(0.32, CFrame.new(-5.25, -0.12, -0.35), Color3.fromRGB(255, 60, 60), Enum.Material.Neon)
		b:ball(0.32, CFrame.new(5.25, -0.12, -0.35), Color3.fromRGB(60, 255, 120), Enum.Material.Neon)
	end,
	bobsled = function(b, _look)
		numberDisc(b, 1.47, Enum.NormalId.Right)
		numberDisc(b, -1.47, Enum.NormalId.Left)
	end,
	snowmobile = function(b, _look)
		b:ellipsoid(Vector3.new(0.75, 0.24, 0.36), CFrame.new(0, 0.04, -3.1) * CFrame.Angles(math.rad(-15), 0, 0), Color3.fromRGB(255, 245, 200), Enum.Material.Neon) -- фара
		b:block(Vector3.new(1.1, 0.16, 0.08), CFrame.new(0, -0.08, 3.0), Color3.fromRGB(255, 50, 50), Enum.Material.Neon) -- стоп-сигнал
	end,
}

function BodyMeshes.build(b, id: string, look: Look, painted: boolean)
	for _, e in MODELS[id] do
		local color, mat, props = paint(e[2], look, painted)
		b:mesh(e[1], color, mat, nil, nil, props)
	end
	local extra = DETAILS[id]
	if extra then
		extra(b, look)
	end
end

return BodyMeshes
