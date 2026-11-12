-- Общее состояние санок на клиенте (часть SledController, см. client/SledController): переменные,
-- которые делят ввод, рогатка, трюки, касания и кадр физики, и объекты под скриптом-контроллером
-- (State, Sfx, RequestLaunch, RocketInput, TrickPopup) — их читают HUD, Effects, Sounds, Tutorial.
-- State.init(controller) вызывает контроллер первым делом, до require остальных модулей Sled/.

local Players = game:GetService("Players")

local State = {
	-- сани и персонаж текущего заезда
	sled = nil :: VehicleSeat?,
	align = nil :: AlignOrientation?,
	humanoid = nil :: Humanoid?,
	controls = nil :: any, -- PlayerModule:GetControls() (client/Sled/Input)
	-- Направление «вниз по трассе» (из куска трассы под санками, см. updateForward в контроллере)
	fwd = Vector3.new(0, 0, -1),
	speed = 0,
	lateral = 0, -- боковая скорость (с инерцией)
	airTime = 0,
	started = false,
	fuel = 0,
	rocketHeld = false,
	flipHeld = false,
	airborne = false,
	lastObstacle = 0,
	lastBoost = 0,
	-- Прыжок с земли: jumpQueued — нажали кнопку (съедается в ближайшем кадре на земле),
	-- jumping — после подброса считаем себя «в воздухе», пока центр саней выше JUMP_GROUND_DIST
	jumpQueued = false,
	jumping = false,
	lastJump = 0,
	-- Трюки (client/Sled/Tricks): текущее вращение и нажатия
	trick = nil :: any, -- Tricks.Trick?
	trickHeldSince = 0, -- когда зажали Пробел
	trickStartedThisPress = false, -- в этом нажатии уже началось вращение (не считать тапом)
	lastTapAt = 0, -- короткий тап в воздухе: второй в TRICK_DOUBLE_TAP = разворот
	pendingGrab = false, -- тап ждёт окно двойного нажатия, потом становится грэбом
	grabUntil = 0, -- анимация грэба (наклон саней)
	autoPlanned = false, -- план авто-трюков на полёт уже выбран
	autoBonus = 0, -- нажатия во время авто-трюка
	-- Рогатка (client/Sled/Launch)
	launchSent = false,
	pulling = false,
	pullInput = nil :: InputObject?,
	pullStartY = 0,
	keyPull = false,
	pullAmount = 0,
	baseCF = nil :: CFrame?,
	-- Авария и подбор (client/Sled/Contacts)
	crashed = false,
	crashTime = 0,
	magnetUntil = 0,
	x2Until = 0,
	coinScan = 10,
	lastPos = nil :: Vector3?,
	magnetScan = 0,
	-- таблицы, общие для модулей (меняются на месте)
	connections = {} :: { RBXScriptConnection },
	airTricks = {} :: { [string]: number }, -- трюки, завершённые за полёт (id → сколько раз)
	airTrickOrder = {} :: { string }, -- порядок первых выполнений (для комбо и подписи)
	autoQueue = {} :: { string }, -- что ещё выполнить авто-трюками
	player = Players.LocalPlayer,
} :: { [string]: any }

function State.init(controller: Instance)
	State.controller = controller
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
	local airborneValue = value("Airborne", "BoolValue") -- в полёте (client/Tutorial)
	local airTimeValue = value("AirTime") -- секунды текущего полёта (HUD: счётчик ✈, #57)
	state.Parent = controller

	-- Звуковые события для Sounds-скрипта: sfx:Fire(имя, [число]) — список в docs/GAME_DESIGN.md → «Звук»
	local sfx = Instance.new("BindableEvent")
	sfx.Name = "Sfx"
	sfx.Parent = controller

	-- HUD-кнопка «Запуск» дёргает это событие
	local requestLaunch = Instance.new("BindableEvent")
	requestLaunch.Name = "RequestLaunch"
	requestLaunch.Parent = controller

	-- Кнопка ракеты в HUD (под спидометром): RocketInput:Fire(true/false)
	local rocketInput = Instance.new("BindableEvent")
	rocketInput.Name = "RocketInput"
	rocketInput.Parent = controller

	local trickPopup = Instance.new("BindableEvent")
	trickPopup.Name = "TrickPopup" -- (текст) — HUD показывает всплывашку
	trickPopup.Parent = controller

	local overlapParams = OverlapParams.new()
	overlapParams.CollisionGroup = "Riders" -- не видит себя и других райдеров
	overlapParams.RespectCanCollide = false

	local rayParams = RaycastParams.new()
	rayParams.CollisionGroup = "Riders" -- луч не видит райдеров
	rayParams.RespectCanCollide = true -- и проходит сквозь монеты/препятствия

	State.state = state
	State.speedValue = speedValue
	State.fuelValue = fuelValue
	State.fuelMaxValue = fuelMaxValue
	State.rocketOn = rocketOn
	State.meterValue = meterValue
	State.awaitingLaunch = awaitingLaunch
	State.magnetLeft = magnetLeft
	State.shieldOn = shieldOn
	State.x2Left = x2Left
	State.airborneValue = airborneValue
	State.airTimeValue = airTimeValue
	State.sfx = sfx
	State.requestLaunch = requestLaunch
	State.rocketInput = rocketInput
	State.trickPopup = trickPopup
	State.overlapParams = overlapParams
	State.rayParams = rayParams
end

return State
