-- Steam HD 4.0.5：F4 建立 Lv80、HP 15% 隔離戰，驗證戰鬥副本等級上限為主角 +11。
-- 除了該隔離戰必需的 HP／Level 設定外，本檔只讀取並記錄靈契前後 callback；
-- 不寫入戰鬥指令、收妖機率或 OnEventValue，不能把時間軸誤認為可控制收妖的入口。

SWD3HighLevelCaptureRateProbe = SWD3HighLevelCaptureRateProbe or {}
local MOD = SWD3HighLevelCaptureRateProbe
local F4_SCANCODE = 61
local F5_SCANCODE = 62
local BATTLE_ID = 'HLCRP_BULL_DEMON_RATE'
local SOURCE_ID = 59
local TEST_MAX_HP = 100
local TEST_HP = 15
local LEVEL_CAP_OFFSET = 11
local TRACE_LINE_LIMIT = 80

MOD.state = MOD.state or { eventsRegistered = false, active = nil }
local State = MOD.state
local installCaptureCallTrace
local runBattleScriptProbe

local function write(message)
    if type(log) == 'function' then log('[HighLevelCaptureRateProbe] ' .. tostring(message)) end
end

local function traceEvent(active, name, details, perEventPrintLimit)
    if type(active) ~= 'table' then return end
    active.timeline = active.timeline or { sequence = 0, counts = {}, suppressed = false }
    local timeline = active.timeline
    timeline.sequence = timeline.sequence + 1
    timeline.counts[name] = (timeline.counts[name] or 0) + 1
    local printable = timeline.sequence <= TRACE_LINE_LIMIT
        and (perEventPrintLimit == nil or timeline.counts[name] <= perEventPrintLimit)
    if printable then
        write('event #' .. tostring(timeline.sequence) .. ': ' .. tostring(name)
            .. (details and ('; ' .. tostring(details)) or ''))
    elseif not timeline.suppressed and timeline.sequence > TRACE_LINE_LIMIT then
        timeline.suppressed = true
        write('event trace reached ' .. tostring(TRACE_LINE_LIMIT) .. ' lines; later events remain counted only')
    end
end

local function timelineSummary(active, reason)
    local timeline = active and active.timeline
    if type(timeline) ~= 'table' then return end
    local names = {}
    for name in pairs(timeline.counts or {}) do table.insert(names, name) end
    table.sort(names)
    local parts = {}
    for _, name in ipairs(names) do table.insert(parts, name .. '=' .. tostring(timeline.counts[name])) end
    write('event summary (' .. tostring(reason) .. '): total=' .. tostring(timeline.sequence)
        .. '; ' .. table.concat(parts, ', '))
end

local function reportNativeCaptureBridge()
    local globals = _G
    local bsc = type(globals) == 'table' and rawget(globals, 'BSC') or nil
    local battleScript = type(globals) == 'table' and rawget(globals, 'BattleScript') or nil
    write('native capture bridge inventory: BSC=' .. type(bsc)
        .. ', BSC.Obsolt=' .. type(bsc and bsc.Obsolt)
        .. ', BattleScript=' .. type(battleScript))
end

local function snapshotField(snapshot, object, field)
    snapshot[field] = { present = object[field] ~= nil, value = object[field] }
end

local function restoreField(snapshot, object, field)
    local saved = snapshot and snapshot[field]
    if saved == nil then return end
    if saved.present then object[field] = saved.value else object[field] = nil end
end

local function restoreProbe(reason)
    local active = State.active
    if type(active) ~= 'table' then return end
    local trace = active.captureTrace
    if type(trace) == 'table' and type(Function) == 'table' and Function.CheckObsolt == trace.wrapper then
        Function.CheckObsolt = trace.original
        write('capture call trace restored (' .. tostring(reason) .. '): observed calls=' .. tostring(trace.calls))
    end
    local level = active.battleLevel
    if type(level) == 'table' and level.applied and level.status ~= nil then
        pcall(function() level.status.Level = level.original end)
    end
    local source = GameData and GameData.ItemTemp and GameData.ItemTemp[SOURCE_ID]
    if type(source) == 'table' then
        for _, field in ipairs({ 'HP', 'ATK', 'SPD', 'Skills', 'CureSkills', 'SP_AE' }) do
            restoreField(active.source, source, field)
        end
    end
    timelineSummary(active, reason)
    State.active = nil
    write('probe restored (' .. tostring(reason) .. '): source Level=' .. tostring(source and source.Level)
        .. ', HP=' .. tostring(source and source.HP) .. ', ATK=' .. tostring(source and source.ATK))
end

local function isFormalCaptureReady()
    local capture = SWD3AllMonsterStaticCapture
    return type(capture) == 'table' and type(capture.captureRuntime) == 'table'
        and type(capture.captureRuntime.active) == 'table' and type(Function) == 'table'
        and type(Function.CheckObsolt) == 'function'
end

local function startProbe()
    if State.active ~= nil then write('F4 ignored: test battle is already active'); return end
    if not isFormalCaptureReady() then
        write('F4 refused: 全魔物靈契 v1.8 bridge or CheckObsolt is not ready; enter a map after a full restart')
        return
    end
    local source = GameData and GameData.ItemTemp and GameData.ItemTemp[SOURCE_ID]
    if type(source) ~= 'table' then write('F4 refused: ItemTemp[59] is unavailable'); return end
    local active = {
        source = {}, rateChecked = false, hpApplied = false, success = false,
        captureTrace = nil, battleLevel = nil, timeline = { sequence = 0, counts = {}, suppressed = false }
    }
    for _, field in ipairs({ 'HP', 'ATK', 'SPD', 'Skills', 'CureSkills', 'SP_AE' }) do
        snapshotField(active.source, source, field)
    end
    source.HP, source.ATK, source.SPD = TEST_MAX_HP, 0, 0
    source.Skills, source.CureSkills, source.SP_AE = {}, {}, {}
    State.active = active
    traceEvent(active, 'ProbeStart', 'F4 isolated battle requested')
    BattleField = BattleField or {}
    BattleScript = BattleScript or {}
    BattleScript[BATTLE_ID] = runBattleScriptProbe
    BattleField[BATTLE_ID] = {
        iBattleFieldBackground = 4,
        MusicFileName = 'Battle_Europa01.mp3',
        tCharActQ = { { ItemTempID = SOURCE_ID, X = 176, Y = 294 } }
    }
    local started, failure = pcall(ESC.StartBattle, BATTLE_ID)
    if not started then
        restoreProbe('StartBattle failed')
        write('F4 StartBattle failed: ' .. tostring(failure))
        return
    end
    write('test battle started: source=59 remains Lv' .. tostring(source.Level)
        .. '; target will be set to HP ' .. tostring(TEST_HP) .. '/' .. tostring(TEST_MAX_HP)
        .. '; BattleScript will restore the target Level to Lv80 and invoke the native capture bridge automatically')
end

local function restoreTargetLevelForTimingTest()
    local active = State.active
    if type(active) ~= 'table' or not active.rateChecked then
        write('F5 ignored: start the F4 probe and wait for PASS native formula first')
        return true
    end
    if active.timingRestoreApplied then
        return false
    end
    local target = BattleEnemys and BattleEnemys[1]
    local targetData = target and target.NPCData
    local source = GameData and GameData.ItemTemp and GameData.ItemTemp[SOURCE_ID]
    local originalLevel = tonumber(source and source.Level)
    local beforeLevel = tonumber(targetData and targetData.Level)
    if tonumber(target and target.NPC_GUID) ~= SOURCE_ID or targetData == nil or originalLevel == nil or beforeLevel == nil then
        write('F5 refused: isolated target or original source Level is unavailable; leave battle and do not save')
        return true
    end
    local ok, failure = pcall(function() targetData.Level = originalLevel end)
    if not ok or tonumber(targetData.Level) ~= originalLevel then
        write('F5 restore failed: ' .. tostring(failure) .. '; leave battle and do not save')
        return true
    end
    active.timingRestoreApplied = true
    traceEvent(active, 'F5_RestoreTargetLevel', 'enemy battle Level=' .. tostring(beforeLevel)
        .. ' -> ' .. tostring(targetData.Level) .. '; now attempt one manual 靈契 without any attack')
    write('TIMING TEST ARMED: target Level is restored before manual 靈契. Success means capture eligibility may have been cached before this point; failure means native capture still reads the live Level. This is an isolated experiment only.')
    return true
end

local function invokeNativeCaptureBridge()
    local active = State.active
    if type(active) ~= 'table' or not active.timingRestoreApplied then
        write('native BSC.Obsolt refused: first F5 must restore the isolated target to Lv80')
        return
    end
    if active.nativeBridgeInvoked then
        write('native BSC.Obsolt ignored: this isolated battle already made its one native call')
        return
    end
    local target = BattleEnemys and BattleEnemys[1]
    local targetData = target and target.NPCData
    local source = GameData and GameData.ItemTemp and GameData.ItemTemp[SOURCE_ID]
    local playerRef = Const and tonumber(Const.BPLAY1) or nil
    local enemyRef = Const and tonumber(Const.BMS1) or nil
    local bsc = type(_G) == 'table' and rawget(_G, 'BSC') or nil
    if type(bsc) ~= 'table' or type(bsc.Obsolt) ~= 'function'
        or playerRef ~= 1 or enemyRef ~= -1
        or tonumber(target and target.NPC_GUID) ~= SOURCE_ID
        or tonumber(targetData and targetData.Level) ~= tonumber(source and source.Level) then
        write('native BSC.Obsolt refused: binding, original target Level, or original signed battle references are unavailable')
        return
    end
    active.nativeBridgeInvoked = true
    traceEvent(active, 'BSC.Obsolt', 'calling original native bridge with playerRef=1, enemyRef=-1, targetLevel='
        .. tostring(targetData.Level) .. '; do not save even if it succeeds')
    write('NATIVE BRIDGE TEST: BattleScript coroutine is invoking BSC.Obsolt once in the F4-only battle. It may end the battle immediately; do not press any other command and do not save.')
    local result = bsc.Obsolt(playerRef, enemyRef)
    write('BSC.Obsolt completed in BattleScript coroutine: value=' .. tostring(result))
end

Scene = Scene or {}
function Scene.HLCRP_Start() startProbe() end
function Scene.HLCRP_InvokeNativeCapture()
    write('native BSC.Obsolt Scene coroutine entered')
    invokeNativeCaptureBridge()
end

runBattleScriptProbe = function()
    local active = State.active
    if type(active) ~= 'table' then return end
    write('native BSC.Obsolt BattleScript coroutine entered')
    if type(BSC) ~= 'table' or type(BSC.Enter) ~= 'function' then
        write('native BSC.Obsolt BattleScript refused: BSC.Enter is unavailable')
        return
    end
    BSC.Enter(1)
    active = State.active
    local target = BattleEnemys and BattleEnemys[1]
    local targetData = target and target.NPCData
    local source = GameData and GameData.ItemTemp and GameData.ItemTemp[SOURCE_ID]
    local originalLevel = tonumber(source and source.Level)
    local beforeLevel = tonumber(targetData and targetData.Level)
    if type(active) ~= 'table' or tonumber(target and target.NPC_GUID) ~= SOURCE_ID
        or targetData == nil or originalLevel == nil or beforeLevel == nil then
        write('native BSC.Obsolt BattleScript refused: isolated target is unavailable after BSC.Enter')
        return
    end
    local ok, failure = pcall(function() targetData.Level = originalLevel end)
    if not ok or tonumber(targetData.Level) ~= originalLevel then
        write('native BSC.Obsolt BattleScript Level restore failed: ' .. tostring(failure))
        return
    end
    active.timingRestoreApplied = true
    traceEvent(active, 'BattleScript_RestoreTargetLevel', 'enemy battle Level=' .. tostring(beforeLevel)
        .. ' -> ' .. tostring(targetData.Level) .. '; native bridge will run in this coroutine')
    invokeNativeCaptureBridge()
end

local function scheduleNativeCaptureBridge()
    if type(GameFunc) ~= 'table' or type(GameFunc.RunScene) ~= 'function' then
        write('native BSC.Obsolt refused: GameFunc.RunScene is unavailable for coroutine scheduling')
        return
    end
    write('native BSC.Obsolt scheduling requested via GameFunc.RunScene')
    local ok, result = pcall(GameFunc.RunScene, -1, 'HLCRP_InvokeNativeCapture', 1)
    write('native BSC.Obsolt RunScene call returned: ok=' .. tostring(ok) .. ', value=' .. tostring(result))
end

local function onInputClick(_, keyScancode)
    if keyScancode == F4_SCANCODE then
        local ok, failure = pcall(GameFunc.RunScene, -1, 'HLCRP_Start', 1)
        if not ok then write('F4 RunScene failed: ' .. tostring(failure)) end
        return true
    end
    if keyScancode == F5_SCANCODE then
        if not restoreTargetLevelForTimingTest() then
            write('second F5 received: scheduling native BSC.Obsolt Scene coroutine')
            scheduleNativeCaptureBridge()
        end
        return State.active ~= nil
    end
    return false
end

local function onBattleEnemyInit(index)
    local active = State.active
    local enemy = BattleEnemys and BattleEnemys[index]
    if type(active) ~= 'table' or tonumber(enemy and enemy.NPC_GUID) ~= SOURCE_ID then return end
    traceEvent(active, 'Battle_EnemyInit', 'index=' .. tostring(index) .. ', source=' .. tostring(enemy.NPC_GUID))
    local status = enemy and enemy.NPCData
    if status == nil then write('enemy init failed: NPCData is unavailable'); return end
    local beforeHP, beforeMaxHP = status.HP, status.MaxHP
    local ok, failure = pcall(function() status.HP = TEST_HP end)
    if not ok then
        write('enemy HP setup failed: ' .. tostring(failure) .. '; stop this test and do not save')
        return
    end
    active.hpApplied = tonumber(status.HP) == TEST_HP and tonumber(status.MaxHP) == TEST_MAX_HP
    write('enemy HP setup: Level=' .. tostring(status.Level) .. ', HP=' .. tostring(beforeHP) .. '/' .. tostring(beforeMaxHP)
        .. ' -> ' .. tostring(status.HP) .. '/' .. tostring(status.MaxHP) .. '; applied=' .. tostring(active.hpApplied))
end

installCaptureCallTrace = function(active)
    if type(active.captureTrace) == 'table' then return Function.CheckObsolt == active.captureTrace.wrapper end
    if type(Function) ~= 'table' or type(Function.CheckObsolt) ~= 'function' then
        write('capture call trace unavailable: Function.CheckObsolt is not ready')
        return false
    end
    local original = Function.CheckObsolt
    local trace = { original = original, calls = 0 }
    local function wrappedCheckObsolt(player, target)
        local rate = original(player, target)
        trace.calls = trace.calls + 1
        local playerData = player and player.CharData
        local targetData = target and target.NPCData
        write('CheckObsolt call #' .. tostring(trace.calls)
            .. ': playerLevel=' .. tostring(playerData and playerData.Level)
            .. ', source=' .. tostring(target and target.NPC_GUID)
            .. ', enemyLevel=' .. tostring(targetData and targetData.Level)
            .. ', HP=' .. tostring(targetData and targetData.HP) .. '/' .. tostring(targetData and targetData.MaxHP)
            .. ', rate=' .. tostring(rate))
        return rate
    end
    trace.wrapper = wrappedCheckObsolt
    active.captureTrace = trace
    Function.CheckObsolt = wrappedCheckObsolt
    write('capture call trace armed: call #1 is the probe baseline; do one manual 靈契 only after PASS formula')
    return true
end

local function onBattleEnter()
    local active = State.active
    if type(active) ~= 'table' or active.rateChecked then return end
    traceEvent(active, 'Battle_Enter', 'isolated target setup and baseline rate check')
    reportNativeCaptureBridge()
    active.rateChecked = true
    local player = BattlePlayers and BattlePlayers[1]
    local target = BattleEnemys and BattleEnemys[1]
    local playerData = player and player.CharData
    local targetData = target and target.NPCData
    local playerLevel = tonumber(playerData and playerData.Level)
    local beforeLevel = tonumber(targetData and targetData.Level)
    local capLevel = playerLevel and playerLevel + LEVEL_CAP_OFFSET or nil
    if player == nil or target == nil or not active.hpApplied or capLevel == nil or beforeLevel == nil then
        write('level-cap setup unavailable: player/target/15% setup or levels are missing; leave battle and do not save')
        return
    end
    if beforeLevel > capLevel then
        local ok, failure = pcall(function() targetData.Level = capLevel end)
        if not ok or tonumber(targetData.Level) ~= capLevel then
            write('level-cap setup failed: ' .. tostring(failure) .. '; leave battle and do not save')
            return
        end
        active.battleLevel = { status = targetData, original = beforeLevel, applied = true }
        write('battle level cap applied: source remains Lv' .. tostring(GameData.ItemTemp[SOURCE_ID].Level)
            .. '; enemy battle Level=' .. tostring(beforeLevel) .. ' -> ' .. tostring(targetData.Level)
            .. ' (player ' .. tostring(playerLevel) .. ' + ' .. tostring(LEVEL_CAP_OFFSET) .. ')')
    else
        write('battle level cap not needed: enemy battle Level=' .. tostring(beforeLevel)
            .. ' <= player ' .. tostring(playerLevel) .. ' + ' .. tostring(LEVEL_CAP_OFFSET))
    end
    if not installCaptureCallTrace(active) then
        write('FAIL setup: CheckObsolt call trace is unavailable at Battle_Enter; leave battle and do not save')
        return
    end
    local ok, rate = pcall(Function.CheckObsolt, player, target)
    if not ok then write('rate check failed: ' .. tostring(rate)); return end
    write('rate check: playerLevel=' .. tostring(playerLevel) .. ', enemyLevel=' .. tostring(targetData and targetData.Level)
        .. ', HP=' .. tostring(targetData and targetData.HP) .. '/' .. tostring(targetData and targetData.MaxHP)
        .. ', CheckObsolt=' .. tostring(rate) .. '%')
    if tonumber(rate) == 100 then
        write('PASS native formula: player +11 and HP 15% use the original 100% capture branch. Now manually use 靈契 once.')
    else
        write('FAIL native formula: expected 100%; do not test capture, leave battle and report this Console block')
    end
end

local function onBattleDead(index, side, mode)
    local active = State.active
    if type(active) ~= 'table' then return end
    traceEvent(active, 'Battle_Dead', 'index=' .. tostring(index) .. ', side=' .. tostring(side) .. ', mode=' .. tostring(mode))
    if side ~= 1 or mode ~= 2 or index ~= 1 then return end
    active.success = true
    write('NATIVE CAPTURE SUCCESS: Battle_Dead(mode=2) observed after manual 靈契')
end

local function onBattleInputClick(cmd)
    local active = State.active
    traceEvent(active, 'Battle_InputClick', 'cmd=' .. tostring(cmd))
end

local function onBattleCmdSelectOK()
    traceEvent(State.active, 'Battle_CmdSelectOK', 'native command confirmation callback')
end

local function onBattleCancelClick()
    traceEvent(State.active, 'Battle_CancelClick', 'native battle command cancellation callback')
end

local function onBattleDrawBGI(selectIndex)
    traceEvent(State.active, 'Battle_DrawBGI', 'selectIndex=' .. tostring(selectIndex), 3)
end

local function onBattlePlayerAI(index)
    traceEvent(State.active, 'Battle_PlayerAI', 'index=' .. tostring(index), 6)
end

local function onBattlePlayerAIAfter(index)
    traceEvent(State.active, 'Battle_PlayerAI_after', 'index=' .. tostring(index), 6)
end

local function onBattleEnemyAI(index)
    traceEvent(State.active, 'Battle_EnemyAI', 'index=' .. tostring(index), 6)
end

local function onBattleNPCAI(index)
    traceEvent(State.active, 'Battle_NPCAI', 'index=' .. tostring(index), 6)
end

local function onBattleCriticalHitRate(beCriticalHit, index, side, targetIndex, targetSide)
    traceEvent(State.active, 'BattleCriticalHitRate', 'input=' .. tostring(beCriticalHit)
        .. ', source=' .. tostring(index) .. '/' .. tostring(side)
        .. ', target=' .. tostring(targetIndex) .. '/' .. tostring(targetSide), 12)
end

local function onBattleRestoreItem()
    traceEvent(State.active, 'Battle_RestoreItem', 'battle cleanup callback')
    restoreProbe('Battle_RestoreItem')
end

local function onMapLoading()
    traceEvent(State.active, 'MapLoading', 'map transition callback')
    restoreProbe('MapLoading')
end
local function onGameStart()
    restoreProbe('GameStart')
    write('loaded v1.0: F4 starts one Lv80 牛魔王 at 15% HP and traces capture-related callbacks; after PASS native formula, press F5 before any action to restore Lv80 and test whether native capture eligibility was cached. Enable only this probe and 全魔物靈契 v1.9, then do not save')
end

OnEvent = OnEvent or {}
OnEvent.GameStart = OnEvent.GameStart or {}
OnEvent.InputClick = OnEvent.InputClick or {}
OnEvent.Battle_EnemyInit = OnEvent.Battle_EnemyInit or {}
OnEvent.Battle_Enter = OnEvent.Battle_Enter or {}
OnEvent.Battle_InputClick = OnEvent.Battle_InputClick or {}
OnEvent.Battle_CmdSelectOK = OnEvent.Battle_CmdSelectOK or {}
OnEvent.Battle_CancelClick = OnEvent.Battle_CancelClick or {}
OnEvent.Battle_DrawBGI = OnEvent.Battle_DrawBGI or {}
OnEvent.Battle_PlayerAI = OnEvent.Battle_PlayerAI or {}
OnEvent.Battle_PlayerAI_after = OnEvent.Battle_PlayerAI_after or {}
OnEvent.Battle_EnemyAI = OnEvent.Battle_EnemyAI or {}
OnEvent.Battle_NPCAI = OnEvent.Battle_NPCAI or {}
OnEvent.BattleCriticalHitRate = OnEvent.BattleCriticalHitRate or {}
OnEvent.Battle_Dead = OnEvent.Battle_Dead or {}
OnEvent.Battle_RestoreItem = OnEvent.Battle_RestoreItem or {}
OnEvent.MapLoading = OnEvent.MapLoading or {}
if not State.eventsRegistered then
    table.insert(OnEvent.GameStart, onGameStart)
    table.insert(OnEvent.InputClick, onInputClick)
    table.insert(OnEvent.Battle_EnemyInit, onBattleEnemyInit)
    table.insert(OnEvent.Battle_Enter, onBattleEnter)
    table.insert(OnEvent.Battle_InputClick, onBattleInputClick)
    table.insert(OnEvent.Battle_CmdSelectOK, onBattleCmdSelectOK)
    table.insert(OnEvent.Battle_CancelClick, onBattleCancelClick)
    table.insert(OnEvent.Battle_DrawBGI, onBattleDrawBGI)
    table.insert(OnEvent.Battle_PlayerAI, onBattlePlayerAI)
    table.insert(OnEvent.Battle_PlayerAI_after, onBattlePlayerAIAfter)
    table.insert(OnEvent.Battle_EnemyAI, onBattleEnemyAI)
    table.insert(OnEvent.Battle_NPCAI, onBattleNPCAI)
    table.insert(OnEvent.BattleCriticalHitRate, onBattleCriticalHitRate)
    table.insert(OnEvent.Battle_Dead, onBattleDead)
    table.insert(OnEvent.Battle_RestoreItem, onBattleRestoreItem)
    table.insert(OnEvent.MapLoading, onMapLoading)
    State.eventsRegistered = true
end
