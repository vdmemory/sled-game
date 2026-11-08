-- Физика санок на клиенте (у игрока network ownership санок → отклик без пинга).
--
-- Модель «импульса», как в оригинале: скорость растёт на крутых участках и падает на пологих
-- (гравитация вдоль склона − трение − сопротивление воздуха). Ракета и ускорители добавляют,
-- препятствия отнимают. Остановился — заезд окончен (это решает сервер).

-- Скрипт разбит на модули (папка client/Sled): State — общее состояние и объекты для HUD/эффектов,
-- Input — руль, Launch — рогатка, Tricks — трюки, Contacts — касания, монеты, магнит. Здесь —
-- посадка/высадка и кадр физики.

local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Sled = script.Parent:WaitForChild("Sled")
local st = require(Sled:WaitForChild("State"))
st.init(script) -- State, Sfx, RequestLaunch, RocketInput, TrickPopup — под этим скриптом
local Input = require(Sled:WaitForChild("Input"))
local Launch = require(Sled:WaitForChild("Launch"))
local Tricks = require(Sled:WaitForChild("Tricks"))
local Contacts = require(Sled:WaitForChild("Contacts"))

local speedValue = st.speedValue
local fuelValue = st.fuelValue
local fuelMaxValue = st.fuelMaxValue
local rocketOn = st.rocketOn
local meterValue = st.meterValue
local awaitingLaunch = st.awaitingLaunch
local magnetLeft = st.magnetLeft
local shieldOn = st.shieldOn
local x2Left = st.x2Left
local airborneValue = st.airborneValue
local sfx = st.sfx
local trickPopup = st.trickPopup
local rayParams = st.rayParams
local player = st.player
local connections = st.connections
local readSteer = Input.readSteer
local stickOn = Input.stickOn
local setPull = Launch.setPull
local PULL_KEY_TIME = Launch.PULL_KEY_TIME
local completeTrick = Tricks.completeTrick
local clearAirTricks = Tricks.clearAirTricks
local onTrickKey = Tricks.onTrickKey
local onJump = Tricks.onJump
local onRocket = Tricks.onRocket
local onTouched = Contacts.onTouched

-- Направление «вниз по трассе». Трасса петляет, поэтому берём его из куска трассы под санками
-- (у кусков Floor/Bank ось -Z смотрит вдоль трассы, у трамплина — наоборот).
local TRACK_PARTS = { Floor = 1, Bank = 1, Ramp = -1 }
local function updateForward(ground: BasePart)
	local sign = TRACK_PARTS[ground.Name]
	if sign then
		local look = ground.CFrame.LookVector * sign
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 0.1 then
			st.fwd = flat.Unit
		end
	end
end

local STEP_SAME_NORMAL = math.cos(math.rad(1.5)) -- нормали пола до и после ступеньки почти совпадают

------------------------------------------------------------------ посадка / высадка
local function stopRiding()
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	if st.humanoid then
		st.humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		st.humanoid.JumpPower = 50
	end
	ContextActionService:UnbindAction("Flip")
	ContextActionService:UnbindAction("Jump")
	ContextActionService:UnbindAction("Rocket")
	if st.controls then
		pcall(st.controls.Enable, st.controls)
	end
	stickOn.Value = false
	awaitingLaunch.Value = false
	st.pulling, st.keyPull, st.pullInput, st.baseCF = false, false, nil, nil
	meterValue.Value = 0
	local cam = workspace.CurrentCamera
	if cam and cam.CameraType == Enum.CameraType.Scriptable then
		cam.CameraType = Enum.CameraType.Custom
	end
	st.sled, st.align, st.humanoid = nil, nil, nil
	rocketOn.Value = false
	speedValue.Value = 0
end

local function startRiding(seat: VehicleSeat, hum: Humanoid)
	stopRiding()
	st.sled = seat
	st.align = seat:FindFirstChildOfClass("AlignOrientation")
	st.humanoid = hum
	st.speed = 0
	st.lateral = 0
	st.fwd = Vector3.new(0, 0, -1)
	st.started = false
	st.crashed = false
	st.airborne, st.flipHeld, st.rocketHeld = false, false, false
	airborneValue.Value = false
	st.jumpQueued, st.jumping, st.lastJump = false, false, 0
	clearAirTricks()
	st.lastTapAt, st.grabUntil = 0, 0
	st.magnetUntil = 0
	magnetLeft.Value = 0
	st.x2Until = 0
	x2Left.Value = 0
	st.lastPos = nil
	st.coinScan = 10
	shieldOn.Value = false
	st.fuel = Config.rocketFuel(player:GetAttribute("RocketLevel") or 0)
	fuelMaxValue.Value = st.fuel
	fuelValue.Value = st.fuel

	hum.UseJumpPower = true
	hum.JumpPower = 0
	hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

	ContextActionService:BindActionAtPriority("Flip", onTrickKey, true, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
	ContextActionService:SetTitle("Flip", "🔄")
	ContextActionService:SetPosition("Flip", UDim2.new(1, -230, 1, -100))
	-- Прыжок: на телефоне круглая кнопка над 🔄 (тот же столбик под большой палец, руль — левее)
	ContextActionService:BindActionAtPriority("Jump", onJump, true, Enum.ContextActionPriority.High.Value, Enum.KeyCode.LeftControl, Enum.KeyCode.W, Enum.KeyCode.ButtonX)
	ContextActionService:SetTitle("Jump", "⤴")
	ContextActionService:SetPosition("Jump", UDim2.new(1, -230, 1, -190))
	ContextActionService:BindActionAtPriority(
		"Rocket",
		onRocket,
		false, -- на телефоне — своя кнопка в HUD под спидометром
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.LeftShift,
		Enum.KeyCode.E,
		Enum.KeyCode.ButtonR2
	)
	-- Стандартный стик Roblox на телефоне прячем: руль — наше кольцо в любом месте экрана
	if st.controls and UserInputService.TouchEnabled then
		pcall(st.controls.Disable, st.controls)
	end

	-- Рогатка: ждём, пока игрок оттянет и отпустит
	st.launchSent = false
	st.pulling, st.keyPull, st.pullInput, st.baseCF = false, false, nil, nil
	meterValue.Value = 0
	awaitingLaunch.Value = seat.Anchored

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
	if s == st.sled then
		stopRiding()
	end
end)
for _, s in sledsFolder:GetChildren() do
	task.spawn(onSledAdded, s)
end
player.CharacterAdded:Connect(function(character)
	-- санки убраны или персонаж пересоздан во время заезда (сервер закончит заезд сам) — камера
	-- не должна остаться на рогатке старой трассы
	if st.sled and (not st.sled.Parent or (st.humanoid and st.humanoid.Parent ~= character)) then
		stopRiding()
	end
end)

-- Мягкий возврат на трассу (server/Runs, Config.RESCUE_*): сервер прислал точку на дне куска —
-- переставляем свои санки (физика у нас), скорость × keep вдоль трассы, полёт и трюки сбрасываем
-- (падение — не «полёт» с монетами)
Remotes:WaitForChild("Rescue").OnClientEvent:Connect(function(cf: CFrame, keep: number)
	local s = st.sled
	if not s or not s.Parent or s.Anchored or st.crashed or typeof(cf) ~= "CFrame" then
		return
	end
	local k = if typeof(keep) == "number" then math.clamp(keep, 0, 1) else 0.7
	st.speed *= k
	st.lateral = 0
	local look = cf.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude > 0.1 then
		st.fwd = flat.Unit
	end
	s.CFrame = cf
	s.AssemblyLinearVelocity = look * st.speed
	s.AssemblyAngularVelocity = Vector3.zero
	st.airborne, st.jumping, st.jumpQueued = false, false, false
	airborneValue.Value = false
	st.airTime = 0
	clearAirTricks()
	trickPopup:Fire("↩ Назад на трассу")
end)

------------------------------------------------------------------ кадр физики
RunService.Heartbeat:Connect(function(dt)
	local s = st.sled
	if not s or not s.Parent then
		return
	end
	if s.Anchored then
		-- Ждём рогатку: при удержании клавиши натяжение растёт само
		if st.pulling and st.keyPull then
			setPull(st.pullAmount + dt / PULL_KEY_TIME)
		end
		-- Камера закреплена за рогаткой (как в оригинале), чтобы свайп не крутил её
		local cam = workspace.CurrentCamera
		if cam then
			local base = st.baseCF or s.CFrame
			cam.CameraType = Enum.CameraType.Scriptable
			local eye = (base * CFrame.new(0, 7 + st.pullAmount * 2, 17 + st.pullAmount * 6)).Position
			cam.CFrame = CFrame.lookAt(eye, (base * CFrame.new(0, 1, -30)).Position)
		end
		return
	end
	do
		local cam = workspace.CurrentCamera
		if cam and cam.CameraType == Enum.CameraType.Scriptable then
			cam.CameraType = Enum.CameraType.Custom
		end
	end
	-- Детали санок (стабилизатор) могут прийти по сети позже самих санок
	local a = st.align
	if not a then
		a = s:FindFirstChildOfClass("AlignOrientation")
		st.align = a
		if not a then
			return
		end
	end
	if not st.started then
		st.started = true
		st.speed = s:GetAttribute("LaunchSpeed") or 50
	end
	if st.crashed then
		-- После кувырка гасим движение: ватрушка останавливается
		if os.clock() - st.crashTime > 0.9 then
			local k = 1 - math.min(1, dt * 4)
			s.AssemblyLinearVelocity *= k
			s.AssemblyAngularVelocity *= k
		end
		return
	end

	local sledLevel = player:GetAttribute("SledLevel") or 0
	-- Бонус модели и редкости саней (+% скорости): выше потолок и меньше трение
	local sledBonus = s:GetAttribute("SledBonus") or 0
	local maxSpeed = Config.maxSpeed(sledLevel) * (1 + sledBonus)
	local useRocket = st.rocketHeld and st.fuel > 0
	if useRocket then
		st.fuel = math.max(0, st.fuel - dt)
	end
	rocketOn.Value = useRocket
	fuelValue.Value = st.fuel

	Contacts.scan(s, dt)

	local hit = workspace:Raycast(s.Position, Vector3.new(0, -4, 0), rayParams)
	local vel = s.AssemblyLinearVelocity
	local steer = readSteer(s)
	local now = os.clock()
	-- После прыжка с ровного места луч до снега короче 4 studs почти весь полёт — поэтому
	-- «в воздухе» считаем по высоте центра саней над снегом (JUMP_GROUND_DIST)
	local grounded = hit ~= nil and (not st.jumping or hit.Distance <= Config.JUMP_GROUND_DIST)
	-- Грэб: тап в воздухе, за TRICK_DOUBLE_TAP не стало разворотом
	if st.pendingGrab and now - st.lastTapAt >= Config.TRICK_DOUBLE_TAP then
		st.pendingGrab = false
		if st.airborne and not st.trick and st.airTime >= Config.TRICKS.grab.minAir then
			st.grabUntil = now + Config.GRAB_TIME
			completeTrick("grab")
		end
	end

	if grounded and hit then
		-- На земле: считаем скорость сами
		local n = hit.Normal
		updateForward(hit.Instance)
		local d = (st.fwd - n * st.fwd:Dot(n)).Unit
		local right = d:Cross(n)

		-- Трамплин — пусковая площадка: скорость на нём не теряется, и он подбрасывает вверх
		local onRamp = hit.Instance.Name == "Ramp"
		local acc = if onRamp
			then 0
			else -Config.GRAVITY_ALONG * d.Y - Config.friction(sledLevel) * (1 - sledBonus) - Config.DRAG * st.speed * st.speed
		if useRocket then
			acc += Config.ROCKET_THRUST
		end
		if onRamp then
			st.speed = math.max(st.speed, Config.RAMP_MIN_SPEED)
		end
		st.speed += acc * dt
		if st.speed > maxSpeed and not useRocket then
			st.speed = math.max(maxSpeed, st.speed - 30 * dt) -- буст плавно гаснет
		end
		st.speed = math.max(0, st.speed)
		-- Трамплин-ускоритель островков (#40, shared/Islands): скорость вылета в окне LaunchMin…LaunchMax —
		-- прыжок до следующего островка всегда достаёт и не перелетает его
		local launchLo, launchHi = hit.Instance:GetAttribute("LaunchMin"), hit.Instance:GetAttribute("LaunchMax")
		if onRamp and typeof(launchLo) == "number" and typeof(launchHi) == "number" then
			st.speed = math.clamp(st.speed, launchLo, launchHi)
			sfx:Fire("spring") -- пружина островка (Sounds не чаще раза в секунду)
		end

		-- Руль с инерцией + борта скатывают к центру (right.Y > 0 — мы на наклонном борту).
		-- Боковая скорость растёт вместе с продольной (Config.steerSpeed): время смены полосы
		-- не зависит от скорости (docs/GAME_DESIGN.md → «Скорость и руль»)
		local steerMax = Config.steerSpeed(st.speed)
		st.lateral += (steer * steerMax - st.lateral) * math.min(1, dt * Config.STEER_RESPONSE)
		st.lateral -= Config.WALL_PULL * right.Y * dt

		local vn = vel:Dot(n)
		if onRamp then
			local lift = hit.Instance:GetAttribute("Lift")
			vn = math.max(vn, st.speed * (if typeof(lift) == "number" then lift else Config.RAMP_LIFT))
		end
		-- Подсадка на ступеньку (#40): пол впереди выше на 0.05…STEP_UP_MAX при почти той же нормали
		-- (стык кусков, а не склон или трамплин) — поднимаем сани заранее, чтобы край плиты саней не
		-- ударился о торец. Скорость считаем сами, поэтому она не теряется.
		if not onRamp and st.speed > 5 and Config.STEP_UP_MAX > 0 then
			local probe = s.Position + d * (Config.STEP_PROBE + st.speed * dt) + n * (Config.STEP_UP_MAX + 0.5)
			local ahead = workspace:Raycast(probe, -n * (Config.STEP_UP_MAX + 2.5), rayParams)
			if ahead and ahead.Instance.Name ~= "Ramp" and ahead.Normal:Dot(n) > STEP_SAME_NORMAL then
				local rise = (ahead.Position - hit.Position):Dot(n)
				if rise > 0.05 and rise <= Config.STEP_UP_MAX then
					s.CFrame += n * rise
				end
			end
		end
		-- Прыжок: подброс вверх по нормали; дальше тот же путь, что и с трамплина (airborne → трюки)
		if st.jumpQueued and not onRamp and not st.airborne and now - st.lastJump >= Config.JUMP_COOLDOWN then
			st.lastJump = now
			st.jumping = true
			-- на борту жёлоба (Bank) подброс слабее: от стенки не оттолкнёшься как от ровного снега
			vn = math.max(vn, Config.JUMP_SPEED * (if hit.Instance.Name == "Bank" then 0.7 else 1))
			sfx:Fire("jump")
		end
		st.jumpQueued = false
		if st.jumping and not st.airborne and now - st.lastJump > Config.JUMP_COOLDOWN then
			st.jumping = false -- подброс не оторвал от снега (горка в борт) — сбрасываем режим
		end
		s.AssemblyLinearVelocity = d * st.speed + right * st.lateral + n * vn
		a.Enabled = true
		-- Наклон в поворот: ватрушка кренится и чуть разворачивается по направлению движения
		local tilt = math.rad(Config.STEER_TILT) * math.clamp(st.lateral / steerMax, -1, 1)
		a.CFrame = CFrame.lookAt(Vector3.zero, d, n) * CFrame.Angles(0, -tilt * 0.5, -tilt)

		-- Приземление
		if st.airborne then
			st.airborne = false
			airborneValue.Value = false
			st.jumping = false
			if st.airTime > 0.35 then
				sfx:Fire("land")
			end
			-- Air time: бонус за долгий полёт (как в оригинале)
			if st.airTime >= Config.AIR_MIN_TIME then
				Remotes.Air:FireServer(st.airTime)
				trickPopup:Fire(string.format("✈ Полёт %.1f с  +%d", st.airTime, math.floor(math.min(st.airTime, 4) * Config.AIR_COINS_PER_SEC)))
			end
			Tricks.land(s, n)
			clearAirTricks()
		end
		st.airTime = 0
	else
		-- В воздухе: летим по физике, немного рулим, ракета толкает вперёд
		st.airborne = true
		airborneValue.Value = true
		st.airTime += dt
		local rightH = st.fwd:Cross(Vector3.yAxis)
		local along = vel:Dot(st.fwd)
		st.speed = math.max(0, along)
		st.lateral += (steer * Config.steerSpeed(st.speed) * 0.6 - st.lateral) * math.min(1, dt * Config.STEER_RESPONSE * 0.5)
		local newVel = st.fwd * along + rightH * st.lateral + Vector3.new(0, vel.Y, 0)
		if useRocket then
			newVel += st.fwd * Config.ROCKET_THRUST * dt
		end
		s.AssemblyLinearVelocity = newVel

		Tricks.air(s, a, vel, steer, rightH, now, dt)
	end
	speedValue.Value = st.speed
end)
