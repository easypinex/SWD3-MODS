-- 軒轅劍參 Steam 高清版 4.0.x
-- 自由挑戰：以原生 ESC.Menu 場景處理選怪與輸入。
-- 公開 OnEvent 輸入 callback 不能 consume 物品欄事件；F9 只進入原生 Scene coroutine。

SWD3LiveCardBattle = SWD3LiveCardBattle or {}

local MOD = SWD3LiveCardBattle
local Rules = assert(MOD.Rules, '[LiveCardBattle] CardBattleRules.lua must load first')
local State = MOD.State or {}
MOD.State = State

local F9_SCANCODE = 66
local BATTLE_ID = 'MOD_CARD_CHALLENGE'
local MENU_DRAW_TIMEOUT_MS = 250
-- 原生 ESC.Menu 沒有可用的鍵盤取消鍵；縮短頁面，並在所有子選單首尾保留
-- 「返回上層」，讓滑鼠與每次重開選單後的鍵盤焦點都能立即找到安全出口。
local PAGE_SIZE = 7
-- Steam HD 的 ESC.Menu 會破壞選項列 UTF-8 尾端的少數位元組；實機確認四個
-- ASCII 空白可作為犧牲緩衝，且不會在畫面顯示。所有選項都必須經 nativeMenu。
local MENU_ROW_UTF8_PADDING = '    '

State.lastMenuDrawTick = State.lastMenuDrawTick or -10000
State.activeChallenge = State.activeChallenge or nil
State.selector = State.selector or nil
State.draft = State.draft or nil
State.selectorRunning = State.selectorRunning or false
State.challengeNoOverEnabled = State.challengeNoOverEnabled or false
State.challengeDefeatBreakRequested = State.challengeDefeatBreakRequested or false

local FALLBACK_TEXT = {
    LCB_TITLE = '挑戰模式',
    LCB_EMPTY = '沒有可挑戰的活物。',
    LCB_INVALID = '請先選擇 1～5 張活物。',
    LCB_BUSY = '挑戰正在進行中。',
    LCB_OWNED = '我的活物', LCB_CATALOGUE = '神魔異事錄（依種族）',
    LCB_SPECIAL = '特殊／首領', LCB_TEAM = '已選隊伍', LCB_START = '開始挑戰',
    LCB_RETURN = '返回物品欄', LCB_BACK = '返回上層', LCB_PREVIOUS = '上一頁',
    LCB_NEXT = '下一頁', LCB_REMOVE_ONE = '移除一張：', LCB_CLEAR_TEAM = '清空隊伍',
    LCB_SELECTED = '已選', LCB_DIFFICULTY = '難度調整',
    LCB_DIFFICULTY_HP = '生命', LCB_DIFFICULTY_ATTACK = '攻擊傷害',
    LCB_DIFFICULTY_DEFENSE = '防禦', LCB_DIFFICULTY_SPEED = '速度',
    LCB_DIFFICULTY_SKILL = '技能傷害', LCB_DIFFICULTY_CURRENT = '目前係數：',
    LCB_DIFFICULTY_DOWN = '降低 0.1x', LCB_DIFFICULTY_UP = '提高 0.1x',
    LCB_DIFFICULTY_RESET = '重設為 1.0x', LCB_DIFFICULTY_AVERAGE = '平均係數：',
    LCB_NO_REWARD = '本次無獎勵'
}

local DIFFICULTY_OPTIONS = {
    { key = 'hp', textKey = 'LCB_DIFFICULTY_HP' },
    { key = 'attack', textKey = 'LCB_DIFFICULTY_ATTACK' },
    { key = 'defense', textKey = 'LCB_DIFFICULTY_DEFENSE' },
    { key = 'speed', textKey = 'LCB_DIFFICULTY_SPEED' },
    { key = 'skill', textKey = 'LCB_DIFFICULTY_SKILL' }
}

local function write(message)
    if type(log) == 'function' then
        log('[LiveCardBattle] ' .. tostring(message))
    end
end

local function uiText(key)
    if type(StringDB) == 'function' then
        local ok, value = pcall(StringDB, key)
        if ok and type(value) == 'string' and value ~= '' and value ~= key then
            return value
        end
    end
    return FALLBACK_TEXT[key] or key
end

local function isInventoryMenuVisible()
    return type(GetTicks) == 'function'
        and GetTicks() - State.lastMenuDrawTick <= MENU_DRAW_TIMEOUT_MS
end

local function getItems()
    return SaveData and SaveData.Items or nil
end

local function getItemTemps()
    return GameData and GameData.ItemTemp or nil
end

-- 隊伍與難度是本次遊戲執行期間的選單草稿。不要保存到 SaveData：背包槽位
-- 可能在其他流程後改變，跨讀檔保存反而可能把過期槽位當成原本的活物。
local function getChallengeDraft()
    local draft = State.draft
    if type(draft) ~= 'table' or type(draft.selectedByKey) ~= 'table' then
        draft = Rules.NewMenuState()
        State.draft = draft
    end
    draft.difficulty = Rules.NormalizeDifficultySettings(draft.difficulty)
    return draft
end

local function resolveItemName(itemId, fallbackName)
    local nameKey = fallbackName
    if Function ~= nil and type(Function.GetItemTemp) == 'function' then
        local ok, value = pcall(Function.GetItemTemp, itemId, 'Name')
        if ok and type(value) == 'string' and value ~= '' then
            nameKey = value
        end
    end
    if type(StringDB) == 'function' and type(nameKey) == 'string' then
        local ok, localized = pcall(StringDB, nameKey)
        if ok and type(localized) == 'string' and localized ~= '' and localized ~= nameKey then
            return localized
        end
    end
    return tostring(nameKey or itemId)
end

local function localizeCards(cards)
    for _, card in ipairs(cards or {}) do
        card.name = resolveItemName(card.itemId, card.name)
    end
    return cards
end

local function isChallengeBattle()
    return State.activeChallenge ~= nil and GameFunc ~= nil
        and type(GameFunc.GetBattleFieldID) == 'function'
        and GameFunc.GetBattleFieldID() == BATTLE_ID
end

-- 宣告在前，讓敗北中止流程可呼叫下方的實作。
local settlePendingCaptures
local restoreNoRewardOverrides

local function releaseActiveChallenge(reason)
    State.challengeNoOverEnabled = false
    State.challengeDefeatBreakRequested = false
    local challenge = State.activeChallenge
    if challenge == nil then
        return
    end
    restoreNoRewardOverrides(challenge)
    Rules.ReleaseReservations(getItems(), challenge.reservations)
    State.activeChallenge = nil
    write('released card reservation: ' .. tostring(reason))
end

local function isDefeatedBattlePlayer(data)
    local character = data and data.self
    if character and type(character.isDeath) == 'function' then
        local ok, isDead = pcall(character.isDeath, character)
        if ok then
            return isDead == true
        end
    end
    local status = data and data.status
    return status ~= nil and (tonumber(status.HP) or 0) <= 0
end

local function areAllChallengePlayersDefeated()
    local players = BattleEnv and BattleEnv.players
    local foundPlayer = false
    for _, data in pairs(players or {}) do
        if data ~= nil then
            foundPlayer = true
            if not isDefeatedBattlePlayer(data) then
                return false
            end
        end
    end
    return foundPlayer
end

local function enableChallengeNoGameOver()
    if not isChallengeBattle() then
        return
    end
    if BSC == nil or type(BSC.NoOVER) ~= 'function' then
        write('challenge defeat fallback unavailable: BSC.NoOVER is not exposed')
        return
    end
    local ok, failure = pcall(BSC.NoOVER)
    if ok then
        State.challengeNoOverEnabled = true
        write('challenge defeat returns to game instead of Game Over')
    else
        write('challenge defeat fallback failed: ' .. tostring(failure))
    end
end

local function endChallengeAsDefeat()
    if State.challengeDefeatBreakRequested then
        return
    end
    State.challengeDefeatBreakRequested = true
    State.selector = nil
    State.selectorRunning = false
    settlePendingCaptures()
    releaseActiveChallenge('challenge defeat')
    if BSC == nil or type(BSC.BattleBreak) ~= 'function' then
        write('challenge defeat fallback unavailable: BSC.BattleBreak is not exposed')
        return
    end
    local ok, failure = pcall(BSC.BattleBreak)
    if ok then
        write('challenge defeat returned to game')
    else
        write('challenge defeat break failed: ' .. tostring(failure))
    end
end

local function buildCaptureBaseline(items, selection)
    local baseline = {}
    for _, entry in ipairs(selection or {}) do
        if baseline[entry.itemId] == nil then
            baseline[entry.itemId] = Rules.CountItemCopies(items, entry.itemId)
        end
    end
    return baseline
end

local function formatMultiplier(value)
    return string.format('%.1fx', Rules.NormalizeDifficultyMultiplier(value))
end

local function formatDifficultyAverage(value)
    return string.format('%.2fx', tonumber(value) or Rules.DEFAULT_DIFFICULTY_MULTIPLIER)
end

local function formatDifficultySettings(settings)
    local parts = {}
    for _, option in ipairs(DIFFICULTY_OPTIONS) do
        table.insert(parts, option.key .. '=' .. formatMultiplier(settings and settings[option.key]))
    end
    return table.concat(parts, ', ')
end

local function formatCombatStats(status)
    return string.format('HP=%s/%s ATK=%s DEF=%s SPD=%s WIS=%s',
        tostring(status and status.HP), tostring(status and status.MaxHP),
        tostring(status and status.ATK), tostring(status and status.DEF),
        tostring(status and status.SPD), tostring(status and status.WIS))
end

restoreNoRewardOverrides = function(challenge)
    for itemId, snapshot in pairs(challenge and challenge.noRewardOverrides or {}) do
        local item = getItemTemps() and getItemTemps()[itemId]
        if type(item) == 'table' then
            for field, saved in pairs(snapshot) do
                item[field] = saved.exists and saved.value or nil
            end
        end
    end
end

-- 低難度在原版結算前暫時移除敵人的基礎獎勵和一般掉落。這是短暫的
-- GameData 修改，必須只在本 MOD 戰場存活，並由所有離開路徑精確還原。
local function applyNoRewardOverrides(selection)
    local snapshots = {}
    for _, entry in ipairs(selection or {}) do
        local itemId = tonumber(entry.itemId)
        local item = itemId and getItemTemps() and getItemTemps()[itemId]
        if type(item) ~= 'table' then
            restoreNoRewardOverrides({ noRewardOverrides = snapshots })
            return nil, 'challenge enemy data is unavailable'
        end
        if snapshots[itemId] == nil then
            local snapshot = {}
            snapshots[itemId] = snapshot
            for _, field in ipairs({ 'GainEXP', 'GainGold', 'DropItems', 'DropItemsRate' }) do
                snapshot[field] = { exists = item[field] ~= nil, value = item[field] }
            end
            item.GainEXP = 0
            item.GainGold = 0
            item.DropItems = {}
            item.DropItemsRate = {}
        end
    end
    return snapshots
end

local function startChallenge()
    local selector = State.selector
    if selector == nil then
        return false, 'selector is unavailable'
    end
    local items = getItems()
    local normalized, validationError = Rules.ValidateSelection(
        items, getItemTemps(), Rules.BuildMenuSelection(selector)
    )
    if normalized == nil then
        return false, validationError
    end
    local reservations, reservationError = Rules.ReserveSelection(items, normalized)
    if reservations == nil then
        return false, reservationError
    end
    local difficulty = Rules.NormalizeDifficultySettings(selector.difficulty)
    local rewardsAllowed = Rules.IsRewardAllowedForDifficulty(difficulty)
    local field, fieldError = Rules.BuildBattleField(normalized, {
        backgroundId = 4,
        musicFileName = 'Battle_Europa01.mp3'
    })
    if field == nil then
        Rules.ReleaseReservations(items, reservations)
        return false, fieldError
    end

    local noRewardOverrides = {}
    if not rewardsAllowed then
        noRewardOverrides, fieldError = applyNoRewardOverrides(normalized)
        if noRewardOverrides == nil then
            Rules.ReleaseReservations(items, reservations)
            return false, fieldError
        end
    end

    BattleField = BattleField or {}
    BattleField[BATTLE_ID] = field
    State.activeChallenge = {
        selection = normalized,
        reservations = reservations,
        captureBaseline = buildCaptureBaseline(items, normalized),
        pendingCaptureById = {},
        capturedById = {},
        difficulty = difficulty,
        rewardsAllowed = rewardsAllowed,
        noRewardOverrides = noRewardOverrides,
        scaledEnemyIndexes = {}
    }
    State.selector = nil
    -- ESC.StartBattle 可能直接切走並中止目前的選單 coroutine；不能依賴
    -- LCB_LiveCardBattleMenu 的尾端才清除這個旗標。從此刻起選單已交出
    -- 控制權給戰鬥，F9 不應再被視為有一個未結束的選單。
    State.selectorRunning = false
    local ok, failure = pcall(ESC.StartBattle, BATTLE_ID)
    if not ok then
        releaseActiveChallenge('start battle failed')
        return false, failure
    end
    write(string.format('challenge difficulty: %s; average=%s; rewards=%s',
        formatDifficultySettings(difficulty), formatDifficultyAverage(Rules.GetDifficultyAverage(difficulty)),
        rewardsAllowed and 'normal' or 'disabled'))
    write(string.format('started challenge with %d card(s)', #field.tCharActQ))
    return true
end

-- 此函式只能由下方 Scene coroutine 呼叫；它會等待原生鍵盤／滑鼠選取。
-- Steam HD 的 ESC.Menu 是唯一已實機確認可以回到多層選單的入口。
-- 不要在呼叫端手動補空白或改用 ESC.Menu；統一在此處加入已實機驗證的緩衝。
local function nativeMenu(rows)
    local menuRows = {}
    for _, row in ipairs(rows or {}) do
        table.insert(menuRows, tostring(row) .. MENU_ROW_UTF8_PADDING)
    end
    local ok, failure = pcall(ESC.Menu, uiText('LCB_TITLE'), menuRows)
    if not ok then
        write('ESC.Menu failed: ' .. tostring(failure))
        return 0
    end
    local readOk, selected = pcall(ESC.GetMENUSelect)
    if not readOk then
        write('ESC.GetMENUSelect failed: ' .. tostring(selected))
        return 0
    end
    return tonumber(selected) or 0
end

local function formatCardRow(card, selected)
    return string.format('%s  Lv.%d  %s %d', card.name, card.level or 0, uiText('LCB_SELECTED'), selected or 0)
end

local function showCardList(title, cards, selector)
    if #cards == 0 then
        nativeMenu({ uiText('LCB_BACK'), title .. '：' .. uiText('LCB_EMPTY'), uiText('LCB_BACK') })
        return
    end
    local page = 1
    local pageCount = math.max(1, math.ceil(#cards / PAGE_SIZE))
    while true do
        local first = (page - 1) * PAGE_SIZE + 1
        local last = math.min(#cards, first + PAGE_SIZE - 1)
        local rows, rowCards = { uiText('LCB_BACK') }, { 'return' }
        if pageCount > 1 and page > 1 then
            table.insert(rows, uiText('LCB_PREVIOUS'))
            table.insert(rowCards, false)
        end
        for index = first, last do
            local card = cards[index]
            table.insert(rows, formatCardRow(card, Rules.GetMenuSelectedCount(selector, card)))
            table.insert(rowCards, card)
        end
        if pageCount > 1 and page < pageCount then
            table.insert(rows, uiText('LCB_NEXT'))
            table.insert(rowCards, 'next')
        end
        table.insert(rows, uiText('LCB_BACK'))
        table.insert(rowCards, 'return')

        local selected = nativeMenu(rows)
        local selectedCard = rowCards[selected]
        if selected == 0 or selectedCard == 'return' then
            return
        elseif selectedCard == false then
            page = page - 1
        elseif selectedCard == 'next' then
            page = page + 1
        elseif type(selectedCard) == 'table' then
            local changed, reason = Rules.AdjustMenuCard(selector, selectedCard, 1)
            if not changed then
                write(title .. ' selection unchanged: ' .. tostring(reason))
            end
        end
    end
end

local function raceName(raceId)
    local race = GameData and GameData.Race and GameData.Race[raceId]
    local name = race and (race.Name or race.name)
    if type(StringDB) == 'function' and type(name) == 'string' then
        local ok, localized = pcall(StringDB, name)
        if ok and type(localized) == 'string' and localized ~= '' and localized ~= name then
            return localized
        end
    end
    return tostring(name or ('種族 ' .. tostring(raceId)))
end

local function showCatalogue(selector)
    local cards = localizeCards(Rules.GetCatalogueCards(getItemTemps()))
    local groups = {}
    for _, card in ipairs(cards) do
        local raceId = card.race or -1
        groups[raceId] = groups[raceId] or {}
        table.insert(groups[raceId], card)
    end
    local raceIds = {}
    for raceId in pairs(groups) do
        table.insert(raceIds, raceId)
    end
    table.sort(raceIds)

    local page = 1
    local pageCount = math.max(1, math.ceil(#raceIds / PAGE_SIZE))
    while true do
        local first = (page - 1) * PAGE_SIZE + 1
        local last = math.min(#raceIds, first + PAGE_SIZE - 1)
        local rows, rowRaces = { uiText('LCB_BACK') }, { 'return' }
        if pageCount > 1 and page > 1 then
            table.insert(rows, uiText('LCB_PREVIOUS'))
            table.insert(rowRaces, 'previous')
        end
        for index = first, last do
            local raceId = raceIds[index]
            table.insert(rows, string.format('%s [%d]', raceName(raceId), #groups[raceId]))
            table.insert(rowRaces, raceId)
        end
        if pageCount > 1 and page < pageCount then
            table.insert(rows, uiText('LCB_NEXT'))
            table.insert(rowRaces, 'next')
        end
        table.insert(rows, uiText('LCB_BACK'))
        table.insert(rowRaces, 'return')
        local selected = nativeMenu(rows)
        local selectedRace = rowRaces[selected]
        if selected == 0 or selectedRace == 'return' then
            return
        end
        if selectedRace == 'previous' then
            page = page - 1
        elseif selectedRace == 'next' then
            page = page + 1
        elseif type(selectedRace) == 'number' then
            showCardList(raceName(selectedRace), groups[selectedRace], selector)
        end
    end
end

local function showTeam(selector)
    while true do
        local entries = Rules.GetMenuEntries(selector)
        local rows, rowEntries = { uiText('LCB_BACK') }, { 'return' }
        for _, entry in ipairs(entries) do
            table.insert(rows, string.format('%s%s  Lv.%d [%d]', uiText('LCB_REMOVE_ONE'), entry.name, entry.level or 0, entry.count))
            table.insert(rowEntries, entry)
        end
        if #entries > 0 then
            table.insert(rows, uiText('LCB_CLEAR_TEAM'))
            table.insert(rowEntries, 'clear')
        end
        table.insert(rows, uiText('LCB_BACK'))
        table.insert(rowEntries, 'return')
        local selected = nativeMenu(rows)
        local selectedEntry = rowEntries[selected]
        if selected == 0 or selectedEntry == 'return' then
            return
        end
        if type(selectedEntry) == 'table' then
            Rules.AdjustMenuCard(selector, selectedEntry, -1)
        elseif selectedEntry == 'clear' then
            selector.selectedByKey = {}
        end
    end
end

local function showDifficultyAdjustment(selector, option)
    while true do
        local value = selector.difficulty[option.key]
        local rows = {
            uiText('LCB_BACK'),
            uiText('LCB_DIFFICULTY_CURRENT') .. formatMultiplier(value),
            uiText('LCB_DIFFICULTY_DOWN'),
            uiText('LCB_DIFFICULTY_UP'),
            uiText('LCB_DIFFICULTY_RESET'),
            uiText('LCB_BACK')
        }
        local selected = nativeMenu(rows)
        if selected == 0 or selected == 1 or selected == 6 then
            return
        elseif selected == 3 then
            Rules.AdjustDifficultySetting(selector.difficulty, option.key, -Rules.DIFFICULTY_MULTIPLIER_STEP)
        elseif selected == 4 then
            Rules.AdjustDifficultySetting(selector.difficulty, option.key, Rules.DIFFICULTY_MULTIPLIER_STEP)
        elseif selected == 5 then
            selector.difficulty[option.key] = Rules.DEFAULT_DIFFICULTY_MULTIPLIER
        end
    end
end

local function showDifficultySettings(selector)
    while true do
        local rows, rowOptions = { uiText('LCB_BACK') }, { 'return' }
        for _, option in ipairs(DIFFICULTY_OPTIONS) do
            table.insert(rows, string.format('%s：%s', uiText(option.textKey), formatMultiplier(selector.difficulty[option.key])))
            table.insert(rowOptions, option)
        end
        table.insert(rows, uiText('LCB_DIFFICULTY_AVERAGE') .. formatDifficultyAverage(Rules.GetDifficultyAverage(selector.difficulty)))
        table.insert(rowOptions, false)
        if not Rules.IsRewardAllowedForDifficulty(selector.difficulty) then
            table.insert(rows, uiText('LCB_NO_REWARD'))
            table.insert(rowOptions, false)
        end
        table.insert(rows, uiText('LCB_BACK'))
        table.insert(rowOptions, 'return')

        local selected = nativeMenu(rows)
        local option = rowOptions[selected]
        if selected == 0 or option == 'return' then
            return
        elseif type(option) == 'table' then
            showDifficultyAdjustment(selector, option)
        end
    end
end

Scene = Scene or {}

function Scene.LCB_LiveCardBattleMenu()
    if State.activeChallenge ~= nil then
        write('selector refused: ' .. uiText('LCB_BUSY'))
        return
    end
    State.selectorRunning = true
    State.selector = getChallengeDraft()
    write('native selector opened')
    while State.selector ~= nil do
        local selected = nativeMenu({
            uiText('LCB_OWNED'),
            uiText('LCB_CATALOGUE'),
            uiText('LCB_SPECIAL'),
            string.format('%s [%d/%d]', uiText('LCB_TEAM'), Rules.GetMenuTotal(State.selector), Rules.MAX_TEAM_SIZE),
            uiText('LCB_DIFFICULTY'),
            uiText('LCB_START'),
            uiText('LCB_RETURN')
        })
        if selected == 0 or selected == 7 then
            State.selector = nil
        elseif selected == 1 then
            showCardList(uiText('LCB_OWNED'), localizeCards(Rules.GetAvailableCards(getItems(), getItemTemps())), State.selector)
        elseif selected == 2 then
            showCatalogue(State.selector)
        elseif selected == 3 then
            showCardList(uiText('LCB_SPECIAL'), localizeCards(Rules.GetSpecialCards(getItemTemps())), State.selector)
        elseif selected == 4 then
            showTeam(State.selector)
        elseif selected == 5 then
            showDifficultySettings(State.selector)
        elseif selected == 6 then
            local started, reason = startChallenge()
            if started then
                break
            end
            write('challenge start refused: ' .. tostring(reason or uiText('LCB_INVALID')))
        end
    end
    State.selectorRunning = false
    write('native selector closed')
end

local function removeCapturedCard(challenge, itemId)
    local removal = Rules.FindCaptureRemoval(getItems(), itemId, challenge.captureBaseline[itemId])
    if removal == nil or ItemClass == nil or type(ItemClass.DelItem) ~= 'function' then
        return false
    end
    ItemClass.DelItem(removal.slot, removal.itemId, removal.count, 0)
    challenge.capturedById[itemId] = (challenge.capturedById[itemId] or 0) + 1
    write('removed captured challenge card ' .. tostring(itemId))
    return true
end

-- 全魔物靈契已武裝時，它會在 Battle_RestoreItem 以同一場開戰基線
-- 將原生新增的來源物交換成靜態卡。自由挑戰若在 Battle_Dead 先刪來源物，
-- 會令該安全交換看不到新增量；因此只對其正式卡庫範圍交接處理。
local function delegateCaptureToStaticCatalogue(itemId)
    local capture = SWD3AllMonsterStaticCapture
    if type(capture) ~= 'table' or type(capture.captureRuntime) ~= 'table'
        or type(capture.captureRuntime.active) ~= 'table' or type(capture.CardIdForEnemy) ~= 'function' then
        return false
    end
    local ok, cardId = pcall(capture.CardIdForEnemy, itemId)
    return ok and tonumber(cardId) ~= nil
end

settlePendingCaptures = function()
    local challenge = State.activeChallenge
    if challenge == nil then
        return
    end
    for itemId, pending in pairs(challenge.pendingCaptureById) do
        while pending > 0 and removeCapturedCard(challenge, itemId) do
            pending = pending - 1
        end
        challenge.pendingCaptureById[itemId] = pending
    end
end

local function onBattleDead(index, side, mode)
    if not isChallengeBattle() then
        return
    end
    if side == 0 then
        if State.challengeNoOverEnabled and areAllChallengePlayersDefeated() then
            endChallengeAsDefeat()
        end
        return
    end
    if side == 1 and mode == 2 then
        local enemy = BattleEnv and BattleEnv.enemys and BattleEnv.enemys[index]
        local itemId = enemy and tonumber(enemy.GUID)
        if itemId ~= nil then
            if delegateCaptureToStaticCatalogue(itemId) then
                write('delegated captured challenge card ' .. tostring(itemId)
                    .. ' to AllMonsterStaticCapture exchange')
                return
            end
            local challenge = State.activeChallenge
            challenge.pendingCaptureById[itemId] = (challenge.pendingCaptureById[itemId] or 0) + 1
            settlePendingCaptures()
        end
    end
end

-- 此 callback 在原版 Battle_EnemyInit.main 之後追加，因此 NPCData 已經是
-- 僅屬本次戰鬥的敵方資料。只改本 MOD 戰場，並以 index 防止 callback 重入
-- 導致倍率被重複套用。
local function onBattleEnemyInit(index)
    if not isChallengeBattle() then
        return
    end
    local challenge = State.activeChallenge
    if challenge.scaledEnemyIndexes[index] then
        return
    end
    local enemy = BattleEnemys and BattleEnemys[index]
    local status = enemy and enemy.NPCData
    if status == nil then
        write('difficulty scaling skipped: enemy NPCData is unavailable for index ' .. tostring(index))
        return
    end
    local difficulty = challenge.difficulty or Rules.NewDifficultySettings()
    local ok, failure = pcall(function()
        local before = formatCombatStats(status)
        local originalHP = status.HP
        status.HP = Rules.ScaleDifficultyStat(originalHP, difficulty.hp)
        if tonumber(status.MaxHP) and tonumber(status.MaxHP) > 0 then
            status.MaxHP = Rules.ScaleDifficultyStat(status.MaxHP, difficulty.hp)
        else
            status.MaxHP = status.HP
        end
        status.ATK = Rules.ScaleDifficultyStat(status.ATK, difficulty.attack)
        status.DEF = Rules.ScaleDifficultyStat(status.DEF, difficulty.defense)
        status.SPD = Rules.ScaleDifficultyStat(status.SPD, difficulty.speed)
        -- 原版傷害核心未公開直接的「技能傷害」callback；技能係數對應其
        -- 已初始化的 WIS 戰鬥屬性，仍須在實機逐一驗證不同技能類型的效果。
        status.WIS = Rules.ScaleDifficultyStat(status.WIS, difficulty.skill)
        write(string.format('difficulty applied: enemyIndex=%s, id=%s; before {%s}; after {%s}',
            tostring(index), tostring(enemy.NPC_GUID), before, formatCombatStats(status)))
    end)
    if ok then
        challenge.scaledEnemyIndexes[index] = true
    else
        write('difficulty scaling failed for enemy ' .. tostring(index) .. ': ' .. tostring(failure))
    end
end

local function onBattleGain(playerExp, money, mItemExp, specialSkillExp)
    if not isChallengeBattle() then
        return
    end
    local challenge = State.activeChallenge
    if challenge == nil or challenge.rewardsAllowed then
        return
    end
    if type(OnEventValue) ~= 'table' then
        write('no-reward override failed: OnEventValue is unavailable')
        return
    end
    local rewards = Rules.BuildRewardValues(playerExp, money, mItemExp, specialSkillExp, false)
    OnEventValue.PlayerExp = rewards.PlayerExp
    OnEventValue.Money = rewards.Money
    OnEventValue.MItemExp = rewards.MItemExp
    OnEventValue.SpecialSkillExp = rewards.SpecialSkillExp
    if not challenge.rewardLogWritten then
        challenge.rewardLogWritten = true
        write('rewards disabled because the difficulty average is below 1.0x')
    end
end

local function onBattleRestoreItem()
    -- ESC.StartBattle 在部分結束路徑不會回到選單 coroutine；不要依賴其尾端清理。
    State.selector = nil
    State.selectorRunning = false
    if State.activeChallenge ~= nil then
        settlePendingCaptures()
        releaseActiveChallenge('battle restore item')
    end
end

local function onMapLoading()
    State.selector = nil
    State.selectorRunning = false
    settlePendingCaptures()
    releaseActiveChallenge('map loading')
end

local function onGameStart()
    State.selector = nil
    State.selectorRunning = false
    releaseActiveChallenge('game start')
    State.draft = Rules.NewMenuState()
    write('loaded; open the native item basket and press F9')
end

local function onDrawMenuAfter()
    State.lastMenuDrawTick = GetTicks()
    -- 主修復在 ESC.StartBattle 前已結束 selectorRunning。這裡僅是防呆：若其他
    -- 非預期引擎中斷仍留下旗標，只有回到物品欄、挑戰已建立且不再處於本 MOD
    -- 戰鬥時，才判為安全的遺留狀態。
    if State.selectorRunning and State.activeChallenge ~= nil and not isChallengeBattle() then
        State.selector = nil
        State.selectorRunning = false
        settlePendingCaptures()
        releaseActiveChallenge('stale selector recovered from inventory draw')
        write('recovered stale selector after interrupted battle')
    end
end

local function onInputClick(_, keyScancode)
    if keyScancode ~= F9_SCANCODE then
        return false
    end
    if State.selectorRunning then
        write('ignored F9: selector is already running; use 返回物品欄 or click empty menu area')
        return true
    end
    if not isInventoryMenuVisible() then
        return false
    end
    local ok, failure = pcall(GameFunc.RunScene, -1, 'LCB_LiveCardBattleMenu', 0)
    if not ok then
        write('RunScene failed: ' .. tostring(failure))
    end
    return true
end

OnEvent = OnEvent or {}
OnEvent.GameStart = OnEvent.GameStart or {}
OnEvent.DrawMenuAfter = OnEvent.DrawMenuAfter or {}
OnEvent.InputClick = OnEvent.InputClick or {}
OnEvent.Battle_Dead = OnEvent.Battle_Dead or {}
OnEvent.Battle_Enter = OnEvent.Battle_Enter or {}
OnEvent.Battle_EnemyInit = OnEvent.Battle_EnemyInit or {}
OnEvent.BattleGain = OnEvent.BattleGain or {}
OnEvent.Battle_RestoreItem = OnEvent.Battle_RestoreItem or {}
OnEvent.MapLoading = OnEvent.MapLoading or {}

if not State.eventsRegistered then
    table.insert(OnEvent.GameStart, onGameStart)
    table.insert(OnEvent.DrawMenuAfter, onDrawMenuAfter)
    table.insert(OnEvent.InputClick, onInputClick)
    table.insert(OnEvent.Battle_Dead, onBattleDead)
    table.insert(OnEvent.Battle_Enter, enableChallengeNoGameOver)
    table.insert(OnEvent.Battle_EnemyInit, onBattleEnemyInit)
    table.insert(OnEvent.BattleGain, onBattleGain)
    table.insert(OnEvent.Battle_RestoreItem, onBattleRestoreItem)
    table.insert(OnEvent.MapLoading, onMapLoading)
    State.eventsRegistered = true
end

function MOD.GetInputCaptureStatus()
    return {
        selectorRunning = State.selectorRunning,
        inventoryMenuVisible = isInventoryMenuVisible(),
        challengeActive = State.activeChallenge ~= nil,
        implementation = 'native ESC.Menu Scene coroutine'
    }
end
