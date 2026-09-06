local sourcePath = assert(arg[1], 'StaticCaptureExchangeProbe.lua path is required')
local function equal(actual, expected, message) if actual ~= expected then error(message .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end end
local function truthy(value, message) if not value then error(message) end end
local logs = {}
log = function(message) table.insert(logs, message) end
SaveData = { Items = {} }
GameData = { ItemTemp = {
    [101] = { Name = 'ItemName101', ACT = 101, Race = 9, Level = 12, IT_12 = true, isBattleChar = true, HP = 10 },
    [102] = { Name = 'ItemName102', ACT = 102, Race = 14, Level = 13, isBattleChar = true, HP = 20, ATK = 25 }
} }
OnEvent = { GameStart = {}, InputClick = {}, Battle_Dead = {}, Battle_RestoreItem = {}, MapLoading = {} }
BattleField, BattleEnv, Scene = {}, { enemys = { [1] = { GUID = 102 } } }, {}
local battleId = nil
GameFunc = { GetBattleFieldID = function() return battleId end, RunScene = function(_, name, phase) assert(type(phase) == 'number'); Scene[name]() end }
ESC = { StartBattle = function(id) battleId = id end }
ItemClass = {}
function ItemClass.AddItem(id, count)
    for _, item in ipairs(SaveData.Items) do if item.ItemTempID == id then item.Count_New = item.Count_New + count; return 0 end end
    table.insert(SaveData.Items, { ItemTempID = id, Count = 0, Count_New = count }); return 1
end
function ItemClass.DelItem(slot, id, count)
    local item = SaveData.Items[slot]; if not item or item.ItemTempID ~= id then return -1 end
    item.Count_New = item.Count_New - count
    if item.Count_New < 0 then item.Count = item.Count + item.Count_New; item.Count_New = 0 end
    if item.Count <= 0 and item.Count_New <= 0 then table.remove(SaveData.Items, slot) end
    return 0
end
dofile(sourcePath)
truthy(GameData.ItemTemp[9004] and GameData.ItemTemp[9004].IT_12, 'static snake card exists at load')
equal(GameData.ItemTemp[102].IT_12, nil, 'source snake stays non-card before battle')
OnEvent.GameStart[1]()
OnEvent.InputClick[1](nil, 59)
equal(battleId, 'SCEP_SNAKE_CAPTURE', 'F2 starts snake battle')
equal(GameData.ItemTemp[102].IT_12, true, 'bridge temporarily permits snake targeting')
ItemClass.AddItem(102, 1)
OnEvent.Battle_Dead[1](1, 1, 2)
OnEvent.Battle_RestoreItem[1]()
equal(#SaveData.Items, 1, 'exchange leaves one item')
equal(SaveData.Items[1].ItemTempID, 9004, 'native source becomes static card')
equal(GameData.ItemTemp[102].IT_12, nil, 'bridge restores source table')
battleId = nil
OnEvent.InputClick[1](nil, 58)
equal(#SaveData.Items, 0, 'F1 clears static snake cards')
truthy(#logs > 0, 'diagnostics were written')
print('PASS: static capture exchange probe mock runtime')
