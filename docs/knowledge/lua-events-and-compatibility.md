# Lua 事件與相容性

## 常見公開事件

現有 MOD 已使用或研究的事件包括：

- `OnEvent.GameStart`
- `OnEvent.SysInit`
- `OnEvent.DrawMenuAfter`
- `OnEvent.InputKeyDown`
- `OnEvent.InputClick`
- `OnEvent.CancelClick`
- `OnEvent.MapLoading`
- 戰鬥 callback 的完整索引與相對時序見[戰鬥事件與時序](battle-events-and-timing.md)。

事件名稱存在不代表所有參數與回傳值都已文件化；使用前應在原版腳本或隔離探針中確認。

## 原版 4.0.5 事件候選索引

狀態：**官方檔內說明**。下列名稱與 signature 來自已驗證 `script_index.ssmod` 的原版 Lua；只有前節已被現有 MOD／探針使用的事件，才另有工作區實測。這份索引用來快速選擇探針目標，不代表每個事件都會巡覽追加 handler、每個參數型別已穩定，或包裝 `.main` 一定相容。

| 類別 | 原版 `.main` 定義 |
| --- | --- |
| 系統／地圖 | `SysInit()`、`GameStart()`、`MapLoading(ToMapID,x,y,ACT,QQ,DIR,Flag)`、`MapLoaded()`、`DrawMenuAfter()`、`CancelClick()`、`PlayerMove()`、`CompanyInMap(GUID,MAPID)` |
| 一般輸入 | `InputKeyDown(KeyFunc_flag,Key_SCANCODE)`、`InputKeyUp(KeyFunc_flag,Key_SCANCODE)`、`InputClick(KeyFunc_flag,Key_SCANCODE)`、`InputDClick(KeyFunc_flag,Key_SCANCODE)` |
| 煉化 | `Obsolt(itemtab1,itemtab2,doing)` |
| 戰鬥 | 完整 callback、signature、`OnEventValue` 與時序證據見[戰鬥事件與時序](battle-events-and-timing.md#原版戰鬥-callback-完整索引)。 |

`OnEvent.Battle_InputDClick` 的「只有 table、沒有 Lua 預設 handler」案例與其限制，已移至[戰鬥事件與時序](battle-events-and-timing.md#原版戰鬥-callback-完整索引)。

### `OnEventValue` 候選回傳槽

原版 Lua 會在部分 `.main` 內寫入共享 `OnEventValue`：

| 來源事件 | 原版寫入欄位 |
| --- | --- |
| `MapLoading` | `ACT` |
| `CompanyInMap` | `CompanyRange` |
| `Obsolt` | `CalcResEast`、`CalcResWest` |
| 戰鬥計算／結算 callback | 見[戰鬥事件與時序](battle-events-and-timing.md#oneventvalue-與計算-callback)。 |

這只證明原版 Lua 以這些欄位向後續流程傳值。新 MOD 若要讀寫，需先確認 callback 進出前後的清空時機、native 讀取時點、值域，以及與其他 MOD 的覆寫衝突。

## 優先追加，不覆蓋

**已靜態反解，Steam HD 4.0.5、2026-09-05。** 已分析的原生 OnEvent dispatcher 先呼叫 `.main(...)`，再巡覽追加 function；這證明該 dispatcher 的處理方式，不表示每個 native branch 都會發出事件，也不授予取消原生指令的權限。版本、位址與分析腳本見[反解證據](../../research/active/swd3-native-menu-probe/NATIVE-CAPTURE-RESEARCH.md#已靜態反解hd-戰鬥輸入與靈契命令分流)。

對事件處理器表使用連續追加：

```lua
OnEvent.DrawMenuAfter = OnEvent.DrawMenuAfter or {}
table.insert(OnEvent.DrawMenuAfter, drawMyPanel)
```

不要覆寫原版整份 `OnEvent_*.lua`，也不要無必要地取代 `.main`。若功能必須包裝既有函式，保存安裝當下的函式並呼叫它：

```lua
local previousMain = OnEvent.Obsolt.main
OnEvent.Obsolt.main = function(...)
    return previousMain(...)
end
```

包裝器必須有 MOD 專屬安裝標記，避免重複載入造成遞迴。若其他 MOD 直接覆蓋同一函式且不串接，不能宣稱完全相容，應以兩種載入順序測試並在 README 列明限制。

### 包裝器的回傳值與原版計算結果

wrapper 必須原樣回傳原函式的**所有**回傳值；只寫 `return previousMain(...)` 雖在最簡單情況可行，但一旦 wrapper 要在呼叫前後做清理、讀取結果或加入 `xpcall`，就容易遺失多回傳值。現有 Lua 相容式樣如下：

```lua
local unpackValues = unpack or table.unpack

local function pack(...)
    return { n = select('#', ...), ... }
end

local args = pack(...)
local returns
local ok, failure = xpcall(function()
    returns = pack(previousMain(unpackValues(args, 1, args.n)))
    -- 僅在原函式成功返回後，才讀取它已寫出的結果。
end, tracebackMessage)

if not ok then
    -- 先還原 MOD 暫態資料，再傳遞原錯誤。
    error(failure)
end
return unpackValues(returns, 1, returns.n)
```

範例中的 `...` 應置於實際 wrapper 函式作用域，並在進入內層 `xpcall` 函式前先封裝；若 Lua runtime 沒有 `debug.traceback`，錯誤處理器退回 `tostring` 即可。`OnEventValue` 是原版 callback 可能寫入的共享結果表；目前只在煉化 wrapper 觀察到 `CalcResEast`／`CalcResWest` 於原函式返回後可讀。其他事件、欄位與寫入時序一律先用隔離探針確認，不能當成通用 callback context。

## `SysInit` 與載入時序

已觀察到原版 `OnEvent.SysInit` 使用連續索引。稀疏的大型索引可能被只巡覽連續項目的引擎跳過，因此一般情況使用 `table.insert`。

只有在依賴明確載入順序且已確認前方索引時，才可使用固定連續索引。例如熟練度 MOD 因 Lua 早於 `Save/setting_v2.lua` 載入，使用既有 1、2、3 後的 `[4]` 讀取 `Setting`。來源為該專案 [4.0.5 的 SysInit 紀錄](../../swd3-proficiency-multiplier-mod/PACKAGING-NOTES.md#sysinit4-專案例外)，不是所有 MOD 的預設模板。

多個 Lua `DAT` 的先後順序也只能作為該專案的依賴契約。規則檔與引擎整合檔應分離：規則檔只處理可 mock 的純資料，整合檔才接觸 `OnEvent`、UI 與引擎函式；整合檔在使用相依 namespace 前應清楚失敗，而不是默默以 `nil` 繼續。

## 防禦式呼叫與可重複安裝

- 呼叫可選或尚未完整文件化的引擎 API 前，檢查 table 與 function 類型。
- 可能拋錯的引擎呼叫使用 `pcall`；包裝原函式且須清理暫態資料時，使用 `xpcall` 並在失敗路徑還原。
- 將安裝中的 wrapper 函式保存在 MOD namespace；若目前目標已是同一個 wrapper，直接返回，避免重複包裝遞迴。
- 事件 handler 也應以 MOD 專屬 `eventsRegistered` 標記防止重複 `table.insert`。
- 對關鍵快捷鍵、事件、全域表、保存 key 或戰場 ID，先查[工作區相容性登記表](../compatibility-registry.md)。

## 狀態壽命與清理

事件 callback 的出現頻率不應被當作狀態壽命。例如配方計算不一定逐幀發生，不能用短時間窗推定 UI 是否仍有效。

需要跨幀保存的暫態狀態，依[狀態保存與資料安全](state-persistence-and-safety.md#依用途選擇還原時點)界定正常完成、取消與錯誤清理。預覽、戰鬥判定及背包預留的還原時點不同；掛接 callback 前先確認該事件在目標條件下代表的階段，不能在每次繪圖或進戰時一律清除。

## 相容性驗收

- 與會觸碰相同事件、快捷鍵或資料表的 MOD 同時啟用。
- 交換兩種載入順序。
- 確認沒有 handler 被覆蓋、函式重複包裝、逐幀洗版或狀態殘留。
- 對無法組合的同一 `.main` 覆蓋，在文件中清楚標示。
