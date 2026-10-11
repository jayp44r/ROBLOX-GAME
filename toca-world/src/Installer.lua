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
