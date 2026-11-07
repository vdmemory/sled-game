-- Предметы на трассе (сервер начисляет): монеты с комбо, магнит, бонусы (x2, кольца, канистра,
-- ускорители), гемы, ледяной кристалл. Касания и клиентские сообщения проверяются на близость.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Tuning = require(script.Parent.Tuning)
local AntiCheat = require(script.Parent.AntiCheat)
local Remotes = require(script.Parent.Remotes)
local Runs = require(script.Parent.Runs)

local runs = Runs.runs
local Crystal: RemoteEvent = Remotes.Crystal
local CoinGrab: RemoteEvent = Remotes.CoinGrab
local PowerUp: RemoteEvent = Remotes.PowerUp

type Run = Runs.Run

local Pickups = {}

------------------------------------------------------------------ Монетки на трассе
local function playerFromHit(hit: BasePart): Player?
	local owner = hit:GetAttribute("Owner") or (hit.Parent and hit.Parent:GetAttribute("Owner"))
	if owner then
		return Players:GetPlayerByUserId(owner)
	end
	local model = hit:FindFirstAncestorOfClass("Model")
	return model and Players:GetPlayerFromCharacter(model)
end

-- Монета с комбо: подряд (без пауз) — множитель растёт
local function awardCoin(player: Player, run: Run)
	local now = os.clock()
	run.combo = if now - (run.lastCoin or 0) < Config.COMBO_WINDOW then (run.combo or 0) + 1 else 1
	run.lastCoin = now
	local value = Tuning.forPlayer(player, function()
		return Config.COIN_PICKUP_VALUE * Config.comboMult(run.combo or 1) * (if (run.x2Until or 0) > now then 2 else 1)
	end)
	run.bonusCoins += value
	player:SetAttribute("RunCoins", (player:GetAttribute("RunCoins") or 0) + value)
	player:SetAttribute("Combo", run.combo)
	run.maxCombo = math.max(run.maxCombo or 0, run.combo or 0)
end

local function takeCoin(coin: BasePart)
	coin:SetAttribute("Taken", true)
	coin.Transparency = 1
	coin.CanTouch = false
	for _, detail in coin:GetChildren() do
		if detail:IsA("BasePart") then
			detail.Transparency = 1
		end
	end
end

local function setupCoin(coin: Instance)
	if not coin:IsA("BasePart") then
		return
	end
	coin.Touched:Connect(function(hit)
		if coin:GetAttribute("Taken") then
			return
		end
		local player = playerFromHit(hit)
		local run = player and runs[player]
		if not run or run.ended then
			return
		end
		takeCoin(coin)
		awardCoin(player, run)
	end)
end

function Pickups.start()
	-- Магнит: клиент притягивает монеты и сообщает; проверяем, что монета рядом с санками
	CoinGrab.OnServerEvent:Connect(function(player, coin)
		local run = runs[player]
		if not run or run.ended or typeof(coin) ~= "Instance" or not coin:IsA("BasePart") then
			return
		end
		if not CollectionService:HasTag(coin, "Coin") or coin:GetAttribute("Taken") then
			return
		end
		local radius = Tuning.forPlayer(player, function()
			return Config.MAGNET_RADIUS
		end)
		if (coin.Position - run.sled.Position).Magnitude > radius + 25 then
			return
		end
		takeCoin(coin)
		awardCoin(player, run)
		run.magnetCoins = (run.magnetCoins or 0) + 1 -- задание «Притяни магнитом N монет»
	end)

	-- Бонусы на трассе: x2 монеты (на время) и кольца (+монеты). Щит и канистра — только у клиента.
	PowerUp.OnServerEvent:Connect(function(player, part)
		local run = runs[player]
		if not run or run.ended or typeof(part) ~= "Instance" or not part:IsA("BasePart") then
			return
		end
		-- только предметы своей трассы и рядом с санками по серверу (с поправкой на пинг)
		if not part:IsDescendantOf(run.track.folder) or not Tuning.forPlayer(player, function()
			return AntiCheat.near(run, part.Position)
		end) then
			return
		end
		-- ускоритель: каждую полосу считаем один раз (для заданий)
		if CollectionService:HasTag(part, "Boost") then
			local pads = run.boostPads or {}
			run.boostPads = pads
			if not pads[part] then
				pads[part] = true
				run.boosts = (run.boosts or 0) + 1
				Tuning.forPlayer(player, function()
					AntiCheat.onBoost(run) -- честный разгон: поднимаем предел скорости
				end)
			end
			return
		end
		local kind = if CollectionService:HasTag(part, "Magnet") then "magnet" else part:GetAttribute("Kind")
		if typeof(kind) ~= "string" or not (CollectionService:HasTag(part, "PowerUp") or kind == "magnet") or part:GetAttribute("Taken") then
			return
		end
		part:SetAttribute("Taken", true)
		local picked = run.picked or {}
		run.picked = picked
		picked[kind] = (picked[kind] or 0) + 1
		if kind == "fuel" then
			AntiCheat.onFuel(run) -- полный бак: ракета снова может разгонять
		elseif kind == "x2" then
			run.x2Until = os.clock() + Tuning.forPlayer(player, function()
				return Config.POWERUPS.x2.time
			end)
		elseif kind == "ring" then
			local c = Tuning.forPlayer(player, function()
				return Config.POWERUPS.rings.coins
			end)
			run.bonusCoins += c
			player:SetAttribute("RunCoins", (player:GetAttribute("RunCoins") or 0) + c)
		end
	end)

	-- Гем на трассе
	CollectionService:GetInstanceAddedSignal("Gem"):Connect(function(gem)
		if not gem:IsA("BasePart") then
			return
		end
		gem.Touched:Connect(function(hit)
			if gem:GetAttribute("Taken") then
				return
			end
			local player = playerFromHit(hit)
			local run = player and runs[player]
			if not run or run.ended then
				return
			end
			gem:SetAttribute("Taken", true)
			gem.Transparency = 1
			gem.CanTouch = false
			run.gems = (run.gems or 0) + 1
			player:SetAttribute("RunGems", run.gems)
		end)
	end)

	-- Ледяной кристалл: клиент разбивает его касанием, сервер начисляет (один раз за заезд)
	Crystal.OnServerEvent:Connect(function(player, part)
		local run = runs[player]
		if not run or run.ended or run.crystal or typeof(part) ~= "Instance" or not part:IsA("BasePart") or not CollectionService:HasTag(part, "Crystal") then
			return
		end
		if (part.Position - run.sled.Position).Magnitude > 30 then
			return
		end
		run.crystal = true
		local add = Tuning.forPlayer(player, function()
			return Config.CRYSTAL_COINS
		end)
		run.bonusCoins += add
		run.gems = (run.gems or 0) + 1
		player:SetAttribute("RunCoins", (player:GetAttribute("RunCoins") or 0) + add)
		player:SetAttribute("RunGems", run.gems)
	end)
	CollectionService:GetInstanceAddedSignal("Coin"):Connect(setupCoin)
end

return Pickups
