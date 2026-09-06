local function equal(actual, expected, label)
    if actual ~= expected then error(label .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end
end

local function contains(text, fragment, label)
    if not string.find(text, fragment, 1, true) then error(label .. ': missing ' .. fragment .. ' in ' .. text) end
end

local logs = {}
function log(message) table.insert(logs, message) end

OnEvent = {}
GameFunc = { GetBattleFieldID = function() return 'MOCK_BATTLE' end }
_BattleEnv = { NowMenu = 1, bBattleCmdPause = true, PlayerIDMax = 2, EnemyIDMax = 1 }
BattleEnv = { inSelectAI = -1, inSelectAIKeyDown = -1, inCommandMenu = -1 }
InputFunc = { MouseX = 713, MouseY = 288 }
BattlePlayers = {
    [1] = { NPC_GUID = 1, AI_Command = 6, AI_Target = 1, AI_TargetIsEnemySide = true, AI_SelectItem = 0, CharData = { Level = 20, HP = 410, MaxHP = 550 } },
    [2] = { NPC_GUID = 2, AI_Command = 0, AI_Target = 0, AI_TargetIsEnemySide = false, AI_SelectItem = 0, NPCData = { Level = 18, HP = 375, MaxHP = 375 } }
}
BattleEnemys = { [1] = { NPC_GUID = 59, NPCData = { Level = 80, HP = 1, MaxHP = 30000 } } }

dofile(arg[1])

local events = {
    'InputKeyDown', 'InputKeyUp', 'InputClick', 'InputDClick',
    'Battle_Enter', 'Battle_InputKeyDown', 'Battle_InputClick', 'Battle_InputDClick', 'Battle_CmdSelectOK', 'Battle_DrawBGI',
    'Battle_EnemyInit', 'Battle_PlayerInit', 'Battle_NPCInit', 'Battle_KeeperInit', 'Battle_Dead', 'Battle_StopSkill',
    'Battle_Freeze', 'Battle_SetActive', 'Battle_RestoreItem', 'Battle_CancelClick', 'CheckLearnSpecialSkill',
    'CheckStatSpecialSkill', 'BattleCriticalHitRate', 'BattleEnemyEscapeRate', 'BattleGain', 'BattleEnemyAI',
    'BattlePlayerAI', 'BattlePlayerAI_after', 'BattleNPCAI'
}
for _, eventName in ipairs(events) do
    equal(type(OnEvent[eventName]), 'table', 'creates ' .. eventName .. ' handler table')
    equal(#OnEvent[eventName], 1, 'registers exactly one ' .. eventName .. ' handler')
end

OnEvent.Battle_EnemyInit[1](1)
contains(logs[#logs], 'Battle_EnemyInit[1]: enemyIndex=1, source=59, statusType=table, level=80, hp=1/30000', 'reads initialized enemy')
OnEvent.Battle_PlayerInit[1](1)
contains(logs[#logs], 'Battle_PlayerInit[1]: playerIndex=1, source=1, statusType=table, level=20, hp=410/550', 'reads initialized player')
OnEvent.Battle_Enter[1]()
contains(logs[#logs], 'Battle_Enter[1]: field=MOCK_BATTLE', 'traces battle entry')
OnEvent.InputKeyDown[1](32, 40)
contains(logs[#logs], 'InputKeyDown[1]: flag=32, scancode=40;', 'records the HD global input arguments during battle')
OnEvent.InputKeyUp[1](32, 40)
OnEvent.InputClick[1](32, 40)
OnEvent.InputDClick[1](32, 40)
OnEvent.Battle_DrawBGI[1](1)
OnEvent.Battle_InputKeyDown[1]()
OnEvent.Battle_InputClick[1](nil)
OnEvent.Battle_InputDClick[1]()
OnEvent.Battle_CmdSelectOK[1]()
contains(logs[#logs], 'capture=playerIndex=1, enemyIndex=1, source=59, statusType=table, level=80, hp=1/30000', 'reads capture target without changing it')
contains(logs[#logs], 'native={NowMenu=1, pause=true, players=2, enemys=1}', 'records the native menu snapshot without changing it')
contains(logs[#logs], 'selection={ai=-1, aiKey=-1, commandMenu=-1, target=nil}', 'records Lua selection state without changing it')
OnEvent.Battle_NPCInit[1](2)
OnEvent.Battle_KeeperInit[1](2, 3)
OnEvent.BattleEnemyAI[1](1)
OnEvent.BattlePlayerAI[1](1)
OnEvent.BattlePlayerAI_after[1](1)
OnEvent.BattleNPCAI[1](2)
OnEvent.BattleCriticalHitRate[1](0, 1, 0, 1, 1)
OnEvent.BattleEnemyEscapeRate[1](1, 1, 20, 0)
OnEvent.Battle_StopSkill[1](1, 0)
OnEvent.Battle_Freeze[1](1, 0)
OnEvent.Battle_SetActive[1](1, 0, 1)
OnEvent.CheckLearnSpecialSkill[1](1, 100)
OnEvent.CheckStatSpecialSkill[1](1, 100)
OnEvent.BattleGain[1](10, 20, 30, 40)
OnEvent.Battle_CancelClick[1]()
OnEvent.Battle_Dead[1](1, 1, 2)
contains(logs[#logs], 'Battle_Dead[1]: index=1, side=1, mode=2, source=59', 'records native capture result')
equal(BattleEnemys[1].NPCData.Level, 80, 'does not change target level during the full trace')
OnEvent.Battle_RestoreItem[1]()
contains(logs[#logs - 1], 'battle summary #1: field=MOCK_BATTLE;', 'writes a per-battle callback summary')
contains(logs[#logs], 'battle order prefix:', 'writes the observed order prefix')
equal(BattleEnemys[1].NPCData.Level, 80, 'leaves level unchanged after every callback')
local countBeforeMapInput = #logs
OnEvent.InputKeyDown[1](32, 40)
equal(#logs, countBeforeMapInput, 'does not trace global input after battle cleanup')

print('PASS: capture command timing probe mock runtime')
