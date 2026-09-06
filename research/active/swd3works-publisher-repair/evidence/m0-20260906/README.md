# M0 Steam 實測證據

日期：2026-09-06 17:18–17:24 Asia/Taipei；log 時間為 UTC。目標 AppID `1638230`，登入帳號為 log 的 SteamID，私人測試 ID `3796679826`。來源與操作說明見[原型文件](../../PROTOTYPE.md)。

## 版本

- 真實 Create／Update 使用[上傳版指紋](upload-build-fingerprint.json)及[精確歷史自有來源](upload-tested-source.cs)。歷史來源與 manifest 的 SHA-256 已比對，非反編譯原版工具。
- 隨後只收緊「封包必須在 content 根目錄」、新增離線防護測試與限制測試清理目錄，未改 Steam 提交內容／回呼流程。現行 build 見[最終版指紋](final-build-fingerprint.json)，編輯來源為[現行 SteamPrototype.cs](../../prototype/SteamPrototype.cs)。不把後加離線案例冒稱為上傳前即已執行。
- 兩版都使用 `Steamworks.NET.dll 20.2.0.0` hash `CFC3DB8EDBB2A1BB5A23FA045BB3F30C959068DF147B01FC34291F7E0C71029F`、x86 `steam_api.dll` hash `DF431862608823F54DF423428296273E1CA65C9928FA93633B882FE1C3D7D153`。
- 目標 framework 4.8；實機 registry Version `4.8.09221`／Release `533509`，編譯器 `4.8.9221.0 built by: NET481REL1LAST_25H2`。CLR 的 `4.0.30319.42000` 不能單獨當 framework 版本。

## 已實測案例

| 證據 | 操作與結果 |
| --- | --- |
| [01 作者基線](01-published-before.log) | Published 第一頁 4／4，全部為目前帳號與目標 AppID；不依賴原工具 `.mod` |
| [02 第二頁](02-page2.log) | 明確查 page=2，0／總數4；單頁診斷 `complete=false`，沒有誤宣稱取得完整清單 |
| [03 新建 r1](03-create-r1.log) | create-intent → ID 3796679826 已保存 → submit-intent → `k_EResultOK` → verified → shutdown；英文文案／Private／預覽及 marker 正確 |
| [04 重啟列表](04-restart-list.log) | 新程序取得5件，新增私人 r1；原四件仍在 |
| [05 下載 r1](05-download-r1.log) | Steam DownloadItem 成功，只有單一 `.ssmod`，hash `47D75EFA1539CE8BB652947549CD1856B1A0310294CFEECA75C28E832890E5C5`，subscribed=false |
| [06 同 ID 更新 r2](06-update-r2.log) | Update 仍為3796679826，verified revision=2，正常 shutdown |
| [07 下載 r2](07-download-r2.log) | hash `844EA33D1DAE3DF398CEA50765A4296B508A7BA6B2BDED59C4AD7D4EC2EF4752`，與r1不同，subscribed=false |
| [08 離線14項](08-self-test.log) | 尚未增加清理目錄檢查前的版本；全部通過，未初始化 Steam |
| [09 重啟查驗](09-restart-verify-r2.log) | 新程序從本機 journal 查遠端r2，通過後保存 verified |
| [10 最後列表](10-final-list.log) | 4件既有公開＋1件私人r2；沒有第二件測試作品 |
| [11 既有 ID 詳情](11-existing-item-details.log) | 唯讀取得3796228075，正常完成 |
| [12 最終離線14項](12-final-self-test.log) | 最終來源測試通過；不作新的遠端寫入 |

原4件所有本次讀出的遠端欄位，前後逐項一致，見[比較結果](existing-items-comparison.json)；比較包含標題、說明、可見度、更新時間、metadata、預覽URL等，不宣稱驗證了未查到的 Steam 後端欄位。

## 內容與狀態

[測試 fixture 指紋](fixture-evidence.json)、[r1 反解](package-r1-verification.json)、[r2 反解](package-r2-verification.json)保留來源 Lua／ext／封包 hash；兩次下載 log 直接匹配封包 hash。

[r1 計畫](plan-r1.json)、[r2 計畫](plan-r2.json)是當次實際提交文字及路徑快照；[最終 journal](test-state.json)為 verified r2。這些 evidence 是歷史唯讀紀錄，不作現行編輯或操作狀態來源。

原型未訂閱／啟用測試 MOD，也未修改 SWD3Works、遊戲核心或正式作品。私人項目與 Steam 下載快取保留，供後續維護；沒有執行刪除。

## 證據邊界

已證明這組 runtime／相依／帳號可獨立查詢、新建及更新私人 UGC，並有實際下載位元證據。沒有真實多頁滿資料、網路中斷、Create 回呼遺失、磁碟滿、不同帳號等測試；更不代表完整 GUI、原工具卡死修復或遊戲載入已驗收。
