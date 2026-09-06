$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$source = Join-Path $projectRoot 'src\data\FormalCaptureValidationProbe.lua'
$mock = Join-Path $PSScriptRoot 'mock_formal_capture_validation_probe.lua'
npx --yes --package luaparse luaparse --quiet --file $source
$output = npx --yes --package fengari-node-cli fengari $mock $source 2>&1
if ($LASTEXITCODE -ne 0 -or $output -match 'stack traceback:' -or $output -notmatch 'PASS: formal capture validation probe mock runtime') { throw "Formal capture validation probe mock failed:`n$output" }
Write-Host $output
Write-Host 'PASS: formal capture validation probe automated checks'
