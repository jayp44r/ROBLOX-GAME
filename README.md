# ROBLOX-GAME

Lets Claude Code build in **Roblox Studio** and **Blender** for you: GUIs, maps, pets, models and animations.

## Setup: 2 steps, done once

**1. Download and install: paste one line.**

**Windows:** press the **Windows key**, type `powershell`, press **Enter**, then paste this and press **Enter**:
```
irm https://raw.githubusercontent.com/jayp44r/ROBLOX-GAME/HEAD/install.ps1 | iex
```

**Mac:** press **Cmd + Space**, type `terminal`, press **Enter**, then paste this and press **Enter**:
```
curl -fsSL https://raw.githubusercontent.com/jayp44r/ROBLOX-GAME/HEAD/install.sh | bash
```

It downloads everything into your **Documents** folder as **ROBLOX-GAME**, installs it, and opens the folder. Wait until it says **All done!**

**2. Start building.**

**Windows:**
1. Open Roblox Studio and open your game.
2. Double-click **Roblox Claude** on your desktop. It opens Claude Code in the right folder and connects to Studio by itself.

The first time, it asks you to log in, and asks whether to trust the folder (press **Enter**).

**Mac:** open Roblox Studio and your game, then open the **ROBLOX-GAME** folder (in Documents) in the Claude Code app, pick **Local**, and type **connect to Studio**.

The first time, Studio asks to let the plugin use `localhost`. Click **Allow**.

That's it. Now ask for anything, like *"make a shop GUI"* or *"build a lava obby"*.

## Every time after that

Open your game in Studio, then double-click **Roblox Claude** (Windows) and ask.

## If it doesn't connect

- In Studio, open the **Plugins** tab. The **MCP → Connect** button should be lit; if not, click it.
- Close Studio and Claude Code, then open them again.
- Still stuck? Run step 1 again.

More details: [roblox-studio-mcp/README.md](roblox-studio-mcp/README.md) and [blender-mcp/README.md](blender-mcp/README.md).
