local sourcePath = assert(arg[1], 'expected probe source path')

local messages = {}
function log(message) table.insert(messages, tostring(message)) end

OnEvent = {}
GameData = { ItemTemp = {
    [59] = { IT_12 = true, IT_06 = nil, HP = 30000, ATK = 800, SPD = 60,
        Skills = { 1 }, CureSkills = { 2 }, SP_AE = { 3 } }
} }
SWD3AllMonsterStaticCapture = { captureRuntime = { active = {} } }
BattleEnemys, BattlePlayers, BattleField, BattleScript = nil, {}, {}, {}
BSC = { Enter = function() end }
Scene = {}
_BattleEnv = { NowMenu = 0 }

local function dispatch(name, ...)
    for _, handler in ipairs(OnEvent[name] or {}) do handler(...) end
end

ESC = {
    StartBattle = function(id)
        BattleEnemys = { [1] = { NPC_GUID = 59, NPCData = { HP = 100, MaxHP = 100, Level = 80, ItemType = 0x20 } } }
        dispatch('Battle_EnemyInit', 1)
        dispatch('Battle_Enter')
        assert(type(BattleScript[id]) == 'function', 'missing isolated BattleScript')
        BattleScript[id]()
    end
}
GameFunc = {
    RunScene = function(_, name)
        assert(type(Scene[name]) == 'function', 'missing Scene function: ' .. tostring(name))
        return Scene[name]()
    end
}

dofile(sourcePath)
assert(BattlePlayerAI_mod == nil, 'v0.5 must not enable the native AI dispatch global')
dispatch('GameStart')
dispatch('InputClick', nil, 60)

local status = BattleEnemys[1].NPCData
assert(status.HP == 15, 'F3 must set isolated enemy HP to 15')
assert(status.ItemType == 0, 'Battle_Enter baseline must disable the live Boss bit')

status.ItemType = 0x20
_BattleEnv.NowMenu = 1
dispatch('InputKeyDown', nil, 0)
assert(status.ItemType == 0, 'NowMenu=1 input must clear the Boss bit')
dispatch('BattlePlayerAI_after', 2)
assert(status.ItemType == 0x20, 'every PlayerAI_after must restore the Boss bit')

_BattleEnv.NowMenu = 3
dispatch('Battle_InputKeyDown', nil, 0)
assert(status.ItemType == 0, 'NowMenu=3 battle input must clear the Boss bit')
dispatch('BattlePlayerAI_after', 1)
assert(status.ItemType == 0, 'Seth after must retain the non-Boss window for action 6 in v0.6')
dispatch('BattlePlayerAI_after', 2)
assert(status.ItemType == 0x20, 'non-Seth after must restore the Boss bit before damage')
dispatch('Battle_RestoreItem')

local source = GameData.ItemTemp[59]
assert(source.HP == 30000 and source.ATK == 800 and source.SPD == 60, 'source numeric fields were not restored')
assert(source.Skills[1] == 1 and source.CureSkills[1] == 2 and source.SP_AE[1] == 3, 'source skill fields were not restored')
assert(status.ItemType == 0x20, 'live ItemType snapshot was not restored')

print('PASS: Seth capture input-window probe mock runtime')
