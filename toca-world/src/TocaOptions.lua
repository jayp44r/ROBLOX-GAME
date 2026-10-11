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
