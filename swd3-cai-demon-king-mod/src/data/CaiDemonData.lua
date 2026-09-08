-- Repair Cai's references and enemy Boss identity during DAT2 load.
local MOD = assert(SWD3CaiDemonKing)
assert(MOD.actions, '[CaiDemonKing] actions must load first')
MOD.originals = MOD.originals or {}
local fields = {'ACT','Skills','SkillsCount','Skills_QQ','SkillRate',
    'SP_AttackEffects','SP_AttackEffectsCount','SP_AttackEffectRate',
    'CR_Skills','CR_SkillsCount','CR_Skills_QQ'}

local function repair(item, bossSource)
    if MOD.originals[item] then return end
    local snapshot = {}
    for _,key in ipairs(fields) do snapshot[key] = {value=item[key]} end
    MOD.originals[item] = snapshot
    if bossSource then
        snapshot.IT_06 = {value=item.IT_06}
        -- Register before GameStart so the capture MOD snapshots this identity.
        -- Its existing battle windows own live Boss-bit changes; cards stay non-Boss.
        item.IT_06 = true
    end
    item.ACT = 438
    item.Skills = {1676,1668}
    item.SkillsCount = {2,2}
    item.Skills_QQ = {44,44}
    item.SkillRate = 1
    item.SP_AttackEffects = nil
    item.SP_AttackEffectsCount = nil
    item.SP_AttackEffectRate = nil
    item.CR_Skills = {1683}
    item.CR_SkillsCount = {5}
    item.CR_Skills_QQ = {44}
end

repair(assert(GameData.ItemTemp[438], '[CaiDemonKing] original Cai template missing'), true)
-- If the catalogue loaded first, edit its verified table identity in place at
-- DAT2 time, before native registration. Never create or replace another MOD's card.
local capture = SWD3AllMonsterStaticCapture
local catalogue = SWD3AllMonsterStaticCatalogue
local entry = catalogue and catalogue.entries and catalogue.entries[438]
if entry and entry.staticCard and entry.cardId == 10096 then
    local card = GameData.ItemTemp[10096]
    if card and capture and capture.staticCards and capture.staticCards[10096] == card then
        repair(card)
    end
end
MOD.dataInstalled = true
