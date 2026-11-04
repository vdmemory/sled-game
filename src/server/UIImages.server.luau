-- Картинки интерфейса: из ID декалей (Shared/UIDecals, их загружает деплой) достаём ID самих
-- изображений через InsertService (декаль принадлежит владельцу игры — так можно) и отдаём
-- клиентам атрибутами папки ReplicatedStorage.UIImages: имя → "rbxassetid://…".
-- Пока картинки нет (не загрузилась, на модерации) — интерфейс показывает эмодзи.

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local decals = require(ReplicatedStorage.Shared.UIDecals)

local folder = Instance.new("Folder")
folder.Name = "UIImages"
folder.Parent = ReplicatedStorage

for name, decalId in decals do
	task.spawn(function()
		local lastErr = ""
		for attempt = 1, 3 do
			local ok, model = pcall(InsertService.LoadAsset, InsertService, decalId)
			if not ok then
				lastErr = tostring(model)
			end
			if ok and model then
				local decal = model:FindFirstChildWhichIsA("Decal", true)
				local tex = decal and decal.Texture or ""
				model:Destroy()
				local imageId = string.match(tex, "%d+$")
				if imageId then
					folder:SetAttribute(name, "rbxassetid://" .. imageId)
					return
				end
			end
			task.wait(attempt * 5)
		end
		warn("[UIImages] не удалось получить картинку для " .. name .. " (декаль " .. decalId .. "): " .. lastErr)
		-- диагностика видна и на клиенте (F9 → лог клиента)
		folder:SetAttribute("_err", name .. ": " .. string.sub(lastErr, 1, 200))
	end)
end
