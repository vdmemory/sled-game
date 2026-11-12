-- Островки над пропастью (#40): цепочка 3–6 снежных островков, на краю каждого — трамплин-
-- ускоритель; между ними пропасть без дна (упал — заезд «fell», как вылет за трассу).
--
-- Как устроено (docs/GAME_DESIGN.md → «Островки над пропастью»):
--   Track.buildProfile  → Islands.plan(level, rng): зазоры, перепады высот, длины и уклоны островков;
--                         куски isleIn (разгон с ускорителем) → gap → isle → gap → … → landing.
--   Track.buildSegment  → Islands.buildIsle / buildGap / buildLauncher: геометрия, монеты, бонусы.
--
-- Главное — прыжок всегда достижим. Ускоритель задаёт скорость вылета в окне [vmin, vmax]
-- (атрибуты LaunchMin/LaunchMax/Lift у Ramp, их читает SledController), дальше — баллистика:
-- в воздухе SledController сохраняет горизонтальную скорость (сопротивления нет), вниз тянет
-- workspace.Gravity. Зазор берётся так, что при vmin и самом раннем отрыве (в начале трамплина)
-- садимся дальше края на ISLE_LAND_MARGIN; длина островка — так, что при vmax, самом позднем
-- отрыве и ракете весь полёт садимся до начала его трамплина − ISLE_END_MARGIN.
-- Чистая баллистика (takeoff/landX/coinArc/plan) не создаёт Instance — её гоняет scratchpad-проверка.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Props = require(ReplicatedStorage.Shared.Props)

local part, deco = Props.part, Props.deco

local Islands = {}

------------------------------------------------------------------ баллистика
-- Система координат прыжка: x — по горизонтали вперёд от края куска (верх пола в его конце),
-- y — вверх. Трамплин (длина RL, высота RH) стоит в конце куска с уклоном pitch.

-- Точка и скорость отрыва. early = оторвались в начале трамплина (ниже и раньше), иначе на его
-- верхнем краю. Скорость — как в SledController на Ramp: d·v + n·max(vn, v·lift).
function Islands.takeoff(v: number, pitch: number, early: boolean): (number, number, number, number)
	local RL, RH = Config.ISLE_RAMP[1], Config.ISLE_RAMP[2]
	local p = math.rad(pitch)
	local theta = math.atan2(RH, RL) - p -- угол поверхности трамплина над горизонтом
	local lift = Config.ISLE_LIFT
	local vx = v * (math.cos(theta) - lift * math.sin(theta))
	local vy = v * (math.sin(theta) + lift * math.cos(theta))
	if early then
		return -RL * math.cos(p), RL * math.sin(p), vx, vy
	end
	return RH * math.sin(p), RH * math.cos(p), vx, vy
end

-- Высота траектории над точкой x (без ракеты); nil — до точки отрыва
function Islands.yAt(v: number, pitch: number, early: boolean, x: number): number?
	local x0, y0, vx, vy = Islands.takeoff(v, pitch, early)
	if x < x0 then
		return nil
	end
	local t = (x - x0) / vx
	return y0 + vy * t - workspace.Gravity * t * t / 2
end

-- Где сядем: следующая поверхность начинается через gap, ниже на drop и уходит вниз под углом
-- slope. thrust — ракета по горизонтали весь полёт. Ответ: x посадки (nil — врезались в торец
-- или не долетели) и время полёта.
function Islands.landX(v: number, pitch: number, early: boolean, thrust: number, drop: number, gap: number, slope: number): (number?, number)
	local x0, y0, vx, vy = Islands.takeoff(v, pitch, early)
	local g = workspace.Gravity
	local k = math.tan(math.rad(slope))
	local t, dt = 0, 0.002
	while t < 8 do
		t += dt
		local x = x0 + vx * t + thrust * t * t / 2
		local y = y0 + vy * t - g * t * t / 2
		if vy - g * t > 0 then
			continue -- ещё набираем высоту: следующий островок может быть выше точки отрыва
		end
		if x >= gap then
			if y <= -drop - (x - gap) * k then
				return x, t
			end
		elseif y <= -drop then
			return nil, t -- ниже края следующего островка до его начала — торец/пропасть
		end
	end
	return nil, t
end

-- Монеты дугой: точки, где все крайние траектории окна (vmin/vmax × ранний/поздний отрыв)
-- проходят в окне подбора монеты (SledController: монета от −3 до +7 по высоте от саней).
function Islands.coinArc(vmin: number, vmax: number, pitch: number, xFrom: number, xTo: number, count: number): { { number } }
	local out = {}
	for k = 1, count do
		local x = xFrom + (xTo - xFrom) * (k - 1) / math.max(1, count - 1)
		local lo, hi = math.huge, -math.huge
		local ok = true
		for _, v in { vmin, vmax } do
			for _, early in { true, false } do
				local y = Islands.yAt(v, pitch, early, x)
				if not y then
					ok = false
					break
				end
				lo, hi = math.min(lo, y), math.max(hi, y)
			end
		end
		-- окно монеты: hi − 3 < монета < lo + 7 (с запасом 0.5 с каждой стороны)
		if ok and hi - 2.5 < lo + 6.5 then
			table.insert(out, { x, (hi - 2.5 + lo + 6.5) / 2 })
		end
	end
	return out
end

-- План цепочки. Ответ: { vmin, vmax, n, gaps = { {gap, drop, from, minLand, maxLand, arc, landMid, final} },
-- isles = { {len, pitch, rim, landAt, spare} } }. Детерминирован rng (seed уровня).
function Islands.plan(level: number, rng: Random)
	local vmin, vmax = Config.isleSpeed(level)
	local lo, hi = Config.isleCount(level)
	local n = rng:NextInteger(lo, hi)
	local RL = Config.ISLE_RAMP[1]
	local thrust = Config.ROCKET_THRUST
	local spec = { vmin = vmin, vmax = vmax, n = n, gaps = {}, isles = {} }
	local pitch = Config.ISLE_IN[1]
	local vSafe = vmin * Config.ISLE_SLACK
	for i = 1, n + 1 do
		local final = i == n + 1
		local dr = if final then Config.ISLE_FINAL_DROP else Config.ISLE_DROP
		local drop = rng:NextNumber(dr[1], dr[2])
		local nextPitch = if final then 18 else rng:NextNumber(Config.ISLE_PITCH[1], Config.ISLE_PITCH[2])
		-- зазор по плоской оценке (островок впереди считаем ровным — так дальность меньше, с запасом)
		local rMin = Islands.landX(vSafe, pitch, true, 0, drop, -1000, 0) or 0
		local hiG = rMin - Config.ISLE_LAND_MARGIN
		local loG = math.min(hiG, math.max(Config.ISLE_GAP_MIN, rMin * Config.ISLE_GAP_FILL))
		local gap = math.max(4, rng:NextNumber(loG, hiG))
		local minLand = Islands.landX(vSafe, pitch, true, 0, drop, gap, nextPitch)
		local maxLand = Islands.landX(vmax, pitch, false, thrust, drop, gap, nextPitch)
		local midV = (vmin + vmax) / 2
		local landMid = Islands.landX(midV, pitch, false, 0, drop, gap, nextPitch)
		local arc = Islands.coinArc(vmin, vmax, pitch, gap * 0.15, gap + 0.25 * ((landMid or gap) - gap), Config.ISLE_COINS)
		table.insert(spec.gaps, {
			gap = gap,
			drop = drop,
			from = pitch,
			final = final,
			minLand = (minLand or 0) - gap, -- запас долёта за краем при vmin
			maxLand = (maxLand or 0) - gap, -- куда долетим при vmax + ракета
			landMid = (landMid or gap) - gap,
			arc = arc,
		})
		if not final then
			local need = (maxLand or gap) - gap + RL + Config.ISLE_END_MARGIN
			local len = math.max(rng:NextNumber(Config.ISLE_LEN[1], Config.ISLE_LEN[2]), need)
			table.insert(spec.isles, {
				len = len,
				pitch = nextPitch,
				rim = rng:NextNumber(Config.ISLE_RIM[1], Config.ISLE_RIM[2]),
				landAt = (landMid or gap) - gap,
				spare = len - RL - ((maxLand or gap) - gap), -- сколько осталось до трамплина при vmax + ракета
			})
			pitch = nextPitch
		end
	end
	return spec
end

------------------------------------------------------------------ вид
local W = Config.TRACK_WIDTH
local SNOW = Color3.fromRGB(250, 252, 255)
local SNOW_TOP = Color3.fromRGB(240, 246, 255)
local BOOST = Color3.fromRGB(80, 230, 255)
local ROCKS = {
	[3] = { Enum.Material.Sandstone, Color3.fromRGB(205, 140, 95) },
	[4] = { Enum.Material.Glacier, Color3.fromRGB(140, 195, 235) },
	[5] = { Enum.Material.Slate, Color3.fromRGB(70, 80, 110) },
	[6] = { Enum.Material.Basalt, Color3.fromRGB(60, 56, 62) },
	[7] = { Enum.Material.Limestone, Color3.fromRGB(245, 200, 225) },
}
local function rockOf(theme: number): (Enum.Material, Color3)
	local r = ROCKS[theme]
	if r then
		return r[1], r[2]
	end
	return Enum.Material.Rock, Color3.fromRGB(120, 128, 145)
end
-- Цвет акцента мира для разметки и флажков
local ACCENT = {
	Color3.fromRGB(255, 80, 90), Color3.fromRGB(80, 170, 255), Color3.fromRGB(255, 150, 50), Color3.fromRGB(90, 220, 255),
	Color3.fromRGB(150, 110, 255), Color3.fromRGB(255, 110, 40), Color3.fromRGB(255, 110, 190),
}
function Islands.accent(theme: number): Color3
	return ACCENT[((theme - 1) % #ACCENT) + 1]
end

-- Smooth Terrain для скал (опоры островков, стены каньона): только сервер и только трасса заезда
-- (витрина лобби строится у клиента — там без Terrain). Каждая заливка запоминается в clears,
-- чтобы Track стёр её воздухом, когда кусок уходит из стриминга.
local function terrainOn(track): boolean
	return RunService:IsServer() and not track.preview and workspace.Terrain ~= nil
end
local function clearBox(clears: { any }, cf: CFrame, size: Vector3)
	table.insert(clears, { cf, size })
end

-- Пропасть: облака внизу (полупрозрачные шары) — без коллизий, падение сквозь них = «fell»
local function clouds(cf: CFrame, len: number, rng: Random, m: Instance, count: number)
	for _ = 1, count do
		local s = rng:NextNumber(26, 52)
		deco({
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(s * 1.6, s * 0.55, s),
			CFrame = cf * CFrame.new(rng:NextNumber(-90, 90), -rng:NextNumber(38, 62), -rng:NextNumber(0, len)),
			Color = Color3.fromRGB(245, 248, 255),
			Transparency = rng:NextNumber(0.15, 0.4),
			Material = Enum.Material.SmoothPlastic,
		}, m)
	end
end

-- Стены каньона по бокам пропасти (Terrain) + декор мира на их кромке (через dress из Track)
local CANYON_X = W / 2 + 60
local function canyon(track, cf: CFrame, len: number, rng: Random, m: Instance, clears: { any }, dress: (any, any) -> ())
	local look = cf.LookVector
	local flat = CFrame.lookAt(cf.Position, cf.Position + Vector3.new(look.X, 0, look.Z))
	if terrainOn(track) then
		local terrain = workspace.Terrain
		local mat = rockOf(track.theme)
		for _, side in { -1, 1 } do
			local x = side * (CANYON_X + 22)
			local top = 4 + rng:NextNumber(-1.5, 1.5)
			local wallCF = flat * CFrame.new(x, top - 50, -len / 2)
			local size = Vector3.new(44, 100, len + 6)
			terrain:FillBlock(wallCF, size, mat)
			-- снежная шапка и неровная кромка шарами
			terrain:FillBlock(flat * CFrame.new(x, top + 1, -len / 2), Vector3.new(44, 4, len + 6), Enum.Material.Snow)
			for _ = 1, 2 do
				terrain:FillBall((flat * CFrame.new(side * (CANYON_X + rng:NextNumber(2, 10)), top - rng:NextNumber(6, 30), -rng:NextNumber(0, len))).Position, rng:NextNumber(7, 13), mat)
			end
			clearBox(clears, flat * CFrame.new(x - side * 6, top - 46, -len / 2), Vector3.new(60, 112, len + 8))
		end
		-- декор мира на кромке каньона (ёлки/дома/кактусы — как у обычной трассы)
		dress(flat, { out = CANYON_X, top = 7, banks = {} })
	else
		-- без Terrain (витрина): каньон из пары больших скал
		local _, color = rockOf(track.theme)
		for _, side in { -1, 1 } do
			deco({ Size = Vector3.new(40, 90, len + 4), CFrame = flat * CFrame.new(side * (CANYON_X + 20), -45, -len / 2), Color = color, Material = Enum.Material.Slate }, m)
		end
	end
end

-- Флажок на шесте (пол + полотнище); без анимации, 2 Part-а
local function pennant(base: CFrame, color: Color3, h: number, m: Instance)
	deco({ Size = Vector3.new(0.5, h, 0.5), CFrame = base * CFrame.new(0, h / 2, 0), Color = Color3.fromRGB(235, 238, 245), Material = Enum.Material.Metal }, m)
	deco({ Size = Vector3.new(0.15, 2.6, 4.2), CFrame = base * CFrame.new(0, h - 1.4, 2.1), Color = color }, m, "WedgePart")
end

Islands.pennant = pennant

-- Трамплин-ускоритель на краю куска: голубой клин с белыми шевронами, светящаяся дорожка
-- «Boost» перед ним (+BOOST_ADD, «⚡ Ускорение!»), арка с надписью и флажки по бокам.
-- Атрибуты Ramp: LaunchMin/LaunchMax — окно скорости вылета, Lift — подброс (SledController).
function Islands.buildLauncher(cf: CFrame, len: number, width: number, level: number, theme: number, m: Instance, sign: string?)
	local RL, RH = Config.ISLE_RAMP[1], Config.ISLE_RAMP[2]
	local vmin, vmax = Config.isleSpeed(level)
	local ramp = Props.ramp(cf * CFrame.new(0, 0, -(len - RL / 2)), width, RL, RH, m)
	ramp.Color = BOOST
	ramp.Material = Enum.Material.SmoothPlastic
	ramp:SetAttribute("LaunchMin", vmin)
	ramp:SetAttribute("LaunchMax", vmax)
	ramp:SetAttribute("Lift", Config.ISLE_LIFT)
	-- светящаяся кромка трамплина
	deco({ Size = Vector3.new(width, 0.4, 0.8), CFrame = cf * CFrame.new(0, RH - 0.1, -(len - 0.4)), Material = Enum.Material.Neon, Color = Color3.new(1, 1, 1) }, m)
	-- дорожка-ускоритель перед трамплином
	local pad = part("Part", {
		Name = "Boost",
		Size = Vector3.new(W - 8, 0.3, 9),
		CFrame = cf * CFrame.new(0, 0.15, -(len - RL - 7)),
		Material = Enum.Material.Neon,
		Color = BOOST,
		CanCollide = false,
		CanQuery = false,
	}, m)
	CollectionService:AddTag(pad, "Boost")
	for k = 0, 2 do
		deco({ Size = Vector3.new(W - 14, 0.35, 1.1), CFrame = cf * CFrame.new(0, 0.2, -(len - RL - 3.5 - k * 3.5)), Material = Enum.Material.Neon, Color = Color3.new(1, 1, 1) }, m)
	end
	-- арка над краем: два столба + перекладина с надписью (декор, сквозь неё летим)
	local accent = Islands.accent(theme)
	local edge = cf * CFrame.new(0, 0, -(len - RL))
	local span = width / 2 + 2
	for _, side in { -1, 1 } do
		deco({ Size = Vector3.new(1.6, 26, 1.6), CFrame = edge * CFrame.new(side * span, 13, 0), Color = Color3.fromRGB(240, 242, 248), CastShadow = true }, m)
		pennant(edge * CFrame.new(side * span, 26, 0), accent, 6, m)
	end
	local bar = deco({ Size = Vector3.new(span * 2 + 1.6, 3.2, 1.4), CFrame = edge * CFrame.new(0, 25, 0), Material = Enum.Material.Neon, Color = accent }, m)
	if sign then
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Back -- лицом к игроку (едет по −Z)
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 20
		sg.LightInfluence = 0
		sg.Parent = bar
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.Text = sign
		t.TextColor3 = Color3.new(1, 1, 1)
		t.TextStrokeTransparency = 0.2
		t.Parent = sg
	end
	return ramp
end

-- Островок: снежная плита шире коридора, невидимые борта по коридору ±W/2 (как у трассы),
-- округлые снежные кромки, разметка «посадочной зоны» там, куда прилетаешь на средней скорости,
-- ускоритель на краю, бонус, скала-опора снизу (Terrain), облака и стены каньона.
function Islands.buildIsle(track, seg, m: Instance, rng: Random, kit): { any }
	local clears = {}
	local cf, len = seg.cf, seg.length
	local spec = seg.isle
	local fw = W + spec.rim * 2
	local theme = track.theme
	local snowMat = if theme == 4 then Enum.Material.Glacier else Enum.Material.Snow
	part("Part", {
		Name = "Floor",
		Size = Vector3.new(fw, 4, len),
		CFrame = cf * CFrame.new(0, -2, -len / 2),
		Material = snowMat,
		Color = if theme == 7 then Color3.fromRGB(255, 225, 240) else SNOW_TOP,
	}, m)
	-- снежный «подбой» под плитой (толще и чуть уже — плита не выглядит листом)
	deco({ Size = Vector3.new(fw - 4, 5, len - 4), CFrame = cf * CFrame.new(0, -6, -len / 2), Material = Enum.Material.Snow, Color = SNOW }, m)
	-- льдина (#67, референсы): сосульки по краю «подбоя» — без Random (раскладка островка та же)
	if theme ~= 3 and theme ~= 6 then
		local ice = if theme == 7 then Color3.fromRGB(255, 210, 235) else Color3.fromRGB(200, 230, 252)
		for _, side in { -1, 1 } do
			for k = 1, math.floor(len / 6) do
				local l = 2 + (k * 7 % 5) * 0.9
				deco({ Size = Vector3.new(0.9, l, 0.9), CFrame = cf * CFrame.new(side * (fw / 2 - 2.6), -8.5 - l / 2, -k * 6 + 3), Material = Enum.Material.Ice, Color = ice, Transparency = 0.1 }, m)
			end
		end
	end
	-- округлые кромки по бокам (визуальный бортик)
	for _, side in { -1, 1 } do
		deco({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(len, 3.2, 3.2),
			CFrame = cf * CFrame.new(side * (fw / 2 - 0.6), 0.2, -len / 2) * CFrame.Angles(0, math.rad(90), 0),
			Material = Enum.Material.Snow,
			Color = SNOW,
		}, m)
		-- невидимый борт коридора (двойной: прилетаем сверху)
		local wallH = Config.WALL_HEIGHT * 2
		local tilt = math.rad(Config.WALL_TILT)
		part("Part", {
			Name = "Wall",
			Size = Vector3.new(0.6, wallH + 2, len),
			CFrame = cf * CFrame.new(side * (W / 2 + Config.WALL_OFFSET), -1.5, -len / 2) * CFrame.Angles(0, 0, -side * tilt) * CFrame.new(0, (wallH + 2) / 2, 0),
			Transparency = 1,
			CanQuery = false,
			CastShadow = false,
		}, m)
	end
	-- посадочная зона: цветное кольцо на снегу (видно в полёте — куда садиться)
	local accent = Islands.accent(theme)
	local landZ = math.clamp(spec.landAt, 10, len - Config.ISLE_RAMP[1] - 12)
	for k, d in { 30, 24 } do
		deco({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.1 + k * 0.02, d, d),
			CFrame = cf * CFrame.new(0, 0.03 + k * 0.02, -landZ) * CFrame.Angles(0, 0, math.rad(90)),
			Color = if k == 1 then accent else SNOW_TOP,
			Transparency = if k == 1 then 0.15 else 0,
		}, m)
	end
	-- ускоритель на краю
	Islands.buildLauncher(cf, len, fw, track.level, theme, m)
	-- бонус посередине островка (между посадкой и ускорителем)
	if rng:NextNumber() < Config.ISLE_BONUS_CHANCE then
		local z = (landZ + len - Config.ISLE_RAMP[1] - 10) / 2
		local lane = rng:NextInteger(2, Config.LANES - 1)
		local at = cf * CFrame.new(-W / 2 + (W / Config.LANES) * (lane - 0.5), 3, -z)
		local pick = rng:NextInteger(1, 4)
		local fn = ({ kit.shield, kit.x2, kit.fuel, kit.magnet })[pick]
		fn(at, m)
	end
	-- опора: скала под островком (Terrain), сужается книзу; верх на 10 studs внутри краёв плиты —
	-- недолетевшие сани не застревают на уступе под островком, а падают в пропасть
	local r = math.min(fw, len) / 2 - 10
	local center = cf * CFrame.new(0, 0, -len / 2)
	if terrainOn(track) then
		local terrain = workspace.Terrain
		local mat = rockOf(theme)
		local up = CFrame.new(center.Position)
		terrain:FillCylinder(up * CFrame.new(0, -16, 0), 18, r, mat)
		terrain:FillBall((up * CFrame.new(rng:NextNumber(-4, 4), -30, rng:NextNumber(-4, 4))).Position, math.min(r * 0.75, 22), mat) -- верх ≤ −8: скала не выходит на снег
		terrain:FillCylinder(up * CFrame.new(0, -46, 0) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), 0, rng:NextNumber(-0.15, 0.15)), 26, r * 0.42, mat)
		terrain:FillBall((up * CFrame.new(0, -62, 0)).Position, r * 0.3, mat)
		clearBox(clears, up * CFrame.new(0, -40, 0), Vector3.new(r * 2 + 12, 76, r * 2 + 12))
	else
		local _, color = rockOf(theme)
		deco({ Size = Vector3.new(r * 1.6, 22, r * 1.6), CFrame = center * CFrame.new(0, -18, 0) * CFrame.Angles(0, 0.4, 0), Color = color, Material = Enum.Material.Slate }, m)
		deco({ Size = Vector3.new(r * 0.8, 30, r * 0.8), CFrame = center * CFrame.new(0, -42, 0) * CFrame.Angles(0, 1.1, 0), Color = color, Material = Enum.Material.Slate }, m)
	end
	clouds(cf, len, rng, m, 1)
	canyon(track, cf, len, rng, m, clears, kit.dress)
	return clears
end

-- Пропасть между островками: монеты дугой по траектории прыжка, облака внизу, стены каньона;
-- перед склоном приземления — скальная стена под его краем
function Islands.buildGap(track, seg, m: Instance, rng: Random, kit): { any }
	local clears = {}
	local cf, len = seg.cf, seg.length
	local g = seg.isle
	local look = cf.LookVector
	local flat = CFrame.lookAt(cf.Position, cf.Position + Vector3.new(look.X, 0, look.Z))
	local laneW = W / Config.LANES
	local lane = rng:NextInteger(2, Config.LANES - 1)
	local x = -W / 2 + laneW * (lane - 0.5)
	for _, p in g.arc do
		kit.coin(flat * CFrame.new(x, p[2], -p[1]), m)
	end
	clouds(cf, len, rng, m, 3)
	canyon(track, cf, len, rng, m, clears, kit.dress)
	-- подвесной мост над пропастью сбоку от коридора (#70, декор; сторона — по номеру куска, без Random)
	if Config.BRIDGE_GAP_X > 0 then
		local side = if math.floor(seg.hStart / 10) % 2 == 0 then -1 else 1
		local y = -Config.BRIDGE_DROP
		Props.ropeBridge(flat:PointToWorldSpace(Vector3.new(side * Config.BRIDGE_GAP_X, y, 2)), cf:PointToWorldSpace(Vector3.new(side * Config.BRIDGE_GAP_X, y, -len - 2)), 6, m)
	end
	if g.final then
		-- край склона приземления: скала уходит вниз из-под снега
		local edge = cf * CFrame.new(0, 0, -len)
		local _, color = rockOf(track.theme)
		local eflat = CFrame.lookAt(edge.Position, edge.Position + Vector3.new(look.X, 0, look.Z))
		deco({ Size = Vector3.new(W + 70, 70, 6), CFrame = eflat * CFrame.new(0, -37, 3), Color = color, Material = Enum.Material.Slate }, m)
		deco({ Size = Vector3.new(W + 74, 4, 8), CFrame = eflat * CFrame.new(0, -1.6, 2.5), Color = SNOW, Material = Enum.Material.Snow }, m)
	end
	return clears
end

-- Край разгона перед первым прыжком: ускоритель с вывеской + скала под обрывом
function Islands.buildIn(track, seg, m: Instance)
	local cf, len = seg.cf, seg.length
	Islands.buildLauncher(cf, len, W, track.level, track.theme, m, "ПРЫГАЙ!")
	local endPos = cf:PointToWorldSpace(Vector3.new(0, 0, -len))
	local look = cf.LookVector
	local eflat = CFrame.lookAt(endPos, endPos + Vector3.new(look.X, 0, look.Z))
	local _, color = rockOf(track.theme)
	deco({ Size = Vector3.new(W + 140, 70, 6), CFrame = eflat * CFrame.new(0, -37, 3), Color = color, Material = Enum.Material.Slate }, m)
end

-- Стереть Terrain куска (кусок уходит из стриминга или трасса уничтожается)
function Islands.clear(clears: { any }?)
	if not clears or #clears == 0 then
		return
	end
	local terrain = workspace.Terrain
	if not terrain then
		return
	end
	for _, c in clears do
		terrain:FillBlock(c[1], c[2], Enum.Material.Air)
	end
end

return Islands
