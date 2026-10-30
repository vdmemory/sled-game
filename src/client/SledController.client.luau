-- Физика санок на клиенте (у игрока network ownership санок → отклик без пинга).
--
-- Модель «импульса», как в оригинале: скорость растёт на крутых участках и падает на пологих
-- (гравитация вдоль склона − трение − сопротивление воздуха). Ракета и ускорители добавляют,
-- препятствия отнимают. Остановился — заезд окончен (это решает сервер).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local FWD = Vector3.new(0, 0, -1) -- все трассы идут по -Z

-- Состояние для HUD и эффектов (читают эти значения)
local state = Instance.new("Folder")
state.Name = "State"
local function value(name: string, class: string?): any
	local v = Instance.new(class or "NumberValue")
	v.Name = name
	v.Parent = state
	return v
end
local speedValue = value("Speed")
local fuelValue = value("Fuel")
local fuelMaxValue = value("FuelMax")
local rocketOn = value("RocketOn", "BoolValue")
local meterValue = value("Meter") -- шкала силы рогатки 0..1
local awaitingLaunch = value("AwaitingLaunch", "BoolValue")
state.Parent = script

-- HUD-кнопка «Запуск» дёргает это событие
local requestLaunch = Instance.new("BindableEvent")
requestLaunch.Name = "RequestLaunch"
requestLaunch.Parent = script

local trickPopup = Instance.new("BindableEvent")
trickPopup.Name = "TrickPopup" -- (текст) — HUD показывает всплывашку
trickPopup.Parent = script

local rayParams = RaycastParams.new()
rayParams.CollisionGroup = "Riders" -- луч не видит райдеров
rayParams.RespectCanCollide = true -- и проходит сквозь монеты/препятствия

local sled: VehicleSeat? = nil
local align: AlignOrientation? = nil
local humanoid: Humanoid? = nil
local connections: { RBXScriptConnection } = {}
local speed = 0
local started = false
local fuel = 0
local rocketHeld, flipHeld = false, false
local airborne, flipping = false, false
local flipAngle = 0
local lastObstacle, lastBoost = 0, 0

------------------------------------------------------------------ ввод
local launchSent = false
local function tryLaunch()
	if awaitingLaunch.Value and not launchSent then
		launchSent = true
		awaitingLaunch.Value = false
		ContextActionService:UnbindAction("LaunchTap")
		Remotes.Launch:FireServer(meterValue.Value)
	end
end

local function onFlip(_, inputState: Enum.UserInputState)
	if inputState == Enum.UserInputState.Begin and awaitingLaunch.Value then
		tryLaunch()
		return Enum.ContextActionResult.Sink
	end
	flipHeld = inputState == Enum.UserInputState.Begin
	return Enum.ContextActionResult.Sink
end
local function onLaunchTap(_, inputState: Enum.UserInputState)
	if inputState == Enum.UserInputState.Begin then
		tryLaunch()
	end
	return Enum.ContextActionResult.Pass
end
requestLaunch.Event:Connect(tryLaunch)

-- Запасной путь: любой тап / клик по экрану во время прицеливания
game:GetService("UserInputService").InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		tryLaunch()
	end
end)
local function onRocket(_, inputState: Enum.UserInputState)
	rocketHeld = inputState == Enum.UserInputState.Begin
	return Enum.ContextActionResult.Sink
end

------------------------------------------------------------------ столкновения
local function onTouched(hit: BasePart)
	local now = os.clock()
	if CollectionService:HasTag(hit, "Obstacle") then
		if now - lastObstacle < 0.5 then
			return
		end
		lastObstacle = now
		speed *= Config.OBSTACLE_SLOWDOWN
		-- Сбитое препятствие становится полупрозрачным (только у себя)
		local model = hit:FindFirstAncestorOfClass("Model")
		for _, p in (if model then model:GetDescendants() else { hit }) do
			if p:IsA("BasePart") then
				p.LocalTransparencyModifier = 0.7
				p.CanTouch = false
			end
		end
		trickPopup:Fire("💥 Бум!")
	elseif CollectionService:HasTag(hit, "Boost") then
		if now - lastBoost < 0.4 then
			return
		end
		lastBoost = now
		speed += Config.BOOST_ADD
		trickPopup:Fire("⚡ Ускорение!")
	elseif CollectionService:HasTag(hit, "Coin") then
		hit.LocalTransparencyModifier = 1 -- мгновенно прячем, сервер засчитает
	end
end

------------------------------------------------------------------ посадка / высадка
local function stopRiding()
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	if humanoid then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		humanoid.JumpPower = 50
	end
	ContextActionService:UnbindAction("Flip")
	ContextActionService:UnbindAction("Rocket")
	ContextActionService:UnbindAction("LaunchTap")
	awaitingLaunch.Value = false
	sled, align, humanoid = nil, nil, nil
	rocketOn.Value = false
	speedValue.Value = 0
end

local function startRiding(seat: VehicleSeat, hum: Humanoid)
	stopRiding()
	sled = seat
	align = seat:FindFirstChildOfClass("AlignOrientation")
	humanoid = hum
	speed = 0
	started = false
	airborne, flipping, flipHeld, rocketHeld = false, false, false, false
	flipAngle = 0
	fuel = Config.rocketFuel(player:GetAttribute("RocketLevel") or 0)
	fuelMaxValue.Value = fuel
	fuelValue.Value = fuel

	hum.UseJumpPower = true
	hum.JumpPower = 0
	hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

	ContextActionService:BindActionAtPriority("Flip", onFlip, true, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
	ContextActionService:SetTitle("Flip", "🔄")
	ContextActionService:SetPosition("Flip", UDim2.new(1, -230, 1, -100))
	ContextActionService:BindActionAtPriority(
		"Rocket",
		onRocket,
		true, -- кнопка на телефоне
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.LeftShift,
		Enum.KeyCode.E,
		Enum.KeyCode.ButtonR2
	)
	ContextActionService:SetTitle("Rocket", "🚀")
	ContextActionService:SetPosition("Rocket", UDim2.new(1, -150, 1, -150))

	-- Рогатка: ждём клик / тап / пробел
	launchSent = false
	awaitingLaunch.Value = seat.Anchored
	if seat.Anchored then
		ContextActionService:BindActionAtPriority(
			"LaunchTap",
			onLaunchTap,
			false,
			Enum.ContextActionPriority.Low.Value,
			Enum.UserInputType.MouseButton1,
			Enum.UserInputType.Touch
		)
	end

	for _, p in seat:GetDescendants() do
		if p:IsA("BasePart") then
			table.insert(connections, p.Touched:Connect(onTouched))
		end
	end
	table.insert(connections, seat.Touched:Connect(onTouched))
end

-- Свои санки находим по папке workspace.Sleds (атрибут Owner), а не по событию Seated:
-- пока санки закреплены у рогатки, Seated на клиенте может не прийти.
local sledsFolder = workspace:WaitForChild("Sleds")

local function onSledAdded(s: Instance)
	if not s:IsA("VehicleSeat") or s:GetAttribute("Owner") ~= player.UserId then
		return
	end
	local character = player.Character or player.CharacterAdded:Wait()
	local hum = character:WaitForChild("Humanoid", 5) :: Humanoid?
	if hum and s.Parent then
		startRiding(s, hum)
	end
end

sledsFolder.ChildAdded:Connect(onSledAdded)
sledsFolder.ChildRemoved:Connect(function(s)
	if s == sled then
		stopRiding()
	end
end)
for _, s in sledsFolder:GetChildren() do
	task.spawn(onSledAdded, s)
end
player.CharacterAdded:Connect(function()
	if sled and not sled.Parent then
		stopRiding()
	end
end)

------------------------------------------------------------------ кадр физики
RunService.Heartbeat:Connect(function(dt)
	local s, a = sled, align
	if not s or not a or not s.Parent then
		return
	end
	if s.Anchored then
		-- Ждём рогатку: шкала силы бегает туда-сюда
		meterValue.Value = 0.5 + 0.5 * math.sin(os.clock() * 3.4)
		return
	end
	if not started then
		started = true
		speed = s:GetAttribute("LaunchSpeed") or 50
	end

	local sledLevel = player:GetAttribute("SledLevel") or 0
	local maxSpeed = Config.maxSpeed(sledLevel)
	local useRocket = rocketHeld and fuel > 0
	if useRocket then
		fuel = math.max(0, fuel - dt)
	end
	rocketOn.Value = useRocket
	fuelValue.Value = fuel

	local hit = workspace:Raycast(s.Position, Vector3.new(0, -4, 0), rayParams)
	local vel = s.AssemblyLinearVelocity
	local steer = s.SteerFloat

	if hit then
		-- На земле: считаем скорость сами
		local n = hit.Normal
		local d = (FWD - n * FWD:Dot(n)).Unit
		local right = d:Cross(n)

		local acc = -Config.GRAVITY_ALONG * d.Y - Config.friction(sledLevel) - Config.DRAG * speed * speed
		if useRocket then
			acc += Config.ROCKET_THRUST
		end
		speed += acc * dt
		if speed > maxSpeed and not useRocket then
			speed = math.max(maxSpeed, speed - 30 * dt) -- буст плавно гаснет
		end
		speed = math.max(0, speed)

		local vn = vel:Dot(n)
		s.AssemblyLinearVelocity = d * speed + right * (steer * Config.STEER_SPEED) + n * vn
		a.Enabled = true
		a.CFrame = CFrame.lookAt(Vector3.zero, d, n)

		-- Приземление
		if airborne then
			airborne = false
			if flipping then
				local upright = s.CFrame.UpVector:Dot(n) > 0.5
				local flips = math.floor((flipAngle + math.pi / 2) / (2 * math.pi))
				if not upright then
					speed *= 0.5
					trickPopup:Fire("😵 Кривое приземление")
				elseif flips >= 1 then
					speed *= Config.FLIP_BOOST ^ flips
					Remotes.Trick:FireServer(flips)
					trickPopup:Fire((if flips > 1 then "Флип x" .. flips else "Флип") .. "! ⚡")
				end
			end
			flipping = false
			flipAngle = 0
		end
	else
		-- В воздухе: летим по физике, немного рулим, ракета толкает вперёд
		airborne = true
		speed = math.max(0, vel:Dot(FWD))
		local newVel = Vector3.new(steer * Config.STEER_SPEED * 0.6, vel.Y, vel.Z)
		if useRocket then
			newVel += FWD * Config.ROCKET_THRUST * dt
		end
		s.AssemblyLinearVelocity = newVel

		if flipHeld then
			flipping = true
			a.Enabled = false
			s.AssemblyAngularVelocity = Vector3.new(-Config.FLIP_SPEED, 0, 0)
			flipAngle += Config.FLIP_SPEED * dt
		else
			a.Enabled = true
			a.CFrame = CFrame.lookAt(Vector3.zero, FWD, Vector3.yAxis)
		end
	end
	speedValue.Value = speed
end)
