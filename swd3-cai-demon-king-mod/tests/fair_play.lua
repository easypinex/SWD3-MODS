local root,native=assert(arg[1]),assert(arg[2])
local function eq(a,b,label) assert(a==b,(label or '')..': '..tostring(a)..' ~= '..tostring(b)) end
GameData={};Const={};Function={};OnEvent={};BattleEnv={}
SWD3CaiDemonKing={state={active=true}}
dofile(root..'/src/data/CaiFairPlay.lua')
local F=SWD3CaiDemonKing.FairPlay
for key,limit in pairs(F.limits) do
    local state={active=true}
    F.Entry(state,{isPlayer=true,CharData={[key]=limit}},1)
    eq(state.fairBlocked,nil,'inclusive entry limit '..key)
    F.Entry(state,{isPlayer=true,CharData={[key]=limit+1}},1)
    eq(state.fairBlocked,'stats',key)
end
local state={active=true}
F.Entry(state,{isPlayer=false,CharData={MaxHP=99999,ATK=2000}},5)
eq(state.fairBlocked,nil,'reward keeper excluded')
F.Entry(state,{isPlayer=true,CharData={MaxHP=5800,MaxMP=1400,MaxSP=1500,Level=60}},1)
eq(state.fairBlocked,nil,'accepted test party')
F.Flag(state,'rules','first');F.Flag(state,'items','second')
eq(state.fairBlocked,'rules','sticky verdict')
eq(state.victoryRequested,false);eq(state.victoryProved,false)

for _,name in ipairs({'GameData_ItemData','GameData_BattleCharData','GameData_SkillData','GameData_AttackEffect'}) do
    dofile(native..'/'..name..'.lua')
end
log=function() end
Scene={ACH_17=function() end,ACH_18_2=function() end}
GameData.CatalogueLabel={[13]={},[14]={}}
dofile(native..'/ItemsClass.lua');ItemClass.ItemsClear()
dofile(native..'/OnEvent_Battle.lua')
local field='CDK_CAI_CHALLENGE'
GameFunc={GetBattleFieldID=function() return field end}
local originalDel=ItemClass.DelItem
local frozen=false
ItemClass.DelItem=function(...)
    if frozen then return 0,'kept return value' end
    return originalDel(...)
end
dofile(root..'/src/data/CaiInventory.lua')
local I=SWD3CaiDemonKing.Inventory
local function count(id)
    for _,item in ipairs(SaveData.Items) do
        if item.ItemTempID==id then return item.Count+item.Count_New end
    end
    return 0
end
local function begin()
    SWD3CaiDemonKing.state={active=true}
    I.Begin(log)
    return SWD3CaiDemonKing.state
end
ItemClass.AddItem(632,3,0,false)
state=begin()
ItemClass.DelItem(1,632,1,0);eq(count(632),2)
ItemClass.AddItem(632,1,0,false)
SaveData.Items[1].Stock=1 -- reservation is not a quantity change
I.CheckBalance();eq(state.fairBlocked,nil,'native spending/gain/Stock legal')
I.Restore('exit');eq(count(632),4,'only real debit refunded')
state=begin();frozen=true
local a,b=ItemClass.DelItem(1,632,1,0)
eq(a,0);eq(b,'kept return value','native returns preserved')
eq(state.fairBlocked,'items','frozen successful debit rejected')
I.Restore('invalid');eq(count(632),4,'no phantom refund')
frozen=false;state=begin()
SaveData.Items[1].Count=SaveData.Items[1].Count+1
I.CheckBalance();eq(state.fairBlocked,'items','direct inventory injection')
I.Restore('invalid')
state=begin();ItemClass.DelItem(1,632,0,0);I.CheckBalance()
eq(state.fairBlocked,nil,'zero guardian cleanup')
I.WithoutRefund(ItemClass.DelItem,1,632,1,0);I.CheckBalance()
eq(state.fairBlocked,nil,'declared exclusion')
I.Restore('exit')
state=begin();field='BS1'
SaveData.Items[1].Count=SaveData.Items[1].Count+1;I.CheckBalance()
eq(state.fairBlocked,nil,'other battle untouched')
I.Restore('exit');field='CDK_CAI_CHALLENGE'
state=begin()
assert(F.Check(state,function() return true end,{{isPlayer=true,status={HP=500,MP=500}}}))
assert(F.Check(state,function() return true end,{{isPlayer=true,status={HP=500,MP=500}}}))
eq(state.fairBlocked,nil,'unchanged HP/MP is not proof of locks')
assert(not F.Check(state,function() return false end,{}));eq(state.fairBlocked,'rules')
I.Restore('exit')
state=begin();assert(not F.Check(state,function() return true end,{{isPlayer=true,status={MP=0/0}}}))
eq(state.fairBlocked,'values');I.Restore('exit')
print('PASS: fair-play caps, native item accounting, frozen debits, no false lock verdict, refund and isolation')
