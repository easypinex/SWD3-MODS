$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$source = Join-Path $projectRoot 'src\data\StaticCaptureExchangeProbe.lua'
$mock = Join-Path $PSScriptRoot 'mock_static_capture_exchange_probe.lua'
npx --yes --package luaparse luaparse --quiet --file $source
$output = npx --yes --package fengari-node-cli fengari $mock $source 2>&1
if ($LASTEXITCODE -ne 0 -or $output -match 'stack traceback:' -or $output -notmatch 'PASS: static capture exchange probe mock runtime') { throw "Static capture exchange probe mock failed:`n$output" }
Write-Host $output
Write-Host 'PASS: all static capture exchange probe automated checks'
