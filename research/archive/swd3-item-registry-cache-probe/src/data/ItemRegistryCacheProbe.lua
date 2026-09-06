-- 軒轅劍參 Steam 高清版 4.0.x
-- 問題：GameData.SendItemTempData() 能否重建執行期新增物品的 Lua 索引？
-- F11：加入一張探針卡 9002。F12：移除全部探針卡。僅在安全地圖使用。

SWD3ItemRegistryCacheProbe = SWD3ItemRegistryCacheProbe or {}

local MOD = SWD3ItemRegistryCacheProbe
local F11_SCANCODE = 68
local F12_SCANCODE = 69
local SOURCE_CARD_ID = 101 -- 黏怪：原版完整 IT_12 護駕資料，避免測試缺少卡欄位。
local PROBE_CARD_ID = 9002 -- 與已否決的 9001 路徑分離。

MOD.eventsRegistered = MOD.eventsRegistered or false

local function write(message)
    if type(log) == 'function' then
        log('[ItemRegistryCacheProbe] ' .. tostring(message))
    end
end

local function shallowCopy(source)
    local copy = {}
    for key, value in pairs(source or {}) do
        copy[key] = value
    end
    return copy
end

local function countItem(itemId)
    local total = 0
    for _, item in ipairs(SaveData and SaveData.Items or {}) do
        if tonumber(item.ItemTempID) == tonumber(itemId) then
            total = total + (tonumber(item.Count) or 0) + (tonumber(item.Count_New) or 0)
        end
    end
    return total
end

local function findItemSlot(itemId)
    for slot, item in ipairs(SaveData and SaveData.Items or {}) do
        local total = (tonumber(item.Count) or 0) + (tonumber(item.Count_New) or 0)
        if tonumber(item.ItemTempID) == tonumber(itemId) and total > 0 then
            return slot
        end
    end
    return nil
end

local function cacheContains(list, itemId)
    for _, value in ipairs(list or {}) do
        if tonumber(value) == tonumber(itemId) then
            return true
        end
    end
    return false
end

local function installProbeCardAndRebuildIndexes()
    if GameData == nil or type(GameData.ItemTemp) ~= 'table' then
        return false, 'GameData.ItemTemp is unavailable'
    end
    local source = GameData.ItemTemp[SOURCE_CARD_ID]
    if type(source) ~= 'table' or source.IT_12 ~= true then
        return false, 'source card ItemTemp[101] is unavailable or not IT_12'
    end
    local existing = GameData.ItemTemp[PROBE_CARD_ID]
    if existing ~= nil and existing ~= MOD.probeCardTemplate then
        return false, 'ItemTemp[9002] is occupied by another source'
    end

    local beforeInCache = cacheContains(GameData._ItemTemp, PROBE_CARD_ID)
    local card = shallowCopy(source)
    card.Name = 'IRCP_CardName'
    card.HelpText = 'IRCP_CardHelp'
    card.InfoText = 'IRCP_CardInfo'
    card.NotInBook = true
    card.DropItems = nil
    card.DropItemsRate = nil
    card.GainEXP = 0
    card.GainGold = 0
    GameData.ItemTemp[PROBE_CARD_ID] = card
    MOD.probeCardTemplate = card

    if type(GameData.SendItemTempData) ~= 'function' then
        GameData.ItemTemp[PROBE_CARD_ID] = nil
        MOD.probeCardTemplate = nil
        return false, 'GameData.SendItemTempData is unavailable'
    end
    local rebuilt, failure = pcall(GameData.SendItemTempData)
    if not rebuilt then
        GameData.ItemTemp[PROBE_CARD_ID] = nil
        MOD.probeCardTemplate = nil
        return false, 'SendItemTempData failed: ' .. tostring(failure)
    end
    local indexed = cacheContains(GameData._ItemTemp, PROBE_CARD_ID)
    local inRace = card.Race ~= nil and GameData._Race and cacheContains(GameData._Race[card.Race], PROBE_CARD_ID)
    write('rebuild complete: before=' .. tostring(beforeInCache)
        .. ', itemCache=' .. tostring(indexed) .. ', raceCache=' .. tostring(inRace))
    if not indexed or not inRace then
        return false, 'rebuild completed but custom ID is missing from a Lua cache'
    end
    return true
end

local function addProbeCard()
    if type(ItemClass) ~= 'table' or type(ItemClass.AddItem) ~= 'function' then
        write('F11 refused: ItemClass.AddItem is unavailable')
        return
    end
    if GameData == nil or GameData.ItemTemp == nil or GameData.ItemTemp[PROBE_CARD_ID] == nil then
        write('F11 refused: ItemTemp[9002] was not registered at GameStart')
        return
    end
    local ok, result = pcall(ItemClass.AddItem, PROBE_CARD_ID, 1, 0, false)
    if not ok or result == -1 or result == -2 then
        write('F11 AddItem failed: ' .. tostring(result))
        return
    end
    write('F11 added one ID 9002; do not save, then test inventory highlight once')
end

local function removeProbeCards()
    if type(ItemClass) ~= 'table' or type(ItemClass.DelItem) ~= 'function' then
        write('F12 cleanup unavailable: ItemClass.DelItem is unavailable')
        return
    end
    local removed = 0
    while countItem(PROBE_CARD_ID) > 0 do
        local slot = findItemSlot(PROBE_CARD_ID)
        if slot == nil then
            write('F12 cleanup stopped: item count exists without a removable slot')
            return
        end
        local ok, result = pcall(ItemClass.DelItem, slot, PROBE_CARD_ID, 1, 0)
        if not ok or result == -1 then
            write('F12 cleanup failed: ' .. tostring(result))
            return
        end
        removed = removed + 1
    end
    write('F12 cleanup complete; removed=' .. tostring(removed))
end

local function onGameStart()
    local installed, reason = installProbeCardAndRebuildIndexes()
    if installed then
        write('loaded: F11=add ID 9002, F12=remove it before saving or disabling')
    else
        write('registration probe unavailable: ' .. tostring(reason))
    end
end

local function onInputClick(_, keyScancode)
    if keyScancode == F11_SCANCODE then
        addProbeCard()
        return true
    elseif keyScancode == F12_SCANCODE then
        removeProbeCards()
        return true
    end
    return false
end

OnEvent = OnEvent or {}
OnEvent.GameStart = OnEvent.GameStart or {}
OnEvent.InputClick = OnEvent.InputClick or {}

if not MOD.eventsRegistered then
    table.insert(OnEvent.GameStart, onGameStart)
    table.insert(OnEvent.InputClick, onInputClick)
    MOD.eventsRegistered = true
end

function MOD.GetStatus()
    local card = GameData and GameData.ItemTemp and GameData.ItemTemp[PROBE_CARD_ID]
    return {
        cardRegistered = card ~= nil,
        cardInItemCache = GameData and cacheContains(GameData._ItemTemp, PROBE_CARD_ID) or false,
        cardInRaceCache = card and GameData and GameData._Race
            and cacheContains(GameData._Race[card.Race], PROBE_CARD_ID) or false,
        cardCount = countItem(PROBE_CARD_ID)
    }
end
