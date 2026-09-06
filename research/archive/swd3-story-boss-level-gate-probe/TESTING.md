# 測試紀錄

## 自動檢查

`./tests/run-tests.ps1` 檢查 Lua 語法與 mock：F6 先套用資格／等級／生存欄位、敵人初始化看到 Lv1，原生收妖候選只在戰後依基線交換 ID `10017`，並精確還原原始欄位。

## 實機驗收

- F6 建立 `SBLGP_CHIYOU_LEVEL`；Console 記錄 Lv80 → Lv1。
- `Battle_EnemyInit` 記錄 `NPCData.Level=1`。
- 靈契對蚩尤的紅色 X 結果。
- 收服後 Console 記錄來源 ID `46` → 靜態卡 ID `10017`，物品欄反白安全。
- 離場後 `ItemTemp[46].Level=80`，且 `IT_12`、`IT_06`、`Race.catch`、ATK／SPD／技能表都還原。

### 已通過：蚩尤可選取

**Steam HD 4.0.5，2026-09-03。** Console 記錄來源 ID `46` 在開戰前由 Lv80 暫設 Lv1，並在 `Battle_EnemyInit` 確認戰鬥副本 `NPCData.Level=1`。使用者確認蚩尤可用靈契選取。第一次戰鬥因首領先手而全滅，但 `Battle_RestoreItem` 已記錄來源等級還原 Lv80；此後重入亦確認相同 bridge 生效。未完成收服、未新增物品、未保存。

### 已通過：蚩尤收服、交換與物品欄反白

**Steam HD 4.0.5，2026-09-03，v0.2。** 探針暫設資格、Lv1 與生存欄位後，原生 `Battle_Dead(mode=2)` 觀察到兩次；原生新增 ID `46` 及正常掉落 ID `994`。`Battle_RestoreItem` 時，探針只移除高於開戰前基線的一張 ID `46`，加入靜態卡 ID `10017`，Console 記錄 `capture exchange confirmed`。使用者以方向鍵反白 `10017`，名稱／資訊正常，未觸發裝備；來源 ID `46` 已還原 Lv80。遊戲隨即關閉且未保存。

### 已通過／受限：ID `10017` 存檔與停用

**Steam HD 4.0.5，2026-09-03。** ID `10017` 存入第 1 格後，完整重啟、讀檔與物品欄反白均正常。停用靜態卡庫與本探針後讀同一格，遊戲可進地圖但 ID `10017` 不顯示；本輪未保存。重新啟用後重讀原存檔，ID `10017` 恢復並可反白。故持有首領靜態卡的存檔不能安全停用卡庫，也不可在卡片消失的狀態保存。

## 封裝驗收

- **已通過，2026-09-03。** 成品 SHA-256：`AA6EF31846A77B06057ABAAA2AE0A689513B26D890CCFEEC6A3638B3D9CF633E`。
- **已通過，2026-09-03。** 反解 manifest SHA-256：`36CB33DA05D20EE244DB3CA7004D366FD5567343E5B23D7CA6D2BBC3A98EC059`；Lua SHA-256：`4AC57260EE9ACB6099DD1207AA4A5D2C971FC080FCCB51D7DBDEB590A1CFE1AA`，皆與來源一致。
- **已通過，2026-09-03，v0.2。** 成品 SHA-256：`993BD18DEC3A027B55687258D22574A0AED00F4B9644BEF61EF139AB8AC797BC`；反解 manifest SHA-256：`7AE301984B1FC98A970975C3E41819AAB80AB83C0418DCEFB54FC466371E7784`、Lua SHA-256：`286CB1F824398FD1B2C691ED52E44DB5AF20ECEA59489EDDEEE8834E8D2EA5D8`，皆與來源一致。
