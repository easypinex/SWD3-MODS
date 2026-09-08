local MOD=assert(SWD3CaiDemonKing)
local R={ID=11006}
MOD.Reward=R
local function copy(value)
    if type(value)~='table' then return value end
    local result={}
    for key,child in pairs(value) do result[key]=copy(child) end
    return result
end
if MOD.rewardTemplate then
    assert(GameData.ItemTemp[R.ID]==MOD.rewardTemplate,'Cai reward replaced')
else
    assert(GameData.ItemTemp[R.ID]==nil,'ItemTemp11006 conflict')
    local card=copy(assert(GameData.ItemTemp[101],'native living card missing'))
    for key,value in pairs(assert(MOD.challengeTemplate)) do card[key]=copy(value) end
    card.Name='CDK_REWARD_NAME';card.HelpText='CDK_REWARD_HELP';card.InfoText='CDK_REWARD_HELP'
    card.IT_06=nil;card.IT_12=true;card.isBattleChar=true;card.NotInBook=true
    card.User_01=true;card.User_02=true;card.User_03=true;card.User_04=true
    card.Cons_SP=true;card.Cons_MP=nil;card.Cons_Item=nil;card.Consumption=280;card.UsePlace=1
    card.HP=99999;card.ATK=2000;card.DEF=1600;card.SPD=240;card.WIS=600
    card.AddHP=1000;card.AddMP=350;card.AddSP=350;card.AddSTR=80;card.AddStamina=60
    card.AddWIS=80;card.AddSPD=35;card.AddATK=120;card.AddDEF=120
    -- Native KeeperAI does not bound CR healing by a positive remaining count.
    card.CR_Skills=nil;card.CR_SkillsCount=nil;card.CR_Skills_QQ=nil
    card.DropItems=nil;card.DropItemsCount=nil;card.DropItemsRate=nil;card.GainEXP=0;card.GainGold=0
    for _,key in ipairs({'AttrDark','AttrLight','AttrFire','AttrIce','AttrEarth',
        'AttrWind','AttrThunder','AttrTunder','AttrPhysical','AttrPoison'}) do card[key]=nil end
    GameData.ItemTemp[R.ID]=card;MOD.rewardTemplate=card
end
function R.Count()
    -- A spent reward keeper still belongs to the player until its refund settles.
    local total=MOD.Inventory and MOD.Inventory.Held(R.ID) or 0
    for _,item in ipairs(SaveData and SaveData.Items or {}) do
        if item.ItemTempID==R.ID then
            -- Stock is a reservation, still owned. Never grant around that lock.
            total=total+(item.Count or 0)+(item.Count_New or 0)
        end
    end
    for _,equipment in pairs(SaveData and SaveData.PlayerEqu or {}) do
        for _,item in pairs(equipment) do
            if item.ItemTempID==R.ID then total=total+1 end
        end
    end
    return total
end
function R.Settle(state,write)
    if state.rewardsAllowed==false then return false end
    if not state.victoryRequested or not state.victoryProved or state.outcome~='victory'
        or state.breakRequested or state.rewardAttempted or state.fairBlocked then return false end
    state.rewardAttempted=true
    if R.Count()>0 then write('reward already owned; no duplicate');return false end
    local ok,err=pcall(function()
        assert(GameData.ItemTemp[R.ID]==MOD.rewardTemplate,'reward template changed')
        ItemFunc.AddItem(R.ID,1)
        assert(R.Count()>0,'native grant not confirmed')
    end)
    if ok then R.pendingReceipt={save=SaveData,id=R.ID,count=1} end
    write(ok and 'reward confirmed: Item11006 x1' or 'reward failed: '..tostring(err))
    return ok
end
function R.PendingReceipt()
    local receipt=R.pendingReceipt
    if receipt and (receipt.save~=SaveData or R.Count()<=0) then
        R.pendingReceipt=nil
        return nil
    end
    return receipt
end
function R.ClearReceipt() R.pendingReceipt=nil end
