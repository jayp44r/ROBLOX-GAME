---
name: blender-modeling
description: Pro Blender modelling and scene tricks via blender-mcp. Covers round objects with the Spin/lathe trick (bottles, cups, potions, vases, pillars, barrels), staircases, brick or stone paths, puffy cloud seas, rainbows, sky lighting, grass scatter, handheld camera shake and a dreamy or VHS render look. Use when the user wants a model, prop or scene made in Blender, or a cinematic render or thumbnail.
---

# Blender modelling and scenes

Learned from creator videos: a water bottle modelled in a minute with the Spin tool (@wisefrog7), and a dreamy "door in the sky" VHS render (@onlyrj.tech).

Helpers live in `scripts/blender_tricks.py`. Send the whole file through blender-mcp `execute_python`, followed by the calls you need, in the same code string. All helpers were tested in Blender 5.2, and each one replaces any object of the same name, so it's safe to re-run.

## Round objects: the Spin (lathe) trick

Don't model bottles, cups, potions, vases, lamps, pillars or barrels face by face. Draw the **side outline** and spin it 360°, which takes seconds:

```python
lathe("Bottle", [(0,0),(0.35,0),(0.38,0.1),(0.36,0.5),(0.38,0.9),(0.3,1.15),(0.14,1.3),(0.14,1.42),(0,1.42)])
```

- Points are `(radius, height)` from bottom to top. Start and end at radius 0 so it's closed.
- More points where the shape bends gives a crisper shape. `subdivide=2` gives the smooth Ctrl+2 look.
- For a reference photo: trace the outline's right half, measure a few radii, and type them in.
- Hand-made in Blender: Shift+A → Mesh → Plane, Edit Mode, M → Merge At Center, extrude (E) a vertex up along the outline, Spin tool, angle 360, then Ctrl+2.
- For Roblox: keep `steps` at 16-24 and `subdivide=0` or 1, then apply the modifier before `export_fbx` (fewer triangles works better on phones).

## Scene building blocks

- `stairs("Stairs", steps=8, width=2, depth=0.35, height=0.2)`: one clean mesh with a small bevel. By hand: a cube, then Bevel with a custom profile using the "Steps" preset.
- `brick_material()`: brick texture × noise texture for colour variation + Bump from the brick. Assign it to a path or floor plane.
- `cloud_plane(size=40, height=-3)`: a plane + **Ocean modifier** (choppiness 0) + Smooth, matte white with a touch of subsurface, for puffy clouds below the path.
- `rainbow(radius=12, location=(0,20,0))`: an emission arch with soft edges. Place it behind the subject.
- `world_sky()`: Blender's built-in sky, or `world_sky(hdri_path=...)` for an HDRI from Poly Haven. Lighting from the sky beats lots of lamps.
- **Grass or plants**: add 2 thin planes beside the path and use a particle system (Hair, render as Object/Collection) or geometry nodes *Distribute Points on Faces → Instance on Points* with a small grass blade, randomising rotation and scale.
- Assets like doors and furniture: `import_file` a free model, or build one from cubes with bevels.

## Camera and the "filmed" look

- `handheld_camera("Camera", strength=0.03)` adds Noise modifiers so the shot drifts like a handheld camera. For a calmer shot, use about 0.01.
- Low camera, slightly upward, subject centred, long lens (50-85 mm) gives a dreamy look.
- **VHS look**: the video did it in an editor (DaVinci Resolve) with chromatic aberration, scanlines, noise, slight blur and a date stamp like "PM 1:02 DEC. 22 2023". In Blender you can approximate it in the Compositor (Lens Distortion with dispersion, Glare, a film-grain noise mix, lower saturation). Render at 640×480 and upscale for chunkier pixels.

## Making it pro

- Bevel every hard edge a little (`add_modifier` Bevel, width 0.01-0.03). Real objects never have razor edges.
- Use 2-3 materials with roughness variation (noise into Roughness) rather than flat colours.
- Check with `get_viewport_screenshot` after each big step, and fix what looks off before moving on.
- Name objects clearly. Apply scale (Ctrl+A) before exporting to Roblox, and keep it under about 10k triangles per prop.
