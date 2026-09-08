local MOD=assert(SWD3CaiDemonKing)
local AI={}
MOD.CombatAI=AI

-- Plans one native AI selection, not a completed action or a player turn.
function AI.Plan(memory,hp,maxHP,canSkill,rng)
    if hp<=0 or maxHP<=0 then return nil end
    if hp*100<=maxHP*60 then memory.phase=2 end
    memory.phase=memory.phase or 1
    if not memory.opened then
        memory.opened=true; memory.lastOffensive=0
        return 0,'opening'
    end
    if canSkill and not memory.healUsed and hp*100<=maxHP*45 then
        -- Reserve once on selection. Interruptions do not grant another cast.
        memory.healUsed=true
        return 11005,'heal'
    end
    if not canSkill then memory.lastOffensive=0; return 0,'skill blocked' end
    -- Keep a lighter selection after the phase-one heavy strike, including
    -- a transition into phase two. A cure or seal does not consume this slot.
    if memory.earlyRecovery then
        memory.earlyRecovery=false;memory.lastOffensive=0
        return 0,'early heavy recovery'
    end
    if memory.phase==2 then
        -- A pressure pair followed by a lighter attack. This counts native
        -- selections only; it does not promise a fixed number of player turns.
        local cycle={11004,11003,0,11002}
        memory.cycle=(memory.cycle or 0)%#cycle+1
        local skill=cycle[memory.cycle]
        memory.lastOffensive=skill
        return skill,'pressure cycle '..memory.cycle
    end
    -- High light/dark resistance must not leave phase one spell-only forever.
    -- Opening and recovery are separate; only eligible pool selections count.
    memory.earlyStep=(memory.earlyStep or 0)+1
    if memory.earlyStep==4 then
        memory.earlyStep=0;memory.earlyRecovery=true;memory.lastOffensive=11004
        return 11004,'early heavy strike'
    end
    local pool={{0,20},{11002,45},{11003,35}}
    local total=0
    for _,row in ipairs(pool) do
        if row[1]~=11003 or memory.lastOffensive~=11003 then total=total+row[2] end
    end
    local draw=rng(1,total)
    assert(type(draw)=='number' and draw>=1 and draw<=total,'invalid random result')
    for _,row in ipairs(pool) do
        if row[1]~=11003 or memory.lastOffensive~=11003 then
            draw=draw-row[2]
            if draw<=0 then
                memory.lastOffensive=row[1]
                return row[1],'phase '..memory.phase
            end
        end
    end
end

function AI.Select(memory,data,index,players,rng)
    local actor=data.self
    local status=data.status or actor.NPCData
    assert(status and type(status.HP)=='number' and type(status.MaxHP)=='number',
        'enemy HP/MaxHP unavailable')
    if status.HP<=0 then actor.AI_Command=-1; actor.RestorHP=0; return nil end
    -- Keep the native crazy/immobilised path; do not grant status immunity.
    if type(actor.IsCrazy)=='function' and actor.IsCrazy(actor) then return nil end
    if type(actor.IsFreeze)=='function' and actor.IsFreeze(actor) then
        actor.AI_Command=-1; actor.RestorHP=0; return nil
    end
    local targets={}
    for i,p in pairs(players or {}) do
        if p and p.isPlayer and p.status and type(p.status.HP)=='number' and p.status.HP>0
            and p.self and type(p.self.isHide)=='function' and not p.self.isHide(p.self)
            and type(p.self.isDeath)=='function' and not p.self.isDeath(p.self) then
            targets[#targets+1]=i
        end
    end
    table.sort(targets)
    actor.RestorHP=0 -- discard any native cure selection before applying our plan
    if #targets==0 then actor.AI_Command=-1; return nil end
    -- Native command execution remains responsible for states not exposed here.
    local readable,state=pcall(function() return tonumber(status.State) end)
    if not readable then state=nil end
    local canSkill=not state or math.floor(state/16)%2==0
    local skill,reason=AI.Plan(memory,status.HP,status.MaxHP,canSkill,rng or math.random)
    if skill==nil then actor.AI_Command=-1; return nil end
    actor.AI_SelectAttackEffect=0
    actor.AI_SelectItem=skill
    actor.AI_Command=skill==0 and Const.AI_ATTACK or Const.AI_SKILL
    actor.Action_qq=skill==0 and 40 or 44
    if skill==11005 then
        actor.AI_TargetIsEnemySide=false
        actor.AI_Target=index
        actor.RestorHP=6000 -- per pulse; ACT11005 has two cure events, total 12000
    else
        actor.AI_TargetIsEnemySide=true
        local choices=targets
        if skill==11002 and memory.lastHeavyTarget and #targets>1 then
            choices={}
            for _,target in ipairs(targets) do
                if target~=memory.lastHeavyTarget then choices[#choices+1]=target end
            end
        end
        actor.AI_Target=choices[(rng or math.random)(1,#choices)]
        if skill==11004 then memory.lastHeavyTarget=actor.AI_Target end
    end
    -- Native weights/counts are irrelevant to our pool; other enemies retain theirs.
    data.AttackCount=skill==0 and (data.AttackCount or 0)+1 or 0
    return skill,reason
end
