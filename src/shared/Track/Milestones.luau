-- Рубежи дистанции (#61, Config.MILESTONES): арка над трассой каждые STEP м пути (250, 500, 750…) —
-- два столба по краю сечения, перекладина-табличка «500 м» (лицом к едущему), флажки; каждый
-- BIG_EVERY-й рубеж — золотой. Только декор (Props.deco: без коллизий, касаний и лучей) и без Random:
-- раскладка препятствий/монет, физика и античит не меняются. Награду за рубеж считает сервер
-- (server/Runs, по засчитанному пути), здесь — только вид. Вызывается из Track:buildSegment.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Props = require(ReplicatedStorage.Shared.Props)

local deco = Props.deco

local Milestones = {}

local POST = Color3.fromRGB(235, 242, 250)
local NORMAL = Color3.fromRGB(70, 175, 255)
local BIG = Color3.fromRGB(255, 200, 50)
local FLAGS = { Color3.fromRGB(255, 90, 90), Color3.fromRGB(255, 205, 60), Color3.fromRGB(90, 210, 255), Color3.fromRGB(120, 230, 120) }
local POST_H = 20 -- высота столбов над кромкой сечения
local BOARD_H = 4.5

-- Рубежи (м пути), которые попадают на кусок seg; length — длина уровня
function Milestones.at(seg: any, length: number): { number }
	local M = Config.MILESTONES
	local out = {}
	if M.STEP <= 0 then
		return out
	end
	local k = math.max(1, math.ceil(seg.hStart / M.STEP))
	while k * M.STEP < seg.hStart + seg.hLen do
		local h = k * M.STEP
		if h >= seg.hStart and length - h >= M.FINISH_GAP then
			table.insert(out, h)
		end
		k += 1
	end
	return out
end

-- Большой ли рубеж h (каждый BIG_EVERY-й)
function Milestones.isBig(h: number): boolean
	local M = Config.MILESTONES
	return M.STEP > 0 and M.BIG_EVERY > 0 and math.round(h / M.STEP) % M.BIG_EVERY == 0
end

-- Арки рубежей на куске: cf — начало куска (ось −Z вдоль трассы), prof — сечение (out — половина
-- ширины до внешнего края, top — высота кромки). Над пропастью и островками арок нет.
function Milestones.build(seg: any, cf: CFrame, prof: any, length: number, parent: Instance)
	if seg.kind == "gap" or seg.kind == "isle" or seg.open then -- развилка (#42): столб арки встал бы на пол к мосту
		return
	end
	local cosA = math.cos(math.rad(seg.angle))
	for _, h in Milestones.at(seg, length) do
		local big = Milestones.isBig(h)
		local color = if big then BIG else NORMAL
		local m = Instance.new("Model")
		m.Name = "Milestone"
		m:SetAttribute("Meters", h)
		local at = cf * CFrame.new(0, 0, -(h - seg.hStart) / cosA)
		local half = prof.out
		local top = prof.top + POST_H
		for side = -1, 1, 2 do
			deco({ Size = Vector3.new(1.6, top, 1.6), CFrame = at * CFrame.new(side * half, top / 2, 0), Color = POST }, m)
			deco({ Size = Vector3.new(2.4, 0.8, 2.4), CFrame = at * CFrame.new(side * half, top + 0.4, 0), Color = color, Material = Enum.Material.Neon }, m)
		end
		deco({ Size = Vector3.new(half * 2, 0.8, 0.8), CFrame = at * CFrame.new(0, top - 0.4, 0), Color = POST }, m)
		local board = deco({ Size = Vector3.new(18, BOARD_H, 0.6), CFrame = at * CFrame.new(0, top - 0.8 - BOARD_H / 2, 0), Color = color }, m)
		-- гирлянда флажков под перекладиной
		local n = math.max(4, math.floor(half * 2 / 9))
		for f = 1, n do
			local x = -half + (f - 0.5) * (half * 2 / n)
			if math.abs(x) > 10 then
				deco({ Size = Vector3.new(1.8, 2.2, 0.2), CFrame = at * CFrame.new(x, top - 2, 0) * CFrame.Angles(0, 0, math.rad(45)), Color = FLAGS[(f % #FLAGS) + 1] }, m)
			end
		end
		-- надпись лицом к едущему: санки едут по −Z, видят грань +Z (Back)
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Back
		sg.CanvasSize = Vector2.new(400, 100)
		sg.LightInfluence = 0
		sg.Parent = board
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Text = string.format("%d м", h)
		t.TextScaled = true
		t.Font = Enum.Font.FredokaOne
		t.TextColor3 = Color3.new(1, 1, 1)
		t.TextStrokeTransparency = 0.3
		t.Parent = sg
		m.Parent = parent
	end
end

return Milestones
