$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$source = Join-Path $projectRoot 'src\data\HighLevelCaptureRateProbe.lua'
$mock = Join-Path $PSScriptRoot 'mock_high_level_capture_rate_probe.lua'
npx --yes --package luaparse luaparse --quiet --file $source
$output = npx --yes --package fengari-node-cli fengari $mock $source 2>&1
if ($LASTEXITCODE -ne 0 -or $output -match 'stack traceback:' -or $output -notmatch 'PASS: high-level capture-rate probe mock runtime') { throw "High-level capture-rate probe mock failed:`n$output" }
Write-Host $output
