-- Пьедестал топ-3 недели в лобби (#48): геометрия (сервер, из Lobby.furnish). Место и размеры —
-- Lobby.PLAN.top3/top3H (их же читает макет scripts/ui_layout_preview.py); аватары — server/Podium,
-- вращение короны — client/LobbyScene. Чистая геометрия, серверных сервисов нет.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Props = require(ReplicatedStorage.Shared.Props)

local part, deco = Props.part, Props.deco

local LobbyPodium = {}

-- Пьедестал топ-3 недели (#48), как в Roblox-симуляторах: три ступени 2-1-3 (1 — в центре и выше),
-- белый мрамор с неоновой кромкой цвета медали, номер места на фасаде, подсветка, зона-круг, корона
-- над 1-м местом (клиент её вращает); отдельной вывески нет — над
-- пьедесталом она попадала под ⚙ (макет), смысл читается по короне и медалям. Аватары ставит server/Podium по
-- атрибутам модели Slot1..3 (CFrame верха ступени, лицом к спавну); пока ступень пуста — «?».
-- Подписи — BillboardGui в studs (не в пикселях): издалека три таблички не наезжают друг на друга.
LobbyPodium.MEDALS = { Color3.fromRGB(255, 205, 60), Color3.fromRGB(205, 215, 230), Color3.fromRGB(215, 135, 70) }
function LobbyPodium.build(base: CFrame, PLAN: any, parent: Instance)
	local tx, tz, tw, sc = PLAN.top3[1], PLAN.top3[2], PLAN.top3[3], PLAN.top3[4]
	local center = (base * CFrame.new(tx, 0, tz)).Position
	local spawnAt = Config.LOBBY_POS
	local cf = CFrame.lookAt(center, Vector3.new(spawnAt.X, center.Y, spawnAt.Z)) -- −Z (фасад) к спавну
	local m = Instance.new("Model")
	m.Name = "Top3"
	m:SetAttribute("Scale", sc)
	-- зона-круг на земле (как у подиумов витрин)
	local r = tw * 1.75
	deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, r * 2, r * 2), CFrame = cf * CFrame.new(0, 0.12, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = LobbyPodium.MEDALS[1], Transparency = 0.25 }, m)
	deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, r * 2 + 1.2, r * 2 + 1.2), CFrame = cf * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Neon, Color = LobbyPodium.MEDALS[1]:Lerp(Color3.new(1, 1, 1), 0.3), Transparency = 0.55 }, m)
	-- общий цоколь
	part("Part", { Name = "Plinth", Size = Vector3.new(tw * 3 + 1.2, 0.5, 5.2), CFrame = cf * CFrame.new(0, 0.25, 0), Material = Enum.Material.Slate, Color = Color3.fromRGB(120, 130, 150) }, m)
	for place, lx in { 0, -tw, tw } do
		local h = PLAN.top3H[place]
		local medal = LobbyPodium.MEDALS[place]
		local step = part("Part", {
			Name = "Step" .. place,
			Size = Vector3.new(tw - 0.15, h, 4.2),
			CFrame = cf * CFrame.new(lx, 0.5 + h / 2, 0),
			Material = Enum.Material.Marble,
			Color = Color3.fromRGB(240, 244, 250),
			CastShadow = true,
		}, m)
		-- неоновая кромка по верхнему краю фасада и полоса цвета медали по низу
		deco({ Size = Vector3.new(tw - 0.1, 0.22, 0.22), CFrame = cf * CFrame.new(lx, 0.5 + h - 0.11, -2.12), Material = Enum.Material.Neon, Color = medal }, m)
		deco({ Size = Vector3.new(tw - 0.1, 0.35, 0.1), CFrame = cf * CFrame.new(lx, 0.7, -2.12), Color = medal, Material = Enum.Material.Metal }, m)
		-- номер места на фасаде
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Front
		sg.CanvasSize = Vector2.new(200, 200 * h / tw)
		sg.LightInfluence = 0.2
		sg.Parent = step
		local num = Instance.new("TextLabel")
		num.BackgroundTransparency = 1
		num.Size = UDim2.fromScale(1, 0.9)
		num.Font = Enum.Font.FredokaOne
		num.TextScaled = true
		num.TextColor3 = medal
		num.TextStrokeColor3 = Color3.fromRGB(60, 45, 20)
		num.TextStrokeTransparency = 0.2
		num.Text = tostring(place)
		num.Parent = sg
		-- подсветка ступени цветом медали
		local light = Instance.new("PointLight")
		light.Color = medal
		light.Range = 9
		light.Brightness = if place == 1 then 1.6 else 1
		light.Parent = step
		local top = cf * CFrame.new(lx, 0.5 + h, 0)
		m:SetAttribute("Slot" .. place, top)
		-- пустая ступень: большой «?» (server/Podium выключает, когда на ступени аватар)
		local anchor = deco({ Name = "EmptyAnchor" .. place, Size = Vector3.one, CFrame = top * CFrame.new(0, 2.6 * sc, 0), Transparency = 1 }, m)
		local bb = Instance.new("BillboardGui")
		bb.Name = "Empty" .. place
		bb.Size = UDim2.fromScale(3 * sc, 3.6 * sc) -- в studs
		bb.MaxDistance = Config.PODIUM.MAX_DIST
		bb.Parent = anchor
		local q = Instance.new("TextLabel")
		q.BackgroundTransparency = 1
		q.Size = UDim2.fromScale(1, 1)
		q.Font = Enum.Font.FredokaOne
		q.TextScaled = true
		q.TextColor3 = medal
		q.TextStrokeTransparency = 0.2
		q.Text = "?"
		q.Parent = bb
	end
	-- корона над табличкой 1-го места (клиент вращает её вокруг вертикали, атрибут BaseCF)
	local crownCF = cf * CFrame.new(0, 0.5 + PLAN.top3H[1] + 8.4 * sc, 0)
	local crown = Instance.new("Model")
	crown.Name = "Crown"
	local gold = LobbyPodium.MEDALS[1]
	deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 1.7, 1.7), CFrame = crownCF * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Neon, Color = gold }, crown)
	for k = 0, 4 do
		local a = k / 5 * math.pi * 2
		deco({ Size = Vector3.new(0.28, 0.75, 0.28), CFrame = crownCF * CFrame.new(math.cos(a) * 0.75, 0.55, math.sin(a) * 0.75) * CFrame.Angles(0, -a, 0), Material = Enum.Material.Neon, Color = gold }, crown)
		deco({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.32, CFrame = crownCF * CFrame.new(math.cos(a) * 0.75, 1, math.sin(a) * 0.75), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 90, 110) }, crown)
	end
	crown.WorldPivot = crownCF -- ось вращения — центр обода
	crown:SetAttribute("BaseCF", crownCF)
	crown.Parent = m
	local avatars = Instance.new("Folder")
	avatars.Name = "Avatars"
	avatars.Parent = m
	m.Parent = parent
end

return LobbyPodium
