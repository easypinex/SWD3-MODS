# 0.3.1 Steam 入口接管驗收

**歷史範圍錯誤，已撤回。** 本版驗證的是整體入口接管，不符合使用者要求的「進階 → Steam 模組開發工具」。本機已還原此接管，現行修正見[0.3.2 驗收](../developer-menu-20260906/README.md)。

**已實測，2026-09-06。** Windows／Framework 4.8，桌面 0.3.1，Steam 工作者沿用 0.3.0。正式來源與程式雜湊見 [desktop-fingerprint.json](desktop-fingerprint.json)。

| 層次／案例 | 結果與定位 |
| --- | --- |
| 隔離副本 | [15 次入口命令與結果](isolated-results.json)：首次／重複接管、原版還原、模擬 Steam 還原後接管、未知入口拒絕、損壞備份拒絕、檔案鎖定造成替換失敗後重試。腳本另逐一核對原工具／轉接器雜湊及原 config 未變；沒有執行遊戲 marker 或初始化 Steam |
| 桌面／worker | 建置回歸 13 項桌面、14 + 18 項 worker 離線測試通過；本次 Steam 發佈邏輯未改，不重送私人或公開作品 |
| 本機安裝 | [最終接管](final-install.jsonl)與[還原](restore.jsonl)成功；入口備份 hash `756D9E2F9866EC335F8A536B9ED0DE2869BBE83FF3D5BF468E0F8A2E3C0330FA`。最終保留接管狀態，目標為 build/desktop-0.3.1-final |
| 真實入口轉接 | 正常關閉先前桌面後，直接啟動遊戲目錄的 `SWD3Works.exe`，可見新的 MOD Studio 主視窗，版本 0.3.1，Steam 查回 7 件作品；主程序位於 final 建置目錄，轉接器已退出 |
| 桌面 UI | 選檔對話框成功選定 `swd3.exe`；設定頁顯示已接管路徑。完成版按「還原原版入口」顯示原版狀態，再按「接管 Steam 啟動入口」成功恢復。按「開啟原工具」在遊戲仍執行時顯示先正常關閉遊戲的提示，介面按鈕恢復可用 |
| 遊戲與 config | [前後雜湊一致](game-unchanged.json)：`swd3.exe` 和原 `SWD3Works.exe.config`；本次沒有修改 MOD、遊戲資源或中斷使用中的遊戲 |
| 可攜套件 | 最終 ZIP 全新解壓後，Windows PowerShell 5.1 Setup 搭配本機 Python 3.12.10／zstandard 0.25.0 成功，worker 32 項離線測試通過。ZIP 不含遊戲 DLL／本機 Python 設定；首次 Setup 不接管 |

最終 ZIP `SWD3-Mod-Studio-0.3.1-Windows.zip` SHA-256：`D3BAFC77BF7FB7F781F5DC6CC4B456577194723BFEAA866E758F73F98022F728`。

## 原工具在遊戲執行中會退出

**已靜態反解＋單次觀察，限定上述原工具雜湊。** [原啟動節錄](original-startup-excerpt.txt)來自本機完整反解的 `Program.Main`，原行 4722–4759，反解基線見[研究 README](../../README.md#分析基線與重跑)。Main 偵測高清／1999 版遊戲 mutex 存在時，會直接 `Application.Exit`。本次在遊戲執行中啟動原備份，程序退出且沒有原工具視窗；完成版因此先檢查相同 mutex 並提示使用者，不自動關閉遊戲。

## 邊界

使用中的遊戲保持執行，本次沒有重按 Steam「開始」按鈕，也未實測關閉遊戲後的備份原工具 UI、直接啟動遊戲按鈕、Steam Overlay、遊玩時間或 DLC 切換。入口路徑與桌面查詢成功不提升成這些功能的驗收。資料夾搬移／缺失時的原工具後備提示具程式檢查，本次未刪除實際桌面套件去觸發該對話框。
