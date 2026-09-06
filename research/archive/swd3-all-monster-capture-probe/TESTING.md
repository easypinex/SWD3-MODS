# 全魔物收妖探針：驗證紀錄

本文件只記錄此探針的驗收狀態。通用證據標記與測試層級見[測試與驗證](../../../docs/knowledge/testing-and-verification.md)，資料安全規則見[狀態保存與資料安全](../../../docs/knowledge/state-persistence-and-safety.md)。

## 自動檢查

```powershell
.\tests\run-tests.ps1
```

| 檢查 | 狀態 |
| --- | --- |
| Lua 語法 | **已通過**（2026-09-03） |
| mock：wrapper 僅作用於 `AMCP_CAPTURE_PROBE` 的蛇 | **已通過**（2026-09-03） |
| mock：目標資格 bridge 僅在 F10／F7 測試戰期間將蛇設為 `IT_12`，且離場精確還原 | **已通過**（2026-09-03） |
| mock：原始 ID 基線確認後才移除 | **已通過**（2026-09-03） |
| mock：新卡 ID `9001` 不改動來源 ID `102` | **已通過**（2026-09-03） |
| mock：F5 清除全部測試卡 | **已通過**（2026-09-03） |
| 封裝反解與 SHA-256 | **已通過**（2026-09-03；來源與反解檔逐檔一致） |

## 實機驗收矩陣（全部待驗證）

| 編號 | 前置與操作 | 成功證據 | 失敗時處置 |
| ---: | --- | --- | --- |
| 1 | 全新測試存檔，只啟用本探針，按 F6 | 蛇顯示紅色 X；此為 UI 在 wrapper 前過濾非 `IT_12` 目標的已實測結果 | 正常結束戰鬥，改測 F10。 |
| 2 | 按 F10 後收服蛇 | Console 有 bridge／`mode=2`／phase 1／restore，背包沒有殘留 ID `102` | 已通過；native 是否走 wrapper 另記待驗證。 |
| 3 | 按 F7 收服蛇 | phase 2 confirmed，背包新增 1 張 ID `9001` | 已通過交換；不得移動物品欄反白至該卡。 |
| 4 | 將物品欄反白移至 ID `9001` | Steam HD 4.0.5 遊戲閃退 | **已否決路徑**；停止讀檔、護駕與批量卡片測試。 |
| 5 | 與正式自由挑戰 MOD 以兩種載入順序各測一次 | 只有在明確可串接且沒有 wrapper 覆蓋時才可記為相容 | 已否決 runtime 新 ID 路徑，故不再進行。 |

## 研究結果

- **官方檔內說明**：`Function.CheckObsolt` 會拒絕非 `IT_12` 目標；`OnEvent.Battle_Dead(index, side, mode)` 的 `mode=2` 表示被收妖。
- **已實測**（Steam HD 4.0.5，2026-09-03）：F6 以紅色 X 排除蛇，表示原生目標 UI 在 wrapper 前先檢查 `IT_12`。
- **已實測**（Steam HD 4.0.5，2026-09-03）：F10 暫時資格 bridge 成功讓蛇被原生收妖；`additem 102` 出現後，本探針以基線保護移除一張，並在 `Battle_RestoreItem` 還原 `IT_12=nil`。
- **已實測**（Steam HD 4.0.5，2026-09-03）：自訂戰鬥結束、探針已收到 `Battle_RestoreItem` 後，`GameFunc.GetBattleFieldID()` 仍可能回傳 `AMCP_CAPTURE_PROBE`。因此此專案只以自己的 `State.active` 判定是否仍在探針生命週期；快捷鍵操作仍限定於安全地圖。
- **待驗證／目前不可依賴**：本輪 F10 Console 未見 `CheckObsolt wrapper observed`，故無證據證明 native 靈契會呼叫或採用 MOD 包裝的 `Function.CheckObsolt`。
- **已否決路徑**（Steam HD 4.0.5，2026-09-03）：F7 成功交換 ID `9001` 後，背包能顯示該物品，但以鍵盤移動反白至該列會立刻閃退。該次遊戲程序結束、存檔未更新；停止後續讀檔與護駕驗收。正式版本不得以執行期全新 `GameData.ItemTemp` ID 儲存活物卡。
- **專案決策**：完成上述矩陣前，絕不對 97 個非原版活物卡批量生成資料，亦不把任一原版敵人範本原地改為 `IT_12`。
