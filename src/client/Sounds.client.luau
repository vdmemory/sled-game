-- Звук игры (docs/GAME_DESIGN.md → «Звук», docs/ARCHITECTURE.md → «Звук»).
--
-- Источник (по приоритету): Config.SOUND.library[имя] — ID из Roblox Creator Store (играет весь ассет, без
-- загрузки и лимита) → свой атлас assets/audio/sfx_atlas_v2.ogg (записи CC0/CC BY + синтез, scripts/gen_audio.py)
-- — один аудио-ассет, каждый звук играет свой кусок через Sound.PlaybackRegion, лупы — через LoopRegion
-- (shared/AudioIds) → пока атлас не загружен/на модерации — встроенные rbxasset://sounds/* (FALLBACK).
-- Громкость каждого звука берётся из Config.SOUND.sfx в момент проигрывания (правится в DEV → «Звуки»).
--
-- Проверка из панели DEV: BindableEvent «SoundTest» под этим скриптом — ("sfx", имя) сыграть как в игре,
-- ("loop", имя, вкл, доля скорости 0..1) — луп как на этой скорости, ("music", nil | 0 лобби | номер мира).
-- Атрибут SoundService «SoundSource»: "atlas" | "builtin" — что сейчас играет.
--
-- Каналы SoundGroup в SoundService: Music, SFX, UI, Ambience (Config.SOUND.groups). Выключатели ⚙
-- «Звуки»/«Музыка» (атрибуты SetSfx/SetMusic) глушат каналы. Музыка приглушается (ducking) на финише,
-- аварии, падении и наградах. События: controller.Sfx:Fire(имя, [число]) из любых клиентских скриптов;
-- UI-хуки — UIKit.sfx (окно, «нет», сундук, полёт монет) и клик любой кнопки в PlayerGui.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local CollectionService = game:GetService("CollectionService")
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer
local controller = script.Parent:WaitForChild("SledController")
local state = controller:WaitForChild("State")
local st = require(script.Parent:WaitForChild("Sled"):WaitForChild("State")) :: any
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local AudioIds = require(Shared:WaitForChild("AudioSet")) :: any
local UI = require(Shared:WaitForChild("UIKit")) :: any

local SND = Config.SOUND

------------------------------------------------------------------ каналы
local groups: { [string]: SoundGroup } = {}
for name in SND.groups do
	local g = Instance.new("SoundGroup")
	g.Name = name
	g.Volume = 0
	g.Parent = SoundService
	groups[name] = g
end

------------------------------------------------------------------ источник: атлас или встроенные
-- Встроенные звуки — запасной вариант: { файл, множитель громкости, высота }. Нет записи — тишина.
local FALLBACK: { [string]: { any } } = {
	pull = { "button.wav", 0.5, 0.6 }, -- без атласа: щелчок начала натяжения (с атласом — луп stretch)
	click = { "button.wav", 0.6, 1.3 },
	open = { "button.wav", 0.5, 1 },
	deny = { "button.wav", 0.6, 0.55 },
	buy = { "electronicpingshort.wav", 0.6, 1.6 },
	claim = { "electronicpingshort.wav", 0.5, 1.3 },
	chest = { "impact_explosion_03.mp3", 0.3, 1.6 },
	ready = { "electronicpingshort.wav", 0.6, 1.2 },
	task = { "electronicpingshort.wav", 0.6, 1.1 },
	reveal = { "action_falling.ogg", 0.5, 1.4 },
	tierup = { "electronicpingshort.wav", 0.8, 0.9 },
	coin = { "volume_slider.ogg", 0.9, 1.8 },
	gem = { "electronicpingshort.wav", 0.7, 1.5 },
	crystal = { "electronicpingshort.wav", 0.7, 1.9 },
	shield = { "electronicpingshort.wav", 0.7, 0.8 },
	shieldhit = { "impact_explosion_03.mp3", 0.3, 1.8 },
	x2 = { "electronicpingshort.wav", 0.7, 1.4 },
	magnet = { "electronicpingshort.wav", 0.7, 0.7 },
	fuel = { "impact_water.mp3", 0.6, 1.2 },
	ring = { "electronicpingshort.wav", 0.6, 1.7 },
	boost = { "impact_water.mp3", 0.6, 1.6 },
	spring = { "action_jump.mp3", 0.7, 0.6 },
	launch = { "action_jump.mp3", 0.9, 0.75 },
	jump = { "action_jump.mp3", 0.7, 1.35 },
	land = { "action_jump_land.mp3", 1, 0.8 },
	spin = { "action_get_up.mp3", 0.5, 1.8 },
	flip = { "action_get_up.mp3", 0.9, 1.4 },
	wipe = { "action_jump_land.mp3", 1, 0.6 },
	smash = { "impact_explosion_03.mp3", 0.3, 1.8 },
	crash = { "impact_explosion_03.mp3", 0.45, 1.1 },
	fall = { "action_falling.ogg", 0.8, 1 },
	rocket_on = { "impact_water.mp3", 0.5, 2 },
	finish = { "impact_explosion_03.mp3", 0.4, 1.2 },
	record = { "electronicpingshort.wav", 0.7, 1 },
	horn = { "electronicpingshort.wav", 0.7, 0.32 },
	wind = { "action_falling.ogg", 1, 1 },
	rocket = { "action_falling.ogg", 0.9, 2.2 },
}
local ALIAS: { [string]: string } = { hit = "crash", reward = "ready" } -- старые имена событий

local useAtlas = false -- атлас загружен и играет
local atlasId = "rbxassetid://" .. tostring(AudioIds.atlas or 0)
SoundService:SetAttribute("SoundSource", "builtin")

-- Множитель громкости источника: у встроенных свой (FALLBACK[2]), у атласа и библиотеки — 1
local function srcGain(name: string): number
	if (SND.library and SND.library[name]) or (useAtlas and AudioIds.regions[name]) then
		return 1
	end
	local fb = FALLBACK[name]
	return if fb then fb[2] else 1
end
local function specVol(name: string): number
	local spec = SND.sfx[name]
	return (if spec then spec[1] else 0.5) * srcGain(name)
end

-- Настроить Sound на звук name. Возвращает базовую высоту (у встроенных своя) или nil — звука нет.
local function setup(s: Sound, name: string): number?
	local spec = SND.sfx[name]
	local region = AudioIds.regions[name]
	local lib = SND.library and SND.library[name]
	if lib and lib > 0 then -- Roblox Creator Store: весь ассет целиком
		s.SoundId = "rbxassetid://" .. tostring(lib)
		s.PlaybackRegionsEnabled = false
		s.Volume = if spec then spec[1] else 0.5
		return 1
	end
	if useAtlas and region then
		s.SoundId = atlasId
		s.PlaybackRegionsEnabled = true
		s.PlaybackRegion = NumberRange.new(region[1], region[1] + region[2])
		if region[3] then
			s.LoopRegion = NumberRange.new(region[1], region[1] + region[2])
		end
		s.Volume = if spec then spec[1] else 0.5
		return 1
	end
	local fb = FALLBACK[name]
	if not fb then
		s.SoundId = ""
		return nil
	end
	s.SoundId = "rbxasset://sounds/" .. fb[1]
	s.PlaybackRegionsEnabled = false
	s.Volume = (if spec then spec[1] else 0.5) * fb[2]
	return fb[3]
end

------------------------------------------------------------------ одиночные звуки: пулы
type Pool = { list: { Sound }, base: number?, next: number }
local pools: { [string]: Pool } = {}

local function pool(name: string): Pool
	local p = pools[name]
	if p then
		return p
	end
	local spec = SND.sfx[name]
	local copies = if spec then spec[3] else 2
	p = { list = {}, base = nil, next = 1 }
	for i = 1, copies do
		local s = Instance.new("Sound")
		s.Name = name
		s.SoundGroup = groups[if spec then spec[2] else "SFX"]
		p.base = setup(s, name)
		s.Parent = SoundService
		p.list[i] = s
	end
	pools[name] = p
	return p
end

local function muted(name: string): boolean
	local spec = SND.sfx[name]
	if spec and spec[2] == "Music" then
		return player:GetAttribute("SetMusic") == false
	end
	return player:GetAttribute("SetSfx") == false
end

-- Сыграть звук; pitch — множитель высоты (серии), vol — множитель громкости
local function play(name: string, pitch: number?, vol: number?)
	name = ALIAS[name] or name
	if muted(name) or (name == "pull" and useAtlas) then
		return
	end
	local p = pool(name)
	if not p.base then
		return
	end
	local s = p.list[p.next]
	p.next = p.next % #p.list + 1
	s.PlaybackSpeed = p.base * (pitch or 1) * (1 + (math.random() * 2 - 1) * SND.jitter)
	s.Volume = specVol(name) * (vol or 1) -- громкость живая: правки из DEV слышны сразу
	s:Play() -- играет с начала куска (PlaybackRegion), даже если эта копия ещё звучала
end

-- 3D: звук из точки part (гудок машины). Отдельный Sound, удаляется после проигрывания.
local function play3D(name: string, part: BasePart)
	if muted(name) then
		return
	end
	local spec = SND.sfx[name]
	local s = Instance.new("Sound")
	s.SoundGroup = groups[if spec then spec[2] else "SFX"]
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 15
	s.RollOffMaxDistance = SND.moverRadius
	local base = setup(s, name)
	if not base then
		s:Destroy()
		return
	end
	s.PlaybackSpeed = base * (1 + (math.random() * 2 - 1) * SND.jitter)
	s.Parent = part
	s:Play()
	task.delay(1.5, function()
		s:Destroy()
	end)
end

------------------------------------------------------------------ ducking музыки
local duckLevel = 1
local duckUntil = 0
local function duck(hold: number)
	duckLevel = math.min(duckLevel, SND.duck)
	duckUntil = math.max(duckUntil, os.clock() + hold)
end
local DUCK_ON: { [string]: number } = { finish = 2, crash = 1, fall = 1.5, record = 1, tierup = 1.5, reveal = 1, chest = 1, task = 0.8 }

------------------------------------------------------------------ события
local SCALE = { 0, 2, 4, 5, 7, 9, 11, 12, 14, 16, 17 } -- мажорная гамма: тон серии монет
local coinStreak, lastCoin = 0, 0
local lastAt: { [string]: number } = {}
-- не чаще: трамплин островка шлёт событие каждый кадр на рампе, финиш приходит из двух мест
local MIN_GAP: { [string]: number } = { spring = 1, finish = 3, claim = 0.3, open = 0.08, click = 0.05, record = 0.5 }

local function onEvent(name: string, arg: any?)
	name = ALIAS[name] or name
	local now = os.clock()
	local gap = MIN_GAP[name]
	if gap and now - (lastAt[name] or -math.huge) < gap then
		return
	end
	lastAt[name] = now
	if name == "coin" then
		coinStreak = if now - lastCoin < SND.coinWindow then math.min(coinStreak + 1, SND.coinStreakMax) else 0
		lastCoin = now
		play("coin", 2 ^ (SCALE[coinStreak + 1] / 12))
		return
	elseif name == "flip" then
		-- комбо: каждый следующий трюк — на кварту выше (до +10 полутонов)
		local n = if typeof(arg) == "number" then arg else 1
		play("flip", 2 ^ (math.min(n - 1, 2) * 5 / 12))
		return
	elseif name == "crystal" then
		play("gem", 1.2, 0.6) -- звон поверх хруста
	elseif name == "perfect" then
		-- идеальный запуск (#58): своего звука в атласе нет — мощный вуш ускорителя + звон на терцию выше
		play("boost")
		play("ring", 2 ^ (4 / 12))
		return
	end
	play(name)
	local hold = DUCK_ON[name]
	if hold then
		duck(hold)
	end
end
controller:WaitForChild("Sfx").Event:Connect(onEvent)

-- UI-хуки (UIKit.pop → "open", UIFx.shakeNo → "deny", openChest → "chest", flyCurrency → "claim")
UI.sfx = function(name: string)
	onEvent(name)
end
-- Клик любой кнопки интерфейса
local function hookButton(d: Instance)
	if d:IsA("GuiButton") then
		d.Activated:Connect(function()
			if player:GetAttribute("InRun") ~= true then -- в заезде кнопки (прыжок, ракета) звучат своими эффектами
				onEvent("click")
			end
		end)
	end
end
local playerGui = player:WaitForChild("PlayerGui")
for _, d in playerGui:GetDescendants() do
	hookButton(d)
end
playerGui.DescendantAdded:Connect(hookButton)

Remotes.RunEnded.OnClientEvent:Connect(function(r)
	if typeof(r) == "table" and r.reason == "fell" then
		onEvent("fall")
	end
end)

------------------------------------------------------------------ машины и поезда: 3D-моторы, гудок
local function moverPart(m: Instance): BasePart?
	if m:IsA("BasePart") then
		return m
	end
	if m:IsA("Model") then
		return m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end
local engines: { [Instance]: Sound } = {}
local lastHorn = 0
task.spawn(function()
	while true do
		task.wait(0.4)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local near = {}
		if root then
			for _, m in CollectionService:GetTagged("Mover") do
				local part = moverPart(m)
				if part and (m.Name == "Vehicle" or m.Name == "Train") then
					local d = (part.Position - root.Position).Magnitude
					if d < SND.moverRadius then
						table.insert(near, { m = m, part = part, d = d })
					end
				end
			end
			table.sort(near, function(a, b)
				return a.d < b.d
			end)
		end
		local keep: { [Instance]: boolean } = {}
		for i = 1, math.min(#near, SND.moverMax) do
			local e = near[i]
			keep[e.m] = true
			if not engines[e.m] then
				local name = if e.m.Name == "Train" then "train" else "car"
				local s = Instance.new("Sound")
				s.Name = "Engine"
				s.Looped = true
				s.SoundGroup = groups.Ambience
				s.RollOffMode = Enum.RollOffMode.InverseTapered
				s.RollOffMinDistance = if name == "train" then 25 else 12
				s.RollOffMaxDistance = SND.moverRadius
				local base = setup(s, name)
				if base then
					s.PlaybackSpeed = base * (0.9 + math.random() * 0.2) -- машины звучат по-разному
					s.Parent = e.part
					s:Play()
					engines[e.m] = s
				else
					s:Destroy()
				end
			end
		end
		for m, s in engines do
			if not keep[m] or not s.Parent then
				s:Destroy()
				engines[m] = nil
			end
		end
		-- гудок: проносишься рядом с машиной в заезде — «би-бип» из самой машины
		local first = near[1]
		if first and first.d < 28 and player:GetAttribute("Launched") == true and os.clock() - lastHorn > 4 and first.m.Name == "Vehicle" then
			lastHorn = os.clock()
			play3D("horn", first.part)
			task.delay(0.18, function()
				if first.part.Parent then
					play3D("horn", first.part)
				end
			end)
		end
	end
end)

------------------------------------------------------------------ лупы: ветер, поверхность, ракета, рогатка
local LOOPS = { "wind", "snow", "ice", "hard", "rocket", "stretch" }
local loops: { [string]: { s: Sound, base: number?, vol: number } } = {}
local function buildLoops()
	for _, name in LOOPS do
		local old = loops[name]
		local s = if old then old.s else Instance.new("Sound")
		s.Name = "Loop_" .. name
		s.Looped = true
		s.SoundGroup = groups[SND.sfx[name][2]]
		local base = setup(s, name)
		s.Volume = 0
		s.Parent = SoundService
		loops[name] = { s = s, base = base, vol = 0 }
		if base then
			s:Play()
		else
			s:Stop()
		end
	end
end
buildLoops()

-- Материал под санями → луп поверхности
local SURFACE: { [Enum.Material]: string } = {
	[Enum.Material.Ice] = "ice",
	[Enum.Material.Glacier] = "ice",
	[Enum.Material.Asphalt] = "hard",
	[Enum.Material.Basalt] = "hard",
	[Enum.Material.Concrete] = "hard",
	[Enum.Material.Rock] = "hard",
	[Enum.Material.Slate] = "hard",
	[Enum.Material.Pavement] = "hard",
	[Enum.Material.Cobblestone] = "hard",
	[Enum.Material.Granite] = "hard",
	[Enum.Material.Wood] = "hard",
	[Enum.Material.WoodPlanks] = "hard",
	[Enum.Material.Metal] = "hard",
	[Enum.Material.DiamondPlate] = "hard",
}
local surface, surfacePitch = "snow", 1
-- проверка из DEV: луп звучит как на скорости f (доля loopFullSpeed), даже в лобби
local devLoop: { name: string, f: number }? = nil
local surfaceScan = 0
local wasRocket = false

RunService.RenderStepped:Connect(function(dt)
	local riding = player:GetAttribute("Launched") == true and not st.crashed
	local speed = state.Speed.Value
	local f = math.clamp(speed / SND.loopFullSpeed, 0, 1)
	local sled = st.sled :: BasePart?
	local grounded = riding and sled ~= nil and not st.airborne

	surfaceScan += dt
	if grounded and sled and surfaceScan > 0.12 then
		surfaceScan = 0
		local hit = workspace:Raycast(sled.Position, Vector3.new(0, -6, 0), st.rayParams)
		if hit then
			surface = SURFACE[hit.Material] or "snow"
			-- песок пустыни — тот же «шшш», только глуше
			surfacePitch = if hit.Material == Enum.Material.Sand or hit.Material == Enum.Material.Sandstone then 0.75 else 1
		end
	end
	-- руль: в повороте полоз режет снег — громче
	local carve = math.clamp(math.abs(st.lateral or 0) / 40, 0, 1)

	local target: { [string]: number } = {
		wind = if riding then (f ^ 1.5) * (if st.airborne then 1.25 else 1) else 0,
		rocket = if state.RocketOn.Value and riding then 1 else 0,
		stretch = if state.AwaitingLaunch.Value and st.pulling then math.max(0.15, state.Meter.Value) else 0,
	}
	for _, k in { "snow", "ice", "hard" } do
		target[k] = if grounded and surface == k and speed > 3 then (0.25 + 0.75 * f) * (1 + 0.5 * carve) else 0
	end
	local loopF = f -- скорость, от которой зависят тон/громкость лупа
	if devLoop then
		local name, df = devLoop.name, devLoop.f
		loopF = df
		target[name] = if name == "wind" then df ^ 1.5
			elseif name == "rocket" then 1
			elseif name == "stretch" then math.max(0.15, df)
			elseif name == "snow" or name == "ice" or name == "hard" then 0.25 + 0.75 * df
			else 1
	end
	for name, l in loops do
		if not l.base then
			continue
		end
		local full = specVol(name)
		local rate = if name == "rocket" or name == "stretch" then 12 else 5
		l.vol += ((target[name] or 0) * full - l.vol) * math.min(1, dt * rate)
		l.s.Volume = l.vol
		if name == "wind" then
			l.s.PlaybackSpeed = l.base * (0.8 + 0.5 * loopF)
		elseif name == "stretch" then
			l.s.PlaybackSpeed = l.base * (0.7 + 0.8 * (if devLoop then loopF else state.Meter.Value))
		elseif name == "rocket" then
			l.s.PlaybackSpeed = l.base * (0.9 + 0.2 * loopF)
		else
			l.s.PlaybackSpeed = l.base * (if devLoop then 1 else surfacePitch) * (0.85 + 0.35 * loopF)
		end
	end

	-- ракета: поджиг и «пых-пых» на выключении
	local rocket = state.RocketOn.Value and riding
	if rocket ~= wasRocket then
		onEvent(if rocket then "rocket_on" else "rocket_off")
		wasRocket = rocket
	end
end)

-- Вращение трюка: «вуш» на старте и на каждом полном обороте
local spinTurns, spinTrick = 0, nil
RunService.Heartbeat:Connect(function()
	local t = st.trick
	if t ~= spinTrick then
		spinTrick = t
		spinTurns = 0
		if t then
			play("spin")
		end
	elseif t and typeof(t.angle) == "number" then
		local turns = math.floor(math.abs(t.angle) / (2 * math.pi))
		if turns > spinTurns then
			spinTurns = turns
			play("spin", 1.1)
		end
	end
end)

------------------------------------------------------------------ фоновая музыка
-- Треки из Config.MUSIC_IDS (что загрузилось): лобби — первый, заезд — другой по миру (RunTheme).
-- Переход — кроссфейд Config.MUSIC_FADE. Ни один не загрузился — тихая «музыкальная шкатулка».
type Track = { s: Sound, vol: number }
local tracks: { Track } = {}
local current: Track? = nil

local devMusic: number? = nil -- проверка из DEV: 0 — трек лобби, N — трек мира N
local function musicTarget(): Track?
	if #tracks == 0 then
		return nil
	end
	if devMusic then
		if devMusic == 0 or #tracks == 1 then
			return tracks[1]
		end
		return tracks[2 + (devMusic - 1) % (#tracks - 1)]
	end
	if player:GetAttribute("InRun") == true and #tracks > 1 then
		local theme = player:GetAttribute("RunTheme") or 1
		return tracks[2 + (theme - 1) % (#tracks - 1)]
	end
	return tracks[1]
end

local function musicBox()
	-- пентатоника до-мажор, спокойные арпеджио: 4 такта по 8 нот
	local notes = {
		0, 4, 7, 12, 7, 4, 0, 4,
		-3, 0, 4, 9, 4, 0, -3, 0,
		-7, -3, 0, 5, 0, -3, -7, -3,
		-5, -1, 2, 7, 2, -1, -5, 2,
	}
	local box = {}
	for i = 1, 4 do
		local s = Instance.new("Sound")
		s.SoundId = "rbxasset://sounds/electronicpingshort.wav"
		s.SoundGroup = groups.Music
		s.Parent = SoundService
		box[i] = s
	end
	local k = 0
	while #tracks == 0 do
		for _, n in notes do
			k = k % #box + 1
			local s = box[k]
			s.PlaybackSpeed = 0.5 * 2 ^ (n / 12)
			s.Volume = Config.MUSIC_VOLUME * 0.45 * (if player:GetAttribute("InRun") == true then Config.MUSIC_RUN_MULT else 1)
			s:Play()
			task.wait(0.42)
		end
	end
	for _, s in box do
		s:Destroy()
	end
end

task.spawn(function()
	for _, id in Config.MUSIC_IDS do
		local s = Instance.new("Sound")
		s.Name = "Music"
		s.Looped = true
		s.Volume = 0
		s.SoundGroup = groups.Music
		s.SoundId = "rbxassetid://" .. tostring(id)
		s.Parent = SoundService
		local t0 = os.clock()
		while not s.IsLoaded and os.clock() - t0 < 8 do
			task.wait(0.25)
		end
		if s.IsLoaded and s.TimeLength > 5 then
			table.insert(tracks, { s = s, vol = 0 })
		else
			s:Destroy()
		end
	end
end)
task.delay(26, function() -- все ID проверены (3 × 8 с) и ни один не загрузился
	if #tracks == 0 then
		musicBox()
	end
end)

------------------------------------------------------------------ кадр микса
RunService.Heartbeat:Connect(function(dt)
	-- каналы: выключатели ⚙ и ducking
	local now = os.clock()
	if now > duckUntil and duckLevel < 1 then
		duckLevel = math.min(1, duckLevel + dt * (1 - SND.duck) / SND.duckRelease)
	end
	local sfxOn = if player:GetAttribute("SetSfx") == false then 0 else 1
	local musicOn = if player:GetAttribute("SetMusic") == false then 0 else 1
	for name, g in groups do
		local want = SND.groups[name] * (if name == "Music" then musicOn * duckLevel else sfxOn)
		g.Volume += (want - g.Volume) * math.min(1, dt * 8)
	end
	-- музыка: кроссфейд к нужному треку
	local want = musicTarget()
	if want ~= current then
		current = want
	end
	local vol = Config.MUSIC_VOLUME * (if player:GetAttribute("InRun") == true then Config.MUSIC_RUN_MULT else 1)
	local step = dt / math.max(0.05, Config.MUSIC_FADE)
	for _, tr in tracks do
		local target = if tr == current then vol else 0
		tr.vol = if tr.vol < target then math.min(target, tr.vol + step * vol) else math.max(target, tr.vol - step * math.max(vol, 0.05))
		tr.s.Volume = tr.vol
		if tr.vol > 0 and not tr.s.IsPlaying then
			tr.s:Resume()
		elseif tr.vol <= 0 and tr.s.IsPlaying then
			tr.s:Pause() -- вернёмся с того же места
		end
	end
end)

------------------------------------------------------------------ атлас: загрузка и переключение
-- Встроенные звуки играют сразу; когда атлас загрузился — все пулы и лупы пересобираются на него.
if (AudioIds.atlas or 0) > 0 then
	task.spawn(function()
		local probe = Instance.new("Sound")
		probe.SoundId = atlasId
		probe.Parent = SoundService
		pcall(function()
			ContentProvider:PreloadAsync({ probe })
		end)
		local t0 = os.clock()
		while not probe.IsLoaded and os.clock() - t0 < 15 do
			task.wait(0.25)
		end
		local ok = probe.IsLoaded and probe.TimeLength > 1
		probe:Destroy()
		if not ok then
			warn("[Sounds] атлас звуков не загрузился (модерация?) — играют встроенные звуки")
			return
		end
		useAtlas = true
		SoundService:SetAttribute("SoundSource", "atlas")
		for name, p in pools do
			for _, s in p.list do
				s:Destroy()
			end
			pools[name] = nil
		end
		buildLoops()
		for m, s in engines do
			s:Destroy()
			engines[m] = nil
		end
	end)
end

------------------------------------------------------------------ проверка из панели DEV (только владелец)
-- Тот же код, что в игре: одиночные — через onEvent (серии, ducking, громкость из Config), лупы — через
-- кадр микса выше (devLoop), моторы машин/поезда — 2D-копия лупа, музыка — выбор трека (devMusic).
if player.UserId == game.CreatorId then
	local test = Instance.new("BindableEvent")
	test.Name = "SoundTest"
	test.Parent = script
	local engineTest: Sound? = nil
	test.Event:Connect(function(cmd: string, name: any?, on: any?, f: any?)
		if cmd == "sfx" and typeof(name) == "string" then
			onEvent(name)
		elseif cmd == "loop" and typeof(name) == "string" then
			local df = if typeof(f) == "number" then math.clamp(f, 0, 1) else 1
			if name == "car" or name == "train" then
				if engineTest then
					engineTest:Destroy()
					engineTest = nil
				end
				if on then
					local s = Instance.new("Sound")
					s.Name = "EngineTest"
					s.Looped = true
					s.SoundGroup = groups.Ambience
					local base = setup(s, name)
					if base then
						s.PlaybackSpeed = base
						s.Parent = SoundService
						s:Play()
						engineTest = s
					else
						s:Destroy()
					end
				end
			elseif on then
				devLoop = { name = name, f = df }
			elseif devLoop and devLoop.name == name then
				devLoop = nil
			end
		elseif cmd == "music" then
			devMusic = if typeof(name) == "number" then name else nil
		end
	end)
end
