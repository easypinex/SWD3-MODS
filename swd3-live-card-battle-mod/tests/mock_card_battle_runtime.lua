local sourcePath = assert(arg[1], 'CardBattleRules.lua path is required')

local function equal(actual, expected, message)
    if actual ~= expected then
        error(string.format('%s: expected %s, got %s', message, tostring(expected), tostring(actual)))
    end
end

local function truthy(value, message)
    if not value then
        error(message)
    end
end

assert(loadfile(sourcePath))()

local Rules = assert(SWD3LiveCardBattle and SWD3LiveCardBattle.Rules, 'Rules module was not loaded')

-- 難度設定：所有項目預設 1.0x；每項都只能在 0.5x～2.0x 間以 0.1x 調整。
local difficulty = Rules.NewDifficultySettings()
for _, key in ipairs(Rules.DIFFICULTY_SETTING_KEYS) do
    equal(difficulty[key], 1.0, 'Difficulty defaults to 1.0x: ' .. key)
end
equal(Rules.IsRewardAllowedForDifficulty(difficulty), true, 'Default difficulty retains rewards')
local nextDifficulty, changedDifficulty = Rules.AdjustDifficultySetting(difficulty, 'hp', -0.1)
equal(changedDifficulty, true, 'Difficulty can be reduced by one tenth')
equal(nextDifficulty, 0.9, 'Difficulty reduction uses 0.1x step')
truthy(math.abs(Rules.GetDifficultyAverage(difficulty) - 0.98) < 0.0001, 'Difficulty average includes every adjustment')
equal(Rules.IsRewardAllowedForDifficulty(difficulty), false, 'Average below 1.0x disables rewards')
Rules.AdjustDifficultySetting(difficulty, 'attack', 0.1)
equal(Rules.GetDifficultyAverage(difficulty), 1.0, 'A higher adjustment can offset a lower adjustment')
equal(Rules.IsRewardAllowedForDifficulty(difficulty), true, 'Average at 1.0x retains rewards')
Rules.AdjustDifficultySetting(difficulty, 'hp', 2.0)
equal(difficulty.hp, 2.0, 'Difficulty caps at 2.0x')
Rules.AdjustDifficultySetting(difficulty, 'hp', -3.0)
equal(difficulty.hp, 0.5, 'Difficulty floors at 0.5x')
equal(Rules.ScaleDifficultyStat(101, 1.5), 152, 'Positive battle stats scale with rounding')
equal(Rules.ScaleDifficultyStat(0, 2.0), 0, 'Zero-valued special stats are preserved')

local itemTemps = {
    [101] = { Name = '黏怪', IT_12 = true, isBattleChar = true, ACT = 101, Level = 12 },
    [133] = { Name = '亞格瑞斯', IT_12 = true, isBattleChar = true, ACT = 133, Level = 26 },
    [401] = { Name = '戰馬', IT_12 = true, ACT = 401 },
    [621] = { Name = '藥草', IT_13 = true, UsePlace = 4 },
    [999] = { Name = '殘缺活物', IT_12 = true, isBattleChar = true, ACT = 999 }
}

local items = {
    { ItemTempID = 101, Count = 2, Count_New = 1, Stock = 1 },
    { ItemTempID = 133, Count = 1, Count_New = 0 },
    { ItemTempID = 401, Count = 1, Count_New = 0 },
    { ItemTempID = 621, Count = 4, Count_New = 0 },
    { ItemTempID = 999, Count = 1, Count_New = 0 }
}

-- 卡片資格：只接受真正可進戰鬥的 IT_12，戰馬及資料不完整活物必須排除。
truthy(Rules.IsEligibleCard(itemTemps[101]), 'Battle living item should be eligible')
equal(Rules.IsEligibleCard(itemTemps[401]), false, 'War horse should not be eligible')
equal(Rules.IsEligibleCard(itemTemps[621]), false, 'Non-living item should not be eligible')
equal(Rules.IsEligibleCard(itemTemps[999]), false, 'Incomplete living item should not be eligible')

local cards = Rules.GetAvailableCards(items, itemTemps)
equal(#cards, 2, 'Only battle-ready owned living cards are listed')
equal(cards[1].slot, 1, 'First card source slot')
equal(cards[1].available, 2, 'Reserved copies are excluded from availability')
equal(cards[2].slot, 2, 'Second card source slot')
equal(cards[2].available, 1, 'Second card availability')

-- 圖鑑與特殊／首領可列出未持有的完整戰鬥活物，且後續不會預留 Stock。
itemTemps[777] = { Name = '撒旦賽特', IT_12 = true, isBattleChar = true, ACT = 777, Level = 55, Race = 0, IT_06 = true, NotInBook = true }
itemTemps[75] = { Name = '撒旦賽特（首領）', isBattleChar = true, ACT = 75, Level = 60, Race = 23, IT_06 = true }
equal(Rules.IsEligibleCard(itemTemps[75]), false, 'Non-item boss is not an owned living card')
equal(Rules.IsBattleReady(itemTemps[75]), true, 'Non-item boss remains a valid virtual enemy')
local catalogueCards = Rules.GetCatalogueCards(itemTemps)
equal(#catalogueCards, 3, 'Catalogue includes battle-ready non-IT_12 bosses that are in the book')
equal(catalogueCards[1].itemId, 75, 'Catalogue keeps Satan Septem-like boss ID')
local specialCards = Rules.GetSpecialCards(itemTemps)
equal(#specialCards, 1, 'Special list excludes custom enemy IDs even with copied boss flags')
equal(specialCards[1].itemId, 75, 'Special list keeps non-IT_12 boss ID')
for _, id in ipairs({10001, 10096, 11001, 11006, 99999}) do
    itemTemps[id] = {Name='Custom card', IT_12=true, isBattleChar=true, ACT=75, Level=60, IT_06=true, NotInBook=true}
end
equal(#Rules.GetSpecialCards(itemTemps), 1, 'Static pact cards and Cai custom templates never enter Special')
local ownedCustom = Rules.GetAvailableCards({{ItemTempID=10001,Count=1}}, itemTemps)
equal(#ownedCustom, 1, 'Owned custom cards remain available under My Cards')

local menu = Rules.NewMenuState()
local virtualCard = specialCards[1]
local changed, selectedCount = Rules.AdjustMenuCard(menu, virtualCard, 1)
equal(changed, true, 'Virtual boss can be selected')
equal(selectedCount, 1, 'Virtual boss selection count')
local virtualSelection = Rules.BuildMenuSelection(menu)
equal(virtualSelection[1].source, 'virtual', 'Virtual selection has no inventory slot source')
local normalizedVirtual, virtualError = Rules.ValidateSelection(items, itemTemps, virtualSelection)
equal(virtualError, nil, 'Virtual selection validates from battle data')
local virtualReservations, virtualReservationError = Rules.ReserveSelection(items, normalizedVirtual)
equal(virtualReservationError, nil, 'Virtual selection requires no reservation')
equal(#virtualReservations, 0, 'Virtual selection creates zero Stock entries')

-- 同一欄位多次點選會合併；五張上限可跨不同卡片。
local selection, selectionError = Rules.ValidateSelection(items, itemTemps, {
    { slot = 1, count = 1 },
    { slot = 2, count = 1 },
    { slot = 1, count = 1 }
})
equal(selectionError, nil, 'Valid selection has no error')
equal(#selection, 2, 'Duplicate slots are merged')
equal(selection[1].count, 2, 'First slot merged count')
equal(selection[2].count, 1, 'Second slot count')

local invalid, invalidError = Rules.ValidateSelection(items, itemTemps, {})
equal(invalid, nil, 'Empty selection is rejected')
equal(invalidError, 'challenge requires one to five cards', 'Empty selection reason')

invalid, invalidError = Rules.ValidateSelection(items, itemTemps, {
    { slot = 1, count = 2 },
    { slot = 2, count = 1 },
    { source = 'virtual', itemId = 75, count = 3 }
})
equal(invalid, nil, 'Six-card selection is rejected')
equal(invalidError, 'challenge requires one to five cards', 'Six-card selection reason')

invalid, invalidError = Rules.ValidateSelection(items, itemTemps, { { slot = 1, count = 3 } })
equal(invalid, nil, 'Selection beyond unreserved inventory is rejected')
equal(invalidError, 'selection exceeds available card count', 'Insufficient card reason')

invalid, invalidError = Rules.ValidateSelection(items, itemTemps, { { slot = 3, count = 1 } })
equal(invalid, nil, 'Non-battle living item is rejected')
equal(invalidError, 'selection contains a non-battle living item', 'Non-battle item reason')

-- 預留不得改 Count；勝利後釋放預留，物品數量與原本 Stock 都必須完整回復。
local count1Before = items[1].Count
local count2Before = items[2].Count
local reservations, reservationError = Rules.ReserveSelection(items, selection)
equal(reservationError, nil, 'Reservation succeeds')
equal(#reservations, 2, 'Two reservation rows')
equal(items[1].Count, count1Before, 'Reservation does not deduct first card')
equal(items[2].Count, count2Before, 'Reservation does not deduct second card')
equal(items[1].Stock, 3, 'Reservation adds to existing first Stock')
equal(items[2].Stock, 1, 'Reservation creates second Stock')
Rules.ReleaseReservations(items, reservations)
equal(items[1].Stock, 1, 'Release restores pre-existing first Stock')
equal(items[2].Stock, nil, 'Release removes MOD-created second Stock')
equal(items[1].Count, count1Before, 'Victory leaves first card count unchanged')
equal(items[2].Count, count2Before, 'Victory leaves second card count unchanged')

-- 戰鬥中原版若增加同一卡的 Stock，MOD 只能移除自己的預留量。
reservations, reservationError = Rules.ReserveSelection(items, selection)
equal(reservationError, nil, 'Second reservation succeeds')
items[1].Stock = items[1].Stock + 1
Rules.ReleaseReservations(items, reservations)
equal(items[1].Stock, 2, 'Release preserves unrelated Stock added during battle')
equal(items[2].Stock, nil, 'Release still clears second MOD reservation')
items[1].Stock = 1

-- Game Over 後讀檔可能已把 Stock 還原；釋放記憶體中的舊 reservation 不可再扣掉
-- 新載入存檔原有的 Stock。
reservations, reservationError = Rules.ReserveSelection(items, selection)
equal(reservationError, nil, 'Recovery reservation succeeds')
items[1].Stock = 1
items[2].Stock = nil
Rules.ReleaseReservations(items, reservations)
equal(items[1].Stock, 1, 'Release never drops below pre-reservation Stock after load recovery')
equal(items[2].Stock, nil, 'Release keeps restored empty Stock empty after load recovery')

-- 收妖產生的同 ID 額外卡必須以原版 ItemClass 的欄位／堆疊規則移除；
-- 純規則只決定正確的移除目標，不自行重排背包。
items[2].Count_New = 1
equal(Rules.CountItemCopies(items, 133), 2, 'Capture counting includes newly gained copy')
local captureRemoval = Rules.FindCaptureRemoval(items, 133, 1)
equal(captureRemoval.slot, 2, 'Capture cleanup finds the matching card slot')
equal(captureRemoval.itemId, 133, 'Capture cleanup keeps matching card ID')
equal(captureRemoval.count, 1, 'Capture cleanup removes exactly one copy')
equal(Rules.FindCaptureRemoval(items, 133, 2), nil, 'Capture cleanup never removes an original-only card')
equal(Rules.FindCaptureRemoval(items, 401, 0).slot, 3, 'Capture lookup can target another owned live item')
equal(Rules.FindCaptureRemoval(items, 12345), nil, 'Missing capture item has no removal target')
items[2].Count_New = 0

-- 選卡完成後背包若被其他流程改動，已套用的預留必須回滾。
items[2].ItemTempID = 401
reservations, reservationError = Rules.ReserveSelection(items, selection)
equal(reservations, nil, 'Changed inventory aborts reservation')
equal(reservationError, 'inventory changed before reservation', 'Changed inventory reason')
equal(items[1].Stock, 1, 'Partial reservation is rolled back')
items[2].ItemTempID = 133

-- 專用戰場必須保留選擇次數（含同一張卡兩次），最多可生成五個敵人。
local fieldSelection = {
    { slot = 1, itemId = 101, count = 2 },
    { slot = 2, itemId = 133, count = 1 },
    { source = 'virtual', itemId = 75, count = 2 }
}
local field, fieldError = Rules.BuildBattleField(fieldSelection, { backgroundId = 4 })
equal(fieldError, nil, 'Battle field generation succeeds')
equal(field.iBattleFieldBackground, 4, 'Configured battle background')
equal(#field.tCharActQ, 5, 'Battle field has exactly five enemies')
equal(field.tCharActQ[1].ItemTempID, 101, 'First selected enemy')
equal(field.tCharActQ[2].ItemTempID, 101, 'Repeated selected enemy')
equal(field.tCharActQ[3].ItemTempID, 133, 'Third selected enemy')
equal(field.tCharActQ[4].ItemTempID, 75, 'Fourth enemy is a virtual boss')
equal(field.tCharActQ[5].ItemTempID, 75, 'Fifth enemy preserves repeated virtual boss')
truthy(field.tCharActQ[4].X ~= field.tCharActQ[5].X, 'Fourth and fifth enemies use distinct positions')
truthy(field.tCharActQ[1].X ~= field.tCharActQ[2].X, 'Enemies use distinct configured positions')

-- 預設模式僅返還卡片，不提供原版戰鬥經驗、金錢或額外法寶／絕招經驗。
local rewards = Rules.BuildRewardValues(100, 50, 20, 10, false)
equal(rewards.PlayerExp, 0, 'Challenge default experience is disabled')
equal(rewards.Money, 0, 'Challenge default money is disabled')
equal(rewards.MItemExp, 0, 'Challenge default magic-item experience is disabled')
equal(rewards.SpecialSkillExp, 0, 'Challenge default special-skill experience is disabled')

rewards = Rules.BuildRewardValues(100, 50, 20, 10, true)
equal(rewards.PlayerExp, 100, 'Optional normal experience is preserved')
equal(rewards.Money, 50, 'Optional normal money is preserved')

-- 選卡面板：W/S 或上下移動焦點，A/D 或左右逐張調整；空白鍵在卡片列
-- 切換選取，在開始列啟動。這些規則不依賴遊戲輸入事件，能快速回歸。
cards[1].available = 5
cards[2].available = 5
local panel = Rules.NewPanelState(cards)
equal(panel.focus, 1, 'Panel starts at first card')
equal(Rules.GetPanelRowCount(panel), 4, 'Two cards plus start and cancel rows')
equal(Rules.MovePanelFocus(panel, 1), 2, 'Focus moves down')
equal(Rules.MovePanelFocus(panel, -1), 1, 'Focus moves up')

local changed, current = Rules.AdjustPanelCard(panel, 1, 1)
equal(changed, true, 'Right/D adds first card')
equal(current, 1, 'One first card is selected')
changed, current = Rules.AdjustPanelCard(panel, 1, 1)
equal(changed, true, 'Repeated card can be selected')
equal(current, 2, 'Two copies selected')
changed, current = Rules.AdjustPanelCard(panel, 2, 1)
equal(changed, true, 'A second card can continue toward five-card limit')
equal(Rules.GetPanelTotal(panel), 3, 'Panel totals three cards')
changed, current = Rules.AdjustPanelCard(panel, 2, 1)
equal(changed, true, 'Panel allows a fourth card')
changed, current = Rules.AdjustPanelCard(panel, 2, 1)
equal(changed, true, 'Panel allows a fifth card')
changed, current = Rules.AdjustPanelCard(panel, 2, 1)
equal(changed, false, 'Panel rejects more than five cards')
equal(current, 'challenge requires one to five cards', 'Five-card limit is enforced')

panel.focus = 1
changed, current = Rules.ToggleFocusedPanelCard(panel)
equal(changed, true, 'Space toggles a selected card row')
equal(current, 0, 'Space removes all copies of focused selected card')
equal(Rules.GetPanelTotal(panel), 3, 'Remaining selection is preserved')
changed, current = Rules.ToggleFocusedPanelCard(panel)
equal(changed, true, 'Space adds an unselected card row')
equal(current, 1, 'Space adds one card')

panel.focus = #panel.cards + 1
local action, actionError = Rules.ActivatePanelFocus(panel)
equal(action, 'start', 'Space on start row requests battle')
equal(actionError, nil, 'Start action has no error')
panel.focus = #panel.cards + 2
action = Rules.ActivatePanelFocus(panel)
equal(action, 'cancel', 'Space on cancel row cancels panel')

local layout = {
    x = 200,
    y = 50,
    width = 450,
    headerHeight = 50,
    rowHeight = 30,
    minusX = 300,
    plusX = 360,
    buttonWidth = 38,
    actionGap = 12,
    actionHeight = 30
}
local hit = Rules.HitTestPanel(panel, 560, 105, layout)
equal(hit.type, 'card', 'Mouse click hits first card row')
equal(hit.cardIndex, 1, 'Mouse click returns first card index')
equal(hit.delta, 1, 'Mouse click on plus button increments')
hit = Rules.HitTestPanel(panel, 230, 180, layout)
equal(hit.type, 'start', 'Mouse click hits start button')
hit = Rules.HitTestPanel(panel, 230, 225, layout)
equal(hit.type, 'cancel', 'Mouse click hits cancel button')

-- 發布版保留原版獎勵；不得沿用早期純挑戰的全零獎勵設定。
rewards = Rules.BuildRewardValues(100, 50, 20, 10, true)
equal(rewards.PlayerExp, 100, 'Release policy retains normal experience')
equal(rewards.Money, 50, 'Release policy retains normal money')

io.write('PASS: live card battle rules mock runtime\n')
