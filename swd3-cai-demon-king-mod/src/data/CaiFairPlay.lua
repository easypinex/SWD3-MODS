local MOD=assert(SWD3CaiDemonKing)
local F={}
MOD.FairPlay=F
-- Admission rules, not proof of a trainer: legitimate unlimited stat farming
-- can also exceed these generous protagonist-only challenge limits.
F.limits={Level=99,MaxHP=30000,MaxMP=10000,MaxSP=10000,ATK=5000,DEF=5000,WIS=3000,SPD=500}
local function finite(value)
    return type(value)=='number' and value==value and value~=math.huge and value~=-math.huge
end
local function read(object,key)
    local ok,value=pcall(function() return object[key] end)
    return ok and value or nil
end
function F.Flag(state,kind,detail,write)
    if not state or not state.active or state.fairBlocked then return end
    state.fairBlocked=kind;state.fairDetail=detail
    state.victoryRequested=false;state.victoryProved=false;state.outcome='invalid'
    if write then write('fair-play rejected: '..kind..'; '..tostring(detail)) end
end
function F.Entry(state,actor,index,write)
    if not actor or actor.isPlayer~=true then return end
    local status=actor.CharData
    if not status then return end
    for _,key in ipairs({'Level','MaxHP','MaxMP','MaxSP','ATK','DEF','WIS','SPD'}) do
        local value=read(status,key)
        -- Unexposed fields are not evidence of cheating.
        if value~=nil and (not finite(value) or value>F.limits[key]) then
            F.Flag(state,'stats','player='..index..'; '..key..'='..tostring(value)..'; limit='..F.limits[key],write)
            return
        end
    end
end
function F.Check(state,ready,players,write)
    if state.fairBlocked then return false end
    local ok,valid=pcall(ready)
    if not ok or not valid then F.Flag(state,'rules','owned challenge definitions changed',write);return false end
    for index,p in pairs(players or {}) do
        if p and p.isPlayer and p.status then
            for _,key in ipairs({'HP','MP','SP','MaxHP','MaxMP','MaxSP'}) do
                local value=read(p.status,key)
                if value~=nil and not finite(value) then
                    F.Flag(state,'values','player='..index..'; invalid '..key,write);return false
                end
            end
        end
    end
    if MOD.Inventory.CheckBalance then
        local checked,err=pcall(MOD.Inventory.CheckBalance)
        if not checked then F.Flag(state,'items','quantity check failed: '..tostring(err),write) end
    end
    return not state.fairBlocked
end
F.lines={
    stats='CDK_FAIR_STATS',items='CDK_FAIR_ITEMS',rules='CDK_FAIR_RULES',values='CDK_FAIR_VALUES',
}
