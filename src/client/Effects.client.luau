-- Визуальные эффекты на клиенте: ощущение скорости, снежная пыль, вращение монет.
-- Ничего не влияет на геймплей — только картинка.

local Players = game:GetService("Players")
local SledModels = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("SledModels"))
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local BASE_FOV = 70
local MAX_FOV = 95
local FOV_SPEED_FULL = 140 -- при такой скорости FOV максимальный

------------------------------------------------------------------ Снежная пыль из-под санок
local function addSnowTrail(sled: Instance)
	if not sled:IsA("BasePart") or sled:FindFirstChild("SnowTrail") then
		return
	end
	local att = Instance.new("Attachment")
	att.Name = "SnowTrailAttachment"
	att.Position = Vector3.new(0, -0.5, 3) -- задний край санок
	att.Parent = sled

	local pe = Instance.new("ParticleEmitter")
	pe.Name = "SnowTrail"
	pe.Texture = "rbxasset://textures/particles/smoke_main.dds" -- встроенная текстура клиента
	pe.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	pe.LightEmission = 0.3
	pe.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	pe.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(1, 4),
	})
	pe.Lifetime = NumberRange.new(0.4, 0.8)
	pe.Speed = NumberRange.new(4, 9)
	pe.SpreadAngle = Vector2.new(35, 20)
	pe.EmissionDirection = Enum.NormalId.Back
	pe.Rate = 0
	pe.Parent = att

	-- Ледяной след за ватрушкой (как в оригинале): лента между двумя точками у днища
	local a0 = Instance.new("Attachment")
	a0.Name = "TrailL"
	a0.Position = Vector3.new(-2.6, -0.45, 1.5)
	a0.Parent = sled
	local a1 = Instance.new("Attachment")
	a1.Name = "TrailR"
	a1.Position = Vector3.new(2.6, -0.45, 1.5)
	a1.Parent = sled
	local trail = Instance.new("Trail")
	trail.Name = "IceTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(Color3.fromRGB(120, 175, 230), Color3.fromRGB(170, 210, 245))
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(0.7, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Lifetime = 1.6
	trail.MinLength = 0.2
	trail.LightInfluence = 1
	trail.Enabled = false
	trail.Parent = sled

	-- Цветной след (купленный в меню «Следы»): лента повыше, видна и в полёте
	local tc = sled:GetAttribute("TrailColor")
	if typeof(tc) == "Color3" then
		local b0 = Instance.new("Attachment")
		b0.Position = Vector3.new(-1.3, 0.4, 2.8)
		b0.Parent = sled
		local b1 = Instance.new("Attachment")
		b1.Position = Vector3.new(1.3, 0.4, 2.8)
		b1.Parent = sled
		local ct = Instance.new("Trail")
		ct.Name = "ColorTrail"
		ct.Attachment0 = b0
		ct.Attachment1 = b1
		ct.Color = if sled:GetAttribute("Rainbow")
			then ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 70)),
				ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 200, 50)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 230, 100)),
				ColorSequenceKeypoint.new(0.75, Color3.fromRGB(70, 150, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 90, 255)),
			})
			else ColorSequence.new(tc)
		ct.Transparency = NumberSequence.new(0.1, 1)
		ct.Lifetime = 0.9
		ct.LightEmission = 0.6
		ct.FaceCamera = true
		ct.Enabled = false
		ct.Parent = sled
	end

	-- Ракетные сопла (горят, когда у этих санок включена ракета; видно только своему игроку)
	if sled:GetAttribute("Owner") == player.UserId then
		-- сопла боковых ракет: координаты отдаёт сервер (SledModels.extras)
		local np = sled:GetAttribute("RocketNozzle")
		local n = if typeof(np) == "Vector3" then np else Vector3.new(2.2, 0.6, 3.6)
		-- Реалистичное пламя: светящийся конус-факел (два Beam: ядро и оболочка), искристое ядро,
		-- языки огня, дым позади и мерцающий свет. Плазменные ракеты (тир 5+) горят голубым.
		local tier = sled:GetAttribute("RocketTier") or 0
		local plasma = tier >= 5
		local d = (SledModels.ROCKETS[math.clamp(tier, 0, 6)] or SledModels.ROCKETS[1]).d
		local hot = if plasma then Color3.fromRGB(220, 250, 255) else Color3.fromRGB(255, 250, 220)
		local mid = if plasma then Color3.fromRGB(90, 200, 255) else Color3.fromRGB(255, 170, 40)
		local outer = if plasma then Color3.fromRGB(140, 90, 255) else Color3.fromRGB(255, 70, 20)
		for _, side in { -1, 1 } do
			local nozzle = Instance.new("Attachment")
			nozzle.Name = "RocketNozzle"
			nozzle.Position = Vector3.new(side * math.abs(n.X), n.Y, n.Z)
			nozzle.Parent = sled
			local tail = Instance.new("Attachment")
			tail.Name = "RocketTail"
			tail.Position = nozzle.Position + Vector3.new(0, 0, 5)
			tail:SetAttribute("BaseZ", tail.Position.Z)
			tail.Parent = sled
			local coreTail = Instance.new("Attachment")
			coreTail.Name = "RocketCoreTail"
			coreTail.Position = nozzle.Position + Vector3.new(0, 0, 2.2)
			coreTail.Parent = sled
			local function beam(name: string, a1: Attachment, w0: number, colors: ColorSequence, transp: NumberSequence)
				local bm = Instance.new("Beam")
				bm.Name = name
				bm.Attachment0 = nozzle
				bm.Attachment1 = a1
				bm.Width0 = w0
				bm.Width1 = 0.05
				bm.FaceCamera = true
				bm.Segments = 12
				bm.LightEmission = 0.7
				bm.LightInfluence = 0
				bm.Color = colors
				bm.Transparency = transp
				bm.Enabled = false
				bm.Parent = sled
				return bm
			end
			-- оболочка факела: от жёлто-белого у сопла к оранжевому и красному на конце
			beam("RocketPlume", tail, d * 0.7, ColorSequence.new({
				ColorSequenceKeypoint.new(0, hot),
				ColorSequenceKeypoint.new(0.25, mid),
				ColorSequenceKeypoint.new(1, outer),
			}), NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.05),
				NumberSequenceKeypoint.new(0.6, 0.45),
				NumberSequenceKeypoint.new(1, 1),
			})).Name = "RocketPlume" .. side
			-- ослепительное короткое ядро
			beam("RocketCore", coreTail, d * 0.35, ColorSequence.new(Color3.new(1, 1, 1), hot), NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(1, 1),
			})).Name = "RocketCore" .. side
			local function emitter(name: string, tex: string): ParticleEmitter
				local pe = Instance.new("ParticleEmitter")
				pe.Name = name
				pe.Texture = tex
				pe.EmissionDirection = Enum.NormalId.Back
				pe.Rate = 0
				pe.Parent = nozzle
				return pe
			end
			-- языки пламени вокруг факела
			local fire = emitter("RocketFire", "rbxasset://textures/particles/fire_main.dds")
			fire.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, hot), ColorSequenceKeypoint.new(0.3, mid), ColorSequenceKeypoint.new(1, outer) })
			fire.LightEmission = 0.6
			fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, d * 0.6), NumberSequenceKeypoint.new(0.5, d * 0.9), NumberSequenceKeypoint.new(1, 0.1) })
			fire.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
			fire.Lifetime = NumberRange.new(0.12, 0.22)
			fire.Speed = NumberRange.new(28, 40)
			fire.SpreadAngle = Vector2.new(6, 6)
			fire.RotSpeed = NumberRange.new(-180, 180)
			fire.Rotation = NumberRange.new(0, 360)
			-- искры
			local sparks = emitter("RocketSparks", "rbxasset://textures/particles/sparkles_main.dds")
			sparks.Color = ColorSequence.new(hot, mid)
			sparks.LightEmission = 1
			sparks.Size = NumberSequence.new(0.25, 0)
			sparks.Lifetime = NumberRange.new(0.2, 0.4)
			sparks.Speed = NumberRange.new(30, 50)
			sparks.SpreadAngle = Vector2.new(14, 14)
			-- дымный след (живёт дольше, расширяется, сносится назад)
			local smoke = emitter("RocketSmoke", "rbxasset://textures/particles/smoke_main.dds")
			smoke.Color = ColorSequence.new(Color3.fromRGB(150, 150, 155), Color3.fromRGB(210, 210, 215))
			smoke.LightEmission = 0
			smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, d), NumberSequenceKeypoint.new(1, d * 4.5) })
			smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
			smoke.Lifetime = NumberRange.new(0.7, 1.2)
			smoke.Speed = NumberRange.new(10, 16)
			smoke.Drag = 2
			smoke.SpreadAngle = Vector2.new(10, 10)
			-- свет от пламени
			local light = Instance.new("PointLight")
			light.Name = "RocketLight"
			light.Color = mid
			light.Range = 7
			light.Brightness = 0.8
			light.Enabled = false
			light.Parent = nozzle
		end
	end
end

local controller = script.Parent:WaitForChild("SledController")
local rocketOn = controller:WaitForChild("State"):WaitForChild("RocketOn")
local speedState = controller.State:WaitForChild("Speed")

local sleds = workspace:WaitForChild("Sleds")
sleds.ChildAdded:Connect(addSnowTrail)
for _, s in sleds:GetChildren() do
	addSnowTrail(s)
end

------------------------------------------------------------------ Монеты крутятся
local coins: { [BasePart]: CFrame } = {}
local coinPhase: { [BasePart]: number } = {}
local function trackCoin(coin: Instance)
	if coin:IsA("BasePart") then
		coins[coin] = coin.CFrame
		coinPhase[coin] = math.random() * math.pi * 2
		-- Блёстки
		local att = Instance.new("Attachment")
		att.Parent = coin
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 240, 170))
		sparkle.LightEmission = 1
		sparkle.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 0.7),
			NumberSequenceKeypoint.new(1, 0),
		})
		sparkle.Lifetime = NumberRange.new(0.4, 0.7)
		sparkle.Speed = NumberRange.new(0)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.Rate = 1.5
		sparkle.Parent = att
	end
end
CollectionService:GetInstanceAddedSignal("Coin"):Connect(trackCoin)
CollectionService:GetInstanceRemovedSignal("Coin"):Connect(function(coin)
	coins[coin :: BasePart] = nil
	coinPhase[coin :: BasePart] = nil -- иначе таблица держит уничтоженные монеты каждого заезда
end)
for _, c in CollectionService:GetTagged("Coin") do
	trackCoin(c)
end

------------------------------------------------------------------ Снегопад и линии скорости (вокруг камеры)
local fxAnchor = Instance.new("Part")
fxAnchor.Name = "CameraFX"
fxAnchor.Anchored = true
fxAnchor.CanCollide = false
fxAnchor.CanQuery = false
fxAnchor.CanTouch = false
fxAnchor.Transparency = 1
fxAnchor.Size = Vector3.new(160, 1, 160)
fxAnchor.Parent = workspace

local snow = Instance.new("ParticleEmitter")
snow.Name = "Snowfall"
snow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
snow.Color = ColorSequence.new(Color3.new(1, 1, 1))
snow.LightEmission = 0.4
snow.Size = NumberSequence.new(0.35, 0.25)
snow.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.15, 0.1),
	NumberSequenceKeypoint.new(1, 0.4),
})
snow.Lifetime = NumberRange.new(4, 6)
snow.Speed = NumberRange.new(10, 16)
snow.EmissionDirection = Enum.NormalId.Bottom
snow.SpreadAngle = Vector2.new(15, 15)
snow.Acceleration = Vector3.new(2, 0, 0)
snow.Rate = 120
snow.Parent = fxAnchor
-- Настройка «Снегопад» (меню ⚙)
local function applySnow()
	snow.Enabled = Players.LocalPlayer:GetAttribute("SetSnow") ~= false
end
Players.LocalPlayer:GetAttributeChangedSignal("SetSnow"):Connect(applySnow)
applySnow()

local linesAtt = Instance.new("Attachment")
linesAtt.Parent = fxAnchor
local speedLines = Instance.new("ParticleEmitter")
speedLines.Name = "SpeedLines"
speedLines.Color = ColorSequence.new(Color3.new(1, 1, 1))
speedLines.LightEmission = 1
speedLines.Orientation = Enum.ParticleOrientation.VelocityParallel
speedLines.Size = NumberSequence.new(0.12)
speedLines.Squash = NumberSequence.new(-4) -- вытягиваем в полоски
speedLines.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.3, 0.4),
	NumberSequenceKeypoint.new(1, 1),
})
speedLines.Lifetime = NumberRange.new(0.25, 0.4)
speedLines.Speed = NumberRange.new(120, 160)
speedLines.SpreadAngle = Vector2.new(60, 35)
speedLines.Rate = 0
speedLines.Parent = linesAtt

------------------------------------------------------------------ Кадр
local spin = 0
RunService.RenderStepped:Connect(function(dt)
	-- FOV растёт со скоростью своих санок
	-- Скорость берём у контроллера санок (SeatPart на клиенте может быть пустым)
	local speed = speedState.Value
	local targetFov = BASE_FOV + (MAX_FOV - BASE_FOV) * math.clamp(speed / FOV_SPEED_FULL, 0, 1)
	camera.FieldOfView += (targetFov - camera.FieldOfView) * math.min(1, dt * 4)

	-- Снег падает вокруг камеры; линии скорости летят навстречу, когда разогнался
	local camCF = camera.CFrame
	fxAnchor.CFrame = CFrame.new(camCF.Position + Vector3.new(0, 35, 0))
	-- Эмиттер полос впереди камеры, «дует» назад на игрока
	linesAtt.WorldCFrame = CFrame.lookAt(camCF.Position + camCF.LookVector * 40, camCF.Position)
		* CFrame.Angles(-math.pi / 2, 0, 0) -- частицы летят по +Y аттачмента → направляем на камеру
	speedLines.Rate = if speed > 70 then math.clamp((speed - 70) * 2.5, 0, 150) else 0

	-- Снежная пыль сильнее на скорости и только на земле
	for _, s in sleds:GetChildren() do
		local pe = s:FindFirstChild("SnowTrailAttachment") and s.SnowTrailAttachment:FindFirstChild("SnowTrail")
		if pe and s:IsA("BasePart") then
			local v = s.AssemblyLinearVelocity.Magnitude
			local grounded = workspace:Raycast(s.Position, -s.CFrame.UpVector * 3) ~= nil
			pe.Rate = if grounded then math.clamp(v * 0.8, 0, 90) * (if player:GetAttribute("LowQuality") then 0.3 else 1) else 0
			local trail = s:FindFirstChild("IceTrail")
			if trail then
				trail.Enabled = grounded and v > 5 and not s.Anchored
			end
			local ct = s:FindFirstChild("ColorTrail")
			if ct then
				ct.Enabled = v > 5 and not s.Anchored
			end
		end
		if s:GetAttribute("Owner") == player.UserId then
			local on = rocketOn.Value
			local flick = 1 + math.noise(os.clock() * 18) * 0.35 -- мерцание длины факела
			for _, child in s:GetChildren() do
				if child.Name == "RocketNozzle" then
					local fire = child:FindFirstChild("RocketFire") :: ParticleEmitter?
					if fire then
						fire.Rate = if on then 90 else 0
						(child:FindFirstChild("RocketSparks") :: ParticleEmitter).Rate = if on then 60 else 0
						(child:FindFirstChild("RocketSmoke") :: ParticleEmitter).Rate = if on then 45 else 0
						local light = child:FindFirstChild("RocketLight") :: PointLight
						light.Enabled = on
						light.Brightness = 0.6 + math.random() * 0.5 -- без пересвета снега
					end
				elseif child:IsA("Beam") and string.sub(child.Name, 1, 6) == "Rocket" then
					child.Enabled = on
				elseif child.Name == "RocketTail" and child:IsA("Attachment") then
					local p = child.Position
					child.Position = Vector3.new(p.X, p.Y, (child:GetAttribute("BaseZ") :: number) + (flick - 1) * 3)
				end
			end
		end
	end

	-- Вращаем только монеты рядом с камерой
	spin += dt * 2.5
	local t = os.clock()
	local camPos = camera.CFrame.Position
	for coin, base in coins do
		if coin.Parent == nil then
			coins[coin] = nil
			coinPhase[coin] = nil
		elseif coin.Transparency < 1 and coin.LocalTransparencyModifier < 1 and (coin.Position - camPos).Magnitude < 250 then
			local bob = math.sin(t * 2.2 + coinPhase[coin]) * 0.35
			local cf = base * CFrame.new(0, bob, 0) * CFrame.Angles(0, spin, 0)
			coin.CFrame = cf
			for _, detail in coin:GetChildren() do
				if detail:IsA("BasePart") then
					detail.CFrame = cf
				end
			end
		end
	end
end)

------------------------------------------------------------------ Освещение и дымка под мир
-- В заезде небо, дымка и цвет кадра подстраиваются под тему уровня (RunTheme с сервера),
-- в лобби — базовый снежный вид. Меняется только у этого игрока.
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local LOOKS = {
	-- 1 Снежный лес: ясный голубой день
	{ clock = 14.5, atmo = { Color = Color3.fromRGB(190, 220, 255), Decay = Color3.fromRGB(110, 160, 230), Density = 0.25, Haze = 0.5 }, cc = { TintColor = Color3.fromRGB(240, 248, 255), Saturation = 0.25 } },
	-- 2 Ледяной город: холодный вечерний свет и городская дымка
	{ clock = 16.2, atmo = { Color = Color3.fromRGB(205, 215, 240), Decay = Color3.fromRGB(120, 130, 185), Density = 0.32, Haze = 1.3 }, cc = { TintColor = Color3.fromRGB(232, 238, 255), Saturation = 0.15 } },
	-- 3 Каньон: тёплый закатный свет и пыльная оранжевая дымка
	{ clock = 16.9, atmo = { Color = Color3.fromRGB(255, 222, 185), Decay = Color3.fromRGB(215, 140, 90), Density = 0.3, Haze = 1.1 }, cc = { TintColor = Color3.fromRGB(255, 240, 222), Saturation = 0.32 } },
	-- 4 Ледяные пещеры: голубая плотная дымка, холодный кадр
	{ clock = 15, atmo = { Color = Color3.fromRGB(175, 225, 255), Decay = Color3.fromRGB(80, 160, 230), Density = 0.38, Haze = 1.6 }, cc = { TintColor = Color3.fromRGB(225, 242, 255), Saturation = 0.2 } },
	-- 5 Северное сияние: сумерки, фиолетово-зелёное небо
	{ clock = 18.6, atmo = { Color = Color3.fromRGB(150, 140, 220), Decay = Color3.fromRGB(60, 160, 140), Density = 0.3, Haze = 1.4 }, cc = { TintColor = Color3.fromRGB(225, 225, 255), Saturation = 0.3 } },
	-- 6 Снежный вулкан: багровый вечер и дым
	{ clock = 17.6, atmo = { Color = Color3.fromRGB(235, 180, 160), Decay = Color3.fromRGB(150, 60, 40), Density = 0.36, Haze = 1.8 }, cc = { TintColor = Color3.fromRGB(255, 232, 220), Saturation = 0.25 } },
	-- 7 Конфетная гора: розовый солнечный день
	{ clock = 13, atmo = { Color = Color3.fromRGB(255, 210, 235), Decay = Color3.fromRGB(240, 140, 200), Density = 0.26, Haze = 0.8 }, cc = { TintColor = Color3.fromRGB(255, 240, 248), Saturation = 0.35 } },
}

-- Осадки по теме: снег (по умолчанию), пепел с искрами у вулкана, ничего в каньоне и на конфетной
-- горе, редкие блёстки на сиянии. nil — эмиттер выключен.
local SNOW_DEFAULT = { color = Color3.new(1, 1, 1), rate = 120, size = 0.35, speed = NumberRange.new(10, 16), light = 0.4 }
local PRECIP: { [number]: any } = {
	[3] = false, -- каньон: сухо
	[5] = { color = Color3.fromRGB(200, 255, 230), rate = 50, size = 0.3, speed = NumberRange.new(6, 10), light = 1 },
	[6] = { color = Color3.fromRGB(110, 100, 100), rate = 70, size = 0.45, speed = NumberRange.new(5, 9), light = 0 },
	[7] = false, -- конфетная гора: солнечно
}
local function applyPrecip(theme: number)
	local p = PRECIP[theme]
	if p == nil then
		p = SNOW_DEFAULT
	end
	if not p then
		snow.Rate = 0
		return
	end
	snow.Color = ColorSequence.new(p.color)
	snow.Size = NumberSequence.new(p.size, p.size * 0.7)
	snow.Speed = p.speed
	snow.LightEmission = p.light
	snow.Rate = if player:GetAttribute("LowQuality") then math.min(p.rate, 40) else p.rate
end

-- В заезде — тема уровня (RunTheme), в лобби — тема витринной трассы (LobbyTheme от LobbyScene):
-- небо, дымка, время суток и осадки меняются у этого игрока плавно
local function applyWorldLook()
	local inRun = player:GetAttribute("InRun")
	local theme = if inRun then player:GetAttribute("RunTheme") or 1 else player:GetAttribute("LobbyTheme") or 1
	local look = LOOKS[((theme - 1) % #LOOKS) + 1]
	local info = TweenInfo.new(if inRun then 1.5 else Config.LOBBY_LOOK_TWEEN, Enum.EasingStyle.Sine)
	TweenService:Create(Lighting, info, { ClockTime = look.clock }):Play()
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmo then
		TweenService:Create(atmo, info, look.atmo):Play()
	end
	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if cc then
		TweenService:Create(cc, info, look.cc):Play()
	end
	applyPrecip(((theme - 1) % #LOOKS) + 1)
end
player:GetAttributeChangedSignal("InRun"):Connect(applyWorldLook)
player:GetAttributeChangedSignal("RunTheme"):Connect(applyWorldLook)
player:GetAttributeChangedSignal("LobbyTheme"):Connect(applyWorldLook)
task.delay(2, applyWorldLook)

------------------------------------------------------------------ Авто-качество (FPS на телефонах)
-- Если кадров стабильно меньше ~40, облегчаем картинку: меньше снега и пыли, без bloom,
-- без мелких теней. Вернуть нельзя автоматически — чтобы не «мигало» качество.
local lowQuality = false
local frames, elapsed, slowWindows = 0, 0, 0
local fpsConn
fpsConn = RunService.RenderStepped:Connect(function(dt)
	frames += 1
	elapsed += dt
	if elapsed < 3 then
		return
	end
	local fps = frames / elapsed
	frames, elapsed = 0, 0
	slowWindows = if fps < 40 then slowWindows + 1 else 0
	if slowWindows >= 2 and not lowQuality then
		lowQuality = true
		player:SetAttribute("LowQuality", true)
		snow.Rate = math.min(snow.Rate, 40)
		local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
		if bloom then
			bloom.Enabled = false
		end
		local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
		if clouds then
			clouds.Enabled = false
		end
		fpsConn:Disconnect()
	end
end)
