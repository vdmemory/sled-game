-- Звуки. Используем только встроенные звуки клиента Roblox (rbxasset://sounds/...),
-- они есть у всех игроков и не требуют загрузки ассетов.
-- Свои звуки потом можно залить в Creator Hub и подставить rbxassetid://ID.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local controller = script.Parent:WaitForChild("SledController")
local state = controller:WaitForChild("State")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local function sound(file: string, volume: number, pitch: number?, looped: boolean?): Sound
	local s = Instance.new("Sound")
	s.SoundId = "rbxasset://sounds/" .. file
	s.Volume = volume
	s.PlaybackSpeed = pitch or 1
	s.Looped = looped or false
	s.Parent = SoundService
	return s
end

-- Одиночные эффекты: имя события → {файл, громкость, высота}
local ONE_SHOTS = {
	launch = { "action_jump.mp3", 0.9, 0.75 },
	pull = { "button.wav", 0.5, 0.6 },
	land = { "action_jump_land.mp3", 0.9, 0.8 },
	hit = { "oof.ogg", 0.7, 1 },
	boost = { "impact_water.mp3", 0.5, 1.6 },
	coin = { "volume_slider.ogg", 0.6, 1.8 },
	flip = { "action_get_up.mp3", 0.8, 1.4 },
	finish = { "impact_explosion_03.mp3", 0.35, 1.2 },
	smash = { "impact_explosion_03.mp3", 0.25, 1.8 },
	record = { "electronicpingshort.wav", 0.6, 1 },
}
local cache: { [string]: Sound } = {}
local function play(name: string)
	local spec = ONE_SHOTS[name]
	if not spec then
		return
	end
	local s = cache[name]
	if not s then
		s = sound(spec[1], spec[2], spec[3])
		cache[name] = s
	end
	-- Монетки идут пачками — даём им слегка разную высоту
	if name == "coin" then
		s.PlaybackSpeed = spec[3] + math.random() * 0.2
	end
	if player:GetAttribute("SetSfx") == false then
		return
	end
	SoundService:PlayLocalSound(s)
end

controller:WaitForChild("Sfx").Event:Connect(play)
Remotes.RunEnded.OnClientEvent:Connect(function(r)
	if r.reason == "finish" then
		play("finish")
	end
end)

-- Петли: ветер растёт со скоростью, шипение ракеты
local wind = sound("action_falling.ogg", 0, 1, true)
local jet = sound("action_falling.ogg", 0, 2.2, true)
wind:Play()
jet:Play()

RunService.RenderStepped:Connect(function(dt)
	local speed = state.Speed.Value
	local riding = player:GetAttribute("Launched") == true
	local muted = player:GetAttribute("SetSfx") == false
	local targetWind = if muted then 0 elseif riding then math.clamp(speed / 110, 0, 1) * 0.6 else 0
	wind.Volume += (targetWind - wind.Volume) * math.min(1, dt * 4)
	wind.PlaybackSpeed = 0.8 + math.clamp(speed / 140, 0, 1) * 0.6
	local targetJet = if state.RocketOn.Value and not muted then 0.5 else 0
	jet.Volume += (targetJet - jet.Volume) * math.min(1, dt * 10)
end)
