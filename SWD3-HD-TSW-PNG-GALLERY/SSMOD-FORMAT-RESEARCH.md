# Steam HD `tsw_index.ssmod` 格式研究紀錄

更新：2026-09-03。此文件只記錄唯讀分析結果；不主張或執行遊戲核心資源替換。

可供一般 MOD 使用的圖片／TSW 規則摘要見 [圖片與 TSW 資產](../docs/knowledge/graphics-and-tsw-assets.md)；本文件是可重跑的格式研究證據。

## 結論

Steam HD 的 `tsw_index.ssmod` 並非沒有 TSW 索引。完整 `tsw_index.ext` manifest 被放在封包中的第一個 Zstandard 壓縮 frame；官方 `SS2Dtool x` 會輸出素材，卻不會把該 manifest 寫成 `.ext`。

因此 HD 的 `DrawTSW(ID, SN)` 對照可由封包內資料完整還原，而不是靠圖檔名稱或視覺猜測。例如：

| ID/SN | manifest 圖檔 | 預覽 PNG | 已知用途 |
| --- | --- | --- | --- |
| `9385/0` | `MenuWallPaper_BG_item.png` | `HD-TSW09385-SN00__MenuWallPaper_BG_item.png` | 物品頁不透明背景 |
| `10007/0` | `BattleInfoBG.png` | `HD-TSW10007-SN00__BattleInfoBG.png` | 戰鬥說明用半透明藍色底圖 |

## 已驗證的封包觀察

- HD 檔：`D:\SteamLibrary\steamapps\common\SWD3\tsw_index.ssmod`
- 檔頭 magic：ASCII `SMOD`
- 格式版本：little-endian `4`
- 檔頭／資料區可找到 Zstandard magic：`28 B5 2F FD`
- 第一個 frame 位於位移 `0xFF`；解壓後為 UTF-8 BOM 的 `tsw_index.ext` 內容。
- 解壓 manifest 大小：739,660 bytes，包含 20,991 條 `TSW` 列。
- `SS2Dtool.exe` 內嵌 Zstandard 函式，並可由 `x` 讀取此格式；但其 `x` 命令不把 manifest 回寫為 `.ext`。

## 可重跑的安全還原流程

圖庫資料夾中的 `Extract-HdTswManifest.py`：

1. 唯讀載入遊戲的 `tsw_index.ssmod`。
2. 找到第一個 Zstandard frame 並解壓。
3. 驗證內容以 `MODName ` 開頭、包含 TSW 列。
4. 寫出 `tsw_index_hd.ext`、`hd_tsw_mapping.csv`。
5. 僅重新命名 `hd_tsw_png` 圖庫副本為 `HD-TSWxxxxx-SNyy__原始檔名.png`。

需要 Python 套件：`zstandard==0.25.0`（見 `requirements.txt`）。這個腳本不會寫入遊戲安裝目錄，也不會建立或替換 `.ssmod`。

### 官方工具參數的已驗證規則

- `x`：輸入資料夾內必須有 `<basename>.ssmod`，例如 `SS2Dtool x "-iD:\Temp\work" "-Itsw_index"`。輸出會建立在該工作資料夾下的 `out_tsw`，不會產生 `.ext`。
- `pg`：`-i`／`-o` 是資料夾，`-I`／`-O` 是完整檔名且含副檔名。例如 `-Itsw00001_00.pic` 與 `-Otsw00001_00.png`。單張轉檔不能省略 `-I`。
- `p`：`-I` 是要讀取的來源 `.ext` 檔名去副檔名，**不是**任意輸出名稱；這點即使工具回傳 0 也必須以產物是否存在驗證。
- `te[p]`：適用於 `swd3DVD\all_*.tsw` 的舊版原始資源，可直接輸出舊版 `tsw_index.ext`；它不是 HD `.ssmod` manifest 的擷取方式。

## 素材統計與限制

- `SS2Dtool x` 解出的素材：20,194 個 PIC、360 個原生 PNG。
- 以官方 `pg` 將 PIC 逐張轉成 PNG 後：20,554 個可瀏覽 PNG。
- 這 20,554 張都可對應至 manifest。
- manifest 還含 9 條未被 `x` 輸出的 `MenuFrame1`：`TSW 9094/SN0..8`、`tsw09094_00.pic` 至 `tsw09094_08.pic`。目前不以其他版本資源補造，避免錯把非 HD 圖像標為 HD。
- 部分檔案被多個 ID/SN 共用，詳見 `hd_tsw_mapping.csv`；PNG 檔名會列出所有綁定，例如 `HD-TSW09264-SN03__TSW09369-SN05__ItemTab6.png`。

## 後續研究方向

若要使官方工具也直接輸出 `.ext`，需逆向或替換其 `func_extra_ssmod` 的輸出行為；這是工具功能研究，不需要改動遊戲。現階段 Python 還原器已能以封包內原始 manifest 產出完整且可驗證的對照，因此不需要以螢幕掃描推測 ID/SN。
