-- Панель разработчика (DevAction): только владелец игры (game.CreatorId).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Data = require(script.Parent.DataService)
local Rewards = require(script.Parent.Rewards)
local Tuning = require(script.Parent.Tuning)
local Weekly = require(script.Parent.Weekly)
local Remotes = require(script.Parent.Remotes)
local PlayerState = require(script.Parent.PlayerState)
local Runs = require(script.Parent.Runs)

local runs = Runs.runs
local endRun = Runs.endRun
local syncPlayer = PlayerState.sync
local postLevel = PlayerState.postLevel
local DevAction: RemoteFunction = Remotes.DevAction

local DevTools = {}

function DevTools.start()
	-- Панель разработчика: только владелец игры (game.CreatorId). Меняет свой прогресс для проверки
	-- уровней прокачки, миров, саней и наград. Обычным игрокам сервер всегда отказывает.
	DevAction.OnServerInvoke = function(player, action, a, b, c)
		if player.UserId ~= game.CreatorId then
			return false, "Только для владельца"
		end
		-- Настройка на лету: не трогает заезд и профиль.
		-- "tune": a — { путь = число }, b — область "all" | "player", c — UserId или ник (для "player").
		-- "tuneGet": a — UserId или ник → { userId, name, overrides } (персональный слой игрока).
		if action == "tune" then
			if typeof(a) ~= "table" then
				return false, "Нет данных"
			end
			local scope = if b == nil then "all" else b
			if scope == "all" then
				return Tuning.save("all", nil, a)
			elseif scope == "player" then
				local userId, nameOrErr = Tuning.resolveTarget(c)
				if not userId then
					return false, nameOrErr
				end
				return Tuning.save("player", userId, a)
			end
			return false, "Неизвестная область"
		elseif action == "tuneGet" then
			local userId, nameOrErr = Tuning.resolveTarget(a)
			if not userId then
				return false, nameOrErr
			end
			local ok, res = Tuning.fetchPlayer(userId)
			if not ok then
				return false, res
			end
			return true, { userId = userId, name = nameOrErr, overrides = res }
		end
		local d = Data.get(player)
		if not d then
			return false, "Профиль не загружен"
		end
		if runs[player] then
			endRun(player, "back")
		end
		if action == "setLevel" and typeof(a) == "string" and Config.UPGRADES[a] and typeof(b) == "number" then
			local step = Config.UPGRADES[a].step or 1 -- ракета: только границы тира (#47)
			d[a .. "Level"] = math.clamp(math.floor(b) // step * step, 0, Config.UPGRADES[a].MaxLevel)
		elseif action == "add" and (a == "Coins" or a == "Gems") and typeof(b) == "number" then
			d[a] = math.max(0, d[a] + math.floor(b))
		elseif action == "setWorldLevel" and typeof(a) == "number" then
			d.Level = math.clamp(math.floor(a), 1, 200)
			d.LevelBest = 0
			d.FarmWorld = 0
			postLevel(player, d.Level)
		elseif action == "giveSled" and typeof(a) == "string" and typeof(b) == "number" then
			local model = Config.sled(a)
			local r = math.clamp(math.floor(b), 1, #Config.RARITIES)
			for k = 1, r do
				d.OwnedSleds[model.id .. ":" .. k] = true
			end
			d.Sled, d.SledRarity = model.id, r
		elseif action == "resetTutorial" then
			d.Tutorial = 0
			if d.Stats then
				d.Stats.Runs = 0 -- подсказки только для первых заездов; Onboard не трогаем (воронка не задвоится)
			end
		elseif action == "resetDaily" then
			d.Daily = nil
			d.ChestAt = 0
			d.GiftsClaimed = {}
			Rewards.sync(player)
		elseif action == "sessionShift" then
			Rewards.devShiftSession(player, Config.DEV_SESSION_SHIFT)
		elseif action == "streakNext" then
			Rewards.devStreakShift(player, 1)
		elseif action == "streakSkip" then
			Rewards.devStreakShift(player, 2)
		elseif action == "weekQuestAdd" then
			Rewards.devWeekAdd(player) -- задание недели +25 % (#56)
		elseif action == "weekQuestReset" then
			Rewards.devWeekReset(player)
		elseif action == "weeklyTitle" and typeof(a) == "number" then
			Weekly.devTitle(player, a) -- титул себе на неделю (1..3, 0 — снять)
		elseif action == "weeklyRefresh" then
			Weekly.refreshNow()
		else
			return false, "Неизвестное действие"
		end
		syncPlayer(player)
		return true, "Готово"
	end
end

return DevTools
