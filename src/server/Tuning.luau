-- Настройка игры на лету: владелец меняет параметры в панели разработчика (вкладка «Настройка»).
-- Два слоя переопределений { путь = число }:
--   • общие (scope "all") — DataStore `GameConfig_v1`, ключ `overrides`; применяются к Config на
--     сервере и у всех клиентов (атрибут ReplicatedStorage.ConfigOverrides, JSON);
--   • персональные (scope "player") — ключ `p_<UserId>`; накладываются поверх общих только для
--     этого игрока (атрибут игрока `ConfigOverrides`, JSON; клиент сливает оба слоя сам, сервер —
--     через Tuning.forPlayer).
-- Изменения рассылаются на все сервера через MessagingService (тема SledConfigChanged, payload
-- { scope, userId, job }) — серверы перечитывают только нужный ключ.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Tuning = {}

type Overrides = { [string]: number }

local store = DataStoreService:GetDataStore("GameConfig_v1")
local KEY = "overrides"
local TOPIC = "SledConfigChanged"
local RETRIES = 3

local global: Overrides = {}
local perPlayer: { [number]: Overrides } = {} -- только игроки, которые сейчас на этом сервере
local savedOffline: { [number]: Overrides } = {} -- что этот сервер записал для офлайн-игроков (панель перечитывает без DataStore)
local activeFor: number? = nil -- UserId, чьи настройки сейчас применены к Config (forPlayer)

local function playerKey(userId: number): string
	return "p_" .. userId
end

-- Оставляем только известные числовые параметры в допустимых границах
local function clean(overrides: { [string]: any }): Overrides
	local out: Overrides = {}
	for _, tn in Config.TUNABLES do
		local v = overrides[tn[1]]
		if typeof(v) == "number" and v == v then
			out[tn[1]] = math.clamp(v, tn[4], tn[5])
		end
	end
	return out
end

local function count(t: Overrides): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

local function applyGlobal(overrides: { [string]: any })
	global = clean(overrides)
	Config.applyOverrides(global)
	ReplicatedStorage:SetAttribute("ConfigOverrides", HttpService:JSONEncode(global))
end

local function pushPlayerAttribute(userId: number)
	local player = Players:GetPlayerByUserId(userId)
	if player then
		player:SetAttribute("ConfigOverrides", HttpService:JSONEncode(perPlayer[userId] or {}))
	end
end

-- Чтение ключа с ретраями (экспоненциальная пауза). Возвращает (ok, таблица|nil)
local function fetch(key: string): (boolean, Overrides?)
	local lastErr
	for attempt = 1, RETRIES do
		local ok, saved = pcall(store.GetAsync, store, key)
		if ok then
			return true, if type(saved) == "table" then saved else nil
		end
		lastErr = saved
		if attempt < RETRIES then
			task.wait(2 ^ attempt)
		end
	end
	warn("[Tuning] не удалось загрузить «" .. key .. "»: " .. tostring(lastErr))
	return false, nil
end

local function loadGlobal()
	local ok, saved = fetch(KEY)
	if ok then
		applyGlobal(saved or {})
	end
end

-- Персональные настройки игрока: при входе и по сообщению с другого сервера
function Tuning.loadPlayer(player: Player)
	local userId = player.UserId
	perPlayer[userId] = perPlayer[userId] or {}
	savedOffline[userId] = nil
	local ok, saved = fetch(playerKey(userId))
	if not player.Parent then -- вышел, пока ждали DataStore
		perPlayer[userId] = nil
		return
	end
	if ok then
		perPlayer[userId] = clean(saved or {})
	end
	pushPlayerAttribute(userId)
end

function Tuning.unloadPlayer(player: Player)
	perPlayer[player.UserId] = nil
end

function Tuning.init()
	applyGlobal({})
	loadGlobal()
	pcall(function()
		MessagingService:SubscribeAsync(TOPIC, function(message)
			local data = message.Data
			if type(data) ~= "table" then -- старый формат (число): перечитать общие
				loadGlobal()
				return
			end
			if data.job == game.JobId then
				return -- своё же сообщение: уже применено при сохранении
			end
			if data.scope == "player" and typeof(data.userId) == "number" then
				savedOffline[data.userId] = nil -- изменил другой сервер: наша копия устарела
				local player = Players:GetPlayerByUserId(data.userId)
				if player then
					Tuning.loadPlayer(player)
				end
			else
				loadGlobal()
			end
		end)
	end)
end

function Tuning.get(): Overrides
	return global
end

function Tuning.getPlayer(userId: number): Overrides
	return perPlayer[userId] or {}
end

-- Эффективный набор для игрока: по умолчанию ← общие ← персональные
-- (значения по умолчанию подставляет Config.applyOverrides для путей, которых нет в словаре)
function Tuning.merged(player: Player): Overrides
	local out = table.clone(global)
	for path, v in (perPlayer[player.UserId] or {}) :: Overrides do
		out[path] = v
	end
	return out
end

-- Выполнить fn с Config, настроенным под игрока, и вернуть общие значения обратно.
-- Безопасно только для СИНХРОННОГО fn (без task.wait / DataStore / Invoke): Luau исполняет
-- поток без прерываний до первого yield, поэтому между applyOverrides(merged) и
-- applyOverrides(global) никакой другой код Config не читает. Если бы fn уступил поток, другой
-- игрок успел бы посчитать награды по чужим настройкам. Повторный вход для того же игрока
-- (endRun внутри обработчика) — просто вызов fn.
function Tuning.forPlayer(player: Player, fn: () -> ...any): ...any
	local userId = player.UserId
	local personal = perPlayer[userId]
	if activeFor == userId or not personal or next(personal) == nil then
		return fn()
	end
	activeFor = userId
	Config.applyOverrides(Tuning.merged(player))
	local results = table.pack(pcall(fn))
	Config.applyOverrides(global)
	activeFor = nil
	if not results[1] then
		error(results[2], 0)
	end
	return table.unpack(results, 2, results.n)
end

-- Имя игрока для сообщений (онлайн — сразу, иначе — через API в pcall)
local function nameOf(userId: number): string
	local player = Players:GetPlayerByUserId(userId)
	if player then
		return player.Name
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	return if ok then name else "?"
end

-- «Цель» из панели: UserId (число) или ник (строка) → (userId, имя) либо (nil, ошибка)
function Tuning.resolveTarget(target: any): (number?, string)
	if typeof(target) == "number" then
		if target % 1 ~= 0 or target <= 0 then
			return nil, "Неверный UserId"
		end
		return target, nameOf(target)
	end
	if typeof(target) ~= "string" then
		return nil, "Укажи UserId или ник игрока"
	end
	local text = string.gsub(target, "^%s+", "")
	text = string.gsub(text, "%s+$", "")
	if text == "" then
		return nil, "Укажи UserId или ник игрока"
	end
	local asNumber = tonumber(text)
	if asNumber then
		return Tuning.resolveTarget(asNumber)
	end
	if #text > 20 or string.find(text, "[^%w_]") then
		return nil, "Такого ника не бывает: " .. text
	end
	local online = Players:FindFirstChild(text)
	if online and online:IsA("Player") then
		return online.UserId, online.Name
	end
	local ok, userId = pcall(Players.GetUserIdFromNameAsync, Players, text)
	if not ok or typeof(userId) ~= "number" then
		return nil, "Игрок «" .. text .. "» не найден"
	end
	return userId, text
end

-- Персональный набор игрока (онлайн — из памяти, иначе — из DataStore) для панели владельца
function Tuning.fetchPlayer(userId: number): (boolean, Overrides | string)
	if perPlayer[userId] then
		return true, perPlayer[userId]
	end
	if savedOffline[userId] then
		return true, savedOffline[userId]
	end
	local ok, saved = fetch(playerKey(userId))
	if not ok then
		return false, "DataStore не ответил"
	end
	return true, clean(saved or {})
end

local function changesText(n: number): string
	return if n == 0 then "всё как у всех" else n .. " " .. Config.plural(n, { "изменение", "изменения", "изменений" })
end

-- Сохранить набор: scope "all" — общие; "player" — персональные для userId (пустой набор —
-- вернуть игроку общие значения). Возвращает (ok, сообщение).
function Tuning.save(scope: string, userId: number?, overrides: { [string]: any }): (boolean, string)
	local data = clean(overrides)
	local n = count(data)
	if scope == "all" then
		local ok, err = pcall(store.SetAsync, store, KEY, data)
		if not ok then
			return false, "Не сохранилось: " .. tostring(err)
		end
		applyGlobal(data)
		pcall(MessagingService.PublishAsync, MessagingService, TOPIC, { scope = "all", job = game.JobId })
		return true, if n == 0 then "Для всех — всё по умолчанию" else "Сохранено для всех: " .. changesText(n)
	elseif scope == "player" and typeof(userId) == "number" then
		local ok, err
		if n == 0 then
			ok, err = pcall(store.RemoveAsync, store, playerKey(userId))
		else
			ok, err = pcall(store.SetAsync, store, playerKey(userId), data)
		end
		if not ok then
			return false, "Не сохранилось: " .. tostring(err)
		end
		if perPlayer[userId] then -- игрок на этом сервере
			perPlayer[userId] = data
			pushPlayerAttribute(userId)
		else
			savedOffline[userId] = data
		end
		pcall(MessagingService.PublishAsync, MessagingService, TOPIC, { scope = "player", userId = userId, job = game.JobId })
		return true, string.format("Сохранено для игрока %s (%d): %s", nameOf(userId), userId, changesText(n))
	end
	return false, "Неизвестная область: " .. tostring(scope)
end

return Tuning
