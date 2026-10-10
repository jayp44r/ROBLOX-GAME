# ROBLOX-GAME

Connects Claude Code to **Roblox Studio** and **Blender**, so Claude can build GUIs, maps, pets, models and animations directly in them.

## Setup (one double-click)

1. On GitHub, click **Code > Download ZIP** and unzip it (or clone the repo).
2. Double-click **`SETUP-WINDOWS.bat`** (Windows) or **`SETUP-MAC.command`** (Mac). It installs everything:
   - the connection servers (it installs Node.js too if it's missing),
   - the Roblox Studio plugin,
   - the Blender add-on.
3. Open Roblox Studio and Blender, then open **this folder** in Claude Code on your computer. Choose a local session, not cloud, and approve the two servers when asked.

Done. Ask Claude Code to build something. The first time, Studio asks to allow the plugin to use `localhost`: click **Allow**.

Details: [roblox-studio-mcp/README.md](roblox-studio-mcp/README.md) and [blender-mcp/README.md](blender-mcp/README.md).
