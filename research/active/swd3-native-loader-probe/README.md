# SWD3 原生 MOD 載入與 SWD3Works 靜態研究

> 研究來源：本頁保存所列版本的操作與證據。是否重用、知識去向及未解問題，先查[研究清冊](../../README.md)；通用能力依[知識庫](../../../docs/knowledge/README.md)，不因歸檔或 mock 通過擴張為正式支援。

本專案以唯讀方式盤點 Steam HD 4.0.5 的兩個不同責任邊界：

- `swd3.exe` 的本機／工作坊 MOD 清單、`.ssmod`、metadata 與 requirement 載入流程。
- `SWD3Works.exe` 的受管 Steam 工作坊上傳／訂閱管理能力。

它不是可安裝的 MOD，不建立 `.ssmod`，不會啟動遊戲、不連線 Steam、不呼叫 Steam API，也不讀寫遊戲安裝目錄中的檔案。分析腳本會先複製目標與必要受管相依檔到 `native-analysis/input/`，再只對副本執行靜態盤點。`native-analysis/` 是本機產物，不是版本控制的編輯來源。

## 研究問題

1. 遊戲端從何處讀取本機／工作坊 MOD 清單，並以哪些檔名／副檔名分流？
2. `.ssmod` 載入前會檢查哪些 manifest metadata 與相依條件？
3. `SWD3Works.exe` 是否直接載入或控制遊戲內 MOD，還是只管理 Steam UGC？
4. 上述能力是否形成可由一般 `.ssmod` 呼叫的公開 Lua API？

## 已靜態反解：Steam HD 4.0.5（2026-09-05）

目標版本：

| 檔案 | 檔案版本 | SHA-256 |
| --- | --- | --- |
| `swd3.exe` | `4.0.5.0` | `63F1D83D8C3A756D17640D9022E19F8928741B091F0E47ABBDB22C0CCF6C9523` |
| `SWD3Works.exe` | `1.0.0.1` | `756D9E2F9866EC335F8A536B9ED0DE2869BBE83FF3D5BF468E0F8A2E3C0330FA` |

### Workshop、本機清單與 `.ssmod`（已靜態反解）

1. `swd3.exe` 的 `0x1400efec0` 先透過 Steam UGC 介面取得訂閱項目 ID，再讀取遊戲根目錄的 `SteamMods.txt`。檔案內的 `+/-<WorkshopItemID>=<MOD file>` 會對應實際訂閱項目；符合的項目才進入 `0x1400fad20`。
2. `0x1400fad20` 只接受副檔名（不分大小寫）為 `.ssmod` 的項目，建立 MOD 記錄並依其啟用狀態處理。它不呼叫 Windows 模組載入 API。
3. 本機路徑由 `0x1400fbbc0` 讀取 `<game-root>\\Mods\\modlist.txt`，由 `0x1400fad20` 套用檔案與啟用／停用狀態；工作坊與本機條目後續共用 requirement gate `0x1400f5e00`。
4. manifest parser `0x1400f78c0` 讀取 `MODName`、`MODAuthor`、`MODinfo`、`MODpicture`、`MODsystemMOD`、`MODbundleSave`、`MODDate`、`MODVersion`、`MODGameVersion`、`MODrequirement`、`MODelimination` 及 `DAT`。`.ssmod` reader `0x1400f97d0` 驗證 `SSMOD` header、遊戲版本，然後載入 archive 內容；它不以 `.dll`／plugin 名稱分流，也沒有 `LoadLibrary*`／`GetProcAddress` direct call。

### DLL／native module 路徑（已靜態反解）

`swd3.exe` 的 PE import table 確有三個相關入口：`KERNEL32.dll!LoadLibraryExA`、`LoadLibraryW`、`GetProcAddress`。它們不能被誤寫為「不存在」：

| API | direct caller | 作用 | 與 MOD loader 的關係 |
| --- | --- | --- | --- |
| `LoadLibraryExA` + `GetProcAddress` | `0x140028a40` | 編入的 Lua C-module helper；由 `0x140028bc0`（`package.loadlib` 實作）與 `0x140029740`（依 `luaopen_<name>` 的 C module searcher）呼叫。 | 沒有對 `SteamMods.txt`／`modlist.txt`／`.ssmod` parser 的 direct caller overlap。 |
| `LoadLibraryW` + `GetProcAddress` | `0x14009f210` | 只載入 `KERNEL32` 取得 `GetDiskFreeSpaceExA`，隨即 `FreeLibrary`。 | 與 MOD loader 無關。 |
| `GetProcAddress` | `0x14016a0c4` | CRT 初始化取得 condition-variable helpers。 | 與 MOD loader 無關。 |

`0x140028a40` 的資料表與 callers 證明 Lua VM **編入** `package.loadlib`／C-module searcher；這是未列於官方 MOD 文件的 native module 載入候選，而非已驗證的官方 plugin API。它只有在下列條件都成立時，才可能由 MOD 間接使用：MOD runtime 真的保留 `package.loadlib` 或相應 `require` searcher、DLL 位元檔存在於該 API 可解析的實體路徑、架構與入口名稱相符、以及 Steam／遊戲政策容許。這次靜態分析沒有驗證其中任一 runtime 條件，也不會嘗試載入 DLL。

`SWD3Works.exe` 是獨立的 .NET Framework 4.8 WinForms 工具，metadata 參照 `Steamworks.NET 20.2.0.0`，含 `SteamWorkshopManager.CreateItem`、`UpdateItem`、`QueryInstalledWorkshopItems`、`GetItemInstallInfo`、`GetItemDownloadInfo`、`CreateFromWorkshopItem` 等成員。它管理 Steam UGC 項目，沒有和 `swd3.exe` 共用的 in-process plugin ABI、`LoadLibrary` 呼叫點或 MOD 熱載入 IPC 證據。

## 重跑方法

可在遊戲未執行時重跑；若遊戲正在執行，腳本不會干擾它，但會對每個來源檔案做「複製前、複製後、隔離副本」三次 SHA-256 比對，任何不一致都會停止並拒絕產生報告。在工作區根目錄執行：

```powershell
& .\research\active\swd3-native-loader-probe\scripts\Invoke-LoaderStaticAnalysis.ps1 `
  -GameRoot 'D:\SteamLibrary\steamapps\common\SWD3'
```

腳本會：

1. 驗證檔案版本與 SHA-256，複製 `swd3.exe`、`SWD3Works.exe`、`Steamworks.NET.dll` 到隔離目錄。
2. 用 Reflection-only metadata 盤點 `SWD3Works.exe` 的 type、method、field、assembly reference 與包含 Workshop／UGC／item／update 的名稱。
3. 用 Ghidra 對 `swd3.exe` 副本執行完整一次分析，接著以唯讀報告腳本列出 loader 關鍵字、`.ssmod` control flow 與 Windows module API 的 data references、caller 與反編譯摘要。
4. 將版本、工具版本、輸入雜湊與報告寫到 `native-analysis/reports/`。

首次完整 Ghidra 分析通常需要數分鐘；之後可保留同一個本機 analysis database，以 `-noanalysis` 重跑報告。不得將任何位址外推到不同的檔案 SHA-256。

## 安全邊界與目前結論

- **已靜態反解（限上述 SHA-256）**：遊戲本體含有 Steam／本機 MOD list、`.ssmod` header／manifest loader、版本／requirement gate；SWD3Works 是獨立的 Workshop 管理工具。這條官方 loader chain 沒有直達 Windows module API 的 caller 邊。
- **已靜態反解（限上述 SHA-256）**：Lua VM 編入 generic `package.loadlib`／C-module searcher；它是另一條候選路徑，並非 MOD loader 的自動步驟。
- **待驗證**：`package` 在 MOD Lua runtime 的實際可見性、DLL 的可達實體路徑、每一個 requirement／elimination 的精確資料結構、載入失敗後的回滾、同名 MOD 的優先序，以及 Steam 訂閱目錄如何合併至實際清單。
- **不可推定**：從 native loader 字串、Lua VM 編入的 helper 或 SWD3Works metadata 都不能推得 Workshop 訂閱會自動執行 DLL、Lua 有新增 hook、能熱重載、能在遊戲執行時安裝 MOD，或能安全繞過版本／相依檢查。

任何 exe patch、DLL 注入、記憶體寫入、附加 debugger 或自動 Steam 上傳皆不屬本研究與可發布 `.ssmod` 的範圍。

通用研究證據與安全限制見 [引擎研究流程](../../../docs/knowledge/engine-research-workflow.md) 與 [測試與驗證](../../../docs/knowledge/testing-and-verification.md)。
