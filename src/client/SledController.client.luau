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

local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local FWD = Vector3.new(0, 0, -1) -- все трассы идут по -Z

------------------------------------------------------------------ руль: читаем ввод сами
-- Не полагаемся на VehicleSeat.SteerFloat: он заполняется, только если клиент «увидел» посадку.
-- Источники: клавиатура, стик/геймпад (через PlayerModule), свайп пальцем по экрану.
local controls = nil
task.spawn(function()
	local ok, module = pcall(function()
		return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 10))
	end)
	if ok and module then
		controls = module:GetControls()
	end
end)

local SWIPE_FULL = 90 -- пикселей свайпа = руль до упора
local swipeInput: InputObject? = nil
local swipeStartX = 0
UserInputService.InputBegan:Connect(function(input, processed)
	if input.UserInputType == Enum.UserInputType.Touch and not processed and not swipeInput then
		swipeInput = input
		swipeStartX = input.Position.X
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input == swipeInput then
		swipeInput = nil
	end
end)

local function readSteer(seat: VehicleSeat): number
	local steer = 0
	-- Клавиатура
	if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
		steer -= 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
		steer += 1
	end
	-- Стик на экране / геймпад
	if controls then
		local ok, mv = pcall(controls.GetMoveVector, controls)
		if ok and typeof(mv) == "Vector3" and math.abs(mv.X) > math.abs(steer) then
			steer = mv.X
		end
	end
	-- Свайп: держишь палец и ведёшь влево/вправо
	if swipeInput then
		local s = math.clamp((swipeInput.Position.X - swipeStartX) / SWIPE_FULL, -1, 1)
		if math.abs(s) > math.abs(steer) then
			steer = s
		end
	end
	-- И на всякий случай стандартный руль сиденья
	if math.abs(seat.SteerFloat) > math.abs(steer) then
		steer = seat.SteerFloat
	end
	return math.clamp(steer, -1, 1)
end

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

-- Звуковые события для Sounds-скрипта: sfx:Fire("launch" | "land" | "hit" | "boost" | "coin" | "flip")
local sfx = Instance.new("BindableEvent")
sfx.Name = "Sfx"
sfx.Parent = script

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
local lateral = 0 -- боковая скорость (с инерцией)
local airTime = 0
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
		sfx:Fire("launch")
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
-- Удар о препятствие: ватрушка кувыркается вперёд и останавливается, заезд окончен
local crashed = false
local crashTime = 0
local function crash()
	local s, a = sled, align
	if not s or crashed then
		return
	end
	crashed = true
	crashTime = os.clock()
	if a then
		a.Enabled = false
	end
	local side = if math.random() < 0.5 then -1 else 1
	s.AssemblyLinearVelocity = FWD * math.min(speed, 60) * 0.35 + Vector3.new(side * 6, 28, 0)
	s.AssemblyAngularVelocity = Vector3.new(-9, side * 2, side * 5) -- кувырок через «нос»
	speed = 0
	rocketOn.Value = false
	speedValue.Value = 0
	trickPopup:Fire("💥 Врезался!")
	sfx:Fire("hit")
	Remotes.Crash:FireServer()
end

local function onTouched(hit: BasePart)
	local now = os.clock()
	if CollectionService:HasTag(hit, "Obstacle") then
		if crashed or not started or now - lastObstacle < 0.5 then
			return
		end
		lastObstacle = now
		crash()
	elseif CollectionService:HasTag(hit, "Boost") then
		if now - lastBoost < 0.4 then
			return
		end
		lastBoost = now
		speed += Config.BOOST_ADD
		trickPopup:Fire("⚡ Ускорение!")
		sfx:Fire("boost")
	elseif CollectionService:HasTag(hit, "Coin") then
		if hit.LocalTransparencyModifier < 1 then
			hit.LocalTransparencyModifier = 1 -- мгновенно прячем, сервер засчитает
			for _, detail in hit:GetDescendants() do
				if detail:IsA("BasePart") then
					detail.LocalTransparencyModifier = 1
				elseif detail:IsA("ParticleEmitter") then
					detail.Enabled = false
				end
			end
			sfx:Fire("coin")
		end
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
	lateral = 0
	started = false
	crashed = false
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

	local function hook(p: Instance)
		if p:IsA("BasePart") then
			table.insert(connections, p.Touched:Connect(onTouched))
		end
	end
	for _, p in seat:GetDescendants() do
		hook(p)
	end
	table.insert(connections, seat.DescendantAdded:Connect(hook))
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
	local s = sled
	if not s or not s.Parent then
		return
	end
	if s.Anchored then
		-- Ждём рогатку: шкала силы бегает туда-сюда
		meterValue.Value = 0.5 + 0.5 * math.sin(os.clock() * 3.4)
		return
	end
	-- Детали санок (стабилизатор) могут прийти по сети позже самих санок
	local a = align
	if not a then
		a = s:FindFirstChildOfClass("AlignOrientation")
		align = a
		if not a then
			return
		end
	end
	if not started then
		started = true
		speed = s:GetAttribute("LaunchSpeed") or 50
	end
	if crashed then
		-- После кувырка гасим движение: ватрушка останавливается
		if os.clock() - crashTime > 0.9 then
			local k = 1 - math.min(1, dt * 4)
			s.AssemblyLinearVelocity *= k
			s.AssemblyAngularVelocity *= k
		end
		return
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
	local steer = readSteer(s)

	if hit then
		-- На земле: считаем скорость сами
		local n = hit.Normal
		local d = (FWD - n * FWD:Dot(n)).Unit
		local right = d:Cross(n)

		-- Трамплин — пусковая площадка: скорость на нём не теряется, и он подбрасывает вверх
		local onRamp = hit.Instance.Name == "Ramp"
		local acc = if onRamp
			then 0
			else -Config.GRAVITY_ALONG * d.Y - Config.friction(sledLevel) - Config.DRAG * speed * speed
		if useRocket then
			acc += Config.ROCKET_THRUST
		end
		if onRamp then
			speed = math.max(speed, Config.RAMP_MIN_SPEED)
		end
		speed += acc * dt
		if speed > maxSpeed and not useRocket then
			speed = math.max(maxSpeed, speed - 30 * dt) -- буст плавно гаснет
		end
		speed = math.max(0, speed)

		-- Руль с инерцией + борта скатывают к центру (right.Y > 0 — мы на наклонном борту)
		lateral += (steer * Config.STEER_SPEED - lateral) * math.min(1, dt * Config.STEER_RESPONSE)
		lateral -= Config.WALL_PULL * right.Y * dt

		local vn = vel:Dot(n)
		if onRamp then
			vn = math.max(vn, speed * Config.RAMP_LIFT)
		end
		s.AssemblyLinearVelocity = d * speed + right * lateral + n * vn
		a.Enabled = true
		-- Наклон в поворот: ватрушка кренится и чуть разворачивается по направлению движения
		local tilt = math.rad(Config.STEER_TILT) * math.clamp(lateral / Config.STEER_SPEED, -1, 1)
		a.CFrame = CFrame.lookAt(Vector3.zero, d, n) * CFrame.Angles(0, -tilt * 0.5, -tilt)

		-- Приземление
		if airborne then
			airborne = false
			if airTime > 0.35 then
				sfx:Fire("land")
			end
			if flipping then
				local upright = s.CFrame.UpVector:Dot(n) > 0.5
				local flips = math.floor((flipAngle + math.pi / 2) / (2 * math.pi))
				if not upright then
					speed *= 0.5
					trickPopup:Fire("😵 Кривое приземление")
				elseif flips >= 1 then
					speed *= Config.FLIP_BOOST ^ flips
					Remotes.Trick:FireServer(flips)
					sfx:Fire("flip")
					trickPopup:Fire((if flips > 1 then "Флип x" .. flips else "Флип") .. "! ⚡")
				end
			end
			flipping = false
			flipAngle = 0
		end
		airTime = 0
	else
		-- В воздухе: летим по физике, немного рулим, ракета толкает вперёд
		airborne = true
		airTime += dt
		speed = math.max(0, vel:Dot(FWD))
		lateral += (steer * Config.STEER_SPEED * 0.6 - lateral) * math.min(1, dt * Config.STEER_RESPONSE * 0.5)
		local newVel = Vector3.new(lateral, vel.Y, vel.Z)
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
