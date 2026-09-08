local path,ns=arg[1],arg[2]
assert(loadfile(path))()
local P=_G[ns].PartyState
local function eq(a,b,msg) assert(a==b,(msg or '')..': '..tostring(a)..' ~= '..tostring(b)) end
local function fresh()
    SaveData={}; BattlePlayers={}
    for i=1,4 do
        local backing={HP=i==1 and 0 or i*10,MP=2*i,SP=i,State=i==1 and 32768 or 4,
            MaxHP=20000+i,MaxMP=300,MaxSP=400,Level=50,EXP=50}
        local status=setmetatable({}, {__index=backing,__newindex=function(_,k,v)
            assert(backing[k]~=nil,'no member named '..k); backing[k]=v
        end})
        local p={isPlayer=true,CharData=status,SKData={Energy=i},dead=i==1,effects={[4]=true}}
        p.isDeath=function(self) return self.dead end
        p.ReleaseEffect=function(self,mask)
            if mask==32768 then self.dead=false else self.effects[mask]=nil end
        end
        BattlePlayers[i]=p
    end
    P.Begin(function() end)
end
local function enter()
    for i=1,4 do P.Init(i) end
    P.Enter()
    for i=1,4 do
        local p=BattlePlayers[i]
        eq(p.CharData.HP,p.CharData.MaxHP,'full HP >9999')
        eq(p.CharData.MP,300); eq(p.CharData.SP,400); eq(p.CharData.State,0)
        eq(p.SKData.Energy,56); eq(p.dead,false); eq(p.effects[4],nil)
    end
end
for _,reason in ipairs({'victory','defeat','escape','map loading','start failure','inventory recovery'}) do
    fresh(); enter()
    for i=1,4 do
        local p=BattlePlayers[i]; p.CharData.HP=0; p.CharData.MP=0; p.CharData.State=32768
        p.SKData.Energy=0; p.CharData.Level=51; p.CharData.EXP=77
        P.Init(i) -- duplicate callback cannot refill or replace the original snapshot
        eq(p.CharData.HP,0)
    end
    assert(P.Restore(reason)); assert(P.Restore(reason))
    for i=1,4 do
        local p=BattlePlayers[i]
        eq(p.CharData.HP,i==1 and 0 or i*10); eq(p.CharData.MP,2*i); eq(p.CharData.SP,i)
        eq(p.CharData.State,i==1 and 32768 or 4); eq(p.SKData.Energy,i)
        eq(p.CharData.Level,51,'retain earned level'); eq(p.CharData.EXP,77,'retain rewards')
    end
    eq(P.Pending(),false)
end
fresh()
for i=1,4 do BattlePlayers[i].dead=true; BattlePlayers[i].CharData.HP=0; BattlePlayers[i].CharData.State=32768 end
enter(); P.Restore('all dead before entry')
for i=1,4 do eq(BattlePlayers[i].CharData.HP,0);eq(BattlePlayers[i].CharData.State,32768) end
fresh(); P.Init(1)
BattlePlayers[2].ReleaseEffect=function() error('heal interrupted') end
assert(not pcall(P.Init,2)); assert(P.Restore('partial preparation'))
eq(BattlePlayers[1].CharData.HP,0); eq(BattlePlayers[2].CharData.HP,20)
fresh(); enter()
SaveData={}; BattlePlayers[1].CharData.HP=123
P.Restore('different save'); eq(BattlePlayers[1].CharData.HP,123,'no cross-save restoration')
fresh(); enter(); BattlePlayers[1].CharData.HP=88
P.Restore('game start',true); eq(BattlePlayers[1].CharData.HP,88,'new game discards stale pointers')
fresh(); enter()
P.Begin(function() end) -- cleans old operation first
eq(BattlePlayers[1].CharData.HP,0,'new challenge restores before snapshot')
P.Restore('cancel')
print('PASS: party full entry, native revival, four slots, exact restoration and failures')
