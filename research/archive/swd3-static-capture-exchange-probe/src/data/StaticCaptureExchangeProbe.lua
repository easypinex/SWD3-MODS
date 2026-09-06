-- Steam HD 4.0.x：F2 進入一隻蛇的測試戰，以靈契收服；F1 清除靜態蛇卡。
-- ID 9004 在 MOD Lua 載入期建立，不在戰後或 GameStart 動態新增。

SWD3StaticCaptureExchangeProbe = SWD3StaticCaptureExchangeProbe or {}
local MOD = SWD3StaticCaptureExchangeProbe
local F1_SCANCODE = 58
local F2_SCANCODE = 59
local BATTLE_ID = 'SCEP_SNAKE_CAPTURE'
local SOURCE_ENEMY_ID = 102
local CARD_TEMPLATE_ID = 101
local STATIC_SNAKE_CARD_ID = 9004

MOD.state = MOD.state or { eventsRegistered = false }
local State = MOD.state

local function write(message)
    if type(log) == 'function' then
        log('[StaticCaptureExchangeProbe] ' .. tostring(message))
    end
end

local function shallowCopy(source)
    local copy = {}
    for key, value in pairs(source or {}) do copy[key] = value end
    return copy
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

local function currentBattleFieldId()
    if GameFunc == nil or type(GameFunc.GetBattleFieldID) ~= 'function' then return nil end
    local ok, value = pcall(GameFunc.GetBattleFieldID)
    return ok and value or nil
end

local function isProbeBattle()
    return State.active ~= nil and currentBattleFieldId() == BATTLE_ID
end

-- 最早可用的 MOD Lua 載入期：先複製原版卡的 UI 欄位，再覆蓋蛇的戰鬥資料。
local function installStaticSnakeCard()
    if GameData == nil or type(GameData.ItemTemp) ~= 'table' then
        MOD.staticFailure = 'GameData.ItemTemp is unavailable during MOD load'
        return false
    end
    local cardTemplate = GameData.ItemTemp[CARD_TEMPLATE_ID]
    local snake = GameData.ItemTemp[SOURCE_ENEMY_ID]
    if type(cardTemplate) ~= 'table' or cardTemplate.IT_12 ~= true then
        MOD.staticFailure = 'card template ItemTemp[101] is unavailable during MOD load'
        return false
    end
    if type(snake) ~= 'table' then
        MOD.staticFailure = 'snake ItemTemp[102] is unavailable during MOD load'
        return false
    end
    local existing = GameData.ItemTemp[STATIC_SNAKE_CARD_ID]
    if existing ~= nil and existing ~= MOD.staticSnakeCard then
        MOD.staticFailure = 'ItemTemp[9004] is occupied before probe load'
        return false
    end
    local card = shallowCopy(cardTemplate)
    for key, value in pairs(snake) do card[key] = value end
    card.Name = 'SCEP_SnakeCardName'
    card.HelpText = 'SCEP_SnakeCardHelp'
    card.InfoText = 'SCEP_SnakeCardInfo'
    card.IT_12 = true
    card.IT_06 = nil
    card.NotInBook = true
    card.DropItems = nil
    card.DropItemsRate = nil
    card.GainEXP = 0
    card.GainGold = 0
    GameData.ItemTemp[STATIC_SNAKE_CARD_ID] = card
    MOD.staticSnakeCard = card
    MOD.staticFailure = nil
    return true
end

local staticInstalled = installStaticSnakeCard()

local function applyEligibilityBridge(active)
    local snake = GameData and GameData.ItemTemp and GameData.ItemTemp[SOURCE_ENEMY_ID]
    if type(snake) ~= 'table' then return false, 'source snake is unavailable' end
    active.sourceHadIT12 = snake.IT_12 ~= nil
    active.sourceIT12 = snake.IT_12
    snake.IT_12 = true
    write('eligibility bridge applied: ItemTemp[102].IT_12=true (temporary)')
    return true
end

local function restoreEligibilityBridge(active)
    if active == nil or active.sourceHadIT12 == nil then return end
    local snake = GameData and GameData.ItemTemp and GameData.ItemTemp[SOURCE_ENEMY_ID]
    if type(snake) == 'table' then
        snake.IT_12 = active.sourceHadIT12 and active.sourceIT12 or nil
        write('eligibility bridge restored: ItemTemp[102].IT_12=' .. tostring(snake.IT_12))
    end
    active.sourceHadIT12 = nil
end

local function exchangeCapturedSource()
    local active = State.active
    if active == nil or active.exchanged or not active.captureObserved then return false end
    if countItemCopies(SOURCE_ENEMY_ID) <= active.sourceBaseline then return false end
    local slot = findItemSlot(SOURCE_ENEMY_ID)
    if slot == nil or type(ItemClass) ~= 'table' or type(ItemClass.DelItem) ~= 'function' then
        active.exchangeFailure = 'native source exists but cannot be removed safely'
        return false
    end
    local deleted, deleteResult = pcall(ItemClass.DelItem, slot, SOURCE_ENEMY_ID, 1, 0)
    if not deleted or deleteResult == -1 then
        active.exchangeFailure = 'source removal failed: ' .. tostring(deleteResult)
        return false
    end
    if type(ItemClass.AddItem) ~= 'function' then
        active.exchangeFailure = 'ItemClass.AddItem is unavailable after source removal'
        return false
    end
    local added, addResult = pcall(ItemClass.AddItem, STATIC_SNAKE_CARD_ID, 1, 0, false)
    if not added or addResult == -1 or addResult == -2 then
        active.exchangeFailure = 'static snake-card add failed: ' .. tostring(addResult)
        return false
    end
    active.exchanged = true
    write('confirmed: native source ID 102 exchanged for static snake card ID 9004')
    return true
end

local function finishProbe(reason)
    local active = State.active
    if active == nil then return end
    if active.captureObserved and not active.exchanged then
        exchangeCapturedSource()
    end
    if active.captureObserved and not active.exchanged then
        write('exchange unresolved at ' .. tostring(reason) .. ': ' .. tostring(active.exchangeFailure))
    end
    restoreEligibilityBridge(active)
    State.active = nil
    write('probe battle ended: ' .. tostring(reason))
end

local function startProbe()
    if State.active ~= nil then
        write('F2 ignored: a probe battle is already active')
        return
    end
    if not staticInstalled or GameData == nil or GameData.ItemTemp[STATIC_SNAKE_CARD_ID] ~= MOD.staticSnakeCard then
        write('F2 refused: static snake card unavailable (' .. tostring(MOD.staticFailure) .. ')')
        return
    end
    BattleField = BattleField or {}
    BattleField[BATTLE_ID] = {
        iBattleFieldBackground = 4,
        MusicFileName = 'Battle_Europa01.mp3',
        tCharActQ = { { ItemTempID = SOURCE_ENEMY_ID, X = 176, Y = 294 } }
    }
    State.active = { sourceBaseline = countItemCopies(SOURCE_ENEMY_ID), captureObserved = false, exchanged = false }
    local bridged, bridgeFailure = applyEligibilityBridge(State.active)
    if not bridged then
        State.active = nil
        write('F2 refused: ' .. tostring(bridgeFailure))
        return
    end
    local started, startFailure = pcall(ESC.StartBattle, BATTLE_ID)
    if not started then
        finishProbe('StartBattle failed')
        write('StartBattle failed: ' .. tostring(startFailure))
        return
    end
    write('snake battle started; use 靈契 on 蛇, do not defeat it normally')
end

Scene = Scene or {}
function Scene.SCEP_StartProbe()
    startProbe()
end

local function clearStaticSnakeCards()
    if State.active ~= nil then
        write('F1 cleanup refused during an active probe battle')
        return
    end
    local removed = 0
    while countItemCopies(STATIC_SNAKE_CARD_ID) > 0 do
        local slot = findItemSlot(STATIC_SNAKE_CARD_ID)
        if slot == nil or type(ItemClass) ~= 'table' or type(ItemClass.DelItem) ~= 'function' then
            write('F1 cleanup stopped; remaining=' .. tostring(countItemCopies(STATIC_SNAKE_CARD_ID)))
            return
        end
        local ok, result = pcall(ItemClass.DelItem, slot, STATIC_SNAKE_CARD_ID, 1, 0)
        if not ok or result == -1 then
            write('F1 cleanup failed: ' .. tostring(result))
            return
        end
        removed = removed + 1
    end
    write('F1 cleanup complete; removed=' .. tostring(removed))
end

local function onInputClick(_, keyScancode)
    if keyScancode == F1_SCANCODE then clearStaticSnakeCards(); return true end
    if keyScancode == F2_SCANCODE then
        local ok, failure = pcall(GameFunc.RunScene, -1, 'SCEP_StartProbe', 1)
        if not ok then write('F2 RunScene failed: ' .. tostring(failure)) end
        return true
    end
    return false
end

local function onBattleDead(index, side, mode)
    if not isProbeBattle() or side ~= 1 or mode ~= 2 then return end
    local enemy = BattleEnv and BattleEnv.enemys and BattleEnv.enemys[index]
    if enemy == nil or tonumber(enemy.GUID) ~= SOURCE_ENEMY_ID then return end
    State.active.captureObserved = true
    write('native Battle_Dead(mode=2) observed; waiting for native source-item addition')
end

local function onBattleRestoreItem()
    if State.active ~= nil then finishProbe('Battle_RestoreItem') end
end

local function onMapLoading()
    if State.active ~= nil then finishProbe('MapLoading') end
end

local function onGameStart()
    State.active = nil
    write('load-phase static snake card=' .. tostring(staticInstalled)
        .. '; F2=start snake capture, F1=remove ID 9004 before saving or disabling')
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
