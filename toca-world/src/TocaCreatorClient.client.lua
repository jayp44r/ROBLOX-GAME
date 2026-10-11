-- TocaCreatorClient (LocalScript in StarterPlayerScripts)
-- The Toca-style character creator screen, pop-up messages, the mirror and the bouncy bed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local Options = require(ReplicatedStorage:WaitForChild("TocaOptions"))
local Remotes = ReplicatedStorage:WaitForChild("TocaRemotes")
local ChangeLook = Remotes:WaitForChild("ChangeLook")
local Toast = Remotes:WaitForChild("Toast")

local FONT = Enum.Font.FredokaOne
local INK = Color3.fromRGB(70, 48, 84)
local GOLD = Color3.fromRGB(255, 196, 44)

local function c(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function tween(obj, props, time, style, dir)
	local t = TweenService:Create(obj, TweenInfo.new(time or 0.2, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

---------------------------------------------------------------------------
-- Little UI kit
---------------------------------------------------------------------------
local strokes = {}

local function new(class, props, children)
	local obj = Instance.new(class)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then
			obj[k] = v
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = obj
	end
	if props and props.Parent then
		obj.Parent = props.Parent
	end
	return obj
end

local function corner(scale)
	return new("UICorner", { CornerRadius = UDim.new(scale or 0.25, 0) })
end

local function stroke(thickness, color, forText)
	local s = new("UIStroke", {
		Thickness = thickness,
		Color = color or INK,
		ApplyStrokeMode = forText and Enum.ApplyStrokeMode.Contextual or Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
	table.insert(strokes, { Stroke = s, Base = thickness })
	return s
end

local function gradient(top, bottom)
	return new("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = 90 })
end

local function label(text, props)
	local l = new("TextLabel", {
		BackgroundTransparency = 1,
		Font = FONT,
		Text = text,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		Size = UDim2.fromScale(1, 1),
	}, { stroke(2.5, INK, true) })
	for k, v in pairs(props or {}) do
		l[k] = v
	end
	return l
end

local clickSound = new("Sound", { SoundId = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.35, Parent = SoundService })

local function pressFx(button)
	local scale = new("UIScale", { Parent = button })
	button.MouseEnter:Connect(function()
		tween(scale, { Scale = 1.06 }, 0.12)
	end)
	button.MouseLeave:Connect(function()
		tween(scale, { Scale = 1 }, 0.12)
	end)
	button.MouseButton1Down:Connect(function()
		tween(scale, { Scale = 0.92 }, 0.06)
	end)
	button.MouseButton1Up:Connect(function()
		tween(scale, { Scale = 1 }, 0.15, Enum.EasingStyle.Back)
	end)
	button.Activated:Connect(function()
		SoundService:PlayLocalSound(clickSound)
	end)
end

-- Round button sized from screen height so it stays a circle on every device
local function roundButton(parent, name, color, icon, position, size)
	local b = new("TextButton", {
		Name = name,
		Parent = parent,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Position = position,
		Size = UDim2.fromScale(size, size),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
	}, {
		corner(1),
		stroke(3),
		gradient(color, color:Lerp(Color3.new(0, 0, 0), 0.18)),
		label(icon, { Size = UDim2.fromScale(0.62, 0.62), Position = UDim2.fromScale(0.19, 0.17) }),
	})
	pressFx(b)
	return b
end

---------------------------------------------------------------------------
-- Screen
---------------------------------------------------------------------------
local gui = new("ScreenGui", {
	Name = "TocaCreatorGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

-- HUD: sparkle button top-left, like Toca's home screen
local hud = new("Frame", { Name = "Hud", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = gui })
local styleButton = roundButton(hud, "StyleButton", c(84, 218, 210), "✨", UDim2.fromScale(0.015, 0.03), 0.13)
new("Frame", {
	Name = "Dot",
	Parent = styleButton,
	BackgroundColor3 = c(255, 70, 90),
	Position = UDim2.fromScale(0.72, -0.04),
	Size = UDim2.fromScale(0.3, 0.3),
}, { corner(1), stroke(2, Color3.new(1, 1, 1)) })
label("Style", { Parent = styleButton, Size = UDim2.fromScale(1.4, 0.34), Position = UDim2.fromScale(-0.2, 1.02) })

-- Creator screen
local creator = new("Frame", { Name = "Creator", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = gui })

label("Create your look!", {
	Name = "Title",
	Parent = creator,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.3, 0.03),
	Size = UDim2.fromScale(0.36, 0.08),
})

local backButton = roundButton(creator, "BackButton", c(255, 150, 64), "←", UDim2.fromScale(0.015, 0.03), 0.12)
local undoButton = roundButton(creator, "UndoButton", c(240, 80, 90), "↺", UDim2.fromScale(0.015, 0.19), 0.12)
local shuffleButton = roundButton(creator, "ShuffleButton", c(255, 210, 70), "🎲", UDim2.fromScale(0.015, 0.35), 0.12)

local panel = new("Frame", {
	Name = "OptionsPanel",
	Parent = creator,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(0.985, 0.04),
	Size = UDim2.fromScale(0.4, 0.74),
	BackgroundColor3 = Color3.new(1, 1, 1),
}, {
	corner(0.06),
	stroke(3.5),
	gradient(c(210, 244, 250), c(176, 228, 242)),
	new("UISizeConstraint", { MaxSize = Vector2.new(760, 900) }),
})
local panelScale = new("UIScale", { Parent = panel })

local panelTitle = label("Hair", {
	Name = "CategoryTitle",
	Parent = panel,
	Position = UDim2.fromScale(0.05, 0.02),
	Size = UDim2.fromScale(0.9, 0.1),
})

local grid = new("ScrollingFrame", {
	Name = "ItemGrid",
	Parent = panel,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Position = UDim2.fromScale(0.04, 0.14),
	Size = UDim2.fromScale(0.92, 0.83),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = INK,
	ElasticBehavior = Enum.ElasticBehavior.Always,
}, {
	new("UIPadding", {
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0.02, 0),
		PaddingRight = UDim.new(0.04, 0),
	}),
	new("UIGridLayout", {
		CellSize = UDim2.fromScale(0.3, 0.3),
		CellPadding = UDim2.new(0.035, 0, 0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}, {
		new("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Width }),
	}),
})

local bar = new("Frame", {
	Name = "CategoryBar",
	Parent = creator,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromScale(0.5, 0.985),
	Size = UDim2.fromScale(0.96, 0.16),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 0.1,
}, {
	corner(0.3),
	stroke(3),
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0.012, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})
local barScale = new("UIScale", { Parent = bar })

local toastLabel = label("", {
	Name = "Toast",
	Parent = gui,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.2),
	Size = UDim2.fromScale(0.6, 0.1),
	Visible = false,
	ZIndex = 20,
})
local toastScale = new("UIScale", { Parent = toastLabel })

---------------------------------------------------------------------------
-- Fit every screen: phones get a bigger panel, outlines follow screen size
---------------------------------------------------------------------------
local function layout()
	local view = camera.ViewportSize
	local phone = view.Y < 600
	panel.Size = phone and UDim2.fromScale(0.46, 0.72) or UDim2.fromScale(0.4, 0.74)
	bar.Size = phone and UDim2.fromScale(0.98, 0.19) or UDim2.fromScale(0.96, 0.16)
	local factor = math.clamp(view.Y / 1080, 0.45, 1.4)
	for _, s in ipairs(strokes) do
		s.Stroke.Thickness = math.max(1, s.Base * factor)
	end
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)

---------------------------------------------------------------------------
-- Look state
---------------------------------------------------------------------------
local function foundCrumpet()
	return player:GetAttribute("FoundCrumpet") == true
end

local function readLook()
	local raw = player:GetAttribute("TocaLook")
	local ok, look = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	return Options.Sanitize(ok and look or nil, foundCrumpet())
end

local current = readLook()
local history = {}
local isOpen = false
local activeCategory

local function copy(t)
	local out = {}
	for k, v in pairs(t) do
		out[k] = v
	end
	return out
end

local categories = {
	{ Key = "Skin", Label = "Skin", Icon = "🎨", Color = c(255, 200, 160), Kind = "Color" },
	{ Key = "Hair", Label = "Hair", Icon = "💇", Color = c(255, 170, 212), Kind = "Item" },
	{ Key = "HairColor", Label = "Hair Color", Icon = "🌈", Color = c(200, 172, 255), Kind = "Color" },
	{ Key = "Eyes", Label = "Eyes", Icon = "👀", Color = c(140, 214, 255), Kind = "Item" },
	{ Key = "Top", Label = "Top", Icon = "👕", Color = c(150, 230, 170), Kind = "Color" },
	{ Key = "Bottom", Label = "Bottom", Icon = "👖", Color = c(130, 178, 255), Kind = "Color" },
	{ Key = "Hat", Label = "Hats", Icon = "🎩", Color = c(255, 220, 110), Kind = "Item" },
	{ Key = "Presets", Label = "Styles", Icon = "⭐", Color = c(255, 150, 150), Kind = "Preset" },
}

local renderCategory -- defined below

local function setLook(look, remember)
	if remember then
		table.insert(history, copy(current))
		if #history > 30 then
			table.remove(history, 1)
		end
	end
	current = Options.Sanitize(look, foundCrumpet())
	ChangeLook:FireServer(current)
	if activeCategory then
		renderCategory(activeCategory)
	end
end

---------------------------------------------------------------------------
-- Pop-up messages and confetti
---------------------------------------------------------------------------
local toastId = 0
local function confetti()
	local bits = { "🎉", "✨", "💖", "⭐", "🌸", "🐾" }
	for _ = 1, 26 do
		local x = math.random()
		local bit = label(bits[math.random(#bits)], {
			Parent = gui,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, -0.05),
			Size = UDim2.fromScale(0.05, 0.05),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			Rotation = math.random(-40, 40),
			ZIndex = 19,
		})
		local fall = 1.6 + math.random() * 1.2
		tween(bit, { Position = UDim2.fromScale(x + (math.random() - 0.5) * 0.2, 1.1), Rotation = math.random(-200, 200) }, fall, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
		task.delay(fall, function()
			bit:Destroy()
		end)
	end
end

local function showToast(text, kind)
	toastId += 1
	local id = toastId
	toastLabel.Text = text
	toastLabel.TextColor3 = kind == "rare" and GOLD or Color3.new(1, 1, 1)
	toastLabel.Visible = true
	toastScale.Scale = 0
	tween(toastScale, { Scale = 1 }, 0.35, Enum.EasingStyle.Back)
	if kind == "rare" then
		confetti()
	end
	task.delay(3.2, function()
		if id == toastId then
			tween(toastScale, { Scale = 0 }, 0.2).Completed:Wait()
			if id == toastId then
				toastLabel.Visible = false
			end
		end
	end)
end

Toast.OnClientEvent:Connect(showToast)

---------------------------------------------------------------------------
-- Item cards
---------------------------------------------------------------------------
local function card(order, selected, onClick)
	local b = new("TextButton", {
		Parent = grid,
		LayoutOrder = order,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = selected and c(255, 246, 196) or Color3.new(1, 1, 1),
	}, {
		corner(0.2),
		stroke(selected and 5 or 3, selected and GOLD or INK),
	})
	pressFx(b)
	b.Activated:Connect(onClick)
	return b
end

local function nameTag(parent, text)
	label(text, {
		Parent = parent,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.95),
		Size = UDim2.fromScale(0.9, 0.24),
	})
end

renderCategory = function(category)
	activeCategory = category
	panelTitle.Text = category.Icon .. " " .. category.Label
	for _, child in ipairs(grid:GetChildren()) do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
	-- These strokes are gone now, stop tracking them
	for i = #strokes, 1, -1 do
		if not strokes[i].Stroke.Parent then
			table.remove(strokes, i)
		end
	end

	local first
	if category.Kind == "Preset" then
		for i, preset in ipairs(Options.Presets) do
			local b = card(i, false, function()
				setLook(preset.Look, true)
				showToast(preset.Icon .. " " .. preset.Name .. "!", "info")
			end)
			label(preset.Icon, { Parent = b, Size = UDim2.fromScale(0.56, 0.5), Position = UDim2.fromScale(0.22, 0.1) })
			nameTag(b, preset.Name)
			first = first or b
		end
	else
		local list = Options[category.Key]
		for i, option in ipairs(list) do
			local locked = option.Secret and not foundCrumpet()
			local selected = current[category.Key] == i
			local b = card(i, selected, function()
				if locked then
					showToast("🔒 Find the hidden Crumpet to unlock this!", "info")
					return
				end
				local look = copy(current)
				look[category.Key] = i
				setLook(look, true)
			end)
			if category.Kind == "Color" then
				new("Frame", {
					Parent = b,
					BackgroundColor3 = option.Color,
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromScale(0.5, 0.1),
					Size = UDim2.fromScale(0.55, 0.55),
					SizeConstraint = Enum.SizeConstraint.RelativeXX,
				}, { corner(1), stroke(3) })
			else
				label(locked and "🔒" or option.Icon, { Parent = b, Size = UDim2.fromScale(0.56, 0.5), Position = UDim2.fromScale(0.22, 0.1) })
			end
			nameTag(b, locked and "???" or option.Name)
			if selected or not first then
				first = b
			end
		end
	end
	layout()
	if isOpen and first and GuiService.SelectedObject then
		GuiService.SelectedObject = first
	end
end

for i, category in ipairs(categories) do
	local b = new("TextButton", {
		Name = category.Key,
		Parent = bar,
		LayoutOrder = i,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(0.84, 0.84),
	}, {
		corner(1),
		stroke(3),
		gradient(category.Color, category.Color:Lerp(Color3.new(0, 0, 0), 0.15)),
		new("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height }),
		label(category.Icon, { Size = UDim2.fromScale(0.5, 0.5), Position = UDim2.fromScale(0.25, 0.1) }),
		label(category.Label, { Size = UDim2.fromScale(0.9, 0.26), Position = UDim2.fromScale(0.05, 0.62) }),
	})
	pressFx(b)
	b.Activated:Connect(function()
		renderCategory(category)
		panelScale.Scale = 0.9
		tween(panelScale, { Scale = 1 }, 0.25, Enum.EasingStyle.Back)
	end)
end

---------------------------------------------------------------------------
-- Open / close with a close-up camera
---------------------------------------------------------------------------
local savedMove

local function open()
	if isOpen then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	isOpen = true
	current = readLook()
	history = {}
	savedMove = { humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight }
	humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight = 0, 0, 0

	-- Character on the left of the screen, options on the right
	local target = root.Position + Vector3.new(0, 1.2, 0) - root.CFrame.RightVector * 4.2
	local eye = target + root.CFrame.LookVector * 11 + Vector3.new(0, 0.8, 0)
	camera.CameraType = Enum.CameraType.Scriptable
	tween(camera, { CFrame = CFrame.lookAt(eye, target) }, 0.6, Enum.EasingStyle.Sine)

	hud.Visible = false
	creator.Visible = true
	renderCategory(activeCategory or categories[2])
	panelScale.Scale, barScale.Scale = 0, 0
	tween(panelScale, { Scale = 1 }, 0.4, Enum.EasingStyle.Back)
	tween(barScale, { Scale = 1 }, 0.4, Enum.EasingStyle.Back)
	local dot = styleButton:FindFirstChild("Dot")
	if dot then
		dot.Visible = false
	end
	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = bar:FindFirstChild(activeCategory.Key)
	end
end

local function close()
	if not isOpen then
		return
	end
	isOpen = false
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and savedMove then
		humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight = savedMove[1], savedMove[2], savedMove[3]
	end
	camera.CameraType = Enum.CameraType.Custom
	tween(panelScale, { Scale = 0 }, 0.2)
	tween(barScale, { Scale = 0 }, 0.2).Completed:Wait()
	creator.Visible = false
	hud.Visible = true
	GuiService.SelectedObject = nil
end

styleButton.Activated:Connect(open)
backButton.Activated:Connect(close)

undoButton.Activated:Connect(function()
	local last = table.remove(history)
	if last then
		setLook(last, false)
	else
		showToast("Nothing to undo!", "info")
	end
end)

shuffleButton.Activated:Connect(function()
	local look = {}
	for _, field in ipairs(Options.Fields) do
		look[field] = math.random(#Options[field])
	end
	if Options.Hat[look.Hat].Secret and not foundCrumpet() then
		look.Hat = 1
	end
	setLook(look, true)
	if math.random(12) == 1 then
		showToast("🌟 Super rare shuffle! You look AMAZING", "rare")
	end
end)

player:GetAttributeChangedSignal("FoundCrumpet"):Connect(function()
	if isOpen and activeCategory then
		renderCategory(activeCategory)
	end
end)
player:GetAttributeChangedSignal("TocaLook"):Connect(function()
	if not isOpen then
		current = readLook()
	end
end)
player.CharacterAdded:Connect(function()
	if isOpen then
		isOpen = false
		creator.Visible = false
		hud.Visible = true
		camera.CameraType = Enum.CameraType.Custom
	end
end)

---------------------------------------------------------------------------
-- Room bits: the vanity mirror opens the creator, the bed is a trampoline
---------------------------------------------------------------------------
task.spawn(function()
	local room = workspace:WaitForChild("TocaWorld"):WaitForChild("Bedroom")

	local mirror = room:WaitForChild("Vanity"):WaitForChild("Mirror")
	mirror:WaitForChild("MirrorPrompt").Triggered:Connect(open)

	local mattress = room:WaitForChild("Bed"):WaitForChild("BouncyMattress")
	local lastBounce = 0
	mattress.Touched:Connect(function(hit)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not hit:IsDescendantOf(character) or os.clock() - lastBounce < 0.5 then
			return
		end
		lastBounce = os.clock()
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(v.X, 62, v.Z)
	end)
end)

layout()
task.delay(4, function()
	showToast("Psst... a Crumpet is hiding somewhere in this room 👀", "info")
end)
