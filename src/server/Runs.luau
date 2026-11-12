-- Заезды: слоты трасс, состояние заезда (runs), старт (startRun, зона посадки у мостика лобби),
-- конец заезда с расчётом наград (endRun), ⟳/BACK и цикл Heartbeat (прогресс, античит,
-- финиш, остановка, падение).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Track = require(ReplicatedStorage.Shared.Track)
local SledModels = require(ReplicatedStorage.Shared.SledModels)
local Data = require(script.Parent.DataService)
local Rewards = require(script.Parent.Rewards)
local Tuning = require(script.Parent.Tuning)
local Analytics = require(script.Parent.Analytics)
local AntiCheat = require(script.Parent.AntiCheat)
local Weekly = require(script.Parent.Weekly)
local Remotes = require(script.Parent.Remotes)
local Sleds = require(script.Parent.Sleds)
local PlayerState = require(script.Parent.PlayerState)
local Ghosts = require(script.Parent.Ghosts) -- призрак рекорда (#62)

local syncPlayer = PlayerState.sync
local postLevel = PlayerState.postLevel
local makeSled = Sleds.makeSled
local StartRun: RemoteEvent = Remotes.StartRun
local RunEnded: RemoteEvent = Remotes.RunEnded
local Restart: RemoteEvent = Remotes.Restart
local Back: RemoteEvent = Remotes.Back
local TaskDone: RemoteEvent = Remotes.TaskDone
local Rescue: RemoteEvent = Remotes.Rescue

local Runs = {}

------------------------------------------------------------------ Слоты трасс (у каждого игрока своя)
local slots: { [number]: Player } = {}
local function takeSlot(player: Player): number
	local i = 0
	while slots[i] do
		i += 1
	end
	slots[i] = player
	return i
end

------------------------------------------------------------------ Заезды
export type Run = {
	track: any,
	slot: number,
	sled: VehicleSeat,
	ropes: { Instance },
	launched: boolean,
	distance: number,
	bonusCoins: number,
	-- части bonusCoins для разбивки чипами в итоге (#71): воздух, трюки, бонусы (разбил/TNT, кольца,
	-- кристалл); остальное в bonusCoins — монеты на трассе (подобранные, с комбо и x2)
	bonusAir: number?,
	bonusTricks: number?,
	bonusExtra: number?,
	bonusMilestones: number?, -- монеты за рубежи дистанции (#61), тоже часть bonusCoins
	milestones: number?, -- сколько рубежей Config.MILESTONES засчитано в этом заезде
	lastTrick: number,
	slowTime: number,
	startTime: number,
	launchTime: number?,
	pullAt: number?, -- начал натягивать рогатку (Launch "pull", идеальный запуск #58)
	perfectLaunch: boolean?, -- идеальный запуск засчитан (× Config.PERFECT_LAUNCH_MULT)
	crashed: boolean?,
	level: number,
	farm: boolean,
	finishedAt: number?,
	smashes: number?,
	airTotal: number?,
	flips: number?,
	tricks: number?, -- всего трюков за заезд (аналитика «Tricks»)
	gems: number?,
	combo: number?,
	x2Until: number?,
	maxCombo: number?,
	maxSpeed: number?,
	boosts: number?,
	boostPads: { [Instance]: boolean }?,
	picked: { [string]: number }?,
	lastCoin: number?,
	crystal: boolean?,
	lastAir: number?,
	ended: boolean?,
	crashedOnTrack: boolean?, -- авария до финишной арки (задания «без аварии»)
	magnetCoins: number?, -- монет притянуто магнитом (задание magnetCoins)
	flags: number?, -- мягкие нарушения античита за заезд (server/AntiCheat)
	ac: any?, -- состояние античита (AntiCheat.start на Launch)
	humanoid: Humanoid, -- персонаж, посаженный в санки на старте (сторож «без персонажа»)
	unseated: number?, -- сек подряд персонажа нет в санках (Config.RUN_UNSEATED_MAX)
	outside: number?, -- сек подряд снаружи невидимого борта (Config.RESCUE_OUT_TIME)
	rescues: number?, -- мягких возвратов за заезд (Config.RESCUE_MAX)
	lastRescue: number?,
}
local runs: { [Player]: Run } = {}
-- Заезд закончен, но санки/трасса ещё не убраны и персонаж не пересоздан (пауза в endRun).
-- Пока игрок здесь, новый заезд не начинаем: иначе отложенный LoadCharacter убьёт новый заезд.
local ending: { [Player]: boolean } = {}

local startRun: (Player) -> ()

-- Новый персонаж в лобби. LoadCharacterAsync может упасть (сбой загрузки внешности) — повторяем;
-- без этого игрок остаётся без персонажа, а камера — на старте трассы.
local function respawn(player: Player)
	for attempt = 1, 3 do
		if not player.Parent then
			return
		end
		local ok, err = pcall(player.LoadCharacterAsync, player)
		if ok and player.Character then
			return
		end
		warn(string.format("[Runs] LoadCharacterAsync %s, попытка %d: %s", player.Name, attempt, tostring(err)))
		task.wait(0.5 * attempt)
	end
end

-- leaving = игрок выходит из игры (PlayerRemoving/BindToClose, #21): начисление и аналитика как
-- обычно, но без окна итогов и без паузы — санки/трасса/слот убираются сразу, персонаж не пересоздаётся.
local function endRun(player: Player, reason: string, leaving: boolean?)
	local run = runs[player]
	if not run or run.ended then
		return
	end
	run.ended = true
	runs[player] = nil
	ending[player] = true

	local d = Data.get(player)
	local level = run.level
	local L = run.track.length
	local finished = reason == "finish"
	local dist = math.min(run.distance, L)
	local pct = math.floor(dist / L * 100)
	-- без итогов и без засчитанного заезда: BACK, ⟳ и «idle» (простоял у рогатки без выстрела, #20)
	local quiet = reason == "back" or reason == "restart" or reason == "idle"
	local cheat = reason == "cheat" -- античит: заезд не засчитан, наград нет
	local clean = not run.crashedOnTrack and reason ~= "fell" -- заезд без аварии
	local mult, earned = 1, 0
	local parts = { track = 0, air = 0, tricks = 0, bonus = 0, milestones = 0, record = 0 } -- разбивка earned чипами (#71)
	local newBest = false
	local gems = 0

	-- Весь расчёт наград — синхронно (без yield) внутри Tuning.forPlayer: Config на это время
	-- настроен под персональные переопределения игрока, затем возвращается общий. Первый yield
	-- в endRun — task.delay ниже, уже после расчёта.
	Tuning.forPlayer(player, function()
		mult = (if player:GetAttribute("X2Coins") then 2 else 1)
			* Config.incomeMult(d and d.IncomeLevel or 0)
			* (1 + Config.trail(d and d.Trail).bonus / 100)
		if cheat then
			return
		end
		local finishCoins = if finished then Config.finishBonus(level) else 0
		earned = math.floor((math.floor(dist / Config.STUDS_PER_COIN) + run.bonusCoins + finishCoins) * mult)
		-- Разбивка только для показа (#71): сумма чипов = earned, сам earned считается как раньше.
		-- «Трасса» = дистанция + подобранные монеты, «Бонусы» = финиш + разбил/кольца/кристалл + округление.
		local air, tricks, extra, miles = run.bonusAir or 0, run.bonusTricks or 0, run.bonusExtra or 0, run.bonusMilestones or 0
		local pickups = math.max(0, run.bonusCoins - air - tricks - extra - miles)
		parts.track = math.floor((math.floor(dist / Config.STUDS_PER_COIN) + pickups) * mult)
		parts.air = math.floor(air * mult)
		parts.tricks = math.floor(tricks * mult)
		parts.milestones = math.floor(miles * mult) -- рубежи дистанции (#61)
		parts.bonus = math.max(0, earned - parts.track - parts.air - parts.tricks - parts.milestones)
		-- Новый рекорд уровня (#59): + (NEW_BEST_COIN_MULT − 1) от монет заезда, только при улучшении
		-- рекорда % (то же условие, что newBest ниже); свой чип «рекорд», сумма чипов = earned
		if d and not run.farm and not finished and not quiet and pct > d.LevelBest then
			parts.record = math.max(0, math.floor(earned * (Config.NEW_BEST_COIN_MULT - 1)))
			earned += parts.record
		end

		if d then
			d.Coins += earned
			if run.farm then
				-- фарм пройденного мира: только монеты и немного гемов, прогресс не двигается
				if finished then
					gems += Config.GEMS_FARM_FINISH
				end
			elseif finished then
				d.Level += 1
				d.LevelBest = 0
				gems += Config.GEMS_FINISH
				postLevel(player, d.Level)
			elseif pct > d.LevelBest and not quiet then
				d.LevelBest = pct
				newBest = true
				gems += Config.GEMS_NEW_BEST
			end
			gems += run.gems or 0
			d.Gems += gems
			-- аналитика: экономика и воронка (docs/METRICS.md)
			d.Stats = d.Stats or {}
			if not quiet then
				d.Stats.Runs = (d.Stats.Runs or 0) + 1
				local w = Config.worldOf(level)
				Analytics.economy(player, "Source", "Coins", earned, d.Coins, Enum.AnalyticsEconomyTransactionType.Gameplay.Name, if finished then "Finish" else "Run", Analytics.fields(w, level, if newBest then "NewBest" else nil))
				Analytics.economy(player, "Source", "Gems", gems, d.Gems, Enum.AnalyticsEconomyTransactionType.Gameplay.Name, if finished then "Finish" else "Run", Analytics.fields(w, level))
				Analytics.custom(player, "RunDistance", math.floor(dist))
				Analytics.custom(player, "RunPercent", pct)
				Analytics.custom(
					player,
					if leaving and reason == "left" then "RunLeft" -- вышел из игры посреди заезда (#21)
						elseif finished then "RunFinished"
						elseif reason == "crash" then "RunCrashed"
						else "RunStopped",
					if leaving and reason == "left" then pct else nil
				)
				if d.Stats.Runs == 1 then
					Analytics.onboarding(player, d, 2)
				elseif d.Stats.Runs == 3 then
					Analytics.onboarding(player, d, 3)
				end
				if finished and not run.farm then
					d.Stats.Finishes = (d.Stats.Finishes or 0) + 1
					Analytics.onboarding(player, d, 5)
					if Config.worldOf(d.Level) >= 2 then
						Analytics.onboarding(player, d, 6)
					end
				end
			end
			local done = Rewards.onRun(player, {
				runs = if quiet then 0 else 1,
				coins = earned,
				distance = math.floor(dist),
				air = math.floor(run.airTotal or 0),
				flips = run.flips or 0,
				smash = run.smashes or 0,
				best = if newBest or (finished and not run.farm) then 1 else 0,
				finish = if finished then 1 else 0,
				distanceRun = math.floor(dist),
				coinsRun = earned,
				combo = run.maxCombo or 0,
				gems = run.gems or 0,
				crystal = if run.crystal then 1 else 0,
				airRun = math.floor(run.airTotal or 0),
				speed = math.floor(run.maxSpeed or 0),
				boosts = run.boosts or 0,
				magnet = run.picked and run.picked.magnet or 0,
				shield = run.picked and run.picked.shield or 0,
				x2 = run.picked and run.picked.x2 or 0,
				fuel = run.picked and run.picked.fuel or 0,
				rings = run.picked and run.picked.ring or 0,
				farm = if run.farm and not quiet then 1 else 0,
				-- новые задания (docs/GAME_DESIGN.md → «Задания дня»)
				cleanFinish = if finished and clean then 1 else 0,
				cleanRun = if clean then math.floor(dist) else 0,
				magnetCoins = run.magnetCoins or 0,
				rareRuns = if not quiet and (d.SledRarity or 1) >= 2 then 1 else 0,
			})
			syncPlayer(player)
			if not leaving then
				for _, text in done do
					TaskDone:FireClient(player, text)
				end
			end
		end
	end)

	-- лидерборд недели: синхронно, только очередь в памяти (фарм и «cheat» не идут, флаги — см. Weekly)
	local week = if d
		then Weekly.onRun(player, {
			level = level,
			dist = dist,
			finished = finished,
			clean = clean,
			farm = run.farm,
			cheat = cheat,
			flags = run.flags,
			elapsed = if run.launchTime then os.clock() - run.launchTime else 0,
		})
		else nil

	-- вышел, ещё не выстрелив (у рогатки): наград нет, но выход виден в воронке
	if leaving and reason == "back" then
		Analytics.custom(player, "RunLeft", 0)
	end

	-- призрак рекорда (#62): заезд лучше сохранённого — сервер просит у клиента запись траектории
	if d and not leaving and not quiet and not cheat then
		Ghosts.onRunEnd(player, run, dist, finished)
	end

	player:SetAttribute("InRun", false)
	player:SetAttribute("Launched", false)
	if leaving then
		run.sled:Destroy()
		run.track:destroy()
		if slots[run.slot] == player then
			slots[run.slot] = nil
		end
		ending[player] = nil
		return
	end
	if reason == "idle" then
		Analytics.custom(player, "RunIdle") -- сел и не понял, как стрелять? (воронка, #20)
		RunEnded:FireClient(player, { reason = "idle", timeout = Config.IDLE_LAUNCH_TIMEOUT })
	elseif not quiet then
		RunEnded:FireClient(player, {
			reason = reason,
			percent = if finished then 100 else pct,
			coins = earned,
			bonus = if cheat then 0 else math.floor(run.bonusCoins * mult),
			distance = math.floor(dist),
			length = L,
			level = level,
			newBest = newBest,
			mult = math.floor(mult * 100 + 0.5) / 100,
			gems = gems,
			week = week,
			parts = parts, -- { track, air, tricks, bonus, milestones, record }: чипы итога (#71, #61, #59), в сумме = coins
			milestones = run.milestones or 0, -- рубежей пройдено (#61)
		})
	end

	-- Любой конец заезда (finish, crash, fell, stopped, cheat, left, back, restart): санки и трасса
	-- убираются, персонаж пересоздаётся в лобби. Новый заезд не начнётся, пока персонаж не
	-- пересоздан: раньше `ending` снимался ДО LoadCharacterAsync, и тап «Играть»/зона посадки во
	-- время загрузки сажали в новые санки старого персонажа — он тут же удалялся, и игрок оставался
	-- на старте трассы без персонажа, только с санками (баг «без игрока — только сани»).
	task.delay(if finished then 2.5 elseif quiet then 0.1 else 1.5, function()
		run.sled:Destroy()
		run.track:destroy()
		if slots[run.slot] == player then
			slots[run.slot] = nil
		end
		respawn(player)
		ending[player] = nil
		if reason == "restart" and player.Parent then
			task.wait(0.3)
			startRun(player)
		end
	end)
end

-- Вердикт античита «kill»: заезд заканчивается как "cheat" (без наград), событие в аналитику
local function antiCheatVerdict(player: Player, run: Run, verdict: string?)
	if verdict == "kill" and runs[player] == run and not run.ended then
		Analytics.custom(player, "AntiCheatFlag", run.flags or 0)
		endRun(player, "cheat")
	end
end

startRun = function(player: Player)
	if runs[player] or ending[player] or not player:GetAttribute("Loaded") then
		return
	end
	local d = Data.get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not d or not character or not humanoid or humanoid.Health <= 0 or not character:FindFirstChild("HumanoidRootPart") then
		return
	end

	-- Какой уровень едем: текущий или (фарм) последний уровень пройденного мира
	local farmWorld = d.FarmWorld or 0
	-- владелец игры может «фармить» и ещё не открытые миры — для проверки новых миров
	local farm = farmWorld > 0 and (farmWorld < Config.worldOf(d.Level) or player.UserId == game.CreatorId)
	local level = if farm then Config.farmLevel(farmWorld) else d.Level
	local slot = takeSlot(player)
	-- Генерация трассы читает Config (ряды препятствий, шансы, старт без препятствий) синхронно —
	-- строим по персональным настройкам игрока (Tuning.forPlayer); достройка — в Heartbeat ниже
	local track = Tuning.forPlayer(player, function()
		return Track.new(slot, level, if farm then 0 else d.LevelBest / 100 * Config.levelLength(d.Level))
	end)
	player:SetAttribute("RunTheme", Config.themeOf(level))
	-- уровень заезда (с фармом — уровень пройденного мира): HUD строит по нему профиль для баннеров
	-- зон и показывает на шкале аватары тех, кто едет тот же уровень (#71; RunDistance/LevelLength
	-- игроков реплицируются всем)
	player:SetAttribute("RunLevel", level)
	player:SetAttribute("LevelLength", track.length)
	player:SetAttribute("RunOrigin", track.origin.Position) -- начало трассы: от него пишется и играется призрак (#62)
	local startCF = track:startCFrame()
	local sled = makeSled(player, startCF)

	-- Тиры рогатки: свой детализированный столб на каждый тир (Shared/SledModels.slingshot)
	local ltier = math.min(Config.tierOf(d.LaunchLevel), 10)
	for _, post in track.posts do
		local old = post:FindFirstChild("Look")
		if old then
			old:Destroy()
		end
		local look = Instance.new("Folder")
		look.Name = "Look"
		look.Parent = post
		SledModels.slingshot(look, post.CFrame, ltier)
	end
	local ropeColor = SledModels.ROPE_COLORS[ltier + 1]

	-- Резинка рогатки: «витая» верёвка — чередующиеся светлые и тёмные полосы вдоль луча
	local RAINBOW = { Color3.fromRGB(240, 70, 70), Color3.fromRGB(255, 160, 50), Color3.fromRGB(255, 225, 60), Color3.fromRGB(90, 210, 90), Color3.fromRGB(70, 160, 255), Color3.fromRGB(150, 90, 240) }
	local keys = {}
	for i = 0, 18 do
		local c = if ltier == 9 then RAINBOW[(i % #RAINBOW) + 1]
			elseif i % 2 == 0 then ropeColor
			else ropeColor:Lerp(Color3.new(0, 0, 0), if SledModels.ROPE_GLOW[ltier] then 0.15 else 0.35)
		table.insert(keys, ColorSequenceKeypoint.new(i / 18, c))
	end
	local twisted = ColorSequence.new(keys)
	local ropes = {}
	for _, post in track.posts do
		local beam = Instance.new("Beam")
		beam.Attachment0 = post.RopeAttachment
		beam.Attachment1 = sled.RopeAttachment
		-- резинка толще и ярче с каждым тиром
		local w = 0.5 + ltier * 0.04
		beam.Width0 = w
		beam.Width1 = w
		beam.Color = twisted
		beam.LightInfluence = if SledModels.ROPE_GLOW[ltier] then 0.3 else 1
		beam.LightEmission = if SledModels.ROPE_GLOW[ltier] then 0.6 else 0
		beam.FaceCamera = true
		beam.Segments = 1
		beam.Parent = sled
		table.insert(ropes, beam)
	end

	character:PivotTo(startCF * CFrame.new(0, 3, 0))
	sled:Sit(humanoid)

	local run: Run = {
		track = track,
		slot = slot,
		sled = sled,
		ropes = ropes,
		level = level,
		farm = farm,
		launched = false,
		distance = 0,
		bonusCoins = 0,
		lastTrick = 0,
		slowTime = 0,
		startTime = os.clock(),
		humanoid = humanoid,
	}
	runs[player] = run
	player:SetAttribute("InRun", true)
	player:SetAttribute("Launched", false)
	player:SetAttribute("RunDistance", 0)
	player:SetAttribute("RunCoins", 0)
	player:SetAttribute("RunMilestone", 0) -- последний пройденный рубеж, м (#61)
	player:SetAttribute("Finished", false)
	player:SetAttribute("RunGems", 0)
	player:SetAttribute("Combo", 0)

	sled:GetPropertyChangedSignal("Occupant"):Connect(function()
		-- при аварии персонаж вылетает из санок сам — это не «вышел»
		if not sled.Occupant and not run.crashed then
			-- в первые секунды у рогатки (ещё не запущен) персонаж мог соскочить случайно —
			-- сажаем обратно, а не обрываем заезд с «0 м»
			if not run.launched and os.clock() - run.startTime < 3 and humanoid.Parent and humanoid.Health > 0 then
				task.defer(function()
					if runs[player] == run and not sled.Occupant then
						sled:Sit(humanoid)
					end
				end)
				return
			end
			endRun(player, "left")
		end
	end)
end
Runs.startRun = startRun

Runs.runs = runs
Runs.slots = slots
Runs.ending = ending
Runs.endRun = endRun
Runs.antiCheatVerdict = antiCheatVerdict

-- Ремоуты старта/выхода и зона посадки
function Runs.start()
	StartRun.OnServerEvent:Connect(startRun)

	-- Мостик лобби ведёт к старту трассы: впереди видна «витринная» трасса, а на краю мостика —
	-- зона посадки. Шагнул в неё — садишься в свои санки у рогатки (как в Roblox-референсе).
	-- Сама витринная трасса — трасса текущего мира игрока — строится у каждого локально
	-- (client/LobbyScene, Config.LOBBY_PREVIEW_SEGMENTS); сервер держит только невидимый пол под
	-- стартовой площадкой (опора персонажа одинаковая у всех) и зону посадки.
	do
		local previewOrigin = CFrame.new(Config.LOBBY_POS + Vector3.new(0, 0, -70))
		local floor = Instance.new("Part")
		floor.Name = "PreviewFloor"
		floor.Anchored = true
		floor.Transparency = 1
		floor.CanQuery = false
		floor.CastShadow = false
		floor.Size = Vector3.new(Config.TRACK_WIDTH + 56, 4, 30)
		floor.CFrame = previewOrigin * CFrame.new(0, -2.05, 15) -- чуть ниже видимого пола витрины
		floor.Parent = workspace
		local pad = Instance.new("Part")
		pad.Name = "LaunchPad"
		pad.Anchored = true
		pad.CanCollide = false
		pad.CanQuery = false
		pad.Transparency = 1
		pad.Size = Vector3.new(60, 8, 12)
		pad.CFrame = previewOrigin * CFrame.new(0, 4, 6)
		pad.Parent = workspace
		-- светящееся кольцо на снегу, куда шагать
		local ring = Instance.new("Part")
		ring.Name = "LaunchRing"
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CanTouch = false
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.2, 12, 12)
		ring.Material = Enum.Material.Neon
		ring.Color = Color3.fromRGB(90, 220, 255)
		ring.Transparency = 0.35
		ring.CFrame = previewOrigin * CFrame.new(0, 0.6, 7) * CFrame.Angles(0, 0, math.rad(90))
		ring.Parent = workspace
		local cooldown: { [Player]: number } = {}
		pad.Touched:Connect(function(hit)
			local character = hit:FindFirstAncestorOfClass("Model")
			local player = character and Players:GetPlayerFromCharacter(character)
			if not player or runs[player] or (cooldown[player] and os.clock() - cooldown[player] < 3) then
				return
			end
			cooldown[player] = os.clock()
			startRun(player)
		end)
	end

	Restart.OnServerEvent:Connect(function(player)
		local run = runs[player]
		if run and not run.ended then
			endRun(player, "restart")
		end
	end)
	Back.OnServerEvent:Connect(function(player)
		local run = runs[player]
		if run and not run.launched and not run.ended then
			endRun(player, "back")
		end
	end)
end

-- Страховка «мягкий возврат» (Config.RESCUE_*): сани провалились ниже дна куска, ушли за барьер
-- или катятся снаружи невидимого борта (сугроб после жёлоба) — клиенту (у него физика саней)
-- уходит Rescue с точкой на дне куска. Над пропастью островков и на озере точки нет (nil) —
-- там падение остаётся концом заезда «fell». Ответ: вернули ли.
local function rescueCheck(player: Player, run: Run, x: number, y: number, step: number): boolean
	local track = run.track
	local seg = track.segments[track.hint]
	-- вбок — от края ходовой части куска (у развилки #42 она шире: до края моста, Track.floorSpan)
	local out = track:sideOut(x)
	local outside = seg ~= nil and not seg.chute and seg.kind ~= "lake" and out > Config.WALL_OFFSET + 2
	run.outside = if outside then (run.outside or 0) + step else 0
	local need = y < -Config.RESCUE_DEPTH or out > Config.RESCUE_SIDE or (run.outside or 0) >= Config.RESCUE_OUT_TIME
	if not need or (run.rescues or 0) >= Config.RESCUE_MAX then
		return false
	end
	if run.lastRescue and os.clock() - run.lastRescue < 1 then
		return true -- ждём, пока клиент переставит сани (пинг)
	end
	local cf = track:rescueCFrame(run.sled.Position)
	if not cf then
		return false
	end
	run.rescues = (run.rescues or 0) + 1
	run.lastRescue = os.clock()
	run.outside = 0
	Rescue:FireClient(player, cf, Config.RESCUE_SPEED_KEEP)
	Analytics.custom(player, "RunRescued", run.rescues)
	return true
end

-- Рубежи дистанции (#61, Config.MILESTONES): путь, засчитанный античитом (run.distance), прошёл
-- очередной рубеж — один раз за заезд монеты в bonusCoins (чип «рубежи»), атрибут RunMilestone (м) —
-- клиенту на всплывашку и звук. Рубеж ближе FINISH_GAP к финишу не считается (как и арка в Track/Milestones).
-- Вызывать внутри Tuning.forPlayer.
local function milestoneCheck(player: Player, run: Run, length: number)
	local M = Config.MILESTONES
	if M.STEP <= 0 then
		return
	end
	local k = (run.milestones or 0) + 1
	while run.distance >= k * M.STEP and length - k * M.STEP >= M.FINISH_GAP do
		local add = if M.BIG_EVERY > 0 and k % M.BIG_EVERY == 0 then M.BIG_COINS else M.COINS
		run.milestones = k
		run.bonusCoins += add
		run.bonusMilestones = (run.bonusMilestones or 0) + add
		player:SetAttribute("RunCoins", (player:GetAttribute("RunCoins") or 0) + add)
		player:SetAttribute("RunMilestone", k * M.STEP)
		k += 1
	end
end

------------------------------------------------------------------ Цикл: прогресс, остановка, финиш
function Runs.startLoop()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.2 then
			return
		end
		local step = acc
		acc = 0

		-- Упал с площадки лобби (не в заезде) — возвращаем на точку появления. Пока заезд
		-- заканчивается (ending), персонаж ещё сидит в санках заезда: его не трогаем — PivotTo
		-- перенёс бы в лобби и сани (одна сборка), а через миг его всё равно пересоздаст endRun.
		for _, p in Players:GetPlayers() do
			if not runs[p] and not ending[p] then
				local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root and root.Position.Y < Config.LOBBY_POS.Y - 30 then
					p.Character:PivotTo(CFrame.new(Config.LOBBY_POS + Vector3.new(0, 4, 0)))
				end
			end
		end

		for player, run in runs do
			local sled = run.sled
			if not sled.Parent then
				endRun(player, "left")
				continue
			end
			-- Сторож «без персонажа»: персонаж заезда удалён/пересоздан/мёртв или не сидит в санках
			-- дольше RUN_UNSEATED_MAX (Occupant мог не смениться) — заезд окончен, сани убираются
			if not run.crashed then
				local hum = run.humanoid
				local alive = hum.Parent ~= nil and hum.Health > 0 and player.Character == hum.Parent
				if alive and sled.Occupant == hum then
					run.unseated = 0
				else
					run.unseated = (run.unseated or 0) + step
					if not alive or run.unseated >= Config.RUN_UNSEATED_MAX then
						endRun(player, "left")
						continue
					end
				end
			end
			local track = run.track
			local pos = sled.Position
			local h, x, y = track:progressOf(pos)
			-- путь засчитывается не быстрее предела скорости; телепорт/накрутка → вердикт (server/AntiCheat)
			local verdict = Tuning.forPlayer(player, function()
				local v = AntiCheat.tick(run, player, pos, step, h)
				track:ensureAround(math.max(0, run.distance)) -- синхронно; Config под игрока (см. startRun)
				return v
			end)
			if verdict == "kill" then
				antiCheatVerdict(player, run, verdict)
				continue
			end
			player:SetAttribute("RunDistance", math.floor(math.min(run.distance, track.length)))
			run.maxSpeed = math.max(run.maxSpeed or 0, sled.AssemblyLinearVelocity.Magnitude * Config.KMH_PER_STUD) -- км/ч, как на спидометре

			if not run.launched then
				-- AFK у рогатки (#20): иначе трасса (ensureAround), слот и санки держатся бесконечно
				local idle = Config.IDLE_LAUNCH_TIMEOUT
				if not run.crashed and idle > 0 and os.clock() - run.startTime > idle then
					endRun(player, "idle")
				end
				continue
			end
			if run.crashed then
				continue
			end
			Tuning.forPlayer(player, function()
				milestoneCheck(player, run, track.length)
			end)
			if run.distance >= track.length and not run.finishedAt then
				-- Финишная арка пройдена: дальше скользим по ледяному озеру до остановки
				run.finishedAt = os.clock()
				player:SetAttribute("Finished", true)
			end
			if run.finishedAt then
				local slow = sled.AssemblyLinearVelocity.Magnitude < Config.STOP_SPEED * 2
				if slow or os.clock() - run.finishedAt > Config.FINISH_GLIDE_MAX then
					endRun(player, "finish")
				end
			elseif y < -Config.FELL_DEPTH or math.abs(x) > Config.TRACK_WIDTH * 2 then
				endRun(player, "fell")
			elseif rescueCheck(player, run, x, y, step) then
				continue -- вернули на трассу: остановку этого тика не считаем
			else
				-- Первые 2 секунды после выстрела не считаем (передача управления по сети)
				if os.clock() - (run.launchTime or 0) > 2 and sled.AssemblyLinearVelocity.Magnitude < Config.STOP_SPEED then
					run.slowTime += step
				else
					run.slowTime = 0
				end
				if run.slowTime >= Config.STOP_TIME or os.clock() - run.startTime > 240 then
					endRun(player, "stopped")
				end
			end
		end
	end)
end

-- Игрок выходит из игры посреди заезда (#21): общий путь endRun — начисляется честно заработанное
-- (дистанция + собранные монеты/гемы + прогресс заданий и рекорда %, без финиш-бонуса), аналитика
-- RunLeft и экономика; санки/трасса/слот убираются сразу. Финишная арка уже пройдена — это финиш.
-- Не выстрелил — "back" (наград нет). Вызывать ДО Data.release (расчёт в endRun синхронный).
local function leaveRun(player: Player)
	local run = runs[player]
	if run and not run.ended then
		local reason = if run.finishedAt then "finish" elseif run.launched and not run.crashed then "left"
			elseif run.crashed then "crash"
			else "back"
		local ok, err = pcall(endRun, player, reason, true)
		if not ok then
			warn("[Runs] endRun при выходе " .. player.Name .. ": " .. tostring(err))
		end
	end
	-- страховка: если endRun упал — всё равно убрать санки/трассу/слот
	run = runs[player]
	if run then
		runs[player] = nil
		pcall(function()
			run.sled:Destroy()
			run.track:destroy()
		end)
		slots[run.slot] = nil
	end
	ending[player] = nil
end

function Runs.onLeave(player: Player)
	leaveRun(player)
end

-- Сервер закрывается (BindToClose): закончить все заезды до сохранения профилей
function Runs.endAll()
	for player in runs do
		leaveRun(player)
	end
end

return Runs
