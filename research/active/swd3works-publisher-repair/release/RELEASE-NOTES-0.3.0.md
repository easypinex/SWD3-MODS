# SWD3 MOD Studio 桌面版 0.3.0

獨立的 Windows 桌面工具，用於《軒轅劍參：雲和山的彼端》Steam 高清版工作坊 MOD 發佈與版本維護。

- 查詢目前帳號已發佈作品，以原 Workshop ID 更新；支援搜尋、網址匯入和新建私人作品。
- 編輯標題、完整說明、更新說明，選擇 `.ssmod` 與預覽圖片。更換封包內容時要求提高內嵌版本。
- 送出前展示更新差異；完成後重新查詢文字並下載封包，核對檔名、大小、SHA-256、版本和可見度，全部一致才顯示「已驗證更新完成」。
- 草稿自動保存、發佈紀錄恢復、遠端封包取回、版本歷史及 HTML 核對報告。
- Steam 工作者在獨立程序執行；介面可停止等待並重新核對未完成操作。

## 下載與首次設定

1. 下載 `SWD3-Mod-Studio-0.3.0-Windows.zip`，完整解壓到遊戲安裝目錄以外的可寫入資料夾。`SHA256SUMS.txt` 提供下載雜湊。
2. 準備 Windows 10/11、.NET Framework 4.8、Python 3，以及 `zstandard`：`python -m pip install zstandard==0.25.0`。本次驗收使用 Python 3.12.10。
3. 執行 `Setup.cmd`，選擇正版 Steam 高清版遊戲的 `swd3.exe`。設定會核對並複製配套 DLL、設定本機 Python，完成後開啟工具。之後直接開啟 `SWD3ModStudio.exe`。
4. 登入 Steam，從「我的作品」選取作品或新建作品，準備並核對後確認發佈。

發佈包未簽章，不含遊戲 DLL、遊戲資源或帳號草稿。僅支援目前已驗證的配套 DLL，版本不符會停止設定。設定程式不修改遊戲內容；命令列指定路徑的方式見 ZIP 內 `README.txt`。

## 驗證與範圍

已由桌面介面完成私人作品更新 0.5 → 0.6、新建 0.7，以及真實下載核對；原四件公開作品未變更。工作者 32 項、桌面 13 項、封包回歸 5 項測試通過。發佈 ZIP 另經全新解壓、首次設定、重複設定及封包讀取檢查。

「停止等待」不代表 Steam 已取消，請從原發佈紀錄重新核對。歷史是這台電腦保存的成功紀錄，不代表 Steam 保存全部舊封包。本版涵蓋發佈與版本維護；MOD 封裝編輯器、本機安裝排序及遊戲／DLC 管理仍為後續範圍。

[完整桌面說明](https://github.com/easypinex/SWD3-MODS/blob/mod-studio-v0.3.0/research/active/swd3works-publisher-repair/DESKTOP.md) · [私人作品驗收證據](https://github.com/easypinex/SWD3-MODS/blob/mod-studio-v0.3.0/research/active/swd3works-publisher-repair/evidence/desktop-20260906/README.md)
