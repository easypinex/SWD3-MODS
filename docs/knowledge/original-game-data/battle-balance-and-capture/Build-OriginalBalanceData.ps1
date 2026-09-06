param(
    [string]$SourceRoot,
    [string]$OutputRoot
)

$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $PSCommandPath
$workspaceRoot = (Resolve-Path (Join-Path $scriptRoot '..\..\..\..')).Path
if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
    $SourceRoot = Join-Path $workspaceRoot '.work\extracted\script-index-inspect\out_data'
}
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $scriptRoot 'generated'
}
$extractor = Join-Path $scriptRoot 'Extract-OriginalBalanceData.lua'
$itemStrings = Join-Path $SourceRoot 'ItemString.txt'

if (-not (Test-Path -LiteralPath $extractor)) { throw "Missing exporter: $extractor" }
if (-not (Test-Path -LiteralPath $itemStrings)) { throw "Missing original StringDB text: $itemStrings" }

$stringDb = @{}
foreach ($line in Get-Content -LiteralPath $itemStrings -Encoding utf8) {
    if ($line -match '^(\S+)\s+(.+)$') {
        $stringDb[$matches[1]] = $matches[2]
    }
}

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

$stream = & npx --yes --package fengari-node-cli fengari $extractor $SourceRoot $OutputRoot 2>&1
if ($LASTEXITCODE -ne 0) {
    throw ($stream -join [Environment]::NewLine)
}

$csvByFile = @{}
$currentFile = $null
foreach ($entry in $stream) {
    $line = [string]$entry
    if ($line.StartsWith('@@BEGIN_FILE@@')) {
        $currentFile = $line.Substring('@@BEGIN_FILE@@'.Length)
        if ($currentFile -notmatch '^[a-z0-9-]+\.csv$') {
            throw "Unsafe exporter output name: $currentFile"
        }
        $csvByFile[$currentFile] = [System.Collections.Generic.List[string]]::new()
        continue
    }
    if ($line -like 'PASS:*') { continue }
    if ($null -eq $currentFile) {
        throw "Unexpected exporter output before a file marker: $line"
    }
    $csvByFile[$currentFile].Add($line)
}

if ($csvByFile.Count -eq 0) { throw 'Exporter produced no CSV sections.' }

function Resolve-StringDbText([object]$Value) {
    if ($null -eq $Value) { return '' }
    $raw = [string]$Value
    if ($raw -eq '') { return '' }
    $parts = $raw -split '\|'
    $resolved = foreach ($part in $parts) {
        if ($stringDb.ContainsKey($part)) { $stringDb[$part] } else { $part }
    }
    return ($resolved -join '|')
}

$displayColumns = @('name', 'info_text', 'help_text', 'character_name', 'skill_name', 'learned_skill_names')
foreach ($fileName in ($csvByFile.Keys | Sort-Object)) {
    $lines = $csvByFile[$fileName]
    if ($lines.Count -lt 1) { throw "Exporter produced no header for $fileName" }
    $records = @($lines | ConvertFrom-Csv)
    foreach ($record in $records) {
        foreach ($column in $displayColumns) {
            $property = $record.PSObject.Properties[$column]
            if ($null -ne $property) {
                $property.Value = Resolve-StringDbText $property.Value
            }
        }
    }
    $target = Join-Path $OutputRoot $fileName
    $records | ConvertTo-Csv -NoTypeInformation | Set-Content -LiteralPath $target -Encoding utf8
}

function Split-IdList([object]$Value) {
    if ($null -eq $Value -or [string]$Value -eq '') { return @() }
    return @(([string]$Value -split '\|') | Where-Object { $_ -ne '' -and $_ -ne '0' })
}

function Get-At([object[]]$Values, [int]$Index) {
    if ($Index -ge 0 -and $Index -lt $Values.Count) { return $Values[$Index] }
    return ''
}

function As-Int([object]$Value) {
    $parsed = 0
    [void][int]::TryParse([string]$Value, [ref]$parsed)
    return $parsed
}

# The following two files apply the exact eligibility test currently used by
# CardBattleRules.lua: isBattleChar + positive ACT + positive Level.  The
# exported combatants table contains only isBattleChar rows, so no further
# category or possession rule is added here.
$effectsById = @{}
foreach ($effect in Import-Csv (Join-Path $OutputRoot 'attack-effects.csv')) {
    $effectsById[[string]$effect.effect_id] = $effect
}
$skillsById = @{}
foreach ($skill in Import-Csv (Join-Path $OutputRoot 'skills.csv')) {
    $skillsById[[string]$skill.item_id] = $skill
}
$challengeable = @(
    Import-Csv (Join-Path $OutputRoot 'combatants.csv') |
        Where-Object { (As-Int $_.act) -gt 0 -and (As-Int $_.level) -gt 0 } |
        ForEach-Object {
            $paths = [System.Collections.Generic.List[string]]::new()
            if ($_.not_in_book -ne 'Y') { $paths.Add('神魔異事錄') }
            if ($_.story_or_special_flag -eq 'Y' -or $_.not_in_book -eq 'Y') { $paths.Add('特殊／首領') }
            [pscustomobject]@{
                item_id = $_.item_id
                name = $_.name
                current_menu_sources = ($paths -join '|')
                level = $_.level
                hp = $_.hp
                atk = $_.atk
                def = $_.def
                spd = $_.spd
                wis = $_.wis
                dodge_rate = $_.dodge_rate
                basic_attack_effect_id = $_.basic_attack_effect_id
                skill_ids = $_.skill_ids
                skill_counts = $_.skill_counts
                skill_rate = $_.skill_rate
                special_effect_ids = $_.special_effect_ids
                special_effect_counts = $_.special_effect_counts
                special_effect_rate = $_.special_effect_rate
                critical_skill_ids = $_.critical_skill_ids
                critical_skill_counts = $_.critical_skill_counts
                existing_living_card = $_.existing_living_card
                story_or_special_flag = $_.story_or_special_flag
                not_in_book = $_.not_in_book
                discard = $_.discard
                raw_data_caution = if ($_.discard -eq 'Y') { '原版標示 discard；目前選單規則未排除，不能當成正常可遇敵人。' } else { '' }
            }
        } |
        Sort-Object @{ Expression = { As-Int $_.hp }; Descending = $true }, @{ Expression = { As-Int $_.atk }; Descending = $true }, @{ Expression = { As-Int $_.def }; Descending = $true }
)
$challengeable | ConvertTo-Csv -NoTypeInformation | Set-Content -LiteralPath (Join-Path $OutputRoot 'current-challengeable-enemies.csv') -Encoding utf8
$challengeable | Select-Object -First 30 | ConvertTo-Csv -NoTypeInformation | Set-Content -LiteralPath (Join-Path $OutputRoot 'top-challengeable-enemies-by-hp.csv') -Encoding utf8

$enemyActions = [System.Collections.Generic.List[object]]::new()
function Add-EnemyAction {
    param(
        [object]$Enemy,
        [string]$ActionType,
        [string]$SourceId,
        [string]$ActionName,
        [string]$EffectId,
        [string]$InitialCount,
        [string]$Rate
    )
    $effect = $effectsById[$EffectId]
    $enemyActions.Add([pscustomobject]@{
        enemy_id = $Enemy.item_id
        enemy_name = $Enemy.name
        action_type = $ActionType
        source_id = $SourceId
        action_name = $ActionName
        attack_effect_id = $EffectId
        attack_point = if ($null -ne $effect) { $effect.attack_point } else { '' }
        attribute_id = if ($null -ne $effect) { $effect.attribute_id } else { '' }
        wide_range = if ($null -ne $effect) { $effect.wide_range } else { '' }
        affixation_effect = if ($null -ne $effect) { $effect.affixation_effect } else { '' }
        continuous_turns = if ($null -ne $effect) { $effect.continuous_turns } else { '' }
        add_buff = if ($null -ne $effect) { $effect.add_buff } else { '' }
        initial_usage_count = $InitialCount
        ai_rate = $Rate
        cooldown = '未定義；原版 AI 使用權重與剩餘使用次數，非每回合 CD。'
    })
}

foreach ($enemy in $challengeable) {
    if ([string]$enemy.basic_attack_effect_id -ne '') {
        Add-EnemyAction -Enemy $enemy -ActionType '普通攻擊' -SourceId '' -ActionName '基本攻擊效果' -EffectId ([string]$enemy.basic_attack_effect_id) -InitialCount '' -Rate '動態：連續普通攻擊越多，權重越低，最低 2。'
    }
    $skillIds = Split-IdList $enemy.skill_ids
    $skillCounts = Split-IdList $enemy.skill_counts
    for ($index = 0; $index -lt $skillIds.Count; $index++) {
        $skillId = [string]$skillIds[$index]
        $skill = $skillsById[$skillId]
        $actionName = if ($null -ne $skill) { [string]$skill.name } else { "技能 $skillId" }
        $effectId = if ($null -ne $skill) { [string]$skill.attack_effect_id } else { '' }
        Add-EnemyAction -Enemy $enemy -ActionType '技能' -SourceId $skillId -ActionName $actionName -EffectId $effectId -InitialCount ([string](Get-At $skillCounts $index)) -Rate ([string]$enemy.skill_rate)
    }
    $specialIds = Split-IdList $enemy.special_effect_ids
    $specialCounts = Split-IdList $enemy.special_effect_counts
    for ($index = 0; $index -lt $specialIds.Count; $index++) {
        $effectId = [string]$specialIds[$index]
        Add-EnemyAction -Enemy $enemy -ActionType '特殊攻擊' -SourceId $effectId -ActionName "特殊攻擊效果 $effectId" -EffectId $effectId -InitialCount ([string](Get-At $specialCounts $index)) -Rate ([string]$enemy.special_effect_rate)
    }
    $cureIds = Split-IdList $enemy.critical_skill_ids
    $cureCounts = Split-IdList $enemy.critical_skill_counts
    for ($index = 0; $index -lt $cureIds.Count; $index++) {
        $skillId = [string]$cureIds[$index]
        $skill = $skillsById[$skillId]
        $actionName = if ($null -ne $skill) { [string]$skill.name } else { "技能 $skillId" }
        $effectId = if ($null -ne $skill) { [string]$skill.attack_effect_id } else { '' }
        Add-EnemyAction -Enemy $enemy -ActionType '治療／危急技能' -SourceId $skillId -ActionName $actionName -EffectId $effectId -InitialCount ([string](Get-At $cureCounts $index)) -Rate '依全隊最低 HP 百分比增加權重。'
    }
}
$enemyActions | ConvertTo-Csv -NoTypeInformation | Set-Content -LiteralPath (Join-Path $OutputRoot 'current-challengeable-enemy-actions.csv') -Encoding utf8

Write-Output "PASS: generated $($csvByFile.Count) original-data CSV files and 3 current-rule analysis CSV files in $OutputRoot"
