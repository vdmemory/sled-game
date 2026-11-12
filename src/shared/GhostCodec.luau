-- Призрак рекорда (#62): сжатие записи траектории в строку и обратно. Общий для клиента (пишет
-- и проигрывает) и сервера (проверяет и хранит в DataStore Ghost_v1).
--
-- Запись — последовательность сэмплов раз в Config.GHOST_SAMPLE_DT с момента выстрела рогатки.
-- Сэмпл = позиция саней относительно начала трассы (Track.origin; слот игрока на сервере может
-- быть другим — запись от него не зависит) + рыскание (yaw, направление носа по горизонтали).
-- Квантование: позиция — шаг Config.GHOST_POS_Q studs, yaw — 1/256 оборота. Хранятся разности
-- целых соседних сэмплов (у первого — от нуля): ошибка не накапливается, разности маленькие.
-- Каждое целое — zigzag (знак в младший бит) и varint по 5 бит на символ: символ — 6 бит
-- (5 бит значения + бит «продолжение»), алфавит base64url «A–Z a–z 0–9 - _» — валидный UTF-8 и
-- без экранирования в JSON (DataStore хранит значение как JSON-строку).
-- Типичный сэмпл — 6–8 символов: заезд 40 с ≈ 270 сэмплов ≈ 2 КБ; потолок — Config.GHOST_MAX_*.

local GhostCodec = {}

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
local ENC: { string } = {}
local DEC: { [number]: number } = {}
for i = 1, 64 do
	local ch = string.sub(ALPHABET, i, i)
	ENC[i] = ch
	DEC[string.byte(ch)] = i - 1
end

local YAW_STEPS = 256
local MAX_CHARS_PER_INT = 6 -- 30 бит: больше не бывает у честной записи

GhostCodec.FIELDS = 4 -- x, y, z, yaw на сэмпл

-- Целое → символы varint (в буфер out)
local function putInt(out: { string }, v: number)
	local z = if v >= 0 then v * 2 else -v * 2 - 1
	repeat
		local chunk = z % 32
		z = z // 32
		if z > 0 then
			chunk += 32 -- бит «дальше ещё символ»
		end
		table.insert(out, ENC[chunk + 1])
	until z == 0
end

local function wrapYaw(d: number): number
	d %= YAW_STEPS
	return if d >= YAW_STEPS / 2 then d - YAW_STEPS else d
end

-- Квантование одного сэмпла: rel — позиция от начала трассы, yaw — радианы
function GhostCodec.quantize(rel: Vector3, yaw: number, q: number): (number, number, number, number)
	return math.round(rel.X / q), math.round(rel.Y / q), math.round(rel.Z / q), math.round(yaw / (2 * math.pi) * YAW_STEPS) % YAW_STEPS
end

-- Плоский массив целых { x1, y1, z1, yaw1, x2, … } → строка
function GhostCodec.encode(ints: { number }): string
	local out = table.create(#ints * 2)
	local px, py, pz, pyaw = 0, 0, 0, 0
	for i = 1, #ints, 4 do
		local x, y, z, yaw = ints[i], ints[i + 1], ints[i + 2], ints[i + 3]
		putInt(out, x - px)
		putInt(out, y - py)
		putInt(out, z - pz)
		putInt(out, wrapYaw(yaw - pyaw))
		px, py, pz, pyaw = x, y, z, yaw
	end
	return table.concat(out)
end

-- Строка → массивы x, y, z (studs от начала трассы), yaw (радианы). nil — битая строка или
-- сэмплов больше maxSamples (сервер проверяет недоверенные данные клиента этой же функцией).
function GhostCodec.decode(data: string, q: number, maxSamples: number): ({ number }?, { number }?, { number }?, { number }?)
	local xs, ys, zs, yaws = {}, {}, {}, {}
	local acc = { 0, 0, 0, 0 }
	local field = 1
	local z, mul, chars = 0, 1, 0
	local n = 0
	for i = 1, #data do
		local d = DEC[string.byte(data, i)]
		if d == nil then
			return nil
		end
		chars += 1
		if chars > MAX_CHARS_PER_INT then
			return nil
		end
		z += (d % 32) * mul
		mul *= 32
		if d < 32 then
			local v = if z % 2 == 0 then z // 2 else -(z + 1) // 2
			if field == 4 then
				acc[4] = (acc[4] + v) % YAW_STEPS
			else
				acc[field] += v
			end
			z, mul, chars = 0, 1, 0
			field += 1
			if field > 4 then
				field = 1
				n += 1
				if n > maxSamples then
					return nil
				end
				xs[n] = acc[1] * q
				ys[n] = acc[2] * q
				zs[n] = acc[3] * q
				yaws[n] = acc[4] / YAW_STEPS * 2 * math.pi
			end
		end
	end
	if field ~= 1 or chars ~= 0 then
		return nil -- оборвано посреди сэмпла
	end
	return xs, ys, zs, yaws
end

return GhostCodec
