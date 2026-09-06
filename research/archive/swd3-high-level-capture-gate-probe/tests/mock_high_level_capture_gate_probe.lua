local sourcePath = arg[1]
local function equal(actual, expected, label)
    if actual ~= expected then error(label .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end
end
local logs = {}
function log(message) table.insert(logs, message) end

GameData = { ItemTemp = { [59] = { Race = 2, Level = 80, HP = 30000, ATK = 800, DEF = 444, SPD = 180, IT_06 = true } }, Race = { [2] = { catch = false } } }
SaveData = { Items = {} }
OnEvent = { GameStart = {}, InputClick = {}, Battle_EnemyInit = {}, Battle_Dead = {}, Battle_RestoreItem = {}, MapLoading = {} }
BattleField, Scene = {}, {}
BattleEnemys = { [1] = { NPC_GUID = 59, NPCData = { Level = 1 } } }
BattleEnv = { enemys = { [1] = { GUID = 59 } } }
ESC = { StartBattle = function(id) equal(id, 'HLCGP_BULL_DEMON_LEVEL', 'battle id') end }
GameFunc = { RunScene = function(_, name) Scene[name]() end }
SWD3AllMonsterStaticCatalogue = { Get = function(id) if id == 59 then return { cardId = 10024 } end end }
ItemClass = {}
function ItemClass.DelItem(id, count)
    equal(id, 59, 'removes source ID')
    equal(count, 1, 'removes exactly one source')
    for index, item in ipairs(SaveData.Items) do
        if item.ItemTempID == id then table.remove(SaveData.Items, index); return end
    end
    error('source item missing')
end
function ItemClass.AddItem(id, count)
    equal(id, 10024, 'adds static card ID')
    equal(count, 1, 'adds exactly one static card')
    table.insert(SaveData.Items, { ItemTempID = id, Count = count, Count_New = 0 })
end
SWD3AllMonsterStaticCapture = {
    ExchangeCapturedSource = function(sourceId, baseline)
        equal(sourceId, 59, 'helper source')
        equal(baseline, 0, 'helper baseline')
        ItemClass.DelItem(59, 1)
        ItemClass.AddItem(10024, 1)
        return true, 'exchanged', 10024
    end
}

dofile(sourcePath)
OnEvent.GameStart[1]()
OnEvent.InputClick[1](nil, 64)
equal(GameData.ItemTemp[59].Level, 1, 'level is lowered only during probe')
equal(GameData.ItemTemp[59].IT_12, true, 'IT_12 bridge applied')
equal(GameData.ItemTemp[59].IT_06, nil, 'IT_06 bridge applied')
equal(GameData.Race[2].catch, true, 'race bridge applied')
equal(GameData.ItemTemp[59].HP, 30000, 'HP untouched')
equal(GameData.ItemTemp[59].ATK, 800, 'ATK untouched')
OnEvent.Battle_EnemyInit[1](1)
OnEvent.Battle_Dead[1](1, 1, 2)
table.insert(SaveData.Items, { ItemTempID = 59, Count = 1, Count_New = 0 })
OnEvent.Battle_RestoreItem[1]()
equal(SaveData.Items[1].ItemTempID, 10024, 'native source is exchanged after addition')
equal(GameData.ItemTemp[59].Level, 80, 'level restored')
equal(GameData.ItemTemp[59].IT_12, nil, 'absent IT_12 restored')
equal(GameData.ItemTemp[59].IT_06, true, 'IT_06 restored')
equal(GameData.Race[2].catch, false, 'race restored')
equal(GameData.ItemTemp[59].HP, 30000, 'HP remains untouched after restore')
table.insert(SaveData.Items, { ItemTempID = 59, Count = 1, Count_New = 0 })
OnEvent.InputClick[1](nil, 62)
equal(SaveData.Items[2].ItemTempID, 10024, 'F5 exchanges an explicitly held v0.1 source')
assert(#logs > 0, 'diagnostic logs emitted')
print('PASS: high-level capture gate probe mock runtime')
