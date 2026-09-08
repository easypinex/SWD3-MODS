local MOD = assert(SWD3CaiDemonKing)
assert(MOD.dataInstalled, '[CaiDemonKing] data must load first')
assert(MOD.challengeTemplate, '[CaiDemonKing] challenge data must load first')
local ENEMY = MOD.challengeId
local FIELD = 'CDK_CAI_CHALLENGE'
local S = MOD.state or {lastMenuTick=-10000}
local Party=assert(MOD.PartyState,'CaiPartyState must load first')
local Inventory=assert(MOD.Inventory,'CaiInventory must load first')
local CombatAI=assert(MOD.CombatAI,'CaiDemonAI must load first')
local Reward=assert(MOD.Reward,'CaiReward must load first')
local Dialogue=assert(MOD.Dialogue,'CaiDialogue must load first')
local FairPlay=assert(MOD.FairPlay,'CaiFairPlay must load first')
MOD.state = S
local runBattleScript
local fallback = {
    CDK_TITLE='Cai Demon King', CDK_BACK='Return', CDK_START='Start challenge',
    CDK_INFO='Lv99 / HP80000',
    CDK_RECEIPT_TITLE='Challenge reward',
    CDK_RECEIPT_ITEM='Received: Cai Demon King True Pact x1',
    CDK_RECEIPT_BACK='Return to inventory',
    CDK_DETAIL='Early: after three pool choices, heavy strike then attack. Below 60%: heavy, dark, attack, light. One heal: 6000 x 2.',
    CDK_ERROR='Challenge could not start. Check Console.',
    CDK_CONFLICT='Cai data was changed by another MOD. Restart with compatible MODs.',
    CDK_HINT_ONE='The Light Tower, the Dark Vessel... Good things reward care. Their finer qualities emerge with practice.',
    CDK_HINT_TWO='Phoenix and Nike are old friends too. With such company close at hand, a long journey feels easier.',
    CDK_PHASE_TWO='I always thought a stroke here, a passage there, could be better still. Perhaps I earned the Demon King name.',
    CDK_OPEN_ONE='After all these years, you still remember this place. Come closer. Let me have a look at you.',
    CDK_OPEN_TWO='When the Tun Town demo came out, over five hundred letters arrived in just days. That was when we knew someone was waiting.'
}
local function write(s)
    if type(log)=='function' then log('[CaiDemonKing] '..s) end
end
local function text(key)
    if type(StringDB)=='function' then
        local value=StringDB(key)
        if type(value)=='string' and value~='' and value~=key then return value end
    end
    return fallback[key] or Dialogue.fallback[key] or key
end
local function currentField()
    return GameFunc and type(GameFunc.GetBattleFieldID)=='function' and GameFunc.GetBattleFieldID() or nil
end
local function ownBattle() return S.active and currentField()==FIELD and S.entrySave==SaveData end
local function reset(reason)
    if reason=='game start' or reason=='map loading' or reason=='new challenge' then
        Reward.ClearReceipt(); S.receiptQueued=nil
    end
    Inventory.Restore(reason,reason=='game start')
    Party.Restore(reason,reason=='game start')
    if S.active then write('finished: '..reason) end
    S.active=false; S.menu=false; S.noOver=false; S.breakRequested=false; S.seenSkills={}
    S.entered=false; S.outcome=nil; S.enemyRemoved=false; S.lastIdentity=nil
    S.scriptActive=false; S.defeatDialogueShown=false
    S.removalMode=nil; S.victoryProved=false; S.victoryRequested=false
    S.rewardAttempted=false; S.phaseDialogueShown=false
    S.manualSummon=false
    S.dialogue=nil;S.entrySave=nil;S.healDialoguePending=nil;S.healDialogueShown=nil
    S.fairBlocked=nil;S.fairDetail=nil
    S.partyError=nil
    S.lastOffensiveSkill=nil
    S.combat={}
    S.combats={}; S.expectedEnemies=nil; S.removedEnemies={}
    S.mixed=false; S.rewardsAllowed=true
end
local function finish(reason)
    reset(reason)
end
local function menu(keys,title)
    local rows={}
    for i,key in ipairs(keys) do rows[i]=text(key)..'    ' end
    ESC.Menu(text(title or 'CDK_TITLE'),rows)
    return ESC.GetMENUSelect()
end
local function ready()
    local t=GameData.ItemTemp[ENEMY]
    return t and t==MOD.challengeTemplate and t.ACT==438 and MOD.actions~=nil
        and t.IT_06==true and not t.IT_12 and t.Level==99 and t.HP==80000
        and t.ATK==950 and t.DEF==350 and t.SPD==150 and t.WIS==220
        and GameData.ItemTemp[11006]==MOD.rewardTemplate
        and t.Skills and t.Skills[1]==11002 and t.Skills[2]==11003
        and GameData.ItemTemp[11002]==MOD.challengeSkills[11002]
        and GameData.ItemTemp[11003]==MOD.challengeSkills[11003]
        and GameData.ItemTemp[11002].AttackEffect==11002
        and GameData.ItemTemp[11003].AttackEffect==11003
        and GameData.AttackEffect[11002]==MOD.challengeEffects[11002]
        and GameData.AttackEffect[11003]==MOD.challengeEffects[11003]
        and GameData.AttackEffect[11002].iAttackPoint==3000
        and GameData.AttackEffect[11003].iAttackPoint==3200
        and t.Skills[3]==11004 and t.Skills_QQ and t.Skills_QQ[3]==44
        and GameData.ItemTemp[11004]==MOD.challengeSkills[11004]
        and GameData.ItemTemp[11004].AttackEffect==11004
        and GameData.ItemTemp[11004].ACT==6145
        and GameData.AttackEffect[11004]==MOD.challengeEffects[11004]
        and GameData.AttackEffect[11004].iAttackPoint==4200
        and GameData.AttackEffect[11004].iAttr==9
        and GameData.AttackEffect[11004].iActionFX_ACT==6145
        and GameData.ItemTemp[11005]==MOD.challengeSkills[11005]
        and GameData.ItemTemp[11005].AddHP==6000
        and GameData.ItemTemp[11005].ATK_Count==2
        and GameData.ItemTemp[11005].ACT==11005
        and GameData.ItemTemp[11005].AttackEffect==11005
        and GameData.AttackEffect[11005]==MOD.challengeEffects[11005]
        and GameData.AttackEffect[11005].iActionFX_ACT==11005
        and t.SP_AttackEffects==nil and t.Skills_QQ and t.Skills_QQ[1]==44
        and t.Skills_QQ[2]==44 and t.CR_Skills and t.CR_Skills[1]==11005
        and t.CR_Skills_QQ and t.CR_Skills_QQ[1]==44
end
local function startBattle(manualSummon,customField,rewardsAllowed)
    if not ready() then menu({'CDK_BACK','CDK_CONFLICT','CDK_BACK'}); return false end
    BattleField[FIELD]=customField or {
        iBattleFieldBackground=4, MusicFileName='Battle_Europa01.mp3',
        tCharActQ={{ItemTempID=ENEMY,X=176,Y=294}}
    }
    BattleScript=BattleScript or {}
    BattleScript[FIELD]=runBattleScript
    reset('new challenge')
    S.expectedEnemies={}
    for index,entry in ipairs(BattleField[FIELD].tCharActQ) do S.expectedEnemies[index]=entry.ItemTempID end
    S.mixed=#S.expectedEnemies>1
    S.rewardsAllowed=rewardsAllowed~=false
    S.entrySave=SaveData
    S.manualSummon=manualSummon==true
    local prepared,preparationError=pcall(function() Inventory.Begin(write);Party.Begin(write) end)
    if not prepared then
        reset('preparation failed');write(tostring(preparationError));menu({'CDK_BACK','CDK_ERROR','CDK_BACK'});return false
    end
    S.battleSerial=(S.battleSerial or 0)+1
    S.active=true; S.seenSkills={}
    -- StartBattle can terminate its calling Scene coroutine.
    S.menu=false
    write('start: Item'..ENEMY..'; Lv99 HP80000 SPD150; points 3000/3200/4200; one heal 12000; pressure cycle')
    local ok,err=pcall(ESC.StartBattle,FIELD)
    if not ok then
        reset('start failed'); write(tostring(err)); menu({'CDK_BACK','CDK_ERROR','CDK_BACK'})
        return false
    elseif currentField()~=FIELD then finish('returned from battle') end
    return true
end
-- F9 owns selection/reservations/difficulty; Cai owns party, inventory and combat.
function MOD.StartFreeChallenge(field,rewardsAllowed)
    assert(not S.active and not S.menu,'Cai challenge is busy')
    assert(type(field)=='table' and type(field.tCharActQ)=='table','invalid challenge field')
    assert(#field.tCharActQ>=1 and #field.tCharActQ<=5,'invalid enemy count')
    local found=false
    for _,entry in ipairs(field.tCharActQ) do
        assert(type(entry)=='table' and GameData.ItemTemp[entry.ItemTempID],'missing enemy')
        if entry.ItemTempID==ENEMY then found=true end
    end
    assert(found,'Cai required')
    return startBattle(false,field,rewardsAllowed)
end
MOD.freeChallengeVersion=1
MOD.freeChallengeField=FIELD
Scene.CDK_ChallengeMenu=function()
    if S.menu or S.active then return end
    S.menu=true
    local ok,err=pcall(function()
        while true do
            local rows={'CDK_BACK','CDK_INFO','CDK_START','CDK_BACK'}
            local selected=menu(rows)
            if selected==3 then startBattle(); return end
            if selected==2 then
                if menu({'CDK_BACK','CDK_DETAIL','CDK_LIMITS','CDK_BACK'})==3 then
                    menu({'CDK_BACK','CDK_LIMIT_DETAIL_ONE','CDK_LIMIT_DETAIL_TWO','CDK_BACK'})
                end
            else return end
        end
    end)
    S.menu=false
    if not ok then write('menu error: '..tostring(err)) end
end
-- A system receipt, not character dialogue. Enter only after confirmed settlement.
-- Use the native Scene return path to rebuild the inventory UI (manual QA required).
Scene.CDK_RewardReceipt=function()
    S.receiptQueued=nil
    if S.active or S.menu or not Reward.PendingReceipt() then return end
    Reward.ClearReceipt() -- consume on actual entry, never on a merely requested dispatch
    write('reward receipt entered: Item11006 x1')
    S.menu=true
    local ok,err=pcall(menu,{'CDK_RECEIPT_ITEM','CDK_RECEIPT_BACK'},'CDK_RECEIPT_TITLE')
    S.menu=false
    if ok then write('reward receipt closed; native inventory rebuild requested')
    else write('reward receipt error: '..tostring(err)) end
end
local function hook(name,fn)
    OnEvent[name]=OnEvent[name] or {}; table.insert(OnEvent[name],fn)
end
local function readMember(object,key)
    local ok,value=pcall(function() return object[key] end)
    return ok and value or nil
end
local function requestBreak()
    if S.breakRequested or not ownBattle() then return end
    S.breakRequested=true
    S.victoryRequested=false
    write('requesting native BattleBreak; outcome='..tostring(S.outcome))
    local ok,err=pcall(BSC.BattleBreak)
    if not ok then S.outcome=nil; write('BattleBreak failed: '..tostring(err)) end
end
local function battleLine(key)
    write('battle dialogue opening: '..key)
    -- AutoPrint is the original BSC.Print wrapper, called only by BattleScript.
    BattleScript.AutoPrint(Const.BMS1,9005,50,30,'%C4%S0'..text(key))
    write('battle dialogue closed: '..key)
end
local function allEnemiesCleared()
    local found=false
    for index,id in pairs(S.expectedEnemies or {}) do
        found=true
        local mode=S.removedEnemies[index]
        if id==ENEMY and mode~=nil and mode~=0 then return false end
        if mode==nil then
            local enemy=BattleEnemys and BattleEnemys[index]
            local status=enemy and readMember(enemy,'NPCData')
            local hp=status and tonumber(readMember(status,'HP'))
            if not enemy or readMember(enemy,'NPC_GUID')~=id or not hp or hp>0 then return false end
        end
    end
    return found
end
runBattleScript=function()
    if not S.active then return end
    local serial=S.battleSerial
    local function thisBattle() return S.battleSerial==serial and ownBattle() end
    S.scriptActive=true
    write('native BattleScript entered')
    local ok,err=pcall(function()
        if S.mixed then
            -- Native victory handles the whole enemy side. No held corpses,
            -- character lines, attempt counter, or early BSC.Win in mixed teams.
            BSC.Enter(1)
            while thisBattle() and not S.breakRequested do
                if S.outcome=='defeat' or (S.removalMode~=nil and S.removalMode~=0)
                    or not FairPlay.Check(S,ready,BattleEnv and BattleEnv.players,write) then
                    requestBreak(); return
                end
                BSC.Run(1)
            end
            return
        end
        -- Original BS164/BS165 hold the defeated enemy for dialogue this way.
        BSC.SetDisable(Const.BMS1)
        BSC.Enter(1)
        if not thisBattle() or not S.noOver or S.breakRequested then return end
        local function fair()
            if not thisBattle() then return false end
            return FairPlay.Check(S,ready,BattleEnv and BattleEnv.players,write)
        end
        local function invalidMatch()
            S.outcome='invalid';S.victoryRequested=false;S.victoryProved=false
            battleLine(FairPlay.lines[S.fairBlocked] or 'CDK_FAIR_RULES')
            if not thisBattle() then return end
            battleLine('CDK_FAIR_END')
            if thisBattle() then requestBreak() end
        end
        if not fair() then invalidMatch();return end
        local dialogue=Dialogue.Begin(S,SaveData,BattleEnv and BattleEnv.players,GetTicks())
        write('dialogue branch: '..dialogue.branch..'; attempt='..dialogue.attempt)
        for _,key in ipairs(dialogue.opening) do
            battleLine(key)
            if not thisBattle() then return end
            if not fair() then invalidMatch();return end
        end
        if S.manualSummon then
            battleLine('CDK_SUMMON_INFO')
            if not thisBattle() then return end
        end
        while thisBattle() and not S.breakRequested do
            if not fair() then invalidMatch();return end
            if S.outcome=='defeat' then
                local hints=Dialogue.Defeat(S,SaveData)
                battleLine(hints[1])
                if not thisBattle() or S.enemyRemoved then return end
                if not fair() then invalidMatch();return end
                battleLine(hints[2])
                if not thisBattle() or S.enemyRemoved then return end
                S.defeatDialogueShown=true
                requestBreak()
                return
            end
            if S.removalMode~=nil and S.removalMode~=0 then requestBreak();return end
            local enemy=BattleEnemys and BattleEnemys[1]
            local status=enemy and readMember(enemy,'NPCData')
            local hp=status and tonumber(readMember(status,'HP'))
            if enemy and readMember(enemy,'NPC_GUID')==ENEMY and hp and hp<=0 then
                S.victoryProved=true;S.enemyRemoved=true;S.outcome='victory'
                local function stillWon()
                    return thisBattle() and fair() and not S.breakRequested and S.outcome=='victory'
                        and (S.removalMode==nil or S.removalMode==0)
                end
                battleLine(dialogue.win)
                if not stillWon() then
                    if thisBattle() then if S.fairBlocked then invalidMatch() else requestBreak() end end
                    return
                end
                if S.rewardsAllowed then battleLine(Reward.Count()>0 and dialogue.owned or dialogue.reward) end
                if not stillWon() then
                    if thisBattle() then if S.fairBlocked then invalidMatch() else requestBreak() end end
                    return
                end
                S.victoryRequested=true
                BSC.Win()
                return
            end
            if S.combat.phase==2 and not S.phaseDialogueShown then
                S.phaseDialogueShown=true
                dialogue.middleCount=dialogue.middleCount+1
                battleLine(dialogue.phase)
                if not thisBattle() then return end
            elseif S.healDialoguePending and not S.healDialogueShown then
                S.healDialogueShown=true
                if dialogue.middleCount<dialogue.middleLimit then
                    dialogue.middleCount=dialogue.middleCount+1
                    battleLine(dialogue.heal)
                    if not thisBattle() then return end
                end
            end
            -- Native script resume point; not a per-character action counter.
            BSC.Run(1)
        end
    end)
    if S.battleSerial==serial then S.scriptActive=false end
    if not ok then
        write('battle dialogue error: '..tostring(err))
        -- Do not strand a NoOVER battle if the new dialogue path fails.
        if thisBattle() then requestBreak() end
    end
end
local function diagnostic(index,full)
    local enemy=BattleEnemys and BattleEnemys[index]
    if not enemy or readMember(enemy,'NPC_GUID')~=ENEMY then return end
    local status=readMember(enemy,'NPCData')
    if not status then write('readback unavailable: NPCData'); return end
    local level=readMember(status,'Level')
    local flags=tonumber(readMember(status,'ItemType'))
    local boss=flags and math.floor(flags/32)%2==1 or false
    local identity=tostring(level)..'/'..tostring(flags)
    if full or S.lastIdentity~=identity then
        write('readback: source='..ENEMY..'; Level='..tostring(level)..'; Boss='..tostring(boss)
            ..'; ItemType='..tostring(flags))
        S.lastIdentity=identity
    end
    if full then
        local values={}
        for _,key in ipairs({'HP','MaxHP','ATK','DEF','SPD','WIS','DodgeRate','AttrDark','AttrWind'}) do
            values[#values+1]=key..'='..tostring(readMember(status,key))
        end
        write('readback stats: '..table.concat(values,'; '))
    end
    if level~=99 or not boss then
        if not S.identityWarning then write('WARNING: independent Lv99/Boss invariant failed') end
        S.identityWarning=true
    end
end
if not MOD.eventsRegistered then
    hook('GameStart',function()
        reset('game start'); S.lastMenuTick=-10000; S.lastKeyTick=nil
        write('v1.8 loaded; bounded phase-one heavy strike and recovery; F9 mixed bridge')
        local card=GameData.ItemTemp[10096]
        write('references ready='..tostring(ready())..'; card10096 ACT='..tostring(card and card.ACT))
    end)
    hook('DrawMenuAfter',function()
        S.lastMenuTick=GetTicks()
        if Party.Pending() and not S.active then Party.Restore('inventory recovery') end
        if S.active and currentField()~=FIELD then finish('inventory recovery') end
        if not S.active and not S.menu and not S.receiptQueued and Reward.PendingReceipt()
            and not GameFunc.InBattle and type(GameFunc.GetEventScriptID)=='function'
            and GameFunc.GetEventScriptID()==nil then
            S.receiptQueued=true; S.lastMenuTick=-10000
            local ok,err=pcall(GameFunc.RunScene,-1,'CDK_RewardReceipt',0)
            if not ok then S.receiptQueued=nil;write('reward receipt dispatch failed: '..tostring(err)) end
        end
    end)
    local function onKey(_,key)
        if key~=73 or S.menu or S.active or S.receiptQueued or GetTicks()-S.lastMenuTick>250 then return false end
        if S.lastKeyTick and GetTicks()-S.lastKeyTick<400 then return false end
        S.lastKeyTick=GetTicks()
        -- Reserve before dispatch, so repeated input cannot queue a second Scene.
        S.lastMenuTick=-10000
        local ok,err=pcall(GameFunc.RunScene,-1,'CDK_ChallengeMenu',0)
        if not ok then S.menu=false; write('scene error: '..tostring(err)) end
        return true
    end
    hook('InputKeyDown',onKey)
    hook('InputClick',onKey)
    hook('Battle_PlayerInit',function(index)
        if not ownBattle() then return end
        local ok,err=pcall(Party.Init,index)
        if not ok then S.partyError=tostring(err); write('party preparation failed: '..S.partyError) end
        if ok then FairPlay.Entry(S,BattlePlayers[index],index,write) end
    end)
    hook('Battle_Enter',function()
        if not ownBattle() then return end
        S.entered=true; S.identityWarning=false
        local ok,err=pcall(BSC.NoOVER)
        S.noOver=ok
        if not ok then
            write('NoOVER failed; aborting validation battle: '..tostring(err))
            S.breakRequested=true
            local stopped,failure=pcall(BSC.BattleBreak)
            if not stopped then write('BattleBreak failed: '..tostring(failure)) end
            return
        end
        local prepared,failure=pcall(Party.Enter)
        if not prepared or S.partyError then
            write('party preparation error: '..tostring(S.partyError or failure))
            requestBreak(); return
        end
        for index in pairs(BattleEnv and BattleEnv.enemys or {}) do diagnostic(index,true) end
    end)
    -- Replace the native choice only for our own enemy/field. No yielding here.
    hook('BattleEnemyAI',function(index)
        if not ownBattle() then return end
        local data=BattleEnv and BattleEnv.enemys and BattleEnv.enemys[index]
        if not data or data.GUID~=ENEMY or not data.self then return end
        if S.breakRequested or S.enemyRemoved or S.outcome=='defeat'
            or not FairPlay.Check(S,ready,BattleEnv.players,write) then
            data.self.AI_Command=-1; data.self.RestorHP=0; return
        end
        diagnostic(index,false)
        local memory=S.combat
        if S.mixed then
            S.combats[index]=S.combats[index] or {}
            memory=S.combats[index]
        end
        local ok,id,reason=pcall(CombatAI.Select,memory,data,index,BattleEnv.players)
        if not ok then
            data.self.AI_Command=-1
            write('strategy error: '..tostring(id)); requestBreak(); return
        end
        if id==nil then return end
        if id==11005 then S.healDialoguePending=true end
        S.seenSkills[id]=true
        write('strategy selected: '..tostring(id)..'; '..reason..'; phase='..tostring(memory.phase)
            ..'; healUsed='..tostring(memory.healUsed==true)
            ..'; oppositeSide='..tostring(data.self.AI_TargetIsEnemySide)
            ..'; target='..tostring(data.self.AI_Target)..'; animation='..tostring(data.self.Action_qq))
    end)
    hook('Battle_Dead',function(index,side,mode)
        if not ownBattle() then return end
        if side==1 then
            local enemy=BattleEnv and BattleEnv.enemys and BattleEnv.enemys[index]
            S.removedEnemies[index]=mode
            if enemy and enemy.GUID==ENEMY then
                if S.mixed and mode==0 then return end
                S.enemyRemoved=true; S.removalMode=mode
                if mode~=0 then S.outcome=nil;S.victoryRequested=false end
            end
            return
        end
        if side~=0 or mode~=0 or not S.noOver or S.breakRequested or S.enemyRemoved then return end
        local found=false
        for _,data in pairs(BattleEnv and BattleEnv.players or {}) do
            if data and data.isPlayer then
                found=true
                -- Ignore keepers/NPCs; never treat missing HP as a dead protagonist.
                local hp=tonumber(data.status and readMember(data.status,'HP'))
                if hp==nil or hp>0 then return end
            end
        end
        if not found then return end
        if S.outcome=='defeat' then return end
        S.outcome='defeat'
        if S.scriptActive then
            write('party defeated; dialogue queued in BattleScript before exit')
        else
            -- Recovery for a battle whose script never started. No yielding here.
            write('party defeated without active BattleScript; using return fallback')
            requestBreak()
        end
    end)
    hook('BattleGain',function()
        if not ownBattle() then return end
        if S.mixed and not S.breakRequested and not S.fairBlocked and S.outcome~='defeat'
            and allEnemiesCleared() and FairPlay.Check(S,ready,BattleEnv and BattleEnv.players,write) then
            S.victoryProved=true; S.victoryRequested=true; S.outcome='victory'
        end
        Reward.Settle(S,write)
    end)
    hook('Battle_RestoreItem',function()
        if S.active then
            if ownBattle() then Reward.Settle(S,write) end
            finish('restore item')
        end
    end)
    hook('MapLoading',function()
        reset('map loading'); S.lastMenuTick=-10000
    end)
    MOD.eventsRegistered=true
end
