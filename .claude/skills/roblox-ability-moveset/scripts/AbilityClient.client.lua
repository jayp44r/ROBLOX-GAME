-- AbilityClient: LocalScript in StarterPlayer > StarterPlayerScripts.
-- Keys / buttons cast abilities, shows the cooldown bar, the hold-Q ability wheel,
-- and draws every effect the server announces.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("AbilityConfig"))
local VFX = require(ReplicatedStorage:WaitForChild("AbilityVFX"))
local remotes = ReplicatedStorage:WaitForChild("AbilityRemotes")
local castRemote = remotes:WaitForChild("Cast") :: RemoteEvent
local effectRemote = remotes:WaitForChild("Effect") :: RemoteEvent

local player = Players.LocalPlayer
local theme = Config.theme
VFX.theme = theme

effectRemote.OnClientEvent:Connect(function(kind, data)
	VFX.play(kind, data)
end)

---------------------------------------------------------------------------- UI

local PANEL = Color3.fromRGB(20, 14, 32)

local gui = Instance.new("ScreenGui")
gui.Name = "Abilities"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local function rounded(inst: GuiObject, stroke: boolean?)
	Instance.new("UICorner", inst).CornerRadius = UDim.new(0, 10)
	if stroke then
		local s = Instance.new("UIStroke")
		s.Color = theme.main
		s.Transparency = 0.3
		s.Thickness = 1.5
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = inst
	end
end

local function label(parent: Instance, text: string, size: UDim2, pos: UDim2): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size, l.Position = size, pos
	l.Font = Enum.Font.GothamBold
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextScaled = true
	l.Text = text
	l.Parent = parent
	return l
end

-- Character pill (bottom left) like "DARK SELF / READY".
local pill = Instance.new("Frame")
pill.AnchorPoint = Vector2.new(0, 1)
pill.Position = UDim2.new(0, 16, 1, -16)
pill.Size = UDim2.fromOffset(170, 44)
pill.BackgroundColor3 = PANEL
pill.Parent = gui
rounded(pill, true)
label(pill, Config.name, UDim2.new(1, -36, 0, 18), UDim2.fromOffset(28, 5)).TextXAlignment = Enum.TextXAlignment.Left
local stateText = label(pill, "READY", UDim2.new(1, -36, 0, 11), UDim2.fromOffset(28, 24))
stateText.TextXAlignment = Enum.TextXAlignment.Left
stateText.TextColor3 = theme.light
local gem = Instance.new("Frame")
gem.Size, gem.Position = UDim2.fromOffset(12, 12), UDim2.fromOffset(10, 16)
gem.BackgroundColor3 = theme.main
gem.Parent = pill
Instance.new("UICorner", gem).CornerRadius = UDim.new(1, 0)

-- Cast text (bottom centre): "[E] OUTBURST · 4.2s".
local castPill = Instance.new("Frame")
castPill.AnchorPoint = Vector2.new(0.5, 1)
castPill.Position = UDim2.new(0.5, 0, 1, -96)
castPill.Size = UDim2.fromOffset(240, 26)
castPill.BackgroundColor3 = PANEL
castPill.Parent = gui
rounded(castPill, true)
local castText = label(castPill, "HOLD " .. Config.wheelKey.Name .. " · ABILITIES", UDim2.new(1, -16, 1, -8), UDim2.fromOffset(8, 4))
castText.TextColor3 = theme.light

-- Ability bar (bottom centre): one button per ability, tappable on phone.
local bar = Instance.new("Frame")
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.new(0.5, 0, 1, -16)
bar.Size = UDim2.fromOffset(#Config.abilities * 70, 70)
bar.BackgroundTransparency = 1
bar.Parent = gui
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Padding = UDim.new(0, 8)
layout.Parent = bar

local readyAt: { [string]: number } = {}
local buttons = {}

local function aimPoint(): Vector3
	local cam = workspace.CurrentCamera
	local screen = if UserInputService.TouchEnabled or UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
		then cam.ViewportSize / 2
		else UserInputService:GetMouseLocation()
	local ray = cam:ViewportPointToRay(screen.X, screen.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance }
	local result = workspace:Raycast(ray.Origin, ray.Direction * 300, params)
	return if result then result.Position else ray.Origin + ray.Direction * 300
end

local lastCast = nil

local function cast(ability)
	local now = os.clock()
	if (readyAt[ability.id] or 0) > now then
		return
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or humanoid:GetAttribute("Stunned") then
		return
	end
	readyAt[ability.id] = now + ability.cooldown
	lastCast = ability
	castRemote:FireServer(ability.id, aimPoint())
	local b = buttons[ability.id]
	if b then
		b.scale.Scale = 0.85
		TweenService:Create(b.scale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
end

for _, ability in Config.abilities do
	local button = Instance.new("TextButton")
	button.Name = ability.id
	button.Size = UDim2.fromOffset(62, 62)
	button.BackgroundColor3 = PANEL
	button.AutoButtonColor = false
	button.Text = ""
	button.Parent = bar
	rounded(button, true)
	local scale = Instance.new("UIScale")
	scale.Parent = button
	local keyText = label(button, ability.key.Name, UDim2.new(1, 0, 0, 22), UDim2.fromOffset(0, 8))
	keyText.TextColor3 = theme.light
	local nameText = label(button, string.upper(ability.id), UDim2.new(1, -6, 0, 12), UDim2.fromOffset(3, 38))
	nameText.Font = Enum.Font.Gotham
	-- Dark overlay that shrinks as the cooldown runs out.
	local cover = Instance.new("Frame")
	cover.AnchorPoint = Vector2.new(0, 1)
	cover.Position = UDim2.fromScale(0, 1)
	cover.Size = UDim2.fromScale(1, 0)
	cover.BackgroundColor3 = Color3.new(0, 0, 0)
	cover.BackgroundTransparency = 0.4
	cover.ZIndex = 2
	cover.Parent = button
	Instance.new("UICorner", cover).CornerRadius = UDim.new(0, 10)
	local timer = label(button, "", UDim2.fromScale(1, 0.5), UDim2.fromScale(0, 0.25))
	timer.ZIndex = 3
	buttons[ability.id] = { button = button, cover = cover, timer = timer, scale = scale, ability = ability }
	button.Activated:Connect(function()
		cast(ability)
	end)
end

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local anyCooling = false
	for id, b in buttons do
		local left = (readyAt[id] or 0) - now
		if left > 0 then
			anyCooling = true
			b.cover.Size = UDim2.fromScale(1, left / b.ability.cooldown)
			b.timer.Text = string.format("%.1f", left)
		else
			b.cover.Size = UDim2.fromScale(1, 0)
			b.timer.Text = ""
		end
	end
	if lastCast then
		local left = (readyAt[lastCast.id] or 0) - now
		castText.Text = if left > 0
			then string.format("[%s] %s · %.1fs", lastCast.key.Name, string.upper(lastCast.id), left)
			else "HOLD " .. Config.wheelKey.Name .. " · ABILITIES"
	end
	stateText.Text = if anyCooling then "COOLING DOWN" else "READY"
end)

---------------------------------------------------------------------------- hold-Q ability wheel

local wheel = Instance.new("Frame")
wheel.AnchorPoint = Vector2.new(0.5, 0.5)
wheel.Position = UDim2.fromScale(0.5, 0.5)
wheel.Size = UDim2.fromScale(0.5, 0.5)
wheel.BackgroundColor3 = PANEL
wheel.BackgroundTransparency = 0.15
wheel.Visible = false
wheel.Parent = gui
Instance.new("UIAspectRatioConstraint").Parent = wheel
local wheelMax = Instance.new("UISizeConstraint")
wheelMax.MaxSize = Vector2.new(420, 420)
wheelMax.Parent = wheel
Instance.new("UICorner", wheel).CornerRadius = UDim.new(1, 0)
local wheelStroke = Instance.new("UIStroke")
wheelStroke.Color = theme.main
wheelStroke.Thickness = 2
wheelStroke.Parent = wheel
local wheelTitle = label(wheel, "", UDim2.fromScale(0.4, 0.12), UDim2.fromScale(0.3, 0.44))

local slots = {}
for i, ability in Config.abilities do
	local a = -math.pi / 2 + (i - 1) * (2 * math.pi / #Config.abilities)
	local slot = Instance.new("TextButton")
	slot.AnchorPoint = Vector2.new(0.5, 0.5)
	slot.Position = UDim2.fromScale(0.5 + math.cos(a) * 0.36, 0.5 + math.sin(a) * 0.36)
	slot.Size = UDim2.fromScale(0.2, 0.2)
	slot.BackgroundColor3 = Color3.fromRGB(40, 28, 64)
	slot.AutoButtonColor = false
	slot.Text = ability.key.Name
	slot.Font = Enum.Font.GothamBold
	slot.TextScaled = true
	slot.TextColor3 = Color3.new(1, 1, 1)
	slot.Parent = wheel
	Instance.new("UICorner", slot).CornerRadius = UDim.new(1, 0)
	local stroke = Instance.new("UIStroke")
	stroke.Color = theme.main
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = slot
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0.25, 0), UDim.new(0.25, 0)
	pad.Parent = slot
	slots[i] = { slot = slot, stroke = stroke, angle = a, ability = ability }
end

local picked = nil
local function pick(entry)
	if picked == entry then
		return
	end
	if picked then
		picked.slot.BackgroundColor3 = Color3.fromRGB(40, 28, 64)
		picked.stroke.Color = theme.main
	end
	picked = entry
	if entry then
		entry.slot.BackgroundColor3 = theme.main
		entry.stroke.Color = theme.light
		wheelTitle.Text = string.upper(entry.ability.id)
	end
end

for _, entry in slots do
	entry.slot.MouseEnter:Connect(function()
		pick(entry)
	end)
	entry.slot.Activated:Connect(function()
		pick(entry)
		wheel.Visible = false
		cast(entry.ability)
	end)
end

local function openWheel()
	wheel.Visible = true
	pick(slots[1])
end

local function closeWheel(useIt: boolean)
	if not wheel.Visible then
		return
	end
	wheel.Visible = false
	if useIt and picked then
		cast(picked.ability)
	end
end

UserInputService.InputChanged:Connect(function(input)
	if wheel.Visible and input.UserInputType == Enum.UserInputType.MouseMovement then
		local mid = wheel.AbsolutePosition + wheel.AbsoluteSize / 2
		local dir = UserInputService:GetMouseLocation() - mid
		if dir.Magnitude > 20 then
			local ang = math.atan2(dir.Y, dir.X)
			local best, bestDiff = nil, math.huge
			for _, entry in slots do
				local diff = math.abs((ang - entry.angle + math.pi) % (2 * math.pi) - math.pi)
				if diff < bestDiff then
					best, bestDiff = entry, diff
				end
			end
			pick(best)
		end
	end
end)

---------------------------------------------------------------------------- keys

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Config.wheelKey then
		openWheel()
		return
	end
	for _, ability in Config.abilities do
		if input.KeyCode == ability.key then
			cast(ability)
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Config.wheelKey then
		closeWheel(true)
	end
end)
