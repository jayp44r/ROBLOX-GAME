-- GTA-style weapon wheel. LocalScript in StarterPlayer > StarterPlayerScripts.
-- PC: hold Tab (or Q), point the mouse at a weapon, let go.
-- Phone: tap the wheel button, tap a weapon.  Gamepad: hold L1, aim the right stick, let go.
-- Weapons are the Tools in the player's Backpack (up to 8), plus "Unarmed".

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local ACCENT = Color3.fromRGB(70, 230, 170)
local RADIUS = 0.36 -- slot distance from centre, as a fraction of the wheel size
local MAX_SLOTS = 8
local OPEN_KEYS = { [Enum.KeyCode.Tab] = true, [Enum.KeyCode.Q] = true, [Enum.KeyCode.ButtonL1] = true }

local gui = Instance.new("ScreenGui")
gui.Name = "WeaponWheel"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local wheel = Instance.new("Frame")
wheel.Name = "Wheel"
wheel.AnchorPoint = Vector2.new(0.5, 0.5)
wheel.Position = UDim2.fromScale(0.5, 0.5)
wheel.Size = UDim2.fromScale(0.55, 0.55)
wheel.BackgroundColor3 = Color3.fromRGB(15, 18, 24)
wheel.BackgroundTransparency = 0.35
wheel.Visible = false
wheel.Parent = gui
Instance.new("UIAspectRatioConstraint").Parent = wheel
local wheelLimit = Instance.new("UISizeConstraint")
wheelLimit.MaxSize = Vector2.new(460, 460)
wheelLimit.Parent = wheel
Instance.new("UICorner", wheel).CornerRadius = UDim.new(1, 0)
local wheelStroke = Instance.new("UIStroke")
wheelStroke.Color = Color3.new(1, 1, 1)
wheelStroke.Transparency = 0.7
wheelStroke.Thickness = 2
wheelStroke.Parent = wheel
local wheelScale = Instance.new("UIScale")
wheelScale.Parent = wheel

local center = Instance.new("TextLabel")
center.Name = "Selected"
center.AnchorPoint = Vector2.new(0.5, 0.5)
center.Position = UDim2.fromScale(0.5, 0.5)
center.Size = UDim2.fromScale(0.34, 0.34)
center.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
center.BackgroundTransparency = 0.1
center.TextColor3 = Color3.new(1, 1, 1)
center.Font = Enum.Font.GothamBold
center.TextScaled = true
center.Text = ""
center.Parent = wheel
Instance.new("UICorner", center).CornerRadius = UDim.new(1, 0)
local centerPad = Instance.new("UIPadding")
centerPad.PaddingLeft = UDim.new(0.15, 0)
centerPad.PaddingRight = UDim.new(0.15, 0)
centerPad.Parent = center

-- Little pointer that orbits the centre towards the highlighted slot.
local pointer = Instance.new("Frame")
pointer.Name = "Pointer"
pointer.AnchorPoint = Vector2.new(0.5, 0.5)
pointer.Size = UDim2.fromScale(0.04, 0.04)
pointer.BackgroundColor3 = ACCENT
pointer.Parent = wheel
Instance.new("UICorner", pointer).CornerRadius = UDim.new(1, 0)

local mobileButton = Instance.new("TextButton")
mobileButton.Name = "WheelButton"
mobileButton.AnchorPoint = Vector2.new(1, 1)
mobileButton.Position = UDim2.new(1, -20, 0.62, 0)
mobileButton.Size = UDim2.fromOffset(64, 64)
mobileButton.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
mobileButton.BackgroundTransparency = 0.2
mobileButton.Text = "🔫"
mobileButton.TextScaled = true
mobileButton.Visible = UserInputService.TouchEnabled
mobileButton.Parent = gui
Instance.new("UICorner", mobileButton).CornerRadius = UDim.new(1, 0)
local mobileStroke = Instance.new("UIStroke")
mobileStroke.Color = ACCENT
mobileStroke.Thickness = 2
mobileStroke.Parent = mobileButton

local blur = Instance.new("BlurEffect")
blur.Name = "WeaponWheelBlur"
blur.Size = 0
blur.Parent = Lighting

local slots = {} -- { frame, stroke, tool (nil = unarmed), angle }
local hovered = nil
local isOpen = false
local stickDir = Vector2.zero
local close -- defined below; slot buttons call it

local function equipped()
	local character = player.Character
	return character and character:FindFirstChildOfClass("Tool")
end

local function weaponList()
	local list = {}
	local current = equipped()
	if current then
		table.insert(list, current)
	end
	for _, item in player.Backpack:GetChildren() do
		if item:IsA("Tool") and #list < MAX_SLOTS - 1 then
			table.insert(list, item)
		end
	end
	return list
end

local function setHovered(slot)
	if hovered == slot then
		return
	end
	if hovered then
		TweenService:Create(hovered.frame, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(35, 42, 55) }):Play()
		hovered.stroke.Color = Color3.new(1, 1, 1)
		hovered.stroke.Transparency = 0.6
	end
	hovered = slot
	if slot then
		TweenService:Create(slot.frame, TweenInfo.new(0.1), { BackgroundColor3 = ACCENT:Lerp(Color3.new(0, 0, 0), 0.55) }):Play()
		slot.stroke.Color = ACCENT
		slot.stroke.Transparency = 0
		center.Text = slot.tool and slot.tool.Name or "Unarmed"
		local a = slot.angle
		pointer.Position = UDim2.fromScale(0.5 + math.cos(a) * 0.2, 0.5 + math.sin(a) * 0.2)
	end
end

local function buildSlots()
	for _, slot in slots do
		slot.frame:Destroy()
	end
	table.clear(slots)
	hovered = nil

	local tools = weaponList()
	local entries = { false } -- false = unarmed
	for _, tool in tools do
		table.insert(entries, tool)
	end
	local current = equipped()

	for i, tool in entries do
		-- Slot 1 at the top, going clockwise.
		local angle = -math.pi / 2 + (i - 1) * (2 * math.pi / #entries)
		local frame = Instance.new("TextButton")
		frame.Name = "Slot" .. i
		frame.AutoButtonColor = false
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.fromScale(0.5 + math.cos(angle) * RADIUS, 0.5 + math.sin(angle) * RADIUS)
		frame.Size = UDim2.fromScale(0.22, 0.22)
		frame.BackgroundColor3 = Color3.fromRGB(35, 42, 55)
		frame.Text = ""
		frame.Parent = wheel
		Instance.new("UICorner", frame).CornerRadius = UDim.new(1, 0)
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.new(1, 1, 1)
		stroke.Transparency = 0.6
		stroke.Thickness = 2
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = frame

		if tool and tool.TextureId ~= "" then
			local icon = Instance.new("ImageLabel")
			icon.BackgroundTransparency = 1
			icon.AnchorPoint = Vector2.new(0.5, 0.5)
			icon.Position = UDim2.fromScale(0.5, 0.5)
			icon.Size = UDim2.fromScale(0.7, 0.7)
			icon.Image = tool.TextureId
			icon.ScaleType = Enum.ScaleType.Fit
			icon.Parent = frame
		else
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(1, 1)
			label.Text = tool and tool.Name or "✋"
			label.TextColor3 = Color3.new(1, 1, 1)
			label.Font = Enum.Font.GothamBold
			label.TextScaled = true
			label.Parent = frame
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft, pad.PaddingRight = UDim.new(0.12, 0), UDim.new(0.12, 0)
			pad.PaddingTop, pad.PaddingBottom = UDim.new(0.25, 0), UDim.new(0.25, 0)
			pad.Parent = label
		end

		if (tool and tool == current) or (not tool and not current) then
			local check = Instance.new("TextLabel")
			check.Name = "Equipped"
			check.BackgroundColor3 = ACCENT
			check.AnchorPoint = Vector2.new(0.5, 0.5)
			check.Position = UDim2.fromScale(0.85, 0.15)
			check.Size = UDim2.fromScale(0.3, 0.3)
			check.Text = "✓"
			check.TextScaled = true
			check.TextColor3 = Color3.new(0, 0, 0)
			check.Font = Enum.Font.GothamBold
			check.Parent = frame
			Instance.new("UICorner", check).CornerRadius = UDim.new(1, 0)
		end

		local slot = { frame = frame, stroke = stroke, tool = tool or nil, angle = angle }
		table.insert(slots, slot)
		frame.MouseEnter:Connect(function()
			setHovered(slot)
		end)
		frame.Activated:Connect(function()
			setHovered(slot)
			if UserInputService.TouchEnabled then
				close(true)
			end
		end)
	end
	setHovered(slots[1])
end

local function pickByDirection(dir: Vector2)
	if dir.Magnitude < 0.35 or #slots == 0 then
		return
	end
	local angle = math.atan2(dir.Y, dir.X)
	local best, bestDiff = nil, math.huge
	for _, slot in slots do
		local diff = math.abs((angle - slot.angle + math.pi) % (2 * math.pi) - math.pi)
		if diff < bestDiff then
			best, bestDiff = slot, diff
		end
	end
	setHovered(best)
end

local function open()
	if isOpen or not player.Character then
		return
	end
	isOpen = true
	buildSlots()
	wheel.Visible = true
	wheelScale.Scale = 0.85
	TweenService:Create(wheelScale, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	TweenService:Create(blur, TweenInfo.new(0.15), { Size = 14 }):Play()
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
end

close = function(apply: boolean)
	if not isOpen then
		return
	end
	isOpen = false
	wheel.Visible = false
	TweenService:Create(blur, TweenInfo.new(0.15), { Size = 0 }):Play()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if apply and hovered and humanoid then
		if hovered.tool then
			humanoid:EquipTool(hovered.tool)
		else
			humanoid:UnequipTools()
		end
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if OPEN_KEYS[input.KeyCode] and not processed then
		open()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if OPEN_KEYS[input.KeyCode] then
		close(true)
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if not isOpen then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		local mid = wheel.AbsolutePosition + wheel.AbsoluteSize / 2
		local mouse = UserInputService:GetMouseLocation()
		pickByDirection(mouse - mid)
	elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
		stickDir = Vector2.new(input.Position.X, -input.Position.Y)
	end
end)

RunService.RenderStepped:Connect(function()
	if isOpen and stickDir.Magnitude > 0.35 then
		pickByDirection(stickDir)
	end
end)

mobileButton.Activated:Connect(function()
	if isOpen then
		close(false)
	else
		open()
	end
end)
