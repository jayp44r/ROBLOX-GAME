-- AbilityVFX: ModuleScript in ReplicatedStorage. Client-side effects, built in layers:
--   1. core   - the bright main shape (flash, beam, sphere, shockwave)
--   2. detail - secondary shapes (magic circle, rings, streaks, smoke)
--   3. particles - sparks and debris
--   + feel    - screen tint, camera shake, damage numbers
-- No uploaded assets needed: everything is parts, GUIs and built-in Roblox particle textures.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

local VFX = {}
VFX.theme = {
	main = Color3.fromRGB(150, 80, 255),
	dark = Color3.fromRGB(25, 10, 40),
	light = Color3.fromRGB(225, 200, 255),
}

local folder = Instance.new("Folder")
folder.Name = "AbilityVFX"
folder.Parent = workspace

local function tween(obj: Instance, t: number, goal, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end

local function part(shape: Enum.PartType, material: Enum.Material, color: Color3, cf: CFrame, size: Vector3): Part
	local p = Instance.new("Part")
	p.Shape = shape
	p.Material = material
	p.Color = color
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.CFrame = cf
	p.Size = size
	p.Parent = folder
	return p
end

local function ground(position: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { folder }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	local result = workspace:Raycast(position + Vector3.new(0, 3, 0), Vector3.new(0, -50, 0), params)
	return if result then result.Position else position - Vector3.new(0, 3, 0)
end

local function emitter(parent: Instance, props): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

local function anchorAt(position: Vector3, life: number): Attachment
	local holder = part(Enum.PartType.Block, Enum.Material.SmoothPlastic, Color3.new(), CFrame.new(position), Vector3.one)
	holder.Transparency = 1
	local att = Instance.new("Attachment")
	att.Parent = holder
	Debris:AddItem(holder, life)
	return att
end

local function rootOf(model: Instance?): BasePart?
	return model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

---------------------------------------------------------------------------- layers

-- Magic circle drawn with a SurfaceGui on a flat part: rings, a hexagram and glyphs, spinning.
function VFX.magicCircle(position: Vector3, radius: number, color: Color3, life: number)
	local pos = ground(position) + Vector3.new(0, 0.06, 0)
	local plate = part(Enum.PartType.Block, Enum.Material.SmoothPlastic, color, CFrame.new(pos), Vector3.new(radius * 2, 0.05, radius * 2))
	plate.Transparency = 1
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.CanvasSize = Vector2.new(512, 512)
	gui.LightInfluence = 0
	gui.Brightness = 3
	gui.Parent = plate
	local canvas = Instance.new("CanvasGroup")
	canvas.BackgroundTransparency = 1
	canvas.AnchorPoint = Vector2.new(0.5, 0.5)
	canvas.Position = UDim2.fromScale(0.5, 0.5)
	canvas.Size = UDim2.fromScale(1, 1)
	canvas.GroupTransparency = 1
	canvas.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = canvas

	local function ring(fraction: number, thickness: number)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(0.5, 0.5)
		f.Size = UDim2.fromScale(fraction, fraction)
		f.BackgroundTransparency = 1
		f.Parent = canvas
		Instance.new("UICorner", f).CornerRadius = UDim.new(1, 0)
		local s = Instance.new("UIStroke")
		s.Color = color
		s.Thickness = thickness
		s.Parent = f
	end
	ring(0.97, 8)
	ring(0.88, 3)
	ring(0.5, 4)
	ring(0.12, 3)

	-- Hexagram: two triangles made of thin bars.
	local r = 0.44
	for t = 0, 1 do
		for i = 0, 2 do
			local a1 = math.rad(90 + t * 60 + i * 120)
			local a2 = math.rad(90 + t * 60 + (i + 1) * 120)
			local x1, y1 = 0.5 + r * math.cos(a1), 0.5 + r * math.sin(a1)
			local x2, y2 = 0.5 + r * math.cos(a2), 0.5 + r * math.sin(a2)
			local bar = Instance.new("Frame")
			bar.AnchorPoint = Vector2.new(0.5, 0.5)
			bar.Position = UDim2.fromScale((x1 + x2) / 2, (y1 + y2) / 2)
			bar.Size = UDim2.new(math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2), 0, 0, 4)
			bar.Rotation = math.deg(math.atan2(y2 - y1, x2 - x1))
			bar.BackgroundColor3 = color
			bar.BorderSizePixel = 0
			bar.Parent = canvas
		end
	end
	-- Glyphs around the band between the two outer rings.
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		local g = Instance.new("TextLabel")
		g.AnchorPoint = Vector2.new(0.5, 0.5)
		g.Position = UDim2.fromScale(0.5 + 0.462 * math.cos(a), 0.5 + 0.462 * math.sin(a))
		g.Size = UDim2.fromOffset(26, 26)
		g.Rotation = math.deg(a) + 90
		g.BackgroundTransparency = 1
		g.Text = if i % 2 == 0 then "✦" else "✧"
		g.TextColor3 = color
		g.TextScaled = true
		g.Parent = canvas
	end

	tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(canvas, 0.2, { GroupTransparency = 0 })
	local spin = RunService.RenderStepped:Connect(function(dt)
		canvas.Rotation += dt * 40
	end)
	task.delay(math.max(life - 0.4, 0.1), function()
		tween(canvas, 0.4, { GroupTransparency = 1 })
	end)
	task.delay(life, function()
		spin:Disconnect()
		plate:Destroy()
	end)
	return plate
end

function VFX.smoke(position: Vector3, color: Color3, amount: number, size: number, life: number?)
	local att = anchorAt(position, 4)
	emitter(att, {
		Texture = SMOKE,
		Color = ColorSequence.new(color),
		LightEmission = 0,
		LightInfluence = 0,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.1), NumberSequenceKeypoint.new(1, 1) }),
		Size = NumberSequence.new(size * 0.5, size),
		Lifetime = NumberRange.new(life or 1, (life or 1) * 1.5),
		Speed = NumberRange.new(size * 0.5, size * 1.5),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 3,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-60, 60),
	}):Emit(amount)
end

function VFX.sparks(position: Vector3, color: Color3, amount: number, speed: number)
	local att = anchorAt(position, 2)
	emitter(att, {
		Texture = SPARK,
		Color = ColorSequence.new(color),
		LightEmission = 1,
		Size = NumberSequence.new(0.6, 0),
		Lifetime = NumberRange.new(0.3, 0.7),
		Speed = NumberRange.new(speed * 0.5, speed),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 4,
		Acceleration = Vector3.new(0, -20, 0),
	}):Emit(amount)
end

function VFX.flash(position: Vector3, color: Color3, size: number)
	local ball = part(Enum.PartType.Ball, Enum.Material.Neon, color, CFrame.new(position), Vector3.one * size * 0.3)
	ball.Transparency = 0
	tween(ball, 0.25, { Size = Vector3.one * size, Transparency = 1 })
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = size * 2
	light.Brightness = 5
	light.Parent = ball
	Debris:AddItem(ball, 0.3)
end

function VFX.shockwave(position: Vector3, radius: number, color: Color3)
	local pos = ground(position) + Vector3.new(0, 0.15, 0)
	local disc = part(Enum.PartType.Cylinder, Enum.Material.Neon, color, CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.2, 2, 2))
	disc.Transparency = 0.3
	tween(disc, 0.45, { Size = Vector3.new(0.2, radius * 2.2, radius * 2.2), Transparency = 1 }, Enum.EasingStyle.Quart)
	local dome = part(Enum.PartType.Ball, Enum.Material.ForceField, color, CFrame.new(pos), Vector3.one * 2)
	tween(dome, 0.4, { Size = Vector3.one * radius * 1.6, Transparency = 1 }, Enum.EasingStyle.Back)
	Debris:AddItem(disc, 0.5)
	Debris:AddItem(dome, 0.5)
end

-- Rising streak lines (layer 2 of a blast): thin neon slivers that shoot up and fade.
function VFX.streaks(position: Vector3, radius: number, color: Color3, count: number)
	for _ = 1, count do
		local a = math.random() * math.pi * 2
		local d = math.random() * radius
		local base = position + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		local s = part(Enum.PartType.Block, Enum.Material.Neon, color, CFrame.new(base), Vector3.new(0.15, 1, 0.15))
		local h = 4 + math.random() * 6
		tween(s, 0.35 + math.random() * 0.2, {
			Size = Vector3.new(0.05, h, 0.05),
			CFrame = CFrame.new(base + Vector3.new(0, h, 0)),
			Transparency = 1,
		})
		Debris:AddItem(s, 0.6)
	end
end

function VFX.beam(fromPart: BasePart, toPart: BasePart, color: Color3, life: number)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Parent, a1.Parent = fromPart, toPart
	local beams = {}
	for i = 1, 3 do -- three twisting strands read like chains / energy
		local b = Instance.new("Beam")
		b.Attachment0, b.Attachment1 = a0, a1
		b.Color = ColorSequence.new(if i == 1 then VFX.theme.light else color)
		b.LightEmission = 1
		b.FaceCamera = true
		b.Segments = 20
		b.Width0, b.Width1 = 0.35 / i, 0.35 / i
		b.CurveSize0, b.CurveSize1 = (i - 2) * 2, -(i - 2) * 2
		b.Transparency = NumberSequence.new(0)
		b.Parent = fromPart
		table.insert(beams, b)
	end
	task.delay(life, function()
		for _, b in beams do
			b:Destroy()
		end
		a0:Destroy()
		a1:Destroy()
	end)
end

function VFX.aura(model: Model, color: Color3, duration: number)
	local root = rootOf(model)
	if not root then
		return
	end
	local hl = Instance.new("Highlight")
	hl.FillColor = color
	hl.FillTransparency = 0.6
	hl.OutlineColor = VFX.theme.light
	hl.Parent = model
	local att = Instance.new("Attachment")
	att.Parent = root
	local smoke = emitter(att, {
		Texture = SMOKE,
		Color = ColorSequence.new(VFX.theme.dark),
		LightEmission = 0,
		Transparency = NumberSequence.new(0.2, 1),
		Size = NumberSequence.new(2, 4),
		Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(2, 5),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, 6, 0),
		Rate = 40,
	})
	smoke.Enabled = true
	local wisps = emitter(att, {
		Texture = SPARK,
		Color = ColorSequence.new(color),
		LightEmission = 1,
		Size = NumberSequence.new(0.5, 0),
		Lifetime = NumberRange.new(0.5, 1),
		Speed = NumberRange.new(4, 8),
		SpreadAngle = Vector2.new(30, 30),
		EmissionDirection = Enum.NormalId.Top,
		Rate = 30,
	})
	wisps.Enabled = true
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 14
	light.Brightness = 3
	light.Parent = att
	task.delay(duration, function()
		smoke.Enabled, wisps.Enabled = false, false
		tween(hl, 0.3, { FillTransparency = 1, OutlineTransparency = 1 })
		tween(light, 0.3, { Brightness = 0 })
		Debris:AddItem(att, 1.5)
		Debris:AddItem(hl, 0.4)
	end)
end

function VFX.bubble(model: Model, color: Color3, duration: number)
	local root = rootOf(model)
	if not root then
		return
	end
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Material = Enum.Material.ForceField
	ball.Color = color
	ball.Size = Vector3.one * 2
	ball.CanCollide, ball.CanQuery, ball.CanTouch, ball.Massless = false, false, false, true
	ball.CastShadow = false
	ball.CFrame = root.CFrame
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = ball, root
	weld.Parent = ball
	ball.Parent = folder
	tween(ball, 0.25, { Size = Vector3.one * 9 }, Enum.EasingStyle.Back)
	task.delay(duration, function()
		tween(ball, 0.25, { Size = Vector3.one * 11, Transparency = 1 })
		Debris:AddItem(ball, 0.3)
	end)
end

function VFX.projectile(from: Vector3, to: Vector3, color: Color3, travel: number)
	local orb = part(Enum.PartType.Ball, Enum.Material.Neon, VFX.theme.light, CFrame.new(from), Vector3.one * 1.2)
	local att0, att1 = Instance.new("Attachment"), Instance.new("Attachment")
	att0.Position, att1.Position = Vector3.new(0, 0.5, 0), Vector3.new(0, -0.5, 0)
	att0.Parent, att1.Parent = orb, orb
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = att0, att1
	trail.Color = ColorSequence.new(color)
	trail.LightEmission = 1
	trail.Lifetime = 0.25
	trail.Transparency = NumberSequence.new(0, 1)
	trail.Parent = orb
	tween(orb, travel, { CFrame = CFrame.new(to) }, Enum.EasingStyle.Linear)
	Debris:AddItem(orb, travel + 0.3)
end

---------------------------------------------------------------------------- feel

local tint = Instance.new("ColorCorrectionEffect")
tint.Name = "AbilityTint"
tint.Parent = Lighting

function VFX.screenTint(color: Color3, strength: number, duration: number)
	tint.TintColor = Color3.new(1, 1, 1):Lerp(color, strength)
	tint.Saturation = 0.2
	tint.Contrast = 0.1
	task.delay(duration, function()
		tween(tint, 0.5, { TintColor = Color3.new(1, 1, 1), Saturation = 0, Contrast = 0 })
	end)
end

local shakeUntil, shakePower = 0, 0
RunService:BindToRenderStep("AbilityShake", Enum.RenderPriority.Camera.Value + 2, function()
	local left = shakeUntil - os.clock()
	if left > 0 then
		local p = shakePower * math.min(left * 4, 1)
		local cam = workspace.CurrentCamera
		cam.CFrame *= CFrame.Angles(math.rad((math.random() - 0.5) * p), math.rad((math.random() - 0.5) * p), 0)
	end
end)

function VFX.shake(power: number, seconds: number)
	if os.clock() > shakeUntil then
		shakePower = 0
	end
	shakePower = math.max(shakePower, power)
	shakeUntil = math.max(shakeUntil, os.clock() + seconds)
end

-- Shake only if the local player is close to where it happened.
local function shakeNear(position: Vector3, radius: number, power: number, seconds: number)
	local root = rootOf(Players.LocalPlayer.Character)
	if root and (root.Position - position).Magnitude < radius then
		VFX.shake(power, seconds)
	end
end

function VFX.damageNumber(position: Vector3, amount: number)
	local att = anchorAt(position, 1.2)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(80, 40)
	gui.AlwaysOnTop = true
	gui.StudsOffset = Vector3.new(math.random() * 2 - 1, 0, 0)
	gui.Parent = att
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.Text = "-" .. tostring(amount)
	label.TextScaled = true
	label.TextColor3 = VFX.theme.light
	label.TextStrokeColor3 = VFX.theme.dark
	label.TextStrokeTransparency = 0
	label.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Scale = 1.6
	scale.Parent = label
	tween(scale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(gui, 1, { StudsOffset = gui.StudsOffset + Vector3.new(0, 3, 0) })
	task.delay(0.6, function()
		tween(label, 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 })
	end)
end

---------------------------------------------------------------------------- abilities

local play = {}

function play.burst(d)
	local t = VFX.theme
	VFX.magicCircle(d.origin, d.radius * 0.8, t.main, 1.4) -- detail
	task.delay(0.15, function()
		VFX.flash(d.origin, t.light, 8) -- core
		VFX.shockwave(d.origin, d.radius, t.main) -- core
		VFX.streaks(ground(d.origin), d.radius * 0.6, t.light, 14) -- detail
		VFX.smoke(d.origin, t.dark, 20, 5, 0.8) -- detail
		VFX.sparks(d.origin, t.main, 30, 40) -- particles
		shakeNear(d.origin, d.radius * 3, 2.5, 0.35)
	end)
end

function play.chain(d)
	local from, to = rootOf(d.caster), rootOf(d.target)
	if not from then
		return
	end
	VFX.smoke(from.Position, VFX.theme.dark, 10, 3, 0.6)
	if to then
		VFX.beam(from, to, VFX.theme.main, d.duration)
		VFX.magicCircle(to.Position, 4, VFX.theme.main, d.duration)
		VFX.flash(to.Position, VFX.theme.light, 6)
		VFX.sparks(to.Position, VFX.theme.main, 20, 25)
		shakeNear(to.Position, 20, 1.5, 0.2)
	end
end

function play.aura(d)
	local root = rootOf(d.caster)
	if not root then
		return
	end
	VFX.magicCircle(root.Position, d.radius, VFX.theme.main, d.duration)
	VFX.aura(d.caster, VFX.theme.main, d.duration)
	VFX.flash(root.Position, VFX.theme.light, 10)
	VFX.smoke(root.Position, VFX.theme.dark, 25, 6, 1)
	local me = rootOf(Players.LocalPlayer.Character)
	if me and (me.Position - root.Position).Magnitude < d.radius * 2 then
		VFX.screenTint(VFX.theme.main, 0.35, d.duration)
	end
	shakeNear(root.Position, d.radius * 2, 1.5, 0.4)
end

function play.shield(d)
	local root = rootOf(d.caster)
	if not root then
		return
	end
	VFX.bubble(d.caster, VFX.theme.main, d.duration)
	VFX.smoke(root.Position, VFX.theme.main, 25, 5, 0.8)
	VFX.sparks(root.Position, VFX.theme.light, 25, 20)
end

function play.storm(d)
	local t = VFX.theme
	VFX.magicCircle(d.origin, d.radius, t.main, d.duration)
	VFX.flash(d.origin, t.light, 14)
	for i = 0, math.floor(d.duration / 0.5) do
		task.delay(i * 0.5, function()
			local a = math.random() * math.pi * 2
			local p = d.origin + Vector3.new(math.cos(a), 0, math.sin(a)) * math.random() * d.radius
			VFX.smoke(p, t.dark, 12, 8, 1.4)
			VFX.streaks(ground(p), 4, t.main, 4)
		end)
	end
	local me = rootOf(Players.LocalPlayer.Character)
	if me and (me.Position - d.origin).Magnitude < d.radius * 1.5 then
		VFX.screenTint(t.dark:Lerp(t.main, 0.4), 0.55, d.duration)
	end
	shakeNear(d.origin, d.radius * 2, 2, 0.5)
end

function play.bolt(d)
	VFX.projectile(d.from, d.to, VFX.theme.main, d.travel)
	task.delay(d.travel, function()
		VFX.flash(d.to, VFX.theme.light, d.radius * 1.5)
		VFX.smoke(d.to, VFX.theme.dark, 8, 3, 0.6)
		VFX.sparks(d.to, VFX.theme.main, 15, 30)
		shakeNear(d.to, 25, 1, 0.15)
	end)
end

function play.damage(d)
	VFX.damageNumber(d.position, d.amount)
end

function VFX.play(kind: string, data)
	local fn = play[kind]
	if fn then
		task.spawn(fn, data)
	end
end

return VFX
