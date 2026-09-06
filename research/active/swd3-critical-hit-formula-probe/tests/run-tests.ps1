$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$source = Join-Path $projectRoot 'src\data\CriticalHitFormulaProbe.lua'
$mock = Join-Path $PSScriptRoot 'mock_critical_hit_formula_probe.lua'

npx --yes --package luaparse luaparse --quiet --file $source
$result = & npx --yes --package fengari-node-cli fengari $mock $source 2>&1
$result | ForEach-Object { Write-Output $_ }
if ($LASTEXITCODE -ne 0 -or -not ($result -match 'PASS: critical-hit formula probe mock runtime')) {
    throw 'Critical-hit formula probe mock failed.'
}
