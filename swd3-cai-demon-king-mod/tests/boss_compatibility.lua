local root=arg[1]
local function eq(a,b,msg) assert(a==b,(msg or '')..' expected '..tostring(b)..', got '..tostring(a)) end
local function loadCai(name) assert(loadfile(root..'/src/data/'..name))() end
local function loadCapture()
    assert(loadfile(root..'/../swd3-all-monster-static-capture-mod/src/data/AllMonsterCaptureRuntime.lua'))()
end
local function event(name,...) for _,fn in ipairs(OnEvent[name] or {}) do fn(...) end end
for _,captureFirst in ipairs({false,true}) do
    OnEvent={}; SWD3CaiDemonKing=nil
    log=function() end
    local source={ACT=438,Race=1,Level=99,HP=10000}
    local normal={ACT=12,Race=1,Level=20}
    local card={ACT=438,IT_12=true,HP=16000}
    GameData={ItemTemp={[438]=source,[12]=normal,[10096]=card},Race={[1]={catch=false}}}
    assert(loadfile(root..'/tests/skill_fixture.lua'))()
    SaveData={Items={}}
    SWD3AllMonsterStaticCatalogue={entries={[438]={raceId=1,staticCard=true,cardId=10096},[12]={raceId=1}}}
    SWD3AllMonsterStaticCapture={staticCards={[10096]=card}}
    if captureFirst then loadCapture() end
    loadCai('CaiDemonActions.lua'); loadCai('CaiDemonData.lua'); loadCai('CaiDemonChallengeData.lua')
    if not captureFirst then loadCapture() end
    eq(source.IT_06,true); eq(card.IT_06,nil)
    event('GameStart')
    local runtime=SWD3AllMonsterStaticCapture.captureRuntime
    eq(runtime.active.sources[438].IT_06.value,true,'capture remembers Boss source')
    eq(source.IT_06,nil,'map capture eligibility bridge')
    loadCai('CaiDemonData.lua')
    eq(source.IT_06,nil,'duplicate load does not fight capture bridge')
    eq(SWD3CaiDemonKing.originals[source].IT_06.value,nil,'snapshot not overwritten')
    BattlePlayers={{CharData={Level=59}}}
    _BattleEnv={EnemyIDMax=3,NowMenu=1}
    BattleEnv={enemys={}}
    BattleEnemys={{NPC_GUID=438,NPCData={ItemType=0xA00,Level=99}},
        {NPC_GUID=12,NPCData={ItemType=0x800,Level=20}},
        {NPC_GUID=11001,NPCData={ItemType=0x20,Level=99,HP=80000,MaxHP=80000}}}
    local status=BattleEnemys[1].NPCData
    for round=1,2 do
        event('Battle_Enter')
        eq(status.Level,70,'existing level cap retained')
        eq(status.ItemType,0xA00,'initial capture window')
        eq(runtime.active.battleBossFlags[1].sourceId,438)
        eq(runtime.active.battleBossFlags[2],nil,'normal enemy not tracked')
        eq(runtime.active.baselines[11001],nil,'independent source outside bridge')
        eq(runtime.active.battleBossFlags[3],nil,'independent Boss not tracked')
        eq(runtime.active.battleLevelCaps[3],nil,'independent level not capped')
        event('BattlePlayerAI_after',2)
        eq(status.ItemType,0xA20,'non-Seth executor restores only Boss bit')
        _BattleEnv.NowMenu=3; event('Battle_InputKeyDown')
        eq(status.ItemType,0xA00,'capture targeting clears Boss bit')
        event('BattlePlayerAI_after',1)
        eq(status.ItemType,0xA00,'Seth retains capture window')
        event('BattlePlayerAI_after',2)
        eq(status.ItemType,0xA20)
        eq(BattleEnemys[2].NPCData.ItemType,0x800,'unrelated enemy untouched')
        eq(card.IT_06,nil,'guardian untouched')
        eq(BattleEnemys[3].NPCData.Level,99,'independent true Level99')
        eq(BattleEnemys[3].NPCData.ItemType,0x20,'independent Boss unchanged across input windows')
        eq(BattleEnemys[3].NPCData.HP,80000)
        event('Battle_RestoreItem')
        eq(status.ItemType,0xA00,'original full ItemType restored')
        eq(status.Level,99)
        eq(GameData.ItemTemp[11001].IT_06,true)
        eq(BattleEnemys[3].NPCData.Level,99)
        eq(BattleEnemys[3].NPCData.ItemType,0x20)
        eq(runtime.active.sources[438].IT_06.value,true,'post-battle bridge remembers Boss')
    end
    event('MapLoading'); eq(source.IT_06,true); eq(runtime.active,nil)
    eq(normal.IT_06,nil); eq(card.IT_06,nil); eq(GameData.Race[1].catch,false)
end
print('PASS: Cai Boss identity with actual capture runtime, both load orders, attack/capture windows and repeated cleanup')
