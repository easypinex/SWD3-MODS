# 測試紀錄

## 自動檢查

執行 `./tests/run-tests.ps1`：檢查 Lua 語法，並以 mock 驗證 bridge 可正確套用與逐欄還原 `IT_12`、`IT_06`、`Race.catch`。

**已通過，2026-09-03。** mock 同時涵蓋「原本不存在」、「原本為 `false`」與「原本為 `true`」的欄位，確認還原不會把 `false` 誤還原為 `nil`。

## 實機驗收（待執行）

- Steam HD 4.0.5，可丟棄測試存檔；全魔物靜態卡庫啟用，本探針啟用。
- 地圖上按 Home 後，Console 記錄 `pre-battle bridge active: sources=183, races=15, skipped=10`；再進入原生一般遭遇一隻原本不能靈契選取的非活物。
- 每隻敵人初始化時，Console 記錄 `Battle_EnemyInit observed under pre-battle bridge`；靈契目標不顯示紅色 X。
- 收服一隻非原生活物後，`Battle_Dead(mode=2)` 只標記候選；`Battle_RestoreItem` 只在來源物品總數高於該敵人的開戰前基線時，記錄 `capture exchange confirmed` 並加入對應靜態卡。
- 物品欄反白交換後的靜態卡一次；確認正常後結束遊戲且不儲存。

### 已通過：一般遭遇野猴

**Steam HD 4.0.5，2026-09-03。** 在地圖啟用 bridge 後進入 `BS41`，`Battle_EnemyInit` 記錄來源 ID `106`（野猴）。原生 `Battle_Dead(mode=2)` 後新增 ID `106`；`Battle_RestoreItem` 時探針只刪除高於開戰前基線的一張 ID `106`，加入靜態卡 ID `10046`，並記錄 `capture exchange confirmed`。使用者已確認 ID `10046` 可在物品欄正常反白，且戰後已記錄 bridge 還原。此次未保存。
- 取消或離開戰鬥後，Console 記錄 `bridge restored (Battle_RestoreItem)`；回到地圖後不儲存。
- 額外測試：同一場戰鬥 Home 兩次，第二次必須完整還原；重新啟用不累積修改。

## 封裝驗收

- **已通過，2026-09-03，v0.4。** `SS2Dtool p` 產生 `dist/build-v04-20260903/swd3_general_capture_eligibility_probe.ssmod`（SHA-256 `0295C4AD412DC0F7CE078A4DD6E5D12366749272021A21B23A81C4E1FD12BA7F`）。
- **已通過，2026-09-03，v0.4。** `SS2Dtool x` 反解至 `dist/verify-general-capture-eligibility-v04-20260903`；manifest SHA-256 `D894BE3A9B0E461BE1706AE2C376E0E037BF54003CCBA70ABAAA11F3FD449BA3`、Lua SHA-256 `1B65886E2D5DB08ADA6E2069CA6062A69E0F77A6CFBEE25681B43D68CA7AECAD`，都與來源一致。
