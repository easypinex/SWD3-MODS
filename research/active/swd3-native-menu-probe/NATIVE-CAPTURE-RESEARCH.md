# 原生收妖、旗標與事件反解證據

> 歷史研究紀錄：由原 ENGINE-UI-RESEARCH.md 的戰鬥段落分出，保留假設到否決的順序；下列「待驗證候選」不是現行實作建議。現行結論見[原生靈契](../../../docs/knowledge/native-capture-and-eligibility.md)與[戰鬥時序](../../../docs/knowledge/battle-events-and-timing.md)。分析腳本仍在本專案 tools/ghidra，位址只適用記錄的 exe SHA。

## 已靜態反解：HD 戰鬥輸入與靈契命令分流

**版本與方法。** 2026-09-05 對 Steam HD `swd3.exe` 4.0.5.0 的隔離副本進行唯讀靜態反解；副本 SHA-256 為 `63F1D83D8C3A756D17640D9022E19F8928741B091F0E47ABBDB22C0CCF6C9523`。研究腳本位於 `tools/ghidra/`，不注入、hook 或修改遊戲安裝檔。位址只適用此版本。

1. 原生 `OnEvent` dispatcher（`0x14014ccf0`）會依序呼叫 `OnEvent.<name>.main(...)`，再巡覽同一 event table 的追加 function。這證明 Lua 追加 handler 的執行機制，但不賦予它取消原生輸入或改寫 native command 的權限。
2. 全域輸入管理器會以兩個整數參數呼叫 `InputKeyDown`、`InputKeyUp`、`InputClick`：分別是原生輸入 flag 與 scan code。戰鬥專用 `Battle_InputKeyDown`／`Battle_InputClick`／`Battle_InputDClick` 是另一條分流，固定以 **0 個 Lua 參數** 呼叫。
3. 原生戰鬥命令 state machine 的 action code `6` 是靈契（與原版 `Const.AI_CATCH=6` 一致）。該 code 不會呼叫 `Battle_InputClick(cmd)`；該 callback 只在另一個原生選取分支使用。`Battle_CmdSelectOK` 也不是 action 6 的通用前置 callback。
4. action code `6` 會直接進 native 收妖資格 gate `0x1400752b0`。在命令選取到此 gate 之間，沒有可被 `.ssmod` Lua 追加的「靈契已選／目標已定」callback。它直接讀取戰鬥副本的玩家與敵人 Level、HP、物品／種族可捕捉旗標並擲骰。
5. `BSC.Obsolt` 的 Lua binding 本身只設定原生戰鬥的靈契狀態旗標與 state；它不接受「玩家、敵人」作為公開且獨立的收服 API。先前隔離 BattleScript 內的成功，是在原生 coroutine 與既有目標狀態下接力，不能外推為一般遭遇戰可直接呼叫的替代命令。

這些結果修正了早期只靠 public callback 觀察的界線：戰鬥事件並非沒被 native 呼叫；問題是原生手動靈契的 command code 6 沒有提供可攜、可取消的 Lua 分流點。全域輸入是否能作為「唯讀辨識 UI 點擊」的前置信號仍需實機量測；在驗證前不得以座標猜測作正式功能。

## 已靜態反解：action 6 與 `BattlePlayerAI_after` 的同一狀態機分流，但命令值沒有公開映射

**版本與方法。** 同一 HD 4.0.5 隔離副本。`ReportHdAction6PreDispatch.py` 由 action 6 gate 反向追到玩家命令流，`ReportHdBattleStateBindings.py` 與 `DecompileHdBattleLuaBindings.py` 盤點 Lua binding；`ReportHdBattlePlayerActionStateSplit.py` 與 `ReportHdBattleAfterStateRefs.py` 交叉檢查 `BattlePlayerAI_after` 與 executor 的 state 分流；既有手動靈契唯讀探針結果交叉驗證公開欄位。

```text
native 命令選取 case 6
  → 寫入私有 action queue = 6
  → native 整理／提交 helper
  → native 狀態機：可能 dispatch `BattlePlayerAI_after(index)`
  → 後續 state：native action executor
  → executor case 6 收妖 gate
```

1. 在 `0x140044ab0` 的 action case 6，native 先把 `6` 寫入私有 command queue `DAT_1401aa8f4` 與每位行動者的 `DAT_1401aa918[...]`，再提交此行動。`ReportHdBattlePlayerActionStateSplit.py` 顯示後段以未命名 state `DAT_1401ab44c` 分流：非零分支呼叫 `FUN_140072060` 與 `BattlePlayerAI_after(index)`，零分支才呼叫 action executor `0x140040820`。兩者不是同一次進入函式的線性相鄰呼叫；executor 的 case 6 才進入收妖 gate `0x1400752b0`。因此可以說 callback 早於收妖 gate，但**不可**由此推出「某角色的 after 後立刻執行同一角色」或不同角色 after／executor 的交錯順序。
2. 但 queue 不是公開 Lua state。`_BattleEnv` 的 native registration 只暴露 `PlayerIDMax`、`EnemyIDMax`、`AI_Ready_OK`、`isShowFaceIcon`、`NowMenu`、`CantRetreat`、兩個 limit rate 與目前選取玩家 getter／setter；沒有 queued action／target getter。`BattlePlayers[index].AI_Command` 是另一個 userdata 欄位（offset `0x39dc`），不是上述 action queue。
3. 原版 `BattlePlayerAI_after.main` 會清空 `AI_Target`、`AI_Command` 與 `AI_SelectItem`。更重要的是，已實測的 v0.5 wrapper 在呼叫原版 `.main` **之前**，手動模式仍只讀到 `AI_Command=0`、預設 target 與無選取物；這和 `swd3-capture-command-timing-probe` 的手動靈契結果一致。故不是單純把 handler 排到 `.main` 前面就能看到 native action 6。
4. `InputKeyDown`／`InputClick` 可能發生在命令選取更早期，但只提供輸入旗標、scan code 或滑鼠位置，不會提供已解碼的 action／target。用固定 UI 座標猜 action 6 仍缺少鍵盤、控制器、取消、解析度與目標選取的安全證據，不能作正式 `.ssmod` 分流。

補充的交叉檢查（`ReportHdQueuedActionLuaExposure.py`）：`DAT_1401aa918` 有 45 個 direct xref，`DAT_1401aa8f4` 有 43 個 direct xref；兩者在 `_BattleEnv` 與 `BattlePlayers` 的 Lua registration routine 內都是 **0** 個。公開的 `AI_PMenu`（actor offset `0x39e0`）、`AI_Command`（`0x39dc`）與 `Action_qq`（`0x3568`）都是每個 actor userdata 的成員，並非此全域 queue。Lua binding 初始化也在載入 `.ssmod` 前完成，所以 MOD 可建立自己的 Lua table 欄位，卻不能以 Lua 新增「讀取這個 native 位址」的 getter。

### 已靜態反解：靈契目標確認讀取 live Boss bit，並非只靠戰鬥初始快取

同一 HD 4.0.5 副本以 `ReportHdCaptureUiEligibility.py` 反解戰鬥選單 transition `0x1400574a0`。當目前選取 command 是 `6`，且玩家正確認一個敵方目標時，native 在**寫入 private action queue 之前**呼叫 `FUN_14007a060(&BattleEnemys[target])`。此 helper 直接讀取該戰鬥敵人資料的 flag word：bit `0x20` 必須是 0、bit `0x800` 必須是 1，另有一個 `< 0x16` 的 16-bit 資格欄位；任一條件不合即 `break`，不提交 action 6。

因此「戰鬥建立前暫清 `IT_06` 讓 UI 快取可用、`Battle_Enter` 立刻恢復 Boss、等 `BattlePlayerAI_after(賽特)` 再暫清」已被靜態反證：目標確認當下 bit 若已恢復為 Boss，UI branch 就不會產生 action 6 queue，自然也到不了 `BattlePlayerAI_after`。此前 UI 是否只讀初始快取的假設不成立；不是進一步實機測試的候選正式路徑。

**待驗證候選（因 action 6 僅限賽特）。** 不必知道 queue 裡是不是 `6`，只需在賽特進入手動命令 UI 時維持非 Boss。`ReportHdBattleDrawBgiTiming.py` 顯示每個 battle update 先呼叫 `Battle_DrawBGI(active_index)`，接著才進下一段 UI／命令處理；`Battle_DrawBGI` 只在 `NowMenu != 3` 時 dispatch，而 action 6 選到目標後進入的正是 `NowMenu=3`。故可建立一個**隔離、只在旗標狀態改變時寫入**的探針：收到 `Battle_DrawBGI(1)` 時暫清目標 Boss bit；收到其他 index 或 nil 時恢復。若 index 在整段賽特選單／目標確認保持為 1，live `CanObsolt` UI gate 與後續 native gate 都會讀到非 Boss；目標確認期間 DrawBGI 暫停，因此不會在中途自行覆寫。

#### BGI 啟動條件與隔離反例

**已重新靜態反解，Steam HD 4.0.5，2026-09-05。** 對同一 SHA-256 的全新隔離副本重新執行 `ReportHdBattleDrawBgiTiming.py`，native dispatcher `0x1400402a0` 的條件為：戰鬥 UI flag 啟用、`NowMenu != 3`、且 `NowMenu < 100`；條件成立時才以目前命令中的玩家 ID（或無玩家時零引數）dispatch 字串 `Battle_DrawBGI`。此副本中唯一的可執行 native caller 是每次 battle update 的 `0x14003f640`。原版 Lua `OnEvent.Battle_DrawBGI.main(select_index)` 的名稱、拼字與 1 個可選 index 都正確；它負責新版戰鬥的背景、臉像與 AI 模式按鈕繪製，不是回合結算／命令確認 callback。該 Lua main 雖含 `NowMenu==3` 的防禦分支，但 primary native dispatcher 在此狀態不呼叫它；目前沒有另一個 native caller 能把那條 Lua 分支提升為 action 6 期間的可依賴 hook。

**已靜態反解，Steam HD 4.0.5，2026-09-05。** 上述「戰鬥 UI flag」不是 Lua 可任意設定的普通欄位。`ReportHdBattleDrawBgiEnableFlag.py` 顯示 native 初始化函式 `FUN_140146a50` 只查詢 Lua global `BattlePlayerAI_mod`；回傳值為真時才把該 flag 設為 1。相同 flag 亦是 `BattlePlayerAI` native dispatch 的前置條件，因此此 global 會同時啟用 BGI 與玩家 AI callback。`ReportHdBattlePlayerAiModEnableTiming.py` 再追到此查詢只經 `FUN_1401507a0`，由早期主初始化 `FUN_14009d4b0` 呼叫；它是在一般 Lua／戰鬥流程前的啟動快照，已進入地圖後才設定不會補開。故 v0.4 隔離探針在 DAT 載入期宣告 `BattlePlayerAI_mod=true`，且每次測試必須完整結束 process 後才可移除該效果；是否在實機確實產生 BGI callback 仍待 F3 測試。

**已實測／已否決此開關作為純 `.ssmod` 候選，Steam HD 4.0.5，2026-09-05。** 完整重啟載入 `BattlePlayerAI_mod=true` 的 v0.4 隔離探針後，Console 確認 global 已在 boot snapshot 前成立；但使用者立刻失去自由點擊戰鬥指令，角色完全由 AI 操作。這與同一 flag 控制 native `BattlePlayerAI` dispatch 的靜態結果一致，證明它是玩家 AI MOD 模式的一部分，而非可單獨開 BGI 的觀察 hook。此模式會破壞「維持原版手動戰鬥 UI」這一正式需求，因此不再進行 F3 BGI 稽核，也不得併入全魔物靈契。

**已實測的條件窗口與其限制，Steam HD 4.0.5，2026-09-06，F3 隔離牛魔王。** 沒有可 Lua 寫入的 Boss UI 快取；目標確認直接讀 live bit `0x20`。但不需 queue 映射即可作條件窗口：`NowMenu=1/3` 的輸入時清 Boss，賽特 after 保持 OFF，非賽特 after 設回 ON。賽特、妮可先各防禦後，下一輪賽特 action 6 在 `NowMenu=3` 輸入後通過；妮可 after 先設 ON、賽特 after 設 OFF，隨後原生 `Battle_Dead(mode=2)`、加來源物與靜態卡交換完整發生。這是「賽特唯一可靈契」前提下可用純 `.ssmod` 的隔離收服證據，並間接支持 action 6 executor 在賽特 after 後仍讀 live Boss bit。

它尚不是正式功能。妮可在成功場只防禦，未證明其普攻／爆擊的 Boss 分支；賽特的非靈契攻擊、奇術與物品，敵方回合、一般地圖 Boss、收服失敗、取消、逃跑與全部還原路徑都未驗收。`Battle_DrawBGI` 仍不可用：其 index 是行動者而非命令選項、`NowMenu=3` 不 dispatch，且開啟所需 global 會接管手動指令。

**結論（已靜態反解＋已實測）。** private queue 到 Lua 的可讀映射確實不存在，故純 `.ssmod` 不能精確辨識「這一個已提交的動作就是 action 6」。但在「action 6 僅賽特可用」的產品前提下，無需辨識它：以輸入 `NowMenu=1/3` 清 Boss、賽特 after 保持 OFF、非賽特 after 還原 ON，已在隔離戰完成原生 action 6。是否能安全接入正式一般戰鬥仍取決於上述未完成的平衡與生命週期驗收，不需要先做 executable patch／native injection。

### 已靜態反解：`BattlePlayerAI` 不是「queue 已建立、等待執行」事件

`ReportHdBattlePlayerAiTiming.py` 對 native player command flow `0x140044ab0` 的結果：`BattlePlayerAI(index)` 先清空該角色的選取／目標暫態，然後建立可用命令並開啟 command UI（`NowMenu=1`）。action queue `DAT_1401aa918[...]` 的寫入在之後的 command switch；確認選項與目標後才寫入。因此它是**命令選擇的前段**，不是已排入 queue、即將執行 action 的 callback。

反之 `BattlePlayerAI_after(index)` 是 command 已提交後、action executor 前的 state callback；但它看不到 queue 值，且**不保證緊貼**該 executor。既有手動戰鬥 log 也沒有穩定看到 `BattlePlayerAI`，故不能把它當作一般手動靈契的可靠 pre-execution hook。這排除「用 `BattlePlayerAI` 在賽特真正執行 action 6 前才暫清 Boss bit」的解讀；也要求以實機 trace 驗證「賽特 after → 賽特 executor → 妮可 after」是否真的成立，不能假定。

## 已靜態反解：不在 `OnEvent` 表中的 native Lua 呼叫，及其邊界

**版本與方法。** 同一份 Steam HD 4.0.5.0 隔離副本與 SHA-256；以 `InventoryHdNativeLuaEvents.py`、`DecompileHdDynamicEventDispatchers.py`、`DecompileHdAlternateBattleDispatch.py`、`SummarizeHdCallbackHelpers.py` 唯讀列舉 native dispatcher 與其 callers。這是對「原版 Lua 表可能不完整」的直接檢查，不以 Lua 宣告表作結論。

1. 先前從 Ghidra 已辨識 function 的 direct callers 取得 **33 個 literal 名稱**：`BattleCriticalHitRate`、`BattleEnemyAI`、`BattleEnemyEscapeRate`、`BattleGain`、`BattleNPCAI`、`BattlePlayerAI`、`BattlePlayerAI_after`、`Battle_CmdSelectOK`、`Battle_Dead`、`Battle_DrawBGI`、`Battle_EnemyInit`、`Battle_Enter`、`Battle_Freeze`、`Battle_InputClick`、`Battle_KeeperInit`、`Battle_NPCInit`、`Battle_PlayerInit`、`Battle_RestoreItem`、`Battle_SetActive`、`Battle_StopSkill`、`CheckLearnSpecialSkill`、`CheckStatSpecialSkill`、`CompanyInMap`、`DrawMenuAfter`、`GameStart`、`InputClick`、`InputKeyDown`、`InputKeyUp`、`MapLoaded`、`MapLoading`、`Obsolt`、`PlayerMove`、`SysInit`。這是 **function-bound inventory**，不是所有可達 basic block 的完備證明；後續交叉檢查正是為了避免漏掉未被 Ghidra 劃入 function 的 tail。
2. 此 dispatcher 的兩個 non-literal callers 也已逐一反解：一個只在 `Battle_InputKeyDown`／`Battle_InputClick`／`Battle_InputDClick` 三個零參數輸入名稱間切換；另一個只產生 `Battle_Freeze`／`Battle_StopSkill` 狀態事件。它們不是 action code 或「命令確認完成」事件。
3. 另有獨立 helper `0x14014dc20 → 0x14014dd30`，不經 `OnEvent` table，而是把兩個整數寫入內部 BattleEnv scratch 欄位後，以名稱查找並呼叫 Lua。這證明「`OnEvent` 表不是 native→Lua 的完整宇宙」。不過 HD exe 中只存在兩個這類名稱：`BattleEnv_MemberSkillType` 與 `BattleEnv_MemberItemType`；原版 script index 也沒有它們的 Lua 宣告。
4. 兩個 `BattleEnv_*` 呼叫都在戰鬥 UI 的**奇術／物品子分類**切換分支；其 payload 是目前行動者索引與分類索引。已追到的 action code `6` 靈契分支既不呼叫此 helper，也不提供目標或靈契選取結果。因此它們是值得保留的未公開 Lua 呼叫面，但不是「高等靈契」的指令分流點；不得拿來在一般 Boss 戰中暫改 `IT_06`。
5. 同次反解更正了原版 `Battle_DrawBGI(select_index)` 的命名誤導：native 傳入的是目前戰鬥行動者 index，不是主選單 action／靈契選項編號。它同樣不能辨識 action 6。

**結論（已靜態反解）。** 你的前提是正確的：不能因 `OnEvent_Battle.lua` 沒有名稱就宣稱沒有 native Lua 呼叫，也不能把「Ghidra 沒有替 basic block 建 function」誤當成沒有 dispatch。後續的原版戰鬥表逐項字串 xref 交叉檢查顯示，表內 21 個名稱都接到 HD native（詳見下一節）。在 action 6 的已追 command branch 與已找到的第二條 named-Lua bridge 中，仍沒有「手動靈契已選、目標已定」callback。這是「目前找不到可封裝 `.ssmod` 分流點」的版本限定證據，不是宣稱所有未來 HD 版本都不存在。

## 已靜態反解：原版戰鬥 event table 不是未接線，而是條件式呼叫

**版本與方法。** 同一 HD 4.0.5 隔離副本。`ReportHdBattleEventStringRefs.py` 逐項取得 `OnEvent_Battle.lua` 定義的 21 個 event 名稱在 exe 內的 data xref，再追其原生 dispatcher call；`ReportHdBattleInputEventConditions.py` 補看輸入／取消／確認三種容易在 Console 觀察不到的條件分支。

1. **25/25 都有 native data xref。** `OnEvent_Battle.lua` 的 21 個名稱，加上 `OnEvent_BattleEnemyAI.lua`、`OnEvent_BattlePlayerAI.lua`、`OnEvent_BattleNPCAI.lua` 的四個 AI callback，全部各有至少一個 HD exe data xref；沒有任何一項是「Lua 檔建立 table、HD exe 完全沒有接線」的殘留名稱。
2. **`Battle_CancelClick` 是先前 inventory 漏項，不是未呼叫。** `0x1400b09a0` 比較一個未命名 native byte；非零時載入 `Battle_CancelClick`，零時改載入一般地圖／選單的 `CancelClick`，接著以 `JMP 0x14014ccf0` 尾端呼叫 Lua dispatcher。這個 basic block 緊接前一個 `RET`，沒有被 Ghidra 自動歸屬 function，故「只枚舉 function caller」漏掉它。該 byte 的確在戰鬥生命週期相關函式被設／清，但其精確欄位名稱仍待驗證。
3. **`Battle_InputDClick` 也確實接線。** 它在 `0x140053ae0` 先通過原生雙擊 predicate `0x1401240c0` 才以零參數 dispatch；普通單擊、鍵盤確認、或 action 6 的 command branch 都不會自然滿足這條路徑。因此「一次手動靈契沒有 log」不能證明該 event 不存在，只能證明當次輸入不是 native 認定的雙擊。
4. **`Battle_CmdSelectOK` 有兩個狹窄 caller。** 一個在戰鬥 UI state transition `0x1400574a0`，另一個在 AI／命令 transition `0x140044ab0`；兩者都是狀態清理後才 dispatch，並非每次選主選單 action 都發送。已追到的 action 6 收妖 branch 不會通過這兩個 caller，所以它仍不能作靈契前的分流點。

**修正後的判讀。** 原版 event table 是引擎可在特定狀態下呼叫的 callback schema，而不是「每個事件在每場戰鬥、每個按鍵或每個 command 都必發」。早期實機 probe 未看到某 event，最多表示操作沒有命中它的 native predicate；不可再將其記為「native 沒有呼叫」。

## 已靜態反解：`IT_06` bridge 與 9999 爆擊的關係

**版本與方法。** Steam HD 4.0.5.0、`swd3.exe` SHA-256 `63F1D83D8C3A756D17640D9022E19F8928741B091F0E47ABBDB22C0CCF6C9523`；同一份唯讀 Ghidra 專案。以下是 native control flow 的證據，不是以 Lua callback 推測。

1. action code `6` 的收妖 gate 是 `0x1400752b0`；它只讀取目標的捕捉資格、等級與 HP，並回傳可否收妖。該函式沒有呼叫一般攻擊傷害函式，也沒有寫入傷害累計值。因此「按靈契」本身不是 9999 的傷害來源。
2. 同一 gate 將來源物件 flag word 的 bit `0x20` 視為拒絕條件，並同時要求 bit `0x800`。這與原版 `IT_06=true`／`IT_12=true` 的已知資格語意相符：`IT_06` 對應 bit `0x20`，`IT_12` 對應 bit `0x800`。
3. 一般攻擊的爆擊旗標由 `BattleCriticalHitRate` callback 回傳後寫入攻擊者；一般攻擊路徑為 `0x1400712c0 → 0x1400786b0 → 0x140089570`。最終的 `0x1400786b0` 對任何 `>=9999` 的計算結果都套用 `9999` 上限，故畫面上的 9999 是 cap，不是普通傷害公式恰好算出 9999。
4. `0x140089570` 的爆擊專用分支也讀取**相同目標物件的 bit `0x20`**。該 bit 存在時會跳過一個將傷害基準提高到目標戰鬥數值門檻的特殊分支；bit 被清除時，該分支可執行，結果再被上述 9999 cap 截斷。這與「原版劇情／首領目標正常，將 `IT_06` 暫清後妮可爆擊固定顯示 9999」相符。

**結論（已靜態反解＋既有 A/B 實測）。** 全魔物靈契為了通過 action 6，對所有來源執行 `IT_06=nil`；這不只是收妖 UI 資格，而是同時移除了 native 爆擊傷害分支用來辨識特殊目標的 flag。這是目前 9999 的直接機制。`IT_12=true` 與 `Race.catch=true` 仍是收妖資格的一部分，但尚未發現它們進入這條爆擊分支。

**重要界線。** 此結果不能用「戰鬥等級封頂造成 9999」解釋。以已回報的玩家 Lv58 對 Lv68 目標為例，`+11` 封頂不會改動 Lv68；該樣本反而排除等級下修是其必要條件。等級下修仍會影響原版其他戰鬥判定，故也不適合留在追求原版戰鬥平衡的正式版，但它不是本次 9999 的根因。

**專案決策。** 在能以不改動原戰鬥目標 `IT_06` 的方式接入收妖前，不得把「全魔物靈契」宣稱為不影響原版戰鬥平衡的正式 MOD；現有 bridge 僅可作研究／隔離驗證用途。

## 已靜態反解：非致死傷害後沒有可用 Lua 還原點

**版本與方法。** Steam HD 4.0.5.0、同一份 SHA-256 已驗證副本；使用 `ReportHdDamageCompletionEvents.py` 與 `ExtractHdDispatcherContexts.py` 唯讀列出 native call sites。此結論只涵蓋已追到的標準一般攻擊非致死路徑。

1. `BattlePlayerAI_after` 在 native AI／命令選擇函式 `0x140044ab0` 呼叫；它接在 `FUN_140072060` 後，但一般攻擊尚未進入 command state machine。這與既有實機 log 中「`BattlePlayerAI_after` 後仍等待 HP 更新」一致。
2. 一般攻擊之後才由 command state machine 進入 `0x1400712c0 → 0x1400786b0 → 0x1400851b0`；其中 `0x1400851b0` 是 HP 套用 helper。`0x1400786b0` 本身及已追到的直接非致死呼叫鏈沒有呼叫 Lua event dispatcher `0x14014ccf0`。
3. command state machine 可在死亡時呼叫 `Battle_Dead`，但未找到「非致死傷害已套用」的 `Battle_*` callback。`Battle_Dead` 對暫態 flag 還原而言已太晚，且不會覆蓋存活目標。

**已否決路徑（限 Steam HD 4.0.5）。** 「在 `BattleCriticalHitRate` 暫補 Boss bit、於 `BattlePlayerAI_after` 還原」沒有正確時序；後者在傷害前。現有公開 Lua event 中，也未發現能在每次非致死傷害後、下一次命令前還原的 callback。因此不能把這個暫態 `ItemType` workaround 接入 `.ssmod` 正式 MOD。`NPCData.ItemType` 的 Lua 可寫性即使另獲證實，也不改變缺少安全還原點的結論。

**已實測佐證，Steam HD 4.0.5，2026-09-05，F3 隔離牛魔王戰。** `swd3-seth-capture-window-probe` 以 `Battle_Enter` 清 Boss bit，並在 `BattlePlayerAI_after(賽特)` 清、`BattlePlayerAI_after(妮可)` 設回。第一輪妮可傷害正常；但在妮可行動後進入下一輪賽特 UI 時，bit 仍為 Boss，原生 action 6 目標確認拒絕靈契，且該場沒有觀察到 `Battle_DrawBGI` 可作復位點。這是對上述靜態「非致死 HP 寫入後沒有 Lua dispatcher」結論的行為層佐證，不把單次未出現 `Battle_DrawBGI` 外推為其在所有戰場永不觸發。

**已實測補強，Steam HD 4.0.5，2026-09-05，BS34 自然戰鬥。** 明確操作「賽特防禦 → 妮可普攻 → 妮可防禦 → 賽特攻擊」中，第二次妮可 `BattlePlayerAI_after`（#194）後，下一個公開訊號已是賽特選單的泛用 input（#195 起、`NowMenu=1`）；沒有 active player callback、queue 映射或可唯一識別攻擊的計算 callback。這否決「after(妮可) 開 Boss、等 active-player=賽特 event 再關」的 actor-specific 方案。

**待驗證候選，依既有 static／L2 evidence，Steam HD 4.0.5。** active player 並非必要條件的話，可在任何輸入 callback 讀到 `NowMenu=1` 或 `3` 時關 Boss，並在每個 `BattlePlayerAI_after` 開 Boss。這利用已靜態反解的事實：action 6 target-confirmation 的 `CanObsolt` 在寫 private queue 前才讀 live flag；也利用 L2 的 `input → 計算 callback → after → death` 樣本，讓妮可傷害前有 after 補回 Boss。它仍缺兩項實測：input dispatcher 對 action 6 gate 的精確先後，以及 queue 後的 native capture executor 是否重讀 Boss flag。`Battle_DrawBGI` 仍不可用，因其開關會接管手動指令；但這個 input-window 方案不依賴 BGI。必須建立一次性 no-save probe 驗證，不能先併入正式 MOD。

### 專案評估：以「賽特整個行動窗」暫清 Boss bit

**已靜態反解／待驗證的提案，不可作正式功能。** `BattlePlayerAI_after(index)` 的 `index` 可辨識賽特，因此技術上可嘗試在該 callback 對賽特的行動暫清 bit `0x20`。但它不是「靈契行動」標記，而是該角色的所有行動：普攻、奇術、物品、防禦與靈契都會共用此窗。對普攻而言，清除 bit 仍會讓後續 native 傷害路徑讀到非 Boss；這正是妮可 9999 的已知成因，不能因賽特目前未觀察到 9999 就宣稱安全。

更根本的是，`BattlePlayerAI_after` 與 action executor 是同一 native state machine 的兩個**不同 state 分支**；已靜態反解沒有提供「after 後立刻執行同一角色」或「下一名角色 after 必在前一名角色 executor 後」的保證。已追到的一般攻擊非致死路徑也沒有 Lua dispatcher；`Battle_Dead` 又只覆蓋死亡。因此沒有可保證「賽特這一次行動已完全結束」的公開 callback 可還原 bit。以 `BattleCriticalHitRate` 還原會落在傷害公式**之前**，使暫清無法只服務收妖；以後一名角色的選擇 callback 還原，則可能讓下一次行動已經讀到錯誤 flag。`Battle_SetActive` 是角色顯示／隱藏事件，不是回合切換或行動完成事件。

此外，若戰鬥開始時 bit 保持 Boss，原生 UI／命令選取可能根本不開放靈契；若戰鬥開始時先清 bit 讓 UI 快取通過，又需要另一條已證明的「UI 快取完成、第一個傷害前」還原時點，目前同樣不存在。故這個策略最多能成為隔離探針，不能解決「一般戰鬥、所有 Boss 可靈契、原版傷害不變」三項正式需求。
