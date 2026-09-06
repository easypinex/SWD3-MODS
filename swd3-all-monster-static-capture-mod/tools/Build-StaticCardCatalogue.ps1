[CmdletBinding()]
param(
    [string]$AuditCsv = (Join-Path $PSScriptRoot '..\..\docs\knowledge\original-game-data\battle-balance-and-capture\generated\capture-card-audit.csv'),
    [string]$GuardianCsv = (Join-Path $PSScriptRoot '..\..\docs\knowledge\original-game-data\battle-balance-and-capture\generated\guardian-cards.csv'),
    [string]$CombatantsCsv = (Join-Path $PSScriptRoot '..\..\docs\knowledge\original-game-data\battle-balance-and-capture\generated\combatants.csv'),
    [string]$OutputLua = (Join-Path $PSScriptRoot '..\src\data\AllMonsterStaticCatalogue.lua'),
    [string]$OutputStrings = (Join-Path $PSScriptRoot '..\src\data\AllMonsterStaticCapture.txt'),
    [string]$OutputCsv = (Join-Path $PSScriptRoot '..\catalogue\all-monster-static-cards.csv'),
    [string]$OutputGuardianSpecsCsv = (Join-Path $PSScriptRoot '..\catalogue\static-card-guardian-specs.csv'),
    [string]$SpecializationCsv = (Join-Path $PSScriptRoot '..\catalogue\guardian-specialization-overrides.csv')
)

$ErrorActionPreference = 'Stop'

function Get-Tier {
    param($row)
    if ($row.story_or_special_flag -eq 'Y' -or $row.not_in_book -eq 'Y') { return 'contract' }
    if ([int]$row.level -ge 50 -or [int]$row.hp -ge 5000) { return 'elite' }
    if ([int]$row.level -ge 35 -or [int]$row.hp -ge 1500) { return 'rare' }
    if ([int]$row.level -ge 20 -or [int]$row.hp -ge 400) { return 'uncommon' }
    return 'common'
}

$tierRules = @{
    common =   @{ label = '常見'; hp = 1.08; atk = 1.05; def = 1.05; cost = 10 }
    uncommon = @{ label = '少見'; hp = 1.10; atk = 1.07; def = 1.07; cost = 30 }
    rare =     @{ label = '稀有'; hp = 1.12; atk = 1.09; def = 1.09; cost = 150 }
    elite =    @{ label = '菁英'; hp = 1.15; atk = 1.12; def = 1.12; cost = 260 }
    contract = @{ label = '契約'; hp = 1.18; atk = 1.15; def = 1.15; cost = 200 }
}

foreach ($path in @($AuditCsv, $GuardianCsv, $CombatantsCsv)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Required source CSV is missing: $path" }
}
if (-not (Test-Path -LiteralPath $SpecializationCsv)) { throw "Required specialization override CSV is missing: $SpecializationCsv" }

$rows = @(Import-Csv -LiteralPath $AuditCsv | Where-Object { $_.battle_data_complete -eq 'Y' } | Sort-Object { [int]$_.item_id })
if ($rows.Count -ne 193) { throw "Expected 193 battle-complete records, got $($rows.Count)" }
$existingCount = @($rows | Where-Object { $_.existing_living_card -eq 'Y' }).Count
if ($existingCount -ne 96) { throw "Expected 96 existing living cards, got $existingCount" }

$specializationOverrides = @(Import-Csv -LiteralPath $SpecializationCsv)
if ($specializationOverrides.Count -ne 62) { throw "Expected 62 specialization overrides, got $($specializationOverrides.Count)" }
$specializationById = @{}
foreach ($override in $specializationOverrides) {
    $sourceId = [int]$override.source_enemy_id
    if ($sourceId -le 0 -or $specializationById.ContainsKey($sourceId)) { throw "Specialization override source IDs must be positive and unique: $sourceId" }
    foreach ($field in @('title', 'archetype', 'signature', 'focus', 'note', 'bias')) {
        if ([string]::IsNullOrWhiteSpace([string]$override.$field)) { throw "Specialization override $sourceId has a blank $field" }
    }
    if ($override.bias -notin @('life', 'magic', 'attack', 'guard', 'speed')) { throw "Specialization override $sourceId has an unknown bias: $($override.bias)" }
    $specializationById[$sourceId] = $override
}

$manualBiasProfiles = @{
    life   = @{ hp = 6; mp = 0; sp = 0; str = 0; stamina = 1; wis = 0; spd = 0; atk = 0; def = 1 }
    magic  = @{ hp = 0; mp = 5; sp = 0; str = 0; stamina = 0; wis = 2; spd = 0; atk = 0; def = 0 }
    attack = @{ hp = 0; mp = 0; sp = 0; str = 2; stamina = 0; wis = 0; spd = 0; atk = 3; def = 0 }
    guard  = @{ hp = 3; mp = 0; sp = 0; str = 0; stamina = 2; wis = 0; spd = 0; atk = 0; def = 3 }
    speed  = @{ hp = 0; mp = 0; sp = 5; str = 0; stamina = 0; wis = 0; spd = 2; atk = 0; def = 0 }
}

# 與同分級原生活物卡比較：成本採現有中位數約 90% 的可讀整數，
# 但契約級由劇情／圖鑑外資料主導，固定 200 SP，避免 30,000 HP 首領零成本化。
$referenceCosts = @{
    common = 11; uncommon = 33; rare = 168; elite = 290; contract = 135
}

# 收妖稀有度（$tier）和護駕強度是兩件事。前者保留原定義，供卡本體與 SP
# 成本使用；後者只依來源的實際戰鬥資料分級，避免劇情旗標令低面板角色虛高。
$guardianProfiles = @{
    common    = @{ label = '初階';     cost = 10;  hp = 20;  mp = 10;  sp = 10; stat = 1; speed = 1; atk = 1;  def = 1;  focus = 1 }
    veteran   = @{ label = '熟練';     cost = 30;  hp = 45;  mp = 20;  sp = 20; stat = 2; speed = 2; atk = 3;  def = 3;  focus = 2 }
    elite     = @{ label = '菁英';     cost = 90;  hp = 90;  mp = 38;  sp = 35; stat = 4; speed = 3; atk = 6;  def = 6;  focus = 3 }
    boss      = @{ label = '首領';     cost = 160; hp = 165; mp = 65;  sp = 55; stat = 6; speed = 4; atk = 11; def = 11; focus = 5 }
    sovereign = @{ label = '傳說首領'; cost = 280; hp = 250; mp = 100; sp = 85; stat = 9; speed = 6; atk = 17; def = 17; focus = 7 }
}

# 個性加護不取代原型或首領階級，而是讓同原型的不同敵方也有可感知的裝備差異。
# 以來源 ID 穩定選取，故重建後不會隨 CSV 排序改變。
$guardianSignatureProfiles = @(
    @{ label = '厚命印'; note = '以生命與耐力維持前線。'; hp = 14; mp = 0;  sp = 0;  str = 0; stamina = 2; wis = 0; spd = 0; atk = 0; def = 1 },
    @{ label = '靈泉印'; note = '以靈力、體力與智慧維持術法。'; hp = 0;  mp = 12; sp = 6;  str = 0; stamina = 0; wis = 3; spd = 0; atk = 0; def = 0 },
    @{ label = '破軍印'; note = '把加護集中於力量與正面攻勢。'; hp = 4;  mp = 0;  sp = 0;  str = 3; stamina = 0; wis = 0; spd = 0; atk = 5; def = 0 },
    @{ label = '鐵壁印'; note = '以耐力與防禦承受壓力。'; hp = 8;  mp = 0;  sp = 0;  str = 0; stamina = 3; wis = 0; spd = 0; atk = 0; def = 5 },
    @{ label = '疾影印'; note = '以體力與敏捷搶先行動。'; hp = 0;  mp = 0;  sp = 14; str = 0; stamina = 0; wis = 0; spd = 4; atk = 1; def = 0 },
    @{ label = '明悟印'; note = '以智慧與靈力提高術法續航。'; hp = 0;  mp = 14; sp = 2;  str = 0; stamina = 0; wis = 4; spd = 0; atk = 0; def = 0 },
    @{ label = '獵心印'; note = '將速度轉為力量與攻擊節奏。'; hp = 0;  mp = 0;  sp = 8;  str = 2; stamina = 0; wis = 0; spd = 2; atk = 3; def = 0 },
    @{ label = '壓陣印'; note = '以生命與力量維持穩定壓制。'; hp = 10; mp = 0;  sp = 0;  str = 2; stamina = 2; wis = 0; spd = 0; atk = 2; def = 0 },
    @{ label = '銳鋒印'; note = '以力量、敏捷與攻擊提升破陣能力。'; hp = 0;  mp = 4;  sp = 4;  str = 4; stamina = 0; wis = 0; spd = 1; atk = 4; def = 0 },
    @{ label = '磐石印'; note = '以生命、耐力與防禦構成持久防線。'; hp = 16; mp = 0;  sp = 0;  str = 0; stamina = 4; wis = 0; spd = 0; atk = 0; def = 2 },
    @{ label = '守脈印'; note = '以靈力與防禦維持長線守勢。'; hp = 0;  mp = 6;  sp = 6;  str = 0; stamina = 2; wis = 1; spd = 0; atk = 0; def = 4 },
    @{ label = '咒紋印'; note = '以靈力、體力與智慧形成術式循環。'; hp = 0;  mp = 10; sp = 8;  str = 0; stamina = 0; wis = 2; spd = 1; atk = 0; def = 0 },
    @{ label = '玄識印'; note = '以智慧與少量守勢穩定施術。'; hp = 4;  mp = 8;  sp = 4;  str = 0; stamina = 0; wis = 5; spd = 0; atk = 0; def = 1 },
    @{ label = '追風印'; note = '以速度、體力與靈力掌握先機。'; hp = 4;  mp = 4;  sp = 10; str = 0; stamina = 0; wis = 0; spd = 5; atk = 0; def = 0 },
    @{ label = '掠行印'; note = '以敏捷與攻擊維持遊擊節奏。'; hp = 0;  mp = 0;  sp = 12; str = 1; stamina = 1; wis = 0; spd = 3; atk = 2; def = 0 }
)

function Get-GuardianSignature {
    param($Record, [string]$SourceFocus)
    # 同一戰鬥傾向只從語意相符的四種加護中選擇；來源 ID 只用來在其中穩定分流。
    # 如此個性差異仍遵循攻勢、守勢、術法或迅捷，而不是隨機套用。
    $labels = switch ($SourceFocus) {
        '攻勢本能' { @('破軍印', '獵心印', '壓陣印', '銳鋒印') }
        '守勢本能' { @('厚命印', '鐵壁印', '磐石印', '守脈印') }
        '術法本能' { @('靈泉印', '明悟印', '咒紋印', '玄識印') }
        default { @('疾影印', '獵心印', '追風印', '掠行印') }
    }
    $label = $labels[([int]$Record.enemy_id + [int]$Record.static_ordinal) % $labels.Count]
    return @($guardianSignatureProfiles | Where-Object { $_.label -eq $label })[0]
}

function Get-ManualGuardianSignature {
    param($Override)
    $profile = $manualBiasProfiles[$Override.bias]
    if ($null -eq $profile) { throw "Manual specialization has an unknown bias: $($Override.bias)" }
    [pscustomobject]@{
        label=$Override.signature; note=$Override.note
        hp=$profile.hp; mp=$profile.mp; sp=$profile.sp; str=$profile.str; stamina=$profile.stamina
        wis=$profile.wis; spd=$profile.spd; atk=$profile.atk; def=$profile.def
    }
}

function Get-GuardianPowerTier {
    param($row)
    $level = To-Int $row.level
    $hp = To-Int $row.hp
    $atk = To-Int $row.atk
    $def = To-Int $row.def
    # 30,000 HP 的終局／最終敵人與高攻防等級者一律是傳說首領；
    # 其他劇情旗標不參與這個判定。
    if ($hp -ge 20000 -or ($level -ge 70 -and ($atk -ge 600 -or $def -ge 500))) { return 'sovereign' }
    if ($hp -ge 8000 -or ($level -ge 50 -and $atk -ge 450) -or ($level -ge 55 -and $def -ge 300)) { return 'boss' }
    if ($hp -ge 2000 -or $atk -ge 250 -or $def -ge 180 -or $level -ge 40) { return 'elite' }
    if ($hp -ge 400 -or $atk -ge 80 -or $def -ge 70 -or $level -ge 20) { return 'veteran' }
    return 'common'
}

function New-GuardianTheme {
    param([string]$Label, [string]$Note, [int]$HP = 0, [int]$MP = 0, [int]$SP = 0, [int]$STR = 0, [int]$Stamina = 0, [int]$WIS = 0, [int]$SPD = 0, [int]$ATK = 0, [int]$DEF = 0)
    [pscustomobject]@{ label=$Label; note=$Note; hp=$HP; mp=$MP; sp=$SP; str=$STR; stamina=$Stamina; wis=$WIS; spd=$SPD; atk=$ATK; def=$DEF }
}

function Get-GuardianTheme {
    param([string]$Name)
    if ($Name -match '蚩尤') { return New-GuardianTheme '兵主戰神' '兵主戰意，兼顧猛攻與軍陣韌性。' -HP 16 -STR 4 -Stamina 3 -ATK 6 -DEF 3 }
    if ($Name -match '牛魔王') { return New-GuardianTheme '平天巨力' '平天巨力，將高生命與正面壓制化作力量與耐力。' -HP 22 -STR 5 -Stamina 5 -ATK 5 -DEF 2 }
    if ($Name -match '大棕熊|熊|金剛|猿|猴') { return New-GuardianTheme '巨力鎮守' '巨力原型，以力量、耐力與正面壓制見長。' -HP 15 -STR 3 -Stamina 3 -ATK 3 }
    if ($Name -match '鬥戰聖佛') { return New-GuardianTheme '鬥戰神通' '神通百變，強調出手速度與攻勢。' -SP 12 -STR 4 -SPD 5 -ATK 6 }
    if ($Name -match '蜃|幻') { return New-GuardianTheme '蜃景幻術' '幻景惑敵，偏向靈力、智慧與迅捷。' -MP 12 -SP 6 -WIS 3 -SPD 2 }
    if ($Name -match '撒旦賽特') { return New-GuardianTheme '冥王咒鎧' '冥王咒鎧，以暗系術法與防線兼顧長戰。' -HP 10 -MP 22 -WIS 6 -Stamina 2 -DEF 4 }
    if ($Name -match '^撒旦$') { return New-GuardianTheme '魔王霸權' '魔王霸權，將極端攻防凝為壓制性的契靈加護。' -HP 16 -MP 14 -STR 4 -Stamina 4 -WIS 3 -ATK 5 -DEF 5 }
    if ($Name -match '蔡魔王') { return New-GuardianTheme '魔王蓄勢' '魔王蓄勢，以龐大生命轉化為續戰與術法儲備。' -HP 24 -MP 18 -SP 12 -Stamina 4 -WIS 4 -DEF 3 }
    if ($Name -match '魔神|恐懼|夜叉|鬼|屍|骷髏|死靈|地獄|藍魔') { return New-GuardianTheme '幽冥魔能' '幽冥原型，將加護傾向靈力與智慧。' -MP 15 -SP 5 -WIS 4 -DEF 1 }
    if ($Name -match '機關|妖機|木鐵') { return New-GuardianTheme '機巧鋼骨' '機關構造，側重耐力、防禦與穩定。' -HP 10 -Stamina 3 -DEF 4 -SPD 1 }
    if ($Name -match '慧彥|悟緣|和尚|教士|武僧|道士|院長') { return New-GuardianTheme '修行護持' '修行者的定力，著重智慧、靈力與守勢。' -MP 14 -WIS 4 -Stamina 1 -DEF 3 }
    if ($Name -match '影忍|羯忍|忍') { return New-GuardianTheme '潛影疾襲' '潛行突擊，優先敏捷、體力與攻擊。' -SP 10 -SPD 4 -ATK 3 -STR 1 }
    if ($Name -match '蛇|蠍|蜘蛛|蜈蚣|蟾蜍|蛙') { return New-GuardianTheme '伏毒奇襲' '伏擊型原型，將加護轉為迅捷與體力。' -SP 12 -SPD 3 -STR 1 -ATK 2 }
    if ($Name -match '鷹|蝙蝠|蛾|鳥') { return New-GuardianTheme '翔空獵影' '飛行原型，突出敏捷、智慧與靈力。' -MP 8 -WIS 2 -SPD 4 -ATK 1 }
    if ($Name -match '狼|虎|獅|豹|鱷|蜥|羊|妖貓') { return New-GuardianTheme '獵獸本能' '掠食原型，以力量、敏捷與攻擊作為核心。' -HP 6 -STR 2 -SPD 2 -ATK 3 }
    if ($Name -match '騎士|軍人|兵|步卒|水軍|大食') { return New-GuardianTheme '軍陣守勢' '軍陣原型，將加護投入耐力與防禦。' -HP 8 -Stamina 3 -DEF 4 -ATK 1 }
    if ($Name -match '財寶') { return New-GuardianTheme '聚寶靈藏' '財寶異靈，傾向靈力、體力與智慧。' -MP 12 -SP 12 -WIS 3 }
    if ($Name -match '冰') { return New-GuardianTheme '霜魄凝守' '冰霜原型，以智慧與防禦維持節奏。' -MP 10 -WIS 3 -DEF 3 }
    return New-GuardianTheme '異界契印' '依原型戰鬥資料凝成的契靈加護。' -HP 5 -MP 3 -SP 3 -STR 1 -Stamina 1 -WIS 1 -SPD 1 -ATK 1 -DEF 1
}

function To-Int {
    param($Value)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return 0 }
    return [int]$Value
}

function Round-Scaled {
    param([int]$Value, [double]$Multiplier)
    return [int][math]::Floor($Value * $Multiplier + 0.5)
}

$combatantsById = @{}
foreach ($combatant in @(Import-Csv -LiteralPath $CombatantsCsv)) {
    $combatantsById[(To-Int $combatant.item_id)] = $combatant
}

$nextStaticId = 10001
$records = foreach ($row in $rows) {
    $isExisting = $row.existing_living_card -eq 'Y'
    $tier = Get-Tier $row
    $rule = $tierRules[$tier]
    $guardianPowerTier = Get-GuardianPowerTier $row
    $guardianPowerRule = $guardianProfiles[$guardianPowerTier]
    if ($null -eq $guardianPowerRule) { throw "Guardian power profile is unavailable for source $($row.item_id): $guardianPowerTier" }
    $staticOrdinal = if ($isExisting) { 0 } else { $nextStaticId - 10000 }
    $cardId = if ($isExisting) { [int]$row.item_id } else { $id = $nextStaticId; $nextStaticId++; $id }
    [pscustomobject]@{
        enemy_id = [int]$row.item_id
        card_id = $cardId
        static_card_required = if ($isExisting) { 'N' } else { 'Y' }
        static_ordinal = $staticOrdinal
        name = [string]$row.name
        race_id = [int]$row.race_id
        level = [int]$row.level
        hp = [int]$row.hp
        atk = [int]$row.atk
        def = [int]$row.def
        story_or_special = $row.story_or_special_flag
        not_in_book = $row.not_in_book
        rarity_tier = $tier
        rarity_label = $rule.label
        guardian_power_tier = $guardianPowerTier
        hp_multiplier = $rule.hp
        atk_multiplier = $rule.atk
        def_multiplier = $rule.def
        guardian_sp_cost = $guardianPowerRule.cost
        native_tier_median_sp_cost = $referenceCosts[$tier]
        balance_note = "收妖稀有度為$($rule.label)，護駕戰力為$($guardianPowerRule.label)；本卡召喚成本 $($guardianPowerRule.cost) SP，並套用 HP/ATK/DEF 小幅強化。"
    }
}

if (@($records | Where-Object { $_.static_card_required -eq 'Y' }).Count -ne 97) { throw 'Expected 97 static-card records' }
if ((@($records.card_id | Sort-Object -Unique)).Count -ne $records.Count) { throw 'Card IDs are not unique' }

# 同名敵方在原始資料中確實存在；在護駕稱號加上來源 ID，讓表格與物品摘要仍可清楚辨識。
$staticNameCounts = @{}
foreach ($record in @($records | Where-Object { $_.static_card_required -eq 'Y' })) {
    if (-not $staticNameCounts.ContainsKey($record.name)) { $staticNameCounts[$record.name] = 0 }
    $staticNameCounts[$record.name]++
}

function Get-GuardianBonus {
    param($Record)
    $combatant = $combatantsById[$Record.enemy_id]
    if ($null -eq $combatant) { throw "Combatant data is unavailable for static card source $($Record.enemy_id)" }
    $rule = $guardianProfiles[$Record.guardian_power_tier]
    if ($null -eq $rule) { throw "Guardian power profile is unavailable for source $($Record.enemy_id): $($Record.guardian_power_tier)" }
    $override = $specializationById[$Record.enemy_id]
    $theme = if ($null -ne $override) { New-GuardianTheme $override.archetype $override.note } else { Get-GuardianTheme $Record.name }
    $hp, $mp, $sp = $rule.hp, $rule.mp, $rule.sp
    $str, $stamina, $wis = $rule.stat, $rule.stat, $rule.stat
    $spd, $atk, $def = $rule.speed, $rule.atk, $rule.def

    $sourceATK = To-Int $combatant.atk
    $sourceDEF = To-Int $combatant.def
    $sourceWIS = To-Int $combatant.wis
    $sourceHP = To-Int $combatant.hp
    $sourceSPD = To-Int $combatant.spd
    $sourceSpeedWeighted = (To-Int $combatant.spd) * 3
    if ($sourceATK -ge $sourceDEF -and $sourceATK -ge $sourceWIS -and $sourceATK -ge $sourceSpeedWeighted) {
        $atk += $rule.focus; $str += $rule.focus; $sourceFocus = '攻勢本能'
    } elseif ($sourceDEF -ge $sourceWIS -and $sourceDEF -ge $sourceSpeedWeighted) {
        $def += $rule.focus; $stamina += $rule.focus; $sourceFocus = '守勢本能'
    } elseif ($sourceWIS -ge $sourceSpeedWeighted) {
        $wis += $rule.focus; $mp += $rule.focus * 10; $sourceFocus = '術法本能'
    } else {
        $spd += $rule.focus; $sp += $rule.focus * 10; $sourceFocus = '迅捷本能'
    }
    if ($null -ne $override) {
        $sourceFocus = $override.focus
        $signature = Get-ManualGuardianSignature $override
    } else {
        $signature = Get-GuardianSignature $Record $sourceFocus
    }

    $hp += $theme.hp; $mp += $theme.mp; $sp += $theme.sp
    $str += $theme.str; $stamina += $theme.stamina; $wis += $theme.wis
    $spd += $theme.spd; $atk += $theme.atk; $def += $theme.def
    $hp += $signature.hp; $mp += $signature.mp; $sp += $signature.sp
    $str += $signature.str; $stamina += $signature.stamina; $wis += $signature.wis
    $spd += $signature.spd; $atk += $signature.atk; $def += $signature.def

    # 將可見面板的高壓來源轉成小而可追溯的個體差異：
    # HP 偏向續戰，ATK 偏向壓制，DEF 偏向鎮守，WIS/SPD 各自轉成術法／迅捷。
    # 上限刻意很低，真正的強度差仍主要來自首領階級，避免把 30,000 HP 直接換成失衡數值。
    $hpBand = [math]::Min(3, [int][math]::Floor($sourceHP / 10000))
    $atkBand = [math]::Min(3, [int][math]::Floor($sourceATK / 300))
    $defBand = [math]::Min(3, [int][math]::Floor($sourceDEF / 250))
    $wisBand = [math]::Min(3, [int][math]::Floor($sourceWIS / 100))
    $spdBand = [math]::Min(3, [int][math]::Floor($sourceSPD / 60))
    $hp += $hpBand * 10; $stamina += $hpBand
    $str += $atkBand; $atk += $atkBand * 2
    $stamina += $defBand; $def += $defBand * 2
    $mp += $wisBand * 8; $wis += $wisBand
    $sp += $spdBand * 8; $spd += $spdBand

    # 三段式契印座標（5 × 5 × 4 = 100 組）使 97 張卡有可辨識的加護分布。
    # 每一段都是兩項能力的固定總量轉換，因此不會提高任一階級的總強度：
    # 生命／靈力、體力／防禦、力量／智慧各自呈現不同的契印走向。
    $ordinal = [int]$Record.static_ordinal - 1
    $lifeRune = $ordinal % 5
    $guardRune = [int][math]::Floor($ordinal / 5) % 5
    $mindRune = [int][math]::Floor($ordinal / 25) % 4
    $hp += $lifeRune * 6; $mp += (4 - $lifeRune) * 6
    $sp += $guardRune * 6; $def += (4 - $guardRune) * 6
    $str += $mindRune * 6; $wis += (3 - $mindRune) * 6

    $sourceLabel = $Record.name
    if ($staticNameCounts[$Record.name] -gt 1) { $sourceLabel = "$sourceLabel（$($Record.enemy_id)）" }
    $themeLabel = if ($null -ne $override) { $override.title } else { "$($theme.label)・$sourceLabel" }
    $specializationMode = if ($null -ne $override) { 'manual' } else { 'generated' }
    [pscustomobject]@{
        hp=$hp; mp=$mp; sp=$sp; str=$str; stamina=$stamina; wis=$wis; spd=$spd; atk=$atk; def=$def
        theme_label=$themeLabel; archetype_label=$theme.label; theme_note=$theme.note; signature_label=$signature.label; signature_note=$signature.note; source_focus=$sourceFocus; power_label=$rule.label; specialization_mode=$specializationMode
    }
}

$guardianBonuses = @{}
$seenVectors = @{}
$acceptedGuardianBonuses = @()
$minimumGuardianDistance = 12
function Get-GuardianDistance {
    param($Left, $Right)
    $distance = 0
    foreach ($field in @('hp', 'mp', 'sp', 'str', 'stamina', 'wis', 'spd', 'atk', 'def')) {
        $distance += [math]::Abs(([int]$Left.$field) - ([int]$Right.$field))
    }
    return $distance
}
foreach ($record in @($records | Where-Object { $_.static_card_required -eq 'Y' } | Sort-Object card_id)) {
    $bonus = Get-GuardianBonus $record
    $separationAdjustment = 0
    while ($true) {
        $nearest = $null
        $nearestDistance = [int]::MaxValue
        foreach ($accepted in $acceptedGuardianBonuses) {
            $distance = Get-GuardianDistance $bonus $accepted.bonus
            if ($distance -lt $nearestDistance) { $nearest = $accepted; $nearestDistance = $distance }
        }
        if ($null -eq $nearest -or $nearestDistance -ge $minimumGuardianDistance) { break }
        # 僅在差距不足時補到 HP：保持既有原型／個性傾向，且任何兩張卡都能在面板上明確區分。
        $hpIncrease = if ($bonus.hp -le $nearest.bonus.hp) { ([int]$nearest.bonus.hp - [int]$bonus.hp) + $minimumGuardianDistance } else { $minimumGuardianDistance - $nearestDistance }
        $bonus.hp += $hpIncrease
        $separationAdjustment += $hpIncrease
    }
    $vector = "$($bonus.hp)|$($bonus.mp)|$($bonus.sp)|$($bonus.str)|$($bonus.stamina)|$($bonus.wis)|$($bonus.spd)|$($bonus.atk)|$($bonus.def)"
    while ($seenVectors.ContainsKey($vector)) {
        $bonus.hp++
        $vector = "$($bonus.hp)|$($bonus.mp)|$($bonus.sp)|$($bonus.str)|$($bonus.stamina)|$($bonus.wis)|$($bonus.spd)|$($bonus.atk)|$($bonus.def)"
    }
    $bonus | Add-Member -NotePropertyName separation_adjustment -NotePropertyValue $separationAdjustment
    $seenVectors[$vector] = $record.card_id
    $guardianBonuses[$record.card_id] = $bonus
    $acceptedGuardianBonuses += [pscustomobject]@{ card_id = $record.card_id; bonus = $bonus }
}
if ($guardianBonuses.Count -ne 97 -or $seenVectors.Count -ne 97) { throw 'Guardian bonus vectors must be unique for all 97 static cards.' }

$utf8 = [System.Text.UTF8Encoding]::new($false)
$lua = [System.Collections.Generic.List[string]]::new()
$lua.Add('-- GENERATED by tools/Build-StaticCardCatalogue.ps1; do not edit by hand.')
$lua.Add('-- Source: Steam HD 4.0.5 capture-card-audit.csv. 193 mappings; 97 static card definitions.')
$lua.Add('SWD3AllMonsterStaticCatalogue = SWD3AllMonsterStaticCatalogue or {}')
$lua.Add('local Catalogue = SWD3AllMonsterStaticCatalogue')
$lua.Add('Catalogue.entries = {')
foreach ($record in $records) {
    $static = if ($record.static_card_required -eq 'Y') { 'true' } else { 'false' }
    $guardianLua = ''
    if ($record.static_card_required -eq 'Y') {
        $bonus = $guardianBonuses[$record.card_id]
        $guardianLua = (", guardianPowerTier = '{0}', guardianBonus = {{ hp = {1}, mp = {2}, sp = {3}, str = {4}, stamina = {5}, wis = {6}, spd = {7}, atk = {8}, def = {9} }}" -f $record.guardian_power_tier, $bonus.hp, $bonus.mp, $bonus.sp, $bonus.str, $bonus.stamina, $bonus.wis, $bonus.spd, $bonus.atk, $bonus.def)
    }
    $lua.Add(("    [{0}] = {{ cardId = {1}, staticCard = {2}, raceId = {3}, tier = '{4}', hpMultiplier = {5:F2}, atkMultiplier = {6:F2}, defMultiplier = {7:F2}, guardianSpCost = {8}{9} }}," -f $record.enemy_id, $record.card_id, $static, $record.race_id, $record.rarity_tier, $record.hp_multiplier, $record.atk_multiplier, $record.def_multiplier, $record.guardian_sp_cost, $guardianLua))
}
$lua.Add('}')
$lua.Add('function Catalogue.Get(enemyId) return Catalogue.entries[tonumber(enemyId)] end')
$lua.Add('function Catalogue.CardIdForEnemy(enemyId) local entry = Catalogue.Get(enemyId); return entry and entry.cardId or nil end')
$lua.Add('function Catalogue.RequiresStaticCard(enemyId) local entry = Catalogue.Get(enemyId); return entry and entry.staticCard == true or false end')
[System.IO.File]::WriteAllLines($OutputLua, $lua, $utf8)

$strings = [System.Collections.Generic.List[string]]::new()
foreach ($record in $records | Where-Object { $_.static_card_required -eq 'Y' }) {
    $keySuffix = $record.enemy_id
    $bonus = $guardianBonuses[$record.card_id]
    $strings.Add("AMSC_Name_$keySuffix $($record.name)・契靈")
    $strings.Add("AMSC_Info_$keySuffix 護駕・$($bonus.power_label)：HP+$($bonus.hp) MP+$($bonus.mp) SP+$($bonus.sp) 力+$($bonus.str) 耐+$($bonus.stamina) 智+$($bonus.wis) 敏+$($bonus.spd) 攻+$($bonus.atk) 防+$($bonus.def)。$($bonus.theme_label)：$($bonus.theme_note) 個性・$($bonus.signature_label)：$($bonus.signature_note)")
}
[System.IO.File]::WriteAllLines($OutputStrings, $strings, $utf8)

$records | Export-Csv -LiteralPath $OutputCsv -NoTypeInformation -Encoding utf8

$guardianSpecs = foreach ($record in @($records | Where-Object { $_.static_card_required -eq 'Y' })) {
    $combatant = $combatantsById[$record.enemy_id]
    if ($null -eq $combatant) { throw "Combatant data is unavailable for static card source $($record.enemy_id)" }
    $bonus = $guardianBonuses[$record.card_id]
    $sourceATK = To-Int $combatant.atk
    $sourceDEF = To-Int $combatant.def
    $sourceWIS = To-Int $combatant.wis

    [pscustomobject][ordered]@{
        card_id = $record.card_id
        card_name = "$($record.name)・契靈"
        source_enemy_id = $record.enemy_id
        source_name = $record.name
        rarity_tier = $record.rarity_tier
        rarity_label = $record.rarity_label
        guardian_power_tier = $record.guardian_power_tier
        guardian_power_label = $bonus.power_label
        race_id = $record.race_id
        level = $record.level
        guardian_sp_cost = $record.guardian_sp_cost
        not_in_book = 'Y'
        source_hp = To-Int $combatant.hp
        source_atk = $sourceATK
        source_def = $sourceDEF
        source_spd = To-Int $combatant.spd
        source_wis = $sourceWIS
        card_battle_hp = Round-Scaled (To-Int $combatant.hp) $record.hp_multiplier
        card_battle_atk = Round-Scaled $sourceATK $record.atk_multiplier
        card_battle_def = Round-Scaled $sourceDEF $record.def_multiplier
        add_hp = $bonus.hp
        add_mp = $bonus.mp
        add_sp = $bonus.sp
        add_str = $bonus.str
        add_stamina = $bonus.stamina
        add_wis = $bonus.wis
        add_spd = $bonus.spd
        add_atk = $bonus.atk
        add_def = $bonus.def
        guardian_theme = $bonus.theme_label
        guardian_archetype = $bonus.archetype_label
        guardian_signature = $bonus.signature_label
        guardian_signature_note = $bonus.signature_note
        specialization_mode = $bonus.specialization_mode
        separation_adjustment_hp = $bonus.separation_adjustment
        source_focus = $bonus.source_focus
        design_note = "$($bonus.power_label)護駕／$($bonus.theme_label)：$($bonus.theme_note) 個性・$($bonus.signature_label)：$($bonus.signature_note) $($bonus.source_focus)與原始面板折算已反映在九維加成。"
    }
}
if ($guardianSpecs.Count -ne 97) { throw "Expected 97 static guardian specs, got $($guardianSpecs.Count)" }
$guardianSpecs | Sort-Object card_id | Export-Csv -LiteralPath $OutputGuardianSpecsCsv -NoTypeInformation -Encoding utf8

$tierSummary = $records | Group-Object rarity_tier | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Count)" }
Write-Host "Generated mappings=$($records.Count), staticCards=$($nextStaticId - 10001), guardianSpecs=$($guardianSpecs.Count), IDs=10001-$($nextStaticId - 1), $($tierSummary -join ', ')"
