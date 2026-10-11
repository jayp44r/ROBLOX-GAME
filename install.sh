#!/bin/bash
# One-line install for Mac. Paste this into Terminal:
#   curl -fsSL https://raw.githubusercontent.com/jayp44r/ROBLOX-GAME/HEAD/install.sh | bash
# It downloads this repo to ~/Documents/ROBLOX-GAME and runs the setup.

main() {
  set -e
  TARGET="$HOME/Documents/ROBLOX-GAME"
  TEMP="$(mktemp -d)"

  printf '\n\033[36m== %s\033[0m\n' "Downloading ROBLOX-GAME"
  curl -fsSL "https://github.com/jayp44r/ROBLOX-GAME/archive/HEAD.zip" -o "$TEMP/repo.zip"
  unzip -q "$TEMP/repo.zip" -d "$TEMP/unzipped"
  SOURCE="$(find "$TEMP/unzipped" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
  mkdir -p "$TARGET"
  cp -R "$SOURCE"/. "$TARGET"/
  rm -rf "$TEMP"
  chmod +x "$TARGET/SETUP-MAC.command"
  printf '   \033[32mOK\033[0m  Saved to %s\n' "$TARGET"

  # Read prompts from the keyboard, not from the piped-in script.
  bash "$TARGET/SETUP-MAC.command" < /dev/tty
  open "$TARGET"
}

main "$@"
