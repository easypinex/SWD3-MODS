-- 軒轅劍參 Steam 高清版 4.0.x
-- 唯讀診斷：只枚舉 Lua 已暴露的欄位名稱，絕不呼叫未知的原生 API。

local PREFIX = '[EngineUiDiagnostics] '

local function write(message)
    if type(log) == 'function' then
        log(PREFIX .. tostring(message))
    end
end

local function typeName(value)
    local ok, result = pcall(type, value)
    return ok and result or 'unreadable'
end

local function dumpTable(name, value)
    local valueType = typeName(value)
    write(name .. ' type=' .. valueType)
    if valueType ~= 'table' then
        return
    end

    local keys = {}
    local ok, failure = pcall(function()
        for key, entry in pairs(value) do
            table.insert(keys, tostring(key) .. ':' .. typeName(entry))
        end
    end)
    if not ok then
        write(name .. ' enumeration failed: ' .. tostring(failure))
        return
    end

    table.sort(keys)
    write(name .. ' count=' .. tostring(#keys))
    for _, entry in ipairs(keys) do
        write(name .. '.' .. entry)
    end
end

local function dumpRelevantGlobals()
    local keys = {}
    for key, value in pairs(_G) do
        local label = tostring(key)
        if label:match('^[A-Za-z_][A-Za-z0-9_]*$')
            and label:match('^[Ee][Ss][Cc]$|^[Gg]ame|^[Dd]raw|^[Ii]nput|^[Mm]enu|^[Ee]dit|^[Ss]creen|^[Ll]ayer|^[Ss]tringFunc$|^[Pp]ackage$|^[Oo]nEvent$') then
            table.insert(keys, label .. ':' .. typeName(value))
        end
    end
    table.sort(keys)
    write('relevant globals=' .. table.concat(keys, ','))
end

local function onGameStart()
    write('begin read-only inventory')
    dumpRelevantGlobals()
    dumpTable('ESC', ESC)
    dumpTable('GameFunc', GameFunc)
    dumpTable('DrawFunc', DrawFunc)
    dumpTable('StringFunc', StringFunc)
    dumpTable('InputFunc', InputFunc)
    dumpTable('EditLayer', EditLayer)
    dumpTable('MenuFunc', MenuFunc)
    dumpTable('package', package)
    write('end read-only inventory')
end

OnEvent = OnEvent or {}
OnEvent.GameStart = OnEvent.GameStart or {}
table.insert(OnEvent.GameStart, onGameStart)
