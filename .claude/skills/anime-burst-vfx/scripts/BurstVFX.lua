-- BurstVFX: anime-style burst / shockwave.
-- Put this ModuleScript in ReplicatedStorage, then:
--   local BurstVFX = require(game.ReplicatedStorage.BurstVFX)
--   BurstVFX.play(Vector3.new(0, 0, 0), { color = Color3.fromRGB(70, 230, 255), size = 12 })

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local BurstVFX = {}

local function newPart(parent: Instance, shape: Enum.PartType, material: Enum.Material, color: Color3): Part
	local part = Instance.new("Part")
	part.Shape = shape
	part.Material = material
	part.Color = color
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = Vector3.new(0.5, 0.5, 0.5)
	part.Parent = parent
	return part
end

local function tween(instance: Instance, seconds: number, style: Enum.EasingStyle, goal: { [string]: any }): Tween
	local t = TweenService:Create(instance, TweenInfo.new(seconds, style, Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

export type Options = {
	color: Color3?,
	size: number?,
	duration: number?,
	ring: boolean?,
	sparks: boolean?,
}

function BurstVFX.play(where: Vector3 | CFrame, options: Options?)
	local opts = options or {}
	local color = opts.color or Color3.fromRGB(70, 230, 255)
	local size = opts.size or 12
	local duration = opts.duration or 0.9
	local origin = if typeof(where) == "CFrame" then where.Position else where

	local model = Instance.new("Model")
	model.Name = "BurstVFX"
	model.Parent = workspace

	-- Dome: a ball centred on the ground, so only the top half shows.
	-- ForceField gives the moving cartoon stripes.
	local dome = newPart(model, Enum.PartType.Ball, Enum.Material.ForceField, color)
	dome.CFrame = CFrame.new(origin)
	local rise = duration * 0.3
	tween(dome, rise, Enum.EasingStyle.Back, { Size = Vector3.one * size })
	task.delay(rise, function()
		tween(dome, duration - rise, Enum.EasingStyle.Quad, { Transparency = 1, Size = Vector3.one * size * 1.08 })
	end)

	-- Flash: a bright core that pops and fades fast.
	local flash = newPart(model, Enum.PartType.Ball, Enum.Material.Neon, color:Lerp(Color3.new(1, 1, 1), 0.6))
	flash.CFrame = CFrame.new(origin)
	flash.Transparency = 0.1
	tween(flash, duration * 0.35, Enum.EasingStyle.Quad, { Size = Vector3.one * size * 0.7, Transparency = 1 })

	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = size * 1.5
	light.Brightness = 4
	light.Parent = flash
	tween(light, duration * 0.6, Enum.EasingStyle.Quad, { Brightness = 0 })

	-- Ring: a thin flat disc on the ground that races outward and fades.
	if opts.ring ~= false then
		local ring = newPart(model, Enum.PartType.Cylinder, Enum.Material.Neon, color)
		ring.CFrame = CFrame.new(origin + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
		ring.Size = Vector3.new(0.15, size * 0.5, size * 0.5)
		ring.Transparency = 0.35
		tween(ring, duration, Enum.EasingStyle.Quart, {
			Size = Vector3.new(0.15, size * 2.4, size * 2.4),
			Transparency = 1,
		})
	end

	-- Sparks: a quick spray of particles.
	if opts.sparks ~= false then
		local holder = newPart(model, Enum.PartType.Block, Enum.Material.SmoothPlastic, color)
		holder.Transparency = 1
		holder.CFrame = CFrame.new(origin + Vector3.new(0, 0.5, 0))
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Color = ColorSequence.new(color)
		emitter.LightEmission = 1
		emitter.Enabled = false
		emitter.Lifetime = NumberRange.new(0.3, 0.6)
		emitter.Speed = NumberRange.new(size * 1.5, size * 3)
		emitter.SpreadAngle = Vector2.new(80, 80)
		emitter.Acceleration = Vector3.new(0, -workspace.Gravity * 0.3, 0)
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, size * 0.08),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Parent = holder
		emitter:Emit(24)
	end

	Debris:AddItem(model, duration + 1)
	return model
end

return BurstVFX
