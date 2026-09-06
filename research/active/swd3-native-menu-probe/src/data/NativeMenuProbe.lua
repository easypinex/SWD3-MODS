-- 軒轅劍參 Steam 高清版 4.0.x
-- 唯一作用：驗證 ESC.Menu 能否在 GameFunc.RunScene 建立的原生 coroutine 中運作。
-- 操作：在安全地圖、沒有開任何原生選單時按 B。選項均不會造成遊戲資料變更。

SWD3NativeMenuProbe = SWD3NativeMenuProbe or {}

local MOD = SWD3NativeMenuProbe
local B_SCANCODE = 5
local ESC_SCANCODE = 41

MOD.running = MOD.running or false

local function write(message)
    if type(log) == 'function' then
        log('[NativeMenuProbe] ' .. tostring(message))
    end
end

local function safeCall(target, name, ...)
    if type(target) ~= 'table' or type(target[name]) ~= 'function' then
        return false, tostring(name) .. ' is unavailable'
    end
    return pcall(target[name], ...)
end

Scene = Scene or {}

function Scene.LCB_NativeMenuProbe()
    MOD.running = true
    write('scene entered; ESC.Menu type=' .. type(ESC and ESC.Menu)
        .. ', ESC.GetMENUSelect type=' .. type(ESC and ESC.GetMENUSelect))

    -- 原版 Print 類 API 都以 GUID 為第一個參數；Menu 以單一字串表呼叫時
    -- 回報「參數不足」，因此第一輪以最小的 (GUID, 字串表) 型式驗證。
    local opened, failure = safeCall(ESC, 'Menu', 0, {
        '0  CANCEL / RETURN',
        '1  SELECT ALPHA',
        '2  SELECT BRAVO'
    })
    if not opened then
        MOD.running = false
        write('ESC.Menu failed: ' .. tostring(failure))
        return
    end

    -- 若 ESC.Menu 在 coroutine 中 yield，這一行會在玩家選擇／取消後才繼續；
    -- 若它不 yield，仍只讀取目前選項並安全結束，供 Console 判斷其真實語意。
    local selected, selectFailure = safeCall(ESC, 'GetMENUSelect')
    if selected then
        write('ESC.Menu returned; selected=' .. tostring(selectFailure))
    else
        write('GetMENUSelect unavailable/failed: ' .. tostring(selectFailure))
    end
    MOD.running = false
    write('scene completed')
end

local function onInputClick(_, keyScancode)
    if keyScancode == ESC_SCANCODE and MOD.running then
        local closed, failure = safeCall(ESC, 'DLGClose', 0)
        write('Esc requested DLGClose(0): ' .. (closed and 'called' or 'failed: ' .. tostring(failure)))
        return true
    end
    if keyScancode ~= B_SCANCODE then
        return false
    end
    if MOD.running then
        write('ignored B: native-menu probe already running')
        return true
    end

    local started, failure = safeCall(GameFunc, 'RunScene', -1, 'LCB_NativeMenuProbe', 0)
    if started then
        write('RunScene requested')
    else
        write('RunScene failed: ' .. tostring(failure))
    end
    return true
end

local function onGameStart()
    MOD.running = false
    write('loaded: in a safe map with no menu open, press B once')
end

OnEvent = OnEvent or {}
OnEvent.GameStart = OnEvent.GameStart or {}
OnEvent.InputClick = OnEvent.InputClick or {}
table.insert(OnEvent.GameStart, onGameStart)
table.insert(OnEvent.InputClick, onInputClick)
