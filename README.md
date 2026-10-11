# ROBLOX-GAME

Lets Claude Code build in **Roblox Studio** for you: GUIs, maps, pets, models and animations (and in Blender, if you have it).

## Setup: one command (Windows)

1. Open your game in **Roblox Studio**.
2. Press the **Windows key**, type `powershell`, press **Enter**, paste this and press **Enter**:
   ```
   irm https://raw.githubusercontent.com/jayp44r/ROBLOX-GAME/HEAD/install.ps1 | iex
   ```

It installs everything, puts **Roblox Claude** on your desktop, and opens Claude Code already connected to Studio.

First time only: log in when asked, pick **Yes, I trust this folder** (press the **Down arrow**, then **Enter**), and click **Allow** if Studio asks about `localhost`.

## Every time after that

Open your game in Studio, double-click **Roblox Claude** on your desktop, and ask for anything, like *"make a shop GUI"*.

To update, paste the command again.

## If it doesn't connect

- In Studio, open the **Plugins** tab. The **MCP → Connect** button should be lit; if not, click it.
- Close Studio and Claude Code, open them again.
- Still stuck? Paste the command again.

Details: [roblox-studio-mcp/README.md](roblox-studio-mcp/README.md) and [blender-mcp/README.md](blender-mcp/README.md).
