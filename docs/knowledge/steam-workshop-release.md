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

1. 使用 `<game-root>\SWD3Works.exe` 建立或選擇正確項目。
2. 內容資料夾指向只含 `.ssmod` 的 `workshop_content`。
3. 填入標題、說明、預覽圖、版本和相容性資訊。
4. 第一次或重大更新先設為私人或僅限好友。
5. 上傳後取消訂閱再重新訂閱，檢查 Steam 實際下載內容。
6. 確認 `steamapps/workshop/content/1638230/<WorkshopItemID>` 只有預期成品。
7. 在 MOD 管理停用再啟用，清除可能殘留的舊 `.ext` 清單。
8. 完全關閉並重開遊戲，以訂閱下載版重新做 Console 與實機驗收。
9. 全部通過後才改為公開。

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
