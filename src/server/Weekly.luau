-- Лидерборд недели по мирам и титулы топ-3 прошлой недели (#26). Устройство и бюджет запросов —
-- docs/ARCHITECTURE.md → «Лидерборд недели», правила — docs/GAME_DESIGN.md → «Неделя».
--   Weekly.start()                 — циклы: опрос досок раз в REFRESH, очередь записей раз в FLUSH_TICK
--   Weekly.onJoin / onLeave(player) — свои очки недели, титул; на выходе — запись очереди
--   Weekly.onRun(player, r)        — синхронно (без yield) из endRun: результат в очередь → сводка для RunEnded
--   Weekly.refreshNow(), devTitle(player, rank), flushAll()
-- Клиентам: ReplicatedStorage.WeeklyBoard (JSON топ-10 досок), Player.WeeklyMe (JSON: мои очки и места),
-- Player.Title / TitleUntil (титул, client/WeeklyBoard рисует плашку над головой).

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Week = require(ReplicatedStorage.Shared.Week)
local Data = require(script.Parent.DataService)
local Analytics = require(script.Parent.Analytics)

local W = Config.WEEKLY -- та же таблица, что правит Tuning (setPath меняет поля на месте)
local ALL_TIME = "BestLevel_v1" -- доска «всё время» (лучший уровень), пишет Main.postLevel

local Weekly = {}

------------------------------------------------------------------ DataStore
local stores: { [string]: any } = {}
local function ordered(name: string): any?
	local s = stores[name]
	if s == nil then
		local ok, res = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, name)
		if not ok then
			return nil
		end
		s = res
		stores[name] = s
	end
	return s
end
local okWin, winnersStore = pcall(DataStoreService.GetDataStore, DataStoreService, "WeeklyWinners_v1")

local function distName(week: string, world: number | string): string
	return "LB_" .. week .. "_" .. world
end
local function cleanName(week: string): string
	return "LB_" .. week .. "_clean"
end

-- Есть ли запас в бюджете DataStore (вне Roblox / ошибка — пробуем, вызов всё равно в pcall)
local function budget(kind: Enum.DataStoreRequestType): boolean
	local ok, n = pcall(DataStoreService.GetRequestBudgetForRequestType, DataStoreService, kind)
	return not ok or n > W.BUDGET_RESERVE
end

type Entry = { id: number, v: number }

local function fetch(storeName: string, count: number): { Entry }?
	local s = ordered(storeName)
	if not s or not budget(Enum.DataStoreRequestType.GetSortedAsync) then
		return nil
	end
	local ok, pages = pcall(s.GetSortedAsync, s, false, count)
	if not ok then
		return nil
	end
	local list = {}
	for _, e in pages:GetCurrentPage() do
		local id = tonumber(string.sub(e.key, 3))
		if id then
			table.insert(list, { id = id, v = e.value })
		end
	end
	return list
end

------------------------------------------------------------------ кэш сервера
local pages: { [string]: { Entry } } = {} -- "w<N>" | "clean" | "all" → первая сотня доски
local pagesWeek = ""
local names: { [number]: string } = {} -- ники: не дёргать web API каждую минуту
local function nameOf(id: number): string
	local n = names[id]
	if n == nil then
		local p = Players:GetPlayerByUserId(id)
		if p then
			n = p.Name
		else
			local ok, res = pcall(Players.GetNameFromUserIdAsync, Players, id)
			n = if ok then res else "?"
		end
		names[id] = n
	end
	return n :: string
end

-- Место игрока по первой сотне доски и его (возможно, более свежему) счёту; nil — вне сотни / нет очков
local function rankIn(list: { Entry }?, id: number, mine: number): number?
	if not list or mine <= 0 then
		return nil
	end
	if #list >= W.PAGE and mine < list[#list].v then
		return nil
	end
	local higher = 0
	for _, e in list do
		if e.id ~= id and e.v > mine then
			higher += 1
		end
	end
	return higher + 1
end

type Pending = { dist: { [number]: number }, clean: number }
type State = {
	week: string,
	dist: { [number]: number }, -- мой лучший путь недели по мирам
	clean: number, -- мои чистые финиши недели
	loaded: { [string]: boolean },
	pending: { [string]: Pending }, -- неделя → что ещё не записано
	lastWrite: number,
	writing: boolean,
}
local state: { [Player]: State } = {}

local function stateOf(player: Player): State?
	local st = state[player]
	local week = Week.key(os.time())
	if st and st.week ~= week then -- сброс недели у онлайн-игрока (очередь прошлой недели сохраняется)
		st.week, st.dist, st.clean, st.loaded = week, {}, 0, {}
	end
	return st
end

local function publishMe(player: Player)
	local st, d = stateOf(player), Data.get(player)
	if not st or not d then
		return
	end
	local world = Config.worldOf(d.Level)
	local dist = st.dist[world] or 0
	player:SetAttribute("WeeklyMe", HttpService:JSONEncode({
		w = world,
		wn = Config.worldName(world),
		dist = dist,
		distRank = rankIn(pages["w" .. world], player.UserId, dist),
		clean = st.clean,
		cleanRank = rankIn(pages.clean, player.UserId, st.clean),
		level = d.Level,
		levelRank = rankIn(pages.all, player.UserId, d.Level),
	}))
end

-- Мои очки текущей недели (один раз на мир и неделю): GetAsync, бюджет — ARCHITECTURE
local function loadMine(player: Player)
	local st, d = stateOf(player), Data.get(player)
	if not st or not d then
		return
	end
	local week, world = st.week, Config.worldOf(d.Level)
	local key = "u_" .. player.UserId
	for _, b in { { "w" .. world, distName(week, world) }, { "clean", cleanName(week) } } do
		if not st.loaded[b[1]] and budget(Enum.DataStoreRequestType.GetAsync) then
			local s = ordered(b[2])
			local ok, v = false, nil
			if s then
				ok, v = pcall(s.GetAsync, s, key)
			end
			if ok and st.week == week then
				st.loaded[b[1]] = true
				v = if typeof(v) == "number" then v else 0
				if b[1] == "clean" then
					st.clean = math.max(st.clean, v)
				else
					st.dist[world] = math.max(st.dist[world] or 0, v)
				end
			end
		end
	end
	publishMe(player)
end

------------------------------------------------------------------ запись (не чаще WRITE_EVERY на игрока)
local function flush(player: Player, force: boolean?)
	local st = state[player]
	if not st or st.writing or next(st.pending) == nil then
		return
	end
	if not force and os.clock() - st.lastWrite < W.WRITE_EVERY then
		return
	end
	st.writing, st.lastWrite = true, os.clock()
	local key = "u_" .. player.UserId
	local batch = st.pending
	st.pending = {}
	local failed: { [string]: Pending } = {}
	for week, p in batch do
		for world, v in p.dist do
			local s = ordered(distName(week, world))
			local ok = s ~= nil and pcall(s.UpdateAsync, s, key, function(old)
				if typeof(old) == "number" and old >= v then
					return nil -- лучший результат уже записан
				end
				return v
			end)
			if not ok then
				failed[week] = failed[week] or { dist = {}, clean = 0 }
				failed[week].dist[world] = v
			end
		end
		if p.clean > 0 then
			local s = ordered(cleanName(week))
			if not (s ~= nil and pcall(s.IncrementAsync, s, key, p.clean)) then
				failed[week] = failed[week] or { dist = {}, clean = 0 }
				failed[week].clean += p.clean
			end
		end
	end
	-- неудачное — обратно в очередь (следующая попытка через WRITE_EVERY)
	for week, f in failed do
		local p = st.pending[week] or { dist = {}, clean = 0 }
		st.pending[week] = p
		for world, v in f.dist do
			p.dist[world] = math.max(p.dist[world] or 0, v)
		end
		p.clean += f.clean
	end
	st.writing = false
end

------------------------------------------------------------------ титулы
local winners: { [string]: any } = {} -- неделя → документ WeeklyWinners_v1 { ["w<N>"|"clean"] = { UserId топ-3 } }

-- Топ-3 доски прошлой недели. Первый сервер считает его по OrderedDataStore и пишет в WeeklyWinners_v1
-- (UpdateAsync: уже записанное не меняем) — все серверы выдают одинаковые титулы. nil — нет данных.
local function winnersFor(week: string, board: string, storeName: string): { number }?
	if not okWin then
		return nil
	end
	local doc = winners[week]
	if doc == nil then
		if not budget(Enum.DataStoreRequestType.GetAsync) then
			return nil
		end
		local ok, res = pcall(winnersStore.GetAsync, winnersStore, week)
		if not ok then
			return nil
		end
		doc = if type(res) == "table" then res else {}
		winners[week] = doc
	end
	if doc[board] ~= nil then
		return doc[board]
	end
	local list = fetch(storeName, 3)
	if not list or not budget(Enum.DataStoreRequestType.UpdateAsync) then
		return nil
	end
	local ids = {}
	for i, e in list do
		ids[i] = e.id
	end
	local ok, res = pcall(winnersStore.UpdateAsync, winnersStore, week, function(old)
		old = if type(old) == "table" then old else {}
		if old[board] == nil then
			old[board] = ids
		end
		return old
	end)
	if ok and type(res) == "table" then
		winners[week] = res
		return res[board]
	end
	return nil
end

local function titleIndex(id: string): number?
	for i, t in W.TITLES do
		if t.id == id then
			return i
		end
	end
	return nil
end

local function syncTitle(player: Player)
	local d = Data.get(player)
	if not d then
		return
	end
	local active = d.Title ~= "" and d.TitleUntil > os.time() and titleIndex(d.Title) ~= nil
	player:SetAttribute("Title", if active then d.Title else "")
	player:SetAttribute("TitleUntil", if active then d.TitleUntil else 0)
end

local function award(player: Player, d: any, rank: number?, now: number)
	d.TitleWeek = Week.key(now)
	if rank and W.TITLES[rank] then
		d.Title = W.TITLES[rank].id
		d.TitleUntil = Week.reset(now)
		Analytics.custom(player, "TitleAwarded", rank)
	end
	syncTitle(player)
end

-- Первый вход (или первая минута онлайн) в новой неделе: титул по месту в прошлой
local titleBusy = false
local function checkTitle(player: Player)
	local d = Data.get(player)
	local now = os.time()
	if not d or d.TitleWeek == Week.key(now) or now - Week.start(now) < W.WINNERS_DELAY then
		return
	end
	local prev = Week.prevKey(now)
	local wp = d.WeekPlay
	local best: number? = nil
	if type(wp) == "table" and wp.key == prev then
		local boards = {}
		for ws in (wp.worlds or {}) :: any do
			table.insert(boards, { "w" .. ws, distName(prev, ws) })
		end
		if wp.clean then
			table.insert(boards, { "clean", cleanName(prev) })
		end
		for _, b in boards do
			local ids = winnersFor(prev, b[1], b[2])
			if ids == nil then
				return -- лимит/ошибка: повторим в следующем цикле
			end
			for i, id in ids do
				if id == player.UserId and (best == nil or i < best) then
					best = i
				end
			end
		end
	end
	if Data.get(player) == d then
		award(player, d, best, now)
	end
end

------------------------------------------------------------------ табло
local refreshing = false
local function doRefresh()
	local now = os.time()
	local week = Week.key(now)
	if week ~= pagesWeek then
		pages, pagesWeek = {}, week
	end
	-- доски: всё время + чистые финиши + миры, где сейчас игроки этого сервера
	local boards = { { "all", ALL_TIME }, { "clean", cleanName(week) } }
	local seen = {}
	for _, p in Players:GetPlayers() do
		local d = Data.get(p)
		local w = d and Config.worldOf(d.Level)
		if w and not seen[w] then
			seen[w] = true
			table.insert(boards, { "w" .. w, distName(week, w) })
		end
	end
	for _, b in boards do
		local list = fetch(b[2], W.PAGE)
		if list then
			pages[b[1]] = list
		end
	end
	local pub = { week = week, reset = Week.reset(now), boards = {} :: { [string]: any } }
	for id, list in pages do
		local top = {}
		for i = 1, math.min(W.SHOW, #list) do
			top[i] = { id = list[i].id, n = nameOf(list[i].id), v = list[i].v }
		end
		pub.boards[id] = top
	end
	ReplicatedStorage:SetAttribute("WeeklyBoard", HttpService:JSONEncode(pub))
	for _, p in Players:GetPlayers() do
		loadMine(p) -- кэш: GetAsync только для нового мира/недели
	end
	if not titleBusy then
		titleBusy = true
		for _, p in Players:GetPlayers() do
			pcall(checkTitle, p)
		end
		titleBusy = false
	end
end
local function refresh()
	if refreshing then
		return
	end
	refreshing = true
	local ok, err = pcall(doRefresh)
	refreshing = false
	if not ok then
		warn("[Weekly] " .. tostring(err))
	end
end

------------------------------------------------------------------ API
function Weekly.start()
	task.spawn(function()
		while true do
			refresh()
			task.wait(W.REFRESH)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(W.FLUSH_TICK)
			for player in state do
				task.spawn(flush, player)
			end
		end
	end)
end

function Weekly.onJoin(player: Player)
	state[player] = { week = Week.key(os.time()), dist = {}, clean = 0, loaded = {}, pending = {}, lastWrite = 0, writing = false }
	syncTitle(player)
	task.spawn(function()
		loadMine(player)
		if not titleBusy then
			titleBusy = true
			pcall(checkTitle, player)
			titleBusy = false
		end
	end)
end

function Weekly.onLeave(player: Player)
	task.spawn(function()
		local st = state[player]
		while st and st.writing do
			task.wait(0.2)
		end
		flush(player, true)
		state[player] = nil
	end)
end

function Weekly.flushAll()
	for player in state do
		task.spawn(flush, player, true)
	end
end

-- r = { level, dist, finished, clean, farm, cheat, flags, elapsed }. Без yield (вызывается из endRun).
-- Возвращает сводку для итога заезда или nil (фарм / «cheat» — доска не трогается).
function Weekly.onRun(player: Player, r: any): any?
	local st, d = stateOf(player), Data.get(player)
	if not st or not d or r.farm or r.cheat then
		return nil
	end
	local world = Config.worldOf(r.level)
	local dist = math.floor(r.dist)
	-- античит: мягкие флаги или путь быстрее правдоподобного — результат не идёт в доску
	if (r.flags or 0) >= W.MAX_FLAGS or dist > r.elapsed * W.MAX_AVG_SPEED then
		Analytics.custom(player, "CheatSuspect", r.flags or 0)
		return { world = world, excluded = true }
	end
	local cleanAdd = if r.finished and r.clean then 1 else 0
	if dist > 0 or cleanAdd > 0 then
		local p = st.pending[st.week] or { dist = {}, clean = 0 }
		st.pending[st.week] = p
		if dist > (st.dist[world] or 0) then
			st.dist[world] = dist
			p.dist[world] = math.max(p.dist[world] or 0, dist)
		end
		p.clean += cleanAdd
		st.clean += cleanAdd
		-- где играл на этой неделе: по этому в следующую неделю ищем титул
		if type(d.WeekPlay) ~= "table" or d.WeekPlay.key ~= st.week then
			d.WeekPlay = { key = st.week, worlds = {}, clean = false }
		end
		d.WeekPlay.worlds[tostring(world)] = true
		if cleanAdd > 0 then
			d.WeekPlay.clean = true
		end
		publishMe(player)
	end
	local best = st.dist[world] or 0
	return { world = world, best = best, rank = rankIn(pages["w" .. world], player.UserId, best) }
end

function Weekly.refreshNow()
	task.spawn(refresh)
end

-- DEV: титул себе на текущую неделю (1..3; 0 — снять)
function Weekly.devTitle(player: Player, rank: number)
	local d = Data.get(player)
	if not d then
		return
	end
	local now = os.time()
	d.Title, d.TitleUntil = "", 0
	award(player, d, if rank >= 1 and rank <= #W.TITLES then math.floor(rank) else nil, now)
end

return Weekly
