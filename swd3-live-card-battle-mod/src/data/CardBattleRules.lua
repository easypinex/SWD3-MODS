-- 軒轅劍參 Steam 高清版 4.0.x
-- 自由挑戰：可獨立測試的規則核心。
--
-- 本檔不直接啟動戰鬥、不繪製 UI，也不改動 GameData；它只處理可驗證的
-- 背包選卡、預留與戰場編成規則。遊戲內入口會在後續實機原型確認後接入。

SWD3LiveCardBattle = SWD3LiveCardBattle or {}

local MOD = SWD3LiveCardBattle
local Rules = MOD.Rules or {}
MOD.Rules = Rules

Rules.MAX_TEAM_SIZE = 5
Rules.MIN_DIFFICULTY_MULTIPLIER = 0.5
Rules.MAX_DIFFICULTY_MULTIPLIER = 2.0
Rules.DIFFICULTY_MULTIPLIER_STEP = 0.1
Rules.DEFAULT_DIFFICULTY_MULTIPLIER = 1.0
Rules.DIFFICULTY_SETTING_KEYS = {
    'hp', 'attack', 'defense', 'speed', 'skill'
}

local function isPositiveInteger(value)
    return type(value) == 'number'
        and value >= 1
        and value == math.floor(value)
end

local function itemTotal(item)
    return (tonumber(item.Count) or 0) + (tonumber(item.Count_New) or 0)
end

local function itemStock(item)
    return tonumber(item.Stock) or 0
end

-- 難度只接受 0.5x～2.0x、每格 0.1x。以整數 tenth 做運算，避免 Lua 浮點值
-- 讓選單顯示出現 1.2000000001x 或越界。
function Rules.NormalizeDifficultyMultiplier(value)
    local numeric = tonumber(value)
    if numeric == nil then
        return Rules.DEFAULT_DIFFICULTY_MULTIPLIER
    end
    local tenths = math.floor(numeric * 10 + 0.5)
    local minTenths = math.floor(Rules.MIN_DIFFICULTY_MULTIPLIER * 10 + 0.5)
    local maxTenths = math.floor(Rules.MAX_DIFFICULTY_MULTIPLIER * 10 + 0.5)
    if tenths < minTenths then tenths = minTenths end
    if tenths > maxTenths then tenths = maxTenths end
    return tenths / 10
end

function Rules.AdjustDifficultyMultiplier(value, delta)
    local currentTenths = math.floor(Rules.NormalizeDifficultyMultiplier(value) * 10 + 0.5)
    local numericDelta = tonumber(delta) or 0
    local deltaTenths
    if numericDelta < 0 then
        deltaTenths = math.ceil(numericDelta * 10 - 0.5)
    else
        deltaTenths = math.floor(numericDelta * 10 + 0.5)
    end
    local nextValue = Rules.NormalizeDifficultyMultiplier((currentTenths + deltaTenths) / 10)
    return nextValue, nextValue ~= currentTenths / 10
end

function Rules.NewDifficultySettings()
    local settings = {}
    for _, key in ipairs(Rules.DIFFICULTY_SETTING_KEYS) do
        settings[key] = Rules.DEFAULT_DIFFICULTY_MULTIPLIER
    end
    return settings
end

function Rules.NormalizeDifficultySettings(settings)
    local normalized = {}
    for _, key in ipairs(Rules.DIFFICULTY_SETTING_KEYS) do
        normalized[key] = Rules.NormalizeDifficultyMultiplier(settings and settings[key])
    end
    return normalized
end

function Rules.AdjustDifficultySetting(settings, key, delta)
    if type(settings) ~= 'table' then
        return nil, false
    end
    local validKey = false
    for _, candidate in ipairs(Rules.DIFFICULTY_SETTING_KEYS) do
        if candidate == key then validKey = true; break end
    end
    if not validKey then return nil, false end
    local nextValue, changed = Rules.AdjustDifficultyMultiplier(settings[key], delta)
    settings[key] = nextValue
    return nextValue, changed
end

function Rules.GetDifficultyTotalTenths(settings)
    local totalTenths = 0
    for _, key in ipairs(Rules.DIFFICULTY_SETTING_KEYS) do
        local value = type(settings) == 'table' and settings[key] or nil
        totalTenths = totalTenths + math.floor(Rules.NormalizeDifficultyMultiplier(value) * 10 + 0.5)
    end
    return totalTenths
end

function Rules.GetDifficultyAverage(settings)
    return Rules.GetDifficultyTotalTenths(settings) / (#Rules.DIFFICULTY_SETTING_KEYS * 10)
end

-- 獎勵以所有可調整項目的算術平均判斷，而非逐項判斷。
function Rules.IsRewardAllowedForDifficulty(settings)
    return Rules.GetDifficultyTotalTenths(settings) >= #Rules.DIFFICULTY_SETTING_KEYS * 10
end

-- 只處理正值戰鬥屬性；0 與負值可能是原版的特殊語意，不能強行改為 1。
function Rules.ScaleDifficultyStat(value, multiplier)
    local numeric = tonumber(value)
    if numeric == nil or numeric <= 0 then
        return value
    end
    return math.max(1, math.floor(numeric * Rules.NormalizeDifficultyMultiplier(multiplier) + 0.5))
end

-- 可作為敵人的最低資料門檻。圖鑑／首領不一定能成為背包活物，
-- 因此不能在這裡要求 IT_12。
function Rules.IsBattleReady(itemTemp)
    return type(itemTemp) == 'table'
        and itemTemp.isBattleChar == true
        and isPositiveInteger(tonumber(itemTemp.ACT))
        and isPositiveInteger(tonumber(itemTemp.Level))
end

-- 只有「我的活物」需要物品欄活物旗標；這項規則用於可用數量與 Stock 預留。
function Rules.IsEligibleCard(itemTemp)
    return Rules.IsBattleReady(itemTemp) and itemTemp.IT_12 == true
end

function Rules.GetAvailableCards(items, itemTemps)
    local cards = {}

    if type(items) ~= 'table' or type(itemTemps) ~= 'table' then
        return cards
    end

    for slot, item in ipairs(items) do
        local itemId = tonumber(item and item.ItemTempID)
        local itemTemp = itemId and itemTemps[itemId]
        local available = item and itemTotal(item) - itemStock(item) or 0

        if Rules.IsEligibleCard(itemTemp) and available > 0 then
            table.insert(cards, {
                source = 'owned',
                slot = slot,
                itemId = itemId,
                name = tostring(itemTemp.Name or itemId),
                available = available,
                level = tonumber(itemTemp.Level)
            })
        end
    end

    return cards
end

-- 圖鑑與特殊首領是「虛擬」挑戰對手，不要求玩家持有物品，也不會預留 Stock。
-- 只取有完整戰鬥資料的活物；NotInBook 的條目不屬於神魔異事錄，保留給特殊／首領。
function Rules.GetCatalogueCards(itemTemps)
    local cards = {}
    if type(itemTemps) ~= 'table' then
        return cards
    end

    for itemId, itemTemp in pairs(itemTemps) do
        local numericId = tonumber(itemId)
        if numericId ~= nil and Rules.IsBattleReady(itemTemp) and itemTemp.NotInBook ~= true then
            table.insert(cards, {
                source = 'virtual',
                itemId = numericId,
                name = tostring(itemTemp.Name or numericId),
                level = tonumber(itemTemp.Level) or 0,
                race = tonumber(itemTemp.Race),
                available = Rules.MAX_TEAM_SIZE
            })
        end
    end

    table.sort(cards, function(left, right)
        return left.itemId < right.itemId
    end)
    return cards
end

-- 特殊／首領以劇情／圖鑑外標記彙整。若資料表沒有這些欄位，安全地回傳空清單。
-- Original HD4.0.5 allowlist: generated/current-challengeable-enemies.csv
-- in docs/knowledge/original-game-data/battle-balance-and-capture (58 rows).
-- Do not infer provenance from IT_06/NotInBook: custom pact cards clone them.
local originalSpecial = {}
for _, id in ipairs({2,3,4,6,7,10,12,13,16,18,28,32,33,38,39,40,46,48,50,51,52,53,
    59,60,61,62,63,64,67,68,69,70,71,72,73,74,75,93,180,378,379,381,382,383,
    384,385,389,394,395,396,398,399,403,433,438,2201,2202,2203}) do
    originalSpecial[id] = true
end
function Rules.GetSpecialCards(itemTemps)
    local cards = {}
    if type(itemTemps) ~= 'table' then
        return cards
    end

    for itemId, itemTemp in pairs(itemTemps) do
        local numericId = tonumber(itemId)
        if originalSpecial[numericId]
            and Rules.IsBattleReady(itemTemp)
            and (itemTemp.IT_06 == true or itemTemp.NotInBook == true) then
            table.insert(cards, {
                source = 'virtual',
                itemId = numericId,
                name = tostring(itemTemp.Name or numericId),
                level = tonumber(itemTemp.Level) or 0,
                race = tonumber(itemTemp.Race),
                available = Rules.MAX_TEAM_SIZE
            })
        end
    end

    table.sort(cards, function(left, right)
        return left.itemId < right.itemId
    end)
    return cards
end

function Rules.CardSelectionKey(card)
    if type(card) ~= 'table' then
        return nil
    end
    if card.source == 'owned' then
        return 'owned:' .. tostring(card.slot)
    end
    return 'virtual:' .. tostring(card.itemId)
end

function Rules.NewMenuState()
    return {
        selectedByKey = {},
        difficulty = Rules.NewDifficultySettings()
    }
end

function Rules.GetMenuTotal(menu)
    local total = 0
    for _, entry in pairs(menu and menu.selectedByKey or {}) do
        total = total + (tonumber(entry.count) or 0)
    end
    return total
end

function Rules.GetMenuSelectedCount(menu, card)
    local key = Rules.CardSelectionKey(card)
    local entry = key and menu and menu.selectedByKey and menu.selectedByKey[key]
    return tonumber(entry and entry.count) or 0
end

function Rules.AdjustMenuCard(menu, card, delta)
    local key = Rules.CardSelectionKey(card)
    if type(menu) ~= 'table' or type(menu.selectedByKey) ~= 'table' or key == nil then
        return false, 'card is not available'
    end

    local oldCount = Rules.GetMenuSelectedCount(menu, card)
    local nextCount = oldCount + (tonumber(delta) or 0)
    if nextCount < 0 then
        return false, 'card is not selected'
    end
    if nextCount > (tonumber(card.available) or 0) then
        return false, 'selection exceeds available card count'
    end
    if Rules.GetMenuTotal(menu) - oldCount + nextCount > Rules.MAX_TEAM_SIZE then
        return false, 'challenge requires one to five cards'
    end

    if nextCount == 0 then
        menu.selectedByKey[key] = nil
    else
        menu.selectedByKey[key] = {
            source = card.source,
            slot = card.slot,
            itemId = card.itemId,
            count = nextCount,
            name = card.name,
            level = card.level
        }
    end
    return true, nextCount
end

function Rules.BuildMenuSelection(menu)
    local selection = {}
    for _, entry in pairs(menu and menu.selectedByKey or {}) do
        table.insert(selection, {
            source = entry.source,
            slot = entry.slot,
            itemId = entry.itemId,
            count = entry.count
        })
    end
    table.sort(selection, function(left, right)
        local leftKey = (left.source or 'owned') .. ':' .. tostring(left.slot or left.itemId)
        local rightKey = (right.source or 'owned') .. ':' .. tostring(right.slot or right.itemId)
        return leftKey < rightKey
    end)
    return selection
end

function Rules.GetMenuEntries(menu)
    local entries = {}
    for _, entry in pairs(menu and menu.selectedByKey or {}) do
        table.insert(entries, entry)
    end
    table.sort(entries, function(left, right)
        return tostring(left.name or left.itemId) < tostring(right.name or right.itemId)
    end)
    return entries
end

-- selection 格式：{ { slot = 背包欄位, count = 張數 }, ... }
-- 回傳正規化後的選擇；同一欄位會合併，總張數限 1～5。
function Rules.ValidateSelection(items, itemTemps, selection)
    if type(selection) ~= 'table' then
        return nil, 'selection must be a table'
    end

    local normalized = {}
    local bySlot = {}
    local total = 0

    for _, request in ipairs(selection) do
        local source = request and request.source or 'owned'
        local slot = tonumber(request and request.slot)
        local count = tonumber(request and request.count)
        local item = slot and items and items[slot]
        local itemId = item and tonumber(item.ItemTempID)
        if source == 'virtual' then
            itemId = tonumber(request and request.itemId)
        end
        local itemTemp = itemId and itemTemps and itemTemps[itemId]

        if not isPositiveInteger(count) then
            return nil, 'selection contains an invalid card count'
        end
        if source == 'owned' and not isPositiveInteger(slot) then
            return nil, 'selection contains an invalid slot or count'
        end
        if source ~= 'owned' and source ~= 'virtual' then
            return nil, 'selection contains an invalid source'
        end

        local isValid = source == 'owned'
            and Rules.IsEligibleCard(itemTemp)
            or source == 'virtual'
            and Rules.IsBattleReady(itemTemp)
        if not isValid then
            return nil, 'selection contains a non-battle living item'
        end

        local key = source == 'owned' and ('owned:' .. slot) or ('virtual:' .. itemId)
        local entry = bySlot[key]
        if entry == nil then
            entry = { source = source, slot = slot, itemId = itemId, count = 0 }
            bySlot[key] = entry
            table.insert(normalized, entry)
        end

        entry.count = entry.count + count
        total = total + count
    end

    if total < 1 or total > Rules.MAX_TEAM_SIZE then
        return nil, 'challenge requires one to five cards'
    end

    for _, entry in ipairs(normalized) do
        if entry.source == 'owned' then
            local item = items[entry.slot]
            local available = itemTotal(item) - itemStock(item)
            if entry.count > available then
                return nil, 'selection exceeds available card count'
            end
        end
    end

    return normalized
end

-- 只增加 Stock 預留，不扣 Count。這使勝利時不必再「加回」物品，
-- 避免重複觸發圖鑑、成就或新增物品副作用。
function Rules.ReserveSelection(items, normalizedSelection)
    local reservations = {}

    for _, entry in ipairs(normalizedSelection or {}) do
        if entry.source == 'virtual' then
            -- 虛擬圖鑑／首領敵人沒有背包欄位可預留。
        else
        local item = items and items[entry.slot]
        if item == nil or tonumber(item.ItemTempID) ~= entry.itemId then
            Rules.ReleaseReservations(items, reservations)
            return nil, 'inventory changed before reservation'
        end

        local stockBefore = itemStock(item)
        item.Stock = stockBefore + entry.count
        table.insert(reservations, {
            slot = entry.slot,
            itemId = entry.itemId,
            count = entry.count,
            stockBefore = stockBefore
        })
        end
    end

    return reservations
end

function Rules.ReleaseReservations(items, reservations)
    for _, reservation in ipairs(reservations or {}) do
        local item = items and items[reservation.slot]
        if item ~= nil and tonumber(item.ItemTempID) == reservation.itemId then
            -- 只移除本 MOD 增加的預留量。戰鬥中原版若另外增加同一物品的
            -- Stock（例如玩家仍有其他複本可召為護駕），不能被這裡覆蓋掉。
            local stockBefore = tonumber(reservation.stockBefore) or 0
            local remainingStock = itemStock(item) - reservation.count
            -- 讀檔可能已把 Stock 還原為開戰前值；此時 MOD 的暫態 reservation
            -- 仍在記憶體中，但不可再從新載入的背包扣一次。也保留戰鬥中其他
            -- 流程額外增加的 Stock。
            if remainingStock > stockBefore then
                item.Stock = remainingStock
            elseif stockBefore > 0 then
                item.Stock = stockBefore
            else
                item.Stock = nil
            end
        end
    end
end

-- 收妖後引擎已把一張同 ID 物品加入背包時，回傳可安全交給 ItemClass.DelItem
-- 的移除目標。實際刪除仍由原生 ItemClass 完成，以保留其堆疊規則。
function Rules.CountItemCopies(items, itemId)
    local wantedId = tonumber(itemId)
    if wantedId == nil or type(items) ~= 'table' then
        return 0
    end

    local total = 0
    for slot, item in ipairs(items) do
        if tonumber(item and item.ItemTempID) == wantedId and itemTotal(item) > 0 then
            total = total + itemTotal(item)
        end
    end

    return total
end

function Rules.FindCaptureRemoval(items, itemId, baselineCount)
    local wantedId = tonumber(itemId)
    if wantedId == nil or type(items) ~= 'table' then
        return nil
    end

    -- 只有背包確實比開戰前多出同 ID 卡片時才允許移除；收妖事件的回呼
    -- 順序在不同引擎版可能不同，不能只憑 mode=2 直接扣玩家原有物品。
    if baselineCount ~= nil
        and Rules.CountItemCopies(items, wantedId) <= tonumber(baselineCount) then
        return nil
    end

    for slot, item in ipairs(items) do
        if tonumber(item and item.ItemTempID) == wantedId and itemTotal(item) > 0 then
            return { slot = slot, itemId = wantedId, count = 1 }
        end
    end

    return nil
end

function Rules.BuildBattleField(normalizedSelection, options)
    local selection = normalizedSelection or {}
    local total = 0
    for _, entry in ipairs(selection) do
        total = total + entry.count
    end

    if total < 1 or total > Rules.MAX_TEAM_SIZE then
        return nil, 'challenge requires one to five cards'
    end

    options = options or {}
    local positions = options.positions or {
        { X = 176, Y = 294 },
        { X = 104, Y = 354 },
        { X = 248, Y = 364 },
        { X = 48, Y = 304 },
        { X = 304, Y = 304 }
    }

    local field = {
        iBattleFieldBackground = tonumber(options.backgroundId) or 4,
        MusicFileName = options.musicFileName or 'Battle_Europa01.mp3',
        tCharActQ = {}
    }

    for _, entry in ipairs(selection) do
        for _ = 1, entry.count do
            local position = positions[#field.tCharActQ + 1]
            if position == nil then
                return nil, 'not enough battle positions'
            end

            table.insert(field.tCharActQ, {
                ItemTempID = entry.itemId,
                X = position.X,
                Y = position.Y
            })
        end
    end

    return field
end

function Rules.BuildRewardValues(playerExp, money, mItemExp, specialSkillExp, allowNormalRewards)
    if allowNormalRewards == true then
        return {
            PlayerExp = playerExp,
            Money = money,
            MItemExp = mItemExp,
            SpecialSkillExp = specialSkillExp
        }
    end

    return {
        PlayerExp = 0,
        Money = 0,
        MItemExp = 0,
        SpecialSkillExp = 0
    }
end

-- 選卡面板的狀態機刻意不使用遊戲 API，方便在 mock runtime 中完整回歸。
-- focus：1..#cards 為卡片列，#cards+1 為開始，#cards+2 為取消。
function Rules.NewPanelState(cards)
    local panel = {
        cards = cards or {},
        focus = 1,
        scrollOffset = 0,
        selectedBySlot = {}
    }

    return panel
end

function Rules.GetPanelRowCount(panel)
    return #(panel and panel.cards or {}) + 2
end

function Rules.GetPanelTotal(panel)
    local total = 0
    for _, count in pairs(panel and panel.selectedBySlot or {}) do
        total = total + (tonumber(count) or 0)
    end
    return total
end

function Rules.GetPanelSelectedCount(panel, slot)
    return tonumber(panel and panel.selectedBySlot and panel.selectedBySlot[slot]) or 0
end

function Rules.MovePanelFocus(panel, delta)
    if type(panel) ~= 'table' then
        return nil
    end

    local rows = Rules.GetPanelRowCount(panel)
    panel.focus = ((tonumber(panel.focus) or 1) - 1 + delta) % rows + 1
    return panel.focus
end

function Rules.AdjustPanelCard(panel, cardIndex, delta)
    local card = panel and panel.cards and panel.cards[cardIndex]
    if card == nil then
        return false, 'focus is not a card row'
    end

    local oldCount = Rules.GetPanelSelectedCount(panel, card.slot)
    local nextCount = oldCount + delta
    if nextCount < 0 then
        return false, 'card is not selected'
    end

    if nextCount > (tonumber(card.available) or 0) then
        return false, 'selection exceeds available card count'
    end

    if Rules.GetPanelTotal(panel) - oldCount + nextCount > Rules.MAX_TEAM_SIZE then
        return false, 'challenge requires one to five cards'
    end

    if nextCount == 0 then
        panel.selectedBySlot[card.slot] = nil
    else
        panel.selectedBySlot[card.slot] = nextCount
    end

    return true, nextCount
end

function Rules.ToggleFocusedPanelCard(panel)
    local cardIndex = panel and tonumber(panel.focus)
    local card = cardIndex and panel.cards and panel.cards[cardIndex]
    if card == nil then
        return false, 'focus is not a card row'
    end

    local count = Rules.GetPanelSelectedCount(panel, card.slot)
    if count > 0 then
        panel.selectedBySlot[card.slot] = nil
        return true, 0
    end

    return Rules.AdjustPanelCard(panel, cardIndex, 1)
end

function Rules.BuildPanelSelection(panel)
    local selection = {}
    for _, card in ipairs(panel and panel.cards or {}) do
        local count = Rules.GetPanelSelectedCount(panel, card.slot)
        if count > 0 then
            table.insert(selection, { slot = card.slot, count = count })
        end
    end
    return selection
end

function Rules.ActivatePanelFocus(panel)
    if type(panel) ~= 'table' then
        return nil, 'panel is not available'
    end

    local cardCount = #panel.cards
    if panel.focus <= cardCount then
        return Rules.ToggleFocusedPanelCard(panel)
    end

    if panel.focus == cardCount + 1 then
        if Rules.GetPanelTotal(panel) < 1 then
            return nil, 'challenge requires one to five cards'
        end
        return 'start'
    end

    return 'cancel'
end

-- 由遊戲 UI 與測試共用的固定版面命中判定。
function Rules.HitTestPanel(panel, x, y, layout)
    if type(panel) ~= 'table' or type(layout) ~= 'table' then
        return nil
    end

    if x < layout.x or x > layout.x + layout.width then
        return nil
    end

    local cardCount = #panel.cards
    local scrollOffset = math.max(0, tonumber(panel.scrollOffset) or 0)
    local maxVisibleRows = math.max(1, tonumber(layout.maxVisibleRows) or cardCount)
    local visibleCount = math.min(maxVisibleRows, math.max(0, cardCount - scrollOffset))
    local firstCardY = layout.y + layout.headerHeight
    if y >= firstCardY and y < firstCardY + visibleCount * layout.rowHeight then
        local cardIndex = scrollOffset + math.floor((y - firstCardY) / layout.rowHeight) + 1
        local relativeX = x - layout.x
        if relativeX >= layout.minusX and relativeX < layout.minusX + layout.buttonWidth then
            return { type = 'card', cardIndex = cardIndex, delta = -1 }
        elseif relativeX >= layout.plusX and relativeX < layout.plusX + layout.buttonWidth then
            return { type = 'card', cardIndex = cardIndex, delta = 1 }
        end
        return { type = 'card', cardIndex = cardIndex, toggle = true }
    end

    local actionY = firstCardY + visibleCount * layout.rowHeight + layout.actionGap
    if y >= actionY and y < actionY + layout.actionHeight then
        return { type = 'start' }
    elseif y >= actionY + layout.actionHeight + layout.actionGap
        and y < actionY + layout.actionHeight * 2 + layout.actionGap then
        return { type = 'cancel' }
    end

    return nil
end
