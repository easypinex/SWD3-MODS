# 圖片與 TSW 資產

## 三種資源層級

| 層級 | 格式／宣告 | 已知用途與限制 |
| --- | --- | --- |
| 一般 PNG | `DAT 3` | 封包可攜帶 PNG，不代表公開 Lua API 能直接繪製。 |
| TSW 圖片 | `.pic`、`TSW ID,SN,...` | `DrawFunc.DrawTSW` 使用；PIC 檔頭為 `tswp`，不能直接改副檔名。 |
| 字型 | `FONT` | 獨立管線，不可和 PNG 或 TSW 宣告混用。 |

TSW 慣例檔名為 `tsw%05d_%02d.pic`。索引欄位：

```text
TSW ID,SN,TYPE,LangID,FileName,Comment
```

官方工具註解的 TYPE 包含 1 char、2 item、3 effect、4 system、5 map1、6 map2、8 HGA；`LangID 0` 為 default、`1` 為 chs。

## PNG 與 PIC 轉檔

`gp/gp2/gpa/pg/pg2/pga` 的完整參數、範例與工具內建說明見[工具與命令參考的圖片轉檔小節](tools-and-commands.md)。退出碼 0 不代表讀到正確檔案，仍必須檢查輸出、尺寸、透明區與視覺結果。

已驗證格式差異：

- 24 位 RGB：`gp` 後可用 `pg` 回轉，但有 16 位量化。
- 32 位 ARGB：不要用預設 `gp`；既有探針出現錯色。
- 不需要透明的 32 位來源可評估 `gp2`，回轉會變為不透明。
- `gpa`／`pga` 是深色轉透明的色鍵流程，不是保真 RGBA alpha；深色 UI 不得直接套用。

原始 PNG 是唯一可編輯來源，`.pic` 是建置產物。新素材先用獨立像素測試圖做回轉驗證。

## 來源圖庫與 HD 圖庫

- `SWD3-TSW-PNG-GALLERY` 來自 `swd3DVD/all_*.tsw`，是來源索引，不是 Steam HD 的正式 `DrawTSW` ID 對照。
- `SWD3-HD-TSW-PNG-GALLERY` 來自目前 HD `tsw_index.ssmod`。研究已從第一個 Zstandard frame 還原 manifest，建立正式 HD `ID/SN → 圖檔` 映射。
- 圖片外觀或相同編號不能證明兩個圖庫的 ID 對應。資料應分別記錄來源 ID/SN、HD ID/SN、Verification 與 Evidence。
- 實際用途與透明效果仍應另外標示 `game_verified`；manifest 映射只證明資源綁定。

完整重建流程、數量與已知缺口保留在兩個圖庫 README 及 `SSMOD-FORMAT-RESEARCH.md`；各圖庫腳本參數集中在[工具與命令參考](tools-and-commands.md)。

## 自訂 TSW 的安全界線

### 既有 TSW 的增量 ACT 宣告

**已實測（使用者人工回報＋部分 Console），Steam HD4.0.5，2026-09-06。** 獨立 `.ssmod` 透過 `DAT 1` 載入小型 ACT `.ext`、引用既有 HD TSW，可以補入原版未宣告的 ACT；蔡魔王探針 v0.2 已確認進場、普攻、受擊、勝利返回，重複挑戰另有使用者通過回報。封包、exe 指紋、來源、建置與逐項證據見[此案例](../../research/active/swd3-cai-act-probe/README.md#v02-人工結果2026-09-06)。

這是「新增動作宣告、沿用既有圖片」的有限成功例，不是新 TSW 登錄成功，也不證明 Lua `ACTData` 路線可用。其他 ACT／QQ、施法、卡片、護駕、全滅或任意載入順序仍需個別驗證；只引用已確認存在的圖片並不免除動作驗收。

### 新 TSW 登錄

**已實測**：官方工具能把 PNG 轉成 PIC，也能建立包含自訂列的資源封包。

**尚未完成驗證**：一般增量 Lua MOD 如何安全登錄新的 TSW ID。既有最小封包即使先載入，`DrawTSW(20001, 0, ...)` 仍未顯示；把帶檔名的 `MODpicture` 放進主 Lua 包還使文字表失效。這只否決已測封包形式，不代表引擎永遠不支援自訂 PIC。

在增量登錄流程完成實機驗證前：

- 正式 MOD 只繪製 HD manifest 中已存在的 TSW ID/SN。
- 不發布依賴自訂 TSW ID 的功能。
- 不用相似原版圖片冒充自訂素材。
- 未經明確授權，不替換遊戲的 `tsw_index.ssmod`；全量資源重建包也不得作為一般額外 MOD 發布。

活物挑戰的失敗方案與探針證據保留在 `swd3-live-card-battle-mod/IMAGE-ASSET-GUIDE.md`。

## 戰鬥跳字與實際數值

**已靜態反解，Steam HD4.0.5.0，2026-09-08。** `FUN_1400851b0`以千、百、十、個四個欄位拆解戰鬥數字，千位未對10取模；例如12000得到[12,0,0,0]。`FUN_140083170`將四欄按固定12像素間距交由可繪製多位整數的`FUN_14003be20`處理。五位數可能使首欄跨入下一欄，不應從跳字異常推定HP數值也被截短。這不是宣稱所有傷害／回血都無上限，實際數值仍由各結算路徑決定。

精確exe／腳本指紋與報告定位見[跳字證據](../../swd3-cai-demon-king-mod/evidence/v15-healing/README.md#靜態證據)。該案例使用者只回報畫面1000，未量測HP差額；兩段顯示方案是專案決策且仍待實機，不提升為通用的多段回血保證。
