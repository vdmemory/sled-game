-- Точки крепления обвеса и ракет на каждой модели саней (кадр саней: +Z назад, нос по −Z,
-- центр сиденья — 0; персонаж сидит на верху невидимого сиденья 5×1×5).

local Mounts = {}

-- Где у каждой модели саней крепятся ракеты (x, y, z — правая), фары (lights — правая, на поверхности
-- носа, не внутри корпуса), задние габариты (tail — правый, сзади по борту, видны с камеры, #33)
-- и неоновые полосы (neon — x полосы по борту). Проверено по мешам и Part-моделям: ничего не утопает
-- в корпусе и не закрывает персонажа (scripts/preview_sleds.py).
local MOUNTS = {
	tube = { x = 3.95, y = 0.3, z = 0.6, lights = Vector3.new(1.15, 1.1, -3.25), tail = Vector3.new(1.25, 1.15, 2.62), neon = 3.0 },
	classic = { x = 2.25, y = 0.45, z = 0.6, lights = Vector3.new(1.4, 0.95, -2.55), tail = Vector3.new(1.6, 0.85, 4.02) },
	board = { x = 1.5, y = -0.15, z = 0.3, lights = Vector3.new(0.85, 0.08, -3.15), tail = Vector3.new(0.7, 0.07, 3.55) },
	plane = { x = 2.75, y = -0.2, z = 0.3, lights = Vector3.new(2.2, -0.3, -1.3), tail = Vector3.new(1.6, 0.66, 4.95), onWing = true },
	saucer = { x = 2.85, y = -0.15, z = 0.3, lights = Vector3.new(0.9, 0.15, -2.55), tail = Vector3.new(0.9, 0.05, 2.6) },
	toboggan = { x = 1.45, y = -0.15, z = 0.8, lights = Vector3.new(0.8, 1.2, -4.05), tail = Vector3.new(1.0, -0.28, 3.25) },
	kayak = { x = 1.25, y = -0.05, z = 1.0, lights = Vector3.new(0.42, 0.82, -3.2), tail = Vector3.new(0.3, 0.6, 3.4) },
	bobsled = { x = 1.55, y = 0.05, z = 0.8, lights = Vector3.new(0.65, 0.35, -3.55), tail = Vector3.new(1.05, 0.45, 3.34) },
	snowmobile = { x = 1.0, y = -0.1, z = 1.3, lights = Vector3.new(0.6, 0.25, -3.3), tail = Vector3.new(0.75, -0.05, 3.0) },
}

-- Где у моделей спойлер (тир 2), обтекатель (тир 3) и золотой бампер (тир 4): { z, y }.
-- Нет записи — деталь этой модели не нужна (у самолёта и снегохода своё стекло и хвост).
local SPOILER = {
	tube = { 3.55, 1.1 }, classic = { 3.7, 1.0 }, board = { 3.3, 0.0 }, saucer = { 2.9, 0.1 },
	toboggan = { 3.3, 0.3 }, kayak = { 3.7, 0.5 }, bobsled = { 3.4, 0.7 }, snowmobile = { 3.0, 0.5 },
}
local SHIELD = {
	tube = { -3.4, 1.4 }, classic = { -2.5, 1.25 }, board = { -2.4, 0.35 }, saucer = { -2.4, 0.45 },
	toboggan = { -2.5, 0.65 }, kayak = { -1.3, 1.05 },
}
local BUMPER = {
	classic = { -3.0, 0.0 }, board = { -3.6, -0.25 }, saucer = { -2.95, -0.3 }, toboggan = { -3.15, -0.3 },
	kayak = { -4.2, -0.2 }, bobsled = { -4.25, -0.3 }, snowmobile = { -3.75, -0.35 }, plane = { -2.9, 0.0 },
}
Mounts.MOUNTS = MOUNTS
Mounts.SPOILER = SPOILER
Mounts.SHIELD = SHIELD
Mounts.BUMPER = BUMPER

return Mounts
