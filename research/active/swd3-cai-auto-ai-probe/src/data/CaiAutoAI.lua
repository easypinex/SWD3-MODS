local M = assert(SWD3CaiAutoAIProbe)
local P = assert(M.Policy)
M.supportsManualSummon=true
-- Native boot-time switch also enables its global battle UI. Test MOD only.
BattlePlayerAI_mod = true
local FIELD = 'CDK_CAI_CHALLENGE'
local function write(message)
    if type(log) == 'function' then log('[CaiAutoAI] '..message) end
end
local function ownBattle()
    local cai = SWD3CaiDemonKing
    return cai and cai.challengeId == 11001 and cai.state and cai.state.active
        and not cai.state.breakRequested and not cai.state.enemyRemoved
        and cai.state.outcome ~= 'defeat'
        and GameFunc and type(GameFunc.GetBattleFieldID) == 'function'
        and GameFunc.GetBattleFieldID() == FIELD
end
local function hero(player)
    return player and player.isPlayer and not player.isNPC and player.CharData
end
local function alive(player)
    return hero(player) and player.CharData.HP > 0
        and not player.isDeath(player) and not player.isHide(player)
end
local function get(id, key) return Function.GetItemTemp(id, key) end
local function effect(id, key)
    return Function.GetGameData('AttackEffect', get(id, 'AttackEffect'), key)
end
local function trueFlag(value) return value == true or value == 1 end
local function available(id)
    local count=0
    for _,item in ipairs(SaveData.Items or {}) do
        if item.ItemTempID==id then count=count+math.max(0,
            (item.Count or 0)+(item.Count_New or 0)-(item.Stock or 0)) end
    end
    return count
end
local function affordable(actor,id,reserve)
    local cost=tonumber(get(id,'Consumption')) or 0
    if cost<0 then return false end
    if trueFlag(get(id,'Cons_SP')) and actor.CharData.SP<cost+(reserve or 0) then return false end
    if trueFlag(get(id,'Cons_MP')) and actor.CharData.MP<cost then return false end
    if trueFlag(get(id,'Cons_Item')) and available(cost)<1 then return false end
    return true
end
local function reserveSP(actor)
    return actor.PlayerID==0 and available(804)>0 and 300 or 100
end

local function livingKeepers()
    local count=0
    for index,data in pairs(BattleEnv.players or {}) do
        if data.isKeeper and data.status and data.status.HP>0 and data.self
            and BattlePlayers[index]==data.self and data.self.NPC_GUID>0
            and M.removedKeepers[index]~=data and not data.self.isDeath(data.self) then
            -- Original enemy targeting exempts keepers from the hero isHide gate.
            count=count+1
        end
    end
    return count
end

local function tryHandoff()
    if not ownBattle() or not M.active or not M.awaitSummons or M.failed then return end
    if livingKeepers()<2 then return end
    M.awaitSummons=false
    for slot,saved in pairs(M.snapshots or {}) do
        if BattlePlayers[slot]==saved.player then saved.player.AImode=1 end
    end
    write('two native keepers confirmed; automatic hero AI resumed')
end

local function recovery(fromItems, user, target, hp, maximum, group, addType, minimum)
    if M.groupOnly and not group then return 0 end
    local actor, receiver = BattlePlayers[user], BattlePlayers[target]
    if not alive(receiver) or not hero(actor) then return 0 end
    local command = fromItems and Const.AI_ITEM or Const.AI_SKILL
    if not BattleEnv.CmdLists[command] then return 0 end
    addType = (addType == 'AddMP' or addType == 'AddSP') and addType or 'AddHP'
    local list = fromItems and SaveData.Items or SaveData.PlayerSkills[actor.PlayerID + 1]
    local rows = {}
    for index, prop in ipairs(list or {}) do
        local id = prop.ItemTempID
        local allowed = type(id) == 'number' and id > 0
        if allowed and fromItems then
            local count = (prop.Count or 0) + (prop.Count_New or 0) - (prop.Stock or 0)
            allowed = count > 0 and bit32.band(get(id, 'UsePlace'), 5) > 0
                and trueFlag(get(id, string.format('User_%02u', actor.PlayerID + 1)))
                and not trueFlag(get(id, 'IT_12')) and affordable(actor,id)
                and bit32.band(effect(id, 'hRelieveEfficacy'), Const.eff_DIE) == 0
        elseif allowed then
            allowed = Function.CheckPlayerCanUseSkill(user, id)
        end
        if allowed then
            local add = get(id, addType)
            if type(add) == 'number' and add > 0 then
                rows[#rows + 1] = {id=fromItems and index or id, add=add,
                    calculation=get(id, 'Calculation'), all=trueFlag(effect(id, 'bWideRange')),
                    consumable=fromItems and not trueFlag(get(id, 'IT_06'))
                        and not trueFlag(get(id, 'IT_08')) and prop or nil}
            end
        end
    end
    local row = P.Recovery(rows, hp, maximum, group == true, minimum)
    if not row then return 0 end
    return row.id, row.calculation == 0 and row.add or 0,
        row.calculation == 512 and row.add or 0, row.all, row.consumable
end

local function findEnemy()
    for index, data in pairs(BattleEnv.enemys or {}) do
        local enemy = data.self
        local status = enemy and enemy.NPCData
        if data.GUID == 11001 and status and status.HP > 0
            and not enemy.isDeath(enemy) and not enemy.isHide(enemy) then
            -- The probe only supports the Cai single-enemy field.
            return index, enemy, status
        end
    end
end
local function attack(index, target, status)
    local actor = BattlePlayers[index]
    local rows = {}
    local commands = BattleEnv.CmdLists
    local function consider(command, item, preference)
        if not commands[command] then return end
        local damage = _BattleEnv.CalDamage(index, -target, command, item)
        rows[#rows + 1] = {command=command, item=item, damage=damage, preference=preference}
    end
    consider(Const.AI_ATTACK, 0, 0)
    for _, prop in ipairs(SaveData.PlayerSkills[actor.PlayerID + 1] or {}) do
        local id = prop.ItemTempID
        if id and id > 0 and trueFlag(get(id, 'IT_05'))
            and Function.CheckPlayerCanUseSkill(index, id) and affordable(actor,id,reserveSP(actor)) then
            local special = get(id, 'Race') == 31
            consider(special and Const.AI_SPECIAL or Const.AI_SKILL, id, special and 2 or 1)
        end
    end
    local best = P.Attack(rows, status.HP)
    if not best then return false end
    actor.AI_Command, actor.AI_SelectItem = best.command, best.item
    actor.AI_TargetIsEnemySide = true
    BattleEnv.setTarget = target
    return true
end

local function decide()
    local index = BattleEnv.index
    local actor = BattlePlayers[index]
    if not alive(actor) then return 'inactive' end
    local target, enemy, status = findEnemy()
    if not target then return 'no-enemy' end
    -- The original SP inventory omits exactly-zero SP. Include depleted heroes.
    for slot = 1, _BattleEnv.PlayerIDMax do
        local player = BattlePlayers[slot]
        if alive(player) and player.CharData.SP == 0 and player.CharData.MaxSP > 0 then
            local found = false
            for _, row in ipairs(BattleEnv.SP) do if row[1] == slot then found = true end end
            if not found then table.insert(BattleEnv.SP, 1, {slot, 0}) end
            BattleEnv.SPP = 0
        end
    end
    if status.MaxHP > 0 and status.HP / status.MaxHP <= 0.60 then M.phase = 2 end
    local function try(name, ...)
        if name == 'GroupHP' then
            M.groupOnly = true
            Function.AI_SkillAddHP(...)
            if BattleEnv.setTarget == 0 then Function.AI_ItemAddHP(...) end
            M.groupOnly = false
        else
            Function[name](...)
        end
        return BattleEnv.setTarget ~= 0
    end
    local reason = P.Decide(BattleEnv, actor.PlayerID, M.phase, try)
    -- HD4.0.5 AI_ITEM paid SP but never entered native keeper action 0x10.
    -- Do not submit living cards as ordinary items, or fake a successful spawn.
    if reason == 'attack' then attack(index,target,status) end
    write(string.format('select actor=%s phase=%s reason=%s command=%s item=%s target=%s enemySide=%s HPP=%s',
        tostring(index), tostring(M.phase), reason, tostring(actor.AI_Command),
        tostring(actor.AI_SelectItem), tostring(BattleEnv.setTarget),
        tostring(actor.AI_TargetIsEnemySide), tostring(BattleEnv.HPP)))
    return reason
end

function M.Install()
    if M.installed then return end
    if not Function then return end
    for _, name in ipairs({'BattlePlayerAI_FullAuto', 'CheckPlayerCureHPfromSkill',
        'CheckPlayerCureHPfromItems', 'AI_CureBadState', 'AI_SkillAddHP', 'AI_ItemAddHP',
        'AI_SkillAddMP', 'AI_ItemAddMP', 'AI_SkillAddSP', 'AI_ItemAddSP'}) do
        if type(Function[name]) ~= 'function' then return end
    end
    local previous = Function.BattlePlayerAI_FullAuto
    M.wrapper = function(...)
        if not ownBattle() or not M.active or M.failed or M.awaitSummons then return previous(...) end
        M.deciding = true
        local ok, failure = pcall(decide)
        M.deciding, M.groupOnly = false, false
        if not ok then
            M.failed = true
            local index = BattleEnv.index
            -- Stop the test AI; do not rerun a partially executed decision.
            pcall(Function.Battle_InitPlayerAImemo, index)
            local actor = BattlePlayers[index]
            actor.AI_Command, actor.AI_SelectItem = Const.AI_DEFENSE, 0
            actor.AI_TargetIsEnemySide, actor.AImode = false, 0
            BattleEnv.setTarget = index
            for slot, saved in pairs(M.snapshots or {}) do
                if BattlePlayers[slot] == saved.player then
                    pcall(function() saved.player.AImode = 0 end)
                end
            end
            write('ERROR; automatic test stopped: '..tostring(failure))
        end
    end
    Function.BattlePlayerAI_FullAuto = M.wrapper
    for _, fromItems in ipairs({false, true}) do
        local name = fromItems and 'CheckPlayerCureHPfromItems' or 'CheckPlayerCureHPfromSkill'
        local old = Function[name]
        Function[name] = function(...)
            if M.deciding then return recovery(fromItems, ...) end
            return old(...)
        end
    end
    M.installed = true
    local oldState=Function.CheckPlayerCureStatefromItems
    if type(oldState)=='function' then
        Function.CheckPlayerCureStatefromItems=function(index,target,group)
            if not M.deciding then return oldState(index,target,group) end
            local actor=BattlePlayers[index]
            local best
            for _,item in ipairs(SaveData.Items or {}) do
                local id=item.ItemTempID
                if id and id>0 and available(id)>0 and affordable(actor,id)
                    and not trueFlag(get(id,'IT_12')) and bit32.band(get(id,'UsePlace'),5)>0
                    and trueFlag(get(id,string.format('User_%02u',actor.PlayerID+1))) then
                    local all=trueFlag(effect(id,'bWideRange'))
                    local relief=effect(id,'hRelieveEfficacy')
                    if (group or not all) and bit32.band(relief,target.v)>0 then
                        local price=tonumber(get(id,'Price')) or 0
                        if not best or price<best.price then
                            best={id=id,all=all,relief=relief,price=price,
                                prop=not trueFlag(get(id,'IT_06')) and not trueFlag(get(id,'IT_08')) and item or nil}
                        end
                    end
                end
            end
            if not best then return 0 end
            return best.id,best.all,best.relief,best.prop
        end
    end
    write('v0.4 helpers installed; keeper handoff uses native keeper eligibility and rechecks')
end

local function forget()
    M.active, M.deciding, M.failed, M.groupOnly = false, false, false, false
    M.snapshots, M.phase = {}, 1
    M.awaitSummons=false;M.resources={};M.removedKeepers={}
end
local function restore()
    for index, saved in pairs(M.snapshots or {}) do
        -- Restore only still-current objects, never old battle userdata.
        if BattlePlayers and BattlePlayers[index] == saved.player then
            local ok, err = pcall(function() saved.player.AImode = saved.mode end)
            if not ok then write('mode restore failed: '..tostring(err)) end
        end
    end
    if M.active then write('battle finished; modes restored') end
    forget()
end
local function enter()
    M.Install()
    if not ownBattle() or not M.installed or M.active then return end
    forget()
    M.active = true
    M.awaitSummons=SWD3CaiDemonKing.state.manualSummon==true
    local count = 0
    for index = 1, _BattleEnv.PlayerIDMax do
        local actor = BattlePlayers[index]
        if hero(actor) and count < 4 then
            M.snapshots[index] = {player=actor, mode=actor.AImode}
            actor.AImode = M.awaitSummons and 0 or 1
            count = count + 1
        end
    end
    write('automatic Cai test entered; heroes='..count..'; manualSummon='..tostring(M.awaitSummons))
end
if not M.eventsRegistered then
    local function hook(name, handler)
        OnEvent[name] = OnEvent[name] or {}
        table.insert(OnEvent[name], handler)
    end
    hook('SysInit', M.Install)
    hook('GameStart', function() forget(); M.Install() end)
    hook('Battle_Enter', enter)
    hook('Battle_KeeperInit',function(index,itemtabIdx)
        if not ownBattle() or not M.active then return end
        local data=BattleEnv.players[index]
        local item=SaveData.Items[itemtabIdx]
        if not data or not data.isKeeper or not item then return end
        M.removedKeepers[index]=nil
        write('native keeper confirmed item='..item.ItemTempID..'; slot='..index
            ..'; living='..livingKeepers()..'; available='..available(item.ItemTempID)
            ..'; HP='..tostring(data.status.HP)..'; dead='..tostring(data.self.isDeath(data.self))
            ..'; hidden='..tostring(data.self.isHide(data.self)))
        tryHandoff()
    end)
    hook('BattleNPCAI',tryHandoff)
    hook('Battle_Dead',function(index,side,mode)
        if not M.active or side~=0 then return end
        local data=BattleEnv.players[index]
        if data and data.isKeeper then
            M.removedKeepers[index]=data
            write('keeper removed item='..tostring(data.GUID)..'; mode='..tostring(mode)
                ..'; remaining available='..available(data.GUID))
        end
    end)
    hook('BattlePlayerAI',function(index)
        if not ownBattle() or not M.active or not hero(BattlePlayers[index]) then return end
        tryHandoff()
        local status=BattlePlayers[index].CharData
        local old=M.resources[index]
        if old then write('resource readback actor='..index..'; MP='..old.mp..'->'..status.MP
            ..'; SP='..old.sp..'->'..status.SP..'; prior item='..tostring(old.item)) end
        M.resources[index]={mp=status.MP,sp=status.SP,item=BattlePlayers[index].AI_SelectItem}
    end)
    hook('Battle_RestoreItem', restore)
    hook('MapLoading', forget)
    M.eventsRegistered = true
    forget()
end
M.Install()
write('v0.4 loaded; corrected keeper count; manual summon handoff rechecks enabled')
