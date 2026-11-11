-- События заезда от клиента: запуск с рогатки (Launch), время в полёте (Air), авария (Crash),
-- разбитое препятствие (Smash), трюки (Trick). Все числа клиента проверяет AntiCheat.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Data = require(script.Parent.DataService)
local Tuning = require(script.Parent.Tuning)
local Analytics = require(script.Parent.Analytics)
local AntiCheat = require(script.Parent.AntiCheat)
local Remotes = require(script.Parent.Remotes)
local Sleds = require(script.Parent.Sleds)
local Runs = require(script.Parent.Runs)

local runs = Runs.runs
local endRun = Runs.endRun
local antiCheatVerdict = Runs.antiCheatVerdict
local ragdoll = Sleds.ragdoll
local Launch: RemoteEvent = Remotes.Launch
local Crash: RemoteEvent = Remotes.Crash
local Air: RemoteEvent = Remotes.Air
local Trick: RemoteEvent = Remotes.Trick
local Smash: RemoteEvent = Remotes.Smash

local RunEvents = {}

function RunEvents.start()
	-- Игрок отпустил рогатку: power 0..1 — насколько сильно оттянул резинку
	Launch.OnServerEvent:Connect(function(player, power)
		local run = runs[player]
		local d = Data.get(player)
		if not run or run.launched or not d or typeof(power) ~= "number" or power ~= power then
			return
		end
		power = math.clamp(power, 0.25, 1)
		run.launched = true
		run.launchTime = os.clock()
		for _, r in run.ropes do
			r:Destroy()
		end
		local sled = run.sled
		sled:SetAttribute("LaunchSpeed", Tuning.forPlayer(player, function()
			AntiCheat.start(run, player, d, power) -- огибающая скорости под персональные настройки
			return Config.launchSpeed(d.LaunchLevel) * power
		end))
		sled.Anchored = false
		-- дальше физику считает клиент: мгновенный отклик
		local ok, err = pcall(sled.SetNetworkOwner, sled, player)
		if not ok then
			warn("[Launch] SetNetworkOwner: " .. tostring(err))
		end
		player:SetAttribute("Launched", true)
	end)

	-- Air time: монеты за время в полёте (с ограничением, чтобы не накручивали)
	Air.OnServerEvent:Connect(function(player, seconds)
		local run = runs[player]
		-- seconds ~= seconds — NaN: math.min/floor его не отсекают, и NaN попал бы в монеты профиля
		if not run or not run.launched or run.crashed or typeof(seconds) ~= "number" or seconds ~= seconds then
			return
		end
		local claimed: number = seconds
		local now = os.clock()
		if now - (run.lastAir or 0) < 0.8 or claimed < Config.AIR_MIN_TIME then
			return
		end
		run.lastAir = now
		-- засчитываем не больше полёта, который видел сервер (AntiCheat.air); на земле — ничего
		local sec, seen = 0, true
		Tuning.forPlayer(player, function()
			sec, seen = AntiCheat.air(run, claimed)
		end)
		if not seen then
			antiCheatVerdict(player, run, AntiCheat.flag(run, player, string.format("Air %.1f с без полёта", claimed)))
		end
		if sec <= 0 then
			return
		end
		run.airTotal = (run.airTotal or 0) + math.min(sec, 6)
		local add = Tuning.forPlayer(player, function()
			return math.floor(math.min(sec, 4) * Config.AIR_COINS_PER_SEC)
		end)
		run.bonusCoins += add
		player:SetAttribute("RunCoins", (player:GetAttribute("RunCoins") or 0) + add)
	end)

	-- Врезался: даём кувырку доиграть на экране, потом заканчиваем заезд
	Crash.OnServerEvent:Connect(function(player)
		local run = runs[player]
		if not run or not run.launched or run.crashed then
			return
		end
		run.crashed = true
		run.crashedOnTrack = not run.finishedAt -- после арки авария не портит «заезд без аварии»
		if run.finishedAt then
			-- после финишной арки авария уже не страшна: уровень пройден
			task.delay(1.2, function()
				if runs[player] == run then
					endRun(player, "finish")
				end
			end)
		end
		-- выкидываем персонажа из санок и превращаем в ragdoll
		local weld = run.sled:FindFirstChild("SeatWeld")
		if weld then
			weld:Destroy()
		end
		if player.Character then
			ragdoll(player.Character)
		end
		task.delay(2.2, function()
			if runs[player] == run then
				endRun(player, "crash")
			end
		end)
	end)

	-- model — разбитая модель с атрибутом Breakable; засчитываем, если она своей трассы, рядом с
	-- санками по серверу и ещё не разбита в этом заезде (AntiCheat.canSmash)
	Smash.OnServerEvent:Connect(function(player, model)
		local run = runs[player]
		if not run or not run.launched or run.crashed then
			return
		end
		if (run.smashes or 0) >= 40 then -- потолок за заезд: и монеты, и прогресс задания «разбей N»
			return
		end
		if not Tuning.forPlayer(player, function()
			return AntiCheat.canSmash(run, model)
		end) then
			return
		end
		run.smashes = (run.smashes or 0) + 1
		local add = Tuning.forPlayer(player, function()
			return if model:GetAttribute("Explosive") then Config.TNT_COINS else Config.SMASH_COINS
		end)
		run.bonusCoins += add
		player:SetAttribute("RunCoins", (player:GetAttribute("RunCoins") or 0) + add)
	end)

	-- Трюки за один полёт: list = { { id, count }, … }, airTime — сколько летел (с).
	-- Проверки: известные id, целые count ≤ TRICK_MAX_COUNT, не чаще раза в 0.8 с, оборотов не больше,
	-- чем влезает в полёт при FLIP_SPEED (+1 на щедрое округление), грэбов ≤ 2.
	-- Монеты = Σ coins × count × множитель комбо за число разных трюков (docs/GAME_DESIGN.md → «Трюки»).
	Trick.OnServerEvent:Connect(function(player, list, airTime)
		local run = runs[player]
		if not run or not run.launched or run.crashed or typeof(list) ~= "table" then
			return
		end
		local now = os.clock()
		if now - run.lastTrick < 0.8 then
			return
		end
		run.lastTrick = now
		local clientAir = if typeof(airTime) == "number" and airTime == airTime then math.clamp(airTime, 0, 10) else 0
		-- обороты проверяем по полёту, который видел сервер (AntiCheat.trickAir); не видел — трюки на земле
		local serverAir = Tuning.forPlayer(player, function()
			return AntiCheat.trickAir(run, clientAir)
		end)
		if not serverAir then
			antiCheatVerdict(player, run, AntiCheat.flag(run, player, "Trick без полёта"))
			return
		end
		local air: number = serverAir
		local counts: { [string]: number } = {}
		local distinct, rotations, grabs = 0, 0, 0
		for i, item in list do
			if typeof(i) ~= "number" or i > #Config.TRICK_ORDER or typeof(item) ~= "table" then
				break
			end
			local id, count = item.id, item.count
			local def = if typeof(id) == "string" then Config.TRICKS[id] else nil
			if not def or counts[id] or typeof(count) ~= "number" or count ~= count then
				continue
			end
			count = math.clamp(math.floor(count), 0, Config.TRICK_MAX_COUNT)
			if count == 0 then
				continue
			end
			counts[id] = count
			distinct += 1
			if def.kind == "grab" then
				grabs += count
			else
				rotations += count
			end
		end
		if distinct == 0 or rotations > Config.maxRotations(air) or grabs > 2 then
			return
		end
		local add, flips, total = 0, 0, 0
		Tuning.forPlayer(player, function()
			local mult = Config.trickComboMult(distinct)
			local sum, boost = 0, 1
			for id, count in counts do
				local def = Config.TRICKS[id]
				sum += def.coins * count
				boost *= def.boost ^ count -- тот же буст скорости, что даёт клиент при приземлении
				total += count
				if def.kind == "pitch" then
					flips += count -- задание дня «Сделай N сальто» — любые сальто
				end
			end
			add = math.floor(sum * mult)
			AntiCheat.onTrick(run, boost)
		end)
		run.flips = (run.flips or 0) + flips
		run.tricks = (run.tricks or 0) + total
		run.bonusCoins += add
		player:SetAttribute("RunCoins", (player:GetAttribute("RunCoins") or 0) + add)
		Analytics.custom(player, "Tricks", total)
	end)
end

return RunEvents
