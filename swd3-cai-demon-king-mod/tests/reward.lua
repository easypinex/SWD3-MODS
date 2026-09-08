local project,native=assert(arg[1]),assert(arg[2])
GameData={};Const={};SWD3CaiDemonKing=nil;log=function(s) if s:find('reward failed',1,true) then print(s) end end
for _,name in ipairs({'GameData_ItemData','GameData_BattleCharData','GameData_SkillData','GameData_AttackEffect'}) do
    dofile(native..'/'..name..'.lua')
end
local function load(name) dofile(project..'/src/data/'..name..'.lua') end
load('CaiDemonActions');load('CaiDemonData');load('CaiDemonChallengeData');load('CaiReward')
local M=SWD3CaiDemonKing;local R=M.Reward;local card=GameData.ItemTemp[R.ID]
assert(card.IT_12 and not card.IT_06 and card.isBattleChar and card.Cons_SP and card.Consumption==280)
assert(card.HP==99999 and card.Level==99 and card.ATK==2000 and card.DEF==1600)
assert(card.CR_Skills==nil and card.CR_SkillsCount==nil,'no unbounded enemy healing on reward')
assert(card.Skills~=M.challengeTemplate.Skills and card.SkillsCount~=M.challengeTemplate.SkillsCount)
assert(card.Skills[1]==11002 and card.Skills[3]==11004 and card.ACT==438)
card.SkillsCount[1]=0;assert(M.challengeTemplate.SkillsCount[1]==2)
for i=1,4 do assert(card['User_0'..i]) end
Scene={ACH_17=function() end,ACH_18_2=function() end}
GameData.CatalogueLabel={[13]={},[14]={}} -- no achievement/UI integration in this mock
dofile(native..'/ItemsClass.lua');ItemClass.ItemsClear()
ItemFunc={AddItem=function(id,n) return ItemClass.AddItem(id,n,0,false) end}
local function win() return {victoryRequested=true,victoryProved=true,outcome='victory'} end
assert(R.Settle(win(),log));assert(R.Count()==1)
assert(R.PendingReceipt().save==SaveData and R.PendingReceipt().count==1)
R.ClearReceipt();assert(not R.PendingReceipt())
assert(not R.Settle(win(),log));assert(R.Count()==1)
assert(not R.PendingReceipt(),'owned reward must not show a new receipt')
local slot
for i,item in ipairs(SaveData.Items) do if item.ItemTempID==R.ID then slot=i end end
assert(slot)
ItemClass.DelItem(slot,0,1,0)
assert(R.Count()==0);assert(R.Settle(win(),log),'lost card can be earned again')
ItemClass.ItemsClear();ItemClass.NewEquip(R.ID,1,8)
assert(R.Count()==1 and not R.Settle(win(),log),'native equipped item counts without inventory')
ItemClass.ItemsClear();local state=win();ItemFunc.AddItem=function() error('inventory failure') end
R.ClearReceipt()
assert(not R.Settle(state,log));assert(R.Count()==0)
assert(not R.PendingReceipt(),'failed grant cannot announce receipt')
ItemFunc.AddItem=function(id,n) return ItemClass.AddItem(id,n,0,false) end
assert(not R.Settle(state,log),'no repeated attempt within same settlement')
assert(R.Settle(win(),log),'next victory retries after failure')
local grantedSave=SaveData; SaveData={Items={}}
assert(not R.PendingReceipt(),'receipt must not cross saves')
SaveData=grantedSave
load('CaiReward');assert(GameData.ItemTemp[R.ID]==card)
GameData.ItemTemp[R.ID]={};assert(not pcall(load,'CaiReward'),'conflict rejected')
print('PASS: reward native definitions, inventory/equipment lifecycle, failure retry and isolated skill arrays')
