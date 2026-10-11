# Opened by the "Roblox Claude" desktop shortcut. Press Enter once to connect Claude
# Code to Roblox Studio. If Claude Code closes after running a while, it reopens by
# itself and carries on the same conversation. If it closes right away (for example
# "No" was picked on the trust question), it waits for Enter instead of looping.

$Host.UI.RawUI.WindowTitle = "Roblox Claude"
Set-Location $PSScriptRoot

$claude = (Get-Command claude -ErrorAction SilentlyContinue).Source
if (-not $claude) { $claude = Join-Path $env:USERPROFILE ".local\bin\claude.exe" }
if (-not (Test-Path $claude)) {
    Write-Host "Claude Code isn't installed. Paste the install command again." -ForegroundColor Yellow
    Read-Host "Press Enter to close" | Out-Null
    return
}

function Wait-ForEnter {
    Write-Host ""
    Write-Host "  Open your game in Roblox Studio, then:" -ForegroundColor Gray
    Write-Host "  Press Enter to connect Claude to Roblox Studio" -ForegroundColor Green
    Write-Host ""
    Write-Host "  If Claude asks 'Do you trust this folder?':" -ForegroundColor Yellow
    Write-Host "    press the DOWN ARROW to pick 'Yes, I trust this folder', then Enter." -ForegroundColor Yellow
    Write-Host "    (Plain Enter picks 'No, exit' and Claude closes.) It only asks once." -ForegroundColor DarkGray
    Read-Host | Out-Null
}

$resume = $false
while ($true) {
    if (-not $resume) { Wait-ForEnter }
    $started = Get-Date
    if ($resume) { & $claude --continue "reconnect to Studio" } else { & $claude "connect to Studio" }
    $ranSeconds = ((Get-Date) - $started).TotalSeconds

    if ($ranSeconds -lt 15) {
        # Closed right away: don't reopen into the same question again.
        Write-Host ""
        Write-Host "  Claude closed right away." -ForegroundColor Yellow
        $resume = $false
    } else {
        Write-Host ""
        Write-Host "  Claude closed. Reconnecting in 3 seconds... (close this window to stop)" -ForegroundColor Yellow
        Start-Sleep -Seconds 3
        $resume = $true
    }
}
