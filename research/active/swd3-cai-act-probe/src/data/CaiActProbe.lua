SWD3CaiActProbe = { tick=-10000 }
local P = SWD3CaiActProbe
local t = assert(GameData.ItemTemp[438])
t.Skills=nil; t.SkillsCount=nil; t.SP_AttackEffects=nil; t.SP_AttackEffectsCount=nil
t.HP=2000; t.GainEXP=0; t.GainGold=0
BattleField.CDK_ACT_PROBE = {
    iBattleFieldBackground=4, MusicFileName='Battle_Europa01.mp3',
    tCharActQ={{ItemTempID=438,X=176,Y=294}}
}
Scene.CDK_ActProbe = function()
    log('[CaiActProbe] start ACT438 red normal attack')
    ESC.StartBattle('CDK_ACT_PROBE')
end
local function hook(name, fn)
    OnEvent[name]=OnEvent[name] or {}; table.insert(OnEvent[name],fn)
end
hook('GameStart',function() log('[CaiActProbe] v0.2 DAT1 loaded; inventory Insert; no saving') end)
hook('DrawMenuAfter',function()
    P.tick=GetTicks()
    if not P.drawLogged then P.drawLogged=true; log('[CaiActProbe] inventory draw active') end
end)
hook('InputKeyDown',function(_,key)
    log('[CaiActProbe] input='..tostring(key)..'; menuAge='..tostring(GetTicks()-P.tick))
    if key==73 and GetTicks()-P.tick<=250 then GameFunc.RunScene(-1,'CDK_ActProbe',0) end
end)
hook('Battle_Enter',function()
    if GameFunc.GetBattleFieldID()=='CDK_ACT_PROBE' then
        log('[CaiActProbe] entered; DAT1 ACT438')
        BSC.NoOVER()
    end
end)
hook('Battle_RestoreItem',function() log('[CaiActProbe] restore item') end)
