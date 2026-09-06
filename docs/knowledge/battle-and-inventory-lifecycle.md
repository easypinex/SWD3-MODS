# 戰鬥與背包生命週期

## 適用範圍與界線

本文件整理活物挑戰 MOD 在 Steam HD 4.0.x 已驗證的「自訂戰鬥 + 背包預留」模式。`BattleField` 結構與事件存在已由專案測試／實機驗收支持，但不表示所有戰鬥欄位或獎勵改寫皆已支援。確切敵方編成、掉落與產品規則仍屬各專案決策。

## 最小生命週期

```text
選取物品 → 檢查可用數 → 預留 Stock → 建立 BattleField → ESC.StartBattle
    → Battle_Dead / Battle_RestoreItem / 換圖 → 安全釋放預留 → 清除暫態
```

1. 從 `SaveData.Items` 取得槽位，並以 `Count + Count_New - Stock` 計算可用數。
2. 只對實際持有的物品預留；虛擬圖鑑／首領對手不可寫入玩家背包。
3. 將完整的預留明細保存在 MOD 暫態狀態，而不是只記「目前在戰鬥」。
4. 以專屬、不會撞名的文字 ID 建立 `BattleField[BATTLE_ID]`，再以 `pcall(ESC.StartBattle, BATTLE_ID)` 開戰。
5. 以 `GameFunc.GetBattleFieldID()` 比對目前戰場 ID，避免處理其他戰鬥。
6. 在 `OnEvent.Battle_Dead`、`OnEvent.Battle_RestoreItem`、換圖及啟動新挑戰前都呼叫同一個釋放函式。
7. 不可假設 Game Over 後一定會觸發 `Battle_RestoreItem`、換圖或重新開局事件；若戰鬥是由可中斷的原生 coroutine 啟動，回到可驗證的 UI（例如物品籃繪製）時，應偵測已離開自訂戰場卻仍存在的 MOD 狀態，並執行可重入的清理。

## 已觀察的最小 `BattleField` 結構

活物挑戰已將下列 table 放入 `BattleField[BATTLE_ID]` 後，以 `ESC.StartBattle(BATTLE_ID)` 建立戰鬥：

```lua
local field = {
    iBattleFieldBackground = 4,
    MusicFileName = 'Battle_Europa01.mp3',
    tCharActQ = {
        { ItemTempID = itemId, X = 176, Y = 294 }
    }
}
```

- `tCharActQ` 的每個敵人項目使用 `ItemTempID` 與座標 `X`／`Y`。
- 背景、音樂與位置是**專案參數**，必須各自實機驗收，不從活物挑戰的數值複製成通用預設。
- 這是 Steam HD 4.0.x 已觀察到可用的最小形狀，不是完整 `BattleField` schema；未知欄位須先走[引擎研究流程](engine-research-workflow.md)。
- 純規則測試中出現的 `PlayerExp`、`Money`、`MItemExp`、`SpecialSkillExp` 僅是獎勵資料的專案模型，尚未證實為 `BattleField` 可接受欄位；不可據此改寫原版戰鬥結算。

## `Stock` 預留規則

現有測試顯示：`Count` 與 `Count_New` 是物品數量來源，`Stock` 可用來暫時排除被挑戰使用的份數。開始戰鬥不應直接扣除 `Count`，也不應自行發放／扣除原版獎勵。

釋放時只移除本 MOD 當初增加的預留量，且不可低於預留前記錄的 `Stock` 基線；讀檔可能已將背包還原，但 Lua 暫態仍保有舊 reservation。不可把 `Stock` 一律設為零，否則會抹去其他流程在戰鬥期間新增的預留。以下為概念式樣：

```lua
-- reservation 記錄 slot、addedStock；實作需處理槽位或物品已不存在。
local baseline = tonumber(reservation.stockBefore) or 0
item.Stock = math.max(baseline, (tonumber(item.Stock) or 0) - reservation.addedStock)
if item.Stock == 0 then item.Stock = nil end
```

新增「目前挑戰」前先釋放舊挑戰；任何失敗、無法開戰或事件重入也要走釋放路徑。完整的 snapshot／錯誤保護原則見[狀態保存與資料安全](state-persistence-and-safety.md)。

## 原生獎勵／捕捉副作用的最小補償

原版流程已新增物品、但 MOD 必須排除該新增物時，不能直接依 `Battle_Dead` 的 mode、敵人 ID 或預期結果刪除物品。正確順序是：戰鬥前按 ID 記錄背包總數 → callback 後重新計數 → 僅在總數大於基線時刪除那一份新增物。實際刪除使用原生 `ItemClass.DelItem`，不直接修改 `Count`／`Count_New`。

這是防止誤刪玩家原有同 ID 物品的安全模式；callback 順序與完整參數仍待驗證。`ItemClass.DelItem` 的已觀察呼叫形式與限制見[執行期 API 與遊戲資料模型](runtime-api-and-data-model.md)。

### 原生靈契 → 靜態活物卡

**已實測，Steam HD 4.0.5，2026-09-03。** 原生一般遭遇的非活物要安全轉為新增活物卡，使用以下順序；每一步不可略過或換到較晚時點：

1. 先依[執行期 API 與遊戲資料模型](runtime-api-and-data-model.md#新增活物卡的原生註冊時點)在 MOD 載入期建立完整靜態卡與「敵人 ID → 卡 ID」表。
2. 先依[原生靈契](native-capture-and-eligibility.md)界定可收服範圍與資格準備；來源準備不能取代目標確認與結算時的 live 判定。本節不提供任意暫清 Boss 的安全承諾。
3. 同時記錄每個來源 ID 的背包總數基線；資格 bridge 只保留到戰鬥結束、切圖或重啟，所有快照都須精確還原。
4. `Battle_Dead(..., side=1, mode=2)` 只標記「原生可能收妖」候選。不要在此時自行加卡或刪除來源，因原生 `additem` 會在其後才發生，且 callback 可重複出現。
5. `Battle_RestoreItem` 時，僅當來源總數高於開戰前基線，才用 `ItemClass.DelItem` 移除一張新增來源，再用 `ItemClass.AddItem` 加入映射的靜態卡；最後才還原資格 bridge。

代表性的原生新增與交換證據見[靜態蛇卡](../../research/archive/swd3-static-capture-exchange-probe/README.md)及[一般遭遇](../../research/archive/swd3-general-capture-eligibility-probe/README.md)。這些支持基線補償流程，不代表所有敵人、存檔或停用安全性已驗收。首領資格與等級副作用統一見[原生靈契](native-capture-and-eligibility.md)。

### 原生護駕召喚的背包位置

**已實測，Steam HD 4.0.5，2026-09-03。** 原生戰鬥的「物品 → 護駕」清單以背包的 `SaveData.Items` 為來源；護駕卡只存在於 `SaveData.PlayerEqu` 時不會列入該清單。靜態蚩尤卡 `10017` 留在背包、賽特 SP 足夠 `200` 時，已成功召喚並正常使用，戰後仍在背包且可反白；將同一張卡裝入護駕欄後，實機診斷顯示背包數量為 0，因而不列出。

因此，想使用原生戰鬥護駕時，卡片應留在背包，不應把「裝備在護駕欄」當成召喚前置條件。這是原生召喚清單的已測位置規則；護駕欄本身的其他效果與全部原生卡的行為範圍仍待個別驗證。

## 事件與相容性

已使用的事件為 `OnEvent.Battle_Dead` 與 `OnEvent.Battle_RestoreItem`；請以 `table.insert` 追加，不覆寫事件表。這兩個事件的完整參數與所有觸發條件仍未文件化，因此 handler 應只讀取自己儲存的狀態，並能安全地重複呼叫。

`BattleField` ID、事件、快捷鍵、全域表與 StringDB 前綴都必須先查[工作區相容性登記表](../compatibility-registry.md)。Lua 安裝與載入相容性另見[Lua 事件與相容性](lua-events-and-compatibility.md)。

## 驗收最低集

- 背包同一物品有 `Count`、`Count_New`、既有 `Stock` 時，預留量正確。
- 開戰失敗、勝敗、逃跑、換圖、重開遊戲與連續開戰都釋放自己的預留。
- 戰鬥期間原版或其他 MOD 改變數量／`Stock` 時，不覆蓋其變更。
- 其他戰鬥不觸發本 MOD 的清理或獎勵邏輯。
- 封裝後反解，確認規則檔先於依賴它的整合檔被 `DAT` 宣告；此順序是專案載入契約，並非已證實的全引擎排序保證。
