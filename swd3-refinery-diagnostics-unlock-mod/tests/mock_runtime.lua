local sourcePath = assert(arg[1], 'MOD Lua path is required')

local function equal(actual, expected, message)
    if actual ~= expected then
        error(string.format(
            '%s: expected %s, got %s',
            message,
            tostring(expected),
            tostring(actual)
        ))
    end
end

local tick = 1000
local drawCount = 0
local drawnText = {}
local drawnCalls = {}
local logMessages = {}
local executionCount = 0
local recipe = { east = 500, west = 600 }
local forceError = false
local altarItemCount = 0
local levelsSeenByOriginal = {}

function GetTicks()
    return tick
end

function log(message)
    table.insert(logMessages, tostring(message))
    io.write(tostring(message), '\n')
end

local uiStrings = {
    RDU_TITLE = '護駕／煉化診斷',
    RDU_MATERIALS = '投入材料：',
    RDU_UNLOCKED = '目前狀態：成品等級限制已解除',
    RDU_WEST = '西方祭壇結果：',
    RDU_EAST = '東方祭壇結果：',
    RDU_TRUE_LEVEL = '真實等級',
    RDU_VANILLA_SETH = '原版最低需賽特',
    RDU_ALTAR_OWNED = '封神壇：已取得，可正常使用東方祭壇',
    RDU_ALTAR_MISSING = '封神壇：尚未取得；按鍵盤 End 預覽東方結果',
    RDU_ALTAR_UNKNOWN = '封神壇：狀態無法讀取',
    RDU_SETH_LAST = '賽特等級：最近戰鬥',
    RDU_SETH_UNKNOWN = '賽特等級：尚未同步，完成一場戰鬥後更新',
    RDU_NOW_EAST = '目前預覽：東方結果',
    RDU_NEXT_END = '下一步：按 End 偷看東方；確認鍵仍走原版煉化',
    RDU_NEXT_OK = '下一步：使用原版確認鍵或滑鼠進行煉化',
    RDU_SLIME = '黏怪說明：這是配方結果，不是等級不足'
}

function StringDB(key)
    return uiStrings[key] or key
end

DrawFunc = {
    Color = function(r, g, b, a)
        return r + g + b + a
    end
}

StringFunc = {
    DrawString = function(text, x, y, font, color, shadow, scale)
        drawCount = drawCount + 1
        table.insert(drawnText, tostring(text))
        table.insert(drawnCalls, {
            text = tostring(text),
            x = x,
            y = y,
            font = font,
            color = color,
            shadow = shadow,
            scale = scale
        })
    end
}

local function assertDrawStyle(firstCall, text, expectedCount, expectedColor, message)
    local count = 0
    for index = firstCall, #drawnCalls do
        local call = drawnCalls[index]
        if call.text == text then
            count = count + 1
            equal(call.color, expectedColor, message .. ' color')
        end
    end
    equal(count, expectedCount, message .. ' weight')
end

Const = {
    KeyFunc_Cancel = 5,
    KeyFunc_Menu = 7,
    KeyFunc_End = 12
}

DefineKeyFunc = {
    [5] = 0x10,
    [7] = 0x40,
    [12] = 0x800
}

GameData = {
    ItemTemp = {
        [101] = { Name = '黏怪', Level = 1 },
        [500] = { Name = '東方甲', Level = 20 },
        [600] = { Name = '西方乙', Level = 40 },
        [700] = { Name = '東方丙', Level = 55 },
        [800] = { Name = '西方丁', Level = 70 }
    }
}

SaveData = {
    Items = {
        [1] = { ItemTempID = 500 },
        [2] = { ItemTempID = 600 },
        [3] = { ItemTempID = 700 }
    }
}

Function = {
    GetItemTemp = function(itemId, field)
        return GameData.ItemTemp[itemId][field]
    end
}

GameFunc = {
    PlayerItemCount = function(itemId)
        if itemId == 771 then
            return altarItemCount
        end
        return 0
    end
}

OnEventValue = {}
OnEvent = {
    GameStart = {},
    DrawMenuAfter = {},
    InputKeyDown = {},
    InputClick = {},
    CancelClick = {},
    MapLoading = {},
    Battle_Enter = {},
    Battle_DrawBGI = {},
    Obsolt = {}
}

OnEvent.Obsolt.main = function(_, _, doing)
    levelsSeenByOriginal[500] = GameData.ItemTemp[500].Level
    levelsSeenByOriginal[600] = GameData.ItemTemp[600].Level
    levelsSeenByOriginal[700] = GameData.ItemTemp[700].Level
    levelsSeenByOriginal[800] = GameData.ItemTemp[800].Level

    if forceError then
        error('forced original error')
    end

    OnEventValue.CalcResEast = recipe.east
    OnEventValue.CalcResWest = recipe.west

    if (tonumber(doing) or 0) >= 1 then
        executionCount = executionCount + 1
    end
end

assert(loadfile(sourcePath))()
equal(#OnEvent.GameStart, 1, 'GameStart handler count')
OnEvent.GameStart[1]()

-- 一般預覽：兩項結果暫設為 1，繪圖事件立刻還原。
OnEvent.Obsolt.main(1, 2, 0)
equal(GameData.ItemTemp[500].Level, 1, 'East preview patch')
equal(GameData.ItemTemp[600].Level, 1, 'West preview patch')
equal(SWD3RefineryDiagnostics.GetPatchedItemCount(), 2, 'Two snapshots')
OnEvent.DrawMenuAfter[1]()
equal(GameData.ItemTemp[500].Level, 20, 'East draw restore')
equal(GameData.ItemTemp[600].Level, 40, 'West draw restore')
equal(SWD3RefineryDiagnostics.GetPatchedItemCount(), 0, 'Draw clears snapshots')
assert(drawCount >= 6, 'Diagnostics panel was not drawn')
local joinedText = table.concat(drawnText, '\n')
assert(string.find(joinedText, '投入材料：東方甲 + 西方乙', 1, true), 'Material names missing')
assert(string.find(joinedText, '西方祭壇結果：西方乙', 1, true), 'West result missing')
assert(string.find(joinedText, '東方祭壇結果：東方甲', 1, true), 'East result missing')
assertDrawStyle(
    1,
    '西方祭壇結果：西方乙',
    1,
    DrawFunc.Color(255, 214, 82, 255),
    'Default West result is crisp and highlighted'
)
assertDrawStyle(
    1,
    '東方祭壇結果：東方甲',
    1,
    DrawFunc.Color(235, 224, 190, 255),
    'Default East result is crisp and normal'
)
local joinedLogs = table.concat(logMessages, '\n')
assert(string.find(joinedLogs, '材料：東方甲 + 西方乙', 1, true), 'Readable log materials missing')
assert(string.find(joinedLogs, '等級限制已解除', 1, true), 'Readable log status missing')

-- 預覽不是逐幀重算；即使經過很久，面板仍須持續顯示。
local previousDrawCount = drawCount
tick = tick + 10000
OnEvent.DrawMenuAfter[1]()
assert(drawCount > previousDrawCount, 'Persistent diagnostics panel was not drawn')

-- 東西方為相同成品時只保存一份快照。
recipe = { east = 500, west = 500 }
tick = tick + 10
OnEvent.Obsolt.main(1, 2, 0)
equal(SWD3RefineryDiagnostics.GetPatchedItemCount(), 1, 'Deduplicated snapshot')
equal(GameData.ItemTemp[500].Level, 1, 'Same-result patch')

-- 不經繪圖直接切配方，也必須在新計算前先還原舊結果。
recipe = { east = 700, west = 800 }
tick = tick + 10
OnEvent.Obsolt.main(1, 3, 0)
equal(levelsSeenByOriginal[500], 20, 'Restore before next recipe')
equal(GameData.ItemTemp[500].Level, 20, 'Old result remains restored')
equal(GameData.ItemTemp[700].Level, 1, 'New East patch')
equal(GameData.ItemTemp[800].Level, 1, 'New West patch')

-- 正式煉化前還原，且不在執行後再次暫設。
OnEvent.Obsolt.main(1, 3, 1)
equal(levelsSeenByOriginal[700], 55, 'Execution sees true East level')
equal(levelsSeenByOriginal[800], 70, 'Execution sees true West level')
equal(GameData.ItemTemp[700].Level, 55, 'Execution leaves East restored')
equal(GameData.ItemTemp[800].Level, 70, 'Execution leaves West restored')
equal(executionCount, 1, 'Original execution count')
equal(SWD3RefineryDiagnostics.GetPatchedItemCount(), 0, 'No execution snapshot')

-- 右 Shift 不標示東方預覽；End 才標示。
recipe = { east = 500, west = 600 }
tick = tick + 10
OnEvent.Obsolt.main(1, 2, 0)
OnEvent.InputKeyDown[1](0x800, 229)
equal(SWD3RefineryDiagnostics.State.eastPreviewActive, false, 'Right Shift ignored')
OnEvent.InputKeyDown[1](0x800, 77)
equal(SWD3RefineryDiagnostics.State.eastPreviewActive, true, 'End accepted')
local eastSelectionFirstCall = #drawnCalls + 1
OnEvent.DrawMenuAfter[1]()
assertDrawStyle(
    eastSelectionFirstCall,
    '西方祭壇結果：西方乙',
    1,
    DrawFunc.Color(235, 224, 190, 255),
    'West result returns to crisp normal color in East preview'
)
assertDrawStyle(
    eastSelectionFirstCall,
    '東方祭壇結果：東方甲',
    1,
    DrawFunc.Color(255, 214, 82, 255),
    'East result becomes crisp and highlighted in East preview'
)

-- 未取得封神壇時，Q／左方向鍵不會觸發原版東方切換。
OnEvent.InputKeyDown[1](0, 8)
equal(SWD3RefineryDiagnostics.State.eastPreviewActive, false, 'E selects West')
OnEvent.InputKeyDown[1](0, 20)
equal(SWD3RefineryDiagnostics.State.eastPreviewActive, false, 'Q requires altar')
OnEvent.InputKeyDown[1](0, 80)
equal(SWD3RefineryDiagnostics.State.eastPreviewActive, false, 'Left requires altar')

-- 取得封神壇後，Q／左選東方，E／右選西方。
altarItemCount = 1
OnEvent.InputKeyDown[1](0, 20)
equal(SWD3RefineryDiagnostics.State.eastPreviewActive, true, 'Q selects East')

-- 正常解鎖的東方方向在更換配方後仍由原版選擇狀態維持。
recipe = { east = 700, west = 800 }
OnEvent.Obsolt.main(1, 3, 0)
equal(
    SWD3RefineryDiagnostics.State.eastPreviewActive,
    true,
    'Unlocked East survives recipe change'
)
recipe = { east = 500, west = 600 }
OnEvent.Obsolt.main(1, 2, 0)
OnEvent.InputKeyDown[1](0, 8)
equal(SWD3RefineryDiagnostics.State.eastPreviewActive, false, 'E returns West')
OnEvent.InputKeyDown[1](0, 80)
equal(SWD3RefineryDiagnostics.State.eastPreviewActive, true, 'Left selects East')
OnEvent.InputKeyDown[1](0, 79)
equal(SWD3RefineryDiagnostics.State.eastPreviewActive, false, 'Right returns West')

-- 取消事件必須還原並清除面板。
OnEvent.InputClick[1](0x10, 0)
equal(GameData.ItemTemp[500].Level, 20, 'Cancel restores East')
equal(GameData.ItemTemp[600].Level, 40, 'Cancel restores West')
equal(SWD3RefineryDiagnostics.State.preview, nil, 'Cancel clears preview')

-- 原函式拋錯時仍須還原所有暫存等級。
OnEvent.Obsolt.main(1, 2, 0)
forceError = true
local ok = pcall(OnEvent.Obsolt.main, 1, 2, 0)
equal(ok, false, 'Original error propagated')
equal(GameData.ItemTemp[500].Level, 20, 'Error restores East')
equal(GameData.ItemTemp[600].Level, 40, 'Error restores West')
equal(SWD3RefineryDiagnostics.GetPatchedItemCount(), 0, 'Error clears snapshots')
forceError = false

-- 最近戰鬥賽特等級保存於本存檔。
BattlePlayers = { [1] = { CharData = { Level = 33 } } }
OnEvent.Battle_Enter[1]()
OnEvent.Battle_DrawBGI[1]()
equal(
    SaveData.SWD3RefineryDiagnostics.LastSethLevel,
    33,
    'Saved last battle Seth level'
)

io.write('PASS: refinery diagnostics mock runtime\n')
