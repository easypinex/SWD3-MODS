-- 軒轅劍參：雲和山的彼端 Steam 版
-- 武器熟練度倍率選單面板

SWD3ProficiencyMultiplierUI = SWD3ProficiencyMultiplierUI or {}

local UI = SWD3ProficiencyMultiplierUI
local PRESETS = { 0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 50.0, 100.0 }
local LABELS = { '0.5', '1', '2', '5', '10', '20', '50', '100' }

local F8_SCANCODE = 65
local PANEL_X = 10
local TITLE_Y = 398
local LABEL_Y = 419
local TRACK_Y = 438
local HELP_Y = 458
local NODE_START_X = 16
local NODE_SPACING = 24
local TRACK_HIT_TOP = 431
local TRACK_HIT_BOTTOM = 453
local MENU_DRAW_TIMEOUT_MS = 250
local KEY_TOGGLE_DEBOUNCE_MS = 300

UI.visible = true
UI.lastMenuDrawTick = -10000
UI.lastToggleTick = -10000

local function drawText(text, x, y, color, background, font)
    StringFunc.DrawString(text, x, y, font or 0, color, background, 1)
end

local function findSelectedIndex()
    local current = SWD3ProficiencyMultiplier.GetMultiplier()

    for index, preset in ipairs(PRESETS) do
        if math.abs(current - preset) < 0.0001 then
            return index
        end
    end

    return #PRESETS
end

local function drawMultiplierPanel()
    UI.lastMenuDrawTick = GetTicks()

    if not UI.visible then
        return
    end

    local selectedIndex = findSelectedIndex()
    local current = SWD3ProficiencyMultiplier.GetMultiplier()
    local normalColor = DrawFunc.Color(220, 208, 170, 255)
    local selectedColor = DrawFunc.Color(255, 210, 72, 255)
    local titleColor = DrawFunc.Color(255, 244, 205, 255)
    local shadowColor = DrawFunc.Color(36, 24, 16, 220)

    drawText(
        string.format('武器熟練倍率 x%s', LABELS[selectedIndex]),
        PANEL_X,
        TITLE_Y,
        titleColor,
        shadowColor,
        0
    )

    for index, label in ipairs(LABELS) do
        local labelX = NODE_START_X + (index - 1) * NODE_SPACING
        if #label >= 3 then
            labelX = labelX - 6
        elseif #label >= 2 then
            labelX = labelX - 3
        end

        drawText(
            label,
            labelX,
            LABEL_Y,
            index == selectedIndex and selectedColor or normalColor,
            shadowColor,
            0
        )
    end

    drawText('----------------------', NODE_START_X, TRACK_Y, normalColor, shadowColor, 0)

    for index = 1, #PRESETS do
        local nodeX = NODE_START_X + (index - 1) * NODE_SPACING
        drawText(
            index == selectedIndex and '@' or 'o',
            nodeX,
            TRACK_Y,
            index == selectedIndex and selectedColor or normalColor,
            shadowColor,
            0
        )
    end

    drawText('點擊倍率節點　F8 隱藏', PANEL_X, HELP_Y, normalColor, shadowColor, 0)
end

local function isMenuPanelActive()
    return GetTicks() - UI.lastMenuDrawTick <= MENU_DRAW_TIMEOUT_MS
end

local function handleMultiplierClick()
    if not UI.visible or not isMenuPanelActive() then
        return
    end

    local mouseX = InputFunc.MouseX
    local mouseY = InputFunc.MouseY
    local firstX = NODE_START_X - math.floor(NODE_SPACING / 2)
    local lastX = NODE_START_X + (#PRESETS - 1) * NODE_SPACING
        + math.floor(NODE_SPACING / 2)

    if mouseY < TRACK_HIT_TOP or mouseY > TRACK_HIT_BOTTOM
        or mouseX < firstX or mouseX > lastX then
        return
    end

    local nearestIndex = math.floor(
        (mouseX - NODE_START_X) / NODE_SPACING + 0.5
    ) + 1

    nearestIndex = math.max(1, math.min(#PRESETS, nearestIndex))
    SWD3ProficiencyMultiplier.SetMultiplier(PRESETS[nearestIndex])
end

local function handleVisibilityKey(_, keyScancode)
    if keyScancode ~= F8_SCANCODE then
        return
    end

    local now = GetTicks()
    if now - UI.lastToggleTick < KEY_TOGGLE_DEBOUNCE_MS then
        return
    end

    UI.lastToggleTick = now
    UI.visible = not UI.visible
    log(string.format(
        '[ProficiencyMultiplier] Menu panel %s',
        UI.visible and 'shown' or 'hidden'
    ))
end

OnEvent = OnEvent or {}
OnEvent.DrawMenuAfter = OnEvent.DrawMenuAfter or {}
OnEvent.InputClick = OnEvent.InputClick or {}
OnEvent.InputKeyDown = OnEvent.InputKeyDown or {}

table.insert(OnEvent.DrawMenuAfter, drawMultiplierPanel)
table.insert(OnEvent.InputClick, handleMultiplierClick)
table.insert(OnEvent.InputKeyDown, handleVisibilityKey)
