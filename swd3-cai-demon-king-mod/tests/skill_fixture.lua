-- Relevant native 4.0.5 fields; the full native tables are also checked in
-- skill_balance.lua when the extracted baseline path is supplied.
GameData.ItemTemp[101]={IT_12=true,isBattleChar=true,UsePlace=1}
GameData.ItemTemp[1676]={Name='ItemName1676',ACT=6044,isSkill=true,AttackEffect=121}
GameData.ItemTemp[1668]={Name='ItemName1668',ACT=7013,isSkill=true,Area=1,AttackEffect=73}
GameData.ItemTemp[1649]={Name='ItemName1649',ACT=6149,isSkill=true,User_04=true,AttackEffect=285}
GameData.ItemTemp[1683]={Name='ItemName1683',ACT=6079,isSkill=true,Area=1,AddHP=300,AttackEffect=198}
GameData.AttackEffect={
    [285]={iAttackPoint=600,iAttr=9,iDelay=10,iActionFX_ACT=6149,iDeathStyle=2},
    [198]={iAttr=7,iDelay=10,iActionFX_ACT=6079},
    [121]={iAttackPoint=120,iAttr=6,iDelay=1,iActionFX_ACT=6044,iDeathStyle=5},
    [73]={iAttackPoint=80,iAttr=7,iDelay=10,iActionFX_ACT=7013,
        bWideRange=true,bRecall=true,iDeathStyle=7}
}
