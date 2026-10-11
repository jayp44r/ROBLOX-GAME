-- Toca World installer (made by toca-world/build.py, edit the files in src/ instead).
-- Run it once in Roblox Studio (Claude's execute_luau, or paste into the Command Bar).
local SOURCES = {}
SOURCES.TocaOptions = [===[
-- TocaOptions (ModuleScript in ReplicatedStorage)
-- Every choice in the character creator. Shared by the server (to check choices)
-- and the client (to draw the buttons). A look is a table of list positions:
-- { Skin = 2, Hair = 3, HairColor = 1, Eyes = 1, Top = 2, Bottom = 9, Hat = 1 }

local Options = {}

local function c(r, g, b)
	return Color3.fromRGB(r, g, b)
end

Options.Skin = {
	{ Name = "Peach", Color = c(255, 222, 198) },
	{ Name = "Sand", Color = c(243, 196, 158) },
	{ Name = "Caramel", Color = c(206, 146, 100) },
	{ Name = "Cocoa", Color = c(146, 96, 64) },
	{ Name = "Espresso", Color = c(96, 62, 44) },
	{ Name = "Mint Alien", Color = c(172, 232, 196) },
	{ Name = "Lilac Alien", Color = c(204, 186, 244) },
}

Options.Hair = {
	{ Name = "Bald", Icon = "🥚" },
	{ Name = "Bob", Icon = "💁" },
	{ Name = "Space Buns", Icon = "🍡" },
	{ Name = "Puffs", Icon = "☁️" },
	{ Name = "Long", Icon = "🧜" },
	{ Name = "Spiky", Icon = "⚡" },
	{ Name = "Curly", Icon = "🌀" },
}

Options.HairColor = {
	{ Name = "Bubblegum", Color = c(255, 150, 200) },
	{ Name = "Mint", Color = c(140, 228, 196) },
	{ Name = "Lavender", Color = c(186, 156, 240) },
	{ Name = "Sky", Color = c(120, 196, 255) },
	{ Name = "Sunny", Color = c(255, 214, 96) },
	{ Name = "Ginger", Color = c(238, 136, 66) },
	{ Name = "Chocolate", Color = c(108, 68, 44) },
	{ Name = "Jet", Color = c(42, 36, 48) },
	{ Name = "Snow", Color = c(246, 246, 252) },
}

Options.Eyes = {
	{ Name = "Big", Icon = "👀" },
	{ Name = "Dots", Icon = "⚫" },
	{ Name = "Sleepy", Icon = "😴" },
	{ Name = "Sparkle", Icon = "✨" },
}

Options.Cloth = {
	{ Name = "Cloud", Color = c(252, 252, 252) },
	{ Name = "Blush", Color = c(255, 190, 212) },
	{ Name = "Strawberry", Color = c(240, 92, 112) },
	{ Name = "Peach", Color = c(255, 190, 150) },
	{ Name = "Lemon", Color = c(255, 234, 128) },
	{ Name = "Matcha", Color = c(182, 222, 150) },
	{ Name = "Froggy", Color = c(102, 192, 92) },
	{ Name = "Aqua", Color = c(118, 216, 222) },
	{ Name = "Denim", Color = c(92, 132, 204) },
	{ Name = "Lilac", Color = c(202, 172, 242) },
	{ Name = "Grape", Color = c(132, 92, 192) },
	{ Name = "Cocoa", Color = c(132, 92, 62) },
	{ Name = "Charcoal", Color = c(62, 62, 72) },
}
Options.Top = Options.Cloth
Options.Bottom = Options.Cloth

Options.Hat = {
	{ Name = "None", Icon = "🚫" },
	{ Name = "Frog Hat", Icon = "🐸" },
	{ Name = "Headphones", Icon = "🎧" },
	{ Name = "Big Bow", Icon = "🎀" },
	{ Name = "Cap", Icon = "🧢" },
	{ Name = "Flower Crown", Icon = "🌸" },
	-- Unlocked by finding the Crumpet hidden in the bedroom
	{ Name = "Crumpet Pal", Icon = "🐾", Secret = true },
}

Options.Fields = { "Skin", "Hair", "HairColor", "Eyes", "Top", "Bottom", "Hat" }

Options.Default = { Skin = 2, Hair = 2, HairColor = 1, Eyes = 1, Top = 2, Bottom = 9, Hat = 1 }

-- One-tap aesthetic styles
Options.Presets = {
	{ Name = "Soft Indie", Icon = "🌻", Look = { Skin = 3, Hair = 7, HairColor = 7, Eyes = 2, Top = 6, Bottom = 9, Hat = 6 } },
	{ Name = "Y2K Grunge", Icon = "🖤", Look = { Skin = 1, Hair = 6, HairColor = 8, Eyes = 3, Top = 13, Bottom = 11, Hat = 3 } },
	{ Name = "Pastel Gamer", Icon = "🎮", Look = { Skin = 2, Hair = 3, HairColor = 3, Eyes = 4, Top = 10, Bottom = 2, Hat = 3 } },
	{ Name = "Preppy", Icon = "🎀", Look = { Skin = 4, Hair = 5, HairColor = 5, Eyes = 1, Top = 1, Bottom = 3, Hat = 4 } },
	{ Name = "Cottagecore", Icon = "🍄", Look = { Skin = 5, Hair = 4, HairColor = 6, Eyes = 2, Top = 5, Bottom = 7, Hat = 2 } },
	{ Name = "Alien Pop", Icon = "👽", Look = { Skin = 6, Hair = 3, HairColor = 1, Eyes = 4, Top = 11, Bottom = 8, Hat = 1 } },
}

-- Turns any table into a safe look. Anything missing or out of range becomes the default.
function Options.Sanitize(look, allowSecret)
	local clean = {}
	for _, field in ipairs(Options.Fields) do
		local list = Options[field]
		local value = type(look) == "table" and look[field] or nil
		if type(value) ~= "number" or value ~= value or value % 1 ~= 0 or value < 1 or value > #list then
			value = Options.Default[field]
		end
		if list[value].Secret and not allowSecret then
			value = Options.Default[field]
		end
		clean[field] = value
	end
	return clean
end

return Options
]===]
SOURCES.TocaServer = [===[
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
]===]
SOURCES.TocaCreatorClient = [===[
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
]===]
-- Installer body. build.py puts the SOURCES table above this.
-- Builds the cozy Toca bedroom, sets up lighting, and puts the scripts in place.
-- Safe to run again: it replaces what it made last time.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Lighting = game:GetService("Lighting")

local function c(r, g, b)
	return Color3.fromRGB(r, g, b)
end
local rad = math.rad

---------------------------------------------------------------------------
-- Scripts and remotes
---------------------------------------------------------------------------
local function putScript(class, name, parent, source)
	local old = parent:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local s = Instance.new(class)
	s.Name = name
	s.Source = source
	s.Parent = parent
	return s
end

putScript("ModuleScript", "TocaOptions", ReplicatedStorage, SOURCES.TocaOptions)
putScript("Script", "TocaServer", ServerScriptService, SOURCES.TocaServer)
putScript("LocalScript", "TocaCreatorClient", StarterPlayer:WaitForChild("StarterPlayerScripts"), SOURCES.TocaCreatorClient)

do
	local old = ReplicatedStorage:FindFirstChild("TocaRemotes")
	if old then
		old:Destroy()
	end
	local remotes = Instance.new("Folder")
	remotes.Name = "TocaRemotes"
	for _, name in ipairs({ "ChangeLook", "Toast" }) do
		local r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = remotes
	end
	remotes.Parent = ReplicatedStorage
end

-- Everyone starts as a plain character and makes their look in the creator
StarterPlayer.LoadCharacterAppearance = false

---------------------------------------------------------------------------
-- Building helpers
---------------------------------------------------------------------------
local function part(parent, name, size, cf, color, opts)
	opts = opts or {}
	local p = Instance.new(opts.Class or "Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = typeof(cf) == "CFrame" and cf or CFrame.new(cf)
	p.Color = color
	p.Material = opts.Material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Transparency = opts.Transparency or 0
	p.Reflectance = opts.Reflectance or 0
	p.CanCollide = opts.CanCollide ~= false
	p.CastShadow = opts.CastShadow ~= false
	if opts.Shape then
		p.Shape = opts.Shape
	end
	if opts.Round then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	p.Parent = parent
	return p
end

local function blob(parent, name, size, cf, color, opts)
	opts = opts or {}
	opts.Round = true
	if opts.CanCollide == nil then
		opts.CanCollide = false
	end
	return part(parent, name, size, cf, color, opts)
end

-- Standing cylinder (like a pot or a pouf)
local function column(parent, name, height, diameter, pos, color, opts)
	opts = opts or {}
	opts.Shape = Enum.PartType.Cylinder
	return part(parent, name, Vector3.new(height, diameter, diameter), CFrame.new(pos) * CFrame.Angles(0, 0, rad(90)), color, opts)
end

-- Round thing facing out along Z (like a mirror or a clock face)
local function disc(parent, name, thick, diameter, pos, color, opts)
	opts = opts or {}
	opts.Shape = Enum.PartType.Cylinder
	return part(parent, name, Vector3.new(thick, diameter, diameter), CFrame.new(pos) * CFrame.Angles(0, rad(90), 0), color, opts)
end

local function model(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function prompt(parent, name, action, object, distance)
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.ObjectText = object
	p.MaxActivationDistance = distance or 10
	p.RequiresLineOfSight = false
	p.HoldDuration = 0
	p.Parent = parent
	return p
end

---------------------------------------------------------------------------
-- The world
---------------------------------------------------------------------------
local old = Workspace:FindFirstChild("TocaWorld")
if old then
	old:Destroy()
end
local world = Instance.new("Folder")
world.Name = "TocaWorld"

local WHITE = c(255, 253, 250)
local CREAM = c(255, 246, 232)
local PINK = c(255, 184, 206)
local HOT_PINK = c(255, 120, 166)
local GREEN = c(130, 206, 104)
local INK = c(46, 34, 52)

-- Garden island the room sits on
local outside = model(world, "Garden")
part(outside, "Island", Vector3.new(2, 200, 200), CFrame.new(0, -0.95, 0) * CFrame.Angles(0, 0, rad(90)), c(150, 222, 112), { Shape = Enum.PartType.Cylinder })
blob(outside, "Hill", Vector3.new(90, 26, 50), CFrame.new(-10, -2, -80), c(124, 204, 100))
blob(outside, "Hill", Vector3.new(70, 20, 40), CFrame.new(45, -2, -72), c(140, 214, 108))
local function tree(pos, leaves)
	column(outside, "Trunk", 9, 1.8, pos + Vector3.new(0, 4.5, 0), c(170, 112, 76))
	blob(outside, "Leaves", Vector3.new(10, 9, 10), CFrame.new(pos + Vector3.new(0, 11, 0)), leaves)
	blob(outside, "Leaves", Vector3.new(6.5, 6, 6.5), CFrame.new(pos + Vector3.new(2.5, 14.5, 1)), leaves:Lerp(Color3.new(1, 1, 1), 0.15))
end
tree(Vector3.new(-16, 0, -36), c(126, 206, 104))
tree(Vector3.new(19, 0, -42), c(255, 186, 214))
tree(Vector3.new(-48, 0, 30), c(126, 206, 104))
tree(Vector3.new(50, 0, 24), c(255, 186, 214))

local room = model(world, "Bedroom")

-- Floor: warm wooden planks
local floor = model(room, "Floor")
for i = 0, 7 do
	local color = i % 2 == 0 and c(238, 206, 166) or c(228, 192, 150)
	part(floor, "Plank", Vector3.new(60, 1, 5), Vector3.new(0, 0.5, -17.5 + i * 5), color)
end

-- Walls (open at the front like a dollhouse)
local walls = model(room, "Walls")
local backColor = c(253, 228, 228)
part(walls, "BackLeft", Vector3.new(22, 24, 1), Vector3.new(-19, 13, -20.5), backColor)
part(walls, "BackRight", Vector3.new(22, 24, 1), Vector3.new(19, 13, -20.5), backColor)
part(walls, "BackBelowWindow", Vector3.new(16, 8, 1), Vector3.new(0, 5, -20.5), backColor)
part(walls, "BackAboveWindow", Vector3.new(16, 6, 1), Vector3.new(0, 22, -20.5), backColor)
part(walls, "LeftWall", Vector3.new(1, 24, 41), Vector3.new(-30.5, 13, -0.5), c(255, 240, 204))
part(walls, "RightWall", Vector3.new(1, 24, 41), Vector3.new(30.5, 13, -0.5), c(232, 222, 252))
part(walls, "BackPanel", Vector3.new(60, 6, 0.4), Vector3.new(0, 4, -19.8), WHITE)
part(walls, "LeftPanel", Vector3.new(0.4, 6, 40), Vector3.new(-29.8, 4, 0), WHITE)
part(walls, "RightPanel", Vector3.new(0.4, 6, 40), Vector3.new(29.8, 4, 0), WHITE)

-- Window with a view of the garden
local window = model(room, "Window")
part(window, "Glass", Vector3.new(16, 10, 0.3), Vector3.new(0, 14, -20.5), c(196, 232, 255), { Material = Enum.Material.Glass, Transparency = 0.65 })
part(window, "FrameTop", Vector3.new(17, 0.8, 1.4), Vector3.new(0, 19, -20.3), WHITE)
part(window, "Sill", Vector3.new(18, 0.8, 2), Vector3.new(0, 9, -20), WHITE)
part(window, "FrameLeft", Vector3.new(0.8, 10, 1.4), Vector3.new(-8, 14, -20.3), WHITE)
part(window, "FrameRight", Vector3.new(0.8, 10, 1.4), Vector3.new(8, 14, -20.3), WHITE)
part(window, "CrossV", Vector3.new(0.5, 10, 1.2), Vector3.new(0, 14, -20.4), WHITE)
part(window, "CrossH", Vector3.new(16, 0.5, 1.2), Vector3.new(0, 14, -20.4), WHITE)
column(window, "SillPlantPot", 1.2, 1.2, Vector3.new(-5, 10, -19.8), c(255, 160, 140))
blob(window, "SillPlant", Vector3.new(1.8, 1.6, 1.8), CFrame.new(-5, 11.2, -19.8), GREEN)

-- Pink curtains
local curtains = model(room, "Curtains")
part(curtains, "Rod", Vector3.new(24, 0.4, 0.4), Vector3.new(0, 20.3, -19.5), WHITE, { Shape = Enum.PartType.Cylinder })
for _, s in ipairs({ -1, 1 }) do
	for k = 0, 2 do
		column(curtains, "Fold", 11.5, 1.7, Vector3.new(s * (7.6 + k * 1.4), 14.4, -19.4 + (k % 2) * 0.35), k % 2 == 0 and PINK or c(255, 198, 216))
	end
	blob(curtains, "TieBack", Vector3.new(4.6, 0.7, 2), CFrame.new(s * 9, 12.5, -19.2), HOT_PINK)
end

-- Bed with plushies (the mattress is a trampoline!)
local bed = model(room, "Bed")
part(bed, "Base", Vector3.new(10, 2, 13), Vector3.new(0, 2, -12.5), CREAM)
part(bed, "Headboard", Vector3.new(10.4, 7, 1), Vector3.new(0, 5.5, -19.3), WHITE)
part(bed, "Footboard", Vector3.new(10.4, 3.5, 0.8), Vector3.new(0, 2.75, -5.8), WHITE)
part(bed, "BouncyMattress", Vector3.new(9.4, 1.4, 12.4), Vector3.new(0, 3.7, -12.5), c(255, 252, 250))
part(bed, "Blanket", Vector3.new(9.8, 0.5, 7.5), Vector3.new(0, 4.55, -9.5), c(255, 196, 214), { CanCollide = false })
part(bed, "BlanketFold", Vector3.new(9.8, 0.6, 1), Vector3.new(0, 4.6, -13.5), WHITE, { CanCollide = false })
blob(bed, "Pillow", Vector3.new(5, 1.4, 2.6), CFrame.new(0, 5.1, -17), WHITE)
for _, s in ipairs({ -1, 1 }) do
	blob(bed, "BowLoop", Vector3.new(1.6, 1, 0.5), CFrame.new(s * 0.9, 8.4, -18.7) * CFrame.Angles(0, 0, rad(-15 * s)), HOT_PINK)
	blob(bed, "FootBowLoop", Vector3.new(1.2, 0.8, 0.4), CFrame.new(s * 0.7, 3.4, -5.3) * CFrame.Angles(0, 0, rad(-15 * s)), HOT_PINK)
end
blob(bed, "BowKnot", Vector3.new(0.6, 0.6, 0.6), CFrame.new(0, 8.4, -18.6), HOT_PINK)
-- Flower pillow
for i = 0, 4 do
	local a = rad(i * 72)
	blob(bed, "Petal", Vector3.new(1.6, 0.6, 1.6), CFrame.new(-2.4 + math.cos(a) * 1, 5.15, -14 + math.sin(a) * 1), c(255, 136, 170))
end
blob(bed, "FlowerMiddle", Vector3.new(1, 0.7, 1), CFrame.new(-2.4, 5.3, -14), c(255, 224, 96))
-- Teddy bear
local bear = c(196, 140, 92)
blob(bed, "TeddyBody", Vector3.new(2, 2.2, 1.8), CFrame.new(2.6, 5.6, -15), bear)
blob(bed, "TeddyHead", Vector3.new(1.8, 1.6, 1.6), CFrame.new(2.6, 7.1, -15), bear)
for _, s in ipairs({ -1, 1 }) do
	blob(bed, "TeddyEar", Vector3.new(0.7, 0.7, 0.5), CFrame.new(2.6 + 0.75 * s, 7.8, -15), bear)
	blob(bed, "TeddyEye", Vector3.new(0.2, 0.22, 0.1), CFrame.new(2.6 + 0.35 * s, 7.3, -15.8), INK)
end
blob(bed, "TeddySnout", Vector3.new(0.8, 0.6, 0.4), CFrame.new(2.6, 6.9, -15.8), c(238, 206, 170))

-- Nightstand with a green alarm clock
local stand = model(room, "Nightstand")
part(stand, "Body", Vector3.new(4, 4, 3.5), Vector3.new(-8, 3, -17.5), WHITE)
part(stand, "Drawer", Vector3.new(3.2, 1.2, 0.2), Vector3.new(-8, 3.6, -15.7), PINK)
blob(stand, "Knob", Vector3.new(0.4, 0.4, 0.3), CFrame.new(-8, 3.6, -15.55), WHITE)
disc(stand, "Clock", 0.8, 1.8, Vector3.new(-8, 5.9, -17.3), c(110, 196, 120))
disc(stand, "ClockFace", 0.2, 1.4, Vector3.new(-8, 5.9, -16.85), WHITE)
part(stand, "ClockHand", Vector3.new(0.1, 0.5, 0.05), Vector3.new(-8, 6.05, -16.72), INK)
for _, s in ipairs({ -1, 1 }) do
	blob(stand, "ClockBell", Vector3.new(0.6, 0.5, 0.6), CFrame.new(-8 + 0.6 * s, 6.85, -17.3), c(110, 196, 120))
end

-- Desk under the window shelf
local desk = model(room, "Desk")
part(desk, "Top", Vector3.new(10, 0.8, 5), Vector3.new(17, 6, -17.5), WHITE)
for _, x in ipairs({ 12.6, 21.4 }) do
	for _, z in ipairs({ -15.4, -19.6 }) do
		part(desk, "Leg", Vector3.new(0.8, 5, 0.8), Vector3.new(x, 3.5, z), WHITE)
	end
end
part(desk, "Drawers", Vector3.new(3, 4.6, 4.4), Vector3.new(20, 3.4, -17.5), c(255, 214, 190))
part(desk, "LaptopBase", Vector3.new(3.4, 0.2, 2.2), Vector3.new(16, 6.5, -17), c(232, 232, 242))
part(desk, "LaptopScreen", Vector3.new(3.4, 2.2, 0.15), CFrame.new(16, 7.6, -18.1) * CFrame.Angles(rad(-10), 0, 0), c(232, 232, 242))
part(desk, "ScreenGlow", Vector3.new(3, 1.8, 0.05), CFrame.new(16, 7.6, -18.0) * CFrame.Angles(rad(-10), 0, 0), c(170, 214, 255), { Material = Enum.Material.Neon, CanCollide = false })
-- Frog plush
blob(desk, "FrogBody", Vector3.new(1.8, 1.5, 1.5), CFrame.new(19.5, 7.15, -17), GREEN)
for _, s in ipairs({ -1, 1 }) do
	blob(desk, "FrogEye", Vector3.new(0.6, 0.6, 0.6), CFrame.new(19.5 + 0.45 * s, 7.95, -17.3), WHITE)
	blob(desk, "FrogPupil", Vector3.new(0.25, 0.25, 0.1), CFrame.new(19.5 + 0.45 * s, 7.95, -17.6), INK)
end
-- Pink lamp
column(desk, "LampBase", 0.3, 1.4, Vector3.new(13.4, 6.55, -18.8), HOT_PINK)
column(desk, "LampStalk", 2, 0.25, Vector3.new(13.4, 7.6, -18.8), WHITE)
local shade = blob(desk, "LampShade", Vector3.new(2, 1.3, 2), CFrame.new(13.4, 8.9, -18.8), PINK)
local lampLight = Instance.new("PointLight")
lampLight.Color = c(255, 210, 220)
lampLight.Range = 10
lampLight.Brightness = 0.8
lampLight.Parent = shade
-- Mug and books
column(desk, "Mug", 1, 0.8, Vector3.new(21.2, 6.9, -16.3), c(140, 214, 220))
for i, color in ipairs({ c(200, 172, 242), c(255, 214, 96), c(255, 150, 180) }) do
	part(desk, "Book", Vector3.new(2, 0.4, 1.4), CFrame.new(21, 6.2 + i * 0.4, -18.6) * CFrame.Angles(0, rad(i * 8), 0), color)
end
-- Round chair
column(desk, "ChairStem", 2.4, 0.6, Vector3.new(17, 2.2, -13.5), WHITE)
column(desk, "ChairSeat", 0.6, 3.4, Vector3.new(17, 3.6, -13.5), WHITE)
blob(desk, "ChairCushion", Vector3.new(3, 0.6, 3), CFrame.new(17, 4, -13.5), c(255, 214, 190))
part(desk, "ChairBack", Vector3.new(3, 2.6, 0.5), Vector3.new(17, 5.4, -11.9), WHITE)

-- Wall shelf with little plants above the desk
local wallShelf = model(room, "WallShelf")
part(wallShelf, "Board", Vector3.new(10, 0.5, 1.6), Vector3.new(17, 12, -19.5), WHITE)
for i, x in ipairs({ 13.5, 17, 20.5 }) do
	column(wallShelf, "Pot", 1, 1, Vector3.new(x, 12.75, -19.4), i == 2 and c(140, 214, 220) or c(255, 170, 150))
	blob(wallShelf, "Leaves", Vector3.new(1.6, 1.5, 1.6), CFrame.new(x, 13.8, -19.4), GREEN)
end

-- Polaroids on the wall
local photos = model(room, "Polaroids")
local photoColors = { c(255, 186, 214), c(170, 214, 255), c(255, 224, 140), c(180, 230, 170), c(210, 186, 246), c(255, 200, 160) }
for i = 0, 5 do
	local x = -17 + (i % 3) * 2.4
	local y = 18 - math.floor(i / 3) * 2.6
	local tilt = CFrame.Angles(0, 0, rad((i % 2 == 0) and 6 or -5))
	part(photos, "Photo", Vector3.new(1.8, 2.1, 0.1), CFrame.new(x, y, -19.95) * tilt, WHITE)
	part(photos, "Picture", Vector3.new(1.5, 1.4, 0.05), CFrame.new(x, y, -19.88) * tilt * CFrame.new(0, 0.22, 0), photoColors[i + 1])
end

-- Bookshelf on the right wall (one book is wobbly...)
local shelf = model(room, "Bookshelf")
part(shelf, "Back", Vector3.new(0.4, 16, 10), Vector3.new(29.8, 9, -1), WHITE)
part(shelf, "SideA", Vector3.new(5, 16, 0.5), Vector3.new(27.5, 9, -5.75), WHITE)
part(shelf, "SideB", Vector3.new(5, 16, 0.5), Vector3.new(27.5, 9, 3.75), WHITE)
for _, y in ipairs({ 1.25, 5, 9, 13, 17 }) do
	part(shelf, "Shelf", Vector3.new(5, 0.5, 10), Vector3.new(27.5, y, -1), WHITE)
end
local bookColors = { c(255, 150, 180), c(140, 214, 220), c(255, 214, 96), c(170, 214, 255), c(180, 140, 230), c(180, 230, 170), c(255, 186, 150), c(240, 92, 112), c(200, 172, 242) }
local LOOSE = 5
local looseZ
for i = 1, 9 do
	local z = -5 + (i - 1) * 0.95
	local h = 2.6 + (i % 3) * 0.25
	if i == LOOSE then
		looseZ = z
		local book = part(shelf, "LooseBook", Vector3.new(3.2, 3, 0.8), Vector3.new(26.6, 9.25 + 1.5, z), bookColors[i], { CanCollide = false })
		prompt(book, "BookPrompt", "Pull", "Wobbly book", 10)
	else
		part(shelf, "Book", Vector3.new(3.2, h, 0.8), Vector3.new(26.9, 9.25 + h / 2, z), bookColors[i])
	end
end
-- The secret Crumpet behind the wobbly book
local crumpet = model(shelf, "HiddenCrumpet")
local fluff = c(252, 250, 244)
blob(crumpet, "Body", Vector3.new(1.1, 1, 1.1), CFrame.new(29.05, 9.8, looseZ), fluff)
blob(crumpet, "Fluff", Vector3.new(0.5, 0.5, 0.5), CFrame.new(29.05, 10.35, looseZ - 0.2), fluff)
blob(crumpet, "Fluff", Vector3.new(0.45, 0.45, 0.45), CFrame.new(29.1, 10.3, looseZ + 0.25), fluff)
for _, s in ipairs({ -1, 1 }) do
	blob(crumpet, "Eye", Vector3.new(0.08, 0.17, 0.12), CFrame.new(28.5, 9.95, looseZ + 0.2 * s), INK)
	blob(crumpet, "Blush", Vector3.new(0.06, 0.08, 0.14), CFrame.new(28.55, 9.75, looseZ + 0.33 * s), c(255, 160, 180))
	blob(crumpet, "Foot", Vector3.new(0.3, 0.2, 0.25), CFrame.new(28.8, 9.35, looseZ + 0.3 * s), fluff)
end
crumpet.PrimaryPart = crumpet:FindFirstChild("Body")
-- Folded clothes, bins and a frog on the other shelves
for i, color in ipairs({ c(255, 196, 214), c(170, 214, 255), c(255, 234, 140), c(200, 172, 242) }) do
	part(shelf, "Clothes", Vector3.new(3, 0.6, 1.8), Vector3.new(27.2, 5.25 + 0.3 + (i % 2) * 0.6, -4.5 + math.floor((i - 1) / 2) * 2.4), color)
end
part(shelf, "Bin", Vector3.new(3.4, 2.8, 3.6), Vector3.new(27.3, 2.9, -3.4), PINK)
part(shelf, "Bin", Vector3.new(3.4, 2.8, 3.6), Vector3.new(27.3, 2.9, 1.2), c(170, 214, 255))
blob(shelf, "FrogPlush", Vector3.new(1.8, 1.5, 1.6), CFrame.new(27, 14, 1.5), GREEN)
for _, s in ipairs({ -1, 1 }) do
	blob(shelf, "FrogEye", Vector3.new(0.55, 0.55, 0.55), CFrame.new(26.7, 14.8, 1.5 + 0.45 * s), WHITE)
	blob(shelf, "FrogPupil", Vector3.new(0.1, 0.25, 0.25), CFrame.new(26.42, 14.8, 1.5 + 0.45 * s), INK)
end
column(shelf, "Jar", 1.6, 1.1, Vector3.new(27, 14.05, -3.5), c(200, 240, 250), { Transparency = 0.3 })

-- Vanity with the magic mirror (opens the character creator)
local vanity = model(room, "Vanity")
part(vanity, "Top", Vector3.new(7, 0.6, 3.5), Vector3.new(-22, 5, -18), WHITE)
for _, x in ipairs({ -24.6, -19.4 }) do
	part(vanity, "Drawers", Vector3.new(1.8, 3.7, 3.2), Vector3.new(x, 2.85, -18), c(255, 214, 190))
end
disc(vanity, "MirrorFrame", 0.3, 6.2, Vector3.new(-22, 9.3, -19.75), WHITE)
local mirror = disc(vanity, "Mirror", 0.3, 5.4, Vector3.new(-22, 9.3, -19.55), c(206, 238, 255), { Material = Enum.Material.Glass, Reflectance = 0.25 })
prompt(mirror, "MirrorPrompt", "Change Look", "✨ Magic Mirror", 12)
column(vanity, "StoolStem", 1.8, 1, Vector3.new(-22, 1.9, -14.5), WHITE)
column(vanity, "StoolSeat", 0.6, 3, Vector3.new(-22, 3, -14.5), PINK)
blob(vanity, "StoolCushion", Vector3.new(2.8, 0.7, 2.8), CFrame.new(-22, 3.4, -14.5), PINK)
column(vanity, "Perfume", 0.9, 0.5, Vector3.new(-24.3, 5.75, -17.6), c(255, 170, 200), { Transparency = 0.2 })
column(vanity, "Perfume", 0.7, 0.45, Vector3.new(-23.6, 5.65, -17.2), c(200, 172, 242), { Transparency = 0.2 })
column(vanity, "Vase", 1.2, 0.9, Vector3.new(-19.6, 5.9, -18.3), WHITE)
for i = 0, 4 do
	local a = rad(i * 72)
	blob(vanity, "Flower", Vector3.new(0.7, 0.7, 0.7), CFrame.new(-19.6 + math.cos(a) * 0.5, 7.1 + (i % 2) * 0.3, -18.3 + math.sin(a) * 0.5), i % 2 == 0 and WHITE or c(255, 236, 200))
end

-- Rug, poufs and floor clutter
local decor = model(room, "Decor")
part(decor, "Rug", Vector3.new(0.1, 18, 18), CFrame.new(0, 1.05, 0) * CFrame.Angles(0, 0, rad(90)), c(172, 222, 120), { Shape = Enum.PartType.Cylinder, CanCollide = false })
part(decor, "RugRing", Vector3.new(0.12, 12, 12), CFrame.new(0, 1.07, 0) * CFrame.Angles(0, 0, rad(90)), c(196, 236, 150), { Shape = Enum.PartType.Cylinder, CanCollide = false })
column(decor, "WatermelonPouf", 2.4, 4.4, Vector3.new(-12, 2.2, 5), c(84, 172, 84))
column(decor, "WatermelonTop", 0.2, 4, Vector3.new(-12, 3.45, 5), c(240, 90, 104))
for i = 0, 5 do
	local a = rad(i * 60)
	blob(decor, "Seed", Vector3.new(0.25, 0.1, 0.4), CFrame.new(-12 + math.cos(a) * 1.1, 3.57, 5 + math.sin(a) * 1.1), INK)
end
blob(decor, "BeanBag", Vector3.new(5.5, 3.6, 5.5), CFrame.new(16, 2.6, 6), c(255, 170, 204), { CanCollide = true })
blob(decor, "BeanBagDent", Vector3.new(3.6, 1, 3.6), CFrame.new(16, 4.1, 6), c(255, 190, 216))
for i, color in ipairs({ c(255, 214, 96), c(140, 214, 220), c(200, 172, 242) }) do
	part(decor, "Sock", Vector3.new(1.6, 0.25, 0.7), CFrame.new(9 + i * 1.1, 1.15, 10 + (i % 2)) * CFrame.Angles(0, rad(i * 50), 0), color, { CanCollide = false })
end
blob(decor, "Ball", Vector3.new(1.6, 1.6, 1.6), CFrame.new(-6, 1.8, 12), c(255, 120, 140), { CanCollide = true })
for _, spot in ipairs({ Vector3.new(-26, 0, 15), Vector3.new(26, 0, 14) }) do
	column(decor, "BigPot", 3, 3, spot + Vector3.new(0, 2.5, 0), c(255, 236, 214))
	blob(decor, "BigLeaves", Vector3.new(4, 4, 4), CFrame.new(spot + Vector3.new(0, 5.6, 0)), GREEN)
	blob(decor, "BigLeaves", Vector3.new(3, 3.4, 3), CFrame.new(spot + Vector3.new(0.8, 7.8, 0.3)), c(110, 192, 96))
end

-- Fairy lights along the top of the walls
local fairy = model(room, "FairyLights")
local bulbColors = { c(255, 232, 150), c(255, 190, 214), c(186, 226, 255), c(200, 255, 200) }
local function bulb(pos, i)
	local b = blob(fairy, "Bulb", Vector3.new(0.6, 0.7, 0.6), CFrame.new(pos), bulbColors[i % 4 + 1], { Material = Enum.Material.Neon, CastShadow = false })
	local light = Instance.new("PointLight")
	light.Color = b.Color
	light.Range = 6
	light.Brightness = 1
	light.Parent = b
end
local n = 0
for x = -28, 28, 2 do
	n += 1
	bulb(Vector3.new(x, 23.4 - 1.2 * math.abs(math.sin((x + 28) / 8 * math.pi)), -19.6), n)
end
for z = -18, 18, 2 do
	n += 1
	bulb(Vector3.new(-29.6, 23.4 - 1.2 * math.abs(math.sin((z + 18) / 8 * math.pi)), z), n)
end

-- Paper lantern
local lantern = model(room, "Lantern")
part(lantern, "Cord", Vector3.new(0.15, 7, 0.15), Vector3.new(-20, 21.5, -6), WHITE)
local lanternBulb = blob(lantern, "Bulb", Vector3.new(4, 4.4, 4), CFrame.new(-20, 16, -6), c(255, 226, 140))
for _, y in ipairs({ 15, 17 }) do
	part(lantern, "Rib", Vector3.new(0.1, 4.2, 4.2), CFrame.new(-20, y, -6) * CFrame.Angles(0, 0, rad(90)), c(255, 210, 110), { Shape = Enum.PartType.Cylinder, CanCollide = false })
end
local glow = Instance.new("PointLight")
glow.Color = c(255, 214, 150)
glow.Range = 20
glow.Brightness = 0.3
glow.Parent = lanternBulb

-- Mood light switch
local switch = model(room, "MoodSwitch")
local plate = part(switch, "Plate", Vector3.new(0.3, 2.2, 1.6), Vector3.new(-29.75, 6.5, 10), WHITE)
part(switch, "Toggle", Vector3.new(0.4, 0.8, 0.5), Vector3.new(-29.5, 6.7, 10), c(255, 214, 96))
prompt(plate, "MoodPrompt", "Flip", "💡 Mood Switch", 10)

-- Where players appear
local spawn = Instance.new("SpawnLocation")
spawn.Name = "TocaSpawn"
spawn.Anchored = true
spawn.Size = Vector3.new(6, 0.2, 6)
spawn.CFrame = CFrame.new(0, 1.1, 10)
spawn.Transparency = 1
spawn.CanCollide = false
spawn.Neutral = true
spawn.Duration = 0
for _, d in ipairs(spawn:GetChildren()) do
	d:Destroy()
end
spawn.Parent = room

world.Parent = Workspace

-- Turn off other spawn points so everyone starts in the bedroom
for _, d in ipairs(Workspace:GetDescendants()) do
	if d:IsA("SpawnLocation") and not d:IsDescendantOf(world) then
		d.Enabled = false
	end
end

---------------------------------------------------------------------------
-- Soft, bright lighting
---------------------------------------------------------------------------
Lighting.ClockTime = 10
Lighting.Brightness = 3
Lighting.Ambient = c(150, 140, 156)
Lighting.OutdoorAmbient = c(186, 176, 196)
Lighting.EnvironmentDiffuseScale = 0.6
Lighting.EnvironmentSpecularScale = 0.2
local function effect(class, name, props)
	local e = Lighting:FindFirstChild(name)
	if e then
		e:Destroy()
	end
	e = Instance.new(class)
	e.Name = name
	for k, v in pairs(props) do
		e[k] = v
	end
	e.Parent = Lighting
end
effect("BloomEffect", "TocaBloom", { Intensity = 0.4, Size = 24, Threshold = 0.95 })
effect("ColorCorrectionEffect", "TocaColor", { Saturation = 0.15, Contrast = 0.05, TintColor = c(255, 248, 252) })
effect("Atmosphere", "TocaAtmosphere", { Density = 0.25, Offset = 0.1, Color = c(232, 222, 255), Decay = c(255, 214, 230), Glare = 0, Haze = 1 })

print("✨ Toca World installed! Press Play to try the creator (✨ button or the vanity mirror).")
