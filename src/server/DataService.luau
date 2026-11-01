-- Сохранение прогресса через DataStore.
-- Для продакшена позже стоит перейти на ProfileStore (защита от дюпа и одновременных сессий).

local DataStoreService = game:GetService("DataStoreService")

local store = DataStoreService:GetDataStore("SledData_v1")

local DEFAULT = {
	Coins = 0,
	Level = 1, -- текущий уровень (мир)
	LevelBest = 0, -- лучший % на текущем уровне
	LaunchLevel = 0,
	RocketLevel = 0,
	SledLevel = 0,
	IncomeLevel = 0,
	Gems = 0,
	Skin = "classic", -- надетый скин
	OwnedSkins = { classic = true },
	Settings = { Sfx = true, Snow = true, Shadows = true },
	Sled = "tube", -- модель саней
	SledRarity = 1,
	OwnedSleds = { ["tube:1"] = true },
	Trail = "white",
	OwnedTrails = { white = true },
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

type Profile = { data: { [string]: any }, canSave: boolean }

local Data = {}
local profiles: { [Player]: Profile } = {}

local function retry(fn: () -> any): (boolean, any)
	for attempt = 1, 3 do
		local ok, res = pcall(fn)
		if ok then
			return true, res
		end
		warn("[Data] попытка " .. attempt .. ": " .. tostring(res))
		task.wait(attempt * 2)
	end
	return false, nil
end

local function key(player: Player): string
	return "u_" .. player.UserId
end

function Data.load(player: Player)
	local ok, saved = retry(function()
		return store:GetAsync(key(player))
	end)
	local data = deepCopy(DEFAULT)
	if ok and type(saved) == "table" then
		for k, v in saved do
			data[k] = v
		end
	end
	-- Если загрузка не удалась, не сохраняем — иначе затрём реальный прогресс пустым
	profiles[player] = { data = data, canSave = ok }
	if not ok then
		warn("[Data] не удалось загрузить " .. player.Name .. ", сохранение отключено")
	end
	return data
end

function Data.get(player: Player)
	local p = profiles[player]
	return p and p.data
end

function Data.save(player: Player)
	local p = profiles[player]
	if not p or not p.canSave then
		return
	end
	retry(function()
		store:SetAsync(key(player), p.data)
	end)
end

function Data.release(player: Player)
	Data.save(player)
	profiles[player] = nil
end

function Data.saveAll()
	for player in profiles do
		task.spawn(Data.save, player)
	end
end

return Data
