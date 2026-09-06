local sourcePath = assert(arg[1], 'expected source path')
local logs = {}
log = function(message) logs[#logs + 1] = message end

GameData = {
    ItemTemp = {
        [102] = { Race = 7 },
        [103] = { Race = 8, IT_12 = false, IT_06 = true },
        [999] = { Race = 9 },
    },
    Race = { [7] = { catch = false }, [8] = { catch = true }, [9] = { catch = false } },
}
SWD3AllMonsterStaticCatalogue = { entries = { [102] = {}, [103] = {} } }
BattleEnemys = { [1] = { NPC_GUID = 102 } }
BattleEnv = { enemys = { [1] = { GUID = 102, self = BattleEnemys[1] } } }
SaveData = { Items = {} }
local exchangeCalls = {}
SWD3AllMonsterStaticCapture = {
    ExchangeCapturedSource = function(sourceId, baseline)
        exchangeCalls[#exchangeCalls + 1] = { sourceId = sourceId, baseline = baseline }
        return true, 'exchanged', 10042
    end,
}
OnEvent = {}

assert(loadfile(sourcePath))()
assert(type(OnEvent.InputClick) == 'table' and #OnEvent.InputClick == 1)
assert(type(OnEvent.Battle_EnemyInit) == 'table' and #OnEvent.Battle_EnemyInit == 1)

OnEvent.InputClick[1](nil, 74)
assert(GameData.ItemTemp[102].IT_12 == true and GameData.ItemTemp[102].IT_06 == nil)
assert(GameData.ItemTemp[103].IT_12 == true and GameData.ItemTemp[103].IT_06 == nil)
assert(GameData.ItemTemp[999].IT_12 == nil and GameData.Race[9].catch == false)
assert(GameData.Race[7].catch == true and GameData.Race[8].catch == true)
OnEvent.Battle_EnemyInit[1](1)

OnEvent.Battle_Dead[1](1, 1, 2)
OnEvent.Battle_RestoreItem[1]()
assert(#exchangeCalls == 1 and exchangeCalls[1].sourceId == 102 and exchangeCalls[1].baseline == 0)
assert(GameData.ItemTemp[102].IT_12 == nil and GameData.ItemTemp[102].IT_06 == nil)
assert(GameData.ItemTemp[103].IT_12 == false and GameData.ItemTemp[103].IT_06 == true)
assert(GameData.Race[7].catch == false and GameData.Race[8].catch == true)

SWD3AllMonsterStaticCatalogue = nil
OnEvent.InputClick[1](nil, 74)
assert(GameData.ItemTemp[102].IT_12 == nil and GameData.Race[7].catch == false)
assert(#logs >= 4)
print('PASS: general capture eligibility probe mock runtime')
