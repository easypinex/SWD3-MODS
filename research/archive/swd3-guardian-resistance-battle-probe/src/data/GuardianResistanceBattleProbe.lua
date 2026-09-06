-- Steam HD 4.0.5 護駕戰鬥抗性隔離探針。
-- 假設：在 Battle_EnemyInit 後、Battle_PlayerInit 前暫改角色來源 ItemTemp，
-- native 玩家初始化會將 Attr* 複製到戰鬥資料。所有欄位在戰後／切圖精確還原。

SWD3GuardianResistanceBattleProbe = SWD3GuardianResistanceBattleProbe or {}
local MOD = SWD3GuardianResistanceBattleProbe
local F5_SCANCODE = 62
local F6_SCANCODE = 63
local TEST_BATTLE_ID = 'GRBP_POISON_FLOWER'
local TEST_ENEMY_ID = 189 -- 食人花；原版普通攻擊 AttackEffect 117 為毒屬性。
local FULL_RESISTANCE = -10 -- 原版資料中的 100% 抗性上限。

local ATTRIBUTE_KEYS = {
    'AttrFire', 'AttrIce', 'AttrWind', 'AttrEarth', 'AttrPoison',
    'AttrLight', 'AttrDark', 'AttrThunder', 'AttrPhysical'
}

MOD.eventsRegistered = MOD.eventsRegistered or false
MOD.active = MOD.active or nil
MOD.nextTestMode = MOD.nextTestMode or nil

local function write(message)
    if type(log) == 'function' then log('[GuardianResistanceBattleProbe] ' .. tostring(message)) end
end

local function staticGuardianIdForPlayer(playerIndex)
    local equipment = SaveData and SaveData.PlayerEqu and SaveData.PlayerEqu[playerIndex]
    if type(equipment) ~= 'table' then return nil end
    for _, equipped in pairs(equipment) do
        local itemId = tonumber(equipped and equipped.ItemTempID)
        if itemId ~= nil and itemId >= 10001 and itemId <= 10097 then
            local card = GameData and GameData.ItemTemp and GameData.ItemTemp[itemId]
            if type(card) == 'table' and card.IT_12 == true and card.isBattleChar == true then return itemId, card end
        end
    end
    return nil
end

local function snapshotField(snapshot, target, key)
    if snapshot[key] ~= nil then return end
    snapshot[key] = { exists = target[key] ~= nil, value = target[key] }
end

local function restoreBridge(reason)
    local active = MOD.active
    if type(active) ~= 'table' then return end
    for sourceId, snapshot in pairs(active.sources) do
        local source = GameData and GameData.ItemTemp and GameData.ItemTemp[sourceId]
        if type(source) == 'table' then
            for key, saved in pairs(snapshot) do source[key] = saved.exists and saved.value or nil end
        end
    end
    write('source bridge restored (' .. tostring(reason) .. '): players=' .. tostring(active.count))
    MOD.active = nil
    MOD.nextTestMode = nil
end

local function applySourceBridge()
    if MOD.active ~= nil then return end
    if type(GameData) ~= 'table' or type(GameData.ItemTemp) ~= 'table' then
        write('source bridge skipped: GameData.ItemTemp is unavailable')
        return
    end
    local active = { sources = {}, count = 0 }
    if MOD.nextTestMode == 'baseline' then
        MOD.active = active
        write('source bridge intentionally suppressed for the F5 baseline; equipped guardian Add* ability fields remain native and unchanged')
        return
    end
    for playerIndex in pairs(SaveData and SaveData.PlayerEqu or {}) do
        local guardianId, guardian = staticGuardianIdForPlayer(playerIndex)
        local sourceId = tonumber(playerIndex)
        local source = sourceId and GameData.ItemTemp[sourceId]
        if guardianId ~= nil and type(source) == 'table' then
            local snapshot = {}
            local changes = {}
            for _, key in ipairs(ATTRIBUTE_KEYS) do
                local bonus = tonumber(guardian[key]) or 0
                if MOD.nextTestMode == 'resistance100' and key == 'AttrPoison' then
                    snapshotField(snapshot, source, key)
                    local before = tonumber(source[key]) or 0
                    source[key] = FULL_RESISTANCE
                    table.insert(changes, key .. ' ' .. tostring(before) .. ' -> ' .. tostring(source[key]) .. ' (F6 test override: 100%)')
                elseif bonus < 0 then
                    snapshotField(snapshot, source, key)
                    local before = tonumber(source[key]) or 0
                    source[key] = before + bonus
                    table.insert(changes, key .. ' ' .. tostring(before) .. ' -> ' .. tostring(source[key]))
                end
            end
            if #changes > 0 then
                active.sources[sourceId] = snapshot
                active.count = active.count + 1
                write('source bridge applied before player init: player=' .. tostring(playerIndex)
                    .. ', source=' .. tostring(sourceId) .. ', guardian=' .. tostring(guardianId)
                    .. ', ' .. table.concat(changes, ', '))
            end
        end
    end
    MOD.active = active
    if active.count == 0 then write('source bridge armed: no equipped static guardian with Attr* resistance') end
end

-- 僅建立單隻原版食人花的低成本對照戰；不改它的數值、技能、掉落或收妖流程。
local function startPoisonTestBattle(mode)
    if MOD.active ~= nil then
        write('F6 ignored: a battle bridge is already active')
        return
    end
    local enemy = GameData and GameData.ItemTemp and GameData.ItemTemp[TEST_ENEMY_ID]
    if type(enemy) ~= 'table' then
        write('F6 refused: ItemTemp[' .. tostring(TEST_ENEMY_ID) .. '] is unavailable')
        return
    end
    BattleField = BattleField or {}
    BattleField[TEST_BATTLE_ID] = {
        iBattleFieldBackground = 5,
        MusicFileName = 'Battle_Arab01.mp3',
        tCharActQ = { { ItemTempID = TEST_ENEMY_ID, X = 176, Y = 294 } }
    }
    local started, failure = pcall(ESC.StartBattle, TEST_BATTLE_ID)
    if not started then
        MOD.nextTestMode = nil
        write('F6 StartBattle failed: ' .. tostring(failure))
        return
    end
    local label = mode == 'baseline' and 'baseline (resistance bridge suppressed)' or '100% poison resistance bridge enabled'
    write('poison comparison battle started (' .. label .. '): one original 食人花 (ID 189, Lv'
        .. tostring(enemy.Level) .. ') uses its native poison basic attack; do not capture it. Record one non-critical hit, then end the battle.')
end

Scene = Scene or {}
function Scene.GRBP_StartPoisonTestBattle() startPoisonTestBattle(MOD.nextTestMode) end

local function onInputClick(_, keyScancode)
    local mode
    if keyScancode == F5_SCANCODE then mode = 'baseline'
    elseif keyScancode == F6_SCANCODE then mode = 'resistance100'
    else return false end
    if MOD.active ~= nil then
        write((mode == 'baseline' and 'F5' or 'F6') .. ' ignored: a battle bridge is already active')
        return true
    end
    MOD.nextTestMode = mode
    local ok, failure = pcall(GameFunc.RunScene, -1, 'GRBP_StartPoisonTestBattle', 1)
    if not ok then
        MOD.nextTestMode = nil
        write((mode == 'baseline' and 'F5' or 'F6') .. ' RunScene failed: ' .. tostring(failure))
    end
    return true
end

OnEvent = OnEvent or {}
OnEvent.GameStart = OnEvent.GameStart or {}
OnEvent.MapLoading = OnEvent.MapLoading or {}
OnEvent.Battle_EnemyInit = OnEvent.Battle_EnemyInit or {}
OnEvent.Battle_RestoreItem = OnEvent.Battle_RestoreItem or {}
OnEvent.InputClick = OnEvent.InputClick or {}
if not MOD.eventsRegistered then
    table.insert(OnEvent.GameStart, function() restoreBridge('GameStart') end)
    table.insert(OnEvent.MapLoading, function() restoreBridge('MapLoading') end)
    table.insert(OnEvent.Battle_EnemyInit, applySourceBridge)
    table.insert(OnEvent.Battle_RestoreItem, function() restoreBridge('Battle_RestoreItem') end)
    table.insert(OnEvent.InputClick, onInputClick)
    MOD.eventsRegistered = true
end

write('loaded; F6 starts the poison test with a temporary 100% source resistance (AttrPoison=-10); F5 is the same-card baseline without source resistance')
