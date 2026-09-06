SWD3 MOD Studio 0.3.0 - Windows desktop release

首次使用
1. 將 ZIP 完整解壓到一般可寫入資料夾，放在遊戲安裝目錄之外。
2. 安裝 Python 3，並執行 python -m pip install zstandard==0.25.0。
3. 雙擊 Setup.cmd，選擇 Steam 高清版遊戲目錄內的 swd3.exe。
   設定程式只複製並核對遊戲配套 DLL，不修改遊戲內容。
   完成後自動開啟桌面工具；往後直接開啟 SWD3ModStudio.exe。
4. 登入 Steam；在「我的作品」雙擊作品，或按「新建作品」。
5. 填寫標題、完整說明、更新說明並選擇已驗收的 .ssmod。
   按「準備並核對」，檢查身分與可見度，再確認發佈。

Windows 10/11、.NET Framework 4.8；只支援已驗證的 Steam HD 配套 DLL。
發佈包不含遊戲 DLL、遊戲資源、帳號草稿或本機 Python 路徑。
本版本未簽章；Setup.cmd 的 ExecutionPolicy Bypass 僅用於這次設定程序，
不修改 Windows 的持久設定；也可自行檢視腳本後執行 Setup-Desktop.ps1。
設定不下載或安裝依賴、不呼叫 Steam、不發佈作品。

可指定 Python 路徑：
powershell -NoProfile -ExecutionPolicy Bypass -File .\Setup-Desktop.ps1 -GameRoot "D:\SteamLibrary\steamapps\common\SWD3" -PythonExe "C:\Python312\python.exe"

維護重點
- 修改封包內容時，必須先提高封包內的 MODVersion。
- 相同版本與相同封包可修正刊登文字；更新沿用原 Workshop ID。
- 新作品預設私人；只有文字、版本及實際下載檔案一致才顯示驗證完成。
- 停止等待不表示 Steam 已取消；從「發佈紀錄」開啟原操作核對。
- 草稿、紀錄與快照位於使用者目錄下的 SWD3ModStudio。
- 本版涵蓋發佈與版本維護，尚不含 MOD 封裝編輯器與遊戲內安裝排序。

來源與完整說明：
https://github.com/easypinex/SWD3-MODS/tree/main/research/active/swd3works-publisher-repair
