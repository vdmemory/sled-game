-- Управление санками. Работает на клиенте, потому что сервер отдал игроку
-- network ownership санок: отклик мгновенный, без пинга.
--
-- Модель движения: скорость вдоль склона задаём сами (разгон до максимума),
-- боковую — по вводу, а нормальную к склону компоненту оставляем физике
-- (гравитация + трамплины). Так прыжки работают «бесплатно».

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local ORIGIN = Config.trackOrigin()
local FWD, RIGHT, UP = ORIGIN.LookVector, ORIGIN.RightVector, ORIGIN.UpVector

-- HUD подписывается на это событие, чтобы показать «Флип x2!»
local trickPopup = Instance.new("BindableEvent")
trickPopup.Name = "TrickPopup"
trickPopup.Parent = script

local rayParams = RaycastParams.new()
rayParams.CollisionGroup = "Riders" -- луч игнорирует всех райдеров (свои и чужие санки)

local sled: VehicleSeat? = nil
local align: AlignOrientation? = nil
local humanoid: Humanoid? = nil
local speed = 0
local flipHeld, flipping, airborne, crashed = false, false, false, false
local flipAngle = 0
local boostUntil = 0

local function onFlip(_, state: Enum.UserInputState)
	flipHeld = state == Enum.UserInputState.Begin
	return Enum.ContextActionResult.Sink -- глушим стандартный прыжок
end

local function startRiding(seat: VehicleSeat, hum: Humanoid)
	sled = seat
	align = seat:FindFirstChildOfClass("AlignOrientation")
	humanoid = hum
	speed = 15
	flipHeld, flipping, airborne, crashed = false, false, false, false
	flipAngle, boostUntil = 0, 0

	-- Прыжок выкинул бы игрока из санок
	hum.UseJumpPower = true
	hum.JumpPower = 0
	hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

	ContextActionService:BindActionAtPriority(
		"Flip",
		onFlip,
		true, -- кнопка на мобильных
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.Space,
		Enum.KeyCode.ButtonA
	)
	ContextActionService:SetTitle("Flip", "Флип")
end

local function stopRiding()
	if humanoid then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		humanoid.JumpPower = 50
	end
	ContextActionService:UnbindAction("Flip")
	sled, align, humanoid = nil, nil, nil
end

local function onCharacter(character: Model)
	stopRiding()
	local hum = character:WaitForChild("Humanoid") :: Humanoid
	hum.Seated:Connect(function(active, seatPart)
		if active and seatPart and seatPart.Name == "Sled" and seatPart:GetAttribute("Owner") == player.UserId then
			startRiding(seatPart :: VehicleSeat, hum)
		else
			stopRiding()
		end
	end)
end

player.CharacterAdded:Connect(onCharacter)
if player.Character then
	task.spawn(onCharacter, player.Character)
end

local function isGrounded(s: BasePart): boolean
	return workspace:Raycast(s.Position, -UP * 3, rayParams) ~= nil
end

RunService.Heartbeat:Connect(function(dt)
	local s, a = sled, align
	if not s or not a or not s.Parent or crashed then
		return
	end

	-- Скорость вдоль склона
	local maxSpeed = Config.maxSpeed(player:GetAttribute("SpeedLevel") or 0)
	if os.clock() < boostUntil then
		maxSpeed *= Config.FLIP_BOOST
	end
	if speed > maxSpeed then
		speed = math.max(maxSpeed, speed - 40 * dt) -- плавно гасим буст
	else
		speed = math.min(maxSpeed, speed + Config.ACCELERATION * dt)
	end

	local grounded = isGrounded(s)
	local lateral = s.SteerFloat * Config.steerSpeed(player:GetAttribute("ControlLevel") or 0)
	if not grounded then
		lateral *= 0.5 -- в воздухе рулить сложнее
	end
	local vn = s.AssemblyLinearVelocity:Dot(UP)
	s.AssemblyLinearVelocity = FWD * speed + RIGHT * lateral + UP * vn

	-- Флипы: держи пробел в воздухе — крутишься; отпустил — санки выравниваются
	if not grounded then
		airborne = true
		if flipHeld then
			flipping = true
			a.Enabled = false
			s.AssemblyAngularVelocity = RIGHT * Config.FLIP_SPEED
			flipAngle += Config.FLIP_SPEED * dt
		else
			a.Enabled = true
		end
	elseif airborne then
		airborne = false
		a.Enabled = true
		if flipping then
			local upright = s.CFrame.UpVector:Dot(UP) > 0.6
			if not upright then
				crashed = true
				Remotes.Crash:FireServer()
				return
			end
			local flips = math.floor((flipAngle + math.pi / 2) / (2 * math.pi))
			if flips >= 1 then
				boostUntil = os.clock() + Config.FLIP_BOOST_TIME
				Remotes.Trick:FireServer(flips)
				trickPopup:Fire(flips)
			end
		end
		flipping = false
		flipAngle = 0
	end
end)
