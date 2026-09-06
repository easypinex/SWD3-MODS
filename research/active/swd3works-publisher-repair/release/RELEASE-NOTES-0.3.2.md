# SWD3 MOD Studio 桌面版 0.3.2

修正 0.3.1 替換範圍：**保留「Steam 啟動 → 原版選單 → 進階」，只將「Steam 模組開發工具」按鈕改為開啟 MOD Studio。** 0.3.1 的整體啟動入口接管已撤回。

- 從已驗證原檔修補 `GameTools.button_SteamWorkshop_Click`，原 `Program.Main`、其餘 292 個函式及 7 份內嵌介面資源均逐項核對不變。
- 原檔備份、還原、重新設定新桌面位置，以及從舊 0.3.1 已登記狀態修正；未知或損壞的檔案拒絕覆蓋。
- 修補在本機產生；ZIP 不含原版或修補後的 SWD3Works，不含遊戲 DLL。附帶 Mono.Cecil 0.11.6 與 MIT 授權全文。
- 沿用工作者 0.3.0、原草稿與發佈紀錄。首次 Setup 不會自動修改原工具。

完成 Setup 後，在桌面「設定與診斷」選擇遊戲的 `swd3.exe`，按「替換 Steam 模組開發工具」。正常從 Steam 開啟遊戲時仍先出現原版選單；由其「進階」開啟 MOD Studio。

驗收與限制見[桌面說明](../DESKTOP.md)及[0.3.2 驗收](../evidence/developer-menu-20260906/README.md)。
