-- Магазин за игровую валюту: сани (модель + редкость), следы, апгрейды; награды (задания,
-- подарки, сундук, стрик) и действия с мирами (фарм пройденного, пропуск за Robux).

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Data = require(script.Parent.DataService)
local Rewards = require(script.Parent.Rewards)
local Tuning = require(script.Parent.Tuning)
local Analytics = require(script.Parent.Analytics)
local Remotes = require(script.Parent.Remotes)
local PlayerState = require(script.Parent.PlayerState)
local Runs = require(script.Parent.Runs)

local runs = Runs.runs
local syncPlayer = PlayerState.sync
local RewardAction: RemoteFunction = Remotes.RewardAction
local TaskDone: RemoteEvent = Remotes.TaskDone
local SledAction: RemoteFunction = Remotes.SledAction
local TrailAction: RemoteFunction = Remotes.TrailAction
local BuyUpgrade: RemoteFunction = Remotes.BuyUpgrade
local WorldAction: RemoteFunction = Remotes.WorldAction

local Shop = {}

-- Покупки и цены считаем по Config, настроенному под игрока (Tuning.forPlayer): обработчики ниже
-- синхронные (без yield), поэтому подмена Config не видна другим игрокам.
-- Сани: модель открывается с миром, редкости покупаются по порядку; купленное — надеть
local function sledAction(player: Player, id: any, rarity: any): (boolean, string?)
	local d = Data.get(player)
	if not d or runs[player] or typeof(id) ~= "string" or typeof(rarity) ~= "number" then
		return false, "Недоступно"
	end
	local model = Config.sled(id)
	if model.id ~= id or not Config.RARITIES[rarity] then
		return false, "Нет таких саней"
	end
	local key = id .. ":" .. rarity
	if not d.OwnedSleds[key] then
		if Config.worldOf(d.Level) < model.world then
			return false, "Откроется в мире " .. model.world
		end
		if rarity > 1 and not d.OwnedSleds[id .. ":" .. (rarity - 1)] then
			return false, "Сначала купи " .. Config.RARITIES[rarity - 1].name
		end
		local price = model.prices[rarity]
		if d.Coins < price then
			return false, "Не хватает монет"
		end
		d.Coins -= price
		d.OwnedSleds[key] = true
		Analytics.economy(player, "Sink", "Coins", price, d.Coins, Enum.AnalyticsEconomyTransactionType.Shop.Name, "Sled:" .. key, Analytics.fields(Config.worldOf(d.Level), nil, "Sled"))
		for _, text in Rewards.add(player, "buySled") do -- задание «Купи N редкостей саней»
			TaskDone:FireClient(player, text)
		end
	end
	d.Sled = id
	d.SledRarity = rarity
	syncPlayer(player)
	return true, model.name .. " · " .. Config.RARITIES[rarity].name
end

local function trailAction(player: Player, id: any): (boolean, string?)
	local d = Data.get(player)
	if not d or runs[player] or typeof(id) ~= "string" then
		return false, "Недоступно"
	end
	local t = Config.trail(id)
	if t.id ~= id then
		return false, "Нет такого следа"
	end
	if not d.OwnedTrails[id] then
		if d.Coins < t.price then
			return false, "Не хватает монет"
		end
		d.Coins -= t.price
		Analytics.economy(player, "Sink", "Coins", t.price, d.Coins, Enum.AnalyticsEconomyTransactionType.Shop.Name, "Trail:" .. id, Analytics.fields(Config.worldOf(d.Level), nil, "Trail"))
		d.OwnedTrails[id] = true
	end
	d.Trail = id
	syncPlayer(player)
	return true, "След «" .. t.name .. "» надет"
end

local function buyUpgrade(player: Player, name: any): (boolean, string?)
	local u = Config.UPGRADES[name]
	local d = Data.get(player)
	if not u or not d or runs[player] then
		return false, "Недоступно"
	end
	local field = name .. "Level"
	local level = d[field]
	if level >= u.MaxLevel then
		return false, "Максимум"
	end
	local cost, currency = Config.upgradePrice(name, level)
	if d[currency] < cost then
		return false, if currency == "Gems" then "Не хватает гемов 💎" else "Не хватает монет"
	end
	d[currency] -= cost
	local nextLevel = Config.upgradeNext(name, level) -- ракета: сразу до следующего тира (#47)
	d[field] = nextLevel
	Analytics.economy(player, "Sink", currency, cost, d[currency], Enum.AnalyticsEconomyTransactionType.Shop.Name, "Upgrade:" .. name, Analytics.fields(Config.worldOf(d.Level), nextLevel, "Upgrade " .. name))
	Analytics.onboarding(player, d, 4)
	syncPlayer(player)
	for _, text in Rewards.add(player, "upgrades") do
		TaskDone:FireClient(player, text)
	end
	-- новый тир → клиент покажет «ПОЛУЧЕНО: …» (Reveal «было → стало»; у ракеты — каждая покупка)
	if nextLevel % Config.TIER_SIZE == 0 then
		return true, Config.tierName(name, nextLevel)
	end
	return true
end

function Shop.start()
	SledAction.OnServerInvoke = function(player, id, rarity)
		return Tuning.forPlayer(player, function()
			return sledAction(player, id, rarity)
		end)
	end
	TrailAction.OnServerInvoke = function(player, id)
		return Tuning.forPlayer(player, function()
			return trailAction(player, id)
		end)
	end

	RewardAction.OnServerInvoke = function(player, action, arg)
		local ok, res
		if action == "task" then
			ok, res = Rewards.claimTask(player, arg)
		elseif action == "taskChest" then
			ok, res = Rewards.claimTaskChest(player)
		elseif action == "gift" then
			ok, res = Rewards.claimGift(player, arg)
		elseif action == "chest" then
			ok, res = Rewards.openChest(player)
		elseif action == "streak" then
			ok, res = Rewards.claimStreak(player)
		elseif action == "streakSave" then
			ok, res = Rewards.saveStreak(player)
		elseif action == "streakDecline" then
			ok, res = Rewards.declineStreakSave(player)
		else
			return false, "?"
		end
		syncPlayer(player)
		return ok, res
	end

	BuyUpgrade.OnServerInvoke = function(player, name)
		return Tuning.forPlayer(player, function()
			return buyUpgrade(player, name)
		end)
	end

	-- Миры: «farm» — кататься в пройденном мире (0 = вернуться в текущий),
	-- «skip» — пропустить текущий мир за Robux (Developer Product, выдаёт ProcessReceipt ниже)
	WorldAction.OnServerInvoke = function(player, action, arg)
		local d = Data.get(player)
		if not d or runs[player] then
			return false, "Недоступно"
		end
		local current = Config.worldOf(d.Level)
		if action == "farm" then
			local owner = player.UserId == game.CreatorId
			if typeof(arg) ~= "number" or arg % 1 ~= 0 or arg < 0 or (arg >= current and not owner) or arg > 99 then
				return false, "Мир ещё не пройден"
			end
			d.FarmWorld = arg
			syncPlayer(player)
			return true, if arg == 0 then "Вернулся в мир " .. current else "Фарм: " .. Config.worldName(arg)
		elseif action == "skip" then
			local product = Config.PRODUCTS.SkipWorld
			if product.id == 0 then
				return false, "Пропуск мира появится скоро"
			end
			MarketplaceService:PromptProductPurchase(player, product.id)
			return true
		end
		return false, "Недоступно"
	end
end

return Shop
