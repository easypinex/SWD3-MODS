# 專案結構與 Metadata

## 適用範圍

- 遊戲：《軒轅劍參：雲和山的彼端》Steam 高清版。
- 已實測執行檔：`swd3.exe 4.0.5`；目前專案只承諾 4.0.x。
- 本文件說明 SWD3 遊戲 MOD，不是 Codex plugin。

## 三種專案型態

| 型態 | 用途 | 最低文件責任 |
| --- | --- | --- |
| 正式 MOD | 提供可持續使用的遊戲功能 | README、來源、測試、可反解的 `.ssmod` 成品 |
| 研究探針 | 隔離驗證一個引擎假設 | README、最小來源、觸發與停止方法、研究結果 |
| 資源圖庫 | 保存可重建的素材與索引 | README、來源說明、重建腳本、數量／映射驗收 |

探針不得混入正式功能；圖庫不得直接替換遊戲核心資源。研究完成後，僅把可重現且通用的結論提升到知識庫。

## 工作區資料位置

**專案決策。** 正式 MOD 與圖庫留在工作區根目錄；新研究建在 `research/active/<project-name>/`，已完成／被取代的研究移至 `research/archive/`。研究來源、測試與版本證據保持成套；分類與未解問題只在[研究清冊](../../research/README.md)維護。

本機建置／反解採 `.work/` 或專案既有產物目錄。原版解包與工具快取可重建；唯一的實驗紀錄、原創素材及腳本不得因歸檔而丟棄。文件整理與證據提升入口仍是根 AGENTS。

## 正式 MOD 建議結構

```text
<project-root>/
├─ src/
│  ├─ <mod-name>.ext
│  └─ data/
│     ├─ Main.lua
│     └─ Strings.txt       # 只有新增文字時需要
├─ dist/
│  └─ <mod-name>.ssmod
├─ tests/                  # 有自動測試時
├─ README.md
└─ TESTING.md              # 實機矩陣較長時
```

`.ext` 放在 `src` 根目錄；Lua、文字及 `DAT` 宣告的其他資源放在 `src/data`。已實測：Lua 錯放在 `src` 根目錄時，工具可能仍回傳成功或產生小型封包，但封包不含腳本。

`dist`、`verify-*`、`out_data` 是產物或反解資料，不是編輯來源。

## Metadata 基本欄位

現有專案共同使用：

```text
MODName 顯示名稱
MODAuthor 作者
MODDate 2026,9,3
MODVersion 0,1
MODinfo 簡介%Q
MODGameVersion 4,0
MODsystemMOD 0
MODbundleSave 1
```

`MODName`、檔名基底與發行檔名各有不同責任；其中封裝時的 `-I` 必須等於來源 `.ext` 的檔名基底（不含 `.ext`），詳見 [封裝與安裝](packaging-and-installation.md)。

`MODbundleSave` 的值會影響存檔關係；選值與實機驗收規則統一見 [狀態保存與資料安全](state-persistence-and-safety.md)。

### 已知欄位語意與未知邊界

- **官方檔內說明**：原版 HD manifest 註解將 `MODsystemMOD 0` 標為非系統用、`1` 標為系統用；一般正式 MOD 使用 `0`，不要未經研究改成 `1`。
- **官方檔內說明**：`MODbundleSave 0` 記錄在 Save、`1` 不綁 Save、`2` 使 Save 永久要求 MOD。行為仍要依本文件與狀態文件的矩陣實測。
- **已觀察、待驗證**：`MODpicture` 出現在原版 HD 圖形 manifest，但現有研究尚未確認自訂 MOD 的完整行為；不可把它當作可安全註冊自訂圖示的已支援功能。
- **已觀察、待驗證**：`MODinfo` 現有 manifest 以 `%Q` 結尾；保留這個既有格式，但不宣稱已完成所有轉義或換行語意的研究。

## `DAT` 資源宣告

遊戲範例與現有專案使用的資料類型：

| TYPE | 資源 |
| ---: | --- |
| 0 | txt／StringDB 文字表 |
| 1 | ext |
| 2 | script／Lua |
| 3 | PNG |
| 4 | font |
| `>100` | 壓縮資料 |

格式：

```text
; Datas: TYPE, LangID, FileName, Comment
DAT 2,0,Main.lua,Main script
```

每一列都必須對應 `src/data` 中的真實檔案。新增中文時另讀 [在地化與文字](localization-and-strings.md)；圖片並不因為能以 `DAT 3` 封裝就必然能由公開 Lua API 直接繪製，另讀 [圖片與 TSW 資產](graphics-and-tsw-assets.md)。

多個 `DAT 2` 的順序應視為**專案載入契約**：依賴其他 Lua 建立的 namespace／規則檔，先宣告依賴檔，再宣告整合檔，並在整合檔以明確 assertion 檢查。現有活物挑戰採此方式。此順序在該專案封包與實機版本可用，但尚未以獨立探針證明為全引擎保證。

## 命名與邊界

- 資料表 key、全域表、`SaveData` 與 `Setting` 欄位使用 MOD 專屬前綴。
- 一個正式 MOD 使用一個清楚、穩定的 `.ext`／`.ssmod` basename。
- 測試腳本、反解原版資料、暫存檔、私人路徑與封面來源不得放入 `src`。
- 正式發布優先使用單一 `.ssmod`；工作坊內容邊界見 [Steam 工作坊發布](steam-workshop-release.md)。
