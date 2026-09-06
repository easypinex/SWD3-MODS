$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
& (Join-Path $projectRoot 'tools\Build-StaticCardCatalogue.ps1')
$catalogue = Join-Path $projectRoot 'src\data\AllMonsterStaticCatalogue.lua'
$source = Join-Path $projectRoot 'src\data\AllMonsterStaticCapture.lua'
$runtime = Join-Path $projectRoot 'src\data\AllMonsterCaptureRuntime.lua'
$mock = Join-Path $PSScriptRoot 'mock_catalogue_runtime.lua'
$runtimeMock = Join-Path $PSScriptRoot 'mock_automatic_capture_runtime.lua'
$guardianSpecs = Join-Path $projectRoot 'catalogue\static-card-guardian-specs.csv'
if (-not (Test-Path -LiteralPath $guardianSpecs)) { throw 'Static guardian specification table was not generated.' }
$guardianRows = @(Import-Csv -LiteralPath $guardianSpecs)
if ($guardianRows.Count -ne 97) { throw "Expected 97 static guardian specification rows, got $($guardianRows.Count)." }
foreach ($field in @('card_id', 'card_name', 'guardian_power_tier', 'guardian_power_label', 'add_hp', 'add_mp', 'add_sp', 'add_str', 'add_stamina', 'add_wis', 'add_spd', 'add_atk', 'add_def', 'guardian_theme', 'guardian_archetype', 'guardian_signature', 'guardian_signature_note', 'specialization_mode', 'separation_adjustment_hp', 'source_focus', 'design_note')) {
    if ($guardianRows | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.($field)) }) { throw "Static guardian specification table has a blank $field value." }
}
if (@($guardianRows.card_id | Sort-Object -Unique).Count -ne 97) { throw 'Static guardian specification card IDs are not unique.' }
$guardianVectors = $guardianRows | ForEach-Object { "$($_.add_hp)|$($_.add_mp)|$($_.add_sp)|$($_.add_str)|$($_.add_stamina)|$($_.add_wis)|$($_.add_spd)|$($_.add_atk)|$($_.add_def)" }
if (@($guardianVectors | Sort-Object -Unique).Count -ne 97) { throw 'Every static guardian must have a unique nine-stat bonus vector.' }
if (@($guardianRows.guardian_theme | Sort-Object -Unique).Count -ne 97) { throw 'Every static guardian must have a distinct named guardian identity.' }
$semanticCombinations = $guardianRows | ForEach-Object { "$($_.guardian_archetype)|$($_.guardian_signature)|$($_.source_focus)" }
if (@($semanticCombinations | Sort-Object -Unique).Count -ne 97) { throw 'Every static guardian must have a distinct archetype/signature/focus combination.' }
$expectedManualSourceIds = @(2,3,4,6,7,10,12,13,16,32,33,38,39,40,48,51,52,53,61,62,63,64,65,67,68,69,70,71,72,73,76,102,103,105,106,108,109,110,111,112,113,114,115,116,117,120,123,176,180,380,381,382,384,385,386,388,389,396,397,398,433,2202)
$manualRows = @($guardianRows | Where-Object { $_.specialization_mode -eq 'manual' })
if ($manualRows.Count -ne 62) { throw "Expected 62 manual specializations, got $($manualRows.Count)." }
if (@($guardianRows | Where-Object { $_.specialization_mode -notin @('manual', 'generated') }).Count -ne 0) { throw 'Guardian specialization mode must be manual or generated.' }
$actualManualSourceIds = @($manualRows.source_enemy_id | ForEach-Object { [int]$_ } | Sort-Object -Unique)
if (Compare-Object -ReferenceObject $expectedManualSourceIds -DifferenceObject $actualManualSourceIds) { throw 'Manual specialization coverage does not exactly match the 62 originally repeated cards.' }
for ($left = 0; $left -lt $guardianRows.Count; $left++) {
    for ($right = $left + 1; $right -lt $guardianRows.Count; $right++) {
        $distance = 0
        foreach ($field in @('add_hp', 'add_mp', 'add_sp', 'add_str', 'add_stamina', 'add_wis', 'add_spd', 'add_atk', 'add_def')) {
            $distance += [math]::Abs(([int]$guardianRows[$left].$field) - ([int]$guardianRows[$right].$field))
        }
        if ($distance -lt 12) { throw "Static guardians $($guardianRows[$left].card_id) and $($guardianRows[$right].card_id) are too similar (distance=$distance)." }
    }
}
$powerOrder = @{ common = 1; veteran = 2; elite = 3; boss = 4; sovereign = 5 }
$expectedGuardianCosts = @{ common = 10; veteran = 30; elite = 90; boss = 160; sovereign = 280 }
if ($guardianRows | Where-Object { -not $powerOrder.ContainsKey($_.guardian_power_tier) }) { throw 'Static guardian specification has an unknown guardian power tier.' }
foreach ($guardian in $guardianRows) {
    $expectedCost = $expectedGuardianCosts[$guardian.guardian_power_tier]
    if ([int]$guardian.guardian_sp_cost -ne $expectedCost) { throw "Guardian SP cost does not match power tier for source $($guardian.source_enemy_id)." }
}
$scoreByTier = @{}
foreach ($tier in $powerOrder.Keys) {
    $scores = @($guardianRows | Where-Object { $_.guardian_power_tier -eq $tier } | ForEach-Object {
        ([int]$_.add_hp + [int]$_.add_mp + [int]$_.add_sp + [int]$_.add_str + [int]$_.add_stamina + [int]$_.add_wis + [int]$_.add_spd + [int]$_.add_atk + [int]$_.add_def)
    })
    if ($scores.Count -eq 0) { throw "Guardian power tier $tier has no cards." }
    $scoreByTier[$tier] = @{ min = ($scores | Measure-Object -Minimum).Minimum; max = ($scores | Measure-Object -Maximum).Maximum }
}
foreach ($pair in @(@('common', 'veteran'), @('veteran', 'elite'), @('elite', 'boss'), @('boss', 'sovereign'))) {
    if ($scoreByTier[$pair[0]].max -ge $scoreByTier[$pair[1]].min) { throw "Guardian power tiers overlap: $($pair[0]) and $($pair[1])." }
}
foreach ($bossId in @(28, 46, 59, 74, 75, 378)) {
    $boss = $guardianRows | Where-Object { [int]$_.source_enemy_id -eq $bossId }
    if ($boss.guardian_power_tier -ne 'sovereign') { throw "Expected source $bossId to be a sovereign guardian." }
}
npx --yes --package luaparse luaparse --quiet --file $catalogue --file $source --file $runtime
$output = npx --yes --package fengari-node-cli fengari $mock $catalogue $source 2>&1
if ($LASTEXITCODE -ne 0 -or $output -match 'stack traceback:' -or $output -notmatch 'PASS: all-monster static catalogue mock runtime') { throw "All-monster static catalogue mock failed:`n$output" }
$runtimeOutput = npx --yes --package fengari-node-cli fengari $runtimeMock $catalogue $source $runtime 2>&1
if ($LASTEXITCODE -ne 0 -or $runtimeOutput -match 'stack traceback:' -or $runtimeOutput -notmatch 'PASS: automatic capture runtime mock') { throw "Automatic capture runtime mock failed:`n$runtimeOutput" }
Write-Host $output
Write-Host $runtimeOutput
Write-Host 'PASS: all all-monster static catalogue automated checks'
