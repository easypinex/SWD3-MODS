-- Steam HD 4.0.5：低成本驗證正式全魔物收妖 runtime。
-- F4 只暫降此測試戰牛魔王的戰鬥壓力；IT_12、IT_06、Race.catch、Level 與卡片交換皆不由本探針處理。

SWD3FormalCaptureValidationProbe = SWD3FormalCaptureValidationProbe or {}
local MOD = SWD3FormalCaptureValidationProbe
local F4_SCANCODE = 61
local BATTLE_ID = 'AMSC_FORMAL_BOSS_VALIDATE'
local SOURCE_ID = 59

MOD.state = MOD.state or { eventsRegistered = false, active = nil }
local State = MOD.state

local function write(message)
    if type(log) == 'function' then log('[FormalCaptureValidationProbe] ' .. tostring(message)) end
end

local function snapshotField(snapshot, object, field)
    snapshot[field] = { present = object[field] ~= nil, value = object[field] }
end

local function restoreField(snapshot, object, field)
    local saved = snapshot and snapshot[field]
    if saved == nil then return end
    if saved.present then object[field] = saved.value else object[field] = nil end
end

local function restoreProbe(reason)
    local active = State.active
    if type(active) ~= 'table' then return end
    local source = GameData and GameData.ItemTemp and GameData.ItemTemp[SOURCE_ID]
    if type(source) == 'table' then
        for _, field in ipairs({ 'HP', 'ATK', 'SPD', 'Skills', 'CureSkills', 'SP_AE' }) do
            restoreField(active.source, source, field)
        end
    end
    State.active = nil
    write('battle tuning restored (' .. tostring(reason) .. '): HP=' .. tostring(source and source.HP)
        .. ', ATK=' .. tostring(source and source.ATK) .. ', Level=' .. tostring(source and source.Level))
end

local function startProbe()
    if State.active ~= nil then write('F4 ignored: validation battle is already active'); return end
    local capture = SWD3AllMonsterStaticCapture
    local runtime = capture and capture.captureRuntime
    if type(runtime) ~= 'table' or type(runtime.active) ~= 'table' then
        write('F4 refused: formal all-monster capture bridge is not armed; enable v0.3 static capture card library and enter a map first')
        return
    end
    local source = GameData and GameData.ItemTemp and GameData.ItemTemp[SOURCE_ID]
    if type(source) ~= 'table' then write('F4 refused: ItemTemp[59] is unavailable'); return end
    local active = { source = {} }
    for _, field in ipairs({ 'HP', 'ATK', 'SPD', 'Skills', 'CureSkills', 'SP_AE' }) do snapshotField(active.source, source, field) end
    source.HP = 1
    source.ATK = 0
    source.SPD = 0
    source.Skills, source.CureSkills, source.SP_AE = {}, {}, {}
    State.active = active
    BattleField = BattleField or {}
    BattleField[BATTLE_ID] = {
        iBattleFieldBackground = 4,
        MusicFileName = 'Battle_Europa01.mp3',
        tCharActQ = { { ItemTempID = SOURCE_ID, X = 176, Y = 294 } }
    }
    local started, failure = pcall(ESC.StartBattle, BATTLE_ID)
    if not started then
        restoreProbe('StartBattle failed')
        write('StartBattle failed: ' .. tostring(failure))
        return
    end
    write('validation battle started: source=59 uses formal bridge fields IT_12=' .. tostring(source.IT_12)
        .. ', IT_06=' .. tostring(source.IT_06) .. ', Level=' .. tostring(source.Level)
        .. '; use 靈契 to capture, then inspect formal exchange to card 10024')
end

Scene = Scene or {}
function Scene.AMSC_FormalCaptureValidationStart() startProbe() end

local function onInputClick(_, keyScancode)
    if keyScancode ~= F4_SCANCODE then return false end
    local ok, failure = pcall(GameFunc.RunScene, -1, 'AMSC_FormalCaptureValidationStart', 1)
    if not ok then write('F4 RunScene failed: ' .. tostring(failure)) end
    return true
end

local function onBattleRestoreItem() restoreProbe('Battle_RestoreItem') end
local function onMapLoading() restoreProbe('MapLoading') end
local function onGameStart()
    restoreProbe('GameStart')
    write('loaded: F4 starts a low-risk boss battle; all capture eligibility and source → card exchange must come from the formal static capture MOD')
end

OnEvent = OnEvent or {}
OnEvent.GameStart = OnEvent.GameStart or {}
OnEvent.InputClick = OnEvent.InputClick or {}
OnEvent.Battle_RestoreItem = OnEvent.Battle_RestoreItem or {}
OnEvent.MapLoading = OnEvent.MapLoading or {}
if not State.eventsRegistered then
    table.insert(OnEvent.GameStart, onGameStart)
    table.insert(OnEvent.InputClick, onInputClick)
    table.insert(OnEvent.Battle_RestoreItem, onBattleRestoreItem)
    table.insert(OnEvent.MapLoading, onMapLoading)
    State.eventsRegistered = true
end
