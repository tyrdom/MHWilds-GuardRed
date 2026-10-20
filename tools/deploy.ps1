# 把仓库里的 reframework 目录同步到游戏目录（开发时反复用）
# 用法：pwsh -File tools/deploy.ps1
param(
    [string]$GameDir = "C:\Program Files (x86)\Steam\steamapps\common\MonsterHunterWilds"
)

$src = Join-Path $PSScriptRoot "..\reframework"
$dst = Join-Path $GameDir "reframework"

if (-not (Test-Path (Join-Path $GameDir "MonsterHunterWilds.exe"))) {
    Write-Error "游戏目录不对：$GameDir"
    exit 1
}
if (-not (Test-Path (Join-Path $GameDir "dinput8.dll"))) {
    Write-Warning "游戏目录里没有 dinput8.dll，REFramework 还没装。"
}

New-Item -ItemType Directory -Force -Path (Join-Path $dst "autorun") | Out-Null
Copy-Item (Join-Path $src "autorun\guard_red.lua") (Join-Path $dst "autorun\guard_red.lua") -Force
Write-Host "已同步 guard_red.lua -> $dst\autorun"
Write-Host "进游戏后 ScriptRunner -> Reset Scripts 生效。"
