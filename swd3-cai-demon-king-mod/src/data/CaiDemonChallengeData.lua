-- DAT2-only registration. This enemy is outside the capture catalogue.
local MOD = assert(SWD3CaiDemonKing)
assert(MOD.dataInstalled, '[CaiDemonKing] legacy repair must load first')
local ID = 11001
MOD.challengeId = ID
local function copy(value)
    if type(value) ~= 'table' then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = copy(child) end
    return result
end
if MOD.challengeTemplate then
    assert(GameData.ItemTemp[ID] == MOD.challengeTemplate, '[CaiDemonKing] challenge ID replaced')
    for id, skill in pairs(MOD.challengeSkills) do
        assert(GameData.ItemTemp[id] == skill and GameData.AttackEffect[id] == MOD.challengeEffects[id],
            '[CaiDemonKing] challenge skill/effect replaced')
    end
    return
end
assert(GameData.ItemTemp[ID] == nil, '[CaiDemonKing] ItemTemp11001 conflict')
-- Validate every dependency and destination before registering any new data.
local skills, effects = {}, {}
for _, spec in ipairs({{11002,1676,121,3000}, {11003,1668,73,3200},
                       {11004,1649,285,4200}, {11005,1683,198}}) do
    local id, source, effect, points = spec[1], spec[2], spec[3], spec[4]
    assert(GameData.ItemTemp[id] == nil and GameData.AttackEffect[id] == nil,
        '[CaiDemonKing] challenge skill/effect ID conflict: '..id)
    skills[id] = copy(assert(GameData.ItemTemp[source], 'missing native skill'))
    assert(skills[id].AttackEffect == effect, 'native skill effect changed')
    effects[id] = copy(assert(GameData.AttackEffect[effect], 'missing native effect'))
    effects[id].iAttackPoint = points
    skills[id].AttackEffect = id
end
skills[11004].Name='CDK_PHYSICAL_NAME'
skills[11004].HelpText='CDK_PHYSICAL_HELP'
skills[11004].InfoText='CDK_PHYSICAL_HELP'
skills[11004].User_04=nil
-- Native Blood Blade FX; keep the original single-target physical behavior.
skills[11004].ACT=6145
effects[11004].iActionFX_ACT=6145
-- Two native cure events in one animation keep each floating number at four digits.
skills[11005].AddHP=6000
skills[11005].ATK_Count=2 -- native AI estimate only; ACT events perform the two pulses
skills[11005].ACT=11005
effects[11005].iActionFX_ACT=11005
skills[11005].Area=nil -- explicitly self-only; native target is this boss
local enemy = copy(assert(GameData.ItemTemp[438]))
enemy.Name = 'CDK_ENEMY_NAME'
enemy.HelpText = 'CDK_ENEMY_HELP'
enemy.IT_06 = true
enemy.IT_12 = nil
enemy.NotInBook = true
enemy.Level = 99
enemy.HP = 80000
enemy.ATK = 950
enemy.DEF = 350
enemy.SPD = 150
enemy.WIS = 220
enemy.DodgeRate = 5
enemy.EscapeRate = 0
enemy.AttrDark = -4
enemy.AttrWind = 2
for _, key in ipairs({'AttrLight','AttrFire','AttrIce','AttrEarth','AttrThunder','AttrPhysical'}) do
    enemy[key] = 0
end
enemy.Skills = {11002,11003,11004}
enemy.SkillsCount = {2,2,2}
enemy.Skills_QQ = {44,44,44}
enemy.CR_Skills = {11005}
enemy.CR_SkillsCount = {1} -- planner enforces once-only; this count alone does not
enemy.CR_Skills_QQ = {44}
enemy.GainEXP = 1
enemy.GainGold = 1
enemy.DropItems = nil
enemy.DropItemsCount = nil
enemy.DropItemsRate = nil
GameData.ItemTemp[ID] = enemy
for id, skill in pairs(skills) do
    GameData.ItemTemp[id] = skill
    GameData.AttackEffect[id] = effects[id]
end
MOD.challengeSkills = skills
MOD.challengeEffects = effects
MOD.challengeTemplate = enemy
