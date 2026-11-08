-- 3D-модели транспорта: сани (9 моделей), обвес по тирам, ракеты, рогатка.
-- Корпуса, обвес и ракеты — свои меши (scripts/gen_sled_meshes.py, gen_kit_meshes.py → деплой →
-- ReplicatedStorage.MeshTemplates → MeshPart по цветам); пока шаблонов нет (не загружены, модерация,
-- Config.MESH_SLEDS = 0) — прежние модели из Part: «трубки» из цилиндров с шариками в стыках.
--
-- SledModels.build(parent, base, id, look, weldTo?, painted?) → число деталей
--   base   — CFrame центра саней (центр невидимого сиденья 5×1×5; персонаж сидит на base.Y + 0.5,
--            низ корпуса ≈ base.Y − 0.5…−0.9), «нос» смотрит по −Z
--   look   — { main: Color3, accent: Color3, material: Enum.Material?, glow: boolean?, shine: number? }
--   weldTo — если задан, детали привариваются к нему (санки в заезде), иначе закреплены (витрина)
--
-- Модули: Builder (помощник сборки, Part и MeshPart), Bodies (корпуса из Part), BodyMeshes (корпуса
-- из мешей), Mounts (точки крепления), Kit (обвес по тирам), Rockets (ракеты), Slingshot (рогатка).
-- Этот файл — фасад с прежним API.

local B = require(script.Builder)
local Bodies = require(script.Bodies)
local BodyMeshes = require(script.BodyMeshes)
local Kit = require(script.Kit)
local Rockets = require(script.Rockets)
local Slingshot = require(script.Slingshot)
local Mounts = require(script.Mounts)

local SledModels = {}

SledModels.ROCKETS = Rockets.ROCKETS
SledModels.MOUNTS = Mounts.MOUNTS
SledModels.ROPE_COLORS = Slingshot.ROPE_COLORS
SledModels.ROPE_GLOW = Slingshot.ROPE_GLOW

-- Все меши транспорта (корпуса 9 моделей, обвес, кромки тира 4, ракеты): витрина лобби ждёт их
-- загрузки (Lobby.MESHES), чтобы не показывать сначала Part-модель
SledModels.MESHES = BodyMeshes.names()
for _, n in Kit.MESHES do
	table.insert(SledModels.MESHES, n)
end
for _, s in BodyMeshes.ids() do
	table.insert(SledModels.MESHES, "trim_" .. s)
end
for _, n in Rockets.MESHES do
	table.insert(SledModels.MESHES, n)
end

-- Одна ракета отдельно (витрина апгрейда «Ракета»)
function SledModels.rocket(parent: Instance, base: CFrame, tier: number): Vector3
	local b = B.new(parent, base, nil)
	return Rockets.build(b, Vector3.zero, tier)
end

-- Детали апгрейдов на санках: боковые ракеты по тиру «Ракеты» + обвес по тиру «Саней».
-- Возвращает { x, y, z } сопла правой ракеты (для огня в Effects).
SledModels.extras = Kit.extras

function SledModels.slingshot(parent: Instance, base: CFrame, tier: number)
	Slingshot.build(parent, base, tier)
end

function SledModels.build(parent: Instance, base: CFrame, id: string, look: B.Look, weldTo: BasePart?, painted: boolean?): number
	local b = B.new(parent, base, weldTo)
	b.main = look.main
	b.shine = look.shine or 0
	if not Bodies.BUILDERS[id] then
		id = "tube"
	end
	if BodyMeshes.ready(id) then
		BodyMeshes.build(b, id, look, painted == true)
	else
		Bodies.BUILDERS[id](b, look, painted == true)
	end
	return b.count
end

return SledModels
