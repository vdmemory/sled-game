-- Призрак своего рекорда (#62): запись траектории заезда, полупрозрачные сани-призрак лучшего
-- заезда уровня и HUD «+12 м / −8 м к рекорду». Хранение и проверка записи — server/Ghosts,
-- сжатие — shared/GhostCodec.
--
-- Запись: с выстрела рогатки (сани откреплены) раз в Config.GHOST_SAMPLE_DT — позиция саней от
-- начала трассы (атрибут RunOrigin) + направление движения по горизонтали. Конец заезда (InRun =
-- false) — запись закрывается и ждёт: сервер решает, рекорд ли это, и просит её ремоутом Ghost.
-- Воспроизведение: на старте заезда GetGhost(level) → запись → сани-призрак (только у клиента:
-- без коллизий, CanQuery/CanTouch = false) с подписью «Твой рекорд», позиция — интерполяция
-- соседних сэмплов, наклон — по разности позиций (вверх/вниз по склону и в полёте).
-- «К рекорду» — путь своих саней минус путь призрака в тот же момент от выстрела; оба считаются
-- одинаково (Track.progressOf по профилю уровня, как RunDistance на сервере), но локально — без
-- задержки атрибута RunDistance. Переключатель — настройка «Призрак» (атрибут SetGhost).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local UI = require(Shared:WaitForChild("UIKit"))
local GhostCodec = require(Shared:WaitForChild("GhostCodec"))
local SledModels = require(Shared:WaitForChild("SledModels"))
local Track = require(Shared:WaitForChild("Track"))
local Profile = require(Shared.Track:WaitForChild("Profile"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GetGhost = Remotes:WaitForChild("GetGhost") :: RemoteFunction
local GhostRemote = Remotes:WaitForChild("Ghost") :: RemoteEvent

local player = Players.LocalPlayer
local L = UI.L
local progressOf = (Track :: any).progressOf -- метод читает только segments и hint: хватает простой таблицы
local sledsFolder = workspace:WaitForChild("Sleds")

local GHOST_TINT = Color3.fromRGB(170, 220, 255)
local AHEAD = Color3.fromRGB(120, 240, 140)
local BEHIND = Color3.fromRGB(255, 140, 120)
local PITCH_MAX = math.rad(45)

local function enabled(): boolean
	return player:GetAttribute("SetGhost") ~= false
end

------------------------------------------------------------------ HUD «к рекорду»
local gui = Instance.new("ScreenGui")
gui.Name = "Ghost"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")
local root = UI.new("Frame", { Name = "Root", BackgroundTransparency = 1, Parent = gui })
local rootScale = UI.fitScale(root, gui) -- тот же масштаб, что у корня HUD
local label = UI.text(UI.at(L.ghost, { Text = "", TextColor3 = AHEAD, Visible = false, Parent = root }))
UI.outline(label, 2) -- цветной текст UI.text не обводит сам
local function placeLabel()
	UI.at(if UI.isPhone() then L.ghostPhone else L.ghost, label :: any)
	label.TextXAlignment = if UI.isPhone() then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left
end
placeLabel()
rootScale:GetPropertyChangedSignal("Scale"):Connect(placeLabel)

------------------------------------------------------------------ состояние
type Rec = { level: number, origin: Vector3, dt: number, ints: { number }, t0: number?, nextT: number }
type Ghost = { xs: { number }, ys: { number }, zs: { number }, yaws: { number }, hs: { number }, n: number, dt: number }

local token = 0 -- номер заезда: ответ GetGhost от прошлого заезда отбрасываем
local rec: Rec? = nil -- запись текущего заезда
local finished: { level: number, dt: number, data: string, at: number }? = nil -- закрытая запись, ждёт запроса сервера
local ghost: Ghost? = nil
local model: Model? = nil
local ghostRoot: BasePart? = nil
local mySegs: { segments: { any }, hint: number }? = nil
local length = 1
local hudAcc = 0
local mySled: BasePart? = nil

local function findSled(): BasePart?
	if mySled and mySled.Parent == sledsFolder then
		return mySled
	end
	mySled = nil
	for _, s in sledsFolder:GetChildren() do
		if s:IsA("BasePart") and s:GetAttribute("Owner") == player.UserId then
			mySled = s
			break
		end
	end
	return mySled
end

local function destroyModel()
	if model then
		model:Destroy()
	end
	model, ghostRoot = nil, nil
end

-- Сани-призрак: модель надетых саней, всё приварено к закреплённому корню (двигаем только его)
local function buildModel()
	destroyModel()
	local m = Instance.new("Model")
	m.Name = "RecordGhost"
	local base = Instance.new("Part")
	base.Name = "GhostRoot"
	base.Size = Vector3.new(1, 1, 1)
	base.Transparency = 1
	base.Anchored = true
	base.CanCollide = false
	base.CanQuery = false
	base.CanTouch = false
	base.CastShadow = false
	base.CFrame = CFrame.new(0, -10000, 0)
	base.Parent = m
	m.PrimaryPart = base
	local id = player:GetAttribute("Sled")
	local ok, err = pcall(SledModels.build, m, base.CFrame, if typeof(id) == "string" then id else "tube", { main = GHOST_TINT, accent = Color3.new(1, 1, 1) }, base, true)
	if not ok then
		warn("[Ghost] модель призрака: " .. tostring(err))
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			if d ~= base then
				d.Anchored = false
				d.Massless = true
				d.Transparency = math.max(d.Transparency, Config.GHOST_TRANSPARENCY)
				d.Color = d.Color:Lerp(GHOST_TINT, 0.6)
			end
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
		elseif d:IsA("Decal") or d:IsA("Texture") then
			d.Transparency = math.max(d.Transparency, Config.GHOST_TRANSPARENCY)
		elseif d:IsA("Light") or d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") or d:IsA("Sound") then
			d:Destroy()
		end
	end
	local tag = Instance.new("BillboardGui")
	tag.Name = "Tag"
	tag.Size = UDim2.fromOffset(150, 28)
	tag.StudsOffset = Vector3.new(0, 4.5, 0)
	tag.MaxDistance = Config.GHOST_TAG_DIST
	tag.LightInfluence = 0
	tag.Adornee = base
	local text = UI.text({ Text = "Твой рекорд", Size = UDim2.fromScale(1, 1), TextColor3 = GHOST_TINT, Parent = tag })
	UI.outline(text, 2)
	tag.Parent = base
	m.Parent = workspace
	model, ghostRoot = m, base
end

local function clearGhost()
	destroyModel()
	ghost = nil
	mySegs = nil
	label.Visible = false
end

------------------------------------------------------------------ запись
local function closeRecording()
	local r = rec
	rec = nil
	if not r or not r.t0 or #r.ints < 8 then
		return
	end
	finished = { level = r.level, dt = r.dt, data = GhostCodec.encode(r.ints), at = os.clock() }
	table.clear(r.ints)
end

local function sample(r: Rec, s: BasePart)
	local v = s.AssemblyLinearVelocity
	local flat = Vector3.new(v.X, 0, v.Z)
	local dir = if flat.Magnitude > 3 then flat.Unit else s.CFrame.LookVector
	local yaw = math.atan2(-dir.X, -dir.Z) -- CFrame.Angles(0, yaw, 0).LookVector = dir
	local x, y, z, q = GhostCodec.quantize(s.Position - r.origin, yaw, Config.GHOST_POS_Q)
	local ints = r.ints
	table.insert(ints, x)
	table.insert(ints, y)
	table.insert(ints, z)
	table.insert(ints, q)
end

-- Сервер: «это рекорд — пришли запись»
GhostRemote.OnClientEvent:Connect(function(level: any)
	if rec and rec.level == level then
		closeRecording() -- событие пришло раньше атрибута InRun = false
	end
	local f = finished
	if f and f.level == level and os.clock() - f.at < Config.GHOST_UPLOAD_WINDOW then
		finished = nil
		GhostRemote:FireServer(level, f.dt, f.data)
	end
end)

------------------------------------------------------------------ старт / конец заезда
local function loadGhost(my: number, level: number, origin: Vector3)
	local res = UI.invoke(GetGhost, level)
	if my ~= token or type(res) ~= "table" or type(res.data) ~= "string" or type(res.dt) ~= "number" then
		return
	end
	local xs, ys, zs, yaws = GhostCodec.decode(res.data, Config.GHOST_POS_Q, Config.GHOST_MAX_SAMPLES)
	if not xs or not ys or not zs or not yaws or #xs < 2 or my ~= token then
		return
	end
	-- путь призрака по трассе в каждом сэмпле (для «к рекорду»), тем же способом, что свой
	local segs = mySegs
	if not segs then
		return
	end
	local fake = { segments = segs.segments, hint = 1 }
	local hs = table.create(#xs)
	for i = 1, #xs do
		local h = progressOf(fake, origin + Vector3.new(xs[i], ys[i], zs[i]))
		hs[i] = math.min(math.max(h, if i > 1 then hs[i - 1] else 0), length) -- не убывает: кувырок назад не «отнимает» рекорд
	end
	ghost = { xs = xs, ys = ys, zs = zs, yaws = yaws, hs = hs, n = #xs, dt = res.dt }
	if enabled() then
		buildModel()
	end
end

local function onRunStart()
	token += 1
	local my = token
	clearGhost()
	rec = nil
	finished = nil -- новый заезд: невостребованная запись прошлого не нужна
	-- атрибуты заезда ставятся до InRun; на всякий случай ждём их кадр
	local origin, level = player:GetAttribute("RunOrigin"), player:GetAttribute("RunLevel")
	if typeof(origin) ~= "Vector3" or typeof(level) ~= "number" then
		task.wait()
		origin, level = player:GetAttribute("RunOrigin"), player:GetAttribute("RunLevel")
	end
	if typeof(origin) ~= "Vector3" or typeof(level) ~= "number" or my ~= token then
		return
	end
	length = player:GetAttribute("LevelLength") or Config.levelLength(level)
	rec = { level = level, origin = origin, dt = Config.GHOST_SAMPLE_DT, ints = {}, t0 = nil, nextT = 0 }
	local ok, segs = pcall(function()
		return (Profile.build(CFrame.new(origin), level))
	end)
	if ok and type(segs) == "table" and #segs > 0 then
		mySegs = { segments = segs, hint = 1 }
		task.spawn(loadGhost, my, level, origin)
	end
end

local function onRunEnd()
	token += 1
	closeRecording()
	clearGhost()
end

player:GetAttributeChangedSignal("InRun"):Connect(function()
	if player:GetAttribute("InRun") then
		onRunStart()
	else
		onRunEnd()
	end
end)
if player:GetAttribute("InRun") then
	task.spawn(onRunStart)
end

player:GetAttributeChangedSignal("SetGhost"):Connect(function()
	if not enabled() then
		destroyModel()
		label.Visible = false
	elseif ghost and not model then
		buildModel()
	end
end)

------------------------------------------------------------------ кадр
-- Путь призрака и CFrame в момент t от выстрела (после конца записи — последний сэмпл)
local function ghostAt(g: Ghost, t: number): (number, CFrame)
	local f = math.clamp(t / g.dt, 0, g.n - 1)
	local i = math.floor(f) + 1
	local j = math.min(i + 1, g.n)
	local a = f - (i - 1)
	local p0 = Vector3.new(g.xs[i], g.ys[i], g.zs[i])
	local p1 = Vector3.new(g.xs[j], g.ys[j], g.zs[j])
	local pos = p0:Lerp(p1, a)
	local dy = g.yaws[j] - g.yaws[i]
	dy = (dy + math.pi) % (2 * math.pi) - math.pi -- кратчайший поворот
	local yaw = g.yaws[i] + dy * a
	-- наклон по разности позиций: вниз по склону, дуга полёта
	local i0, i1 = math.max(1, i - 1), math.min(g.n, i + 1)
	local d = Vector3.new(g.xs[i1] - g.xs[i0], g.ys[i1] - g.ys[i0], g.zs[i1] - g.zs[i0])
	local horiz = Vector3.new(d.X, 0, d.Z).Magnitude
	local pitch = if horiz > 0.5 then math.clamp(math.atan2(d.Y, horiz), -PITCH_MAX, PITCH_MAX) else 0
	local h = g.hs[i] + (g.hs[j] - g.hs[i]) * a
	return h, CFrame.new(pos) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
end

RunService.Heartbeat:Connect(function(dt)
	local r = rec
	if not r then
		return
	end
	local s = findSled()
	if not s then
		return
	end
	local now = os.clock()
	if not r.t0 then
		if s.Anchored then
			return -- ещё у рогатки
		end
		r.t0 = now
		r.nextT = 0
	end
	local t = now - (r.t0 :: number)
	-- запись: по сэмплу на каждый пройденный шаг dt (на подвисании кадра — одинаковые сэмплы)
	while t >= r.nextT and #r.ints < Config.GHOST_MAX_SAMPLES * GhostCodec.FIELDS do
		sample(r, s)
		r.nextT += r.dt
	end

	local g = ghost
	if not g then
		return
	end
	local h, cf = ghostAt(g, t)
	local gr = ghostRoot
	if gr then
		gr.CFrame = CFrame.new(r.origin) * cf
	end
	hudAcc += dt
	if hudAcc < Config.GHOST_HUD_EVERY then
		return
	end
	hudAcc = 0
	local segs = mySegs
	if not segs or not enabled() then
		label.Visible = false
		return
	end
	local mine = math.min(progressOf(segs, s.Position), length)
	local diff = math.floor(mine - h + 0.5)
	label.Text = if diff >= 0 then string.format("+%d м к рекорду", diff) else string.format("−%d м к рекорду", -diff)
	label.TextColor3 = if diff >= 0 then AHEAD else BEHIND
	label.Visible = true
end)
