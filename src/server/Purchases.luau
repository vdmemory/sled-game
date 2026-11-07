-- Покупки за Robux: геймпасс x2 монет (атрибут X2Coins) и Developer Products (ProcessReceipt,
-- идемпотентно по ID чека).

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Data = require(script.Parent.DataService)
local Analytics = require(script.Parent.Analytics)
local PlayerState = require(script.Parent.PlayerState)
local Runs = require(script.Parent.Runs)

local runs = Runs.runs
local endRun = Runs.endRun
local syncPlayer = PlayerState.sync
local postLevel = PlayerState.postLevel

local Purchases = {}

function Purchases.start()
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased and passId == Config.GAMEPASS_X2_COINS then
			player:SetAttribute("X2Coins", true)
		end
	end)

	-- Покупки за Robux. Каждая покупка выдаётся ровно один раз: ID чека запоминаем в профиле.
	local PRODUCT_HANDLERS: { [number]: (Player, any) -> () } = {}
	if Config.PRODUCTS.SkipWorld.id ~= 0 then
		PRODUCT_HANDLERS[Config.PRODUCTS.SkipWorld.id] = function(player, d)
			d.Level = Config.worldOf(d.Level) * Config.LEVELS_PER_WORLD + 1
			d.LevelBest = 0
			d.FarmWorld = 0
			postLevel(player, d.Level)
		end
	end
	MarketplaceService.ProcessReceipt = function(info)
		local player = Players:GetPlayerByUserId(info.PlayerId)
		local d = player and Data.get(player)
		local handler = PRODUCT_HANDLERS[info.ProductId]
		-- профиль не загрузился (сохранение отключено) — не выдаём: покупка потерялась бы при выходе
		if not player or not d or not handler or not Data.canSave(player) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		d.Receipts = d.Receipts or {}
		if table.find(d.Receipts, info.PurchaseId) then
			-- уже выдано в этой сессии, но прошлое сохранение могло не пройти — подтверждаем только сохранённое
			return if Data.save(player) then Enum.ProductPurchaseDecision.PurchaseGranted else Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if runs[player] then
			endRun(player, "back")
		end
		handler(player, d)
		table.insert(d.Receipts, info.PurchaseId)
		d.Stats = d.Stats or {}
		d.Stats.Purchases = (d.Stats.Purchases or 0) + 1
		Analytics.onboarding(player, d, 7)
		Analytics.custom(player, "RobuxPurchase", info.CurrencySpent)
		while #d.Receipts > 50 do
			table.remove(d.Receipts, 1)
		end
		syncPlayer(player)
		if not Data.save(player) then
			return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox повторит вызов; чек уже в Receipts — второй выдачи не будет
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
end

return Purchases
