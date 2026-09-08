local MOD=assert(SWD3LiveCardBattle)
local FIELD='MOD_CARD_CHALLENGE'
if MOD.Inventory then return end
local I={}
MOD.Inventory=I
local session
local unpackValues=table.unpack or unpack
local function pack(...) return {n=select('#',...),...} end
local function count(id)
    local total=0
    for _,item in pairs(SaveData and SaveData.Items or {}) do
        if item.ItemTempID==id then total=total+(item.Count or 0)+(item.Count_New or 0) end
    end
    return total
end
local function current(s)
    return s and s.save==SaveData and s.items==SaveData.Items
end
local function tracking()
    return current(session) and session.tracking and session.ignore==0
        and GameFunc.GetBattleFieldID()==FIELD
end
local function observe(id,fn,...)
    local s=tracking() and session
    if not s or not id or id<=0 then return fn(...) end
    local before=count(id)
    local result=pack(pcall(fn,...))
    local lost=math.max(0,before-count(id))
    if current(s) and session==s and lost>0 then
        s.spent[id]=(s.spent[id] or 0)+lost
        s.write('challenge item spent: Item'..id..' x'..lost)
    end
    if not result[1] then error(result[2],0) end
    return unpackValues(result,2,result.n)
end
function I.WithoutRefund(fn,...)
    local s=session
    if not s then return fn(...) end
    s.ignore=s.ignore+1
    local result=pack(pcall(fn,...))
    s.ignore=s.ignore-1
    if not result[1] then error(result[2],0) end
    return unpackValues(result,2,result.n)
end
function I.Held(id)
    return current(session) and (session.spent[id] or 0) or 0
end
function I.Restore(reason,discard)
    local s=session
    if not s then return true end
    if discard or not current(s) then session=nil;return true end
    s.tracking=false
    local failed=false
    local ids={}
    for id,n in pairs(s.spent) do if n>0 then ids[#ids+1]=id end end
    table.sort(ids)
    for _,id in ipairs(ids) do
        local n=s.spent[id]
        local before=count(id)
        -- Restore quantities through the native inventory helper, retaining loot.
        local ok,err=pcall(ItemClass.AddItem,id,n,0,false)
        local added=math.max(0,count(id)-before)
        s.spent[id]=math.max(0,n-added)
        if added>0 then s.write('challenge item refunded: Item'..id..' x'..added..'; '..reason) end
        if not ok or s.spent[id]>0 then
            failed=true
            s.write('item refund incomplete: Item'..id..'; remaining='..s.spent[id]..'; '..tostring(err))
        end
    end
    if not failed then
        session=nil
        s.write('challenge items restored: '..reason)
    end
    return not failed
end
function I.Install()
    if I.installed then return end
    assert(ItemClass and type(ItemClass.AddItem)=='function' and type(ItemClass.DelItem)=='function',
        'native inventory helpers unavailable')
    OnEvent.Battle_RestoreItem=OnEvent.Battle_RestoreItem or {}
    local previous=OnEvent.Battle_RestoreItem.main
    assert(type(previous)=='function','native restore handler unavailable')
    local add,del=ItemClass.AddItem,ItemClass.DelItem
    ItemClass.AddItem=function(id,n,...)
        if type(n)=='number' and n<0 then return observe(id,add,id,n,...) end
        return add(id,n,...)
    end
    ItemClass.DelItem=function(slot,id,n,...)
        local item=SaveData and SaveData.Items and SaveData.Items[slot]
        local actual=(item and (not id or id<=0 or item.ItemTempID==id)) and item.ItemTempID or id
        return observe(actual,del,slot,id,n,...)
    end
    OnEvent.Battle_RestoreItem.main=function(...)
        if current(session) then session.tracking=false end
        local result=pack(previous(...))
        -- Before appended capture-exchange/reward handlers; native Stock is cleared.
        I.Restore('native battle settlement')
        return unpackValues(result,1,result.n)
    end
    I.installed=true
end
function I.Begin(write)
    assert(I.Restore('before next challenge'),'previous item refund incomplete')
    I.Install()
    session={save=SaveData,items=assert(SaveData.Items),tracking=true,ignore=0,spent={},write=write}
    write('challenge item refunds armed; costs remain limited during battle')
end
