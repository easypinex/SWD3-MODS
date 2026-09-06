-- Steam HD 4.0.5：玩家普通攻擊的爆擊傷害唯讀量測。
-- 只讀取原版已宣告的 callback、戰鬥資料、裝備與 OnEventValue；不寫入任何遊戲資料。

SWD3CriticalHitFormulaProbe = SWD3CriticalHitFormulaProbe or {}
local MOD = SWD3CriticalHitFormulaProbe
MOD.state = MOD.state or { eventsRegistered = false, battleNumber = 0, samples = 0, pendingByPlayer = {} }
local State = MOD.state
local SAMPLE_LIMIT = 40

local function write(message)
    if type(log) == 'function' then
        log('[CriticalHitFormulaProbe] ' .. tostring(message))
    end
end

local function number(value, fallback)
    local result = tonumber(value)
    if result == nil then return fallback end
    return result
end

local function battleFieldId()
    if type(GameFunc) ~= 'table' or type(GameFunc.GetBattleFieldID) ~= 'function' then return '?' end
    local ok, value = pcall(GameFunc.GetBattleFieldID)
    return ok and tostring(value) or '?'
end

local function itemName(itemId)
    local item = GameData and GameData.ItemTemp and GameData.ItemTemp[itemId]
    local key = item and item.Name
    if type(key) == 'string' then return key end
    return tostring(itemId or '?')
end

local function equippedWeapon(actor)
    local playerId = number(actor and actor.NPC_GUID, nil)
    local equipment = SaveData and SaveData.PlayerEqu and playerId and SaveData.PlayerEqu[playerId]
    if type(equipment) ~= 'table' then return nil, nil end
    for _, slot in pairs(equipment) do
        local itemId = number(slot and slot.ItemTempID, nil)
        local item = itemId and GameData and GameData.ItemTemp and GameData.ItemTemp[itemId]
        if type(item) == 'table' and item.IT_09 == true then
            return itemId, item
        end
    end
    return nil, nil
end

local function normalAttackRateBase(sourceLevel, targetLevel)
    if sourceLevel ~= nil and targetLevel ~= nil and sourceLevel - 5 > targetLevel then
        return 10
    end
    return 20
end

local function resetBattle(reason)
    State.pendingByPlayer = {}
    State.samples = 0
    write('reset samples (' .. tostring(reason) .. ')')
end

local function settlePendingSample(playerIndex, reason)
    local sample = State.pendingByPlayer[playerIndex]
    if type(sample) ~= 'table' then return false end
    local target = BattleEnemys and BattleEnemys[sample.targetIndex]
    local afterHp = number(target and target.NPCData and target.NPCData.HP, nil)
    if afterHp == nil or sample.beforeHp == nil or afterHp == sample.beforeHp then
        return false
    end
    State.pendingByPlayer[playerIndex] = nil
    write(string.format(
        'result: %s via %s; playerSource=%s Lv%s, weapon=%s, effect=%s; enemySource=%s Lv%s; hp=%s->%s, observedDamage=%s',
        sample.critical and 'CRITICAL' or 'normal', tostring(reason), tostring(sample.sourceId),
        tostring(sample.sourceLevel), tostring(sample.weaponId), tostring(sample.effectId),
        tostring(sample.targetId), tostring(sample.targetLevel), tostring(sample.beforeHp),
        tostring(afterHp), tostring(sample.beforeHp - afterHp)))
    return true
end

local function onBattleEnter()
    State.battleNumber = number(State.battleNumber, 0) + 1
    resetBattle('Battle_Enter #' .. tostring(State.battleNumber) .. ', field=' .. battleFieldId())
end

-- 原版 callback 的 `main` 會先寫入 OnEventValue；本 handler 只讀取它的最終值。
local function onBattleCriticalHitRate(inputCritical, playerIndex, side, targetIndex, targetSide)
    if side ~= 0 or targetSide ~= 1 then return end
    -- 已觀察到 BattlePlayerAI_after 仍早於傷害寫入；下一次玩家攻擊前再補讀上筆。
    settlePendingSample(playerIndex, 'next BattleCriticalHitRate')
    local player = BattlePlayers and BattlePlayers[playerIndex]
    local target = BattleEnemys and BattleEnemys[targetIndex]
    local sourceStatus = player and player.CharData
    local targetStatus = target and target.NPCData
    local sourceLevel = number(sourceStatus and sourceStatus.Level, nil)
    local targetLevel = number(targetStatus and targetStatus.Level, nil)
    local beforeHp = number(targetStatus and targetStatus.HP, nil)
    local weaponId, weapon = equippedWeapon(player)
    local effectId = number(weapon and weapon.AttackEffect, nil)
    local effect = effectId and GameData and GameData.AttackEffect and GameData.AttackEffect[effectId]
    local finalCritical = number(OnEventValue and OnEventValue.BeCriticalHit, number(inputCritical, 0))

    if State.samples >= SAMPLE_LIMIT then
        if State.samples == SAMPLE_LIMIT then write('sample limit reached; later player attacks are ignored') end
        State.samples = State.samples + 1
        return
    end
    State.samples = State.samples + 1
    State.pendingByPlayer[playerIndex] = {
        targetIndex = targetIndex,
        beforeHp = beforeHp,
        critical = finalCritical == 1,
        sourceId = number(player and player.NPC_GUID, nil),
        sourceLevel = sourceLevel,
        targetId = number(target and target.NPC_GUID, nil),
        targetLevel = targetLevel,
        weaponId = weaponId,
        effectId = effectId
    }
    write(string.format(
        'roll #%d: player=%s Lv%s -> enemy=%s Lv%s; input=%s, final=%s, rateBase=1/%s; weapon=%s(%s), effect=%s type=%s point=%s, targetHP=%s',
        State.samples, tostring(playerIndex), tostring(sourceLevel), tostring(targetIndex), tostring(targetLevel),
        tostring(inputCritical), tostring(finalCritical), tostring(normalAttackRateBase(sourceLevel, targetLevel)),
        itemName(weaponId), tostring(weaponId), tostring(effectId), tostring(effect and effect.hActionType),
        tostring(effect and effect.iAttackPoint), tostring(beforeHp)))
end

-- 已實測這個 callback 早於 native HP 寫入。保留樣本，改由後續 UI 更新或下一次攻擊結算。
local function onBattlePlayerAIAfter(playerIndex)
    local sample = State.pendingByPlayer[playerIndex]
    if type(sample) ~= 'table' then return end
    if not settlePendingSample(playerIndex, 'BattlePlayerAI_after') and not sample.awaitingReported then
        sample.awaitingReported = true
        write('sample awaits native HP update after BattlePlayerAI_after')
    end
end

local function onBattleDrawBGI()
    for playerIndex, _ in pairs(State.pendingByPlayer) do
        settlePendingSample(playerIndex, 'Battle_DrawBGI')
    end
end

OnEvent = OnEvent or {}
OnEvent.Battle_Enter = OnEvent.Battle_Enter or {}
OnEvent.BattleCriticalHitRate = OnEvent.BattleCriticalHitRate or {}
OnEvent.BattlePlayerAI_after = OnEvent.BattlePlayerAI_after or {}
OnEvent.Battle_DrawBGI = OnEvent.Battle_DrawBGI or {}
OnEvent.Battle_RestoreItem = OnEvent.Battle_RestoreItem or {}
OnEvent.MapLoading = OnEvent.MapLoading or {}

if not State.eventsRegistered then
    table.insert(OnEvent.Battle_Enter, onBattleEnter)
    table.insert(OnEvent.BattleCriticalHitRate, onBattleCriticalHitRate)
    table.insert(OnEvent.BattlePlayerAI_after, onBattlePlayerAIAfter)
    table.insert(OnEvent.Battle_DrawBGI, onBattleDrawBGI)
    table.insert(OnEvent.Battle_RestoreItem, function() resetBattle('Battle_RestoreItem') end)
    table.insert(OnEvent.MapLoading, function() resetBattle('MapLoading') end)
    State.eventsRegistered = true
end

write('armed: read-only player normal-attack samples, maximum ' .. tostring(SAMPLE_LIMIT) .. ' per battle')
