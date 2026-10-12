---
name: gta-style-game
description: Build GTA-style Roblox features. Covers a radial weapon wheel (hold Tab/Q/L1, or tap on phone), an over-the-shoulder aiming camera with crosshair, gun muzzle flash and smoke, and a cinematic lighting overhaul (sunset over the ocean, night or day, with an optional day/night cycle). Use when the user asks for a weapon wheel, weapon select, shooter or third-person aim camera, gun effects, GTA or open-world city game, or better lighting, graphics, sunset or day/night.
---

# GTA-style game features

Learned from a "GTA inspired game" devlog by @pendingdev. It showed:
- shooting over the shoulder with a muzzle flash and smoke;
- a weapon wheel: a ring around the character with the gun on top, a teal highlight on the hovered slot, a ✓ on the equipped weapon, and a blurred background;
- a lighting overhaul: golden sunset over shiny ocean water, pink clouds, haze and a big glowing sun or moon.

Each part works on its own; build only what the user asks for. All scripts work on PC, phone and gamepad. Paste them in with the robloxstudio-mcp tools (create the instance, then set its Source).

| Feature | File | Goes in |
|---|---|---|
| Weapon wheel | `scripts/WeaponWheel.client.lua` | LocalScript `WeaponWheel` in StarterPlayer › StarterPlayerScripts |
| Shoulder aim camera | `scripts/ShoulderCamera.client.lua` | LocalScript `ShoulderCamera` in StarterPlayer › StarterPlayerScripts |
| Muzzle flash + smoke | `scripts/MuzzleFlash.lua` | ModuleScript `MuzzleFlash` in ReplicatedStorage |
| Lighting overhaul | `scripts/LightingPresets.lua` | Script `LightingPresets` in ServerScriptService |

## Weapon wheel

- Lists the Tools in the player's Backpack (up to 7) plus "Unarmed". Any tool, gun or not, works.
- **PC**: hold **Tab** or **Q**, point at a slot, let go. **Gamepad**: hold **L1**, aim the right stick. **Phone**: a round 🔫 button on the right; tap it, then tap a slot.
- A tool with a `TextureId` shows its icon; otherwise it shows the tool name.
- Change the highlight colour with `ACCENT` (default teal `70,230,170`).
- If the game has no tools yet, add a couple of Tools to StarterPack so the wheel has something to show.

## Shoulder camera

Turns on whenever a Tool is held: the camera shifts right by `OFFSET`, the character turns with the camera, the mouse locks to the centre and a crosshair dot appears. It unlocks while the weapon wheel is open. On phone it uses Roblox's normal touch camera.

## Muzzle flash

In each gun's firing code (inside `tool.Activated`), call `MuzzleFlash.play(tool.Handle)`. Put an Attachment named `Muzzle` at the barrel tip for exact placement. Fire it on each client (via a RemoteEvent) if other players should see it.

## Lighting overhaul

Sets `Atmosphere`, `Bloom`, `SunRays`, `ColorCorrection`, volumetric `Clouds` and terrain water so everything looks like the video's warm sunset.
- `PRESET`: `"sunset"` (default), `"night"` or `"day"`.
- `CYCLE = true` makes time keep moving (`MINUTES_PER_DAY`).
- Also set **Lighting › Technology = Future**. Game scripts aren't allowed to set it, but the Studio plugin is, so set it directly with robloxstudio-mcp.
- Water only shows if the map has terrain water. For an ocean like the video, fill a big flat region with Water terrain (`workspace.Terrain:FillBlock(CFrame.new(0, -10, 0), Vector3.new(2048, 20, 2048), Enum.Material.Water)`).
- Volumetric clouds and Future lighting cost frames on weak phones. If the user says it's laggy, set the `Clouds` Density lower or remove the Clouds instance.

## Reply to the user

A few lines: what you added, where it is in Explorer, and how to try it (press Play, hold Tab / tap the 🔫 button).
