-- Применяет у клиента настройки из панели разработчика: общие (атрибут
-- ReplicatedStorage.ConfigOverrides) и персональные для этого игрока (атрибут игрока
-- ConfigOverrides) — персональные поверх общих. Общий модуль Config у клиента один, поэтому
-- новые значения сразу видят HUD, управление санками и меню.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local player = Players.LocalPlayer

local function decode(raw: any): { [string]: any }
	local ok, data = pcall(HttpService.JSONDecode, HttpService, if typeof(raw) == "string" then raw else "{}")
	return if ok and type(data) == "table" then data else {}
end

local function apply()
	local merged = decode(ReplicatedStorage:GetAttribute("ConfigOverrides"))
	for path, v in decode(player:GetAttribute("ConfigOverrides")) do
		merged[path] = v
	end
	Config.applyOverrides(merged)
end
ReplicatedStorage:GetAttributeChangedSignal("ConfigOverrides"):Connect(apply)
player:GetAttributeChangedSignal("ConfigOverrides"):Connect(apply)
apply()
