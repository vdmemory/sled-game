-- Детализированные 3D-модели саней из примитивов Roblox (без загрузки мешей —
-- работает с автодеплоем). Плавные формы собираются из «трубок»: цилиндры между
-- точками + шарики в стыках, поэтому тор ватрушки и изогнутые полозья выглядят гладкими.
--
-- SledModels.build(parent, base, id, look, weldTo?)
--   base   — CFrame центра саней (низ корпуса ≈ base.Y − 0.5), «нос» смотрит по −Z
--   look   — { main: Color3, accent: Color3, material: Enum.Material?, glow: boolean? }
--   weldTo — если задан, детали привариваются к нему (санки в заезде), иначе закреплены (витрина)
--
-- Модули: Builder (помощник сборки), Bodies (корпуса из Part), Mounts (точки крепления),
-- Kit (обвес по тирам), Rockets (ракеты), Slingshot (рогатка). Этот файл — фасад с прежним API.

local B = require(script.Builder)
local Bodies = require(script.Bodies)
local Kit = require(script.Kit)
local Rockets = require(script.Rockets)
local Slingshot = require(script.Slingshot)
local Mounts = require(script.Mounts)

local SledModels = {}

SledModels.ROCKETS = Rockets.ROCKETS
SledModels.MOUNTS = Mounts.MOUNTS
SledModels.ROPE_COLORS = Slingshot.ROPE_COLORS
SledModels.ROPE_GLOW = Slingshot.ROPE_GLOW

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
	local fn = Bodies.BUILDERS[id] or Bodies.BUILDERS.tube
	fn(b, look, painted == true)
	return b.count
end

return SledModels
