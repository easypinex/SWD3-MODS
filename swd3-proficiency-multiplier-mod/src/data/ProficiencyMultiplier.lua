-- 軒轅劍參：雲和山的彼端 Steam 版
-- 武器熟練度 100 倍 MOD

SWD3ProficiencyMultiplier = SWD3ProficiencyMultiplier or {}
SWD3ProficiencyMultiplier.multiplier =
    SWD3ProficiencyMultiplier.multiplier or 100.0

local MIN_MULTIPLIER = 0.5
local MAX_MULTIPLIER = 100.0
local originalThresholds = {}

local function applyProficiencyMultiplier()
    local multiplier = tonumber(SWD3ProficiencyMultiplier.multiplier)

    if multiplier == nil then
        log('[ProficiencyMultiplier] Invalid multiplier; using 100.0')
        multiplier = 100.0
    elseif multiplier < MIN_MULTIPLIER then
        log('[ProficiencyMultiplier] Multiplier below 0.5; clamped to 0.5')
        multiplier = MIN_MULTIPLIER
    elseif multiplier > MAX_MULTIPLIER then
        log('[ProficiencyMultiplier] Multiplier above 100.0; clamped to 100.0')
        multiplier = MAX_MULTIPLIER
    end

    SWD3ProficiencyMultiplier.multiplier = multiplier

    local changedCount = 0

    for itemId, itemData in pairs(GameData.ItemTemp) do
        if itemData.IT_09 == true
            and type(itemData.ProficientHard) == 'number'
            and itemData.ProficientHard > 0 then

            if originalThresholds[itemId] == nil then
                originalThresholds[itemId] = itemData.ProficientHard
            end

            local adjustedThreshold = math.floor(
                originalThresholds[itemId] / multiplier + 0.5
            )

            itemData.ProficientHard = math.max(1, adjustedThreshold)
            changedCount = changedCount + 1
        end
    end

    log(string.format(
        '[ProficiencyMultiplier] Applied x%.3f to %d weapons',
        multiplier,
        changedCount
    ))
end

-- 非系統 MOD 會在遊戲基礎資料載入完成後執行，因此直接套用最可靠。
-- 若未來版本改變載入順序，才退回到連續的 SysInit 事件列表。
if GameData ~= nil and GameData.ItemTemp ~= nil then
    applyProficiencyMultiplier()
else
    log('[ProficiencyMultiplier] Item data not ready; waiting for SysInit')
    OnEvent = OnEvent or {}
    OnEvent.SysInit = OnEvent.SysInit or {}
    table.insert(OnEvent.SysInit, applyProficiencyMultiplier)
end
