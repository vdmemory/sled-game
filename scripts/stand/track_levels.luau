--!nolint
-- Сборка трасс уровней (#43/#44): строит все куски уровней 1–45 (7 миров, Config.themeOf) через
-- Track.new + buildSegment и проверяет:
--   • ни один кусок не падает с ошибкой (pcall на кусок);
--   • трамплин-лестница (#43): при верхней скорости + ракета садимся до следующего трамплина −
--     STAIR_END_MARGIN и до конца склона приземления, при нижней — за краем трамплина; на кусках
--     лестницы нет тоннеля, долины, рядов препятствий;
--   • гладкость стыков ходовой части (как scratchpad/smooth/check_tail, #40): ступенька > 0.2 stud /
--     излом > 3° на 2 studs; намеренные разрывы — край кикера, островки, трамплины лестницы;
--   • вираж-спираль (#44): не под тоннелем/долиной, курс не дальше SPIRAL_MAX_HEADING; ледяной тоннель:
--     кольца-ускорители (тег Boost) построены, перед ним нет препятствий;
--   • снос вбок (#73): центр трассы (начала и концы кусков) не дальше SLOT_SPACING/2 − 150, а полоса
--     трассы со всем оформлением (углы всех BasePart) — не дальше SLOT_SPACING/2 и не шире
--     |снос| + TRACK_FOOTPRINT: соседние слоты не пересекаются (с --meshes — с горами и скалами мешей);
--   • статистика по уровням: сколько новых участков и какая доля пути.
--   python3 scripts/stand/run.py scripts/stand/track_levels.luau [--meshes]
-- STAND_MESHES — шаблоны MeshTemplates на все имена MeshSpecs (как после загрузки мешей).

local RS = game:GetService("ReplicatedStorage")
RS.FindFirstChild = function(self, n) return rawget(self, n) end
do
	local InstMT = getmetatable(workspace)
	InstMT.Clone = function(t)
		local c = Instance.new(rawget(t, "_p").ClassName)
		for k, v in rawget(t, "_p") do
			if k ~= "Parent" then rawget(c, "_p")[k] = v end
		end
		return c
	end
end
if STAND_MESHES then
	local folder = Instance.new("Folder")
	folder.Name = "MeshTemplates"
	folder.Parent = workspace
	for name in require(SHARED.MeshSpecs) do
		local mp = Instance.new("MeshPart")
		mp.Name = name
		mp.Parent = folder
	end
	rawset(RS, "MeshTemplates", folder)
end
Config = require(SHARED.Config)
local Track = require(SHARED.Track)

------------------------------------------------------------------ гладкость стыков (#40)
local INTENT_END = { kicker = true, isleIn = true, isle = true, gap = true, stair = true }
local XS = { -39, -26, -13, 0, 13, 26, 39 }
local STEP_MAX, KINK_MAX = 0.2, 3
local function prep(p)
	local c, s = p.CFrame, p.Size
	local r, u, b, o = c.r, c.u, c.b, c.p
	return { ox = o.X, oy = o.Y, oz = o.Z, rx = r.X, ry = r.Y, rz = r.Z, ux = u.X, uy = u.Y, uz = u.Z, bx = b.X, by = b.Y, bz = b.Z, hx = s.X / 2, hy = s.Y / 2, hz = s.Z / 2 }
end
local function topAt(f, P)
	if f.uy < 0.3 then
		return nil
	end
	local dx, dz = P.X - f.ox, P.Z - f.oz
	local y = f.oy + (f.hy - f.ux * dx - f.uz * dz) / f.uy
	local dy = y - f.oy
	local qx = f.rx * dx + f.ry * dy + f.rz * dz
	local qz = f.bx * dx + f.by * dy + f.bz * dz
	if math.abs(qx) <= f.hx + 1e-6 and math.abs(qz) <= f.hz + 1e-6 then
		return y
	end
	return nil
end
local function smoothness(tr)
	local segs = tr.segments
	local floors = {}
	for _, d in tr.folder:GetDescendants() do
		if d:IsA("BasePart") and d.CanCollide ~= false and d.Name == "Floor" then
			local m = d.Parent
			local idx = if m.Name == "Start" then -1 else tonumber(string.match(m.Name, "Segment_(%d+)"))
			if idx then
				idx += 1
				floors[idx] = floors[idx] or {}
				table.insert(floors[idx], prep(d))
			end
		end
	end
	local function H(P, k)
		local best = nil
		for idx = k - 6, k + 4 do
			for _, f in floors[idx] or {} do
				local y = topAt(f, P)
				if y and math.abs(y - P.Y) < 3 and (best == nil or y > best) then
					best = y
				end
			end
		end
		return best
	end
	local bad, worst, byKind = 0, 0, {}
	for k = 2, #segs do
		local A, B = segs[k - 1], segs[k]
		if INTENT_END[A.kind] or B.kind == "gap" then
			continue
		end
		local hit = nil
		for _, x in XS do
			local pts = {}
			for t = -3, 3, 0.25 do
				local P = if t < 0 then A.cf * Vector3.new(x, 0, -(A.length + t)) else B.cf * Vector3.new(x, 0, -t)
				local hh = H(P, if t < 0 then k - 1 else k)
				if not hh then
					hit = "дыра"
					break
				end
				table.insert(pts, { P = P, h = hh })
			end
			if hit then
				break
			end
			local function hd(a, b)
				local d = pts[b].P - pts[a].P
				return math.sqrt(d.X * d.X + d.Z * d.Z)
			end
			local n, i0 = #pts, 13
			local sA = (pts[i0 - 1].h - pts[1].h) / math.max(1e-3, hd(1, i0 - 1))
			local sB = (pts[n].h - pts[i0 + 1].h) / math.max(1e-3, hd(i0 + 1, n))
			local sA2 = (pts[i0 - 1].h - pts[i0 - 8].h) / math.max(1e-3, hd(i0 - 8, i0 - 1))
			local sB2 = (pts[i0 + 8].h - pts[i0 + 1].h) / math.max(1e-3, hd(i0 + 1, i0 + 8))
			local kink = math.abs(math.deg(math.atan(sB2)) - math.deg(math.atan(sA2)))
			local step = 0
			for j = 1, n - 1 do
				local sRef = if j < i0 then sA else sB
				local d = math.abs((pts[j + 1].h - pts[j].h) - sRef * hd(j, j + 1))
				step = math.max(step, d - math.abs(sB - sA) * hd(j, j + 1))
			end
			worst = math.max(worst, step)
			if step > STEP_MAX then
				hit = string.format("ступенька %.2f", step)
				break
			elseif step <= 0.01 and kink > KINK_MAX then
				hit = string.format("излом %.1f°", kink)
				break
			end
		end
		if hit then
			bad += 1
			local key = A.kind .. "→" .. B.kind
			byKind[key] = (byKind[key] or 0) + 1
			if VERBOSE then
				print("  стык", k, key, hit)
			end
		end
	end
	return bad, worst, byKind
end

------------------------------------------------------------------ лестница (#43)
local function checkStairs(segs, level): (number, number, { string })
	local errs, series, coins = {}, 0, 0
	for k, s in segs do
		local st = s.stair
		if st then
			coins += #st.arc
			if s.tunnel or s.valley then
				table.insert(errs, "свод/долина на лестнице")
			end
			if st.minLand <= 0 then
				table.insert(errs, "недолёт за край трамплина")
			end
			local nxt = segs[k + 1]
			if st.final then
				series += 1
				if not nxt or nxt.kind ~= "stairLand" or nxt.length < st.maxLand then
					table.insert(errs, string.format("перелёт склона приземления %.0f > %.0f", st.maxLand, nxt and nxt.length or 0))
				end
			else
				local room = nxt and nxt.stair and (nxt.length - nxt.stair.ramp[1]) or 0
				if st.maxLand > room - Config.STAIR_END_MARGIN + 1e-6 then
					table.insert(errs, string.format("перелёт ступени %.0f > %.0f", st.maxLand, room - Config.STAIR_END_MARGIN))
				end
			end
		end
	end
	return series, coins, errs
end

------------------------------------------------------------------ вираж и ледяной тоннель (#44)
local CS = game:GetService("CollectionService")
local function checkSpiral(tr): (number, number, number, number, number, { string })
	local segs = tr.segments
	local errs = {}
	local spirals, ice, maxYaw, maxDrift = 0, 0, 0, 0
	for k, s in segs do
		maxYaw = math.max(maxYaw, math.abs(math.deg(s.yaw)))
		maxDrift = math.max(maxDrift, math.abs(tr.origin:PointToObjectSpace(s.cf.Position).X),
			math.abs(tr.origin:PointToObjectSpace((s.cf * CFrame.new(0, 0, -s.length)).Position).X))
		if s.kind == "spiral" then
			if s.tunnel or s.valley then
				table.insert(errs, "свод/долина на вираже")
			end
			if not segs[k - 1] or segs[k - 1].kind ~= "spiral" then
				spirals += 1
			end
		elseif s.kind == "iceTunnel" and s.ice.half == 1 then
			ice += 1
		end
	end
	if maxYaw > Config.SPIRAL_MAX_HEADING + 0.5 then
		table.insert(errs, string.format("курс %.0f°", maxYaw))
	end
	local rings = 0
	for _, d in tr.folder:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "Boost" and CS:HasTag(d, "Boost") then
			local m = d.Parent
			local idx = tonumber(string.match(m.Name, "Segment_(%d+)"))
			if idx and segs[idx + 1].kind == "iceTunnel" then
				rings += 1
			end
		end
	end
	if rings ~= ice * Config.ICE_TUNNEL_RINGS then
		table.insert(errs, string.format("колец %d вместо %d", rings, ice * Config.ICE_TUNNEL_RINGS))
	end
	return spirals, ice, rings, maxYaw, maxDrift, errs
end

------------------------------------------------------------------ полоса трассы (#73)
-- Дальше всего от оси слота: углы всех BasePart трассы
local function footprint(tr): number
	local o, foot = tr.origin, 0
	for _, d in tr.folder:GetDescendants() do
		if d:IsA("BasePart") then
			local c, sz = d.CFrame, d.Size
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz2 in { -1, 1 } do
						local p = c * Vector3.new(sx * sz.X / 2, sy * sz.Y / 2, sz2 * sz.Z / 2)
						foot = math.max(foot, math.abs(o:PointToObjectSpace(p).X))
					end
				end
			end
		end
	end
	return foot
end

local fails = 0
local worstDrift, worstFoot = 0, 0
local totalSpirals, totalIce = 0, 0
local totalStairs, totalSmooth = 0, 0
local worstStep = 0
for level = tonumber(ARGS_FROM) or 1, tonumber(ARGS_TO) or 45 do
	local ok, tr = pcall(Track.new, 0, level)
	if not ok then
		print("УРОВЕНЬ", level, "Track.new:", tr)
		fails += 1
		continue
	end
	local segs = tr.segments
	local errs = 0
	for i = 0, #segs - 1 do
		if not tr.built[i] then
			local ok2, e = pcall(tr.buildSegment, tr, i)
			if not ok2 then
				errs += 1
				if errs <= 3 then
					print("  ур.", level, "кусок", i, segs[i + 1].kind, e)
				end
			end
		end
	end
	if errs > 0 then
		fails += 1
	end
	local total, by = 0, {}
	for _, s in segs do
		if s.kind ~= "lake" then
			total += s.hLen
			by[s.kind] = (by[s.kind] or 0) + s.hLen
		end
	end
	local series, coins, serr = checkStairs(segs, level)
	totalStairs += series
	for _, e in serr do
		print("  ур.", level, "лестница:", e)
		fails += 1
	end
	local spirals, ice, rings, maxYaw, maxDrift, perr = checkSpiral(tr)
	totalSpirals += spirals
	totalIce += ice
	for _, e in perr do
		print("  ур.", level, "вираж/тоннель:", e)
		fails += 1
	end
	local foot = footprint(tr)
	worstDrift, worstFoot = math.max(worstDrift, maxDrift), math.max(worstFoot, foot)
	local half = Config.SLOT_SPACING / 2
	if maxDrift > half - 150 or foot > half or foot > maxDrift + Config.TRACK_FOOTPRINT then
		print(string.format("  ур. %d снос %.0f / полоса %.0f: соседний слот (шаг %d, полоса ≤ снос + %d)", level, maxDrift, foot, Config.SLOT_SPACING, Config.TRACK_FOOTPRINT))
		fails += 1
	end
	local bad, worst, byKind = smoothness(tr)
	totalSmooth += bad
	worstStep = math.max(worstStep, worst)
	local bk = {}
	for k, v in byKind do
		table.insert(bk, k .. "×" .. v)
	end
	local stairShare = ((by.stair or 0) + (by.stairLand or 0)) / total * 100
	local spiralShare = (by.spiral or 0) / total * 100
	print(string.format("ур.%2d мир %d тема %d  кусков %4d  ошибок %d  лестниц %d (%.0f%% пути, монет %d)  виражей %d (%.0f%%)  ледяных тоннелей %d (колец %d)  курс ≤ %.0f°  снос ≤ %.0f  полоса ≤ %.0f  стыков с нарушениями %d %s",
		level, Config.worldOf(level), Config.themeOf(level), #segs, errs, series, stairShare, coins, spirals, spiralShare, ice, rings, maxYaw, maxDrift, foot, bad, table.concat(bk, " ")))
	tr:destroy()
end
print(string.format("Итого: виражей %d, ледяных тоннелей %d", totalSpirals, totalIce))
print(string.format("Итого: снос центра ≤ %.0f, полоса с оформлением ≤ %.0f studs от оси (шаг слотов %d)", worstDrift, worstFoot, Config.SLOT_SPACING))
print(string.format("Итого: лестниц %d, стыков с нарушениями %d, худшая ступенька %.2f stud, ошибок %d", totalStairs, totalSmooth, worstStep, fails))
if fails > 0 then
	error("есть ошибки сборки трасс")
end
print("track_levels: OK")
