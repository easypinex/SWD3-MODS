-- Steam HD 4.0.5：以牛魔王 ID 59 驗證高等目標的靈契等級門檻。
-- F7 只建立隔離戰，暫改收妖資格與 Level；不改任何戰鬥數值、技能、掉落或背包。

SWD3HighLevelCaptureGateProbe = SWD3HighLevelCaptureGateProbe or {}
local MOD = SWD3HighLevelCaptureGateProbe
local F5_SCANCODE = 62
local F7_SCANCODE = 64
local BATTLE_ID = 'HLCGP_BULL_DEMON_LEVEL'
local SOURCE_ID = 59
local CAPTURE_LEVEL = 1

MOD.state = MOD.state or { eventsRegistered = false, active = nil }
local State = MOD.state

local function write(message)
    if type(log) == 'function' then log('[HighLevelCaptureGateProbe] ' .. tostring(message)) end
end

local function snapshotField(snapshot, object, field)
    snapshot[field] = { present = object[field] ~= nil, value = object[field] }
end

local function restoreField(snapshot, object, field)
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
        if tonumber(item and item.ItemTempID) == tonumber(itemId) then total = total + itemTotal(item) end
    end
    return total
end

local function restoreProbe(reason)
    local active = State.active
    if type(active) ~= 'table' then return end
    local source = GameData and GameData.ItemTemp and GameData.ItemTemp[SOURCE_ID]
    local race = source and GameData and GameData.Race and GameData.Race[source.Race]
    if type(source) == 'table' then
        restoreField(active.source, source, 'IT_12')
        restoreField(active.source, source, 'IT_06')
        restoreField(active.source, source, 'Level')
    end
    if type(race) == 'table' then restoreField(active.race, race, 'catch') end
    State.active = nil
    write('probe restored (' .. tostring(reason) .. '): ItemTemp[59].Level=' .. tostring(source and source.Level)
        .. ', ATK=' .. tostring(source and source.ATK) .. ', HP=' .. tostring(source and source.HP))
end

local function applyProbe()
    local source = GameData and GameData.ItemTemp and GameData.ItemTemp[SOURCE_ID]
    local race = source and GameData and GameData.Race and GameData.Race[source.Race]
    if type(source) ~= 'table' or type(race) ~= 'table' then
        return nil, 'source ItemTemp[59] or its Race is unavailable'
    end
    local active = { source = {}, race = {} }
    snapshotField(active.source, source, 'IT_12')
    snapshotField(active.source, source, 'IT_06')
    snapshotField(active.source, source, 'Level')
    snapshotField(active.race, race, 'catch')
    source.IT_12 = true
    source.IT_06 = nil
    source.Level = CAPTURE_LEVEL
    race.catch = true
    active.sourceBaseline = countItemCopies(SOURCE_ID)
    active.captureObserved = false
    State.active = active
    write('bridge applied before battle: source=59, originalLevel=' .. tostring(active.source.Level.value)
        .. ', captureLevel=1, IT_12=true, IT_06=nil, Race.catch=true; combat fields untouched: HP='
        .. tostring(source.HP) .. ', ATK=' .. tostring(source.ATK) .. ', DEF=' .. tostring(source.DEF)
        .. ', SPD=' .. tostring(source.SPD))
    return true
end

local function startProbe()
    if State.active ~= nil then write('F7 ignored: probe is already active'); return end
    if type(SWD3AllMonsterStaticCatalogue) ~= 'table' or type(SWD3AllMonsterStaticCatalogue.Get) ~= 'function' then
        write('F7 refused: static capture catalogue is not loaded')
        return
    end
    local entry = SWD3AllMonsterStaticCatalogue.Get(SOURCE_ID)
    if entry == nil or entry.cardId == SOURCE_ID then
        write('F7 refused: expected a static mapping for source ID 59')
        return
    end
    BattleField = BattleField or {}
    BattleField[BATTLE_ID] = {
        iBattleFieldBackground = 4,
        MusicFileName = 'Battle_Europa01.mp3',
        tCharActQ = { { ItemTempID = SOURCE_ID, X = 176, Y = 294 } }
    }
    local applied, failure = applyProbe()
    if not applied then write('F7 refused: ' .. tostring(failure)); return end
    local started, startFailure = pcall(ESC.StartBattle, BATTLE_ID)
    if not started then
        restoreProbe('StartBattle failed')
        write('StartBattle failed: ' .. tostring(startFailure))
        return
    end
    write('牛魔王 battle started: use 靈契 only to test target selection, then cancel or escape. Do not attack, capture, or save.')
end

Scene = Scene or {}
function Scene.HLCGP_StartProbe() startProbe() end

local function onInputClick(_, keyScancode)
    if keyScancode == F5_SCANCODE then
        if State.active ~= nil then
            write('F5 recovery refused: finish the active probe battle first')
            return true
        end
        local catalogue = SWD3AllMonsterStaticCatalogue
        local entry = catalogue and catalogue.Get and catalogue.Get(SOURCE_ID)
        if type(entry) ~= 'table' or tonumber(entry.cardId) == SOURCE_ID then
            write('F5 recovery refused: static mapping 59 → 10024 is unavailable')
            return true
        end
        if countItemCopies(SOURCE_ID) < 1 then
            write('F5 recovery skipped: no source ID 59 is in the backpack')
            return true
        end
        if type(ItemClass) ~= 'table' or type(ItemClass.DelItem) ~= 'function' or type(ItemClass.AddItem) ~= 'function' then
            write('F5 recovery refused: native item functions are unavailable')
            return true
        end
        ItemClass.DelItem(SOURCE_ID, 1)
        ItemClass.AddItem(entry.cardId, 1)
        write('F5 recovery confirmed: exchanged one explicit source ID 59 for static card ID ' .. tostring(entry.cardId))
        return true
    end
    if keyScancode ~= F7_SCANCODE then return false end
    local ok, failure = pcall(GameFunc.RunScene, -1, 'HLCGP_StartProbe', 1)
    if not ok then write('F7 RunScene failed: ' .. tostring(failure)) end
    return true
end

local function onBattleEnemyInit(index)
    if State.active == nil then return end
    local enemy = type(BattleEnemys) == 'table' and BattleEnemys[index] or nil
    if tonumber(enemy and enemy.NPC_GUID) == SOURCE_ID then
        write('Battle_EnemyInit observed: NPCData.Level=' .. tostring(enemy.NPCData and enemy.NPCData.Level)
            .. '; source combat fields remain HP=' .. tostring(GameData.ItemTemp[SOURCE_ID].HP)
            .. ', ATK=' .. tostring(GameData.ItemTemp[SOURCE_ID].ATK))
    end
end

local function onBattleDead(index, side, mode)
    if State.active == nil or side ~= 1 or mode ~= 2 then return end
    local entry = BattleEnv and BattleEnv.enemys and BattleEnv.enemys[index]
    local enemy = entry and entry.self
    if tonumber((entry and entry.GUID) or (enemy and enemy.NPC_GUID)) == SOURCE_ID then
        State.active.captureObserved = true
        write('native Battle_Dead(mode=2) observed; exchange will be checked after native source-item addition')
    end
end

local function exchangeCapturedSource()
    local active = State.active
    if type(active) ~= 'table' or not active.captureObserved then return end
    local helper = SWD3AllMonsterStaticCapture and SWD3AllMonsterStaticCapture.ExchangeCapturedSource
    if type(helper) ~= 'function' then
        write('capture exchange unavailable: static-card helper is not loaded')
        return
    end
    local ok, status, cardId = helper(SOURCE_ID, active.sourceBaseline)
    if ok then
        write('capture exchange confirmed: source=59, card=' .. tostring(cardId) .. ', status=' .. tostring(status))
    else
        write('capture exchange unresolved: source=59, reason=' .. tostring(status))
    end
end

local function onBattleRestoreItem()
    exchangeCapturedSource()
    restoreProbe('Battle_RestoreItem')
end
local function onMapLoading() restoreProbe('MapLoading') end
local function onGameStart()
    restoreProbe('GameStart')
    write('loaded: F7 starts the isolated 牛魔王 level-gate probe; F5 explicitly exchanges one prior probe source ID 59 into static card 10024')
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
