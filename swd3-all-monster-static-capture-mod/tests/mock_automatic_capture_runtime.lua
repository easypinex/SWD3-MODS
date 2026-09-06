local cataloguePath = assert(arg[1], 'catalogue path is required')
local installerPath = assert(arg[2], 'installer path is required')
local runtimePath = assert(arg[3], 'runtime path is required')
local function equal(actual, expected, label)
    if actual ~= expected then error(label .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end
end
local function truthy(value, label) if not value then error(label) end end
local function run(handlers, ...)
    for _, handler in ipairs(handlers or {}) do handler(...) end
end
local logs = {}
function log(message) table.insert(logs, message) end

GameData = { ItemTemp = { [101] = { Name='ItemName101', Race=1, IT_12=true, isBattleChar=true, HP=100, ATK=40, DEF=30, Level=8 } }, Race = { [1] = {}, [14] = {} } }
SaveData = { Items = {} }
OnEvent = {
    GameStart = {}, MapLoading = {}, MapLoaded = {}, InputKeyDown = {}, InputKeyUp = {}, InputClick = {},
    Battle_Enter = {}, Battle_InputKeyDown = {}, BattlePlayerAI_after = {}, Battle_Dead = {}, Battle_RestoreItem = {}
}
Function = {}
function Function.CheckObsolt(player, target)
    if target.isDeath(target) or target.isHide(target) or target.NPCData.HP <= 0 then return 0 end
    local difference = target.NPCData.Level - player.CharData.Level
    if difference >= 12 then return 0 end
    if difference >= 7 and target.NPCData.HP * 4 <= target.NPCData.MaxHP then return 100 end
    return 37
end
ItemClass = {}
function ItemClass.AddItem(id, count)
    for _, item in ipairs(SaveData.Items) do
        if item.ItemTempID == id then item.Count_New = item.Count_New + count; return 0 end
    end
    table.insert(SaveData.Items, { ItemTempID = id, Count = 0, Count_New = count }); return 0
end
function ItemClass.DelItem(slot, id, count)
    local item = SaveData.Items[slot]
    if not item or item.ItemTempID ~= id then return -1 end
    item.Count_New = item.Count_New - count
    if item.Count_New < 0 then item.Count = item.Count + item.Count_New; item.Count_New = 0 end
    if item.Count <= 0 and item.Count_New <= 0 then table.remove(SaveData.Items, slot) end
    return 0
end

dofile(cataloguePath)
equal(SWD3AllMonsterStaticCatalogue.Get(149).raceId, 0, 'catalogue retains the audited Race[0] metadata')
for sourceId in pairs(SWD3AllMonsterStaticCatalogue.entries) do
    if GameData.ItemTemp[sourceId] == nil then
        GameData.ItemTemp[sourceId] = { Name='ItemName'..sourceId, Race=1, Level=35, ACT=sourceId, isBattleChar=true, HP=500, ATK=100, DEF=80 }
    end
end
GameData.ItemTemp[102] = { Name='ItemName102', Race=14, IT_06=true, Level=35, ACT=102, isBattleChar=true, HP=20, ATK=25, DEF=20 }
dofile(installerPath)
-- 模擬一筆已存在來源但缺少 runtime Race table 的目錄項；正式 bridge 必須安全略過並可診斷。
GameData.ItemTemp[46].Race = 99
GameData.ItemTemp[149].Race = nil
dofile(runtimePath)
run(OnEvent.GameStart)
equal(GameData.ItemTemp[102].IT_12, true, 'bridge applies IT_12 before battle')
equal(GameData.ItemTemp[102].IT_06, nil, 'bridge removes IT_06 before battle')
equal(GameData.ItemTemp[102].Level, 35, 'map source level remains original before battle')
equal(GameData.Race[14].catch, true, 'bridge applies race capture before battle')
equal(GameData.ItemTemp[149].Race, 0, 'bridge supplies the audited source race when runtime omitted it')
equal(GameData.Race[0].name, 'NAME1000', 'bridge supplies missing native Race[0] name')
equal(GameData.Race[0].catch, true, 'bridge supplies missing native Race[0] capture eligibility')

BattleEnemys = {
    [1] = {
        NPC_GUID = 102,
        NPCData = { Level = 35, HP = 20, MaxHP = 20, ItemType = 0x800 },
        isDeath = function() return false end,
        isHide = function() return false end
    }
}
BattleEnv = { enemys = { [1] = { GUID = 102 } } }
_BattleEnv = { EnemyIDMax = 1, NowMenu = 0 }
BattlePlayers = { [1] = { CharData = { Level = 20 } } }
run(OnEvent.Battle_Enter)
equal(BattleEnemys[1].NPCData.Level, 31, 'Battle_Enter caps an eligible high-level battle copy at player +11')
equal(GameData.ItemTemp[102].Level, 35, 'battle level cap leaves the map source level unchanged')
equal(BattleEnemys[1].NPCData.ItemType, 0x800, 'Boss capture window starts non-Boss for the first command UI')
_BattleEnv.NowMenu = 1
run(OnEvent.InputKeyDown, nil, 0)
equal(BattleEnemys[1].NPCData.ItemType, 0x800, 'command input keeps a Boss target non-Boss')
run(OnEvent.BattlePlayerAI_after, 1)
equal(BattleEnemys[1].NPCData.ItemType, 0x800, 'Seth after retains the non-Boss capture window')
run(OnEvent.BattlePlayerAI_after, 2)
equal(BattleEnemys[1].NPCData.ItemType, 0x820, 'non-Seth after restores the original Boss bit before its executor')
_BattleEnv.NowMenu = 3
run(OnEvent.Battle_InputKeyDown)
equal(BattleEnemys[1].NPCData.ItemType, 0x800, 'target-confirmation input clears the Boss bit again')
BattleEnemys[1].NPCData.HP = 5
equal(Function.CheckObsolt(BattlePlayers[1], BattleEnemys[1]), 100, 'player +11 and HP at or below 25 percent use the native 100 percent branch')
BattleEnemys[1].NPCData.HP = 6
equal(Function.CheckObsolt(BattlePlayers[1], BattleEnemys[1]), 37, 'the native formula remains in control above the 25 percent threshold')
BattleEnemys[1].NPCData.HP = 5
BattleEnemys[1].NPCData.Level = 35
BattleEnemys[1].NPC_GUID = 999999
run(OnEvent.Battle_Enter)
equal(BattleEnemys[1].NPCData.Level, 35, 'a source outside the bridge catalogue is never battle-capped')
BattleEnemys[1].NPC_GUID = 102
BattleEnemys[1].NPCData.Level = 31
run(OnEvent.Battle_Dead, 1, 1, 2)
run(OnEvent.Battle_Dead, 1, 1, 2)
ItemClass.AddItem(102, 1)
run(OnEvent.Battle_RestoreItem)
equal(SaveData.Items[1].ItemTempID, 10042, 'native source exchanges into mapped static card once')
equal((SaveData.Items[2] and SaveData.Items[2].ItemTempID) or nil, nil, 'duplicate Battle_Dead does not duplicate exchange')
equal(GameData.ItemTemp[102].IT_12, true, 'post-battle bridge re-arms for next battle')
equal(GameData.ItemTemp[102].Level, 35, 'post-battle re-arm retains original map source level')
equal(BattleEnemys[1].NPCData.Level, 35, 'battle restore returns the capped battle copy to its original level')
equal(BattleEnemys[1].NPCData.ItemType, 0x800, 'battle restore returns the original battle ItemType snapshot')
run(OnEvent.MapLoading)
equal(GameData.ItemTemp[102].IT_12, nil, 'map loading restores absent IT_12')
equal(GameData.ItemTemp[102].IT_06, true, 'map loading restores the source Boss flag')
equal(GameData.ItemTemp[102].Level, 35, 'map loading restores original level')
equal(GameData.Race[14].catch, nil, 'map loading restores absent race catch')
equal(GameData.ItemTemp[149].Race, nil, 'map loading restores the absent source Race field')
equal(GameData.Race[0], nil, 'map loading removes only the bridge-created Race[0]')
truthy(#logs > 0, 'runtime emits diagnostics')
local skippedLogged = false
for _, message in ipairs(logs) do
    if string.find(message, '46 %(Race%[99%] unavailable%)') then skippedLogged = true; break end
end
truthy(skippedLogged, 'runtime reports the skipped source ID and missing race reason')
print('PASS: automatic capture runtime mock')
