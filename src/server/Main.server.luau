-- Главный серверный скрипт: только порядок запуска и связывание модулей server/*.
--   Remotes — ремоуты; Environment — свет; Sleds — сани и ragdoll; PlayerState — профиль в атрибуты,
--   вход, табло уровня, обучение; Runs — заезды и цикл Heartbeat; RunEvents — Launch/Air/Crash/
--   Smash/Trick; Pickups — монеты и бонусы; Shop — магазин и награды; Purchases — Robux;
--   DevTools — панель владельца.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Track = require(ReplicatedStorage.Shared.Track) -- общий модуль: сервер строит трассы заездов, клиент — витрину лобби
local Data = require(script.Parent.DataService)
local Rewards = require(script.Parent.Rewards)
local Tuning = require(script.Parent.Tuning)
local Analytics = require(script.Parent.Analytics)
local Weekly = require(script.Parent.Weekly) -- лидерборд недели и титулы (#26)
local Remotes = require(script.Parent.Remotes)
local Environment = require(script.Parent.Environment)
local Sleds = require(script.Parent.Sleds)
local PlayerState = require(script.Parent.PlayerState)
local Runs = require(script.Parent.Runs)
local RunEvents = require(script.Parent.RunEvents)
local Pickups = require(script.Parent.Pickups)
local Shop = require(script.Parent.Shop)
local Purchases = require(script.Parent.Purchases)
local DevTools = require(script.Parent.DevTools)
Tuning.init() -- настройки из панели разработчика (DataStore) — до постройки лобби и трасс

Remotes.folder.Parent = ReplicatedStorage

------------------------------------------------------------------ Мир
Sleds.setup()
Environment.setup()
Track.buildLobby()

-- Табло в лобби (неделя по мирам, чистые финиши, всё время) — server/Weekly + client/WeeklyBoard
Weekly.start()

------------------------------------------------------------------ Обработчики
Runs.start() -- StartRun, зона посадки, ⟳ и BACK
PlayerState.start() -- шаги обучения, настройки
Shop.start() -- сани, следы, награды, апгрейды, миры
RunEvents.start() -- Launch, Air, Crash, Smash, Trick
DevTools.start()
Purchases.start() -- геймпасс и ProcessReceipt
Pickups.start() -- монеты, магнит, бонусы, гемы, кристалл
Runs.startLoop() -- Heartbeat: прогресс, остановка, финиш

------------------------------------------------------------------ Подключение / выход
Players.PlayerAdded:Connect(PlayerState.onPlayerAdded)
for _, p in Players:GetPlayers() do
	task.spawn(PlayerState.onPlayerAdded, p)
end

Players.PlayerRemoving:Connect(function(player)
	Runs.onLeave(player)
	Rewards.onLeave(player)
	Weekly.onLeave(player)
	Tuning.unloadPlayer(player)
	local d = Data.get(player)
	local joined = player:GetAttribute("JoinedAt")
	if d and typeof(joined) == "number" then
		local minutes = math.floor((os.clock() - joined) / 60)
		d.Stats = d.Stats or {}
		d.Stats.Playtime = (d.Stats.Playtime or 0) + minutes
		Analytics.custom(player, "SessionMinutes", minutes)
	end
	Data.release(player)
end)

task.spawn(function()
	while true do
		task.wait(Config.DATA_AUTOSAVE)
		Data.saveAll()
	end
end)

-- Сохраняем всех параллельно и ждём (лимит BindToClose — 30 с; последовательные ретраи не влезали)
game:BindToClose(function()
	Weekly.flushAll() -- параллельно с сейвами: очередь лидерборда недели
	Data.saveAllAndWait(25)
end)