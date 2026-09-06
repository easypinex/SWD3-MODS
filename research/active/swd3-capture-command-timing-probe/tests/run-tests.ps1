$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$source = Join-Path $projectRoot 'src\data\CaptureCommandTimingProbe.lua'
$mock = Join-Path $PSScriptRoot 'mock_capture_command_timing_probe.lua'

npx --yes --package luaparse luaparse --quiet --file $source
$result = & npx --yes --package fengari-node-cli fengari $mock $source 2>&1
$result | ForEach-Object { Write-Output $_ }
if ($LASTEXITCODE -ne 0 -or -not ($result -match 'PASS: capture command timing probe mock runtime')) {
    throw 'Capture command timing probe mock failed.'
}
