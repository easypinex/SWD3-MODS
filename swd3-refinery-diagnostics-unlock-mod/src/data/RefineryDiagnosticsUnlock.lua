-- 軒轅劍參：雲和山的彼端 Steam 高清版 4.0.x
-- 煉化條件診斷與東、西方成品等級限制解除

SWD3RefineryDiagnostics = SWD3RefineryDiagnostics or {}

local MOD = SWD3RefineryDiagnostics
local State = MOD.State or {}
MOD.State = State

local ALTAR_ITEM_ID = 771
local SLIME_ITEM_ID = 101
local E_SCANCODE = 8
local Q_SCANCODE = 20
local RIGHT_SCANCODE = 79
local LEFT_SCANCODE = 80
local END_SCANCODE = 77
local unpackValues = unpack or table.unpack

local UI_FALLBACK = {
    RDU_TITLE = '[REFINERY DIAGNOSTICS]',
    RDU_MATERIALS = 'MATERIALS: ',
    RDU_UNLOCKED = 'LEVEL LIMIT: UNLOCKED',
    RDU_WEST = 'WEST RESULT: ',
    RDU_EAST = 'EAST RESULT: ',
    RDU_TRUE_LEVEL = 'TRUE LEVEL',
    RDU_VANILLA_SETH = 'VANILLA SETH NEED',
    RDU_ALTAR_OWNED = 'ALTAR: OWNED',
    RDU_ALTAR_MISSING = 'ALTAR: NOT OWNED; PRESS END FOR EAST',
    RDU_ALTAR_UNKNOWN = 'ALTAR: UNKNOWN',
    RDU_SETH_LAST = 'LAST BATTLE SETH',
    RDU_SETH_UNKNOWN = 'SETH LEVEL: NOT SYNCED',
    RDU_NOW_EAST = 'NOW: EAST RESULT',
    RDU_NEXT_END = 'NEXT: PRESS END FOR EAST; OK TO CRAFT',
    RDU_NEXT_OK = 'NEXT: OK OR CLICK TO CRAFT',
    RDU_SLIME = 'SLIME: RECIPE RESULT, NOT LEVEL FAILURE'
}

local uiTextCache = {}

local function uiText(key)
    if uiTextCache[key] ~= nil then
        return uiTextCache[key]
    end

    if type(StringDB) == 'function' then
        local ok, value = pcall(StringDB, key)
        if ok and type(value) == 'string' and value ~= '' and value ~= key then
            uiTextCache[key] = value
            return value
        end
    end

    uiTextCache[key] = UI_FALLBACK[key] or key
    return uiTextCache[key]
end

State.patchedLevels = State.patchedLevels or {}
State.preview = nil
State.eastPreviewActive = false
State.materialSignature = nil
State.awaitBattleLevel = false
State.panelLogSignature = nil

local function eventFlag(keyFuncIndex)
    if DefineKeyFunc == nil or keyFuncIndex == nil then
        return nil
    end

    return DefineKeyFunc[keyFuncIndex]
end

local function hasFlag(value, flag)
    if type(value) ~= 'number' or type(flag) ~= 'number' or flag <= 0 then
        return false
    end

    return value % (flag * 2) >= flag
end

local function restorePatchedLevels(reason)
    local failures = 0

    for itemId, trueLevel in pairs(State.patchedLevels) do
        local itemData = GameData
            and GameData.ItemTemp
            and GameData.ItemTemp[itemId]

        if itemData ~= nil then
            itemData.Level = trueLevel
            if itemData.Level ~= trueLevel then
                failures = failures + 1
            end
        else
            failures = failures + 1
        end
    end

    State.patchedLevels = {}

    if failures > 0 then
        log(string.format(
            '[RefineryDiagnostics] Failed to restore %d item level(s), reason=%s',
            failures,
            tostring(reason)
        ))
    end

    return failures == 0
end

local function clearPreview(reason)
    restorePatchedLevels(reason or 'clear')
    State.preview = nil
    State.eastPreviewActive = false
    State.materialSignature = nil
    State.panelLogSignature = nil
end

local function getItemName(itemId)
    if Function ~= nil and type(Function.GetItemTemp) == 'function' then
        local ok, name = pcall(Function.GetItemTemp, itemId, 'Name')
        if ok and name ~= nil and tostring(name) ~= '' then
            return tostring(name)
        end
    end

    local itemData = GameData
        and GameData.ItemTemp
        and GameData.ItemTemp[itemId]

    if itemData ~= nil and itemData.Name ~= nil then
        return tostring(itemData.Name)
    end

    return string.format('物品 %s', tostring(itemId))
end

local function captureMaterial(itemtab)
    local slot = tonumber(itemtab)
    local item = SaveData and SaveData.Items and SaveData.Items[slot]
    local itemId = item and tonumber(item.ItemTempID)

    if slot == nil or itemId == nil then
        return { slot = slot, id = itemId, name = '未知材料' }
    end

    return {
        slot = slot,
        id = itemId,
        name = getItemName(itemId)
    }
end

local function captureResult(itemId)
    if type(itemId) ~= 'number' then
        return nil
    end

    local itemData = GameData
        and GameData.ItemTemp
        and GameData.ItemTemp[itemId]

    if itemData == nil or type(itemData.Level) ~= 'number' then
        return nil
    end

    local trueLevel = itemData.Level

    return {
        id = itemId,
        name = getItemName(itemId),
        level = trueLevel,
        minimumSethLevel = math.max(1, trueLevel - 6),
        isSlime = itemId == SLIME_ITEM_ID
    }
end

local function patchResultLevel(result)
    if result == nil then
        return false
    end

    local itemData = GameData
        and GameData.ItemTemp
        and GameData.ItemTemp[result.id]

    if itemData == nil or type(itemData.Level) ~= 'number' then
        return false
    end

    if State.patchedLevels[result.id] == nil then
        State.patchedLevels[result.id] = itemData.Level
    end

    itemData.Level = 1
    return true
end

local function materialSignature(itemtab1, itemtab2)
    local first = tonumber(itemtab1)
    local second = tonumber(itemtab2)

    if first == nil or second == nil then
        return nil
    end

    if first > second then
        first, second = second, first
    end

    return string.format('%d:%d', first, second)
end

local function saveTable()
    if SaveData == nil then
        return nil
    end

    SaveData.SWD3RefineryDiagnostics =
        SaveData.SWD3RefineryDiagnostics or {}

    return SaveData.SWD3RefineryDiagnostics
end

local function getLastSethLevel()
    local data = saveTable()
    if data == nil then
        return nil
    end

    local level = tonumber(data.LastSethLevel)
    if level == nil or level < 1 then
        return nil
    end

    return math.floor(level)
end

local function syncSethLevelFromBattle()
    if not State.awaitBattleLevel then
        return
    end

    local player = BattlePlayers and BattlePlayers[1]
    local level = player and player.CharData and tonumber(player.CharData.Level)

    if level == nil or level < 1 then
        return
    end

    local data = saveTable()
    if data ~= nil then
        data.LastSethLevel = math.floor(level)
        State.awaitBattleLevel = false
    end
end

local function altarOwned()
    if GameFunc == nil or type(GameFunc.PlayerItemCount) ~= 'function' then
        return nil
    end

    local ok, count = pcall(GameFunc.PlayerItemCount, ALTAR_ITEM_ID)
    if not ok or type(count) ~= 'number' then
        return nil
    end

    return count > 0
end

local function pack(...)
    return { n = select('#', ...), ... }
end

local function tracebackMessage(message)
    if debug ~= nil and type(debug.traceback) == 'function' then
        return debug.traceback(tostring(message), 2)
    end

    return tostring(message)
end

local function installWrapper()
    OnEvent = OnEvent or {}
    OnEvent.Obsolt = OnEvent.Obsolt or {}

    if State.installedWrapper ~= nil
        and OnEvent.Obsolt.main == State.installedWrapper then
        return true
    end

    local previousMain = OnEvent.Obsolt.main
    if type(previousMain) ~= 'function' then
        log('[RefineryDiagnostics] Refinery function unavailable; wrapper not installed')
        return false
    end

    local wrapper
    wrapper = function(itemtab1, itemtab2, doing)
        local execution = (tonumber(doing) or 0) >= 1
        restorePatchedLevels(execution and 'before execution' or 'before preview')

        if execution then
            State.preview = nil
            State.eastPreviewActive = false
            State.materialSignature = nil
        end

        local callResults
        local ok, failure = xpcall(function()
            callResults = pack(previousMain(itemtab1, itemtab2, doing))

            if not execution then
                local signature = materialSignature(itemtab1, itemtab2)
                if signature ~= State.materialSignature
                    and altarOwned() ~= true then
                    State.eastPreviewActive = false
                end

                State.materialSignature = signature

                local east = captureResult(
                    OnEventValue and tonumber(OnEventValue.CalcResEast)
                )
                local west = captureResult(
                    OnEventValue and tonumber(OnEventValue.CalcResWest)
                )

                if signature ~= nil and east ~= nil and west ~= nil then
                    State.preview = {
                        material1 = captureMaterial(itemtab1),
                        material2 = captureMaterial(itemtab2),
                        east = east,
                        west = west
                    }

                    patchResultLevel(east)
                    patchResultLevel(west)
                else
                    clearPreview('invalid preview')
                end
            end
        end, tracebackMessage)

        if not ok then
            clearPreview('refinery error')
            log('[RefineryDiagnostics] Refinery wrapper error: ' .. tostring(failure))
            error(failure)
        end

        return unpackValues(callResults, 1, callResults.n)
    end

    State.previousMain = previousMain
    State.installedWrapper = wrapper
    OnEvent.Obsolt.main = wrapper

    log('[RefineryDiagnostics] Installed refinery wrapper; East/West level limits unlocked')
    return true
end

local function drawText(text, x, y, color, shadow)
    StringFunc.DrawString(text, x, y, 0, color, shadow, 1)
end

local function drawResultLine(label, result, x, y, color, shadow)
    drawText(
        label .. result.name,
        x,
        y,
        color,
        shadow
    )

    drawText(
        string.format(
            '  %s Lv.%d | %s Lv.%d',
            uiText('RDU_TRUE_LEVEL'),
            result.level,
            uiText('RDU_VANILLA_SETH'),
            result.minimumSethLevel
        ),
        x,
        y + 19,
        color,
        shadow
    )
end

local function altarStatusText()
    local owned = altarOwned()
    if owned == true then
        return uiText('RDU_ALTAR_OWNED'), owned
    elseif owned == false then
        return uiText('RDU_ALTAR_MISSING'), owned
    end

    return uiText('RDU_ALTAR_UNKNOWN'), owned
end

local function logReadableDiagnostics(preview)
    local altarText = altarStatusText()
    log(string.format(
        '[RefineryDiagnostics] 材料：%s + %s | 西方：%s Lv.%d（原版賽特 Lv.%d） | 東方：%s Lv.%d（原版賽特 Lv.%d） | 等級限制已解除 | %s',
        preview.material1.name,
        preview.material2.name,
        preview.west.name,
        preview.west.level,
        preview.west.minimumSethLevel,
        preview.east.name,
        preview.east.level,
        preview.east.minimumSethLevel,
        altarText
    ))
end

local function drawDiagnostics()
    -- 原生程式已在本幀讀過暫設的 Level=1；在任何自訂繪圖前先還原。
    restorePatchedLevels('menu draw')

    local preview = State.preview
    if preview == nil then
        return
    end

    if State.panelLogSignature ~= State.materialSignature then
        State.panelLogSignature = State.materialSignature
        logReadableDiagnostics(preview)
    end

    local x = 16
    local y = 56
    local line = 20
    local normal = DrawFunc.Color(235, 224, 190, 255)
    local highlight = DrawFunc.Color(255, 214, 82, 255)
    local warning = DrawFunc.Color(255, 150, 105, 255)
    local shadow = DrawFunc.Color(32, 22, 16, 225)

    drawText(uiText('RDU_TITLE'), x, y, highlight, shadow)
    drawText(
        uiText('RDU_MATERIALS')
            .. preview.material1.name
            .. ' + '
            .. preview.material2.name,
        x,
        y + line,
        normal,
        shadow
    )
    drawText(uiText('RDU_UNLOCKED'), x, y + line * 2, highlight, shadow)
    local eastSelected = State.eastPreviewActive
    drawResultLine(
        uiText('RDU_WEST'),
        preview.west,
        x,
        y + line * 3,
        eastSelected and normal or highlight,
        shadow
    )
    drawResultLine(
        uiText('RDU_EAST'),
        preview.east,
        x,
        y + line * 5,
        eastSelected and highlight or normal,
        shadow
    )

    local altarText, owned = altarStatusText()
    drawText(altarText, x, y + line * 7, normal, shadow)

    local sethLevel = getLastSethLevel()
    local levelText = sethLevel ~= nil
        and string.format('%s Lv.%d', uiText('RDU_SETH_LAST'), sethLevel)
        or uiText('RDU_SETH_UNKNOWN')
    drawText(levelText, x, y + line * 8, normal, shadow)

    if State.eastPreviewActive then
        drawText(uiText('RDU_NOW_EAST'), x, y + line * 9, highlight, shadow)
    elseif owned == false then
        drawText(uiText('RDU_NEXT_END'), x, y + line * 9, highlight, shadow)
    else
        drawText(uiText('RDU_NEXT_OK'), x, y + line * 9, highlight, shadow)
    end

    if preview.east.isSlime or preview.west.isSlime then
        drawText(uiText('RDU_SLIME'), x, y + line * 10, warning, shadow)
    end
end

local function onInputKeyDown(keyFuncFlag, keyScancode)
    local endFlag = eventFlag(Const and Const.KeyFunc_End)

    -- 僅接受實體 End 鍵；右 Shift 即使被映射也不觸發此標示。
    if keyScancode == END_SCANCODE
        and hasFlag(keyFuncFlag, endFlag)
        and State.preview ~= nil then
        State.eastPreviewActive = true
        log(string.format(
            '[RefineryDiagnostics] End 東方預覽：%s，真實 Lv.%d，原版最低需賽特 Lv.%d',
            State.preview.east.name,
            State.preview.east.level,
            State.preview.east.minimumSethLevel
        ))
        return
    end

    if State.preview ~= nil then
        -- With the altar, the original refinery menu switches to East with
        -- Q/Left and back to West with E/Right. Mirror that same input so the
        -- diagnostics highlight always follows the direction the game uses.
        if (keyScancode == Q_SCANCODE or keyScancode == LEFT_SCANCODE)
            and altarOwned() == true then
            State.eastPreviewActive = true
            return
        elseif keyScancode == E_SCANCODE or keyScancode == RIGHT_SCANCODE then
            State.eastPreviewActive = false
            return
        end
    end

    local cancelFlag = eventFlag(Const and Const.KeyFunc_Cancel)
    local menuFlag = eventFlag(Const and Const.KeyFunc_Menu)
    if hasFlag(keyFuncFlag, cancelFlag) or hasFlag(keyFuncFlag, menuFlag) then
        clearPreview('keyboard cancel')
    end
end

local function onInputClick(keyFuncFlag)
    local cancelFlag = eventFlag(Const and Const.KeyFunc_Cancel)
    local menuFlag = eventFlag(Const and Const.KeyFunc_Menu)
    if hasFlag(keyFuncFlag, cancelFlag) or hasFlag(keyFuncFlag, menuFlag) then
        clearPreview('mouse/controller cancel')
    end
end

local function onCancelClick()
    clearPreview('cancel event')
end

local function onMapLoading()
    clearPreview('map loading')
end

local function onBattleEnter()
    clearPreview('battle enter')
    State.awaitBattleLevel = true
end

local function onGameStart()
    clearPreview('game start')
    saveTable()
    installWrapper()
end

OnEvent = OnEvent or {}
OnEvent.GameStart = OnEvent.GameStart or {}
OnEvent.DrawMenuAfter = OnEvent.DrawMenuAfter or {}
OnEvent.InputKeyDown = OnEvent.InputKeyDown or {}
OnEvent.InputClick = OnEvent.InputClick or {}
OnEvent.CancelClick = OnEvent.CancelClick or {}
OnEvent.MapLoading = OnEvent.MapLoading or {}
OnEvent.Battle_Enter = OnEvent.Battle_Enter or {}
OnEvent.Battle_DrawBGI = OnEvent.Battle_DrawBGI or {}

if not State.eventsRegistered then
    table.insert(OnEvent.GameStart, onGameStart)
    table.insert(OnEvent.DrawMenuAfter, drawDiagnostics)
    table.insert(OnEvent.InputKeyDown, onInputKeyDown)
    table.insert(OnEvent.InputClick, onInputClick)
    table.insert(OnEvent.CancelClick, onCancelClick)
    table.insert(OnEvent.MapLoading, onMapLoading)
    table.insert(OnEvent.Battle_Enter, onBattleEnter)
    table.insert(OnEvent.Battle_DrawBGI, syncSethLevelFromBattle)
    State.eventsRegistered = true
end

-- 提供只讀診斷入口，方便控制台與測試確認還原狀態。
function MOD.GetPatchedItemCount()
    local count = 0
    for _ in pairs(State.patchedLevels) do
        count = count + 1
    end
    return count
end

function MOD.RestoreNow()
    return restorePatchedLevels('manual restore')
end
