-- Steam HD 4.0.5：直接寫入玩家戰鬥副本 CharData 的護駕抗性隔離探針。
-- 僅在自訂食人花測試戰中，以 pcall 讀寫已建立的玩家 CharData；不改 ItemTemp 或 SaveData。

SWD3GuardianResistanceRuntimeProbe = SWD3GuardianResistanceRuntimeProbe or {}
local MOD = SWD3GuardianResistanceRuntimeProbe
local F5_SCANCODE = 62
local F6_SCANCODE = 63
local BATTLE_ID = 'GRRP_POISON_FLOWER'
local ENEMY_ID = 189
local STATIC_CARD_MIN = 10001
local STATIC_CARD_MAX = 10097
local FULL_RESISTANCE = -10

MOD.eventsRegistered = MOD.eventsRegistered or false
MOD.active = MOD.active or nil
MOD.nextMode = MOD.nextMode or nil

local function write(message)
    if type(log) == 'function' then log('[GuardianResistanceRuntimeProbe] ' .. tostring(message)) end
end

local function equippedStaticGuardian(playerIndex)
    local equipment = SaveData and SaveData.PlayerEqu and SaveData.PlayerEqu[playerIndex]
    if type(equipment) ~= 'table' then return nil end
    for _, slot in pairs(equipment) do
        local itemId = tonumber(slot and slot.ItemTempID)
        local card = itemId and GameData and GameData.ItemTemp and GameData.ItemTemp[itemId]
        if itemId and itemId >= STATIC_CARD_MIN and itemId <= STATIC_CARD_MAX
            and type(card) == 'table' and card.IT_12 == true and card.isBattleChar == true then
            return itemId
        end
    end
    return nil
end

local function restoreBattleCopies(reason)
    local active = MOD.active
    if type(active) ~= 'table' then return end
    local restored = 0
    for index, saved in pairs(active.players) do
        local player = BattlePlayers and BattlePlayers[index]
        local ok = pcall(function()
            if saved.exists then player.CharData.AttrPoison = saved.value else player.CharData.AttrPoison = nil end
        end)
        if ok then restored = restored + 1 end
    end
    MOD.active, MOD.nextMode = nil, nil
    write('battle-copy probe restored (' .. tostring(reason) .. '): players=' .. tostring(restored))
end

local function beginTest(mode)
    if MOD.active ~= nil then write('test ignored: a probe battle is already active'); return end
    local enemy = GameData and GameData.ItemTemp and GameData.ItemTemp[ENEMY_ID]
    if type(enemy) ~= 'table' then write('test refused: ItemTemp[189] is unavailable'); return end
    MOD.active = { mode = mode, players = {} }
    BattleField = BattleField or {}
    BattleField[BATTLE_ID] = {
        iBattleFieldBackground = 5,
        MusicFileName = 'Battle_Arab01.mp3',
        tCharActQ = { { ItemTempID = ENEMY_ID, X = 176, Y = 294 } }
    }
    local ok, failure = pcall(ESC.StartBattle, BATTLE_ID)
    if not ok then
        restoreBattleCopies('StartBattle failed')
        write('test StartBattle failed: ' .. tostring(failure))
    end
end

Scene = Scene or {}
function Scene.GRRP_StartTest() beginTest(MOD.nextMode) end

local function onInputClick(_, keyScancode)
    local mode
    if keyScancode == F6_SCANCODE then mode = 'direct100'
    elseif keyScancode == F5_SCANCODE then mode = 'baseline'
    else return false end
    if MOD.active ~= nil then write('F5/F6 ignored: a probe battle is already active'); return true end
    MOD.nextMode = mode
    local ok, failure = pcall(GameFunc.RunScene, -1, 'GRRP_StartTest', 1)
    if not ok then
        MOD.nextMode = nil
        write('F5/F6 RunScene failed: ' .. tostring(failure))
    end
    return true
end

-- 不把 CharData 限定為 Lua table；此 engine binding 可為 userdata。
local function onBattlePlayerInit(index)
    local active = MOD.active
    if type(active) ~= 'table' then return end
    local guardianId = equippedStaticGuardian(index)
    if guardianId == nil then return end
    local player = BattlePlayers and BattlePlayers[index]
    local okRead, before = pcall(function() return player.CharData.AttrPoison end)
    if not okRead then
        write('direct copy unavailable after Battle_PlayerInit: player=' .. tostring(index) .. ', read=' .. tostring(before))
        return
    end
    if active.mode == 'baseline' then
        write('direct baseline observed: player=' .. tostring(index) .. ', guardian=' .. tostring(guardianId)
            .. ', CharData type=' .. tostring(type(player.CharData)) .. ', AttrPoison=' .. tostring(before))
        return
    end
    active.players[index] = { exists = before ~= nil, value = before }
    local okWrite, failure = pcall(function() player.CharData.AttrPoison = FULL_RESISTANCE end)
    local okAfter, after = pcall(function() return player.CharData.AttrPoison end)
    write('direct copy write after Battle_PlayerInit: player=' .. tostring(index) .. ', guardian=' .. tostring(guardianId)
        .. ', CharData type=' .. tostring(type(player.CharData)) .. ', AttrPoison ' .. tostring(before)
        .. ' -> ' .. tostring(after) .. ', write=' .. tostring(okWrite) .. (okWrite and '' or (', error=' .. tostring(failure))))
    if not okAfter then write('direct copy post-read failed: ' .. tostring(after)) end
end

local function onGameStart()
    restoreBattleCopies('GameStart')
    write('loaded; F6 starts one 食人花 with direct CharData AttrPoison=-10, F5 starts the same-card baseline; source-bridge probe must be disabled')
end

OnEvent = OnEvent or {}
OnEvent.GameStart = OnEvent.GameStart or {}
OnEvent.MapLoading = OnEvent.MapLoading or {}
OnEvent.InputClick = OnEvent.InputClick or {}
OnEvent.Battle_PlayerInit = OnEvent.Battle_PlayerInit or {}
OnEvent.Battle_RestoreItem = OnEvent.Battle_RestoreItem or {}
if not MOD.eventsRegistered then
    table.insert(OnEvent.GameStart, onGameStart)
    table.insert(OnEvent.MapLoading, function() restoreBattleCopies('MapLoading') end)
    table.insert(OnEvent.InputClick, onInputClick)
    table.insert(OnEvent.Battle_PlayerInit, onBattlePlayerInit)
    table.insert(OnEvent.Battle_RestoreItem, function() restoreBattleCopies('Battle_RestoreItem') end)
    MOD.eventsRegistered = true
end
