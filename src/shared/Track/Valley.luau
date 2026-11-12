-- Гребень над долиной (владелец 2026-11-12, видео референса 613–651 м): с одной стороны трассы
-- (или с обеих, seg.valley = −1 / 1 / 2) вместо ровной земли — полка, обрыв вниз на VALLEY_DEPTH и
-- дно долины, из которого поднимаются островки-столбы со снежной шапкой и деревом на верхушке
-- (верх островков ниже трассы — смотришь на них сверху). Вид по миру: снег/скалы, ледяные столбы,
-- красные мезы каньона, базальт над лавой вулкана, розовые в конфетном мире.
-- Только декор (Props.deco / Meshes.place): невидимый барьер у кромки (Sections) остаётся, физика и
-- раскладка уровня не меняются. Участки выбирает Profile (seg.valley). Часть shared/Track.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Props = require(ReplicatedStorage.Shared.Props)
local Meshes = require(ReplicatedStorage.Shared.Meshes)

local deco = Props.deco

local Valley = {}

type Look = { cliff: Color3, cliffMat: Enum.Material, floor: Color3, floorMat: Enum.Material, cap: Color3?, capMat: Enum.Material?, tree: string? }

local LOOKS: { [number]: Look } = {
	[1] = { cliff = Color3.fromRGB(120, 130, 150), cliffMat = Enum.Material.Slate, floor = Color3.fromRGB(240, 246, 255), floorMat = Enum.Material.Snow, cap = Color3.fromRGB(250, 252, 255), capMat = Enum.Material.Snow, tree = "pine" },
	[2] = { cliff = Color3.fromRGB(130, 140, 160), cliffMat = Enum.Material.Slate, floor = Color3.fromRGB(235, 242, 252), floorMat = Enum.Material.Snow, cap = Color3.fromRGB(250, 252, 255), capMat = Enum.Material.Snow, tree = "pine" },
	[3] = { cliff = Color3.fromRGB(196, 120, 80), cliffMat = Enum.Material.Sandstone, floor = Color3.fromRGB(222, 170, 120), floorMat = Enum.Material.Sand, tree = "acacia" },
	[4] = { cliff = Color3.fromRGB(150, 205, 240), cliffMat = Enum.Material.Glacier, floor = Color3.fromRGB(200, 230, 250), floorMat = Enum.Material.Ice, cap = Color3.fromRGB(245, 250, 255), capMat = Enum.Material.Snow },
	[5] = { cliff = Color3.fromRGB(80, 92, 125), cliffMat = Enum.Material.Slate, floor = Color3.fromRGB(215, 225, 245), floorMat = Enum.Material.Snow, cap = Color3.fromRGB(240, 246, 255), capMat = Enum.Material.Snow, tree = "pine" },
	[6] = { cliff = Color3.fromRGB(58, 54, 60), cliffMat = Enum.Material.Basalt, floor = Color3.fromRGB(255, 110, 40), floorMat = Enum.Material.CrackedLava, tree = "charred" },
	[7] = { cliff = Color3.fromRGB(230, 170, 215), cliffMat = Enum.Material.SmoothPlastic, floor = Color3.fromRGB(255, 225, 240), floorMat = Enum.Material.SmoothPlastic, cap = Color3.fromRGB(255, 240, 248), capMat = Enum.Material.SmoothPlastic },
}

local function tree(kind: string?, rng: Random, at: CFrame, parent: Instance)
	if kind == "pine" then
		Props.pine(rng, at, parent)
	elseif kind == "acacia" then
		Props.acacia(rng, at, parent)
	elseif kind == "charred" then
		Props.charredTree(rng, at, parent)
	end
end

-- Островок-столб: верх на высоте top над дном (в кадре base, основание на дне долины)
local function isle(look: Look, theme: number, rng: Random, base: CFrame, top: number, w: number, parent: Instance)
	if theme == 3 and rng:NextNumber() < 0.45 then
		-- каньон: столб-худу (стопка глыб) вместо мезы
		Props.hoodoo(rng, base, parent, top)
		return
	elseif theme == 6 and rng:NextNumber() < 0.5 then
		Props.lavaSpire(rng, base, parent, top)
		return
	elseif theme == 3 and Meshes.has("mesa") then
		-- меза каньона: плоский верх, слоистые бока
		Meshes.place("mesa", base, Vector3.new(w / 2.2, top, w / 2.2), { Material = look.cliffMat, Color = Meshes.vary(look.cliff, base.Position, 0.08), CastShadow = true }, parent)
	elseif Meshes.has("crag") then
		Meshes.place("crag", base, Vector3.new(w / 1.96, top / 3.46, w / 1.46), { Material = look.cliffMat, Color = Meshes.vary(look.cliff, base.Position, 0.08), CastShadow = true }, parent)
	else
		deco({ Size = Vector3.new(w * 0.8, top, w * 0.8), CFrame = base * CFrame.new(0, top / 2, 0), Material = look.cliffMat, Color = look.cliff, CastShadow = true }, parent)
	end
	local cap = base * CFrame.new(0, top - 0.5, 0)
	if look.cap then
		if Meshes.has("isle_cap") then
			Meshes.place("isle_cap", cap, Vector3.new(w * 0.5, w * 0.22, w * 0.5), { Material = look.capMat or Enum.Material.Snow, Color = look.cap }, parent)
		else
			deco({ Size = Vector3.new(w * 0.9, 1.6, w * 0.9), CFrame = cap * CFrame.new(0, 0.6, 0), Material = look.capMat or Enum.Material.Snow, Color = look.cap }, parent)
		end
	end
	local spot = cap * CFrame.new(rng:NextNumber(-w * 0.15, w * 0.15), 0.6, rng:NextNumber(-w * 0.15, w * 0.15))
	if theme == 4 then
		Props.crystalSpire(rng, spot, parent) -- ледяные пещеры: кристалл на верхушке
	elseif rng:NextNumber() < 0.75 then
		local roll = rng:NextNumber()
		if look.tree == "pine" and roll < 0.35 then
			Props.tierPine(rng, spot, parent)
		elseif look.tree == "pine" and roll < 0.6 then
			Props.fluffyPine(rng, spot, parent)
		else
			tree(look.tree, rng, spot, parent)
		end
	end
end

-- Обрыв и долина вдоль куска. cf — начало куска (центр дна, −Z вниз по трассе), visLen — длина
-- видимой части, prof — сечение (out — край полки, top — высота кромки).
function Valley.build(theme: number, seg, cf: CFrame, visLen: number, prof, parent: Instance)
	local look = LOOKS[theme] or LOOKS[1]
	local depth = Config.VALLEY_DEPTH
	local x0 = prof.out + Config.VALLEY_SHOULDER -- край полки = верх обрыва
	local yTop = prof.top - 1
	local yBottom = yTop - depth
	local p0 = cf.Position
	local rng = Random.new((math.floor(p0.X * 5.17 + p0.Z * 9.31) % 2147483647) + theme) -- свой: раскладка уровня не сдвигается
	local len = visLen + 2
	for _, side in { -1, 1 } do
		if seg.valley == side or seg.valley == 2 then
			-- стена обрыва: чуть наклонена наружу, сверху снежный козырёк
			deco({
				Size = Vector3.new(8, depth + 2, len),
				CFrame = cf * CFrame.new(side * (x0 + 4), yTop - depth / 2, -visLen / 2) * CFrame.Angles(0, 0, -side * math.rad(6)),
				Material = look.cliffMat,
				Color = Meshes.vary(look.cliff, p0, 0.05),
				CastShadow = true,
			}, parent)
			if look.cap then
				deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(len, 4, 4), CFrame = cf * CFrame.new(side * (x0 + 1), yTop + 0.6, -visLen / 2) * CFrame.Angles(0, math.rad(90), 0), Material = look.capMat or Enum.Material.Snow, Color = look.cap }, parent)
			end
			-- выступы скалы на стене (неровный обрыв)
			if Meshes.has("rock_b") and rng:NextNumber() < 0.7 then
				local z = rng:NextNumber(0, visLen)
				local r = rng:NextNumber(6, 11)
				Meshes.place("rock_b", cf * CFrame.new(side * (x0 + 6), yTop - rng:NextNumber(10, depth - 10), -z) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0), Vector3.one * r, { Material = look.cliffMat, Color = Meshes.vary(look.cliff, p0 + Vector3.new(0, z, 0), 0.08) }, parent)
			end
			-- дно долины
			local w = Config.VALLEY_WIDTH
			local fl = deco({
				Size = Vector3.new(w, 2, len),
				CFrame = cf * CFrame.new(side * (x0 + 8 + w / 2), yBottom - 1, -visLen / 2),
				Material = look.floorMat,
				Color = look.floor,
			}, parent)
			if look.floorMat == Enum.Material.CrackedLava then
				local light = Instance.new("PointLight")
				light.Color = Color3.fromRGB(255, 120, 50)
				light.Range = 40
				light.Brightness = 1
				light.Parent = fl
			end
			-- островки: верх на 45–88% глубины, ближние ниже и шире, дальние — до 260 studs
			local count = visLen / 100 * Config.VALLEY_ISLES
			local n = math.floor(count) + (if rng:NextNumber() < count % 1 then 1 else 0)
			for _ = 1, n do
				local dx = rng:NextNumber(28, 260)
				local base = cf * CFrame.new(side * (x0 + 8 + dx), yBottom, -rng:NextNumber(0, visLen)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
				isle(look, theme, rng, base, depth * rng:NextNumber(0.45, 0.88), rng:NextNumber(14, 30), parent)
			end
		end
	end
end

-- Декор обочин, попавший на сторону долины (висел бы в воздухе над обрывом), — убрать.
-- Декор строится как обычно (те же случайные числа), потом лишнее удаляется — раскладка не меняется.
function Valley.prune(seg, cf: CFrame, prof, from: Instance, to: Instance)
	for _, c in from:GetChildren() do
		local pos = if c:IsA("BasePart") then c.Position elseif c:IsA("Model") then c:GetPivot().Position else nil
		local rel = pos and cf:PointToObjectSpace(pos)
		local side = if rel and rel.X < 0 then -1 else 1
		if rel and math.abs(rel.X) > prof.out + 1 and (seg.valley == side or seg.valley == 2) then
			c:Destroy()
		else
			c.Parent = to
		end
	end
	from:Destroy()
end

return Valley
