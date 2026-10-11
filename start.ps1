# Opened by the "Roblox Claude" desktop shortcut. Press Enter once to connect Claude
# Code to Roblox Studio. If Claude Code ever closes, it reopens by itself and carries
# on the same conversation, so it stays connected until this window is closed.

$Host.UI.RawUI.WindowTitle = "Roblox Claude"
Set-Location $PSScriptRoot

$claude = (Get-Command claude -ErrorAction SilentlyContinue).Source
if (-not $claude) { $claude = Join-Path $env:USERPROFILE ".local\bin\claude.exe" }
if (-not (Test-Path $claude)) {
    Write-Host "Claude Code isn't installed. Paste the install command again." -ForegroundColor Yellow
    Read-Host "Press Enter to close" | Out-Null
    return
}

Write-Host ""
Write-Host "  Open your game in Roblox Studio, then:" -ForegroundColor Gray
Write-Host "  Press Enter to connect Claude to Roblox Studio" -ForegroundColor Green
Write-Host "  (First time only: if it asks to trust this folder, press the Down arrow, then Enter.)" -ForegroundColor DarkGray
Read-Host | Out-Null
& $claude "connect to Studio"

while ($true) {
    Write-Host ""
    Write-Host "  Claude closed. Reconnecting in 3 seconds... (close this window to stop)" -ForegroundColor Yellow
    Start-Sleep -Seconds 3
    & $claude --continue "reconnect to Studio"
}
