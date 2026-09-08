SWD3CaiTestStart = SWD3CaiTestStart or {}
local M=SWD3CaiTestStart
M.Equipment={
    {Weapon=580,Head=898,Chest=869,Hand=887,Foot=912,Acce1=979,Acce2=993,Guardian1=255,Guardian2=178,Sutra1=931,Sutra2=932},
    {Weapon=536,Head=1031,Chest=1015,Hand=889,Foot=909,Acce1=994,Acce2=993,Guardian1=179,Guardian2=198,Sutra1=948,Sutra2=954},
    {Weapon=553,Head=1031,Chest=1017,Hand=1047,Foot=1040,Acce1=995,Acce2=993,Guardian1=149,Guardian2=152,Sutra1=952,Sutra2=951},
    {Weapon=562,Head=905,Chest=871,Hand=886,Foot=915,Acce1=979,Acce2=993,Guardian1=368,Guardian2=154,Sutra1=949,Sutra2=939}
}
-- Fixed original HD4.0.5 thresholds, independent of a proficiency speed MOD.
M.Training={[536]=400,[553]=250,[562]=220,[580]=10,[931]=1200,[932]=1000,
    [939]=1300,[948]=1000,[949]=1000,[951]=1500,[952]=1200,[954]=5000}
M.Supplies={{632,3},{642,4},{641,3},{646,3},{626,20},{804,1},
    {178,2},{179,2},{368,2},{255,2}}
local keys={'HP','MP','SP','STR','Stamina','WIS','SPD','Friend','AGI','Luck','Dodge'}
function M.Copy(value)
    if type(value)~='table' then return value end
    local result={}
    for k,v in pairs(value) do result[k]=M.Copy(v) end
    return result
end
function M.Build(data)
    local chars,skills={},{}
    for role=1,4 do
        local initial=assert(data.NewGameChar[role],'missing character')
        local levels=assert(data.PlayerLevel[role],'missing level table')
        assert(levels.LevelMax==60 and initial.Level<=60,'unsupported level baseline')
        local char=M.Copy(initial)
        local learned,seen={},{}
        local function learn(id)
            assert(data.ItemTemp[id] and data.ItemTemp[id].isSkill,'missing skill '..tostring(id))
            if not seen[id] then seen[id]=true; learned[#learned+1]=id end
        end
        for _,id in ipairs(data.NewGameSkill[role]) do learn(id) end
        for level=initial.Level+1,60 do
            local gains=assert(levels[level],'missing growth row')
            for i,key in ipairs(keys) do char[key]=assert(char[key])+assert(gains[i]) end
            char.TotalEXP=(char.TotalEXP or 0)+(gains[12] or 0)
            if gains[13] then learn(gains[13]) end
        end
        for _,id in ipairs(data.PlayerSpecialSkill[role]) do learn(id) end
        char.Level=60;char.EXP=0;char.State=0;char.AI=0
        char.HPMax=char.HP;char.MPMax=char.MP;char.SPMax=char.SP
        chars[role],skills[role]=char,learned
        for slot,id in pairs(M.Equipment[role]) do
            local item=assert(data.ItemTemp[id],'missing equipment '..id)
            assert(item['User_0'..role]==true,'equipment role mismatch '..id)
            assert(id~=438 and id~=10096,'Cai excluded')
        end
    end
    for id,hard in pairs(M.Training) do
        local item=assert(data.ItemTemp[id])
        assert(item.IT_09 or item.IT_07,'invalid training item')
        assert(hard>0)
    end
    for _,row in ipairs(M.Supplies) do assert(data.ItemTemp[row[1]],'missing supply') end
    return chars,skills,M.Copy(M.Equipment)
end
