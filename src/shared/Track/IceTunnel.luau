-- Ледяной тоннель с кольцами-ускорителями (#44): «момент скорости» перед цепочкой островков. Короткий
-- ледяной жёлоб (два куска "iceTunnel": портал входа и выхода) под ледяным сводом (Track/Tunnel, вид
-- Tunnel.ICE во всех мирах), внутри ICE_TUNNEL_RINGS колец по центру трассы — каждое обычный ускоритель
-- (+BOOST_ADD), между ними монеты по центру, по бортам — лампы. Препятствий нет: игрок держит центр,
-- собирает монеты и разгоняется; дальше разгон островков (ускоритель островков задаёт окно скорости
-- вылета, лишняя скорость прыжок не ломает).
--
--   вид сверху:  ▕ · ◯ · · ◯ · · ◯ · ▏ → разгон островков ⚡
--
-- Куски ставит Profile (в islands(), seg.ice = { half }); здесь — содержимое одного куска.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Props = require(ReplicatedStorage.Shared.Props)

local deco = Props.deco

local IceTunnel = {}

-- cf, len — кусок (половина тоннеля), prof — сечение (жёлоб), kit — make* из Track/Items
function IceTunnel.build(seg, cf: CFrame, len: number, prof, m: Instance, kit)
	local total = Config.ICE_TUNNEL_LEN
	local z0 = (seg.ice.half - 1) * len -- начало куска от входа в тоннель
	local n = math.max(0, math.floor(Config.ICE_TUNNEL_RINGS))
	local rings = {}
	for j = 1, n do
		local z = total * (j - 0.5) / n - z0
		if z >= 0 and z < len then
			kit.boostRing(cf * CFrame.new(0, 0, -z), Config.ICE_TUNNEL_RING_R, m)
		end
		table.insert(rings, total * (j - 0.5) / n)
	end
	-- монеты по центру между кольцами (и до первого), через 6 studs, не ближе 4 к кольцу
	for z = 4, total - 4, 6 do
		local near = false
		for _, rz in rings do
			if math.abs(rz - z) < 4 then
				near = true
			end
		end
		local zl = z - z0
		if not near and zl >= 0 and zl < len then
			kit.coin(cf * CFrame.new(0, 3, -zl), m)
		end
	end
	-- лампы на втором поясе жёлоба с обеих сторон (Neon, без света — свет даёт свод)
	local b1 = prof.banks[1]
	local x = Config.TRACK_WIDTH / 2 + b1.width * math.cos(math.rad(b1.angle))
	local y = b1.width * math.sin(math.rad(b1.angle)) + 1
	for z = Config.ICE_TUNNEL_LAMP_STEP / 2, len, Config.ICE_TUNNEL_LAMP_STEP do
		for _, side in { -1, 1 } do
			deco({ Size = Vector3.new(1.2, 1.2, 3), CFrame = cf * CFrame.new(side * x, y, -z), Material = Enum.Material.Neon, Color = Color3.fromRGB(150, 235, 255) }, m)
		end
	end
end

return IceTunnel
