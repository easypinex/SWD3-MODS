# 工具與命令參考

本文件是工作區工具名稱、用途、參數與命令格式的唯一權威索引。主題文件負責說明「何時執行」與驗收流程；實際參數以本文件為準。

## 路徑與狀態標記

- `<game-root>`：遊戲安裝目錄；目前本機範例為 `D:\SteamLibrary\steamapps\common\SWD3`。
- `<project-root>`：單一 MOD 專案根目錄。
- `<input-dir>`、`<output-dir>`：獨立輸入／輸出目錄。
- **已實測**：本工作區已有成功或失敗產物證據。
- **工具內建說明**：從目前本機 `SS2Dtool.exe` 的內嵌 Big5 說明取得，但不代表所有組合都已實機驗證。
- **專案腳本**：參數由倉庫內腳本本身定義。

## `SS2Dtool.exe`

位置：

```text
<game-root>\Tools\SS2Dtool.exe
```

目前本機檔案內建版本字串為 `SS2Dtool v0.1 (c)2016 SOFTSTAR Abalone`。直接執行、`-h`、`--help`、`help` 或 `?` 都會以退出碼 0 結束，但本機終端不會顯示說明；下列命令名稱與開關已從執行檔內建 Big5 字串核對。

### 共用語法與開關

工具內建語法：

```text
SS2Dtool <指令> -<開關>
```

| 開關 | 工具內建說明 | 實際規則 |
| --- | --- | --- |
| `-i[路徑]` | 輸入路徑 | 路徑必須與 `-i` 放在同一個引號字串。 |
| `-o[路徑]` | 輸出路徑 | 路徑必須與 `-o` 放在同一個引號字串。 |
| `-I[檔名]` | 輸入檔名 | 檔名必須與 `-I` 相連；圖片命令包含副檔名。 |
| `-O[檔名]` | 輸出檔名 | 檔名必須與 `-O` 相連且包含副檔名。 |
| `-a[倍率]` | 增減 ALPHA，`-255..255` | 精確適用命令待驗證；既有 `gpa -a128` 探針沒有可觀察差異，不得當作遊戲 UI 透明度控制。 |

PowerShell 的安全呼叫形式：

```powershell
$tool = '<game-root>\Tools\SS2Dtool.exe'
& $tool <command> '-i<input-dir>' '-I<input-file>' '-o<output-dir>' '-O<output-file>'
```

不要拆成 `-i '<input-dir>'`。本工具可能在參數錯誤時仍回傳 0，因此每次都要檢查實際產物。

### `p`：壓製 `.ssmod`

狀態：**已實測**。

```powershell
$tool = '<game-root>\Tools\SS2Dtool.exe'
& $tool p '-i<project-root>\src' '-I<basename>'
```

- `<project-root>\src\<basename>.ext` 必須存在。
- `-I` 必須是來源 `.ext` 的**同名檔名基底**，不包含 `.ext`；例如來源是 `src\live_card_battle.ext` 時，必須傳 `-Ilive_card_battle`。傳入 `.ext` 副檔名會靜默不產出成品。
- `p` 的輸出會寫到執行命令時的目前工作目錄；建置前該目錄不能已有同名 `.ssmod`，因為工具不會覆寫舊檔卻仍可能回傳成功。建置後必須從該目錄取用成品，不能假設它會寫回 `src` 或專案根目錄。
- 成功條件：`.ssmod` 實際出現且大小合理；接著必須使用 `x` 反解。
- 常見假成功：Lua 不在 `src/data`、參數和值被拆開、`-I` 與 `.ext` 不同。

完整工作流見 [封裝與安裝](packaging-and-installation.md)。

### `x`：解開 `.ssmod`

狀態：**已實測**。

```powershell
# <work-dir> 內先放入 <basename>.ssmod
$tool = '<game-root>\Tools\SS2Dtool.exe'
& $tool x '-i<work-dir>' '-I<basename>'
```

預期輸出依封包類型包含根目錄 `.ext`、`out_data/` 或 `out_tsw/`。對 HD `tsw_index.ssmod`，`x` 會輸出圖片，但不會寫出內嵌的 `tsw_index.ext` manifest。

解開 `script_index.ssmod` 時可能因重名資源產生 `out_data_N` 目錄；後綴不是可跨 archive 假定的語言名稱，必須用內容辨識。版本指紋與輸出盤點集中在[引擎研究流程](engine-research-workflow.md)，語言槽見[在地化與文字](localization-and-strings.md)。

### PNG → PIC：`gp`、`gp2`、`gpa`

共用參數：

```powershell
& $tool <gp|gp2|gpa> `
  '-i<input-dir>' `
  '-I<input.png>' `
  '-o<output-dir>' `
  '-O<output.pic>'
```

| 指令 | 工具內建說明 | 本工作區驗證結果 |
| --- | --- | --- |
| `gp` | PNG 轉換 PIC | 24 位 RGB 可轉換；32 位 ARGB 探針出現錯色。 |
| `gp2` | PNG 轉換 PIC，強制 32 位轉 24 位、無透明 | 32 位來源色彩大致保留，但 alpha 全部不透明。 |
| `gpa` | PNG 轉換 PIC，強制 32 位轉 16 位、深色轉透明 | 不是保真 RGBA；深色與半透明像素會變化。 |

實例：

```powershell
& $tool gp `
  '-i<input-dir>' `
  '-Itsw20002_00.png' `
  '-o<output-dir>' `
  '-Otsw20002_00.pic'
```

### PIC → PNG：`pg`、`pg2`、`pga`

共用參數：

```powershell
& $tool <pg|pg2|pga> `
  '-i<input-dir>' `
  '-I<input.pic>' `
  '-o<output-dir>' `
  '-O<output.png>'
```

| 指令 | 工具內建說明 | 本工作區驗證結果 |
| --- | --- | --- |
| `pg` | PIC 轉換 PNG | 用於一般回轉；尺寸保留但可能有色彩量化。 |
| `pg2` | PIC 轉換 PNG，強制使用 24 位 | alpha 會變為不透明，只適合檢視色彩。 |
| `pga` | PIC 轉換 PNG，強制使用 32 位、深色轉透明 | 色鍵行為，不代表原始 alpha 保真。 |

每次 PNG→PIC 後立即以相應的 PIC→PNG 回轉，檢查尺寸、色彩、透明區和輸出存在；不要要求 PNG 位元雜湊相同。

### `pu`：重新壓縮 PIC

工具內建說明：`指定路徑下的 pic 重新壓縮`。

目前只確認對已壓縮的小型探針 PIC，執行前後大小與 SHA-256 沒有變化。確切輸入路徑組合、批次覆寫範圍與對其他 PIC 的效果沒有完成系統驗證；使用前必須複製到隔離目錄並記錄檔案數、大小與雜湊，不得直接對來源圖庫執行。

### `te[p]`：解開原始 TSW

狀態：**已實測**。工具內建說明：`解開軒三的 tsw [也輸出 png]`。`tep` 會從遊戲隨附的六個 `swd3DVD/all_*.tsw` 建立 `tsw/`、`tsw_png/` 與 `tsw_index.ext`。

```powershell
$game = '<game-root>'
$tool = "$game\Tools\SS2Dtool.exe"
$output = '<output-dir>'

New-Item -ItemType Directory -Force -Path "$output\tsw", "$output\tsw_png" | Out-Null
& $tool tep "-i$game\swd3DVD" "-o$output"
```

指定 `-o` 時，`tsw` 與 `tsw_png` 必須先存在；否則工具可能回傳 0 並只寫出沒有 `TSW` 列的 135-byte 空 `tsw_index.ext`。目前 Steam HD 4.0.x 的六個來源封包已實測輸出 20,091 個 PIC、20,091 個 PNG 與 20,091 條索引列；三者必須逐一計數，不能以退出碼或單一 `.ext` 存在判定成功。正式重建請使用 `SWD3-TSW-PNG-GALLERY/Rebuild-SourceGallery.ps1`，它會驗證來源、拒絕覆寫非空輸出並建立 CSV／瀏覽檔名。

這是舊版來源資源流程，不是 HD `tsw_index.ssmod` 的 manifest 擷取方式。不要在遊戲安裝目錄中指定輸出或留下解包產物。

### `tx<增減值>`：批次調整 TSW ID

工具內建說明：`增減 tsw ext 檔的所有 tsw 編號`，命令值直接接在 `tx` 後，例如語法形狀為 `tx<增減值>`。

目前專案沒有保存一條通過回驗的正式命令，也沒有使用它修改權威索引。它會批次改動 ID，使用前必須：

1. 複製 `.ext` 到隔離目錄。
2. 先記錄行數、最小／最大 ID 與雜湊。
3. 執行後逐列驗證只有預期 ID 位移。
4. 不對 HD 正式 manifest 或遊戲核心資源直接執行。

## `SS2DConsole.exe`

位置：`<game-root>\Tools\SS2DConsole.exe`。這是 GUI 診斷工具，沒有在本專案驗證 CLI 參數。

### 程式化唯讀擷取目前輸出

狀態：**已實測，Steam HD 4.0.5／`SS2DConsole.exe` 1.0.0.0（42,496 bytes），2026-09-05。** Console 不會把 Lua 訊息寫入可發現的 log 檔、named pipe 或網路端點；其接收視窗以 `WM_COPYDATA`（`0x4A`）將 Unicode 訊息附加到 WinForms `RichTextBox`。該控制項透過 Windows UI Automation 暴露為 `ControlType.Document`，可從 `ValuePattern` **唯讀**取得當下完整文字。

因此，實機測試時不必由測試者反覆手動複製 Console。**SS2DConsole 必須以可見的一般視窗啟動；不可使用隱藏視窗、背景模式或在啟動後立刻隱藏。** 遊戲與可見的 Console 維持開啟後，可由 Agent 或下列 Windows PowerShell 指令擷取；它只讀取 UIA value，**不會**按鍵、送出 Console 指令、清除畫面或改動遊戲資料：

```powershell
$script = @'
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
$process = Get-Process -Name SS2DConsole -ErrorAction Stop |
  Select-Object -First 1
$root = [System.Windows.Automation.AutomationElement]::FromHandle(
  $process.MainWindowHandle
)
$all = $root.FindAll(
  [System.Windows.Automation.TreeScope]::Descendants,
  [System.Windows.Automation.Condition]::TrueCondition
)
foreach ($element in $all) {
  if ($element.Current.ControlType -ne
      [System.Windows.Automation.ControlType]::Document) { continue }
  $valuePattern = $null
  if ($element.TryGetCurrentPattern(
      [System.Windows.Automation.ValuePattern]::Pattern,
      [ref] $valuePattern
  )) {
    $valuePattern.Current.Value
    break
  }
}
'@
& powershell.exe -NoProfile -ExecutionPolicy Bypass -Command $script
```

這是**快照**，不是 Console 原生的串流／訂閱 API。若要持續監看，輪詢快照並僅輸出相對前一快照新增的尾端；遇到 Console 重新連線或清除而使文字縮短時，必須將新的完整內容視為新的基線，不能以舊長度切片。UIA 存取需要 Console 在互動式桌面上以同一使用者／相容權限層級執行，且維持可見；未實測背景服務、不同 Windows session 或提升權限不一致時的可見性。

### Console → 遊戲命令通道（不可作正式依賴）

狀態：**工具內部程式碼分析＋待驗證 runtime 行為，Steam HD 4.0.5，2026-09-05。** `SS2DConsole` 的 Send 按鈕會把一般輸入包成 `#&l<輸入文字>`，再以 `WM_COPYDATA` 送給標題為遊戲名稱的視窗；傳送端 `wParam` 是 Console 視窗。簡短輸入曾在遊戲回傳的 Console 畫面出現原始命令與 `-- [Console] : PASS.`，但尚未取得一個可重複、可區分「回顯」「Lua 執行結果」與「命令完成」的協定；較長的唯讀輸入亦曾只留下回顯、未見完成回應。

因此不得把 `#&l` 視為穩定的 CLI、Lua RPC 或讀檔／測試控制 API，也不得用它取代測試 MOD 明確的自動化入口。若需研究，應在可丟棄存檔建立獨立探針，依序驗證短命令、明確回應、逾時、重連與無副作用的狀態查詢；未完成前僅可作研究線索。

使用方式：

### 本機實機啟動流程

**已實測，Steam HD 4.0.5，2026-09-05。** 本機驗證 MOD 時，正確順序是先以**可見的一般視窗**開 Console，再直接啟動遊戲根目錄的 `swd3.exe`；不需要 Steam URI、`-applaunch` 或未驗證的命令列參數。**不可用 `-WindowStyle Hidden`、背景模式或啟動後隱藏 Console。**

```powershell
$gameRoot = 'D:\SteamLibrary\steamapps\common\SWD3'
Start-Process -FilePath "$gameRoot\Tools\SS2DConsole.exe" `
  -WorkingDirectory "$gameRoot\Tools"
Start-Sleep -Milliseconds 800
Start-Process -FilePath "$gameRoot\swd3.exe" -WorkingDirectory $gameRoot
```

1. 確認 Console 已先以**可見的一般視窗**開啟，且未被隱藏。
2. 直接執行 `<game-root>\swd3.exe`，並等候遊戲主視窗出現。
3. 在 Console 確認目標 MOD 的 README 所列初始化訊息。
4. 只有「遊戲主視窗已出現」且「Console 已收到 MOD 載入訊息」才算啟動成功；背景 `swd3` 程序、MOD 管理顯示啟用、`.ssmod` 存在或 `modlist.txt` 紀錄都不足以證明 Lua 已載入。

若直接啟動後立即退出或 Windows 應用程式事件記錄顯示 `swd3.exe` crash，停止自動重試與猜測 Steam 啟動參數，保留 Console 並請使用者用其已知可行流程從 Steam 啟動，再記錄結果。


## `SWD3Works.exe`

位置：`<game-root>\SWD3Works.exe`。這是 Steam 工作坊 GUI；目前沒有已驗證的命令列參數。

輸入包括工作坊內容資料夾、標題、說明、預覽圖、更新說明與可見度。內容資料夾應只含單一正式 `.ssmod`。完整順序、重新訂閱與公開門檻見 [Steam 工作坊發布](steam-workshop-release.md)。

### SWD3Works 受管反編譯

**已實測工具流程，2026-09-06。** SWD3Works 是受管工具，使用 ILSpyCmd；不需為此執行整個遊戲的 Ghidra loader 分析。來源版本及可定位控制流見[發佈工具研究](../../research/active/swd3works-publisher-repair/README.md#分析基線與重跑)。此處只定義靜態匯出，不執行或修補目標、不呼叫 Steam API。

本機已測 `.NET SDK 8.0.204`／runtime `8.0.4` 配 `ilspycmd 9.1.0.7988`。從工作區根目錄準備工具，安裝會下載 NuGet 套件並寫入 `.tools`／本機套件快取；不修改遊戲安裝：

```powershell
dotnet tool install ilspycmd --version 9.1.0.7988 --tool-path .tools/ilspycmd
& ./.tools/ilspycmd/ilspycmd.exe --help
```

已安裝即略過 install。依該版實際 help 核對：`-r` 指受管相依目錄、`-o` 指 C# 輸出目錄，最後為 assembly 路徑；`--disable-updatecheck` 停用更新檢查，`--version` 記錄分析器版本。官方入口：[ILSpyCmd](https://github.com/icsharpcode/ILSpy/tree/master/ICSharpCode.ILSpyCmd)，不同版本不得直接假定行號或參數一致。

```powershell
& ./research/active/swd3works-publisher-repair/scripts/Export-PublisherAnalysis.ps1 `
  -GameRoot '<game-root>' `
  -OutputRoot '<workspace>/.work/publisher-analysis-new-run' `
  -IlspyPath '<workspace>/.tools/ilspycmd/ilspycmd.exe'
```

三個參數皆必填。腳本拒絕既存輸出目錄及遊戲目錄內輸出；建立 `input/` 三份副本（exe、Steamworks.NET.dll、exe.config）、`decompiled/` C# 與 `fingerprint.json`。複製前後及分析後核對原檔與副本 hash；檢查所需 symbols 與退出碼。僅當來源及完整匯出 hash 符合既有基線，才另產生 `control-flow-excerpts.txt` 行號摘要；其他版本須重新定位。所有完整反編譯及原版副本留在本機產物，只有選定證據與指紋可歸入研究目錄。

### Steam 工作者原型 M0

**已實測，2026-09-06。** 獨立 x86 命令列工作者，目標 .NET Framework 4.8，依賴本機配套 `Steamworks.NET 20.2.0.0` 與 x86 `steam_api.dll`；不用執行 SWD3Works。版本、指紋、操作範圍與線上證據見[原型文件](../../research/active/swd3works-publisher-repair/PROTOTYPE.md#實測結果)。只適用已測版本，不把 x86 結論套用所有 Steamworks.NET build。

所有命令從工作區根目錄執行。建置使用 Windows 隨附的 `Microsoft.NET/Framework/v4.0.30319/csc.exe`，本次版本 `4.8.9221.0`；使用本機 framework／System.Web.Extensions，沒有 NuGet restore 或新 SDK 安裝。現行建置腳本產生 0.3.0（桌面擴充見下方），另需本機 Python 3＋`zstandard` 作封包檢查，擴充命令見[版本維護入口](#steam-版本維護原型-020)：

```powershell
& ./research/active/swd3works-publisher-repair/scripts/Build-SteamPrototype.ps1 `
  -GameRoot '<game-root>' -OutputRoot '<workspace>/.work/steam-prototype-new-build'
```

兩參數必填。拒絕既存輸出目錄／遊戲目錄內輸出及未知依賴 hash；複製配套 DLL，呼叫 C# compiler 的 `/target:exe /platform:x86 /optimize+ /warnaserror+`，建立 exe、framework config、`steam_appid.txt` 與 build fingerprint，執行離線 self-test。build 是本機產物，不包含遊戲核心修改；離線測試只寫自己的暫存目錄。

操作包裝器：[Invoke-SteamPrototype.ps1](../../research/active/swd3works-publisher-repair/scripts/Invoke-SteamPrototype.ps1)。`-BuildRoot`、`-Command`、`-LogPath` 必填；核對 exe／DLL hash，以 build 目錄為 cwd 執行並保存 stdout。`-LogPath` 必須尚不存在：

```powershell
& ./research/active/swd3works-publisher-repair/scripts/Invoke-SteamPrototype.ps1 `
  -BuildRoot '<build-root>' -Command list `
  -LogPath '<new-log-path>' -OutputPath '<published-json-path>'
```

| 參數／Command | 規則與副作用 |
| --- | --- |
| `self-test` | 現行0.2.0離線32項（原M0為14項），無 Steam init |
| `health`、`list`、`details` | 唯讀 Steam；details 必須給 `-ItemId`；list 可給 `-OutputPath`（原子替換，保留 .bak）及 `-Page 1..1000`；省略 Page 自動逐頁 |
| `create-test`、`update-test` | 必須給 `-PlanPath`、`-StatePath`；**會向 Steam 建立／更新專用私人測試項目**；不適用正式作品，既有 create journal 禁止重建 |
| `verify-test` | 相同 PlanPath／StatePath；唯讀遠端，核對後寫本機 journal |
| `download-test` | 相同 PlanPath／StatePath；Steam 下載至其快取，比對成品 hash；不訂閱、不啟用、不安裝到 Mods |
| `-TimeoutSeconds` | 5–600，預設60；逾時停止等待但不宣稱遠端取消，不能盲目重送 Create |

初次私人測試前準備並檢查專用計畫：

```powershell
& ./research/active/swd3works-publisher-repair/scripts/Prepare-SteamPrototypeTest.ps1 `
  -GameRoot '<game-root>' -OutputRoot '<workspace>/.work/steam-prototype-new-fixture'
```

拒絕既存／遊戲內輸出，建立兩版 no-op fixture、512×256 自有預覽與 `plan-r1.json`／`plan-r2.json`；呼叫已記錄的 `SS2Dtool p`，再由 `Verify-M0Package.py <package> <source-dir> <new-output-dir>` 反向解出兩個 frame 並逐位元比較。此 helper 使用 CPython3／`zstandard 0.25.0`，只適用此 fixture，不是通用解包器。準備本身不呼叫 Steam；本次官方 x 無輸出之例外保留在[專案紀錄](../../research/active/swd3works-publisher-repair/PROTOTYPE.md#測試內容與解包差異)。

真實新建使用 `-Command create-test -PlanPath <plan-r1> -StatePath <new-state>`，同 ID 第二版更新用 `-Command update-test -PlanPath <plan-r2> -StatePath <same-state>`；都另給必填 BuildRoot／LogPath。可先透過原型 `--help` 查看 CLI。使用相同 ID 做 `verify-test` 可核對未知 submit 結果；缺 ID 的未知建立須先查作品，不自動重建。正式完整產品的多語言、一般作品編輯、UI／IPC 不屬 M0。

### Steam 版本維護原型 0.2.0

**已實測，2026-09-06，所列版本限定。** 沿用上方建置與 Invoke 腳本，加入原 ID 持續升版、一般自有作品查詢／更新、逐版歷史、雙語預設欄位同步與自動下載驗證。專案契約、實例與限制見 [RELEASES](../../research/active/swd3works-publisher-repair/RELEASES.md)，精確線上證據見[案例](../../research/active/swd3works-publisher-repair/evidence/releases-20260906/README.md#案例)。

前置環境為原配套 x86 DLL、Framework4.8，另需可執行 `python` 且已安裝 `zstandard`（本次0.25.0）。Build 會解析實際 `python.exe` 路徑，複製自有 `SteamReleasePackage.py`，保存 runtime 設定及其 hash；Invoke 核對這兩個檔案，搬機應重新建置。每次讀包啟動背景 Python helper，最多等候30秒；不使用 shell 拼接命令。

| 入口 | 參數、輸出與副作用 |
| --- | --- |
| `SteamReleasePackage.py inspect <package>` | 唯讀 `.ssmod`，stdout JSON：內嵌版本、MODName、檔名、大小、SHA-256、manifest hash；只辨識SMOD v4首個manifest，不完整解包資源 |
| `SteamReleasePackage.py prepare <draft.json> <new-output>` | 輸出必須是工作區內新目錄；複製單一封包／可選預覽、讀取版本，產生schema 3的plan.json／package.json。不呼叫Steam；中文計畫契約含English預設欄位同步 |
| `review-release` | Invoke另給PlanPath／StatePath；查遠端與下載目前檔案，保存審閱。不寫Steam；可重新審閱明確拒絕的原操作，未知結果不能當拒絕 |
| `publish-release` | 相同PlanPath／StatePath，**會新建或更新Steam作品**；新建ID立即保存，中文與預設欄位按序提交，再自動查回／下載驗證。已有送出結果時只核對，不盲目重送 |
| `verify-release` | 相同PlanPath／StatePath；查詢／下載，核對成功才保存verified；不提交。相同操作多次核對不是新版本 |
| `close-release` | 相同PlanPath／StatePath；僅明確遭拒且遠端仍完全保持原狀的既有更新，可查詢／下載後結案。部分改動或未知結果拒絕 |
| `files` | Invoke另給ItemId；查詳情並下載至Steam自身快取，列每個檔名／大小／SHA-256／可辨識內嵌版本；不訂閱、不安裝至Mods |
| `history` | Invoke另給ItemId；目前帳號的本機已驗證歷史；讀LocalAppData，不宣稱可恢復Steam從未記錄的舊包 |
| `-OutputPath` | details、files、history、release-review／verified均可輸出完整JSON；原子替換並保留.bak |
| `-Language` | 查詢預設tchinese，可選english／schinese；release命令以計畫Language為準，舊M0測試固定english |

上述 Invoke 仍必須提供 BuildRoot／Command／新 LogPath；5–600秒時限以每個Steam等待階段計算。release操作另自動產生 `<LogPath>.html`，失敗時有狀態檔也會輸出差異；HTML是當次紀錄，不是即時Steam畫面。獨立報告腳本為 `Export-SteamReleaseReport.ps1 -PlanPath <plan> -StatePath <state> -OutputPath <new-html>`，只讀兩份JSON並寫本機HTML，不查Steam。

測試fixture準備腳本新增 `-Revisions 3,4,5`（預設仍1,2）；產生的schema 1 M0 plan僅適用舊兩版測試，其他版取其已回驗封包再由prepare產生release計畫。離線封包回歸使用 `python research/active/swd3works-publisher-repair/scripts/Test-SteamReleasePackage.py <no-op-fixture.ssmod>`；在工作區 `.work` 內獨立暫存完成5項測試後清理，不呼叫Steam。

固定操作登記／未完成指標／成功歷史寫入 `%LOCALAPPDATA%/SWD3ModStudio/releases/1638230/<SteamID>/`；每次計畫與快照、完整state／.bak保留在指定操作目錄。不要只刪除state來重送未知Create；完整恢復規則見[原型狀態契約](../../research/active/swd3works-publisher-repair/RELEASES.md#狀態失敗與恢復)。

### MOD Studio 桌面版 0.3.0

**已實測，2026-09-06。** Windows WPF 發佈與維護介面，沿用獨立 x86 Steam 工作者。完整操作、環境範圍、資料遷移與驗收證據見 [DESKTOP](../../research/active/swd3works-publisher-repair/DESKTOP.md)。上方 0.2.0 的命令語意保持；現行來源建置版本為 0.3.0。

```powershell
& ./research/active/swd3works-publisher-repair/scripts/Build-Desktop.ps1 `
  -GameRoot '<game-root>' -OutputRoot '.work/mod-studio-new-build'
```

OutputRoot 必須尚不存在且在遊戲外；建置自有 WPF 程式、worker 子目錄、runtime 設定、指紋與離線測試日誌，不呼叫 Steam。Framework 4.8／原配套 DLL／本機 Python 和 zstandard 的要求同上。成品入口 `SWD3ModStudio.exe`；GUI 開啟後會查詢 Steam，按發佈才寫作品，檔案查詢會下載至 Steam 快取。

0.3.0 桌面資料與操作快照寫入 `%USERPROFILE%/SWD3ModStudio/Desktop/`；工作者歷史與未完成指標改用 `%USERPROFILE%/SWD3ModStudio/releases/1638230/<SteamID>/`。舊 LocalAppData 計畫需要時複製到 `%USERPROFILE%/SWD3ModStudio/uploads/<OperationID>/`，核對雜湊後提交；不自動刪除尚可能被 Steam 使用的副本。此位置選擇與 MSIX 預覽隔離的限定證據見[桌面研究](../../research/active/swd3works-publisher-repair/evidence/desktop-20260906/README.md#預覽環境的資料隔離問題)，不提升為遊戲引擎規則。

worker 另提供 `inspect-package --package <absolute-path>`（唯讀，不初始化 Steam）及 `--expected-account <SteamID>`（連線帳號不符即停止）。GUI 會自動使用這兩項。`SWD3ModStudio.exe --self-test` 只做離線程序與保存測試；因 WinExe 不附加主控台，建置腳本以重導 stdout 保存結果。

#### GitHub 桌面發佈包

`scripts/Build-DesktopRelease.ps1 -BuildRoot <desktop-build> -OutputRoot <new-directory>` 只讀已建置的 0.3.0 成品，核對程式指紋，使用明確清單複製至新目錄並建立 Windows ZIP、`SHA256SUMS.txt`。不含遊戲 DLL、開發機 `package-runtime.json` 或使用者資料；不呼叫 Steam，也不上傳 GitHub。腳本位於上述桌面專案內，輸出使用 `.work/` 或專案已忽略的 `release-artifacts/`。

解壓後執行 `Setup.cmd`，或 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File <package>/Setup-Desktop.ps1 -GameRoot <game-root> -PythonExe <python.exe> -NoLaunch`。`GameRoot` 省略時顯示遊戲選檔對話框，`PythonExe` 省略時從 PATH 的 python／py 尋找；`NoLaunch` 僅執行設定與 32 項工作者離線測試。設定先核對套件檔案與原配套 DLL 雜湊，然後複製兩份 DLL、生成本機 Python runtime 設定與更新其指紋；重跑可重新設定。需要 Python 3 和 zstandard（驗收使用 Python 3.12.10／zstandard 0.25.0），不自動下載依賴、不修改遊戲、不呼叫 Steam。未指定 `NoLaunch` 時完成後開啟桌面程式，介面啟動會查詢 Steam。隨包 `release-files.json` 用於檔案完整性檢查；本機可變的 worker 指紋不在該清單，整份 ZIP 的雜湊另由 `SHA256SUMS.txt` 提供。

## Node.js：Lua 語法與 mock runtime

`swd3-live-card-battle-mod/tests/run-tests.ps1` 已實測使用下列工具。

### `luaparse`

```powershell
npx --yes --package luaparse luaparse --quiet `
  --file '<source-one.lua>' `
  --file '<source-two.lua>'
```

| 參數 | 用途 |
| --- | --- |
| `--yes` | 允許 `npx` 取得指定套件。 |
| `--package luaparse` | 使用 `luaparse` 套件。 |
| `--quiet` | 成功時減少輸出。 |
| `--file <path>` | 指定要解析的 Lua；可重複。 |

以非 0 退出碼判定語法失敗。

### `fengari-node-cli`

```powershell
npx --yes --package fengari-node-cli fengari `
  '<mock-runtime.lua>' `
  '<source.lua>'
```

參數是依序傳給 Lua 程式的檔案路徑。除了退出碼，測試包裝器還應檢查 `stack traceback:` 與明確的 `PASS:` 標記，避免 runtime 靜默失敗。

專案已有 `tests/run-tests.ps1` 時，優先執行包裝器，不要手動拼接命令而遺漏專案驗收。

## HD TSW 圖庫腳本

以下腳本位於 `SWD3-HD-TSW-PNG-GALLERY/`。它們會建立、複製、重新命名或覆寫圖庫輸出；執行前先讀該圖庫 README。

### `Convert-HdPicToPng.ps1`

```powershell
& '<gallery-root>\Convert-HdPicToPng.ps1' `
  -ToolPath '<game-root>\Tools\SS2Dtool.exe' `
  -ExtractedPicRoot '<work-dir>\out_tsw' `
  -OutputRoot '<work-dir>\converted_png' `
  -ThrottleLimit 8
```

| 參數 | 用途 |
| --- | --- |
| `-ToolPath` | 本機遊戲隨附的 `SS2Dtool.exe`；必填，不使用作者電腦的固定路徑。 |
| `-ExtractedPicRoot` | `SS2Dtool x` 產生、含 `.pic` 的目錄。 |
| `-OutputRoot` | PNG 輸出目錄；若已存在必須為空，避免覆寫。 |
| `-ThrottleLimit` | 平行呼叫 `pg` 的最大數量，預設 8。 |

腳本逐張檢查 PNG 是否存在，並要求輸出數等於來源 PIC 數。

### `Build-HdGallery.ps1`

```powershell
& '<gallery-root>\Build-HdGallery.ps1' `
  -ExtractedPngRoot '<work-dir>\out_tsw' `
  -ConvertedPngRoot '<work-dir>\converted_png' `
  -GalleryRoot '<gallery-root>'
```

| 參數 | 用途 |
| --- | --- |
| `-ExtractedPngRoot` | `x` 直接解出的原生 PNG。 |
| `-ConvertedPngRoot` | PIC 回轉得到的 PNG。 |
| `-GalleryRoot` | 圖庫根目錄；預設為腳本所在目錄。 |

腳本拒絕兩個來源中同名 PNG，然後寫入 `hd_tsw_png/`、`hd_tsw_png_index.csv` 與 `hd_tsw_known_references.csv`。

### `Extract-HdTswManifest.py`

安裝依賴：

```powershell
python -m pip install -r '<gallery-root>\requirements.txt'
```

執行：

```powershell
python '<gallery-root>\Extract-HdTswManifest.py' '<game-root>\tsw_index.ssmod'
```

唯一位置參數是來源 `.ssmod`；省略時腳本使用作者本機預設路徑。腳本讀取第一個 Zstandard frame，寫出 `tsw_index_hd.ext`、`hd_tsw_mapping.csv`、`hd_tsw_png_index.csv`，並依正式映射重新命名圖庫副本。它不修改遊戲封包，但會修改圖庫目錄。

## 來源圖庫重新命名腳本

`SWD3-TSW-PNG-GALLERY/Rebuild-SourceGallery.ps1` 是從全新 clone 還原原版來源圖庫的正式入口；`-GameRoot` 指向本機遊戲根目錄，`-GalleryRoot` 預設為腳本所在圖庫。它使用上方已實測的 `tep` 流程，並在解包後呼叫索引與重新命名腳本。

`SWD3-TSW-PNG-GALLERY/Build-SourceGalleryIndex.ps1` 從既有 `tsw_index.ext` 與 `tsw_png/` 產生 CSV，核對 manifest／PNG 數量後再呼叫重新命名腳本；通常不需單獨執行。

`SWD3-TSW-PNG-GALLERY/Rename-PngPreviews.ps1`：

```powershell
& '<source-gallery-root>\Rename-PngPreviews.ps1' `
  -GalleryRoot '<source-gallery-root>'
```

`-GalleryRoot` 預設為腳本目錄。腳本依 `tsw_png_index.csv` 就地重新命名 `tsw_png/` 內檔案並更新 CSV；雖有碰撞與缺檔保護，仍應先備份或在可重建副本上執行。

## Lua binding 唯讀研究工具

`research/active/swd3-native-menu-probe/tools/FindLuaBindingXrefs.py` 只讀取 x64 PE，找出指定 ASCII Lua binding 字串的 RIP-relative 參照。

此腳本使用獨立 **CPython 3**；先確認 `python --version` 可用，再安裝其兩個依賴。只做下方 Ghidra 分析時不需要這一步：

```powershell
python -m pip install pefile capstone
python -c "import pefile, capstone; print('PE scanner dependencies OK')"
```

執行：

```powershell
python 'research\active\swd3-native-menu-probe\tools\FindLuaBindingXrefs.py' `
  '<game-root>\swd3.exe' `
  'Menu' `
  --context 18
```

| 參數 | 用途 |
| --- | --- |
| `exe` | 要唯讀分析的 x64 執行檔。 |
| `symbol` | ASCII binding 名稱，例如 `Menu`。腳本會搜尋尾端 NUL。 |
| `--context` | 每個參照前後輸出的反組譯指令數，預設 18。 |

找到字串或參照只形成研究線索，不代表該函式已公開給 MOD Lua。正式結論仍需隔離探針與 [測試與驗證](testing-and-verification.md)。

### Ghidra：完整 PE 靜態分析（唯讀）

適用於需要從 callback／binding 字串追到 native caller、state machine 與資格 gate 的 HD 引擎研究。流程與證據界線由[引擎研究流程](engine-research-workflow.md#原生執行檔靜態反解)定義；Ghidra 只分析**複製到研究工作目錄**的 exe，絕不對 `<game-root>\swd3.exe` 直接建立專案、修改或寫回。

#### 從全新 clone 準備 portable 工具

工具本體不納入 Git；`/.tools/` 是本機快取。需要進行 Ghidra 靜態研究時，依下列方式自行取得，不要把下載的 ZIP、解壓目錄或分析資料庫提交回倉庫：

1. 到 [Ghidra 官方 Releases](https://github.com/NationalSecurityAgency/ghidra/releases) 下載 release Assets 中名為 `ghidra_<version>_PUBLIC_<date>.zip` 的檔案；**不要**下載 `Source code`。既有 Steam HD 4.0.5 研究使用 Ghidra 11.4.3；如使用其他版本，必須在研究紀錄寫下實際版本。
2. 到 [Eclipse Temurin 官方下載頁](https://adoptium.net/temurin/releases/) 選擇 **JDK 21 LTS**、**Windows x64**、**JDK**、**ZIP**。核對下載檔的 checksum。此配置針對 Ghidra **11.4.3**，其 `Ghidra/application.properties` 記錄最低 Java 版本為 21；其他 Ghidra 版本須另查該版需求。
3. 將兩個 ZIP 解到本機 `/.tools/static-re/`，例如 `/.tools/static-re/ghidra-11.4.3/` 與 `/.tools/static-re/jdk-21/`；這是 portable 配置，不會改寫系統 Java 設定。
4. 確認 `support/analyzeHeadless.bat`、JDK 的 `bin/java.exe` 存在，並執行 `& '<portable-jdk-root>\bin\java.exe' -version`。下方流程直接使用 headless，不必先開 GUI；若同一專案已在 GUI 開啟，先關閉該專案以釋放鎖定。

#### Python 執行環境與唯讀的範圍

**工具官方說明＋腳本來源核對，2026-09-06；適用 Ghidra 11.4.3。** CLI 語意依[該版官方 headless 說明](https://raw.githubusercontent.com/NationalSecurityAgency/ghidra/Ghidra_11.4.3_build/Ghidra/RuntimeScripts/Common/support/analyzeHeadlessREADME.md)的同名參數章節；離線副本位於 Ghidra `support/analyzeHeadlessREADME.md`。

| 工具／參數 | 執行環境或真正效果 |
| --- | --- |
| `FindLuaBindingXrefs.py` | 獨立 CPython 3，需 `pefile`、`capstone`；讀 PE、輸出至終端，不建立 Ghidra 專案。 |
| 下表 `tools/ghidra/*.py` | Ghidra 內的 Jython 2.7，依賴 `currentProgram`、`println` 與 Ghidra Java API。11.4.3 發行包帶有 `Ghidra/Features/Jython/lib/jython-standalone-2.7.4.jar`；不能用 `python xxx.py` 執行，也不靠 pip 安裝上述 PE 套件。 |
| `-import <副本路徑>` | 首次載入 PE、預設自動分析並保存本機分析資料庫；來源 exe 不被寫回。與 `-process` 互斥。 |
| `-process swd3.exe` | 選取**專案內已匯入的程式名稱**，不是磁碟上的 exe 路徑；需先成功 import。 |
| `-noanalysis` | 跳過自動分析；不禁止腳本修改或資料庫保存，因此不能單獨稱為唯讀。 |
| `-readOnly` | process 時不保存程式變更；import 時不保存匯入程式。因此首次要保留資料庫時不加它，後續報告加上它。它不是檔案系統沙箱，腳本仍可自行寫檔，Ghidra 也可能寫 log／快取／鎖定資訊。 |
| `-scriptPath`、`-postScript` | 前者指定腳本目錄，後者指定腳本檔名。下表報告沒有讀取命令列查詢參數；額外傳事件名／地址不會改變查詢目標。 |
| `-scriptlog`、`-log` | 分別指定腳本日誌與分析日誌；一般 Python `print` 不保證進入 script log。即使使用 `println`，也須驗收全文：本次 11.4.3 caller 報告的 script log 只有標題，多行 C 在 stdout／分析日誌。因此下方另將 stdout 存成 UTF-8 `.txt`，以此作完整報告。 |

報告腳本須經來源檢查，只查詢 data、references、function 與 decompiler 並輸出文字；不可增加建立函式、重新命名、改型別、patch 或儲存資料庫的操作。此處「唯讀」指不修改遊戲檔案及後續不保存程式變更，並非整個研究目錄完全不寫入。

#### 依問題選擇反解腳本

**腳本來源核對，2026-09-06。** 以下連結直接到實作；以指定的常數／函式作為精確定位。固定 VA 的既有研究限定 `swd3.exe 4.0.5.0`、SHA-256 `63F1D83D8C3A756D17640D9022E19F8928741B091F0E47ABBDB22C0CCF6C9523`，且使用原始 PE image base，不能只憑檔案版本相同就套用。字串掃描不依賴這些 VA，但新版本的結果仍須重新解讀。

| 想回答的問題 | 腳本與精確定位 | 輸出與限制 |
| --- | --- | --- |
| 已知任意 ASCII 名稱，先找 exe 參照 | [FindLuaBindingXrefs.py](../../research/active/swd3-native-menu-probe/tools/FindLuaBindingXrefs.py)：`main`／`symbol` 參數 | 字串地址、absolute-pointer sites、RIP references、指令上下文；接受名稱參數，不產生完整反編譯。零筆不證明不存在。 |
| native 哪裡參照戰鬥事件名稱 | [ReportHdBattleEventStringRefs.py](../../research/active/swd3-native-menu-probe/tools/ghidra/ReportHdBattleEventStringRefs.py)：`TARGETS`、`getReferencesTo` | 固定 25 個名稱，含 `Battle_InputClick`；輸出 `TARGET`、`REF ... in ...`、`referenceCount`。只搜已定義資料；重複同名字串只保留最後一個地址，不能視為全程式窮舉。 |
| 輸入／UI 事件在哪個分支呼叫、傳什麼參數 | [DecompileHdBattleUiEventCallers.py](../../research/active/swd3-native-menu-probe/tools/ghidra/DecompileHdBattleUiEventCallers.py)：`TARGETS` | 4 個固定 VA 的完整反編譯，含 `battle_input_dispatcher @ 0x140053ae0`、`battle_input_and_command_ui @ 0x1400574a0`。需與事件參照報告及原版 Lua 對照。 |
| Lua 名稱實際註冊到哪個 native bridge | [DecompileHdBattleLuaBindings.py](../../research/active/swd3-native-menu-probe/tools/ghidra/DecompileHdBattleLuaBindings.py)：`TARGETS` | 固定戰鬥環境／player userdata 註冊函式；不包含所有 Lua 模組。 |
| UI 的靈契資格、CanObsolt 查詢與實際 gate 是否一致 | [ReportHdCaptureUiEligibility.py](../../research/active/swd3-native-menu-probe/tools/ghidra/ReportHdCaptureUiEligibility.py)：`GATE`、`TARGETS`、`MENU_TRANSITION` | gate callers、getter 反編譯及選單過渡片段；選單只輸出篩選段落。 |
| 靈契執行時如何判定資格並走成功後續 | [DecompileHdNativeCaptureEligibility.py](../../research/active/swd3-native-menu-probe/tools/ghidra/DecompileHdNativeCaptureEligibility.py)：`TARGETS` | 固定 gate `0x1400752b0`、成功狀態與後續函式；不等同實機成功率驗收。 |
| 爆擊／一般攻擊的傷害資料如何流動 | [DecompileHdCriticalDamageFlow.py](../../research/active/swd3-native-menu-probe/tools/ghidra/DecompileHdCriticalDamageFlow.py)：`TARGETS` | 4 個固定 VA 的 payload／後續處理反編譯；欄位語意仍需原版資料或探針證據。 |
| player action 在哪裡分流 | [ReportHdBattlePlayerActionStateSplit.py](../../research/active/swd3-native-menu-probe/tools/ghidra/ReportHdBattlePlayerActionStateSplit.py)：`TARGET`、`START_LINE`、`END_LINE` | `0x140044ab0` 反編譯的第 810–915 行片段；行號受分析器版本及資料庫狀態影響，須核對上下文，必要時另取完整函式。 |
| MOD loader／native module 載入路徑 | [Invoke-LoaderStaticAnalysis.ps1](../../research/active/swd3-native-loader-probe/scripts/Invoke-LoaderStaticAnalysis.ps1)：`param`、`followUpReports` | 專用多報告包裝器，使用方式與額外前置條件見[Loader 研究包裝器](#loader-研究包裝器)；不接受事件名查詢。 |

**查清單以外的事件／函式：** 先用接受名稱參數的 PE 掃描器找線索，或在 Ghidra GUI 的字串搜尋中檢查各命中地址及 references。要批次保存時，在對應研究的 `tools/ghidra/` 建立另名腳本，複製字串報告並修改 `TARGETS`；沿本次參照找到函式入口後，另名複製 decompile 報告並修改 `TARGETS` 的 label／VA。不覆寫歷史腳本，不把舊 VA 移植到新 hash；記錄新腳本及其 hash。若未識別 enclosing function，先保存原始指令與參照缺口，不以報告缺函式推論引擎沒有分支。

#### 首次匯入並保存事件報告

**已實測工具流程，2026-09-06。** 以下範例以 Ghidra 11.4.3、JDK 21、PowerShell 7.6.5 及上列 exe hash 跑通；原始報告、精確定位與已知警告見[此次流程驗證](../../research/active/swd3-native-menu-probe/evidence/native-event-workflow-20260906/README.md)。工具下載步驟及表中其他報告未在此次逐項執行，不將此結果外推到其他版本。

以下三個區塊在**工作區根目錄、同一個 PowerShell session** 依序執行。先按前文準備工具；把 `<game-root>` 改為實際安裝路徑。每個新 exe hash 使用新研究目錄，第一段遇到已存在目錄會停止，避免把新副本與舊分析資料庫混用。

```powershell
$ErrorActionPreference = 'Stop'
$nativeWorkspace = (Get-Location).Path
$nativeSource = '<game-root>\swd3.exe'
$nativeRun = Join-Path $nativeWorkspace '.work\native-events-first-pass'
$nativeGhidra = Join-Path $nativeWorkspace '.tools\static-re\ghidra-11.4.3'
$nativeJdk = Join-Path $nativeWorkspace '.tools\static-re\jdk-21'
$nativeHeadless = Join-Path $nativeGhidra 'support\analyzeHeadless.bat'
$nativeScripts = Join-Path $nativeWorkspace 'research\active\swd3-native-menu-probe\tools\ghidra'
foreach ($required in @($nativeSource, $nativeHeadless,
    (Join-Path $nativeJdk 'bin\java.exe'),
    (Join-Path $nativeScripts 'ReportHdBattleEventStringRefs.py'))) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Missing: $required" }
}
if (Test-Path -LiteralPath $nativeRun) { throw 'Use a new nativeRun directory; do not overwrite an earlier analysis.' }
$nativeInput = Join-Path $nativeRun 'input\swd3.exe'
$nativeProjectDir = Join-Path $nativeRun 'ghidra-project'
$nativeReports = Join-Path $nativeRun 'reports'
New-Item -ItemType Directory -Path (Split-Path $nativeInput), $nativeProjectDir, $nativeReports | Out-Null
$nativeHash = (Get-FileHash -LiteralPath $nativeSource -Algorithm SHA256).Hash
Copy-Item -LiteralPath $nativeSource -Destination $nativeInput
foreach ($file in @($nativeSource, $nativeInput)) {
    if ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ne $nativeHash) { throw 'Source/copy fingerprint mismatch.' }
}
$nativeInfo = Get-Item -LiteralPath $nativeInput
[pscustomobject]@{
    Source = $nativeSource; FileVersion = $nativeInfo.VersionInfo.FileVersion
    Length = $nativeInfo.Length; SHA256 = $nativeHash
    RecordedAt = (Get-Date).ToString('o')
} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $nativeReports 'input-fingerprint.json') -Encoding utf8
Get-Content -LiteralPath (Join-Path $nativeGhidra 'Ghidra\application.properties'),
    (Join-Path $nativeJdk 'release') |
    Set-Content -LiteralPath (Join-Path $nativeReports 'tool-versions.txt') -Encoding utf8
Get-FileHash -LiteralPath (Join-Path $nativeScripts 'ReportHdBattleEventStringRefs.py') -Algorithm SHA256 |
    Format-List | Out-String | Set-Content -LiteralPath (Join-Path $nativeReports 'event-script-fingerprint.txt') -Encoding utf8
```

首次 import 需要自動分析與保存專案，**不加** `-noanalysis` 或 `-readOnly`。此步會建立 `NativeEvents.gpr` 及同名 `.rep` 資料夾；可能需要數分鐘。

```powershell
$nativeOldJava = $env:JAVA_HOME
$nativeOldPath = $env:PATH
try {
    $env:JAVA_HOME = $nativeJdk
    $env:PATH = "$nativeJdk\bin;" + $nativeOldPath
    & $nativeHeadless $nativeProjectDir 'NativeEvents' `
        -import $nativeInput `
        -scriptPath $nativeScripts -postScript 'ReportHdBattleEventStringRefs.py' `
        -scriptlog (Join-Path $nativeReports 'battle-event-refs.log') `
        -log (Join-Path $nativeReports 'import-analysis.log') |
        Out-File -LiteralPath (Join-Path $nativeReports 'battle-event-refs.txt') -Encoding utf8
    if ($LASTEXITCODE -ne 0) { throw 'Import failed; inspect import-analysis.log.' }
} finally {
    $env:JAVA_HOME = $nativeOldJava
    $env:PATH = $nativeOldPath
}
if (-not (Test-Path -LiteralPath (Join-Path $nativeProjectDir 'NativeEvents.gpr'))) { throw 'Project was not saved.' }
if (-not (Select-String -LiteralPath (Join-Path $nativeReports 'battle-event-refs.txt') `
    -SimpleMatch 'SWD3 HD battle event string xref report' -Quiet)) { throw 'Expected event report is missing.' }
if (-not (Select-String -LiteralPath (Join-Path $nativeReports 'import-analysis.log') `
    -SimpleMatch 'REPORT: Save succeeded for: /swd3.exe' -Quiet)) { throw 'Imported program was not saved.' }
foreach ($file in @($nativeSource, $nativeInput)) {
    if ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ne $nativeHash) { throw 'Input changed during analysis.' }
}
```

#### 從事件參照追到函式並重跑報告

先讀 `battle-event-refs.txt` 中 `TARGET Battle_InputClick` 後的 `REF ... in ...`，再選擇對應的 caller 報告。以下使用已核對 SHA-256 的 4.0.5 範例；新版本先重新定位，不跳過檢查。承接前兩段變數，重跑前關閉 GUI 中的同一專案。換 session 時須重新指定原來的目錄與從 `input-fingerprint.json` 讀回版本指紋，**不要重跑建立副本的第一段**。

```powershell
$nativeBaseline = '63F1D83D8C3A756D17640D9022E19F8928741B091F0E47ABBDB22C0CCF6C9523'
$nativeRecorded = Get-Content -LiteralPath (Join-Path $nativeReports 'input-fingerprint.json') -Raw | ConvertFrom-Json
if ($nativeRecorded.SHA256 -ne $nativeBaseline -or
    (Get-FileHash -LiteralPath $nativeInput -Algorithm SHA256).Hash -ne $nativeBaseline) {
    throw 'Fixed addresses do not apply; relocate functions for this executable.'
}
$nativeReportId = 'ui-callers-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff')
Get-FileHash -LiteralPath (Join-Path $nativeScripts 'DecompileHdBattleUiEventCallers.py') -Algorithm SHA256 |
    Format-List | Out-String | Set-Content -LiteralPath (Join-Path $nativeReports "$nativeReportId-script.txt") -Encoding utf8
$nativeOldJava = $env:JAVA_HOME
$nativeOldPath = $env:PATH
try {
    $env:JAVA_HOME = $nativeJdk
    $env:PATH = "$nativeJdk\bin;" + $nativeOldPath
    & $nativeHeadless $nativeProjectDir 'NativeEvents' `
        -process 'swd3.exe' -noanalysis -readOnly `
        -scriptPath $nativeScripts -postScript 'DecompileHdBattleUiEventCallers.py' `
        -scriptlog (Join-Path $nativeReports "$nativeReportId.log") `
        -log (Join-Path $nativeReports "$nativeReportId-analysis.log") |
        Out-File -LiteralPath (Join-Path $nativeReports "$nativeReportId.txt") -Encoding utf8
    if ($LASTEXITCODE -ne 0) { throw 'Caller report failed; inspect its analysis log.' }
} finally {
    $env:JAVA_HOME = $nativeOldJava
    $env:PATH = $nativeOldPath
}
```

驗收與保存：

1. 事件報告須有欲查的 `TARGET`、實際 `REF` 地址及所屬函式；`<no defined ASCII string>`／`referenceCount=0` 是未命中，`<no enclosing function>` 是分析缺口，均不是「沒有 native 事件」的證明。
2. caller 的 `.txt` 報告須有 `SWD3 HD battle UI/input event caller report`、四個目標區塊及實際 C 反編譯內容。檢查 `<no function defined>`、`<decompilation failed: ...>`、Traceback 與分析日誌錯誤；標題存在或退出碼為零都不代表目標反解成功。分析器或偽碼若有 warning，記錄內容及影響範圍，不把有型別推測警告的片段當精確 C 原始碼。
3. 對照事件名、caller VA、呼叫前後條件、dispatcher 的實參、返回後狀態及必要的下游函式。Ghidra 偽碼不是原始碼；間接呼叫、推測型別與未解析欄位需留下限制，必要時核對原始指令。
4. 保存 exe 指紋、工具版本、腳本指紋、報告與分析日誌。引用格式依[精確證據定位](testing-and-verification.md#結論到證據的定位)：報告檔＋行號＋函式 VA／事件標記＋條件。GUI 如曾匯入其他程式、rebase 或修改分析，原 manifest 不足以識別專案狀態；應另建新目錄重做 import。
5. `.work/` 不是長期證據入口。選定支持結論的報告及 manifest 複製到對應研究的證據目錄再引用；不提交原版 exe 或 Ghidra 資料庫。仍欠遊戲內可達性／時序驗證者標為「已靜態反解」，不得升格成「已實測」。

## 標準驗收工具

可用 PowerShell 確認檔案與雜湊：

```powershell
Test-Path -LiteralPath '<artifact>'
Get-Item -LiteralPath '<artifact>' | Select-Object Length,LastWriteTime
Get-FileHash -LiteralPath '<artifact>' -Algorithm SHA256
```

這些檢查只證明產物存在及位元內容；`.ssmod` 仍須反解，Lua 仍須由 Console 與實機確認。

## 原版腳本重建與資料匯出

**工作區路徑決策，2026-09-06。** 來源 archive 使用正版遊戲安裝的 `script_index.ssmod`，版本指紋及預期檔案數見[引擎研究流程](engine-research-workflow.md#steam-hd-405-原版腳本基線)。在空的 `.work/extracted/script-index-inspect/` 放入 archive 副本，依本文件 `x` 語法解包；不要覆寫非空研究目錄。現有本機副本已搬到此位置，無需再次解包。

```powershell
# 在工作區根目錄執行；先完成上方 x 解包與指紋核對。
& '.\docs\knowledge\original-game-data\battle-balance-and-capture\Build-OriginalBalanceData.ps1' `
  -SourceRoot '.\.work\extracted\script-index-inspect\out_data' `
  -OutputRoot '.\.work\balance-export-check'
```

`-SourceRoot` 預設為上述隔離來源；`-OutputRoot` 省略時會寫入資料集 `generated/`，驗證時必須明確傳入獨立目錄。匯出器只讀原版 Lua／文字並透過既有 Fengari 產生 UTF-8 CSV；確認 PASS、CSV 數量與來源 manifest，不能把資料匯出成功當實機戰鬥驗收。

## Loader 研究包裝器

從工作區根目錄呼叫；`-GameRoot` 必填，`-ReuseAnalysis` 選用。它定位包含 AGENTS 與 docs/knowledge 的祖先目錄，再使用其 `.tools/static-re`；不依賴探針直接位於根目錄。它會建立 native-analysis 副本、報告與 Ghidra 資料庫，方法及副作用見[loader README](../../research/active/swd3-native-loader-probe/README.md)。

**來源核對，2026-09-06：** 此包裝器額外要求遊戲目錄內同時有 `swd3.exe`、`SWD3Works.exe`、`Steamworks.NET.dll`，以及 Windows PowerShell 的 .NET Framework 反射環境、CPython 3（其 `Get-PeImports.py` 只用標準庫）、指定路徑的 Ghidra 11.4.3／JDK 21。它會覆寫自身 `native-analysis/input/` 的三份副本及固定報告；`-ReuseAnalysis` 使用 `-process -noanalysis`，目前**沒有** `-readOnly`，不能宣稱分析資料庫不保存變更。它未核對舊資料庫內程式是否與新複製檔案同 hash；因此不可跨 exe 版本復用，也不應用它代替上方首次事件分析流程。需要保留舊結果時先在研究目錄保存證據，使用新的隔離分析目錄重新 import。

```powershell
& '.\research\active\swd3-native-loader-probe\scripts\Invoke-LoaderStaticAnalysis.ps1' -GameRoot '<game-root>'
```

## 文件連結檢查

```powershell
python '.\docs\tools\check-docs.py'
```

從工作區根目錄執行；僅需 Python 標準庫，唯讀檢查維護範圍內 Markdown 的相對檔案／圖片連結、標題錨點與來源行號，失敗回傳非零。`--root <workspace>` 可指定其他工作區。會略過 fenced code、外部 URL、本機快取及產物；包含 research/archive 的研究證據，不掃根 archive 的安全備份。它不請求網頁，也不宣稱驗證外部網址內容。
