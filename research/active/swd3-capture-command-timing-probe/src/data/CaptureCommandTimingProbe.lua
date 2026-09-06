-- Steam HD 4.0.5 戰鬥事件／時序唯讀探針。
-- 只讀取原版 Lua 已使用的戰鬥欄位；不寫入戰鬥、物品、存檔、資料表或 OnEventValue。

SWD3CaptureCommandTimingProbe = SWD3CaptureCommandTimingProbe or {}
local MOD = SWD3CaptureCommandTimingProbe
MOD.state = MOD.state or { eventsRegistered = false, sequence = 0, battleNumber = 0 }
local State = MOD.state

local CATCH_COMMAND = 6 -- Const.AI_CATCH，原版 OnEvent_BattlePlayerAI.lua 定義。
local ORDER_LIMIT = 80
local DEFAULT_EVENT_LIMIT = 12
local EVENT_LIMITS = {
    InputKeyDown = 40,
    InputKeyUp = 20,
    InputClick = 40,
    InputDClick = 20,
    Battle_DrawBGI = 3,
    Battle_InputClick = 40,
    Battle_InputKeyDown = 12,
    BattleEnemyAI = 24,
    BattlePlayerAI = 24,
    BattlePlayerAI_after = 24,
    BattleNPCAI = 24,
    BattleCriticalHitRate = 24,
    BattleEnemyEscapeRate = 24
}

local function write(message)
    if type(log) == 'function' then
        log('[CaptureCommandTimingProbe] ' .. tostring(message))
    end
end

local function asNumber(value, fallback)
    local number = tonumber(value)
    if number == nil then return fallback end
    return number
end

-- 只讀既有欄位。_BattleEnv 的實作由 native 持有；探針不可列舉、寫入或呼叫它的方法。
local function safeField(subject, field, fallback)
    if subject == nil then return fallback end
    local ok, value = pcall(function() return subject[field] end)
    if not ok or value == nil then return fallback end
    return value
end

local function scalar(value, fallback)
    local kind = type(value)
    if kind == 'number' or kind == 'boolean' or kind == 'string' then return tostring(value) end
    if value == nil then return fallback or 'nil' end
    return '<' .. kind .. '>'
end

local function nativeMenuSnapshot()
    -- NowMenu 和 bBattleCmdPause 都被原版 OnEvent_Battle.lua 讀取；此處只記錄它們。
    local nowMenu = safeField(_BattleEnv, 'NowMenu', '?')
    local paused = safeField(_BattleEnv, 'bBattleCmdPause', '?')
    local playerMax = safeField(_BattleEnv, 'PlayerIDMax', '?')
    local enemyMax = safeField(_BattleEnv, 'EnemyIDMax', '?')
    return 'native={NowMenu=' .. scalar(nowMenu, '?')
        .. ', pause=' .. scalar(paused, '?')
        .. ', players=' .. scalar(playerMax, '?')
        .. ', enemys=' .. scalar(enemyMax, '?') .. '}'
end

local function selectionSnapshot()
    return 'selection={ai=' .. scalar(safeField(BattleEnv, 'inSelectAI', '?'), '?')
        .. ', aiKey=' .. scalar(safeField(BattleEnv, 'inSelectAIKeyDown', '?'), '?')
        .. ', commandMenu=' .. scalar(safeField(BattleEnv, 'inCommandMenu', '?'), '?')
        .. ', target=' .. scalar(safeField(BattleEnv, 'setTarget', nil), 'nil') .. '}'
end

local function mouseSnapshot()
    return 'mouse={x=' .. scalar(safeField(InputFunc, 'MouseX', '?'), '?')
        .. ', y=' .. scalar(safeField(InputFunc, 'MouseY', '?'), '?') .. '}'
end

local function safeBattleFieldId()
    if type(GameFunc) ~= 'table' or type(GameFunc.GetBattleFieldID) ~= 'function' then
        return '?'
    end
    local ok, value = pcall(GameFunc.GetBattleFieldID)
    if not ok or value == nil then return '?' end
    return tostring(value)
end

local function resetBattleTrace()
    State.counts = {}
    State.order = {}
    State.suppressed = {}
end

local function ensureBattleTrace()
    if type(State.counts) ~= 'table' then resetBattleTrace() end
end

local function trace(eventName, detail)
    ensureBattleTrace()
    State.sequence = (tonumber(State.sequence) or 0) + 1
    local count = (State.counts[eventName] or 0) + 1
    State.counts[eventName] = count
    if #State.order < ORDER_LIMIT then
        table.insert(State.order, eventName .. '#' .. tostring(count))
    end

    local limit = EVENT_LIMITS[eventName] or DEFAULT_EVENT_LIMIT
    if count <= limit then
        write('#' .. tostring(State.sequence) .. ' ' .. eventName .. '[' .. tostring(count) .. ']: ' .. tostring(detail or ''))
    elseif count == limit + 1 and not State.suppressed[eventName] then
        State.suppressed[eventName] = true
        write('#' .. tostring(State.sequence) .. ' ' .. eventName .. ': trace limit ' .. tostring(limit) .. ' reached; later occurrences stay counted only')
    end
end

local function summarizeBattleTrace()
    ensureBattleTrace()
    local names = {}
    for name in pairs(State.counts) do table.insert(names, name) end
    table.sort(names)
    local counts = {}
    for _, name in ipairs(names) do
        table.insert(counts, name .. '=' .. tostring(State.counts[name]))
    end
    write('battle summary #' .. tostring(State.battleNumber or 0)
        .. ': field=' .. safeBattleFieldId()
        .. '; counts={' .. table.concat(counts, ', ') .. '}')
    write('battle order prefix: ' .. table.concat(State.order, ' -> ')
        .. (#State.order >= ORDER_LIMIT and ' -> ... (prefix limited)' or ''))
end

local function describeActor(actor, preferredStatus)
    local status = preferredStatus or (actor and (actor.NPCData or actor.CharData)) or nil
    return 'source=' .. tostring(asNumber(actor and actor.NPC_GUID, '?'))
        .. ', statusType=' .. type(status)
        .. ', level=' .. tostring(asNumber(status and status.Level, '?'))
        .. ', hp=' .. tostring(asNumber(status and status.HP, '?'))
        .. '/' .. tostring(asNumber(status and status.MaxHP, '?'))
end

local function captureCommandSnapshot()
    local max = asNumber(_BattleEnv and _BattleEnv.PlayerIDMax, 0)
    local entries = {}
    local capture = nil
    for index = 1, max do
        local player = BattlePlayers and BattlePlayers[index] or nil
        if player ~= nil then
            local command = asNumber(player.AI_Command, 0)
            local target = asNumber(player.AI_Target, 0)
            local targetSide = player.AI_TargetIsEnemySide and 'enemy' or 'ally'
            local selectItem = asNumber(player.AI_SelectItem, 0)
            table.insert(entries, string.format('%d:cmd=%d,target=%d,%s,item=%d', index, command, target, targetSide, selectItem))
            if command == CATCH_COMMAND and capture == nil then
                capture = { playerIndex = index, targetIndex = target, targetSide = targetSide }
            end
        end
    end
    return table.concat(entries, '; '), capture
end

local function describeCaptureTarget(capture)
    if type(capture) ~= 'table' or capture.targetSide ~= 'enemy' or capture.targetIndex <= 0 then
        return 'no readable enemy target'
    end
    local enemy = BattleEnemys and BattleEnemys[capture.targetIndex] or nil
    return 'playerIndex=' .. tostring(capture.playerIndex)
        .. ', enemyIndex=' .. tostring(capture.targetIndex)
        .. ', ' .. describeActor(enemy, enemy and enemy.NPCData)
end

local function commandDetail()
    local allCommands, capture = captureCommandSnapshot()
    return nativeMenuSnapshot() .. '; ' .. selectionSnapshot() .. '; ' .. mouseSnapshot()
        .. '; commands={' .. allCommands .. '}; capture='
        .. (capture and describeCaptureTarget(capture) or 'none')
end

local function onBattleEnter()
    State.battleNumber = (tonumber(State.battleNumber) or 0) + 1
    State.battleActive = true
    trace('Battle_Enter', 'field=' .. safeBattleFieldId())
end

-- HD 原版 OnEvent_Input.lua 宣告這四個事件帶 flag 與 scan code。
-- 僅在已進入戰鬥時記錄；不改寫輸入、也不以回傳值取消原生處理。
local function globalInputDetail(keyFuncFlag, keyScancode)
    return 'flag=' .. scalar(keyFuncFlag, 'nil') .. ', scancode=' .. scalar(keyScancode, 'nil')
        .. '; ' .. commandDetail()
end

local function onInputKeyDown(keyFuncFlag, keyScancode)
    if State.battleActive then trace('InputKeyDown', globalInputDetail(keyFuncFlag, keyScancode)) end
end

local function onInputKeyUp(keyFuncFlag, keyScancode)
    if State.battleActive then trace('InputKeyUp', globalInputDetail(keyFuncFlag, keyScancode)) end
end

local function onInputClick(keyFuncFlag, keyScancode)
    if State.battleActive then trace('InputClick', globalInputDetail(keyFuncFlag, keyScancode)) end
end

local function onInputDClick(keyFuncFlag, keyScancode)
    if State.battleActive then trace('InputDClick', globalInputDetail(keyFuncFlag, keyScancode)) end
end

local function onBattleInputKeyDown()
    trace('Battle_InputKeyDown', commandDetail())
end

local function onBattleInputClick(command)
    trace('Battle_InputClick', 'arg=' .. tostring(command) .. '; ' .. commandDetail())
end

local function onBattleInputDClick()
    trace('Battle_InputDClick', commandDetail())
end

local function onCommandSelectOK()
    trace('Battle_CmdSelectOK', commandDetail())
end

local function onBattleDrawBGI(selectIndex)
    trace('Battle_DrawBGI', 'selectIndex=' .. tostring(selectIndex) .. '; ' .. commandDetail())
end

local function onBattleEnemyInit(index)
    local enemy = BattleEnemys and BattleEnemys[index] or nil
    trace('Battle_EnemyInit', 'enemyIndex=' .. tostring(index) .. ', ' .. describeActor(enemy, enemy and enemy.NPCData))
end

local function onBattlePlayerInit(index)
    local player = BattlePlayers and BattlePlayers[index] or nil
    trace('Battle_PlayerInit', 'playerIndex=' .. tostring(index) .. ', ' .. describeActor(player, player and player.CharData))
end

local function onBattleNPCInit(index)
    local npc = BattlePlayers and BattlePlayers[index] or nil
    trace('Battle_NPCInit', 'playerIndex=' .. tostring(index) .. ', ' .. describeActor(npc, npc and npc.NPCData))
end

local function onBattleKeeperInit(index, itemtabIdx)
    local keeper = BattlePlayers and BattlePlayers[index] or nil
    trace('Battle_KeeperInit', 'playerIndex=' .. tostring(index) .. ', itemSlot=' .. tostring(itemtabIdx)
        .. ', ' .. describeActor(keeper, keeper and keeper.NPCData))
end

local function onBattleDead(index, side, mode)
    local actor = side == 1 and BattleEnemys and BattleEnemys[index] or BattlePlayers and BattlePlayers[index]
    trace('Battle_Dead', 'index=' .. tostring(index) .. ', side=' .. tostring(side)
        .. ', mode=' .. tostring(mode) .. ', ' .. describeActor(actor))
end

local function onBattleStopSkill(index, side)
    trace('Battle_StopSkill', 'index=' .. tostring(index) .. ', side=' .. tostring(side))
end

local function onBattleFreeze(index, side)
    trace('Battle_Freeze', 'index=' .. tostring(index) .. ', side=' .. tostring(side))
end

local function onBattleSetActive(index, side, sw)
    trace('Battle_SetActive', 'index=' .. tostring(index) .. ', side=' .. tostring(side) .. ', active=' .. tostring(sw))
end

local function onBattleRestoreItem()
    trace('Battle_RestoreItem', 'field=' .. safeBattleFieldId())
    summarizeBattleTrace()
    State.battleActive = false
    resetBattleTrace()
end

local function onBattleCancelClick()
    trace('Battle_CancelClick', commandDetail())
end

local function onCheckLearnSpecialSkill(index, nowExp)
    trace('CheckLearnSpecialSkill', 'index=' .. tostring(index) .. ', nowExp=' .. tostring(nowExp))
end

local function onCheckStatSpecialSkill(index, nowExp)
    trace('CheckStatSpecialSkill', 'index=' .. tostring(index) .. ', nowExp=' .. tostring(nowExp))
end

local function onBattleCriticalHitRate(beCriticalHit, index, side, targetIndex, targetSide)
    trace('BattleCriticalHitRate', 'base=' .. tostring(beCriticalHit) .. ', index=' .. tostring(index)
        .. ', side=' .. tostring(side) .. ', targetIndex=' .. tostring(targetIndex) .. ', targetSide=' .. tostring(targetSide))
end

local function onBattleEnemyEscapeRate(index, side, playerLevel, escapeRate)
    trace('BattleEnemyEscapeRate', 'index=' .. tostring(index) .. ', side=' .. tostring(side)
        .. ', playerLevel=' .. tostring(playerLevel) .. ', base=' .. tostring(escapeRate))
end

local function onBattleGain(playerExp, money, mItemExp, specialSkillExp)
    trace('BattleGain', 'exp=' .. tostring(playerExp) .. ', money=' .. tostring(money)
        .. ', itemExp=' .. tostring(mItemExp) .. ', skillExp=' .. tostring(specialSkillExp))
end

local function onBattleEnemyAI(index)
    trace('BattleEnemyAI', 'enemyIndex=' .. tostring(index) .. '; ' .. commandDetail())
end

local function onBattlePlayerAI(index)
    trace('BattlePlayerAI', 'playerIndex=' .. tostring(index) .. '; ' .. commandDetail())
end

local function onBattlePlayerAIAfter(index)
    trace('BattlePlayerAI_after', 'playerIndex=' .. tostring(index) .. '; ' .. commandDetail())
end

local function onBattleNPCAI(index)
    trace('BattleNPCAI', 'playerIndex=' .. tostring(index) .. '; ' .. commandDetail())
end

OnEvent = OnEvent or {}
OnEvent.InputKeyDown = OnEvent.InputKeyDown or {}
OnEvent.InputKeyUp = OnEvent.InputKeyUp or {}
OnEvent.InputClick = OnEvent.InputClick or {}
OnEvent.InputDClick = OnEvent.InputDClick or {}
OnEvent.Battle_Enter = OnEvent.Battle_Enter or {}
OnEvent.Battle_InputKeyDown = OnEvent.Battle_InputKeyDown or {}
OnEvent.Battle_InputClick = OnEvent.Battle_InputClick or {}
OnEvent.Battle_InputDClick = OnEvent.Battle_InputDClick or {}
OnEvent.Battle_CmdSelectOK = OnEvent.Battle_CmdSelectOK or {}
OnEvent.Battle_DrawBGI = OnEvent.Battle_DrawBGI or {}
OnEvent.Battle_EnemyInit = OnEvent.Battle_EnemyInit or {}
OnEvent.Battle_PlayerInit = OnEvent.Battle_PlayerInit or {}
OnEvent.Battle_NPCInit = OnEvent.Battle_NPCInit or {}
OnEvent.Battle_KeeperInit = OnEvent.Battle_KeeperInit or {}
OnEvent.Battle_Dead = OnEvent.Battle_Dead or {}
OnEvent.Battle_StopSkill = OnEvent.Battle_StopSkill or {}
OnEvent.Battle_Freeze = OnEvent.Battle_Freeze or {}
OnEvent.Battle_SetActive = OnEvent.Battle_SetActive or {}
OnEvent.Battle_RestoreItem = OnEvent.Battle_RestoreItem or {}
OnEvent.Battle_CancelClick = OnEvent.Battle_CancelClick or {}
OnEvent.CheckLearnSpecialSkill = OnEvent.CheckLearnSpecialSkill or {}
OnEvent.CheckStatSpecialSkill = OnEvent.CheckStatSpecialSkill or {}
OnEvent.BattleCriticalHitRate = OnEvent.BattleCriticalHitRate or {}
OnEvent.BattleEnemyEscapeRate = OnEvent.BattleEnemyEscapeRate or {}
OnEvent.BattleGain = OnEvent.BattleGain or {}
OnEvent.BattleEnemyAI = OnEvent.BattleEnemyAI or {}
OnEvent.BattlePlayerAI = OnEvent.BattlePlayerAI or {}
OnEvent.BattlePlayerAI_after = OnEvent.BattlePlayerAI_after or {}
OnEvent.BattleNPCAI = OnEvent.BattleNPCAI or {}

if not State.eventsRegistered then
    table.insert(OnEvent.InputKeyDown, onInputKeyDown)
    table.insert(OnEvent.InputKeyUp, onInputKeyUp)
    table.insert(OnEvent.InputClick, onInputClick)
    table.insert(OnEvent.InputDClick, onInputDClick)
    table.insert(OnEvent.Battle_Enter, onBattleEnter)
    table.insert(OnEvent.Battle_InputKeyDown, onBattleInputKeyDown)
    table.insert(OnEvent.Battle_InputClick, onBattleInputClick)
    table.insert(OnEvent.Battle_InputDClick, onBattleInputDClick)
    table.insert(OnEvent.Battle_CmdSelectOK, onCommandSelectOK)
    table.insert(OnEvent.Battle_DrawBGI, onBattleDrawBGI)
    table.insert(OnEvent.Battle_EnemyInit, onBattleEnemyInit)
    table.insert(OnEvent.Battle_PlayerInit, onBattlePlayerInit)
    table.insert(OnEvent.Battle_NPCInit, onBattleNPCInit)
    table.insert(OnEvent.Battle_KeeperInit, onBattleKeeperInit)
    table.insert(OnEvent.Battle_Dead, onBattleDead)
    table.insert(OnEvent.Battle_StopSkill, onBattleStopSkill)
    table.insert(OnEvent.Battle_Freeze, onBattleFreeze)
    table.insert(OnEvent.Battle_SetActive, onBattleSetActive)
    table.insert(OnEvent.Battle_RestoreItem, onBattleRestoreItem)
    table.insert(OnEvent.Battle_CancelClick, onBattleCancelClick)
    table.insert(OnEvent.CheckLearnSpecialSkill, onCheckLearnSpecialSkill)
    table.insert(OnEvent.CheckStatSpecialSkill, onCheckStatSpecialSkill)
    table.insert(OnEvent.BattleCriticalHitRate, onBattleCriticalHitRate)
    table.insert(OnEvent.BattleEnemyEscapeRate, onBattleEnemyEscapeRate)
    table.insert(OnEvent.BattleGain, onBattleGain)
    table.insert(OnEvent.BattleEnemyAI, onBattleEnemyAI)
    table.insert(OnEvent.BattlePlayerAI, onBattlePlayerAI)
    table.insert(OnEvent.BattlePlayerAI_after, onBattlePlayerAIAfter)
    table.insert(OnEvent.BattleNPCAI, onBattleNPCAI)
    State.eventsRegistered = true
end

write('loaded: read-only command-routing trace is armed; records HD global and battle input, NowMenu, selection and mouse without changing battle state')
