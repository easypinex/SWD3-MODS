local sourcePath = assert(arg[1], 'probe source path is required')
local function equal(actual, expected, label) if actual ~= expected then error(label .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end end
local function truthy(value, label) if not value then error(label) end end
local function contains(items, needle) for _, value in ipairs(items) do if tostring(value):find(needle, 1, true) then return true end end end
local function run(handlers, ...) for _, handler in ipairs(handlers or {}) do handler(...) end end
local logs = {}
function log(message) table.insert(logs, message) end

GameData = { ItemTemp = { [59] = { Level = 80, HP = 30000, ATK = 800, SPD = 180, Skills = { 1 }, CureSkills = { 2 }, SP_AE = { 3 } } } }
SWD3AllMonsterStaticCapture = { captureRuntime = { active = {} } }
OnEvent = {
    GameStart = {}, InputClick = {}, Battle_EnemyInit = {}, Battle_Enter = {}, Battle_Dead = {}, Battle_RestoreItem = {}, MapLoading = {},
    BattlePlayerAI_after = { main = function(index)
        BattlePlayers[index].AI_Target = 0
        BattlePlayers[index].AI_Command = 0
        BattlePlayers[index].AI_SelectItem = 0
    end }
}
BattleField, BattleScript, Scene = {}, {}, {}
local nativeCalls = 0
local currentField = nil
BSC = {
    Enter = function()
        run(OnEvent.Battle_EnemyInit, 1)
        BattleEnemys[1].NPCData.Level = 31 -- formal all-monster Battle_Enter cap, before this probe restores it.
        run(OnEvent.Battle_Enter)
    end,
    Run = function()
        equal(BattleEnemys[1].NPCData.Level, 80, 'manual turn sees restored live Level')
        BattlePlayers[1].AI_Command = 6
        BattlePlayers[1].AI_Target = 1
        BattlePlayers[1].AI_TargetIsEnemySide = true
        OnEvent.BattlePlayerAI_after.main(1)
    end,
    Obsolt = function(playerRef, enemyRef)
        nativeCalls = nativeCalls + 1
        equal(playerRef, 1, 'native player reference')
        equal(enemyRef, -1, 'native enemy reference')
        return 'mock-native-capture'
    end
}
BattleEnemys = { [1] = { NPC_GUID = 59, NPCData = { Level = 80, HP = 100, MaxHP = 100 } } }
BattleEnv = { enemys = { [1] = { GUID = 59, self = BattleEnemys[1] } } }
BattlePlayers = { [1] = { CharData = { Level = 20 } } }
ESC = { StartBattle = function(id) currentField = id; BattleScript[id]() end }
GameFunc = { GetBattleFieldID = function() return currentField end, RunScene = function(_, name) return Scene[name]() end }

dofile(sourcePath)
run(OnEvent.GameStart)
equal(OnEvent.InputClick[1](nil, 63), true, 'F6 is handled')
equal(nativeCalls, 1, 'bridge is called once only after BSC.Run returns')
equal(BattleEnemys[1].NPCData.HP, 15, 'target current HP is isolated at 15 percent')
equal(BattleEnemys[1].NPCData.MaxHP, 100, 'target max HP is isolated at 100')
run(OnEvent.Battle_Dead, 1, 1, 2)
currentField = nil
run(OnEvent.Battle_RestoreItem)
equal(GameData.ItemTemp[59].HP, 30000, 'source HP restored')
equal(GameData.ItemTemp[59].ATK, 800, 'source ATK restored')
equal(GameData.ItemTemp[59].SPD, 180, 'source SPD restored')
equal(#GameData.ItemTemp[59].Skills, 1, 'source skills restored')
truthy(contains(logs, 'BattleScript entered'), 'script context is observable')
truthy(contains(logs, 'Battle_Enter restored target Level 31 -> 80'), 'formal cap is restored before manual turn')
truthy(contains(logs, 'manual 靈契 observed before AI reset: player=1, enemy=1, source=59'), 'manual capture command is observed before original reset')
truthy(contains(logs, 'BSC.Run returned after high-level manual 靈契'), 'bridge waits for the post-turn return')
truthy(contains(logs, 'cleanup complete: Battle_RestoreItem'), 'cleanup is observable')
print('PASS: manual capture bridge probe mock runtime')
