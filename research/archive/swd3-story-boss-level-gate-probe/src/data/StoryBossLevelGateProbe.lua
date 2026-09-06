-- Steam HD 4.0.x：F6 只研究劇情首領的原生靈契等級門檻。
-- 蚩尤 ID 46 原等級 80；本探針僅在自訂測試戰前暫設為 Lv1，戰後精確還原。

SWD3StoryBossLevelGateProbe = SWD3StoryBossLevelGateProbe or {}
local MOD = SWD3StoryBossLevelGateProbe
local F6_SCANCODE = 63
local BATTLE_ID = 'SBLGP_CHIYOU_LEVEL'
local SOURCE_ID = 46
local CAPTURE_LEVEL = 1

MOD.state = MOD.state or { eventsRegistered = false, active = nil }
local State = MOD.state

local function write(message)
    if type(log) == 'function' then log('[StoryBossLevelGateProbe] ' .. tostring(message)) end
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
        if tonumber(item.ItemTempID) == tonumber(itemId) then total = total + itemTotal(item) end
    end
    return total
end

local function restoreProbe(reason)
    local active = State.active
    if active == nil then return end
    local source = GameData and GameData.ItemTemp and GameData.ItemTemp[SOURCE_ID]
    local race = source and GameData.Race and GameData.Race[source.Race]
    if type(source) == 'table' then
        restoreField(active.source, source, 'IT_12')
        restoreField(active.source, source, 'IT_06')
        restoreField(active.source, source, 'Level')
        restoreField(active.source, source, 'ATK')
        restoreField(active.source, source, 'SPD')
        restoreField(active.source, source, 'Skills')
        restoreField(active.source, source, 'CureSkills')
        restoreField(active.source, source, 'SP_AE')
    end
    if type(race) == 'table' then restoreField(active.race, race, 'catch') end
    State.active = nil
    write('probe restored (' .. tostring(reason) .. '): ItemTemp[46].Level=' .. tostring(source and source.Level))
end

local function applyProbe()
    local source = GameData and GameData.ItemTemp and GameData.ItemTemp[SOURCE_ID]
    local race = source and GameData.Race and GameData.Race[source.Race]
    if type(source) ~= 'table' or type(race) ~= 'table' then return nil, 'source ItemTemp[46] or its Race is unavailable' end
    local active = { source = {}, race = {} }
    snapshotField(active.source, source, 'IT_12')
    snapshotField(active.source, source, 'IT_06')
    snapshotField(active.source, source, 'Level')
    snapshotField(active.source, source, 'ATK')
    snapshotField(active.source, source, 'SPD')
    snapshotField(active.source, source, 'Skills')
    snapshotField(active.source, source, 'CureSkills')
    snapshotField(active.source, source, 'SP_AE')
    snapshotField(active.race, race, 'catch')
    source.IT_12 = true
    source.IT_06 = nil
    source.Level = CAPTURE_LEVEL
    source.ATK = 0
    source.SPD = 0
    source.Skills, source.CureSkills, source.SP_AE = {}, {}, {}
    race.catch = true
    active.sourceBaseline = countItemCopies(SOURCE_ID)
    active.captureObserved = false
    State.active = active
    write('bridge applied before battle: source=46, originalLevel=' .. tostring(active.source.Level.value)
        .. ', captureLevel=' .. tostring(CAPTURE_LEVEL) .. ', IT_12=true, IT_06=nil, Race.catch=true; survival fields are temporary')
    return true
end

local function startProbe()
    if State.active ~= nil then write('F6 ignored: probe is already active'); return end
    if type(SWD3AllMonsterStaticCatalogue) ~= 'table' or type(SWD3AllMonsterStaticCatalogue.Get) ~= 'function' then
        write('F6 refused: static capture catalogue is not loaded')
        return
    end
    local entry = SWD3AllMonsterStaticCatalogue.Get(SOURCE_ID)
    if entry == nil or entry.cardId == SOURCE_ID then
        write('F6 refused: expected a static mapping for source ID 46')
        return
    end
    BattleField = BattleField or {}
    BattleField[BATTLE_ID] = {
        iBattleFieldBackground = 4,
        MusicFileName = 'Battle_Europa01.mp3',
        tCharActQ = { { ItemTempID = SOURCE_ID, X = 176, Y = 294 } }
    }
    local applied, failure = applyProbe()
    if not applied then write('F6 refused: ' .. tostring(failure)); return end
    local started, startFailure = pcall(ESC.StartBattle, BATTLE_ID)
    if not started then
        restoreProbe('StartBattle failed')
        write('StartBattle failed: ' .. tostring(startFailure))
        return
    end
    write('蚩尤 battle started: test whether 靈契 can select it; cancel or escape, do not defeat/capture/save')
end

Scene = Scene or {}
function Scene.SBLGP_StartProbe() startProbe() end

local function onInputClick(_, keyScancode)
    if keyScancode ~= F6_SCANCODE then return false end
    local ok, failure = pcall(GameFunc.RunScene, -1, 'SBLGP_StartProbe', 1)
    if not ok then write('F6 RunScene failed: ' .. tostring(failure)) end
    return true
end

local function onBattleEnemyInit(index)
    if State.active == nil then return end
    local enemy = type(BattleEnemys) == 'table' and BattleEnemys[index] or nil
    if tonumber(enemy and enemy.NPC_GUID) == SOURCE_ID then
        write('Battle_EnemyInit observed: NPCData.Level=' .. tostring(enemy.NPCData and enemy.NPCData.Level)
            .. ' (must equal temporary capture level ' .. tostring(CAPTURE_LEVEL) .. ')')
    end
end

local function onBattleDead(index, side, mode)
    if State.active == nil or side ~= 1 or mode ~= 2 then return end
    local entry = BattleEnv and BattleEnv.enemys and BattleEnv.enemys[index]
    local enemy = entry and entry.self
    if tonumber((entry and entry.GUID) or (enemy and enemy.NPC_GUID)) ~= SOURCE_ID then return end
    State.active.captureObserved = true
    write('native Battle_Dead(mode=2) observed; exchange will wait for native source-item addition')
end

local function exchangeCapturedBoss()
    local active = State.active
    if active == nil or not active.captureObserved then return end
    local helper = SWD3AllMonsterStaticCapture and SWD3AllMonsterStaticCapture.ExchangeCapturedSource
    if type(helper) ~= 'function' then
        write('capture exchange unavailable: static-card helper is not loaded')
        return
    end
    local ok, status, cardId = helper(SOURCE_ID, active.sourceBaseline)
    if ok then
        write('capture exchange confirmed: source=46, card=' .. tostring(cardId) .. ', status=' .. tostring(status))
    else
        write('capture exchange unresolved: source=46, reason=' .. tostring(status))
    end
end

local function onBattleRestoreItem()
    exchangeCapturedBoss()
    restoreProbe('Battle_RestoreItem')
end
local function onMapLoading() restoreProbe('MapLoading') end
local function onGameStart()
    restoreProbe('GameStart')
    write('loaded: F6 starts the isolated 蚩尤 level-gate probe; it does not issue a card and must not be saved')
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
