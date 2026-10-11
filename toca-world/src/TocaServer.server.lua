-- TocaServer (Script in ServerScriptService)
-- Builds each player's Toca-style look, saves it, and runs the bedroom secrets:
-- the hidden Crumpet behind the loose book and the mood light switch.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local Options = require(ReplicatedStorage:WaitForChild("TocaOptions"))
local Remotes = ReplicatedStorage:WaitForChild("TocaRemotes")
local ChangeLook = Remotes:WaitForChild("ChangeLook")
local Toast = Remotes:WaitForChild("Toast")

local Room = workspace:WaitForChild("TocaWorld"):WaitForChild("Bedroom")

local function c(r, g, b)
	return Color3.fromRGB(r, g, b)
end

---------------------------------------------------------------------------
-- Saving
---------------------------------------------------------------------------
local store
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("TocaWorld_v1")
	end)
	if ok then
		store = result
	end
end

local playerData = {}

local function loadData(player)
	local saved
	if store then
		local ok, result = pcall(function()
			return store:GetAsync("p_" .. player.UserId)
		end)
		if ok then
			saved = result
		else
			warn("[TocaWorld] Could not load saved look (turn on API access to save in Studio):", result)
		end
	end
	saved = type(saved) == "table" and saved or {}
	local found = saved.FoundCrumpet == true
	return { FoundCrumpet = found, Look = Options.Sanitize(saved.Look, found) }
end

local function saveData(player)
	local data = playerData[player]
	if not data or not store then
		return
	end
	pcall(function()
		store:SetAsync("p_" .. player.UserId, { FoundCrumpet = data.FoundCrumpet, Look = data.Look })
	end)
end

---------------------------------------------------------------------------
-- Building the look out of soft round pieces
---------------------------------------------------------------------------
local INK = c(46, 34, 52)
local WHITE = c(255, 255, 255)

local function makePart(parent, name, size, cf, color, round)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	if round then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	p.Parent = parent
	return p
end

local BODY_TOP = { UpperTorso = true, LowerTorso = true, Torso = true, LeftUpperArm = true, RightUpperArm = true }
local BODY_SKIN = { Head = true, LeftLowerArm = true, RightLowerArm = true, LeftHand = true, RightHand = true, ["Left Arm"] = true, ["Right Arm"] = true }
local BODY_SHOES = { LeftFoot = true, RightFoot = true }

local function buildLook(character, look)
	local head = character:FindFirstChild("Head")
	if not head or not character:FindFirstChildOfClass("Humanoid") then
		return
	end

	local old = character:FindFirstChild("TocaLook")
	if old then
		old:Destroy()
	end
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Accessory") or child:IsA("Shirt") or child:IsA("Pants")
			or child:IsA("ShirtGraphic") or child:IsA("BodyColors") then
			child:Destroy()
		end
	end
	for _, child in ipairs(head:GetChildren()) do
		if child:IsA("Decal") then
			child:Destroy()
		end
	end
	head.Transparency = 1

	local skin = Options.Skin[look.Skin].Color
	local hairColor = Options.HairColor[look.HairColor].Color
	local top = Options.Top[look.Top].Color
	local bottom = Options.Bottom[look.Bottom].Color

	-- Body colours: t-shirt, skin arms, trousers, white sneakers
	for _, part in ipairs(character:GetChildren()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.Material = Enum.Material.SmoothPlastic
			if BODY_TOP[part.Name] then
				part.Color = top
			elseif BODY_SKIN[part.Name] then
				part.Color = skin
			elseif BODY_SHOES[part.Name] then
				part.Color = WHITE
			else
				part.Color = bottom
			end
		end
	end

	local folder = Instance.new("Folder")
	folder.Name = "TocaLook"

	-- Big round Toca head sitting on the neck
	local D = 2.2
	local R = D / 2
	local center = head.CFrame * CFrame.new(0, R - head.Size.Y / 2, 0)
	local ball = makePart(folder, "TocaHead", Vector3.new(D, D, D), center, skin, true)

	local function at(x, y, z)
		return center * CFrame.new(x * D, y * D, z * D)
	end
	-- A spot on the face: pitch up/down and yaw left/right in degrees
	local function onFace(pitch, yaw, out)
		return center * CFrame.Angles(math.rad(pitch), math.rad(yaw), 0) * CFrame.new(0, 0, -(R + out))
	end
	local function blob(name, size, cf, color)
		return makePart(folder, name, size, cf, color, true)
	end

	-- Face
	local eyes = Options.Eyes[look.Eyes].Name
	for _, side in ipairs({ -1, 1 }) do
		local yaw = 22 * side
		if eyes == "Big" or eyes == "Sparkle" then
			blob("EyeWhite", Vector3.new(0.55, 0.66, 0.2), onFace(-2, yaw, -0.03), WHITE)
			local pupilColor = eyes == "Sparkle" and c(128, 64, 170) or INK
			blob("Pupil", Vector3.new(0.38, 0.47, 0.16), onFace(-4, yaw, 0.03), pupilColor)
			blob("Shine", Vector3.new(0.13, 0.13, 0.08), onFace(1, yaw - 3 * side, 0.08), WHITE)
			if eyes == "Sparkle" then
				blob("Shine2", Vector3.new(0.08, 0.08, 0.06), onFace(-7, yaw + 3 * side, 0.08), WHITE)
			end
		elseif eyes == "Dots" then
			blob("Eye", Vector3.new(0.28, 0.36, 0.12), onFace(-2, yaw, 0), INK)
		else -- Sleepy
			makePart(folder, "Eye", Vector3.new(0.42, 0.08, 0.1), onFace(-4, yaw, 0.01), INK, false)
		end
		blob("Blush", Vector3.new(0.36, 0.2, 0.08), onFace(-15, 38 * side, 0), c(255, 150, 172))
	end
	blob("Nose", Vector3.new(0.15, 0.12, 0.12), onFace(-10, 0, 0.02), skin:Lerp(INK, 0.15))
	blob("Mouth", Vector3.new(0.32, 0.12, 0.08), onFace(-21, 0, 0), c(110, 44, 60))

	-- Hair
	local hair = Options.Hair[look.Hair].Name
	if hair ~= "Bald" then
		blob("HairCap", Vector3.new(1.06, 1.06, 1.06) * D, at(0, 0.12, 0.12), hairColor)
	end
	if hair == "Bob" then
		for _, s in ipairs({ -1, 1 }) do
			blob("HairSide", Vector3.new(0.32, 0.6, 0.6) * D, at(0.44 * s, -0.12, 0.08), hairColor)
		end
		blob("HairBack", Vector3.new(0.9, 0.65, 0.5) * D, at(0, -0.15, 0.3), hairColor)
	elseif hair == "Space Buns" then
		for _, s in ipairs({ -1, 1 }) do
			blob("Bun", Vector3.new(0.42, 0.42, 0.42) * D, at(0.33 * s, 0.5, 0.08), hairColor)
		end
	elseif hair == "Puffs" then
		for _, s in ipairs({ -1, 1 }) do
			blob("Puff", Vector3.new(0.55, 0.55, 0.55) * D, at(0.58 * s, 0.15, 0.1), hairColor)
		end
	elseif hair == "Long" then
		blob("HairBack", Vector3.new(0.95, 1.2, 0.45) * D, at(0, -0.3, 0.33), hairColor)
		for _, s in ipairs({ -1, 1 }) do
			blob("Strand", Vector3.new(0.22, 0.9, 0.3) * D, at(0.45 * s, -0.25, 0.02), hairColor)
		end
	elseif hair == "Spiky" then
		local capCenter = center * CFrame.new(0, 0.12 * D, 0.12 * D)
		for _, tilt in ipairs({ 0, 38 }) do
			for i = -2, 2 do
				local cf = capCenter * CFrame.Angles(math.rad(tilt), 0, math.rad(i * 28))
					* CFrame.new(0, 0.5 * D, 0) * CFrame.Angles(0, 0, math.rad(45))
				makePart(folder, "Spike", Vector3.new(0.3, 0.3, 0.3) * D, cf, hairColor, false)
			end
		end
	elseif hair == "Curly" then
		for _, ring in ipairs({ { 38, 40 }, { 68, 60 } }) do
			for yaw = 0, 359, ring[2] do
				local cf = center * CFrame.new(0, 0, 0.05 * D) * CFrame.Angles(0, math.rad(yaw), 0)
					* CFrame.Angles(math.rad(ring[1]), 0, 0) * CFrame.new(0, 0, -0.55 * D)
				blob("Curl", Vector3.new(0.36, 0.36, 0.36) * D, cf, hairColor)
			end
		end
		blob("Curl", Vector3.new(0.4, 0.4, 0.4) * D, at(0, 0.6, 0.08), hairColor)
	end

	-- Hats
	local hat = Options.Hat[look.Hat].Name
	if hat == "Frog Hat" then
		local green = c(104, 194, 92)
		blob("FrogHat", Vector3.new(1.12, 1.12, 1.12) * D, at(0, 0.16, 0.08), green)
		for _, s in ipairs({ -1, 1 }) do
			blob("FrogEyeBall", Vector3.new(0.3, 0.3, 0.3) * D, at(0.22 * s, 0.68, -0.08), green)
			blob("FrogEye", Vector3.new(0.2, 0.2, 0.1) * D, at(0.22 * s, 0.7, -0.2), WHITE)
			blob("FrogPupil", Vector3.new(0.1, 0.1, 0.06) * D, at(0.22 * s, 0.7, -0.25), INK)
		end
	elseif hat == "Headphones" then
		local pink = c(255, 160, 204)
		for _, s in ipairs({ -1, 1 }) do
			local cup = makePart(folder, "EarCup", Vector3.new(0.18, 0.45, 0.45) * D, at(0.53 * s, 0, 0), pink, false)
			cup.Shape = Enum.PartType.Cylinder
			makePart(folder, "BandSide", Vector3.new(0.08, 0.5, 0.14) * D, at(0.56 * s, 0.3, 0), WHITE, false)
		end
		makePart(folder, "Band", Vector3.new(1.2, 0.1, 0.14) * D, at(0, 0.58, 0), WHITE, false)
	elseif hat == "Big Bow" then
		local pink = c(255, 112, 160)
		blob("BowKnot", Vector3.new(0.18, 0.18, 0.18) * D, at(0.28, 0.6, 0), pink)
		for _, s in ipairs({ -1, 1 }) do
			blob("BowLoop", Vector3.new(0.4, 0.28, 0.14) * D, at(0.28 + 0.2 * s, 0.6, 0) * CFrame.Angles(0, 0, math.rad(20 * s)), pink)
		end
	elseif hat == "Cap" then
		local red = c(240, 92, 112)
		blob("Cap", Vector3.new(1.1, 1.1, 1.1) * D, at(0, 0.2, 0.08), red)
		makePart(folder, "Brim", Vector3.new(0.75, 0.06, 0.5) * D, at(0, 0.3, -0.6), red, false)
		blob("CapButton", Vector3.new(0.12, 0.12, 0.12) * D, at(0, 0.77, 0.08), WHITE)
	elseif hat == "Flower Crown" then
		local colors = { c(255, 150, 200), c(255, 226, 96), WHITE, c(196, 166, 244) }
		for i = 0, 7 do
			local cf = center * CFrame.new(0, 0, 0.06 * D) * CFrame.Angles(0, math.rad(i * 45), 0)
				* CFrame.Angles(math.rad(42), 0, 0) * CFrame.new(0, 0, -0.56 * D)
			blob("Flower", Vector3.new(0.18, 0.18, 0.18) * D, cf, colors[i % 4 + 1])
		end
	elseif hat == "Crumpet Pal" then
		local fluff = c(252, 250, 244)
		blob("Crumpet", Vector3.new(0.5, 0.42, 0.5) * D, at(0, 0.7, 0.05), fluff)
		for _, s in ipairs({ -1, 1 }) do
			blob("Fluff", Vector3.new(0.2, 0.2, 0.2) * D, at(0.22 * s, 0.82, 0.05), fluff)
			blob("CrumpetEye", Vector3.new(0.07, 0.09, 0.05) * D, at(0.09 * s, 0.74, -0.2), INK)
			blob("CrumpetBlush", Vector3.new(0.07, 0.04, 0.03) * D, at(0.16 * s, 0.69, -0.18), c(255, 160, 180))
		end
		blob("Fluff", Vector3.new(0.22, 0.22, 0.22) * D, at(0, 0.9, 0.08), fluff)
	end

	-- Stick everything to the head
	for _, part in ipairs(folder:GetChildren()) do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = part == ball and head or ball
		weld.Part1 = part
		weld.Parent = part
	end
	folder.Parent = character
end

-- Rebuild at most a few times a second, always with the newest look
local pending = {}
local function requestBuild(player)
	if pending[player] then
		return
	end
	pending[player] = true
	task.delay(0.12, function()
		pending[player] = nil
		local data = playerData[player]
		local character = player.Character
		if data and character and character.Parent then
			buildLook(character, data.Look)
		end
	end)
end

local function publish(player)
	local data = playerData[player]
	player:SetAttribute("FoundCrumpet", data.FoundCrumpet)
	player:SetAttribute("TocaLook", HttpService:JSONEncode(data.Look))
end

ChangeLook.OnServerEvent:Connect(function(player, look)
	local data = playerData[player]
	if not data then
		return
	end
	data.Look = Options.Sanitize(look, data.FoundCrumpet)
	publish(player)
	requestBuild(player)
end)

local function onPlayer(player)
	local function onCharacter(character)
		character:WaitForChild("Head")
		character:WaitForChild("Humanoid")
		while not playerData[player] and player.Parent do
			task.wait(0.1)
		end
		requestBuild(player)
	end
	player.CharacterAdded:Connect(onCharacter)

	playerData[player] = loadData(player)
	publish(player)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayer, player)
end

Players.PlayerRemoving:Connect(function(player)
	saveData(player)
	playerData[player] = nil
	pending[player] = nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		saveData(player)
	end
end)

---------------------------------------------------------------------------
-- Secret: the Crumpet hiding behind the loose book
---------------------------------------------------------------------------
task.spawn(function()
	local shelf = Room:WaitForChild("Bookshelf")
	local book = shelf:WaitForChild("LooseBook")
	local prompt = book:WaitForChild("BookPrompt")
	local crumpet = shelf:WaitForChild("HiddenCrumpet")
	local home = book.CFrame
	local crumpetHome = crumpet:GetPivot()
	local open = false

	prompt.Triggered:Connect(function(player)
		local data = playerData[player]
		if data then
			if not data.FoundCrumpet then
				data.FoundCrumpet = true
				publish(player)
				Toast:FireClient(player, "🐾 You found a secret Crumpet!\nCrumpet Pal hat unlocked ✨", "rare")
			else
				Toast:FireClient(player, "The Crumpet waves hi! 👋", "info")
			end
		end
		if open then
			return
		end
		open = true
		prompt.Enabled = false
		local info = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		TweenService:Create(book, info, { CFrame = (home + Vector3.new(-2.8, 0, 0)) * CFrame.Angles(math.rad(-14), 0, 0) }):Play()
		-- Little happy hops
		for _ = 1, 3 do
			task.wait(0.35)
			crumpet:PivotTo(crumpetHome + Vector3.new(0, 0.6, 0))
			task.wait(0.15)
			crumpet:PivotTo(crumpetHome)
		end
		task.wait(5)
		TweenService:Create(book, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { CFrame = home }):Play()
		task.wait(0.6)
		prompt.Enabled = true
		open = false
	end)
end)

---------------------------------------------------------------------------
-- Secret: the light switch that changes the room's mood
---------------------------------------------------------------------------
task.spawn(function()
	local switch = Room:WaitForChild("MoodSwitch")
	local prompt = switch:WaitForChild("Plate"):WaitForChild("MoodPrompt")
	local toggle = switch:WaitForChild("Toggle")
	local fairy = Room:WaitForChild("FairyLights")
	local lantern = Room:WaitForChild("Lantern"):WaitForChild("Bulb")

	local bulbs = {}
	for _, bulb in ipairs(fairy:GetChildren()) do
		local light = bulb:FindFirstChildOfClass("PointLight")
		if light then
			table.insert(bulbs, { Part = bulb, Light = light, Color = bulb.Color })
		end
	end
	local lanternLight = lantern:FindFirstChildOfClass("PointLight")

	local moods = {
		{ Name = "☀️ Sunny Morning", Clock = 10, Bright = 3, Ambient = c(150, 140, 156), Outdoor = c(186, 176, 196), Lights = 0.3, Toggle = c(255, 214, 96) },
		{ Name = "🌅 Golden Hour", Clock = 17.6, Bright = 2.2, Ambient = c(176, 126, 116), Outdoor = c(212, 150, 122), Lights = 1.4, Toggle = c(255, 150, 90) },
		{ Name = "🌙 Dreamy Night", Clock = 0, Bright = 1, Ambient = c(96, 86, 146), Outdoor = c(82, 82, 142), Lights = 2.6, Toggle = c(150, 130, 240) },
		{ Name = "🪩 Disco Party", Clock = 0, Bright = 1, Ambient = c(132, 72, 152), Outdoor = c(92, 62, 132), Lights = 3, Toggle = c(255, 90, 200), Party = true },
	}
	local index = 1
	local party = false

	local function apply(mood)
		Lighting.ClockTime = mood.Clock
		local info = TweenInfo.new(0.8, Enum.EasingStyle.Sine)
		TweenService:Create(Lighting, info, { Brightness = mood.Bright, Ambient = mood.Ambient, OutdoorAmbient = mood.Outdoor }):Play()
		for _, b in ipairs(bulbs) do
			b.Light.Brightness = mood.Lights
			b.Light.Color = b.Color
			b.Part.Color = b.Color
		end
		if lanternLight then
			lanternLight.Brightness = mood.Lights
		end
		toggle.Color = mood.Toggle
		party = mood.Party == true
	end

	prompt.Triggered:Connect(function()
		index = index % #moods + 1
		apply(moods[index])
		Toast:FireAllClients("Room mood: " .. moods[index].Name, "info")
	end)

	apply(moods[1])

	while true do
		task.wait(0.25)
		if party then
			local t = os.clock()
			for i, b in ipairs(bulbs) do
				local color = Color3.fromHSV((t * 0.5 + i * 0.09) % 1, 0.6, 1)
				b.Part.Color = color
				b.Light.Color = color
			end
		end
	end
end)
