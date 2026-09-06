# 測試紀錄

## 自動檢查

- Lua 語法解析。
- mock：F4 只在 formal bridge 可用時開戰；來源 Level 維持 80，戰鬥副本 HP 由 `100/100` 改為 `15/100`、Level 由 80 改為主角 +11 的 31，`CheckObsolt` 記錄原生 100；探針確認戰後原函式、戰鬥等級與來源欄位完整還原。
- mock（v0.9）：對隔離戰模擬 `Battle_InputClick`、命令確認、背景 UI、玩家 AI、爆擊 callback、收妖死亡與清理；逐序號時間軸與戰後事件摘要都必須輸出，但不寫入收妖率或 `OnEventValue`。
- mock（v1.0）：`PASS native formula` 後的 F5 只對隔離目標寫回來源原始 Level；必須留下時間軸紀錄，且離場仍由既有還原流程清理。
- mock（v1.1）：只讀取 `BSC`、`BSC.Obsolt` 與 `BattleScript` 的型別並輸出盤點；mock 的 `BSC.Obsolt` 會在被呼叫時失敗，確保本版不會嘗試呼叫未驗證 native binding。
- mock（v1.2）：只有第一次 F5 已將 F4 隔離目標還原 Lv80 時，第二次 F5 才以原版簽名參照 `1, -1` 呼叫一次 `BSC.Obsolt`；不會在其他戰鬥或未還原的等級下呼叫。
- mock（v1.3）：第二次 F5 必須經 `GameFunc.RunScene` 呼叫獨立 Scene coroutine；該 coroutine 才能呼叫 `BSC.Obsolt`。mock 確認原生 binding 的回傳會在 Scene 中正常走完。
- mock（v1.4）：第二次 F5、`RunScene` 排程請求、Scene 進入與 `RunScene` 返回必須各自有診斷行，避免把「按鍵沒收到」與「戰鬥內無法排程 Scene」混為同一種失敗。
- mock（v1.5）：F4 指定唯一的 `BattleScript[HLCRP_BULL_DEMON_RATE]`；在 `BSC.Enter` 後，該原生戰鬥腳本把目標由主角 +11 還原為 Lv80，再以 `BSC.Obsolt(1,-1)` 呼叫一次。此版不依賴 F5 或 `RunScene`。

## 實機驗收

依 [README.md](README.md) 操作。必須記錄以下三項：

1. `battle level cap applied ...`；
2. `rate check ... CheckObsolt=100%`；
3. 原生 `NATIVE CAPTURE SUCCESS`、`Battle_Dead(mode=2)` 與 `additem 59`。
4. v0.9：一次手動靈契附近的 `event #` 時間軸及 `event summary`。僅記錄實際事件；沒有候選事件不視為失敗，也不推定 native 沒有未公開入口。
5. v1.0 是歷史 F5 時序實驗；v1.5 不可按 F5。F4 後確認 `BattleScript_RestoreTargetLevel ... -> 80`、`BSC.Obsolt completed in BattleScript coroutine`，再記錄 `Battle_Dead(mode=2)`、`additem 59`、靜態卡交換與清理。整次均不可保存。

## 證據狀態

- **已通過 mock、待實機，Steam HD 4.0.5，2026-09-04，v1.0：** F5 可在 mock 的 F4 隔離戰中將目標由主角 +11 還原為來源 Lv80，並留下可審核時間軸。是否能在 HD 實機戰鬥中接到 F5 輸入、以及還原後原生靈契仍成功或失敗，皆待驗證；它不是正式收妖功能。
- **已通過 mock、待實機，Steam HD 4.0.5，2026-09-04，v1.1：** 只讀盤點 `BSC.Obsolt` 是否存在。原版劇情確有 `BSC.Obsolt(Const.BPLAY1, Const.BMS4)` 呼叫；一般 F4 戰鬥是否可讀到此 binding、其合法參數／前置條件與副作用皆待驗證。
- **已通過 mock、待實機，Steam HD 4.0.5，2026-09-04，v1.2：** 原版 `Const.lua` 證明 `BPLAY1=1`、`BMS1=-1`；探針只會在 F4 的第一隻敵人牛魔王已由第一次 F5 還原為 Lv80 後，以 `BSC.Obsolt(1, -1)` 測試 native bridge。實機可能成功、回傳錯誤或結束程序；任一結果都只屬該版本／該隔離戰的證據。
- **已實測、待修正 coroutine，Steam HD 4.0.5，2026-09-04，v1.2：** 目標 Lv80 時直接從 F5 event handler 呼叫 `BSC.Obsolt(1,-1)` 仍出現兩次 `Battle_Dead(mode=2)`、原生 `additem 59`、正式 `59 → 10024` 交換與 `Battle_RestoreItem` 還原；但 Lua 回報 `attempt to yield across a C-call boundary`。這證明 native binding 能繞過即時等級門檻，亦證明 event handler 不是合法 coroutine 上下文。v1.3 改由 `GameFunc.RunScene` 排程，待實機驗證。
- **已否決，Steam HD 4.0.5，2026-09-04，v1.4：** 戰鬥內第二次 F5 有收到，`GameFunc.RunScene` 回傳 `ok=true, value=nil`，但沒有進入目標 Scene。故地圖 Scene 不能作為戰鬥 coroutine scheduler。v1.5 改為原版戰鬥腳本 coroutine，待實機驗證。

- **已實測，Steam HD 4.0.5，2026-09-04，v1.5：** F4 的自訂 `BattleScript[HLCRP_BULL_DEMON_RATE]` 確實在 `BSC.Enter(1)` 後進入；全魔物靈契已將牛魔王戰鬥副本封頂至主角 Lv59 `+11 = 70`，腳本再將該副本還原為 Lv80，並在同一 coroutine 執行 `BSC.Obsolt(1,-1)`。Console 回報正常完成、沒有 `yield across a C-call boundary`，接著出現兩次 `Battle_Dead(mode=2)`、原生 `additem 59`、正式 `59 → 10024` 交換與 `Battle_RestoreItem` 完整還原。這證明 `BSC.Obsolt` 能在正確的原生戰鬥腳本 coroutine 繞過即時等級門檻；未證明它能直接接管一般遭遇的手動靈契流程。

- **已通過 mock、待實機，Steam HD 4.0.5，2026-09-04，v0.9：** F4 隔離戰可把靈契相關公開 callback 依序記錄，並在 `Battle_RestoreItem` 輸出摘要。它尚未在實機高等目標手動靈契中量到序列，亦不構成任何 callback 可在 native 擲骰前安全暫改 Level 的證據。

- **已實測，Steam HD 4.0.5，2026-09-04，v0.2：** `NPCData.HP` 的隔離寫入成功，Lv80 牛魔王在 `15/100` 時 `CheckObsolt=33%`，且手動 UI 可選取、沒有紅色 X。連續約 10 次手動靈契均失敗；這在真實 33% 機率下約為 1.7%，不足以單獨否定 native 骰子，故由 v0.3 自動 20 次原生指令探針續驗。
- **已否決路徑，Steam HD 4.0.5，2026-09-04，v0.3：** 在兩位角色仍為手動模式時，只寫入 `Battle_PlayerAI` 回傳欄位不會排程自動回合；v0.3 不視為有效 native 結算測試。
- **已否決路徑，Steam HD 4.0.5，2026-09-04，v0.4：** 直接設定 `BattlePlayers[index].AImode=1` 不會通知 native 排程；此欄位不構成遙控自動戰鬥 API。v0.4 不視為有效 native 結算測試。
- **已否決路徑，Steam HD 4.0.5，2026-09-04，v0.5：** `OnEvent.BattlePlayerAI.main` 在 `GameStart` 尚未載入，wrapper 沒有安裝。v0.5 不視為有效 native 結算測試。
- **已否決路徑，Steam HD 4.0.5，2026-09-04，v0.6：** `Battle_Enter` 時 wrapper 成功安裝，且使用者以原生 UI 開啟自動戰鬥；實際仍是 native 攻擊，沒有 wrapper 的靈契指令紀錄或原版 Lua AI main 進入紀錄，只有 `Battle_PlayerAI_after`。此模式的 native 自動戰鬥繞過公開 Lua AI 指令點；v0.6 不視為有效 native 結算測試。
- **已實測／已否決路徑，Steam HD 4.0.5，2026-09-04，v0.7：** Lv35 對 Lv80、HP `15/100` 時基線 `CheckObsolt=33`；使用者完整手動靈契一次後沒有第二次呼叫。原生成功骰子不採用此 Lua 函式。
- **已實測，Steam HD 4.0.5，2026-09-04，v0.8：** 主角 Lv35、來源仍 Lv80 的牛魔王在 `Battle_Enter` 成功由戰鬥副本 Lv80 → Lv46（主角 +11）；HP `15/100` 時 `CheckObsolt=100`，使用者手動靈契成功。來源／地圖等級保持 Lv80。此結果已作為正式「全魔物靈契」v1.9 的實作依據；探針測試完成，應停用。

## 封裝驗收
*AEC99E2B8F4EDB2A3B95FF077BA5E0B5B9826044E8CF46CEFBB3DC9DB49BEB4B`；反解 manifest 與 `HighLevelCaptureRateProbe.lua` 均與來源 SHA-256 一致。v0.5 在 `GameStart` 過早安裝 wrapper；v0.6 改為 `Battle_Enter` 安裝。實機顯示 native 自動戰鬥繞過 wrapper，未送出靈契，故這個自動結算路徑不再繼續使用；不屬正式發布內容。
- **已通過靜態、mock 與封裝驗收，2026-09-04，v0.7。** 成品 `3,861` bytes、SHA-256：`5619DFDC166CB4FE95B6DF0141A2FDC5A704A5BB704961AD8E99C6EFA2386606`；反解 manifest 與 `HighLevelCaptureRateProbe.lua` 均與來源 SHA-256 一致。已移除所有 AI／自動出招實驗，只追蹤一次手動靈契對 `CheckObsolt` 的實際呼叫；不屬正式發布內容。
- **已通過靜態、mock、封裝與實機驗收，2026-09-04，v0.8。** 成品 `4,189` bytes、SHA-256：`C85A3033035CB42D30E9DDAC1C1C1D21E676366A3ADCB89A989E7E99B8C2411F`；反解 manifest 與 `HighLevelCaptureRateProbe.lua` 均與來源 SHA-256 一致。隔離戰已實測主角 +11 的戰鬥副本封頂與原生手動收服成功；不屬正式發布內容，應停用。
- **已通過靜態、mock、封裝與實機驗收，2026-09-04，v1.5。** 成品 `6,159` bytes、SHA-256：`8AE25C2762CDB913EE4E4254DFAF75C4B4DFE274E3E33CC08DA6BF214DE75A84`；反解 manifest 與 `HighLevelCaptureRateProbe.lua` 均與來源逐檔 SHA-256 一致。已實測自訂 `BattleScript` coroutine 下的 Lv80 `BSC.Obsolt(1,-1)` 原生收妖、正式靜態卡交換與完整清理；僅屬隔離研究，應停用。
- **已通過靜態、mock 與封裝驗收，2026-09-04，v1.6。** 成品 `6,159` bytes、SHA-256：`7FD596C5302A9BB6332E366D47BE92FC0C1585F65457123098CE1E0FEFD173C1`；反解 manifest 與 `HighLevelCaptureRateProbe.lua` 均與來源逐檔 SHA-256 一致。本版只將成功訊息由歷史遺留的 `Scene coroutine` 更正為 `BattleScript coroutine`，未改變已實機驗證的行為；不必重新執行研究戰，且仍應停用。
- **歷史版本，v0.5。** 成品 `4,781` bytes、SHA-256：`C5BD4E8ECE0DA7E91439217A753B1A1EA6845DF0DF000E2AFB51BF22423BD720`；因原版 AI 尚未載入，已由 v0.6 取代。
- **歷史版本，v0.4。** 成品 `4,371` bytes、SHA-256：`EF517E36D9870D586BBCFEE7D8C724AE8FEB8B86B5DA24703DB19820B26B39A9`；因 native 排程與原版 AI 覆寫問題，已由 v0.5 取代。
- **歷史版本，v0.3。** 成品 `4,065` bytes、SHA-256：`7AE9FEBEBC1A55249C9C451B8196FE34C10E1872BEEB602F6991CF701BBD9746`；因手動模式不會排程自動回合，已由 v0.4 取代。

- **已通過，2026-09-04，v0.2。** 自動 mock 通過。成品 `3,278` bytes、SHA-256：`A1E644AE3A90A64BF554A8EA291461D8D2AE2ED8E2F8062EFFBDA0B544A0C21E`；反解 manifest 與 `HighLevelCaptureRateProbe.lua` 的 SHA-256 均與來源一致。v0.2 僅把測試觸發由 Insert 改為 F4。
- **歷史版本，v0.1。** Insert 版本成品 `3,291` bytes、SHA-256：`323C3A46063DE8BD46B61EB89DB6F905CFBA39E9B753B650E732680DA72209A7`；已由 v0.2 取代，不再安裝。
