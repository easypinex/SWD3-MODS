local root,native=assert(arg[1]),assert(arg[2])
local function eq(a,b,label) assert(a==b,(label or '')..': '..tostring(a)..' ~= '..tostring(b)) end
SWD3CaiDemonKing={}
dofile(root..'/src/data/CaiDialogue.lua')
local D=SWD3CaiDemonKing.Dialogue
eq(D.NextSeed(1),16807)
eq(D.NextSeed(2147483646),2147466840,'32-bit boundary')
local seed=1
for i=1,1000 do seed=D.NextSeed(seed);assert(seed>0 and seed<2147483647) end
for roll=1,100 do
    eq(D.Plan(1,roll,false).branch,'reunion')
    eq(D.Plan(2,roll,false).branch,'reunion')
    eq(D.Plan(3,roll,false).branch,roll<=30 and 'nostalgic' or 'reunion')
    eq(D.Plan(3,roll,true).opening[1],'CDK_EQUIPPED_OPEN','equipment priority')
end
eq(D.Plan(2,100,false).opening[1],D.Plan(6,100,false).opening[1],'repeat cycle')
local save={PlayerEqu={[1]={[8]={ItemTempID=11006}}}}
eq(D.Equipped(save,{{isPlayer=true,GUID=1}}),true)
eq(D.Equipped(save,{{isPlayer=true,GUID=2}}),false,'reserve character not in party')
eq(D.Equipped(save,{{isKeeper=true,GUID=1}}),false)
save.PlayerEqu[1][8]=nil;save.PlayerEqu[1][1]={ItemTempID=11006}
eq(D.Equipped(save,{{isPlayer=true,GUID=1}}),false,'only guardian slots')
save.PlayerEqu[1][9]={ItemTempID=11006}
eq(D.Equipped(save,{{isPlayer=true,GUID=1}}),true)

local oldRng,oldSeed=math.random,math.randomseed
math.random=function() error('dialogue must not consume combat RNG') end
math.randomseed=function() error('dialogue must not seed combat RNG') end
local state={}
local d=D.Begin(state,save,{},123)
eq(d.attempt,1);eq(save.SWD3CaiDemonKing.Attempts,1)
eq(D.Begin(state,save,{},999),d,'duplicate enter')
eq(save.SWD3CaiDemonKing.Attempts,1)
local firstHints=D.Defeat(state,save)
eq(D.Defeat(state,save),firstHints);eq(save.SWD3CaiDemonKing.Defeats,1)
for i=2,5 do
    state={};d=D.Begin(state,save,{},999)
    local pair=D.Defeat(state,save)
    eq(pair[1]==firstHints[1],i==5,'four loss topics rotate')
end
local other={};local otherState={}
D.Begin(otherState,other,{},1);eq(other.SWD3CaiDemonKing.Attempts,1)
assert(not pcall(D.Defeat,state,other),'cross-save rejection')
eq(other.SWD3CaiDemonKing.Defeats,0)
for attempt=1,50 do
    for _,manual in ipairs({false,true}) do
        local s={SWD3CaiDemonKing={Attempts=attempt-1,Seed=1}}
        local x=D.Begin({manualSummon=manual},s,{},1)
        assert(#x.opening+(manual and 1 or 0)+x.middleLimit+2<=6,'line budget')
    end
end
math.random,math.randomseed=oldRng,oldSeed

-- Execute the original serializer in isolation, then reload its output.
GameData={};Const={};Function={}
dofile(native..'/GameData_cFunction.lua')
SaveData=save
local wire=GameData.SendAllSaveData()
assert(wire:find('SWD3CaiDemonKing',1,true),'namespace serialized')
assert(load(wire))()
assert(SaveData~=save,'new save identity')
eq(SaveData.SWD3CaiDemonKing.Attempts,5)
eq(SaveData.SWD3CaiDemonKing.Defeats,5)
local resumed=D.Begin({},SaveData,{},9999)
eq(resumed.attempt,6)
eq(save.SWD3CaiDemonKing.Attempts,5,'old save untouched after reload')
local corrupt={SWD3CaiDemonKing={Attempts=math.huge,Seed=-1,Defeats=0/0}}
D.Begin({},corrupt,{},1)
eq(corrupt.SWD3CaiDemonKing.Attempts,1);eq(corrupt.SWD3CaiDemonKing.Defeats,0)
assert(not pcall(D.Begin,{}, {SWD3CaiDemonKing={DialogueVersion=2}}, {},1),'future schema not overwritten')
print('PASS: dialogue thresholds, private RNG, equipment context, rotation, budgets and native save serialization')
