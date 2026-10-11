# One-time setup for the Roblox Studio + Blender connections to Claude Code (Windows).
# Run it by double-clicking SETUP-WINDOWS.bat in the repo folder.

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

function Step($text) { Write-Host "`n== $text" -ForegroundColor Cyan }
function Ok($text) { Write-Host "   OK  $text" -ForegroundColor Green }
function Warn($text) { Write-Host "   !!  $text" -ForegroundColor Yellow }

function Refresh-Path {
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
}

# 1. Node.js -------------------------------------------------------------
Step "Checking Node.js"
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "   Installing Node.js (a window may ask for permission)..."
        winget install --id OpenJS.NodeJS.LTS -e --accept-source-agreements --accept-package-agreements | Out-Host
        Refresh-Path
    }
}
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Warn "Node.js is missing. Install it from https://nodejs.org (LTS), then run this setup again."
    Read-Host "Press Enter to close"
    exit 1
}
Ok "Node.js $(node --version)"

# 2. Server packages -------------------------------------------------------
Step "Installing the connection servers"
foreach ($dir in "roblox-studio-mcp", "blender-mcp") {
    Push-Location (Join-Path $root $dir)
    & npm.cmd install --no-audit --no-fund --loglevel=error | Out-Host
    if ($LASTEXITCODE -ne 0) { Pop-Location; throw "npm install failed in $dir" }
    Pop-Location
    Ok $dir
}

# 3. Roblox Studio plugin ------------------------------------------------
Step "Installing the Roblox Studio plugin"
$pluginsDir = Join-Path $env:LOCALAPPDATA "Roblox\Plugins"
New-Item -ItemType Directory -Force -Path $pluginsDir | Out-Null
Copy-Item -Force (Join-Path $root "roblox-studio-mcp\plugin\RobloxStudioMCP.lua") $pluginsDir
Ok "Copied to $pluginsDir (restart Studio if it is open)"

# 4. Blender add-on --------------------------------------------------------
Step "Installing the Blender add-on"
$blenders = @()
$blenders += Get-ChildItem "C:\Program Files\Blender Foundation\*\blender.exe" -ErrorAction SilentlyContinue
$blenders += Get-ChildItem "C:\Program Files (x86)\Steam\steamapps\common\Blender\blender.exe" -ErrorAction SilentlyContinue
$blenders += Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WindowsApps\blender*.exe" -ErrorAction SilentlyContinue
$blender = $blenders | Sort-Object { $_.Directory.Name } -Descending | Select-Object -First 1
if ($blender) {
    $env:BLENDER_MCP_ADDON = Join-Path $root "blender-mcp\addon\blender_mcp.py"
    $expr = "import bpy, os; bpy.ops.preferences.addon_install(filepath=os.environ['BLENDER_MCP_ADDON'], overwrite=True); bpy.ops.preferences.addon_enable(module='blender_mcp'); bpy.ops.wm.save_userpref()"
    & $blender.FullName --background --python-expr $expr 2>&1 | Out-Null
    & $blender.FullName --background --python-expr "import addon_utils, sys; sys.exit(0 if addon_utils.check('blender_mcp')[1] else 3)" 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { Ok "Enabled in $($blender.FullName) (restart Blender if it is open)" }
    else { Warn "Could not enable it automatically. In Blender: Edit > Preferences > Add-ons > Install from Disk > blender-mcp\addon\blender_mcp.py" }
} else {
    Warn "Blender not found. After installing Blender, run this setup again."
}

# 5. Claude Code + desktop shortcut ----------------------------------------
Step "Installing Claude Code"
$claudeExe = Join-Path $env:USERPROFILE ".local\bin\claude.exe"
if (-not (Get-Command claude -ErrorAction SilentlyContinue) -and -not (Test-Path $claudeExe)) {
    & powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://claude.ai/install.ps1 | iex" | Out-Host
    Refresh-Path
}
$claude = Get-Command claude -ErrorAction SilentlyContinue
if ($claude) { $claudeExe = $claude.Source }
if (Test-Path $claudeExe) {
    Ok "Claude Code is installed"
    $shortcutPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "Roblox Claude.lnk"
    $shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut($shortcutPath)
    $shortcut.TargetPath = "powershell.exe"
    $shortcut.Arguments = "-NoProfile -NoExit -Command `"& '$claudeExe' 'connect to Studio'`""
    $shortcut.WorkingDirectory = $root
    $shortcut.IconLocation = "$claudeExe,0"
    $shortcut.Description = "Open Claude Code connected to Roblox Studio"
    $shortcut.Save()
    Ok "Added 'Roblox Claude' to your desktop"
} else {
    Warn "Claude Code is missing. Install it from https://claude.ai/download, then run this setup again."
}

Write-Host "`nAll done!" -ForegroundColor Green
Write-Host "Next:"
Write-Host "  1. Open Roblox Studio and open your game."
Write-Host "  2. Double-click 'Roblox Claude' on your desktop."
Write-Host "The first time, it asks you to log in and to trust the folder: press Enter."
Write-Host "The first time, Studio asks to let the plugin use localhost: click Allow."
Read-Host "`nPress Enter to close"
