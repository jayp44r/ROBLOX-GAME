-- Cinematic lighting presets (sunset over the ocean, night, day) + optional day/night cycle.
-- Script in ServerScriptService. Change PRESET / CYCLE below.
-- Lighting.Technology can only be set in Studio (Properties or a plugin): set it to Future.

local PRESET = "sunset" -- "sunset", "night" or "day"
local CYCLE = false -- true = time keeps moving
local MINUTES_PER_DAY = 12 -- real minutes for one full in-game day when CYCLE is on

local Lighting = game:GetService("Lighting")
local Terrain = workspace:FindFirstChildOfClass("Terrain")

local PRESETS = {
	sunset = {
		ClockTime = 17.9,
		Brightness = 2.5,
		Ambient = Color3.fromRGB(70, 50, 45),
		OutdoorAmbient = Color3.fromRGB(150, 105, 85),
		ColorShift_Top = Color3.fromRGB(255, 170, 110),
		EnvironmentDiffuseScale = 1,
		EnvironmentSpecularScale = 1,
		Atmosphere = { Density = 0.38, Offset = 0.1, Color = Color3.fromRGB(255, 170, 120), Decay = Color3.fromRGB(120, 60, 70), Glare = 1.2, Haze = 2.2 },
		Bloom = { Intensity = 0.8, Size = 30, Threshold = 1.4 },
		SunRays = { Intensity = 0.12, Spread = 0.8 },
		Color = { Brightness = 0.02, Contrast = 0.12, Saturation = 0.15, TintColor = Color3.fromRGB(255, 235, 215) },
		Clouds = { Cover = 0.62, Density = 0.55, Color = Color3.fromRGB(255, 190, 150) },
		Water = { WaterColor = Color3.fromRGB(60, 70, 80), WaterReflectance = 1, WaterTransparency = 0.6, WaterWaveSize = 0.15, WaterWaveSpeed = 12 },
	},
	night = {
		ClockTime = 0.5,
		Brightness = 1,
		Ambient = Color3.fromRGB(35, 35, 55),
		OutdoorAmbient = Color3.fromRGB(70, 75, 110),
		ColorShift_Top = Color3.fromRGB(150, 170, 255),
		EnvironmentDiffuseScale = 0.6,
		EnvironmentSpecularScale = 1,
		Atmosphere = { Density = 0.32, Offset = 0, Color = Color3.fromRGB(90, 90, 130), Decay = Color3.fromRGB(40, 40, 70), Glare = 0.4, Haze = 1.5 },
		Bloom = { Intensity = 1, Size = 24, Threshold = 1.2 },
		SunRays = { Intensity = 0.03, Spread = 0.5 },
		Color = { Brightness = 0, Contrast = 0.15, Saturation = -0.05, TintColor = Color3.fromRGB(215, 225, 255) },
		Clouds = { Cover = 0.5, Density = 0.4, Color = Color3.fromRGB(120, 120, 150) },
		Water = { WaterColor = Color3.fromRGB(20, 30, 50), WaterReflectance = 1, WaterTransparency = 0.5, WaterWaveSize = 0.15, WaterWaveSpeed = 10 },
	},
	day = {
		ClockTime = 13,
		Brightness = 3,
		Ambient = Color3.fromRGB(90, 95, 105),
		OutdoorAmbient = Color3.fromRGB(140, 145, 155),
		ColorShift_Top = Color3.fromRGB(255, 245, 230),
		EnvironmentDiffuseScale = 1,
		EnvironmentSpecularScale = 1,
		Atmosphere = { Density = 0.28, Offset = 0.15, Color = Color3.fromRGB(200, 215, 235), Decay = Color3.fromRGB(110, 130, 160), Glare = 0.3, Haze = 1 },
		Bloom = { Intensity = 0.5, Size = 24, Threshold = 2 },
		SunRays = { Intensity = 0.06, Spread = 0.6 },
		Color = { Brightness = 0, Contrast = 0.08, Saturation = 0.1, TintColor = Color3.fromRGB(255, 252, 245) },
		Clouds = { Cover = 0.55, Density = 0.5, Color = Color3.fromRGB(255, 255, 255) },
		Water = { WaterColor = Color3.fromRGB(25, 90, 110), WaterReflectance = 1, WaterTransparency = 0.7, WaterWaveSize = 0.15, WaterWaveSpeed = 10 },
	},
}

local function getOrMake(parent: Instance, className: string): Instance
	local found = parent:FindFirstChildOfClass(className)
	if not found then
		found = Instance.new(className)
		found.Parent = parent
	end
	return found
end

local function setProps(instance: Instance, props: { [string]: any })
	for key, value in props do
		(instance :: any)[key] = value
	end
end

local function apply(name: string)
	local p = PRESETS[name] or PRESETS.sunset
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.2
	for _, key in { "ClockTime", "Brightness", "Ambient", "OutdoorAmbient", "ColorShift_Top", "EnvironmentDiffuseScale", "EnvironmentSpecularScale" } do
		(Lighting :: any)[key] = p[key]
	end
	setProps(getOrMake(Lighting, "Atmosphere"), p.Atmosphere)
	setProps(getOrMake(Lighting, "BloomEffect"), p.Bloom)
	setProps(getOrMake(Lighting, "SunRaysEffect"), p.SunRays)
	setProps(getOrMake(Lighting, "ColorCorrectionEffect"), p.Color)
	if Terrain then
		setProps(getOrMake(Terrain, "Clouds"), p.Clouds)
		setProps(Terrain, p.Water)
	end
end

apply(PRESET)

if CYCLE then
	local hoursPerSecond = 24 / (MINUTES_PER_DAY * 60)
	while true do
		local dt = task.wait(0.1)
		Lighting.ClockTime = (Lighting.ClockTime + dt * hoursPerSecond) % 24
	end
end
