# SWD3 MOD Studio 桌面版 0.3.0

2026-09-06。發佈與維護的 Windows 桌面介面已完成；私人作品已實測更新與新建，並核對 Steam 實際下載內容。驗收條件與原始紀錄見 [桌面驗收](evidence/desktop-20260906/README.md)。

## 開啟與日常使用

本機程式：`build/desktop-0.3.0/SWD3ModStudio.exe`。桌面另有 **SWD3 MOD Studio** 捷徑。先登入 Steam，再開啟程式；不需啟動遊戲或 SWD3Works。

1. **我的作品**：重新整理目前帳號的作品，雙擊開始維護；也可貼上工作坊網址或作品 ID。支援搜尋及本機草稿。
2. **發佈編輯**：填寫標題、完整說明、更新說明，選擇 `.ssmod` 成品及預覽圖片。新作品預設私人；既有作品預設保持可見度。版本直接讀取封包內的 `MODVersion`，更換內容必須提高版本。
3. **準備並核對**：保存本次封包快照，查詢目前 Steam 文字與封包，展示更新前／本次內容／查回結果。確認作品身分及可見度後按「確認發佈到 Steam」。
4. 只有標題、說明、版本標記、下載檔名、大小、SHA-256 和內嵌版本全部吻合，才顯示「已驗證更新完成」。中文文字同步到 Steam 的 English 預設欄位，避免不同介面語言顯示舊文字。
5. **遠端檔案／版本歷史**：重新下載盤點，或查看這台電腦曾成功驗證的版本。歷史不代表 Steam 保存過去每一版封包。

缺少原成品時，可按「取回目前 Steam 封包」複製並綁定目前下載版本；可用相同封包維護刊登文字。修改 MOD 功能仍應回到來源專案，重新封裝與驗收。預覽圖片新建必填、小於 1 MB，更新時留空沿用遠端圖片。

## 保存、恢復與匯出

- 草稿約在停止編輯 0.9 秒後自動保存，也可手動保存／匯入／匯出 JSON。
- 資料放在 `%USERPROFILE%/SWD3ModStudio/Desktop/`，依 Steam 帳號區分。`drafts` 保存文字與來源綁定，`operations` 保存各次快照與狀態，`logs` 保存診斷，`recovered` 保存取回封包。
- 工作者的成功歷史與未完成登記放在 `%USERPROFILE%/SWD3ModStudio/releases/1638230/<SteamID>/`。0.2.0 的歷史位置為 LocalAppData；本機已搬入已驗證歷史及預覽草稿，保留原檔。其他電腦的舊操作可從「發佈紀錄 → 匯入既有操作」選擇原 `state.json`，勿同時混用兩版工具發佈同一作品。
- 發佈紀錄可重新開啟操作並核對結果。Steam 明確拒絕的操作可重新審閱；只有查回證明完全未變更的既有更新，才能核對並結案。未知結果不能當成取消。
- 「停止等待」只停止本機背景工作者；Steam 可能仍在處理。重啟後先開啟原操作核對，保留原作品 ID。
- 核對頁可匯出 HTML 報告；報告保留完整文字與雜湊，是匯出當時的紀錄。設定頁可複製診斷紀錄、開啟資料位置。

## 實作與邊界

WPF／.NET Framework 4.8 桌面程序，Steam API 在獨立 x86 工作者執行。雙向輸出並行讀取；每個 Steam 等待階段有時限，停止等待只終止本工具啟動的工作者。錯誤、取消、成功均恢復介面操作，完成訊息不使用 callback 內阻塞對話框。啟動子程序前核對本機建置指紋，Steam 帳號切換後拒絕沿用舊帳號送出。

本版採原子替換與備份的 UTF-8 JSON，不另安裝 .NET 10／SQLite。是發佈與版本維護的完整桌面流程；[完整產品提案](NEW-TOOL-DESIGN.md)中的專案封裝編輯器、本機 MOD 安裝排序、遊戲／DLC 管理仍為後續範圍。檔案檢查只解析可辨識的 SMOD v4 manifest；不替代 MOD 實機驗收。

可從 [GitHub Release](https://github.com/easypinex/SWD3-MODS/releases/tag/mod-studio-v0.3.0) 下載未簽章的 Windows ZIP。完整解壓到遊戲以外的可寫入目錄，準備 Python 3／zstandard，再執行 `Setup.cmd` 選擇遊戲的 `swd3.exe`；設定會核對並複製本機遊戲配套 DLL、設定 Python，完成後開啟桌面程式。之後直接執行 `SWD3ModStudio.exe`。發佈包不含遊戲 DLL、帳號資料或開發機 Python 路徑。詳見 [隨包說明](release/README.txt)及[版本說明](release/RELEASE-NOTES-0.3.0.md)。命令參數、輸出與副作用的唯一入口為 [工具索引](../../../docs/knowledge/tools-and-commands.md#mod-studio-桌面版-030)。
