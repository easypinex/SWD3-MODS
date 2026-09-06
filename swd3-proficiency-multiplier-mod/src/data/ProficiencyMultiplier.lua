-- 軒轅劍參：雲和山的彼端 Steam 版
-- 武器熟練度 100 倍 MOD：倍率核心

SWD3ProficiencyMultiplier = SWD3ProficiencyMultiplier or {}
SWD3ProficiencyMultiplier.multiplier =
    SWD3ProficiencyMultiplier.multiplier or 100.0

local DEFAULT_MULTIPLIER = 100.0
local SETTING_KEY = 'SWD3ProficiencyMultiplierValue'
local PRESET_MULTIPLIERS = { 0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 50.0, 100.0 }
local originalThresholds = {}

local function normalizeMultiplier(value)
    local numericValue = tonumber(value)

    if numericValue ~= nil then
        for _, preset in ipairs(PRESET_MULTIPLIERS) do
            if math.abs(numericValue - preset) < 0.0001 then
                return preset
            end
        end
    end

    return nil
end

local function captureOriginalThresholds()
    if GameData == nil or GameData.ItemTemp == nil then
        return false
    end

    for itemId, itemData in pairs(GameData.ItemTemp) do
        if itemData.IT_09 == true
            and type(itemData.ProficientHard) == 'number'
            and itemData.ProficientHard > 0
            and originalThresholds[itemId] == nil then

            originalThresholds[itemId] = itemData.ProficientHard
        end
    end

    return true
end

local function applyProficiencyMultiplier(multiplier)
    if not captureOriginalThresholds() then
        log('[ProficiencyMultiplier] Item data not ready; multiplier not applied')
        return false, 0
    end

    local changedCount = 0

    for itemId, itemData in pairs(GameData.ItemTemp) do
        if originalThresholds[itemId] ~= nil then
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

    return true, changedCount
end

function SWD3ProficiencyMultiplier.GetMultiplier()
    return normalizeMultiplier(SWD3ProficiencyMultiplier.multiplier)
        or DEFAULT_MULTIPLIER
end

function SWD3ProficiencyMultiplier.SetMultiplier(value)
    local multiplier = normalizeMultiplier(value)

    if multiplier == nil then
        log('[ProficiencyMultiplier] Invalid preset; using 100.0')
        multiplier = DEFAULT_MULTIPLIER
    end

    SWD3ProficiencyMultiplier.multiplier = multiplier

    if Setting ~= nil then
        Setting[SETTING_KEY] = multiplier
    end

    return applyProficiencyMultiplier(multiplier)
end

function SWD3ProficiencyMultiplier.GetPresetMultipliers()
    local presets = {}

    for index, multiplier in ipairs(PRESET_MULTIPLIERS) do
        presets[index] = multiplier
    end

    return presets
end

local function initializeProficiencyMultiplier()
    local multiplier = nil

    if Setting ~= nil then
        multiplier = normalizeMultiplier(Setting[SETTING_KEY])
    end

    if multiplier == nil then
        multiplier = normalizeMultiplier(SWD3ProficiencyMultiplier.multiplier)
            or DEFAULT_MULTIPLIER
    end

    SWD3ProficiencyMultiplier.SetMultiplier(multiplier)
end

-- MOD Lua 早於 Save/setting_v2.lua 載入；基礎腳本會建立 SysInit 1～3，
-- 因此固定使用連續的第 4 個事件，在設定檔載入完成後套用保存倍率。
OnEvent = OnEvent or {}
OnEvent.SysInit = OnEvent.SysInit or {}
OnEvent.SysInit[4] = initializeProficiencyMultiplier
