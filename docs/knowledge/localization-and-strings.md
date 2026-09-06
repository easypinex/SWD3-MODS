# 在地化與文字

## 新增中文的可靠流程

已實測：把新的中文字直接寫入 Lua，再交給 `StringFunc.DrawString`，可能只留下遊戲資料庫原有名稱、數字或 ASCII。新增 UI 中文應使用 UTF-8 `TYPE 0` 文字表。

文字表：

```text
ABC_TITLE 功能標題
ABC_MATERIALS 投入材料：
```

`.ext`：

```text
DAT 0,0,Strings.txt,Traditional Chinese UI strings
DAT 2,0,Main.lua,Main script
```

Lua：

```lua
local title = StringDB('ABC_TITLE')
StringFunc.DrawString(title, x, y, 0, color, shadow, 1)
```

## 規則

- 每個 key 使用 MOD 專屬前綴，避免與原版或其他 MOD 衝突。
- 文字檔保持 UTF-8；不要以反解副本取代 `src/data` 來源。
- 動態物品或角色名稱可與 `StringDB` 取得的固定標籤串接。
- 為每個重要訊息準備完整、可理解的 ASCII fallback。
- fallback 的目的不是遮掩封裝失敗；Console 仍應記錄文字表載入異常。

## 原版多語文字槽基線

狀態：**已實測解包＋官方檔內說明**。Steam HD 4.0.5 的已驗證 `script_index.ssmod` 經 `SS2Dtool x` 解包後，四個重複文字表依目前 archive 順序落在：

| 輸出目錄 | 已辨識語言 | 重複檔案 |
| --- | --- | --- |
| `out_data` | 繁體中文 | `BattleScriptString.txt`、`ItemString.txt`、`name.txt`、`Scene.txt` |
| `out_data_1` | 簡體中文 | 同上 |
| `out_data_2` | 英文 | 同上 |
| `out_data_3` | 日文 | 同上 |

這個對照只適用於[引擎研究流程](engine-research-workflow.md)記錄的 4.0.5 archive 雜湊。後綴是工具為重名輸出建立的目錄，不是語言 ID；其他版本或封包必須以實際文字重新辨識。

四語檔案均已確認為 UTF-8，但 BOM 與 key 集不完全一致。因此不要用 BOM 判斷語言或完整性；多語處理應依 key 做集合比對，不能假設行號或總行數完全相同。自訂 MOD 仍只維護自己的文字表與前綴，不複製原版整份文字表。

## 驗證

1. 靜態檢查所有 key 無重複、無漏列，Lua 引用能在文字表找到。
2. 封裝後反向解包，確認 `.txt` 存在且與來源 SHA-256 相同。
3. 在遊戲中確認新增中文完整顯示，不只檢查原版物品名稱。
4. 模擬或實測文字表不可用時，確認 ASCII fallback 仍提供完整資訊。
5. 在目標語言、解析度與相關選單中檢查截斷、重疊和字型清晰度。

專案對外 README 可以說明採用 `StringDB` 與 fallback，但通用操作與範例只維護在本文件。
