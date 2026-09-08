# UI、輸入與原生選單

## 公開繪圖與輸入邊界

**既有實測摘要，Steam HD 4.0.x；原紀錄未保留精確小版本、日期及完整 Console。** [UI 盤點結果](../../research/active/swd3-native-menu-probe/ENGINE-UI-RESEARCH.md#已排除或未公開)列出的 `DrawFunc` 項目只有 `Color`、`DrawTSW`、`GetTSWSizeWH`，`EditLayer` 與 `MenuFunc` 為 `nil`。本次盤點範圍未建立矩形、任意 PNG、圖層或更晚 overlay callback 的可用證據；不得外推成全部 HD 版本不存在這些能力。名稱存在只證明可見，不代表呼叫安全。

**已否決路徑，限活物挑戰舊版自繪物品欄面板。** [專案限制紀錄](../../swd3-live-card-battle-mod/TESTING.md#已知引擎限制與安全行為)記載 `OnEvent.InputClick` 回傳 `true` 仍不能阻止物品欄輸入；該條未保留失敗版號、日期及完整 trace，不能套用現行 v0.6 版號。它足以否決沿用此回傳值作阻擋保證；其他 UI 的 consume 契約仍待驗證，自繪面板須逐頁實測。

**待驗證／專案選型。** 上述盤點未提供已驗證的滑鼠按住查詢方式；這不證明 API 不存在。離散選項可採明確節點點擊，連續拖曳須另找輸入證據。

## 已驗證的座標式 UI 基元

下表是現有專案的讀取／繪圖用法，實作定位為[已移除的熟練度 v1.2 面板紀錄](../../swd3-proficiency-multiplier-mod/PACKAGING-NOTES.md#點擊穿透風險)中的 `InputFunc.MouseX`、`DrawFunc.Color`、`StringFunc.DrawString`；該專案的 [4.0.5 實測基線](../../swd3-proficiency-multiplier-mod/PACKAGING-NOTES.md#實測基線)與[逐頁點擊待驗收](../../swd3-proficiency-multiplier-mod/PACKAGING-NOTES.md#點擊穿透風險)分開記錄。來源用法不等於各解析度、透明度與輸入頁面均已驗收。

| 目標 | 用法 | 注意事項 |
| --- | --- | --- |
| 游標座標 | `InputFunc.MouseX`、`InputFunc.MouseY` | 僅在相關選單實機測試；先用面板是否剛繪製的狀態限制命中範圍。 |
| 色彩 | `DrawFunc.Color(r, g, b, a)` | 使用明確 RGBA 值；alpha 的實際視覺結果仍以遊戲測試為準。 |
| 文字 | `StringFunc.DrawString(text, x, y, font, color, shadow, 1)` | 現有 MOD 的已觀察參數樣式；字型、截斷與解析度都需實測。 |

命中測試應先檢查 UI 是否處於正確選單與有效時間窗，再檢查矩形／節點邊界，最後才改變 MOD 狀態。`InputClick` 目前沒有可靠 consume 契約，因此任何可點面板都要逐頁驗證底層操作不會被誤觸。

## 鍵盤事件、旗標與時間窗

狀態：**官方檔內說明**。Steam HD 4.0.5 原版 `ScancodeDefine.lua` 會建立 `SCANCODE` 與 `DefineKeyFunc`；`Setting.lua` 另建立 `Const.KeyFunc_*` 索引。能使用 table 時優先比較具名值，例如 `SCANCODE.END`，不要在每個 MOD 各自抄一份完整數字表。

完整 scancode 數值表不在本知識庫複製；新增按鍵時先查原版 `SCANCODE.<名稱>`，再做目標鍵盤實測。`DefineKeyFunc` 是稀疏 table，不能用 `#DefineKeyFunc` 推定範圍，也不能假設每個 `Const.KeyFunc_*` 都有值；使用前逐項檢查 number。

**專案決策＋mock 驗證。** 若規格要求實體 End，煉化 MOD 同時檢查功能旗標與 scancode `77`；[2026-09-01 自動檢查紀錄](../../swd3-refinery-diagnostics-unlock-mod/TESTING.md#自動檢查)確認 mock 的 End 會觸發、右 Shift 不觸發。這是目前可精確定位的證據，不等同各鍵盤／映射的實機結果；原版符號查核使用 [4.0.5 腳本基線](engine-research-workflow.md#steam-hd-405-原版腳本基線)的 `ScancodeDefine.lua`／`SCANCODE.END`。

現有煉化 MOD 已觀察 `OnEvent.InputKeyDown(keyFuncFlag, keyScancode)`：第一個值可包含映射功能鍵的 bit flag，第二個值才是實體鍵 scancode。可先從 `Const.KeyFunc_*` 取得功能鍵索引，再由 `DefineKeyFunc[index]` 取得旗標；兩者任一 table／值不存在時，安全地不觸發。

```lua
local function hasFlag(value, flag)
    return type(value) == 'number'
        and type(flag) == 'number'
        and flag > 0
        and value % (flag * 2) >= flag
end

-- 只有規格確實要求「實體 End 鍵」時才同時檢查兩者。
local endFlag = DefineKeyFunc and Const and DefineKeyFunc[Const.KeyFunc_End]
if keyScancode == 77 and hasFlag(keyFuncFlag, endFlag) then
    -- handle physical End
end
```

原版 `OnEvent_Input.lua` 將 `InputKeyDown`、`InputKeyUp`、`InputClick`、`InputDClick` 的 `.main` 都定義成 `(KeyFunc_flag, Key_SCANCODE)`；這是**官方檔內說明**，不是四種事件都已實機驗證。現有正式功能仍只依賴已測過的 `InputKeyDown`／`InputClick` 路徑；`InputKeyUp` 與 `InputDClick` 應先做隔離探針。

**專案用法，時間單位待驗證。** [已移除的熟練度 v1.2 面板紀錄](../../swd3-proficiency-multiplier-mod/PACKAGING-NOTES.md#點擊穿透風險)的 `GetTicks` 呼叫用於繪製後的點擊有效窗與快捷鍵 debounce。呼叫前檢查它是否為 function；以相對差值比較，且把門檻當成專案 UX 參數。其精確時間單位尚未獨立驗證，不要把數值標成毫秒的引擎保證。

快捷鍵要與其他 MOD 一起測試，並在相關選單、地圖、戰鬥和對話狀態確認觸發範圍。

## `DrawMenuAfter` 狀態

**專案決策＋mock 驗證。** 煉化面板在預覽停止重算後仍需持續顯示，見[自動檢查結果](../../swd3-refinery-diagnostics-unlock-mod/TESTING.md#自動檢查)。因此 `DrawMenuAfter` 繪製已存在狀態，面板由開啟、取消、正式操作、換圖、戰鬥與錯誤事件控制壽命；此案例不提供原生預覽 callback 的逐幀頻率保證。

使用覆蓋式面板前必須驗證：

- 不遮擋或誤觸底層功能。
- 不在其他選單、地圖或戰鬥殘留。
- 不逐幀輸出 Console。
- 不依賴未公開的輸入 consume 行為。

## 原生選單 coroutine

**既有實測摘要，Steam HD 4.0.x。** 以下用法、列索引、空白返回、Esc 無反應及物品欄暫態重建，逐項見[原生選單案例第 1～7 項](../../research/active/swd3-native-menu-probe/ENGINE-UI-RESEARCH.md#已實測escmenu-原生選單-coroutine)。原紀錄未保留精確小版本及完整原始 Console；只沿用所列選單／操作範圍。

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

已確認規則：

1. `ESC.Menu` 必須在 `GameFunc.RunScene` 建立的場景 coroutine 中使用；直接從輸入 callback 呼叫不能形成可靠的持續 UI。
2. 已驗證前兩個參數為標題字串（早期探針傳入 `0`，因而畫面顯示標題 `0`）與字串陣列；參數不足會回報 `Menu Error: Not enough arguments.`。
3. `ESC.Menu` 會等待原生輸入，下一行在選取或取消後繼續。
4. `ESC.GetMENUSelect()` 的列索引從 1 起算；點選空白區回傳 `0`，必須視為安全返回。
5. 方向鍵、確認鍵與滑鼠列選取可用；點選選單空白處會回傳 `0`。`Esc` 已實測無反應，也不會進入 Lua 的 MOD 事件記錄；它不是目前可用的返回快捷鍵。
6. 從物品籃進出原生場景後，反白、分類與使用中暫態會重建，背包內容不變；尚無已驗證的公開 API 可復原這些暫態欄位。

行數／字串長度上限及所有巢狀場景組合仍需按專案實測。中文列尾修正的條件見[文字案例](../../research/active/swd3-native-menu-probe/ENGINE-UI-RESEARCH.md#escmenu-的已知不適用情況)，不能由英文選單成功推定中文安全。

## 選型原則

**已實測的受限修正，HD4.0.5，2026-09-07：** 四人測試開局v0.2在提示後先開原生`ESC.SaveMenu()`，使用者已通過取消後Esc開選單／四人人數回歸，並首次保存。這支持原生存檔畫面可補齊此起點的共用邊框初始化；不代表任意選單都需先開存檔畫面，亦未補足重讀／停用矩陣。版本、實際安裝hash與Console見[首次通過紀錄](../../research/active/swd3-cai-test-start/TESTING.md#v02-選單與首次保存通過)。下段保留v0.1反例及修正前的研究背景。

**已人工回報失敗＋崩潰檔／靜態定位，HD4.0.5，2026-09-07：** 四人測試開局v0.1略過原版序章，`ESC.Menu`提示可正常顯示及關閉，隨後按Esc進物品頁卻因共用邊框TSW快取為0而崩潰。原生提示選單通過不能代替其後角色／物品介面的初始化驗收。反例、exe指紋、原生存檔列會先載入共用ACT的靜態路徑，與v0.2修正候選邊界見[測試開局研究](../../research/active/swd3-cai-test-start/TESTING.md#v02-esc崩潰修正候選)；尚未證明所有自訂起點需要同一處理。

- 需要 modal 鍵鼠操作時，優先評估已驗證的原生 `ESC.Menu`。
- 若原生選單沒有已驗證的鍵盤取消鍵，子選單應把「返回上層」同時放在首列與末列，並縮短資料頁面；可再以標題提示「點選空白處返回」。不要把未驗證的 Esc 當成替代方案。
- 只需資訊顯示且能接受穿透風險時，才評估 `DrawMenuAfter` 自繪。
- 劇情對話函式從輸入 callback 直接建立持續 modal 的失敗，見[盤點反例](../../research/active/swd3-native-menu-probe/ENGINE-UI-RESEARCH.md#已排除或未公開)；中文按鈕首層可見但無法進第二層的另一案例，見[原版腳本對照](../../research/active/swd3-native-menu-probe/ENGINE-UI-RESEARCH.md#原版腳本對照中文按鈕格式尚未可直接取代選單)。兩者只否決所測上下文，不否決原版劇情中的合法呼叫。
