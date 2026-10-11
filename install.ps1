# One-line install for Windows. Paste this into PowerShell:
#   irm https://raw.githubusercontent.com/jayp44r/ROBLOX-GAME/HEAD/install.ps1 | iex
# It downloads this repo to Documents\ROBLOX-GAME and runs the setup.

& {
    $ErrorActionPreference = "Stop"
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    $target = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "ROBLOX-GAME"
    $temp = Join-Path $env:TEMP "roblox-game-download"
    $zip = "$temp.zip"

    Write-Host "`n== Downloading ROBLOX-GAME" -ForegroundColor Cyan
    Remove-Item -Recurse -Force $temp, $zip -ErrorAction SilentlyContinue
    Invoke-WebRequest -UseBasicParsing "https://github.com/jayp44r/ROBLOX-GAME/archive/HEAD.zip" -OutFile $zip
    Expand-Archive -Force $zip $temp
    $source = Get-ChildItem $temp -Directory | Select-Object -First 1
    New-Item -ItemType Directory -Force -Path $target | Out-Null
    Copy-Item -Recurse -Force (Join-Path $source.FullName "*") $target
    Remove-Item -Recurse -Force $temp, $zip -ErrorAction SilentlyContinue
    Write-Host "   OK  Saved to $target" -ForegroundColor Green

    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $target "setup\setup.ps1")
    Start-Process explorer.exe $target
}
