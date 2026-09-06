-- 軒轅劍參 Steam 高清版 4.0.x
-- 僅供實機驗證：不修改背包、存檔、戰鬥或任何遊戲資料。
-- F9 在原生選單中建立一個無框、不可穿透、無期限的原生對話層；
-- 再按 F9 嘗試關閉同一 GUID 的對話層。

SWD3LiveCardDialogueProbe = SWD3LiveCardDialogueProbe or {}

local MOD = SWD3LiveCardDialogueProbe
local F9_SCANCODE = 66
local DIALOG_GUID = 0

MOD.active = MOD.active or false
MOD.lastMenuDrawTick = MOD.lastMenuDrawTick or -10000
MOD.openCalls = MOD.openCalls or 0
MOD.closeCalls = MOD.closeCalls or 0

local function text(key, fallback)
    if type(StringDB) == 'function' then
        local ok, value = pcall(StringDB, key)
        if ok and type(value) == 'string' and value ~= '' and value ~= key then
            return value
        end
    end
    return fallback
end

local function logProbe(message)
    if type(log) == 'function' then
        log('[LiveCardDialogueProbe] ' .. tostring(message))
    end
end

local function callESC(name, ...)
    if type(ESC) ~= 'table' or type(ESC[name]) ~= 'function' then
        return false, 'ESC.' .. name .. ' is unavailable'
    end
    return pcall(ESC[name], ...)
end

local function openDialogHost()
    -- 此組合直接取自原版場景腳本；不呼叫 WaitDLG，避免在輸入回呼中阻塞。
    local ok, failure = callESC('DLGNoFrame')
    if not ok then
        logProbe('open failed: ' .. tostring(failure))
        return false
    end

    ok, failure = callESC('DLGNoPass')
    if not ok then
        logProbe('open failed: ' .. tostring(failure))
        return false
    end

    ok, failure = callESC('DLGHoldTime', -1)
    if not ok then
        logProbe('open failed: ' .. tostring(failure))
        return false
    end

    ok, failure = callESC(
        'Print_SLF',
        DIALOG_GUID,
        9009,
        220,
        170,
        30,
        2,
        '%S0%K' .. text('LCDP_TITLE', 'LIVING CARD HOST PROBE')
            .. '%N' .. text('LCDP_BODY', 'TRY INPUT, THEN PRESS F9 TO RETURN.')
    )
    if not ok then
        logProbe('open failed: ' .. tostring(failure))
        return false
    end

    MOD.active = true
    MOD.openCalls = MOD.openCalls + 1
    logProbe('opened native dialogue host request #' .. tostring(MOD.openCalls))
    return true
end

local function closeDialogHost(reason)
    local ok, failure = callESC('DLGClose', DIALOG_GUID)
    MOD.active = false
    MOD.closeCalls = MOD.closeCalls + 1
    if not ok then
        logProbe('close request failed (' .. tostring(reason) .. '): ' .. tostring(failure))
        return false
    end
    logProbe('closed native dialogue host request #' .. tostring(MOD.closeCalls) .. ': ' .. tostring(reason))
    return true
end

local function handleInputClick(_, keyScancode)
    if keyScancode ~= F9_SCANCODE then
        return false
    end

    if MOD.active then
        closeDialogHost('F9')
    else
        openDialogHost()
    end

    -- 實機已知這個回傳值不保證攔截原生輸入；F9 必須維持未綁定。
    return true
end

local function drawAfterMenu()
    if type(GetTicks) == 'function' then
        MOD.lastMenuDrawTick = GetTicks()
    end
    if not MOD.active then
        return
    end

    -- 這個短標記用來驗證：原生對話層存在時，MOD 是否仍有可見繪製時機。
    if StringFunc ~= nil and type(StringFunc.DrawString) == 'function'
        and DrawFunc ~= nil and type(DrawFunc.Color) == 'function' then
        local foreground = DrawFunc.Color(255, 224, 104, 255)
        local shadow = DrawFunc.Color(20, 20, 20, 255)
        StringFunc.DrawString(text('LCDP_DRAW', 'MOD DRAW IS ACTIVE'), 236, 130, 0, foreground, shadow, 1)
    end
end

local function onGameStart()
    MOD.active = false
    logProbe('loaded: F9 opens/closes the native dialogue host probe')
end

OnEvent = OnEvent or {}
OnEvent.GameStart = OnEvent.GameStart or {}
OnEvent.DrawMenuAfter = OnEvent.DrawMenuAfter or {}
OnEvent.InputClick = OnEvent.InputClick or {}

table.insert(OnEvent.GameStart, onGameStart)
table.insert(OnEvent.DrawMenuAfter, drawAfterMenu)
table.insert(OnEvent.InputClick, handleInputClick)
