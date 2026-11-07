-- Сани игрока в заезде (makeSled: сиденье, модель по редкости и тирам, след, ракеты, крепления)
-- и ragdoll после аварии; группа коллизий «Riders» (игроки и сани друг друга не толкают).

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local SledModels = require(ReplicatedStorage.Shared.SledModels)
local Data = require(script.Parent.DataService)

local Sleds = {}

local function setRider(p: Instance)
	if p:IsA("BasePart") then
		p.CollisionGroup = "Riders"
	end
end

local sledsFolder = Instance.new("Folder")
sledsFolder.Name = "Sleds"

local function makeSled(player: Player, cf: CFrame): VehicleSeat
	-- Сиденье — плоская невидимая плита (на ней сидит персонаж и она скользит по льду),
	-- а «ватрушка» — два приваренных декоративных цилиндра
	local seat = Instance.new("VehicleSeat")
	seat.Name = "Sled"
	seat.Size = Vector3.new(5, 1, 5)
	seat.Transparency = 1
	seat.MaxSpeed = 0
	seat.Torque = 0
	seat.TurnSpeed = 0
	seat.HeadsUpDisplay = false
	seat.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0, 0, 100, 100)
	seat.CollisionGroup = "Riders"
	seat.CFrame = cf
	seat.Anchored = true

	local d = Data.get(player)
	-- Тиры апгрейда «Сани»: санки обрастают деталями (как MEGA THRUSTER / AERO TAIL в оригинале)
	local tier = Config.tierOf(d and d.SledLevel or 0)

	-- Корпус: модель саней + редкость (как в каталоге референса). Редкость красит корпус.
	local model = Config.sled(d and d.Sled)
	local rarityIdx = math.clamp(d and d.SledRarity or 1, 1, #Config.RARITIES)
	local rarity = Config.RARITIES[rarityIdx]
	-- цвет: у обычной редкости — фирменные цвета модели, у редких — цвет редкости
	local main = rarity.color or model.main
	local accent = if rarityIdx > 1 then Color3.new(1, 1, 1):Lerp(rarity.color :: Color3, 0.35) else model.accent
	-- Детализированная модель (Shared/SledModels): тор-ватрушка, деревянные санки, доска, самолёт
	SledModels.build(seat, seat.CFrame, model.id, {
		main = main,
		accent = accent,
		material = if rarityIdx > 1 then rarity.material else nil,
		glow = rarityIdx == 5,
		shine = rarity.shine,
	}, seat, rarityIdx > 1)
	if rarityIdx == 5 then
		local glow = Instance.new("PointLight")
		glow.Color = main
		glow.Range = 10
		glow.Parent = seat
	end
	seat:SetAttribute("SledBonus", Config.sledBonus(model.id, rarityIdx))
	-- След: цвет шлейфа за санками (Effects рисует его у всех игроков)
	local trail = Config.trail(d and d.Trail)
	if trail.id ~= "white" then
		seat:SetAttribute("TrailColor", trail.color)
		seat:SetAttribute("Rainbow", trail.rainbow == true)
	end
	-- Боковые ракеты (дизайн по тиру «Ракеты») + обвес по тиру «Саней» — Shared/SledModels
	local rocketTier = Config.tierOf(d and d.RocketLevel or 0)
	local nozzle = SledModels.extras(seat, seat.CFrame, model.id, tier, rocketTier, accent, seat)
	seat:SetAttribute("RocketNozzle", nozzle)
	seat:SetAttribute("RocketTier", math.min(rocketTier, 6))
	if tier >= 5 then -- неон
		local glow = Instance.new("PointLight")
		glow.Color = accent
		glow.Range = 12
		glow.Brightness = 2
		glow.Parent = seat
	end

	-- Ориентация задаётся с клиента (по нормали склона)
	local att = Instance.new("Attachment")
	att.Name = "AlignAttachment"
	att.Parent = seat
	local align = Instance.new("AlignOrientation")
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = att
	align.Responsiveness = 30
	align.MaxTorque = 1e7
	align.CFrame = cf.Rotation
	align.Parent = seat

	local ropeAtt = Instance.new("Attachment")
	ropeAtt.Name = "RopeAttachment"
	ropeAtt.Position = Vector3.new(0, 0, 0)
	ropeAtt.Parent = seat

	seat:SetAttribute("Owner", player.UserId)
	seat.Parent = sledsFolder
	return seat
end

-- Ragdoll: суставы персонажа → шарниры, чтобы он кувыркался после аварии (видно всем)
local function ragdoll(character: Model)
	local hum = character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.BreakJointsOnDeath = false
		hum.RequiresNeck = false
	end
	for _, m in character:GetDescendants() do
		if m:IsA("Motor6D") and m.Part0 and m.Part1 and m.Name ~= "RootJoint" and m.Name ~= "Root" then
			local a0 = Instance.new("Attachment")
			a0.CFrame = m.C0
			a0.Parent = m.Part0
			local a1 = Instance.new("Attachment")
			a1.CFrame = m.C1
			a1.Parent = m.Part1
			local bs = Instance.new("BallSocketConstraint")
			bs.Attachment0 = a0
			bs.Attachment1 = a1
			bs.LimitsEnabled = true
			bs.UpperAngle = 70
			bs.TwistLimitsEnabled = true
			bs.TwistLowerAngle = -45
			bs.TwistUpperAngle = 45
			bs.Parent = m.Parent
			m.Enabled = false
		end
	end
end

-- Группа коллизий и папка саней в workspace — один раз при старте сервера
function Sleds.setup()
	PhysicsService:RegisterCollisionGroup("Riders")
	PhysicsService:CollisionGroupSetCollidable("Riders", "Riders", false)
	sledsFolder.Parent = workspace
end

Sleds.setRider = setRider
Sleds.makeSled = makeSled
Sleds.ragdoll = ragdoll

return Sleds
