local sourcePath = assert(arg[1], 'StaticItemRegistryProbe.lua path is required')

local function equal(actual, expected, message)
    if actual ~= expected then
        error(string.format('%s: expected %s, got %s', message, tostring(expected), tostring(actual)))
    end
end

local function truthy(value, message)
    if not value then error(message) end
end

local logs = {}
log = function(message) table.insert(logs, message) end

SaveData = { Items = {} }
GameData = {
    ItemTemp = {
        [101] = {
            Name = 'ItemName101', HelpText = 'ItemHelp101', InfoText = 'ItemInfo101',
            ACT = 101, Race = 9, Level = 12, IT_12 = true, isBattleChar = true,
            HP = 100, ATK = 10, DEF = 10, SPD = 10, WIS = 10
        }
    },
    _ItemTemp = {},
    _Race = {}
}
OnEvent = { GameStart = {}, InputClick = {} }
ItemClass = {}

function ItemClass.AddItem(id, count)
    for _, item in ipairs(SaveData.Items) do
        if item.ItemTempID == id then
            item.Count_New = item.Count_New + count
            return 0
        end
    end
    table.insert(SaveData.Items, { ItemTempID = id, Count = 0, Count_New = count })
    return 1
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

-- 模擬引擎：原版資料先就緒，MOD DAT 2 在 native cache 建立前載入。
dofile(sourcePath)
truthy(GameData.ItemTemp[9003], 'top-level MOD load creates ID 9003')
equal(GameData.ItemTemp[101].Name, 'ItemName101', 'source card remains unchanged')

for id, item in pairs(GameData.ItemTemp) do
    table.insert(GameData._ItemTemp, id)
    GameData._Race[item.Race] = GameData._Race[item.Race] or {}
    table.insert(GameData._Race[item.Race], id)
end
table.sort(GameData._ItemTemp)

OnEvent.GameStart[1]()
local status = SWD3StaticItemRegistryProbe.GetStatus()
truthy(status.installedAtLoad, 'status records load-phase installation')
truthy(status.cardInItemCache, 'native-style cache build sees ID 9003')
truthy(status.cardInRaceCache, 'native-style race cache build sees ID 9003')

OnEvent.InputClick[1](nil, 61)
equal(SaveData.Items[1].ItemTempID, 9003, 'F4 adds the static probe card')
OnEvent.InputClick[1](nil, 60)
equal(#SaveData.Items, 0, 'F3 removes the static probe card')
truthy(#logs >= 2, 'probe logs load and input diagnostics')

print('PASS: static item registry probe mock runtime')
