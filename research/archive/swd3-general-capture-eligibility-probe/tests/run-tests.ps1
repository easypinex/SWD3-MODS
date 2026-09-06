$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$source = Join-Path $projectRoot 'src\data\GeneralCaptureEligibilityProbe.lua'
$mock = Join-Path $PSScriptRoot 'mock_general_capture_eligibility_probe.lua'
npx --yes --package luaparse luaparse --quiet --file $source
$output = npx --yes --package fengari-node-cli fengari $mock $source 2>&1
if ($LASTEXITCODE -ne 0 -or $output -match 'stack traceback:' -or $output -notmatch 'PASS: general capture eligibility probe mock runtime') { throw "General capture eligibility probe mock failed:`n$output" }
Write-Host $output
Write-Host 'PASS: all general capture eligibility probe automated checks'
