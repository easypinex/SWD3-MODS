# 狀態保存與資料安全

## 全域偏好與每存檔資料

| 需求 | 儲存位置 | 注意事項 |
| --- | --- | --- |
| 跨存檔的使用者偏好 | `Setting` | MOD Lua 可能早於 `Save/setting_v2.lua` 載入，不要在檔案頂層假設值已存在。 |
| 單一存檔的功能資料 | `SaveData.<ModNamespace>` | 使用 MOD 專屬命名空間，測試不同存檔不互相污染。 |
| 純 UI 暫態 | 記憶體中的 MOD 狀態 | 沒有必要不要保存；重啟回到明確預設。 |

讀取 `Setting` 應放在已確認設定載入完成的事件。熟練度 MOD 的 [4.0.5 載入順序紀錄](../../swd3-proficiency-multiplier-mod/PACKAGING-NOTES.md#sysinit4-專案例外)是 `SysInit[4]` 的專案例外來源；一般掛接方式見 [Lua 事件與相容性](lua-events-and-compatibility.md#sysinit-與載入時序)。單一存檔資料的既有範例為煉化 MOD 的最近戰鬥等級；[自動檢查](../../swd3-refinery-diagnostics-unlock-mod/TESTING.md#自動檢查)只證明 mock 寫入各存檔表，不補齊完整重啟／載入矩陣。

遊戲內建 manifest 的註解指出：`MODbundleSave 0` 會記錄在 Save、`1` 不綁 Save、`2` 使 Save 永久要求 MOD。無論欄位值為何，只要 MOD 讀寫持久資料，都要驗證全新存檔、既有存檔、不同存檔、停用和重新啟用。

## 原版 Lua 序列化器的資料邊界

狀態：**官方檔內說明**，來源為 [Steam HD 4.0.5 腳本基線](engine-research-workflow.md#steam-hd-405-原版腳本基線)的 `GameData_cFunction.lua`；重建方式見[原版腳本重建](tools-and-commands.md#原版腳本重建與資料匯出)。以 `GameData.SendAllSaveData`、`SendSettingData`、`SendCommonSaveData` 定位它們共用的遞迴輸出器；以下僅描述該 Lua 實作可表示的資料形狀：

- key 只保留 `string` 或 `number`；其他 key 型別會略過。
- value 只保留 `table`、`number`、`boolean` 或 `string`；function、userdata、thread 等會略過。
- 空 table 不會輸出；重新載入後不能依賴「存在但為空」和「完全不存在」的差異。
- 數字 key 會寫成 `[n]`；字串 key 直接寫成未加括號的 Lua 欄位名。因此持久化 namespace 與欄位名應使用合法 Lua 識別字，不用空白、連字號、標點或使用者輸入作 key。
- 原版程式直接把字串包進雙引號，該 Lua 層沒有處理引號、反斜線或換行的跳脫。除非另有實機證據證明外層會處理，持久資料不要保存未清理的任意文字；優先保存數字、布林與受控 enum／短字串。

這些是原版 Lua 實作可見的限制，不等同已完成所有存檔檔案格式與 native 寫入流程的實測。新資料結構仍需做存檔、完整重啟、載入與停用矩陣。

## 暫改遊戲資料

**專案安全決策。** 需要短暫修改 `GameData`、物品範本或其他原版物件時，先界定它供哪個原生流程讀取，再選擇還原時點。下列是設計約束，不宣稱每個清理事件在所有情境都會觸發。

1. 在修改前保存原值，不從已修改值反推。
2. 同一操作內，同一物件／欄位只保存一份原始快照，不讓重入覆蓋基線。
3. 開始新的獨立操作前先完成前次清理；同一次操作若須跨 callback 維持值，不提前清除。
4. 列出正常完成、取消、錯誤、切圖、讀檔及重啟中實際適用的離開路徑，逐項確認可用的清理入口與重入安全。
5. 使用 `xpcall` 或等效錯誤保護，錯誤路徑也必須還原；此保護不能替代原生崩潰或未觸發事件的驗收。
6. 提供只讀診斷入口，能確認目前仍有多少物件處於暫改狀態。

### 依用途選擇還原時點

| 用途 | 還原界線 | 證據與可用範圍 |
| --- | --- | --- |
| 僅供選單預覽的判定資料 | 依已測預覽流程在繪圖後還原；下一次預覽及正式確認前再確保原值。 | 煉化 MOD [運作原理](../../swd3-refinery-diagnostics-unlock-mod/README.md#運作原理)是專案契約；[2026-09-01 mock 結果](../../swd3-refinery-diagnostics-unlock-mod/TESTING.md#自動檢查)驗證還原。原生完整驗收仍依該 TESTING，不能外推為每種 UI 的同幀保證。 |
| 供戰鬥資格或結算讀取的來源／live 資料 | 必須涵蓋所需原生讀取階段，完成後才還原；不能套用「正式操作前一律還原」。 | [4.0.5 目標確認 live gate](../../research/active/swd3-native-menu-probe/NATIVE-CAPTURE-RESEARCH.md#已靜態反解靈契目標確認讀取-live-boss-bit並非只靠戰鬥初始快取)反證提前還原可使收妖無法提交；實際窗口與風險依[原生靈契](native-capture-and-eligibility.md#賽特輸入窗口的證據邊界)，不據此承諾任意旗標可安全暫改。 |
| 背包物品預留 | 保留至本次挑戰完成或放棄，只釋放本 MOD 增加的份額。 | [預留與釋放](battle-and-inventory-lifecycle.md#stock-預留規則)維護算法；挑戰 MOD 的 [mock 規格](../../swd3-live-card-battle-mod/TESTING.md#一鍵自動測試)與[實機矩陣](../../swd3-live-card-battle-mod/TESTING.md#實機驗收)分開，不把列出的退出路徑視為全部已通過。 |

需要逐次傷害後還原時，先查[戰鬥時序](battle-events-and-timing.md#對-mod-設計的直接規則)。目前沒有可依賴的通用非致死傷害完成 callback；不能用繪圖、timer 或下一名角色的 after 猜測結束點。

任何倍率或衍生值切換都應從保存的原始值重新計算，避免反覆切換累積誤差。

## 尊重原版交易與獎勵流程

不要複製原版的合成、扣料、加物品、戰鬥結算或獎勵流程。若只需繞過預覽判定，應在最小時間窗調整判定資料，正式確認前還原，讓原版繼續處理：

- 背包容量與唯一物品。
- 材料扣除和成品增加。
- 動畫、Steam 統計與成就。
- 戰鬥經驗、金錢與一般掉落。

## 發布阻斷條件

發現資料未還原、跨存檔污染、重複扣料／獎勵、正式數值被測試值覆蓋，或停用後無法安全載入存檔時，該版本不得發布。
