# roblox-studio-mcp

Lets Claude Code build directly in Roblox Studio. It has two parts:

- **MCP server** (`src/`): Claude Code starts this. It opens a small bridge on `localhost:44755`.
- **Studio plugin** (`plugin/RobloxStudioMCP.lua`): runs inside Studio, picks up commands from the bridge, runs them in your place, and sends back the results.

```
Claude Code ──stdio──> MCP server ──localhost:44755──> Studio plugin ──> your place
```

Everything stays on your computer, so Claude Code has to run on the **same computer as Studio**. A cloud session can't reach it.

## Setup (once)

You need [Node.js](https://nodejs.org) 18 or newer.

1. **Install the server's packages.** In a terminal, from this folder:
   ```
   cd roblox-studio-mcp
   npm install
   ```
2. **Install the plugin.** In Studio, open the **Plugins** tab and click **Plugins Folder**. Copy `plugin/RobloxStudioMCP.lua` into that folder, then restart Studio.
3. **Turn on the connection.** Open your place. An **MCP** toolbar with a **Connect** button appears in the Plugins tab. It connects automatically, and the button lights up when it's on. The first time, Studio asks whether the plugin may make HTTP requests to `localhost`. Click **Allow**.
4. **Add the server to Claude Code.** If you open Claude Code in this repo folder, the `.mcp.json` at the repo root already registers it, and `.claude/settings.json` turns it on automatically (no approval prompt). To use it from any folder instead:
   ```
   claude mcp add --scope user robloxstudio-mcp -- node "/full/path/to/roblox-studio-mcp/src/index.js"
   ```

Check it works: start Claude Code and ask it to "check Roblox Studio". Studio's Output window should show `[MCP] Connected to Claude Code`.

## Tools

| Tool | What it does |
|---|---|
| `get_connected_instances` | Lists the Studio windows that are connected |
| `get_place_info` | Shows the place name, ids and services |
| `get_explorer_tree` | Reads the Explorer hierarchy |
| `find_instances` | Searches by class (`IsA`) and/or name |
| `get_properties` / `set_properties` | Reads or writes properties, attributes and tags |
| `create_instance` / `mass_create_objects` | Creates one object, or many in a single undo step |
| `create_ui_tree` | Builds a whole nested GUI in one step |
| `clone_instance` / `delete_instances` | Copies or removes objects |
| `get_script_source` / `set_script_source` | Reads or writes scripts, creating them if they don't exist |
| `execute_luau` | Runs any Luau code in Studio and returns its output and return values |
| `get_selection` / `set_selection` | Reads or sets what's selected in Studio |
| `get_output_log` | Recent Output window messages |
| `focus_camera` | Moves the editor camera to a part or model |

Every change is one entry in Studio's undo history, so **Ctrl+Z** reverts it. If a multi-object create fails partway, the whole step is rolled back.

### Property values

Values are written as JSON and converted to whatever type the property already has:

| Type | Example |
|---|---|
| Color3 | `[255, 200, 0]` or `"#ffc800"` |
| Vector3 / Vector2 | `[0, 5, 0]` / `[0.5, 0.5]` |
| UDim2 / UDim | `[0.5, 0, 0.1, 0]` / `[0, 12]` |
| CFrame | `[x, y, z]` or `[x, y, z, rx, ry, rz]` (degrees) |
| Enum | `"FredokaOne"`, `"Neon"`, `"Center"` |
| ColorSequence | `[[255,220,0], [255,140,0]]` or `[[0,[255,0,0]], [1,[0,0,255]]]` |
| NumberSequence | `[0, 1]` or `[[0,0], [0.5,1], [1,0]]` |
| Instance reference | `"Workspace.Map.Spawn"` |
| FontFace | `"FredokaOne"` or `{"family": "Fredoka One", "weight": "Bold"}` |
| Attributes | `"Attributes": {"Price": 100, "Tint": {"type": "Color3", "value": [255,0,0]}}` |

Paths are dot-separated from `game`, for example `StarterGui.ShopGui.MainFrame`. A leading `game.` is optional.

## Settings

- **Port:** set `ROBLOX_STUDIO_MCP_PORT` for the server, and change `PORT` at the top of the plugin file to match. The default is `44755`.
- **Pausing:** click the **Connect** button to disconnect. Studio remembers the choice.
- **Playtests:** only the edit window connects. Playtest server and client windows stay quiet.

## Troubleshooting

- **`get_connected_instances` returns `[]`:** check that Studio is open with a place loaded, and that the **Connect** button is lit. Look in Output for `[MCP] Waiting for Claude Code`.
- **"Port 44755 is already in use":** another Claude Code window is already running the server. Close it, or use a different port in both places.
- **HTTP permission denied:** in Studio, go to **Plugins** tab > **Manage Plugins**, find RobloxStudioMCP, and allow `localhost`.
- **No screenshots:** Studio plugins can't capture the viewport. Use `focus_camera` and look in Studio yourself, or attach a screenshot to your message.
