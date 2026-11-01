-- Удержание: ежедневные задания, скретч-билет, подарки за время в игре, сундук в лобби.
-- Все таймеры серверные (os.time), состояние лежит в профиле игрока (DataService).
-- Клиенту состояние уходит JSON-строкой в атрибут "Rewards" (меню в LobbyMenus).

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Data = require(script.Parent.DataService)

local Rewards = {}

local sessionStart: { [Player]: number } = {}

local function today(): number
	return os.time() // 86400
end

-- 3 задания дня: выбор детерминирован по номеру дня (у всех игроков одни и те же)
local function tasksFor(day: number)
	local rng = Random.new(day * 7349 + 11)
	local pool = table.clone(Config.TASK_POOL)
	local out = {}
	for _ = 1, Config.TASKS_PER_DAY do
		local t = table.remove(pool, rng:NextInteger(1, #pool))
		local target = t.targets[1] + rng:NextInteger(0, 2) * math.floor((t.targets[2] - t.targets[1]) / 2)
		table.insert(out, { id = t.id, text = string.format(t.text, target), target = target, gems = t.gems })
	end
	return out
end

local function ensure(d)
	d.Daily = d.Daily or {}
	local day = today()
	if d.Daily.day ~= day then
		d.Daily = { day = day, progress = {}, claimed = {}, chest = false }
	end
	d.TicketDay = d.TicketDay or 0
	d.ChestAt = d.ChestAt or 0
end

function Rewards.sync(player: Player)
	local d = Data.get(player)
	if not d then
		return
	end
	ensure(d)
	local tasks = tasksFor(d.Daily.day)
	local list = {}
	for i, t in tasks do
		table.insert(list, {
			id = t.id,
			text = t.text,
			target = t.target,
			gems = t.gems,
			progress = math.min(d.Daily.progress[t.id] or 0, t.target),
			claimed = d.Daily.claimed[tostring(i)] == true,
		})
	end
	local gifts = {}
	for i in Config.PLAYTIME_GIFTS do
		gifts[i] = d.GiftsClaimed and d.GiftsClaimed[tostring(i)] == true or false
	end
	player:SetAttribute("Rewards", HttpService:JSONEncode({
		tasks = list,
		chestClaimed = d.Daily.chest,
		resetAt = (d.Daily.day + 1) * 86400,
		ticketReady = d.TicketDay ~= today(),
		chestAt = d.ChestAt,
		sessionStart = sessionStart[player] or os.time(),
		gifts = gifts,
		now = os.time(),
	}))
end

function Rewards.onJoin(player: Player)
	sessionStart[player] = os.time()
	local d = Data.get(player)
	if d then
		d.GiftsClaimed = {} -- подарки за время — заново в каждой сессии
	end
	Rewards.sync(player)
end

function Rewards.onLeave(player: Player)
	sessionStart[player] = nil
end

-- Итоги заезда → прогресс заданий. Возвращает тексты заданий, выполненных этим заездом.
function Rewards.onRun(player: Player, stats: { [string]: number }): { string }
	local d = Data.get(player)
	if not d then
		return {}
	end
	ensure(d)
	local done = {}
	for _, t in tasksFor(d.Daily.day) do
		local before = d.Daily.progress[t.id] or 0
		local add = stats[t.id] or 0
		if add > 0 then
			d.Daily.progress[t.id] = before + add
			if before < t.target and before + add >= t.target then
				table.insert(done, t.text)
			end
		end
	end
	Rewards.sync(player)
	return done
end

local function grant(player: Player, d, coins: number?, gems: number?)
	if coins then
		d.Coins += Config.rewardCoins(coins, d.Level)
	end
	if gems then
		d.Gems += gems
	end
end

-- Возвращает (ok, сообщение | данные)
function Rewards.claimTask(player: Player, index: number): (boolean, any)
	local d = Data.get(player)
	if not d or typeof(index) ~= "number" then
		return false, "Недоступно"
	end
	ensure(d)
	local t = tasksFor(d.Daily.day)[index]
	if not t then
		return false, "Нет задания"
	end
	if d.Daily.claimed[tostring(index)] then
		return false, "Уже получено"
	end
	if (d.Daily.progress[t.id] or 0) < t.target then
		return false, "Ещё не выполнено"
	end
	d.Daily.claimed[tostring(index)] = true
	grant(player, d, nil, t.gems)
	Rewards.sync(player)
	return true, "+" .. t.gems .. " 💎"
end

function Rewards.claimTaskChest(player: Player): (boolean, any)
	local d = Data.get(player)
	if not d then
		return false, "Недоступно"
	end
	ensure(d)
	if d.Daily.chest then
		return false, "Уже открыт"
	end
	for i = 1, Config.TASKS_PER_DAY do
		if not d.Daily.claimed[tostring(i)] then
			return false, "Сначала забери награды за все задания"
		end
	end
	d.Daily.chest = true
	grant(player, d, Config.TASK_CHEST_COINS, Config.TASK_CHEST_GEMS)
	Rewards.sync(player)
	return true, "+" .. Config.rewardCoins(Config.TASK_CHEST_COINS, d.Level) .. " 💰  +" .. Config.TASK_CHEST_GEMS .. " 💎"
end

-- Скретч-билет: сервер сразу разыгрывает 3 награды и начисляет их, клиент только «стирает»
function Rewards.scratch(player: Player): (boolean, any)
	local d = Data.get(player)
	if not d then
		return false, "Недоступно"
	end
	ensure(d)
	if d.TicketDay == today() then
		return false, "Билет уже использован сегодня"
	end
	d.TicketDay = today()
	local total = 0
	for _, r in Config.TICKET_REWARDS do
		total += r.chance
	end
	local out = {}
	for _ = 1, 3 do
		local roll = math.random() * total
		for _, r in Config.TICKET_REWARDS do
			roll -= r.chance
			if roll <= 0 then
				local coins = if r.coins then Config.rewardCoins(r.coins, d.Level) else nil
				if coins then
					d.Coins += coins
				end
				if r.gems then
					d.Gems += r.gems
				end
				table.insert(out, { text = string.format(r.label, coins or r.gems), rarity = r.rarity, gem = r.coins == nil })
				break
			end
		end
	end
	Rewards.sync(player)
	return true, out
end

function Rewards.claimGift(player: Player, index: number): (boolean, any)
	local d = Data.get(player)
	local g = typeof(index) == "number" and Config.PLAYTIME_GIFTS[index]
	if not d or not g then
		return false, "Недоступно"
	end
	d.GiftsClaimed = d.GiftsClaimed or {}
	if d.GiftsClaimed[tostring(index)] then
		return false, "Уже получено"
	end
	if os.time() - (sessionStart[player] or os.time()) < g.min * 60 then
		return false, "Ещё рано"
	end
	d.GiftsClaimed[tostring(index)] = true
	grant(player, d, g.coins, g.gems)
	Rewards.sync(player)
	local parts = {}
	if g.coins then
		table.insert(parts, "+" .. Config.rewardCoins(g.coins, d.Level) .. " 💰")
	end
	if g.gems then
		table.insert(parts, "+" .. g.gems .. " 💎")
	end
	return true, table.concat(parts, "  ")
end

function Rewards.openChest(player: Player): (boolean, any)
	local d = Data.get(player)
	if not d then
		return false, "Недоступно"
	end
	ensure(d)
	if os.time() < d.ChestAt then
		return false, "Сундук ещё закрыт"
	end
	d.ChestAt = os.time() + Config.CHEST_INTERVAL
	grant(player, d, Config.CHEST_COINS, Config.CHEST_GEMS)
	Rewards.sync(player)
	return true, "+" .. Config.rewardCoins(Config.CHEST_COINS, d.Level) .. " 💰  +" .. Config.CHEST_GEMS .. " 💎"
end

return Rewards
