-- Активный набор звуков (Config.SOUND_SET): 0 — встроенные звуки Roblox (rbxasset://sounds), 1 — v1 (синтез,
-- атлас 85020498524123), 2 — v2 (записи, shared/AudioIds генерируется деплоем). Владелец 2026-11-08: v2 хуже —
-- по умолчанию v1. Смена — DEV → Настройка → «Звук: набор» + перезаход (набор читается при запуске клиента).
local Shared = script.Parent
local Config = require(Shared:WaitForChild("Config"))
local V1 = require(Shared:WaitForChild("AudioSetV1")) :: any
local V2 = require(Shared:WaitForChild("AudioIds")) :: any

local set = math.floor(Config.SOUND_SET or 1)
if set <= 0 then
	return { atlas = 0, regions = V1.regions, name = "встроенные" }
elseif set == 1 then
	return { atlas = V1.atlas, regions = V1.regions, name = "v1 (синтез)" }
end
return { atlas = V2.atlas, regions = V2.regions, name = "v2 (записи)" }
