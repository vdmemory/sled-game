-- Свет миров и пост-обработка у этого игрока (ничего не реплицируется):
--  • пресет мира (shared/WorldLook): Lighting, Atmosphere, Clouds, Sky, ColorCorrection, Bloom,
--    SunRays, DepthOfField — плавно (TweenService). В заезде — тема уровня (RunTheme с сервера),
--    в лобби — тема витринной трассы (LobbyTheme от LobbyScene) + поправки WorldLook.LOBBY;
--  • уровень графики 1–3 (Низкое/Среднее/Высокое): выбор игрока в ⚙ (атрибут GfxChoice, 0 — авто)
--    или авто: «Графика» в меню Roblox (SavedQualityLevel) и падение FPS (AutoLowFps от Effects).
--    Итог — атрибут GfxTier (Effects берёт из него множитель частиц);
--  • виньетка скорости по краям экрана (UI-оверлей под HUD) в заезде.
-- Future-освещение: Lighting.Technology = Future в default.project.json (из кода не ставится),
-- LightingStyle/PrioritizeLightingQuality (новые свойства «Unified Lighting») — из кода, в pcall.
-- Atmosphere/ColorCorrection/Bloom/Clouds создаёт сервер (Main), SunRays/DOF/Sky — этот скрипт.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local WorldLook = require(Shared:WaitForChild("WorldLook"))
local UI = require(Shared:WaitForChild("UIKit"))

local player = Players.LocalPlayer

local function setProp(obj: Instance, prop: string, value: any)
	pcall(function()
		(obj :: any)[prop] = value
	end)
end

-- Свой эффект в Lighting (локальный); сервер таких не создаёт
local function own(className: string, name: string): any
	local o = Lighting:FindFirstChild(name)
	if o and o:IsA(className) then
		return o
	end
	o = Instance.new(className)
	o.Name = name
	o.Parent = Lighting
	return o
end
local sunRays = own("SunRaysEffect", "PostFX_SunRays")
local dof = own("DepthOfFieldEffect", "PostFX_DOF")
local sky = Lighting:FindFirstChildOfClass("Sky") or own("Sky", "PostFX_Sky")

------------------------------------------------------------------ Уровень графики
local function savedQuality(): number
	local ok, v = pcall(function()
		return (UserSettings():GetService("UserGameSettings") :: any).SavedQualityLevel.Value
	end)
	return if ok and typeof(v) == "number" then v else 0
end

local function computeTier(): number
	local choice = player:GetAttribute("GfxChoice")
	if typeof(choice) == "number" and choice >= 1 and choice <= #WorldLook.QUALITY then
		return choice
	end
	if player:GetAttribute("AutoLowFps") then
		return 1
	end
	local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	return WorldLook.tierFromSaved(savedQuality(), touchOnly)
end

local tier = 0 -- 0 — ещё не применён
local function applyTier(): boolean
	local t = computeTier()
	if t == tier then
		return false
	end
	tier = t
	player:SetAttribute("GfxTier", t)
	local q = WorldLook.QUALITY[t]
	-- Низкое: Soft + без приоритета света = дешёвый воксельный свет; иначе Realistic (Future)
	pcall(function()
		local styles = (Enum :: any).LightingStyle
		Lighting.LightingStyle = if t == 1 then styles.Soft else styles.Realistic
	end)
	setProp(Lighting, "PrioritizeLightingQuality", q.prioritizeLighting)
	return true
end

------------------------------------------------------------------ Пресет мира
local tweens: { [Instance]: Tween } = {}
local function tweenTo(obj: Instance?, props: { [string]: any }, info: TweenInfo)
	if not obj then
		return
	end
	local old = tweens[obj]
	if old then
		old:Cancel()
		tweens[obj] = nil
	end
	if info.Time <= 0 then
		for k, v in props do
			setProp(obj, k, v)
		end
		return
	end
	local ok, tw = pcall(TweenService.Create, TweenService, obj, info, props)
	if ok then
		tweens[obj] = tw
		tw:Play()
	else
		for k, v in props do
			setProp(obj, k, v)
		end
	end
end

local function apply(instant: boolean?)
	applyTier()
	local G = Config.GRAPHICS
	local L = WorldLook.LOBBY
	local q = WorldLook.QUALITY[tier]
	local inRun = player:GetAttribute("InRun") == true
	local theme = player:GetAttribute(if inRun then "RunTheme" else "LobbyTheme")
	local p = WorldLook.get(if typeof(theme) == "number" then theme else 1)
	local info = TweenInfo.new(if instant then 0 elseif inRun then G.RUN_TWEEN else Config.LOBBY_LOOK_TWEEN, Enum.EasingStyle.Sine)

	local lp = table.clone(p.lighting)
	lp.ClockTime = p.clock
	if not inRun then
		lp.ExposureCompensation += L.exposureAdd
	end
	tweenTo(Lighting, lp, info)
	Lighting.GlobalShadows = q.shadows and player:GetAttribute("SetShadows") ~= false

	tweenTo(Lighting:FindFirstChildOfClass("Atmosphere"), p.atmo, info)

	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	if clouds then
		clouds.Enabled = q.clouds
		tweenTo(clouds, p.clouds, info)
	end

	for k, v in p.sky do
		setProp(sky, k, v)
	end

	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if cc then
		local c = table.clone(p.cc)
		c.Saturation = p.cc.Saturation * G.SATURATION + (if inRun then 0 else L.saturationAdd)
		c.Contrast = math.max(p.cc.Contrast, G.CONTRAST_MIN)
		tweenTo(cc, c, info)
	end

	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if bloom then
		bloom.Enabled = q.bloom and G.BLOOM > 0
		local b = table.clone(p.bloom)
		b.Intensity = p.bloom.Intensity * G.BLOOM * (if inRun then 1 else L.bloomMult)
		tweenTo(bloom, b, info)
	end

	sunRays.Enabled = q.rays and G.SUNRAYS > 0
	tweenTo(sunRays, { Intensity = math.clamp(p.rays.Intensity * G.SUNRAYS, 0, 1), Spread = p.rays.Spread }, info)

	-- Размытие дали — только в заезде (фокус на санях и трассе впереди), в лобби витрина чёткая
	dof.Enabled = q.dof and G.DOF > 0 and (inRun or L.dof ~= false)
	local d = table.clone(p.dof)
	d.FarIntensity = math.clamp(p.dof.FarIntensity * G.DOF, 0, 1)
	tweenTo(dof, d, info)
end

local function soon()
	task.defer(apply)
end
for _, attr in { "InRun", "RunTheme", "LobbyTheme", "SetShadows", "GfxChoice", "AutoLowFps" } do
	player:GetAttributeChangedSignal(attr):Connect(soon)
end
-- Панель «Настройка» (ConfigSync применяет раньше или позже — отложим на кадр)
ReplicatedStorage:GetAttributeChangedSignal("ConfigOverrides"):Connect(soon)
player:GetAttributeChangedSignal("ConfigOverrides"):Connect(soon)
pcall(function()
	(UserSettings():GetService("UserGameSettings") :: any):GetPropertyChangedSignal("SavedQualityLevel"):Connect(soon)
end)
-- Эффекты сервера реплицируются не сразу: как появятся — сразу в нужный вид
Lighting.ChildAdded:Connect(function()
	task.defer(apply, true)
end)
workspace.Terrain.ChildAdded:Connect(function(c)
	if c:IsA("Clouds") then
		task.defer(apply, true)
	end
end)
apply(true)

------------------------------------------------------------------ Виньетка скорости
-- Четыре полосы по краям с градиентом к центру: на скорости края кадра темнеют — «туннель»
-- скорости вместе с FOV и линиями (Effects). Ниже HUD (DisplayOrder), клики не ловит.
local gui = UI.new("ScreenGui", { Name = "SpeedVignette", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = -10, Enabled = false, Parent = player:WaitForChild("PlayerGui") })
local edges: { Frame } = {}
local function edge(anchor: Vector2, pos: UDim2, size: UDim2, rotation: number)
	local f = UI.new("Frame", { AnchorPoint = anchor, Position = pos, Size = size, BackgroundColor3 = UI.C.ink, BackgroundTransparency = 1, Active = false, Parent = gui })
	UI.new("UIGradient", {
		Rotation = rotation,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.45, 0.65),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = f,
	})
	table.insert(edges, f)
end
edge(Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(0.2, 1), 0) -- слева
edge(Vector2.new(1, 0), UDim2.fromScale(1, 0), UDim2.fromScale(0.2, 1), 180) -- справа
edge(Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.18), 90) -- сверху
edge(Vector2.new(0, 1), UDim2.fromScale(0, 1), UDim2.fromScale(1, 0.18), -90) -- снизу

local controller = script.Parent:WaitForChild("SledController")
local speedState = controller:WaitForChild("State"):WaitForChild("Speed") :: NumberValue
local shown = 0
RunService.RenderStepped:Connect(function(dt)
	local G = Config.GRAPHICS
	local target = 0
	if player:GetAttribute("InRun") then
		local span = math.max(1, G.VIGNETTE_FULL - G.VIGNETTE_FROM)
		target = math.clamp((speedState.Value - G.VIGNETTE_FROM) / span, 0, 1) * G.VIGNETTE_MAX
	end
	shown += (target - shown) * math.min(1, dt * 3)
	local on = shown > 0.01
	if gui.Enabled ~= on then
		gui.Enabled = on
	end
	if on then
		for _, f in edges do
			f.BackgroundTransparency = 1 - shown
		end
	end
end)
