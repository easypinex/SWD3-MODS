local root, native=arg[1],arg[2]
local function load(name) assert(loadfile(root..'/src/data/'..name))() end
local function fresh()
    SWD3CaiDemonKing=nil; SWD3AllMonsterStaticCapture=nil
    GameData={ItemTemp={[438]={ACT=438,Level=99,HP=10000}}}; Const={}
    if native then
        assert(loadfile(native..'/GameData_SkillData.lua'))()
        assert(loadfile(native..'/GameData_AttackEffect.lua'))()
    else assert(loadfile(root..'/tests/skill_fixture.lua'))() end
    load('CaiDemonActions.lua'); load('CaiDemonData.lua')
end
fresh()
local oldLight,oldDark=GameData.ItemTemp[1676],GameData.ItemTemp[1668]
local oldEffect=GameData.AttackEffect[73]
load('CaiDemonChallengeData.lua')
assert(GameData.ItemTemp[1676]==oldLight and oldLight.AttackEffect==121)
assert(GameData.ItemTemp[1668]==oldDark and oldDark.AttackEffect==73)
assert(GameData.AttackEffect[73]==oldEffect and oldEffect.iAttackPoint==80)
assert(GameData.AttackEffect[121].iAttackPoint==120)
for _,pair in ipairs({{11002,1676,121,3000},{11003,1668,73,3200}}) do
    local id,source,effect,points=table.unpack(pair)
    local skill,fx=GameData.ItemTemp[id],GameData.AttackEffect[id]
    assert(skill~=GameData.ItemTemp[source] and fx~=GameData.AttackEffect[effect])
    assert(skill.AttackEffect==id and fx.iAttackPoint==points)
    for k,v in pairs(GameData.ItemTemp[source]) do
        if k~='AttackEffect' then assert(skill[k]==v,'skill field changed: '..k) end
    end
    for k,v in pairs(GameData.AttackEffect[effect]) do
        if k~='iAttackPoint' then assert(fx[k]==v,'effect field changed: '..k) end
    end
end
assert(GameData.ItemTemp[11002].Area==nil and GameData.AttackEffect[11002].iAttr==6)
assert(GameData.ItemTemp[11003].Area==1 and GameData.AttackEffect[11003].bWideRange==true)
assert(GameData.ItemTemp[438].Skills[1]==1676)
assert(GameData.ItemTemp[11004].AttackEffect==11004 and GameData.ItemTemp[11004].User_04==nil)
assert(GameData.AttackEffect[11004].iAttackPoint==4200 and GameData.AttackEffect[11004].iAttr==9)
assert(not GameData.AttackEffect[11004].bWideRange and not GameData.ItemTemp[11004].ATK_Count)
assert(GameData.ItemTemp[11004].ACT==6145 and GameData.AttackEffect[11004].iActionFX_ACT==6145)
local usedFX={}
for _,id in ipairs({11002,11003,11004,11005}) do
    local fx=assert(GameData.AttackEffect[id].iActionFX_ACT)
    assert(not usedFX[fx], 'challenge skills must use distinct FX')
    usedFX[fx]=true
end
if native then
    assert(GameData.ItemTemp[1645].ACT==6145 and GameData.ItemTemp[1645].AttackEffect==301)
    assert(GameData.AttackEffect[301].iActionFX_ACT==6145)
end
assert(GameData.ItemTemp[1649].ACT==6149 and GameData.AttackEffect[285].iActionFX_ACT==6149)
for k,v in pairs(GameData.AttackEffect[285]) do
    if k~='iAttackPoint' and k~='iActionFX_ACT' then
        assert(GameData.AttackEffect[11004][k]==v,'physical behavior changed: '..k)
    end
end
assert(GameData.ItemTemp[11005].AddHP==6000 and GameData.ItemTemp[11005].Area==nil)
assert(GameData.ItemTemp[11005].ATK_Count==2 and GameData.ItemTemp[11005].AddHP*2==12000)
assert(GameData.ItemTemp[11005].ACT==11005 and GameData.AttackEffect[11005].iActionFX_ACT==11005)
assert(GameData.ItemTemp[1683].AddHP==300 and GameData.AttackEffect[285].iAttackPoint==600)
assert(GameData.ItemTemp[11001].Skills[3]==11004 and GameData.ItemTemp[11001].CR_Skills[1]==11005)
-- A conflict must fail before partial registration, in either namespace.
for _,namespace in ipairs({'ItemTemp','AttackEffect'}) do
  for _,occupied in ipairs({11003,11004,11005}) do
    fresh(); local foreign={}; GameData[namespace][occupied]=foreign
    assert(not pcall(load,'CaiDemonChallengeData.lua'))
    assert(GameData[namespace][occupied]==foreign)
    assert(GameData.ItemTemp[11001]==nil and GameData.ItemTemp[11002]==nil)
    assert(GameData.AttackEffect[11002]==nil)
  end
end
print('PASS: private skills preserve native effects, scope and atomic conflict handling')
