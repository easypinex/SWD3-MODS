local probePath = assert(arg[1], 'probe path is required')
local function equal(actual, expected, label)
    if actual ~= expected then error(label .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end
end
local logs = {}
function log(message) table.insert(logs, message) end
GameData = { ItemTemp = { [10017] = { IT_12=true, isBattleChar=true, AttrDark=-6, AttrPoison=-4 }, [189] = { Name='食人花', Level=28 } } }
SaveData = { PlayerEqu = { [1] = { [10] = { ItemTempID=10017 } } } }
BattlePlayers = { [1] = { CharData = { AttrDark=0, AttrPoison=2, AttrFire=-2 } } }
GameData.ItemTemp[1] = { Name='ItemName1', AttrDark=2 }
ESC = { StartBattle = function(id) assert(id == 'GRBP_POISON_FLOWER', 'poison comparison battle ID') end }
GameFunc = { RunScene = function(_, name, phase) assert(phase == 1, 'scene phase'); Scene[name]() end }
BattleField, Scene = {}, {}
OnEvent = { GameStart = {}, Battle_EnemyInit = {}, Battle_RestoreItem = {}, MapLoading = {}, InputClick = {} }
dofile(probePath)
OnEvent.Battle_EnemyInit[1](1)
equal(GameData.ItemTemp[1].AttrDark, -4, 'dark resistance bridges to player source')
equal(GameData.ItemTemp[1].AttrPoison, -4, 'poison resistance bridges to absent player source field')
equal(GameData.ItemTemp[1].AttrFire, nil, 'unrelated source field remains unchanged')
OnEvent.Battle_EnemyInit[1](2)
equal(GameData.ItemTemp[1].AttrDark, -4, 'bridge does not stack on additional enemies')
OnEvent.Battle_RestoreItem[1]()
equal(GameData.ItemTemp[1].AttrDark, 2, 'battle restore returns original present player field')
equal(GameData.ItemTemp[1].AttrPoison, nil, 'battle restore returns original absent player field')
OnEvent.Battle_EnemyInit[1](1)
equal(GameData.ItemTemp[1].AttrDark, -4, 'new battle applies after bridge reset')
OnEvent.Battle_RestoreItem[1]()
equal(OnEvent.InputClick[1](nil, 63), true, 'F6 starts poison comparison battle')
OnEvent.Battle_EnemyInit[1](1)
equal(GameData.ItemTemp[1].AttrPoison, -10, 'F6 comparison uses the temporary 100 percent poison source bridge')
OnEvent.Battle_RestoreItem[1]()
equal(OnEvent.InputClick[1](nil, 62), true, 'F5 starts same-card baseline battle')
OnEvent.Battle_EnemyInit[1](1)
equal(GameData.ItemTemp[1].AttrPoison, nil, 'F5 baseline suppresses only source resistance bridge')
print('PASS: guardian resistance battle probe mock')
