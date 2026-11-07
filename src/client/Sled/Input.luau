-- Руль саней (часть SledController): клавиатура, стик/геймпад через PlayerModule, свайп пальцем
-- с плавающим кольцом (папка Stick под контроллером — её рисует HUD).

local UserInputService = game:GetService("UserInputService")

local st = require(script.Parent.State)

local player = st.player

local Input = {}

------------------------------------------------------------------ руль: читаем ввод сами
-- Не полагаемся на VehicleSeat.SteerFloat: он заполняется, только если клиент «увидел» посадку.
-- Источники: клавиатура, стик/геймпад (через PlayerModule), свайп пальцем по экрану.
task.spawn(function()
	local ok, module = pcall(function()
		-- PlayerModule появляется только в рантайме (нет в sourcemap) — require без проверки типов
		return (require :: any)(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 10))
	end)
	if ok and module then
		st.controls = module:GetControls()
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
stickFolder.Parent = st.controller
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
	if st.controls then
		local ok, mv = pcall(st.controls.GetMoveVector, st.controls)
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
	if st.controls then
		local ok, mv = pcall(st.controls.GetMoveVector, st.controls)
		if ok and typeof(mv) == "Vector3" and mv.Z > 0.5 then
			return true
		end
	end
	if swipeInput and swipeInput.Position.Y - stickOrigin.Value.Y > SWIPE_FULL * 0.8 then
		return true
	end
	return false
end

Input.readSteer = readSteer
Input.readPitchDown = readPitchDown
Input.stickOn = stickOn

return Input
