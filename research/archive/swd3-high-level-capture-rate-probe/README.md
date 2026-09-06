# 高等靈契機率驗證戰

> 歷史實驗：本頁保存所列版本的操作與證據。是否重用、知識去向及未解問題，先查[研究清冊](../../README.md)；通用能力依[知識庫](../../../docs/knowledge/README.md)，不因歸檔或 mock 通過擴張為正式支援。

這是 Steam HD 4.0.5 的隔離研究探針，用來驗證「全魔物靈契」在高等敵人戰鬥副本中，將敵方等級上限設為施放者 `+11` 後，是否能走原生靈契的實際結算。v1.0 另以 F5 在同一場隔離戰、任何行動前，把目標戰鬥等級還原為原始 Lv80，用來驗證原生收妖資格是否只在進戰時快取。v1.1 只讀盤點原版劇情所用的 `BSC.Obsolt` 原生收妖入口是否在一般戰鬥 Lua 環境可見；它不呼叫此函式。

它不是正式功能，不可上傳工作坊、不可和其他收妖／戰鬥探針同時啟用，且整個測試都**不得存檔**。

## 最短操作

1. 只啟用「全魔物靈契」v1.9 和本探針，完整重啟並進入地圖。
2. 確認 Console 有全魔物靈契的 bridge armed 訊息。
3. 按 **F4** 一次。本探針建立一隻來源 Lv80 牛魔王，來源資料保持 Lv80；戰鬥副本設為 HP `15/100`、無攻擊／技能，並只將其戰鬥等級改為當前主角 `+11`。
4. Console 必須顯示 `battle level cap applied`、`CheckObsolt=100%` 與 `PASS native formula`。若不是，直接離場、不存檔。
5. **不要按 F5、不要攻擊、不要手動靈契。** 隨後原版形狀的 `BattleScript` coroutine 會自動顯示 `native BSC.Obsolt BattleScript coroutine entered`，把目標由主角 `+11` 還原為 Lv80，再呼叫 `BSC.Obsolt(1,-1)`。
6. `BattleScript_RestoreTargetLevel ... -> 80`、`BSC.Obsolt completed in BattleScript coroutine`、`NATIVE CAPTURE SUCCESS` 與原生 `additem 59` 是完整成功證據：原生收妖在即時 Lv80 時成功，主角 +11 僅用於先前 Lua 基線檢查，沒有留在結算戰鬥。
7. 離場後確認 `capture call trace restored`、`probe restored`，以及全魔物靈契的 `capture exchange confirmed ... 10024`；不要保存。

## v0.9 的時序判讀

探針記錄 `Battle_InputClick`、`Battle_CmdSelectOK`、`Battle_CancelClick`、`Battle_DrawBGI`、玩家／敵方／護駕 AI、`BattleCriticalHitRate`、`Battle_Dead` 與 `Battle_RestoreItem`。這些行均是**唯讀觀察**；即使某事件出現在靈契附近，也還不能代表它發生在 native 收妖擲骰前。

F5 是受控的單一寫入實驗，僅限 F4 建立的牛魔王戰：它將「全魔物靈契」剛設成 `主角 +11` 的目標戰鬥等級，改回來源原始 Lv80。這不改來源模板、背包、機率或存檔，離場時原本的還原流程仍會回到 Lv80。若 F5 後仍能原生收服，才支持「資格可能在 F5 以前被快取」；若失敗或目標變紅 X，則證明 native 在手動收妖時仍讀取即時等級。無論哪一種，單次結果都不會直接提升為正式 MOD 行為。

v1.1 另會在 `Battle_Enter` 輸出 `native capture bridge inventory`。原版劇情 `BattleScript.lua` 曾以 `BSC.Obsolt(施放者, 目標)` 取得劇情首領；若此行顯示 `BSC.Obsolt=function`，只代表可讀到候選 native binding，**不**代表一般 Lua handler 可安全呼叫、可指定一般遭遇目標，或能取代原生靈契。

v1.2 已實測 `BSC.Obsolt(1, -1)` 在 Lv80 牛魔王上確實引發原生收妖並完成靜態卡交換，但從 F5 event handler 直接呼叫會得到 `attempt to yield across a C-call boundary`。v1.3／v1.4 已否決地圖用 `GameFunc.RunScene`：第二次 F5 可收到、`RunScene` 也會回傳，但它不會在戰鬥中進入 Scene。**v1.5 已實測**原版形狀的 `BattleScript` coroutine：F4 建立單隻牛魔王，`BSC.Enter(1)` 完成初始化後將目標 Lv70 還原 Lv80，再直接呼叫 `BSC.Obsolt(1,-1)`；沒有 yield 錯誤，收妖成功、原生新增來源物品並由正式 MOD 交換成 `10024`。這只證明自訂 `BattleScript` 戰鬥可安全使用該 bridge，尚未證明一般地圖遭遇的手動靈契可被轉入同一 coroutine。

判斷「可即時控制」至少需要同時滿足：事件在每次手動靈契都穩定出現、可辨識該指令及其目標、事件後的暫態寫入能被原生收妖判定讀到、且在同一個原生流程結束前可還原。現有證據已否決 `Battle_CmdSelectOK` 與 `Function.CheckObsolt`；v0.9 的任務是尋找或再次排除其他公開候選，並不會在這一版嘗試寫入 Level。

## 邊界與還原

- 僅暫改隔離戰建立前的來源 HP、ATK、SPD 與技能表；來源 `Level` 保持不變。只在 `Battle_Enter` 對隔離戰的 `NPCData.Level` 設為主角 +11，並在已知離場路徑還原。
- 戰鬥副本的 HP 設定使用已知可讀欄位的受保護寫入；若寫入不成功，Console 會要求停止測試。
- 在 `Battle_RestoreItem`、換圖與 `GameStart` 還原來源欄位；Game Over／強制關閉仍不可保證單一 callback，所以使用可丟棄存檔且不保存。
- 這是使用者允許的戰鬥內等級例外：原版暴擊、逃跑與 AI 也可能讀取該戰鬥等級；來源／地圖資料不變。本探針只以 `Battle_Dead(mode=2)` 作為 native 成功的證據，不會自行發卡或偽造成功。
- v0.9 的新增時間軸不寫 `NPCData.Level`、`OnEventValue`、收妖機率、戰鬥指令、背包或存檔；不把目前未驗證的 callback 當作正式收妖邏輯。
