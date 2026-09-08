local source=assert(arg[1])
local function check(value, expected)
 SWD3ProficiencyMultiplier={multiplier=value}
 GameData={ItemTemp={
  [1]={IT_09=true,ProficientHard=2800,ProficientPoint=80},
  [2]={IT_09=true,ProficientHard=30,ProficientPoint=4},
  [3]={ProficientHard=800,ProficientPoint=17}}}
 log=function() end
 OnEvent={SysInit={}}
 dofile(source)
 assert(GameData.ItemTemp[1].ProficientHard==expected)
 assert(GameData.ItemTemp[3].ProficientHard==800,'non-weapons remain unchanged')
 assert(GameData.ItemTemp[1].ProficientPoint==80,'attack gains remain unchanged')
 assert(#OnEvent.SysInit==0,'ready data is applied directly without UI hooks')
 if value==100 then assert(GameData.ItemTemp[2].ProficientHard==1,'minimum is one hit') end
end
check(100,28);check(1,2800);check(0.5,5600);check(999,28);check(0.1,5600);check('invalid',28)
SWD3ProficiencyMultiplier={multiplier=100}; GameData=nil; OnEvent={SysInit={}}
dofile(source)
assert(#OnEvent.SysInit==1,'unready data defers initialization')
GameData={ItemTemp={[1]={IT_09=true,ProficientHard=2800}}}
OnEvent.SysInit[1]();OnEvent.SysInit[1]()
assert(GameData.ItemTemp[1].ProficientHard==28,'repeat initialization must not compound')
assert(OnEvent.DrawMenuAfter==nil and OnEvent.InputKeyDown==nil,'no slider or F8 hooks')
print('PASS: published v1.1 bounds, one-hit floor, original attack gains, deferred/repeated initialization and no UI hooks')
