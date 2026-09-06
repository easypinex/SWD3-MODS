local function equal(actual, expected, label)
    if actual ~= expected then error(label .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end
end

local function contains(text, fragment, label)
    if not string.find(text, fragment, 1, true) then error(label .. ': missing ' .. fragment .. ' in ' .. text) end
end

local logs = {}
function log(message) table.insert(logs, message) end

OnEvent = {}
OnEventValue = { BeCriticalHit = 0 }
GameFunc = { GetBattleFieldID = function() return 'MOCK_CRITICAL' end }
GameData = {
    ItemTemp = {
        [2] = { Name = 'ItemNamePlayer2' },
        [59] = { Name = 'ItemName59' },
        [521] = { IT_09 = true, Name = 'ItemName521', AttackEffect = 7 }
    },
    AttackEffect = { [7] = { hActionType = 2, iAttr = 9, iDelay = 10 } }
}
SaveData = { PlayerEqu = { [2] = { { ItemTempID = 521 } } } }
BattlePlayers = { [1] = { NPC_GUID = 2, CharData = { Level = 40 } } }
BattleEnemys = { [1] = { NPC_GUID = 59, NPCData = { Level = 80, HP = 30000 } } }

dofile(arg[1])

equal(#OnEvent.BattleCriticalHitRate, 1, 'registers critical handler')
OnEvent.Battle_Enter[1]()
OnEvent.BattleCriticalHitRate[1](0, 1, 0, 1, 1)
OnEvent.BattlePlayerAI_after[1](1)
BattleEnemys[1].NPCData.HP = 29997
OnEvent.Battle_DrawBGI[1](1)
contains(logs[#logs], 'normal', 'reports normal result')
contains(logs[#logs], 'observedDamage=3', 'measures normal damage')

OnEventValue.BeCriticalHit = 1
BattleEnemys[1].NPCData.HP = 30000
OnEvent.BattleCriticalHitRate[1](0, 1, 0, 1, 1)
OnEvent.BattlePlayerAI_after[1](1)
BattleEnemys[1].NPCData.HP = 20001
OnEvent.Battle_DrawBGI[1](1)
contains(logs[#logs], 'CRITICAL', 'reports final critical flag')
contains(logs[#logs], 'observedDamage=9999', 'measures critical damage')

print('PASS: critical-hit formula probe mock runtime')
