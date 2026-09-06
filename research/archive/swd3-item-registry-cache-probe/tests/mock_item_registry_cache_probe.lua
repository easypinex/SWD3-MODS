local sourcePath = assert(arg[1], 'ItemRegistryCacheProbe.lua path is required')

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
            ACT = 101, Race = 9, Level = 12, isBattleChar = true, IT_12 = true,
            Consumption = 8, Cons_SP = true, UsePlace = 1,
            User_01 = true, User_02 = true, User_03 = true, User_04 = true,
            HP = 6, ATK = 19, DEF = 18, SPD = 16, WIS = 10
        }
    }
}
function GameData.SendItemTempData()
    local items, races = {}, {}
    for id, item in pairs(GameData.ItemTemp) do
        table.insert(items, id)
        races[item.Race] = races[item.Race] or {}
        table.insert(races[item.Race], id)
    end
    table.sort(items)
    for _, ids in pairs(races) do table.sort(ids) end
    GameData._ItemTemp, GameData._Race = items, races
end
GameData.SendItemTempData()
OnEvent = { GameStart = {}, InputClick = {} }
ItemClass = {}
function ItemClass.AddItem(id, count)
    for _, item in ipairs(SaveData.Items) do
        if item.ItemTempID == id then item.Count_New = item.Count_New + count; return 0 end
    end
    table.insert(SaveData.Items, { ItemTempID = id, Count = 0, Count_New = count })
    return 1
end
function ItemClass.DelItem(slot, id, count)
    local item = SaveData.Items[slot]
    if not item or item.ItemTempID ~= id then return -1 end
    item.Count_New = item.Count_New - count
    if item.Count_New < 0 then item.Count = item.Count + item.Count_New; item.Count_New = 0 end
    if item.Count <= 0 and item.Count_New <= 0 then table.remove(SaveData.Items, slot) end
    return 0
end

dofile(sourcePath)
OnEvent.GameStart[1]()
truthy(GameData.ItemTemp[9002], 'GameStart creates the custom item template')
equal(GameData.ItemTemp[101].Name, 'ItemName101', 'source card remains unchanged')
truthy(GameData._ItemTemp[2] == 9002, 'rebuild adds 9002 to the sorted item cache')
truthy(GameData._Race[9][2] == 9002, 'rebuild adds 9002 to the race cache')
OnEvent.InputClick[1](nil, 68)
equal(#SaveData.Items, 1, 'F11 adds exactly one custom item')
equal(SaveData.Items[1].ItemTempID, 9002, 'F11 adds the cache probe ID')
OnEvent.InputClick[1](nil, 69)
equal(#SaveData.Items, 0, 'F12 removes all cache probe cards')
truthy(#logs > 0, 'probe logs diagnostics')
print('PASS: item registry cache probe mock runtime')
