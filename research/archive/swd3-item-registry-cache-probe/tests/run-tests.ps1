$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$source = Join-Path $projectRoot 'src\data\ItemRegistryCacheProbe.lua'
$mock = Join-Path $PSScriptRoot 'mock_item_registry_cache_probe.lua'

npx --yes --package luaparse luaparse --quiet --file $source
$output = npx --yes --package fengari-node-cli fengari $mock $source 2>&1
if ($LASTEXITCODE -ne 0 -or $output -match 'stack traceback:' -or $output -notmatch 'PASS: item registry cache probe mock runtime') {
    throw "Item registry cache probe mock failed:`n$output"
}
Write-Host $output
Write-Host 'PASS: all item registry cache probe automated checks'
