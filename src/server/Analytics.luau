-- Аналитика для Creator Hub (AnalyticsService): воронка онбординга, экономика монет/гемов,
-- события заездов. Работает только на опубликованном плейсе; всё в pcall — не ломает игру.
-- Что и зачем логируем — docs/METRICS.md, раздел «События в игре».

local AnalyticsService = game:GetService("AnalyticsService")

local Analytics = {}

-- Шаги онбординга (Creator Hub → Analytics → Funnels → Onboarding). Порядок важен, пропускать нельзя.
Analytics.ONBOARDING = {
	"Joined", -- 1 зашёл
	"FirstRun", -- 2 первый заезд
	"ThirdRun", -- 3 третий заезд (понял игру)
	"FirstUpgrade", -- 4 первый апгрейд
	"FinishedLevel", -- 5 прошёл первый уровень
	"World2", -- 6 дошёл до мира 2
	"FirstPurchase", -- 7 первая покупка за Robux
}

local function try(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		warn("[Analytics] " .. tostring(err))
	end
end

-- Онбординг: продвигаем игрока до шага step (все пропущенные шаги между — тоже), один раз.
function Analytics.onboarding(player: Player, d: any, step: number)
	d.Stats = d.Stats or {}
	local reached = d.Stats.Onboard or 0
	if step <= reached then
		return
	end
	for s = reached + 1, step do
		try(AnalyticsService.LogOnboardingFunnelStepEvent, AnalyticsService, player, s, Analytics.ONBOARDING[s])
	end
	d.Stats.Onboard = step
end

-- Экономика: flow = "Source" | "Sink"; currency "Coins" | "Gems"; txType — Enum.AnalyticsEconomyTransactionType.*.Name
function Analytics.economy(player: Player, flow: string, currency: string, amount: number, balance: number, txType: string, sku: string?, fields: { [string]: string }?)
	if amount <= 0 then
		return
	end
	local ft = if flow == "Sink" then Enum.AnalyticsEconomyFlowType.Sink else Enum.AnalyticsEconomyFlowType.Source
	try(AnalyticsService.LogEconomyEvent, AnalyticsService, player, ft, currency, math.floor(amount), math.floor(math.max(0, balance)), txType, sku, fields)
end

-- Произвольное событие со значением (агрегируется по дням) или счётчик (value = nil)
function Analytics.custom(player: Player, name: string, value: number?)
	if value ~= nil then
		try(AnalyticsService.LogCustomEvent, AnalyticsService, player, name, value)
	else
		try(AnalyticsService.LogCustomEvent, AnalyticsService, player, name)
	end
end

-- Поля для разрезов в графиках (до 3)
function Analytics.fields(world: number?, level: number?, extra: string?): { [string]: string }
	local f = {}
	if world then
		f[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = "World " .. world
	end
	if level then
		f[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = "Level " .. level
	end
	if extra then
		f[Enum.AnalyticsCustomFieldKeys.CustomField03.Name] = extra
	end
	return f
end

return Analytics
