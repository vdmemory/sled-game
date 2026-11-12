-- Призрак рекорда (#62): лучший заезд игрока на уровне — запись траектории в отдельном DataStore
-- `Ghost_v1` (не в профиле SledData_v1: профиль маленький и пишется часто, запись — десятки КБ
-- и пишется только на рекорде).
--
-- Поток:
--   1. Старт заезда: клиент (client/Ghost) запрашивает GetGhost(level) → запись или false.
--      Запись кэшируется в памяти (одна на игрока — уровень текущего заезда): ⟳ не тратит чтений.
--   2. Конец заезда (Runs.endRun → Ghosts.onRunEnd): если заезд лучше сохранённого (финиш быстрее /
--      дальше), сервер запоминает «ожидание» (уровень, засчитанная дистанция, время, профиль
--      трассы) и шлёт клиенту Ghost(level) — «пришли запись».
--   3. Клиент шлёт Ghost(level, dt, data). Сервер проверяет (размер, число сэмплов, длительность ≈
--      времени заезда, путь вдоль трассы не назад, точки у трассы, скорость, итог ≈ дистанции) и
--      пишет UpdateAsync: внутри ещё раз сравнивает с тем, что в хранилище (другой сервер мог
--      записать лучше).
--
-- Запись: { v = 1, level, dist (studs), fin (финишировал), time (с от выстрела до конца),
--   dt (с между сэмплами), n (сэмплов), data (shared/GhostCodec), ts (os.time) }.
-- Ключ: "g_<userId>_<level>" (≤ 50 символов). Номер уровня однозначно задаёт мир, а фарм
-- пройденного мира едет его последний уровень — у фарма и обычного заезда один призрак (трасса
-- уровня детерминирована, Track/Profile).
--
-- Лимиты DataStore (create.roblox.com → Data stores → Error codes and limits): значение ≤ 4 МБ
-- (наше ≤ GHOST_MAX_CHARS ≈ 24 КБ), ключ ≤ 50 символов, бюджет сервера 60 + 40 × игроков чтений и
-- столько же записей в минуту (UpdateAsync тратит оба) — у нас ≤ 1 чтения на смену уровня и
-- ≤ 1 записи на рекордный заезд; на ключ — 4 МБ/мин записи.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Track = require(ReplicatedStorage.Shared.Track)
local GhostCodec = require(ReplicatedStorage.Shared.GhostCodec)
local Data = require(script.Parent.DataService)
local Remotes = require(script.Parent.Remotes)

local GetGhost: RemoteFunction = Remotes.GetGhost
local GhostRemote: RemoteEvent = Remotes.Ghost

local store = DataStoreService:GetDataStore("Ghost_v2") -- v2: длины уровней и раскладки изменились (2026-11-12), старые записи не подходят

local Ghosts = {}

type Record = { v: number, level: number, dist: number, fin: boolean, time: number, dt: number, n: number, data: string, ts: number }
type Pending = { level: number, dist: number, fin: boolean, time: number, length: number, segments: { any }, origin: Vector3, at: number }

-- Кэш: последняя запрошенная/записанная запись игрока (уровень → запись | false «нет»)
local cache: { [Player]: { level: number, rec: Record | false } } = {}
local pending: { [Player]: Pending } = {}
local lastFetch: { [Player]: number } = {}

local function key(userId: number, level: number): string
	return "g_" .. userId .. "_" .. level
end

-- pcall + ретраи с паузой (docs/ENGINEERING.md); призрак не критичен — попыток немного
local function retry(fn: () -> any, attempts: number): (boolean, any)
	for attempt = 1, attempts do
		local ok, res = pcall(fn)
		if ok then
			return true, res
		end
		warn("[Ghosts] попытка " .. attempt .. ": " .. tostring(res))
		if attempt < attempts then
			task.wait(attempt * 2)
		end
	end
	return false, nil
end

-- Запись из хранилища — правдоподобной формы (сохраняли мы, но поле могло смениться)
local function valid(rec: any): boolean
	return type(rec) == "table"
		and type(rec.data) == "string"
		and type(rec.dist) == "number"
		and type(rec.time) == "number"
		and type(rec.dt) == "number"
		and type(rec.n) == "number"
end

-- a лучше b: финиш лучше нефиниша; два финиша — быстрее; два нефиниша — дальше
local function better(a: { dist: number, fin: boolean, time: number }, b: any): boolean
	if not valid(b) then
		return true
	end
	local bfin = b.fin == true
	if a.fin ~= bfin then
		return a.fin
	end
	if a.fin then
		return a.time < b.time - 0.05
	end
	return a.dist > b.dist + 1
end

-- Можно ли игроку смотреть призрак уровня: пройденные и текущий (владелец — любые, «ТЕСТ МИРА»)
local function levelAllowed(player: Player, level: any): boolean
	if typeof(level) ~= "number" or level ~= level or level < 1 or level % 1 ~= 0 or level > 10000 then
		return false
	end
	local d = Data.get(player)
	return d ~= nil and (level <= d.Level or player.UserId == game.CreatorId or level == player:GetAttribute("RunLevel"))
end

local function fetch(player: Player, level: number): Record | false
	local c = cache[player]
	if c and c.level == level then
		return c.rec
	end
	local ok, rec = retry(function()
		return store:GetAsync(key(player.UserId, level))
	end, 2)
	if not ok then
		return false -- не кэшируем: следующий старт попробует снова
	end
	local out: Record | false = if valid(rec) then rec else false
	if player.Parent then
		cache[player] = { level = level, rec = out }
	end
	return out
end

-- Из Runs.endRun (синхронно, без yield): заезд засчитан (не BACK/⟳/idle/cheat, не выход из игры).
-- dist — засчитанный путь (≤ длины трассы), run.launchTime — момент выстрела.
function Ghosts.onRunEnd(player: Player, run: any, dist: number, finished: boolean)
	pending[player] = nil
	if not run.launchTime or dist < Config.GHOST_MIN_DIST then
		return
	end
	local info = { dist = math.floor(dist), fin = finished, time = os.clock() - run.launchTime }
	local c = cache[player]
	if c and c.level == run.level and not better(info, c.rec) then
		return -- не рекорд (кэша нет — решит UpdateAsync при записи)
	end
	pending[player] = {
		level = run.level,
		dist = info.dist,
		fin = finished,
		time = info.time,
		length = run.track.length,
		segments = run.track.segments, -- таблица профиля переживает track:destroy (удаляется только папка)
		origin = run.track.origin.Position,
		at = os.clock(),
	}
	GhostRemote:FireClient(player, run.level)
end

-- Проверка записи клиента против заезда, который засчитал сервер: (причина отказа | nil, сэмплов)
local function check(p: Pending, dt: number, data: string): (string?, number)
	local q = Config.GHOST_POS_Q
	local xs, ys, zs = GhostCodec.decode(data, q, Config.GHOST_MAX_SAMPLES)
	if not xs or not ys or not zs then
		return "битая запись", 0
	end
	local n = #xs
	if n < 2 then
		return "мало сэмплов", n
	end
	local duration = (n - 1) * dt
	if math.abs(duration - p.time) > Config.GHOST_TIME_TOL + p.time * 0.1 then
		return string.format("длительность %.1f с, заезд %.1f с", duration, p.time), n
	end
	local fake = { segments = p.segments, hint = 1 } -- progressOf читает только segments и hint
	local progressOf = (Track :: any).progressOf
	-- нарушение «вне трассы» и «назад» считается один раз на эпизод (вылет, возврат на трассу),
	-- рывок скорости — на каждый сэмпл
	local maxH, bad = 0, 0
	local wasOut, wasBack = false, false
	local prev: Vector3? = nil
	for i = 1, n do
		local pos = p.origin + Vector3.new(xs[i], ys[i], zs[i])
		local h, x, y = progressOf(fake, pos)
		local out = math.abs(x) > Config.GHOST_MAX_SIDE or y < -(Config.FELL_DEPTH + 20) or y > Config.GHOST_MAX_ABOVE
		if out and not wasOut then
			bad += 1
		end
		wasOut = out
		local back = h < maxH - Config.GHOST_BACK_SLACK
		if back and not wasBack then
			bad += 1
		end
		wasBack = back
		if prev and (pos - prev).Magnitude / dt > Config.GHOST_MAX_SPEED then
			bad += 1
		end
		if bad > Config.GHOST_BAD_MAX then
			return string.format("сэмпл %d: вне трассы / назад / рывок (x %.0f, y %.0f, h %.0f)", i, x, y, h), n
		end
		maxH = math.max(maxH, h)
		prev = pos
	end
	local reach = math.min(maxH, p.length)
	if math.abs(reach - p.dist) > Config.GHOST_DIST_TOL + p.dist * 0.08 then
		return string.format("путь записи %.0f, засчитано %d", reach, p.dist), n
	end
	return nil, n
end

local function onUpload(player: Player, level: any, dt: any, data: any)
	local p = pending[player]
	if not p or level ~= p.level or os.clock() - p.at > Config.GHOST_UPLOAD_WINDOW then
		return
	end
	pending[player] = nil -- одна попытка на заезд
	if typeof(dt) ~= "number" or dt ~= dt or dt < 0.1 or dt > 0.5 then
		return
	end
	if typeof(data) ~= "string" or #data == 0 or #data > Config.GHOST_MAX_CHARS then
		return
	end
	local why, n = check(p, dt, data)
	if why then
		warn(string.format("[Ghosts] запись %s (уровень %d) отклонена: %s", player.Name, p.level, why))
		return
	end
	local rec: Record = {
		v = 1,
		level = p.level,
		dist = p.dist,
		fin = p.fin,
		time = math.round(p.time * 100) / 100,
		dt = dt,
		n = n,
		data = data,
		ts = os.time(),
	}
	local userId = player.UserId
	local saved = false
	local ok = retry(function()
		saved = false
		store:UpdateAsync(key(userId, p.level), function(old)
			if not better(rec, old) then
				saved = false
				return nil -- в хранилище уже лучше (другой сервер) — отмена записи
			end
			saved = true
			return rec
		end)
	end, 3)
	if ok and saved and player.Parent then
		cache[player] = { level = p.level, rec = rec }
	end
end

function Ghosts.start()
	GetGhost.OnServerInvoke = function(player: Player, level: any)
		if not levelAllowed(player, level) then
			return false
		end
		local now = os.clock()
		if lastFetch[player] and now - lastFetch[player] < Config.GHOST_FETCH_COOLDOWN then
			local c = cache[player]
			return if c and c.level == level then c.rec else false
		end
		lastFetch[player] = now
		return fetch(player, level)
	end
	GhostRemote.OnServerEvent:Connect(onUpload)
	Players.PlayerRemoving:Connect(function(player)
		cache[player] = nil
		pending[player] = nil
		lastFetch[player] = nil
	end)
end

return Ghosts
