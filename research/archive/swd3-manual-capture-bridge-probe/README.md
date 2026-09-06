# 手動靈契原生橋接探針

> 歷史實驗：本頁保存所列版本的操作與證據。是否重用、知識去向及未解問題，先查[研究清冊](../../README.md)；通用能力依[知識庫](../../../docs/knowledge/README.md)，不因歸檔或 mock 通過擴張為正式支援。

Steam HD 4.0.5 的隔離研究探針。它驗證一個有限問題：原生 `BattleScript` 的 `BSC.Run(1)` 在玩家手動操作一回合後返回時，能否在**同一戰鬥 coroutine** 安全呼叫 `BSC.Obsolt`，把已失敗的高等手動靈契交接給原生收妖 bridge。

它不是正式功能、不會自動辨識一般戰鬥的靈契按鈕，也不修改「全魔物靈契」正式邏輯。整個實驗只用可丟棄存檔，**不得保存**。

## 前置與操作

1. 只啟用「全魔物靈契」v1.9 與本探針；其他收妖／戰鬥探針保持停用，完整重啟遊戲。
2. 在地圖按 **F6**。探針建立一隻來源仍為 Lv80 的牛魔王，戰鬥副本 HP 為 `15/100`。全魔物靈契先照正式邏輯把副本壓到主角 `+11`，本探針隨即在自己的 `BattleScript` 中還原 Lv80。
3. 確認 Console 依序出現 `BattleScript entered`、`Battle_Enter restored target Level ... -> 80`、`BattlePlayerAI_after observer installed`、`waiting at BSC.Run`。
4. 直接對牛魔王手動使用**一次**靈契。不要攻擊、不要按其他快捷鍵。
5. 原版 `BattlePlayerAI_after.main` 清空 AI 指令前，探針會讀取 `AI_Command=6`、玩家與目標，顯示 `manual 靈契 observed before AI reset`。這次靈契預期因即時 Lv80 而失敗；若 `BSC.Run(1)` 返回，探針會顯示 `BSC.Run returned after high-level manual 靈契`，並從同一個 `BattleScript` 呼叫相同玩家／目標的 `BSC.Obsolt`。
6. 成功條件：沒有 yield 錯誤，且出現 `Battle_Dead(mode=2)`、native `additem 59` 與全魔物靈契的 `capture exchange confirmed ... card=10024`。離場後確認 `cleanup complete`。不要保存。

## 判讀

- **已實測（v0.3）：**「明確武裝 + 手動靈契後的一回合交接」在自訂 BattleScript 可行。Steam HD 4.0.5、主角 Lv59、牛魔王來源與戰鬥副本 Lv80、HP `15/100` 下，F7 後的手動靈契使 `BSC.Run(1)` 返回，隨後 `BSC.Obsolt(1,-1)` 正常完成兩次 `Battle_Dead(mode=2)`、native `additem 59` 與正式 `59 → 10024` 交換，沒有 yield 錯誤。
- **已否決自動辨識（v0.4／v0.5）：** 包裝原版 `BattlePlayerAI_after.main` 的確會執行，但可讀到的 `AI_Command=0`、`AI_Target` 為預設值、`AI_SelectItem=0`、`BattleEnv.setTarget=nil`。這不能可靠辨識手動靈契或其目標。`aiMode` 數值本身也不能單獨對應使用者畫面上的操作模式，因此不把它當作「使用者開了自動戰鬥」的證據。配合已否決的 `Battle_InputClick`、`Battle_CmdSelectOK` 與 `CheckObsolt` 路徑，目前沒有公開 Lua 入口可安全、自動接管一般手動靈契；本探針不可升級為正式 MOD。
- 若 F7 有收到但 `BSC.Run` 不返回，表示目前腳本無法在該手動回合後取得控制權。
- 若 `BSC.Run` 返回但 bridge yield 或失敗，表示這種交接時點不是合法 bridge 上下文。
- 如果成功，下一輪才研究如何可靠辨識一般戰鬥中「玩家選的是靈契、目標是哪一隻」；在取得該證據前，不能把本探針升級為正式 MOD。

## 還原

探針只暫時降低隔離來源牛魔王的 HP／攻擊壓力，並在 `Battle_RestoreItem`、切圖與重啟時還原。若強制關閉，重新啟動也會執行還原邏輯；仍以不保存為必要條件。
