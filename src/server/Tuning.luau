-- Настройка игры на лету: владелец меняет параметры в панели разработчика (вкладка «Настройка»).
-- Изменения { путь = число } лежат в DataStore, применяются к Config на сервере и у клиентов
-- (атрибут ReplicatedStorage.ConfigOverrides, JSON) и рассылаются на все сервера (MessagingService).

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Tuning = {}

local store = DataStoreService:GetDataStore("GameConfig_v1")
local KEY = "overrides"
local TOPIC = "SledConfigChanged"
local current: { [string]: number } = {}

local function apply(overrides: { [string]: any })
	-- оставляем только известные числовые параметры
	local clean = {}
	for _, tn in Config.TUNABLES do
		local v = overrides[tn[1]]
		if typeof(v) == "number" and v == v then
			clean[tn[1]] = math.clamp(v, tn[4], tn[5])
		end
	end
	current = clean
	Config.applyOverrides(clean)
	ReplicatedStorage:SetAttribute("ConfigOverrides", HttpService:JSONEncode(clean))
end

local function load()
	local ok, saved = pcall(store.GetAsync, store, KEY)
	if ok and type(saved) == "table" then
		apply(saved)
	elseif not ok then
		warn("[Tuning] не удалось загрузить настройки: " .. tostring(saved))
	end
end

function Tuning.init()
	apply({})
	load()
	pcall(function()
		MessagingService:SubscribeAsync(TOPIC, function()
			load()
		end)
	end)
end

function Tuning.get(): { [string]: number }
	return current
end

-- Сохранить новый набор изменений (пустой — вернуть всё по умолчанию)
function Tuning.save(overrides: { [string]: any }): (boolean, string)
	apply(overrides)
	local ok, err = pcall(store.SetAsync, store, KEY, current)
	if not ok then
		return false, "Не сохранилось: " .. tostring(err)
	end
	pcall(MessagingService.PublishAsync, MessagingService, TOPIC, os.time())
	local n = 0
	for _ in current do
		n += 1
	end
	return true, if n == 0 then "Всё по умолчанию" else "Сохранено изменений: " .. n
end

return Tuning
