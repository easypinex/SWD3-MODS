local root=arg[1]
local function load(name) assert(loadfile(root..'/src/data/'..name))() end
local function eq(a,b,msg) assert(a==b,(msg or '')..' expected '..tostring(b)..', got '..tostring(a)) end
local function fresh()
    local h={field=nil,breaks=0,hints=0,starts=0,ticks=1000,choices={}}
    SWD3CaiDemonKing=nil; SWD3LiveCardBattle=nil; SWD3AllMonsterStaticCapture=nil; SWD3AllMonsterStaticCatalogue=nil
    assert(loadfile(root..'/tests/party_fixture.lua'))()
    GameData={ItemTemp={[438]={ACT=438,Race=1,Level=99,HP=10000,ATK=100,DEF=100,SPD=40,
        isBattleChar=true,NotInBook=true,AttackEffect=1,GainEXP=1,GainGold=1}}}
    assert(loadfile(root..'/tests/skill_fixture.lua'))()
    SaveData={Items={}}; OnEvent={}; Scene={}; BattleField={}; Const={AI_SKILL=2,AI_ATTACK=1}
    GetTicks=function() return h.ticks end
    StringDB=function(key) return key end
    h.logs={}; log=function(line) h.logs[#h.logs+1]=line end
    GameFunc={GetBattleFieldID=function() return h.field end,
        RunScene=function(_,name) Scene[name]() end}
    ESC={Menu=function(title,rows)
        h.menuRows=rows
        if rows[2]=='The Light Tower, the Dark Vessel... Good things reward care. Their finer qualities emerge with practice.    ' then h.hints=h.hints+1 end
        h.selected=table.remove(h.choices,1) or 1
    end,GetMENUSelect=function() return h.selected end,
    StartBattle=function(id)
        h.field=id; h.starts=h.starts+1
        for i=1,4 do h.event('Battle_PlayerInit',i) end
    end}
    BSC={NoOVER=function() end,BattleBreak=function() h.breaks=h.breaks+1 end}
    BattleEnv={players={{isPlayer=true,status={HP=100}},{isPlayer=true,status={HP=100}},
        {isKeeper=true,status={HP=10000}}},enemys={{GUID=11001}}}
    BattleEnemys={{NPC_GUID=11001,NPCData={Level=99,ItemType=0x20,HP=80000,MaxHP=80000,
        ATK=950,DEF=350,SPD=120,WIS=220}}}
    function h.event(name,...)
        for _,fn in ipairs(OnEvent[name] or {}) do fn(...) end
    end
    function h.menu(choices)
        h.ticks=h.ticks+500; h.choices=choices
        h.event('DrawMenuAfter'); h.event('InputClick',0,73)
    end
    function h.start()
        h.menu({3}); h.event('Battle_Enter')
    end
    function h.defeat()
        BattleEnv.players[1].status.HP=0; BattleEnv.players[2].status.HP=0
        h.event('Battle_Dead',2,0,0)
    end
    load('CaiDemonActions.lua'); load('CaiDemonData.lua'); load('CaiDemonChallengeData.lua')
    load('CaiPartyState.lua')
    assert(loadfile(root..'/tests/inventory_fixture.lua'))()
    load('CaiInventory.lua')
    load('CaiDemonAI.lua')
    load('CaiReward.lua');load('CaiDialogue.lua');load('CaiFairPlay.lua');load('CaiDemonKing.lua'); h.event('GameStart')
    return h
end
local h=fresh()
local template=GameData.ItemTemp[11001]
eq(template.HP,80000); eq(template.Level,99); eq(template.IT_06,true); eq(template.IT_12,nil)
eq(template.DodgeRate,5); eq(template.AttrWind,2); eq(template.AttrDark,-4)
eq(template.Skills[1],11002); eq(template.CR_Skills[1],11005)
assert(template.Skills~=GameData.ItemTemp[438].Skills,'independent skill arrays')
template.SkillsCount[1]=0
eq(GameData.ItemTemp[438].SkillsCount[1],2,'native source untouched')
load('CaiDemonChallengeData.lua'); eq(GameData.ItemTemp[11001],template,'idempotent registration')
GameData.ItemTemp[11001]={}
assert(not pcall(load,'CaiDemonChallengeData.lua'),'foreign replacement must fail')
h=fresh(); SWD3CaiDemonKing.challengeTemplate=nil
assert(not pcall(load,'CaiDemonChallengeData.lua'),'occupied new ID must fail')

h=fresh(); h.start(); h.defeat()
eq(h.breaks,1,'living keeper does not prevent protagonist defeat')
h.event('Battle_Dead',2,0,0); eq(h.breaks,1,'deduplicated break')
eq(h.hints,0,'no yielding dialog inside death callback')
eq(SWD3CaiDemonKing.state.pendingHintSave,nil,'wait for cleanup')
h.event('Battle_RestoreItem'); h.event('Battle_RestoreItem')
eq(SWD3CaiDemonKing.state.pendingHintSave,nil,'no deferred menu receipt')
h.field=nil; h.menu({1}); eq(h.hints,0,'no hint in inventory menu')
h.menu({1}); eq(h.hints,0)
h.start(); eq(h.starts,2,'rechallenge after defeat')

-- A deferred engine break can instead be confirmed by the inventory boundary.
h=fresh(); h.start(); h.defeat(); h.field=nil; h.menu({1,1})
eq(h.hints,0,'inventory recovery does not display combat dialogue')

-- v0.4 live trace: two RestoreItem callbacks, then MapLoading, then Insert.
h=fresh(); h.start(); h.defeat(); h.event('Battle_RestoreItem'); h.event('Battle_RestoreItem')
h.event('MapLoading'); h.field=nil; h.menu({1,1})
eq(h.hints,0,'no dialogue deferred across map return')
h.menu({1}); eq(h.hints,0)
-- Last battle ID is not a current-mode flag; cleanup already ended this battle.
h=fresh(); h.start(); h.defeat(); h.event('Battle_RestoreItem')
h.menu({1,1}); eq(h.hints,0,'no menu dialogue with stale battle ID')

-- Natural victory and non-death exit modes never become loss hints.
for _,mode in ipairs({0,1,2,3}) do
    h=fresh(); h.start(); h.event('Battle_Dead',1,1,mode); h.defeat()
    eq(h.breaks,0,'enemy removal wins priority')
    h.event('Battle_RestoreItem'); h.field=nil; h.menu({1}); eq(h.hints,0)
end
for _,mode in ipairs({1,2,3}) do
    h=fresh(); h.start()
    BattleEnv.players[1].status.HP=0; BattleEnv.players[2].status.HP=0
    h.event('Battle_Dead',2,0,mode); eq(h.breaks,0,'non-death mode ignored')
end
h=fresh(); h.start(); h.event('Battle_RestoreItem'); h.field=nil; h.menu({1}); eq(h.hints,0)
h=fresh(); h.start(); BattleEnv.players[1].status.HP=nil; BattleEnv.players[2].status.HP=0
h.event('Battle_Dead',2,0,0); eq(h.breaks,0,'unknown HP is not defeat')
h=fresh(); h.start(); BattleEnv.players={{isKeeper=true,status={HP=0}}}
h.event('Battle_Dead',1,0,0); eq(h.breaks,0,'no protagonists is not defeat')

-- Failure, cross-map/save and unrelated battles clear the pending result.
h=fresh(); h.start(); BSC.BattleBreak=function() error('break failure') end; h.defeat()
h.event('Battle_RestoreItem'); eq(SWD3CaiDemonKing.state.pendingHintSave,nil)
for _,clear in ipairs({'game','save','otherBattle'}) do
    h=fresh(); h.start(); h.defeat(); h.event('Battle_RestoreItem'); h.field=nil
    if clear=='game' then h.event('GameStart')
    elseif clear=='save' then SaveData={Items={}}
    else h.field='BS1'; h.event('Battle_Enter'); h.field=nil end
    h.menu({1}); eq(h.hints,0,'pending hint cleared: '..clear)
end
h=fresh(); h.start(); h.defeat(); h.event('Battle_RestoreItem')
SaveData={Items={}}; h.event('MapLoading'); h.field=nil; h.menu({1}); eq(h.hints,0,'map load into another save')
h=fresh(); h.start(); h.defeat(); h.event('MapLoading'); h.field=nil; h.menu({1})
eq(h.hints,0,'unconfirmed interrupted defeat is not carried across maps')
h=fresh(); ESC.StartBattle=function() error('start failure') end; h.menu({3,1})
eq(SWD3CaiDemonKing.state.active,false); eq(h.hints,0)
h=fresh(); BSC.NoOVER=function() error('NoOVER failure') end; h.start(); h.defeat()
eq(h.breaks,1,'abort if defeat-return protection cannot be enabled'); eq(h.hints,0)
-- Reentrant cleanup inside the native call must not restore stale active state.
h=fresh(); h.start()
BSC.BattleBreak=function() h.event('Battle_RestoreItem'); h.field=nil end
h.defeat(); eq(SWD3CaiDemonKing.state.active,false)
h.menu({1,1}); eq(h.hints,0)
print('PASS: Cai v0.4 independent registration, exit classification and context isolation')

-- v0.6: real Lua coroutine suspension at every dialog and native Run boundary.
local function scripted(options)
    local ctx=fresh()
    Const.BMS1=-1
    BattleScript={}
    ctx.lines={}
    BattleScript.AutoPrint=function(who,act,x,y,line)
        eq(who,-1); eq(act,9005); eq(x,50); eq(y,30)
        assert(coroutine.isyieldable(),'dialogue must not run in the death event')
        ctx.lines[#ctx.lines+1]=line
        coroutine.yield('dialogue')
    end
    BSC.Enter=function(mode) eq(mode,1); ctx.event('Battle_Enter') end
    BSC.SetDisable=function(who) eq(who,-1);ctx.disabled=true end
    ItemFunc={AddItem=function(id,n)
        ctx.grants=(ctx.grants or 0)+1;SaveData.Items[#SaveData.Items+1]={ItemTempID=id,Count=n}
    end}
    BSC.Win=function()
        ctx.wins=(ctx.wins or 0)+1;ctx.event('BattleGain');ctx.event('Battle_RestoreItem');ctx.field=nil
    end
    BSC.Run=function(mode) eq(mode,1); coroutine.yield('run') end
    BSC.BattleBreak=function()
        ctx.breaks=ctx.breaks+1
        ctx.event('Battle_RestoreItem'); ctx.field=nil
    end
    if options then options(ctx) end
    ctx.menu({3})
    -- Legacy internal dialogue path; the released menu exposes no test entry.
    if ctx.manual then SWD3CaiDemonKing.state.manualSummon=true end
    ctx.co=coroutine.create(BattleScript.CDK_CAI_CHALLENGE)
    function ctx.step(expected)
        local ok,value=coroutine.resume(ctx.co)
        assert(ok,value); eq(value,expected)
    end
    return ctx
end
h=scripted(); h.step('dialogue'); eq(#h.lines,1,'opening before battle loop')
h.step('dialogue'); eq(#h.lines,2)
h.step('run'); h.defeat(); h.event('Battle_Dead',2,0,0)
eq(h.breaks,0,'death callback queues dialogue instead of exiting')
eq(#h.lines,2,'death callback does not display dialogue')
h.step('dialogue'); eq(#h.lines,3)
eq(h.breaks,0,'still in battle during defeat hint')
h.step('dialogue'); eq(#h.lines,4)
h.step(nil); eq(h.breaks,1); eq(SWD3CaiDemonKing.state.active,false)
eq(SWD3CaiDemonKing.state.pendingHintSave,nil,'spoken defeat not repeated in menu')
h.menu({1}); eq(h.hints,0)

h=scripted(); h.step('dialogue'); h.step('dialogue'); h.step('run')
BattleEnemys[1].NPCData.HP=0;h.event('Battle_Dead',1,1,0)
h.step('dialogue');h.step('dialogue');eq(h.grants,nil,'reward waits for native Win')
h.step(nil);eq(h.wins,1);eq(h.grants,1);eq(#h.lines,4);eq(h.breaks,0);eq(h.disabled,true)
h.event('BattleGain');h.event('Battle_RestoreItem');eq(h.grants,1,'duplicate settlement ignored')
eq(SWD3CaiDemonKing.Reward.Count(),1)

for _,mode in ipairs({1,2,3}) do
    h=scripted();h.step('dialogue');h.step('dialogue');h.step('run')
    BattleEnemys[1].NPCData.HP=0;h.event('Battle_Dead',1,1,mode);h.step(nil)
    eq(h.grants,nil);eq(h.wins,nil);eq(h.breaks,1,'non-death removal exits without reward')
end
h=scripted();h.step('dialogue');h.step('dialogue');h.step('run')
BattleEnemys[1].NPCData.HP=0;h.step('dialogue');h.event('MapLoading');h.step(nil)
eq(h.grants,nil,'interrupted victory dialogue cannot reward')
h=scripted();h.step('dialogue');h.step('dialogue');h.step('run')
BattleEnemys[1].NPCData.HP=0;h.step('dialogue');h.event('Battle_Dead',1,1,3);h.step(nil)
eq(h.grants,nil);eq(h.breaks,1,'non-death removal during victory safely exits')
h=scripted();h.step('dialogue');h.step('dialogue');h.step('run')
BattleEnemys[1].NPCData.HP=0;h.step('dialogue');h.step('dialogue')
BSC.Win=function() h.wins=1;h.event('Battle_RestoreItem');h.field=nil end
h.step(nil);eq(h.grants,1,'verified native Win supports restore fallback')
h=scripted();h.step('dialogue');h.step('dialogue');h.step('run')
BattleEnemys[1].NPCData.HP=0;h.step('dialogue');h.step('dialogue')
ItemFunc.AddItem=function() end;h.step(nil);eq(h.grants,nil);eq(SWD3CaiDemonKing.Reward.Count(),0)

for _,owned in ipairs({'inventory','equipped','reserved'}) do
    h=scripted();h.step('dialogue');h.step('dialogue');h.step('run')
    if owned=='equipped' then SaveData.PlayerEqu={{ {ItemTempID=11006} }}
    else
        ItemClass.AddItem(11006,1,0,false)
        SaveData.Items[#SaveData.Items].Stock=owned=='reserved' and 1 or 0
    end
    BattleEnemys[1].NPCData.HP=0;h.step('dialogue');h.step('dialogue');h.step(nil)
    eq(h.wins,1);eq(h.grants,nil,'owned reward not duplicated: '..owned)
end
h=scripted();h.step('dialogue');h.step('dialogue');h.step('run')
BattleEnemys[1].NPCData.HP=0;h.defeat();h.step('dialogue');h.step('dialogue');h.step(nil)
eq(h.wins,nil);eq(h.grants,nil,'party defeat has priority')
h=scripted();h.step('dialogue');h.step('dialogue');h.step('run')
SWD3CaiDemonKing.state.combat.phase=2;h.step('dialogue');h.step('run');h.step('run')
eq(#h.lines,3,'phase dialogue only once')

h=scripted(); h.step('dialogue'); h.step('dialogue'); h.step('run')
h.event('MapLoading'); h.field=nil; h.step(nil)
eq(#h.lines,2,'map interruption does not play defeat dialogue'); eq(h.breaks,0)

h=scripted(); h.step('dialogue')
h.event('MapLoading'); h.field=nil; h.menu({3})
SWD3CaiDemonKing.state.scriptActive=true
h.step(nil); eq(#h.lines,1,'old dialogue cannot continue in a new challenge')
eq(SWD3CaiDemonKing.state.scriptActive,true,'old coroutine cannot clear new script state')

h=scripted()
BattleScript.AutoPrint=function() error('dialogue failure') end
h.step(nil); eq(h.breaks,1,'failed opening exits safely'); eq(SWD3CaiDemonKing.state.active,false)

h=scripted(); h.step('dialogue'); h.step('dialogue'); h.step('run'); h.defeat()
BattleScript.AutoPrint=function() error('defeat dialogue failure') end
h.step(nil); eq(h.breaks,1,'failed defeat dialog still exits')
eq(SWD3CaiDemonKing.state.pendingHintSave,nil,'dialogue failure never creates menu fallback')

h=fresh(); h.menu({4}); eq(h.hints,0,'fourth menu row remains Return')
eq(h.starts,0)
print('PASS: Cai native dialogue coroutine, opening/defeat order, cancellation, errors and no menu hints')

h=fresh(); h.start()
local ai={AI_Command=Const.AI_SKILL,AI_SelectItem=11005,AI_TargetIsEnemySide=false,AI_Target=1,RestorHP=10000}
BattleEnv.enemys[1].self=ai
BattleEnv.enemys[1].status={HP=80000,MaxHP=80000}
BattleEnv.players[2].self={isHide=function() return false end,isDeath=function() return false end}
h.event('BattleEnemyAI',1); eq(ai.AI_SelectItem,0,'opening replaces native cure')
eq(ai.RestorHP,0); eq(ai.AI_Target,2); eq(ai.AI_TargetIsEnemySide,true)
BattleEnv.enemys[1].status.HP=36000
h.event('BattleEnemyAI',1); eq(ai.AI_SelectItem,11005); eq(ai.RestorHP,6000)
eq(ai.AI_Target,1); eq(ai.AI_TargetIsEnemySide,false)
h.event('BattleEnemyAI',1); assert(ai.AI_SelectItem~=11005,'cannot heal twice'); eq(ai.RestorHP,0)
ai.AI_SelectItem=123
BattleEnv.enemys[1].GUID=438
h.event('BattleEnemyAI',1); eq(ai.AI_SelectItem,123,'legacy Cai ignored')
BattleEnv.enemys[1].GUID=11001; h.field='OTHER'
h.event('BattleEnemyAI',1); eq(ai.AI_SelectItem,123,'other field ignored')
h.field='CDK_CAI_CHALLENGE'; h.event('Battle_RestoreItem')
eq(SWD3CaiDemonKing.state.combat.healUsed,nil,'healing allowance reset on exit')
print('PASS: strategy hook, native cure replacement, scope and cleanup')
h=fresh();SWD3CaiAutoAIProbe={supportsManualSummon=true}
local restocks=0
SWD3CaiTestStart={Restock=function() restocks=restocks+1 end};SaveData.SWD3CaiTestStart={Ready=true}
h.menu({1});eq(#h.menuRows,4,'test packages cannot add menu rows')
h.menu({5});eq(h.starts,0,'removed restock row cannot start a battle');eq(restocks,0)
h.menu({6});eq(h.starts,0,'removed manual row cannot start a battle')
h.menu({3});eq(h.starts,1);eq(SWD3CaiDemonKing.state.manualSummon,false,'normal challenge only')
h.event('Battle_RestoreItem');SWD3CaiAutoAIProbe=nil;SWD3CaiTestStart=nil
print('PASS: released menu excludes test entries even with test packages and saved markers')

-- v1.0: actual integration routing and cancellation, beyond pure selection.
h=fresh();h.menu({1});eq(SaveData.SWD3CaiDemonKing,nil,'menu does not count')
ESC.StartBattle=function() error('start failure') end;h.menu({3,1})
eq(SaveData.SWD3CaiDemonKing,nil,'failed start does not count')
h=scripted();h.step('dialogue');eq(SaveData.SWD3CaiDemonKing.Attempts,1)
h.event('Battle_Enter');eq(SaveData.SWD3CaiDemonKing.Attempts,1,'duplicate enter does not count')
h.step('dialogue');h.step('run')
SWD3CaiDemonKing.state.combat.phase=2;SWD3CaiDemonKing.state.healDialoguePending=true
h.step('dialogue');h.step('run');h.step('dialogue');h.step('run');h.step('run')
eq(#h.lines,4,'phase and heal one each')
BattleEnemys[1].NPCData.HP=0;h.step('dialogue');h.step('dialogue');h.step(nil)
eq(#h.lines,6);eq(h.grants,1,'first complete route')
h=scripted(function()
    SaveData.SWD3CaiDemonKing={DialogueVersion=1,Attempts=2,Defeats=0,Seed=1}
end)
h.step('dialogue');assert(h.lines[1]:find('Maoshou and Zhihao',1,true))
h.step('dialogue');h.step('run');eq(SWD3CaiDemonKing.state.dialogue.branch,'nostalgic')
SWD3CaiDemonKing.state.combat.phase=2;h.step('dialogue')
assert(h.lines[3]:find('Maoshou',1,true));h.step('run')
BattleEnemys[1].NPCData.HP=0;h.step('dialogue');h.step('dialogue');h.step(nil)
eq(h.grants,1,'nostalgic victory still grants')
h=scripted(function()
    SaveData.PlayerEqu={[1]={[8]={ItemTempID=11006}}}
    BattleEnv.players[1].GUID=1
end)
h.step('dialogue');assert(h.lines[1]:find('now I travel with you',1,true));h.step('run')
BattleEnemys[1].NPCData.HP=0;h.step('dialogue');h.step('dialogue');h.step(nil)
eq(h.grants,nil,'equipped opening and owned ending')
h=scripted(function(ctx) ctx.manual=true;SWD3CaiAutoAIProbe={supportsManualSummon=true} end)
h.step('dialogue');h.step('dialogue');h.step('dialogue');h.step('run')
SWD3CaiDemonKing.state.combat.phase=2;SWD3CaiDemonKing.state.healDialoguePending=true
h.step('dialogue');h.step('run');h.step('run')
BattleEnemys[1].NPCData.HP=0;h.step('dialogue');h.step('dialogue');h.step(nil)
eq(#h.lines,6,'manual intro replaces extra heal chatter')
SWD3CaiAutoAIProbe=nil
for _,kind in ipairs({'stats','items','rules'}) do
    h=scripted(function()
        if kind=='stats' then BattlePlayers[1].CharData.ATK=5001 end
        if kind=='items' then SaveData.Items={{ItemTempID=632,Count=2,Count_New=0}} end
    end)
    if kind=='items' then SaveData.Items[1].Count=3 end
    if kind=='rules' then GameData.AttackEffect[11003].iAttackPoint=1 end
    h.step('dialogue');eq(SWD3CaiDemonKing.state.fairBlocked,kind)
    eq(SaveData.SWD3CaiDemonKing,nil,'rejected entry not counted')
    h.step('dialogue');h.step(nil)
    eq(h.breaks,1);eq(h.wins,nil);eq(h.grants,nil,'invalid never grants')
    eq(BattlePlayers[1].CharData.HP,0,'original dead character restored')
end
h=scripted(function() SaveData.Items={{ItemTempID=632,Count=2,Count_New=0}} end)
h.step('dialogue');h.step('dialogue');h.step('run')
BattleEnemys[1].NPCData.HP=0;h.step('dialogue')
SaveData.Items[1].Count=3
h.step('dialogue');assert(h.lines[4]:find('supplies',1,true),'tamper during victory gets its own line')
h.step('dialogue');h.step(nil);eq(h.wins,nil);eq(h.grants,nil)
h=scripted();h.step('dialogue')
local oldSave=SaveData;SaveData={Items={}}
h.step(nil);eq(SaveData.SWD3CaiDemonKing,nil,'stale dialogue cannot write another save')
eq(oldSave.SWD3CaiDemonKing.Attempts,1)
print('PASS: v1 dialogue branches, six-line budget, admission rejection, invalid victory and cross-save cancellation')

-- Confirmed reward is announced after cleanup through a deferred native Scene.
h=fresh();h.start()
local receiptState=SWD3CaiDemonKing.state
receiptState.victoryRequested=true;receiptState.victoryProved=true;receiptState.outcome='victory'
h.event('BattleGain')
assert(SWD3CaiDemonKing.Reward.PendingReceipt(),'confirmed grant queues receipt')
local dispatched,queuedName=0,nil
GameFunc.GetEventScriptID=function() return queuedName end
GameFunc.RunScene=function(_,name) dispatched=dispatched+1;queuedName=name end
h.event('DrawMenuAfter');eq(dispatched,0,'never interrupt battle')
h.event('Battle_RestoreItem');h.field=nil
queuedName='UnrelatedScene';h.event('DrawMenuAfter');eq(dispatched,0,'wait for another Scene')
queuedName=nil;GameFunc.InBattle=true;h.event('DrawMenuAfter');eq(dispatched,0)
GameFunc.InBattle=false;h.event('DrawMenuAfter');eq(dispatched,1);eq(queuedName,'CDK_RewardReceipt')
h.event('DrawMenuAfter');h.event('InputClick',0,73);eq(dispatched,1,'no double dispatch or challenge during receipt')
assert(SWD3CaiDemonKing.Reward.PendingReceipt(),'dispatch alone does not consume receipt')
Scene[queuedName]();queuedName=nil
assert(h.menuRows[1]:find('Received:',1,true),'system reward receipt')
eq(h.menuRows[2],'Return to inventory    ')
assert(not SWD3CaiDemonKing.Reward.PendingReceipt())
h.event('DrawMenuAfter');eq(dispatched,1,'receipt shown once')
eq(SWD3CaiDemonKing.Reward.Count(),1,'receipt never grants again')
for _,clear in ipairs({'GameStart','MapLoading','save switch'}) do
    h=fresh()
    SaveData.Items={{ItemTempID=11006,Count=1,Count_New=0}}
    local r=SWD3CaiDemonKing.Reward
    r.pendingReceipt={save=SaveData,id=11006,count=1}
    if clear=='save switch' then SaveData={Items={}} else h.event(clear) end
    Scene.CDK_RewardReceipt()
    assert(not r.PendingReceipt(),'stale receipt cleared: '..clear)
    assert(not h.menuRows,'no stale reward notice')
end
print('PASS: confirmed reward receipt after cleanup, Scene guards, one-time display and save isolation')

local function freeBattle(low,reverse,single)
    return scripted(function(ctx)
        local live=root..'/../swd3-live-card-battle-mod/src/data/'
        for _,name in ipairs({'CardBattleRules.lua','LiveCardPartyState.lua','LiveCardInventory.lua','LiveCardBattle.lua'}) do
            assert(loadfile(live..name))()
        end
        if reverse then
            for _,handlers in pairs(OnEvent) do
                for i=1,math.floor(#handlers/2) do handlers[i],handlers[#handlers-i+1]=handlers[#handlers-i+1],handlers[i] end
            end
        end
        GameData.ItemTemp[101]={Name='Slime',IT_12=true,isBattleChar=true,ACT=101,Level=12,
            HP=1000,ATK=100,DEF=100,SPD=30,WIS=40,GainEXP=10,GainGold=1}
        SaveData.Items={{ItemTempID=101,Count=1,Count_New=0},{ItemTempID=632,Count=2,Count_New=0}}
        ItemClass.DelItem=function(slot,id,n)
            eq(SaveData.Items[slot].ItemTempID,id)
            SaveData.Items[slot].Count=SaveData.Items[slot].Count-n
        end
        local rules=SWD3LiveCardBattle.Rules
        local draft=rules.NewMenuState()
        if not single then assert(rules.AdjustMenuCard(draft,{source='owned',slot=1,itemId=101,name='Slime',available=1},1)) end
        assert(rules.AdjustMenuCard(draft,{source='virtual',itemId=438,name='Cai',available=5},single and 1 or 2))
        draft.difficulty.hp=low and 0.5 or 1.2
        SWD3LiveCardBattle.State.draft=draft
        ESC.StartBattle=function(id)
            ctx.field=id;ctx.starts=ctx.starts+1
            BattleEnemys={};BattleEnv.enemys={};BattleEnv.players={}
            for i,entry in ipairs(BattleField[id].tCharActQ) do
                local source=GameData.ItemTemp[entry.ItemTempID]
                local status={Level=source.Level,ItemType=entry.ItemTempID==11001 and 32 or 0,
                    HP=source.HP,MaxHP=source.HP,ATK=source.ATK,DEF=source.DEF,SPD=source.SPD,WIS=source.WIS}
                local actor={NPC_GUID=entry.ItemTempID,NPCData=status,IsCrazy=function() return false end,
                    IsFreeze=function() return false end}
                BattleEnemys[i]=actor;BattleEnv.enemys[i]={GUID=entry.ItemTempID,self=actor,status=status}
                ctx.event('Battle_EnemyInit',i)
            end
            for i,p in ipairs(BattlePlayers) do
                p.isHide=function() return false end
                BattleEnv.players[i]={isPlayer=true,self=p,status=p.CharData}
                ctx.event('Battle_PlayerInit',i)
            end
        end
        ctx.menu=function()
            ctx.choices={6}
            local originalMenu=ESC.Menu
            ESC.Menu=function(...)
                assert(#ctx.choices>0,table.concat(ctx.logs,'\n'))
                return originalMenu(...)
            end
            Scene.LCB_LiveCardBattleMenu()
            assert(ctx.starts==1,table.concat(ctx.logs,'\n'))
        end
    end)
end
for _,reverse in ipairs({false,true}) do
    h=freeBattle(false,reverse)
    h.step('run');eq(#h.lines,0,'mixed opening silent');eq(h.disabled,nil,'native mixed enemies are not held')
    eq(SaveData.SWD3CaiDemonKing,nil,'mixed battles do not advance dialogue history')
    eq(BattleEnemys[2].NPCData.HP,96000,'F9 applies HP multiplier to formal Cai')
    eq(BattleEnemys[3].NPCData.HP,96000,'repeated Cai gets same base and multiplier')
    eq(SaveData.Items[1].Stock,1,'F9 keeps ordinary owned enemy reservation')
    eq(SWD3LiveCardBattle.PartyState.Pending(),false,'F9 does not duplicate party snapshot')
    for _,index in ipairs({2,3}) do
        BattleEnemys[index].NPCData.HP=40000
        h.event('BattleEnemyAI',index);eq(BattleEnemys[index].AI_SelectItem,0,'each Cai opens separately')
        h.event('BattleEnemyAI',index);eq(BattleEnemys[index].AI_SelectItem,11005,'each Cai heals once')
        h.event('BattleEnemyAI',index);eq(BattleEnemys[index].AI_SelectItem,11004,'each Cai has its own pressure cycle')
    end
    h.step('run');eq(#h.lines,0,'mixed phase and heal silent')
    ItemClass.DelItem(2,632,1,0);eq(SaveData.Items[2].Count,1,'item paid during mixed battle')
    for _,index in ipairs({2,3}) do BattleEnemys[index].NPCData.HP=0;h.event('Battle_Dead',index,1,0) end
    h.event('BattleGain');eq(h.grants,nil,'Cai defeat cannot reward while another enemy remains')
    h.step('run');eq(h.wins,nil,'script never wins early')
    BattleEnemys[1].NPCData.HP=0;h.event('Battle_Dead',1,1,0)
    h.event('BattleGain');eq(h.grants,1,'whole enemy side cleared grants once')
    h.event('Battle_RestoreItem');h.event('Battle_RestoreItem')
    eq(SaveData.Items[2].Count+(SaveData.Items[2].Count_New or 0),2,'mixed refund occurs exactly once')
    eq(SaveData.Items[1].Stock,nil,'mixed reservation released')
    eq(BattlePlayers[1].CharData.HP,0,'mixed exit restores original dead player')
    eq(SWD3LiveCardBattle.State.activeChallenge,nil,'F9 cleaned up')
    eq(SWD3CaiDemonKing.state.active,false,'Cai cleaned up')
    eq(#h.lines,0,'mixed victory silent')
end
for _,outcome in ipairs({'low','defeat','removed','map','save','invalid'}) do
    h=freeBattle(outcome=='low',false);h.step('run')
    if outcome=='defeat' then
        for _,p in pairs(BattleEnv.players) do p.status.HP=0 end
        h.event('Battle_Dead',1,0,0);h.step(nil);eq(h.breaks,1)
    elseif outcome=='removed' then
        h.event('Battle_Dead',2,1,2);h.step(nil);eq(h.breaks,1)
    elseif outcome=='map' then h.event('MapLoading');h.step(nil)
    elseif outcome=='save' then SaveData={Items={}};h.step(nil);h.event('MapLoading')
    elseif outcome=='invalid' then
        GameData.AttackEffect[11003].iAttackPoint=1;h.step(nil);eq(h.breaks,1)
    else
        for index,enemy in pairs(BattleEnemys) do enemy.NPCData.HP=0;h.event('Battle_Dead',index,1,0) end
        h.event('BattleGain');h.event('Battle_RestoreItem')
    end
    eq(h.grants,nil,outcome..' cannot grant reward');eq(#h.lines,0,outcome..' is silent')
end
h=freeBattle(false,false,true);h.step('dialogue');h.step('dialogue');h.step('run')
eq(SWD3CaiDemonKing.state.mixed,false,'single F9 Cai retains full dialogue')
BattleEnemys[1].NPCData.HP=0;h.step('dialogue');h.step('dialogue');h.step(nil)
eq(h.grants,1,'single F9 formal victory reward')
print('PASS: integrated F9 mixed Cai, silence, independent AI, difficulty, whole-side victory, one refund, cleanup and handler orders')
