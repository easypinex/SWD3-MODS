$ErrorActionPreference='Stop'
$caiProject=Split-Path -Parent $PSScriptRoot
foreach ($case in @('dialogue','fair_play')) {
    $result=(& npx --yes --package fengari-node-cli fengari "$PSScriptRoot/$case.lua" $caiProject "$caiProject/../.work/extracted/script-index-inspect/out_data" 2>&1 | Out-String)
    Write-Output $result
    if ($LASTEXITCODE -ne 0 -or $result -match 'stack traceback:' -or $result -notmatch 'PASS:') { throw "$case failed" }
}
$refundOutput=(& npx --yes --package fengari-node-cli fengari "$PSScriptRoot/inventory_refund.lua" $caiProject "$caiProject/../.work/extracted/script-index-inspect/out_data" "$caiProject/../swd3-live-card-battle-mod" 2>&1 | Out-String)
Write-Output $refundOutput
if ($LASTEXITCODE -ne 0 -or $refundOutput -match 'stack traceback:' -or $refundOutput -notmatch 'PASS: inventory refunds') { throw 'Inventory refund integration failed' }
$rewardResult=(& npx --yes --package fengari-node-cli fengari "$PSScriptRoot/reward.lua" $caiProject "$caiProject/../.work/extracted/script-index-inspect/out_data" 2>&1 | Out-String)
Write-Output $rewardResult
if ($LASTEXITCODE -ne 0 -or $rewardResult -match 'stack traceback:' -or $rewardResult -notmatch 'PASS: reward native definitions') { throw 'Reward integration mock failed' }
$strategyOutput=(& npx --yes --package fengari-node-cli fengari "$PSScriptRoot/strategy.lua" $caiProject 2>&1 | Out-String)
Write-Output $strategyOutput
if ($LASTEXITCODE -ne 0 -or $strategyOutput -match 'stack traceback:' -or $strategyOutput -notmatch 'PASS: phase boundaries') { throw 'Strategy mock failed' }
$skillOutput=(& npx --yes --package fengari-node-cli fengari "$PSScriptRoot/skill_balance.lua" $caiProject "$caiProject/../.work/extracted/script-index-inspect/out_data" 2>&1 | Out-String)
Write-Output $skillOutput
if ($LASTEXITCODE -ne 0 -or $skillOutput -match 'stack traceback:' -or $skillOutput -notmatch 'PASS: private skills') { throw 'Skill isolation mock failed' }
$caiPhysicalAct=@(Get-Content "$caiProject/../.work/extracted/script-index-inspect/out_data/act.ext" | Where-Object { $_ -match '^ACT 6145,0,' })
if ($caiPhysicalAct.Count -ne 1 -or $caiPhysicalAct[0] -notmatch ',RF,6325,' -or
    [regex]::Matches($caiPhysicalAct[0], ',AT,1,').Count -ne 1 -or
    [regex]::Matches($caiPhysicalAct[0], ',AT,').Count -ne 1 -or $caiPhysicalAct[0] -notmatch ',O2$') {
    throw 'Native physical FX sequence changed'
}
Write-Output 'PASS: native physical FX declaration has one impact event'
$caiNativeCure=@(Get-Content "$caiProject/../.work/extracted/script-index-inspect/out_data/act.ext" | Where-Object { $_ -match '^ACT 6079,0,' })
$caiCure=@(Get-Content "$caiProject/src/data/CaiDemonActions.ext" | Where-Object { $_ -match '^ACT 11005,0,' })
if ($caiNativeCure.Count -ne 1 -or $caiCure.Count -ne 1) { throw 'Cure declaration missing or duplicated' }
$caiExpectedCure=$caiNativeCure[0].Replace('ACT 6079,0,','ACT 11005,0,').Replace(',AM,PA,48,ED,',',AM,AT,16,PA,48,ED,')
if ($caiCure[0] -ne $caiExpectedCure -or [regex]::Matches($caiCure[0], ',AT,16,').Count -ne 2 -or
    [regex]::Matches($caiCure[0], ',AT,').Count -ne 2) { throw 'Cure must preserve native assets/timing with exactly two cure events' }
if ($caiNativeCure[0] -notmatch ',TN,60,RF,6040,' -or $caiCure[0] -notmatch ',O2$') { throw 'Native cure baseline changed' }
Write-Output 'PASS: one native-length cure animation, two distinct cure events, unchanged original FX'
$luaFiles=Get-ChildItem "$caiProject/src/data" -Filter '*.lua' | ForEach-Object { '--file'; $_.FullName }
& npx --yes --package luaparse luaparse --quiet @luaFiles
if ($LASTEXITCODE -ne 0) { throw 'Lua syntax failed' }
$caiOutput=(& npx --yes --package fengari-node-cli fengari "$PSScriptRoot/runtime.lua" $caiProject 2>&1 | Out-String)
Write-Output $caiOutput
if ($LASTEXITCODE -ne 0 -or $caiOutput -match 'stack traceback:' -or $caiOutput -notmatch 'PASS: Cai data ownership') { throw 'Runtime mock failed' }
$caiBossOutput=(& npx --yes --package fengari-node-cli fengari "$PSScriptRoot/boss_compatibility.lua" $caiProject 2>&1 | Out-String)
Write-Output $caiBossOutput
if ($LASTEXITCODE -ne 0 -or $caiBossOutput -match 'stack traceback:' -or $caiBossOutput -notmatch 'PASS: Cai Boss identity') { throw 'Boss compatibility mock failed' }
$caiValidation=(& npx --yes --package fengari-node-cli fengari "$PSScriptRoot/validation.lua" $caiProject 2>&1 | Out-String)
Write-Output $caiValidation
if ($LASTEXITCODE -ne 0 -or $caiValidation -match 'stack traceback:' -or $caiValidation -notmatch 'PASS: integrated F9 mixed Cai') { throw 'Validation mock failed' }
$caiStrings=@{}
foreach ($line in Get-Content "$caiProject/src/data/CaiDemonKing.txt" -Encoding UTF8) {
    if ($line -match '^(CDK_\w+)\s+') {
        if ($caiStrings.ContainsKey($Matches[1])) { throw "Duplicate StringDB key: $($Matches[1])" }
        $caiStrings[$Matches[1]]=$true
    }
}
foreach ($file in Get-ChildItem "$caiProject/src/data" -Filter '*.lua') {
    foreach ($match in [regex]::Matches((Get-Content $file.FullName -Raw), "'((?:CDK_)[A-Z_]+)'")) {
        $key=$match.Groups[1].Value
        if ($key -ne 'CDK_CAI_CHALLENGE' -and -not $caiStrings.ContainsKey($key)) { throw "Missing StringDB key: $key" }
    }
}
Write-Output 'PASS: Cai StringDB references and uniqueness'
$partyOutput=(& npx --yes --package fengari-node-cli fengari "$PSScriptRoot/party_state.lua" "$caiProject/src/data/CaiPartyState.lua" SWD3CaiDemonKing 2>&1 | Out-String)
Write-Output $partyOutput
if ($LASTEXITCODE -ne 0 -or $partyOutput -match 'stack traceback:' -or $partyOutput -notmatch 'PASS: party full entry') { throw 'Party state mock failed' }
