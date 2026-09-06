$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$rulesPath = Join-Path $projectRoot 'src\data\CardBattleRules.lua'
$runtimePath = Join-Path $projectRoot 'src\data\LiveCardBattle.lua'
$mockPath = Join-Path $PSScriptRoot 'mock_card_battle_runtime.lua'
$liveMockPath = Join-Path $PSScriptRoot 'mock_live_card_battle_runtime.lua'

npx --yes --package luaparse luaparse --quiet --file $rulesPath --file $runtimePath
if ($LASTEXITCODE -ne 0) {
    throw 'Lua syntax check failed.'
}

$runtimeOutput = (& npx --yes --package fengari-node-cli fengari $mockPath $rulesPath 2>&1 | Out-String)
Write-Host $runtimeOutput
if (($LASTEXITCODE -ne 0) -or ($runtimeOutput -match 'stack traceback:') -or ($runtimeOutput -notmatch 'PASS: live card battle rules mock runtime')) {
    throw 'Lua mock-runtime test failed.'
}

$liveRuntimeOutput = (& npx --yes --package fengari-node-cli fengari $liveMockPath $rulesPath $runtimePath 2>&1 | Out-String)
Write-Host $liveRuntimeOutput
if (($LASTEXITCODE -ne 0) -or ($liveRuntimeOutput -match 'stack traceback:') -or ($liveRuntimeOutput -notmatch 'PASS: live card battle game runtime mock')) {
    throw 'Lua game-runtime mock test failed.'
}

Write-Host 'PASS: all live card battle automated checks'
