-- Лобби: стартовый хаб. Сервер строит общую «архитектуру» (Lobby.build), клиент одевает её под
-- свой текущий мир (Lobby.dress) — см. client/LobbyScene. Чистая геометрия: Part, Config,
-- Props, SledModels; серверных сервисов нет, модуль общий.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Props = require(ReplicatedStorage.Shared.Props)
local SledModels = require(ReplicatedStorage.Shared.SledModels)

local part, deco = Props.part, Props.deco
local SNOW = Color3.fromRGB(250, 252, 255)

local Lobby = {}

-- footer — строка «ты: место · очки · сброс» внизу (табло недели, заполняет client/WeeklyBoard)
local function board(name: string, at: CFrame, title: string, parent: Instance, footer: boolean?): TextLabel
	local m = Instance.new("Model")
	m.Name = name
	for _, sx in { -1, 1 } do
		part("Part", { Size = Vector3.new(1, 16, 1), CFrame = at * CFrame.new(sx * 9, 8, 0.6), Material = Enum.Material.Wood, Color = Color3.fromRGB(120, 80, 45) }, m)
	end
	local panel = part("Part", { Size = Vector3.new(18, 12, 0.6), CFrame = at * CFrame.new(0, 10, 0), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(95, 60, 35) }, m)
	deco({ Size = Vector3.new(18.6, 0.8, 1.4), CFrame = at * CFrame.new(0, 16.3, 0), Material = Enum.Material.Snow, Color = SNOW }, m)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.CanvasSize = Vector2.new(600, 400)
	sg.LightInfluence = 0.3
	sg.Parent = panel
	local head = Instance.new("TextLabel")
	head.Name = "Head"
	head.BackgroundTransparency = 1
	head.Size = UDim2.new(1, 0, 0, 80)
	head.Font = Enum.Font.FredokaOne
	head.TextScaled = true
	head.TextColor3 = Color3.fromRGB(255, 220, 90)
	head.Text = title
	head.Parent = sg
	local body = Instance.new("TextLabel")
	body.Name = "List"
	body.BackgroundTransparency = 1
	body.Position = UDim2.new(0, 30, 0, 90)
	body.Size = UDim2.new(1, -60, 1, if footer then -160 else -110)
	body.Font = Enum.Font.FredokaOne
	body.TextScaled = true
	body.TextColor3 = Color3.new(1, 1, 1)
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.Text = "…"
	body.Parent = sg
	if footer then
		local me = Instance.new("TextLabel")
		me.Name = "Me"
		me.BackgroundColor3 = Color3.fromRGB(60, 38, 20)
		me.BackgroundTransparency = 0.3
		me.Position = UDim2.new(0, 20, 1, -64)
		me.Size = UDim2.new(1, -40, 0, 50)
		me.Font = Enum.Font.FredokaOne
		me.TextScaled = true
		me.TextColor3 = Color3.fromRGB(255, 220, 90)
		me.Text = ""
		me.Parent = sg
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 12)
		c.Parent = me
		local pad = Instance.new("UIPadding")
		pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
		pad.Parent = me
	end
	m.Parent = parent
	return body
end

-- Витрина: подиум с подсветкой и настоящей моделью саней (как подиумы в Roblox-референсе)
local function showcaseSled(at: CFrame, sledId: string, rarityIdx: number, caption: string, parent: Instance)
	local rarity = Config.RARITIES[rarityIdx]
	local col = rarity.color or Color3.fromRGB(240, 70, 120)
	part("Part", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 13, 13), CFrame = at * CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(235, 240, 250) }, parent)
	local ring = deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 13.6, 13.6), CFrame = at * CFrame.new(0, 1.9, 0) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Neon, Color = col }, parent)
	local holder = Instance.new("Model")
	holder.Name = "Showcase"
	local showCF = at * CFrame.new(0, 4, 0) * CFrame.Angles(math.rad(-10), math.rad(30), 0)
	SledModels.build(holder, showCF, sledId, {
		main = col,
		accent = Color3.new(1, 1, 1):Lerp(col, 0.35),
		material = rarity.material,
		glow = rarityIdx == 5,
		shine = rarity.shine,
	}, nil, true)
	-- прокачанная витрина: топовые ракеты и обвес
	SledModels.extras(holder, showCF, sledId, 4, if rarityIdx == 5 then 5 else 3, Color3.new(1, 1, 1):Lerp(col, 0.35), nil)
	holder.Parent = parent
	local glow = Instance.new("PointLight")
	glow.Color = col
	glow.Range = 16
	glow.Brightness = 1.5
	glow.Parent = ring
	local anchor = deco({ Size = Vector3.new(1, 1, 1), CFrame = at * CFrame.new(0, 10, 0), Transparency = 1 }, parent)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(220, 50)
	bb.MaxDistance = 90
	bb.Parent = anchor
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.3
	t.Text = caption
	t.Parent = bb
end


-- Вывеска на перекладине арки: текст меняет клиент (название мира игрока)
local function archSign(beam: BasePart, text: string): TextLabel
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Sign"
	sg.Face = Enum.NormalId.Back -- смотрит на спавн (+Z лобби)
	sg.CanvasSize = Vector2.new(900, 160)
	sg.LightInfluence = 0.2
	sg.Parent = beam
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(255, 225, 90)
	t.TextStrokeTransparency = 0.2
	t.Text = text
	t.Parent = sg
	return t
end

-- Цветной «кружок-зона» на земле под объектом (как в Roblox-референсе): читается с точки спавна
local function zoneDisc(at: CFrame, r: number, color: Color3, parent: Instance)
	deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, r * 2, r * 2), CFrame = at * CFrame.new(0, 0.12, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = color, Transparency = 0.25 }, parent)
	deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, r * 2 + 1.2, r * 2 + 1.2), CFrame = at * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Neon, Color = color:Lerp(Color3.new(1, 1, 1), 0.3), Transparency = 0.55 }, parent)
end

-- Лобби (сервер): только «архитектура», общая для всех — площадка, пирс к обрыву, арка-вывеска,
-- подиумы, табло, костёр, флаги, фонари. Декор по миру (деревья, снеговик, кактусы…), витринная
-- трасса за пирсом и цвет земли — у каждого игрока свои (client/LobbyScene → Lobby.dress).
--
-- Схема сверху (x вправо, −Z = к обрыву и трассе; размеры в studs):
--
--   z=+46   ·  ·  ·  задний ряд декора мира (клиент)  ·  ·  ·
--   z=+24        [флаг]                        [флаг]
--   z=+14   (костёр, брёвна) x=−18        x=+18 (акцент мира, клиент)
--   z=0            ◎ СПАВН (круглая плита, лицом к −Z)
--   z=−4         ╔══ АРКА «мир · ▼ СТАРТ» ══╗  (x ±8.6)
--   z=−10   [ТАБЛО обновл.] x=−34     x=+34 [ТАБЛО лидеров]
--   z=−6…−60     ║ пирс 14 wide, перила,     ║  фонари ×4, гирлянды флажков по перилам
--   z=−24   (подиум саней) x=−24   x=+24 (подиум саней)   — вдоль пирса, видны со спавна
--   z=−30        [флаг] x=−40                 x=+40 [флаг]
--   z=−40   ─────────── край площадки (обрыв) ───────────
--   z=−60        кольцо посадки, конец пирса
--   z=−70        старт витринной трассы: рогатка, LaunchPad (сервер), далее трасса мира (клиент)
function Lobby.build()
	local p = Config.LOBBY_POS
	local base = CFrame.new(p)
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"
	local rng = Random.new(7)
	-- Площадка лобби заканчивается обрывом: дальше вниз уходит трасса (её видно с мостика)
	part("Part", {
		Name = "LobbyGround",
		Size = Vector3.new(150, 4, 90),
		CFrame = base * CFrame.new(0, -2, 5),
		Material = Enum.Material.Snow,
		Color = SNOW,
	}, lobby)
	-- Круглая каменная плита спавна и дорожка-плитка к пирсу: путь «спавн → мостик» читается сразу
	part("Part", { Name = "Plaza", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 30, 30), CFrame = base * CFrame.new(0, 0.2, 2) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Slate, Color = Color3.fromRGB(150, 160, 180) }, lobby)
	deco({ Name = "PlazaRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 31, 31), CFrame = base * CFrame.new(0, 0.2, 2) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Neon, Color = Color3.fromRGB(120, 220, 255), Transparency = 0.5 }, lobby) -- цвет ставит клиент по миру

	-- Деревянный пирс к старту трассы (как в Roblox-референсе): дойди до края — сядешь в сани
	for z = -6, -60, -3 do
		part("Part", { Size = Vector3.new(14, 0.6, 2.6), CFrame = base * CFrame.new(0, 0.3, z), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(150, 105, 65) }, lobby)
	end
	-- Светящиеся стрелки по центру пирса — путь к старту
	for z = -12, -56, -8 do
		deco({ Size = Vector3.new(3.4, 0.08, 1.6), CFrame = base * CFrame.new(0, 0.65, z), Material = Enum.Material.Neon, Color = Color3.fromRGB(90, 220, 255), Transparency = 0.2 }, lobby, "WedgePart")
	end
	for _, sx in { -1, 1 } do
		deco({ Size = Vector3.new(0.8, 1, 56), CFrame = base * CFrame.new(sx * 7.4, 1.2, -33), Material = Enum.Material.Wood, Color = Color3.fromRGB(110, 75, 40) }, lobby)
		for z = -6, -60, -8 do
			deco({ Size = Vector3.new(0.6, 2, 0.6), CFrame = base * CFrame.new(sx * 7.4, 1, z), Material = Enum.Material.Wood, Color = Color3.fromRGB(110, 75, 40) }, lobby)
		end
		-- Фонари на пирсе (тёплый свет, виден и днём как ориентир)
		for _, z in { -22, -48 } do
			Props.lantern(base * CFrame.new(sx * 8.2, 1.4, z), lobby)
		end
		-- Гирлянды флажков вдоль перил
		Props.garland((base * CFrame.new(sx * 7.4, 8, -6)).Position, (base * CFrame.new(sx * 7.4, 8, -34)).Position, lobby, rng)
		Props.garland((base * CFrame.new(sx * 7.4, 8, -34)).Position, (base * CFrame.new(sx * 7.4, 8, -62)).Position, lobby, rng)
	end
	-- Опоры пирса над обрывом
	for _, z in { -44, -58 } do
		for _, sx in { -1, 1 } do
			deco({ Size = Vector3.new(1.2, 30, 1.2), CFrame = base * CFrame.new(sx * 6, -15, z), Material = Enum.Material.Wood, Color = Color3.fromRGB(100, 68, 38), CastShadow = true }, lobby)
		end
	end

	-- Арка-вывеска над входом на пирс: название мира (ставит клиент) и стрелка к старту
	for _, sx in { -1, 1 } do
		part("Part", { Size = Vector3.new(1.6, 15, 1.6), CFrame = base * CFrame.new(sx * 8.6, 7.5, -4), Material = Enum.Material.Wood, Color = Color3.fromRGB(120, 80, 45) }, lobby)
		deco({ Shape = Enum.PartType.Ball, Size = Vector3.one * 2.2, CFrame = base * CFrame.new(sx * 8.6, 15.6, -4), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 215, 80) }, lobby)
	end
	local beam = part("Part", { Name = "ArchBeam", Size = Vector3.new(21, 4.2, 1.2), CFrame = base * CFrame.new(0, 15.5, -4), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(95, 60, 35) }, lobby)
	deco({ Size = Vector3.new(21.6, 0.8, 2), CFrame = base * CFrame.new(0, 17.9, -4), Material = Enum.Material.Snow, Color = SNOW }, lobby)
	archSign(beam, "▼ СТАРТ ▼")
	Props.garland((base * CFrame.new(-8.6, 13, -4)).Position, (base * CFrame.new(8.6, 13, -4)).Position, lobby, rng)

	-- Светящаяся стрелка-указатель у края пирса
	local sign = deco({ Size = Vector3.new(1, 1, 1), CFrame = base * CFrame.new(0, 6, -62), Transparency = 1 }, lobby)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(240, 60)
	bb.MaxDistance = 120
	bb.Parent = sign
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(255, 225, 80)
	t.TextStrokeTransparency = 0.2
	t.Text = "▼ САДИСЬ В САНИ ▼"
	t.Parent = bb

	-- Подиумы с витринными санками (цветные зоны под ними — читаются со спавна)
	zoneDisc(base * CFrame.new(-24, 0, -24), 9, Color3.fromRGB(255, 200, 60), lobby)
	zoneDisc(base * CFrame.new(24, 0, -24), 9, Color3.fromRGB(170, 110, 255), lobby)
	showcaseSled(base * CFrame.new(-24, 0, -24), "board", 2, "Доска · Gold", lobby)
	showcaseSled(base * CFrame.new(24, 0, -24), "plane", 5, "Сани-самолёт · Galaxy", lobby)

	-- Доска лидеров и табло обновления (лицом к точке появления)
	local lbAt = CFrame.lookAt((base * CFrame.new(34, 0, -10)).Position, p)
	board("Leaderboard", lbAt, "🏆 Неделя", lobby, true)
	local upAt = CFrame.lookAt((base * CFrame.new(-34, 0, -10)).Position, p)
	local upText = board("NextUpdate", upAt, "⏳ Следующее обновление", lobby)
	task.spawn(function()
		while lobby.Parent do
			local left = math.max(0, Config.NEXT_UPDATE - os.time())
			upText.TextXAlignment = Enum.TextXAlignment.Center
			upText.Text = if left > 0
				then string.format("%dд %dч %dм\n\nНовый мир и\nновые санки!", left // 86400, (left % 86400) // 3600, (left % 3600) // 60)
				else "Уже скоро!"
			task.wait(30)
		end
	end)

	-- «Живые» детали: костёр с брёвнами, флаги на ветру (качает клиент)
	zoneDisc(base * CFrame.new(-18, 0, 14), 8, Color3.fromRGB(255, 140, 70), lobby)
	Props.campfire(base * CFrame.new(-18, 0, 14), lobby)
	Props.flagpole(base * CFrame.new(-14, 0, 24), Color3.fromRGB(240, 80, 90), lobby, 18)
	Props.flagpole(base * CFrame.new(14, 0, 24), Color3.fromRGB(80, 180, 240), lobby, 18)
	Props.flagpole(base * CFrame.new(-40, 0, -30), Color3.fromRGB(255, 205, 60), lobby, 14)
	Props.flagpole(base * CFrame.new(40, 0, -30), Color3.fromRGB(110, 210, 120), lobby, 14)

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(p + Vector3.new(0, 0.5, 0))
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = lobby
	lobby.Parent = workspace
end

-- Декор лобби по миру (клиент, у каждого свой): деревья/кактусы/кристаллы по периметру,
-- акцентный объект справа от спавна, горы на горизонте, небо (сияние, шары).
-- Возвращает цвет и материал земли лобби для этой темы.
function Lobby.dress(theme: number, parent: Instance): (Color3, Enum.Material)
	local base = CFrame.new(Config.LOBBY_POS)
	local rng = Random.new(7 + theme)
	local themeCfg = Config.THEMES[theme] or Config.THEMES[1]
	-- Точки периметра: задний ряд (z=+46) и боковые ряды (x=±66) — не ближе 12 studs к табло и подиумам
	local spots: { CFrame } = {}
	for x = -70, 70, 17.5 do
		table.insert(spots, base * CFrame.new(x + rng:NextNumber(-3, 3), 0, 46 + rng:NextNumber(-3, 1)))
	end
	for z = -34, 36, 17.5 do
		for _, x in { -66, 66 } do
			table.insert(spots, base * CFrame.new(x + rng:NextNumber(-3, 3), 0, z + rng:NextNumber(-3, 3)))
		end
	end
	-- Вторая линия — реже и ближе
	local inner = { base * CFrame.new(-50, 0, 32), base * CFrame.new(50, 0, 32), base * CFrame.new(-54, 0, -36), base * CFrame.new(54, 0, -36), base * CFrame.new(-30, 0, 40), base * CFrame.new(30, 0, 40) }
	local accent = base * CFrame.new(18, 0, 14) * CFrame.Angles(0, math.rad(-150), 0) -- напротив костра, лицом к спавну
	local function far(x: number, z: number): CFrame
		return base * CFrame.new(x, 0, z)
	end

	local groundColor, groundMat = SNOW, Enum.Material.Snow
	if theme == 2 then
		-- Ледяной город: дома в заднем ряду, фонари по бокам, высотки за домами, остановка
		for _, s in spots do
			local rel = base:PointToObjectSpace(s.Position)
			if rel.Z > 40 then
				Props.house(rng, s * CFrame.Angles(0, math.rad(-90), 0), 1, rng:NextNumber(14, 20), parent)
			elseif math.abs(rel.X) > 60 then
				Props.streetLamp(s * CFrame.Angles(0, if rel.X > 0 then math.rad(180) else 0, 0), 1, parent)
			end
		end
		for _, x in { -40, 10, 55 } do
			Props.tower(rng, far(x, 95) * CFrame.Angles(0, math.rad(-90), 0), 1, parent)
		end
		Props.busStop(accent, parent)
		Props.hydrant(accent * CFrame.new(5, 0, 2), parent)
		Props.car(rng, far(-46, 30) * CFrame.Angles(0, math.rad(20), 0), parent)
	elseif theme == 3 then
		-- Каньон: акации и кактусы, мезы на горизонте, ветряк и водонапорная башня
		for _, s in spots do
			if rng:NextNumber() < 0.5 then
				Props.acacia(rng, s, parent)
			else
				Props.cactus(rng, s, parent)
			end
		end
		for _, x in { -110, 20, 120 } do
			Props.mesa(rng, far(x, 120 + rng:NextNumber(0, 30)), 1, parent)
		end
		Props.windmill(far(52, 30), 1, parent)
		Props.waterTower(far(-52, 30), parent)
		Props.cactus(rng, accent, parent)
		Props.signpost(rng, accent * CFrame.new(5, 0, 0), parent)
		groundColor, groundMat = themeCfg.ground, Enum.Material.Sand
	elseif theme == 4 then
		-- Ледяные пещеры: ледяные скалы сзади, сталагмиты и кристаллы по бокам
		for _, s in spots do
			local rel = base:PointToObjectSpace(s.Position)
			if rel.Z > 40 then
				if rng:NextNumber() < 0.5 then
					Props.iceCliff(rng, s, 1, parent)
				else
					Props.stalagmite(rng, s, parent, false)
				end
			elseif rng:NextNumber() < 0.5 then
				Props.crystalCluster(rng, s, parent)
			else
				Props.stalagmite(rng, s, parent, false)
			end
		end
		for _, c in inner do
			Props.crystalCluster(rng, c, parent)
		end
		Props.crystalCluster(rng, accent, parent)
		groundColor = themeCfg.ground
	elseif theme == 5 then
		-- Северное сияние: редкие ёлки, фонари, иглу, ленты сияния в небе
		for i, s in spots do
			if i % 3 == 0 then
				Props.lantern(s, parent)
			elseif rng:NextNumber() < 0.6 then
				Props.pine(rng, s, parent)
			end
		end
		Props.igloo(rng, far(-48, 32), parent)
		Props.igloo(rng, accent, parent)
		for k = -1, 1 do
			Props.aurora(rng, far(k * 120, 160) * CFrame.new(0, 125, 0), parent)
		end
	elseif theme == 6 then
		-- Снежный вулкан: базальт и обгоревшие деревья, лавовые озёра, вулкан на горизонте
		for _, s in spots do
			if rng:NextNumber() < 0.5 then
				Props.basalt(rng, s, parent, false)
			else
				Props.charredTree(rng, s, parent)
			end
		end
		Props.lavaPool(rng, far(-50, 34), parent)
		Props.lavaPool(rng, far(52, -34), parent)
		Props.volcano(rng, far(40, 230), parent)
		Props.lavaRock(rng, accent, parent)
		groundColor, groundMat = themeCfg.ground, Enum.Material.Basalt
	elseif theme == 7 then
		-- Конфетная гора: леденцовые трости и леденцы, пряничный домик, мармеладки
		for _, s in spots do
			if rng:NextNumber() < 0.5 then
				Props.candyCane(rng, s, parent)
			else
				Props.lollipop(rng, s, parent)
			end
		end
		Props.gingerHouse(rng, far(-48, 36) * CFrame.Angles(0, math.rad(-90), 0), 1, parent)
		for k = 0, 2 do
			Props.gumdrop(rng, accent * CFrame.new(k * 3 - 3, 0, (k % 2) * 2), parent)
		end
		Props.cupcake(rng, accent * CFrame.new(0, 0, -4), parent)
		groundColor = themeCfg.ground
	else
		-- Снежный лес: ёлки и акации, снеговик, хижина
		for _, s in spots do
			if rng:NextNumber() < 0.65 then
				Props.pine(rng, s, parent)
			else
				Props.acacia(rng, s, parent)
			end
		end
		for _, c in inner do
			if rng:NextNumber() < 0.6 then
				Props.pine(rng, c, parent)
			end
		end
		Props.cabin(rng, far(-50, 36) * CFrame.Angles(0, math.rad(-90), 0), 1, parent)
		Props.snowman(rng, accent, parent)
	end
	-- Воздушные шары над лобби (лес, каньон, конфетная гора)
	if theme == 1 or theme == 3 or theme == 7 then
		Props.balloon(rng, far(-60, 70) * CFrame.new(0, 55, 0), parent)
		Props.balloon(rng, far(70, 90) * CFrame.new(0, 70, 0), parent)
	end
	-- Горы на горизонте
	local tint = ({ [4] = Color3.fromRGB(150, 200, 235), [5] = Color3.fromRGB(70, 85, 120), [6] = Color3.fromRGB(60, 56, 62), [7] = Color3.fromRGB(235, 160, 210) })[theme]
	for _, x in { -170, -40, 90, 200 } do
		Props.mountain(rng, far(x + rng:NextNumber(-20, 20), 210 + rng:NextNumber(0, 60)), theme == 3, parent, tint)
	end
	return groundColor, groundMat
end


return Lobby
