-- Offline only: load original definitions, never execute a scene or a transaction.
local root = assert(arg[1])
GameData, Const, OnEvent, SaveData, Function = {}, {}, {}, {Items={}}, {}
for _, name in ipairs({'GameData_ItemData.lua','GameData_BattleCharData.lua',
    'GameData_WeaponData.lua','GameData_ArmorData.lua','GameData_SkillData.lua',
    'GameData_AttackEffect.lua','GameData_RaceDefine.lua','OnEvent_Obsolt.lua'}) do
    assert(loadfile(root..'/'..name))()
end
local function json(value)
    if type(value)=='number' or type(value)=='boolean' then return tostring(value) end
    if type(value)=='string' then
        return '"'..value:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\r','\\r'):gsub('\n','\\n'):gsub('\t','\\t')..'"'
    end
    if type(value)~='table' then return 'null' end
    local keys, parts = {}, {}
    for k in pairs(value) do keys[#keys+1]=k end
    table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
    for _,k in ipairs(keys) do parts[#parts+1]=json(tostring(k))..':'..json(value[k]) end
    return '{'..table.concat(parts,',')..'}'
end
print(json({items=GameData.ItemTemp,effects=GameData.AttackEffect,
    races=GameData.Race,refineryTypes=GameData.RefineryType,
    rev=GameData.RevType,table=GameData.ObsoltRaceTable,xy=GameData.ObsoltXY}))
