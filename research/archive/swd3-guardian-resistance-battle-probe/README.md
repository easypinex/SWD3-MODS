# 護駕戰鬥抗性探針

> 歷史實驗：本頁保存所列版本的操作與證據。是否重用、知識去向及未解問題，先查[研究清冊](../../README.md)；通用能力依[知識庫](../../../docs/knowledge/README.md)，不因歸檔或 mock 通過擴張為正式支援。

## 目的

驗證 Steam HD 4.0.5 的護駕欄雖會套用 `Add*` 能力值，卻不會原生套用活物卡 `Attr*` 抗性時，能否在 `Battle_EnemyInit` 後、`Battle_PlayerInit` 前暫時把已裝備靜態契靈卡的抗性橋接到原版角色來源 `ItemTemp[玩家ID]`。

這是獨立研究探針，不是正式全魔物卡庫的一部分。它不建立卡片、不讀寫 `SaveData` 新欄位；只在玩家初始化前暫改對應 `GameData.ItemTemp[玩家ID]` 的 `Attr*`，並在戰後、切圖與重啟時精確還原。它不保存或長駐修改地圖角色資料。

## 前置與操作

1. 啟用正式 `swd3_all_monster_static_capture.ssmod` 與本探針，完整重啟遊戲。
2. 將一張新靜態契靈（ID `10001`–`10097`，例如蚩尤 `10017`）裝入護駕欄。
3. 保持蚩尤裝備，先按 `F6` 建立一場單隻原版食人花（ID `189`、Lv28）的毒屬性戰。F6 僅為驗證而暫時覆寫毒抗為原版上限 `AttrPoison=-10`（100%）；Console 必須顯示 `source bridge applied before player init`。
4. 記下一次食人花打中賽特的非暴擊傷害後結束戰鬥；不要卸下蚩尤。
5. 仍保持蚩尤裝備，按 `F5` 建立相同戰鬥。Console 必須顯示 `source bridge intentionally suppressed for the F5 baseline`；這一場保留同一張卡的全部 `Add*` 能力值，只停用暫時的 `Attr*` source bridge。
6. 記下同樣的非暴擊傷害。F5 傷害應高於 F6；離開戰鬥後不應有任何地圖或存檔殘留。

蚩尤 `10017` 的 v1.1 正式規格仍是暗抗 `-6`（60%）與毒抗 `-4`（40%）。F6 探針只為放大測試效果，會暫時寫入 `AttrPoison=-10`（100%）；戰後精確還原，不會修改正式卡片或存檔。

## 成功與停止

- **成功條件**：同一張已裝備卡在 F6／F5 兩場戰鬥中的唯一設計差異是 source `Attr*` bridge；Console 顯示正確寫入與戰後還原，且可用同屬性攻擊確認 F6 傷害較低。
- **失敗條件**：沒有 `applied` 訊息、訊息數值錯誤、傷害未降低、戰後狀態殘留或任何閃退。
- **停止方式**：在 MOD 管理停用本探針並完整重啟。它沒有需要清除的存檔資料。

## 證據狀態

- **已實測**：正式卡庫的 `Add*` 九維能力在護駕欄生效；卡片 `Attr*` 抗性沒有生效。
- **已否決路徑**：`Battle_PlayerInit` 時 `BattlePlayers[index].CharData` 尚不可用；實機 Console 會記錄 `CharData is unavailable`。
- **已否決路徑**：`Battle_Enter` 時 `BattlePlayers[index].CharData` 仍不可用；實機 Console 會記錄 `CharData is unavailable`。
- **已否決路徑**：`Battle_DrawBGI` 以追加 handler 註冊未在原生戰鬥觸發；此事件由原版 `.main` 處理，不是可依賴的追加時點。
- **已否決路徑**：`Battle_PlayerInit`、`Battle_Enter`、`Battle_DrawBGI` 與 `BattlePlayerAI_after` 的可用 Lua 時點皆未能取得可寫的 `BattlePlayers[index].CharData`；不再對戰鬥角色副本直接寫入。
- **已否決路徑**（Steam HD 4.0.5，2026-09-04）：`ItemTemp[玩家ID].AttrPoison` 在玩家初始化前可暫寫為 `-10` 並在戰後還原，但食人花毒屬性測試未顯示可用的免傷效果；不可作為護駕抗性方案。
