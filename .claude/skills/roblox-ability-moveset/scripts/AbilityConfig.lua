-- AbilityConfig: ModuleScript in ReplicatedStorage. Edit this to change the moveset.
-- kind = which effect + logic to use:
--   "burst"  - magic circle + shockwave around you, damage + knockback in a radius
--   "chain"  - beam to the nearest enemy near your aim, damage + stun (rooted)
--   "aura"   - dark aura on you, damage ticks around you, purple screen tint
--   "shield" - bubble on you, you take no damage for `duration`
--   "storm"  - huge dark circle on the ground, damage ticks in a big radius
--   "bolt"   - fast projectile toward your aim, explodes on hit

return {
	name = "DARK SELF",
	theme = {
		main = Color3.fromRGB(150, 80, 255), -- glow / magic circle
		dark = Color3.fromRGB(25, 10, 40), -- smoke
		light = Color3.fromRGB(225, 200, 255), -- flashes and core
	},
	wheelKey = Enum.KeyCode.Q, -- hold to open the ability wheel
	abilities = {
		{ id = "Outburst", key = Enum.KeyCode.E, cooldown = 6, kind = "burst", radius = 14, damage = 20, knockback = 70 },
		{ id = "Chains", key = Enum.KeyCode.R, cooldown = 10, kind = "chain", range = 45, damage = 12, stun = 1.5 },
		{ id = "Overload", key = Enum.KeyCode.C, cooldown = 15, kind = "aura", radius = 12, damage = 6, ticks = 6, tickTime = 0.5 },
		{ id = "Shield", key = Enum.KeyCode.F, cooldown = 14, kind = "shield", duration = 3 },
		{ id = "Bolt", key = Enum.KeyCode.T, cooldown = 2, kind = "bolt", range = 80, speed = 120, radius = 6, damage = 10 },
		{ id = "Soul Storm", key = Enum.KeyCode.V, cooldown = 20, kind = "storm", radius = 24, damage = 8, ticks = 8, tickTime = 0.5 },
	},
}
