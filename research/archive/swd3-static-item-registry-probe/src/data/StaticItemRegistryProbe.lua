-- 軒轅劍參 Steam 高清版 4.0.x
-- 問題：MOD 載入期直接建立 ItemTemp，是否早於 native 物品註冊快取？
-- 本檔案頂層執行 installStaticCard；絕不在 GameStart 注入，絕不呼叫 SendItemTempData。
-- F4：加入一張 ID 9003。F3：移除全部 ID 9003。僅在安全地圖使用，絕不存檔。

SWD3StaticItemRegistryProbe = SWD3StaticItemRegistryProbe or {}

local MOD = SWD3StaticItemRegistryProbe
local F3_SCANCODE = 60
local F4_SCANCODE = 61
local SOURCE_CARD_ID = 101
local PROBE_CARD_ID = 9003

MOD.eventsRegistered = MOD.eventsRegistered or false

local function write(message)
    if type(log) == 'function' then
        log('[StaticItemRegistryProbe] ' .. tostring(message))
    end
end

local function shallowCopy(source)
    local copy = {}
    for key, value in pairs(source or {}) do
        copy[key] = value
    end
    return copy
end

local function cacheContains(list, itemId)
    for _, value in ipairs(list or {}) do
        if tonumber(value) == tonumber(itemId) then
            return true
        end
    end
    return false
end

local function itemTotal(item)
    return (tonumber(item and item.Count) or 0) + (tonumber(item and item.Count_New) or 0)
end

local function countItem(itemId)
    local total = 0
    for _, item in ipairs(SaveData and SaveData.Items or {}) do
        if tonumber(item.ItemTempID) == tonumber(itemId) then
            total = total + itemTotal(item)
        end
    end
    return total
end

local function findItemSlot(itemId)
    for slot, item in ipairs(SaveData and SaveData.Items or {}) do
        if tonumber(item.ItemTempID) == tonumber(itemId) and itemTotal(item) > 0 then
            return slot
        end
    end
    return nil
end

-- 此函式在 DAT 2 腳本被載入時立刻執行。這是 MOD 可用的最早 Lua 時點，
-- 與已否決探針的 GameStart／按鍵注入刻意不同。
local function installStaticCard()
    if GameData == nil or type(GameData.ItemTemp) ~= 'table' then
        MOD.installFailure = 'GameData.ItemTemp is unavailable during MOD load'
        return false
    end
    local source = GameData.ItemTemp[SOURCE_CARD_ID]
    if type(source) ~= 'table' or source.IT_12 ~= true then
        MOD.installFailure = 'source ItemTemp[101] is unavailable or not IT_12 during MOD load'
        return false
    end
    local existing = GameData.ItemTemp[PROBE_CARD_ID]
    if existing ~= nil and existing ~= MOD.staticCardTemplate then
        MOD.installFailure = 'ItemTemp[9003] is occupied before probe load'
        return false
    end

    local card = shallowCopy(source)
    card.Name = 'SIRP_CardName'
    card.HelpText = 'SIRP_CardHelp'
    card.InfoText = 'SIRP_CardInfo'
    card.NotInBook = true
    card.DropItems = nil
    card.DropItemsRate = nil
    card.GainEXP = 0
    card.GainGold = 0
    GameData.ItemTemp[PROBE_CARD_ID] = card
    MOD.staticCardTemplate = card
    MOD.installFailure = nil
    return true
end

local installedAtLoad = installStaticCard()

local function addProbeCard()
    if not installedAtLoad or GameData == nil or GameData.ItemTemp == nil
        or GameData.ItemTemp[PROBE_CARD_ID] ~= MOD.staticCardTemplate then
        write('F4 refused: static card was not installed during MOD load (' .. tostring(MOD.installFailure) .. ')')
        return
    end
    if type(ItemClass) ~= 'table' or type(ItemClass.AddItem) ~= 'function' then
        write('F4 refused: ItemClass.AddItem is unavailable')
        return
    end
    local ok, result = pcall(ItemClass.AddItem, PROBE_CARD_ID, 1, 0, false)
    if not ok or result == -1 or result == -2 then
        write('F4 AddItem failed: ' .. tostring(result))
        return
    end
    write('F4 added one ID 9003; do not save, then test inventory highlight once')
end

local function removeProbeCards()
    if type(ItemClass) ~= 'table' or type(ItemClass.DelItem) ~= 'function' then
        write('F3 cleanup unavailable: ItemClass.DelItem is unavailable')
        return
    end
    local removed = 0
    while countItem(PROBE_CARD_ID) > 0 do
        local slot = findItemSlot(PROBE_CARD_ID)
        if slot == nil then
            write('F3 cleanup stopped: item count exists without a removable slot')
            return
        end
        local ok, result = pcall(ItemClass.DelItem, slot, PROBE_CARD_ID, 1, 0)
        if not ok or result == -1 then
            write('F3 cleanup failed: ' .. tostring(result))
            return
        end
        removed = removed + 1
    end
    write('F3 cleanup complete; removed=' .. tostring(removed))
end

local function onGameStart()
    local card = GameData and GameData.ItemTemp and GameData.ItemTemp[PROBE_CARD_ID]
    local inItemCache = GameData and cacheContains(GameData._ItemTemp, PROBE_CARD_ID) or false
    local inRaceCache = card and GameData and GameData._Race
        and cacheContains(GameData._Race[card.Race], PROBE_CARD_ID) or false
    write('load-phase result: card=' .. tostring(card == MOD.staticCardTemplate)
        .. ', itemCache=' .. tostring(inItemCache) .. ', raceCache=' .. tostring(inRaceCache)
        .. '; no cache rebuild was called')
    if card == MOD.staticCardTemplate then
        write('ready: F4=add ID 9003, F3=remove it before saving or disabling')
    else
        write('not testable: static registration was unavailable (' .. tostring(MOD.installFailure) .. ')')
    end
end

local function onInputClick(_, keyScancode)
    if keyScancode == F4_SCANCODE then
        addProbeCard()
        return true
    elseif keyScancode == F3_SCANCODE then
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
        installedAtLoad = installedAtLoad,
        installFailure = MOD.installFailure,
        cardRegistered = card == MOD.staticCardTemplate,
        cardInItemCache = GameData and cacheContains(GameData._ItemTemp, PROBE_CARD_ID) or false,
        cardInRaceCache = card and GameData and GameData._Race
            and cacheContains(GameData._Race[card.Race], PROBE_CARD_ID) or false,
        cardCount = countItem(PROBE_CARD_ID)
    }
end
