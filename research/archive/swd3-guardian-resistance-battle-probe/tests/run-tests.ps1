$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$source = Join-Path $projectRoot 'src\data\GuardianResistanceBattleProbe.lua'
$mock = Join-Path $PSScriptRoot 'mock_guardian_resistance_battle_probe.lua'
npx --yes --package luaparse luaparse --quiet --file $source
$output = npx --yes --package fengari-node-cli fengari $mock $source 2>&1
if ($LASTEXITCODE -ne 0 -or $output -match 'stack traceback:' -or $output -notmatch 'PASS: guardian resistance battle probe mock') { throw "Guardian resistance battle probe mock failed:`n$output" }
Write-Host $output
