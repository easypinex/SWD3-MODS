-- Steam HD 4.0.5 全魔物靜態卡庫整合。
-- 卡片只在 DAT 2 載入期建立；不呼叫 SendItemTempData，也不在 GameStart 動態建立 ItemTemp。
-- 一般地圖「讓所有非活物直接成為靈契目標」仍需獨立驗證，故本檔只提供安全交換 helper。

SWD3AllMonsterStaticCapture = SWD3AllMonsterStaticCapture or {}
local MOD = SWD3AllMonsterStaticCapture
local Catalogue = SWD3AllMonsterStaticCatalogue
local CARD_TEMPLATE_ID = 101

MOD.eventsRegistered = MOD.eventsRegistered or false
MOD.installFailures = MOD.installFailures or {}
MOD.staticCards = MOD.staticCards or {}

local function write(message)
    if type(log) == 'function' then
        log('[AllMonsterStaticCapture] ' .. tostring(message))
    end
end

local function shallowCopy(source)
    local copy = {}
    for key, value in pairs(source or {}) do copy[key] = value end
    return copy
end

local function roundedScale(value, multiplier)
    local number = tonumber(value)
    if number == nil then return value end
    return math.floor(number * multiplier + 0.5)
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

local function findItemSlot(itemId)
    for slot, item in ipairs(SaveData and SaveData.Items or {}) do
        if tonumber(item.ItemTempID) == tonumber(itemId) and itemTotal(item) > 0 then return slot end
    end
    return nil
end

local function cacheContains(list, itemId)
    for _, value in ipairs(list or {}) do
        if tonumber(value) == tonumber(itemId) then return true end
    end
    return false
end

local function applyGuardianBonuses(card, sourceId, entry, source)
    local bonus = entry.guardianBonus
    if type(bonus) ~= 'table' then return end

    -- 所有 97 張卡的實際九維加成由生成目錄明確列出；避免以同一個 runtime 模板抹平原型特色。
    card.AddHP = tonumber(bonus.hp) or 0
    card.AddMP = tonumber(bonus.mp) or 0
    card.AddSP = tonumber(bonus.sp) or 0
    card.AddSTR = tonumber(bonus.str) or 0
    card.AddStamina = tonumber(bonus.stamina) or 0
    card.AddWIS = tonumber(bonus.wis) or 0
    card.AddSPD = tonumber(bonus.spd) or 0
    card.AddATK = tonumber(bonus.atk) or 0
    card.AddDEF = tonumber(bonus.def) or 0

    -- 不讓敵方弱點殘留在卡片資料；護駕抗性沒有安全、已實測的 Lua 套用途徑。
    for _, key in ipairs({ 'AttrFire', 'AttrIce', 'AttrWind', 'AttrEarth', 'AttrPoison', 'AttrLight', 'AttrDark', 'AttrThunder', 'AttrPhysical', 'AttrTunder' }) do
        card[key] = nil
    end
end

local function makeStaticCard(sourceId, entry, cardTemplate)
    local source = GameData.ItemTemp[sourceId]
    if type(source) ~= 'table' then return nil, 'source ItemTemp[' .. tostring(sourceId) .. '] is unavailable' end
    local card = shallowCopy(cardTemplate)
    for key, value in pairs(source) do card[key] = value end
    card.Name = 'AMSC_Name_' .. tostring(sourceId)
    -- HelpText 是原版物品的長篇介紹（物品欄按 N）；保留原始 lore，不以自訂卡文覆蓋。
    card.HelpText = source.HelpText
    -- InfoText 則是物品欄的數值摘要，顯示該張靜態卡實際的九維護駕加成。
    card.InfoText = 'AMSC_Info_' .. tostring(sourceId)
    card.IT_12 = true
    card.IT_06 = nil
    -- 原版欄位註解：NotInBook=true 不顯示於神魔異事錄。
    -- 只套用給本 MOD 新建的 97 張靜態卡；原有 96 張活物卡不會經過本函式。
    card.NotInBook = true
    card.isBattleChar = true
    card.HP = roundedScale(source.HP, entry.hpMultiplier)
    card.ATK = roundedScale(source.ATK, entry.atkMultiplier)
    card.DEF = roundedScale(source.DEF, entry.defMultiplier)
    card.Consumption = entry.guardianSpCost
    card.Cons_SP = true
    card.UsePlace = 1
    card.User_01, card.User_02, card.User_03, card.User_04 = true, true, true, true
    applyGuardianBonuses(card, sourceId, entry, source)
    card.DropItems, card.DropItemsRate = nil, nil
    card.GainEXP, card.GainGold = 0, 0
    return card
end

local function installStaticCards()
    if type(Catalogue) ~= 'table' or type(Catalogue.entries) ~= 'table' then
        MOD.installFailures.catalogue = 'generated catalogue is unavailable'
        return 0, 0
    end
    if GameData == nil or type(GameData.ItemTemp) ~= 'table' then
        MOD.installFailures.gameData = 'GameData.ItemTemp is unavailable during MOD load'
        return 0, 0
    end
    local cardTemplate = GameData.ItemTemp[CARD_TEMPLATE_ID]
    if type(cardTemplate) ~= 'table' or cardTemplate.IT_12 ~= true then
        MOD.installFailures.template = 'ItemTemp[101] is unavailable as a living-card template during MOD load'
        return 0, 0
    end
    local installed, failed = 0, 0
    for sourceId, entry in pairs(Catalogue.entries) do
        if entry.staticCard == true then
            local existing = GameData.ItemTemp[entry.cardId]
            if existing ~= nil and existing ~= MOD.staticCards[entry.cardId] then
                MOD.installFailures[sourceId] = 'target ItemTemp[' .. tostring(entry.cardId) .. '] is occupied'
                failed = failed + 1
            else
                local card, failure = makeStaticCard(sourceId, entry, cardTemplate)
                if card == nil then
                    MOD.installFailures[sourceId] = failure
                    failed = failed + 1
                else
                    GameData.ItemTemp[entry.cardId] = card
                    MOD.staticCards[entry.cardId] = card
                    installed = installed + 1
                end
            end
        end
    end
    return installed, failed
end

local installedCount, failedCount = installStaticCards()

-- 此 helper 只能由已確認原生收妖成功的戰鬥流程呼叫。
-- baselineCount 必須是開戰前該 enemyId 的背包總數，以免誤刪玩家原有物品。
function MOD.ExchangeCapturedSource(enemyId, baselineCount)
    local entry = Catalogue and Catalogue.Get and Catalogue.Get(enemyId)
    if entry == nil then return false, 'enemy is not in the 193-entry capture catalogue' end
    if entry.cardId == tonumber(enemyId) then
        return true, 'native living card requires no exchange', entry.cardId
    end
    if countItemCopies(enemyId) <= (tonumber(baselineCount) or 0) then
        return false, 'native source item has not appeared above its baseline'
    end
    if GameData == nil or GameData.ItemTemp[entry.cardId] ~= MOD.staticCards[entry.cardId] then
        return false, 'mapped static card is not registered at MOD load'
    end
    if type(ItemClass) ~= 'table' or type(ItemClass.DelItem) ~= 'function' or type(ItemClass.AddItem) ~= 'function' then
        return false, 'ItemClass add/remove helpers are unavailable'
    end
    local slot = findItemSlot(enemyId)
    if slot == nil then return false, 'native source item has no removable inventory slot' end
    local deleted, deleteResult = pcall(ItemClass.DelItem, slot, enemyId, 1, 0)
    if not deleted or deleteResult == -1 then return false, 'native source removal failed: ' .. tostring(deleteResult) end
    local added, addResult = pcall(ItemClass.AddItem, entry.cardId, 1, 0, false)
    if not added or addResult == -1 or addResult == -2 then
        return false, 'static card addition failed after source removal: ' .. tostring(addResult)
    end
    return true, 'exchanged', entry.cardId
end

function MOD.CardIdForEnemy(enemyId)
    return Catalogue and Catalogue.CardIdForEnemy and Catalogue.CardIdForEnemy(enemyId) or nil
end

function MOD.GetStatus()
    local mapped, static = 0, 0
    for _, entry in pairs(Catalogue and Catalogue.entries or {}) do
        mapped = mapped + 1
        if entry.staticCard == true then static = static + 1 end
    end
    return { mappedEnemies = mapped, staticCards = static, installedStaticCards = installedCount, failedStaticCards = failedCount }
end

local function onGameStart()
    local itemCache, raceCache = 0, 0
    for sourceId, entry in pairs(Catalogue and Catalogue.entries or {}) do
        if entry.staticCard == true then
            if cacheContains(GameData and GameData._ItemTemp, entry.cardId) then itemCache = itemCache + 1 end
            local card = GameData and GameData.ItemTemp and GameData.ItemTemp[entry.cardId]
            if card and GameData and GameData._Race and cacheContains(GameData._Race[card.Race], entry.cardId) then raceCache = raceCache + 1 end
        end
    end
    write('load-phase catalogue: mappings=193, static=' .. tostring(installedCount)
        .. ', failures=' .. tostring(failedCount) .. ', itemCache=' .. tostring(itemCache)
        .. ', raceCache=' .. tostring(raceCache)
        .. '; capture eligibility is intentionally not changed in this data phase')
end

OnEvent = OnEvent or {}
OnEvent.GameStart = OnEvent.GameStart or {}
if not MOD.eventsRegistered then
    table.insert(OnEvent.GameStart, onGameStart)
    MOD.eventsRegistered = true
end
