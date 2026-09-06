# SWD3 原生選單 Coroutine 驗證

> 研究來源：本頁保存所列版本的操作與證據。是否重用、知識去向及未解問題，先查[研究清冊](../../README.md)；通用能力依[知識庫](../../../docs/knowledge/README.md)，不因歸檔或 mock 通過擴張為正式支援。

本研究模組只驗證 `ESC.Menu` 是否能在 `GameFunc.RunScene` 的原生 coroutine 中開啟。它沒有活物、背包、戰鬥、旗標或存檔程式碼。原始觀察請見 [ENGINE-UI-RESEARCH.md](ENGINE-UI-RESEARCH.md)，可供其他 MOD 使用的摘要見 [UI、輸入與原生選單](../../../docs/knowledge/ui-input-and-native-menu.md)。

本專案亦保留 `tools/ghidra/` 的 native 研究腳本。查特定事件／函式時，先讀[問題到腳本索引](../../../docs/knowledge/tools-and-commands.md#依問題選擇反解腳本)及[首次分析步驟](../../../docs/knowledge/tools-and-commands.md#首次匯入並保存事件報告)；現有靈契結論與限制見 [NATIVE-CAPTURE-RESEARCH.md](NATIVE-CAPTURE-RESEARCH.md)。

2026-09-06 的[工具流程驗證與原始報告](evidence/native-event-workflow-20260906/README.md)保存新專案 import、25 個事件名稱參照、4 個 UI caller 反編譯及輸出保存檢查；此為指定 exe／Ghidra 版本的工具驗證，不是新的遊戲內驗收。

## 現行來源與歷史驗證

**來源核對，2026-09-06。** [metadata](src/swd3_native_menu_probe.ext)仍為 `MODVersion 0,1`；[Lua](src/data/NativeMenuProbe.lua)的載入訊息為 `loaded: in a safe map with no menu open, press B once`。這只識別目前保存的來源與訊息，不把歷史 UI 結果補標成 v0.1，也不證明本機已載入此版。原結果的版本缺口見[早期證據說明](ENGINE-UI-RESEARCH.md#早期證據的版本缺口)。

選取與點空白返回已有[實測摘要](ENGINE-UI-RESEARCH.md#已實測escmenu-原生選單-coroutine)。來源仍保留 Esc／`DLGClose` 嘗試供重現歷史反例；已測 Esc 無反應，不是正常返回路徑。只有新版本或不同條件需要重現時才測 Esc，不為一般開發反覆重試同一路徑。

## 測試步驟

1. 在安全地圖停下，確認沒有對話、戰鬥或原生選單正在開啟。
2. 按一次 `B`（本機預設為無功能鍵）。
3. 看是否出現三列英文原生選單；分次開啟後選取 `SELECT ALPHA`、`SELECT BRAVO`，再測試點選空白處返回。
4. 只有重現 Esc 反例時，在另一次開啟中按一次 `Esc`。已測預期為畫面無反應且沒有 MOD 事件，接著點空白返回；不要求一定出現 `Esc requested DLGClose(0)`。
5. 保存 `[NativeMenuProbe]` 訊息與每次實際操作，特別是 `ESC.Menu returned` 及 selection；附遊戲／封包版本。若新條件出現 `Esc requested DLGClose(0)`，記錄它與選單返回的順序，另立新結果，不覆蓋歷史觀察。

若沒有出現選單或遊戲輸入異常，直接正常關閉遊戲，並把本 MOD 在 `Mods/modlist.txt` 改為 `0`。模組不寫入任何持久資料。
