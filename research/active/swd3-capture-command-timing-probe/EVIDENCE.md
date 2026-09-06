# 戰鬥事件觀察、量測矩陣與歷史索引

> 2026-09-06 從通用時序文件移出的既有證據。保留研究當時的推論、L1–L5 操作、trace 與使用清單；「目前使用」「待驗證」均是當時狀態，不能取代[現行時序正文](../../../docs/knowledge/battle-events-and-timing.md)或[相容性登記](../../../docs/compatibility-registry.md)。

## 已知戰鬥輪廓

下圖是目前能安全描述的輪廓；實線只表示已觀察到的關係，虛線表示 callback 存在或語意可辨識、但相對順序尚未形成規格。

```text
地圖／戰前準備（非 Battle callback）
  │  例如 MapLoading 的資格 bridge
  ▼
Battle_EnemyInit、Battle_PlayerInit、Battle_NPCInit、Battle_KeeperInit
  │  已實測一次：BS36 的 EnemyInit、PlayerInit 記錄在 Battle_Enter 前
  ▼
Battle_Enter
  ⋮
Battle_DrawBGI ── 輸入／手動指令／AI ── 戰鬥行動與條件式計算 callback
                                     │
                                     ├─ Battle_Dead（可重複、每個角色）
                                     ├─ BattleGain（獎勵結算；相對於 RestoreItem 未定）
                                     └─ Battle_RestoreItem（物品／預留清理）
```

### 先分清四種生命週期

**專案決策，2026-09-05。** 從此文件讀取時，不能再把「在同一場 Console 出現過」理解成「每回合／每個角色都會出現」。戰鬥 callback 必須先分進下列四層；只有同一層內、同一個版本與操作情境實測到的相對順序，才可用於功能設計。

```text
I. 戰鬥實例生命週期（整場建立／離場）
   Enemy/Player/NPC/KeeperInit → Battle_Enter → … → Battle_RestoreItem

II. 指令選擇生命週期（每個需要選命令的角色，可能重複）
   玩家 UI／輸入 → native private queue 寫入
   └─ 公開輸入 callback 只是不完整觀察點；不能當作「已提交命令」

III. 行動執行生命週期（每個已排入行動，可能交錯）
   native executor → 條件式 AI／暴擊／逃跑／死亡 callback
   └─ callback 是否出現取決於動作、目標、結果與 native state，不是一回合固定清單

IV. 戰後結算生命週期（只有戰鬥實際結束才可能進入）
   Battle_Dead 候選／native 掉落與加物 → BattleGain（條件式）→ Battle_RestoreItem
```

「回合」不是目前公開 Lua API 的物件或 callback。原生可先讓多名我方角色完成 II 的選擇，再依速度在 III 交錯執行；因此「賽特 UI → 妮可 UI → 賽特行動 → 妮可行動」可與 Console 中的 `BattlePlayerAI_after` 排序共存。任何 MOD 若需要「一個角色已造成非致死傷害」或「上一名角色完整結束」，必須找到該層的已實測結束點；不能把 II 的輸入事件或 III 開頭的 callback 假定為結束點。

### callback 重複頻率矩陣

下表是目前可用於設計的頻率契約。**「候選」不等於保證；未知／條件式項目不能用作暫改資料的唯一還原點。**

| 層 | callback 類別 | 可安全描述的重複粒度 | 已知不能推定的事 |
| --- | --- | --- | --- |
| I | `Battle_EnemyInit`、`Battle_PlayerInit`、`Battle_NPCInit`、`Battle_KeeperInit` | **已實測 BS36：** 在首次 `Battle_Enter` 前，對該場已建立的對象各出現一次。 | 不保證中途新增／召喚、復活、護駕變更或所有戰場只有一次；不是每回合 callback。 |
| I | `Battle_Enter` | **已實測：** 已建立對象後的進戰界線；每場正常建立至少觀察一次。 | 不能當作所有 native UI 資格已快取、所有中途對象已存在，或可覆蓋每個後續回合。 |
| II | 全域 `InputKeyDown`／`InputKeyUp`／`InputClick`／`InputDClick` | 每個實體輸入可能觸發；v0.5 僅在戰鬥旗標內觀察。 | 一次按鍵／點擊不等於一個命令已提交；座標、控制器、滑鼠與 UI state 尚未完成對照。 |
| II | `Battle_InputKeyDown`、`Battle_InputClick`、`Battle_InputDClick`、`Battle_CancelClick`、`Battle_CmdSelectOK` | native predicate 命中時才觸發，**不保證每次手動選指令都出現**。 | BS36／BS41 手動靈契未見 `CmdSelectOK` 或可讀 `cmd=6`；不可用來辨識或攔截 action 6。 |
| II | `BattlePlayerAI(index)` | **已靜態反解：** 位於該玩家 command UI／可用命令建立前，queue 尚未寫入。 | 它受 `BattlePlayerAI_mod` 控制；開啟會接管手動指令，故不能拿來量測原版手動 UI 的逐角色週期。 |
| III | `BattlePlayerAI_after(index)` | **已實測：** 可隨已提交的玩家行動重複，並帶角色 index；靜態上它和 action executor 位於同一 native state machine 的不同 branch。 | 現有靜態 branch 位置與少量 runtime sequence 都不足以建立它對「同一角色 executor／傷害」的通用前後關係；不能代表傷害已結算，也不能保證不同角色的 after／executor 交錯順序。 |
| III | `BattleEnemyAI(index)`、`BattleNPCAI(index)` | 官方檔內為敵方／護駕選動作入口；預期隨其可行動次數而條件式重複。 | 原版手動戰場的實際 dispatch 次數、和 executor／傷害的前後關係仍待量測。 |
| III | `BattleCriticalHitRate(...)` | **已靜態反解＋已實測 L2：** 它會在標準攻擊傷害準備線之前帶來源與目標；但 BS34 也在玩家選擇「防禦」、來源與目標同為自己時出現。 | 不能用「有此 callback」唯一識別普攻、技能、命中或實際傷害；出現不代表 HP 已寫入。 |
| III | `BattleEnemyEscapeRate(...)` | 只在逃跑率被計算的條件式分支。 | 不是逃跑成功／戰鬥結束事件；和 `Battle_Dead(mode=1)` 的相對順序待驗證。 |
| III | `Battle_Dead(index, side, mode)`、`Battle_StopSkill`、`Battle_Freeze`、`Battle_SetActive` | 每次相應的死亡／狀態變更都可能重複；`Dead` 已實測同一收妖可重複兩次。 | `Dead` 不是一般傷害後 callback；不能把「未死」解讀為「行動還沒結束」。 |
| IV | `BattleGain(...)` | 勝利獎勵計算的條件式 callback。 | 尚未證明會在每種結束（逃跑、失敗、腳本中斷、收妖）出現，或與清理的固定排序。 |
| IV | `Battle_RestoreItem()` | 正常戰後物品／預留清理邊界；既有正式 MOD 用它做最終比對。 | 不能單獨覆蓋 Game Over、讀檔、強制關閉或中斷 coroutine；這些仍須額外可重入還原路徑。 |

### 對 MOD 設計的直接規則

1. 若需求是「整場一次設定」，只能從 I 選點，且必須有 IV 與換圖／重啟的還原。
2. 若需求是「在玩家選到某個動作後改資料」，目前 II 沒有公開、可靠的 action queue／目標映射；先做唯讀量測，不可把未見事件補成假設。
3. 若需求是「此角色的傷害已完成才還原」，目前 III 沒有一般非致死傷害後的 Lua callback；`BattlePlayerAI_after` 和 `BattleCriticalHitRate` 都太早。
4. 若需求是「一次行動導致死亡／收妖後做記號」，可在 `Battle_Dead` 記候選，但物品交換與全域還原仍放到 IV 的基線比對／可重入 cleanup。

### 尚缺的生命週期證據與標準量測組合

**待驗證，Steam HD 4.0.5。** 現有平面 trace 已足以說明「事件是否曾發生」，但尚不足以把 II、III 對應到可重複的角色行動。以下是之後使用 `swd3-capture-command-timing-probe` 時必做的最小測試組合；每一場都只啟用唯讀時序探針與必要的正式 MOD，並記下玩家實際按的順序，不能只貼摘要。

| 案例 | 人為操作 | 要回答的生命週期問題 | 需要保留的 log 區段 |
| --- | --- | --- | --- |
| L1：指令緩衝 | 兩名我方都防禦，連續完成至少三輪。 | 原生是否先收集兩人的 II，再在 III 執行；`BattlePlayerAI_after(index)` 是否每輪各出現一次，以及角色 index 的重複順序。 | 從第一個戰鬥輸入到第三輪兩人皆完成行動。 |
| L2：混合動作 | 賽特防禦、妮可普攻；下一輪妮可防禦、賽特攻擊。 | `BattleCriticalHitRate` 是否能區分動作；它與兩人的 `BattlePlayerAI_after`、死亡和下一輪輸入之間的實際相對位置。 | 每次點選前的輸入、暴擊率 callback、兩位玩家 after、死亡／下一輪第一個輸入。 |
| L3：取消／重選 | 在賽特 UI 開啟後進入子選單再取消，最後防禦；妮可也防禦。 | 哪一種取消會實際命中 `Battle_CancelClick`／全域輸入，及它是否只屬 II。 | 從開啟子選單至兩人行動完成。 |
| L4：原生靈契 | 對原本合法的低等怪手動靈契一次。 | `NowMenu`、輸入 callback、queue 前可見狀態與 `Battle_Dead(mode=2)` 的距離；確認沒有把結果 callback 誤作命令 callback。 | 從點靈契到 `Battle_RestoreItem`，另附實際點擊步驟。 |
| L5：結束路徑 | 分別以正常擊殺、逃跑（可行時）完成獨立戰鬥。 | `BattleGain`／`Battle_RestoreItem` 是否分別出現、各自的前後關係及是否可作 cleanup 證據。 | 每場從致命／逃跑輸入至地圖恢復。 |

這五例完成前，文件仍刻意不定義「角色行動結束」這種不存在於公開 Lua 的虛構事件。若某個正式功能必須依賴它，結果只能是：改設計避免暫態窗口、維持隔離 BattleScript，或改用非 `.ssmod` 的 native 方案；不能以 timer 或下一個玩家 callback 補洞。

#### L2 BS34 操作與事件摘錄

**已實測 L2，Steam HD 4.0.5，2026-09-05，BS34，兩隻 Lv12 黏怪、賽特／妮可。** 使用者明確記錄的操作順序是「賽特防禦 → 妮可普攻 → 妮可防禦 → 賽特攻擊」。以下為操作與事件序號摘錄，不是完整原始 Console；本案例未單列探針版號。公開 trace 對應如下：

```text
賽特防禦：#176 BattleCriticalHitRate(賽特 → 賽特)
妮可普攻：#181 BattleCriticalHitRate(妮可 → 敵 1)
           #182 BattlePlayerAI_after(賽特)
           #183 BattlePlayerAI_after(妮可)
           #184 Battle_Dead(敵 1)

妮可防禦：#193 BattleCriticalHitRate(妮可 → 妮可)
           #194 BattlePlayerAI_after(妮可)
賽特攻擊：#199 BattleCriticalHitRate(賽特 → 敵 2)
           #200 BattlePlayerAI_after(賽特)
           #201 Battle_Dead(敵 2) → #202 BattleGain → #213 Battle_RestoreItem
```

這直接修正兩個先前不能確定的點。(1) `BattleCriticalHitRate` 在兩次防禦也出現，且 target 是自己，故它**不能**唯一識別普攻或實際命中；(2) 兩次致死動作的 `Battle_Dead` 都在相關 `BattlePlayerAI_after` 之後，故 after 不是傷害／死亡完成點。此 trace 仍無法見到非致死 HP 寫入或動畫完成，不能由「after 後還沒死」推定精確 executor 邊界。

先前未附實際動作清單的 BS34 平面序列，只能保留為「after 與暴擊 callback 可多次出現」的弱證據；不得再標成「三段防禦」或用來推定原生回合。所有「暫改目標 → 等 after 還原」的設計仍屬已否決。

**已否決 actor-specific 版本；另有待驗證的 input-window 版本，Steam HD 4.0.5。** L2 確實否決「只在 `BattlePlayerAI_after(賽特)` 關、`after(妮可)` 開」的 actor-specific Boss bit 窗口：它需要在妮可 after 後、賽特下一次 UI 前再得知 active player，但沒有該 callback。

```text
妮可 after（可把 Boss 設回開）
  → 賽特下一次 NowMenu=1／指令 UI（需要再次關 Boss）
  → 賽特選靈契目標的 live CanObsolt gate
```

L2 的 `#194 BattlePlayerAI_after(妮可) → #195 起的賽特輸入` 正是 actor-specific 缺口的實測例。`after(妮可)` 若把 Boss 開回來可保護妮可傷害分支，卻在下一個賽特 UI 前沒有「active player=賽特」的公開 event 可再關。

**已實測的 input-window 條件解法，Steam HD 4.0.5，2026-09-06，F3 隔離牛魔王。** 任何全域／戰鬥輸入 callback 觀察到 `_BattleEnv.NowMenu` 為一般命令／目標狀態 `1` 或 `3` 時，把 Boss 暫清；`BattlePlayerAI_after(賽特)` 保持 OFF，`after(非賽特)` 補回 ON。賽特與妮可先各防禦後，下一輪賽特確認靈契目標期間有 `NowMenu=3` 輸入記錄；妮可 after 先把 `ItemType` 設為 `2080`，賽特 after 再維持／設回 `2048`，隨後出現兩次原生 `Battle_Dead(mode=2)`、`additem 59` 與靜態卡交換 `59 → 10024`。這同時證明此場中輸入窗口早於 action 6 target-confirmation gate，且 action 6 在賽特 after 後仍需要 non-Boss。它不需要辨識 private queue，也不依賴 `BattleCriticalHitRate` 或 `Battle_DrawBGI`。

此證據只涵蓋來源 `59`、F3 隔離戰、賽特／妮可與成功收服；妮可此輪只防禦，故「非賽特 after 的 Boss ON 一定令妮可所有傷害正常」仍需以普攻／爆擊實機補測。一般地圖 Boss、敵方回合、收服失敗、取消、逃跑、賽特非靈契攻擊與所有還原路徑也仍待驗證，不能直接併入正式 MOD。

#### BS36 初始化順序

**已實測，Steam HD 4.0.5，2026-09-04，BS36。** Console 依序記錄兩個 `Battle_EnemyInit`、兩個 `Battle_PlayerInit`，再出現原版 `BattleID:BS36`（由 `Battle_Enter.main()` 輸出）。這支持該場戰鬥的初始化 callback 在 `Battle_Enter` 前；不外推成所有戰場、護駕或中途召喚的完整排序。

同場擴充記錄確認：四個 `CheckStatSpecialSkill` 出現在 `MapLoading` 前；進戰後是 `Battle_InputKeyDown`／`Battle_InputClick`，接著才觀察到 `BattleCriticalHitRate`、`BattlePlayerAI_after`、`Battle_Dead`。收妖分支先有另一敵人的 `Battle_Dead(mode=0)`，再有同一隻目標兩次 `Battle_Dead(mode=2)`，其後才是 native `additem 112`，再後為 `BattleGain`。這份摘錄中尚未出現 `Battle_RestoreItem`，所以不推定它與 `BattleGain` 的先後；探針必須等到實際收到該 callback 才輸出該場摘要。

`Battle_DrawBGI` 名稱與原版內容表明它是背景 UI 繪製入口，但尚未以時序探針證明它相對於每次輸入、每個 AI callback 或每幀渲染的精確位置。**已靜態反解，HD 4.0.5、2026-09-05：** native 唯一引數是目前戰鬥行動者 index，不是主選單／action 選項編號；不可用它識別靈契。重新核對同版隔離 exe 顯示，primary dispatcher 只在 UI flag 啟用、`NowMenu != 3` 且 `<100` 時發出此事件；故 action 6 目標確認的 `NowMenu=3` 不是其可依賴時窗。該 UI flag 僅在 process 早期初始化讀到 Lua global `BattlePlayerAI_mod` 為真時開啟，並同時控制 native `BattlePlayerAI` dispatch；已進入遊戲後再設定 global 不會補開。**已實測，4.0.5：** 以該 global 啟動後，玩家手動指令會被原生 AI 操作取代，因此它不是可安全單獨打開 BGI 的 Lua hook。原版 Lua `.main` 雖有 `NowMenu==3` 的視覺清理碼，但 native primary dispatcher 不會在該狀態呼叫它，不能據此推定可掛接靈契確認。`BattleGain`、`Battle_RestoreItem`、勝敗、逃跑與換圖之間也沒有可作通用依賴的完整排序。

### 靈契已知分支

```text
戰前資格／背包基線快照
  → 手動選取與 native 靈契判定（指令 callback 時點待驗證）
  → Battle_Dead(index, 1, 2)
  → native additem（若收服成功）
  → Battle_RestoreItem 的基線比對、交換與還原
```

**已實測，Steam HD 4.0.5。** `Battle_Dead(..., side=1, mode=2)` 可在原生靈契成功時出現，且同一敵人可重複 callback；BS36 的 Console 顯示該 callback 後才有 `additem 112`。因此它只能標記候選，不能在此刻自行刪除來源或加入交換卡。原生靈契轉靜態卡的安全交換步驟與代表案例維護在[戰鬥與背包生命週期](../../../docs/knowledge/battle-and-inventory-lifecycle.md#原生靈契--靜態活物卡)。

**已否決路徑，Steam HD 4.0.5，2026-09-04。** 手動靈契成功的 BS36 測試沒有觸發 `Battle_CmdSelectOK`；不可把它當作靈契成功判定前的暫改入口。`Battle_InputClick` 與敵方初始化資料的實際時點，仍由[靈契指令時序唯讀探針](README.md)量測。

**已實測／已否決公開分流，Steam HD 4.0.5，2026-09-05，BS41。** v0.4 唯讀快照在手動收服野猴（來源 `106`）前觀察到 `_BattleEnv.NowMenu` 由 `1` 轉為 `3`，在 `BattlePlayerAI_after` 時成為 `0`；`AI_Command` 全程仍為 `0`，沒有 `cmd=6`、收服前 `Battle_InputClick`、`Battle_CmdSelectOK` 或可讀目標。`Battle_Dead(mode=2)` 只在原生收服完成後出現。故 `NowMenu` 不是靈契的唯一標記，公開 Lua callback／欄位沒有可安全取消或改派一般手動靈契的入口；此結論不延伸到未公開的 native 指令處理。

**已實測／已否決路徑，Steam HD 4.0.5，2026-09-04，Lv35 對 Lv80 牛魔王隔離戰。** 在敵方 HP `15/100` 時，探針先包裝當前 `Function.CheckObsolt`，基線呼叫得到 `33`；使用者隨後完整執行一次手動靈契，Console 沒有第二次 `CheckObsolt` 呼叫。故手動靈契的原生 UI／成功擲骰不會再進入這個公開 Lua 函式。它可以用於 Lua 端查詢或 UI 前置，但不可作為高等目標的 native 收服率、等級門檻或成功結算覆寫點。

**已實測、受限於自訂戰鬥腳本，Steam HD 4.0.5，2026-09-04。** 原版 `BattleScript.lua` 劇情使用的 `BSC.Obsolt(1,-1)` 是可用的 native 收妖 bridge。於隔離自訂戰場中，`BSC.Enter(1)` 初始化完成後，從同一個 `BattleScript` coroutine 把牛魔王的戰鬥副本由主角 `+11` 還原為 Lv80，再呼叫 `BSC.Obsolt(1,-1)`，可正常完成收妖、`Battle_Dead(mode=2)`、native `additem` 與靜態卡交換，且沒有跨 C 呼叫 yield 錯誤。直接從 Lua event handler 呼叫會 yield 失敗；`GameFunc.RunScene` 在戰鬥內不會進入 Scene。這條路徑可作為「自訂 BattleScript 的原生收妖」證據，**不可**外推成一般地圖遭遇的手動靈契已有安全攔截點。

**已實測、受限於自訂戰鬥腳本，Steam HD 4.0.5，2026-09-04。** 在上述隔離 Lv80 牛魔王戰中，`BSC.Run(1)` 可在玩家手動靈契的一回合完成後返回到同一個 `BattleScript` coroutine。若在該回合前以探針明確武裝，返回後呼叫 `BSC.Obsolt(1,-1)` 可成功完成原生收妖與靜態卡交換。這是「手動回合後接力原生 bridge」的可重現證據；公開 callback 仍沒有可靠地自動辨識靈契命令或目標，故不得把它描述成一般遭遇的無縫攔截方案。

**已否決自動辨識，Steam HD 4.0.5，2026-09-04。** 即使包裝原版 `OnEvent.BattlePlayerAI_after.main`，在它清空 AI 欄位前做快照，回合進入時仍讀到 `AI_Command=0`、預設 target、`AI_SelectItem=0` 與 `BattleEnv.setTarget=nil`，沒有可靠的手動靈契指令或目標資訊。使用者確認未開啟自動戰鬥，故 `AImode` 數值不可單獨對應 UI 操作模式。此結果與 `Battle_InputClick`、`Battle_CmdSelectOK` 與 `Function.CheckObsolt` 的既有否定結果相符：公開 Lua 目前沒有可安全地自動攔截一般手動靈契、並轉交 `BSC.Obsolt` 的時點。

**已靜態反解，Steam HD 4.0.5，2026-09-05，僅限 exe SHA-256 `63F1D83D8C3A756D17640D9022E19F8928741B091F0E47ABBDB22C0CCF6C9523`。** 原生 dispatcher `0x14014ccf0` 確實呼叫 `OnEvent.<event>.main` 與 event table 追加 handler。全域 `InputKeyDown`／`InputKeyUp`／`InputClick` 由輸入管理器以兩個整數引數呼叫；戰鬥專用輸入事件則由 battle update 中的另一條分流以零引數呼叫。原生命令 state machine 的 action code `6`（與 `Const.AI_CATCH=6` 對應）直接進入 native 收妖資格 gate `0x1400752b0`，該 branch 不呼叫 `Battle_InputClick(cmd)`，也沒有通用的 `Battle_CmdSelectOK` 前置呼叫。因此已可更精確地界定：公開 Lua 沒有「已選手動靈契、已知目標、可取消／改派」的 callback；全域 Input event 只可能作為尚待實測的前置信號，不能在未驗證參數、座標、鍵盤／控制器和時序前用於正式機制。原始靜態記錄見 [原生選單／對話按鈕 Coroutine 研究](../swd3-native-menu-probe/NATIVE-CAPTURE-RESEARCH.md#已靜態反解hd-戰鬥輸入與靈契命令分流)。

**已靜態反解，Steam HD 4.0.5，同一 exe。** action code `6` 的 native 收妖 gate 直接讀取戰鬥副本玩家／敵方 Level、HP、物品與種族資料；它不會回呼公開的 `Function.CheckObsolt`。它的等級與 HP 分段和解出 Lua 函式的 `10`、`12`、`1/3`、`1/4`、`80`、`20±` 門檻一致，並以 native 亂數 helper 做機率分支。故覆寫 `Function.CheckObsolt` 只能改 Lua 查詢／AI 參考，不能解除一般手動靈契的 native 高等級門檻；把戰鬥副本 Level 降至門檻內會同時讓原生暴擊、逃跑與 AI 讀到該值。

**已靜態反解，Steam HD 4.0.5，同一 exe。** action selection 把 action `6` 寫進私有全域 queue `DAT_1401aa918[...]` 後，會進入含 `BattlePlayerAI_after` 與 action executor 的 native state machine。其後段由未命名 state `DAT_1401ab44c` 分流：非零分支 dispatch `BattlePlayerAI_after`，零分支才呼叫 action executor；兩者不是同一次 native 呼叫內的線性相鄰事件。因此可確認 after 發生在 action 6 gate 前，卻**不能**推定「after 後立刻執行同一角色」或不同角色的 after／executor 必然交錯順序。此 queue 的 45 個 direct native xref 中，沒有任何一個位於 `_BattleEnv` 或 `BattlePlayers` 的 Lua binding registration；同步 state `DAT_1401aa8f4` 的 43 個 xref 也同樣是零。公開的 `AI_Command`、`AI_PMenu`、`Action_qq` 是不同的 actor userdata offsets，不能當作 queue 的別名。Lua MOD 載入又在 native binding 建立之後，故 `.ssmod` 能新增 Lua table state，**不能**把未註冊 native 位址映射成新 property。不可將 `BattlePlayerAI_after` 當成可安全判別一般手動靈契或傷害完成的入口；若要公開此 queue，必須是 executable patch／native injection，超出 `.ssmod` 發行範圍。完整版本證據見 [原生選單／對話按鈕 Coroutine 研究](../swd3-native-menu-probe/NATIVE-CAPTURE-RESEARCH.md#已靜態反解action-6-與-battleplayerai_after-的同一狀態機分流但命令值沒有公開映射)。

**已靜態反解，Steam HD 4.0.5，同一 exe。** 不可假定靈契 UI 只在戰鬥建立時快取 Boss 資格。戰鬥選單的 action `6` 目標確認 branch 在寫入 queue 前，直接對目前 `BattleEnemys[target]` 呼叫 `NPCROLE.CanObsolt` native helper；該 helper 即時要求目標 bit `0x20`（`IT_06`）為 0、bit `0x800`（`IT_12`）為 1，並檢查一個 `<0x16` 的 16-bit 資格欄位。Boss bit 已恢復時 branch 會中止而不提交 action 6。故「戰前暫清讓 UI 建立、`Battle_Enter` 還原、`BattlePlayerAI_after(賽特)` 再暫清」不可能讓一般手動靈契抵達 native gate；後者只會在前述即時 UI gate 已通過後才執行。原始靜態記錄見 [原生選單／對話按鈕 Coroutine 研究](../swd3-native-menu-probe/NATIVE-CAPTURE-RESEARCH.md#已靜態反解靈契目標確認讀取-live-boss-bit並非只靠戰鬥初始快取)。

### 玩家 AI 指令的已測順序與邊界

**已實測，Steam HD 4.0.5，2026-09-04，隔離牛魔王戰。** 在 `GameStart` 時，`OnEvent.BattlePlayerAI.main` 尚未可供包裝；等到 `Battle_Enter` 才能取得原版 AI main。故需要包裝原版玩家 AI 的研究／功能，不能把 `GameStart` 的「目標不存在」誤判為 API 不支援，應在進戰後重新確認。

**已實測，Steam HD 4.0.5，2026-09-04，隔離牛魔王戰。** 對 `OnEvent.Battle_PlayerAI` 以 `table.insert` 追加 handler，不能令手動模式自行排程回合；直接把 `BattlePlayers[index].AImode` 改為 `1` 也不會通知 native 排程器開始自動回合。使用者透過原生 UI 選擇自動戰鬥後才會開始。這些欄位寫入不應被當成遙控自動戰鬥的公開 API。

**已實測／已否決路徑，Steam HD 4.0.5，2026-09-04，隔離牛魔王戰。** 在 `Battle_Enter` 成功包裝 `OnEvent.BattlePlayerAI.main` 後，使用原生 UI 開啟自動戰鬥；Console 出現 wrapper 已安裝，但實際仍是 native 攻擊，沒有 wrapper 的「已送出靈契指令」紀錄，也沒有原版 Lua AI main 的進入紀錄。相對地，`Battle_PlayerAI_after` 仍會出現。故此戰鬥模式下 native 自動戰鬥可繞過公開 Lua AI main；不能把追加 handler、`AImode` 寫入或 main wrapper 作為靈契指令、機率或等級暫改入口。這不等同證明所有戰場／輸入模式皆如此，但已足以否決它作為正式「只改收服」方案的依賴。

### 高等首領曾可收服的原因

**已實測，Steam HD 4.0.5，2026-09-03，限隔離驗證戰。** 舊有的牛魔王與蚩尤探針不是在 `Battle_EnemyInit` 暫改戰鬥副本；它們在呼叫 `ESC.StartBattle` **之前**，先暫改 `GameData.ItemTemp[來源 ID].Level=1`，再建立自己的戰場。因此引擎建立敵人副本時自然讀到 Lv1，`Battle_EnemyInit` 的紀錄只是確認結果，而非修改入口。兩個探針皆在 `Battle_RestoreItem`、換圖與重啟路徑還原來源模板；牛魔王案例只改資格與 Level，蚩尤案例另將 ATK、SPD、技能暫時清空以降低驗證戰風險。

這證明「在建立戰鬥前改來源模板」可以跨過原版收妖等級門檻，**不**證明存在一條能在一般遭遇戰中只影響收妖、又不影響戰鬥平衡的 callback 路徑。模板 Level 同樣會進入暴擊、逃跑與 AI 等原版計算；它適合有完整還原的隔離實驗，不適合作為「不改戰鬥平衡」的全地圖功能。探針原始證據見 `swd3-high-level-capture-gate-probe` 與 `swd3-story-boss-level-gate-probe` 的 `TESTING.md`。

## 原版戰鬥 callback 完整索引

狀態均為**官方檔內說明**，除非表內另註。此表涵蓋目前原版 Lua 宣告的戰鬥相關 `OnEvent` callback；它不宣稱列出未暴露給 Lua 的 native 呼叫點。`swd3-capture-command-timing-probe` v0.3 會被動追加至表內全部 callback；下列「無目前使用」表示除此唯讀探針外，沒有正式功能依賴該事件。

| 階段 | callback／原版 signature | 原版預設角色 | 目前工作區使用 |
| --- | --- | --- | --- |
| 進戰 | `Battle_Enter()` | 建立戰鬥環境暫態、輸出 BattleField ID。 | `swd3-live-card-battle-mod`：僅在自訂戰場啟用無 Game Over；`swd3-refinery-diagnostics-unlock-mod`：清除煉化預覽並等待戰鬥等級讀取。 |
| 輸入 | `Battle_InputKeyDown()` | 原版預設為空。 | 無目前使用。 |
| 輸入 | `Battle_InputClick(cmd)` | 原版 AI 選取／切換處理；`cmd` 非空時會記錄選取 AI。 | `swd3-capture-command-timing-probe` 唯讀記錄，調查手動靈契附近是否可讀指令與目標。 |
| 輸入 | `Battle_InputDClick()` | 原版只建立 event table，未提供 `.main`；**已靜態反解：** native 雙擊 predicate 成立時以零參數 dispatch。 | 無目前使用；普通單擊／手動靈契未觸發不代表 event 不存在。 |
| 輸入 | `Battle_CmdSelectOK()` | 原版清除 AI 選取狀態，註解為「AI→手動命令選取結束」。 | `swd3-capture-command-timing-probe` 唯讀量測；已否決作為 BS36 手動靈契入口。 |
| UI | `Battle_DrawBGI(active_index)` | 繪製／維護戰鬥背景與 AI UI；**已靜態反解：** `active_index` 是目前戰鬥行動者，不是 action 選項。 | `swd3-refinery-diagnostics-unlock-mod` 同步診斷所需戰鬥等級；不得假定每幀或可作結算點。 |
| 初始化 | `Battle_EnemyInit(index)` | 將 `BattleEnemys[index]` 與 `NPCData` 登錄到原版戰鬥暫態。 | `swd3-live-card-battle-mod` 套用自訂戰場敵方難度；收妖／抗性／時序探針用於隔離研究。全魔物靜態卡庫 v1.7 不再 hook 此事件。 |
| 初始化 | `Battle_PlayerInit(index)` | 將玩家 `CharData` 登錄並初始化玩家 AI 記憶。 | `swd3-guardian-resistance-runtime-probe` 唯讀／隔離護駕資料研究。 |
| 初始化 | `Battle_NPCInit(index)` | 將我方 NPC 的 `NPCData` 登錄，原版也可能依主角等級調整該副本。 | 無目前正式 MOD 使用。 |
| 初始化 | `Battle_KeeperInit(index, itemtabIdx)` | 將護駕的 `NPCData` 與背包物品登錄。 | 無目前正式 MOD 使用。 |
| 狀態變化 | `Battle_Dead(index, side, mode)` | 死亡、逃跑、收妖或 script 結果；`side` 為 0 我方／1 敵方，`mode` 為 0 一般、1 逃跑、2 收妖、3 script。 | `swd3-live-card-battle-mod` 處理自訂戰鬥清理；全魔物卡庫和收妖探針僅標記收妖候選；時序探針只記錄。所有 handler 都必須可重入。 |
| 狀態變化 | `Battle_StopSkill(index, side)` | 技能被封印時重設我方玩家 AI 記憶。 | 無目前使用。 |
| 狀態變化 | `Battle_Freeze(index, side)` | 定身等狀態變更時重設我方玩家 AI 記憶。 | 無目前使用。 |
| 狀態變化 | `Battle_SetActive(index, side, sw)` | 顯示／隱藏角色時重設我方玩家 AI 記憶；`sw` 0 隱藏、1 出現。 | 無目前使用。 |
| 結束／清理 | `Battle_RestoreItem()` | 原版清除背包物品 `Stock`。 | `swd3-live-card-battle-mod` 釋放預留與還原挑戰資料；全魔物卡庫在此比對基線後交換靜態卡並還原 bridge；收妖／抗性探針做清理。 |
| 取消 | `Battle_CancelClick()` | 取消原版 AI 選取狀態；**已靜態反解：** native 以戰鬥狀態 byte 在它與一般 `CancelClick` 間條件選擇，接著零參數 dispatch。 | `swd3-capture-command-timing-probe` 只記錄是否出現；未觸發只能說當次沒有命中其 native 分支。 |
| 成長計算 | `CheckLearnSpecialSkill(index, now_exp)` | 以 `OnEventValue` 回傳可習得絕招與門檻經驗。 | 無目前使用。 |
| 成長計算 | `CheckStatSpecialSkill(index, now_exp)` | 以 `OnEventValue` 回傳絕招經驗結果。 | 無目前使用。 |
| 行動計算 | `BattleCriticalHitRate(BeCriticalHit, Index, Side, TargetIndex, TargetSide)` | 若 native 進入該判定，原版依雙方戰鬥等級再擲骰，寫入 `OnEventValue.BeCriticalHit`。 | **已靜態反解：** 它可在一般攻擊傷害公式前；**已實測 L2：** 防禦的 self-target 流程亦會出現，故不能以 event 存在唯一辨識攻擊。 |
| 行動計算 | `BattleEnemyEscapeRate(Index, Side, PlayerLevel, EscapeRate)` | 依敵方等級與 `EscapeRate` 計算，寫入 `OnEventValue.EscapeRate`。 | 無目前直接 hook；觸發條件與相對於結束流程的時序待驗證。 |
| 結算 | `BattleGain(PlayerExp, Money, MItemExp, SpecialSkillExp)` | 把獎勵寫入 `OnEventValue`。 | `swd3-live-card-battle-mod` 在低難度自訂戰場歸零四項獎勵。 |
| 敵方 AI | `BattleEnemyAI(index)` | 選擇敵方攻擊、技能、治療或特殊攻擊及目標。 | 無目前直接 hook。 |
| 玩家 AI | `BattlePlayerAI(index)` | 依玩家 AI 模式選擇命令與目標。**已靜態反解，HD 4.0.5：** native 在清空該角色選擇暫態、建立可用命令與開啟 command UI 前 dispatch；action queue 尚未寫入。 | 無目前直接 hook；不可把它當成「queue 已建立、下一步即執行」或可靠手動靈契 pre-execution hook。 |
| 玩家 AI 後 | `BattlePlayerAI_after(index)` | 清空玩家 AI 命令、目標與選取物，重設 AI 記憶。 | **已靜態反解＋已實測 L2，HD 4.0.5：** action 已提交後的 state callback；它和 executor／HP 套用屬 native state machine 的不同 branch，並非 after 直接下一行。L2 的兩次致死動作都在相關 after 後才收到 `Battle_Dead`。不同角色的 after／executor 交錯順序和非致死 HP 時點仍待實測。action code 位於未公開的 native queue，不是 `BattlePlayers[index].AI_Command`；手動靈契 wrapper 實測該公開欄位仍為 `0`。不可當作傷害結算、暫態資料還原或可靠的 action 6 判別點。 |
| 護駕 AI | `BattleNPCAI(index)` | 選擇護駕的攻擊、技能、治療或特殊攻擊。 | 無目前使用。 |
