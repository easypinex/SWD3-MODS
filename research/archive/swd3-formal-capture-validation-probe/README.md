# 正式首領收妖驗證戰

> 歷史實驗：本頁保存所列版本的操作與證據。是否重用、知識去向及未解問題，先查[研究清冊](../../README.md)；通用能力依[知識庫](../../../docs/knowledge/README.md)，不因歸檔或 mock 通過擴張為正式支援。

這是低成本的**正式鏈路驗證**，不是資格／等級 bridge 探針。F4 建立一隻 HP 1、無攻擊的牛魔王；它只暫改 HP、ATK、SPD 與技能表，並在離場後還原。靈契資格、收妖等級與來源 `59 → 10024` 交換都必須由正式 `swd3_all_monster_static_capture.ssmod` v0.4 提供。

## 操作

1. 啟用正式卡庫 v0.4 與本驗證戰；其他收妖探針保持停用。
2. 完整重啟並進入地圖，確認正式卡庫 Console 有 `capture bridge armed`。
3. 按 F4，Console 應顯示 `validation battle started`；以原生靈契完成收服並確認來源資料不在地圖長駐為 Lv1。
4. 對 HP 1 的牛魔王使用靈契收服。正式卡庫必須輸出 `capture exchange confirmed: source=59, card=10024`。
5. 離場後確認本探針輸出 `battle tuning restored`，正式卡庫輸出 `capture bridge restored`；反白 `10024`。

使用獨立存檔；本驗證完成後即可停用並移除本探針。

## 已實測結果

**已實測，Steam HD 4.0.5，2026-09-03。** 正式卡庫 v0.3 在本驗證戰中提供 `IT_12=true`、`IT_06=nil`、`Level=1`，並在原生靈契收服後自動將 `59` 交換為 `10024`。驗證戰只還原自己的 HP／ATK／SPD／技能暫態；正式 bridge 在戰後先還原、再重新武裝。使用者已確認 `10024` 可正常反白。

**已實測，v0.4，Steam HD 4.0.5，2026-09-03。** 牛魔王由正式鏈路收服並正確交換為 `10024`；戰後 `ItemTemp[59].Level=80`，使用者也確認異事錄／怪物資訊顯示正常。此驗證模組已可停用並從遊戲移除。
