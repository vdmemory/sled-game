-- Меши декора (#45): из ID ассетов Model (Shared/MeshIds, их загружает деплой) достаём MeshPart через
-- InsertService (ассет принадлежит владельцу игры) и кладём шаблоны в ReplicatedStorage.MeshTemplates —
-- Props клонирует их (MeshId из скрипта не ставится). Видит и клиент (витрина, декор лобби).
-- Пока шаблона нет (не загружен, на модерации, ошибка) — Props строит прежние модели из Part.

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ids = require(ReplicatedStorage.Shared.MeshIds)
local Meshes = require(ReplicatedStorage.Shared.Meshes)

local folder = Instance.new("Folder")
folder.Name = Meshes.FOLDER
folder.Parent = ReplicatedStorage

for name, assetId in ids do
	task.spawn(function()
		local lastErr = ""
		for attempt = 1, 3 do
			local ok, model = pcall(InsertService.LoadAsset, InsertService, assetId)
			if ok and model then
				local mp = model:FindFirstChildWhichIsA("MeshPart", true)
				if mp then
					mp.Name = name
					mp.Anchored = true
					mp.CanCollide = false
					mp.CanQuery = false
					mp.CanTouch = false
					mp.CastShadow = false
					mp.Parent = folder
					model:Destroy()
					return
				end
				lastErr = "в модели нет MeshPart"
				model:Destroy()
			else
				lastErr = tostring(model)
			end
			task.wait(attempt * 5)
		end
		warn("[MeshAssets] меш " .. name .. " (ассет " .. assetId .. ") не загружен, остаётся модель из Part: " .. lastErr)
		folder:SetAttribute("_err", name .. ": " .. string.sub(lastErr, 1, 200))
	end)
end
