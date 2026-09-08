ItemClass={
    AddItem=function(id,n)
        for _,item in ipairs(SaveData.Items) do
            if item.ItemTempID==id then item.Count_New=(item.Count_New or 0)+n;return 0 end
        end
        table.insert(SaveData.Items,{ItemTempID=id,Count=0,Count_New=n});return 1
    end,
    DelItem=function() error('unexpected item deletion in menu fixture') end
}
OnEvent.Battle_RestoreItem={main=function() end}
