-- Ремоуты клиент ↔ сервер: создаются здесь (папка ReplicatedStorage.Remotes), Main кладёт папку в
-- ReplicatedStorage после Tuning.init. Клиент ждёт ReplicatedStorage:WaitForChild("Remotes").

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local function remote(className: string, name: string): any
	local r = Instance.new(className)
	r.Name = name
	r.Parent = remotes
	return r
end
local Remotes = {
	folder = remotes,
	StartRun = remote("RemoteEvent", "StartRun") :: RemoteEvent,
	Launch = remote("RemoteEvent", "Launch") :: RemoteEvent,
	Crash = remote("RemoteEvent", "Crash") :: RemoteEvent,
	Air = remote("RemoteEvent", "Air") :: RemoteEvent,
	Trick = remote("RemoteEvent", "Trick") :: RemoteEvent,
	RunEnded = remote("RemoteEvent", "RunEnded") :: RemoteEvent,
	Restart = remote("RemoteEvent", "Restart") :: RemoteEvent, -- ⟳ в заезде: закончить и сразу новый
	Back = remote("RemoteEvent", "Back") :: RemoteEvent, -- BACK у рогатки: вернуться в лобби
	Smash = remote("RemoteEvent", "Smash") :: RemoteEvent, -- разбил препятствие ракетой/на ускорителе
	SetSetting = remote("RemoteEvent", "SetSetting") :: RemoteEvent, -- настройки: звуки, снег, тени
	RewardAction = remote("RemoteFunction", "RewardAction") :: RemoteFunction, -- задания, билет, подарки, сундук, стрик
	TaskDone = remote("RemoteEvent", "TaskDone") :: RemoteEvent, -- «задание выполнено!»
	Crystal = remote("RemoteEvent", "Crystal") :: RemoteEvent, -- разбил ледяной кристалл
	CoinGrab = remote("RemoteEvent", "CoinGrab") :: RemoteEvent, -- монету притянул магнит
	SledAction = remote("RemoteFunction", "SledAction") :: RemoteFunction, -- купить/надеть сани (модель + редкость)
	TrailAction = remote("RemoteFunction", "TrailAction") :: RemoteFunction, -- купить/надеть след
	BuyUpgrade = remote("RemoteFunction", "BuyUpgrade") :: RemoteFunction,
	PowerUp = remote("RemoteEvent", "PowerUp") :: RemoteEvent, -- подобрал бонус на трассе (x2 / кольцо)
	DevAction = remote("RemoteFunction", "DevAction") :: RemoteFunction, -- панель разработчика (только владелец)
	WorldAction = remote("RemoteFunction", "WorldAction") :: RemoteFunction, -- фарм пройденного мира / пропуск мира за Robux
	TutorialStep = remote("RemoteEvent", "TutorialStep") :: RemoteEvent, -- обучение: шаг i пройден (0 — пропустить всё)
}

return Remotes
