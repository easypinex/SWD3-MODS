-- Independent original Lua preview; doing=0 cannot consume or create items.
local root, witness = assert(arg[1]), assert(arg[2])
GameData, Const, OnEvent, SaveData, Function = {}, {}, {}, {Items={},ItemTemp={}}, {}
function log() end
function StringDB(s) return s end
-- Fengari Lua 5.3 rejects fractional values in %d used by original debug logs.
-- Only format those diagnostics with %g; recipe arithmetic stays untouched.
local originalFormat=string.format
string.format=function(fmt,...) return originalFormat(fmt:gsub('%%d','%%g'),...) end
for _, name in ipairs({'GameData_ItemData.lua','GameData_BattleCharData.lua',
    'GameData_WeaponData.lua','GameData_ArmorData.lua','GameData_SkillData.lua',
    'GameData_AttackEffect.lua','Function_Repository.lua','OnEvent_Obsolt.lua'}) do
    assert(loadfile(root..'/'..name))()
end
ItemClass={DelItem=function() error('transaction forbidden') end,AddItem=function() error('transaction forbidden') end}
local edges=assert(loadfile(witness))()
for _,v in ipairs(edges) do
    SaveData.Items={{ItemTempID=v[1]},{ItemTempID=v[2]}}
    OnEventValue={}
    OnEvent.Obsolt.main(1,2,0)
    local got=OnEventValue[v[3]=='east' and 'CalcResEast' or 'CalcResWest']
    assert(got==v[4],table.concat({v[1],v[2],v[3],got or 'nil',v[4]},' '))
end
print('PASS: original Lua preview witnesses '..#edges..'; no transactions')
