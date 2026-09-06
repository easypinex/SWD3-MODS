# 戰鬥事件時序唯讀探針

> 研究來源：本頁保存所列版本的操作與證據。是否重用、知識去向及未解問題，先查[研究清冊](../../README.md)；通用能力依[知識庫](../../../docs/knowledge/README.md)，不因歸檔或 mock 通過擴張為正式支援。

這是 Steam HD 4.0.5 的**被動式全戰鬥 callback 記錄器**。它把每場實際經過的公開戰鬥事件記成帶序號的 Console 訊息，並在 `Battle_RestoreItem` 輸出次數摘要與順序前綴。

它不寫入 `NPCData.Level`、`ItemTemp`、HP、機率、背包、存檔、戰場、`OnEventValue` 或原生 callback；不建立新卡，也沒有快捷鍵。只使用 `table.insert` 追加自己的唯讀 handler。

完整事件清單、目前已知順序與證據界線見共用文件：[戰鬥事件與時序](../../../docs/knowledge/battle-events-and-timing.md)。

## 現行來源版本與驗證範圍

**來源核對，2026-09-06。** [來源 metadata](src/swd3_capture_command_timing_probe.ext)為 `MODVersion 0,5`，目標研究環境為 Steam HD 4.0.5；`MODGameVersion 4,0` 是載入相容宣告，不證明其他 4.0.x 已實測。

- 現行操作使用 v0.5；[v0.5 建置證據](#v05-建置與待測)記錄 2026-09-05 的 mock、封裝與反解結果。v0.5 的滑鼠／全域輸入配對仍待測。
- v0.1／v0.3 的 BS36、v0.4 的 BS41 及 L2 保持原案例範圍，見[已知證據](#已知證據與邊界)與[逐版驗收](#驗收)，不視為新版全事件回歸。
- [現行 Lua](src/data/CaptureCommandTimingProbe.lua)的載入訊息以 `loaded: read-only command-routing trace is armed` 開頭；訊息沒有版號，須另核對實際載入封包與來源／反解雜湊，不能只憑訊息認定 v0.5。

## 指令分流研究：唯讀選單快照

v0.5 在每個已觸發的 callback 補記下列**既有且原版 Lua 已讀取**的欄位：`_BattleEnv.NowMenu`、`_BattleEnv.bBattleCmdPause`、玩家／敵方數量、`BattleEnv` 的 AI 選取暫態，以及目前滑鼠座標。它不列舉 native userdata、不呼叫 native 方法、不改寫輸入、命令或選單。

此外，v0.5 追加記錄原版 HD `OnEvent_Input.lua` 已宣告的全域 `InputKeyDown/InputKeyUp/InputClick/InputDClick(KeyFunc_flag, Key_SCANCODE)`；只在 `Battle_Enter` 至 `Battle_RestoreItem` 之間輸出。這用來驗證全域輸入事件是否在戰鬥內取得按鍵旗標與掃描碼，和無參數的 `Battle_InputKeyDown` 比較。它仍不攔截或取消輸入。

這一版只回答：「點原生靈契前後，公開 Lua 是否看得到可唯一辨識的選單／選取狀態轉換？」它**不**攔截、取消、轉接或執行收妖。請以**滑鼠**在同一場安全戰鬥依序點一次攻擊、物品、靈契與取消；靈契可選擇一隻可正常收服的低等敵人。完成後提供從第一次點選靈契到 `Battle_Dead(mode=2)` 或失敗提示之間的 Console 記錄。

v0.4 的 BS41 已留下泛用 `NowMenu` 變化與 `AI_Command=0` 的結果，見[BS41 案例](#bs41-v04-手動靈契)。v0.5 的任務是補全域輸入與實際操作的配對；未取得新結果前，設計邊界依[現行原生靈契正文](../../../docs/knowledge/native-capture-and-eligibility.md#公開-lua-能力與不可採用的推論)，不沿用早期「下一階段必須 native hook」的推測。

## 一次擴大觀察範圍

現行 v0.5 保留自 v0.3 起記錄的下列原版戰鬥 callback，另加上前節的全域輸入：

- 進場、輸入、命令確認與 UI：`Battle_Enter`、`Battle_InputKeyDown`、`Battle_InputClick`、`Battle_InputDClick`、`Battle_CmdSelectOK`、`Battle_DrawBGI`。
- 全部初始化：`Battle_EnemyInit`、`Battle_PlayerInit`、`Battle_NPCInit`、`Battle_KeeperInit`。
- 行動、狀態與結束：`Battle_Dead`、`Battle_StopSkill`、`Battle_Freeze`、`Battle_SetActive`、`Battle_RestoreItem`、`Battle_CancelClick`。
- 計算與獎勵：`CheckLearnSpecialSkill`、`CheckStatSpecialSkill`、`BattleCriticalHitRate`、`BattleEnemyEscapeRate`、`BattleGain`。
- AI：`BattleEnemyAI`、`BattlePlayerAI`、`BattlePlayerAI_after`、`BattleNPCAI`。

所以不必為每個新問題另做一個 MOD：保持探針啟用並正常遊玩幾場戰鬥，即可取得每場實際觸發的集合和順序。它不會強制觸發原本不會出現的事件；例如護駕、我方 NPC、封印／定身、敵方逃跑與絕招成長，仍只會在遊戲本來走到該分支時被記錄。

限流數值依[現行 Lua](src/data/CaptureCommandTimingProbe.lua)的 `EVENT_LIMITS`：`Battle_DrawBGI` 3 次；`InputKeyDown`／`InputClick`／`Battle_InputClick` 40 次；`InputKeyUp`／`InputDClick` 20 次；AI、暴擊與逃跑計算各 24 次；`Battle_InputKeyDown` 與其餘事件各 12 次。超出的次數仍計入摘要，但細節不再逐次輸出；量測若超限，摘要不能代替遺失的完整操作配對。

## 實機操作

1. 使用可丟棄的測試存檔，啟用本探針與想觀察的正式 MOD。要檢查全魔物卡庫的收妖鏈，可同時啟用該卡庫；其他會改收妖規則的舊探針保持停用。
2. 依[封裝與安裝](../../../docs/knowledge/packaging-and-installation.md)核對 v0.5 封包及實際載入來源，完整關閉遊戲後安裝；再依[本機啟動流程](../../../docs/knowledge/tools-and-commands.md#本機實機啟動流程)開 Console 與遊戲。確認 `loaded: read-only command-routing trace is armed`，版本識別限制見[現行版本](#現行來源版本與驗證範圍)。
3. 正常進入一場可安全離開的戰鬥。若自然方便，做一次手動指令、取消、靈契、擊倒或逃跑；不需要為了探針刻意重複同一個測試。
4. 戰鬥結束後搜尋兩行：`battle summary` 顯示本場所有實際 callback 次數；`battle order prefix` 顯示前 80 個實際觸發順序。要研究靈契時，再查看 `Battle_InputClick`、`Battle_CmdSelectOK`、`Battle_Dead(mode=2)` 與其間的序號。
5. 可以讓探針跨多場正常遊玩持續蒐集；每場在 `Battle_RestoreItem` 後重設自己的摘要。完成蒐集後停用即可，沒有資料需要還原。

## 角色指令生命週期量測（L1–L5）

一般「正常玩一場」只能證明 event 曾發生，不能回答它是整場一次、每輪一次、每名角色一次，還是某個動作的條件式分支。要建立生命週期證據，直接依 [EVIDENCE 的 L1–L5 操作表](EVIDENCE.md#尚缺的生命週期證據與標準量測組合)選擇所需案例；既有結果與尚缺項目不可混同。

每場要額外提供：

1. 角色實際點選順序，例如「賽特防禦 → 妮可防禦 → 下一輪賽特防禦」。
2. 從首次操作到 `Battle_RestoreItem` 的完整 Console 區段，而不只 `battle summary`／`order prefix`。
3. 是否發生暴擊、敵方死亡、逃跑或收妖。

探針只做旁觀記錄，不能替玩家在 Console 標記「第幾輪」。角色 index、輸入序號與 L1–L5 的人工操作紀錄必須一起判讀，才不會把原生預先收集指令、速度排序執行或條件式傷害 callback 誤解為固定回合順序。

## 判讀界線

| 結果 | 可得結論 |
| --- | --- |
| 某事件出現在同一場序列，且其前後事件都有序號 | 只證明此遊戲版本、戰場與操作下的相對順序。 |
| 摘要中沒有某事件 | 只能說這場未觀察到；不能證明 native 永遠不觸發。 |
| `Battle_DrawBGI`、AI 或計算事件顯示次數高於輸出行數 | 超出部分已被限流，但摘要中的總數仍有效。 |
| `Battle_Dead(..., side=1, mode=2)` 後才出現 native `additem` | 不能在 `Battle_Dead` 直接交換物品；仍遵守戰前基線與 `Battle_RestoreItem` 交換。 |
| 靈契附近沒有 `Battle_CmdSelectOK` | BS36 已實測此情況；不把該入口用作暫時改等級。繼續判讀 `Battle_InputClick` 與原生結果。 |

## 已知證據與邊界

- **官方檔內說明，Steam HD 4.0.5：** 本探針的事件名稱與 signature 來自原版 `OnEvent_Battle.lua`、`OnEvent_BattleEnemyAI.lua`、`OnEvent_BattlePlayerAI.lua` 與 `OnEvent_BattleNPCAI.lua`。
- **已實測 v0.1，Steam HD 4.0.5，2026-09-04：** 在 BS36 以手動靈契成功收服隱翅蟲（來源 `112`）時，探針收到 `Battle_Dead(mode=2)`，其後才由原生 `additem 112` 新增來源物；該流程沒有 `Battle_CmdSelectOK` 記錄。
- **已實測 v0.3，Steam HD 4.0.5，2026-09-04，BS36：** 敵方與玩家的戰鬥資料皆為 userdata；兩隻隱翅蟲的原始 Lv9 在 `Battle_EnemyInit` 時可讀。手動輸入 callback 的可讀命令仍為 `0`，沒有出現 `cmd=6` 或 `Battle_CmdSelectOK`；因此公開輸入 callback 目前不能作為暫改靈契等級的安全入口。`Battle_Dead(mode=2)` 可重複，且 native `additem` 在其後，`BattleGain` 又在其後。
- **已否決路徑：** `Function.CheckObsolt` wrapper 未被 native 靈契流程觀察到；`Battle_CmdSelectOK` 也不能作為上述手動靈契的時序入口。兩者都不拿來改寫機率。
- **待驗證：** 各 callback 是否都由 native 巡覽追加 handler、實際參數型別、不同戰場／輸入模式的順序，以及 `Battle_InputClick` 是否能提供早於原生靈契判定的可靠資料。

## 驗收

執行靜態與 mock 檢查：

```powershell
.\tests\run-tests.ps1
```

**已通過 mock 與封裝驗收，2026-09-04（v0.3）。** mock 會逐一呼叫 25 個已知戰鬥 callback，確認每個 handler 都可註冊、輸出順序／摘要，且目標 `NPCData.Level` 在完整流程後仍為原值。`_build_v03/swd3_capture_command_timing_probe.ssmod` 為 `3,857` bytes、SHA-256 `B41291B781E447BB6963015093C0AD2CA5A4CD6C4454F465E6C717930092ACEB`；反解後 `.ext` 與 `CaptureCommandTimingProbe.lua` 均與來源 SHA-256 相符。

**已通過 mock、封裝與反解驗收，2026-09-04（v0.4）。** `tests/run-tests.ps1` 通過；`_build_v04/swd3_capture_command_timing_probe.ssmod` 為 `4,363` bytes、SHA-256 `99160A91983E8BE30970A82A23ADD79B65857A76F52D8E72FF242E9AFBA6C2C3`。反解後 `.ext` 與 `CaptureCommandTimingProbe.lua` 的 SHA-256 均與 `src` 相同。

### BS41 v0.4 手動靈契

**已實測 v0.4，Steam HD 4.0.5，2026-09-05，BS41：** 手動對野猴（來源 `106`、Lv12）使用靈契並成功收服。收服前的公開 callback 依序只觀察到多次 `Battle_InputKeyDown`：`NowMenu=1`，接著一次 `NowMenu=3`，其後 `BattlePlayerAI_after` 已是 `NowMenu=0`。全程玩家 `AI_Command` 均為 `0`，沒有 `cmd=6`、可讀的靈契目標、`Battle_CmdSelectOK` 或收服前 `Battle_InputClick`；兩次 `Battle_Dead(mode=2)` 才是收服結果，之後原生新增來源物並由正式 MOD 換成卡 `10046`。因此，`NowMenu` 可描述泛用原生選單階段，卻不能唯一識別靈契，也沒有留下可安全改派的公開 Lua 時點。

### BS34 L2 操作配對

**已實測 L2，Steam HD 4.0.5，2026-09-05，BS34：** 操作順序為「賽特防禦 → 妮可普攻 → 妮可防禦 → 賽特攻擊」。兩次防禦也各觸發 self-target 的 `BattleCriticalHitRate`（#176、#193），故該 callback 不能唯一識別普攻；兩次致死的 `Battle_Dead` 皆在相關 `BattlePlayerAI_after` 之後（#182/#183 → #184，#200 → #201），故 after 不是傷害完成點。操作與序號摘錄直接見 [L2 證據](EVIDENCE.md#l2-bs34-操作與事件摘錄)；本案例未單列探針版號，不以 v0.5 代填。

### v0.5 建置與待測

**已通過 mock、封裝與反解驗收，2026-09-05（v0.5）。** `tests/run-tests.ps1` 通過；`_build_v05/swd3_capture_command_timing_probe.ssmod` 為 `4,711` bytes、SHA-256 `C98F448ACA84D583C88C7C2B4B30254A13AF47F98F8816FE4FE3796EA3969865`。反解後 `.ext` 與 `CaptureCommandTimingProbe.lua` 的 SHA-256 均與 `src` 相同。**待實機：** 以滑鼠各做一次攻擊、物品、靈契與取消，才能判定 HD 全域輸入事件是否為候選入口。

**歷史待測敘述已取代。** v0.3 已有上列 BS36 結果；這不表示全部 25 個事件都已觸發。v0.5 滑鼠／全域輸入及 L1–L5 未列實際結果的部分仍待驗證，完整矩陣與舊 trace 見 [EVIDENCE.md](EVIDENCE.md)。
