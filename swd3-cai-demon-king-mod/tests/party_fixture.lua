-- Model the separate persistent CharData and native death flag.
BattlePlayers={}
for i=1,4 do
    local p={isPlayer=true,dead=true,CharData={HP=0,MP=2,SP=3,State=32768,MaxHP=100+i,MaxMP=50,MaxSP=60},
        SKData={Energy=9}}
    p.isDeath=function(self) return self.dead end
    p.ReleaseEffect=function(self,mask) if mask==32768 then self.dead=false end end
    BattlePlayers[i]=p
end
