-- Muzzle flash + smoke puff for any gun Tool. ModuleScript in ReplicatedStorage.
--   local MuzzleFlash = require(game.ReplicatedStorage.MuzzleFlash)
--   tool.Activated:Connect(function() MuzzleFlash.play(tool.Handle) end)
-- Put an Attachment named "Muzzle" at the barrel tip; otherwise the front of the Handle is used.

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local MuzzleFlash = {}

local function muzzleOf(handle: BasePart): Attachment
	local muzzle = handle:FindFirstChild("Muzzle")
	if muzzle and muzzle:IsA("Attachment") then
		return muzzle
	end
	muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = Vector3.new(0, 0, -handle.Size.Z / 2)
	muzzle.Parent = handle
	return muzzle
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

function MuzzleFlash.play(handle: BasePart)
	local muzzle = muzzleOf(handle)

	local flash = emitter(muzzle, {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(255, 220, 140)),
		LightEmission = 1,
		Lifetime = NumberRange.new(0.05),
		Speed = NumberRange.new(0),
		Size = NumberSequence.new(1.2, 0.2),
		Rotation = NumberRange.new(0, 360),
	})
	flash:Emit(2)

	local smoke = emitter(muzzle, {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(200, 200, 200)),
		Transparency = NumberSequence.new(0.6, 1),
		Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(2, 4),
		SpreadAngle = Vector2.new(15, 15),
		Acceleration = Vector3.new(0, 2, 0),
		Size = NumberSequence.new(0.3, 1.5),
		EmissionDirection = Enum.NormalId.Front,
	})
	smoke:Emit(3)

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 200, 120)
	light.Range = 10
	light.Brightness = 5
	light.Parent = muzzle
	TweenService:Create(light, TweenInfo.new(0.08), { Brightness = 0 }):Play()

	Debris:AddItem(flash, 0.2)
	Debris:AddItem(smoke, 1.2)
	Debris:AddItem(light, 0.1)
end

return MuzzleFlash
