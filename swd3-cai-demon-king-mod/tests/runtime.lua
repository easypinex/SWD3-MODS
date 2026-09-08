local root=arg[1]
assert(loadfile(root..'/tests/party_fixture.lua'))()
local function load(name) assert(loadfile(root..'/src/data/'..name))() end
local function eq(a,b,msg) assert(a==b,(msg or '')..' expected '..tostring(b)..', got '..tostring(a)) end
local ticks,field,breaks,noOver,starts,scenes=1000,nil,0,0,0,0
local choices={}
local menus={}
local selection=0
log=function() end
GetTicks=function() return ticks end
StringDB=function(key) return key end
ACTcmd={ED=1,OV=2,O2=3,RF=5,PA=6,SD=9,NO=11,XY=12,WH=13,WV=21,AT=22,TN=25}
ACTData={}
GameData={ItemTemp={
    [438]={ACT=438,Level=99,HP=10000,ATK=100,DEF=100,SPD=40,GainEXP=1,GainGold=1,SP_AttackEffects={1683}},
    [12]={ACT=12,HP=1500}
}}
assert(loadfile(root..'/tests/skill_fixture.lua'))()
SaveData={Items={sentinel={Count=3,Stock=1}},Flag={[170]=8}}
Scene={}; BattleField={}; OnEvent={GameStart={function() end}}
BattleEnv={players={}}
Const={AI_SKILL=2,AI_ATTACK=1}
GameFunc={GetBattleFieldID=function() return field end,
    RunScene=function(_,name) scenes=scenes+1; Scene[name]() end}
ESC={Menu=function(title,rows)
    for _,row in ipairs(rows) do eq(row:sub(-4),'    ','UTF8 padding') end
    menus[#menus+1]=rows
    selection=table.remove(choices,1) or 0
end,GetMENUSelect=function() return selection end,
StartBattle=function(id)
    starts=starts+1; field=id
    for i=1,4 do for _,fn in ipairs(OnEvent.Battle_PlayerInit) do fn(i) end end
end}
BSC={NoOVER=function() noOver=noOver+1 end,BattleBreak=function() breaks=breaks+1; field=nil end}
local function event(name,...) for _,fn in ipairs(OnEvent[name] or {}) do fn(...) end end
load('CaiDemonActions.lua')
local actions=SWD3CaiDemonKing.actions
load('CaiDemonActions.lua'); eq(SWD3CaiDemonKing.actions,actions,'idempotent actions')
local card={ACT=438,HP=16000,IT_12=true,Name='AMSC_Name_438',SP_AttackEffects={1683},Consumption=200}
GameData.ItemTemp[10096]=card
SWD3AllMonsterStaticCatalogue={entries={[438]={staticCard=true,cardId=10096}}}
SWD3AllMonsterStaticCapture={staticCards={[10096]=card}}
load('CaiDemonData.lua')
eq(GameData.ItemTemp[438].IT_06,true,'enemy Boss identity')
eq(card.IT_06,nil,'guardian remains non-Boss')
eq(SWD3CaiDemonKing.originals[GameData.ItemTemp[438]].IT_06.value,nil,'original Boss absence preserved')
eq(card.HP,16000); eq(card.Consumption,200); eq(card.Name,'AMSC_Name_438')
eq(card.SP_AttackEffects,nil); eq(card.CR_Skills[1],1683)
eq(GameData.ItemTemp[438].HP,10000); eq(GameData.ItemTemp[12].ACT,12)
eq(SWD3CaiDemonKing.originals[GameData.ItemTemp[438]].SP_AttackEffects.value[1],1683)
-- Catalogue loaded later copies already repaired source without re-registration.
local later={}; for k,v in pairs(GameData.ItemTemp[438]) do later[k]=v end
-- The actual catalogue builder explicitly clears IT_06 after copying source.
later.IT_06=nil
eq(later.IT_06,nil,'later guardian remains non-Boss')
eq(later.ACT,438); eq(later.SP_AttackEffects,nil); eq(later.Skills_QQ[2],44)
load('CaiDemonChallengeData.lua')
load('CaiPartyState.lua')
assert(loadfile(root..'/tests/inventory_fixture.lua'))()
load('CaiInventory.lua')
load('CaiDemonAI.lua')
load('CaiReward.lua');load('CaiDialogue.lua');load('CaiFairPlay.lua');load('CaiDemonKing.lua'); local count=#OnEvent.GameStart
load('CaiDemonKing.lua'); eq(#OnEvent.GameStart,count,'no duplicate hooks')
event('GameStart'); event('InputClick',0,73); eq(scenes,0,'outside inventory')
event('DrawMenuAfter'); choices={1}; event('InputClick',0,73); eq(starts,0,'cancel')
ticks=ticks+500; event('DrawMenuAfter'); choices={3}; event('InputClick',0,73)
eq(starts,1); eq(BattleField.CDK_CAI_CHALLENGE.tCharActQ[1].ItemTempID,11001)
event('Battle_Enter'); eq(noOver,1)
BattleEnv.enemys={{GUID=11001,status={HP=80000,MaxHP=80000},self={}}}
BattleEnv.players={{isPlayer=true,status={HP=100},self={isHide=function() return false end,isDeath=function() return false end}}}
event('BattleEnemyAI',1)
eq(SWD3CaiDemonKing.state.seenSkills[0],true,'opening always normal attack')
eq(BattleEnv.enemys[1].self.AI_TargetIsEnemySide,true,'opening targets player')
event('InputClick',0,73); eq(starts,1,'no reentry')
BattleEnv.players={{isPlayer=true,status={HP=0}},{isPlayer=true,status={HP=1}}}
event('Battle_Dead',1,0,0); eq(breaks,0,'living player')
BattleEnv.players[2].status.HP=0
event('Battle_Dead',2,0,0); event('Battle_Dead',2,0,0); eq(breaks,1,'single defeat break')
event('Battle_RestoreItem'); event('MapLoading'); eq(SWD3CaiDemonKing.state.active,false)
field='BS001'; event('Battle_Enter'); event('Battle_Dead',1,0,0); eq(noOver,1); eq(breaks,1)
field=nil; ESC.StartBattle=function() error('simulated failure') end
ticks=ticks+500; event('DrawMenuAfter'); choices={3,1}; event('InputClick',0,73)
eq(SWD3CaiDemonKing.state.active,false,'start failure cleanup')
GameData.ItemTemp[11001].ACT=12
ticks=ticks+500; event('DrawMenuAfter'); choices={3,1}; event('InputClick',0,73); eq(starts,1,'reference conflict blocked')
eq(SaveData.Flag[170],8); eq(SaveData.Items.sentinel.Count,3); eq(SaveData.Items.sentinel.Stock,1)
-- Foreign card table is not adopted, even when it uses the expected numeric ID.
SWD3AllMonsterStaticCapture.staticCards[10096]={}
local foreign={ACT=999}; GameData.ItemTemp[10096]=foreign
load('CaiDemonData.lua'); eq(foreign.ACT,999)
print('PASS: Cai data ownership, load order, menu, lifecycle, failure and save isolation')
