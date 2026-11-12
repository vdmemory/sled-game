-- Сохранение прогресса через DataStore с сессионной блокировкой (свой lock на UpdateAsync).
-- В записи поле `_session = { jobId, ts }`: пишет только сервер, чей jobId в блокировке.
-- Подробно — docs/ARCHITECTURE.md, раздел «Сохранение».

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local store = DataStoreService:GetDataStore("SledData_v1")

-- В Studio JobId пустой — свой уникальный id, чтобы две сессии Studio не считались одним сервером
local JOB_ID = if game.JobId ~= "" then game.JobId else "studio-" .. HttpService:GenerateGUID(false)
local LOCK_POLL = 5 -- секунд между попытками взять чужую блокировку
local KICK_LOAD = "Не удалось загрузить прогресс, перезайди. Прогресс цел."
local KICK_LOST = "Прогресс открыт на другом сервере, перезайди."

local DEFAULT = {
	Coins = 0,
	Level = 1, -- текущий уровень (мир)
	LevelBest = 0, -- лучший % на текущем уровне
	LaunchLevel = 0,
	RocketLevel = 0,
	SledLevel = 0,
	IncomeLevel = 0,
	Gems = 0,
	FarmWorld = 0, -- 0 = текущий мир; N = фарм пройденного мира N
	Receipts = {}, -- ID обработанных покупок Robux (защита от повторной выдачи)
	Stats = { Runs = 0, Finishes = 0, Onboard = 0, Purchases = 0, Playtime = 0 }, -- счётчики для аналитики (docs/METRICS.md)
	Settings = { Sfx = true, Music = true, Snow = true, Shadows = true, Ghost = true }, -- Ghost — призрак рекорда (#62)
	Sled = "tube", -- модель саней
	SledRarity = 1,
	OwnedSleds = { ["tube:1"] = true },
	Trail = "white",
	OwnedTrails = { white = true },
	Tutorial = 0, -- биты пройденных шагов обучения (Config.TUTORIAL.STEPS), все биты = пройдено/пропущено
	-- стрик дней входа (#25): day — последний засчитанный UTC-день, count — длина серии, claimedDay — день
	-- последней награды, save — серия, которую можно спасти сегодня (0 — нет предложения)
	Streak = { day = 0, count = 0, claimedDay = 0, save = 0 },
	-- лидерборд недели (#26, server/Weekly): титул топ-3 прошлой недели (id из Config.WEEKLY.TITLES,
	-- "" — нет), действует до TitleUntil (сброс недели); TitleWeek — неделя, в которую титул уже
	-- проверен; WeekPlay — где игрок попал в доски на неделе key (worlds["N"], clean) — по нему ищем титул
	Title = "",
	TitleUntil = 0,
	TitleWeek = "",
	WeekPlay = { key = "", worlds = {}, clean = false },
}

local function deepCopy(t: any): any
	if type(t) ~= "table" then
		return t
	end
	local c = {}
	for k, v in t do
		c[k] = deepCopy(v)
	end
	return c
end

type Profile = { data: { [string]: any }, canSave: boolean, released: boolean?, busy: boolean? }

local Data = {}
local profiles: { [Player]: Profile } = {}
local shuttingDown = false -- после BindToClose каждое сохранение снимает блокировку

local function retry(fn: () -> any, attempts: number?): (boolean, any)
	local n = attempts or 3
	for attempt = 1, n do
		local ok, res = pcall(fn)
		if ok then
			return true, res
		end
		warn("[Data] попытка " .. attempt .. ": " .. tostring(res))
		if attempt < n then
			task.wait(attempt * 2)
		end
	end
	return false, nil
end

local function key(player: Player): string
	return "u_" .. player.UserId
end

-- Блокировка чужая и живая (не наша и обновлялась недавно)
local function lockedByOther(rec: any, now: number): boolean
	local s = type(rec) == "table" and rec._session
	return type(s) == "table" and s.jobId ~= JOB_ID and now - (tonumber(s.ts) or 0) < Config.DATA_LOCK_STALE
end

-- Одна попытка взять блокировку. Возвращает (ok, запись|nil, "taken"|"locked")
local function tryLock(k: string, force: boolean): (boolean, any, string)
	local state = "taken"
	local ok, rec = retry(function()
		return store:UpdateAsync(k, function(old)
			state = "taken" -- функция может вызываться повторно — состояние считаем заново
			local now = os.time()
			if not force and lockedByOther(old, now) then
				state = "locked"
				return nil -- отмена записи
			end
			local out = if type(old) == "table" then old else {}
			out._session = { jobId = JOB_ID, ts = now }
			return out
		end)
	end, 5)
	return ok, rec, state
end

-- Запись профиля, только если блокировка наша (или свободна). release — снять блокировку.
-- Возвращает (успех записи, блокировку перехватили)
local function write(k: string, data: { [string]: any }, release: boolean): (boolean, boolean)
	local lost = false
	local ok = retry(function()
		store:UpdateAsync(k, function(old)
			lost = false
			local s = type(old) == "table" and old._session
			if type(s) == "table" and s.jobId ~= JOB_ID then
				lost = true -- другой сервер забрал профиль: не затираем его данные
				return nil
			end
			local out = table.clone(data) -- снимок на момент записи (вложенные таблицы не мутируем)
			out._session = if release then nil else { jobId = JOB_ID, ts = os.time() }
			return out
		end)
	end)
	return ok and not lost, lost
end

local function migrate(data: { [string]: any })
	-- Палитра «Цвета ватрушки» убрана: купленные цвета возвращаем монетами (один раз)
	if type(data.OwnedSkins) == "table" then
		local PRICES = { ice = 150, lime = 300, melon = 600, night = 900, lava = 1500, gold = 3000, galaxy = 6000 }
		for id in data.OwnedSkins do
			data.Coins += PRICES[id] or 0
		end
		data.OwnedSkins = nil
		data.Skin = nil
	end
	-- Ракета без промежуточных уровней (#47): уровень только кратен 5 (тир = ур. // 5). Уровни сверх
	-- границы тира откатываем и возвращаем их гемы по прежней цене (1 + ур. // 3) — новая цена тира =
	-- сумма прежних цен его 5 уровней, поэтому «вернули + заплатить за тир» = ровно прежний остаток.
	local rl = data.RocketLevel
	if type(rl) == "number" and rl % Config.TIER_SIZE ~= 0 then
		local floorLvl = rl - rl % Config.TIER_SIZE
		local refund = 0
		for l = floorLvl, math.floor(rl) - 1 do
			refund += 1 + l // 3
		end
		data.Gems = (data.Gems or 0) + refund
		data.RocketLevel = floorLvl
	end
	-- новые ключи вложенных таблиц (Settings.Music, Streak.save…) у старых профилей
	-- титул (#26): битые типы → без титула
	if type(data.Title) ~= "string" then
		data.Title = ""
	end
	if type(data.TitleUntil) ~= "number" then
		data.TitleUntil = 0
	end
	if type(data.TitleWeek) ~= "string" then
		data.TitleWeek = ""
	end
	for _, f in { "Settings", "Streak", "WeekPlay" } do
		if type(data[f]) ~= "table" then
			data[f] = deepCopy(DEFAULT[f])
		end
		for k, v in DEFAULT[f] do
			if data[f][k] == nil then
				data[f][k] = v
			end
		end
	end
end

-- Загружает профиль и берёт блокировку. nil — профиля нет (игрок вышел или кикнут).
function Data.load(player: Player)
	local k = key(player)
	local deadline = os.clock() + Config.DATA_LOCK_WAIT
	local ok, saved, state = tryLock(k, false)
	-- другой сервер ещё держит профиль (быстрый переход): ждём, пока он сохранит и снимет блокировку
	while ok and state == "locked" and player.Parent and os.clock() < deadline do
		task.wait(LOCK_POLL)
		ok, saved, state = tryLock(k, false)
	end
	if ok and state == "locked" and player.Parent then
		-- не снял за DATA_LOCK_WAIT — забираем; запись старого сервера после этого будет отклонена
		warn("[Data] забираю блокировку " .. player.Name .. " у " .. tostring(saved and saved._session and saved._session.jobId))
		ok, saved, state = tryLock(k, true)
	end
	if not player.Parent then
		-- вышел, пока ждали DataStore: профиль не регистрируем, взятую блокировку снимаем
		if ok and state == "taken" and type(saved) == "table" then
			saved._session = nil
			task.spawn(write, k, saved, true)
		end
		return nil
	end
	if not ok then
		-- #16: не пускаем играть «с нулём» — кик, сейв в DataStore не тронут
		warn("[Data] не удалось загрузить " .. player.Name)
		if RunService:IsStudio() then
			-- Studio без доступа к API: играть можно, но без сохранения
			profiles[player] = { data = deepCopy(DEFAULT), canSave = false }
			return profiles[player].data
		end
		player:Kick(KICK_LOAD)
		return nil
	end
	local data = deepCopy(DEFAULT)
	if type(saved) == "table" then
		for f, v in saved do
			data[f] = v
		end
		data._session = nil
		migrate(data)
	end
	profiles[player] = { data = data, canSave = true }
	return data
end

function Data.get(player: Player)
	local p = profiles[player]
	return p and p.data
end

-- Можно ли сохранять профиль (загрузился и блокировка наша)
function Data.canSave(player: Player): boolean
	local p = profiles[player]
	return p ~= nil and p.canSave and not p.released
end

-- Возвращает true, если запись прошла
function Data.save(player: Player, release: boolean?): boolean
	local p = profiles[player]
	if not p or not p.canSave or p.released then
		return false
	end
	-- записи одного профиля по очереди: иначе автосейв, закончившийся после release, снова взял бы блокировку
	while p.busy do
		task.wait(0.1)
	end
	if not p.canSave or p.released then
		return false
	end
	p.busy = true
	local rel = release == true or shuttingDown
	local ok, lost = write(key(player), p.data, rel)
	p.busy = false
	if lost then
		-- профиль на другом сервере: дальше этот сервер ничего не пишет
		p.canSave = false
		warn("[Data] блокировку " .. player.Name .. " перехватил другой сервер")
		if player.Parent and not shuttingDown then
			player:Kick(KICK_LOST)
		end
	elseif ok and rel then
		p.released = true
	end
	return ok
end

function Data.release(player: Player)
	Data.save(player, true)
	profiles[player] = nil
end

function Data.saveAll()
	for player in profiles do
		task.spawn(Data.save, player)
	end
end

-- Для BindToClose: все сохранения параллельно (со снятием блокировки), ждём не дольше timeout секунд
function Data.saveAllAndWait(timeout: number)
	shuttingDown = true
	local pending = 0
	for player in profiles do
		pending += 1
		task.spawn(function()
			Data.save(player, true)
			pending -= 1
		end)
	end
	local deadline = os.clock() + timeout
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
end

return Data
