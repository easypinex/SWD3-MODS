-- Steam HD 4.0.5 正式收妖整合。
-- 在地圖及每次戰後預先套用原生靈契前置橋接；進戰後只把過高的敵方戰鬥副本
-- 等級封頂為第一位戰鬥主角 +11，讓原生靈契走既有的高難度分支；收服成功後只交換原生實際新增的來源物。

local MOD = SWD3AllMonsterStaticCapture
local Catalogue = SWD3AllMonsterStaticCatalogue
if type(MOD) ~= 'table' or type(Catalogue) ~= 'table' then error('AllMonsterCaptureRuntime requires the static catalogue and installer') end

MOD.captureRuntime = MOD.captureRuntime or { active = nil, eventsRegistered = false }
local Runtime = MOD.captureRuntime
local BATTLE_LEVEL_CAP_OFFSET = 11
local SETH_PLAYER_INDEX = 1
local BOSS_ITEM_TYPE_MASK = 0x20

local function write(message)
    if type(log) == 'function' then log('[AllMonsterStaticCapture] ' .. tostring(message)) end
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

local function restoreBridge(reason)
    local active = Runtime.active
    if type(active) ~= 'table' then return false end
    for _, bossSnapshot in pairs(active.battleBossFlags or {}) do
        if bossSnapshot.status ~= nil then
            pcall(function() bossSnapshot.status.ItemType = bossSnapshot.original end)
        end
    end
    for _, levelSnapshot in pairs(active.battleLevelCaps or {}) do
        if levelSnapshot.status ~= nil then
            pcall(function() levelSnapshot.status.Level = levelSnapshot.original end)
        end
    end
    for sourceId, snapshot in pairs(active.sources) do
        local source = GameData and GameData.ItemTemp and GameData.ItemTemp[sourceId]
        if type(source) == 'table' then
            restoreField(snapshot, source, 'IT_12')
            restoreField(snapshot, source, 'IT_06')
            restoreField(snapshot, source, 'Race')
        end
    end
    for raceId, snapshot in pairs(active.races) do
        local race = GameData and GameData.Race and GameData.Race[raceId]
        if type(race) == 'table' then restoreField(snapshot, race, 'catch') end
    end
    for raceId, createdRace in pairs(active.createdRaces) do
        if GameData and type(GameData.Race) == 'table' and GameData.Race[raceId] == createdRace then
            GameData.Race[raceId] = nil
        end
    end
    Runtime.active = nil
    write('capture bridge restored (' .. tostring(reason) .. '): sources=' .. tostring(active.sourceCount)
        .. ', races=' .. tostring(active.raceCount)
        .. ', skipped=' .. tostring(active.skipped))
    return true
end

local function applyBridge(reason)
    if Runtime.active ~= nil then return true end
    if type(Catalogue.entries) ~= 'table' or type(GameData) ~= 'table'
        or type(GameData.ItemTemp) ~= 'table' or type(GameData.Race) ~= 'table' then
        write('capture bridge not armed (' .. tostring(reason) .. '): catalogue or GameData is unavailable')
        return false
    end
    local active = {
        sources = {}, races = {}, baselines = {}, capturedEnemyIndexes = {}, captureCounts = {},
        createdRaces = {}, sourceCount = 0, raceCount = 0, sourceRaceFallbacks = 0,
        skipped = 0, skippedDetails = {}, battleLevelCaps = {}, battleBossFlags = {}
    }
    for sourceId, entry in pairs(Catalogue.entries) do
        local source = GameData.ItemTemp[sourceId]
        local sourceSnapshot = nil
        local catalogueRaceId = tonumber(entry and entry.raceId)
        -- 部分原生活物在此 HD runtime 缺失 ItemTemp.Race；目錄來源是原版資料，
        -- 僅以該來源的既有 raceId 暫補，並在 bridge 離場時精確還原欄位是否存在。
        if type(source) == 'table' and tonumber(source.Race) == nil and catalogueRaceId ~= nil then
            sourceSnapshot = {}
            snapshotField(sourceSnapshot, source, 'Race')
            source.Race = catalogueRaceId
            active.sourceRaceFallbacks = active.sourceRaceFallbacks + 1
        end
        local raceId = source and tonumber(source.Race) or nil
        local race = raceId and GameData.Race[raceId] or nil
        -- Steam HD 4.0.5 的原版 RaceDefine 有 Race[0]（天神、catch=true），
        -- 但實際 runtime 可能缺此 table。僅在 bridge 期間以原版同等資料補回。
        if race == nil and raceId == 0 then
            local nativeRaceZero = { name = 'NAME1000', catch = true }
            GameData.Race[0] = nativeRaceZero
            active.createdRaces[0] = nativeRaceZero
            race = nativeRaceZero
            write('capture bridge supplied missing native Race[0] (天神) temporarily')
        end
        if type(source) == 'table' and type(race) == 'table' then
            sourceSnapshot = sourceSnapshot or {}
            active.sources[sourceId] = sourceSnapshot
            active.baselines[sourceId] = countItemCopies(sourceId)
            active.sourceCount = active.sourceCount + 1
            snapshotField(sourceSnapshot, source, 'IT_12')
            snapshotField(sourceSnapshot, source, 'IT_06')
            source.IT_12 = true
            source.IT_06 = nil
            local raceSnapshot = active.races[raceId]
            if raceSnapshot == nil then
                raceSnapshot = {}
                active.races[raceId] = raceSnapshot
                active.raceCount = active.raceCount + 1
                snapshotField(raceSnapshot, race, 'catch')
            end
            race.catch = true
        else
            active.skipped = active.skipped + 1
            local reason
            if type(source) ~= 'table' then
                reason = 'ItemTemp unavailable'
            elseif raceId == nil then
                reason = 'Race is unavailable'
            else
                reason = 'Race[' .. tostring(raceId) .. '] unavailable'
            end
            table.insert(active.skippedDetails, tostring(sourceId) .. ' (' .. reason .. ')')
        end
    end
    if active.sourceCount == 0 then
        write('capture bridge not armed (' .. tostring(reason) .. '): no mutable ItemTemp/Race entries')
        return false
    end
    Runtime.active = active
    write('capture bridge armed (' .. tostring(reason) .. '): sources=' .. tostring(active.sourceCount)
        .. ', races=' .. tostring(active.raceCount)
        .. ', sourceRaceFallbacks=' .. tostring(active.sourceRaceFallbacks)
        .. ', createdRaces=' .. tostring((active.createdRaces[0] and 1) or 0)
        .. ', skipped=' .. tostring(active.skipped)
        .. '; map/異事錄 enemy levels remain original; native 靈契 eligibility is ready')
    if active.skipped > 0 then
        write('capture bridge skipped sources: ' .. table.concat(active.skippedDetails, '; '))
    end
    return true
end

local function normalizedItemType(value)
    local numeric = tonumber(value)
    if numeric == nil or numeric < 0 or numeric ~= math.floor(numeric) then return nil end
    return numeric
end

local function hasBossBit(itemType)
    return math.floor(itemType / BOSS_ITEM_TYPE_MASK) % 2 == 1
end

local function withBossBit(itemType, enabled)
    if hasBossBit(itemType) == enabled then return itemType end
    return enabled and itemType + BOSS_ITEM_TYPE_MASK or itemType - BOSS_ITEM_TYPE_MASK
end

local function sourceWasBoss(active, sourceId)
    local sourceSnapshot = active and active.sources and active.sources[sourceId]
    local saved = sourceSnapshot and sourceSnapshot.IT_06
    return saved ~= nil and saved.present and not not saved.value
end

local function readBattleItemType(status)
    local ok, value = pcall(function() return status.ItemType end)
    if not ok then return nil end
    return normalizedItemType(value)
end

local function writeBattleBossFlag(active, index, enabled, reason)
    local snapshot = active and active.battleBossFlags and active.battleBossFlags[index]
    if snapshot == nil or snapshot.status == nil then return true end
    local before = readBattleItemType(snapshot.status)
    if before == nil then
        write('Boss window read failure: index=' .. tostring(index) .. ', source=' .. tostring(snapshot.sourceId)
            .. ', reason=' .. tostring(reason))
        return false
    end
    local desired = withBossBit(before, enabled)
    local ok, failure = pcall(function() snapshot.status.ItemType = desired end)
    local after = readBattleItemType(snapshot.status)
    if not ok or after ~= desired or hasBossBit(after) ~= enabled then
        write('Boss window write failure: index=' .. tostring(index) .. ', source=' .. tostring(snapshot.sourceId)
            .. ', wanted=' .. tostring(desired) .. ', got=' .. tostring(after)
            .. ', reason=' .. tostring(reason) .. ', failure=' .. tostring(failure))
        return false
    end
    if snapshot.bossEnabled ~= enabled then
        write('Boss window ' .. (enabled and 'ON' or 'OFF') .. ': index=' .. tostring(index)
            .. ', source=' .. tostring(snapshot.sourceId) .. ', reason=' .. tostring(reason))
    end
    snapshot.bossEnabled = enabled
    return true
end

local function prepareBattleBossWindows()
    local active = Runtime.active
    if type(active) ~= 'table' then return end
    local max = tonumber(_BattleEnv and _BattleEnv.EnemyIDMax) or 0
    for index in pairs(BattleEnv and BattleEnv.enemys or {}) do
        local numericIndex = tonumber(index)
        if numericIndex ~= nil and numericIndex > max then max = numericIndex end
    end
    local tracked, failed = 0, 0
    for index = 1, max do
        local enemy = BattleEnemys and BattleEnemys[index]
        local sourceId = tonumber(enemy and enemy.NPC_GUID)
        local status = enemy and enemy.NPCData
        if sourceId ~= nil and sourceWasBoss(active, sourceId) and status ~= nil
            and active.battleBossFlags[index] == nil then
            local original = readBattleItemType(status)
            if original == nil then
                failed = failed + 1
                write('Boss window unavailable: index=' .. tostring(index) .. ', source=' .. tostring(sourceId)
                    .. ', NPCData.ItemType is unreadable')
            else
                active.battleBossFlags[index] = {
                    status = status, original = original, sourceId = sourceId, bossEnabled = hasBossBit(original)
                }
                tracked = tracked + 1
                if not writeBattleBossFlag(active, index, false, 'Battle_Enter baseline for first command UI') then
                    failed = failed + 1
                end
            end
        end
    end
    if tracked > 0 or failed > 0 then
        write('Boss capture window prepared (Battle_Enter): tracked=' .. tostring(tracked)
            .. ', failed=' .. tostring(failed)
            .. '; input NowMenu=1/3 OFF, Seth after OFF, non-Seth after ON')
    end
end

local function hasBattleBossWindows(active)
    return type(active) == 'table' and type(active.battleBossFlags) == 'table'
        and next(active.battleBossFlags) ~= nil
end

local function onCommandInput(origin)
    local active = Runtime.active
    if not hasBattleBossWindows(active) then return end
    local menu = tonumber(_BattleEnv and _BattleEnv.NowMenu)
    if menu ~= 1 and menu ~= 3 then return end
    for index in pairs(active.battleBossFlags) do
        if not writeBattleBossFlag(active, index, false, tostring(origin) .. ' NowMenu=' .. tostring(menu)) then
            write('Boss capture window disabled after input write failure; leaving remaining targets unchanged')
            return
        end
    end
end

local function onBattlePlayerAIAfter(index)
    local active = Runtime.active
    if not hasBattleBossWindows(active) then return end
    local isSeth = tonumber(index) == SETH_PLAYER_INDEX
    for enemyIndex in pairs(active.battleBossFlags) do
        if not writeBattleBossFlag(active, enemyIndex, not isSeth,
            isSeth and 'BattlePlayerAI_after Seth: retain capture window'
                or 'BattlePlayerAI_after non-Seth: restore Boss before executor') then
            write('Boss capture window disabled after after-callback write failure; leaving remaining targets unchanged')
            return
        end
    end
end

local function applyBattleLevelCap()
    local active = Runtime.active
    local player = BattlePlayers and BattlePlayers[1]
    local playerLevel = tonumber(player and player.CharData and player.CharData.Level)
    if type(active) ~= 'table' or playerLevel == nil then
        write('battle level cap unavailable: active bridge or BattlePlayers[1].CharData.Level is missing')
        return
    end
    local capLevel = playerLevel + BATTLE_LEVEL_CAP_OFFSET
    local changed, failed = 0, {}
    local max = tonumber(_BattleEnv and _BattleEnv.EnemyIDMax) or 0
    -- _BattleEnv.EnemyIDMax 是目前觀察到的原生計數；同時由 BattleEnv 補足，
    -- 避免少數戰場未暴露該計數時整場被靜默跳過。
    for index in pairs(BattleEnv and BattleEnv.enemys or {}) do
        local numericIndex = tonumber(index)
        if numericIndex ~= nil and numericIndex > max then max = numericIndex end
    end
    for index = 1, max do
        local enemy = BattleEnemys and BattleEnemys[index]
        local sourceId = tonumber(enemy and enemy.NPC_GUID)
        local status = enemy and enemy.NPCData
        local currentLevel = tonumber(status and status.Level)
        if sourceId ~= nil and active.baselines[sourceId] ~= nil and currentLevel ~= nil and currentLevel > capLevel
            and active.battleLevelCaps[index] == nil then
            local ok, failure = pcall(function() status.Level = capLevel end)
            if ok and tonumber(status.Level) == capLevel then
                active.battleLevelCaps[index] = { status = status, original = currentLevel, sourceId = sourceId }
                changed = changed + 1
            else
                table.insert(failed, tostring(index) .. '/' .. tostring(sourceId) .. ':' .. tostring(failure))
            end
        end
    end
    write('battle level cap applied (Battle_Enter): playerLevel=' .. tostring(playerLevel)
        .. ', cap=' .. tostring(capLevel) .. ', changed=' .. tostring(changed)
        .. ', failed=' .. tostring(#failed) .. '; source/map levels remain original; native high-difficulty capture uses HP ≤25%')
    if #failed > 0 then write('battle level cap write failures: ' .. table.concat(failed, '; ')) end
end

local function battleEnemySourceId(index)
    local entry = BattleEnv and BattleEnv.enemys and BattleEnv.enemys[index]
    local enemy = entry and entry.self
    return tonumber((entry and entry.GUID) or (enemy and enemy.NPC_GUID))
end

local function onBattleDead(index, side, mode)
    local active = Runtime.active
    if type(active) ~= 'table' or side ~= 1 or mode ~= 2 then return end
    if active.capturedEnemyIndexes[index] then return end
    local sourceId = battleEnemySourceId(index)
    if sourceId == nil or active.baselines[sourceId] == nil then return end
    active.capturedEnemyIndexes[index] = true
    active.captureCounts[sourceId] = (active.captureCounts[sourceId] or 0) + 1
    write('native Battle_Dead(mode=2) observed: source=' .. tostring(sourceId)
        .. '; exchange will be checked after native source-item addition')
end

local function exchangeCapturedSources(active)
    for sourceId, count in pairs(active.captureCounts) do
        for _ = 1, count do
            local ok, status, cardId = MOD.ExchangeCapturedSource(sourceId, active.baselines[sourceId])
            if ok then
                write('capture exchange confirmed: source=' .. tostring(sourceId) .. ', card=' .. tostring(cardId)
                    .. ', status=' .. tostring(status))
            else
                write('capture exchange unresolved: source=' .. tostring(sourceId) .. ', reason=' .. tostring(status))
            end
        end
    end
end

local function onBattleRestoreItem()
    local active = Runtime.active
    if type(active) ~= 'table' then return end
    exchangeCapturedSources(active)
    restoreBridge('Battle_RestoreItem')
    applyBridge('post-battle')
end

local function onMapLoading() restoreBridge('MapLoading') end
local function onMapLoaded()
    applyBridge('MapLoaded')
end
local function onGameStart()
    restoreBridge('GameStart')
    applyBridge('GameStart')
end
local function onBattleEnter()
    applyBattleLevelCap()
    prepareBattleBossWindows()
end

OnEvent = OnEvent or {}
OnEvent.GameStart = OnEvent.GameStart or {}
OnEvent.MapLoading = OnEvent.MapLoading or {}
OnEvent.MapLoaded = OnEvent.MapLoaded or {}
OnEvent.InputKeyDown = OnEvent.InputKeyDown or {}
OnEvent.InputKeyUp = OnEvent.InputKeyUp or {}
OnEvent.InputClick = OnEvent.InputClick or {}
OnEvent.Battle_Enter = OnEvent.Battle_Enter or {}
OnEvent.Battle_InputKeyDown = OnEvent.Battle_InputKeyDown or {}
OnEvent.BattlePlayerAI_after = OnEvent.BattlePlayerAI_after or {}
OnEvent.Battle_Dead = OnEvent.Battle_Dead or {}
OnEvent.Battle_RestoreItem = OnEvent.Battle_RestoreItem or {}
if not Runtime.eventsRegistered then
    table.insert(OnEvent.GameStart, onGameStart)
    table.insert(OnEvent.MapLoading, onMapLoading)
    table.insert(OnEvent.MapLoaded, onMapLoaded)
    table.insert(OnEvent.InputKeyDown, function() onCommandInput('InputKeyDown') end)
    table.insert(OnEvent.InputKeyUp, function() onCommandInput('InputKeyUp') end)
    table.insert(OnEvent.InputClick, function() onCommandInput('InputClick') end)
    table.insert(OnEvent.Battle_Enter, onBattleEnter)
    table.insert(OnEvent.Battle_InputKeyDown, function() onCommandInput('Battle_InputKeyDown') end)
    table.insert(OnEvent.BattlePlayerAI_after, onBattlePlayerAIAfter)
    table.insert(OnEvent.Battle_Dead, onBattleDead)
    table.insert(OnEvent.Battle_RestoreItem, onBattleRestoreItem)
    Runtime.eventsRegistered = true
end
