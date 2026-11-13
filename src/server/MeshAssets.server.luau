-- Меши декора (#45): из ID ассетов Model (Shared/MeshIds, их загружает деплой) достаём MeshPart через
-- InsertService (ассет принадлежит владельцу игры) и кладём шаблоны в ReplicatedStorage.MeshTemplates —
-- Props клонирует их (MeshId из скрипта не ставится). Видит и клиент (витрина, декор лобби).
-- Пока шаблона нет (не загружен, на модерации, ошибка) — Props строит прежние модели из Part.
-- Сама загрузка — Meshes.load (её же вызывает StudioTrack в режиме редактирования).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Meshes = require(ReplicatedStorage.Shared.Meshes)

-- если в месте остались шаблоны из Studio (StudioTrack без clear) — грузим заново, начисто
local old = ReplicatedStorage:FindFirstChild(Meshes.FOLDER)
if old then
	old:Destroy()
end
Meshes.load(false)
