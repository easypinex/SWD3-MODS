# 版本維護原型 0.2.0：2026-09-06 證據

**已實測。** Windows、Framework 4.8／CLR 4.0.30319.42000、x86 Steamworks.NET 20.2.0.0，Steam 登入帳號 `76561198095249191`（輕鬆小品），AppID `1638230`。未執行 SWD3Works 或遊戲。成品與三份來源、封包讀取器、相依 DLL 指紋見 [build-fingerprint.json](build-fingerprint.json)。最後交付 exe SHA-256：`87983615EF0B93A0D2BE9A5D774BC75D20FB9CB2A2E9ED8D2D1FEF79F9DB2AEB`。

本地建置目錄 `build/releases-0.2.0-delivery/`；線上發佈過程使用同版號開發建置，最終工作者再查回／下載驗證成功。各檔的精確來源 hash 以指紋區分，不把不同開發編譯稱為同一 binary。可讀結果見[核對報告](release-report.html)，重跑方式見[現行原型文件](../../RELEASES.md)。

## 案例

| 案例 | 層次與結果 | 原始證據 |
| --- | --- | --- |
| 作者清單基線 | 真實 Steam；4 個公開＋原 M0 私人作品 | [01](01-list-before.jsonl) |
| 舊工具追蹤資料不完整的作品接續維護 | 真實 Steam；私人 M0 ID `3796679826` 的內容 0.2 → 0.3；保留其原 Metadata | [02](02-migrate-review.jsonl)、[06](06-migrate-republish.jsonl) |
| 新建 | 真實 Steam；私人 ID `3796691396`；0.3 標題／說明／內容與下載版本驗證通過 | [07](07-create-review.jsonl)、[08](08-create-publish.jsonl) |
| 同 ID 0.3 → 0.4 | 真實 Steam；改標題、說明、內容及檔名；下載目錄只有新版檔案 | [09](09-r4-review.jsonl)、[11](11-r4-publish.jsonl) |
| 過期審閱保護 | 真實 Steam 查詢；0.4 提交後，用先前針對 0.3 審閱的 0.5 草稿送出，被拒絕；沒有 Submit | [10](10-r5-stale-review.jsonl)、[12](12-stale-blocked.jsonl) |
| 已完成操作重複呼叫 | 真實 Steam；只查詢／下載驗證，不再 Submit 或 Create | [13](13-no-resubmit.jsonl) |
| 同 ID 0.4 → 0.5 | 真實 Steam；再次改標題／說明／內容／檔名；下載內容逐項通過 | [14](14-r5-review.jsonl)、[15](15-r5-publish.jsonl) |
| 獨立檔案查詢 | 真實 Steam；含作品詳情、實際檔名／大小／hash／內嵌版本 | [17](17-final-files.jsonl) |
| 中文與預設語言同步 | 真實 Steam；同封包 0.5、原 ID，依 schema 3 提交中文後另提交 English 預設欄位，再查回兩者 | [20](20-sync-review.jsonl)、[21](21-sync-publish.jsonl) |
| 最終建置驗證 | 真實 Steam；最終 exe 再查回兩種語言、下載同包，verified | [22](22-delivery-verify.jsonl)、[報告](release-report.html) |
| 審閱後改說明 | 真實 Steam 初始化，但在任何 Submit 前以計畫 hash 拒絕；失敗 HTML 不顯示已驗證完成 | [24](24-changed-plan-blocked.jsonl) |
| 公開作品未變 | 4 件公開作品全部查回欄位與基線逐項一致；最終測試作品雙語文字一致 | [25](25-final-english-list.jsonl)、[26](26-final-chinese-details.jsonl)、[final-checks](final-checks.json) |
| 逐版歷史 | 本機讀取；0.3／0.4／0.5＋0.5 預設語言修正，共 4 筆成功操作 | [27](27-final-history.jsonl) |
| C# 守衛 | 離線；原有14＋版本維護18＝32項，涵蓋舊標題／說明、預設語言文字、檔名、大小、hash、內嵌版本錯誤、owner、降版、相同版本不同 bytes、重複版本標記等 | [28](28-delivery-self-test.jsonl) |
| 封包準備 | Python 離線；5項：真實封包快照、來源變更不影響快照、版本不符、壞封包、既存輸出保護 | [23](23-package-tests.txt) |

所有完成的線上命令均有 completed／shutdown；刻意失敗有 error／shutdown，之後可繼續操作。這是工作者不掛死的實測，沒有 WinForms 新 UI 可以用來宣稱已驗收 GUI。

## 封包證據

三版測試內容都是原型自有 metadata 與純註解 Lua；準備工具使用 SS2Dtool p，再獨立反解兩 frame 與來源逐 bytes 比較，沒有遊戲 hook 或保存動作。來源識別與封裝工具 hash 見 [fixture-evidence](fixture-evidence.json)。

| 版本 | Bytes | 下載檔名 | SHA-256 |
| --- | ---: | --- | --- |
| 0.3 | 770 | `studio_m0_fixture.ssmod` | `E03B24390B4D814537375453128101692FB60C7F596C8A62D6F5D74BB478EA88` |
| 0.4 | 770 | `studio_versioned_fixture.ssmod` | `F46B62CA21560BA111732F04599EA3929322F0E7025CCC89404EB762EE02EAE5` |
| 0.5 | 770 | `studio_m0_fixture.ssmod` | `BCD11DED6B5BBF814B9DB266C9228E9A772909CECC68A413E9F30E984C8038C5` |

相同大小的不同內容均成功辨識；hash 比對不依賴檔案大小推定版本。計畫證據：[新建](create-plan.json)、[0.4](r4-plan.json)、[0.5](r5-plan.json)、[schema 3 同步](r5-synced-plan.json)、[舊作品接續](migrate-plan.json)。計畫包含當次本機絕對路徑；搬機要重建新計畫，不把證據 JSON 當現成上傳來源。

## 失敗與語言差異發現

**已實測失敗。** 開發版首次使用帶 `.` 的 key（`SWD3Studio.Version` 等）。Setter 回傳成功，但 Submit 回 `k_EResultInvalidParam`。隨後查回繁體中文標題與說明已變成 0.3，下載檔案仍為 0.2、原 metadata 保留。[提交03](03-migrate-publish.jsonl)、[查回04](04-after-rejected.jsonl)、[重新下載05](05-migrate-rereview.jsonl)。因此不能把 Submit 非 OK 解讀成所有欄位都沒改。

Valve 官方限制 key 只能包含英數及底線；修正成 `SWD3Studio_Version`、`SWD3Studio_FileName`、`SWD3Studio_Sha256`、`SWD3Studio_Operation`、`SWD3Studio_Language` 後，同一私人作品重送成功。此為原型控制變更與所列環境的證據，不泛化所有 InvalidParam 的原因。[Valve AddItemKeyValueTag](https://partner.steamgames.com/doc/api/ISteamUGC#AddItemKeyValueTag)

首次失敗所用開發建置尚未把 EResult 存入 journal；為測試修正後的恢復流程，從原始03日誌讀取已確認 callback，將該結果遷入本機開發 journal，保留遷移前副本，見 [journal-migration](journal-migration.json)。這不是「任意手改成功狀態」：只補已存在的失敗證據，再真實下載／重新審閱／重送，06才得到 verified。現行程式在 callback 時自行持久化 EResult；未知 callback 不可用此已知失敗路徑重試。

**已實測語言差異。** schema 2 指定 `tchinese` 更新到0.5後，English查詢仍見新建時的0.3標題；這與繁體中文查回不同。[19](19-final-list.jsonl) 對照 [16](16-final-verify.jsonl)。新增schema 3預設語言同步後，兩者文字完全一致，見25／26。早期 M0 私人項目3796679826保留schema 2歷史語言行為，並非schema 3同步案例。

## 邊界與保留項目

兩個私人作品仍保留，沒有訂閱或安裝至 Mods。Steam 自己的 workshop content 快取下載為預期副作用。原四件公開作品未寫入，主遊戲未啟動。未測故障範圍與完整產品缺口以 [RELEASES](../../RELEASES.md#驗證界線)為準。
