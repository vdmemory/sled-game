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

local sleds = workspace:WaitForChild("Sleds")
sleds.ChildAdded:Connect(addSnowTrail)
for _, s in sleds:GetChildren() do
	addSnowTrail(s)
end

------------------------------------------------------------------ Монеты крутятся
local coins: { [BasePart]: CFrame } = {}
local function trackCoin(coin: Instance)
	if coin:IsA("BasePart") then
		coins[coin] = coin.CFrame
	end
end
CollectionService:GetInstanceAddedSignal("Coin"):Connect(trackCoin)
CollectionService:GetInstanceRemovedSignal("Coin"):Connect(function(coin)
	coins[coin :: BasePart] = nil
end)
for _, c in CollectionService:GetTagged("Coin") do
	trackCoin(c)
end

------------------------------------------------------------------ Кадр
local spin = 0
RunService.RenderStepped:Connect(function(dt)
	-- FOV растёт со скоростью своих санок
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	local speed = if seat then seat.AssemblyLinearVelocity.Magnitude else 0
	local targetFov = BASE_FOV + (MAX_FOV - BASE_FOV) * math.clamp(speed / FOV_SPEED_FULL, 0, 1)
	camera.FieldOfView += (targetFov - camera.FieldOfView) * math.min(1, dt * 4)

	-- Снежная пыль сильнее на скорости и только на земле
	for _, s in sleds:GetChildren() do
		local pe = s:FindFirstChild("SnowTrailAttachment") and s.SnowTrailAttachment:FindFirstChild("SnowTrail")
		if pe and s:IsA("BasePart") then
			local v = s.AssemblyLinearVelocity.Magnitude
			local grounded = workspace:Raycast(s.Position, -s.CFrame.UpVector * 3) ~= nil
			pe.Rate = if grounded then math.clamp(v * 0.8, 0, 90) else 0
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
	spin += dt * 3
	local camPos = camera.CFrame.Position
	for coin, base in coins do
		if coin.Parent == nil then
			coins[coin] = nil
		elseif coin.Transparency < 1 and (coin.Position - camPos).Magnitude < 250 then
			coin.CFrame = base * CFrame.Angles(0, spin, 0)
		end
	end
end)
