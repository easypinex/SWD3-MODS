# 全魔物收妖探針

> 歷史實驗：本頁保存所列版本的操作與證據。是否重用、知識去向及未解問題，先查[研究清冊](../../README.md)；通用能力依[知識庫](../../../docs/knowledge/README.md)，不因歸檔或 mock 通過擴張為正式支援。

這是隔離研究 MOD，不是正式的「全魔物可收妖」功能，也不修改原版 `GameData.ItemTemp[102]` 或任何遊戲安裝檔。它只對一隻自訂戰場中的蛇（原版 ID `102`）驗證兩個假設：

1. 包裝 `Function.CheckObsolt` 的回傳值是否真的會被原生靈契流程採用。
2. 原生目標 UI 是否先以 `IT_12` 過濾目標；若是，暫時資格橋接能否在戰後完整還原。
3. 原生成功後，能否將新增的原始敵人 ID 安全交換成一張新的 MOD 活物卡（ID `9001`），並由玩家實測背包、讀檔與護駕。

原版資料的收妖規則與完整卡庫範圍見[共用平衡研究](../../../docs/knowledge/original-game-data/battle-balance-and-capture/BALANCE-RESEARCH.md)。本專案只保存本次實驗的程式、步驟與結果；未知行為在完成實機前一律是「待驗證」。

## 安全邊界

- **只處理戰場 `AMCP_CAPTURE_PROBE`、敵人 ID `102`。** 其他戰場與敵人完整呼叫原本的 `Function.CheckObsolt`。
- F6／F7 的戰鬥仍使用原生戰鬥結算；請在獨立測試存檔進行，勿把它當作練功或刷取途徑。
- 成功收妖時，探針先以開戰前背包數量確認原版真的新增 ID `102`，才用 `ItemClass.DelItem` 移除一張；若沒有觀察到新增，絕不發放 ID `9001`。
- ID `9001` 是本探針新建的執行期資料，並未實測停用 MOD 後的存檔相容性。**停用前務必在安全地圖按 F5，直到 Console 顯示 `removed custom card count=0`。**
- 探針不呼叫尚未實測的 `GameData.SendItemTempData()`，不宣稱動態 ID 已被完整註冊。

## 實機步驟

1. 使用可丟棄的獨立存檔，僅啟用本探針；不要與自由挑戰或任何其他會包裝 `Function.CheckObsolt` 的 MOD 同時啟用。
2. 先開啟 `SS2DConsole.exe`，再完全啟動遊戲；確認 Console 出現 `CheckObsolt wrapper installed` 與 F5～F7 說明。
3. 在安全地圖、沒有對話或選單時，按 **F6**。蛇會出現紅色 X 是有價值的預期結果：它證明 UI 的 `IT_12` 目標篩選早於 wrapper。
4. 正常結束 F6 戰鬥後，按 **F10**。這次探針只在自訂戰場期間暫時將蛇標為 `IT_12`；對蛇使用靈契，不要正常擊殺。成功後確認 Console 依序出現：`eligibility bridge applied`、`wrapper observed`、`Battle_Dead(mode=2)`、`phase 1 confirmed`、`eligibility bridge restored`。背包不得多出 ID `102`。
5. 完全重啟遊戲後，在新的測試存檔按 **F7**。它會使用相同的暫時資格橋接，並在成功收妖後交換成 ID `9001`；Console 應出現 `phase 2 confirmed`。
6. 到物品欄確認「蛇・探針活物卡」可見且中文完整；完整儲存、關閉遊戲、重新啟動後讀取同一存檔，再確認它仍顯示正確。
7. 在另一場可回復的戰鬥中，嘗試把該卡作為護駕召喚；記錄是否能選取、是否消耗 8 SP、是否正常進場／退場。這只驗證資料路徑，並非正式平衡設計。
8. 實驗結束後回到安全地圖按 **F5**，確認 Console 記錄已移除所有 ID `9001` 卡，再儲存並完全退出遊戲。此後才可在 MOD 管理停用探針。

## 預期與失敗判讀

| 現象 | 結論 |
| --- | --- |
| F6 中蛇顯示紅色 X | **已實測**：原生 UI 在 `CheckObsolt` 前先以 `IT_12` 排除非活物目標。 |
| F10 出現 bridge 與 phase 1 confirmed | **已實測**：暫時資格橋接可讓原生流程收妖，且原始 ID 可安全移除；wrapper 是否被 native 採用另行判定。 |
| ID `9001` 出現在背包、移動反白到該列時遊戲閃退 | **已否決路徑**：執行期新增的 `GameData.ItemTemp` 無法安全支援原生物品欄，禁止作為正式活物卡實作。 |

## 已實測結果（Steam HD 4.0.5，2026-09-03）

- 按 F6 後，蛇在靈契目標列表顯示紅色 X，無法確認；因此原生 UI 的 `IT_12` 篩選早於本探針 Lua wrapper。
- 按 F10 後，Console 依序記錄 `eligibility bridge applied`、兩次 `Battle_Dead(mode=2)`、原生 `additem 102`／`delitem 102`、`phase 1 confirmed` 與 `eligibility bridge restored`。這證明暫時將 `ItemTemp[102].IT_12=true` 能讓原生收妖完成，且本探針只在原生新增確實出現後移除一張 ID `102`。
- 本輪 Console **沒有** `CheckObsolt wrapper observed`。因此「native 靈契會呼叫並採用 MOD 包裝的 `Function.CheckObsolt`」仍是**待驗證／目前不可依賴**；F7 僅驗證資格 bridge 與新卡交換，不承諾覆寫原生成功率。
- F7 成功後，ID `9001` 在背包可見；但用上下鍵將反白移至該列時 Steam HD 4.0.5 立即閃退。遊戲程序已結束，且存檔檔案時間未更新。這否決「執行期加入全新 ItemTemp ID」作為正式卡庫路徑；不再測護駕、讀檔或停用後相容性。

## 自動測試與封裝

```powershell
.\tests\run-tests.ps1
```

封裝前依[封裝與安裝](../../../docs/knowledge/packaging-and-installation.md)建置 basename `swd3_all_monster_capture_probe`，接著在獨立工作目錄反解並比對 `.ext`、Lua 與文字檔的 SHA-256。封包只可複製到遊戲 `Mods` 供實機測試；不得在遊戲安裝目錄解包或修改原版封包。
