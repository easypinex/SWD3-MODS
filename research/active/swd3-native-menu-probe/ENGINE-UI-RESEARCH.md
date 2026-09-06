# SWD3 原生選單／對話按鈕 Coroutine 研究證據

研究範圍：Steam 高清版 4.0.x。可供其他 MOD 採用的摘要規則見 [UI、輸入與原生選單](../../../docs/knowledge/ui-input-and-native-menu.md)；本文件保存探針步驟、原始觀察及未解問題。

> 本文件僅保留選單／文字證據；收妖與傷害反解已移至 [NATIVE-CAPTURE-RESEARCH.md](NATIVE-CAPTURE-RESEARCH.md)。歷史操作與待測條件按所列版本判讀。

## 早期證據的版本缺口

下列 UI 案例是既有實測的文字摘要；原紀錄僅標 Steam HD 4.0.x，未逐案保存精確小版本、探針版號、測試日期或完整 Console／截圖。本次文件整理沒有新增實機結果，也不以同專案後來的 4.0.5 native 反解指紋替這些 UI 案例補版本。重跑工具見 [README 測試步驟](README.md#測試步驟)，新版／不同 UI 情境仍須重新記錄。

## 已實測：`ESC.Menu` 原生選單 coroutine

```lua
function Scene.MyScene()
    ESC.Menu('MENU TITLE', {
        '1  FIRST ROW',
        '2  SECOND ROW'
    })
    local selection = ESC.GetMENUSelect()
end

GameFunc.RunScene(-1, 'MyScene', 0)
```

觀察：

1. 直接從 `OnEvent.InputClick` 呼叫 `ESC.Menu` 會失敗或無法維持 UI；先由 `GameFunc.RunScene(-1, 'Scene 函式名', 參數)` 進入 coroutine 後可用。
2. `ESC.Menu` 需要標題文字與字串陣列；少於兩個參數回報 `Menu Error: Not enough arguments.`。早期探針傳入 `0`，原生 UI 會直接顯示為標題列的 `0`；不可再把它記為 GUID。
3. `ESC.Menu` 等待原生輸入，場景函式下一行在玩家選取或取消後繼續。
4. `ESC.GetMENUSelect()` 為 1 起算；第二列回傳 `2`、第三列回傳 `3`。
5. 點選選單空白區域回傳 `0`。方向鍵、確認鍵與滑鼠列選取可用。
6. **Esc 已實測無效。** `selected=0` 的 Console 記錄來自點選空白處；之後在選單中只按 Esc，畫面沒有反應，且 MOD 沒有收到任何事件記錄。因此不得把 Esc 列為返回快捷鍵或從 Lua 呼叫 `DLGClose`。
7. 從已開啟的物品籃進出原生場景後，物品籃以初始暫態重建：反白、分類與使用中狀態不保留；背包內容沒有改動。

## 原版腳本對照：中文按鈕格式（尚未可直接取代選單）

完整原版 `Scene.lua`／`SceneSetting.lua` 使用的不是 `ESC.Menu`，而是：

```lua
ESC.Print_W(0, 9007, width, height,
    '%S0%C2標題%C4%N%B第一項.%N%B第二項.')
local selection = ESC.GetBTNSelect()
```

- `%N` 是換行，`%B` 開始一個可選按鈕，`.` 結束按鈕文字。
- 原版中文劇情與選項都走這條格式；它是調查 `ESC.Menu` 文字損壞時的主要對照來源。
- 這些呼叫位於場景 coroutine；從輸入 callback 直接呼叫對話函式的舊探針仍不成立。

活物挑戰曾改採此路徑；首層可顯示，但實機點第一層後無法進入第二層。因此不能只因原版劇情使用它，就假設可在 MOD 的嵌套選卡迴圈直接取代 `ESC.Menu`。目前已回復 `ESC.Menu`，並保留此結果作為 API 行為限制。

### `ESC.Menu` 的已知不適用情況

活物挑戰實測顯示：標題字串可正確顯示，但 `ESC.Menu` 的**可選列**會讓 UTF-8 中文尾端出現方框、缺字或額外值。這是原生 Lua bridge 對選項列尾端的已觀察行為；尚未反編譯出內部寫入原因，但已有可重現且已實機驗證的相容修正：

```lua
local MENU_ROW_UTF8_PADDING = '    ' -- 四個 ASCII 空白
table.insert(menuRows, visibleText .. MENU_ROW_UTF8_PADDING)
ESC.Menu(title, menuRows)
```

- 只在傳給 `ESC.Menu` 的**每一列選項**末尾加四個 ASCII 空白；標題不需加。
- 已觀察四個空白可使中文可見文字完整保留；「內部緩衝尾端遭寫壞」仍是待驗證的原因解釋，不能當作已反解事實。
- 任何新選項（包含動態怪物名稱、頁碼與返回列）都必須經同一個 `nativeMenu` 包裝函式；不可在呼叫端直接呼叫 `ESC.Menu`，也不可先 `trim` 結尾。
- 此規則已由活物挑戰主選單實機確認；新增不同語系、含格式字元的怪物名稱或改動該緩衝長度時，仍要重跑文字相容性驗收。

## 文字相容性：正式 UI 前的硬性驗收

**不能**因為 `StringFunc.DrawString` 或一般 `StringDB` 顯示正常，就推論 `ESC.Menu` 也會正常。`ESC.Menu` 會把標題與選項再交給原生對話文字／字型流程；繁中文字、全形標點與格式字元都要獨立實測。

建立正式功能前，以無副作用的獨立場景逐項確認：

1. 傳入標題文字後，不得出現 `0` 或其他佔位數值。
2. 顯示一列全中文（至少含 `活物挑戰`）與一列由 `StringDB` 解析的正式物品名稱。
3. 顯示帶計數的列，分別驗證 ASCII `[]`、`/` 和所有預計採用的全形標點。
4. 以鍵盤與滑鼠各選取一次，再點空白處返回；保留畫面截圖與 Console 記錄。

只要出現方框、亂碼、缺字或額外附加值，就停止 UI 整合，改用已驗證字元集或新的最小探針；不得猜測是圖片、封包或既有 `DrawString` 的問題。

## 已排除或未公開

| 項目 | 實測結果 |
| --- | --- |
| `DrawFunc` | 該次 runtime 盤點列出的項目只有 `Color`、`DrawTSW`、`GetTSWSizeWH`；不代表所有版本的完整公開能力。 |
| `EditLayer` | 執行檔有字串，但插件 Lua runtime 中為 `nil`。 |
| `MenuFunc` | 插件 Lua runtime 中為 `nil`。 |
| 劇情對話容器 | 從輸入 callback 直接呼叫 `DLG*`／`Print_SLF` 無法建立持續 modal。 |

執行檔字串只作研究線索，不因名稱存在就視為公開 Lua API。

## 待驗證

1. 不同情境下連續呼叫多層 `ESC.Menu` 的返回流程。
2. 在原生選單中再次按快捷鍵的安全返回策略。
3. 字串列的安全最大行數與單列長度。
4. 是否存在公開方式復原物品籃反白、分類與使用中暫態。

## 重現探針

來源與封包位於本資料夾。`swd3_native_menu_probe.ssmod` 只使用未綁定的 `B` 觸發，不包含活物、背包、旗標、戰鬥或存檔副作用。操作步驟見 [README.md](README.md)；完成研究後在 `Mods/modlist.txt` 設為 `0`。

活物挑戰採用多層原生選單是該 MOD 的產品決策，記錄在 `swd3-live-card-battle-mod/README.md`，不在本研究證據中維護。
