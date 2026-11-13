-- Трасса в Studio без запуска игры (владелец 2026-11-13): построить уровень целиком (или отрезок) в
-- Workspace режима редактирования и рассмотреть камерой. Строит тот же код, что и в игре (Track.new,
-- тот же seed = номер уровня), — это точная копия трассы заезда, только без игрока и без стриминга.
--
-- Командная строка Studio (View → Command Bar), вставить строку и нажать Enter:
--   require(game.ReplicatedStorage.Shared.StudioTrack).build(2)            -- уровень 2 целиком
--   require(game.ReplicatedStorage.Shared.StudioTrack).build(7, 800, 2000) -- уровень 7, метры 800–2000
--   require(game.ReplicatedStorage.Shared.StudioTrack).clear()             -- убрать трассу
-- Уровень — сквозной номер: мир 1 = уровни 1–5, мир 2 = 6–10 … (Config.LEVELS_PER_WORLD).
--
-- Это ПРОСМОТР: правки деталей в игру не попадают (игра строит трассу заново при каждом заезде).
-- Живые настройки DEV → Настройка здесь не действуют — значения по умолчанию из Config.
-- Столбики «N м» каждые MARK_EVERY метров — чтобы называть места в задачах («на 600 м подъём»).
-- Перед публикацией места из Studio — clear() (иначе трасса и шаблоны мешей сохранятся в месте).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Meshes = require(ReplicatedStorage.Shared.Meshes)
local Track = require(ReplicatedStorage.Shared.Track)

local StudioTrack = {}
StudioTrack.FOLDER = "StudioTrack"
StudioTrack.MARK_EVERY = 100 -- метки дистанции, метры (= studs по горизонтали, как в HUD)

local current: any = nil

-- Метка дистанции над центром трассы
local function mark(text: string, at: CFrame, parent: Instance)
	local p = Instance.new("Part")
	p.Name = "Mark_" .. text
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.CFrame = at
	local g = Instance.new("BillboardGui")
	g.Size = UDim2.fromOffset(120, 40)
	g.AlwaysOnTop = true
	g.MaxDistance = 1500
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
	t.BackgroundTransparency = 0.3
	t.TextColor3 = Color3.fromRGB(255, 220, 90)
	t.TextScaled = true
	t.Font = Enum.Font.GothamBold
	t.Text = text
	t.Parent = g
	g.Parent = p
	p.Parent = parent
end

-- Точка на оси трассы на горизонтальной дистанции h (центр дна)
local function pointAt(segs: { any }, h: number): CFrame?
	for _, s in segs do
		if h >= s.hStart and h < s.hStart + s.hLen and s.hLen > 0 then
			return s.cf * CFrame.new(0, 0, -(h - s.hStart) / s.hLen * s.length)
		end
	end
	return nil
end

-- Что на уровне: сколько тоннелей, долин, развилок, дорог и т. п. (для отчёта в Output)
local function summary(segs: { any }): string
	local n: { [string]: number } = {}
	local function add(k: string)
		n[k] = (n[k] or 0) + 1
	end
	local prev: any = nil
	for _, s in segs do
		if s.tunnel == "in" then
			add("тоннель")
		end
		if s.kind == "road" then
			add("дорога")
		elseif s.kind == "rail" then
			add("переезд")
		elseif s.kind == "climb" then
			add("подъём")
		elseif s.kind == "steep" then
			add("крутой спуск")
		end
		-- развилка и долина — по участкам (начало серии кусков), а не по кускам
		if s.fork and not (prev and prev.fork) then
			add("развилка")
		end
		if s.valley and not (prev and prev.valley) then
			add("долина")
		end
		prev = s
	end
	local parts = {}
	for k, v in n do
		table.insert(parts, k .. " ×" .. v)
	end
	table.sort(parts)
	return table.concat(parts, ", ")
end

function StudioTrack.clear()
	if current then
		current:destroy()
		current = nil
	end
	local old = workspace:FindFirstChild(StudioTrack.FOLDER)
	if old then
		old:Destroy()
	end
	local tpl = ReplicatedStorage:FindFirstChild(Meshes.FOLDER)
	if tpl then
		tpl:Destroy()
	end
end

-- level — сквозной номер уровня; fromM/toM — отрезок в метрах (по умолчанию весь уровень)
function StudioTrack.build(level: number, fromM: number?, toM: number?)
	StudioTrack.clear()
	level = math.max(1, math.floor(level))
	print(string.format("[StudioTrack] уровень %d: загружаю меши…", level))
	Meshes.load(true, 40)
	local origin = CFrame.new(Config.TRACKS_ORIGIN)
	local t = Track.new(0, level, 0, origin)
	t.folder.Name = StudioTrack.FOLDER
	current = t
	local lo, hi = fromM or 0, toM or math.huge
	-- построить все куски отрезка (как Track:ensureAround, но на весь отрезок сразу), лишние — убрать
	local errors = 0
	for i, seg in t.segments do
		local idx = i - 1
		local wanted = seg.hStart + seg.hLen >= lo and seg.hStart <= hi
		if wanted and not t.built[idx] then
			local ok, err = pcall(t.buildSegment, t, idx)
			if not ok then
				errors += 1
				warn("[StudioTrack] кусок " .. idx .. " (" .. seg.kind .. "): " .. tostring(err))
			end
		elseif not wanted and t.built[idx] then
			t.built[idx]:Destroy()
			t.built[idx] = nil
		end
	end
	local marks = Instance.new("Folder")
	marks.Name = "Marks"
	marks.Parent = t.folder
	local every = StudioTrack.MARK_EVERY
	local m = math.ceil(lo / every) * every
	while m <= math.min(hi, t.length) do
		local at = pointAt(t.segments, m)
		if at then
			mark(m .. " м", at * CFrame.new(0, 18, 0), marks)
		end
		m += every
	end
	-- камера: над стартом отрезка, смотрит вниз по трассе
	local first = pointAt(t.segments, lo) or origin
	local cam = workspace.CurrentCamera
	if cam then
		local eye = first * CFrame.new(0, 60, 90)
		cam.CFrame = CFrame.lookAt(eye.Position, (first * CFrame.new(0, 0, -150)).Position)
	end
	local count = 0
	for _, d in t.folder:GetDescendants() do
		if d:IsA("BasePart") then
			count += 1
		end
	end
	print(string.format(
		"[StudioTrack] готово: уровень %d (%s), длина %d м, кусков %d, деталей %d%s. Есть: %s. Убрать: …StudioTrack).clear()",
		level,
		Config.worldName(Config.worldOf(level)),
		math.floor(t.length),
		#t.segments,
		count,
		if errors > 0 then ", ошибок " .. errors else "",
		summary(t.segments)
	))
	return t.folder
end

return StudioTrack
