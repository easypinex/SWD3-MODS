# 封裝與安裝

## 路徑占位

- `<game-root>`：遊戲安裝目錄；目前本機範例為 `D:\SteamLibrary\steamapps\common\SWD3`。
- `<project-root>`：單一 MOD 專案根目錄。
- `<basename>`：`src` 根目錄內來源 `.ext` 的檔名去掉副檔名。
- `<work-dir>`：獨立的反解驗證目錄，不得使用遊戲核心資源目錄。

## 建置單一 `.ssmod`

使用 `SS2Dtool p` 建置；完整命令、`-i/-I` 參數與假成功情況見[工具與命令參考的 `p` 小節](tools-and-commands.md)。`-I` 必須與 `<project-root>\src\<basename>.ext` 的檔名基底完全相同，**不包含 `.ext`**；目前工作目錄也必須先沒有同名舊 `.ssmod`。

建置後立即確認：

1. `<basename>.ssmod` 確實存在。
2. 檔案大小符合內容預期，不是只含 manifest 的異常小檔。
3. 將成品複製到獨立驗證資料夾後反向解包。

## 反向解包與逐檔比對

將成品放入獨立 `<work-dir>`，再依[工具與命令參考的 `x` 小節](tools-and-commands.md)執行 `SS2Dtool x`。

驗收：

- 根目錄解出 `<basename>.ext`。
- `out_data` 包含 `.ext` 宣告的每一個 Lua、txt 及其他資源。
- 逐檔比較來源和反解檔的 SHA-256。
- 若有 `dist`、遊戲安裝版或工作坊內容版，三者雜湊應一致。

「沒有錯誤訊息」和「退出碼為 0」都不能取代產物與反解驗證。

## 本機安裝

只把正式 `.ssmod` 複製到 `<game-root>\Mods`，並在 `modlist.txt` 啟用：

```text
1 <basename>.ssmod
```

更新後必須完全關閉並重開遊戲；只回到標題畫面不足以重新載入 Lua。依[工具與命令參考的 SS2DConsole 小節](tools-and-commands.md)確認專案 README 所列初始化訊息。

工作坊項目若曾從 `.ext` 散檔改為 `.ssmod`，`modlist.txt` 可能保留舊副檔名。進入 MOD 管理停用再啟用一次，並確認清單已改為 `.ssmod`。

## 安全界線

- 正式本機與工作坊成品優先使用單一 `.ssmod`；已實測 4.0.5 的工作坊散檔雖能下載，Lua 不一定執行。
- 不在遊戲安裝目錄直接進行解包、批次轉檔或測試封裝。
- 不把 `src`、`tests`、散裝 `.ext`、反解資料或來源素材複製到工作坊內容資料夾。
- 工作坊發布的完整流程見 [Steam 工作坊發布](steam-workshop-release.md)。

## Steam HD 4.0.5 MOD loader 與 native module 載入的界線

狀態：**已靜態反解，僅適用 `swd3.exe 4.0.5.0` SHA-256 `63F1D83D8C3A756D17640D9022E19F8928741B091F0E47ABBDB22C0CCF6C9523`，2026-09-05。** 完整可重跑證據、Ghidra scripts 與副本指紋保留在 [swd3-native-loader-probe](../../research/active/swd3-native-loader-probe/README.md)。

1. 官方 MOD chain 是 Steam UGC 訂閱 ID → `SteamMods.txt` 映射，或 `<game-root>\\Mods\\modlist.txt` → `.ssmod` 名稱／啟用狀態 → `.ssmod` header、manifest 與 `DAT` 載入 → Lua／資料／資源。`MODGameVersion`、`MODrequirement`、`MODelimination` 都在這條 chain 上檢查。
2. loader 的 `.ssmod` 分流、manifest parser 與 archive reader 沒有 direct call 至 `LoadLibraryA/W/Ex*` 或 `GetProcAddress`。因此「訂閱並啟用一個正常 Workshop MOD」本身沒有靜態證據會自動載入其 DLL 或 native patcher。
3. 同一 executable **確實**匯入 `LoadLibraryExA`、`LoadLibraryW`、`GetProcAddress`。前者屬 Lua VM 編入的 `package.loadlib`／C-module searcher；後兩個 direct caller 分別是磁碟空間查詢與 CRT 同步初始化。不要把「MOD loader 沒有 direct caller」寫成「遊戲沒有 DLL loader」。
4. `package.loadlib` 是否在 MOD Lua runtime 可見、能否讀到 Workshop 的實體 DLL、其入口／架構條件與 Steam／遊戲政策是否允許，均仍是**待驗證**。在未做最小唯讀 runtime inventory 前，它不是可發布 MOD 的依賴，也不能當作 Workshop 訂閱即用 native patch 的證據。

研究結論必須同時報告兩件事：是否找到 Windows module API，以及該 API 與 MOD discovery／archive loader 是否有可證明的控制流連結。只報其中一面，會錯把一般 runtime 能力說成官方 MOD extension point，或錯把無 direct link 說成不存在 DLL 載入能力。
