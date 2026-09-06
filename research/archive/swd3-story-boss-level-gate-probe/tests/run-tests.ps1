$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$source = Join-Path $projectRoot 'src\data\StoryBossLevelGateProbe.lua'
$mock = Join-Path $PSScriptRoot 'mock_story_boss_level_gate_probe.lua'
npx --yes --package luaparse luaparse --quiet --file $source
$output = npx --yes --package fengari-node-cli fengari $mock $source 2>&1
if ($LASTEXITCODE -ne 0 -or $output -match 'stack traceback:' -or $output -notmatch 'PASS: story boss level gate probe mock runtime') { throw "Story boss level-gate probe mock failed:`n$output" }
Write-Host $output
Write-Host 'PASS: all story boss level-gate probe automated checks'
