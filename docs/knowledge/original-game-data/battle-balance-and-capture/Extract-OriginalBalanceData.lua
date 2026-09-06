-- Read-only exporter for the Steam HD 4.0.5 script_index data extracted in this
-- workspace.  Run it through fengari; it never loads a save file or writes to
-- the game installation.
--
-- Usage:
--   fengari Extract-OriginalBalanceData.lua <out_data-dir> <output-dir>

local sourceDir = assert(arg[1], 'missing extracted out_data directory')
local outputDir = assert(arg[2], 'missing output directory')

local function path(name)
    return sourceDir .. '/' .. name
end

local sources = {
    'GameData_ItemData.lua',
    'GameData_BattleCharData.lua',
    'GameData_WeaponData.lua',
    'GameData_ArmorData.lua',
    'GameData_SkillData.lua',
    'GameData_AttackEffect.lua',
    'GameData_NewGame.lua',
    'GameData_PlayerLevel.lua',
    'GameData_RaceDefine.lua',
}

GameData = {}
Const = {}
for _, name in ipairs(sources) do
    local loader, failure = loadfile(path(name))
    assert(loader, ('cannot load %s: %s'):format(name, tostring(failure)))
    loader()
end

local function text(key)
    if type(key) ~= 'string' then
        return ''
    end
    -- fengari's command-line host does not expose io.open/io.lines.  Emit the
    -- original StringDB key and let the PowerShell wrapper resolve it from the
    -- read-only ItemString.txt after parsing CSV safely.
    return key
end

local function number(value)
    if type(value) == 'number' then
        return value
    end
    return 0
end

local function bool(value)
    return value == true and 'Y' or ''
end

local function csv(value)
    local valueType = type(value)
    if value == nil then
        return ''
    end
    if valueType == 'boolean' then
        return value and 'Y' or ''
    end
    local out = tostring(value):gsub('"', '""')
    if out:find('[,\"\r\n]') then
        return '"' .. out .. '"'
    end
    return out
end

local function numericKeys(tableValue)
    local keys = {}
    if type(tableValue) == 'table' then
        for key in pairs(tableValue) do
            if type(key) == 'number' then
                table.insert(keys, key)
            end
        end
    end
    table.sort(keys)
    return keys
end

local function joinNumbers(value)
    local values = {}
    if type(value) == 'table' then
        for _, key in ipairs(numericKeys(value)) do
            table.insert(values, tostring(value[key]))
        end
    end
    return table.concat(values, '|')
end

local itemTypeFields = {
    'IT_01', 'IT_02', 'IT_03', 'IT_04', 'IT_05', 'IT_06', 'IT_07',
    'IT_08', 'IT_09', 'IT_10', 'IT_11', 'IT_12', 'IT_13', 'IT_28',
    'IT_29', 'IT_30', 'IT_31', 'IT_32',
}

local function itemTypes(item)
    local values = {}
    for _, field in ipairs(itemTypeFields) do
        if item[field] == true then
            table.insert(values, field)
        end
    end
    return table.concat(values, '|')
end

local function roleUsers(item)
    local roles = {}
    for role = 1, 4 do
        if item['User_0' .. role] == true then
            table.insert(roles, role)
        end
    end
    return table.concat(roles, '|')
end

local function effect(effectId)
    local data = GameData.AttackEffect and GameData.AttackEffect[effectId]
    if type(data) ~= 'table' then
        return {}
    end
    return data
end

local function effectColumns(effectId)
    local data = effect(effectId)
    return {
        effectId or '',
        number(data.iAttackPoint),
        number(data.iAttr),
        bool(data.bWideRange),
        number(data.iContinuous),
        number(data.hAffixationEfficacy),
        number(data.hRelieveEfficacy),
        number(data.hAddBuff),
        number(data.iResistAttr),
        bool(data.bSnatchHP),
        bool(data.bSnatchMP),
        bool(data.bSnatchSP),
        bool(data.bEscape),
        number(data.iSummonID),
        number(data.iSummonCount),
    }
end

local writers = {}
local writerOrder = {}
local function begin(name, headers)
    local writer = { name = name, lines = { table.concat(headers, ',') } }
    writers[name] = writer
    table.insert(writerOrder, writer)
    return writer
end

local function row(writer, values)
    local cells = {}
    for index, value in ipairs(values) do
        cells[index] = csv(value)
    end
    table.insert(writer.lines, table.concat(cells, ','))
end

local function finish()
    -- The wrapper splits the marked stdout stream into generated CSV files.
    for _, writer in ipairs(writerOrder) do
        print('@@BEGIN_FILE@@' .. writer.name)
        for _, line in ipairs(writer.lines) do
            print(line)
        end
    end
end

local function itemName(item)
    return text(item.Name)
end

local playerLevelCap = 0
for role = 1, 4 do
    local levelData = GameData.PlayerLevel and GameData.PlayerLevel[role]
    playerLevelCap = math.max(playerLevelCap, number(levelData and levelData.LevelMax))
end

local function nativeCaptureAtLevelCap(item)
    if item.IT_06 == true then
        return '否', '原版拒絕 IT_06 劇情類目標。'
    end
    if item.IT_12 ~= true then
        return '否', '原版拒絕非 IT_12 活物卡。'
    end
    local race = GameData.Race and GameData.Race[item.Race]
    if type(race) ~= 'table' or race.catch ~= true then
        return '否', '原版種族沒有 catch=true。'
    end
    local targetLevel = number(item.Level)
    if targetLevel - playerLevelCap >= 12 then
        return '否', ('敵方 Lv%d 比玩家最高 Lv%d 高至少 12 級。'):format(targetLevel, playerLevelCap)
    end
    return '條件式可行', ('需依等級差與 HP；目前玩家最高 Lv%d。'):format(playerLevelCap)
end

local effectsFile = begin('attack-effects.csv', {
    'effect_id', 'attack_point', 'attribute_id', 'wide_range', 'continuous_turns',
    'affixation_effect', 'relieve_effect', 'add_buff', 'resist_attribute',
    'snatch_hp', 'snatch_mp', 'snatch_sp', 'escape', 'summon_id', 'summon_count',
})
for _, id in ipairs(numericKeys(GameData.AttackEffect)) do
    row(effectsFile, effectColumns(id))
end

local skillsFile = begin('skills.csv', {
    'item_id', 'name', 'level', 'area', 'types', 'roles', 'consumption',
    'consumes_mp', 'consumes_sp', 'consumes_throwable', 'consumes_item', 'use_place',
    'attack_effect_id', 'attack_point', 'attribute_id', 'wide_range', 'continuous_turns',
    'affixation_effect', 'relieve_effect', 'add_buff', 'resist_attribute',
    'snatch_hp', 'snatch_mp', 'snatch_sp', 'escape', 'summon_id', 'summon_count',
    'info_text', 'help_text',
})

local battleItemsFile = begin('battle-usable-items.csv', {
    'item_id', 'name', 'level', 'area', 'types', 'roles', 'consumption',
    'consumes_mp', 'consumes_sp', 'consumes_throwable', 'consumes_item', 'use_place',
    'is_unique', 'discard', 'add_hp', 'add_mp', 'add_sp', 'add_atk', 'add_def', 'add_spd',
    'add_dodge', 'add_str', 'add_stamina', 'add_wis', 'add_friend', 'attack_effect_id', 'attack_point', 'attribute_id',
    'wide_range', 'continuous_turns', 'affixation_effect', 'relieve_effect', 'add_buff',
    'resist_attribute', 'snatch_hp', 'snatch_mp', 'snatch_sp', 'escape', 'summon_id',
    'summon_count', 'info_text', 'help_text',
})

local equipmentFile = begin('equipment-and-artifacts.csv', {
    'item_id', 'name', 'level', 'slot_types', 'roles', 'is_unique', 'discard',
    'add_atk', 'add_def', 'add_spd', 'add_dodge', 'add_hp', 'add_mp', 'add_sp',
    'add_str', 'add_stamina', 'add_wis', 'add_friend', 'add_special',
    'attack_effect_id', 'attack_point', 'attribute_id', 'wide_range', 'continuous_turns',
    'affixation_effect', 'relieve_effect', 'add_buff', 'resist_attribute',
    'info_text', 'help_text',
})

local combatantsFile = begin('combatants.csv', {
    'item_id', 'name', 'race_id', 'level', 'act', 'existing_living_card',
    'story_or_special_flag', 'not_in_book', 'is_unique', 'discard', 'hp', 'atk', 'def', 'spd', 'wis',
    'dodge_rate', 'escape_rate', 'gain_exp', 'gain_gold', 'basic_attack_effect_id',
    'skill_ids', 'skill_counts', 'skill_rate', 'special_effect_ids', 'special_effect_counts',
    'special_effect_rate', 'critical_skill_ids', 'critical_skill_counts',
    'drop_item_ids', 'drop_item_rates', 'attr_fire', 'attr_ice', 'attr_wind', 'attr_earth',
    'attr_poison', 'attr_light', 'attr_dark', 'attr_thunder', 'attr_physical', 'help_text',
})

local captureFile = begin('capture-card-audit.csv', {
    'item_id', 'name', 'race_id', 'level', 'act', 'battle_data_complete',
    'existing_living_card', 'story_or_special_flag', 'not_in_book', 'discard', 'race_catch',
    'native_capture_at_player_level_cap', 'native_capture_reason', 'hp', 'atk', 'def',
    'skills_present', 'special_effects_present', 'capture_card_status', 'note',
})

local guardianFile = begin('guardian-cards.csv', {
    'item_id', 'name', 'race_id', 'level', 'roles', 'sp_cost', 'consumes_sp', 'use_place',
    'is_unique', 'combatant_hp', 'combatant_atk', 'combatant_def', 'combatant_spd',
    'combatant_wis', 'guardian_effect_id', 'attack_point', 'attribute_id', 'wide_range',
    'continuous_turns', 'affixation_effect', 'relieve_effect', 'add_buff', 'resist_attribute',
    'snatch_hp', 'snatch_mp', 'snatch_sp', 'escape', 'summon_id', 'summon_count',
    'info_text', 'help_text',
})

local permanentGrowthFile = begin('permanent-growth-items.csv', {
    'item_id', 'name', 'level', 'area', 'types', 'roles', 'price', 'consumes_item',
    'is_unique', 'discard', 'add_hp', 'add_mp', 'add_sp', 'add_str', 'add_stamina',
    'add_wis', 'add_spd', 'add_friend', 'add_dodge', 'info_text', 'help_text',
})

for _, id in ipairs(numericKeys(GameData.ItemTemp)) do
    local item = GameData.ItemTemp[id]
    if type(item) == 'table' then
        local effectValues = effectColumns(item.AttackEffect)
        local common = {
            id, itemName(item), number(item.Level), number(item.Area), itemTypes(item),
            roleUsers(item), number(item.Consumption), bool(item.Cons_MP), bool(item.Cons_SP),
            bool(item.Cons_Throw), bool(item.Cons_Item), number(item.UsePlace),
        }
        if item.isSkill == true then
            local values = {}
            for _, value in ipairs(common) do table.insert(values, value) end
            for _, value in ipairs(effectValues) do table.insert(values, value) end
            table.insert(values, text(item.InfoText))
            table.insert(values, text(item.HelpText))
            row(skillsFile, values)
        end
        if (number(item.UsePlace) == 1 or number(item.UsePlace) == 4) and item.isSkill ~= true then
            local values = {}
            for _, value in ipairs(common) do table.insert(values, value) end
            table.insert(values, bool(item.isUnique))
            table.insert(values, bool(item.discard))
            table.insert(values, number(item.AddHP))
            table.insert(values, number(item.AddMP))
            table.insert(values, number(item.AddSP))
            table.insert(values, number(item.AddATK))
            table.insert(values, number(item.AddDEF))
            table.insert(values, number(item.AddSPD))
            table.insert(values, number(item.AddDodge))
            table.insert(values, number(item.AddSTR))
            table.insert(values, number(item.AddStamina))
            table.insert(values, number(item.AddWIS))
            table.insert(values, number(item.AddFriend))
            for _, value in ipairs(effectValues) do table.insert(values, value) end
            table.insert(values, text(item.InfoText))
            table.insert(values, text(item.HelpText))
            row(battleItemsFile, values)
        end
        if item.IT_09 == true or item.IT_10 == true or item.IT_11 == true or item.IT_07 == true then
            local values = {
                id, itemName(item), number(item.Level), itemTypes(item), roleUsers(item),
                bool(item.isUnique), bool(item.discard), number(item.AddATK), number(item.AddDEF),
                number(item.AddSPD), number(item.AddDodge), number(item.AddHP), number(item.AddMP),
                number(item.AddSP), number(item.AddSTR), number(item.AddStamina), number(item.AddWIS),
                number(item.AddFriend), number(item.AddSpecial),
            }
            for _, value in ipairs(effectValues) do table.insert(values, value) end
            table.insert(values, text(item.InfoText))
            table.insert(values, text(item.HelpText))
            row(equipmentFile, values)
        end
        if item.IT_12 == true then
            local values = {
                id, itemName(item), number(item.Race), number(item.Level), roleUsers(item),
                number(item.Consumption), bool(item.Cons_SP), number(item.UsePlace), bool(item.isUnique),
                number(item.HP), number(item.ATK), number(item.DEF), number(item.SPD), number(item.WIS),
            }
            for _, value in ipairs(effectValues) do table.insert(values, value) end
            table.insert(values, text(item.InfoText))
            table.insert(values, text(item.HelpText))
            row(guardianFile, values)
        end
        -- Calculation=256 also appears on some active guardians/equipment.
        -- Only the original data's normal-use items (UsePlace=2) belong in the
        -- permanent-growth audit; battle-only entries are not asserted to be
        -- permanent character growth.
        if number(item.Calculation) == 256 and number(item.UsePlace) == 2 then
            row(permanentGrowthFile, {
                id, itemName(item), number(item.Level), number(item.Area), itemTypes(item),
                roleUsers(item), number(item.Price), bool(item.Cons_Item), bool(item.isUnique),
                bool(item.discard), number(item.AddHP), number(item.AddMP), number(item.AddSP),
                number(item.AddSTR), number(item.AddStamina), number(item.AddWIS), number(item.AddSPD),
                number(item.AddFriend), number(item.AddDodge), text(item.InfoText), text(item.HelpText),
            })
        end
        if item.isBattleChar == true then
            row(combatantsFile, {
                id, itemName(item), number(item.Race), number(item.Level), number(item.ACT),
                bool(item.IT_12), bool(item.IT_06), bool(item.NotInBook), bool(item.isUnique), bool(item.discard),
                number(item.HP), number(item.ATK), number(item.DEF), number(item.SPD), number(item.WIS),
                number(item.DodgeRate), number(item.EscapeRate), number(item.GainEXP), number(item.GainGold),
                item.AttackEffect or '', joinNumbers(item.Skills), joinNumbers(item.SkillsCount),
                number(item.SkillRate), joinNumbers(item.SP_AttackEffects),
                joinNumbers(item.SP_AttackEffectsCount), number(item.SP_AttackEffectRate),
                joinNumbers(item.CR_Skills), joinNumbers(item.CR_SkillsCount), joinNumbers(item.DropItems),
                joinNumbers(item.DropItemsRate), number(item.AttrFire), number(item.AttrIce),
                number(item.AttrWind), number(item.AttrEarth), number(item.AttrPoison),
                number(item.AttrLight), number(item.AttrDark), number(item.AttrThunder),
                number(item.AttrPhysical), text(item.HelpText),
            })
            local complete = item.ACT and item.ACT > 0 and item.Level and item.Level > 0
            local status = item.IT_12 == true and '現有活物卡' or '非活物卡'
            local captureAtCap, captureReason = nativeCaptureAtLevelCap(item)
            local race = GameData.Race and GameData.Race[item.Race]
            local note = complete and '可作自由挑戰敵方資料；原版可否以煉妖壺收服仍須引擎實測。'
                or '資料不足，不能作自由挑戰敵方或新卡複製來源。'
            row(captureFile, {
                id, itemName(item), number(item.Race), number(item.Level), number(item.ACT),
                bool(complete), bool(item.IT_12), bool(item.IT_06), bool(item.NotInBook), bool(item.discard),
                bool(race and race.catch), captureAtCap, captureReason,
                number(item.HP), number(item.ATK), number(item.DEF), joinNumbers(item.Skills),
                joinNumbers(item.SP_AttackEffects), status, note,
            })
        end
    end
end

local playersFile = begin('players-level-60.csv', {
    'party_slot', 'name', 'start_level', 'level_cap', 'hp', 'mp', 'sp', 'str', 'stamina',
    'wis', 'spd', 'friend', 'agi', 'luck', 'dodge', 'learned_skill_ids', 'learned_skill_names',
})

local playerSkillsFile = begin('player-learned-skills.csv', {
    'party_slot', 'character_name', 'learned_at_level', 'skill_id', 'skill_name', 'consumption',
    'consumes_mp', 'consumes_sp', 'attack_effect_id', 'attack_point', 'attribute_id',
    'wide_range', 'affixation_effect', 'add_buff', 'info_text',
})

local statKeys = { 'HP', 'MP', 'SP', 'STR', 'Stamina', 'WIS', 'SPD', 'Friend', 'AGI', 'Luck', 'Dodge' }
for role = 1, 4 do
    local initial = assert(GameData.NewGameChar[role], 'missing initial player data')
    local levelData = assert(GameData.PlayerLevel[role], 'missing player level data')
    local values = {}
    for _, key in ipairs(statKeys) do
        values[key] = number(initial[key])
    end
    local learned = {}
    local seen = {}
    for _, skillId in ipairs(GameData.NewGameSkill[role] or {}) do
        if not seen[skillId] then
            seen[skillId] = true
            table.insert(learned, skillId)
        end
        local skill = GameData.ItemTemp[skillId] or {}
        local fields = effectColumns(skill.AttackEffect)
        row(playerSkillsFile, {
            role, text(initial.Name), initial.Level, skillId, itemName(skill), number(skill.Consumption),
            bool(skill.Cons_MP), bool(skill.Cons_SP),
            fields[1], fields[2], fields[3], fields[4], fields[6], fields[8], text(skill.InfoText),
        })
    end
    for level = initial.Level + 1, number(levelData.LevelMax) do
        local gains = levelData[level]
        if type(gains) == 'table' then
            for index, key in ipairs(statKeys) do
                values[key] = values[key] + number(gains[index])
            end
            local skillId = gains[13]
            if type(skillId) == 'number' then
                if not seen[skillId] then
                    seen[skillId] = true
                    table.insert(learned, skillId)
                end
                local skill = GameData.ItemTemp[skillId] or {}
                local fields = effectColumns(skill.AttackEffect)
                row(playerSkillsFile, {
                    role, text(initial.Name), level, skillId, itemName(skill), number(skill.Consumption),
                    bool(skill.Cons_MP), bool(skill.Cons_SP), fields[1], fields[2], fields[3], fields[4],
                    fields[6], fields[8], text(skill.InfoText),
                })
            end
        end
    end
    local skillIds, skillNames = {}, {}
    for _, skillId in ipairs(learned) do
        table.insert(skillIds, skillId)
        table.insert(skillNames, itemName(GameData.ItemTemp[skillId] or {}))
    end
    row(playersFile, {
        role, text(initial.Name), initial.Level, levelData.LevelMax, values.HP, values.MP, values.SP,
        values.STR, values.Stamina, values.WIS, values.SPD, values.Friend, values.AGI, values.Luck,
        values.Dodge, table.concat(skillIds, '|'), table.concat(skillNames, '|'),
    })
end

local manifest = begin('export-manifest.csv', { 'source_file', 'purpose' })
for _, name in ipairs(sources) do
    row(manifest, { name, 'loaded as original data definition' })
end
row(manifest, { 'ItemString.txt', 'maps original StringDB keys to Traditional Chinese text' })
row(manifest, { 'Generated files', 'read-only static export; no save data or game installation modified' })

finish()
print('PASS: emitted original balance data for ' .. outputDir)
