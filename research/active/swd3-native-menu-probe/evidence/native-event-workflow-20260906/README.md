# Native 事件分析文件流程驗證（2026-09-06）

**已實測工具流程＋已靜態反解；未進行遊戲內驗收。** 本紀錄驗證知識文件能帶領讀者從全新 Ghidra 專案取得事件參照，再保存完整函式反編譯。操作唯一正文見[首次匯入](../../../../../docs/knowledge/tools-and-commands.md#首次匯入並保存事件報告)及[報告重跑](../../../../../docs/knowledge/tools-and-commands.md#從事件參照追到函式並重跑報告)，本頁只保存此次條件、結果與原始證據。

## 版本與執行條件

- 遊戲：`swd3.exe 4.0.5.0`，2,227,712 bytes，SHA-256 `63F1D83D8C3A756D17640D9022E19F8928741B091F0E47ABBDB22C0CCF6C9523`；見 [input-fingerprint.json](input-fingerprint.json)。
- 工具：Ghidra 11.4.3、Temurin JDK `21.0.12.1+1-LTS`、PowerShell 7.6.5；原始版本屬性見 [tool-versions.txt](tool-versions.txt)，PowerShell 版本見 [validation.json](validation.json)。本次使用已存在的 portable 工具，未測試全新下載／安裝，也未驗證其他工具版本。
- 來源腳本：[ReportHdBattleEventStringRefs.py](../../tools/ghidra/ReportHdBattleEventStringRefs.py)、[DecompileHdBattleUiEventCallers.py](../../tools/ghidra/DecompileHdBattleUiEventCallers.py)；執行時 SHA-256 分別保存在 [event-script-fingerprint.txt](event-script-fingerprint.txt)、[ui-script-fingerprint.txt](ui-script-fingerprint.txt)。未修改兩支腳本。
- 從工具正文擷取三段 PowerShell 範例，僅替換遊戲路徑與隔離目錄名稱，通過 PowerShell 語法解析後依序執行。此次本機目錄為 `.work/native-events-doccheck-20260906-104009/`；使用新資料庫、預設 PE 分析與原始 image base。
- 首次保存分析後，以同一專案進行 `-process -noanalysis -readOnly`。沒有開啟遊戲、載入 MOD、修改遊戲安裝檔或進行動態除錯。
- 本目錄檔案為完成執行後直接複製的原始報告；caller 檔名由執行時間前綴改為固定名稱，內容未改寫。沒有保存 exe 或 Ghidra 資料庫；報告檔案 hash 及執行後來源／副本 hash 見 [validation.json](validation.json)。

## 結論與精確證據

| 本次可確認的結論 | 精確證據位置 | 適用條件與界線 |
| --- | --- | --- |
| 首次分析完成，且程式已保存到新專案 | [import-analysis.log](import-analysis.log) 第 493–494 行，`Save succeeded for: /swd3.exe`／`Import succeeded` | 證明本次 import；不是只有專案檔存在或程序退出碼為零。 |
| 可以由事件名找到 native 參照及函式入口 | [battle-event-refs.log](battle-event-refs.log) 第 11–12 行：`Battle_InputClick @ 140172ba0` → `REF ... 140053c42` → `FUN_140053ae0` | 此腳本固定 25 個名稱；本次全數有 data ref，不代表列出引擎所有事件或同名的全部地址。完整終端報告另存 [battle-event-refs.txt](battle-event-refs.txt)。 |
| 可以沿入口取得四個目標函式的完整偽碼 | [battle-ui-callers.txt](battle-ui-callers.txt) 第 43、200、562、1458 行為四個目標標題，後接函式內容 | 目標為 `0x1400402a0`、`0x140053ae0`、`0x1400574a0`、`0x140054580`；沒有 `<no function defined>`、反編譯失敗或 Traceback。型別仍有下節警告。 |
| 同名事件必須分 caller 查參數與條件 | [battle-ui-callers.txt](battle-ui-callers.txt) 第 254、260 行的輸入 dispatcher 路徑，及第 664、1584 行的另兩個呼叫點 | 可直接比較同名 `Battle_InputClick` 在 `FUN_14014ccf0` 呼叫中的不同實參；本次不重新推定未命名變數的遊戲語意，也不把一個呼叫點的參數外推全部 caller。 |
| 後續報告使用 Ghidra 的 read-only process | [battle-ui-analysis.log](battle-ui-analysis.log) 第 40 行，`Processing read-only project file: /swd3.exe` | 未宣稱整個專案目錄或使用者快取完全不寫入；原檔／副本雜湊未變見 validation。 |
| 只保存 script log 會漏掉此次多行偽碼 | [battle-ui-script.log](battle-ui-script.log) 全部 5 行僅有報告與函式標題；與 [battle-ui-callers.txt](battle-ui-callers.txt) 第 204 行起的 `FUN_140053ae0` 本體比較 | 本次 Ghidra 11.4.3／Jython 實際結果；完整內容在 stdout 及 analysis log。文件已改成另外保存 stdout，不能只驗收標題。 |

## 保留的警告與未覆蓋範圍

- [import-analysis.log](import-analysis.log) 第 51–52 行有外部匯出地址缺函式警告，第 323–324 行有 no-return 名稱前導底線警告；保存原始訊息，沒有宣稱所有外部依賴都完整解析。
- [battle-ui-callers.txt](battle-ui-callers.txt) 第 1460 行有 `Type propagation algorithm not settling`，其他片段有全域符號重疊警告。四段偽碼成功產出，只能證明工具流程與可查閱內容，不保證每個型別／變數都還原正確。
- [battle-event-refs.log](battle-event-refs.log) 第 68 行的 `Battle_CancelClick` 參照仍是 `<no enclosing function>`；這是保留的分析缺口，不能說該事件沒有接線。
- 本次只重跑表列兩支報告；其他腳本索引採來源核對，未在此次逐支執行。沒有驗證新版本地址、任意新事件腳本、runtime 分支可達性或遊戲內時序。

後續若重跑，依工具正文使用新目錄並重新記錄版本與報告，不覆寫本次證據。
