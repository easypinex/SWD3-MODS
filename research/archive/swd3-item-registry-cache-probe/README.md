# 原生物品索引快取探針

> 歷史實驗：本頁保存所列版本的操作與證據。是否重用、知識去向及未解問題，先查[研究清冊](../../README.md)；通用能力依[知識庫](../../../docs/knowledge/README.md)，不因歸檔或 mock 通過擴張為正式支援。

本專案只測試一個問題：原版 `GameData.SendItemTempData()` 是否會將執行期加入的完整活物卡範本，同步到 Lua 可見的 `GameData._ItemTemp` 與 `GameData._Race` 索引，並讓原生物品欄可安全反白該卡。

它不涉及收妖、戰鬥、劇情、掉落或保存資料。測試卡是複製原版黏怪卡（ID `101`）後建立的 ID `9002`，故與已否決的收妖探針 ID `9001` 分開。原版 cache 函式的可見實作來自 Steam HD 4.0.5 `GameData_cFunction.lua`。

## 已實測結論

**已否決路徑。** 在 Steam HD 4.0.5 實機中，Console 已確認 `SendItemTempData()` 後 `_ItemTemp`、`_Race` 都含 ID `9002`（`itemCache=true, raceCache=true`）；F11 加入一張完整複製的原版卡後，原生物品欄第一次反白該卡仍立刻閃退。這表示 Lua 層的索引重建無法補齊 native 物品註冊／快取，不能作為新增正式活物卡的解法。測試後未保存，存檔未受影響。

## 安全規則

- 只啟用本探針；不要與已否決的全魔物收妖探針同時啟用。
- 使用可丟棄的測試存檔；**按 F11 加卡後絕不存檔。**
- F12 會移除所有 ID `9002`，但若反白測試造成閃退，直接結束程序即可；不要重新讀取或保存含卡的狀態。
- 停用前在不開物品欄的安全地圖按 F12，確認 Console 顯示 `removed=0` 或更高的數量。

## 實機步驟

1. 以完整重新啟動的遊戲進入獨立測試存檔，確認 Console 出現 `rebuild complete: ... itemCache=true, raceCache=true`。
2. 在安全地圖按 **F11**。Console 應顯示 `added one ID 9002`。
3. 開啟物品欄，僅將反白移到「黏怪・索引探針卡」一次。
4. 若沒有閃退，記錄名稱、說明、分類與 Console；先離開物品欄，再按 F12 清除，且不存檔。
5. 若閃退，**不要**再測同一方向；關閉遊戲、維持探針停用／使用原本 MOD 清單。這代表 Lua 索引重建不足以修復 native 物品註冊。

## 判讀

| 結果 | 結論 |
| --- | --- |
| `_ItemTemp`／`_Race` 均含 `9002`，反白安全 | 僅證實此版本的 cache rebuild 值得延伸測卡；存檔、護駕仍須獨立驗證。 |
| Lua cache 含 `9002`，反白仍閃退 | **已實測**：native UI 使用尚未被 Lua 重建的註冊／快取；此路徑否決。 |
| `SendItemTempData` 失敗或快取不含 `9002` | Lua cache rebuild 本身不可用；此路徑否決。 |

## 自動檢查與封裝

```powershell
.\tests\run-tests.ps1
```

封裝、反解與雜湊驗證依[封裝與安裝](../../../docs/knowledge/packaging-and-installation.md)進行。這是研究探針，不可發布或加入工作坊。
