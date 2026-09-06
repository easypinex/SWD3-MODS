# Steam 工作坊發布

## 發布前

- 更新版本、日期、支援遊戲版本、功能與已知限制。
- 執行專案自動測試及 [測試與驗證](testing-and-verification.md) 中適用的實機矩陣。
- 依 [封裝與安裝](packaging-and-installation.md) 反向解包並逐檔驗證。
- 自訂中文須通過 `TYPE 0`、StringDB 與 fallback 測試。
- 不得包含測試腳本、私人路徑、反解原版資料或暫存檔。

## 版本同步與可重現性

同一發行版本至少核對下列位置，避免「封包已更新、說明仍是舊版」：

| 項目 | 權威位置 | 核對內容 |
| --- | --- | --- |
| MOD metadata | `src/<basename>.ext` | `MODVersion`、`MODDate`、遊戲版本與 `MODinfo`。 |
| 功能與操作 | 專案 `README.md` | 版本、快捷鍵、保存行為、限制與成功訊息。 |
| 可下載成品 | `dist/<basename>.ssmod` | 反解內容及 SHA-256。 |
| 工作坊內容 | `workshop_content/<basename>.ssmod` | 與 `dist` 的 SHA-256 一致。 |
| 刊登素材 | 專案發布目錄 | 標題、說明、更新內容、預覽圖與 manifest 均對應同一版本。 |

雜湊、文案與 manifest 是特定版本證據，保留在專案發布紀錄；本文件只維護同步規則。

## 工作坊內容邊界

內容資料夾只放單一正式 `.ssmod`：

```text
workshop_content/
└─ <basename>.ssmod
```

以下留在原始碼專案，不放入內容資料夾：

- `src`、`tests`、README 與開發筆記。
- 散裝 `.ext`、Lua、txt 和反解目錄。
- 原始封面大圖、編輯素材或 ImageGen prompt。
- 與發行無關的其他 MOD 成品。

## `SWD3Works.exe` 流程

工具位置、輸入欄位與 CLI 限制見[工具與命令參考的 SWD3Works 小節](tools-and-commands.md)。

**版本限定提醒，已靜態反解，2026-09-06：** 隨附 `SWD3Works 1.0.0.1`（SHA-256 `756D9E2F9866EC335F8A536B9ED0DE2869BBE83FF3D5BF468E0F8A2E3C0330FA`）的新建流程可能在成功提示後以 null 寫維護紀錄，跳過 UI 收尾；作品清單只讀本機紀錄並以訂閱項目篩選。不要依賴成功提示代表本機追蹤已保存，也不能假定工具會從 Steam 自動找回自己發佈的作品。保存 Workshop ID，另核對遠端內容；故障原因、控制流證據與新工具提案見 [F1](../../research/active/swd3works-publisher-repair/README.md#f1成功後空值例外與追蹤紀錄遺失)、[F2](../../research/active/swd3works-publisher-repair/README.md#f2維護清單沒有查詢已發佈作品)。目前尚未完成該故障的 runtime 重現或修正版驗收。

1. 使用 `<game-root>\SWD3Works.exe` 建立或選擇正確項目。
2. 內容資料夾指向只含 `.ssmod` 的 `workshop_content`。
3. 填入標題、說明、預覽圖、版本和相容性資訊。
4. 第一次或重大更新先設為私人或僅限好友。
5. 上傳後取消訂閱再重新訂閱，檢查 Steam 實際下載內容。
6. 確認 `steamapps/workshop/content/1638230/<WorkshopItemID>` 只有預期成品。
7. 在 MOD 管理停用再啟用，清除可能殘留的舊 `.ext` 清單。
8. 完全關閉並重開遊戲，以訂閱下載版重新做 Console 與實機驗收。
9. 全部通過後才改為公開。

## 獨立 Steam 工作者原型

**已實測，2026-09-06，版本限定。** 本工作區的 M0 工作者以 .NET Framework 4.8 目標、x86 `Steamworks.NET 20.2.0.0` 配套 native DLL，在 Steam 已登入且 AppID `1638230` 的條件下，不執行 SWD3Works 即可查作者 Published 清單、讀指定 ID、建立私人作品及同 ID 更新。新建／重啟／更新與兩版實際下載 hash 證據見 [M0 案例](../../research/active/swd3works-publisher-repair/evidence/m0-20260906/README.md#已實測案例)，依賴指紋見[版本](../../research/active/swd3works-publisher-repair/evidence/m0-20260906/README.md#版本)。

**0.2.0 原型** 已加入一般自有作品的版本更新入口，並以私人項目實測新建、連續升版、標題／說明與預設語言同步，以及自動下載檔名／hash／內嵌版本驗證。現行 **0.3.0 桌面版** 再完成發佈維護介面、草稿綁定與紀錄恢復，私人更新／新建／重啟查詢已實測；[桌面驗收](../../research/active/swd3works-publisher-repair/evidence/desktop-20260906/README.md)保留本次環境限制。正式公開作品沒有修改；完整故障矩陣仍未全部驗收。操作及副作用統一見[桌面工具入口](tools-and-commands.md#mod-studio-桌面版-030)，0.2.0 證據見[案例](../../research/active/swd3works-publisher-repair/evidence/releases-20260906/README.md#案例)。這不是跨版本、不同帳號或任意SDK配對的保證。

**已實測，0.2.0 開發建置與上述Steam環境：** Submit 回報失敗時，文字可能已改、內容包仍是舊版；更新單一中文欄位也可能留下English預設欄位的舊標題。因此，失敗後必須先查回目前文字與實際檔案，不能假設自動回滾；成功驗證須涵蓋此次承諾同步的語言。可重現案例與首次失敗條件見[失敗與語言差異發現](../../research/active/swd3works-publisher-repair/evidence/releases-20260906/README.md#失敗與語言差異發現)。工具的下載驗證不取代正式MOD的遊戲實機驗收。

## 說明頁最低內容

- MOD 做什麼與明確不做什麼。
- 預設值、調整範圍與操作方式。
- 支援遊戲版本。
- 是否保存設定、寫入存檔或綁定存檔。
- 與原版及其他 MOD 的相容性限制。
- 安裝或更新後需要完整重啟。
- 已知限制與安全停用條件。
- 驗證生效的方法與預期 Console 訊息。

標題、BBCode、更新說明、預覽圖與版本 manifest 屬特定發行素材，留在各專案的發布目錄，不複製到通用知識庫。
