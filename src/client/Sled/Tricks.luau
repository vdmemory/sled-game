-- Трюки (часть SledController, идея #42): ручные (удержание Пробела — сальто/бочка по рулю,
-- тап — грэб, двойной тап — разворот), авто-трюки по предсказанному полёту (#39), итог полёта
-- при приземлении (Remotes.Trick). Кнопки прыжка и ракеты.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local st = require(script.Parent.State)
local Input = require(script.Parent.Input)
local Launch = require(script.Parent.Launch)

local awaitingLaunch = st.awaitingLaunch
local sfx = st.sfx
local rocketInput = st.rocketInput
local trickPopup = st.trickPopup
local rayParams = st.rayParams
local airTricks = st.airTricks
local airTrickOrder = st.airTrickOrder
local autoQueue = st.autoQueue
local readPitchDown = Input.readPitchDown
local beginPull = Launch.beginPull
local releasePull = Launch.releasePull

-- Трюки (docs/GAME_DESIGN.md → «Трюки»). trick — текущее вращение { id, def, angle, dir, released };
-- завершённые за полёт копятся в airTricks и при приземлении уходят одним Trick:FireServer(list, airTime)
-- auto — авто-трюк (#39): крутится сам со скоростью speed, не «отпускается» и не даёт «Падения»
export type Trick = { id: string, def: any, angle: number, dir: number, released: boolean, auto: boolean?, speed: number? }

local Tricks = {}

-- Трюки: начать вращение / засчитать выполненный
local function startTrick(id: string, dir: number?)
	local def = Config.TRICKS[id]
	if not def then
		return
	end
	st.trick = { id = id, def = def, angle = 0, dir = dir or def.dir or 1, released = false }
	st.pendingGrab = false
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
	table.clear(autoQueue)
	st.trick = nil
	st.pendingGrab = false
	st.trickStartedThisPress = false
	st.autoPlanned = false
	st.autoBonus = 0
end

-- Сколько ещё секунд до касания снега: высота над трассой под санями, наклон трассы впереди
-- (второй луч через AUTO_TRICK_LOOKAHEAD с полёта по горизонтали) и вертикальная скорость.
-- Высота трассы впереди меняется линейно: h + (vy − rate)·t − g·t²/2 = 0.
local AUTO_UP = Vector3.new(0, 20, 0) -- лучи начинаем выше саней: впереди трасса может быть выше
local function predictAirLeft(s: BasePart, vel: Vector3): (number, number)
	local pos = s.Position
	local down = Vector3.new(0, -(Config.AUTO_TRICK_RAY + AUTO_UP.Y), 0)
	local below = workspace:Raycast(pos + AUTO_UP, down, rayParams)
	if not below then
		return Config.AUTO_TRICK_UNKNOWN_AIR, Config.AUTO_TRICK_RAY
	end
	local h = math.max(0, pos.Y - below.Position.Y - 0.5) -- центр саней на снегу ≈ 0.5 над ним
	local look = Config.AUTO_TRICK_LOOKAHEAD
	local ahead = workspace:Raycast(pos + Vector3.new(vel.X, 0, vel.Z) * look + AUTO_UP, down, rayParams)
	local rate = if ahead then (ahead.Position.Y - below.Position.Y) / look else 0
	local v = vel.Y - rate
	local g = workspace.Gravity
	return (v + math.sqrt(math.max(0, v * v + 2 * g * h))) / g, h
end

local AUTO_ROTATIONS = { "flip", "frontflip", "roll", "spin" }
-- Трюк-добавка: первый вращательный, которого ещё не было в этом полёте (даёт множитель комбо)
local function nextDistinctTrick(): string
	for _, id in AUTO_ROTATIONS do
		if not airTricks[id] and not table.find(autoQueue, id) and not (st.trick and st.trick.id == id) then
			return id
		end
	end
	return if airTricks.grab then "flip" else "grab"
end

-- План авто-трюков на полёт: ярус по предсказанному полёту, вариант по умолчанию или случайный,
-- оборотов не больше, чем сервер засчитает (maxRotations × AUTO_TRICK_SAFE_AIR)
local function planAutoTricks(total: number)
	local tier = nil
	for _, p in Config.AUTO_TRICK_PLANS do
		if total >= p.air then
			tier = p
		end
	end
	if not tier then
		return
	end
	local opts = tier.options
	local pick = opts[1]
	if #opts > 1 and math.random() < Config.AUTO_TRICK_RANDOM then
		pick = opts[math.random(2, #opts)]
	end
	local maxRot = Config.maxRotations(total * Config.AUTO_TRICK_SAFE_AIR)
	local rot = 0
	for _, id in pick do
		local def = Config.TRICKS[id]
		if def and not airTricks[id] then
			if def.kind == "grab" then
				table.insert(autoQueue, id)
			elseif rot < maxRot then
				rot += 1
				table.insert(autoQueue, id)
			end
		end
	end
end

-- Пробел / 🔄: у рогатки — натяжение; в воздухе — трюки (удержание = вращение, тап = грэб,
-- двойной тап = разворот). Какое вращение — решает кадр физики по рулю (см. Heartbeat).
local function onTrickKey(_, inputState: Enum.UserInputState)
	if awaitingLaunch.Value or (st.pulling and st.keyPull) then
		if inputState == Enum.UserInputState.Begin then
			beginPull(nil)
		elseif inputState == Enum.UserInputState.End then
			releasePull()
		end
		return Enum.ContextActionResult.Sink
	end
	local now = os.clock()
	if inputState == Enum.UserInputState.Begin then
		st.flipHeld = true
		st.trickHeldSince = now
		st.trickStartedThisPress = false
		if st.airborne and st.trick and st.trick.auto then
			-- во время авто-трюка нажатие = «ещё один» в комбо (выполнит та же авто-система)
			st.autoBonus = math.min(st.autoBonus + 1, 2)
			st.trickStartedThisPress = true
		elseif st.airborne and not st.trick and now - st.lastTapAt < Config.TRICK_DOUBLE_TAP then
			startTrick("spin")
			st.trickStartedThisPress = true
			st.lastTapAt = 0
		end
	elseif inputState == Enum.UserInputState.End then
		st.flipHeld = false
		if st.airborne and not st.trick and not st.trickStartedThisPress and now - st.trickHeldSince < Config.TRICK_TAP_TIME then
			st.lastTapAt = now
			st.pendingGrab = true -- станет грэбом, если за TRICK_DOUBLE_TAP не пришло второе нажатие
		end
	end
	return Enum.ContextActionResult.Sink
end
-- Прыжок с земли (Ctrl / W / ButtonX / ⤴): срабатывает в ближайшем кадре на снегу
local function onJump(_, inputState: Enum.UserInputState)
	if inputState == Enum.UserInputState.Begin and not awaitingLaunch.Value then
		st.jumpQueued = true
	end
	return Enum.ContextActionResult.Sink
end
local function onRocket(_, inputState: Enum.UserInputState)
	st.rocketHeld = inputState == Enum.UserInputState.Begin
	return Enum.ContextActionResult.Sink
end
rocketInput.Event:Connect(function(held: boolean)
	st.rocketHeld = held
end)

-- Приземление: недокрученный трюк, грэб из окна двойного тапа, итог полёта серверу.
-- n — нормаль снега под санями.
function Tricks.land(s: BasePart, n: Vector3)
	-- Грэб, который ещё ждал окно двойного тапа, засчитываем перед итогом
	if st.pendingGrab and not st.trick and st.airTime >= Config.TRICKS.grab.minAir then
		completeTrick("grab")
	end
	-- Недокрученный трюк: ≥ 3/4 оборота прощаем, иначе смотрим, как сели
	local fell = false
	local t = st.trick
	if t then
		if math.floor((t.angle + math.pi / 2) / (2 * math.pi)) >= 1 then
			completeTrick(t.id)
		elseif t.auto then
			fell = false -- недокрученный авто-трюк просто не засчитывается: приземление чистое
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
		st.speed *= Config.OBSTACLE_SLOWDOWN
		trickPopup:Fire("😵 Падение!")
		sfx:Fire("wipe")
	elseif #airTrickOrder > 0 then
		-- Итог полёта: список серверу, буст и подпись («Сальто + Бочка! ×1.5 +52»)
		local list = {}
		local names = {}
		local coins, boost = 0, 1
		-- оборотов не больше, чем сервер признает за этот полёт (иначе он отклонит весь список)
		local rotLeft = Config.maxRotations(st.airTime)
		for _, id in airTrickOrder do
			local def = Config.TRICKS[id]
			local count = math.min(airTricks[id], Config.TRICK_MAX_COUNT)
			if def.kind ~= "grab" then
				count = math.min(count, rotLeft)
				rotLeft -= count
			end
			if count <= 0 then
				continue
			end
			table.insert(list, { id = id, count = count })
			table.insert(names, def.name .. (if count > 1 then " x" .. count else ""))
			coins += def.coins * count
			boost *= def.boost ^ count
		end
		local mult = Config.trickComboMult(#airTrickOrder)
		st.speed *= boost
		Remotes.Trick:FireServer(list, st.airTime)
		sfx:Fire("flip", #list) -- тон растёт с числом трюков в комбо
		trickPopup:Fire(table.concat(names, " + ") .. "! " .. (if mult > 1 then "×" .. mult .. " " else "") .. "+" .. math.floor(coins * mult) .. " 💰")
	end
end

-- Кадр в воздухе: начать/докрутить ручной трюк, план и очередь авто-трюков, вращение саней.
-- a — стабилизатор саней, rightH — горизонталь вправо от направления трассы.
function Tricks.air(s: BasePart, a: AlignOrientation, vel: Vector3, steer: number, rightH: Vector3, now: number, dt: number)
	-- Отпустил и снова зажал — докручиваем тот же трюк
	if st.trick and st.trick.released and st.flipHeld and not st.trickStartedThisPress then
		st.trick.released = false
		st.trickStartedThisPress = true
	end
	-- Удержание Пробела дольше тапа начинает вращение; какое — решает руль в этот момент
	if st.flipHeld and not st.trick and not st.trickStartedThisPress and now - st.trickHeldSince >= Config.TRICK_TAP_TIME then
		if readPitchDown() then
			startTrick("frontflip")
		elseif math.abs(steer) > 0.5 then
			startTrick("roll", if steer > 0 then 1 else -1)
		else
			-- без руля — сальто, а если оно уже было в полёте — другой трюк (множитель комбо)
			startTrick(if airTricks.flip then nextDistinctTrick() else "flip")
		end
		st.trickStartedThisPress = true
	end
	-- Авто-трюки: план на полёт, затем очередь; скорость вращения — под остаток полёта
	local autoOn = Config.AUTO_TRICKS >= 1
	local needPredict = autoOn and (not st.autoPlanned or #autoQueue > 0 or st.autoBonus > 0 or (st.trick and st.trick.auto))
	local airLeft = 0
	if needPredict then
		local h
		airLeft, h = predictAirLeft(s, vel)
		-- план — только когда сани заметно в воздухе: тогда полёт видит и сервер (AntiCheat.trickAir)
		if not st.autoPlanned and h >= Config.AC_AIR_HEIGHT then
			st.autoPlanned = true
			planAutoTricks(st.airTime + airLeft)
		end
	end
	-- ждём, только если игрок держит Пробел под ручной трюк или тап ещё может стать разворотом
	if autoOn and not st.trick and not (st.flipHeld and not st.trickStartedThisPress) and not st.pendingGrab then
		if st.autoBonus > 0 then
			st.autoBonus -= 1
			table.insert(autoQueue, 1, nextDistinctTrick())
		end
		local budget = airLeft - Config.AUTO_TRICK_MARGIN
		while #autoQueue > 0 do
			local id = table.remove(autoQueue, 1)
			local def = Config.TRICKS[id]
			if def.kind == "grab" then
				if budget > 0 and st.airTime + airLeft >= def.minAir then
					st.grabUntil = now + Config.GRAB_TIME
					completeTrick(id)
				end
			elseif budget * Config.AUTO_TRICK_MAX_SPEED >= 2 * math.pi then
				-- целый оборот успевает даже на пределе скорости — начинаем
				startTrick(id, if def.kind == "roll" then (if math.random() < 0.5 then 1 else -1) else nil)
				local nt = (st.trick :: any) :: Trick -- startTrick присвоил trick; анализатор видит nil из сужения выше
				nt.auto = true
				break
			end
			-- не успевает — пропускаем, смотрим следующий
		end
	end
	local t = st.trick
	if t and t.auto then
		-- докручиваем к сроку: (остаток угла) / (остаток полёта − запас)
		local budget = math.max(0.01, airLeft - Config.AUTO_TRICK_MARGIN)
		t.speed = math.clamp((2 * math.pi - t.angle) / budget, Config.AUTO_TRICK_MIN_SPEED, Config.AUTO_TRICK_MAX_SPEED)
	end
	if t then
		local kind = t.def.kind
		if not st.flipHeld and kind ~= "yaw" and not t.released and not t.auto then
			local rest = t.angle % (2 * math.pi)
			if rest < math.pi / 6 or rest > 11 * math.pi / 6 then
				st.trick = nil -- отпустил почти ровно (оборот уже засчитан) — сани выравниваются
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
			local axis = if kind == "pitch" then rightH elseif kind == "roll" then st.fwd else Vector3.yAxis
			local w = t.speed or Config.FLIP_SPEED
			s.AssemblyAngularVelocity = axis * (w * t.dir)
			t.angle += w * dt
			if t.angle >= 2 * math.pi then
				completeTrick(t.id)
				if kind == "yaw" or t.auto then -- авто-трюк — один оборот, дальше очередь
					st.trick = nil -- разворот одиночный: дальше сани выравниваются
				else
					t.angle -= 2 * math.pi -- удержание крутит дальше (Сальто x2…)
				end
			end
		end
	else
		a.Enabled = true
		local pose = CFrame.lookAt(Vector3.zero, st.fwd, Vector3.yAxis)
		if st.grabUntil > now then
			pose *= CFrame.Angles(math.rad(25), 0, 0) -- грэб: нос вверх
		end
		a.CFrame = pose
	end
end

Tricks.startTrick = startTrick
Tricks.completeTrick = completeTrick
Tricks.clearAirTricks = clearAirTricks
Tricks.onTrickKey = onTrickKey
Tricks.onJump = onJump
Tricks.onRocket = onRocket

return Tricks
