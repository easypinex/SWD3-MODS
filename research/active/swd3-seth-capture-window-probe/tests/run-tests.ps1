$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$source = Join-Path $projectRoot 'src\data\SethCaptureWindowProbe.lua'
$mock = Join-Path $PSScriptRoot 'mock_seth_capture_window_probe.lua'
npx --yes --package luaparse luaparse --quiet --file $source
$output = npx --yes --package fengari-node-cli fengari $mock $source 2>&1
if ($LASTEXITCODE -ne 0 -or $output -match 'stack traceback:' -or $output -notmatch 'PASS: Seth capture input-window probe mock runtime') {
    throw "Seth capture-window probe mock failed:`n$output"
}
Write-Host $output
