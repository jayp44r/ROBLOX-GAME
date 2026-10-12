---
name: anime-burst-vfx
description: Make an anime / toon-style burst, shockwave, impact or explosion VFX (a dome that pops up with swirling cartoon stripes, an expanding ring, then breaks apart and fades). Use when the user asks for a burst, blast, shockwave, impact, slam, explosion, ground pound, aura pop, ability effect or "anime VFX", in Roblox Studio or Blender.
---

# Anime burst VFX

Learned from a Blender tutorial by @goodgood3d. The effect has three parts that play together over about 1 second:

1. **Dome**: a half sphere that shoots up fast, overshoots a little, then settles (ease-out curve).
2. **Ring**: a thin flat ring on the ground that expands outward and fades.
3. **Toon surface**: hard-edged black/colour stripes (no soft shading) that swirl and scroll upward. Near the end the dome breaks into blotchy holes and disappears.

Default look: cyan stripes on black, glowing. Other colours from the video: green, red/pink, white/blue. Pick one that matches the ability if the user doesn't say.

## In Roblox Studio (default)

Use `scripts/BurstVFX.lua`. It's a ModuleScript with no assets needed: Neon + ForceField parts tweened with TweenService.

1. Create a ModuleScript named `BurstVFX` in `ReplicatedStorage` and paste in the file's contents.
2. Call it from wherever the ability fires. On the server it shows for everyone; on the client it's smoother but only that player sees it:
   ```lua
   local BurstVFX = require(game.ReplicatedStorage.BurstVFX)
   BurstVFX.play(position, { color = Color3.fromRGB(70, 230, 255), size = 12 })
   ```
3. For a test, also add a Script in `ServerScriptService` that plays a burst under each player every 3 seconds, or when a part is touched.

Options: `color`, `size` (dome width in studs, default 12), `duration` (seconds, default 0.9), `ring` (true/false), `sparks` (true/false).

To match the video more closely (real swirl stripes and a dissolve), build the meshes and a stripe texture in Blender (below), export them, and swap them into the module: dome and ring become MeshParts, and the stripes become a Decal/Texture that scrolls with `OffsetStudsV`.

Keep it cheap for phones: one burst is about 4 parts plus 1 emitter, and everything is destroyed with Debris once it finishes.

## In Blender

Run `scripts/burst_blender.py` with the `execute_python` tool on `blender-mcp`. It builds the whole effect in the open scene: objects `Burst_Dome` and `Burst_Ring`, materials `BurstMat` and `BurstRingMat`, geometry-node groups `BurstAnim` and `RingAnim`, frames 1-40. Then press play.

How it's built, so you can tweak it:

- **Shape animation (Geometry Nodes)**: `Scene Time.Frame` → `Map Range` (frame 0-25 → 0-1, clamp) → `Float Curve` (fast rise, slight overshoot, settle) → `Transform Geometry.Scale`. The ring uses its own curve that keeps growing.
- **age attribute**: the same 0-1 time value goes into `Store Named Attribute` (Float, Point, name `age`). The material reads it with an `Attribute` node to know how far through the burst it is.
- **Toon stripes (shader)**:
  - `Texture Coordinate.Generated` → `Mapping`.
  - Twist: `Separate XYZ.Z` × ~2 → `Combine XYZ` Z → Mapping **Rotation**.
  - Scroll: a driver on Mapping Location Z uses `frame`.
  - → `Noise Texture` (3D fBM, scale ~5, detail 0, roughness 0.5) → `Greater Than` (threshold 0.5) gives hard 0/1 stripes.
  - A `Gradient Texture` set to Quadratic Sphere in place of the noise gives a spiral instead of blotches.
- **Dissolve**: `age` → `Map Range` (0.4-1 → 0.1-1.0) → threshold of a second `Greater Than` on the noise → drives alpha, so holes grow until it's gone.
- **Colour**: stripes = Emission (cyan, strength 3); gaps = black Principled BSDF. `Geometry.Backfacing` mixes the inside to black so the dome reads as a shell.
- Ring material: emission only, faded by `age`.

Tweak recipe: change the threshold for thicker or thinner stripes, the noise scale for busier stripes, the Combine XYZ multiply for more swirl, and the Float Curve for snappier or bouncier motion.

To get it into Roblox: export `Burst_Dome` and `Burst_Ring` with `export_fbx`, import them with Studio's 3D Importer, and render the stripe pattern to a PNG for a Texture. Shader nodes and geometry nodes don't carry over to Roblox. Only meshes and images do.

## Reply to the user

A few lines: what you made, where it is in Explorer (or in the Blender scene), and how to see it (press Play, or press Space in Blender).
