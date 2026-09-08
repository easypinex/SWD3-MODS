SWD3CaiDemonKing = SWD3CaiDemonKing or {}
if SWD3CaiDemonKing.PartyState then return end
-- HD 4.0.5: see Cai TESTING party-state evidence. No save keys.
local P = {}
local session
local fields = {'HP','MP','SP','State'}
local function number(value)
    return type(value)=='number' and value==value and value~=math.huge and value~=-math.huge
end
function P.Pending() return session~=nil end
function P.Restore(reason,discard)
    local s=session
    if not s then return true end
    if discard or s.save~=SaveData then
        session=nil
        return true
    end
    local failed=false
    for index,row in pairs(s.rows) do
        local ok,err=pcall(function()
            for _,key in ipairs(fields) do row.status[key]=row.values[key] end
            if row.skill then row.skill.Energy=row.energy end
            for _,key in ipairs(fields) do
                assert(row.status[key]==row.values[key], 'restore readback '..key)
            end
            if row.skill then assert(row.skill.Energy==row.energy,'restore energy readback') end
        end)
        if ok then
            s.write('party restored: index='..index..'; HP='..row.values.HP..'; MP='..row.values.MP
                ..'; SP='..row.values.SP..'; State='..row.values.State..'; reason='..reason)
            s.rows[index]=nil
        else
            failed=true; s.write('party restore failed: '..tostring(err))
        end
    end
    if not failed then session=nil end
    return not failed
end
function P.Begin(write)
    assert(P.Restore('before next challenge'),'previous party restore incomplete')
    session={save=SaveData,rows={},write=write}
end
function P.Init(index)
    local s=assert(session,'party session missing')
    if s.rows[index] then return end -- duplicate init never replaces baseline
    local actor=assert(BattlePlayers and BattlePlayers[index],'player unavailable')
    assert(actor.isPlayer==true,'not a protagonist')
    local status=assert(actor.CharData,'CharData unavailable')
    local row={status=status,values={},actor=actor}
    for _,key in ipairs(fields) do
        local value=status[key]; assert(number(value),'invalid '..key)
        row.values[key]=value
    end
    for _,key in ipairs({'MaxHP','MaxMP','MaxSP'}) do
        assert(number(status[key]) and status[key]>=0,'invalid '..key)
    end
    assert(status.MaxHP>0,'invalid MaxHP')
    assert(type(actor.ReleaseEffect)=='function','ReleaseEffect unavailable')
    row.skill=actor.SKData
    if row.skill then
        row.energy=row.skill.Energy
        assert(number(row.energy),'invalid skill energy')
    end
    s.rows[index]=row -- retain baseline before any mutation, including a failed heal
    status.HP=status.MaxHP; status.MP=status.MaxMP; status.SP=status.MaxSP
    -- ReleaseEffect(0x8000) revives the native actor and updates the death count.
    -- Setting HP alone leaves a dead actor without a valid target.
    actor.ReleaseEffect(actor,32768)
    status.State=0
    assert(not actor.isDeath(actor),'native resurrection failed')
    s.write('party prepared: index='..index..'; before HP='..row.values.HP..'; MP='..row.values.MP
        ..'; SP='..row.values.SP..'; State='..row.values.State)
end
function P.Enter()
    local s=assert(session,'party session missing')
    assert(next(s.rows)~=nil,'party initialization was not observed')
    for index,row in pairs(s.rows) do
        local actor,status=row.actor,row.status
        -- Clear each effect separately; death has its own native branch.
        for bit=0,14 do actor.ReleaseEffect(actor,2^bit) end
        status.State=0
        status.HP=status.MaxHP; status.MP=status.MaxMP; status.SP=status.MaxSP
        -- Native SpecialSkill Energy is 0..56 (SetSKEnergy(-1) uses 56).
        if row.skill then row.skill.Energy=56 end
        assert(status.HP==status.MaxHP and status.MP==status.MaxMP and status.SP==status.MaxSP
            and status.State==0 and not actor.isDeath(actor),'party entry readback failed')
        s.write('party full: index='..index..'; HP='..status.HP..'/'..status.MaxHP
            ..'; MP='..status.MP..'/'..status.MaxMP..'; SP='..status.SP..'/'..status.MaxSP
            ..'; State='..status.State..'; Energy='..tostring(row.skill and row.skill.Energy))
    end
end
SWD3CaiDemonKing.PartyState=P
