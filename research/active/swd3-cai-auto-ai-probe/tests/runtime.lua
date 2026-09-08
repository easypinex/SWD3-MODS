local project, originals = assert(arg[1]), assert(arg[2])
local function equal(a,b,label) assert(a==b,(label or '')..': '..tostring(a)..' ~= '..tostring(b)) end
local messages={}
function StringDB(value) return value end
function log(s)
    messages[#messages+1]=s
    if string.find(s, 'ERROR', 1, true) then print(s) end
end
bit32={band=function(a,b) return a & b end, bor=function(a,b) return a | b end}
Const={eff_DIE=32768}
OnEvent={}
Function={}
GameData={ItemTemp={},AttackEffect={}}
SaveData={Items={},PlayerSkills={{},{},{},{}}}
BattleEnv={players={},enemys={}}
BattlePlayers={}
BattleEnemys={}
local field='CDK_CAI_CHALLENGE'
GameFunc={GetBattleFieldID=function() return field end}
SWD3CaiDemonKing={challengeId=11001,state={active=true}}
_BattleEnv={PlayerIDMax=4}
_PlayerCommands={1,2,3,4,5}
for i=1,4 do
    BattlePlayers[i]={isPlayer=true,isNPC=false,PlayerID=i-1,Name='Hero'..i,AImode=0,
        CharData={HP=1000,MaxHP=1000,MP=100,MaxMP=100,SP=100,MaxSP=100},
        isDeath=function(self) return self.CharData.HP<=0 end,
        isHide=function(self) return self.hidden or false end}
    BattleEnv.players[i]={self=BattlePlayers[i]}
end
local enemy={Name='Cai',NPCData={HP=80000,MaxHP=80000},
    isDeath=function(self) return self.NPCData.HP<=0 end,isHide=function() return false end}
BattleEnemys[1]=enemy
BattleEnv.enemys[1]={self=enemy,status=enemy.NPCData,GUID=11001}
dofile(originals..'/Function_Repository.lua')
dofile(originals..'/BattlePlayerAI.lua')
dofile(originals..'/OnEvent_BattlePlayerAI.lua')
local damage={ [0]=500, [10]=100, [11]=1200, [12]=800 }
_BattleEnv.CalDamage=function(user,target,command,id) equal(target,-1); return damage[id] or 0,0,0 end
local allowed={}
Function.CheckPlayerCanUseSkill=function(index,id) return allowed[id]~=false end
Function.CheckPlayerBadState=function() return {} end
local old=Function.BattlePlayerAI_FullAuto
local oldCalls=0
Function.BattlePlayerAI_FullAuto=function(...) oldCalls=oldCalls+1; return 'old',nil,17 end
dofile(project..'/src/data/CaiAutoPolicy.lua')
dofile(project..'/src/data/CaiAutoAI.lua')
local M=SWD3CaiAutoAIProbe
local P=M.Policy
local function fire(name,...) for _,fn in ipairs(OnEvent[name] or {}) do fn(...) end end
local function reset()
    fire('Battle_RestoreItem')
    field='CDK_CAI_CHALLENGE'; SWD3CaiDemonKing.state={active=true}
    enemy.NPCData.HP=80000
    SaveData.Items={};SaveData.PlayerSkills={{},{},{},{}}
    allowed={}
    for i=5,10 do BattleEnv.players[i]=nil;BattlePlayers[i]=nil end
    for i=1,4 do
        local a=BattlePlayers[i]
        a.CharData.HP=1000;a.CharData.MP=100;a.CharData.SP=100;a.hidden=false;a.AImode=0
        Function.Battle_InitPlayerAImemo(i)
    end
    fire('Battle_Enter')
end
local function item(id,add,calc,all,resource,offensive,race)
    local t={Name='Item'..id,AddHP=0,AddMP=0,AddSP=0,Calculation=calc,
        AttackEffect=id,UsePlace=5,IT_12=0,IT_05=offensive or false,Race=race or 0}
    t[resource or 'AddHP']=add
    for i=1,4 do t[string.format('User_%02u',i)]=true end
    GameData.ItemTemp[id]=t
    GameData.AttackEffect[id]={bWideRange=all,hRelieveEfficacy=0}
end
item(1,1000,0,false); item(2,600,0,true); item(3,100,512,true)
item(4,50,512,true,'AddMP'); item(5,100,512,true,'AddSP')
item(10,0,0,false,nil,true);item(11,0,0,false,nil,true);item(12,0,0,false,nil,true,31)
reset()
for i=1,4 do equal(BattlePlayers[i].AImode,1,'four automatic modes') end
local wrappers=Function.BattlePlayerAI_FullAuto
dofile(project..'/src/data/CaiAutoAI.lua')
equal(Function.BattlePlayerAI_FullAuto,wrappers,'no duplicate wrapper')
equal(#OnEvent.Battle_Enter,1,'no duplicate event')
fire('Battle_Enter');fire('Battle_RestoreItem')
for i=1,4 do equal(BattlePlayers[i].AImode,0,'restore original mode') end
field='BS34'
local a,b,c=Function.BattlePlayerAI_FullAuto()
equal(a,'old');equal(b,nil);equal(c,17);equal(oldCalls,1)
fire('Battle_Enter');equal(M.active,false,'other battle not armed')

-- Drive the original dispatcher and original HP helpers, not copies.
reset()
SaveData.PlayerSkills[2]={{ItemTempID=1},{ItemTempID=2},{ItemTempID=3}}
for i=1,4 do BattlePlayers[i].CharData.HP=300 end
OnEvent.BattlePlayerAI.main(2)
equal(BattlePlayers[2].AI_Command,Const.AI_SKILL)
equal(BattlePlayers[2].AI_SelectItem,3,'percentage full-party skill')
equal(BattlePlayers[2].AI_TargetIsEnemySide,false)
equal(BattleEnv.players[2].AI_AddPlayerSideHPP[4],100,'percent retained')
SaveData.PlayerSkills[3]={{ItemTempID=3},{ItemTempID=11}}
OnEvent.BattlePlayerAI.main(3)
equal(BattlePlayers[3].AI_SelectItem,11,'do not duplicate reserved group heal')

reset()
for i=1,4 do BattlePlayers[i].CharData.HP=300 end
SaveData.PlayerSkills[2]={{ItemTempID=1}}
SaveData.Items={{ItemTempID=3,Count=1,Count_New=0,Stock=0}}
OnEvent.BattlePlayerAI.main(2)
equal(BattlePlayers[2].AI_Command,Const.AI_ITEM,'group item before single skill')
equal(BattleEnv.players[2].AI_AddPlayerSideHPP[1],100,'item percent is not absolute HP')
equal(SaveData.Items[1].Count,1,'native execution owns consumption')
equal(SaveData.Items[1].Stock,0,'no extra stock reservation')

reset()
BattlePlayers[2].CharData.HP=400
SaveData.PlayerSkills[2]={{ItemTempID=2},{ItemTempID=1}}
OnEvent.BattlePlayerAI.main(2)
equal(BattlePlayers[2].AI_SelectItem,1,'single skill for single injury')
reset()
BattlePlayers[2].CharData.HP=700
SaveData.PlayerSkills[2]={{ItemTempID=1},{ItemTempID=11}}
OnEvent.BattlePlayerAI.main(2);equal(BattlePlayers[2].AI_SelectItem,11,'phase one threshold')
enemy.NPCData.HP=48000
OnEvent.BattlePlayerAI.main(2);equal(BattlePlayers[2].AI_SelectItem,1,'phase two threshold')
enemy.NPCData.HP=58000
OnEvent.BattlePlayerAI.main(2);equal(M.phase,2,'heal does not revert phase')

reset()
BattlePlayers[2].CharData.HP=300
SaveData.Items={{ItemTempID=3,Count=1,Count_New=0,Stock=1}}
OnEvent.BattlePlayerAI.main(2)
equal(BattlePlayers[2].AI_Command,Const.AI_ATTACK,'reserved item unavailable')
reset()
BattlePlayers[2].CharData.HP=300
SaveData.PlayerSkills[2]={{ItemTempID=1}};allowed[1]=false
OnEvent.BattlePlayerAI.main(2)
equal(BattlePlayers[2].AI_Command,Const.AI_ATTACK,'sealed or unaffordable skill unavailable')
reset()
SaveData.PlayerSkills[1]={{ItemTempID=10},{ItemTempID=11},{ItemTempID=12}}
OnEvent.BattlePlayerAI.main(1)
equal(BattlePlayers[1].AI_SelectItem,11,'best native predicted damage instead of special first')
equal(BattlePlayers[1].AI_Target,1)
equal(BattlePlayers[1].AI_TargetIsEnemySide,true)
enemy.NPCData.HP=400
OnEvent.BattlePlayerAI.main(1)
equal(BattlePlayers[1].AI_Command,Const.AI_ATTACK,'cheap sufficient finishing hit')

-- Resource helpers also consume the same corrected candidate units.
reset();BattlePlayers[2].CharData.MP=0
SaveData.PlayerSkills[2]={{ItemTempID=4}}
OnEvent.BattlePlayerAI.main(2);equal(BattlePlayers[2].AI_SelectItem,4,'restore zero MP')
reset();BattlePlayers[2].CharData.SP=0
SaveData.PlayerSkills[2]={{ItemTempID=5}}
OnEvent.BattlePlayerAI.main(2);equal(BattlePlayers[2].AI_SelectItem,5,'restore zero SP')

reset();BattlePlayers[2].CharData.HP=300
SaveData.Items={{ItemTempID=3,Count=1,Count_New=0,Stock=0}}
GameData.ItemTemp[3].User_02=false
OnEvent.BattlePlayerAI.main(2)
equal(BattlePlayers[2].AI_Command,Const.AI_ATTACK,'item role restriction')
GameData.ItemTemp[3].User_02=true
reset();BattlePlayers[2].CharData.HP=300
SaveData.PlayerSkills[2]={{ItemTempID=1}}
_PlayerCommands={1,5}
OnEvent.BattlePlayerAI.main(2)
equal(BattlePlayers[2].AI_Command,Const.AI_ATTACK,'respect available command list')
_PlayerCommands={1,2,3,4,5}

-- Pure policy: urgent support, serious priority, no needless non-healer top-up.
-- Native item selection must pass resource costs before healing or summoning.
reset();BattlePlayers[2].CharData.HP=300
SaveData.Items={{ItemTempID=3,Count=1,Count_New=0,Stock=0}}
GameData.ItemTemp[3].Cons_SP=true;GameData.ItemTemp[3].Consumption=300
OnEvent.BattlePlayerAI.main(2);equal(BattlePlayers[2].AI_Command,Const.AI_ATTACK,'SP cannot pay group heal')
BattlePlayers[2].CharData.SP=300
OnEvent.BattlePlayerAI.main(2);equal(BattlePlayers[2].AI_SelectItem,3,'exact SP can pay')
equal(BattlePlayers[2].CharData.SP,300,'selection never deducts SP')
GameData.ItemTemp[3].Cons_SP=nil;GameData.ItemTemp[3].Cons_MP=true
OnEvent.BattlePlayerAI.main(2);equal(BattlePlayers[2].AI_Command,Const.AI_ATTACK,'MP cannot pay group heal')
GameData.ItemTemp[3].Cons_MP=nil;GameData.ItemTemp[3].Cons_Item=true;GameData.ItemTemp[3].Consumption=99
OnEvent.BattlePlayerAI.main(2);equal(BattlePlayers[2].AI_Command,Const.AI_ATTACK,'missing material cannot pay')
SaveData.Items[2]={ItemTempID=99,Count=1,Count_New=0,Stock=1}
OnEvent.BattlePlayerAI.main(2);equal(BattlePlayers[2].AI_Command,Const.AI_ATTACK,'reserved material cannot pay')
SaveData.Items[2].Stock=0
OnEvent.BattlePlayerAI.main(2);equal(BattlePlayers[2].AI_SelectItem,3,'available material can pay')
GameData.ItemTemp[3].Cons_Item=nil;GameData.ItemTemp[3].Consumption=0

for _,id in ipairs({178,179,804}) do item(id,0,0,false) end
for _,id in ipairs({178,179}) do
    GameData.ItemTemp[id].IT_12=true;GameData.ItemTemp[id].Cons_SP=true;GameData.ItemTemp[id].Consumption=320
end
local function summonSetup()
    reset();BattlePlayers[1].CharData.SP=1000
    SaveData.Items={{ItemTempID=178,Count=2,Count_New=0,Stock=0},
        {ItemTempID=179,Count=2,Count_New=0,Stock=0},{ItemTempID=804,Count=1,Count_New=0,Stock=0}}
end
-- Use the original registration handler, with only its skill catalogue reader mocked.
local savedEvents,savedEnv=OnEvent,BattleEnv
OnEvent={};BattleEnv={}
dofile(originals..'/OnEvent_Battle.lua')
local nativeKeeperInit=OnEvent.Battle_KeeperInit.main
OnEvent,BattleEnv=savedEvents,savedEnv
local function keeper(slot,id,itemSlot,hp)
    local self={Name='Keeper'..id,NPC_GUID=id,NPCData={HP=hp or 3000},
        isDeath=function(self) return self.NPCData.HP<=0 end,
        isHide=function() return true end}
    BattlePlayers[slot]=self
    local oldInit=Function.GetBattleCharInitData
    Function.GetBattleCharInitData=function() end
    nativeKeeperInit(slot,itemSlot)
    Function.GetBattleCharInitData=oldInit
    fire('Battle_KeeperInit',slot,itemSlot)
end
summonSetup();OnEvent.BattlePlayerAI.main(1)
equal(BattlePlayers[1].AI_Command,Const.AI_ATTACK,'AI_ITEM cannot summon; never waste SP on living cards')
equal(BattlePlayers[1].CharData.SP,1000);equal(SaveData.Items[1].Stock,0)
fire('Battle_RestoreItem');SWD3CaiDemonKing.state.manualSummon=true;fire('Battle_Enter')
equal(M.awaitSummons,true)
for i=1,4 do equal(BattlePlayers[i].AImode,0,'explicit summon mode starts manual') end
keeper(5,178,1);equal(M.awaitSummons,true,'one keeper is not two')
fire('Battle_KeeperInit',5,1);equal(M.awaitSummons,true,'duplicate event not counted twice')
keeper(6,179,2);equal(M.awaitSummons,false)
for i=1,4 do equal(BattlePlayers[i].AImode,1,'two actual keeper slots resume AI') end
BattlePlayers[1].AImode=0;fire('BattleNPCAI',5)
equal(BattlePlayers[1].AImode,0,'handoff only once; later manual override retained')
BattlePlayers[1].AImode=1
BattlePlayers[5].NPCData.HP=0;fire('Battle_Dead',5,0,0)
OnEvent.BattlePlayerAI.main(1)
equal(BattlePlayers[1].AI_Command,Const.AI_ATTACK,'no broken automatic replacement command')
fire('Battle_RestoreItem')
for i=1,4 do equal(BattlePlayers[i].AImode,0,'manual entry still restores pre-battle modes') end
summonSetup();fire('Battle_RestoreItem');SWD3CaiDemonKing.state.manualSummon=true;fire('Battle_Enter')
keeper(5,178,1);BattlePlayers[5].NPCData.HP=0;keeper(6,179,2)
equal(M.awaitSummons,true,'two init events with one dead keeper do not complete handoff')
fire('MapLoading');equal(M.awaitSummons,false)
summonSetup();fire('Battle_RestoreItem');SWD3CaiDemonKing.state.manualSummon=true;fire('Battle_Enter')
keeper(5,178,1,0);keeper(6,179,2,0)
equal(M.awaitSummons,true,'initializing slots do not count before HP exists')
BattlePlayers[5].NPCData.HP=3000;BattlePlayers[6].NPCData.HP=3000
fire('BattleNPCAI',5);equal(M.awaitSummons,false,'later native keeper action retries handoff')
for i=1,4 do equal(BattlePlayers[i].AImode,1) end
summonSetup();fire('Battle_RestoreItem');SWD3CaiDemonKing.state.manualSummon=true;fire('Battle_Enter')
keeper(5,178,1);fire('Battle_Dead',5,0,1);keeper(6,179,2)
equal(M.awaitSummons,true,'removed keeper with positive HP does not count')
keeper(5,178,1);equal(M.awaitSummons,false,'new keeper in removed slot can count')
summonSetup();fire('Battle_RestoreItem');SWD3CaiDemonKing.state.manualSummon=true;fire('Battle_Enter')
keeper(5,178,1);BattlePlayers[5]={};keeper(6,179,2)
equal(M.awaitSummons,true,'stale registered object does not count')
field='BS34';fire('BattleNPCAI',6);equal(M.awaitSummons,true,'other field cannot resume')
fire('MapLoading');fire('BattleNPCAI',6);equal(M.active,false)
reset()
M.deciding=true
GameData.AttackEffect[3].hRelieveEfficacy=32768;GameData.ItemTemp[3].Price=10
GameData.ItemTemp[3].Cons_SP=true;GameData.ItemTemp[3].Consumption=300
GameData.AttackEffect[1].hRelieveEfficacy=32768;GameData.ItemTemp[1].Price=20
SaveData.Items={{ItemTempID=3,Count=1,Count_New=0,Stock=0},{ItemTempID=1,Count=1,Count_New=0,Stock=0}}
local cure,all,mask,prop=Function.CheckPlayerCureStatefromItems(2,{v=32768},true)
equal(cure,1,'revive chooses affordable alternative');equal(all,false);equal(mask,32768);equal(prop,SaveData.Items[2])
M.deciding=false
GameData.ItemTemp[3].Cons_SP=nil;GameData.AttackEffect[3].hRelieveEfficacy=0
GameData.AttackEffect[1].hRelieveEfficacy=0
print('PASS: rejected summon regression, manual two-keeper handoff, costs and cure return contract')

local calls={}
local reason=P.Decide({HP={{1,35}},HPP=35,MPP=100,SPP=100},0,1,function(name)
    calls[#calls+1]=name;return name=='AI_ItemAddHP' end)
equal(reason,'heal-item');equal(calls[1],'AI_SkillAddHP')
reason=P.Decide({HP={{1,60}},HPP=60,MPP=100,SPP=100},0,1,function() error('unexpected heal') end)
equal(reason,'attack')
reason=P.Decide({Serious={{ID=1}},HP={{2,20}},HPP=20},2,2,function(name)
    equal(name,'AI_CureBadState');return true end)
equal(reason,'serious')

reset()
local previousPlayer=BattlePlayers[1]
BattlePlayers[1]={AImode=4}
fire('Battle_RestoreItem')
equal(BattlePlayers[1].AImode,4,'never write replacement object')
BattlePlayers[1]=previousPlayer
reset();fire('GameStart');equal(M.active,false);equal(next(M.snapshots),nil)
reset();fire('MapLoading');equal(M.active,false);equal(next(M.snapshots),nil)

reset()
local originalDamage=_BattleEnv.CalDamage
_BattleEnv.CalDamage=function() error('injected prediction failure') end
OnEvent.BattlePlayerAI.main(1)
equal(M.failed,true);equal(M.deciding,false);equal(M.groupOnly,false)
equal(BattlePlayers[1].AI_Command,Const.AI_DEFENSE)
for i=1,4 do equal(BattlePlayers[i].AImode,0,'error stops all automatic roles') end
_BattleEnv.CalDamage=originalDamage
fire('Battle_RestoreItem')
print('PASS: Cai auto AI native dispatcher, four heroes, scoped wrappers, group and percentage healing, reservations, phases, attacks and cleanup')
