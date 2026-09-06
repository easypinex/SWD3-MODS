# 原版開發工具按鈕替換驗收 0.3.2

2026-09-06，Steam HD 4.0.5 隨附 SWD3Works 1.0.0.1。此紀錄取代 [0.3.1 整體接管](../steam-entry-20260906/README.md)的現行功能結論；0.3.1 行為不符合使用者指定範圍，已撤回。

## 靜態核對

**已靜態反解＋可重跑產物驗證。** 原按鈕處理函式及事件註冊見[選定匯出](original-button-excerpt.txt)，完整反編譯留在本機 `.work/publisher-analysis-20260906-verified/decompiled/`。修補來源為 [WorkshopMenuPatch.cs](../../desktop/WorkshopMenuPatch.cs)，只改 `GameTools.button_SteamWorkshop_Click`，呼叫遊戲目錄中的自有轉接器；原 `Program.Main` 保留。

重新解析修補產物並比對 292 個其他函式的 IL／區域變數／例外處理記錄、7 份內嵌資源雜湊、函式數量與組件身分。這是上述範圍的靜態比較，不宣稱 EXE 位元組不變或所有功能均經實機重測。[隔離結果](isolated-results.json)與[本機安裝登記](local-install-record.json)保留核對計數及原檔、修補檔雜湊。修補含本機轉接器絕對路徑，不同安裝目錄的產物雜湊會不同。

## 離線與封裝測試

**已實測。** [桌面指紋](desktop-fingerprint.json)對應本次來源與建置；[桌面自測](desktop-self-test.jsonl) 13 項通過，工作者原型與版本測試分別 14／18 項通過。`Test-SteamEntry.ps1` 對最終 build 完成 20 項命令及雜湊斷言，涵蓋首次與重複設定、還原、Steam 恢復原檔、未知入口、損壞備份、鎖定恢復、舊版接管遷移與未知轉接器拒絕，見[完整結果](isolated-results.json)。

ZIP 解壓至 `.work/desktop-0.3.2-package-check/`，以 `Setup-Desktop.ps1 -NoLaunch` 完成 14＋18 項工作者測試，另對解壓成品執行同一組 20 項隔離測試，見[套件測試](package-results.json)。[套件盤點](package-inventory.json)逐一核對 manifest 雜湊，沒有原版／修補後遊戲工具、遊戲 DLL 或開發機 runtime 設定。僅附帶自有程式與 Mono.Cecil 0.11.6；授權見[MIT 全文](../../release/Mono.Cecil-LICENSE.txt)。命令參數與副作用統一見[工具索引](../../../../../docs/knowledge/tools-and-commands.md#steam-模組開發工具-032)。

## 本機驗收

**已實測安裝。** [安裝 stdout](local-install.jsonl)記錄從正式 `build/desktop-0.3.2/` 設定開發工具成功。[本機檔案指紋](local-files.json)確認原版備份保持既有 SHA-256，遊戲核心與原設定的前後雜湊一致：`swd3.exe` 為 `63F1D83D8C3A756D17640D9022E19F8928741B091F0E47ABBDB22C0CCF6C9523`，設定為 `1FF33566112A07E8E067C9CD940F0EDEA62815EA962724068C93E5E11B250D4E`。

**使用者實測確認。** 使用者允許正常關閉遊戲，原版啟動選單與「遊戲工具」視窗重新出現。介面自動化工具無法取得前景程序，未代按開發工具按鈕；改請使用者在目前「遊戲工具」視窗按「Steam 模組開發工具」。使用者回覆「已開啟 MOD Studio 0.3.2」。此證據涵蓋原選單至新桌面的按鈕流程，不將人工確認誤列為自動化點擊，也不聲稱本次重測完整 Steam 上傳或所有原選單按鈕。

原工具在遊戲執行中會因既有 mutex 檢查而退出；設定後需重開選單。修補與還原保留備份／登記，未重新發佈 GitHub Release，也未向 Steam 建立或更新作品。
