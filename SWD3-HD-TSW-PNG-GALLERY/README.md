# SWD3 Steam HD 內建 TSW PNG 圖庫

這份圖庫從目前安裝遊戲的 `tsw_index.ssmod` 解出，與 `SWD3-TSW-PNG-GALLERY` 的 `swd3DVD\all_*.tsw` 來源圖庫分開保存。它用於查看 Steam HD 版實際內建的 TSW 圖像，且已還原 HD 的 `DrawTSW(ID, SN)` 對照。

PNG、PIC、TSW 與兩種圖庫的通用邊界見 [圖片與 TSW 資產](../docs/knowledge/graphics-and-tsw-assets.md)，各腳本參數見[工具與命令參考](../docs/knowledge/tools-and-commands.md)。本文件只保存本圖庫內容與可重跑流程。

## 內容

- `hd_tsw_png\`：20,554 張從 HD `tsw_index.ssmod` 解出的 PNG 預覽圖。已改為 `HD-TSW10007-SN00__BattleInfoBG.png` 形式，可直接按 ID 搜尋。
- `tsw_index_hd.ext`：從 HD 封包內第一個 Zstandard frame 還原出的完整 TSW manifest，含 20,991 條 `TSW ID,SN,TYPE,LangID,FileName,Comment` 列。
- `hd_tsw_mapping.csv`：一列一筆的正式 HD `ID/SN → 圖檔` 對照，可用試算表查詢所有語言與類型。
- `hd_tsw_png_index.csv`：每張預覽圖一筆的索引；多個 ID/SN 共用同張圖時以 `TswBindings` 合併記錄。
- `hd_tsw_known_references.csv`：本 MOD 已實機驗證的用途對照；目前包含不透明的 `9385/0` 和半透明藍色的 `10007/0`。

`hd_tsw_png\` 是可重建的大型本機產物，已由根目錄 `.gitignore` 排除；腳本、manifest 與 CSV 索引仍由 Git 保存。

## 使用方式

1. 在檔案總管以大圖示開啟 `hd_tsw_png` 瀏覽 HD 圖片；搜尋 `TSW10007` 可直接找到藍色說明底圖。
2. 以 `hd_tsw_mapping.csv` 查詢任何已封裝的 HD `DrawTSW(ID,SN)` 對照。
3. 以 `hd_tsw_known_references.csv` 查詢本 MOD 已實機驗證的用途與視覺結論。

## 從全新 clone 重建圖庫

以下流程只讀取目前 HD 遊戲檔，所有輸出均放入工作資料夾與本圖庫。**不要**在遊戲安裝目錄直接解包或封裝。`hd_tsw_png` 必須不存在或為空；腳本會拒絕覆寫已有圖庫。

```powershell
$game = 'D:\SteamLibrary\steamapps\common\SWD3'
$tool = "$game\Tools\SS2Dtool.exe"
$work = 'D:\Temp\swd3-hd-tsw-work'
$gallery = 'D:\workspace\SWD3-MODS\SWD3-HD-TSW-PNG-GALLERY'

New-Item -ItemType Directory -Force -Path $work | Out-Null
Copy-Item "$game\tsw_index.ssmod" "$work\tsw_index.ssmod" -Force
& $tool x "-i$work" '-Itsw_index'       # 產生 $work\out_tsw

& "$gallery\Convert-HdPicToPng.ps1" `
  -ToolPath $tool `
  -ExtractedPicRoot "$work\out_tsw" `
  -OutputRoot "$work\converted_png"
& "$gallery\Build-HdGallery.ps1" `
  -ExtractedPngRoot "$work\out_tsw" `
  -ConvertedPngRoot "$work\converted_png"

python -m pip install -r "$gallery\requirements.txt"
python "$gallery\Extract-HdTswManifest.py" "$game\tsw_index.ssmod"
```

成功驗收：`hd_tsw_mapping.csv` 有 20,991 條 manifest 列、`hd_tsw_png` 有 20,554 張 PNG，且搜尋 `TSW10007` 可找到 `BattleInfoBG.png`。

若遊戲不在範例路徑，只要修改 `$game`；各腳本不再含作者電腦的固定工具或暫存路徑。`requirements.txt`、重建腳本、索引與研究證據都會隨 clone 取得，遊戲的 `tsw_index.ssmod` 則必須來自使用者自己的安裝。

## 已知工具限制與安全界線

| 項目 | 已知行為 | 正確作法 |
| --- | --- | --- |
| `SS2Dtool x` | 能解出 HD 圖檔，但不輸出 `tsw_index.ext`。 | 以 `Extract-HdTswManifest.py` 解壓第一個 Zstandard frame。 |
| `SS2Dtool pg` | 一次轉一張 PIC；`-I` 必須是來源 `.pic` 的完整檔名，否則工具仍可能回傳 0 卻產生空檔或不產生檔案。 | 使用 `Convert-HdPicToPng.ps1` 批次處理，並以張數驗收。 |
| 一般 MOD 封裝 | 不屬於本圖庫流程。 | 見[封裝與安裝](../docs/knowledge/packaging-and-installation.md)。 |
| HD manifest 還原 | 已確認目前 Steam HD `tsw_index.ssmod` 的第一個 Zstandard frame 是 manifest；不保證其他 SSMOD 類型也使用同一結構。 | 對不同封包先驗證解壓結果以 `MODName ` 開頭。 |
| 圖檔完整性 | `x` 未輸出 `TSW 9094/SN0..8` 的 9 張 `MenuFrame1`。 | 保留為缺口，不以舊版或相似圖片補造。 |
| 自訂 TSW 圖片 | 一般 MOD 的增量自訂圖片登錄仍未完成驗證；全量 TSW 重建包作為額外 MOD 會使遊戲無畫面／無回應。 | 不發布依賴自訂 TSW 的一般 MOD；未經明確授權，不替換遊戲的 `tsw_index.ssmod`。 |
| 透明 PIC | `gpa`／`pga` 是深色轉透明色鍵，非保真 RGBA alpha 流程。 | 先以測試圖回轉驗收，深色 UI 預設避免使用。 |

## 範圍與限制

本圖庫涵蓋 `tsw_index.ssmod` 的 HD TSW 圖像：20,194 張原為 `.pic`、經官方工具轉出；360 張原本即為 PNG。20,554 張預覽圖皆能對應至 manifest；manifest 另列出 9 個未被 `x` 解出的圖檔。地圖、影片、模型等其他圖形資源可能位於不同資源包，並不包含在此處。

`SS2Dtool x` 只會輸出圖檔，卻不會自動寫出 `.ext`。實測發現 `tsw_index.ssmod` 的第一個 Zstandard frame 正是完整 TSW manifest；以 `Extract-HdTswManifest.py` 還原後即可建立正確對照。此腳本只讀取遊戲封包、重新命名圖庫副本與輸出 CSV／EXT，不會修改遊戲檔。執行前依 `requirements.txt` 安裝 `zstandard`。
