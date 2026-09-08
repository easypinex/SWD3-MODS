local rulesPath = assert(arg[1], 'CardBattleRules.lua path is required')
local runtimePath = assert(arg[2], 'LiveCardBattle.lua path is required')
local testDir=runtimePath:gsub('src[\\/]data[\\/]LiveCardBattle.lua$','tests/')
assert(loadfile(testDir..'party_fixture.lua'))()

local function equal(actual, expected, message)
    if actual ~= expected then
        error(string.format('%s: expected %s, got %s', message, tostring(expected), tostring(actual)))
    end
end

local now = 1000
local battleId = nil
local startedBattleId = nil
local currentSelection = 0
local observedMenus = {}
local logs = {}
-- 主選單 → 難度（生命降到 0.9x）→ 我的活物（黏怪兩次）→ 返回
-- → 圖鑑 → 魔神 → 亞格瑞斯 → 返回 → 返回 → 開始。
local menuSelections = { 5, 2, 3, 1, 1, 1, 2, 2, 1, 2, 2, 2, 1, 1, 6 }

OnEvent = {}
SaveData = {
    Items = {
        { ItemTempID = 101, Count = 2, Count_New = 0 },
        { ItemTempID = 133, Count = 1, Count_New = 0 },
        { ItemTempID = 401, Count = 1, Count_New = 0 }
    }
}
GameData = {
    ItemTemp = {
        [101] = { Name = 'ItemName101', IT_12 = true, isBattleChar = true, ACT = 101, Level = 12, Race = 8, GainEXP = 12, GainGold = 8, DropItems = { 501 }, DropItemsRate = { 20 } },
        [133] = { Name = 'ItemName133', IT_12 = true, isBattleChar = true, ACT = 133, Level = 26, Race = 1, GainEXP = 26, GainGold = 18, DropItems = { 502 }, DropItemsRate = { 10 } },
        [401] = { Name = 'ItemName401', IT_12 = true, ACT = 401 },
        [777] = { Name = 'ItemName777', IT_12 = true, isBattleChar = true, ACT = 777, Level = 55, Race = 0, IT_06 = true, NotInBook = true }
    },
    Race = {
        [0] = { Name = 'RaceGod' }, [1] = { Name = 'RaceDemon' }, [8] = { Name = 'RaceMonster' }
    }
}
BattleField = {}
BattleEnv = { enemys = {}, players = {} }
BattleEnemys = {}
BSC = {
    noOverCalls = 0,
    battleBreakCalls = 0,
    NoOVER = function() BSC.noOverCalls = BSC.noOverCalls + 1 end,
    BattleBreak = function() BSC.battleBreakCalls = BSC.battleBreakCalls + 1 end
}
StringDB = function(key)
    local text = {
        ItemName101 = '黏怪', ItemName133 = '亞格瑞斯', ItemName401 = '戰馬', ItemName777 = '撒旦賽特',
        RaceGod = '天神', RaceDemon = '魔神', RaceMonster = '妖怪',
        LCB_TITLE = '挑戰模式'
    }
    return text[key] or key
end
GetTicks = function() return now end
log = function(message) table.insert(logs, message) end
GameFunc = {
    GetBattleFieldID = function() return battleId end,
    RunScene = function(_, sceneName)
        assert(Scene[sceneName], 'missing native menu scene')()
    end
}
ESC = {
    Menu = function(title, rows)
        assert(type(rows) == 'table' and #rows > 0, 'native menu receives non-empty rows')
        assert(rows[1]:sub(-4) == '    ', 'native menu rows include UTF-8 diagnostic padding')
        table.insert(observedMenus, { title = title, rows = rows })
        currentSelection = table.remove(menuSelections, 1) or 0
    end,
    GetMENUSelect = function() return currentSelection end,
    StartBattle = function(id)
        equal(SWD3LiveCardBattle.GetInputCaptureStatus().selectorRunning, false, 'Starting battle clears selector flag before native transition')
        startedBattleId = id
        battleId = id
        for i=1,4 do for _,fn in ipairs(OnEvent.Battle_PlayerInit) do fn(i) end end
    end
}
ItemClass = {
    AddItem = function(id,n)
        for _,item in ipairs(SaveData.Items) do
            if item.ItemTempID==id then item.Count_New=item.Count_New+n;return 0 end
        end
        table.insert(SaveData.Items,{ItemTempID=id,Count=0,Count_New=n});return 1
    end,
    DelItem = function(slot, itemId, count)
        local item = SaveData.Items[slot]
        if item == nil or item.ItemTempID ~= itemId then
            error('ItemClass.DelItem received wrong capture target')
        end
        item.Count_New = item.Count_New - count
        if item.Count_New < 0 then
            item.Count = item.Count + item.Count_New
            item.Count_New = 0
        end
    end
}

assert(loadfile(rulesPath))()
assert(loadfile((runtimePath:gsub('LiveCardBattle.lua$','LiveCardPartyState.lua'))))()
OnEvent.Battle_RestoreItem={main=function() end}
assert(loadfile((runtimePath:gsub('LiveCardBattle.lua$','LiveCardInventory.lua'))))()
assert(loadfile(runtimePath))()

local function event(name, index)
    return assert(OnEvent[name] and OnEvent[name][index], 'missing event ' .. name)
end

event('GameStart', 1)()
event('DrawMenuAfter', 1)()
equal(event('InputClick', 1)(nil, 66), true, 'F9 input is handled')
equal(#menuSelections, 0, 'All nested native-menu choices are consumed')
equal(observedMenus[1].title, '挑戰模式', 'Native menu title uses the player-facing feature name')
local function visibleRow(row)
    return row:sub(1, -5)
end
for _, menuIndex in ipairs({ 2, 3, 4, 5, 7, 8, 9, 11, 12, 13, 14 }) do
    local rows = observedMenus[menuIndex].rows
    equal(visibleRow(rows[1]), '返回上層', 'Submenu has first fixed return row: ' .. menuIndex)
    equal(visibleRow(rows[#rows]), '返回上層', 'Submenu has last fixed return row: ' .. menuIndex)
end
equal(startedBattleId, 'MOD_CARD_CHALLENGE', 'Native selector starts custom battle')
equal(#BattleField.MOD_CARD_CHALLENGE.tCharActQ, 3, 'Battle field has three selected enemies')
equal(BattleField.MOD_CARD_CHALLENGE.tCharActQ[1].ItemTempID, 101, 'First enemy is owned selected card')
equal(BattleField.MOD_CARD_CHALLENGE.tCharActQ[2].ItemTempID, 101, 'Repeated owned card is preserved')
equal(BattleField.MOD_CARD_CHALLENGE.tCharActQ[3].ItemTempID, 133, 'Catalogue card is usable without owning it')
equal(SaveData.Items[1].Count, 2, 'Start does not deduct owned card count')
equal(SaveData.Items[1].Stock, 2, 'Owned card copies are reserved')
equal(SaveData.Items[2].Stock, nil, 'Virtual catalogue card has no Stock reservation')
equal(SWD3LiveCardBattle.State.activeChallenge.difficulty.hp, 0.9, 'Difficulty menu stores the selected HP multiplier')
equal(SWD3LiveCardBattle.State.activeChallenge.rewardsAllowed, false, 'Difficulty average below 1.0x disables rewards')
equal(GameData.ItemTemp[101].GainEXP, 0, 'Low difficulty temporarily disables source experience')
equal(GameData.ItemTemp[101].GainGold, 0, 'Low difficulty temporarily disables source gold')
equal(#GameData.ItemTemp[101].DropItems, 0, 'Low difficulty temporarily disables normal drops')
equal(SWD3LiveCardBattle.GetInputCaptureStatus().implementation, 'native ESC.Menu Scene coroutine', 'Native menu implementation is reported')
event('Battle_Enter', 1)()
equal(BSC.noOverCalls, 1, 'Challenge battle enables native no-Game-Over mode')

BattleEnemys[1] = { NPC_GUID = 101, NPCData = { HP = 100, MaxHP = 100, ATK = 40, DEF = 30, SPD = 20, WIS = 25 } }
event('Battle_EnemyInit', 1)(1)
equal(BattleEnemys[1].NPCData.HP, 90, 'HP multiplier scales current HP')
equal(BattleEnemys[1].NPCData.MaxHP, 90, 'HP multiplier scales maximum HP')
equal(BattleEnemys[1].NPCData.ATK, 40, 'Unchanged attack setting leaves ATK unchanged')
local sawDifficultySummary, sawAppliedStats = false, false
for _, message in ipairs(logs) do
    if message:find('challenge difficulty:', 1, true) and message:find('average=0.98x', 1, true) then
        sawDifficultySummary = true
    end
    if message:find('difficulty applied:', 1, true) and message:find('before {HP=100/100', 1, true) then
        sawAppliedStats = true
    end
end
equal(sawDifficultySummary, true, 'Challenge start logs difficulty average and reward state')
equal(sawAppliedStats, true, 'Enemy initialization logs before-and-after combat stats')
event('Battle_EnemyInit', 1)(1)
equal(BattleEnemys[1].NPCData.HP, 90, 'Enemy init re-entry never stacks difficulty scaling')

OnEventValue = {}
event('BattleGain', 1)(100, 50, 20, 10)
equal(OnEventValue.PlayerExp, 0, 'Low difficulty battle gain experience is zero')
equal(OnEventValue.Money, 0, 'Low difficulty battle gain money is zero')
equal(OnEventValue.MItemExp, 0, 'Low difficulty battle gain magic-item experience is zero')
equal(OnEventValue.SpecialSkillExp, 0, 'Low difficulty battle gain special-skill experience is zero')

-- Game Over 會中斷原生選單 coroutine；模擬讀檔後首次物品欄繪製，應清除卡住的旗標與預留。
SWD3LiveCardBattle.State.selectorRunning = true
SWD3LiveCardBattle.State.selector = { interrupted = true }
battleId = nil
event('DrawMenuAfter', 1)()
equal(SWD3LiveCardBattle.GetInputCaptureStatus().selectorRunning, false, 'Interrupted battle recovery clears stale selector flag')
equal(SWD3LiveCardBattle.GetInputCaptureStatus().challengeActive, false, 'Interrupted battle recovery releases active challenge')
equal(SaveData.Items[1].Stock, nil, 'Interrupted battle recovery releases owned reservation')
equal(GameData.ItemTemp[101].GainEXP, 12, 'Interrupted battle recovery restores source experience')
equal(GameData.ItemTemp[101].GainGold, 8, 'Interrupted battle recovery restores source gold')
equal(#GameData.ItemTemp[101].DropItems, 1, 'Interrupted battle recovery restores normal drops')

event('Battle_RestoreItem', 1)()
equal(SaveData.Items[1].Stock, nil, 'Battle end releases owned reservation')
equal(SaveData.Items[1].Count, 2, 'Battle end preserves owned count')

-- 關閉選單或完成戰鬥後，隊伍草稿與難度都在本次遊戲執行期間保留。
equal(SWD3LiveCardBattle.Rules.GetMenuTotal(SWD3LiveCardBattle.State.draft), 3, 'Challenge team persists after battle cleanup')
equal(SWD3LiveCardBattle.State.draft.difficulty.hp, 0.9, 'Challenge difficulty persists after battle cleanup')
table.insert(menuSelections, 8)
event('DrawMenuAfter', 1)()
equal(event('InputClick', 1)(nil, 66), true, 'F9 reopens the persisted challenge draft')
local reopenedRows = observedMenus[#observedMenus].rows
equal(visibleRow(reopenedRows[4]), '已選隊伍 [3/5]', 'Reopened menu shows the persisted team')
equal(SWD3LiveCardBattle.State.draft.difficulty.hp, 0.9, 'Closing the reopened menu keeps the difficulty draft')

-- 自由挑戰中最後一名我方倒下時，以原生 BattleBreak 中止並回到遊戲，而非 Game Over。
SWD3LiveCardBattle.State.activeChallenge = { reservations = {}, pendingCaptureById = {}, capturedById = {} }
SWD3LiveCardBattle.State.selectorRunning = true
battleId = 'MOD_CARD_CHALLENGE'
BattleEnv.players[1] = {
    isPlayer=true,
    self = { isDeath = function() return true end },
    status = { HP = 0 }
}
SWD3LiveCardBattle.PartyState.Begin(function() end)
for i=1,4 do event('Battle_PlayerInit',1)(i) end
event('Battle_Enter', 1)()
event('Battle_Dead', 1)(1, 0, 0)
equal(BSC.noOverCalls, 2, 'Each challenge entry enables no-Game-Over mode')
equal(BSC.battleBreakCalls, 1, 'All-player defeat requests native battle break')
equal(SWD3LiveCardBattle.GetInputCaptureStatus().selectorRunning, false, 'Defeat return clears selector flag')
equal(SWD3LiveCardBattle.GetInputCaptureStatus().challengeActive, true, 'Death callback retains snapshot until native teardown')
event('Battle_RestoreItem',1)()
equal(SWD3LiveCardBattle.GetInputCaptureStatus().challengeActive, false, 'Teardown releases challenge state')

-- 收妖新增同 ID 後只移除本次額外的一張；原有選卡不會被刪除。
SaveData.Items[1].Count_New = SaveData.Items[1].Count_New + 1
BattleEnv.enemys[1] = { GUID = 101 }
event('Battle_Dead', 1)(1, 1, 2)
equal(SaveData.Items[1].Count_New, 1, 'No inactive challenge capture cleanup runs')

-- 與全魔物靈契同時啟用時，挑戰 MOD 不可先刪原生新增來源；
-- 正式 bridge 會在 Battle_RestoreItem 依自己的基線交換靜態卡。
SWD3AllMonsterStaticCapture = {
    captureRuntime = { active = {} },
    CardIdForEnemy = function(itemId) return itemId == 101 and 101 or nil end
}
SWD3LiveCardBattle.State.activeChallenge = { reservations = {}, pendingCaptureById = {}, capturedById = {}, captureBaseline = { [101] = 2 } }
battleId = 'MOD_CARD_CHALLENGE'
SaveData.Items[1].Count_New = SaveData.Items[1].Count_New + 1
BattleEnv.enemys[1] = { GUID = 101 }
event('Battle_Dead', 1)(1, 1, 2)
equal(SaveData.Items[1].Count_New, 2, 'Static catalogue delegation leaves the newly captured source for exchange')
equal(SWD3LiveCardBattle.State.activeChallenge.pendingCaptureById[101], nil, 'Delegated capture is not queued for local deletion')
SWD3AllMonsterStaticCapture = nil

event('GameStart', 1)()
equal(SWD3LiveCardBattle.Rules.GetMenuTotal(SWD3LiveCardBattle.State.draft), 0, 'A full game start resets the temporary team draft')
equal(SWD3LiveCardBattle.State.draft.difficulty.hp, 1.0, 'A full game start resets the temporary difficulty draft')

-- Cai entry resolves after both mods load and never starts an F9
-- reservation/difficulty lifecycle. The actual Cai Scene owns its battle.
local draft = SWD3LiveCardBattle.State.draft
draft.difficulty.hp = 0.5
local stock = SaveData.Items[1].Stock
local calls = 0
Scene.CDK_ChallengeMenu = function()
    calls = calls + 1
    equal(SWD3LiveCardBattle.State.selectorRunning, false, 'Handoff releases input before Cai Scene')
    equal(SWD3LiveCardBattle.State.selector, nil, 'Handoff releases F9 selector')
    equal(SWD3LiveCardBattle.State.activeChallenge, nil, 'Formal battle has no F9 lifecycle')
    equal(SaveData.Items[1].Stock, stock, 'Formal handoff does not reserve selected cards')
end
menuSelections = {7}
Scene.LCB_LiveCardBattleMenu()
equal(calls, 1, 'Optional formal entry calls the existing Cai Scene once')
equal(#observedMenus[#observedMenus].rows, 8, 'Optional entry adds one row')
equal(SWD3LiveCardBattle.State.draft, draft, 'Cancel from Cai preserves F9 draft')
equal(draft.difficulty.hp, 0.5, 'Formal handoff preserves unrelated difficulty')
menuSelections = {8}
Scene.LCB_LiveCardBattleMenu()
equal(calls, 1, 'Last row remains return when Cai installed')
Scene.CDK_ChallengeMenu = function() error('injected Cai menu failure') end
menuSelections = {7}
Scene.LCB_LiveCardBattleMenu()
equal(SWD3LiveCardBattle.State.selectorRunning, false, 'Cai failure never wedges F9')
equal(SWD3LiveCardBattle.State.activeChallenge, nil, 'Cai failure creates no F9 battle')
Scene.CDK_ChallengeMenu = nil
local beforeMissing = startedBattleId
menuSelections = {7, 1, 8}
Scene.LCB_LiveCardBattleMenu()
equal(#observedMenus[#observedMenus].rows, 8, 'Missing MOD still shows formal entry')
equal(visibleRow(observedMenus[#observedMenus-1].rows[2]),
    'Install and enable the Cai Demon King MOD, then fully restart the game.',
    'Missing MOD explains installation and restart')
equal(startedBattleId, beforeMissing, 'Missing MOD never starts fallback battle')
equal(SWD3LiveCardBattle.State.activeChallenge, nil, 'Missing MOD creates no lifecycle')
equal(SaveData.Items[1].Stock, stock, 'Missing MOD creates no reservation')
equal(SWD3LiveCardBattle.State.draft, draft, 'Missing MOD preserves selected draft')

GameData.ItemTemp[438] = {Name='Cai', isBattleChar=true, ACT=438, Level=99, IT_06=true, NotInBook=true}
local beforeTeam = SWD3LiveCardBattle.Rules.GetMenuTotal(draft)
menuSelections = {3, 2, 1, 1, 8}
Scene.LCB_LiveCardBattleMenu()
equal(#menuSelections, 0, 'Special Cai missing dependency opens notice then safely returns')
equal(SWD3LiveCardBattle.Rules.GetMenuTotal(draft), beforeTeam, 'Missing Cai never enters mixed team')
equal(startedBattleId, beforeMissing, 'Special missing Cai never starts original battle')
local freeCalls=0
SWD3CaiDemonKing={freeChallengeVersion=1,freeChallengeField='CDK_CAI_CHALLENGE',
    StartFreeChallenge=function(field, rewards)
        freeCalls=freeCalls+1
        equal(field.tCharActQ[1].ItemTempID,11001,'Original Cai selection maps to formal enemy')
        equal(rewards,false,'F9 low difficulty reward rule passed to Cai')
        equal(SWD3LiveCardBattle.State.selectorRunning,false,'Release input before Cai battle')
        equal(SWD3LiveCardBattle.State.activeChallenge.caiManaged,true,'Cai owns restoration')
        battleId='CDK_CAI_CHALLENGE'
        return true
    end}
menuSelections = {3, 2, 1, 6}
Scene.LCB_LiveCardBattleMenu()
equal(freeCalls,1,'Special Cai uses formal combat bridge on Start')
equal(SWD3LiveCardBattle.Rules.GetMenuTotal(draft), beforeTeam+1,'Cai remains in selected team')
equal(SaveData.Items[1].Stock, stock, 'Virtual Cai reserves no cards')
event('Battle_RestoreItem',1)()
-- Stale or externally supplied draft is checked again immediately before battle.
Scene.CDK_ChallengeMenu = nil
SWD3CaiDemonKing=nil
menuSelections = {6, 1, 8}
Scene.LCB_LiveCardBattleMenu()
equal(#menuSelections, 0, 'Pre-battle dependency check opens a notice')
equal(SWD3LiveCardBattle.State.activeChallenge, nil, 'Stale Cai draft never opens battle without dependency')
equal(startedBattleId, beforeMissing, 'Stale Cai draft does not fall back to original enemy')

io.write('PASS: live card battle game runtime mock\n')
