-- Лобби: стартовый хаб. Сервер строит общую «архитектуру» (Lobby.build + Lobby.furnish), клиент
-- одевает её под свой текущий мир (Lobby.dress) и ставит витрину саней на подиумы
-- (Lobby.showcase) — см. client/LobbyScene. Чистая геометрия: Part/меши, Config, Props,
-- SledModels; серверных сервисов нет, модуль общий.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Props = require(ReplicatedStorage.Shared.Props)
local SledModels = require(ReplicatedStorage.Shared.SledModels)
local Meshes = require(ReplicatedStorage.Shared.Meshes)
local LobbyPodium = require(ReplicatedStorage.Shared.LobbyPodium)

local part, deco = Props.part, Props.deco
local SNOW = Color3.fromRGB(250, 252, 255)

local Lobby = {}

-- Чертёж лобби (studs от Config.LOBBY_POS; x вправо, −Z — к обрыву и трассе). Его же читает
-- макет-рендер scripts/ui_layout_preview.py: проецирует путь, ворота, подиумы, табло камерой спавна
-- (Config.LOBBY_CAM_PITCH) поверх раскладки UI и проверяет, что их не закрывают плашки.
--
-- Станции стоят ПО КРУГУ (#69, владелец 2026-11-12): эллипс hub — центр (0, 4), полуоси 54 × 36,
-- угол от направления на старт (−Z), по часовой. Все лицом к спавну; между соседями ≥ 4 studs по
-- краям зон, середина (плита-хаб ⌀30 и ~20 studs вокруг неё) свободна — игроку есть где бегать.
-- Декор мира (Lobby.dress) ставится только снаружи кольца и не ближе 3 studs к станциям (Lobby.free).
--
--                              задник: Terrain-скалы z +56…+96, утёсы-меши мира
--     180° акцент мира (0, 40)          ±170° флаги
--   −155° КОСТЁР + палатка (−22.8, 36.6)          +155° ЛАВКА «САНИ» (22.8, 36.6) → окно саней
--  −125° ПОРТАЛ «МИРЫ» (−44.2, 24.6) → окно миров       +125° ПЬЕДЕСТАЛ ТОП-3 (44.2, 24.6)
--                      ◎ ПЛИТА-ХАБ ⌀30, спавн z=0 лицом к −Z
--  −78° ТАБЛО «обновление» (−52.8, −3.5)                +78° ТАБЛО «неделя» (52.8, −3.5)
--     −25° ПОДИУМ витрина (−22.8, −28.6)   ║ дорожка ║   +25° ПОДИУМ «мечта» (22.8, −28.6)
--                     флаги (±14, −35) обрамляют ворота
--   z=−38.5   ╔══ 0° ВОРОТА СТАРТА · вывеска «МИР ▼ СТАРТ» ══╗
--   z=−40   ─────── край площадки: Terrain-обрыв вниз ───────
--   z=−39…−61       ║ мостик 14 wide, перила, гирлянды ║ → ◯ кольцо посадки + МАЯК z=−63
--   фонари-«виселицы» между станциями: ±58°, ±100°, ±140°; дорожка-кольцо (эллипс 42 × 25)
--
-- Камера спавна (client/LobbyScene): сзади-сверху, наклон LOBBY_CAM_PITCH и зум LOBBY_CAM_ZOOM.
-- Записи: пары/тройки чисел; lamps/flags — плоские списки x, z.
Lobby.PLAN = {
	plaza = { 0, 2, 15 }, -- центр x, z, радиус плиты-хаба
	hub = { 0, 4, 54, 36 }, -- эллипс станций: центр x, z, полуоси x, z
	walk = { 42, 25, 4 }, -- дорожка-кольцо: полуоси x, z, ширина (центр — как у hub)
	path = { 0, -12, -38, 5 }, -- дорожка: x, z от, z до, полуширина
	gate = { 0, -38.5, 7.6 }, -- ворота: x, z, высота центра вывески
	pier = { 0, -39, -61, 7 }, -- мостик: x, z от, z до, полуширина
	ring = { 0, -63, 6 }, -- кольцо посадки (как LaunchRing в server/Runs)
	beacon = { 0, -63, 26 }, -- маяк старта: столб света над кольцом, x, z, высота
	podiumL = { -22.8, -28.6, 6.5 }, -- x, z, радиус (±25° кольца: в кадре спавна, не под плитками UI)
	podiumR = { 22.8, -28.6, 6.5 },
	boardL = { -52.8, -3.5 },
	boardR = { 52.8, -3.5 },
	-- пьедестал топ-3 недели (#48): центр x, z, ширина ступени, масштаб аватаров
	top3 = { 44.2, 24.6, 5.6, 1.25 },
	top3H = { 4, 2.8, 1.8 }, -- высота ступеней 1, 2, 3 места (2 — слева, 1 — центр, 3 — справа)
	portal = { -44.2, 24.6 }, -- портал «Миры» (#69)
	stall = { 22.8, 36.6 }, -- лавка «Сани» (#69)
	fire = { -22.8, 36.6 },
	tent = { -29, 42 }, -- палатка за костром
	accent = { 0, 40 },
	flags = { -14, -35, 14, -35, -9.4, 39.5, 9.4, 39.5 },
	lamps = { -7.5, -8, 7.5, -8, -7.5, -28, 7.5, -28, -8.2, -51, 8.2, -51 },
	ringLamps = { -45.8, -15.1, 45.8, -15.1, -53.2, 10.3, 53.2, 10.3, -34.7, 31.6, 34.7, 31.6 },
}
-- Занятые места (центр x, z, радиус зоны) — для Lobby.free: декор мира сюда не ставится
Lobby.STATIONS = {
	{ PLAN_KEY = "plaza", r = 15 },
	{ PLAN_KEY = "podiumL", r = 9 },
	{ PLAN_KEY = "podiumR", r = 9 },
	{ PLAN_KEY = "boardL", r = 11 },
	{ PLAN_KEY = "boardR", r = 11 },
	{ PLAN_KEY = "top3", r = 10 },
	{ PLAN_KEY = "portal", r = 9 },
	{ PLAN_KEY = "stall", r = 8 },
	{ PLAN_KEY = "fire", r = 9 },
	{ PLAN_KEY = "tent", r = 6 },
	{ PLAN_KEY = "accent", r = 6 },
	{ PLAN_KEY = "gate", r = 12 },
}
local PLAN = Lobby.PLAN

-- Свободна ли точка (x, z — studs от LOBBY_POS) для декора радиуса r: снаружи дорожки-кольца
-- (всё внутри кольца — место игрока) и не ближе 3 studs к зонам станций
function Lobby.free(x: number, z: number, r: number): boolean
	local hx, hz = PLAN.hub[1], PLAN.hub[2]
	local ex, ez = (x - hx) / (PLAN.walk[1] + PLAN.walk[3] + r), (z - hz) / (PLAN.walk[2] + PLAN.walk[3] + r)
	if ex * ex + ez * ez < 1 then
		return false
	end
	for _, st in Lobby.STATIONS do
		local c = PLAN[st.PLAN_KEY]
		local dx, dz = x - c[1], z - c[2]
		if dx * dx + dz * dz < (st.r + r + 3) ^ 2 then
			return false
		end
	end
	return true
end

-- Точку внутри кольца или на станции отодвинуть наружу по лучу от центра кольца (для «крупного»
-- декора мира с фиксированным местом: машина, ветряк, башня); дальние точки не трогает
function Lobby.pushOut(x: number, z: number, r: number): (number, number)
	local hx, hz = PLAN.hub[1], PLAN.hub[2]
	local k = 1
	while k < 3 and not Lobby.free(hx + (x - hx) * k, hz + (z - hz) * k, r) do
		k += 0.05
	end
	return hx + (x - hx) * k, hz + (z - hz) * k
end
-- Меши архитектуры: сервер ждёт их загрузки (MeshAssets) перед Lobby.furnish, но не дольше
Lobby.MESHES = { "lamp_post", "podium", "board_frame", "start_gate" }
Lobby.MESH_WAIT = 15

local function at(base: CFrame, xz: { number }, i: number?): CFrame
	local k = i or 1
	return base * CFrame.new(xz[k], 0, xz[k + 1])
end

-- Табло: рама (меш) + доска с SurfaceGui в проёме 18 × 10 на высоте 6–16.
-- footer — строка «ты: место · очки · сброс» внизу (табло недели, заполняет client/WeeklyBoard)
local function board(name: string, at0: CFrame, title: string, parent: Instance, footer: boolean?): TextLabel
	local m = Instance.new("Model")
	m.Name = name
	Props.boardFrame(at0, m)
	local panel = part("Part", { Size = Vector3.new(18, 10, 0.6), CFrame = at0 * CFrame.new(0, 11, 0), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(95, 60, 35) }, m)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.CanvasSize = Vector2.new(600, 333)
	sg.LightInfluence = 0.3
	sg.Parent = panel
	local head = Instance.new("TextLabel")
	head.Name = "Head"
	head.BackgroundTransparency = 1
	head.Size = UDim2.new(1, 0, 0, 64)
	head.Font = Enum.Font.FredokaOne
	head.TextScaled = true
	head.TextColor3 = Color3.fromRGB(255, 220, 90)
	head.Text = title
	head.Parent = sg
	local body = Instance.new("TextLabel")
	body.Name = "List"
	body.BackgroundTransparency = 1
	body.Position = UDim2.new(0, 30, 0, 70)
	body.Size = UDim2.new(1, -60, 1, if footer then -128 else -84)
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
		me.Position = UDim2.new(0, 20, 1, -54)
		me.Size = UDim2.new(1, -40, 0, 46)
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

-- Вывеска на воротах старта: текст меняет клиент (название мира игрока)
local function gateSign(plate: BasePart, text: string, face: Enum.NormalId?): TextLabel
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Sign"
	sg.Face = face or Enum.NormalId.Back -- ворота: смотрит на спавн (+Z лобби); станции кольца — Front
	sg.CanvasSize = Vector2.new(650, 120)
	sg.LightInfluence = 0.2
	sg.Parent = plate
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

-- Подпись над объектом (BillboardGui): видна издалека, не дальше maxDist
local function billboard(anchorCF: CFrame, text: string, size: Vector2, maxDist: number, color: Color3, parent: Instance): TextLabel
	local anchor = deco({ Size = Vector3.one, CFrame = anchorCF, Transparency = 1 }, parent)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(size.X, size.Y)
	bb.MaxDistance = maxDist
	bb.Parent = anchor
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = color
	t.TextStrokeTransparency = 0.2
	t.Text = text
	t.Parent = bb
	return t
end

-- Цветной «кружок-зона» на земле под объектом: читается с точки спавна
local function zoneDisc(at0: CFrame, r: number, color: Color3, parent: Instance)
	deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, r * 2, r * 2), CFrame = at0 * CFrame.new(0, 0.12, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = color, Transparency = 0.25 }, parent)
	deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, r * 2 + 1.2, r * 2 + 1.2), CFrame = at0 * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Neon, Color = color:Lerp(Color3.new(1, 1, 1), 0.3), Transparency = 0.55 }, parent)
end

-- Terrain: скальный массив под площадкой (площадка — вершина горы, а не плита в небе: обрыв виден
-- с мостика) и гряда за спиной спавна (задник; клиент ставит на неё утёсы-меши цвета мира).
-- Только z ≥ −38 выше y −8: под мостиком и витринной трассой (z ≤ −40) пусто. Только сервер.
local function terrain(base: CFrame)
	local t = workspace.Terrain
	if not t then
		return
	end
	local rock = Enum.Material.Rock
	t:FillBlock(base * CFrame.new(0, -26, 6), Vector3.new(144, 44, 84), rock)
	local rng = Random.new(11)
	-- рваные края массива: валы по периметру ниже кромки
	for x = -66, 66, 22 do
		t:FillBall((base * CFrame.new(x + rng:NextNumber(-4, 4), -24 + rng:NextNumber(-6, 4), 46)).Position, rng:NextNumber(12, 16), rock)
		if math.abs(x) > 14 then -- перед мостиком массив не выступает
			t:FillBall((base * CFrame.new(x + rng:NextNumber(-4, 4), -22 + rng:NextNumber(-6, 2), -33)).Position, rng:NextNumber(10, 13), rock)
		end
	end
	for z = -24, 36, 20 do
		for _, sx in { -1, 1 } do
			t:FillBall((base * CFrame.new(sx * 70, -22 + rng:NextNumber(-6, 4), z + rng:NextNumber(-4, 4))).Position, rng:NextNumber(12, 16), rock)
		end
	end
	-- гряда за спиной: верх до y ≈ +22 — закрывает пустое небо сзади
	for x = -96, 96, 24 do
		local c = base * CFrame.new(x + rng:NextNumber(-5, 5), rng:NextNumber(-10, -2), 74 + rng:NextNumber(-6, 10))
		t:FillBall(c.Position, rng:NextNumber(20, 28), rock)
	end
end

-- Лобби (сервер), шаг 1 — то, без чего нельзя войти: земля, плита-хаб, дорожка, мостик, точка
-- появления, Terrain. Шаг 2 (Lobby.furnish) — мебель из мешей: ворота, фонари, подиумы, табло,
-- флаги, костёр; запускается, когда меши загружены (или через MESH_WAIT с фолбэком из Part).
function Lobby.build()
	local p = Config.LOBBY_POS
	local base = CFrame.new(p)
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"
	-- Площадка лобби заканчивается обрывом (z −40): дальше вниз уходит трасса (её видно с мостика)
	part("Part", {
		Name = "LobbyGround",
		Size = Vector3.new(150, 4, 90),
		CFrame = base * CFrame.new(0, -2, 5),
		Material = Enum.Material.Snow,
		Color = SNOW,
	}, lobby)
	-- Плита-хаб спавна: каменный круг, тонкое неоновое кольцо цвета мира (ставит клиент) и
	-- стрелка-шеврон к дорожке — путь «спавн → ворота → мостик» читается с первого кадра
	local px, pz, pr = PLAN.plaza[1], PLAN.plaza[2], PLAN.plaza[3]
	part("Part", { Name = "Plaza", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, pr * 2, pr * 2), CFrame = base * CFrame.new(px, 0.2, pz) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Slate, Color = Color3.fromRGB(150, 160, 180) }, lobby)
	deco({ Name = "PlazaRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, pr * 2 + 1, pr * 2 + 1), CFrame = base * CFrame.new(px, 0.2, pz) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Neon, Color = Color3.fromRGB(120, 220, 255), Transparency = 0.5 }, lobby)
	deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.52, pr * 1.2, pr * 1.2), CFrame = base * CFrame.new(px, 0.22, pz) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Slate, Color = Color3.fromRGB(120, 130, 152) }, lobby)
	-- Дорожка-плитка от хаба до ворот (одна плита + бордюры) и шевроны к старту
	local pathX, z0, z1, hw = PLAN.path[1], PLAN.path[2], PLAN.path[3], PLAN.path[4]
	local len = z0 - z1
	part("Part", { Name = "Path", Size = Vector3.new(hw * 2, 0.5, len + 4), CFrame = base * CFrame.new(pathX, 0.2, (z0 + z1) / 2 + 2), Material = Enum.Material.Slate, Color = Color3.fromRGB(140, 150, 172) }, lobby)
	for _, sx in { -1, 1 } do
		deco({ Size = Vector3.new(0.8, 0.7, len + 4), CFrame = base * CFrame.new(pathX + sx * (hw + 0.2), 0.3, (z0 + z1) / 2 + 2), Material = Enum.Material.Slate, Color = Color3.fromRGB(105, 112, 130) }, lobby)
	end
	for z = pz - pr + 6, z1 + 3, -7 do
		deco({ Size = Vector3.new(3.6, 0.08, 1.8), CFrame = base * CFrame.new(pathX, 0.5, z), Material = Enum.Material.Neon, Color = Color3.fromRGB(90, 220, 255), Transparency = 0.15 }, lobby, "WedgePart")
	end

	-- Деревянный мостик над обрывом к кольцу посадки (как в Roblox-референсе): дошёл — сел в сани
	local qx, q0, q1, qw = PLAN.pier[1], PLAN.pier[2], PLAN.pier[3], PLAN.pier[4]
	for z = q0, q1, -3 do
		part("Part", { Size = Vector3.new(qw * 2, 0.6, 2.6), CFrame = base * CFrame.new(qx, 0.3, z), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(150, 105, 65) }, lobby)
	end
	for z = q0 - 6, q1 + 3, -8 do
		deco({ Size = Vector3.new(3.4, 0.08, 1.6), CFrame = base * CFrame.new(qx, 0.65, z), Material = Enum.Material.Neon, Color = Color3.fromRGB(90, 220, 255), Transparency = 0.2 }, lobby, "WedgePart")
	end
	for _, sx in { -1, 1 } do
		local rx = qx + sx * (qw + 0.4)
		deco({ Size = Vector3.new(0.8, 1, q0 - q1), CFrame = base * CFrame.new(rx, 1.2, (q0 + q1) / 2), Material = Enum.Material.Wood, Color = Color3.fromRGB(110, 75, 40) }, lobby)
		for z = q0, q1, -8 do
			deco({ Size = Vector3.new(0.6, 2, 0.6), CFrame = base * CFrame.new(rx, 1, z), Material = Enum.Material.Wood, Color = Color3.fromRGB(110, 75, 40) }, lobby)
		end
		-- опоры над обрывом
		for _, z in { -46, -58 } do
			deco({ Size = Vector3.new(1.2, 30, 1.2), CFrame = base * CFrame.new(qx + sx * (qw - 1), -15, z), Material = Enum.Material.Wood, Color = Color3.fromRGB(100, 68, 38), CastShadow = true }, lobby)
		end
	end
	-- Маяк старта: полупрозрачный столб света над кольцом посадки — ориентир «куда идти», виден
	-- над головой аватара с камеры спавна (макет scripts/ui_layout_preview.py); надпись под ним
	local bx, bz, bh = PLAN.beacon[1], PLAN.beacon[2], PLAN.beacon[3]
	deco({ Name = "StartBeacon", Shape = Enum.PartType.Cylinder, Size = Vector3.new(bh, 2.8, 2.8), CFrame = base * CFrame.new(bx, 0.6 + bh / 2, bz) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Neon, Color = Color3.fromRGB(120, 235, 255), Transparency = 0.6 }, lobby)
	local rx, rz = PLAN.ring[1], PLAN.ring[2]
	billboard(base * CFrame.new(rx, 6, rz + 1), "▼ САДИСЬ В САНИ ▼", Vector2.new(240, 60), 120, Color3.fromRGB(255, 225, 80), lobby)

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
	terrain(base)
	-- мебель — когда меши загружены (MeshAssets.server кладёт шаблоны асинхронно)
	task.spawn(function()
		Meshes.waitFor(Lobby.MESHES, Lobby.MESH_WAIT)
		Lobby.furnish(lobby)
	end)
	return lobby
end

-- Лобби (сервер), шаг 2: мебель. Повторный вызов ничего не делает.
function Lobby.furnish(lobby: Instance)
	if lobby:GetAttribute("Furnished") then
		return
	end
	lobby:SetAttribute("Furnished", true)
	local p = Config.LOBBY_POS
	local base = CFrame.new(p)
	local rng = Random.new(7)
	local furniture = Instance.new("Model")
	furniture.Name = "Furniture"

	-- Ворота старта у входа на мостик: вывеска «МИР ▼ СТАРТ» (текст ставит клиент), гирлянда
	local gate = base * CFrame.new(PLAN.gate[1], 0, PLAN.gate[2])
	local plate = Props.startGate(gate, lobby)
	gateSign(plate, "▼ СТАРТ ▼")
	Props.garland((gate * CFrame.new(-9.5, 12.6, 0.4)).Position, (gate * CFrame.new(9.5, 12.6, 0.4)).Position, furniture, rng)
	-- Гирлянды вдоль перил мостика
	local qx, q0, q1, qw = PLAN.pier[1], PLAN.pier[2], PLAN.pier[3], PLAN.pier[4]
	for _, sx in { -1, 1 } do
		local rx = qx + sx * (qw + 0.4)
		Props.garland((base * CFrame.new(rx, 7, q0 - 1)).Position, (base * CFrame.new(rx, 7, q1 - 1)).Position, furniture, rng)
	end
	-- Фонари: вдоль дорожки и на мостике (ритм «ведущих линий» к воротам); у станций — PLAN.ringLamps
	local lamps = PLAN.lamps
	for i = 1, #lamps, 2 do
		Props.lampPost(at(base, lamps, i), furniture)
	end

	-- Подиумы витрин: зона-круг цвета редкости, ступенчатый подиум, прожектор, подпись (клиент
	-- ставит сани и меняет подпись — Lobby.showcase)
	for _, side in { { "PodiumL", PLAN.podiumL, Color3.fromRGB(255, 200, 60) }, { "PodiumR", PLAN.podiumR, Color3.fromRGB(170, 110, 255) } } do
		local m = Instance.new("Model")
		m.Name = side[1]
		local spot = at(base, side[2])
		zoneDisc(spot, side[2][3] + 2, side[3], m)
		local top = Props.podium(spot, side[2][3], side[3], m)
		m:SetAttribute("Top", top)
		billboard(top * CFrame.new(0, 7.5, 0), "", Vector2.new(260, 56), 90, Color3.new(1, 1, 1), m)
		m.Parent = lobby
	end

	-- Табло лицом к точке появления: справа — лидеры (неделя → чистые финиши → всё время,
	-- client/WeeklyBoard), слева — обратный отсчёт до обновления (сезонность: «новый мир скоро»)
	local function facing(xz: { number }): CFrame
		return CFrame.lookAt((base * CFrame.new(xz[1], 0, xz[2])).Position, p)
	end
	board("Leaderboard", facing(PLAN.boardR), "🏆 Неделя", lobby, true)
	-- правее табло — пьедестал топ-3 недели (аватары — server/Podium)
	LobbyPodium.build(base, PLAN, lobby)
	local upText = board("NextUpdate", facing(PLAN.boardL), "⏳ Следующее обновление", lobby)
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

	-- «Живые» детали: костёр с брёвнами за спиной спавна, флаги на ветру (качает клиент):
	-- пара у ворот обрамляет мостик, пара у костра
	local fire = at(base, PLAN.fire)
	zoneDisc(fire, 8, Color3.fromRGB(255, 140, 70), furniture)
	Props.campfire(fire, furniture)
	-- Станции по кругу (#69): лицом к спавну; палатка за костром, портал «Миры», лавка «Сани»
	local function facingSpawn(xz: { number }): CFrame
		local pos = (base * CFrame.new(xz[1], 0, xz[2])).Position
		return CFrame.lookAt(pos, Vector3.new(p.X, pos.Y, p.Z))
	end
	Props.tent(facingSpawn(PLAN.tent) * CFrame.Angles(0, math.rad(90), 0), furniture)
	local portalM = Instance.new("Model")
	portalM.Name = "WorldPortal"
	gateSign(Props.worldPortal(facingSpawn(PLAN.portal), portalM), "🌍 МИРЫ", Enum.NormalId.Front)
	zoneDisc(facingSpawn(PLAN.portal) * CFrame.new(0, 0, -3), 6, Color3.fromRGB(255, 205, 60), portalM)
	portalM.Parent = lobby
	local stallM = Instance.new("Model")
	stallM.Name = "SledStall"
	gateSign(Props.shopStall(facingSpawn(PLAN.stall), stallM), "🛷 САНИ", Enum.NormalId.Front)
	zoneDisc(facingSpawn(PLAN.stall) * CFrame.new(0, 0, -5.5), 5, Color3.fromRGB(120, 220, 255), stallM)
	stallM.Parent = lobby
	-- фонари-«виселицы» между станциями, фонарём к центру
	local rl = PLAN.ringLamps
	for i = 1, #rl, 2 do
		Props.hangLamp(facingSpawn({ rl[i], rl[i + 1] }), furniture)
	end
	-- дорожка-кольцо: граница «места игрока» и путь от станции к станции
	local wx, wz, ww = PLAN.walk[1], PLAN.walk[2], PLAN.walk[3]
	local n = 56
	for k = 0, n - 1 do
		local a0, a1 = 2 * math.pi * k / n, 2 * math.pi * (k + 1) / n
		local x0, z0 = PLAN.hub[1] + math.sin(a0) * wx, PLAN.hub[2] - math.cos(a0) * wz
		local x1, z1 = PLAN.hub[1] + math.sin(a1) * wx, PLAN.hub[2] - math.cos(a1) * wz
		local dx, dz = x1 - x0, z1 - z0
		if math.abs((x0 + x1) / 2 - PLAN.path[1]) > PLAN.path[4] + 2 or (z0 + z1) / 2 > PLAN.path[2] then
			deco({ Size = Vector3.new(ww, 0.3, math.sqrt(dx * dx + dz * dz) + 0.6), CFrame = base * CFrame.new((x0 + x1) / 2, 0.08, (z0 + z1) / 2) * CFrame.Angles(0, math.atan2(-dx, -dz), 0), Material = Enum.Material.Slate, Color = Color3.fromRGB(165, 172, 190) }, furniture)
		end
	end
	local flagCols = { Color3.fromRGB(240, 80, 90), Color3.fromRGB(80, 180, 240), Color3.fromRGB(255, 205, 60), Color3.fromRGB(110, 210, 120) }
	local flags = PLAN.flags
	for i = 1, #flags, 2 do
		local k = (i + 1) // 2
		local f = at(base, flags, i)
		-- флаг у ворот смотрит наружу (полотнище не лезет в проход)
		if flags[i + 1] < 0 and flags[i] < 0 then
			f *= CFrame.Angles(0, math.pi, 0)
		end
		Props.flagpole(f, flagCols[k], furniture, if k <= 2 then 15 else 18)
	end
	furniture.Parent = lobby
end

-- Витрина саней на подиуме (клиент, у каждого свой): модель в редкости, прокачанная, медленно
-- вращается (client/LobbyScene вращает holder целиком через BulkMoveTo). Возвращает holder.
function Lobby.showcase(podium: Instance, sledId: string, rarityIdx: number, caption: string, parent: Instance): Model?
	local top = podium:GetAttribute("Top") :: CFrame?
	if not top then
		return nil
	end
	local rarity = Config.RARITIES[rarityIdx] or Config.RARITIES[1]
	local model = Config.SLEDS[1]
	for _, m in Config.SLEDS do
		if m.id == sledId then
			model = m
		end
	end
	local col = rarity.color or model.main
	local accent = if rarity.color then Color3.new(1, 1, 1):Lerp(col, 0.35) else model.accent
	local holder = Instance.new("Model")
	holder.Name = "Showcase"
	local showCF = top * CFrame.new(0, 1.6, 0) * CFrame.Angles(math.rad(-8), 0, 0)
	SledModels.build(holder, showCF, sledId, {
		main = col,
		accent = accent,
		material = rarity.material,
		glow = rarityIdx == 5,
		shine = rarity.shine,
	}, nil, true)
	SledModels.extras(holder, showCF, sledId, 4, if rarityIdx == 5 then 5 else 3, accent, nil)
	holder:SetAttribute("Pivot", top * CFrame.new(0, 1.6, 0)) -- ось вращения — вертикаль подиума
	holder.Parent = parent
	local text = podium:FindFirstChildWhichIsA("TextLabel", true)
	if text then
		text.Text = caption
	end
	return holder
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
	-- станции стоят по кругу (#69): декор — только в свободных местах (Lobby.free)
	local function keepFree(list: { CFrame }, r: number): { CFrame }
		local out = {}
		for _, c in list do
			local rel = base:PointToObjectSpace(c.Position)
			if Lobby.free(rel.X, rel.Z, r) then
				table.insert(out, c)
			end
		end
		return out
	end
	spots = keepFree(spots, 5)
	inner = keepFree(inner, 6)
	local accentPos = (base * CFrame.new(PLAN.accent[1], 0, PLAN.accent[2])).Position
	local accent = CFrame.lookAt(accentPos, Vector3.new(base.X, accentPos.Y, base.Z)) -- 180° кольца, лицом к спавну
	local function far(x: number, z: number): CFrame
		if z < 60 then -- крупный декор у площадки — снаружи кольца станций
			x, z = Lobby.pushOut(x, z, 8)
		end
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
				Props.lampPost(s, parent)
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
		Props.lavaPool(rng, far(-62, 45), parent)
		Props.lavaPool(rng, far(65, 46), parent)
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
	-- Задник за спиной спавна: утёсы-меши на гряде Terrain (Lobby.build) в цвете и материале мира
	if Meshes.has("crag") then
		local crag = ({ [3] = Color3.fromRGB(205, 145, 100), [4] = Color3.fromRGB(165, 210, 240), [5] = Color3.fromRGB(85, 95, 130), [6] = Color3.fromRGB(62, 58, 66), [7] = Color3.fromRGB(240, 175, 215) })[theme]
			or Color3.fromRGB(125, 138, 160)
		local mat = ({ [3] = Enum.Material.Sandstone, [4] = Enum.Material.Glacier, [6] = Enum.Material.Basalt })[theme] or Enum.Material.Slate
		for _, x in { -84, -50, -16, 20, 52, 86 } do
			local sc = rng:NextNumber(7, 10)
			local c = far(x + rng:NextNumber(-6, 6), 62 + rng:NextNumber(0, 12)) * CFrame.new(0, rng:NextNumber(2, 8), 0) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			Meshes.place("crag", c, Vector3.new(sc * 1.4, sc, sc * 1.2), { Material = mat, Color = Meshes.vary(crag, c.Position, 0.08), CastShadow = true }, parent)
		end
	end
	return groundColor, groundMat
end


return Lobby
