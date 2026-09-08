local root=arg[1]
SWD3CaiDemonKing={}; Const={AI_ATTACK=1,AI_SKILL=2}
assert(loadfile(root..'/src/data/CaiDemonAI.lua'))()
local AI=SWD3CaiDemonKing.CombatAI
local function low(a,b) return a end
local function high(a,b) return b end
local m={}
assert(AI.Plan(m,80000,80000,true,high)==0)
assert(AI.Plan(m,48001,80000,true,high)==11003 and m.phase==1)
assert(AI.Plan(m,48001,80000,true,high)==11002,'area removed, weights renormalised')
assert(AI.Plan(m,48000,80000,true,high)==11004 and m.phase==2)
assert(AI.Plan(m,80000,80000,true,high)==11003,'phase and cycle do not reset when HP rises')
assert(AI.Plan(m,36001,80000,true,high)==0 and not m.healUsed)
assert(AI.Plan(m,36000,80000,true,high)==11005 and m.healUsed)
for i=1,40 do assert(AI.Plan(m,1,80000,true,high)~=11005) end
assert(AI.Plan({},0,80000,true,high)==nil,'no post-death healing')
m={opened=true,lastOffensive=11003}
assert(AI.Plan(m,35000,80000,false,low)==0 and not m.healUsed,'seal defers heal')
m.lastOffensive=11003
assert(AI.Plan(m,35000,80000,true,high)==11005)
assert(m.lastOffensive==11003,'heal does not reset area restriction')
assert(AI.Plan(m,35000,80000,true,high)==11004)
-- Exhaustively verify actual pool boundaries, not statistical samples.
for phase=1,1 do
    local counts={}
    for draw=1,100 do
        local chosen=AI.Plan({opened=true,phase=phase,healUsed=true},70000,80000,true,function() return draw end)
        counts[chosen]=(counts[chosen] or 0)+1
    end
    assert(counts[0]==(phase==1 and 20 or 10))
    assert(counts[11002]==(phase==1 and 45 or 25))
    assert(counts[11003]==35 and counts[11004]==(phase==2 and 30 or nil))
end
local cycle={11004,11003,0,11002}
m={opened=true,phase=2,healUsed=true}
for i=1,40 do assert(AI.Plan(m,10000,80000,true,low)==cycle[(i-1)%4+1]) end
m={opened=true,phase=2}
assert(AI.Plan(m,40000,80000,true,low)==11004)
assert(AI.Plan(m,35000,80000,true,low)==11005)
assert(AI.Plan(m,35000,80000,true,low)==11003,'heal preserves pressure position')
assert(AI.Plan(m,35000,80000,false,low)==0)
assert(AI.Plan(m,35000,80000,true,low)==0,'seal does not skip the lighter selection')
local actor={}
local data={self=actor,status={HP=80000,MaxHP=80000}}
local function player(hp,hidden,dead)
    return {isPlayer=true,status={HP=hp},self={isHide=function() return hidden end,isDeath=function() return dead end}}
end
local players={[1]=player(0,false,true),[2]=player(100,true,false),[3]=player(100,false,false),
    [4]={isKeeper=true,status={HP=100},self={}}}
m={}
assert(AI.Select(m,data,7,players,low)==0 and actor.AI_Target==3 and actor.AI_TargetIsEnemySide)
data.status.HP=35000
assert(AI.Select(m,data,7,players,low)==11005)
assert(actor.AI_Target==7 and not actor.AI_TargetIsEnemySide and actor.RestorHP==6000)
AI.Select(m,data,7,players,low); assert(actor.RestorHP==0)
players[3].status.HP=0; m={}
assert(AI.Select(m,data,7,players,low)==nil and not m.opened and actor.AI_Command==-1)
players[3].status.HP=100
actor.IsCrazy=function() return true end; actor.AI_Command=1
assert(AI.Select(m,data,7,players,low)==nil and not m.opened and actor.AI_Command==1)
actor.IsCrazy=nil; actor.IsFreeze=function() return true end
assert(AI.Select(m,data,7,players,low)==nil and actor.AI_Command==-1 and not m.healUsed)
actor.IsFreeze=nil
players[1]=player(100,false,false)
m={opened=true,phase=2,healUsed=true}
AI.Select(m,data,7,players,low);assert(actor.AI_Target==1,'physical target')
AI.Select(m,data,7,players,low);AI.Select(m,data,7,players,low)
AI.Select(m,data,7,players,low);assert(actor.AI_SelectItem==11002 and actor.AI_Target==3,'light does not refocus last physical target')
print('PASS: phase boundaries, exact pools, pressure cycle, once-only heal, valid targets, status and no revival')

-- No random sequence can postpone phase-one physical pressure indefinitely.
for _,random in ipairs({low,high}) do
    m={}
    assert(AI.Plan(m,80000,80000,true,random)==0)
    for cycleIndex=1,20 do
        for slot=1,3 do assert(AI.Plan(m,80000,80000,true,random)~=11004) end
        assert(AI.Plan(m,80000,80000,true,random)==11004,'bounded phase-one heavy')
        assert(AI.Plan(m,80000,80000,true,random)==0,'mandatory lighter follow-up')
    end
end
m={opened=true,earlyStep=3}
assert(AI.Plan(m,80000,80000,false,high)==0 and m.earlyStep==3,'seal does not advance heavy counter')
assert(AI.Plan(m,80000,80000,true,high)==11004)
assert(AI.Plan(m,35000,80000,true,high)==11005,'heal still only once at threshold')
assert(m.earlyRecovery and m.phase==2,'phase change and heal preserve recovery')
assert(AI.Plan(m,35000,80000,false,high)==0 and m.earlyRecovery)
assert(AI.Plan(m,35000,80000,true,high)==0,'no consecutive heavy on phase transition')
assert(AI.Plan(m,35000,80000,true,high)==11004,'normal phase-two cycle resumes')
local another={opened=true}
assert(AI.Plan(another,80000,80000,true,high)==11003 and another.earlyStep==1,'separate enemy clock')
print('PASS: bounded early physical pressure, recovery, phase transition, seal, heal and independent clocks')
