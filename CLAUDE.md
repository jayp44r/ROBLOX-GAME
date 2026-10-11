# ROBLOX-GAME

This folder connects Claude Code to Roblox Studio (`robloxstudio-mcp`) and Blender (`blender-mcp`). Both servers are registered in `.mcp.json` and turned on automatically by `.claude/settings.json`.

## How to work with this user

The user is a non-technical Roblox creator. They want things built, not discussed.

- Get straight to it. Build what they ask in Studio right away, picking sensible defaults (cartoony simulator style, works on phone and PC) instead of asking.
- Ask a question only when you truly can't continue without their answer, and then ask one short question.
- Keep replies short: a few lines saying what you built and where it is in Explorer. No long explanations, option lists or technical terms.
- When something needs them to act (click Allow, open a place), give one or two plain steps.

## When the user asks to connect to Roblox Studio

Treat "connect", "connect to Studio", "check Studio" and similar as a request to connect right away, without asking first:

1. Call `get_connected_instances` on `robloxstudio-mcp`.
2. If it lists a Studio window, call `get_place_info`, then tell the user in one line that you're connected and which place is open. Then do what they asked.
3. If it lists none, Studio isn't reaching the bridge. Tell the user to:
   - open a place in Roblox Studio (the plugin connects by itself when a place opens),
   - check that the **MCP → Connect** button in the **Plugins** tab is lit, and click it if not,
   - click **Allow** if Studio asks to let the plugin use `localhost`.

   Then call `get_connected_instances` again.
4. If the `robloxstudio-mcp` tools are missing or show as failed:
   - In a cloud session, they can't work: Studio runs on the user's computer and a cloud container can't reach it. Tell the user to open this folder in a **local** Claude Code session on the computer that runs Studio.
   - In a local session, the setup probably hasn't been run. Tell the user to paste `irm https://raw.githubusercontent.com/jayp44r/ROBLOX-GAME/HEAD/install.ps1 | iex` into PowerShell, then double-click **Roblox Claude** on the desktop.

Do the same for Blender with `blender-mcp` when the user asks to connect to Blender.
