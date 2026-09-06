# Steam 工作者原型 v0.1.0

本頁保留 0.1.0 的歷史操作與證據；現行可持續升版、同步文字及自動下載驗證的工作者為 [0.2.0 版本維護原型](RELEASES.md)。下方「只允許兩版／不支援一般更新」等敘述僅描述 M0。

2026-09-06，**M0 核心可行性已實測通過**：獨立初始化 Steam、找回作者作品、查指定 ID、私人新建、結束程序後找回、沿用同 ID 更新、兩版實際下載逐檔驗證。完整 UI 與一般作品編輯仍屬 M1／M2；本版為命令列工作者，沒有假裝提供已完成的桌面產品。

## 使用入口

本機成品位於 `research/active/swd3works-publisher-repair/build/m0-0.1.0-final/SteamPrototype.exe`。維護來源是 [SteamPrototype.cs](prototype/SteamPrototype.cs)，建置與操作統一依[工具索引](../../../docs/knowledge/tools-and-commands.md#steam-工作者原型-m0)。build 及本機測試內容不納入 Git；新 clone 先重建。

保留 Steam 客戶端登入，從工作區根目錄執行唯讀作品查詢：

```powershell
& ./research/active/swd3works-publisher-repair/scripts/Invoke-SteamPrototype.ps1 `
  -BuildRoot ./research/active/swd3works-publisher-repair/build/m0-0.1.0-final `
  -Command list `
  -LogPath ./.work/my-published-query.log `
  -OutputPath ./.work/my-published-items.json
```

每次使用新的 LogPath，避免覆寫證據。包裝器會固定工作目錄並核對 exe／相依 DLL 指紋，不能只搬一支 exe 而漏掉相依檔及 `steam_appid.txt`。工具輸出 JSONL，包裝器在終端摘要列表、保存原始 stdout；Steam SDK 自己的 stderr 訊息不保證包含在日誌。

| 命令 | 功能與副作用 |
| --- | --- |
| `self-test` | 14 項離線測試；只在獨立暫存資料夾測試並清理，不初始化 Steam |
| `health` | Steam 初始化、帳號／AppID／登入狀態核對，完成後 shutdown |
| `list` | 作者 Published 清單，逐頁查詢；`-Page` 可單頁診斷；可保存 JSON |
| `details` | 指定 Workshop ID 的遠端詳情，唯讀 |
| `create-test` | 只接收 M0 測試計畫，建立新項目、保存 ID、以私人可見度提交、驗證詳情；會寫 Steam |
| `update-test` | 只更新已驗證第一版且帳號／遊戲／遠端私人標記一致的 M0 項目到第二版；會寫 Steam |
| `verify-test` | 重新查詢遠端，核對文案／可見度／marker／預覽後更新本機狀態；不寫 Steam |
| `download-test` | 透過 Steam 下載指定私人測試版並比對 `.ssmod` SHA-256；會寫 Steam 管理的下載快取，不訂閱、不啟用 |

沒有刪除項目、變更公開可見度或一般作品上傳入口。這是本原型的有限範圍，不能拿來更新四個正式作品。M0 實作採原版成套 x86 相依與 .NET Framework 4.8 目標；完整產品可依[新工具設計](NEW-TOOL-DESIGN.md#技術方案與可行性門檻)接 WPF UI，不需先修 SWD3Works。

## 實測結果

環境：Windows、本機 .NET Framework registry Version `4.8.09221`／Release `533509`、CLR `4.0.30319.42000`，Steam 登入「輕鬆小品」，AppID `1638230`。來源相依、exe／原始碼指紋與每案日誌見[證據索引](evidence/m0-20260906/README.md)。

| 案例 | 結果 |
| --- | --- |
| 原工具未執行時獨立查詢 | 找回 4 個既有公開作品，全部 owner／AppID 正確 |
| 分頁 | 第一頁 4 筆／總數 4；第二頁 0 筆／總數 4，正常結束。多頁都有資料尚未實測 |
| 指定 ID | 成功讀取既有 `3796228075` 詳情；沒有提交修改 |
| 私人新建 | ID `3796679826`，Create／Submit 均 `k_EResultOK`，不需另接受協議 |
| 重啟找回 | 新程序查到原 4 件＋私人測試 1 件，不依賴 `.mod` |
| 原 ID 更新 | 更新至 r2，仍為 `3796679826`，標題／說明／預覽／metadata／Private 正確 |
| 實際內容 | r1、r2 都經 Steam 下載；單一封包與本機 hash 一致，兩版 hash 不同 |
| 程序收尾 | 各案都有 completed／shutdown，能連續啟動下一次操作 |
| 正式作品保護 | 前後查詢的原 4 件資料逐項一致；離線拒絕公開／未標記作品 |
| 離線保護 | 14 項通過：原子保存與前版備份、排他鎖、64 位 ID、非法 ID、公開／marker 防護、重複建立、未完成重送、帳號隔離、計畫驗證、快照鎖定、hash 變動、額外檔案 |

私人測試作品仍保留：[Workshop 3796679826](https://steamcommunity.com/sharedfiles/filedetails/?id=3796679826)，用於後續原型核對。它未訂閱、未寫入 MOD 啟用清單；Steam 下載快取位於 `D:/SteamLibrary/steamapps/workshop/content/1638230/3796679826`。這次沒有啟動遊戲或驗證該 no-op 封包的遊戲載入，M0 的驗收是發布與下載位元內容。

## 保存與故障邊界

- 建立前保存 `create-intent`；建立成功立即保存 Workshop ID，再送內容。狀態檔或備份存在就拒絕再次 Create，避免重啟重複建作品。
- 更新前查 owner／AppID／Private／專屬 marker；只允許 `verified r1 → r2`，不把原工具選取項目當保存來源。
- 送出前保存 `submit-intent`；收到遠端成功寫 `remote-confirmed`；查詳情通過才 `verified`。保存採同目錄暫存、flush、原子替換及 `.bak`。
- Wait 有 5–600 秒時限及 Ctrl+C；timeout／IO failure 不代表遠端取消，保留 intent，退出碼 3 表示等待逾時／中止。一般錯誤退出碼 1，成功 0。
- 已有 ID 時，可用同計畫的 `verify-test` 重新核對並恢復狀態。若建立結果未知且沒有 ID，必須先查作者作品定位，**沒有自動恢復／重新建立**入口。
- Submit 同時鎖住封包／預覽，期間不允許本機寫入或刪除；以 prepared plan 的 hash 核對，不把路徑存在當驗證成功。
- 這是 M0 的單項目 JSON journal，尚非產品設計中的 SQLite、長期多操作佇列或 IPC 主視窗。

尚未真實故障注入：斷網、Steam 退出、程序在 Create callback 空窗被強制終止、磁碟滿、未接受協議、晚到／重複 callback、多頁滿資料、其他帳號與其他 Windows 版本。相關保護有部分離線測試，但不能列成全部線上故障已驗收。

## 測試內容與解包差異

可編輯 fixture 為 [metadata](prototype/fixture/studio_m0_fixture.ext) 及[純註解 Lua](prototype/fixture/Main.lua)。準備腳本建立兩版，各版本只包含一個 `.ssmod`；沒有遊戲 hook、全域名稱或保存 key，因此不需新增遊戲相容性識別碼。

本次 `SS2Dtool p` 成功產物之後，依既有 `x` 呼叫未得到輸出；縮短路徑、檔名、尾端斜線與 BOM 對照也未解決。原因尚未定位，不修改通用 `x` 語法或宣稱所有封包都無法解包。測試改用 [Verify-M0Package.py](scripts/Verify-M0Package.py)，反向解出這個 fixture 的兩個 Zstandard frame，逐位元核對 ext／Lua 並確認 Lua 全為註解；其適用範圍只限這個兩-frame fixture，不是通用 `.ssmod` parser。

已上傳的兩版原始內容與 marker 來自本次 test key `a66dbb2905b2405598981d7fcd76e0e9`。原測試計畫的絕對路徑記錄在 evidence；搬機需重新準備本機內容，不能拿舊路徑當可重建來源。

## 知識歸屬與後續

原型調用、環境與副作用維護在[工具正文](../../../docs/knowledge/tools-and-commands.md#steam-工作者原型-m0)；跨 MOD 可重用的版本限定 Steam 工作者可行性放在[發布正文](../../../docs/knowledge/steam-workshop-release.md#獨立-steam-工作者原型)。帳號、Workshop ID、原始 log、hash、fixture 解包例外與未測故障留在本專案。

下一階段是 M1 的作品列表與本機專案綁定 UI；目前不修改遊戲核心、原 SWD3Works 或正式 MOD 功能。
