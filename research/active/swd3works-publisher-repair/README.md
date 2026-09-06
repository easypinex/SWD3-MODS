# SWD3Works 診斷與發佈維護工具規劃

2026-09-06。已完成 **[SWD3 MOD Studio 發佈與維護桌面版 0.3.0](DESKTOP.md)**：找回作品、保存草稿、原 ID 升版、私人新建、查詢文字／檔案／版本歷史、失敗恢復及 HTML 核對報告。已用私人作品實測桌面更新 0.5 → 0.6、新建 0.7，並重啟驗證紀錄；見[桌面驗收](evidence/desktop-20260906/README.md)。原 CLI 階段保留在 [0.2.0](RELEASES.md)／[M0](PROTOTYPE.md)。尚未製作原工具修正版或重現原工具現場卡死；下方保留原靜態診斷與備案。研究狀態見[研究清冊](../../README.md)。

使用者追加可採全新工具替代。**建議主方案為 [SWD3 MOD Studio 全新工具提案](NEW-TOOL-DESIGN.md)**，涵蓋發佈、維護、作品恢復與本機 MOD 管理；本頁 F1–F3 為共用證據，下方修補策略保留為備案。新工具無需先完成舊工具修補。使用者後續要求「完成 Steam 原型」，已據此完成獨立私人測試；下方「不寫 Steam」等描述僅指最初靜態診斷／規劃階段。

## 目標與授權範圍

使用者回報：無法追蹤已發佈插件，因而無法維護；上傳成功提示出現後整個應用卡死，只能強制終止。回報未區分新建或更新，未提供當次堆疊。

**專案決策：** 這是發佈工具修復，不是遊戲 MOD。依本次使用者「可以用更激進的方式」的指示，可評估受管 IL 修補、重建工具，以及必要時對工具程序取例外／堆疊。一般 `.ssmod` 的禁止 exe patch 支援邊界不作為本工具方案的否決理由。修改先在隔離副本進行；本次規劃不改遊戲核心、不安裝、不上傳。此例外不擴張到其他 MOD 或遊戲本體。

預期結果：重新啟動後仍能找回自己發佈的項目；更新沿用原 Workshop ID；上傳完成、失敗或本機保存失敗時，介面均可繼續操作並清楚區分遠端與本機結果。

## 分析基線與重跑

**已靜態反解**，2026-09-06，本機 Steam HD 4.0.5 安裝隨附：

| 輸入 | 版本 | 大小 | SHA-256 |
| --- | --- | ---: | --- |
| SWD3Works.exe | 1.0.0.1 | 484,864 bytes | `756D9E2F9866EC335F8A536B9ED0DE2869BBE83FF3D5BF468E0F8A2E3C0330FA` |
| Steamworks.NET.dll | 20.2.0 | 381,440 bytes | `CFC3DB8EDBB2A1BB5A23FA045BB3F30C959068DF147B01FC34291F7E0C71029F` |

使用 ILSpyCmd／ICSharpCode.Decompiler `9.1.0.7988`、本機 .NET SDK `8.0.204`／runtime `8.0.4`。從安裝目錄複製三份檔案後反編譯；未執行目標程式、未載入原生 Steam API。完整指紋及重跑腳本 hash 見 [fingerprint.json](evidence/20260906/fingerprint.json)，選定控制流見 [control-flow-excerpts.txt](evidence/20260906/control-flow-excerpts.txt)。報告每列左側數字是完整 C# 匯出行號。

完整反編譯只保留在本機 `.work/publisher-analysis-20260906-verified/decompiled/`；不提交原版程式、相依 DLL 或完整反編譯工程。C# 匯出是反編譯結果，不是官方原始碼。重跑入口、參數與副作用統一見[工具索引](../../../docs/knowledge/tools-and-commands.md#swd3works-受管反編譯)。不同來源或輸出 hash 必須重新定位，腳本不套用既有行號摘要。

## F1：成功後空值例外與追蹤紀錄遺失

**已靜態反解。** 證據：[新增與完成分支](evidence/20260906/control-flow-excerpts.txt#L11)、[新建入口](evidence/20260906/control-flow-excerpts.txt#L149)、[建立回呼](evidence/20260906/control-flow-excerpts.txt#L159)。

1. `PALWorkshopForm.button_New_Click`（原 C# 3437–3444）先設 `SelectItem = null`；`MODDetails` 建構子（1648）把它帶入編輯視窗。
2. `MODDetails.buttonOK_Click`（1854–1871）新建一個區域 `SteamWorkshopItem` 交給 `CreateItem`，沒有寫回視窗的 `SelectItem`，隨後設 `Enabled = false`、等候游標。
3. `CreateFromWorkshopItem`（3886–3913）回填該區域物件的 ID，成功後呼叫 `UpdateItem(item, out ...)`。視窗未訂閱 `ItemCreated` 來接回這個物件。
4. `MODDetails.ItemUpdate`（1879–1902）先顯示成功／失敗訊息，再執行 `WriteItem(SelectItem)`；`WriteItem` 首行即取 `item.FileId`（1907），沒有 null guard。
5. 因此新建流程到達該處會空值例外；後面的 `UseWaitCursor = false` 與 `Close()` 無法執行，本機 `Tools/<ID>.mod` 也不會寫出。管理器回呼的清理位於事件通知之後，也會受事件例外影響。

**待驗證：** 此控制流與使用者回報高度吻合，但尚無當次例外堆疊；不能宣稱已證明所有「卡死」都是死鎖或此例外。若回報來自更新既有項目，優先查 F3 的保存例外與回呼計數；只有仍不能解釋時才附加工具除錯器。

## F2：維護清單沒有查詢已發佈作品

**已靜態反解。** 證據：[PALWorkshopForm 清單流程](evidence/20260906/control-flow-excerpts.txt#L77)、[Steam 查詢實作](evidence/20260906/control-flow-excerpts.txt#L235)。

- `LoadList`（3305）只從 `Application.StartupPath/Tools/*.mod` 載入維護資料。缺少本機紀錄的已發佈項目不會自行重建。
- 建構子先 `LoadList`、`UpdateList`，再查 `QueryInstalledWorkshopItems`（3251）。後者實際以 `GetNumSubscribedItems`／`GetSubscribedItems` 取得訂閱 ID，接著查詳情（4030–4040）。
- `UgcQueryCompleted`（3254–3287）把不在訂閱結果中的條目從記憶體 `items` 刪除；沒有把遠端作品新增進來，也沒有在成功分支呼叫 `UpdateList`。這證明資料來源／篩選有誤，不能直接聲稱當前畫面會立即刪掉條目。
- 查詢失敗會再次直接查詢，沒有上限或退避；這是附帶的可靠性缺口。

**官方 API 說明＋專案決策：** 作者作品查詢應使用 `CreateQueryUserUGCRequest` 搭配 `k_EUserUGCList_Published`，分頁取得；訂閱管理保持其原功能。參考 [Valve ISteamUGC](https://partner.steamgames.com/doc/api/isteamugc#CreateQueryUserUGCRequest)。本機包裝器是否可完整找回私人／未列出／歷史作品仍需實測。

## F3：保存、建立失敗與內容更新的附帶缺口

**已靜態反解：**

- `WriteItem` 寫入相對工作目錄的 `Tools/<ID>.mod`（1912），讀取端卻基於 `Application.StartupPath`（3305）；兩者不保證相同。寫入沒有例外隔離或原子替換。即使是既有項目，檔案被鎖定／目錄無法寫入也會跳過 UI 收尾。[保存分支](evidence/20260906/control-flow-excerpts.txt#L57)
- `CreateFromWorkshopItem` 建立失敗只觸發 `ItemCreated` 並寫 Console；視窗只訂閱 `ItemUpdated`，無法從此路徑恢復禁用狀態。[建立分支](evidence/20260906/control-flow-excerpts.txt#L159)
- 新建成功後走 `UpdateItem(item, out ...)`；這個多載設定 metadata、visibility、tags、content、preview，沒有設定 title／description／language。另有同名單引數示範函式，不是該呼叫點。需在實作驗收增加「新建標題／說明真的提交」案例。[實際多載](evidence/20260906/control-flow-excerpts.txt#L189)
- Steam callbacks 由 `Application.Idle` 直接呼叫；成功提示在 callback stack 內同步顯示。[Idle 入口](evidence/20260906/control-flow-excerpts.txt#L281)

**待驗證：** callback 重入是否導致另一種卡死，目前沒有堆疊證據；不能僅由 `MessageBox` 與 `Application.Idle` 的共存認定死鎖。

## 修復策略

**備案決策：若選擇修原工具，對副本做可重現的受管修補。** 反編譯已能定位到具名方法，先保留現有 UI／資源與 Steamworks.NET 相依，只修改發佈相關流程。實作時以 metadata token／IL 指令核對 C# 結論，patcher 檢查 exe 與 DLL hash、目標方法簽章及原始 IL；任一不符即拒絕。輸出另名修正版與原檔指紋／回復說明，不依賴固定裸位元組偏移。

| 路線 | 使用時機 | 代價與門檻 |
| --- | --- | --- |
| 原工具 IL 修補＋自有 helper | 首選；先修 F1，再完成 F2/F3 | 需維護有限版本白名單、方法驗證及相依載入；尚未驗證可用 patch 工具鏈 |
| 重建獨立發佈器 | 若清單、資料保存與交易流程使 patch 範圍失控 | 以自有來源實作相同 Steam UGC 能力；需補齊 UI、語言、架構、既有資料匯入與 Steam 初始化驗收 |
| runtime hook／注入 | 僅當靜態修補不可行且有明確阻礙 | 部署與生命週期成本高，目前反解結果沒有理由優先採用 |

不以「捕捉所有例外後直接當成功」作修復，也不把 `WriteItem(e.Item)` 當完整答案：既有更新的 `e.Item` 可能是某一語言／內容子請求，只保存它會遺失其餘維護資料。

### P1：可靠完成與可恢復的上傳交易

1. 建立視窗持有的完整操作物件，含原始／草稿狀態、AppID、Steam 帳號、Workshop ID、操作 ID 與各子請求。新建成功接回同一完整物件；事件按操作與項目歸屬過濾，避免全域 static event 混算。
2. `CreateItem` 成功取得 ID 後立即保存「已建立、待提交」紀錄，再送內容；ID 保存失敗時停止自動後續步驟並提供 ID 匯出。重啟／重試沿用此 ID，不再建立重複作品。建立結果未知時查帳號作品人工核對，不盲目重建。
3. 每個實際 submit 對應一筆 pending 狀態；請求發出前登記，失敗移除，重複／遲到 callback 冪等處理。多語言按項目序列提交，每次使用新 update handle，統整部分成功／失敗。使用者僅改說明時不強制重新上傳內容。
4. 首次建立明確提交 title、description、language、visibility、content、preview；檢查每個 setter 回傳與 handle，有錯不繼續宣告成功。既有更新只改選定欄位，保留其他語言、標籤與可見度。
5. 區分遠端提交結果、本機保存結果與 UI 狀態：Steam 成功但保存失敗顯示「已上傳，維護紀錄保存失敗」及 Workshop ID；所有終止路徑用 `finally` 恢復按鈕、游標並清理 callback／事件。全域例外處理只記錄與協助恢復，不代替這些分支。
6. Steam pump 維持單執行緒且有重入防護，可改 WinForms timer 定期執行；callback 先完成狀態與清理，再透過 UI queue 顯示結果。callback 不等待另一個 callback，不作同步長時間 IO。官方執行緒語意參考 [SteamAPI_RunCallbacks](https://partner.steamgames.com/doc/api/steam_api#SteamAPI_RunCallbacks)。
7. 加入階段、時間、操作 ID、Workshop ID、EResult、IO failure、保存例外與 UI 收尾的結構化紀錄。逾時標成「結果待確認」，允許查看／離開；停止等待不宣稱取消了 Steam 上傳，重試前先核對遠端狀態。需要接受工作坊協議另列狀態。

### P2：作品找回與維護資料

1. 新增作者清單專用查詢，使用登入帳號、正確 AppID（SWD3 HD 為 `1638230`）與 Published 類型。查完所有頁，以 Workshop ID 去重；核對 owner、consumer app 和可編輯性。不得把 `QueryInstalledWorkshopItems` 直接全域改成作者查詢，因原工具 MOD 安裝管理也使用它。
2. 合併遠端作者作品、本機紀錄與未完成操作。未訂閱、未下載、本機來源遺失均可顯示；網路失敗保留快取與明確離線狀態，不刪資料。單頁空結果／部分分頁失敗不代表遠端刪除。有限退避，釋放每個 query handle。
3. 提供 Workshop URL／ID 匯入，再向 Steam 驗證歸屬與遊戲；從遠端恢復 ID、標題、說明、可見度。本機原始內容目錄／預覽來源需重新指定，不能從雲端資料推定作者原路徑。
4. 保存位置採每使用者可寫的固定資料目錄，按 AppID／Steam 帳號／Workshop ID 分開。讀入舊 `Tools/*.mod` 保留原檔備份與匯入結果；新格式用版本化 UTF-8 JSON，ID 存十進位字串。不要把 `.mod` 的多行括號格式直接延伸為新權威。
5. 本機保存採同目錄暫存、關閉／flush 後原子替換與備份；對磁碟滿、權限、鎖檔、格式損壞保留可恢復前版。移動來源目錄只重新綁定，不改遠端 ID。修改前保留完整草稿，失敗不冒充已同步。

### P3：離線驗證、實機驗收與交付

先使用假的 Steam gateway 驗證請求與回呼，通過後才啟動工具做真實驗收。規劃本身不觸發真實上傳；實作階段選定私人測試項目及內容，完成可檢閱版本後再執行已授權的測試操作。

| 層次／案例 | 驗收條件 |
| --- | --- |
| 原版回歸重現 | 離線觸發新建成功回呼，抓到 `WriteItem(null)`；另模擬既有項目保存失敗，核對原版 UI 收尾缺失。mock 不標為真實卡死重現 |
| 新建→成功→重啟→更新 | 同一 Workshop ID；第一次 title／description 正確；關閉提示可繼續操作；重啟找得到；再次提交只更新原項目 |
| 回呼異常 | 建立失敗、setter false、submit failure、IO failure、亂序、重複、遲到、部分語言失敗、關窗及連續兩次操作，均不混算、不重複成功、不永久禁用 |
| 本機 IO | 改變工作目錄、唯讀／鎖檔、磁碟滿、損壞 JSON、中文長路徑、內容移動、提交後程序中斷，均保留 ID 與恢復線索 |
| 作者清單 | 0／1／跨頁作品、未訂閱、私人作品、無舊紀錄、舊紀錄存在、他人 ID、錯 AppID、離線及中途換帳號；不能以此刪除或覆寫其他作品 |
| 更新不破壞資料 | 文字單改、多語言、只換內容／預覽、保留 tags／visibility、遠端與草稿差異、部分成功後重試 |
| 真實 Steam | 私人新建／原 ID 更新；驗證遠端詳情與內容、工具可持續操作與正常退出。必要時訂閱下載版按既有發布流程核對內容 hash |
| 發行與還原 | 原檔／相依 hash 不符即拒絕；重複套用拒絕；可還原原工具；Steam 更新覆寫可偵測；不修改遊戲本體或 MOD 核心檔 |

建議交付順序：**先完成 P1 的新建閉環與紀錄保護，再做 P2 的既有作品恢復，最後做 P3 的真實回歸。** 單一 null patch 可作定位實驗，不能稱為完整修復。

## 初次靜態規劃的驗證與知識歸屬

- 已完成兩次隔離 C# 匯出，全文 SHA-256 相同；複製前後與反解後的遊戲輸入／副本 hash 均一致。
- 已保留有版本白名單與完整輸出 hash 保護的摘要匯出腳本；未知版仍可產生本機 C#，但不套用既有摘要行號。
- 本次只驗證靜態流程與文件連結，不宣稱 patch、離線回歸、介面卡死重現或 Steam 上傳通過。
- 可跨 MOD 重用的工具呼叫維護在[工具索引](../../../docs/knowledge/tools-and-commands.md#swd3works-受管反編譯)；發佈時不能依賴成功提示或自動找回清單的版本限定提醒放在[發布正文](../../../docs/knowledge/steam-workshop-release.md#swd3worksexe-流程)。完整 F1–F3 證據、修補例外與未驗證的設計留在本研究。
- 未新增遊戲快捷鍵、hook、namespace、保存 key 或資產 ID，無需變更 MOD 相容性登記；工具內部資料 schema 尚待實作。
