local sourcePath = assert(arg[1], 'expected source path')
local logs = {}
log = function(message) logs[#logs + 1] = message end
GameData = { ItemTemp = { [46] = { Race = 1, Level = 80, IT_06 = true, ATK = 999, SPD = 88, Skills = { 1 }, CureSkills = { 2 }, SP_AE = { 3 } } }, Race = { [1] = { catch = true } } }
SWD3AllMonsterStaticCatalogue = { Get = function(id) return id == 46 and { cardId = 10017 } or nil end }
local exchangeCalls = {}
SWD3AllMonsterStaticCapture = { ExchangeCapturedSource = function(id, baseline) exchangeCalls[#exchangeCalls + 1] = { id = id, baseline = baseline }; return true, 'exchanged', 10017 end }
BattleField, Scene, OnEvent = {}, {}, {}
ESC = { StartBattle = function(id) _G.started = id end }
GameFunc = { RunScene = function(_, name) return Scene[name]() end }
BattleEnemys = { [1] = { NPC_GUID = 46, NPCData = { Level = 1 } } }
BattleEnv = { enemys = { [1] = { GUID = 46, self = BattleEnemys[1] } } }
SaveData = { Items = {} }

assert(loadfile(sourcePath))()
OnEvent.InputClick[1](nil, 63)
assert(started == 'SBLGP_CHIYOU_LEVEL')
assert(GameData.ItemTemp[46].IT_12 == true and GameData.ItemTemp[46].IT_06 == nil and GameData.ItemTemp[46].Level == 1)
assert(GameData.ItemTemp[46].ATK == 0 and GameData.ItemTemp[46].SPD == 0 and #GameData.ItemTemp[46].Skills == 0)
assert(GameData.Race[1].catch == true)
OnEvent.Battle_EnemyInit[1](1)
OnEvent.Battle_Dead[1](1, 1, 2)
OnEvent.Battle_RestoreItem[1]()
assert(#exchangeCalls == 1 and exchangeCalls[1].id == 46 and exchangeCalls[1].baseline == 0)
assert(GameData.ItemTemp[46].IT_12 == nil and GameData.ItemTemp[46].IT_06 == true and GameData.ItemTemp[46].Level == 80)
assert(GameData.ItemTemp[46].ATK == 999 and GameData.ItemTemp[46].SPD == 88 and #GameData.ItemTemp[46].Skills == 1)
assert(GameData.Race[1].catch == true)
assert(#logs >= 4)
print('PASS: story boss level gate probe mock runtime')
