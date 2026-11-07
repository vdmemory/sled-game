-- Табло лидеров в лобби (#26) и титулы над головой. Только отображение: данные ставит server/Weekly —
--   ReplicatedStorage.WeeklyBoard — JSON { week, reset, boards = { w<N> | clean | all = { { id, n, v } } } };
--   Player.WeeklyMe — JSON моих очков и мест (вне первой сотни — места нет);
--   Player.Title / TitleUntil — титул топ-3 прошлой недели (Config.WEEKLY.TITLES).
-- Табло листает страницы раз в WEEKLY.PAGE_SEC: неделя моего мира → чистые финиши → всё время.
-- Текст табло меняется локально (у каждого своя страница мира и своя строка «ты»).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local UI = require(ReplicatedStorage.Shared.UIKit)

local player = Players.LocalPlayer
local W = Config.WEEKLY

local function decode(s: any): any
	if typeof(s) ~= "string" then
		return nil
	end
	local ok, r = pcall(HttpService.JSONDecode, HttpService, s)
	return if ok then r else nil
end

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function esc(s: string): string
	return (string.gsub(s, "[<>&]", { ["<"] = "&lt;", [">"] = "&gt;", ["&"] = "&amp;" }))
end

local function titleOf(p: Player): any?
	local id, untilT = p:GetAttribute("Title"), p:GetAttribute("TitleUntil")
	if typeof(id) ~= "string" or id == "" or typeof(untilT) ~= "number" or untilT <= serverNow() then
		return nil
	end
	for _, t in W.TITLES do
		if t.id == id then
			return t
		end
	end
	return nil
end

------------------------------------------------------------------ табло
local PAGES = { "week", "clean", "all" }

local function fmt(kind: string, v: number): string
	if kind == "week" then
		return tostring(math.floor(v)) .. " м"
	elseif kind == "clean" then
		return tostring(v) .. " ✔"
	end
	return "ур. " .. v
end

local function boardLoop()
	local lobby = workspace:WaitForChild("Lobby", 60)
	local board = lobby and lobby:WaitForChild("Leaderboard", 30)
	if not board then
		return
	end
	local head = board:FindFirstChild("Head", true) :: TextLabel?
	local list = board:FindFirstChild("List", true) :: TextLabel?
	local me = board:FindFirstChild("Me", true) :: TextLabel?
	if not (head and list and me) then
		return
	end
	list.RichText = true
	local page, shown = 1, 0
	while board.Parent do
		local pub = decode(ReplicatedStorage:GetAttribute("WeeklyBoard")) or {}
		local mine = decode(player:GetAttribute("WeeklyMe")) or {}
		local kind = PAGES[page]
		local id, myV, myR
		if kind == "week" then
			id, myV, myR = "w" .. (mine.w or 1), mine.dist, mine.distRank
			head.Text = "🏆 Неделя · " .. (mine.wn or Config.worldName(mine.w or 1))
		elseif kind == "clean" then
			id, myV, myR = "clean", mine.clean, mine.cleanRank
			head.Text = "✨ Чистые финиши недели"
		else
			id, myV, myR = "all", mine.level, mine.levelRank
			head.Text = "⭐ Всё время · уровень"
		end
		local lines = {}
		for i, e in (pub.boards and pub.boards[id]) or {} do
			local line = string.format("%d. %s — %s", i, esc(tostring(e.n)), fmt(kind, tonumber(e.v) or 0))
			table.insert(lines, if e.id == player.UserId then '<font color="#FFDC5A">' .. line .. "</font>" else line)
		end
		list.Text = if #lines > 0 then table.concat(lines, "\n") else "Пока пусто — будь первым!"
		local place = if myR then "#" .. myR elseif (myV or 0) > 0 then "100+" else "—"
		local t = titleOf(player)
		local text = (if t then t.icon .. " " else "") .. "ты: " .. place .. " · " .. fmt(kind, myV or 0)
		if kind ~= "all" and typeof(pub.reset) == "number" then
			local left = math.max(0, math.floor(pub.reset - serverNow()))
			text ..= string.format("  ·  ⏳ %dд %dч %dм", left // 86400, (left % 86400) // 3600, (left % 3600) // 60)
		end
		me.Text = text
		task.wait(1)
		shown += 1
		if shown >= W.PAGE_SEC then
			shown, page = 0, page % #PAGES + 1
		end
	end
end
task.spawn(boardLoop)

------------------------------------------------------------------ титул над головой (только в лобби)
local tags: { [Player]: BillboardGui } = {}

local function makeTag(t: any): BillboardGui
	local bb = Instance.new("BillboardGui")
	bb.Name = "TitleTag"
	bb.Size = UDim2.fromOffset(170, 30)
	bb.StudsOffset = Vector3.new(0, 2.6, 0)
	bb.MaxDistance = 80
	bb.LightInfluence = 0
	bb.ResetOnSpawn = false
	bb:SetAttribute("Id", t.id)
	local pill = UI.new("TextLabel", { Text = t.icon .. " " .. t.name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0, Parent = bb })
	local k = UI.KIND[t.kind] or UI.KIND.yellow
	UI.grad(pill, k[1], k[2])
	UI.corner(pill, 1000)
	UI.stroke(pill, 2, UI.C.white).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	UI.outline(pill, 1.5)
	UI.pad(pill, 4)
	return bb
end

local function clearTag(p: Player)
	if tags[p] then
		tags[p]:Destroy()
		tags[p] = nil
	end
end
Players.PlayerRemoving:Connect(clearTag)

local playerGui = player:WaitForChild("PlayerGui")
while true do
	for _, p in Players:GetPlayers() do
		local t = titleOf(p)
		local headPart = p.Character and p.Character:FindFirstChild("Head")
		if t and headPart and not p:GetAttribute("InRun") then
			local tag = tags[p]
			if not tag or tag:GetAttribute("Id") ~= t.id then
				clearTag(p)
				tag = makeTag(t)
				tags[p] = tag
			end
			tag.Adornee = headPart
			tag.Parent = playerGui
		else
			clearTag(p)
		end
	end
	task.wait(0.5)
end
