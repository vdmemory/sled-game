-- Анимация получения нового тира апгрейда (как «GOT AERO TAIL!» в оригинале):
-- затемнение, вращающиеся лучи, 3D-модель новой детали во ViewportFrame с облётом камеры,
-- большой текст «ПОЛУЧЕНО: …!», искры. Запускается из HUD через BindableEvent UpgradeReveal.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UI = require(ReplicatedStorage.Shared:WaitForChild("UIKit"))
local SledModels = require(ReplicatedStorage.Shared:WaitForChild("SledModels"))

local player = Players.LocalPlayer
local controller = script.Parent:WaitForChild("SledController")
local hudScript = script.Parent:WaitForChild("HUD")
local revealEvent = hudScript:WaitForChild("UpgradeReveal") :: BindableEvent

local function tween(o: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- 3D-модель того, что получили
local function buildModel(kind: string, level: number): Model
	local m = Instance.new("Model")
	local tier = Config.tierOf(level)
	local skin = Config.skin(player:GetAttribute("Skin"))
	local sledId = Config.sled(player:GetAttribute("Sled")).id
	local rarityIdx = math.clamp(player:GetAttribute("SledRarity") or 1, 1, #Config.RARITIES)
	local rarity = Config.RARITIES[rarityIdx]
	local main = rarity.color or skin.tube
	local accent = if rarityIdx > 1 then Color3.new(1, 1, 1):Lerp(rarity.color :: Color3, 0.35) else skin.rim
	local look = {
		main = main,
		accent = accent,
		material = if rarityIdx > 1 then rarity.material else nil,
		glow = rarityIdx == 5,
		shine = rarity.shine,
	}
	if kind == "Rocket" then
		-- одна большая ракета, повёрнутая боком
		SledModels.rocket(m, CFrame.Angles(0, math.rad(90), 0), tier)
	elseif kind == "Launch" then
		-- рогатка: два столба нового тира, резинка, санки перед ней
		local style = Config.POST_STYLES[math.min(tier + 1, #Config.POST_STYLES)]
		for _, sx in { -1, 1 } do
			local post = Instance.new("Part")
			post.Shape = Enum.PartType.Cylinder
			post.Size = Vector3.new(7, 1.2, 1.2)
			post.CFrame = CFrame.new(sx * 5, 1.5, 3) * CFrame.Angles(0, 0, math.rad(90))
			post.Color = style[1]
			post.Material = style[2]
			post.Anchored = true
			post.Parent = m
			local cap = Instance.new("Part")
			cap.Shape = Enum.PartType.Ball
			cap.Size = Vector3.new(1.6, 1.6, 1.6)
			cap.Position = Vector3.new(sx * 5, 5.1, 3)
			cap.Color = style[1]
			cap.Material = style[2]
			cap.Anchored = true
			cap.Parent = m
			local band = Instance.new("Part")
			band.Shape = Enum.PartType.Cylinder
			local a, b = Vector3.new(sx * 5, 4.6, 3), Vector3.new(sx * 1.6, 1.4, 4.8)
			band.Size = Vector3.new((b - a).Magnitude, 0.35, 0.35)
			band.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
			band.Color = if tier >= 4 then Color3.fromRGB(255, 220, 90) elseif tier >= 1 then Color3.fromRGB(70, 70, 80) else Color3.fromRGB(200, 160, 110)
			band.Anchored = true
			band.Parent = m
		end
		SledModels.build(m, CFrame.new(0, 0, 6), sledId, look, nil, rarityIdx > 1)
	else
		-- санки целиком с новым обвесом и ракетами
		SledModels.build(m, CFrame.new(), sledId, look, nil, rarityIdx > 1)
		SledModels.extras(m, CFrame.new(), sledId, if kind == "Sled" then tier else Config.tierOf(player:GetAttribute("SledLevel") or 0), Config.tierOf(player:GetAttribute("RocketLevel") or 0), accent, nil)
	end
	return m
end

local current: ScreenGui? = nil

local function reveal(kind: string, tierName: string)
	if current then
		current:Destroy()
	end
	local level = player:GetAttribute(kind .. "Level") or 0
	local gui = Instance.new("ScreenGui")
	gui.Name = "Reveal"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 40
	gui.Parent = player:WaitForChild("PlayerGui")
	current = gui

	-- затемнение (оно же — кнопка «закрыть по тапу»)
	local bg = UI.new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(8, 20, 50), BackgroundTransparency = 1, Parent = gui })
	local root = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1000, 660), BackgroundTransparency = 1, Parent = gui })
	local fit = Instance.new("UIScale")
	fit.Parent = root
	local cam = workspace.CurrentCamera
	local function refit()
		local v = cam.ViewportSize
		fit.Scale = math.clamp(math.min(v.Y / 660, v.X / 1000), 0.55, 1.2)
	end
	refit()

	-- лучи: 12 полупрозрачных клиньев, медленно крутятся
	local rays = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.44), Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, Parent = root })
	for i = 0, 11 do
		local ray = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.11, 0, 1, 0), Rotation = i * 15, BackgroundColor3 = Color3.fromRGB(255, 236, 150), BackgroundTransparency = 0.55, Parent = rays })
		local g = Instance.new("UIGradient")
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.35, 0.2),
			NumberSequenceKeypoint.new(0.5, 1),
			NumberSequenceKeypoint.new(0.65, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
		g.Rotation = 90
		g.Parent = ray
	end
	-- мягкое свечение в центре
	local halo = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.44), Size = UDim2.fromOffset(0, 0), BackgroundColor3 = Color3.fromRGB(255, 245, 200), BackgroundTransparency = 0.35, Parent = root })
	UI.corner(halo, 1000)
	local hg = Instance.new("UIGradient")
	hg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	hg.Parent = halo

	-- 3D-модель
	local vp = UI.new("ViewportFrame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.44), Size = UDim2.fromOffset(620, 420), BackgroundTransparency = 1, Ambient = Color3.fromRGB(165, 170, 190), LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-1, -1.6, -0.8), Parent = root })
	local vpScale = Instance.new("UIScale")
	vpScale.Scale = 0.2
	vpScale.Parent = vp
	local model = buildModel(kind, level)
	model.Parent = vp
	local vcam = Instance.new("Camera")
	vcam.FieldOfView = 38
	vcam.Parent = vp
	vp.CurrentCamera = vcam
	local bbCF, bbSize = model:GetBoundingBox()
	local center = bbCF.Position
	local dist = bbSize.Magnitude * 0.95 + 1.5

	-- тексты
	local top = UI.text({ Text = "НОВОЕ УЛУЧШЕНИЕ!", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.76), Size = UDim2.fromOffset(420, 34), TextColor3 = Color3.fromRGB(255, 215, 70), TextTransparency = 1, Parent = root })
	UI.outline(top, 3)
	local title = UI.text({ Text = "ПОЛУЧЕНО: " .. UI.upper(tierName) .. "!", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.85), Size = UDim2.fromOffset(860, 74), Outline = 5, Parent = root })
	local tScale = Instance.new("UIScale")
	tScale.Scale = 0
	tScale.Parent = title
	local btn = UI.button("green", "ОТЛИЧНО!", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.95), Size = UDim2.fromOffset(220, 52), Visible = false, Parent = root })

	-- белая вспышка
	local flash = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.25, Parent = gui })

	controller.Sfx:Fire("record")
	tween(flash, 0.5, { BackgroundTransparency = 1 })
	tween(bg, 0.3, { BackgroundTransparency = 0.3 })
	tween(rays, 0.6, { Size = UDim2.fromOffset(980, 980) }, Enum.EasingStyle.Back)
	tween(halo, 0.6, { Size = UDim2.fromOffset(520, 520) }, Enum.EasingStyle.Back)
	tween(vpScale, 0.6, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(0.3, function()
		tween(top, 0.3, { TextTransparency = 0 })
		tween(tScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
		controller.Sfx:Fire("reward")
	end)
	task.delay(0.9, function()
		if btn.Parent then
			btn.Visible = true
			UI.pop(btn)
		end
	end)

	-- искры разлетаются из центра
	for i = 1, 16 do
		local a = i / 16 * math.pi * 2 + math.random() * 0.3
		local star = UI.text({ Text = if i % 2 == 0 then "✦" else "★", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.44), Size = UDim2.fromOffset(30, 30), TextColor3 = Color3.fromRGB(255, 230, 110), Rotation = math.random(0, 90), Parent = root })
		local r = 260 + math.random() * 160
		task.delay(0.05 + math.random() * 0.25, function()
			tween(star, 1.1, { Position = UDim2.new(0.5, math.cos(a) * r, 0.44, math.sin(a) * r * 0.7), Rotation = star.Rotation + 180, TextTransparency = 1, Size = UDim2.fromOffset(46, 46) })
		end)
	end

	-- облёт камеры + вращение лучей + покачивание надписи
	local t0 = os.clock()
	local conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		rays.Rotation = t * 18
		local zoom = 1 + 0.9 * math.exp(-t * 3.5) -- «наезд» камеры
		local ang = math.rad(-35) + t * 0.6
		local eye = center + Vector3.new(math.sin(ang) * dist * zoom, dist * 0.42 * zoom, math.cos(ang) * dist * zoom)
		vcam.CFrame = CFrame.lookAt(eye, center)
		title.Rotation = math.sin(t * 3) * 2
	end)

	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		tween(bg, 0.25, { BackgroundTransparency = 1 })
		tween(vpScale, 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		tween(tScale, 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		tween(rays, 0.25, { Size = UDim2.fromOffset(0, 0) })
		tween(halo, 0.25, { Size = UDim2.fromOffset(0, 0) })
		tween(top, 0.2, { TextTransparency = 1 })
		btn.Visible = false
		task.delay(0.3, function()
			conn:Disconnect()
			gui:Destroy()
			if current == gui then
				current = nil
			end
		end)
	end
	btn.Activated:Connect(close)
	bg.Activated:Connect(function()
		if os.clock() - t0 > 0.9 then
			close()
		end
	end)
	task.delay(5, close)
end

revealEvent.Event:Connect(reveal)
