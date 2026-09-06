$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$source = Join-Path $projectRoot 'src\data\ManualCaptureBridgeProbe.lua'
$mock = Join-Path $PSScriptRoot 'mock_manual_capture_bridge_probe.lua'
npx --yes --package luaparse luaparse --quiet --file $source
if ($LASTEXITCODE -ne 0) { throw 'Lua syntax parse failed' }
$result = & npx --yes --package fengari-node-cli fengari $mock $source 2>&1
if ($LASTEXITCODE -ne 0 -or $result -match 'stack traceback:' -or $result -notmatch 'PASS: manual capture bridge probe mock runtime') {
    throw "Mock runtime failed:`n$result"
}
$result
