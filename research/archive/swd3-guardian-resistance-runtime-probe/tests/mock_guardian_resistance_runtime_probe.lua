local probePath = assert(arg[1], 'probe path is required')
local function equal(actual, expected, label)
    if actual ~= expected then error(label .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end
end
function log(_) end
GameData = { ItemTemp = { [189] = { Name='食人花' }, [10017] = { IT_12=true, isBattleChar=true } } }
SaveData = { PlayerEqu = { [1] = { [10] = { ItemTempID=10017 } } } }
BattlePlayers = { [1] = { CharData = { AttrPoison=0 } } }
BattleField, Scene = {}, {}
ESC = { StartBattle = function(id) assert(id == 'GRRP_POISON_FLOWER') end }
GameFunc = { RunScene = function(_, name, phase) assert(phase == 1); Scene[name]() end }
OnEvent = { GameStart = {}, MapLoading = {}, InputClick = {}, Battle_PlayerInit = {}, Battle_RestoreItem = {} }
dofile(probePath)
equal(OnEvent.InputClick[1](nil, 63), true, 'F6 starts direct test')
OnEvent.Battle_PlayerInit[1](1)
equal(BattlePlayers[1].CharData.AttrPoison, -10, 'direct test writes CharData')
OnEvent.Battle_RestoreItem[1]()
equal(BattlePlayers[1].CharData.AttrPoison, 0, 'restore returns direct CharData value')
equal(OnEvent.InputClick[1](nil, 62), true, 'F5 starts baseline')
OnEvent.Battle_PlayerInit[1](1)
equal(BattlePlayers[1].CharData.AttrPoison, 0, 'baseline leaves CharData untouched')
print('PASS: guardian resistance runtime probe mock')
