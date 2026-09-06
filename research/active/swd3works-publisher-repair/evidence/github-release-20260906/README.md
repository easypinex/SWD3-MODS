# GitHub 0.3.0 發佈包驗收

**已實測，2026-09-06。** 同一 Windows 開發機，Windows PowerShell 5.1、Python 3.12.10／zstandard 0.25.0、已驗證 Steam HD 配套 DLL。使用正式桌面建置產生新 ZIP，再解壓至獨立空目錄；未執行 Steam 發佈。

- `Setup-Desktop.ps1 -GameRoot <本機遊戲> -PythonExe <本機 Python> -NoLaunch` 成功；工作者回報 `passed:14` 及 `passed:18`，均 `steamInitialized:false`。
- 解壓套件的桌面 `--self-test` 回報 `passed:13`、`steamInitialized:false`。
- 解壓套件 `inspect-package` 讀出私人 fixture：版本 `0.6`、768 bytes，SHA-256 `456AF85FF3CF3C2707CE741937DCF73BD7C315882543DC7EB45659AAC3B3A7A1`，符合[桌面驗收](../desktop-20260906/README.md)。
- 重複設定成功；修改解壓目錄的 `README.txt` 後，設定回報 `Release file changed: README.txt. Extract a fresh ZIP.`，退出碼 1。測試副本修改不影響原始 ZIP。
- ZIP 僅含 12 個檔案：桌面程式及 config／指紋、worker 程式及 config／指紋／封包 helper／AppID、設定腳本兩份、README、完整性清單。沒有遊戲 DLL、使用者草稿或本機 `package-runtime.json`。

`SWD3-Mod-Studio-0.3.0-Windows.zip`：94,054 bytes，SHA-256 `4F1926A4B6A43E267B8C9AB496AB45040DBA4A65D648AD641D25CCC867AC6451`。

這證明本機全新解壓後的首次設定與離線功能；未宣稱在無開發環境的新 Windows 裝置上完成驗收。GUI 與真實 Steam 新建／更新的證據沿用上述桌面驗收，執行檔位元內容一致。
