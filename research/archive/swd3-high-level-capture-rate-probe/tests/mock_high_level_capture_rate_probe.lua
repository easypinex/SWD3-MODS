local sourcePath = assert(arg[1], 'probe source path is required')
local function equal(actual, expected, label)
    if actual ~= expected then error(label .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end
end
local function truthy(value, label) if not value then error(label) end end
local function contains(items, needle)
    for _, value in ipairs(items) do if tostring(value):find(needle, 1, true) then return true end end
    return false
end
local function run(handlers, ...)
    for _, handler in ipairs(handlers or {}) do handler(...) end
end
local logs = {}
function log(message) table.insert(logs, message) end

GameData = { ItemTemp = { [59] = { Level = 80, HP = 30000, ATK = 800, SPD = 180, Skills = { 1 }, CureSkills = { 2 }, SP_AE = { 3 } } } }
SWD3AllMonsterStaticCapture = { captureRuntime = { active = {} } }
OnEvent = {
    GameStart = {}, InputClick = {}, Battle_EnemyInit = {}, Battle_Enter = {}, Battle_InputClick = {},
    Battle_CmdSelectOK = {}, Battle_CancelClick = {}, Battle_DrawBGI = {}, Battle_PlayerAI = {},
    Battle_PlayerAI_after = {}, Battle_EnemyAI = {}, Battle_NPCAI = {}, BattleCriticalHitRate = {},
    Battle_Dead = {}, Battle_RestoreItem = {}, MapLoading = {}
}
BattleField, Scene = {}, {}
Const = { BPLAY1 = 1, BMS1 = -1 }
local nativeBscCall = nil
BSC = { Enter = function() end, Obsolt = function(playerRef, enemyRef)
    nativeBscCall = { playerRef = playerRef, enemyRef = enemyRef }
    return 'mock-native-capture'
end }
BattleScript = {}
ESC = { StartBattle = function(id) equal(id, 'HLCRP_BULL_DEMON_RATE', 'battle ID') end }
GameFunc = { RunScene = function(_, name) return Scene[name]() end }
BattleEnemys = { [1] = { NPC_GUID = 59, NPCData = { Level = 80, HP = 100, MaxHP = 100 } } }
BattlePlayers = { [1] = { CharData = { Level = 20 } } }
Function = { CheckObsolt = function(player, target)
    equal(player.CharData.Level, 20, 'player level passed to formula')
    equal(target.NPCData.Level, 31, 'enemy battle level is capped at player plus 11')
    equal(target.NPCData.HP, 15, 'enemy current HP is 15 percent')
    equal(target.NPCData.MaxHP, 100, 'enemy max HP remains 100')
    return 100
end }
local originalCheckObsolt = Function.CheckObsolt

dofile(sourcePath)
run(OnEvent.GameStart)
equal(OnEvent.InputClick[1](nil, 61), true, 'F4 is handled')
equal(GameData.ItemTemp[59].Level, 80, 'source level stays original during setup')
equal(GameData.ItemTemp[59].HP, 100, 'source max HP is only tuned for isolated battle')
run(OnEvent.Battle_EnemyInit, 1)
equal(BattleEnemys[1].NPCData.HP, 15, 'battle HP set to 15 percent')
run(OnEvent.Battle_Enter)
equal(BattleEnemys[1].NPCData.Level, 31, 'battle level is capped at player plus 11')
equal(Function.CheckObsolt(BattlePlayers[1], BattleEnemys[1]), 100, 'call trace preserves native 100 percent result')
BattleScript.HLCRP_BULL_DEMON_RATE()
equal(BattleEnemys[1].NPCData.Level, 80, 'BattleScript restores the target battle level before native capture')
equal(nativeBscCall.playerRef, 1, 'native bridge uses original player signed reference')
equal(nativeBscCall.enemyRef, -1, 'native bridge uses original enemy signed reference')
run(OnEvent.Battle_InputClick, 0)
run(OnEvent.Battle_DrawBGI, 1)
run(OnEvent.Battle_CmdSelectOK)
run(OnEvent.Battle_PlayerAI, 1)
run(OnEvent.BattleCriticalHitRate, 0, 1, 0, 1, 1)
run(OnEvent.Battle_PlayerAI_after, 1)
run(OnEvent.Battle_Dead, 1, 1, 2)
run(OnEvent.Battle_RestoreItem)
equal(Function.CheckObsolt, originalCheckObsolt, 'call trace restored original capture function')
equal(BattleEnemys[1].NPCData.Level, 80, 'battle level restored')
equal(GameData.ItemTemp[59].Level, 80, 'source level restored')
equal(GameData.ItemTemp[59].HP, 30000, 'source HP restored')
equal(GameData.ItemTemp[59].ATK, 800, 'source ATK restored')
equal(GameData.ItemTemp[59].SPD, 180, 'source SPD restored')
equal(#GameData.ItemTemp[59].Skills, 1, 'source skills restored')
truthy(#logs > 0, 'diagnostics emitted')
truthy(contains(logs, 'event #'), 'timeline emitted event ordering')
truthy(contains(logs, 'Battle_InputClick; cmd=0'), 'timeline recorded battle input')
truthy(contains(logs, 'BattleCriticalHitRate; input=0'), 'timeline recorded critical callback')
truthy(contains(logs, 'BattleScript_RestoreTargetLevel; enemy battle Level=31 -> 80'), 'timeline recorded BattleScript timing restore')
truthy(contains(logs, 'event summary (Battle_RestoreItem)'), 'timeline summary emitted')
truthy(contains(logs, 'native capture bridge inventory: BSC=table, BSC.Obsolt=function, BattleScript=table'), 'native capture bridge is only inventoried')
truthy(contains(logs, 'BSC.Obsolt; calling original native bridge with playerRef=1, enemyRef=-1, targetLevel=80'), 'native bridge invocation is isolated and documented')
truthy(contains(logs, 'native BSC.Obsolt BattleScript coroutine entered'), 'BattleScript coroutine entry is observable')
print('PASS: high-level capture-rate probe mock runtime')
