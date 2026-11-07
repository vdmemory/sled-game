-- Пресеты «дорогого» вида миров: свет, атмосфера, облака, небо и пост-обработка.
-- Только данные; применяет client/PostFX (плавно, TweenService), осадки — client/Effects.
-- Индекс = тема мира (Config.THEMES). Лобби = пресет мира витрины + поправки WorldLook.LOBBY.
-- Общие множители (Bloom, DOF, насыщенность, мин. контраст) — в Config.GRAPHICS (панель «Настройка»).
--
-- Правила читаемости (не нарушать при правке чисел):
--  • ColorCorrection.Contrast ≥ Config.GRAPHICS.CONTRAST_MIN — препятствия на снегу должны «стоять»;
--  • Bloom.Threshold ≥ 2 в снежных солнечных мирах: снег ≈ самая яркая поверхность кадра, ниже
--    порога он «цветёт» молоком; порог 1.3–1.7 только там, где темнее (сумерки) и есть неон;
--  • ExposureCompensation ≤ −0.25 днём: снег не уходит в чисто белый;
--  • DOF размывает только дальше ~240 studs (FocusDistance 190 + InFocusRadius 50): всё, на что
--    успевает среагировать игрок (BUILD_AHEAD и ближе), резкое; NearIntensity = 0 — сани резкие.
-- UI (ScreenGui) пост-обработка не затрагивает — Bloom/CC/DOF действуют только на 3D.

local WorldLook = {}

local rgb = Color3.fromRGB

export type Preset = {
	name: string,
	clock: number, -- ClockTime (высота и цвет солнца)
	lighting: { [string]: any }, -- свойства Lighting
	atmo: { [string]: any }, -- Atmosphere
	clouds: { [string]: any }, -- Terrain.Clouds
	sky: { [string]: any }, -- Sky (без своих текстур: размер солнца, звёзды)
	cc: { [string]: any }, -- ColorCorrectionEffect
	bloom: { [string]: any }, -- BloomEffect
	rays: { [string]: any }, -- SunRaysEffect
	dof: { [string]: any }, -- DepthOfFieldEffect (только в заезде и на «Высоком»)
}

WorldLook.PRESETS = {
	-- 1 Снежный лес: ясный морозный день, холодная тень и тёплое солнце
	{
		name = "Снежный лес",
		clock = 14.5,
		lighting = { Brightness = 2.2, ExposureCompensation = -0.4, Ambient = rgb(95, 110, 135), OutdoorAmbient = rgb(125, 145, 175), ColorShift_Top = rgb(255, 244, 228), EnvironmentDiffuseScale = 0.7, EnvironmentSpecularScale = 0.8, ShadowSoftness = 0.25 },
		atmo = { Density = 0.28, Offset = 0.2, Color = rgb(195, 220, 255), Decay = rgb(105, 155, 230), Glare = 0.25, Haze = 0.6 },
		clouds = { Cover = 0.55, Density = 0.55, Color = rgb(255, 255, 255) },
		sky = { SunAngularSize = 18, StarCount = 0 },
		cc = { Brightness = -0.02, Contrast = 0.18, Saturation = 0.22, TintColor = rgb(238, 246, 255) },
		bloom = { Intensity = 0.35, Size = 20, Threshold = 2.2 },
		rays = { Intensity = 0.06, Spread = 0.5 },
		dof = { FarIntensity = 0.12, NearIntensity = 0, FocusDistance = 190, InFocusRadius = 50 },
	},
	-- 2 Ледяной город: холодный вечер, городская дымка, светятся окна
	{
		name = "Ледяной город",
		clock = 16.2,
		lighting = { Brightness = 2, ExposureCompensation = -0.3, Ambient = rgb(95, 105, 140), OutdoorAmbient = rgb(115, 125, 165), ColorShift_Top = rgb(255, 225, 200), EnvironmentDiffuseScale = 0.8, EnvironmentSpecularScale = 1, ShadowSoftness = 0.3 },
		atmo = { Density = 0.33, Offset = 0.25, Color = rgb(205, 215, 240), Decay = rgb(120, 130, 185), Glare = 0.4, Haze = 1.3 },
		clouds = { Cover = 0.65, Density = 0.6, Color = rgb(235, 235, 250) },
		sky = { SunAngularSize = 14, StarCount = 0 },
		cc = { Brightness = -0.01, Contrast = 0.2, Saturation = 0.12, TintColor = rgb(230, 236, 255) },
		bloom = { Intensity = 0.45, Size = 24, Threshold = 2 },
		rays = { Intensity = 0.08, Spread = 0.4 },
		dof = { FarIntensity = 0.15, NearIntensity = 0, FocusDistance = 190, InFocusRadius = 50 },
	},
	-- 3 Каньон: тёплый низкий закат, пыльная оранжевая дымка, длинные лучи
	{
		name = "Каньон",
		clock = 16.9,
		lighting = { Brightness = 2.4, ExposureCompensation = -0.25, Ambient = rgb(130, 105, 85), OutdoorAmbient = rgb(165, 135, 110), ColorShift_Top = rgb(255, 205, 150), EnvironmentDiffuseScale = 0.7, EnvironmentSpecularScale = 0.6, ShadowSoftness = 0.2 },
		atmo = { Density = 0.3, Offset = 0.3, Color = rgb(255, 220, 180), Decay = rgb(210, 135, 85), Glare = 0.8, Haze = 1.2 },
		clouds = { Cover = 0.35, Density = 0.45, Color = rgb(255, 235, 215) },
		sky = { SunAngularSize = 22, StarCount = 0 },
		cc = { Brightness = 0, Contrast = 0.2, Saturation = 0.3, TintColor = rgb(255, 238, 218) },
		bloom = { Intensity = 0.4, Size = 22, Threshold = 2 },
		rays = { Intensity = 0.12, Spread = 0.55 },
		dof = { FarIntensity = 0.14, NearIntensity = 0, FocusDistance = 190, InFocusRadius = 50 },
	},
	-- 4 Ледяные пещеры: плотная голубая дымка, блеск кристаллов
	{
		name = "Ледяные пещеры",
		clock = 15,
		lighting = { Brightness = 1.8, ExposureCompensation = -0.25, Ambient = rgb(90, 130, 160), OutdoorAmbient = rgb(120, 165, 200), ColorShift_Top = rgb(220, 240, 255), EnvironmentDiffuseScale = 0.9, EnvironmentSpecularScale = 1, ShadowSoftness = 0.4 },
		atmo = { Density = 0.4, Offset = 0.15, Color = rgb(175, 225, 255), Decay = rgb(75, 155, 230), Glare = 0.2, Haze = 1.7 },
		clouds = { Cover = 0.8, Density = 0.7, Color = rgb(225, 240, 255) },
		sky = { SunAngularSize = 12, StarCount = 0 },
		cc = { Brightness = -0.01, Contrast = 0.22, Saturation = 0.18, TintColor = rgb(222, 240, 255) },
		bloom = { Intensity = 0.5, Size = 28, Threshold = 1.8 },
		rays = { Intensity = 0.04, Spread = 0.3 },
		dof = { FarIntensity = 0.18, NearIntensity = 0, FocusDistance = 190, InFocusRadius = 50 },
	},
	-- 5 Северное сияние: сумерки, фиолетовое небо, звёзды, неон светится
	-- clock 18.0 (не позже): после 18:00 солнце под горизонтом и трасса темнеет — препятствия
	-- на сине-фиолетовом дне читаются хуже; светлый Ambient держит их контрастными
	{
		name = "Северное сияние",
		clock = 18,
		lighting = { Brightness = 1.6, ExposureCompensation = -0.1, Ambient = rgb(90, 90, 140), OutdoorAmbient = rgb(110, 110, 170), ColorShift_Top = rgb(200, 190, 255), EnvironmentDiffuseScale = 0.8, EnvironmentSpecularScale = 1, ShadowSoftness = 0.45 },
		atmo = { Density = 0.3, Offset = 0.2, Color = rgb(150, 140, 220), Decay = rgb(60, 160, 140), Glare = 0.3, Haze = 1.4 },
		clouds = { Cover = 0.3, Density = 0.4, Color = rgb(170, 160, 230) },
		sky = { SunAngularSize = 10, StarCount = 3000 },
		cc = { Brightness = 0.02, Contrast = 0.22, Saturation = 0.35, TintColor = rgb(225, 225, 255) },
		bloom = { Intensity = 0.7, Size = 30, Threshold = 1.3 },
		rays = { Intensity = 0.03, Spread = 0.3 },
		dof = { FarIntensity = 0.12, NearIntensity = 0, FocusDistance = 190, InFocusRadius = 50 },
	},
	-- 6 Снежный вулкан: багровый вечер, дымные облака, светится лава
	{
		name = "Снежный вулкан",
		clock = 17.6,
		lighting = { Brightness = 2, ExposureCompensation = -0.25, Ambient = rgb(120, 85, 80), OutdoorAmbient = rgb(150, 105, 95), ColorShift_Top = rgb(255, 170, 120), EnvironmentDiffuseScale = 0.6, EnvironmentSpecularScale = 0.8, ShadowSoftness = 0.3 },
		atmo = { Density = 0.38, Offset = 0.2, Color = rgb(235, 175, 155), Decay = rgb(150, 60, 40), Glare = 0.6, Haze = 1.9 },
		clouds = { Cover = 0.75, Density = 0.7, Color = rgb(120, 105, 105) },
		sky = { SunAngularSize = 20, StarCount = 0 },
		cc = { Brightness = -0.02, Contrast = 0.24, Saturation = 0.22, TintColor = rgb(255, 230, 215) },
		bloom = { Intensity = 0.6, Size = 26, Threshold = 1.5 },
		rays = { Intensity = 0.1, Spread = 0.45 },
		dof = { FarIntensity = 0.16, NearIntensity = 0, FocusDistance = 190, InFocusRadius = 50 },
	},
	-- 7 Конфетная гора: розовый солнечный полдень, пастель (контраст мягче, но не ниже минимума)
	{
		name = "Конфетная гора",
		clock = 13,
		lighting = { Brightness = 2.3, ExposureCompensation = -0.35, Ambient = rgb(135, 110, 135), OutdoorAmbient = rgb(170, 140, 170), ColorShift_Top = rgb(255, 235, 245), EnvironmentDiffuseScale = 0.8, EnvironmentSpecularScale = 0.7, ShadowSoftness = 0.35 },
		atmo = { Density = 0.26, Offset = 0.25, Color = rgb(255, 212, 236), Decay = rgb(240, 145, 205), Glare = 0.3, Haze = 0.8 },
		clouds = { Cover = 0.5, Density = 0.5, Color = rgb(255, 235, 245) },
		sky = { SunAngularSize = 18, StarCount = 0 },
		cc = { Brightness = 0.01, Contrast = 0.14, Saturation = 0.3, TintColor = rgb(255, 242, 250) },
		bloom = { Intensity = 0.4, Size = 22, Threshold = 2 },
		rays = { Intensity = 0.07, Spread = 0.5 },
		dof = { FarIntensity = 0.1, NearIntensity = 0, FocusDistance = 190, InFocusRadius = 50 },
	},
} :: { Preset }

-- Лобби: свет мира витринной трассы + поправки (меню поверх сцены — чуть светлее и сочнее,
-- без размытия: витрина за мостиком должна быть чёткой)
WorldLook.LOBBY = {
	exposureAdd = 0.05,
	saturationAdd = 0.03,
	bloomMult = 0.9,
	dof = false,
}

-- Уровни графики. particles — множитель частиц (снег, пыль); shadows=false — тени выключены
-- независимо от настройки «Тени»; prioritizeLighting — Lighting.PrioritizeLightingQuality
-- (false: при нехватке мощности движок сначала режет свет, а не дальность — трассу видно далеко).
WorldLook.QUALITY = {
	{ name = "НИЗКОЕ", dof = false, rays = false, bloom = false, clouds = false, shadows = false, prioritizeLighting = false, particles = 0.3, speedLines = 0.5 },
	{ name = "СРЕДНЕЕ", dof = false, rays = true, bloom = true, clouds = true, shadows = true, prioritizeLighting = false, particles = 0.7, speedLines = 0.8 },
	{ name = "ВЫСОКОЕ", dof = true, rays = true, bloom = true, clouds = true, shadows = true, prioritizeLighting = true, particles = 1, speedLines = 1 },
}

-- SavedQualityLevel (1–10, «Графика» в меню Roblox) → наш уровень; 0 = Automatic → по устройству
function WorldLook.tierFromSaved(saved: number, touch: boolean): number
	if saved <= 0 then
		return if touch then 2 else 3
	elseif saved <= 3 then
		return 1
	elseif saved <= 7 then
		return 2
	end
	return 3
end

function WorldLook.get(theme: number): Preset
	return WorldLook.PRESETS[((theme - 1) % #WorldLook.PRESETS) + 1]
end

return WorldLook
