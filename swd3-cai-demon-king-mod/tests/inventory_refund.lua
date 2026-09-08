local root,native,live=assert(arg[1]),assert(arg[2]),assert(arg[3])
local function eq(a,b,label) assert(a==b,(label or '')..': '..tostring(a)..' ~= '..tostring(b)) end
local function count(id)
    local n=0
    for _,item in ipairs(SaveData.Items) do if item.ItemTempID==id then n=n+item.Count+item.Count_New end end
    return n
end
local function slot(id)
    for i,item in ipairs(SaveData.Items) do if item.ItemTempID==id then return i end end
end
local field
local function fixture(reverse)
    GameData={};Const={};Function={};OnEvent={};BattleEnv={}
    SWD3CaiDemonKing=nil;SWD3LiveCardBattle={}
    for _,name in ipairs({'GameData_ItemData','GameData_BattleCharData','GameData_SkillData','GameData_AttackEffect'}) do
        dofile(native..'/'..name..'.lua')
    end
    log=function() end
    Scene={ACH_17=function() end,ACH_18_2=function() end}
    GameData.CatalogueLabel={[13]={},[14]={}}
    dofile(native..'/ItemsClass.lua');ItemClass.ItemsClear()
    dofile(native..'/OnEvent_Battle.lua')
    for _,name in ipairs({'CaiDemonActions','CaiDemonData','CaiDemonChallengeData','CaiReward','CaiInventory'}) do
        dofile(root..'/src/data/'..name..'.lua')
    end
    dofile(live..'/src/data/LiveCardInventory.lua')
    GameFunc={GetBattleFieldID=function() return field end}
    field=nil
    local a,b=SWD3CaiDemonKing.Inventory,SWD3LiveCardBattle.Inventory
    local first,second=reverse and b or a,reverse and a or b
    first.Begin(log);first.Restore('warmup');second.Begin(log);second.Restore('warmup')
    return a,b
end
for _,reverse in ipairs({false,true}) do
    for _,owner in ipairs({'cai','live'}) do
        local a,b=fixture(reverse)
        local I=owner=='cai' and a or b
        field=owner=='cai' and 'CDK_CAI_CHALLENGE' or 'MOD_CARD_CHALLENGE'
        ItemClass.AddItem(632,3,0,false);ItemClass.AddItem(178,2,0,false)
        SaveData.Items[slot(178)].Stock=1
        I.Begin(log)
        ItemClass.DelItem(slot(632),632,3,0)
        eq(count(632),0,'no free refill in battle')
        ItemClass.DelItem(slot(178),0,1,0)
        eq(count(178),1,'keeper death charged during battle')
        ItemClass.DelItem(slot(178),178,0,0)
        eq(I.Held(178),1,'zero cleanup never creates a refund')
        ItemClass.AddItem(632,2,0,false) -- same-ID reward must survive refund
        ItemClass.AddItem(11006,1,0,false)
        -- Captured source cleanup is not battle consumption.
        ItemClass.AddItem(178,1,0,false)
        I.WithoutRefund(ItemClass.DelItem,slot(178),178,1,0)
        OnEvent.Battle_RestoreItem.main()
        eq(count(632),5,'spent supply plus same-ID loot')
        eq(count(178),2,'only spent keeper returned')
        eq(SaveData.Items[slot(178)].Stock,nil,'native reservation cleanup retained')
        eq(count(11006),1,'new reward retained')
        -- Appended capture exchange after native main is never tracked.
        ItemClass.DelItem(slot(178),178,1,0)
        I.Restore('duplicate');OnEvent.Battle_RestoreItem.main()
        eq(count(178),1,'post-settlement removal never refunded')
        I.Begin(log);ItemClass.AddItem(632,-1,0,false)
        eq(I.Held(632),1,'negative native AddItem tracked')
        I.Restore('defeat');eq(count(632),5)
        I.Begin(log);field='BS34';ItemClass.DelItem(slot(632),632,1,0)
        I.Restore('other field');eq(count(632),4,'ordinary battles unchanged')
        field=owner=='cai' and 'CDK_CAI_CHALLENGE' or 'MOD_CARD_CHALLENGE'
        I.Begin(log);ItemClass.DelItem(slot(632),632,1,0)
        local old=SaveData;SaveData={Items={{ItemTempID=632,Count=1,Count_New=0}}}
        I.Restore('different save');eq(count(632),1,'old debt cannot cross saves')
        SaveData=old
        I.Begin(log);ItemClass.DelItem(slot(632),632,1,0)
        I.Restore('game start',true);eq(count(632),2,'discard does not credit a new game')
        -- Partial add then throw: retry only the unfulfilled remainder.
        I.Begin(log);ItemClass.DelItem(slot(632),632,2,0)
        local add=ItemClass.AddItem
        ItemClass.AddItem=function(id,n,...) add(id,1,...);error('partial refund') end
        eq(I.Restore('first attempt'),false);eq(count(632),1);eq(I.Held(632),1)
        ItemClass.AddItem=add
        eq(I.Restore('retry'),true);eq(count(632),2)
        eq(I.Restore('retry again'),true);eq(count(632),2)
        -- Wrapper preserves nil values and original error propagation.
        local x,y,z=I.WithoutRefund(function() return 9,nil,12 end)
        eq(x,9);eq(y,nil);eq(z,12)
        eq(pcall(I.WithoutRefund,function() error('expected') end),false)
    end
end
local a=fixture(false)
field='CDK_CAI_CHALLENGE'
ItemClass.AddItem(11006,1,0,false);a.Begin(log)
ItemClass.DelItem(slot(11006),11006,1,0)
eq(SWD3CaiDemonKing.Reward.Count(),1,'spent reward keeper still owned before refund')
local state={victoryRequested=true,victoryProved=true,outcome='victory'}
ItemFunc={AddItem=function() error('must not grant a second reward') end}
eq(SWD3CaiDemonKing.Reward.Settle(state,log),false)
OnEvent.Battle_RestoreItem.main();eq(count(11006),1)
print('PASS: inventory refunds, native item helpers, same-ID rewards, keeper costs, capture exclusion, both load orders, failure retries and save isolation')
