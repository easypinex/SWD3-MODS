-- Existing HD red swordsman artwork only. No TSW registration or dark phase.
-- ACT2198 QQ36/38/40/59, Steam HD 4.0.5 act.ext.
SWD3CaiDemonKing = SWD3CaiDemonKing or {}
local MOD = SWD3CaiDemonKing
local C = assert(ACTcmd, '[CaiDemonKing] original ACTcmd is missing')
ACTData = ACTData or {}

-- These are per-action command arrays in the original ACT_Append.lua format.
local idle = {
    {C.TN,4},{C.RF,2290},{C.SD,8},{C.XY,99,155},{C.WH,3,1},C.NO,
    {C.PA,0},C.ED,{C.PA,1},C.ED,{C.PA,2},C.ED,{C.PA,3},C.OV
}
local hurt = {
    {C.TN,4},{C.RF,2291},{C.SD,1},{C.XY,109,155},{C.WH,3,1},C.NO,
    {C.WV,199},{C.PA,0},C.ED,{C.SD,2},{C.XY,109,155},{C.WH,3,1},
    {C.PA,1},C.ED,{C.XY,97,155},{C.WH,3,1},{C.PA,2},C.ED,
    {C.XY,105,155},{C.WH,3,1},{C.PA,1},C.O2
}
local function sword(trigger)
    return {
        {C.TN,8},{C.RF,2300},{C.SD,3},{C.XY,304,218},{C.WH,3,1},C.NO,
        {C.WV,8},{C.PA,0},C.ED,{C.PA,1},C.ED,{C.PA,2},C.ED,
        {C.SD,1},{C.PA,3},C.ED,{C.WV,455},{C.PA,4},C.ED,
        {C.SD,2},{C.PA,4},C.ED,{C.SD,1},{C.WV,36},{C.PA,5},C.ED,
        {C.AT,trigger},{C.PA,6},C.O2
    }
end
local portrait = {{C.TN,1},{C.RF,4779},C.NO,{C.PA,0},C.OV}
local actions = {
    [36]=idle, [38]=hurt, [40]=sword(1),
    -- Native spell trigger, using the same red sword motion; not a new image.
    [44]=sword(8), [59]=portrait, [68]=portrait
}
if MOD.actions == nil then
    assert(ACTData[438] == nil, '[CaiDemonKing] ACTData[438] is already owned')
    ACTData[438] = actions
    MOD.actions = actions
end
