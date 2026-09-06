-- Steam HD 4.0.x：地圖上按 Home，暫時套用完整戰鬥目錄的靈契前置資格。
-- 必須早於進戰，因原生在 Battle_EnemyInit 前已複製／快取目標資格；不改等級、不發卡、不保存。

SWD3GeneralCaptureEligibilityProbe = SWD3GeneralCaptureEligibilityProbe or {}
local MOD = SWD3GeneralCaptureEligibilityProbe
local HOME_SCANCODE = 74

MOD.state = MOD.state or { eventsRegistered = false, active = nil }
local State = MOD.state

local function write(message)
    if type(log) == 'function' then log('[GeneralCaptureEligibilityProbe] ' .. tostring(message)) end
end

local function captureFieldSnapshot(snapshot, object, field)
    if snapshot[field] == nil then
        snapshot[field] = { present = object[field] ~= nil, value = object[field] }
    end
end

local function restoreFieldSnapshot(snapshot, object, field)
    local saved = snapshot and snapshot[field]
    if saved == nil then return end
    if saved.present then object[field] = saved.value else object[field] = nil end
end

local function itemTotal(item)
    return (tonumber(item and item.Count) or 0) + (tonumber(item and item.Count_New) or 0)
end

local function countItemCopies(itemId)
    local total = 0
    for _, item in ipairs(SaveData and SaveData.Items or {}) do
        if tonumber(item.ItemTempID) == tonumber(itemId) then total = total + itemTotal(item) end
    end
    return total
end

local function restoreBridge(reason)
    local active = State.active
    if active == nil then return false end
    for sourceId, snapshot in pairs(active.sources) do
        local source = GameData and GameData.ItemTemp and GameData.ItemTemp[sourceId]
        if type(source) == 'table' then
            restoreFieldSnapshot(snapshot, source, 'IT_12')
            restoreFieldSnapshot(snapshot, source, 'IT_06')
        end
    end
    for raceId, snapshot in pairs(active.races) do
        local race = GameData and GameData.Race and GameData.Race[raceId]
        if type(race) == 'table' then restoreFieldSnapshot(snapshot, race, 'catch') end
    end
    State.active = nil
    write('pre-battle bridge restored (' .. tostring(reason) .. '): sources=' .. tostring(active.sourceCount)
        .. ', races=' .. tostring(active.raceCount) .. ', skipped=' .. tostring(active.skipped))
    return true
end

local function applyPreBattleBridge()
    if State.active ~= nil then
        write('Home ignored: pre-battle bridge is already active; finish the current battle to restore it')
        return
    end
    local catalogue = SWD3AllMonsterStaticCatalogue and SWD3AllMonsterStaticCatalogue.entries
    if type(catalogue) ~= 'table' then
        write('Home refused: all-monster static catalogue is not loaded; enable swd3_all_monster_static_capture.ssmod first')
        return
    end
    if GameData == nil or type(GameData.ItemTemp) ~= 'table' or type(GameData.Race) ~= 'table' then
        write('Home refused: GameData.ItemTemp or GameData.Race is unavailable')
        return
    end

    local active = { sources = {}, races = {}, baselines = {}, captureCandidates = {}, sourceCount = 0, raceCount = 0, skipped = 0 }
    for sourceId in pairs(catalogue) do
        local source = GameData.ItemTemp[sourceId]
        local raceId = source and tonumber(source.Race) or nil
        local race = raceId and GameData.Race[raceId] or nil
        if type(source) == 'table' and type(race) == 'table' then
            local sourceSnapshot = {}
            active.sources[sourceId] = sourceSnapshot
            active.baselines[sourceId] = countItemCopies(sourceId)
            active.sourceCount = active.sourceCount + 1
            captureFieldSnapshot(sourceSnapshot, source, 'IT_12')
            captureFieldSnapshot(sourceSnapshot, source, 'IT_06')
            source.IT_12 = true
            source.IT_06 = nil

            local raceSnapshot = active.races[raceId]
            if raceSnapshot == nil then
                raceSnapshot = {}
                active.races[raceId] = raceSnapshot
                active.raceCount = active.raceCount + 1
            end
            captureFieldSnapshot(raceSnapshot, race, 'catch')
            race.catch = true
        else
            active.skipped = active.skipped + 1
        end
    end
    if active.sourceCount == 0 then
        write('Home refused: catalogue had no mutable ItemTemp/Race entries; skipped=' .. tostring(active.skipped))
        return
    end
    State.active = active
    write('pre-battle bridge active: sources=' .. tostring(active.sourceCount) .. ', races=' .. tostring(active.raceCount)
        .. ', skipped=' .. tostring(active.skipped) .. '; now enter one normal battle and test 靈契.')
end

local function onInputClick(_, keyScancode)
    if keyScancode ~= HOME_SCANCODE then return false end
    applyPreBattleBridge()
    return true
end

local function onBattleEnemyInit(index)
    if State.active == nil then return end
    local enemy = type(BattleEnemys) == 'table' and BattleEnemys[index] or nil
    write('Battle_EnemyInit observed under pre-battle bridge: index=' .. tostring(index)
        .. ', source=' .. tostring(enemy and enemy.NPC_GUID))
end

local function battleEnemySourceId(index)
    local entry = BattleEnv and BattleEnv.enemys and BattleEnv.enemys[index]
    local enemy = entry and entry.self
    return tonumber((entry and entry.GUID) or (enemy and enemy.NPC_GUID))
end

local function onBattleDead(index, side, mode)
    if State.active == nil or side ~= 1 or mode ~= 2 then return end
    local sourceId = battleEnemySourceId(index)
    if sourceId == nil or State.active.baselines[sourceId] == nil then return end
    State.active.captureCandidates[sourceId] = true
    write('native Battle_Dead(mode=2) observed: source=' .. tostring(sourceId)
        .. '; exchange will be checked after native item addition')
end

local function exchangeCapturedSources(active)
    local helper = SWD3AllMonsterStaticCapture and SWD3AllMonsterStaticCapture.ExchangeCapturedSource
    if type(helper) ~= 'function' then
        write('capture exchange unavailable: static-card helper is not loaded')
        return
    end
    for sourceId in pairs(active.captureCandidates) do
        local ok, status, cardId = helper(sourceId, active.baselines[sourceId])
        if ok then
            write('capture exchange confirmed: source=' .. tostring(sourceId) .. ', card=' .. tostring(cardId)
                .. ', status=' .. tostring(status))
        else
            write('capture exchange unresolved: source=' .. tostring(sourceId) .. ', reason=' .. tostring(status))
        end
    end
end

local function onBattleRestoreItem()
    if State.active ~= nil then exchangeCapturedSources(State.active) end
    restoreBridge('Battle_RestoreItem')
end

local function onMapLoading()
    restoreBridge('MapLoading')
end

local function onGameStart()
    restoreBridge('GameStart')
    write('loaded: on the map press Home, then immediately enter one normal battle; the temporary catalogue-wide bridge restores after that battle')
end

OnEvent = OnEvent or {}
OnEvent.GameStart = OnEvent.GameStart or {}
OnEvent.InputClick = OnEvent.InputClick or {}
OnEvent.Battle_EnemyInit = OnEvent.Battle_EnemyInit or {}
OnEvent.Battle_Dead = OnEvent.Battle_Dead or {}
OnEvent.Battle_RestoreItem = OnEvent.Battle_RestoreItem or {}
OnEvent.MapLoading = OnEvent.MapLoading or {}

if not State.eventsRegistered then
    table.insert(OnEvent.GameStart, onGameStart)
    table.insert(OnEvent.InputClick, onInputClick)
    table.insert(OnEvent.Battle_EnemyInit, onBattleEnemyInit)
    table.insert(OnEvent.Battle_Dead, onBattleDead)
    table.insert(OnEvent.Battle_RestoreItem, onBattleRestoreItem)
    table.insert(OnEvent.MapLoading, onMapLoading)
    State.eventsRegistered = true
end
