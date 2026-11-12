-- Касания санок (часть SledController): авария, разбивание лёгких препятствий, щит, бонусы,
-- гемы, кристалл, ускорители; подбор монет по отрезку пути и магнит (засчитывает сервер).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local st = require(script.Parent.State)

local speedValue = st.speedValue
local fuelValue = st.fuelValue
local fuelMaxValue = st.fuelMaxValue
local rocketOn = st.rocketOn
local magnetLeft = st.magnetLeft
local shieldOn = st.shieldOn
local x2Left = st.x2Left
local sfx = st.sfx
local trickPopup = st.trickPopup
local overlapParams = st.overlapParams

local Contacts = {}

------------------------------------------------------------------ столкновения
-- Тряска камеры (краш, TNT): смещение Humanoid.CameraOffset с затуханием
local function shake(duration: number, power: number)
	local hum = st.humanoid
	if not hum then
		return
	end
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = game:GetService("RunService").RenderStepped:Connect(function()
		local k = 1 - (os.clock() - t0) / duration
		if k <= 0 or not hum.Parent then
			hum.CameraOffset = Vector3.zero
			conn:Disconnect()
			return
		end
		hum.CameraOffset = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * power * k
	end)
end
-- «Замедление» при краше (#57): 0.5 с кадр обесцвечивается и размывается, затем возвращается —
-- ощущение слоу-мо без замедления физики (Roblox не замедляет время)
local function crashSlowmo()
	local Lighting = game:GetService("Lighting")
	local TweenService = game:GetService("TweenService")
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "CrashSlowmo"
	cc.Saturation = -0.5
	cc.Contrast = 0.15
	cc.Parent = Lighting
	local blur = Instance.new("BlurEffect")
	blur.Name = "CrashBlur"
	blur.Size = Config.CRASH_BLUR
	blur.Parent = Lighting
	local info = TweenInfo.new(Config.CRASH_SLOWMO, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(cc, info, { Saturation = 0, Contrast = 0 }):Play()
	TweenService:Create(blur, info, { Size = 0 }):Play()
	game:GetService("Debris"):AddItem(cc, Config.CRASH_SLOWMO + 0.1)
	game:GetService("Debris"):AddItem(blur, Config.CRASH_SLOWMO + 0.1)
end

-- Удар о препятствие: ватрушка кувыркается вперёд и останавливается, заезд окончен
local function crash()
	local s, a = st.sled, st.align
	if not s or st.crashed then
		return
	end
	st.crashed = true
	st.crashTime = os.clock()
	if a then
		a.Enabled = false
	end
	local side = if math.random() < 0.5 then -1 else 1
	s.AssemblyLinearVelocity = st.fwd * math.min(st.speed, 60) * 0.35 + st.fwd:Cross(Vector3.yAxis) * side * 6 + Vector3.new(0, 28, 0)
	s.AssemblyAngularVelocity = Vector3.new(-9, side * 2, side * 5) -- кувырок через «нос»
	-- Персонаж вылетает из санок и кувыркается (суставы-шарниры ставит сервер)
	local hum = st.humanoid
	local root = hum and hum.Parent and hum.Parent:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hum and root then
		local weld = s:FindFirstChild("SeatWeld")
		if weld then
			weld:Destroy()
		end
		hum.Sit = false
		hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
		hum:ChangeState(Enum.HumanoidStateType.Physics)
		root.AssemblyLinearVelocity = st.fwd * math.clamp(st.speed, 25, 70) * 0.8 + Vector3.new(0, 30, 0)
		root.AssemblyAngularVelocity = st.fwd:Cross(Vector3.yAxis) * -8 + Vector3.new(0, side * 3, 0)
	end
	-- Монеты разлетаются вокруг (только эффект)
	local origin = s.Position
	for i = 1, 14 do
		local c = Instance.new("Part")
		c.Shape = Enum.PartType.Cylinder
		c.Size = Vector3.new(0.3, 1.4, 1.4)
		c.Color = Color3.fromRGB(255, 200, 40)
		c.Material = Enum.Material.SmoothPlastic
		c.CanCollide = true
		c.CanQuery = false
		c.CanTouch = false
		c.CollisionGroup = "Riders"
		c.CFrame = CFrame.new(origin + Vector3.new(0, 2, 0)) * CFrame.Angles(math.random() * 6, math.random() * 6, 0)
		c.Parent = workspace
		c.AssemblyLinearVelocity = st.fwd * st.speed * 0.3 + Vector3.new(math.random(-20, 20), math.random(18, 34), math.random(-20, 20))
		c.AssemblyAngularVelocity = Vector3.new(math.random(-10, 10), math.random(-10, 10), math.random(-10, 10))
		game:GetService("Debris"):AddItem(c, 2.5 + i * 0.03)
	end
	st.speed = 0
	rocketOn.Value = false
	speedValue.Value = 0
	trickPopup:Fire("💥 Врезался!")
	sfx:Fire("crash")
	shake(Config.CRASH_SHAKE_TIME, Config.CRASH_SHAKE)
	crashSlowmo()
	Remotes.Crash:FireServer()
end

-- Лёгкие препятствия (снеговик, бочки, конусы…) разлетаются, если врезаться с ракетой или на ускорении
local smashed: { [Instance]: boolean } = {}
local function breakableOf(hit: BasePart): Model?
	local node: Instance? = hit.Parent
	while node and node ~= workspace do
		if node:GetAttribute("Breakable") then
			return node :: Model
		end
		node = node.Parent
	end
	return nil
end
local function smash(model: Model, popup: string?)
	if smashed[model] then
		return
	end
	smashed[model] = true
	local s = st.sled
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.LocalTransparencyModifier = 1
			p.CanTouch = false
			p.CanQuery = false
			-- обломки
			if p.Size.Magnitude > 1.5 and p.Transparency < 1 and s then -- невидимые «шапки» — без обломков
				local chunk = Instance.new("Part")
				chunk.Size = p.Size * 0.45
				chunk.Color = p.Color
				chunk.Material = p.Material
				chunk.CFrame = p.CFrame
				chunk.CanCollide = true
				chunk.CanQuery = false
				chunk.CanTouch = false
				chunk.CollisionGroup = "Riders"
				chunk.Parent = workspace
				chunk.AssemblyLinearVelocity = st.fwd * (st.speed * 0.8 + 10) + Vector3.new(math.random(-18, 18), math.random(15, 35), math.random(-18, 18))
				chunk.AssemblyAngularVelocity = Vector3.new(math.random(-12, 12), math.random(-12, 12), math.random(-12, 12))
				game:GetService("Debris"):AddItem(chunk, 2.5)
			end
		end
	end
	st.speed *= 0.92
	trickPopup:Fire(popup or ("💥 Удар!  +" .. Config.SMASH_COINS))
	sfx:Fire("smash")
	Remotes.Smash:FireServer(model) -- сервер проверит: Breakable своей трассы, рядом, один раз
end

-- Ящик TNT (#66): взрыв от любого удара. Не авария: обломки и монеты как у разбитого (сервер
-- проверит Smash и начислит TNT_COINS), огненный шар (визуальный Explosion без урона), сани
-- подбрасывает вверх (полёт — можно сделать трюк), скорость × TNT_SLOW (щит гасит потерю и
-- остаётся), камера трясётся.
local function explode(model: Model)
	local pos = model:GetPivot().Position
	smash(model, "💥 БАБАХ! TNT  +" .. Config.TNT_COINS)
	local e = Instance.new("Explosion")
	e.Position = pos + Vector3.new(0, 2, 0)
	e.BlastRadius = 0 -- только вид: без толчка и урона
	e.BlastPressure = 0
	e.DestroyJointRadiusPercent = 0
	e.ExplosionType = Enum.ExplosionType.NoCraters
	e.Parent = workspace
	if not shieldOn.Value then
		st.speed *= Config.TNT_SLOW / 0.92 -- smash уже снял 8%
	end
	local sled = st.sled
	if sled then
		local v = sled.AssemblyLinearVelocity
		sled.AssemblyLinearVelocity = Vector3.new(v.X, math.max(v.Y, 0) + Config.TNT_POP, v.Z)
	end
	sfx:Fire("crash")
	shake(Config.TNT_SHAKE_TIME, Config.TNT_SHAKE)
end

local nearCoins: { BasePart } = {}
local COIN_PICK_R = 3.6 -- радиус подбора монеты (по горизонтали)
local function hideLocal(p: BasePart)
	p.LocalTransparencyModifier = 1
	for _, d in p:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = 1
		elseif d:IsA("ParticleEmitter") or d:IsA("Light") then
			d.Enabled = false
		end
	end
end

-- Ледяной кристалл: разлетается осколками, сервер даёт монеты и гем
local crystalDone: { [Instance]: boolean } = {}
local function breakCrystal(hit: BasePart)
	local model = hit.Parent
	if not model or crystalDone[model] then
		return
	end
	crystalDone[model] = true
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") then
			hideLocal(p)
			for _ = 1, 3 do
				local shard = Instance.new("Part")
				shard.Size = Vector3.new(0.8, 1.6, 0.8)
				shard.Color = p.Color
				shard.Material = Enum.Material.Glass
				shard.Transparency = 0.2
				shard.CFrame = p.CFrame
				shard.CanQuery = false
				shard.CanTouch = false
				shard.CollisionGroup = "Riders"
				shard.Parent = workspace
				shard.AssemblyLinearVelocity = st.fwd * st.speed * 0.6 + Vector3.new(math.random(-20, 20), math.random(15, 35), math.random(-20, 20))
				game:GetService("Debris"):AddItem(shard, 2)
			end
		end
	end
	trickPopup:Fire("💎 Кристалл!  +" .. Config.CRYSTAL_COINS .. " 💰 +1 💎")
	sfx:Fire("crystal")
	Remotes.Crystal:FireServer(hit)
end

local function onTouched(hit: BasePart)
	local now = os.clock()
	if CollectionService:HasTag(hit, "Crystal") then
		if st.started and not st.crashed then
			breakCrystal(hit)
		end
		return
	elseif CollectionService:HasTag(hit, "Gem") then
		if hit.LocalTransparencyModifier < 1 then
			hideLocal(hit)
			trickPopup:Fire("💎 +1 гем!")
			sfx:Fire("gem")
		end
		return
	elseif CollectionService:HasTag(hit, "PowerUp") then
		-- Бонусы: щит, x2 монеты, канистра, кольца (монеты и x2 засчитывает сервер)
		if hit.LocalTransparencyModifier < 1 and st.started and not st.crashed then
			hideLocal(hit)
			local kind = hit:GetAttribute("Kind")
			local holder = hit.Parent :: Instance
			if kind ~= "ring" then
				for _, d in holder:GetChildren() do
					if d:IsA("BasePart") and (d.Position - hit.Position).Magnitude < 5 then
						d.LocalTransparencyModifier = 1
					end
				end
			end
			if kind == "shield" or kind == "fuel" then
				Remotes.PowerUp:FireServer(hit) -- для заданий дня
			end
			if kind == "shield" then
				shieldOn.Value = true
				trickPopup:Fire("🛡 Щит!")
				sfx:Fire("shield")
			elseif kind == "fuel" then
				st.fuel = fuelMaxValue.Value
				fuelValue.Value = st.fuel
				trickPopup:Fire("⛽ Полный бак!")
				sfx:Fire("fuel")
			elseif kind == "x2" then
				st.x2Until = now + Config.POWERUPS.x2.time
				trickPopup:Fire("✨ Монеты x2!")
				sfx:Fire("x2")
				Remotes.PowerUp:FireServer(hit)
			elseif kind == "ring" then
				trickPopup:Fire("⭕ Кольцо! +" .. Config.POWERUPS.rings.coins)
				sfx:Fire("ring")
				Remotes.PowerUp:FireServer(hit)
			end
		end
		return
	elseif CollectionService:HasTag(hit, "Magnet") then
		if hit.LocalTransparencyModifier < 1 then
			hideLocal(hit)
			for _, d in (hit.Parent :: Instance):GetChildren() do
				if d:IsA("BasePart") and (d.Position - hit.Position).Magnitude < 4 then
					d.LocalTransparencyModifier = 1
				end
			end
			st.magnetUntil = now + Config.MAGNET_TIME
			Remotes.PowerUp:FireServer(hit) -- для заданий дня
			trickPopup:Fire("🧲 Магнит!")
			sfx:Fire("magnet")
		end
		return
	end
	if CollectionService:HasTag(hit, "Obstacle") then
		if st.crashed or not st.started or now - st.lastObstacle < 0.5 then
			return
		end
		local breakable = breakableOf(hit)
		if breakable then
			if smashed[breakable] then
				return
			end
			if breakable:GetAttribute("Explosive") then
				st.lastObstacle = now
				explode(breakable)
				return
			end
			if rocketOn.Value or now - st.lastBoost < 1.5 then
				smash(breakable)
				return
			end
		end
		st.lastObstacle = now
		if shieldOn.Value then
			-- щит принимает удар: препятствие исчезает, скорость немного падает
			shieldOn.Value = false
			local model = hit:FindFirstAncestorOfClass("Model") or hit
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then
					d.LocalTransparencyModifier = 1
					d.CanCollide = false -- только у себя: санки (их считает клиент) проезжают сквозь
				end
			end
			if model:IsA("BasePart") then
				hideLocal(model)
			end
			st.speed *= 0.75
			trickPopup:Fire("🛡 Щит спас!")
			sfx:Fire("shieldhit")
			return
		end
		crash()
	elseif CollectionService:HasTag(hit, "Boost") then
		if now - st.lastBoost < 0.4 then
			return
		end
		st.lastBoost = now
		Remotes.PowerUp:FireServer(hit) -- для заданий дня
		st.speed += Config.BOOST_ADD
		trickPopup:Fire("⚡ Ускорение!")
		sfx:Fire("boost")
	elseif CollectionService:HasTag(hit, "Coin") then
		if hit.LocalTransparencyModifier < 1 then
			hit.LocalTransparencyModifier = 1 -- мгновенно прячем, сервер засчитает
			for _, detail in hit:GetDescendants() do
				if detail:IsA("BasePart") then
					detail.LocalTransparencyModifier = 1
				elseif detail:IsA("ParticleEmitter") then
					detail.Enabled = false
				end
			end
			sfx:Fire("coin")
		end
	end
end

-- Кадр физики: подбор монет по отрезку пути, магнит, подстраховка касаний движущихся препятствий
function Contacts.scan(s: BasePart, dt: number)
-- Подбор монет по расстоянию: Touched на скорости пропускает тонкие монеты, поэтому
-- проверяем весь отрезок пути санок за кадр (без «туннелирования»); засчитывает сервер
st.coinScan += dt
if st.coinScan > 0.4 then
	st.coinScan = 0
	table.clear(nearCoins)
	for _, coin in CollectionService:GetTagged("Coin") do
		if coin:IsA("BasePart") and coin.LocalTransparencyModifier < 1 and (coin.Position - s.Position).Magnitude < 160 then
			table.insert(nearCoins, coin)
		end
	end
end
if not st.crashed then
	local p0, p1 = st.lastPos or s.Position, s.Position
	local ab = p1 - p0
	local len2 = ab:Dot(ab)
	for i = #nearCoins, 1, -1 do
		local coin = nearCoins[i]
		if coin.LocalTransparencyModifier >= 1 or coin:GetAttribute("Taken") then
			table.remove(nearCoins, i)
			continue
		end
		local p = coin.Position
		local t = if len2 > 0 then math.clamp((p - p0):Dot(ab) / len2, 0, 1) else 0
		local d = p - (p0 + ab * t)
		if Vector3.new(d.X, 0, d.Z).Magnitude < COIN_PICK_R and d.Y > -3 and d.Y < 7 then
			hideLocal(coin)
			Remotes.CoinGrab:FireServer(coin)
			sfx:Fire("coin")
			table.remove(nearCoins, i)
		end
	end
end
st.lastPos = s.Position

-- Магнит: притягиваем монеты рядом (анимация у себя, засчитывает сервер)
local mLeft = math.max(0, st.magnetUntil - os.clock())
magnetLeft.Value = mLeft
x2Left.Value = math.max(0, st.x2Until - os.clock())
if mLeft > 0 and not st.crashed then
	st.magnetScan += dt
	if st.magnetScan > 0.1 then
		st.magnetScan = 0
		for _, coin in CollectionService:GetTagged("Coin") do
			if coin:IsA("BasePart") and coin.LocalTransparencyModifier < 1 and not coin:GetAttribute("Taken")
				and (coin.Position - s.Position).Magnitude < Config.MAGNET_RADIUS then
				hideLocal(coin)
				Remotes.CoinGrab:FireServer(coin)
				sfx:Fire("coin")
				-- летящая к санкам копия монеты
				local ghost = Instance.new("Part")
				ghost.Shape = Enum.PartType.Cylinder
				ghost.Size = Vector3.new(0.45, 3, 3)
				ghost.Color = Color3.fromRGB(255, 196, 45)
				ghost.Anchored = true
				ghost.CanCollide = false
				ghost.CanQuery = false
				ghost.CanTouch = false
				ghost.CFrame = coin.CFrame
				ghost.Parent = workspace
				local target = s
				task.spawn(function()
					local t0 = os.clock()
					while ghost.Parent and os.clock() - t0 < 0.35 do
						local k = (os.clock() - t0) / 0.35
						ghost.CFrame = ghost.CFrame:Lerp(target.CFrame + Vector3.new(0, 2, 0), k)
						task.wait()
					end
					ghost:Destroy()
				end)
			end
		end
	end
end

-- Подстраховка к Touched: машины и кабинки двигаются кадрами (CFrame), касание может не прийти
if st.started and not st.crashed then
	for _, p in workspace:GetPartBoundsInBox(s.CFrame * CFrame.new(0, 1.5, 0), Vector3.new(6, 4, 7), overlapParams) do
		if CollectionService:HasTag(p, "Obstacle") then
			onTouched(p)
			break
		end
	end
end
end

Contacts.onTouched = onTouched
Contacts.hideLocal = hideLocal

return Contacts
