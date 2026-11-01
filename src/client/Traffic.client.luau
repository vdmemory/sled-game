-- Движение машин, поездов и кабинок канатки. Сервер ставит модели и пишет в атрибуты маршрут,
-- а здесь каждый кадр считаем позицию по серверному времени: у всех игроков машины
-- в одних и тех же местах, а движение плавное (без рывков сетевой репликации).

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

type Mover = {
	model: Model,
	path: CFrame,
	laneZ: number,
	dir: number,
	yawCF: CFrame,
	speed: number,
	loop: number,
	phase: number,
}

local movers: { [Model]: Mover } = {}

local function add(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local path = model:GetAttribute("Path")
	if typeof(path) ~= "CFrame" then
		return
	end
	movers[model] = {
		model = model,
		path = path,
		laneZ = model:GetAttribute("LaneZ") or 0,
		dir = model:GetAttribute("Dir") or 1,
		yawCF = CFrame.Angles(0, model:GetAttribute("Yaw") or 0, 0),
		speed = model:GetAttribute("Speed") or 40,
		loop = model:GetAttribute("Loop") or 360,
		phase = model:GetAttribute("Phase") or 0,
	}
end

CollectionService:GetInstanceAddedSignal("Mover"):Connect(add)
CollectionService:GetInstanceRemovedSignal("Mover"):Connect(function(model)
	movers[model :: Model] = nil
end)
for _, m in CollectionService:GetTagged("Mover") do
	add(m)
end

RunService.RenderStepped:Connect(function()
	local t = workspace:GetServerTimeNow()
	for model, mv in movers do
		if not model.Parent then
			movers[model] = nil
			continue
		end
		local s = ((t * mv.speed + mv.phase) % mv.loop) - mv.loop / 2
		model:PivotTo(mv.path * CFrame.new(s * mv.dir, 0, mv.laneZ) * mv.yawCF)
	end
end)
