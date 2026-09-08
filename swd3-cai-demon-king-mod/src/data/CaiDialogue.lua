local MOD=assert(SWD3CaiDemonKing)
local D={}
MOD.Dialogue=D

D.fallback={
    CDK_LIMITS='Challenge limits',
    CDK_LIMIT_DETAIL_ONE='Protagonist entry limits: MaxHP 30000; MaxMP and MaxSP 10000 each.',
    CDK_LIMIT_DETAIL_TWO='ATK/DEF 5000 each; WIS 3000; SPD 500; Level 99. Keepers are excluded.',
    CDK_FAIR_STATS='I can see your strength. But this match has agreed limits; beyond them, it becomes a different matter.',
    CDK_FAIR_ITEMS='The supplies do not add up, and I cannot overlook that. I invited you here, so it is my responsibility to uphold the rules.',
    CDK_FAIR_RULES='Something has gone wrong with the rules. Let us stop while I work it out, before deciding a winner.',
    CDK_FAIR_VALUES='Those numbers are odd. Even a small detail deserves a proper explanation.',
    CDK_FAIR_END='No result or reward for this match. Once things are in order, you are welcome back any time.',
    CDK_REPEAT_ONE='Guo drew comics, and I wrote a programming column. Then we started making games together. Neither of us knew how far it would take us.',
    CDK_REPEAT_TWO='Those creatures from A-Fu began as ink on paper. Scanned and colored, they have kept you company for all these years.',
    CDK_REPEAT_THREE='Guocheng took his colleagues on outings and photographed even doorframes and moss. Even on a day out, the next scene was on their minds.',
    CDK_REPEAT_FOUR='Hongxiu later brought the old games to phones. Machines change, but someone still keeps a door open for the old stories. I am glad.',
    CDK_EQUIPPED_OPEN='Once I left my name on an autograph board; now I travel with you. That is good too. A little company on the road.',
    CDK_NOST_OPEN_ONE='Maoshou and Zhihao built their music on computers, passage by passage. Later, Maoshou said live instruments moved even him.',
    CDK_NOST_OPEN_TWO='Over the years, everyone has followed their own road. I treasure the chance to make new stories with a few old companions again.',
    CDK_NOST_PHASE='Maoshou wrote both music and stories. Years later, the music brings those people back. Some feelings are best left to a melody.',
    CDK_NOST_WIN_ONE='You used to write about the characters you loved and the things we could improve. I did not always say it, but those words mattered to me.',
    CDK_NOST_REWARD='At the end of a story, we always have to see you off. Let me come along this time. There are still old memories to share.',
    CDK_NOST_OWNED='You know these places well, yet you will walk through them with me again. Good. Let us take our time today.',
    CDK_HEAL_ONE='Guocheng said he used to draw until the studio lights went out. Time really does pass that way when you love what you do.',
    CDK_HEAL_TWO='Guo had drawings to finish and people to bring together. I used to keep things moving. Looking back, neither part was easy for him.',
    CDK_HINT_LIGHT='The Light Tower has a quiet glow. I have always liked things that protect people without drawing attention.',
    CDK_HINT_DARK='The Dark Vessel too. A fierce name, yet it can protect someone. Names do not always tell the whole story.',
    CDK_HINT_PHOENIX='Phoenix lends strength to your breath. A steadier journey leaves time to look at the scenery along the way.',
    CDK_HINT_NIKE='The strength of Nike is not in her fists. Those light steps remind me of you travelling in search of everyone.',
    CDK_HINT_ARMOR='Reviewing artwork, I could spend ages on a single seam in a suit of armor. Some old habits never leave.',
    CDK_HINT_GUARD='Each guardian has its strengths. Back then, we each looked after our own part to bring this journey into being.',
    CDK_WIN_REPEAT='I am glad to see you again. I do not say that often... But I wanted you to know.',
    CDK_OWNED_REPEAT='I used to hurry everyone toward the finish. There is no rush this time. Stay a little longer if you like.',
    CDK_SUMMON_INFO='Please bring out your two travelling companions too. Company makes a long road a little easier.',
    CDK_WIN_ONE='I always hoped we could do a little better each time. Seeing you return makes me feel that all that care reached someone.',
    CDK_WIN_REWARD='All right, I will come with you. I would like another look at those familiar places myself.',
    CDK_WIN_OWNED='I am already travelling with you. No need for another autograph. Come, let us see the scenery everyone left us.',
    CDK_PHYSICAL_NAME='Pruning Strike',
    CDK_PHYSICAL_HELP='A heavy physical strike against one target.',
}

local repeats={'CDK_REPEAT_ONE','CDK_REPEAT_TWO','CDK_REPEAT_THREE','CDK_REPEAT_FOUR'}
local hints={
    {'CDK_HINT_ONE','CDK_HINT_TWO'},
    {'CDK_HINT_LIGHT','CDK_HINT_DARK'},
    {'CDK_HINT_PHOENIX','CDK_HINT_NIKE'},
    {'CDK_HINT_ARMOR','CDK_HINT_GUARD'},
}
local function integer(value,default,maximum)
    if type(value)~='number' or value~=value or value<0 or value>maximum then return default end
    return math.floor(value)
end
-- Schrage form keeps intermediates within signed 32 bits, including Fengari.
-- This private stream never calls math.random or changes the battle RNG seed.
function D.NextSeed(seed)
    local nextSeed=16807*(seed%127773)-2836*math.floor(seed/127773)
    if nextSeed<=0 then nextSeed=nextSeed+2147483647 end
    return nextSeed
end
function D.Equipped(save,players)
    for _,p in pairs(players or {}) do
        local role=p and p.GUID
        if p and p.isPlayer and type(role)=='number' and role>=1 and role<=4 then
            local equipment=save and save.PlayerEqu and save.PlayerEqu[role]
            for _,slot in ipairs({8,9}) do
                local item=equipment and equipment[slot]
                if item and item.ItemTempID==11006 then return true end
            end
        end
    end
    return false
end
function D.Plan(attempt,roll,equipped)
    local nostalgic=attempt>=3 and roll<=30
    local opening
    if equipped then opening={'CDK_EQUIPPED_OPEN'}
    elseif nostalgic then opening={'CDK_NOST_OPEN_ONE','CDK_NOST_OPEN_TWO'}
    elseif attempt==1 then opening={'CDK_OPEN_ONE','CDK_OPEN_TWO'}
    else opening={repeats[(attempt-2)%#repeats+1]} end
    return {
        branch=nostalgic and 'nostalgic' or 'reunion',opening=opening,
        phase=nostalgic and 'CDK_NOST_PHASE' or 'CDK_PHASE_TWO',
        heal=attempt%2==1 and 'CDK_HEAL_ONE' or 'CDK_HEAL_TWO',
        win=nostalgic and 'CDK_NOST_WIN_ONE' or (attempt==1 and 'CDK_WIN_ONE' or 'CDK_WIN_REPEAT'),
        reward=nostalgic and 'CDK_NOST_REWARD' or 'CDK_WIN_REWARD',
        owned=nostalgic and 'CDK_NOST_OWNED' or (attempt%2==1 and 'CDK_WIN_OWNED' or 'CDK_OWNED_REPEAT'),
    }
end
function D.Begin(state,save,players,ticks)
    if state.dialogue then
        assert(state.dialogue.save==save,'dialogue save changed')
        return state.dialogue
    end
    assert(type(save)=='table','dialogue save unavailable')
    local record=save.SWD3CaiDemonKing
    if record==nil then record={};save.SWD3CaiDemonKing=record end
    assert(type(record)=='table','dialogue save namespace conflict')
    assert(record.DialogueVersion==nil or record.DialogueVersion==1,'unsupported dialogue save version')
    local initial=integer(ticks,1,2147483646)%2147483646+1
    local seed=integer(record.Seed,initial,2147483646)
    if seed<1 then seed=initial end
    seed=D.NextSeed(seed)
    local attempt=integer(record.Attempts,0,1000000)+1
    if attempt>1000000 then attempt=1000000 end
    record.DialogueVersion=1;record.Attempts=attempt;record.Seed=seed
    record.Defeats=integer(record.Defeats,0,1000000)
    local dialogue=D.Plan(attempt,seed%100+1,D.Equipped(save,players))
    dialogue.save=save;dialogue.record=record;dialogue.attempt=attempt
    dialogue.middleCount=0
    -- Reserve the ending's two lines, including the optional manual-summon line.
    dialogue.middleLimit=math.min(2,6-#dialogue.opening-(state.manualSummon and 1 or 0)-2)
    state.dialogue=dialogue
    return dialogue
end
function D.Defeat(state,save)
    local d=assert(state.dialogue,'dialogue session missing')
    assert(d.save==save and save.SWD3CaiDemonKing==d.record,'dialogue save changed')
    if not d.defeat then
        local count=integer(d.record.Defeats,0,1000000)
        d.defeat=hints[count%#hints+1]
        d.record.Defeats=math.min(1000000,count+1)
    end
    return d.defeat
end
