SWD3CaiAutoAIProbe = SWD3CaiAutoAIProbe or {}
local P = {}
SWD3CaiAutoAIProbe.Policy = P

-- Rows have already passed native availability checks. Keep percentage units.
function P.Recovery(rows, hp, maximum, group, minimum)
    if type(maximum) ~= 'number' or maximum <= 0 or hp >= maximum then return nil end
    local best, bestUseful, bestWaste
    for _, row in ipairs(rows) do
        local amount
        if row.calculation == 0 then amount = row.add
        elseif row.calculation == 512 then amount = row.add / 100 * maximum end
        if amount and amount > 0 and amount / maximum >= (minimum or 0.1)
            and row.all == group then
            local useful = math.min(maximum - hp, amount)
            local waste = amount - useful
            if not best or useful > bestUseful or (useful == bestUseful and waste < bestWaste) then
                best, bestUseful, bestWaste = row, useful, waste
            end
        end
    end
    return best
end

function P.Attack(rows, hp)
    local best
    for _, row in ipairs(rows) do
        if type(row.damage) == 'number' and row.damage > 0 and row.damage == row.damage then
            local replace = not best
            if best then
                local kills, bestKills = row.damage >= hp, best.damage >= hp
                if kills ~= bestKills then replace = kills
                elseif kills then replace = row.damage < best.damage
                else replace = row.damage > best.damage end
                if row.damage == best.damage then replace = row.preference < best.preference end
            end
            if replace then best = row end
        end
    end
    return best
end

-- try(name, ...) only succeeds when the helper actually selects an action.
function P.Decide(env, playerID, phase, try)
    local limit = phase == 2 and 75 or 65
    local hurt = 0
    for _, row in ipairs(env.HP or {}) do
        if row[2] <= limit then hurt = hurt + 1 end
    end
    if env.Serious and #env.Serious > 0 and try('AI_CureBadState', 0) then return 'serious' end
    local healer = playerID == 1 or playerID == 2 -- Native PlayerID is zero-based.
    if healer or (env.HPP or 100) <= 35 or hurt >= 2 then
        if hurt >= 2 and try('GroupHP', limit) then return 'heal-group' end
        if try('AI_SkillAddHP', limit) then return 'heal-skill' end
        if try('AI_ItemAddHP', limit) then return 'heal-item' end
    end
    if env.BadState and #env.BadState > 0 and try('AI_CureBadState', 1) then return 'state' end
    if (env.MPP or 100) <= 25 then
        if try('AI_SkillAddMP', 25) or try('AI_ItemAddMP', 25) then return 'restore-mp' end
    end
    if (env.SPP or 100) <= 20 then
        if try('AI_SkillAddSP', 20) or try('AI_ItemAddSP', 20) then return 'restore-sp' end
    end
    return 'attack'
end
