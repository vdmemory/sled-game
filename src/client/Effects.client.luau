-- Визуальные эффекты на клиенте: ощущение скорости, снежная пыль, вращение монет.
-- Ничего не влияет на геймплей — только картинка.

local Players = game:GetService("Players")
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

	-- Ракетные сопла (горят, когда у этих санок включена ракета; видно только своему игроку)
	if sled:GetAttribute("Owner") == player.UserId then
		for _, side in { -1, 1 } do
			local nozzle = Instance.new("Attachment")
			nozzle.Name = "RocketNozzle"
			nozzle.Position = Vector3.new(side * 2.2, 0.6, 3.6)
			nozzle.Parent = sled
			local fire = Instance.new("ParticleEmitter")
			fire.Name = "RocketFire"
			fire.Texture = "rbxasset://textures/particles/fire_main.dds"
			fire.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 90, 30))
			fire.LightEmission = 1
			fire.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1.6),
				NumberSequenceKeypoint.new(1, 0.2),
			})
			fire.Transparency = NumberSequence.new(0.1, 1)
			fire.Lifetime = NumberRange.new(0.15, 0.3)
			fire.Speed = NumberRange.new(25, 35)
			fire.EmissionDirection = Enum.NormalId.Back
			fire.SpreadAngle = Vector2.new(8, 8)
			fire.Rate = 0
			fire.Parent = nozzle
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
			pe.Rate = if grounded then math.clamp(v * 0.8, 0, 90) else 0
			local trail = s:FindFirstChild("IceTrail")
			if trail then
				trail.Enabled = grounded and v > 5 and not s.Anchored
			end
		end
		if s:GetAttribute("Owner") == player.UserId then
			for _, nozzle in s:GetChildren() do
				local fire = nozzle.Name == "RocketNozzle" and nozzle:FindFirstChild("RocketFire")
				if fire then
					fire.Rate = if rocketOn.Value then 120 else 0
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
