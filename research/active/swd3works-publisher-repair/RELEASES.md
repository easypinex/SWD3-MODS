# Steam 發佈與版本維護原型 0.2.0

本頁保存 0.2.0 階段契約及歷史證據。現行版本為 [桌面版 0.3.0](DESKTOP.md)，包括新的使用者資料位置；下文「GUI 未製作」與 LocalAppData 指 0.2.0 當時狀態。

2026-09-06。**已實測**：新建發佈、原 ID 連續更新、遠端標題／說明／版本查詢、實際下載檔名／大小／SHA-256／封包內版本核對，以及本機逐版歷史。這是可執行工作者與 HTML 核對報告；完整桌面 GUI、專案綁定畫面仍未製作。早期 M0 紀錄保留在 [PROTOTYPE](PROTOTYPE.md)，現行操作以本頁與[工具正文](../../../docs/knowledge/tools-and-commands.md#steam-版本維護原型-020)為準。

可直接查看本次[核對報告](evidence/releases-20260906/release-report.html)；[實測與原始日誌](evidence/releases-20260906/README.md)保留版本、帳號條件、失敗案例與修正結果。

## 已完成行為

| 操作 | 結果與完成條件 |
| --- | --- |
| 找回作品 | 從目前帳號的 Steam Published 清單分頁查詢；不需要原工具 `.mod` 或自行訂閱 |
| 查詢 | 標題、完整內容說明、可見度、版本、檔名與預期 hash；`files` 實際下載列出每個檔案及封包內版本 |
| 新建 | 先保存操作，再建立 ID；ID 保存後才提交；新草稿預設私人 |
| 更新 | 指定既有 Workshop ID，支援持續升版；修改封包須提高 `MODVersion`；同版相同 bytes 可修正刊登文字 |
| 標題與說明 | 新產生的 schema 3 計畫同步選定語言及 English 預設欄位，逐字查回兩者；不是把內容翻譯成英文 |
| 檔案與內容 | 發佈前從封包讀版本；提交後重新下載，比對單一檔名、大小、完整 SHA-256、內嵌 MODVersion；額外／舊檔殘留會失敗 |
| 完成判定 | 遠端文字、版本標記與實際下載全部一致才 `verified`；Steam 的 Submit OK 不直接代表完成 |
| 逐版維護 | 每次操作保存原資料、計畫、遠端結果、下載盤點與時間；`history` 可查本機曾成功驗證的版本 |

本次私人作品 `3796691396` 已實際完成 **0.3 → 0.4 → 0.5**，0.4 與 0.5 刻意更換下載檔名，下載目錄均只剩新檔。之後同版 0.5 另做一次預設語言同步修正，故歷史共有四筆成功操作、三個封包版本。原四個公開作品未修改。

## 使用入口

本機已建置可執行目錄為 `build/releases-0.2.0-delivery/`（不提交原版 DLL／build 產物）；重建及所有副作用見[工具正文](../../../docs/knowledge/tools-and-commands.md#steam-版本維護原型-020)。下例均從工作區根目錄執行，所有新輸出路徑必須尚不存在。

1. 將已封裝驗收的成品及本次刊登文案放入草稿 JSON。更新時 `WorkshopId` 是原 ID；新建時省略並必須提供 `PreviewFile`。版本從 `.ssmod` 自動讀取；若草稿額外指定 `Version`，必須與封包內版本完全一致。

```json
{
  "WorkshopId": "原作品的十進位ID",
  "Package": "D:/workspace/SWD3-MODS/目標專案/dist/成品.ssmod",
  "Title": "作品的新標題",
  "Description": "完整作品說明，含本次版本與使用方式。",
  "Language": "tchinese",
  "Visibility": "preserve",
  "ChangeNote": "本次版本的更新內容"
}
```

`Language` 支援 `tchinese`、`schinese`、`english`；預設 `tchinese`。schema 3 的中文草稿會把相同標題／說明寫入中文及 English 預設欄位，審閱報告會列出原預設欄位與預期值；未選定的其他翻譯不變。如果需要各語言保留不同文案，須等待完整多語言編輯功能，不能用此同步流程當翻譯編輯器。歷史 schema 2 仍可驗證，維持其當時的單語言契約。

2. 建立獨立快照並查詢更新前的實際資料：

```powershell
python research/active/swd3works-publisher-repair/scripts/SteamReleasePackage.py prepare `
  '<draft.json>' '<workspace>/.work/my-release'

& ./research/active/swd3works-publisher-repair/scripts/Invoke-SteamPrototype.ps1 `
  -BuildRoot '<build-root>' -Command review-release `
  -PlanPath '<release>/plan.json' -StatePath '<release>/state.json' `
  -LogPath '<release>/review.jsonl' -OutputPath '<release>/review.json'
```

審閱包含本次標題、說明、檔案、版本、可見度與語言。`review.jsonl.html` 是可直接打開的中文核對報告。準備後修改來源不會改變已準備的快照；計畫、快照被修改則拒絕提交，需重新準備。

3. 新建與更新都使用同一個發佈入口；由計畫是否已有 Workshop ID 決定：

```powershell
& ./research/active/swd3works-publisher-repair/scripts/Invoke-SteamPrototype.ps1 `
  -BuildRoot '<build-root>' -Command publish-release `
  -PlanPath '<release>/plan.json' -StatePath '<release>/state.json' `
  -LogPath '<release>/publish.jsonl' -OutputPath '<release>/result.json'
```

此命令**會寫 Steam**，會同步計畫中選定的語言與預設欄位。它接著自動回查／下載，不需額外手動呼叫下載才驗收。成功報告是 `publish.jsonl.html`。狀態不是 `verified` 或退出碼非 0，都不能當作完成；HTML 產出失敗也會回報本機錯誤，不因此重送 Steam 操作。

4. 後續查詢、維護：

```powershell
& ./research/active/swd3works-publisher-repair/scripts/Invoke-SteamPrototype.ps1 `
  -BuildRoot '<build-root>' -Command files -ItemId '<Workshop-ID>' `
  -LogPath '<new-files-log>' -OutputPath '<files.json>'

& ./research/active/swd3works-publisher-repair/scripts/Invoke-SteamPrototype.ps1 `
  -BuildRoot '<build-root>' -Command history -ItemId '<Workshop-ID>' `
  -LogPath '<new-history-log>' -OutputPath '<history.json>'
```

`details` 只查遠端文字／版本標記，不下載；`files` 同時查文字與實際下載，舊工具作品尚無版本標記時仍可從 `.ssmod` 查版本。每次下一版用原 ID 建新草稿與新操作目錄，重複準備→審閱→發佈。不要複用已完成操作來代表新版。

## 狀態、失敗與恢復

- 相同帳號工作者由本機 mutex 序列化；固定帳號目錄保存操作到 journal 的映射及項目的未完成操作，防止換 StatePath 重複 Create 或覆寫尚未確認的更新。
- 更新前檢查 owner、AppID、原始文字、版本標記與再下載的舊檔案。遠端已改動就拒絕過期草稿；重新準備／查詢後才可送出。Steam API 沒有跨其他電腦的原子比較後更新，最後一次查詢到 Submit 間仍存在外部操作競爭空窗。
- 已有 ID 或已送出的操作再次 `publish-release` 只進入核對，不自動再 Create／Submit。`verify-release` 使用相同 PlanPath／StatePath 重新查回及下載，不發佈。
- **明確 Submit 拒絕**：保存 EResult，盡可能查回已部分改動的資料。原計畫再次 `review-release` 可重新盤點並保存舊 attempt，再由 `publish-release` 重送原 ID；不假設 Steam 失敗會回滾文字。
- **未知結果**：逾時、中斷、IO failure 不能當作取消。保留 intent；有 ID 用 `verify-release`，無 ID 必須查作者清單人工定位。沒有盲目重送未知 Create 的入口。
- `close-release` 僅供已有明確拒絕結果且遠端文字與檔案均保持原狀的既有更新；會查詢／下載後標記 `closed-unchanged`。若遠端部分改動或結果未知，拒絕關閉。此入口目前只有程式守衛，未另做線上拒絕無改動案例。
- 逐版成功紀錄位於 `%LOCALAPPDATA%/SWD3ModStudio/releases/1638230/<SteamID>/history-<ID>-<OperationID>.json`，操作目錄保留計畫、來源快照、完整 journal／備份。`history` 是本機曾驗證的歷史，無法從 Steam 恢復從未記錄的舊版封包。

`reviewed → create-intent／created（新建）→ submit-intent → verification-pending → default-submit-intent（中文）→ verification-pending → verified`。中途退出仍保留各階段；回呼只寫結果，不顯示阻塞式成功對話框。

## 驗證界線

- 已通過 32 項 C# 離線斷言、5 項 Python 快照／封包測試，以及所列真實 Steam 案例；[證據索引](evidence/releases-20260906/README.md#案例)區分各層。
- manifest 讀取器只接受 SMOD v4、可辨識且宣告大小不超過 16 MB 的首個 Zstandard frame、UTF-8 metadata、一個兩段 `MODVersion`。它不是完整資源解包／Lua 實機驗收器；未知封包格式明確拒絕。
- 封包完整 bytes 以 SHA-256 比對；說明頁 Description 逐字回查。ChangeNote 已提交且保留本機歷史，尚未從 Steam 歷史頁逐字回查；預覽圖只查遠端 URL 存在，尚未下載逐圖比對。
- 本次未公開測試作品、未訂閱、未啟用 MOD、未改遊戲核心，未啟動遊戲。真正 MOD 的遊戲功能仍依其 TESTING 驗收。
- 未完成斷網、磁碟滿、法律協議、所有失敗重試組合、跨帳號／多頁滿資料、跨電腦競爭及 Steam 內容審核狀態矩陣。私人測試成功不代表正式公開審核一定通過。

本次可重用的工具呼叫與跨 MOD 發佈注意事項已補既有[工具正文](../../../docs/knowledge/tools-and-commands.md#steam-版本維護原型-020)與[發布正文](../../../docs/knowledge/steam-workshop-release.md#獨立-steam-工作者原型)。`SWD3Studio_` 開頭的五個 Workshop key 是此發佈器的遠端追蹤資料，不是遊戲全域名稱或存檔 key；未新增遊戲相容性識別碼。
