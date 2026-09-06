local sourcePath = arg[1]
local function equal(actual, expected, label)
    if actual ~= expected then error(label .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end
end
local logs = {}
function log(message) table.insert(logs, message) end
GameData = { ItemTemp = { [59] = { HP = 30000, ATK = 800, SPD = 180, Level = 1, IT_12 = true, Skills = { 1 }, CureSkills = { 2 }, SP_AE = { 3 } } } }
OnEvent = { GameStart = {}, InputClick = {}, Battle_RestoreItem = {}, MapLoading = {} }
BattleField, Scene = {}, {}
ESC = { StartBattle = function(id) equal(id, 'AMSC_FORMAL_BOSS_VALIDATE', 'battle id') end }
GameFunc = { RunScene = function(_, name) Scene[name]() end }
SWD3AllMonsterStaticCapture = { captureRuntime = { active = {} } }
dofile(sourcePath)
OnEvent.GameStart[1]()
OnEvent.InputClick[1](nil, 61)
equal(GameData.ItemTemp[59].HP, 1, 'HP tuned only for validation battle')
equal(GameData.ItemTemp[59].ATK, 0, 'ATK tuned only for validation battle')
equal(GameData.ItemTemp[59].Level, 1, 'formal bridge level is not changed by validation probe')
OnEvent.Battle_RestoreItem[1]()
equal(GameData.ItemTemp[59].HP, 30000, 'HP restored')
equal(GameData.ItemTemp[59].ATK, 800, 'ATK restored')
equal(GameData.ItemTemp[59].SPD, 180, 'SPD restored')
assert(#logs > 0, 'logs emitted')
print('PASS: formal capture validation probe mock runtime')
