local sourcePath = assert(arg[1], 'AllMonsterCaptureProbe.lua path is required')

local function equal(actual, expected, message)
    if actual ~= expected then
        error(string.format('%s: expected %s, got %s', message, tostring(expected), tostring(actual)))
    end
end

local function truthy(value, message)
    if not value then
        error(message)
    end
end

local logs = {}
log = function(message) table.insert(logs, message) end

SaveData = { Items = {} }
GameData = {
    ItemTemp = {
        [102] = {
            Name = 'ItemName102', ACT = 102, Race = 14, Level = 13,
            isBattleChar = true, ATK = 25, DEF = 20, SPD = 20, WIS = 20,
            HP = 20, AttackEffect = 4, SP_AttackEffects = {10},
            SP_AttackEffectsCount = {3}, GainEXP = 3, GainGold = 5
        }
    },
    Race = { [14] = { catch = true } }
}
OnEvent = { GameStart = {}, InputClick = {}, Battle_Dead = {}, Battle_RestoreItem = {}, MapLoading = {} }
BattleField = {}
BattleEnv = { enemys = { [1] = { GUID = 102 } } }
Scene = {}
local battleId = nil

Function = { CheckObsolt = function() return 0 end }
GameFunc = {
    GetBattleFieldID = function() return battleId end,
    RunScene = function(_, name, phase) Scene[name](phase) end
}
ESC = { StartBattle = function(id) battleId = id end }
ItemClass = {}
function ItemClass.AddItem(id, count)
    local slot
    for i, item in ipairs(SaveData.Items) do
        if item.ItemTempID == id then slot = i end
    end
    if not slot then
        table.insert(SaveData.Items, { ItemTempID = id, Count = 0, Count_New = 0 })
        slot = #SaveData.Items
    end
    SaveData.Items[slot].Count_New = SaveData.Items[slot].Count_New + count
    return 1, slot
end
function ItemClass.DelItem(slot, id, count)
    local item = SaveData.Items[slot]
    if not item or item.ItemTempID ~= id then return -1 end
    item.Count_New = item.Count_New - count
    if item.Count_New < 0 then
        item.Count = item.Count + item.Count_New
        item.Count_New = 0
    end
    if item.Count <= 0 and item.Count_New <= 0 then table.remove(SaveData.Items, slot) end
    return 0
end

dofile(sourcePath)
OnEvent.GameStart[1]()

-- F6: wrapper must affect only the isolated battle and never add the custom card.
OnEvent.InputClick[1](nil, 63)
equal(battleId, 'AMCP_CAPTURE_PROBE', 'F6 starts the isolated battle')
equal(Function.CheckObsolt({}, { NPC_GUID = 102 }), 100, 'wrapper overrides the probe enemy')
equal(Function.CheckObsolt({}, { NPC_GUID = 103 }), 0, 'wrapper leaves other enemies unchanged')
ItemClass.AddItem(102, 1)
OnEvent.Battle_Dead[1](1, 1, 2)
equal(#SaveData.Items, 0, 'phase 1 removes the native source item after confirmation')
OnEvent.Battle_RestoreItem[1]()

-- F10: bridge the target UI's IT_12 prerequisite, then restore the source table.
battleId = nil
OnEvent.InputClick[1](nil, 67)
equal(GameData.ItemTemp[102].IT_12, true, 'eligibility bridge temporarily marks only the probe source')
equal(Function.CheckObsolt({}, { NPC_GUID = 102 }), 100, 'wrapper applies during the eligibility bridge')
ItemClass.AddItem(102, 1)
OnEvent.Battle_Dead[1](1, 1, 2)
OnEvent.Battle_RestoreItem[1]()
equal(GameData.ItemTemp[102].IT_12, nil, 'eligibility bridge restores the absent IT_12 field')
equal(#SaveData.Items, 0, 'bridge phase leaves no source item behind')

-- F7: bridge eligibility and inject a new card table, exchanging only after source addition.
battleId = nil
OnEvent.InputClick[1](nil, 64)
truthy(GameData.ItemTemp[9001], 'phase 2 installs a custom item table')
equal(GameData.ItemTemp[102].IT_12, true, 'card phase temporarily applies the eligibility bridge')
equal(GameData.ItemTemp[9001].IT_12, true, 'custom card is an IT_12 card')
equal(GameData.ItemTemp[9001].Name, 'AMCP_CardName', 'custom card uses its own StringDB key')
equal(Function.CheckObsolt({}, { NPC_GUID = 102 }), 100, 'wrapper still applies in phase 2')
ItemClass.AddItem(102, 1)
OnEvent.Battle_Dead[1](1, 1, 2)
equal(#SaveData.Items, 1, 'phase 2 leaves exactly one item')
equal(SaveData.Items[1].ItemTempID, 9001, 'phase 2 exchanges into the custom ID')

-- F5 is the documented stop path before disabling the probe.
battleId = nil
OnEvent.Battle_RestoreItem[1]()
equal(GameData.ItemTemp[102].IT_12, nil, 'card phase restores the original enemy table')
OnEvent.InputClick[1](nil, 62)
equal(#SaveData.Items, 0, 'F5 clears probe cards')
truthy(#logs > 0, 'probe logs diagnostics')

print('PASS: all-monster capture probe mock runtime')
