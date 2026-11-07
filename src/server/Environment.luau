-- Освещение и атмосфера мира (солнечный зимний день): Lighting, облака, цветокоррекция, bloom.

local Lighting = game:GetService("Lighting")


local Environment = {}

-- Солнечный зимний день
function Environment.setup()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2
	Lighting.ExposureCompensation = -0.35 -- снег не пересвечивается
	Lighting.Ambient = Color3.fromRGB(100, 115, 140)
	Lighting.OutdoorAmbient = Color3.fromRGB(120, 140, 170)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GlobalShadows = true
	do
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.25
		atmosphere.Offset = 0.15
		atmosphere.Color = Color3.fromRGB(190, 220, 255)
		atmosphere.Decay = Color3.fromRGB(110, 160, 230)
		atmosphere.Glare = 0.3
		atmosphere.Haze = 0.5 -- меньше дымки: небо насыщенно-голубое, как в оригинале
		atmosphere.Parent = Lighting

		-- Объёмные облака (встроенные в Terrain, ассеты не нужны)
		local clouds = Instance.new("Clouds")
		clouds.Cover = 0.55
		clouds.Density = 0.6
		clouds.Color = Color3.fromRGB(255, 255, 255)
		clouds.Parent = workspace.Terrain
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Brightness = -0.02
		cc.Contrast = 0.18
		cc.Saturation = 0.25
		cc.TintColor = Color3.fromRGB(240, 248, 255)
		cc.Parent = Lighting
		local bloom = Instance.new("BloomEffect")
		bloom.Intensity = 0.4
		bloom.Size = 18
		bloom.Threshold = 2
		bloom.Parent = Lighting
	end
end

return Environment
