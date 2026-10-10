# blender-mcp

Lets Claude Code build and animate in Blender. It has two parts:

- **Blender add-on** (`addon/blender_mcp.py`): runs a small server inside Blender on `localhost:44756`.
- **MCP server** (`src/`): Claude Code starts this. It forwards each tool call to the add-on.

```
Claude Code ──stdio──> MCP server ──localhost:44756──> Blender add-on ──> your scene
```

Claude Code has to run on the **same computer as Blender**. It works with Blender 3.6 to 5.x.

## Setup (once)

1. **Install the server's packages.** From this folder, run `npm install` (needs [Node.js](https://nodejs.org) 18+).
2. **Install the add-on.** In Blender, go to **Edit > Preferences > Add-ons**, use the drop-down at the top right and choose **Install from Disk**. Pick `addon/blender_mcp.py`, then tick **Blender MCP** to enable it.
3. **Check it's running.** In the 3D viewport press **N** and open the **MCP** tab. It should say **Running on port 44756**. It starts automatically each time Blender opens; you can turn that off in the add-on's preferences.
4. **Add the server to Claude Code.** The `.mcp.json` at the repo root registers it when you open Claude Code in this repo. To use it from any folder instead:
   ```
   claude mcp add --scope user blender-mcp -- node "/full/path/to/blender-mcp/src/index.js"
   ```

## Tools

| Tool | What it does |
|---|---|
| `get_scene_info` | Blender version, objects, fps and frame range, and whether the Roblox add-on is installed |
| `get_object_info` | Transform, materials, modifiers, mesh stats, bones and action of one object |
| `create_object` | Adds cubes, spheres, cylinders, cones, planes, torus, monkey, empties, cameras and lights |
| `transform_objects` / `delete_objects` | Moves, rotates and scales objects, or removes them |
| `set_material` | Colour, metallic, roughness, and glow (for neon pets) |
| `add_modifier` | Bevel, subdivision, mirror, array and the rest |
| `set_animation_settings` | fps and frame range (Roblox plays at 30 fps) |
| `get_armature_bones` | Bone list for R6 and R15 rigs |
| `insert_keyframes` | Keyframes objects or bones; rotation is in degrees and converted to each bone's rotation mode |
| `clear_animation` | Removes an object's animation |
| `execute_python` | Runs any `bpy` code |
| `import_file` / `export_fbx` | Imports FBX, OBJ, glTF, STL or .blend files; exports FBX set up for Roblox |
| `get_viewport_screenshot` | Captures the viewport as an image so Claude can see the result |
| `save_blend_file` | Saves the .blend file |

Each change is a Blender undo step, so **Ctrl+Z** reverts it.

## Getting work into Roblox

- **Models:** use `export_fbx`, then in Studio choose **File > Import 3D**. Or use the Roblox Blender plugin's upload.
- **Animations:** key the rig at 30 fps and `export_fbx` with the armature. Then, in Studio's **Animation Editor**, choose **Import > From FBX Animation**. Publish the animation to get its ID; only you can publish to your account.

## Troubleshooting

- **"Blender is not connected":** check that Blender is open with the add-on enabled, and that the MCP tab says Running.
- **"Port busy":** another program is using 44756. Change the port in the add-on's preferences, and set `BLENDER_MCP_PORT` for the server to match.
- **A command times out:** Blender runs commands on its main thread, so close any open dialog or menu in Blender.
