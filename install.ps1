# One command does everything (Windows). Paste this into PowerShell:
#   irm https://raw.githubusercontent.com/jayp44r/ROBLOX-GAME/HEAD/install.ps1 | iex
#
# It downloads this repo to Documents\ROBLOX-GAME, installs Node.js, the connection
# servers, the Roblox Studio plugin, the Blender add-on and Claude Code, puts a
# "Roblox Claude" shortcut on the desktop, and opens Claude Code connected to Studio.
# Run it again any time to update.

& {
    $ErrorActionPreference = "Stop"
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    function Step($text) { Write-Host "`n== $text" -ForegroundColor Cyan }
    function Ok($text) { Write-Host "   OK  $text" -ForegroundColor Green }
    function Warn($text) { Write-Host "   !!  $text" -ForegroundColor Yellow }
    function Refresh-Path {
        $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
    }

    $root = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "ROBLOX-GAME"

    # 1. Download ---------------------------------------------------------------
    Step "Downloading ROBLOX-GAME"
    $temp = Join-Path $env:TEMP "roblox-game-download"
    $zip = "$temp.zip"
    Remove-Item -Recurse -Force $temp, $zip -ErrorAction SilentlyContinue
    Invoke-WebRequest -UseBasicParsing "https://github.com/jayp44r/ROBLOX-GAME/archive/HEAD.zip" -OutFile $zip
    Expand-Archive -Force $zip $temp
    $source = Get-ChildItem $temp -Directory | Select-Object -First 1
    New-Item -ItemType Directory -Force -Path $root | Out-Null
    # Files from older versions that are no longer used
    Remove-Item -Recurse -Force (Join-Path $root "setup"), (Join-Path $root "SETUP-WINDOWS.bat"), (Join-Path $root "SETUP-MAC.command"), (Join-Path $root "install.sh") -ErrorAction SilentlyContinue
    Copy-Item -Recurse -Force (Join-Path $source.FullName "*") $root
    Remove-Item -Recurse -Force $temp, $zip -ErrorAction SilentlyContinue
    Ok "Saved to $root"

    # 2. Node.js ----------------------------------------------------------------
    Step "Checking Node.js"
    if (-not (Get-Command node -ErrorAction SilentlyContinue) -and (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "   Installing Node.js (a window may ask for permission: click Yes)..."
        winget install --id OpenJS.NodeJS.LTS -e --accept-source-agreements --accept-package-agreements | Out-Host
        Refresh-Path
    }
    if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
        Warn "Node.js is missing. Install it from https://nodejs.org (LTS), then paste the command again."
        return
    }
    Ok "Node.js $(node --version)"

    # 3. Connection servers ------------------------------------------------------
    Step "Installing the connection servers"
    foreach ($dir in "roblox-studio-mcp", "blender-mcp") {
        Push-Location (Join-Path $root $dir)
        & npm.cmd install --no-audit --no-fund --loglevel=error | Out-Host
        $failed = $LASTEXITCODE -ne 0
        Pop-Location
        if ($failed) { Warn "npm install failed in $dir. Paste the command again."; return }
        Ok $dir
    }

    # 4. Roblox Studio plugin ----------------------------------------------------
    Step "Installing the Roblox Studio plugin"
    $pluginsDir = Join-Path $env:LOCALAPPDATA "Roblox\Plugins"
    New-Item -ItemType Directory -Force -Path $pluginsDir | Out-Null
    Copy-Item -Force (Join-Path $root "roblox-studio-mcp\plugin\RobloxStudioMCP.lua") $pluginsDir
    Ok "Installed (restart Studio if it is open)"

    # 5. Blender add-on (optional) -----------------------------------------------
    Step "Installing the Blender add-on"
    $blenders = @()
    $blenders += Get-ChildItem "C:\Program Files\Blender Foundation\*\blender.exe" -ErrorAction SilentlyContinue
    $blenders += Get-ChildItem "C:\Program Files (x86)\Steam\steamapps\common\Blender\blender.exe" -ErrorAction SilentlyContinue
    $blender = $blenders | Sort-Object { $_.Directory.Name } -Descending | Select-Object -First 1
    if ($blender) {
        $env:BLENDER_MCP_ADDON = Join-Path $root "blender-mcp\addon\blender_mcp.py"
        $expr = "import bpy, os; bpy.ops.preferences.addon_install(filepath=os.environ['BLENDER_MCP_ADDON'], overwrite=True); bpy.ops.preferences.addon_enable(module='blender_mcp'); bpy.ops.wm.save_userpref()"
        & $blender.FullName --background --python-expr $expr 2>&1 | Out-Null
        Ok "Enabled in Blender (restart Blender if it is open)"
    } else {
        Ok "Skipped (Blender isn't installed)"
    }

    # 6. Claude Code ---------------------------------------------------------------
    Step "Installing Claude Code"
    $claudeExe = Join-Path $env:USERPROFILE ".local\bin\claude.exe"
    if (-not (Get-Command claude -ErrorAction SilentlyContinue) -and -not (Test-Path $claudeExe)) {
        & powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://claude.ai/install.ps1 | iex" | Out-Host
        Refresh-Path
    }
    $claude = Get-Command claude -ErrorAction SilentlyContinue
    if ($claude) { $claudeExe = $claude.Source }
    if (-not (Test-Path $claudeExe)) {
        Warn "Claude Code didn't install. Get it from https://claude.ai/download, then paste the command again."
        return
    }
    Ok "Claude Code is ready"

    # 7. Desktop shortcut, then open it ---------------------------------------------
    Step "Adding 'Roblox Claude' to your desktop"
    $shortcutPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "Roblox Claude.lnk"
    $shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut($shortcutPath)
    $shortcut.TargetPath = "powershell.exe"
    $shortcut.Arguments = "-NoProfile -NoExit -Command `"& '$claudeExe' 'connect to Studio'`""
    $shortcut.WorkingDirectory = $root
    $shortcut.IconLocation = "$claudeExe,0"
    $shortcut.Description = "Open Claude Code connected to Roblox Studio"
    $shortcut.Save()
    Ok "Done"

    Write-Host "`nAll done! Opening Claude Code now." -ForegroundColor Green
    Write-Host "Have your game open in Roblox Studio. Next time, just double-click 'Roblox Claude' on your desktop."
    Write-Host "First time only: log in when asked, pick "Yes, I trust this folder" (Down arrow, then Enter), and click Allow in Studio."
    Start-Process $shortcutPath
}
