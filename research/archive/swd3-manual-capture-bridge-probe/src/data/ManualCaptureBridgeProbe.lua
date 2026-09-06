-- Steam HD 4.0.5 隔離研究：在手動靈契回合後，測試 BattleScript coroutine 能否接力 BSC.Obsolt。
-- 不是正式收妖功能；不自動攔截任何一般戰鬥指令，也不可保存。

SWD3ManualCaptureBridgeProbe = SWD3ManualCaptureBridgeProbe or {}
local MOD = SWD3ManualCaptureBridgeProbe
local F6_SCANCODE = 63
local BATTLE_ID = 'MCBP_BULL_DEMON_HANDOFF'
local SOURCE_ID = 59
local TEST_MAX_HP = 100
local TEST_HP = 15
local LEVEL_CAP_OFFSET = 11

MOD.state = MOD.state or { active = nil, eventsRegistered = false }
local State = MOD.state
local runBattleScript

local function write(message)
    if type(log) == 'function' then log('[ManualCaptureBridgeProbe] ' .. tostring(message)) end
end

local function snapshotField(snapshot, object, field)
    snapshot[field] = { present = object[field] ~= nil, value = object[field] }
end

local function restoreField(snapshot, object, field)
    local saved = snapshot and snapshot[field]
    if saved == nil then return end
    object[field] = saved.present and saved.value or nil
end

local function isFormalBridgeReady()
    local capture = SWD3AllMonsterStaticCapture
    return type(capture) == 'table' and type(capture.captureRuntime) == 'table'
        and type(capture.captureRuntime.active) == 'table'
end

local function isOwnBattle()
    return State.active ~= nil and type(GameFunc) == 'table' and type(GameFunc.GetBattleFieldID) == 'function'
        and GameFunc.GetBattleFieldID() == BATTLE_ID
end

-- HD runtime exposes the initialized enemy through BattleEnv.enemys[index].self;
-- BattleEnemys is only a fallback for mocks and older observations.
local function getEnemy(index)
    local entry = BattleEnv and BattleEnv.enemys and BattleEnv.enemys[index]
    return (entry and entry.self) or (BattleEnemys and BattleEnemys[index]), entry
end

local function enemySourceId(index)
    local enemy, entry = getEnemy(index)
    return tonumber((entry and entry.GUID) or (enemy and enemy.NPC_GUID)), enemy
end

local function restore(reason)
    local active = State.active
    if type(active) ~= 'table' then return end
    if active.afterWrapper ~= nil and OnEvent and OnEvent.BattlePlayerAI_after
        and OnEvent.BattlePlayerAI_after.main == active.afterWrapper then
        OnEvent.BattlePlayerAI_after.main = active.afterOriginal
    end
    local source = GameData and GameData.ItemTemp and GameData.ItemTemp[SOURCE_ID]
    if type(source) == 'table' then
        for field, _ in pairs(active.source or {}) do restoreField(active.source, source, field) end
    end
    State.active = nil
    write('cleanup complete: ' .. tostring(reason))
end

local function isEnemyAlive(enemy)
    if enemy == nil then return false end
    local deathCheck = enemy.isDeath
    if type(deathCheck) == 'function' then
        local ok, dead = pcall(deathCheck, enemy)
        if ok then return not dead end
    end
    local data = enemy.NPCData
    return data ~= nil and (tonumber(data.HP) or 1) > 0
end

local function installCaptureObserver(active)
    local event = OnEvent and OnEvent.BattlePlayerAI_after
    if type(event) ~= 'table' or type(event.main) ~= 'function' then
        write('BattlePlayerAI_after observer unavailable; leave without saving')
        return false
    end
    if active.afterWrapper ~= nil then return true end
    local original = event.main
    local wrapper
    wrapper = function(playerIndex)
        local player = BattlePlayers and BattlePlayers[playerIndex]
        local command = tonumber(player and player.AI_Command)
        local targetIndex = tonumber(player and player.AI_Target)
        local enemySide = player and player.AI_TargetIsEnemySide == true
        if isOwnBattle() then
            local envTarget = BattleEnv and BattleEnv.setTarget
            write('BattlePlayerAI_after pre-reset: player=' .. tostring(playerIndex)
                .. ', command=' .. tostring(command) .. ', target=' .. tostring(targetIndex)
                .. ', enemySide=' .. tostring(enemySide) .. ', item=' .. tostring(player and player.AI_SelectItem)
                .. ', envTarget=' .. tostring(envTarget) .. ', aiMode=' .. tostring(player and player.AImode))
        end
        if isOwnBattle() and command == 6 and enemySide and targetIndex and targetIndex > 0 then
            local sourceId, target = enemySourceId(targetIndex)
            if sourceId ~= nil and isEnemyAlive(target) then
                active.pendingCapture = { playerIndex = playerIndex, targetIndex = targetIndex, sourceId = sourceId }
                write('manual 靈契 observed before AI reset: player=' .. tostring(playerIndex)
                    .. ', enemy=' .. tostring(targetIndex) .. ', source=' .. tostring(sourceId))
            end
        end
        return original(playerIndex)
    end
    active.afterOriginal, active.afterWrapper = original, wrapper
    event.main = wrapper
    write('BattlePlayerAI_after observer installed: only high-level manual 靈契 can request a bridge handoff')
    return true
end

local function startProbe()
    if State.active ~= nil then write('F6 ignored: probe battle is already active'); return end
    if not isFormalBridgeReady() then
        write('F6 refused: enable 全魔物靈契 v1.9, restart, and enter a map first')
        return
    end
    local source = GameData and GameData.ItemTemp and GameData.ItemTemp[SOURCE_ID]
    if type(source) ~= 'table' then write('F6 refused: ItemTemp[59] is unavailable'); return end
    local active = { source = {}, armed = false, bridgeCalled = false, battleEntered = false }
    for _, field in ipairs({ 'HP', 'ATK', 'SPD', 'Skills', 'CureSkills', 'SP_AE' }) do snapshotField(active.source, source, field) end
    source.HP, source.ATK, source.SPD = TEST_MAX_HP, 0, 0
    source.Skills, source.CureSkills, source.SP_AE = {}, {}, {}
    State.active = active
    BattleField = BattleField or {}
    BattleScript = BattleScript or {}
    BattleScript[BATTLE_ID] = runBattleScript
    BattleField[BATTLE_ID] = {
        iBattleFieldBackground = 4,
        MusicFileName = 'Battle_Europa01.mp3',
        tCharActQ = { { ItemTempID = SOURCE_ID, X = 176, Y = 294 } }
    }
    local ok, failure = pcall(ESC.StartBattle, BATTLE_ID)
    if not ok then
        restore('StartBattle failed')
        write('F6 StartBattle failed: ' .. tostring(failure))
    end
end

local function onEnemyInit(index)
    if State.active == nil then return end
    local sourceId, enemy = enemySourceId(index)
    local data = enemy and enemy.NPCData
    if index == 1 and sourceId == SOURCE_ID and data ~= nil then
        data.HP, data.MaxHP = TEST_HP, TEST_MAX_HP
        write('Battle_EnemyInit: target HP set to 15/100; source Level remains ' .. tostring(data.Level))
    end
end

local function onBattleEnter()
    if State.active == nil then return end
    local active = State.active
    local source = GameData and GameData.ItemTemp and GameData.ItemTemp[SOURCE_ID]
    local sourceId, target = enemySourceId(1)
    local targetData = target and target.NPCData
    if type(active) ~= 'table' or source == nil or targetData == nil
        or sourceId ~= SOURCE_ID then
        write('Battle_Enter refused: target/source unavailable; targetSource=' .. tostring(sourceId)
            .. ', targetType=' .. type(target) .. ', dataType=' .. type(targetData) .. '; leave without saving')
        return
    end
    local before = tonumber(targetData.Level)
    local original = tonumber(source.Level)
    local player = BattlePlayers and BattlePlayers[1]
    local playerLevel = tonumber(player and player.CharData and player.CharData.Level)
    if before == nil or original == nil or playerLevel == nil then
        write('Battle_Enter refused: Level fields unavailable; leave without saving')
        return
    end
    targetData.Level = original
    if tonumber(targetData.Level) ~= original then
        write('Battle_Enter restore failed; leave without saving')
        return
    end
    active.battleEntered = true
    write('Battle_Enter restored target Level ' .. tostring(before) .. ' -> ' .. tostring(original)
        .. '; formal cap expected ' .. tostring(playerLevel + LEVEL_CAP_OFFSET) .. ', now testing live Lv80')
    installCaptureObserver(active)
end

local function invokeBridge()
    local active = State.active
    local sourceId, target = enemySourceId(1)
    local targetData = target and target.NPCData
    local pending = active and active.pendingCapture
    local player = pending and BattlePlayers and BattlePlayers[pending.playerIndex]
    local playerLevel = tonumber(player and player.CharData and player.CharData.Level)
    if type(active) ~= 'table' or active.bridgeCalled or type(pending) ~= 'table' or not active.battleEntered
        or type(BSC) ~= 'table' or type(BSC.Obsolt) ~= 'function'
        or sourceId ~= tonumber(pending.sourceId) or targetData == nil or playerLevel == nil
        or not isEnemyAlive(target) then
        write('native bridge refused: active handoff state or target is unavailable')
        return false
    end
    if tonumber(targetData.Level) <= playerLevel + LEVEL_CAP_OFFSET then
        write('native bridge skipped: target Level is within native capture range')
        return false
    end
    active.bridgeCalled = true
    write('BSC.Run returned after high-level manual 靈契; invoking native BSC.Obsolt('
        .. tostring(pending.playerIndex) .. ',-' .. tostring(pending.targetIndex) .. ') at target Lv'
        .. tostring(targetData.Level) .. '. Do not press further commands or save.')
    local value = BSC.Obsolt(pending.playerIndex, -pending.targetIndex)
    write('native BSC.Obsolt completed in BattleScript coroutine: value=' .. tostring(value))
    return true
end

runBattleScript = function()
    write('BattleScript entered')
    BSC.Enter(1)
    while isOwnBattle() do
        write('waiting at BSC.Run; manually use 靈契 exactly once on 牛魔王')
        BSC.Run(1)
        if State.active and State.active.pendingCapture then
            invokeBridge()
            return
        end
    end
end

local function onInputClick(_, keyScancode)
    if keyScancode == F6_SCANCODE then
        local ok, failure = pcall(GameFunc.RunScene, -1, 'MCBP_Start', 1)
        if not ok then write('F6 RunScene failed: ' .. tostring(failure)) end
        return true
    end
    return false
end

local function onBattleDead(index, side, mode)
    if isOwnBattle() then write('Battle_Dead: index=' .. tostring(index) .. ', side=' .. tostring(side) .. ', mode=' .. tostring(mode)) end
end

local function onBattleRestoreItem()
    if isOwnBattle() or State.active ~= nil then restore('Battle_RestoreItem') end
end

local function onMapLoading() restore('MapLoading') end
local function onGameStart()
    restore('GameStart')
    write('loaded v0.5: F6 starts the isolated BattleScript handoff test; manually use 靈契 once. It logs the complete pre-reset player command state and only hands off a live target above player +11 when command=6 is observed. Enable only 全魔物靈契 and this probe; do not save.')
end

Scene = Scene or {}
function Scene.MCBP_Start() startProbe() end

OnEvent = OnEvent or {}
OnEvent.GameStart = OnEvent.GameStart or {}
OnEvent.InputClick = OnEvent.InputClick or {}
OnEvent.Battle_EnemyInit = OnEvent.Battle_EnemyInit or {}
OnEvent.Battle_Enter = OnEvent.Battle_Enter or {}
OnEvent.Battle_Dead = OnEvent.Battle_Dead or {}
OnEvent.Battle_RestoreItem = OnEvent.Battle_RestoreItem or {}
OnEvent.MapLoading = OnEvent.MapLoading or {}
if not State.eventsRegistered then
    table.insert(OnEvent.GameStart, onGameStart)
    table.insert(OnEvent.InputClick, onInputClick)
    table.insert(OnEvent.Battle_EnemyInit, onEnemyInit)
    table.insert(OnEvent.Battle_Enter, onBattleEnter)
    table.insert(OnEvent.Battle_Dead, onBattleDead)
    table.insert(OnEvent.Battle_RestoreItem, onBattleRestoreItem)
    table.insert(OnEvent.MapLoading, onMapLoading)
    State.eventsRegistered = true
end
