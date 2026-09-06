# 自由挑戰：趣味性、平衡與劇情安全盤點

盤點日期：2026-09-03。範圍為目前正式來源 `src/data/CardBattleRules.lua` 與 `src/data/LiveCardBattle.lua`，以及已解出的原版 `OnEvent_Battle.lua`、`BattleField.lua`、`BattleScript.lua`。

## 結論摘要

| 面向 | 現況 | 風險 | 發行判定 |
| --- | --- | --- | --- |
| 原劇情 Flag／事件 | MOD 沒有呼叫 `FlagOn`、`FlagOff`、`RunEvent`、地圖轉移或劇情場景。自訂戰場只填入背景、音樂、敵方 `ItemTempID` 與位置。 | 低；目前沒有直接寫入路徑。 | 可保留，但要實機以代表性首領驗收。 |
| 戰鬥獎勵 | 五項難度係數的算術平均 `>=1.0x` 時沿用原版；平均 `<1.0x` 時，`OnEvent.BattleGain` 將經驗、金錢、法寶／絕招經驗歸零，且本次戰鬥暫時移除敵人的一般掉落資料。 | 中；需實機確認 native 結算與所有掉落型態都會採用這些資料。 | 低難度路徑完成實機驗收前不得宣稱完全無獎勵。 |
| 虛擬圖鑑／首領 | 可免費選取，且可重收妖複組至 5 隻。 | 高；高價值首領可能把練功、金錢或掉落效率拉高。 | 應設計明確限制或改為無獎勵模式。 |
| 收妖／靈契 | 以開戰前同 ID 數量比對，只移除本次新增的一張。 | 中；仍須對持有卡與虛擬首領實機驗收。 | 已有保護，維持回歸測試。 |
| Game Over／讀檔 | 在呼叫 `ESC.StartBattle` 前已立即結束選單狀態，不依賴讀檔才清除；另保留遺留偵測與不低於 `Stock` 基線的釋放防呆。 | 中；需實機重跑完整流程。 | 必測後才發布。 |
| 挑戰敗北流程 | 僅於 `MOD_CARD_CHALLENGE` 進戰時使用原版戰鬥腳本的 `BSC.NoOVER()`；全員倒下時使用 `BSC.BattleBreak()`。 | 中；原版腳本有此用法，但 MOD 尚需實機驗證。 | 敗北必測後才發布。 |

## 劇情 Flag 的證據與邊界

自由挑戰呼叫的路徑是：建立 `BattleField['MOD_CARD_CHALLENGE']` → `ESC.StartBattle`。建立的欄位只有 `iBattleFieldBackground`、`MusicFileName` 和 `tCharActQ`。來源中沒有 `GameFunc.FlagOn`、`GameFunc.FlagOff`、`GameFunc.RunEvent` 或地圖／劇情 API。

原版的 `OnEvent.Battle_Dead.main` 對敵方死亡只取得敵人資料並寫入日誌；原劇情 Flag 寫入出現在明確的 `BattleScript.lua`／`Scene*.lua` 劇情腳本。自由挑戰沒有指定或執行這些腳本，因此目前沒有發現「打倒指定首領就自動推進劇情」的直接機制。

這是程式碼盤點結論，不是對 native engine 的絕對保證。正式驗收應在可回復的獨立存檔中，選擇一隻劇情首領與一隻普通怪物各勝利一次，比對關鍵任務 Flag、地圖可通行狀態與角色隊伍。

## 獎勵與趣味性的主要取捨

v0.3 採用明確門檻：五項難度（生命、攻擊傷害、防禦、速度、技能傷害）的算術平均為 `1.0x` 或以上時保留原版獎勵；平均低於 `1.0x` 時才視為練習挑戰。練習挑戰只作用於 `MOD_CARD_CHALLENGE`：以 `BattleGain` 歸零經驗、金錢、法寶經驗與絕招經驗，並在該戰鬥期間暫時清空選取敵人的 `GainEXP`、`GainGold`、`DropItems`、`DropItemsRate`，於所有結束路徑還原。

`BattleGain` 回傳欄位與敵方獎勵／掉落資料均有原版 Lua 證據，但低難度下所有 native 掉落型態是否都讀取這些資料，尚未逐項實機確認。因此這是**專案決策**，且「一般掉落為零」仍須完成 `TESTING.md` 的代表性實機矩陣才能提升為已實測結論。

## 發行前最小實機矩陣

1. 普通持有活物、虛擬圖鑑怪與劇情首領各勝利一次，記錄經驗、金錢、法寶／絕招經驗與所有掉落。
2. 於挑戰前後比對代表性劇情 Flag、地圖出口、隊伍角色與任務對話。
3. 對上述三種來源各測一次收妖／靈契，確認背包淨數不增加。
4. 以單隻與五隻首領各測一次，評估時間、難度與獎勵效率；再決定採練習模式或賞金挑戰模式。
5. 戰敗 → Game Over → 讀檔 → 物品欄按 F9，確認可重新開啟且 `Stock`、物品數量不變。

## 蔡魔王開戰崩潰評估（2026-09-06）

**待驗證：使用者回報**可查看蔡魔王資訊，選擇開始挑戰後遊戲崩潰；本次未重啟遊戲或重現。以下核對工作區 v0.6 來源與 Steam HD 4.0.5 原版資料，未確認回報當下實際載入的 MOD 封包、隊伍、倍率、存檔或其他 MOD 組合。本次只做評估及文件記錄，未修改功能、安裝或發布。

### 原版資料與程式證據

**官方檔內說明／資料核對。** 本機與隔離副本的 `script_index.ssmod` SHA-256 均為 `9995B9A1327700B9ED8F642D091BCEA40129EC2F9DDFF03220A4DF1691DB85BF`；原版檔案依[基線與重建入口](../docs/knowledge/engine-research-workflow.md#steam-hd-405-原版腳本基線)取得，下列行號屬此次 `out_data` 副本。這是 Lua／manifest 核對，沒有執行 native 反解或實機因果驗證。

| 發現 | 可定位證據 | 判讀與界線 |
| --- | --- | --- |
| 蔡魔王是未完成資料 | `GameData_BattleCharData.lua:7685–7706`，`ItemTemp[438]`：`ACT=438`、`Level=99`、`HP=10000`、`isBattleChar=true`，並寫有 `NotInBook=true, -- 未完成`。 | 目前選取條件會放行此資料；不能把所有 `NotInBook=true` 都當成未完成，這裡的證據是該筆原版註解。 |
| 指定的 ACT 未在原版動畫表宣告 | 在完整 `act.ext` 搜尋 `^ACTi?\s+438,` 為零筆；`ACT_Append.lua` 只建立 `ACTData[-1]` 測試資料。對照九天玄女 `ACT=149` 在 `act.ext:2770–2774` 有宣告及 QQ 36／40／44／68。 | **首要原因推測：**進戰建立角色時取不到動作資源。零筆限本次原版表，不代表其他資源包／MOD 不可能補入，也未證實 native 的崩潰指令。 |
| 特殊攻擊引用錯誤資料域 | `GameData_BattleCharData.lua:7699` 為 `SP_AttackEffects={1683}`；完整 `GameData_AttackEffect.lua` 無 `GameData.AttackEffect[1683]`。`GameData_SkillData.lua:2478–2491` 的 `ItemTemp[1683]` 是「魔氣縱橫」，其 `AttackEffect=198`。 | `OnEvent_Battle.lua:468` 讀取此陣列；`OnEvent_BattleEnemyAI.lua:227` 直接送入 `AI_SelectAttackEffect`。這是第二項資料缺口，可能在特殊攻擊執行時出錯；未證實它是這次進戰崩潰的觸發點。 |
| 不能直接接回舊劇情戰 | `BattleScript.lua:2460–2478` 的 `BS308` 也標為「未完成」，勝利寫入 `FlagOn(170)`；完整 `BattleField.lua` 未找到 `BS308` 或 `ItemTempID=438` 編成。 | 單純改呼叫 `BS308` 既未解決資源缺口，又可能引入劇情副作用，不列為修復方案。 |
| 地圖造型不等於戰鬥造型 | `GameData_Char.lua:11604` 的地圖角色 `6976` 起始使用 `ACT=507`；`Scene.lua:83406` 改為 `627/QQ0`。 | 地圖能看到蔡魔王不能證明 `438` 有戰鬥動畫；也不能直接把 `507` 或 `627` 當成可用戰鬥替代品。 |

**專案來源核對。** [Rules.IsBattleReady](src/data/CardBattleRules.lua) 只檢查 table、`isBattleChar`、正整數 ACT／Level；清單和 `ValidateSelection` 沿用同一門檻。名稱與面板文字可以由資料表顯示，沒有實際載入戰鬥動畫，故「資訊正常」與「開戰崩潰」並不矛盾。[startChallenge](src/data/LiveCardBattle.lua) 已有 `pcall(ESC.StartBattle, ...)`，但不能以 Lua 錯誤保護承諾攔住 native 存取違規；新增防護必須在呼叫前完成。

唯讀延伸盤點：由 [combatants.csv](../docs/knowledge/original-game-data/battle-balance-and-capture/generated/combatants.csv) 取正 ACT／Level 的 193 筆，將 ACT 對照完整 `act.ext` 宣告集合，未命中的是 `157 女夷22` 與 `438 蔡魔王`；將非空 `special_effect_ids` 逐一對照 `GameData.AttackEffect` 宣告集合，未命中的是蔡魔王的 `1683`。這只是引用完整性檢查；女夷22 **尚無本次實機崩潰證據**，其餘命中者也不因此獲得安全保證。

相容性範圍：[卡庫映射](../swd3-all-monster-static-capture-mod/src/data/AllMonsterStaticCatalogue.lua) 含 `438 → 10096`，而 [makeStaticCard](../swd3-all-monster-static-capture-mod/src/data/AllMonsterStaticCapture.lua) 逐欄複製來源，會繼承 `ACT=438` 與 `SP_AttackEffects={1683}`。所以防護不能只靠移除「特殊／首領」中的原始 ID，還要涵蓋持有卡／虛擬契靈卡入口。護駕召喚亦列為相關待查風險，不宣稱已重現。

Windows Application 記錄在 2026-09-06 01:41:00 有 `swd3.exe 4.0.5.0`／`SDL2.dll 2.26.3.0`、`0xc0000005`、模組位移 `0x5e0bc`；01:05:22 另有 `ntdll.dll`／`0xc0000374`。未取得與本次操作配對的 Console、dump 或時間，**不得把任一事件直接認定為蔡魔王案例**。

### 修正方式與建議順序

以下均為**待實作的專案方案**。

1. **優先止崩，成本低。** 保留資訊瀏覽並標示「戰鬥資料未完成，暫不可挑戰」；加入隊伍及 `ValidateSelection` 開戰前都拒絕已知不安全來源，涵蓋 `438`、映射卡 `10096` 及繼承同一缺失 ACT 的入口。拒絕發生在預留、獎勵暫改和 `ESC.StartBattle` 之前；已保留隊伍亦須重新驗證。這是停用不安全戰鬥，並未恢復可挑戰能力。不要刪除玩家已持有的契靈卡，也不要以關閉整個卡庫作替代處置。
2. **補強所有候選的引用檢查，成本中。** 建置時檢查 ACT 宣告、技能／攻擊效果引用，保存版本與排除原因；runtime 使用已核對的安全清單或例外表，並處理有效來源／Save override。ACT 存在只是必要檢查之一，動作 QQ、引用圖像、出招及死亡流程仍須驗收；不能以原版是否出现在 BattleField 作唯一資格，亦不能一律排除 `NotInBook`。將匯出表中的「目前可選」與「實機可戰」清楚分開。
3. **真正開放蔡魔王，成本較高。** 建立隔離的 MOD 戰鬥版本，採用已驗證的完整戰鬥 ACT（替代外觀須明確呈現），或另研究補齊專屬動作。先以最小普通攻擊驗證進場，再逐一加回技能。對 `1683` 先決定要保留法術「魔氣縱橫」還是直接效果 `198`；兩者的施法／恢復生命／消耗／動畫語意不同，不能只替換數字便宣稱修復。不得原地永久改寫原版角色、直接啟動未完成劇情腳本或依賴未驗證的地圖 ACT。

最低驗證順序：先以真實資料缺口建立靜態及 mock 案例，證明所有入口在開戰前拒絕、背包／獎勵未改；封裝反解後才做實機。若選擇恢復戰鬥，隔離測試每次只改一個因素，記錄開戰前 ID／ACT／技能、EnemyInit、Battle_Enter 與最後 Console；確認單隻進場、待機、普攻、每個技能、受擊、死亡／逃跑／戰敗，再測多隻與卡庫兩種載入順序。不得把現在 `StartBattle` **之後**才印出的 `challenge difficulty` 當成必然可取得的開戰前診斷。

知識歸屬檢視：缺失引用可由原版資料重跑，但其與 native 崩潰的因果、替代 ACT 安全性尚未驗證；本次保留於本專案，不提升為跨 MOD 引擎規則。
