# 賽特靈契 input-window 探針

> 研究來源：本頁保存所列版本的操作與證據。是否重用、知識去向及未解問題，先查[研究清冊](../../README.md)；通用能力依[知識庫](../../../docs/knowledge/README.md)，不因歸檔或 mock 通過擴張為正式支援。

這是 Steam HD 4.0.5 的一次性隔離研究 MOD，不是正式功能。它檢驗一個較小的旗標窗口：手動指令 UI 正在接收輸入時，把隔離牛魔王的 live Boss bit (`NPCData.ItemType & 0x20`) 清除；只有**非賽特**的 `BattlePlayerAI_after` 才把 Boss bit 還原，賽特 after 維持 non-Boss。它不使用 `BattlePlayerAI_mod`、`Battle_DrawBGI`、自訂收妖或傷害公式。

原生事件生命週期、live flag 算式、action 6 gate、成功 trace 與傷害公式的已知界線，集中在[原生事件、旗標與靈契流程](NATIVE-EVENT-AND-CAPTURE-FLOW.md)。

**已實測範圍：** 原生 action 6 的目標確認可由 `NowMenu=1/3` 的輸入窗口取得 non-Boss；其後賽特 `BattlePlayerAI_after` 仍保持 non-Boss 時，原生收服完成。因為只有賽特能用 action 6，賽特 after 必須維持 non-Boss；妮可 after 可先還原 Boss。妮可實際傷害的完整回歸仍另列為待驗證。

## v0.6 規則

```text
Battle_Enter（只覆蓋第一個命令 UI） → Boss OFF
任何輸入 callback 且 NowMenu=1 或 3      → Boss OFF
BattlePlayerAI_after（賽特）             → Boss OFF
BattlePlayerAI_after（非賽特）           → Boss ON
```

輸入 handler 只觀察本探針的 F3 戰場，不會持續輪詢 `NowMenu`，也不會改寫正式「全魔物靈契」的 source bridge。`BattlePlayerAI_after` 不是行動結束事件；本探針只把它當成「命令已提交後，傷害 executor 前」的候選還原點。

## 測試前提

1. 只啟用「全魔物靈契」與本探針；關閉其他收妖、戰鬥、爆擊與時序探針。
2. 完整重啟遊戲，進入地圖，確認 Console 先顯示全魔物靈契 `capture bridge armed`。
3. 使用可丟棄存檔，整個實驗 **不可存檔**。

## 操作：驗證跨角色第二輪

1. 在地圖按 **F3**。隔離牛魔王會被設為 HP `15/100`、無攻擊與技能。
2. 第一輪：賽特選**防禦**；妮可也選**防禦**。不要攻擊、用物品或護駕。
3. 等兩個行動完成，Console 應顯示賽特 after 保持 Boss OFF、妮可 after 把 Boss 設回 ON。
4. 第二輪賽特的命令 UI 出現後，直接選原版**靈契**並指定牛魔王。妮可可選防禦。不要再按任何測試鍵，也不要存檔。
5. 貼出從 `F3 isolated battle started` 到 `cleanup complete` 的完整 Console 記錄。

候選成功的最低證據是：第二輪的 `InputKeyDown`／`InputKeyUp`／`InputClick` 或 `Battle_InputKeyDown` 在 `NowMenu=1` 或 `3` 寫出 `Boss OFF`，賽特 after 仍為 `Boss OFF`，而原生出現 `Battle_Dead(... mode=2)` 和 `PASS CANDIDATE`。妮可 after 必須把 Boss 設為 ON；若第二輪 UI 不能選靈契、原生收妖失敗，或妮可攻擊時 Boss bit 不是 ON，則此假說被否決或需要縮小時序條件；離場、不存檔。

## 安全邊界

- 僅對戰場 `SCWP_BULL_DEMON_WINDOW` 的來源牛魔王 `59` 生效。
- 以 `pcall` 讀寫並 readback `NPCData.ItemType`，只加／清 `0x20`，保留其餘 bit。
- F3 戰鬥暫改的來源 HP／ATK／SPD／技能與 live ItemType 快照，會在戰後、切圖與重啟的已知 callback 還原。
- 強制關閉或崩潰不能取代「不存檔」規則。

## 研究沿革

- **已靜態反解：** HD 4.0.5 的 `NPCData.ItemType` 是可讀寫 native Lua property；Boss 語意是 `0x20` bit。`NPCData.IT_06` 不是 userdata 欄位。
- **已實測／否決：** v0.2 的「進場 OFF、依賽特／妮可 `BattlePlayerAI_after` 切換」只覆蓋第一輪；妮可 after 後，下一輪賽特 UI 仍把目標當 Boss。v0.4 的 `BattlePlayerAI_mod=true` 雖能使 `Battle_DrawBGI` dispatch，但會接管手動角色指令，不能作正式方案。
- **已實測／否決：** v0.5 的 input-window 可在第二輪賽特 UI 前透過輸入 callback 清除 Boss，但賽特 `BattlePlayerAI_after` 把它改回 ON 後，原生收妖沒有完成（沒有 `Battle_Dead mode=2`）。這支持「action 6 在賽特 after 後仍需要 non-Boss」的候選解釋，但尚非 native call-site 證明。
- **已實測，Steam HD 4.0.5，2026-09-06，F3 隔離牛魔王戰：** 賽特與妮可先各防禦一輪；妮可 after 將 `ItemType` 由 `2048` 改為 `2080`（Boss ON）。下一輪輸入先於 `NowMenu=3` 再清回 `2048`；妮可 after 再次 ON，賽特 after 保持／改回 `2048`，隨後原生兩次 `Battle_Dead(index=1, side=1, mode=2)`、`additem 59` 與正式 bridge `59 → 10024` 全部完成。這證明此條件下 action 6 在賽特 after 後仍要求 non-Boss，且不需要讀取 private queue。
- **待實測：** v0.6 下妮可實際普攻／爆擊是否在其 after 的 Boss ON 分支維持正常，賽特非靈契普攻／奇術／物品是否可接受，以及一般地圖 Boss、敵方回合、收服失敗、逃跑與取消的還原矩陣。

## v0.5 靜態驗收

**已 mock／已封裝反解，2026-09-06。** `tests/run-tests.ps1` 通過；產物為 `build/package-20260906-v05-input-window/swd3_seth_capture_window_probe.ssmod`（4,688 bytes，SHA-256 `ABC087290C3FE454D3E0ABCFCEF7C100CD0558FE3D3D6BD528FCD294B2FD7CCE`）。反解的 `.ext` 與 `out_data/SethCaptureWindowProbe.lua` 分別與來源 SHA-256 `2B1FC5BDA0AC58F4DA9399D2E66738DB4FAE2FFD043F06C071F8069A0C486DCD`、`C4A24238EFF5552CADBF6A7A3312B858F83AC79856146801E8041F543239F8D1` 一致。這只證明腳本、封包與 mock 規則一致；仍須依上節做無存檔實機驗證。

## v0.6 靜態驗收

**已 mock／已封裝反解／已實測收服，2026-09-06。** `tests/run-tests.ps1` 通過；產物為 `build/package-20260906-v06-seth-retained/swd3_seth_capture_window_probe.ssmod`（4,846 bytes，SHA-256 `3A827FEB4DA341871EB458C7F356DD8C013A7B027D546A0E6D5DDE2A4D466B9E`）。反解的 `.ext` 與 `out_data/SethCaptureWindowProbe.lua` 分別與來源 SHA-256 `CFFCB9D1E1D4C1411295244E18A349CAD09B55E0C1A0F2159635F8A273AA12DE`、`7CBDCB5EB4FCC01745CA793F97E8A082B9D5583EE56EE40F76047DFC93C5DD24` 一致。F3 收服證據見上節；妮可傷害窗口尚需獨立實機驗收。
