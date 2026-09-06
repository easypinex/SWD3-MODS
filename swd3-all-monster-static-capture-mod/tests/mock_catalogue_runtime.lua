local cataloguePath = assert(arg[1], 'catalogue path is required')
local sourcePath = assert(arg[2], 'integration path is required')
local function equal(actual, expected, message) if actual ~= expected then error(message .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end end
local function truthy(value, message) if not value then error(message) end end
local logs = {}
log = function(message) table.insert(logs, message) end
GameData = { ItemTemp = { [101] = { Name='ItemName101', Race=9, IT_12=true, isBattleChar=true, HP=19, ATK=18, DEF=16, Consumption=8 } } }
SaveData = { Items = {} }
OnEvent = { GameStart = {} }
ItemClass = {}
function ItemClass.AddItem(id, count)
    for _, item in ipairs(SaveData.Items) do if item.ItemTempID == id then item.Count_New = item.Count_New + count; return 0 end end
    table.insert(SaveData.Items, { ItemTempID=id, Count=0, Count_New=count }); return 1
end
function ItemClass.DelItem(slot, id, count)
    local item=SaveData.Items[slot]; if not item or item.ItemTempID ~= id then return -1 end
    item.Count_New=item.Count_New-count
    if item.Count_New < 0 then item.Count=item.Count+item.Count_New; item.Count_New=0 end
    if item.Count <= 0 and item.Count_New <= 0 then table.remove(SaveData.Items,slot) end
    return 0
end
dofile(cataloguePath)
for sourceId, entry in pairs(SWD3AllMonsterStaticCatalogue.entries) do
    if GameData.ItemTemp[sourceId] == nil then
        GameData.ItemTemp[sourceId] = { Name='ItemName'..sourceId, Race=1, Level=20, ACT=sourceId, isBattleChar=true, HP=100, ATK=40, DEF=30 }
    end
end
GameData.ItemTemp[102] = { Name='ItemName102', HelpText='ItemHelp102', Race=14, Level=13, ACT=102, isBattleChar=true, HP=20, ATK=25, DEF=20, AttrThunder=4 }
dofile(sourcePath)
OnEvent.GameStart[1]()
local status=SWD3AllMonsterStaticCapture.GetStatus()
equal(status.mappedEnemies, 193, 'all combatants have mappings')
equal(status.staticCards, 97, 'exactly 97 new static cards are required')
equal(status.installedStaticCards, 97, 'all static cards install at load')
equal(status.failedStaticCards, 0, 'static card installation has no failures')
truthy(GameData.ItemTemp[10042] and GameData.ItemTemp[10042].IT_12, 'snake static card is registered')
equal(GameData.ItemTemp[10042].NotInBook, true, 'new static cards are excluded from the native monster book')
equal(GameData.ItemTemp[10042].HelpText, 'ItemHelp102', 'static card preserves the source long-form item description')
equal(GameData.ItemTemp[10042].InfoText, 'AMSC_Info_102', 'static card uses its own concrete guardian-bonus summary')
for sourceId, entry in pairs(SWD3AllMonsterStaticCatalogue.entries) do
    if entry.staticCard == true then
        local card = GameData.ItemTemp[entry.cardId]
        for _, field in ipairs({ 'AddHP', 'AddMP', 'AddSP', 'AddSTR', 'AddStamina', 'AddWIS', 'AddSPD', 'AddATK', 'AddDEF' }) do
            truthy(type(card[field]) == 'number' and card[field] > 0, 'static card '..entry.cardId..' has a positive guardian bonus: '..field)
        end
        for _, field in ipairs({ 'AttrFire', 'AttrIce', 'AttrWind', 'AttrEarth', 'AttrPoison', 'AttrLight', 'AttrDark', 'AttrThunder', 'AttrPhysical' }) do
            equal(card[field], nil, 'static card '..entry.cardId..' does not claim unsupported guardian resistance: '..field)
        end
    end
end
equal(GameData.ItemTemp[102].IT_12, nil, 'source snake remains unchanged')
equal(SWD3AllMonsterStaticCapture.CardIdForEnemy(102), 10042, 'snake maps to its static card')
ItemClass.AddItem(102, 1)
local exchanged, reason, cardId=SWD3AllMonsterStaticCapture.ExchangeCapturedSource(102, 0)
truthy(exchanged, 'exchange succeeds: '..tostring(reason))
equal(cardId, 10042, 'exchange returns mapped static card')
equal(SaveData.Items[1].ItemTempID, 10042, 'inventory receives mapped static card')
truthy(#logs > 0, 'load summary is logged')
print('PASS: all-monster static catalogue mock runtime')
