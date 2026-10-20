# Sync repo scripts into the game folder.
# Usage:
#   powershell -File tools\deploy.ps1            only guard_red.lua
#   powershell -File tools\deploy.ps1 -WithScan  also put tools\scan.lua into autorun
#   powershell -File tools\deploy.ps1 -CleanScan remove the scan script from autorun
# NOTE: keep this file ASCII-only; Windows PowerShell 5.1 mis-parses UTF-8 without BOM.
param(
    [string]$GameDir = "C:\Program Files (x86)\Steam\steamapps\common\MonsterHunterWilds",
    [switch]$WithScan,
    [switch]$CleanScan
)

$src = Join-Path $PSScriptRoot "..\reframework"
$auto = Join-Path $GameDir "reframework\autorun"
$scanDst = Join-Path $auto "zz_guardred_scan.lua"

if (-not (Test-Path (Join-Path $GameDir "MonsterHunterWilds.exe"))) {
    Write-Error "Wrong game dir: $GameDir"
    exit 1
}
if (-not (Test-Path (Join-Path $GameDir "dinput8.dll"))) {
    Write-Warning "No dinput8.dll in game dir; REFramework is not installed."
}

New-Item -ItemType Directory -Force -Path $auto | Out-Null
Copy-Item (Join-Path $src "autorun\guard_red.lua") (Join-Path $auto "guard_red.lua") -Force

if ($WithScan) {
    Copy-Item (Join-Path $PSScriptRoot "scan.lua") $scanDst -Force
    Write-Host "scan.lua -> $scanDst  (remove later with -CleanScan)"
}
if ($CleanScan -and (Test-Path $scanDst)) {
    Remove-Item $scanDst -Force
    Write-Host "removed $scanDst"
}

Write-Host "synced guard_red.lua -> $auto"
Write-Host "In game: ScriptRunner -> Reset Scripts to reload."
