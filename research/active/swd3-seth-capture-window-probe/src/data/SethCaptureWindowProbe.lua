-- Steam HD 4.0.5 研究用：F3 隔離戰只切換戰鬥副本的 Boss bit (ItemType 0x20)。
-- 假說：手動指令 UI 的輸入期先清 Boss；非賽特命令提交後恢復 Boss，
--       賽特提交後維持非 Boss，供只有賽特可用的原生 action 6 執行。
-- 不使用 BattlePlayerAI_mod、Battle_DrawBGI，不修改正式 bridge、傷害、機率或存檔。

SWD3SethCaptureWindowProbe = SWD3SethCaptureWindowProbe or {}
local MOD = SWD3SethCaptureWindowProbe
local F3_SCANCODE = 60
local BATTLE_ID = 'SCWP_BULL_DEMON_WINDOW'
local SOURCE_ID = 59
local TEST_MAX_HP, TEST_HP = 100, 15
local BOSS_ITEM_TYPE_MASK = 0x20

MOD.state = MOD.state or { eventsRegistered = false, active = nil }
local State = MOD.state
local runBattleScript

local function write(message)
    if type(log) == 'function' then log('[SethCaptureWindowProbe] ' .. tostring(message)) end
end

local function snapshotField(snapshot, object, field)
    snapshot[field] = { present = object[field] ~= nil, value = object[field] }
end

local function restoreField(snapshot, object, field)
    local saved = snapshot and snapshot[field]
    if saved == nil or object == nil then return end
    pcall(function() object[field] = saved.present and saved.value or nil end)
end

local function getTarget()
    local target = BattleEnemys and BattleEnemys[1]
    if tonumber(target and target.NPC_GUID) ~= SOURCE_ID then return nil, nil end
    return target, target.NPCData
end

local function normalizedItemType(value)
    local numeric = tonumber(value)
    if numeric == nil or numeric < 0 or numeric ~= math.floor(numeric) then
        return nil, 'ItemType is not a non-negative integer: ' .. tostring(value)
    end
    return numeric
end

local function hasBossBit(itemType)
    return math.floor(itemType / BOSS_ITEM_TYPE_MASK) % 2 == 1
end

local function withBossBit(itemType, enabled)
    if hasBossBit(itemType) == enabled then return itemType end
    return enabled and itemType + BOSS_ITEM_TYPE_MASK or itemType - BOSS_ITEM_TYPE_MASK
end

local function readBossFlag(status)
    local ok, value = pcall(function() return status.ItemType end)
    if not ok then return false, nil, nil, value end
    local itemType, failure = normalizedItemType(value)
    if itemType == nil then return false, nil, nil, failure end
    return true, hasBossBit(itemType), itemType
end

local function writeBossFlag(active, enabled, reason)
    local _, status = getTarget()
    if type(active) ~= 'table' or status == nil then
        write('flag write refused (' .. tostring(reason) .. '): isolated target is unavailable')
        return false
    end
    if active.flagSnapshot == nil then
        local readable, beforeEnabled, beforeItemType, failure = readBossFlag(status)
        if not readable then
            write('flag write refused: NPCData.ItemType is not readable: ' .. tostring(failure))
            return false
        end
        active.flagSnapshot = { itemType = beforeItemType, status = status }
        write('live flag preflight: NPCData.ItemType=' .. tostring(beforeItemType)
            .. ', Boss bit=' .. tostring(beforeEnabled))
    end
    local readable, _, beforeItemType, failure = readBossFlag(status)
    if not readable then
        write('flag write refused (' .. tostring(reason) .. '): ItemType read failed: ' .. tostring(failure))
        return false
    end
    local desiredItemType = withBossBit(beforeItemType, enabled)
    local ok, writeFailure = pcall(function() status.ItemType = desiredItemType end)
    local afterReadable, afterEnabled, afterItemType, afterFailure = readBossFlag(status)
    if not ok or not afterReadable or afterEnabled ~= enabled or afterItemType ~= desiredItemType then
        write('flag write refused (' .. tostring(reason) .. '): requested ItemType=' .. tostring(desiredItemType)
            .. ', readback=' .. tostring(afterItemType) .. ', Boss bit=' .. tostring(afterEnabled)
            .. ', failure=' .. tostring(writeFailure or afterFailure))
        return false
    end
    if active.bossEnabled ~= enabled then
        write('live Boss flag ' .. (enabled and 'ON' or 'OFF') .. ' (' .. tostring(reason)
            .. '); NPCData.ItemType=' .. tostring(afterItemType))
    end
    active.bossEnabled = enabled
    return true
end

local function restoreProbe(reason)
    local active = State.active
    if type(active) ~= 'table' then return end
    if type(active.flagSnapshot) == 'table' and active.flagSnapshot.status ~= nil then
        pcall(function() active.flagSnapshot.status.ItemType = active.flagSnapshot.itemType end)
    end
    local source = GameData and GameData.ItemTemp and GameData.ItemTemp[SOURCE_ID]
    if type(source) == 'table' then
        for _, field in ipairs({ 'HP', 'ATK', 'SPD', 'Skills', 'CureSkills', 'SP_AE' }) do
            restoreField(active.source, source, field)
        end
    end
    State.active = nil
    write('cleanup complete (' .. tostring(reason) .. '): source data restored; live flag snapshot restored when available')
end

local function formalBridgeReady()
    local bridge = SWD3AllMonsterStaticCapture
    local source = GameData and GameData.ItemTemp and GameData.ItemTemp[SOURCE_ID]
    return type(bridge) == 'table' and type(bridge.captureRuntime) == 'table'
        and type(bridge.captureRuntime.active) == 'table' and type(source) == 'table'
        and source.IT_12 == true and source.IT_06 == nil
end

local function startProbe()
    if State.active ~= nil then write('F3 ignored: an isolated test battle is already active'); return end
    if not formalBridgeReady() then
        write('F3 refused: 全魔物靈契 bridge is not armed for source 59; enable only it and this probe, restart, then enter a map')
        return
    end
    local source = GameData.ItemTemp[SOURCE_ID]
    local active = { source = {}, bossEnabled = nil, flagSnapshot = nil, ready = false, inputSequence = 0 }
    for _, field in ipairs({ 'HP', 'ATK', 'SPD', 'Skills', 'CureSkills', 'SP_AE' }) do
        snapshotField(active.source, source, field)
    end
    source.HP, source.ATK, source.SPD = TEST_MAX_HP, 0, 0
    source.Skills, source.CureSkills, source.SP_AE = {}, {}, {}
    State.active = active
    BattleField, BattleScript = BattleField or {}, BattleScript or {}
    BattleScript[BATTLE_ID] = runBattleScript
    BattleField[BATTLE_ID] = {
        iBattleFieldBackground = 4, MusicFileName = 'Battle_Europa01.mp3',
        tCharActQ = { { ItemTempID = SOURCE_ID, X = 176, Y = 294 } }
    }
    local ok, failure = pcall(ESC.StartBattle, BATTLE_ID)
    if not ok then
        restoreProbe('StartBattle failed')
        write('F3 StartBattle failed: ' .. tostring(failure))
        return
    end
    write('F3 isolated battle started: source 59 has HP 15/100, no attacks or skills; do not save')
end

runBattleScript = function()
    if type(BSC) ~= 'table' or type(BSC.Enter) ~= 'function' then
        write('BattleScript refused: BSC.Enter is unavailable')
        return
    end
    BSC.Enter(1)
end

local function nowMenu()
    local ok, value = pcall(function() return _BattleEnv and _BattleEnv.NowMenu end)
    return ok and tonumber(value) or nil
end

local function onCommandInput(origin)
    local active = State.active
    if type(active) ~= 'table' or not active.ready then return end
    local menu = nowMenu()
    if menu ~= 1 and menu ~= 3 then return end
    active.inputSequence = active.inputSequence + 1
    write('input #' .. tostring(active.inputSequence) .. ' ' .. tostring(origin)
        .. ': NowMenu=' .. tostring(menu) .. '; request Boss OFF for command UI / target confirmation')
    if not writeBossFlag(active, false, origin .. ' NowMenu=' .. tostring(menu)) then
        active.ready = false
        write('FAIL: live Boss flag could not be cleared in the command-input window; leave without saving')
    end
end

local function onInputClick(_, keyScancode)
    if keyScancode == F3_SCANCODE then
        if type(GameFunc) ~= 'table' or type(GameFunc.RunScene) ~= 'function' then
            write('F3 refused: GameFunc.RunScene is unavailable')
            return true
        end
        local ok, failure = pcall(GameFunc.RunScene, -1, 'SCWP_Start', 1)
        if not ok then write('F3 RunScene failed: ' .. tostring(failure)) end
        return true
    end
    onCommandInput('InputClick')
    return false
end

Scene = Scene or {}
function Scene.SCWP_Start() startProbe() end

local function onBattleEnemyInit(index)
    local active, enemy = State.active, BattleEnemys and BattleEnemys[index]
    if type(active) ~= 'table' or tonumber(enemy and enemy.NPC_GUID) ~= SOURCE_ID then return end
    local status = enemy.NPCData
    if status == nil then write('enemy setup refused: NPCData is unavailable'); return end
    local beforeHP, beforeMaxHP = status.HP, status.MaxHP
    local ok, failure = pcall(function() status.HP = TEST_HP end)
    if not ok or tonumber(status.HP) ~= TEST_HP then
        write('enemy HP setup refused: ' .. tostring(failure) .. '; leave without saving')
        return
    end
    write('Battle_EnemyInit: HP ' .. tostring(beforeHP) .. '/' .. tostring(beforeMaxHP)
        .. ' -> ' .. tostring(status.HP) .. '/' .. tostring(status.MaxHP) .. '; Level=' .. tostring(status.Level))
end

local function onBattleEnter()
    local active, target, status = State.active, getTarget()
    if type(active) ~= 'table' or target == nil or status == nil then return end
    if not writeBossFlag(active, false, 'Battle_Enter baseline for first command UI') then
        write('FAIL: this HD build does not expose a writable live NPCData.ItemType. Leave this battle; no result supports the candidate.')
        return
    end
    active.ready = true
    write('READY v0.6: first UI starts Boss OFF; Input* at NowMenu=1/3 clears Boss again; Seth after stays OFF, non-Seth after restores ON. No BattlePlayerAI_mod/Battle_DrawBGI; do not save.')
end

local function onBattlePlayerAIAfter(index)
    local active = State.active
    if type(active) ~= 'table' or not active.ready then return end
    local isSeth = tonumber(index) == 1
    local desiredBoss = not isSeth
    local reason = isSeth
        and 'BattlePlayerAI_after Seth: keep OFF for native action 6 / Seth executor'
        or 'BattlePlayerAI_after non-Seth: restore ON before executor/damage'
    if not writeBossFlag(active, desiredBoss, reason) then
        active.ready = false
        write('FAIL: live Boss flag could not be switched after command submission; leave without saving')
    end
end

local function onBattleCriticalHitRate(beCriticalHit, index, side, targetIndex, targetSide)
    local active = State.active
    if type(active) ~= 'table' then return end
    local _, status = getTarget()
    local readable, flag, itemType = false, nil, nil
    if status ~= nil then readable, flag, itemType = readBossFlag(status) end
    write('BattleCriticalHitRate: input=' .. tostring(beCriticalHit) .. ', source=' .. tostring(index) .. '/' .. tostring(side)
        .. ', target=' .. tostring(targetIndex) .. '/' .. tostring(targetSide)
        .. ', live Boss bit=' .. tostring(flag) .. ', ItemType=' .. tostring(itemType)
        .. ', readable=' .. tostring(readable))
end

local function onBattleDead(index, side, mode)
    if type(State.active) ~= 'table' then return end
    write('Battle_Dead: index=' .. tostring(index) .. ', side=' .. tostring(side) .. ', mode=' .. tostring(mode))
    if index == 1 and side == 1 and mode == 2 then
        write('PASS CANDIDATE: original action 6 captured while Seth retained Boss OFF after command submission')
    end
end

local function onBattleRestoreItem() restoreProbe('Battle_RestoreItem') end
local function onMapLoading() restoreProbe('MapLoading') end
local function onGameStart()
    restoreProbe('GameStart')
    write('loaded v0.6 Seth-retained input-window: no BattlePlayerAI_mod or Battle_DrawBGI; enable only 全魔物靈契 and this probe, then use F3 in a no-save test')
end

OnEvent = OnEvent or {}
for _, name in ipairs({
    'GameStart', 'InputKeyDown', 'InputKeyUp', 'InputClick', 'Battle_InputKeyDown',
    'Battle_EnemyInit', 'Battle_Enter', 'BattlePlayerAI_after', 'BattleCriticalHitRate',
    'Battle_Dead', 'Battle_RestoreItem', 'MapLoading'
}) do OnEvent[name] = OnEvent[name] or {} end
if not State.eventsRegistered then
    table.insert(OnEvent.GameStart, onGameStart)
    table.insert(OnEvent.InputKeyDown, function() onCommandInput('InputKeyDown') end)
    table.insert(OnEvent.InputKeyUp, function() onCommandInput('InputKeyUp') end)
    table.insert(OnEvent.InputClick, onInputClick)
    table.insert(OnEvent.Battle_InputKeyDown, function() onCommandInput('Battle_InputKeyDown') end)
    table.insert(OnEvent.Battle_EnemyInit, onBattleEnemyInit)
    table.insert(OnEvent.Battle_Enter, onBattleEnter)
    table.insert(OnEvent.BattlePlayerAI_after, onBattlePlayerAIAfter)
    table.insert(OnEvent.BattleCriticalHitRate, onBattleCriticalHitRate)
    table.insert(OnEvent.Battle_Dead, onBattleDead)
    table.insert(OnEvent.Battle_RestoreItem, onBattleRestoreItem)
    table.insert(OnEvent.MapLoading, onMapLoading)
    State.eventsRegistered = true
end
