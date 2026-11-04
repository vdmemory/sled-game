-- Применяет у клиента настройки из панели разработчика (сервер кладёт их в атрибут
-- ReplicatedStorage.ConfigOverrides). Общий модуль Config у клиента один, поэтому новые
-- значения сразу видят HUD, управление санками и меню.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local function apply()
	local raw = ReplicatedStorage:GetAttribute("ConfigOverrides")
	local ok, data = pcall(HttpService.JSONDecode, HttpService, if typeof(raw) == "string" then raw else "{}")
	Config.applyOverrides(if ok and type(data) == "table" then data else {})
end
ReplicatedStorage:GetAttributeChangedSignal("ConfigOverrides"):Connect(apply)
apply()
