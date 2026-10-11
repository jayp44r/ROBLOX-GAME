#!/bin/bash
# Double-click this to set up the Roblox Studio + Blender connections for Claude Code (macOS).
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"

step() { printf '\n\033[36m== %s\033[0m\n' "$1"; }
ok() { printf '   \033[32mOK\033[0m  %s\n' "$1"; }
warn() { printf '   \033[33m!!\033[0m  %s\n' "$1"; }
finish() { read -r -p $'\nPress Enter to close' _; exit "${1:-0}"; }

step "Checking Node.js"
if ! command -v node >/dev/null 2>&1 && command -v brew >/dev/null 2>&1; then
  echo "   Installing Node.js with Homebrew..."
  brew install node
fi
if ! command -v node >/dev/null 2>&1; then
  warn "Node.js is missing. Install it from https://nodejs.org (LTS), then run this setup again."
  finish 1
fi
ok "Node.js $(node --version)"

step "Installing the connection servers"
for dir in roblox-studio-mcp blender-mcp; do
  (cd "$ROOT/$dir" && npm install --no-audit --no-fund --loglevel=error)
  ok "$dir"
done

step "Installing the Roblox Studio plugin"
PLUGINS="$HOME/Documents/Roblox/Plugins"
mkdir -p "$PLUGINS"
cp -f "$ROOT/roblox-studio-mcp/plugin/RobloxStudioMCP.lua" "$PLUGINS/"
ok "Copied to $PLUGINS (restart Studio if it is open)"

step "Installing the Blender add-on"
BLENDER=""
for candidate in "/Applications/Blender.app/Contents/MacOS/Blender" "$HOME/Applications/Blender.app/Contents/MacOS/Blender" "$(command -v blender || true)"; do
  if [ -n "$candidate" ] && [ -x "$candidate" ]; then BLENDER="$candidate"; break; fi
done
if [ -n "$BLENDER" ]; then
  export BLENDER_MCP_ADDON="$ROOT/blender-mcp/addon/blender_mcp.py"
  "$BLENDER" --background --python-expr "import bpy, os; bpy.ops.preferences.addon_install(filepath=os.environ['BLENDER_MCP_ADDON'], overwrite=True); bpy.ops.preferences.addon_enable(module='blender_mcp'); bpy.ops.wm.save_userpref()" >/dev/null 2>&1 || true
  if "$BLENDER" --background --python-expr "import addon_utils, sys; sys.exit(0 if addon_utils.check('blender_mcp')[1] else 3)" >/dev/null 2>&1; then
    ok "Enabled in Blender (restart Blender if it is open)"
  else
    warn "Could not enable it automatically. In Blender: Edit > Preferences > Add-ons > Install from Disk > blender-mcp/addon/blender_mcp.py"
  fi
else
  warn "Blender not found in Applications. After installing Blender, run this setup again."
fi

printf '\n\033[32mAll done!\033[0m\n'
echo "Next:"
echo "  1. Open Roblox Studio and open your game."
echo "  2. Open the Claude Code app, pick THIS folder, and pick Local (not Cloud)."
echo "  3. Type: connect to Studio"
echo "The first time, Studio asks to let the plugin use localhost: click Allow."
finish 0
