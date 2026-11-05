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
-- Направление «вниз по трассе». Трасса петляет, поэтому берём его из куска трассы под санками
-- (у кусков Floor/Bank ось -Z смотрит вдоль трассы, у трамплина — наоборот).
local fwd = Vector3.new(0, 0, -1)
local TRACK_PARTS = { Floor = 1, Bank = 1, Ramp = -1 }
local function updateForward(ground: BasePart)
	local sign = TRACK_PARTS[ground.Name]
	if sign then
		local look = ground.CFrame.LookVector * sign
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 0.1 then
			fwd = flat.Unit
		end
	end
end

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

local SWIPE_FULL = 70 -- пикселей = руль до упора (радиус кольца-джойстика в HUD)
local swipeInput: InputObject? = nil
local swipeStartX = 0
-- Плавающий джойстик как в оригинале: кольцо появляется там, где коснулся пальцем
local stickFolder = Instance.new("Folder")
stickFolder.Name = "Stick"
local stickOn = Instance.new("BoolValue")
stickOn.Name = "On"
stickOn.Parent = stickFolder
local stickOrigin = Instance.new("Vector3Value")
stickOrigin.Name = "Origin"
stickOrigin.Parent = stickFolder
local stickValue = Instance.new("NumberValue")
stickValue.Name = "X"
stickValue.Parent = stickFolder
stickFolder.Parent = script
UserInputService.InputBegan:Connect(function(input, processed)
	if input.UserInputType == Enum.UserInputType.Touch and not processed and not swipeInput then
		swipeInput = input
		swipeStartX = input.Position.X
		stickOrigin.Value = Vector3.new(input.Position.X, input.Position.Y, 0)
		stickValue.Value = 0
		stickOn.Value = true
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input == swipeInput then
		swipeInput = nil
		stickOn.Value = false
		stickValue.Value = 0
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
		stickValue.Value = s
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
-- «Руль вперёд» для переднего сальто: S / стрелка вниз, стик к себе, палец ведёт вниз
local function readPitchDown(): boolean
	if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then
		return true
	end
	if controls then
		local ok, mv = pcall(controls.GetMoveVector, controls)
		if ok and typeof(mv) == "Vector3" and mv.Z > 0.5 then
			return true
		end
	end
	if swipeInput and swipeInput.Position.Y - stickOrigin.Value.Y > SWIPE_FULL * 0.8 then
		return true
	end
	return false
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
local magnetLeft = value("MagnetLeft") -- сек до конца магнита (HUD показывает иконку)
local shieldOn = value("ShieldOn", "BoolValue") -- щит: одно столкновение без аварии
local x2Left = value("X2Left") -- сек до конца «x2 монеты»
state.Parent = script

-- Звуковые события для Sounds-скрипта: sfx:Fire("launch" | "land" | "hit" | "boost" | "coin" | "flip" | "jump")
local sfx = Instance.new("BindableEvent")
sfx.Name = "Sfx"
sfx.Parent = script

-- HUD-кнопка «Запуск» дёргает это событие
local requestLaunch = Instance.new("BindableEvent")
requestLaunch.Name = "RequestLaunch"
requestLaunch.Parent = script

-- Кнопка ракеты в HUD (под спидометром): RocketInput:Fire(true/false)
local rocketInput = Instance.new("BindableEvent")
rocketInput.Name = "RocketInput"
rocketInput.Parent = script

local trickPopup = Instance.new("BindableEvent")
trickPopup.Name = "TrickPopup" -- (текст) — HUD показывает всплывашку
trickPopup.Parent = script

local overlapParams = OverlapParams.new()
overlapParams.CollisionGroup = "Riders" -- не видит себя и других райдеров
overlapParams.RespectCanCollide = false

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
local airborne = false
local lastObstacle, lastBoost = 0, 0

-- Прыжок с земли: jumpQueued — нажали кнопку (съедается в ближайшем кадре на земле),
-- jumping — после подброса считаем себя «в воздухе», пока центр саней выше JUMP_GROUND_DIST
local jumpQueued, jumping, lastJump = false, false, 0

-- Трюки (docs/GAME_DESIGN.md → «Трюки»). trick — текущее вращение { id, def, angle, dir, released };
-- завершённые за полёт копятся в airTricks и при приземлении уходят одним Trick:FireServer(list, airTime)
type Trick = { id: string, def: any, angle: number, dir: number, released: boolean }
local trick: Trick? = nil
local airTricks: { [string]: number } = {}
local airTrickOrder: { string } = {} -- порядок первых выполнений (для комбо и подписи)
local trickHeldSince = 0 -- когда зажали Пробел
local trickStartedThisPress = false -- в этом нажатии уже началось вращение (не считать тапом)
local lastTapAt = 0 -- короткий тап в воздухе: второй в TRICK_DOUBLE_TAP = разворот
local pendingGrab = false -- тап ждёт окно двойного нажатия, потом становится грэбом
local grabUntil = 0 -- анимация грэба (наклон саней)

------------------------------------------------------------------ ввод
-- Рогатка: зажал → тянешь вниз (санки отъезжают назад, резинка натягивается) → отпустил = выстрел.
-- Сила = насколько сильно оттянул. Клавиатура/геймпад: держи Пробел/A — натяжение растёт само.
local UIS = game:GetService("UserInputService")
local PULL_BACK = 9 -- studs, на сколько санки отъезжают при полном натяжении
local PULL_SCREEN = 0.28 -- доля высоты экрана для полного натяжения
local PULL_KEY_TIME = 1.1 -- секунд удержания клавиши до 100%
local MIN_PULL = 0.12 -- меньше — считаем, что передумал

local launchSent = false
local pulling = false
local pullInput: InputObject? = nil
local pullStartY = 0
local keyPull = false
local pullAmount = 0
local baseCF: CFrame? = nil

local function setPull(a: number)
	pullAmount = math.clamp(a, 0, 1)
	meterValue.Value = pullAmount
	local s = sled
	if s and s.Anchored and baseCF then
		-- локально (только у себя) отводим санки назад: резинка-Beam тянется за ними
		s.CFrame = baseCF * CFrame.new(0, 0, PULL_BACK * pullAmount)
	end
end

local function fireLaunch(power: number)
	if awaitingLaunch.Value and not launchSent then
		launchSent = true
		awaitingLaunch.Value = false
		Remotes.Launch:FireServer(power)
		sfx:Fire("launch")
	end
end

local function beginPull(input: InputObject?)
	if not awaitingLaunch.Value or launchSent or pulling then
		return
	end
	local s = sled
	if not s then
		return
	end
	pulling = true
	pullInput = input
	keyPull = input == nil
	pullStartY = if input then input.Position.Y else 0
	baseCF = baseCF or s.CFrame
	setPull(0)
	sfx:Fire("pull")
end

local function releasePull()
	if not pulling then
		return
	end
	pulling, keyPull, pullInput = false, false, nil
	local power = pullAmount
	if sled and baseCF then
		sled.CFrame = baseCF -- возвращаем санки к рогатке: дальше их везёт физика
	end
	setPull(0)
	if power >= MIN_PULL then
		fireLaunch(power)
	end
end

-- Старый путь (кнопка HUD) — полный выстрел
requestLaunch.Event:Connect(function()
	fireLaunch(1)
end)

UIS.InputBegan:Connect(function(input)
	-- processed не проверяем: на телефоне касание в зоне стика помечено как «обработанное»
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		beginPull(input)
	end
end)
UIS.InputChanged:Connect(function(input)
	if not pulling or keyPull then
		return
	end
	local isMouse = input.UserInputType == Enum.UserInputType.MouseMovement
		and pullInput
		and pullInput.UserInputType == Enum.UserInputType.MouseButton1
	if isMouse or input == pullInput then
		local cam = workspace.CurrentCamera
		local h = if cam then cam.ViewportSize.Y else 800
		setPull((input.Position.Y - pullStartY) / (h * PULL_SCREEN))
	end
end)
UIS.InputEnded:Connect(function(input)
	if not pulling or keyPull then
		return
	end
	if input == pullInput or input.UserInputType == Enum.UserInputType.MouseButton1 then
		releasePull()
	end
end)

-- Трюки: начать вращение / засчитать выполненный
local function startTrick(id: string, dir: number?)
	local def = Config.TRICKS[id]
	if not def then
		return
	end
	trick = { id = id, def = def, angle = 0, dir = dir or def.dir or 1, released = false }
	pendingGrab = false
end
local function completeTrick(id: string)
	if not airTricks[id] then
		airTricks[id] = 0
		table.insert(airTrickOrder, id)
	end
	airTricks[id] += 1
	local def = Config.TRICKS[id]
	trickPopup:Fire("✨ " .. def.name .. (if airTricks[id] > 1 then " x" .. airTricks[id] else ""))
end
local function clearAirTricks()
	table.clear(airTricks)
	table.clear(airTrickOrder)
	trick = nil
	pendingGrab = false
	trickStartedThisPress = false
end

-- Пробел / 🔄: у рогатки — натяжение; в воздухе — трюки (удержание = вращение, тап = грэб,
-- двойной тап = разворот). Какое вращение — решает кадр физики по рулю (см. Heartbeat).
local function onTrickKey(_, inputState: Enum.UserInputState)
	if awaitingLaunch.Value or (pulling and keyPull) then
		if inputState == Enum.UserInputState.Begin then
			beginPull(nil)
		elseif inputState == Enum.UserInputState.End then
			releasePull()
		end
		return Enum.ContextActionResult.Sink
	end
	local now = os.clock()
	if inputState == Enum.UserInputState.Begin then
		flipHeld = true
		trickHeldSince = now
		trickStartedThisPress = false
		if airborne and not trick and now - lastTapAt < Config.TRICK_DOUBLE_TAP then
			startTrick("spin")
			trickStartedThisPress = true
			lastTapAt = 0
		end
	elseif inputState == Enum.UserInputState.End then
		flipHeld = false
		if airborne and not trick and not trickStartedThisPress and now - trickHeldSince < Config.TRICK_TAP_TIME then
			lastTapAt = now
			pendingGrab = true -- станет грэбом, если за TRICK_DOUBLE_TAP не пришло второе нажатие
		end
	end
	return Enum.ContextActionResult.Sink
end
-- Прыжок с земли (Ctrl / W / ButtonX / ⤴): срабатывает в ближайшем кадре на снегу
local function onJump(_, inputState: Enum.UserInputState)
	if inputState == Enum.UserInputState.Begin and not awaitingLaunch.Value then
		jumpQueued = true
	end
	return Enum.ContextActionResult.Sink
end
local function onRocket(_, inputState: Enum.UserInputState)
	rocketHeld = inputState == Enum.UserInputState.Begin
	return Enum.ContextActionResult.Sink
end
rocketInput.Event:Connect(function(held: boolean)
	rocketHeld = held
end)

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
	s.AssemblyLinearVelocity = fwd * math.min(speed, 60) * 0.35 + fwd:Cross(Vector3.yAxis) * side * 6 + Vector3.new(0, 28, 0)
	s.AssemblyAngularVelocity = Vector3.new(-9, side * 2, side * 5) -- кувырок через «нос»
	-- Персонаж вылетает из санок и кувыркается (суставы-шарниры ставит сервер)
	local hum = humanoid
	local root = hum and hum.Parent and hum.Parent:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hum and root then
		local weld = s:FindFirstChild("SeatWeld")
		if weld then
			weld:Destroy()
		end
		hum.Sit = false
		hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
		hum:ChangeState(Enum.HumanoidStateType.Physics)
		root.AssemblyLinearVelocity = fwd * math.clamp(speed, 25, 70) * 0.8 + Vector3.new(0, 30, 0)
		root.AssemblyAngularVelocity = fwd:Cross(Vector3.yAxis) * -8 + Vector3.new(0, side * 3, 0)
	end
	-- Монеты разлетаются вокруг (только эффект)
	local origin = s.Position
	for i = 1, 14 do
		local c = Instance.new("Part")
		c.Shape = Enum.PartType.Cylinder
		c.Size = Vector3.new(0.3, 1.4, 1.4)
		c.Color = Color3.fromRGB(255, 200, 40)
		c.Material = Enum.Material.SmoothPlastic
		c.CanCollide = true
		c.CanQuery = false
		c.CanTouch = false
		c.CollisionGroup = "Riders"
		c.CFrame = CFrame.new(origin + Vector3.new(0, 2, 0)) * CFrame.Angles(math.random() * 6, math.random() * 6, 0)
		c.Parent = workspace
		c.AssemblyLinearVelocity = fwd * speed * 0.3 + Vector3.new(math.random(-20, 20), math.random(18, 34), math.random(-20, 20))
		c.AssemblyAngularVelocity = Vector3.new(math.random(-10, 10), math.random(-10, 10), math.random(-10, 10))
		game:GetService("Debris"):AddItem(c, 2.5 + i * 0.03)
	end
	speed = 0
	rocketOn.Value = false
	speedValue.Value = 0
	trickPopup:Fire("💥 Врезался!")
	sfx:Fire("hit")
	Remotes.Crash:FireServer()
end

-- Лёгкие препятствия (снеговик, бочки, конусы…) разлетаются, если врезаться с ракетой или на ускорении
local smashed: { [Instance]: boolean } = {}
local function breakableOf(hit: BasePart): Model?
	local node: Instance? = hit.Parent
	while node and node ~= workspace do
		if node:GetAttribute("Breakable") then
			return node :: Model
		end
		node = node.Parent
	end
	return nil
end
local function smash(model: Model)
	if smashed[model] then
		return
	end
	smashed[model] = true
	local s = sled
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.LocalTransparencyModifier = 1
			p.CanTouch = false
			p.CanQuery = false
			-- обломки
			if p.Size.Magnitude > 1.5 and s then
				local chunk = Instance.new("Part")
				chunk.Size = p.Size * 0.45
				chunk.Color = p.Color
				chunk.Material = p.Material
				chunk.CFrame = p.CFrame
				chunk.CanCollide = true
				chunk.CanQuery = false
				chunk.CanTouch = false
				chunk.CollisionGroup = "Riders"
				chunk.Parent = workspace
				chunk.AssemblyLinearVelocity = fwd * (speed * 0.8 + 10) + Vector3.new(math.random(-18, 18), math.random(15, 35), math.random(-18, 18))
				chunk.AssemblyAngularVelocity = Vector3.new(math.random(-12, 12), math.random(-12, 12), math.random(-12, 12))
				game:GetService("Debris"):AddItem(chunk, 2.5)
			end
		end
	end
	speed *= 0.92
	trickPopup:Fire("💥 Удар!  +" .. Config.SMASH_COINS)
	sfx:Fire("smash")
	Remotes.Smash:FireServer()
end

local magnetUntil = 0
local x2Until = 0
local coinScan = 10
local nearCoins: { BasePart } = {}
local lastPos: Vector3? = nil
local COIN_PICK_R = 3.6 -- радиус подбора монеты (по горизонтали)
local magnetScan = 0
local function hideLocal(p: BasePart)
	p.LocalTransparencyModifier = 1
	for _, d in p:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = 1
		elseif d:IsA("ParticleEmitter") or d:IsA("Light") then
			d.Enabled = false
		end
	end
end

-- Ледяной кристалл: разлетается осколками, сервер даёт монеты и гем
local crystalDone: { [Instance]: boolean } = {}
local function breakCrystal(hit: BasePart)
	local model = hit.Parent
	if not model or crystalDone[model] then
		return
	end
	crystalDone[model] = true
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") then
			hideLocal(p)
			for _ = 1, 3 do
				local shard = Instance.new("Part")
				shard.Size = Vector3.new(0.8, 1.6, 0.8)
				shard.Color = p.Color
				shard.Material = Enum.Material.Glass
				shard.Transparency = 0.2
				shard.CFrame = p.CFrame
				shard.CanQuery = false
				shard.CanTouch = false
				shard.CollisionGroup = "Riders"
				shard.Parent = workspace
				shard.AssemblyLinearVelocity = fwd * speed * 0.6 + Vector3.new(math.random(-20, 20), math.random(15, 35), math.random(-20, 20))
				game:GetService("Debris"):AddItem(shard, 2)
			end
		end
	end
	trickPopup:Fire("💎 Кристалл!  +" .. Config.CRYSTAL_COINS .. " 💰 +1 💎")
	sfx:Fire("crystal")
	Remotes.Crystal:FireServer(hit)
end

local function onTouched(hit: BasePart)
	local now = os.clock()
	if CollectionService:HasTag(hit, "Crystal") then
		if started and not crashed then
			breakCrystal(hit)
		end
		return
	elseif CollectionService:HasTag(hit, "Gem") then
		if hit.LocalTransparencyModifier < 1 then
			hideLocal(hit)
			trickPopup:Fire("💎 +1 гем!")
			sfx:Fire("gem")
		end
		return
	elseif CollectionService:HasTag(hit, "PowerUp") then
		-- Бонусы: щит, x2 монеты, канистра, кольца (монеты и x2 засчитывает сервер)
		if hit.LocalTransparencyModifier < 1 and started and not crashed then
			hideLocal(hit)
			local kind = hit:GetAttribute("Kind")
			local holder = hit.Parent :: Instance
			if kind ~= "ring" then
				for _, d in holder:GetChildren() do
					if d:IsA("BasePart") and (d.Position - hit.Position).Magnitude < 5 then
						d.LocalTransparencyModifier = 1
					end
				end
			end
			if kind == "shield" or kind == "fuel" then
				Remotes.PowerUp:FireServer(hit) -- для заданий дня
			end
			if kind == "shield" then
				shieldOn.Value = true
				trickPopup:Fire("🛡 Щит!")
				sfx:Fire("reward")
			elseif kind == "fuel" then
				fuel = fuelMaxValue.Value
				fuelValue.Value = fuel
				trickPopup:Fire("⛽ Полный бак!")
				sfx:Fire("boost")
			elseif kind == "x2" then
				x2Until = now + Config.POWERUPS.x2.time
				trickPopup:Fire("✖2 Монеты x2!")
				sfx:Fire("record")
				Remotes.PowerUp:FireServer(hit)
			elseif kind == "ring" then
				trickPopup:Fire("💍 Кольцо! +" .. Config.POWERUPS.rings.coins)
				sfx:Fire("coin")
				Remotes.PowerUp:FireServer(hit)
			end
		end
		return
	elseif CollectionService:HasTag(hit, "Magnet") then
		if hit.LocalTransparencyModifier < 1 then
			hideLocal(hit)
			for _, d in (hit.Parent :: Instance):GetChildren() do
				if d:IsA("BasePart") and (d.Position - hit.Position).Magnitude < 4 then
					d.LocalTransparencyModifier = 1
				end
			end
			magnetUntil = now + Config.MAGNET_TIME
			Remotes.PowerUp:FireServer(hit) -- для заданий дня
			trickPopup:Fire("🧲 Магнит!")
			sfx:Fire("magnet")
		end
		return
	end
	if CollectionService:HasTag(hit, "Obstacle") then
		if crashed or not started or now - lastObstacle < 0.5 then
			return
		end
		local breakable = breakableOf(hit)
		if breakable then
			if smashed[breakable] then
				return
			end
			if rocketOn.Value or now - lastBoost < 1.5 then
				smash(breakable)
				return
			end
		end
		lastObstacle = now
		if shieldOn.Value then
			-- щит принимает удар: препятствие исчезает, скорость немного падает
			shieldOn.Value = false
			local model = hit:FindFirstAncestorOfClass("Model") or hit
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then
					d.LocalTransparencyModifier = 1
					d.CanCollide = false -- только у себя: санки (их считает клиент) проезжают сквозь
				end
			end
			if model:IsA("BasePart") then
				hideLocal(model)
			end
			speed *= 0.75
			trickPopup:Fire("🛡 Щит спас!")
			sfx:Fire("smash")
			return
		end
		crash()
	elseif CollectionService:HasTag(hit, "Boost") then
		if now - lastBoost < 0.4 then
			return
		end
		lastBoost = now
		Remotes.PowerUp:FireServer(hit) -- для заданий дня
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
	ContextActionService:UnbindAction("Jump")
	ContextActionService:UnbindAction("Rocket")
	if controls then
		pcall(controls.Enable, controls)
	end
	stickOn.Value = false
	awaitingLaunch.Value = false
	pulling, keyPull, pullInput, baseCF = false, false, nil, nil
	meterValue.Value = 0
	local cam = workspace.CurrentCamera
	if cam and cam.CameraType == Enum.CameraType.Scriptable then
		cam.CameraType = Enum.CameraType.Custom
	end
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
	fwd = Vector3.new(0, 0, -1)
	started = false
	crashed = false
	airborne, flipHeld, rocketHeld = false, false, false
	jumpQueued, jumping, lastJump = false, false, 0
	clearAirTricks()
	lastTapAt, grabUntil = 0, 0
	magnetUntil = 0
	magnetLeft.Value = 0
	x2Until = 0
	x2Left.Value = 0
	lastPos = nil
	coinScan = 10
	shieldOn.Value = false
	fuel = Config.rocketFuel(player:GetAttribute("RocketLevel") or 0)
	fuelMaxValue.Value = fuel
	fuelValue.Value = fuel

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
	if controls and UserInputService.TouchEnabled then
		pcall(controls.Disable, controls)
	end

	-- Рогатка: ждём, пока игрок оттянет и отпустит
	launchSent = false
	pulling, keyPull, pullInput, baseCF = false, false, nil, nil
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
		-- Ждём рогатку: при удержании клавиши натяжение растёт само
		if pulling and keyPull then
			setPull(pullAmount + dt / PULL_KEY_TIME)
		end
		-- Камера закреплена за рогаткой (как в оригинале), чтобы свайп не крутил её
		local cam = workspace.CurrentCamera
		if cam then
			local base = baseCF or s.CFrame
			cam.CameraType = Enum.CameraType.Scriptable
			local eye = (base * CFrame.new(0, 7 + pullAmount * 2, 17 + pullAmount * 6)).Position
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
	-- Бонус модели и редкости саней (+% скорости): выше потолок и меньше трение
	local sledBonus = s:GetAttribute("SledBonus") or 0
	local maxSpeed = Config.maxSpeed(sledLevel) * (1 + sledBonus)
	local useRocket = rocketHeld and fuel > 0
	if useRocket then
		fuel = math.max(0, fuel - dt)
	end
	rocketOn.Value = useRocket
	fuelValue.Value = fuel

	-- Подбор монет по расстоянию: Touched на скорости пропускает тонкие монеты, поэтому
	-- проверяем весь отрезок пути санок за кадр (без «туннелирования»); засчитывает сервер
	coinScan += dt
	if coinScan > 0.4 then
		coinScan = 0
		table.clear(nearCoins)
		for _, coin in CollectionService:GetTagged("Coin") do
			if coin:IsA("BasePart") and coin.LocalTransparencyModifier < 1 and (coin.Position - s.Position).Magnitude < 160 then
				table.insert(nearCoins, coin)
			end
		end
	end
	if not crashed then
		local p0, p1 = lastPos or s.Position, s.Position
		local ab = p1 - p0
		local len2 = ab:Dot(ab)
		for i = #nearCoins, 1, -1 do
			local coin = nearCoins[i]
			if coin.LocalTransparencyModifier >= 1 or coin:GetAttribute("Taken") then
				table.remove(nearCoins, i)
				continue
			end
			local p = coin.Position
			local t = if len2 > 0 then math.clamp((p - p0):Dot(ab) / len2, 0, 1) else 0
			local d = p - (p0 + ab * t)
			if Vector3.new(d.X, 0, d.Z).Magnitude < COIN_PICK_R and d.Y > -3 and d.Y < 7 then
				hideLocal(coin)
				Remotes.CoinGrab:FireServer(coin)
				sfx:Fire("coin")
				table.remove(nearCoins, i)
			end
		end
	end
	lastPos = s.Position

	-- Магнит: притягиваем монеты рядом (анимация у себя, засчитывает сервер)
	local mLeft = math.max(0, magnetUntil - os.clock())
	magnetLeft.Value = mLeft
	x2Left.Value = math.max(0, x2Until - os.clock())
	if mLeft > 0 and not crashed then
		magnetScan += dt
		if magnetScan > 0.1 then
			magnetScan = 0
			for _, coin in CollectionService:GetTagged("Coin") do
				if coin:IsA("BasePart") and coin.LocalTransparencyModifier < 1 and not coin:GetAttribute("Taken")
					and (coin.Position - s.Position).Magnitude < Config.MAGNET_RADIUS then
					hideLocal(coin)
					Remotes.CoinGrab:FireServer(coin)
					sfx:Fire("coin")
					-- летящая к санкам копия монеты
					local ghost = Instance.new("Part")
					ghost.Shape = Enum.PartType.Cylinder
					ghost.Size = Vector3.new(0.45, 3, 3)
					ghost.Color = Color3.fromRGB(255, 196, 45)
					ghost.Anchored = true
					ghost.CanCollide = false
					ghost.CanQuery = false
					ghost.CanTouch = false
					ghost.CFrame = coin.CFrame
					ghost.Parent = workspace
					local target = s
					task.spawn(function()
						local t0 = os.clock()
						while ghost.Parent and os.clock() - t0 < 0.35 do
							local k = (os.clock() - t0) / 0.35
							ghost.CFrame = ghost.CFrame:Lerp(target.CFrame + Vector3.new(0, 2, 0), k)
							task.wait()
						end
						ghost:Destroy()
					end)
				end
			end
		end
	end

	-- Подстраховка к Touched: машины и кабинки двигаются кадрами (CFrame), касание может не прийти
	if started and not crashed then
		for _, p in workspace:GetPartBoundsInBox(s.CFrame * CFrame.new(0, 1.5, 0), Vector3.new(6, 4, 7), overlapParams) do
			if CollectionService:HasTag(p, "Obstacle") then
				onTouched(p)
				break
			end
		end
	end

	local hit = workspace:Raycast(s.Position, Vector3.new(0, -4, 0), rayParams)
	local vel = s.AssemblyLinearVelocity
	local steer = readSteer(s)
	local now = os.clock()
	-- После прыжка с ровного места луч до снега короче 4 studs почти весь полёт — поэтому
	-- «в воздухе» считаем по высоте центра саней над снегом (JUMP_GROUND_DIST)
	local grounded = hit ~= nil and (not jumping or hit.Distance <= Config.JUMP_GROUND_DIST)
	-- Грэб: тап в воздухе, за TRICK_DOUBLE_TAP не стало разворотом
	if pendingGrab and now - lastTapAt >= Config.TRICK_DOUBLE_TAP then
		pendingGrab = false
		if airborne and not trick and airTime >= Config.TRICKS.grab.minAir then
			grabUntil = now + Config.GRAB_TIME
			completeTrick("grab")
		end
	end

	if grounded and hit then
		-- На земле: считаем скорость сами
		local n = hit.Normal
		updateForward(hit.Instance)
		local d = (fwd - n * fwd:Dot(n)).Unit
		local right = d:Cross(n)

		-- Трамплин — пусковая площадка: скорость на нём не теряется, и он подбрасывает вверх
		local onRamp = hit.Instance.Name == "Ramp"
		local acc = if onRamp
			then 0
			else -Config.GRAVITY_ALONG * d.Y - Config.friction(sledLevel) * (1 - sledBonus) - Config.DRAG * speed * speed
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

		-- Руль с инерцией + борта скатывают к центру (right.Y > 0 — мы на наклонном борту).
		-- Боковая скорость растёт вместе с продольной (Config.steerSpeed): время смены полосы
		-- не зависит от скорости (docs/GAME_DESIGN.md → «Скорость и руль»)
		local steerMax = Config.steerSpeed(speed)
		lateral += (steer * steerMax - lateral) * math.min(1, dt * Config.STEER_RESPONSE)
		lateral -= Config.WALL_PULL * right.Y * dt

		local vn = vel:Dot(n)
		if onRamp then
			vn = math.max(vn, speed * Config.RAMP_LIFT)
		end
		-- Прыжок: подброс вверх по нормали; дальше тот же путь, что и с трамплина (airborne → трюки)
		if jumpQueued and not onRamp and not airborne and now - lastJump >= Config.JUMP_COOLDOWN then
			lastJump = now
			jumping = true
			-- на борту жёлоба (Bank) подброс слабее: от стенки не оттолкнёшься как от ровного снега
			vn = math.max(vn, Config.JUMP_SPEED * (if hit.Instance.Name == "Bank" then 0.7 else 1))
			sfx:Fire("jump")
		end
		jumpQueued = false
		if jumping and not airborne and now - lastJump > Config.JUMP_COOLDOWN then
			jumping = false -- подброс не оторвал от снега (горка в борт) — сбрасываем режим
		end
		s.AssemblyLinearVelocity = d * speed + right * lateral + n * vn
		a.Enabled = true
		-- Наклон в поворот: ватрушка кренится и чуть разворачивается по направлению движения
		local tilt = math.rad(Config.STEER_TILT) * math.clamp(lateral / steerMax, -1, 1)
		a.CFrame = CFrame.lookAt(Vector3.zero, d, n) * CFrame.Angles(0, -tilt * 0.5, -tilt)

		-- Приземление
		if airborne then
			airborne = false
			jumping = false
			if airTime > 0.35 then
				sfx:Fire("land")
			end
			-- Air time: бонус за долгий полёт (как в оригинале)
			if airTime >= Config.AIR_MIN_TIME then
				Remotes.Air:FireServer(airTime)
				trickPopup:Fire(string.format("✈ Air time %.1fс  +%d", airTime, math.floor(math.min(airTime, 4) * Config.AIR_COINS_PER_SEC)))
			end
			-- Грэб, который ещё ждал окно двойного тапа, засчитываем перед итогом
			if pendingGrab and not trick and airTime >= Config.TRICKS.grab.minAir then
				completeTrick("grab")
			end
			-- Недокрученный трюк: ≥ 3/4 оборота прощаем, иначе смотрим, как сели
			local fell = false
			local t = trick
			if t then
				if math.floor((t.angle + math.pi / 2) / (2 * math.pi)) >= 1 then
					completeTrick(t.id)
				else
					local upright
					if t.def.kind == "yaw" then
						local rest = t.angle % (2 * math.pi)
						upright = rest < math.pi / 3 or rest > 5 * math.pi / 3
					else
						upright = s.CFrame.UpVector:Dot(n) > 0.5
					end
					fell = not upright
				end
			end
			if fell then
				speed *= Config.OBSTACLE_SLOWDOWN
				trickPopup:Fire("😵 Падение!")
				sfx:Fire("smash")
			elseif #airTrickOrder > 0 then
				-- Итог полёта: список серверу, буст и подпись («Сальто + Бочка! ×1.5 +52»)
				local list = {}
				local names = {}
				local coins, boost = 0, 1
				for _, id in airTrickOrder do
					local def = Config.TRICKS[id]
					local count = math.min(airTricks[id], Config.TRICK_MAX_COUNT)
					table.insert(list, { id = id, count = count })
					table.insert(names, def.name .. (if count > 1 then " x" .. count else ""))
					coins += def.coins * count
					boost *= def.boost ^ count
				end
				local mult = Config.trickComboMult(#airTrickOrder)
				speed *= boost
				Remotes.Trick:FireServer(list, airTime)
				sfx:Fire("flip")
				trickPopup:Fire(table.concat(names, " + ") .. "! " .. (if mult > 1 then "×" .. mult .. " " else "") .. "+" .. math.floor(coins * mult) .. " 💰")
			end
			clearAirTricks()
		end
		airTime = 0
	else
		-- В воздухе: летим по физике, немного рулим, ракета толкает вперёд
		airborne = true
		airTime += dt
		local rightH = fwd:Cross(Vector3.yAxis)
		local along = vel:Dot(fwd)
		speed = math.max(0, along)
		lateral += (steer * Config.steerSpeed(speed) * 0.6 - lateral) * math.min(1, dt * Config.STEER_RESPONSE * 0.5)
		local newVel = fwd * along + rightH * lateral + Vector3.new(0, vel.Y, 0)
		if useRocket then
			newVel += fwd * Config.ROCKET_THRUST * dt
		end
		s.AssemblyLinearVelocity = newVel

		-- Отпустил и снова зажал — докручиваем тот же трюк
		if trick and trick.released and flipHeld and not trickStartedThisPress then
			trick.released = false
			trickStartedThisPress = true
		end
		-- Удержание Пробела дольше тапа начинает вращение; какое — решает руль в этот момент
		if flipHeld and not trick and not trickStartedThisPress and now - trickHeldSince >= Config.TRICK_TAP_TIME then
			if readPitchDown() then
				startTrick("frontflip")
			elseif math.abs(steer) > 0.5 then
				startTrick("roll", if steer > 0 then 1 else -1)
			else
				startTrick("flip")
			end
			trickStartedThisPress = true
		end
		local t = trick
		if t then
			local kind = t.def.kind
			if not flipHeld and kind ~= "yaw" and not t.released then
				local rest = t.angle % (2 * math.pi)
				if rest < math.pi / 6 or rest > 11 * math.pi / 6 then
					trick = nil -- отпустил почти ровно (оборот уже засчитан) — сани выравниваются
					t = nil
				else
					t.released = true -- отпустил на полпути: сани замирают как есть, приземление покажет
				end
			end
		end
		if t then
			local kind = t.def.kind
			a.Enabled = false
			if t.released then
				s.AssemblyAngularVelocity = Vector3.zero
			else
				local axis = if kind == "pitch" then rightH elseif kind == "roll" then fwd else Vector3.yAxis
				s.AssemblyAngularVelocity = axis * (Config.FLIP_SPEED * t.dir)
				t.angle += Config.FLIP_SPEED * dt
				if t.angle >= 2 * math.pi then
					completeTrick(t.id)
					if kind == "yaw" then
						trick = nil -- разворот одиночный: дальше сани выравниваются
					else
						t.angle -= 2 * math.pi -- удержание крутит дальше (Сальто x2…)
					end
				end
			end
		else
			a.Enabled = true
			local pose = CFrame.lookAt(Vector3.zero, fwd, Vector3.yAxis)
			if grabUntil > now then
				pose *= CFrame.Angles(math.rad(25), 0, 0) -- грэб: нос вверх
			end
			a.CFrame = pose
		end
	end
	speedValue.Value = speed
end)
