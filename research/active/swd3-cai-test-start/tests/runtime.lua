local project,native=assert(arg[1]),assert(arg[2])
GameData={};Const={};Scene={};SaveData={Untouched=42};OnEvent={}
function log() end
function StringDB(value) return value end
ESC={ScreenShow=function() end,Menu=function() end,SaveMenu=function() end}
for _,name in ipairs({'GameData_ItemData','GameData_BattleCharData','GameData_WeaponData',
    'GameData_ArmorData','GameData_SkillData','GameData_PlayerLevel','GameData_NewGame'}) do
    dofile(native..'/'..name..'.lua')
end
local oldChars,oldEqu,oldSkills=GameData.NewGameChar,GameData.NewGameEqu,GameData.NewGameSkill
local function equal(a,b,label) assert(a==b,(label or '')..': '..tostring(a)..' ~= '..tostring(b)) end
dofile(project..'/src/data/CaiTestProfile.lua')
local M=SWD3CaiTestStart
local originalHard={}
for id,hard in pairs(M.Training) do equal(GameData.ItemTemp[id].ProficientHard,hard,'original threshold');originalHard[id]=hard end
dofile(project..'/src/data/CaiTestStart.lua')
equal(SaveData.Untouched,42);equal(SaveData.SWD3CaiTestStart,nil,'no loaded-save preparation')
equal(next(SaveData),'Untouched','DAT does not alter SaveData')
equal(oldChars[1].Level,2);equal(oldEqu[1].Weapon,501)
equal(GameData.NewGame.Script,'CST_BEGIN')
local expected={{5800,700,1100},{4050,1275,695},{4880,1350,590},{6800,920,1140}}
for i=1,4 do
    local char=GameData.NewGameChar[i]
    equal(char.Level,60);equal(char.HP,expected[i][1]);equal(char.HPMax,char.HP)
    equal(char.MP,expected[i][2]);equal(char.SP,expected[i][3])
    local seen={}
    for _,id in ipairs(GameData.NewGameSkill[i]) do assert(not seen[id]);seen[id]=true end
    for _,id in ipairs(GameData.PlayerSpecialSkill[i]) do assert(seen[id]) end
    local count=0;for _ in pairs(GameData.NewGameEqu[i]) do count=count+1 end
    equal(count,11,'all slots including second accessory')
end
local currentChars=GameData.NewGameChar
dofile(project..'/src/data/CaiTestStart.lua');equal(GameData.NewGameChar,currentChars,'no double growth')
local flags,added={},0
GameFunc={FlagOff=function(id) flags[id]=false end}
Scene.AddMainParty=function(id) flags[id+29]=true end
Scene.CheckMainParty=function(id) return flags[id+29] end
ItemFunc={AddItem=function(id,n)
    added=added+1;SaveData.Items[#SaveData.Items+1]={ItemTempID=id,Count=n,Count_New=0}
end}
dofile(native..'/ItemsClass.lua')
local function fresh()
    SaveData={};ItemClass.ItemsClear()
    for role=1,4 do
        local slot=0
        -- Integration model: native resolves names, these tests do not assume slot numbers.
        for _,id in pairs(GameData.NewGameEqu[role]) do
            slot=slot+1;equal(ItemClass.NewEquip(id,role,slot),0)
        end
        for _,id in ipairs(GameData.NewGameSkill[role]) do ItemClass.AddSkill(id,role,1) end
    end
    flags={};added=0
end
fresh();M.Prepare();equal(added,10)
for i=30,33 do equal(flags[i],true,'all four party flags') end
for id,hard in pairs(M.Training) do
    equal(SaveData.ItemTemp[id].Familiar,hard)
    equal(SaveData.ItemTemp[id].FamiliarPercent,100)
    equal(SaveData.ItemTemp[id].isFamiliarMax,true)
    equal(GameData.ItemTemp[id].ProficientHard,originalHard[id],'original data unchanged')
end
equal(SaveData.SWD3CaiTestStart.Ready,true);equal(SaveData.MapDetail[81].BattleOff,true)
SaveData.Items[1].Count=0
M.Prepare();equal(added,10,'no free repeated supplies');equal(SaveData.Items[1].Count,0)
M.Restock();equal(added,11,'explicit restock fills used supplies only')
M.Restock();equal(added,11,'explicit restock does not exceed quota')
SWD3CaiDemonKing={state={active=true}}
equal(pcall(M.Restock),false,'battle restock blocked');SWD3CaiDemonKing=nil
SaveData.SWD3CaiTestStart=nil;equal(pcall(M.Restock),false,'story save restock blocked')
fresh();SaveData.PlayerEqu[4][1].ItemTempID=-1
local ok=pcall(M.Prepare);equal(ok,false);equal(added,0);equal(next(flags),nil)
equal(SaveData.SWD3CaiTestStart,nil,'preflight before writes')
fresh();SaveData.PlayerSkills[2]={}
equal(pcall(M.Prepare),false);equal(added,0)
-- Scene transition regression: direct main-menu use after a cold test start
-- crashed natively. Require the save-point UI first; no automatic slot write.
fresh()
local sequence={}
ESC.ScreenShow=function() sequence[#sequence+1]='screen' end
ESC.Menu=function(title,rows)
    equal(SaveData.SWD3CaiTestStart.Ready,true)
    equal(rows[2],'CST_SAVE');sequence[#sequence+1]='notice'
end
ESC.SaveMenu=function() sequence[#sequence+1]='save-ui' end
Scene.CST_BEGIN()
equal(table.concat(sequence,','),'screen,notice,save-ui','native save UI follows completed notice')
SaveData.Items[1].Count=0;sequence={};Scene.CST_BEGIN()
equal(SaveData.Items[1].Count,0,'scene reentry cannot duplicate supplies')
fresh();SaveData.PlayerSkills[2]={};sequence={}
ESC.Menu=function(_,rows) equal(rows[1],'CST_FAILED');sequence[#sequence+1]='failure' end
Scene.CST_BEGIN()
equal(table.concat(sequence,','),'screen,failure','failed setup never offers saving')
fresh();ESC.SaveMenu=nil
equal(pcall(M.Prepare),false);equal(added,0,'missing save UI fails before inventory writes')
ESC.SaveMenu=function() end
fresh();ItemFunc.AddItem=function() end
equal(pcall(M.Prepare),false);equal(SaveData.SWD3CaiTestStart.Ready,false)
equal(pcall(M.Prepare),false,'partial failure cannot silently resume')
local source=M.Copy({NewGameChar=oldChars,NewGameSkill=oldSkills,PlayerLevel=GameData.PlayerLevel,
    PlayerSpecialSkill=GameData.PlayerSpecialSkill,ItemTemp=GameData.ItemTemp})
source.ItemTemp[580]=nil
equal(pcall(M.Build,source),false,'missing equipment rejected')
print('PASS: four Lv60 profiles, original data and training thresholds, 44 equipment slots, all skills, new-game-only scope, no duplicate supply, preflight and failure containment')
