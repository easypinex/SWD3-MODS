# SWD3 原版 TSW PNG 圖庫

> 這是由 `swd3DVD\all_*.tsw` 解出的「來源圖庫」，不是 Steam HD 版內建 `tsw_index.ssmod` 的已驗證 ID 對照表。

此資料夾由遊戲隨附的 `SS2Dtool.exe tep` 直接輸出，沒有修改遊戲檔案。

來源圖庫與 HD 圖庫的通用區分、PIC／TSW 規格及安全界線見 [圖片與 TSW 資產](../docs/knowledge/graphics-and-tsw-assets.md)，`te[p]` 與重新命名腳本的已知參數見[工具與命令參考](../docs/knowledge/tools-and-commands.md)。本文件只說明本圖庫的瀏覽、檔名與統計。

## 瀏覽

1. 在檔案總管開啟 `tsw_png`。
2. 切換為「超大圖示」或「大圖示」，即可大量瀏覽 20,091 張 PNG。
3. 用 `tsw_png_index.csv` 搜尋來源 TSW ID、TYPE、SN、檔名或原版註解。

PNG 保留透明像素與原始索引命名；不要改成 JPG，否則透明邊緣與像素圖會受損。

## 檔案對照

- `tsw_index.ext`：工具正式產生的 TSW 索引。
- `tsw_png_index.csv`：便於試算表／文字搜尋的索引；`PngExists` 已驗證為 true。

`tsw\`、`tsw_png\` 與可選的 `all_*.tsw` 本機副本都是可重建的大型產物，已由根目錄 `.gitignore` 排除；README、重建腳本、manifest 與 CSV 索引仍由 Git 保存。

## PNG 預覽檔名

PNG 可以自由改名，不會影響 `.pic`、`tsw_index.ext`、轉檔或遊戲。本圖庫預覽圖使用：

```text
SRC-TSW00001-SN00__char__543-l.png
```

- `SRC`：明確表示這是 `swd3DVD` 來源編號。
- `TSW00001-SN00`：來源索引的 `ID/SN`。
- `char`：來源圖片類型。
- 最後一段是原索引註解；若無註解則省略。

這種命名方便在檔案總管搜尋，卻不會誤稱為 HD 版的實際 `DrawTSW` 編號。若之後實機驗證 HD 編號，請在 CSV 新增 `HdTswId`、`HdSN`、`Verification`、`Evidence` 欄位；只有 `Verification=verified` 的資料才可將 `HD-TSWxxxxx-SNyy` 加入 PNG 檔名。
- `tsw`：原始 PIC。
- `tsw_png`：可直接瀏覽的 PNG。
- `all_*.tsw`：若存在，是早期由遊戲 `swd3DVD` 複製的本機來源副本；重建腳本直接讀取遊戲安裝內容，不需要複製或提交這些封包。

## 從全新 clone 重建圖庫

前提是本機已安裝 Steam HD 版遊戲，並使用其隨附的 `Tools\SS2Dtool.exe` 與 `swd3DVD\all_*.tsw`。在工作區根目錄執行：

```powershell
& '.\SWD3-TSW-PNG-GALLERY\Rebuild-SourceGallery.ps1' `
  -GameRoot 'D:\SteamLibrary\steamapps\common\SWD3'
```

腳本會先確認六個 `all_*.tsw` 都存在，建立工具要求的 `tsw`／`tsw_png` 輸出目錄，再執行：

```powershell
& '<game-root>\Tools\SS2Dtool.exe' tep `
  '-i<game-root>\swd3DVD' `
  '-o<gallery-root>'
```

之後腳本依工具產生的 `tsw_index.ext` 建立 `tsw_png_index.csv`，並呼叫 `Rename-PngPreviews.ps1` 套用 `SRC-TSWxxxxx-SNyy` 檔名。指定輸出目錄時，`SS2Dtool tep` 不會替你建立 `tsw` 與 `tsw_png`；若漏掉這一步，工具可能仍快速結束、只產生沒有 TSW 列的空索引。重建腳本已處理並驗證此陷阱。

目前 Steam HD 4.0.x 的成功驗收結果是：20,091 個 PIC、20,091 個 PNG、20,091 條 manifest／CSV 索引列，且 CSV 全部 `PngExists=True`。腳本要求三組數量相等且大於零，不會只依工具退出碼判定成功；輸出目錄已有內容時也會停止，避免覆寫現有圖庫。

## TYPE 統計

| TYPE | 張數 |
| --- | ---: |
| char | 8,519 |
| item | 458 |
| effect | 9,795 |
| system | 973 |
| map1 | 207 |
| map2 | 139 |

對 UI 背景與按鈕，優先在 `TypeName=system` 的列篩選；PNG 檔名可由 `PicFile` 將 `.pic` 改為 `.png` 取得。
