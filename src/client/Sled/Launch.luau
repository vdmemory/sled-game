-- Рогатка (часть SledController): натяжение пальцем/мышью или удержанием клавиши, выстрел
-- Remotes.Launch(power, zoneAge). Пока санки закреплены, локально отводим их назад.
-- Идеальный запуск (#58): первый вход натяга в зону Config.PERFECT_ZONE запоминается (st.zoneAt и
-- State.PerfectAt — HUD красит шкалу); при отпускании серверу уходит, сколько секунд прошло с входа
-- в зону. Засчитывает сервер (AntiCheat.perfectLaunch), вспышку «ИДЕАЛЬНО!» показывает SledController
-- по атрибуту саней PerfectLaunch. Начало натяга — Launch("pull"): сервер сверяет тайминг по своим часам.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local st = require(script.Parent.State)

local meterValue = st.meterValue
local perfectAtValue = st.perfectAtValue
local awaitingLaunch = st.awaitingLaunch
local sfx = st.sfx
local requestLaunch = st.requestLaunch

local Launch = {}

------------------------------------------------------------------ ввод
-- Рогатка: зажал → тянешь вниз (санки отъезжают назад, резинка натягивается) → отпустил = выстрел.
-- Сила = насколько сильно оттянул. Клавиатура/геймпад: держи Пробел/A — натяжение растёт само.
local UIS = game:GetService("UserInputService")
local PULL_BACK = 9 -- studs, на сколько санки отъезжают при полном натяжении
local PULL_SCREEN = 0.28 -- доля высоты экрана для полного натяжения
local PULL_KEY_TIME = 1.1 -- секунд удержания клавиши до 100%
local MIN_PULL = 0.12 -- меньше — считаем, что передумал

local function setPull(a: number)
	st.pullAmount = math.clamp(a, 0, 1)
	meterValue.Value = st.pullAmount
	if st.pulling and not st.zoneAt and st.pullAmount >= Config.PERFECT_ZONE then
		st.zoneAt = os.clock() -- вошли в зону «ИДЕАЛЬНО»: окно PERFECT_WINDOW пошло
		perfectAtValue.Value = st.zoneAt
	end
	local s = st.sled
	if s and s.Anchored and st.baseCF then
		-- локально (только у себя) отводим санки назад: резинка-Beam тянется за ними
		s.CFrame = st.baseCF * CFrame.new(0, 0, PULL_BACK * st.pullAmount)
	end
end

local function fireLaunch(power: number, zoneAge: number?)
	if awaitingLaunch.Value and not st.launchSent then
		st.launchSent = true
		awaitingLaunch.Value = false
		Remotes.Launch:FireServer(power, zoneAge)
		sfx:Fire("launch")
	end
end

local function beginPull(input: InputObject?)
	if not awaitingLaunch.Value or st.launchSent or st.pulling then
		return
	end
	local s = st.sled
	if not s then
		return
	end
	st.pulling = true
	st.pullInput = input
	st.keyPull = input == nil
	st.pullStartY = if input then input.Position.Y else 0
	st.baseCF = st.baseCF or s.CFrame
	st.zoneAt = nil -- новый натяг — новое окно идеального запуска
	perfectAtValue.Value = 0
	setPull(0)
	Remotes.Launch:FireServer("pull")
	sfx:Fire("pull")
end

local function releasePull()
	if not st.pulling then
		return
	end
	st.pulling, st.keyPull, st.pullInput = false, false, nil
	local power = st.pullAmount
	local zoneAge = if st.zoneAt then os.clock() - st.zoneAt else nil
	st.zoneAt = nil
	perfectAtValue.Value = 0
	if st.sled and st.baseCF then
		st.sled.CFrame = st.baseCF -- возвращаем санки к рогатке: дальше их везёт физика
	end
	setPull(0)
	if power >= MIN_PULL then
		fireLaunch(power, zoneAge)
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
	if not st.pulling or st.keyPull then
		return
	end
	local isMouse = input.UserInputType == Enum.UserInputType.MouseMovement
		and st.pullInput
		and st.pullInput.UserInputType == Enum.UserInputType.MouseButton1
	if isMouse or input == st.pullInput then
		local cam = workspace.CurrentCamera
		local h = if cam then cam.ViewportSize.Y else 800
		setPull((input.Position.Y - st.pullStartY) / (h * PULL_SCREEN))
	end
end)
UIS.InputEnded:Connect(function(input)
	if not st.pulling or st.keyPull then
		return
	end
	if input == st.pullInput or input.UserInputType == Enum.UserInputType.MouseButton1 then
		releasePull()
	end
end)

Launch.setPull = setPull
Launch.fireLaunch = fireLaunch
Launch.beginPull = beginPull
Launch.releasePull = releasePull
Launch.PULL_KEY_TIME = PULL_KEY_TIME

return Launch
