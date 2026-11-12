-- Развилка у островков (#42): ледяной мост сбоку от цепочки островков — «спокойно по мосту / рискованно
-- по островкам». Часть модуля shared/Track (см. Track/init, docs/GAME_DESIGN.md → «Ледяной мост»).
--
-- Схема (сверху, FORK_SIDE = −1 — мост слева):
--   разгон isleIn (шире: пол до края моста) ── разделитель ──┬── ледяной мост (борта, ускорители) ──┐
--                                                          └── ускоритель → островки (монеты ×2) ──┴── приземление (воронка)
-- Мост — не отдельная трасса, а настил параллельно оси цепочки (тот же курс), сбоку на FORK_BRIDGE_X.
-- Поэтому Track.progressOf считает путь как обычно: проекция на кусок цепочки даёт тот же h, x —
-- смещение вбок (сервер знает ширину развилки — Track:sideOut). Настил — ломаная по вертикали:
-- уклон разгона → скругление (≤ SMOOTH_KINK на стык) → прямая средняя часть → скругление → уклон
-- склона приземления; конец моста лежит в плоскости склона приземления (стык без ступеньки).
--   Fork.plan(spec, a0, a1)  — профиль настила по плану островков (без Instance; nil — моста нет)
--   Fork.bridge / buildIn / buildLand — геометрия на кусках цепочки, разгоне и склоне приземления
--   Fork.prune               — убрать декор обочины со стороны моста (там пол развилки)

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Props = require(ReplicatedStorage.Shared.Props)
local Islands = require(ReplicatedStorage.Shared.Islands)

local part, deco = Props.part, Props.deco

local Fork = {}

local W = Config.TRACK_WIDTH
local DECK_T = 2 -- толщина настила
local SNOW_FLOOR = Color3.fromRGB(236, 243, 252) -- как пол трассы (Track/Sections)
local SNOW = Color3.fromRGB(250, 252, 255)
local ICE_DECK = Color3.fromRGB(170, 215, 245)
local ICE_RAIL = Color3.fromRGB(200, 232, 252)
local SAFE = Color3.fromRGB(60, 190, 110)
local RISK = Color3.fromRGB(235, 70, 60)

------------------------------------------------------------------ план
-- spec — план островков (Islands.plan); a0 — уклон разгона, a1 — уклон склона приземления.
-- Ответ: { side, x, w, inner, outer, pitch, U, D, pieces = { {u0, y0, u1, y1} } } в системе цепочки
-- (u — вперёд по горизонтали от конца разгона, y — вверх) или nil, если мост с уклоном FORK_PITCH
-- между этими точками не строится (тогда цепочка без развилки).
function Fork.plan(spec, a0: number, a1: number): any?
	local U, D = 0, 0
	for k, g in spec.gaps do
		U += g.gap
		D += g.drop
		local isle = spec.isles[k]
		if isle then
			U += isle.len * math.cos(math.rad(isle.pitch))
			D += isle.len * math.sin(math.rad(isle.pitch))
		end
	end
	local lo, hi = Config.FORK_PITCH[1], Config.FORK_PITCH[2]
	local kink = math.max(0.1, Config.SMOOTH_KINK)
	local L = Config.FILLET_LEN
	-- число переходных кусков не зависит от уклона середины: падение моста D(b) непрерывно и растёт с b
	local K0 = math.ceil(math.max(math.abs(lo - a0), math.abs(hi - a0)) / kink - 1e-6)
	local K1 = math.ceil(math.max(math.abs(a1 - lo), math.abs(a1 - hi)) / kink - 1e-6)
	local function angles(b: number): { number }
		local out = {}
		for j = 1, K0 do
			table.insert(out, a0 + (b - a0) * j / (K0 + 1))
		end
		table.insert(out, b) -- середина (длина — остаток)
		for j = 1, K1 do
			table.insert(out, b + (a1 - b) * j / (K1 + 1))
		end
		return out
	end
	local function drop(b: number): (number?, { number })
		local list = angles(b)
		local hor, dy = 0, 0
		for k, a in list do
			if k ~= K0 + 1 then
				hor += L * math.cos(math.rad(a))
				dy += L * math.sin(math.rad(a))
			end
		end
		local S = U - hor
		if S < 20 then
			return nil, list
		end
		return dy + S * math.tan(math.rad(b)), list
	end
	local dLo = drop(lo)
	local dHi = drop(hi)
	if not dLo or not dHi or D < dLo or D > dHi then
		return nil
	end
	local bLo, bHi = lo, hi
	for _ = 1, 50 do
		local mid = (bLo + bHi) / 2
		local d = drop(mid)
		if d and d < D then
			bLo = mid
		else
			bHi = mid
		end
	end
	local b = (bLo + bHi) / 2
	local _, list = drop(b)
	local hor = 0
	for k, a in list do
		if k ~= K0 + 1 then
			hor += L * math.cos(math.rad(a))
		end
	end
	local pieces = {}
	local u, y = 0, 0
	for k, a in list do
		local du = if k == K0 + 1 then U - hor else L * math.cos(math.rad(a))
		local dy = du * math.tan(math.rad(a))
		table.insert(pieces, { u, y, u + du, y - dy })
		u += du
		y -= dy
	end
	-- конец ломаной точно в начале склона приземления (бисекция оставляет ~1e-10)
	pieces[#pieces][3], pieces[#pieces][4] = U, -D
	local side = if Config.FORK_SIDE < 0 then -1 else 1
	local half = Config.FORK_BRIDGE_W / 2
	return {
		side = side,
		x = side * Config.FORK_BRIDGE_X,
		w = Config.FORK_BRIDGE_W,
		inner = Config.FORK_BRIDGE_X - half, -- |x| края настила со стороны островков
		outer = Config.FORK_BRIDGE_X + half, -- |x| внешнего края
		pitch = b,
		U = U,
		D = D,
		pieces = pieces,
	}
end

-- Высота настила в точке u (система цепочки)
function Fork.yAt(fork, u: number): number
	for _, p in fork.pieces do
		if u <= p[3] then
			local t = math.clamp((u - p[1]) / math.max(1e-6, p[3] - p[1]), 0, 1)
			return p[2] + (p[4] - p[2]) * t
		end
	end
	return -fork.D
end

------------------------------------------------------------------ геометрия
local function invisibleWall(cf: CFrame, size: Vector3, m: Instance)
	part("Part", { Name = "Wall", Size = size, CFrame = cf, Transparency = 1, CanQuery = false, CastShadow = false }, m)
end

-- Снежный сугроб-бортик (декор) по краю пола со стороны моста: наклонный пояс + полка за ним
local function outerBank(cf: CFrame, side: number, x: number, z0: number, len: number, m: Instance)
	local a = math.rad(25)
	deco({ Size = Vector3.new(14, 2, len), CFrame = cf * CFrame.new(side * x, 0, -(z0 + len / 2)) * CFrame.Angles(0, 0, side * a) * CFrame.new(side * 7, -1, 0), Material = Enum.Material.Snow, Color = SNOW }, m)
	deco({ Size = Vector3.new(150, 2, len), CFrame = cf * CFrame.new(side * (x + 14 * math.cos(a) + 75), 14 * math.sin(a) - 1, -(z0 + len / 2)), Material = Enum.Material.Snow, Color = SNOW }, m)
end

-- Пол развилки со стороны моста: от края коридора (W/2) до внешнего края моста, в плоскости куска
local function sideFloor(fork, cf: CFrame, len: number, m: Instance)
	local wd = fork.outer - W / 2
	part("Part", {
		Name = "Floor",
		Size = Vector3.new(wd, 4, len),
		CFrame = cf * CFrame.new(fork.side * (W / 2 + wd / 2), -2, -len / 2),
		Material = Enum.Material.Snow,
		Color = SNOW_FLOOR,
	}, m)
end

-- Вывеска над развилкой: две половины («⟵ безопасно» над мостом, «риск ⟶» над коридором)
local function signBoard(cf: CFrame, width: number, side: number, m: Instance)
	local bar = deco({ Size = Vector3.new(width, 7, 0.8), CFrame = cf, Color = Color3.fromRGB(40, 45, 60), CastShadow = true }, m)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Back -- лицом к игроку (едет по −Z): слева на вывеске — слева от игрока
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 20
	sg.LightInfluence = 0
	sg.Parent = bar
	local safeText = Config.FORK_SIGN_SAFE .. (if side < 0 then " ⟵" else " ⟶")
	local riskText = (if side < 0 then "⟶ " else "⟵ ") .. Config.FORK_SIGN_RISK
	local halves = if side < 0 then { { safeText, SAFE }, { riskText, RISK } } else { { riskText, RISK }, { safeText, SAFE } }
	for k, hv in halves do
		local t = Instance.new("TextLabel")
		t.Position = UDim2.fromScale((k - 1) * 0.5, 0)
		t.Size = UDim2.fromScale(0.5, 1)
		t.BackgroundColor3 = hv[2]
		t.BackgroundTransparency = 0.05
		t.BorderSizePixel = 0
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.Text = hv[1]
		t.TextColor3 = Color3.new(1, 1, 1)
		t.TextStrokeTransparency = 0.3
		t.Parent = sg
	end
	return bar
end

-- Разгон к развилке (isleIn): пол до края моста, внешний борт, разделитель веток от FORK_SPLIT_AT
-- (невидимая стенка + снежный гребень с «носом»-ромбом), вывеска в начале куска
function Fork.buildIn(track, seg, m: Instance)
	local fork = seg.fork
	local cf, len, side = seg.cf, seg.length, fork.side
	local wallH = Config.WALL_HEIGHT
	sideFloor(fork, cf, len, m)
	invisibleWall(cf * CFrame.new(side * (fork.outer + 0.3), -1.5 + (wallH + 2) / 2, -len / 2), Vector3.new(0.6, wallH + 2, len + 2), m)
	outerBank(cf, side, fork.outer, -1, len + 2, m)
	-- разделитель: от борта коридора (W/2 + WALL_OFFSET) до края настила моста
	local x0, x1 = W / 2 + Config.WALL_OFFSET, fork.inner
	local dw, z0 = x1 - x0, math.min(Config.FORK_SPLIT_AT, len - 10)
	local cx = side * (x0 + x1) / 2
	invisibleWall(cf * CFrame.new(cx, 6.5, -(z0 + len) / 2), Vector3.new(dw, 16, len - z0), m)
	local s = dw / math.sqrt(2)
	invisibleWall(cf * CFrame.new(cx, 6.5, -z0) * CFrame.Angles(0, math.rad(45), 0), Vector3.new(s, 16, s), m)
	deco({ Size = Vector3.new(dw, 3, len - z0), CFrame = cf * CFrame.new(cx, 1.5, -(z0 + len) / 2), Material = Enum.Material.Snow, Color = SNOW, CastShadow = true }, m)
	deco({ Shape = Enum.PartType.Ball, Size = Vector3.new(dw, 4, dw), CFrame = cf * CFrame.new(cx, 1.2, -z0), Material = Enum.Material.Snow, Color = SNOW }, m)
	-- на носу разделителя — две стрелки (в обе стороны)
	Props.arrowSign(cf * CFrame.new(cx - 1.6, 2.5, -z0 - 2) * CFrame.Angles(0, math.pi, 0), -1, m)
	Props.arrowSign(cf * CFrame.new(cx + 1.6, 2.5, -z0 - 2) * CFrame.Angles(0, math.pi, 0), 1, m)
	-- вывеска над всей шириной развилки в начале куска (видна издалека: ≥ 2 с при maxSpeed)
	local xa, xb = side * (fork.outer + 2), -side * (W / 2 + 4)
	local span = math.abs(xb - xa)
	local signZ = 10
	for _, x in { xa, xb } do
		deco({ Size = Vector3.new(1.6, 26, 1.6), CFrame = cf * CFrame.new(x, 13, -signZ), Color = Color3.fromRGB(240, 242, 248), CastShadow = true }, m)
		Islands.pennant(cf * CFrame.new(x, 26, -signZ), Islands.accent(track.theme), 6, m)
	end
	signBoard(cf * CFrame.new((xa + xb) / 2, 22, -signZ), span, side, m)
end

-- Склон приземления у развилки: пол до края моста и воронка — внешний борт моста за FORK_MERGE_LEN
-- сводится к борту коридора, дальше — обычный борт (удвоенный, как у приземления)
function Fork.buildLand(_track, seg, m: Instance)
	local fork = seg.fork
	local cf, len, side = seg.cf, seg.length, fork.side
	local wallH = Config.WALL_HEIGHT * 2
	sideFloor(fork, cf, len, m)
	local merge = math.min(Config.FORK_MERGE_LEN, len - 4)
	local xEnd = W / 2 + Config.WALL_OFFSET
	local p0 = Vector3.new(side * (fork.outer + 0.3), 0, 0)
	local p1 = Vector3.new(side * xEnd, 0, -merge)
	local line = CFrame.lookAt((p0 + p1) / 2, p1)
	local llen = (p1 - p0).Magnitude
	invisibleWall(cf * line * CFrame.new(0, -1.5 + (wallH + 2) / 2, 0), Vector3.new(0.6, wallH + 2, llen + 1), m)
	invisibleWall(cf * CFrame.new(side * xEnd, -1.5 + (wallH + 2) / 2, -(merge + len) / 2), Vector3.new(0.6, wallH + 2, len - merge + 2), m)
	-- сугроб вдоль воронки снаружи (декор) и обычный бортик за ней
	deco({ Size = Vector3.new(18, 3, llen + 2), CFrame = cf * line * CFrame.new(side * 9.4, 1.3, 0), Material = Enum.Material.Snow, Color = SNOW, CastShadow = true }, m)
	outerBank(cf, side, W / 2, merge, len - merge + 1, m)
	outerBank(cf, side, fork.outer, -1, merge * 0.5, m)
end

-- Настил моста на куске цепочки (зазор или островок): часть ломаной, попадающая в его диапазон пути.
-- Каждая часть — плита (Floor, лёд), невидимые борта по краям, ледяные бортики и перила (декор),
-- ускорители каждые FORK_BOOST_EVERY studs, ледяные опоры каждые FORK_PYLON_STEP.
function Fork.bridge(track, seg, m: Instance)
	local fork = seg.fork
	local C: CFrame = fork.origin
	local a = seg.hStart - fork.h0
	local b = if seg.isle and seg.isle.final then math.huge else a + seg.hLen
	local x, w = fork.x, fork.w
	local wallH = Config.WALL_HEIGHT
	local accent = Islands.accent(track.theme)
	local step, boostEvery, pylonStep = Config.FORK_POST_STEP, Config.FORK_BOOST_EVERY, Config.FORK_PYLON_STEP
	-- точки на шаге step, попадающие в [ua, ub) (по глобальному u — не зависят от разбиения на куски)
	local function each(every: number, ua: number, ub: number, fn: (number) -> ())
		if every <= 0 then
			return
		end
		for k = math.max(1, math.ceil(ua / every - 1e-9)), math.floor(ub / every) do
			local u = k * every
			if u >= ua and u < ub then
				fn(u)
			end
		end
	end
	for _, p in fork.pieces do
		local ua, ub = math.max(a, p[1]), math.min(b, p[3])
		if ub - ua < 1e-3 then
			continue
		end
		local function yAt(u: number): number
			return p[2] + (p[4] - p[2]) * (u - p[1]) / math.max(1e-6, p[3] - p[1])
		end
		local ya, yb = yAt(ua), yAt(ub)
		local du, dy = ub - ua, ya - yb
		local len = math.sqrt(du * du + dy * dy)
		local ang = math.atan2(dy, du)
		local top = C * CFrame.new(x, (ya + yb) / 2, -(ua + ub) / 2) * CFrame.Angles(-ang, 0, 0)
		part("Part", {
			Name = "Floor",
			Size = Vector3.new(w, DECK_T, len),
			CFrame = top * CFrame.new(0, -DECK_T / 2, 0),
			Material = Enum.Material.Glacier,
			Color = ICE_DECK,
			Reflectance = 0.1,
		}, m)
		for _, s in { -1, 1 } do
			invisibleWall(top * CFrame.new(s * (w / 2 + 0.3), -1.5 + (wallH + 2) / 2, 0), Vector3.new(0.6, wallH + 2, len + 0.2), m)
			deco({ Size = Vector3.new(1.4, 1.4, len + 0.1), CFrame = top * CFrame.new(s * (w / 2 + 0.7), 0.5, 0), Material = Enum.Material.Ice, Color = ICE_RAIL, Transparency = 0.1 }, m)
			deco({ Size = Vector3.new(0.35, 0.35, len + 0.1), CFrame = top * CFrame.new(s * (w / 2 + 0.7), 3.6, 0), Color = Color3.fromRGB(215, 180, 120) }, m)
			deco({ Size = Vector3.new(0.8, 0.06, len), CFrame = top * CFrame.new(s * (w / 2 - 2.5), 0.03, 0), Color = accent, Transparency = 0.1 }, m)
		end
		each(step, ua, ub, function(u)
			for _, s in { -1, 1 } do
				deco({ Size = Vector3.new(0.5, 3.6, 0.5), CFrame = C * CFrame.new(x + s * (w / 2 + 0.7), yAt(u) + 1.8, -u), Material = Enum.Material.Wood, Color = Color3.fromRGB(150, 105, 65) }, m)
			end
		end)
		each(boostEvery, ua, math.min(ub, fork.U - 30), function(u)
			local z = -(u - (ua + ub) / 2) / math.cos(ang)
			local pad = part("Part", {
				Name = "Boost",
				Size = Vector3.new(w - 8, 0.3, 9),
				CFrame = top * CFrame.new(0, 0.15, z),
				Material = Enum.Material.Neon,
				Color = Color3.fromRGB(80, 230, 255),
				CanCollide = false,
				CanQuery = false,
			}, m)
			CollectionService:AddTag(pad, "Boost")
			for k = 0, 1 do
				deco({ Size = Vector3.new(w - 12, 0.35, 1.1), CFrame = top * CFrame.new(0, 0.2, z + 2 - k * 3.5), Material = Enum.Material.Neon, Color = Color3.new(1, 1, 1) }, m)
			end
		end)
		each(pylonStep, ua, ub, function(u)
			local yb2 = yAt(u) - DECK_T
			for _, s in { -1, 1 } do
				deco({ Size = Vector3.new(2.4, 60, 2.4), CFrame = C * CFrame.new(x + s * (w / 2 - 2), yb2 - 30, -u), Material = Enum.Material.Ice, Color = ICE_RAIL, Transparency = 0.15 }, m)
			end
			deco({ Size = Vector3.new(w, 1.6, 2.4), CFrame = C * CFrame.new(x, yb2 - 0.8, -u), Material = Enum.Material.Ice, Color = ICE_RAIL }, m)
		end)
	end
end

-- Декор обочины со стороны моста (Dress.segment кладёт его за край сечения) — убрать: там пол развилки
function Fork.prune(seg, cf: CFrame, from: Instance, to: Instance)
	local side = seg.open
	for _, c in from:GetChildren() do
		local pos = if c:IsA("BasePart") then c.Position elseif c:IsA("Model") then c:GetPivot().Position else nil
		local rel = pos and cf:PointToObjectSpace(pos)
		if rel and rel.X * side > W / 2 + 1 then
			c:Destroy()
		else
			c.Parent = to
		end
	end
	from:Destroy()
end

return Fork
