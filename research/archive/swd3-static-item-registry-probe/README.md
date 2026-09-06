# 靜態物品註冊探針

> 歷史實驗：本頁保存所列版本的操作與證據。是否重用、知識去向及未解問題，先查[研究清冊](../../README.md)；通用能力依[知識庫](../../../docs/knowledge/README.md)，不因歸檔或 mock 通過擴張為正式支援。

本專案只驗證一個問題：Steam HD 4.0.5 是否會在 MOD `DAT 2` 腳本載入後、建立 native 物品註冊／快取前，接受一張新的完整活物卡。

這不是收妖 MOD，也不是正式卡庫。探針在 Lua 檔案的**頂層載入期**複製原版黏怪卡 `ItemTemp[101]`，建立 ID `9003`；和已否決的 ID `9001`／`9002` 不同，它不等 `GameStart`、不按鍵注入、不呼叫 `GameData.SendItemTempData()`。F4 才會將一張卡放進背包，供一次原生反白測試。

## 已實測結論

**已實測，Steam HD 4.0.5，2026-09-03。** F4 成功加入 ID `9003` 後，原生物品欄可正常反白「黏怪・靜態註冊探針卡」，名稱與說明正常顯示且沒有閃退。這證明 MOD `DAT 2` 的頂層載入期建立新 `ItemTemp`，與先前 `GameStart`／按鍵時才加入的方式不同，能讓 native 物品欄安全註冊該新 ID。

此結論只涵蓋一張卡的載入與物品欄反白；存檔、護駕、收妖交換及批量卡仍須各自驗證。

## 安全規則

- 只啟用本探針；停用全魔物收妖與快取重建探針。
- 使用可丟棄的測試存檔；按 F4 後**絕不存檔**。
- 一次完整啟動只測一次反白。若閃退，不重試，關閉遊戲即可。
- 若反白安全，先離開物品欄，按 F3 清除 ID `9003`，確認 Console 顯示 `removed=1`，且不保存。

## 實機步驟

1. 完全關閉遊戲，啟用本 `.ssmod` 後重開；先開 SS2DConsole。
2. 進入安全地圖的測試存檔，確認 Console 出現：`load-phase result: card=true, itemCache=... , raceCache=...; no cache rebuild was called`。
3. 按 **F4**，確認 `F4 added one ID 9003`。
4. 開啟物品欄，僅移動反白到「黏怪・靜態註冊探針卡」一次。
5. 安全：記下 `itemCache`／`raceCache`、名稱與說明；離開物品欄，按 F3 清除，不存檔。
6. 閃退：不保存、不再測同方向；這表示 MOD 的頂層 Lua 載入仍不足以完成 native 物品註冊。

## 判讀

| 結果 | 結論 |
| --- | --- |
| `card=true`、快取含 `9003`，且反白安全 | **已實測**：可延伸的「MOD 載入期靜態卡」候選；存檔、護駕、批量卡仍待驗證。 |
| `card=true`，但 Lua 快取不含 `9003` | MOD 腳本已在 native／Lua cache 之後載入；此靜態載入期路徑否決。 |
| `card=true`、快取含 `9003`，反白仍閃退 | native 註冊不接受 MOD 新 ID；此路徑否決。 |
| `card=false` | 原版資料尚未存在或 ID 被占用；記錄 Console 後停止。 |

## 自動檢查與封裝

```powershell
.\tests\run-tests.ps1
```

封裝、反解與雜湊驗證依[封裝與安裝](../../../docs/knowledge/packaging-and-installation.md)執行。此為研究探針，不可發布或加入工作坊。
