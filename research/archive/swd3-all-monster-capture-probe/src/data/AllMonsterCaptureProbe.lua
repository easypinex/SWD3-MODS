-- 軒轅劍參 Steam 高清版 4.0.x
-- 全魔物收妖探針：只驗證兩個假設，不改寫任何原版 ItemTemp。
-- F6：靈契 wrapper 探針。F10：資格橋接探針。F7：自訂卡交換探針。F5：清除本探針卡。

SWD3AllMonsterCaptureProbe = SWD3AllMonsterCaptureProbe or {}

local MOD = SWD3AllMonsterCaptureProbe
local F5_SCANCODE = 62
local F6_SCANCODE = 63
local F7_SCANCODE = 64
local F10_SCANCODE = 67
local BATTLE_ID = 'AMCP_CAPTURE_PROBE'
local SOURCE_ENEMY_ID = 102 -- 蛇：原版有完整戰鬥資料、非 IT_12、Race 14.catch=true。
local PROBE_CARD_ID = 9001 -- 高於目前原版 ItemTemp 最大 ID 2203；僅驗證自訂 ID 路徑。

MOD.State = MOD.State or {}
local State = MOD.State
State.active = State.active or nil
State.eventsRegistered = State.eventsRegistered or false
State.wrapperInstalled = State.wrapperInstalled or false
State.previousCheckObsolt = State.previousCheckObsolt or nil

local function write(message)
    if type(log) == 'function' then
        log('[AllMonsterCaptureProbe] ' .. tostring(message))
    end
end

local function getItems()
    return SaveData and SaveData.Items or nil
end

local function itemTotal(item)
    return (tonumber(item and item.Count) or 0) + (tonumber(item and item.Count_New) or 0)
end

local function countItemCopies(itemId)
    local total = 0
    for _, item in ipairs(getItems() or {}) do
        if tonumber(item.ItemTempID) == tonumber(itemId) then
            total = total + itemTotal(item)
        end
    end
    return total
end

local function findItemSlot(itemId)
    for slot, item in ipairs(getItems() or {}) do
        if tonumber(item.ItemTempID) == tonumber(itemId) and itemTotal(item) > 0 then
            return slot
        end
    end
    return nil
end

local function currentBattleFieldId()
    if GameFunc == nil or type(GameFunc.GetBattleFieldID) ~= 'function' then
        return nil
    end
    local ok, value = pcall(GameFunc.GetBattleFieldID)
    if ok then
        return value
    end
    return nil
end

local function isProbeBattle()
    return State.active ~= nil and currentBattleFieldId() == BATTLE_ID
end

local function shallowCopy(source)
    local copy = {}
    for key, value in pairs(source or {}) do
        copy[key] = value
    end
    return copy
end

-- 原生靈契目標 UI 已實測會先以 IT_12 排除蛇，早於 CheckObsolt wrapper。
-- 此 bridge 只在本探針戰場進行期間暫改一個欄位，並保留「原本不存在」與
-- 「原本為 false」的差異，確保所有離開路徑都精確還原。
local function applyEligibilityBridge(active)
    if active == nil or active.sourceEligibilitySnapshot ~= nil then
        return true
    end
    local source = GameData and GameData.ItemTemp and GameData.ItemTemp[SOURCE_ENEMY_ID]
    if type(source) ~= 'table' then
        return false, 'source enemy ItemTemp 102 is unavailable for eligibility bridge'
    end
    active.sourceEligibilitySnapshot = {
        hadIT12 = source.IT_12 ~= nil,
        IT12 = source.IT_12
    }
    source.IT_12 = true
    write('eligibility bridge applied: ItemTemp[102].IT_12=true (temporary)')
    return true
end

local function restoreEligibilityBridge(active)
    local snapshot = active and active.sourceEligibilitySnapshot
    if snapshot == nil then
        return
    end
    local source = GameData and GameData.ItemTemp and GameData.ItemTemp[SOURCE_ENEMY_ID]
    if type(source) == 'table' then
        if snapshot.hadIT12 then
            source.IT_12 = snapshot.IT12
        else
            source.IT_12 = nil
        end
        write('eligibility bridge restored: ItemTemp[102].IT_12=' .. tostring(source.IT_12))
    else
        write('eligibility bridge restoration skipped: source ItemTemp[102] is unavailable')
    end
    active.sourceEligibilitySnapshot = nil
end

-- 只在 F7 測試前新增一筆新的 table；永遠不寫入 GameData.ItemTemp[102]。
-- 不呼叫尚未實測的 GameData.SendItemTempData，讓物品欄／護駕是否接受動態 ID
-- 成為本探針的可觀察結果，而不是預設事實。
local function installProbeCard()
    if GameData == nil or type(GameData.ItemTemp) ~= 'table' then
        return false, 'GameData.ItemTemp is unavailable'
    end
    local source = GameData.ItemTemp[SOURCE_ENEMY_ID]
    if type(source) ~= 'table' then
        return false, 'source enemy ItemTemp 102 is unavailable'
    end
    local existing = GameData.ItemTemp[PROBE_CARD_ID]
    if existing ~= nil and existing ~= MOD.probeCardTemplate then
        return false, 'custom item ID 9001 is already occupied'
    end

    local card = shallowCopy(source)
    card.Name = 'AMCP_CardName'
    card.HelpText = 'AMCP_CardHelp'
    card.InfoText = 'AMCP_CardInfo'
    card.IT_12 = true
    card.IT_06 = nil
    card.NotInBook = true
    card.Consumption = 8
    card.Cons_SP = true
    card.UsePlace = 1
    card.User_01 = true
    card.User_02 = true
    card.User_03 = true
    card.User_04 = true
    card.DropItems = nil
    card.DropItemsRate = nil
    card.GainEXP = 0
    card.GainGold = 0

    GameData.ItemTemp[PROBE_CARD_ID] = card
    MOD.probeCardTemplate = card
    write('custom card ItemTemp[9001] installed; source ItemTemp[102] remains unchanged')
    return true
end

local function removeOneItemAboveBaseline(itemId, baseline)
    if countItemCopies(itemId) <= (tonumber(baseline) or 0) then
        return false, 'no native-added source item observed yet'
    end
    if ItemClass == nil or type(ItemClass.DelItem) ~= 'function' then
        return false, 'ItemClass.DelItem is unavailable'
    end
    local slot = findItemSlot(itemId)
    if slot == nil then
        return false, 'source item count changed but no removable slot was found'
    end
    local ok, result = pcall(ItemClass.DelItem, slot, itemId, 1, 0)
    if not ok or result == -1 then
        return false, 'ItemClass.DelItem failed: ' .. tostring(result)
    end
    return true
end

local function addProbeCard()
    if ItemClass == nil or type(ItemClass.AddItem) ~= 'function' then
        return false, 'ItemClass.AddItem is unavailable'
    end
    local ok, result = pcall(ItemClass.AddItem, PROBE_CARD_ID, 1, 0, false)
    if not ok or result == -1 or result == -2 then
        return false, 'ItemClass.AddItem failed: ' .. tostring(result)
    end
    return true
end

local function settlePendingCapture()
    local active = State.active
    if active == nil or (tonumber(active.pendingCaptures) or 0) < 1 then
        return false
    end
    local removed, removalReason = removeOneItemAboveBaseline(SOURCE_ENEMY_ID, active.sourceBaseline)
    if not removed then
        return false, removalReason
    end

    active.pendingCaptures = active.pendingCaptures - 1
    if active.phase ~= 'card' then
        active.captureSettled = true
        write('phase 1 confirmed: native capture added source ID 102 and it was safely removed')
        return true
    end

    local added, addReason = addProbeCard()
    if not added then
        active.exchangeFailure = addReason
        write('phase 2 source item removed, but custom-card add failed: ' .. tostring(addReason))
        return false, addReason
    end
    active.captureSettled = true
    write('phase 2 confirmed: source ID 102 exchanged for custom card ID 9001')
    return true
end

local function finishActiveProbe(reason)
    local active = State.active
    if active == nil then
        return
    end
    local settled, pendingReason = settlePendingCapture()
    if not settled and (tonumber(active.pendingCaptures) or 0) > 0 then
        write('capture exchange unresolved at ' .. tostring(reason) .. ': ' .. tostring(pendingReason))
    end
    restoreEligibilityBridge(active)
    State.active = nil
    write('probe battle ended: ' .. tostring(reason))
end

local function isProbeTarget(target)
    return isProbeBattle()
        and type(target) == 'table'
        and tonumber(target.NPC_GUID) == SOURCE_ENEMY_ID
end

local function installCheckObsoltWrapper()
    if State.wrapperInstalled then
        return true
    end
    if Function == nil or type(Function.CheckObsolt) ~= 'function' then
        write('CheckObsolt wrapper not installed: Function.CheckObsolt is unavailable')
        return false
    end
    local previous = Function.CheckObsolt
    State.previousCheckObsolt = previous
    Function.CheckObsolt = function(player, target)
        local originalChance = previous(player, target)
        if not isProbeTarget(target) then
            return originalChance
        end
        local active = State.active
        active.wrapperObserved = true
        active.originalChance = originalChance
        if not active.wrapperLogged then
            active.wrapperLogged = true
            write('CheckObsolt wrapper observed: original=' .. tostring(originalChance) .. ', override=100')
        end
        -- 僅針對自訂戰場的蛇；原版地圖、其他戰場及其他敵人完全交回原函式。
        return 100
    end
    State.wrapperInstalled = true
    write('CheckObsolt wrapper installed')
    return true
end

local function startProbe(phase)
    if State.active ~= nil then
        write('start refused: a probe battle is already active')
        return false
    end
    if not installCheckObsoltWrapper() then
        return false
    end
    if phase == 'card' then
        local installed, installReason = installProbeCard()
        if not installed then
            write('phase 2 refused: ' .. tostring(installReason))
            return false
        end
    end
    if BattleField == nil then
        BattleField = {}
    end
    BattleField[BATTLE_ID] = {
        iBattleFieldBackground = 4,
        MusicFileName = 'Battle_Europa01.mp3',
        tCharActQ = { { ItemTempID = SOURCE_ENEMY_ID, X = 176, Y = 294 } }
    }
    State.active = {
        phase = phase,
        sourceBaseline = countItemCopies(SOURCE_ENEMY_ID),
        pendingCaptures = 0,
        wrapperObserved = false,
        captureSettled = false
    }
    if phase == 'bridge' or phase == 'card' then
        local bridged, bridgeReason = applyEligibilityBridge(State.active)
        if not bridged then
            State.active = nil
            write('probe start refused: ' .. tostring(bridgeReason))
            return false
        end
    end
    local started, failure = pcall(ESC.StartBattle, BATTLE_ID)
    if not started then
        finishActiveProbe('StartBattle failed')
        write('StartBattle failed: ' .. tostring(failure))
        return false
    end
    write('phase ' .. phase .. ' started; use 靈契 on 蛇, do not defeat it normally')
    return true
end

Scene = Scene or {}
function Scene.AMCP_StartProbe(phaseCode)
    if tonumber(phaseCode) == 3 then
        startProbe('card')
    elseif tonumber(phaseCode) == 2 then
        startProbe('bridge')
    else
        startProbe('wrapper')
    end
end

local function clearProbeCards()
    if State.active ~= nil then
        write('F5 cleanup refused during an active probe battle')
        return
    end
    local removed = 0
    while countItemCopies(PROBE_CARD_ID) > 0 do
        local slot = findItemSlot(PROBE_CARD_ID)
        if slot == nil or ItemClass == nil or type(ItemClass.DelItem) ~= 'function' then
            write('F5 cleanup stopped; remaining card count=' .. tostring(countItemCopies(PROBE_CARD_ID)))
            return
        end
        local ok, result = pcall(ItemClass.DelItem, slot, PROBE_CARD_ID, 1, 0)
        if not ok or result == -1 then
            write('F5 cleanup failed: ' .. tostring(result))
            return
        end
        removed = removed + 1
    end
    write('F5 cleanup complete; removed custom card count=' .. tostring(removed))
end

local function onInputClick(_, keyScancode)
    if keyScancode == F5_SCANCODE then
        clearProbeCards()
        return true
    elseif keyScancode == F6_SCANCODE or keyScancode == F7_SCANCODE or keyScancode == F10_SCANCODE then
        -- GetBattleFieldID 在此版引擎於戰後仍可能保留舊 ID，不能以它判定
        -- 地圖上的探針是否已結束；只以本探針完整生命週期的 State.active 阻擋。
        -- 使用說明仍要求玩家只在安全地圖按下這些鍵。
        if State.active ~= nil then
            write('start ignored: a probe battle is already active')
            return true
        end
        local phaseCode = 1
        if keyScancode == F10_SCANCODE then
            phaseCode = 2
        elseif keyScancode == F7_SCANCODE then
            phaseCode = 3
        end
        local started, failure = pcall(GameFunc.RunScene, -1, 'AMCP_StartProbe', phaseCode)
        if not started then
            write('RunScene failed: ' .. tostring(failure))
        end
        return true
    end
    return false
end

local function onBattleDead(index, side, mode)
    if not isProbeBattle() or side ~= 1 or mode ~= 2 then
        return
    end
    local enemy = BattleEnv and BattleEnv.enemys and BattleEnv.enemys[index]
    if enemy == nil or tonumber(enemy.GUID) ~= SOURCE_ENEMY_ID then
        return
    end
    State.active.pendingCaptures = State.active.pendingCaptures + 1
    write('native Battle_Dead(mode=2) observed; checking for a source-item addition')
    settlePendingCapture()
end

local function onBattleRestoreItem()
    if State.active ~= nil then
        finishActiveProbe('Battle_RestoreItem')
    end
end

local function onMapLoading()
    if State.active ~= nil then
        finishActiveProbe('MapLoading')
    end
end

local function onGameStart()
    restoreEligibilityBridge(State.active)
    State.active = nil
    installCheckObsoltWrapper()
    write('loaded: F6=wrapper-only, F10=eligibility bridge, F7=custom-card bridge, F5=remove card ID 9001 before disabling')
end

OnEvent = OnEvent or {}
OnEvent.GameStart = OnEvent.GameStart or {}
OnEvent.InputClick = OnEvent.InputClick or {}
OnEvent.Battle_Dead = OnEvent.Battle_Dead or {}
OnEvent.Battle_RestoreItem = OnEvent.Battle_RestoreItem or {}
OnEvent.MapLoading = OnEvent.MapLoading or {}

if not State.eventsRegistered then
    table.insert(OnEvent.GameStart, onGameStart)
    table.insert(OnEvent.InputClick, onInputClick)
    table.insert(OnEvent.Battle_Dead, onBattleDead)
    table.insert(OnEvent.Battle_RestoreItem, onBattleRestoreItem)
    table.insert(OnEvent.MapLoading, onMapLoading)
    State.eventsRegistered = true
end

function MOD.GetStatus()
    local active = State.active
    return {
        wrapperInstalled = State.wrapperInstalled == true,
        battleActive = active ~= nil,
        phase = active and active.phase or nil,
        wrapperObserved = active and active.wrapperObserved or false,
        sourceItemCount = countItemCopies(SOURCE_ENEMY_ID),
        customCardCount = countItemCopies(PROBE_CARD_ID),
        customCardInstalled = GameData and GameData.ItemTemp and GameData.ItemTemp[PROBE_CARD_ID] ~= nil
    }
end
