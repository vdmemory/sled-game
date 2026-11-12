-- Предметы на трассе: монеты, гемы, магнит, бонусы (щит, x2, канистра, кольца), ледяной кристалл
-- и пометка препятствий тегом. Часть модуля shared/Track (см. Track/init).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Props = require(ReplicatedStorage.Shared.Props)

local part, deco = Props.part, Props.deco

local Items = {}

local function tagObstacle(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			CollectionService:AddTag(d, "Obstacle")
		end
	end
end

------------------------------------------------------------------ монета
-- Золотая монета: ободок + утопленное поле + выпуклая серединка (детали — дочерние части,
-- клиент вращает их вместе с монетой). Тег Coin только у основы: её касание и засчитывается.
local GOLD = Color3.fromRGB(255, 196, 45)
local GOLD_DARK = Color3.fromRGB(222, 150, 20)
local GOLD_LIGHT = Color3.fromRGB(255, 225, 110)
local function makeCoin(at: CFrame, parent: Instance)
	local cf = at * CFrame.Angles(0, math.rad(90), 0) -- цилиндр вытянут по X: ставим монету лицом к игроку
	local coin = part("Part", {
		Name = "Coin",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.45, 3, 3),
		CFrame = cf,
		Color = GOLD,
		Reflectance = 0.08,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})
	for _, spec in {
		{ size = Vector3.new(0.5, 2.3, 2.3), color = GOLD_DARK },
		{ size = Vector3.new(0.62, 1.1, 1.1), color = GOLD_LIGHT },
	} do
		part("Part", {
			Name = "CoinDetail",
			Shape = Enum.PartType.Cylinder,
			Size = spec.size,
			CFrame = cf,
			Color = spec.color,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
		}, coin)
	end
	CollectionService:AddTag(coin, "Coin")
	coin.Parent = parent
	return coin
end

------------------------------------------------------------------ бонусы: гем, магнит, кристалл
local GEM_BLUE = Color3.fromRGB(80, 190, 255)
local function makeGem(at: CFrame, parent: Instance)
	local gem = part("Part", {
		Name = "Gem",
		Size = Vector3.new(2.2, 2.2, 2.2),
		CFrame = at * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		Color = GEM_BLUE,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})
	local light = Instance.new("PointLight")
	light.Color = GEM_BLUE
	light.Range = 10
	light.Parent = gem
	CollectionService:AddTag(gem, "Gem")
	gem.Parent = parent
end

local function makeMagnet(at: CFrame, parent: Instance)
	local hit = part("Part", {
		Name = "Magnet",
		Size = Vector3.new(4, 4, 4),
		CFrame = at,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	}, parent)
	-- подкова: две половинки (синяя и розовая) + серебряные кончики
	for _, sx in { -1, 1 } do
		deco({ Size = Vector3.new(0.9, 2.6, 0.9), CFrame = at * CFrame.new(sx * 1, 0.2, 0), Color = if sx < 0 then Color3.fromRGB(60, 130, 255) else Color3.fromRGB(255, 90, 170) }, parent)
		deco({ Size = Vector3.new(0.92, 0.6, 0.92), CFrame = at * CFrame.new(sx * 1, -1.3, 0), Color = Color3.fromRGB(220, 225, 235), Material = Enum.Material.Metal }, parent)
	end
	deco({ Size = Vector3.new(2.9, 0.9, 0.9), CFrame = at * CFrame.new(0, 1.5, 0), Color = Color3.fromRGB(160, 110, 220) }, parent)
	CollectionService:AddTag(hit, "Magnet")
end

-- Бонусы (тег PowerUp, атрибут Kind). Невидимый куб-«датчик» + декоративная модель вокруг.
local function powerHit(kind: string, at: CFrame, size: Vector3, parent: Instance): BasePart
	local hit = part("Part", { Name = "PowerUp", Size = size, CFrame = at, Transparency = 1, CanCollide = false, CanQuery = false }, parent)
	hit:SetAttribute("Kind", kind)
	CollectionService:AddTag(hit, "PowerUp")
	return hit
end
local function makeShield(at: CFrame, parent: Instance)
	powerHit("shield", at, Vector3.new(4.5, 4.5, 4.5), parent)
	deco({ Shape = Enum.PartType.Ball, Size = Vector3.one * 4.2, CFrame = at, Material = Enum.Material.ForceField, Color = Color3.fromRGB(90, 200, 255) }, parent)
	-- щит-эмблема: синий щиток с белой полосой
	local plate = deco({ Size = Vector3.new(2.2, 2.6, 0.4), CFrame = at, Color = Color3.fromRGB(50, 120, 230) }, parent)
	deco({ Size = Vector3.new(0.5, 2.0, 0.45), CFrame = at, Color = Color3.new(1, 1, 1) }, parent)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(90, 200, 255)
	light.Range = 12
	light.Parent = plate
end
-- hit — свой размер датчика (x2 в воздухе над трамплин-лестницей #43: накрывает все траектории окна)
local function makeX2(at: CFrame, parent: Instance, hit: Vector3?)
	powerHit("x2", at, hit or Vector3.new(4.5, 4.5, 4.5), parent)
	local coin = deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 3.8, 3.8), CFrame = at * CFrame.Angles(0, math.rad(90), 0), Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(255, 200, 40), Reflectance = 0.2 }, parent)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(90, 60)
	bb.AlwaysOnTop = false
	bb.LightInfluence = 0
	bb.Parent = coin
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.Text = "x2"
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0
	t.Parent = bb
end
local function makeFuel(at: CFrame, parent: Instance)
	powerHit("fuel", at, Vector3.new(4.5, 4.5, 4.5), parent)
	deco({ Size = Vector3.new(2.6, 3.2, 1.3), CFrame = at, Color = Color3.fromRGB(220, 40, 40) }, parent)
	deco({ Size = Vector3.new(1.4, 0.35, 0.5), CFrame = at * CFrame.new(-0.3, 1.8, 0), Color = Color3.fromRGB(40, 40, 45) }, parent) -- ручка
	deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 0.6, 0.6), CFrame = at * CFrame.new(0.85, 1.85, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 210, 50) }, parent) -- крышка
	deco({ Size = Vector3.new(1.8, 1.0, 1.35), CFrame = at * CFrame.new(0, -0.2, 0), Color = Color3.fromRGB(255, 210, 50) }, parent) -- полоса
end
-- Золотое кольцо поперёк полосы: проезжаешь сквозь — монеты
local function makeRing(at: CFrame, parent: Instance)
	-- целое кольцо над снегом (низ почти касается трассы), датчик — в проёме
	local r, n, cy = 3.6, 18, 3.9
	powerHit("ring", at * CFrame.new(0, cy - 0.5, 0), Vector3.new(5, 6.5, 1.5), parent)
	for k = 0, n - 1 do
		local a = k / n * math.pi * 2
		deco({ Size = Vector3.new(0.6, 1.4, 0.6), CFrame = at * CFrame.new(math.cos(a) * r, math.sin(a) * r + cy, 0) * CFrame.Angles(0, 0, a), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 205, 60) }, parent)
	end
end

-- Кольцо-ускоритель (#44, ледяной тоннель): светящийся голубой обод над полосой, датчик в проёме —
-- обычный ускоритель (тег Boost, имя Boost: +BOOST_ADD в client/Sled/Contacts, учёт и предел скорости —
-- server/Pickups → AntiCheat.onBoost). at — точка на дне под центром кольца, r — радиус обода.
local function makeBoostRing(at: CFrame, r: number, parent: Instance)
	local cy = r + 0.4
	local hit = part("Part", {
		Name = "Boost",
		Size = Vector3.new(r * 1.6, r * 1.6, 6),
		CFrame = at * CFrame.new(0, cy, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	}, parent)
	CollectionService:AddTag(hit, "Boost")
	local n = 20
	for k = 0, n - 1 do
		local a = k / n * math.pi * 2
		deco({ Size = Vector3.new(0.7, r * 2 * math.pi / n + 0.2, 0.7), CFrame = at * CFrame.new(math.cos(a) * r, math.sin(a) * r + cy, 0) * CFrame.Angles(0, 0, a), Material = Enum.Material.Neon, Color = if k % 5 == 0 then Color3.new(1, 1, 1) else Color3.fromRGB(80, 230, 255) }, parent)
	end
	return hit
end

local function makeCrystal(at: CFrame, rng: Random, parent: Instance)
	local m = Instance.new("Model")
	m.Name = "Crystal"
	for _ = 1, 5 do
		local h = rng:NextNumber(5, 10)
		local p = part("Part", {
			Size = Vector3.new(2.2, h, 2.2),
			CFrame = at * CFrame.new(rng:NextNumber(-2, 2), h / 2 - 0.5, rng:NextNumber(-2, 2)) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 3), rng:NextNumber(-0.4, 0.4)),
			Color = Color3.fromRGB(150, 220, 255),
			Material = Enum.Material.Glass,
			Transparency = 0.15,
			Reflectance = 0.2,
			CanCollide = false,
		}, m)
		CollectionService:AddTag(p, "Crystal")
	end
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(150, 220, 255)
	light.Range = 18
	light.Brightness = 2
	light.Parent = m:FindFirstChildWhichIsA("BasePart")
	m.Parent = parent
end

Items.tagObstacle = tagObstacle
Items.coin = makeCoin
Items.gem = makeGem
Items.magnet = makeMagnet
Items.shield = makeShield
Items.x2 = makeX2
Items.fuel = makeFuel
Items.ring = makeRing
Items.boostRing = makeBoostRing
Items.crystal = makeCrystal

return Items
