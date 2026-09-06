$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$source = Join-Path $projectRoot 'src\data\AllMonsterCaptureProbe.lua'
$mock = Join-Path $PSScriptRoot 'mock_all_monster_capture_probe.lua'

npx --yes --package luaparse luaparse --quiet --file $source
$output = npx --yes --package fengari-node-cli fengari $mock $source 2>&1
if ($LASTEXITCODE -ne 0 -or $output -match 'stack traceback:' -or $output -notmatch 'PASS: all-monster capture probe mock runtime') {
    throw "All-monster capture probe mock failed:`n$output"
}

Write-Host $output
Write-Host 'PASS: all all-monster capture probe automated checks'
