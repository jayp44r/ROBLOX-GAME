# Opened by the "Roblox Claude" desktop shortcut. Press Enter to connect Claude Code
# to Roblox Studio; when Claude Code closes, it comes back here so Enter reconnects.

$Host.UI.RawUI.WindowTitle = "Roblox Claude"
Set-Location $PSScriptRoot

$claude = (Get-Command claude -ErrorAction SilentlyContinue).Source
if (-not $claude) { $claude = Join-Path $env:USERPROFILE ".local\bin\claude.exe" }

while ($true) {
    Write-Host ""
    Write-Host "  Open your game in Roblox Studio, then:" -ForegroundColor Gray
    Write-Host "  Press Enter to connect Claude to Roblox Studio" -ForegroundColor Green
    Write-Host "  (First time only: if it asks to trust this folder, press the Down arrow, then Enter.)" -ForegroundColor DarkGray
    Read-Host | Out-Null
    & $claude "connect to Studio"
}
