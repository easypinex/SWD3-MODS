local M=assert(SWD3CaiTestStart)
local function write(s) if type(log)=='function' then log('[CaiTestStart] '..s) end end
local function countItem(id)
    local count=0
    for _,item in ipairs(SaveData.Items or {}) do
        if item.ItemTempID==id then count=count+(item.Count or 0)+(item.Count_New or 0) end
    end
    return count
end
function M.VerifyEquipment()
    for role=1,4 do
        local actual={}
        for _,item in ipairs(assert(SaveData.PlayerEqu[role])) do
            if item.ItemTempID and item.ItemTempID>0 then
                actual[item.ItemTempID]=(actual[item.ItemTempID] or 0)+1
            end
        end
        for _,id in pairs(M.Equipment[role]) do
            assert(actual[id] and actual[id]>0,'native equipment missing '..role..':'..id)
            actual[id]=actual[id]-1
        end
        for _,n in pairs(actual) do assert(n==0,'unexpected native equipment') end
        local actualSkills={}
        for _,item in ipairs(assert(SaveData.PlayerSkills[role])) do actualSkills[item.ItemTempID]=true end
        for _,id in ipairs(M.skills[role]) do assert(actualSkills[id],'native skill missing '..id) end
    end
end
function M.Prepare()
    assert(M.installed and GameData.NewGame.Script=='CST_BEGIN','not a test start')
    assert(SaveData and type(SaveData.Items)=='table','no new-game inventory')
    if SaveData.SWD3CaiTestStart then
        assert(SaveData.SWD3CaiTestStart.Ready==true,'previous preparation failed; start a new test game')
        return
    end
    -- Complete all validation before issuing any inventory or party writes.
    M.VerifyEquipment()
    assert(type(Scene.AddMainParty)=='function' and type(Scene.CheckMainParty)=='function')
    assert(ItemFunc and type(ItemFunc.AddItem)=='function')
    assert(ESC and type(ESC.SaveMenu)=='function','native save menu unavailable')
    for _,row in ipairs(M.Supplies) do
        assert(countItem(row[1])<=row[2],'unexpected pre-existing test supplies')
    end
    SaveData.SWD3CaiTestStart={Version=1,Ready=false}
    SaveData.ItemTemp=SaveData.ItemTemp or {}
    for id,hard in pairs(M.Training) do
        local item=SaveData.ItemTemp[id] or {}
        item.ProficientHard=hard;item.Familiar=hard;item.FamiliarPercent=100;item.isFamiliarMax=true
        SaveData.ItemTemp[id]=item
    end
    for _,row in ipairs(M.Supplies) do
        local need=row[2]-countItem(row[1])
        if need>0 then ItemFunc.AddItem(row[1],need) end
        assert(countItem(row[1])==row[2],'supply verification failed '..row[1])
    end
    for role=1,4 do
        Scene.AddMainParty(role)
        assert(Scene.CheckMainParty(role),'party flag failed '..role)
    end
    -- Keep this new test map quiet; custom Insert/F9 battles are still available.
    SaveData.MapDetail=SaveData.MapDetail or {}
    SaveData.MapDetail[81]=SaveData.MapDetail[81] or {}
    SaveData.MapDetail[81].BattleOff=true
    GameFunc.FlagOff(10);GameFunc.FlagOff(81)
    SaveData.SWD3CaiTestStart.Ready=true
    write('READY: four Lv60 heroes; 44 equipment slots; 12 trained items; fixed supplies')
end
-- Explicit test-save-only top-up; no writes on load or during a battle.
function M.Restock()
    assert(SaveData and SaveData.SWD3CaiTestStart and SaveData.SWD3CaiTestStart.Ready==true,
        'not an initialized test save')
    assert(not (SWD3CaiDemonKing and SWD3CaiDemonKing.state and SWD3CaiDemonKing.state.active),
        'cannot restock during a challenge')
    M.VerifyEquipment()
    for _,row in ipairs(M.Supplies) do assert(GameData.ItemTemp[row[1]],'missing supply') end
    for _,row in ipairs(M.Supplies) do
        local need=row[2]-countItem(row[1])
        if need>0 then ItemFunc.AddItem(row[1],need) end
        assert(countItem(row[1])>=row[2],'restock verification failed '..row[1])
    end
    write('restock verified: fixed supplies and eight spare summon cards; equipment retained')
end
local function begin()
    local ok,err=pcall(M.Prepare)
    ESC.ScreenShow()
    if not ok then
        write('ERROR: '..tostring(err))
        ESC.Menu(StringDB('CST_TITLE'),{StringDB('CST_FAILED')})
        return
    end
    ESC.Menu(StringDB('CST_TITLE'),{StringDB('CST_READY'),StringDB('CST_SAVE')})
    -- HD 4.0.5 resets the shared basic frame at title initialization. The item
    -- page reads its TSW before loading it; the native save-slot renderer loads
    -- it first (see evidence/native-shared-frame.txt, FUN_140099a90).
    -- Open the same UI as the original save-point script. Only the user saves.
    write('opening native save menu; choose an EMPTY slot, or cancel to inspect party')
    ESC.SaveMenu()
end
if not M.installed then
    assert(GameData and GameData.NewGame,'new-game tables not loaded')
    assert(not Scene.CST_BEGIN,'test scene name conflict')
    local chars,skills,equ=M.Build(GameData)
    M.original={chars=GameData.NewGameChar,skills=GameData.NewGameSkill,
        equ=GameData.NewGameEqu,start=M.Copy(GameData.NewGame)}
    M.skills=skills
    GameData.NewGameChar=chars;GameData.NewGameSkill=skills;GameData.NewGameEqu=equ
    local start=M.Copy(GameData.NewGame)
    start.StartMapID=81;start.StartMapX=13;start.StartMapY=28
    start.mainACT=1;start.mainQQ=0;start.mainDir=3;start.mainGUID=1
    start.Script='CST_BEGIN'
    GameData.NewGame=start
    Scene.CST_BEGIN=begin
    M.installed=true
    for role,char in ipairs(chars) do
        write(string.format('profile role=%d Lv%d HP=%d MP=%d SP=%d skills=%d',
            role,char.Level,char.HP,char.MP,char.SP,#skills[role]))
    end
end
write('v0.3 loaded; test-save restock enabled; native new-game save menu retained')
