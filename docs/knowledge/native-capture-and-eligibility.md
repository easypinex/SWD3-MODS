# 原生靈契與資格判定

## 何時閱讀

修改靈契資格、開放首領收服、接續原生收妖，或評估 `BSC.Obsolt` 時先讀本文件。它負責資格到結算的設計邊界；數值公式、欄位定義、callback 表及交換演算法各有唯一正文，見下表。

| 問題 | 權威正文 |
| --- | --- |
| 新卡如何註冊、來源 table 與 live userdata 有何不同 | [執行期資料模型](runtime-api-and-data-model.md#新增活物卡的原生註冊時點) |
| 原版等級差、HP 分段與資料統計 | [原版靈契門檻](original-game-data/battle-balance-and-capture/BALANCE-RESEARCH.md#原版靈契門檻官方檔內說明) |
| callback 引數與前後順序 | [戰鬥事件與時序](battle-events-and-timing.md) |
| 原生新增物如何安全換成靜態卡 | [戰鬥與背包生命週期](battle-and-inventory-lifecycle.md#原生靈契--靜態活物卡) |
| 暫改資料、離場與錯誤還原 | [狀態保存與資料安全](state-persistence-and-safety.md) |

## 適用版本與證據

下列結論限 Steam HD 4.0.5。native 結論來自 `swd3.exe 4.0.5.0`，SHA-256 `63F1D83D8C3A756D17640D9022E19F8928741B091F0E47ABBDB22C0CCF6C9523` 的靜態反解；實機結論限所連結案例。證據類型依[測試文件](testing-and-verification.md#證據標記)，整理文件不等於新增遊戲驗收。

## 四個不同階段

```text
戰前來源資格準備、背包基線
  → 手動選單確認目標：live 資格 gate
  → native 提交命令與執行收妖：再次判定資格及機率
  → 原生結果與新增物：戰後依基線交換、還原
```

**已實測＋已靜態反解。** 戰前準備來源資料的既有 bridge 曾讓一般非活物與隔離首領可收服，但不能因此宣稱資格只在進戰時快取。action 6 的目標確認在寫入 private queue 前讀取 live target；之後原生收妖 gate 還會判定 live 資料。只讓 UI 可選、不維持結算所需條件，不能保證收服。

目標確認的控制流見[live Boss gate 反解](../../research/active/swd3-native-menu-probe/NATIVE-CAPTURE-RESEARCH.md#已靜態反解靈契目標確認讀取-live-boss-bit並非只靠戰鬥初始快取)，後續資格／成功結算見[原生收服 gate](../../research/active/swd3-seth-capture-window-probe/NATIVE-EVENT-AND-CAPTURE-FLOW.md#22-原生收服-gate-與成功結算)。早期[一般遭遇探針的狀態紀錄](../../research/archive/swd3-general-capture-eligibility-probe/README.md#已知狀態)中的「資格快取」是當時解釋，不再視為整條收妖流程的規格。

## 公開 Lua 能力與不可採用的推論

| 開發問題 | 現行結論與證據 | 設計邊界 |
| --- | --- | --- |
| 包裝 `Function.CheckObsolt` 能改原生成功率嗎 | **已靜態反解＋已否決路徑：** 手動 action 6 使用 native gate；既有 wrapper 實測未見回呼。 | 不能把 Lua 預覽值、Console 的 `100%` 或 wrapper mock PASS 當作原生收服證據。 |
| 能在「已選靈契、目標已定」攔截嗎 | **已靜態反解＋已實測：** private queue 沒有已找到的公開 Lua 映射；`AI_Command` 不是該 queue，手動測試讀到 `0`。 | `Battle_CmdSelectOK`、輸入座標、`NowMenu` 或 after 均不能唯一識別靈契及目標。 |
| 能只改 Boss 的 UI 資格嗎 | **已靜態反解：** 目標確認讀 live flag，傷害分支亦會讀相關 Boss flag。 | 不存在已驗證的「只改收妖 UI、傷害完全不受影響」操作；欄位及副作用見[資料模型](runtime-api-and-data-model.md#敵方-live-itemtype-旗標)。 |
| 降戰鬥副本等級是否只影響收服 | **官方檔內說明＋受限實測：** 可寫入案例存在，其他原版判定也使用此 Level。 | 是否接受副作用是各 MOD 的產品決策，見[Level 邊界](runtime-api-and-data-model.md#敵方-npcdatalevel-不是只供靈契使用)。 |
| 死亡 mode=2 是否可以直接發卡 | **已實測：** 可重複收到，且原生加物在其後。 | 只記錄候選；依交換正文在戰後核對新增量，不自行替代原生成功。 |

wrapper 與公開欄位反例見[手動接力研究](../../research/archive/swd3-manual-capture-bridge-probe/README.md)、[戰鬥時序案例](../../research/active/swd3-capture-command-timing-probe/EVIDENCE.md)。

## `BSC.Obsolt` 的受限呼叫上下文

**已實測，2026-09-05，隔離 Lv80 牛魔王。** 在原版形狀的自訂 `BattleScript` coroutine 中，`BSC.Enter` 後接續 `BSC.Obsolt(1,-1)`，或在 `BSC.Run(1)` 返回後明確接力，曾完成原生收妖與靜態卡交換，未產生 yield 錯誤。完整版本與操作見[高等驗證戰](../../research/archive/swd3-high-level-capture-rate-probe/README.md)及[手動接力探針](../../research/archive/swd3-manual-capture-bridge-probe/README.md)。

**已否決路徑。** 直接從一般輸入 handler 呼叫曾出現 `attempt to yield across a C-call boundary`；以地圖 `GameFunc.RunScene` 轉接，在已測戰鬥中未進入 Scene。不能因函式可見、呼叫返回或部分原生副作用已發生，就推定上下文合法。

**已靜態反解。** binding 會設定 native 戰鬥狀態；上述兩個數字不能當作已文件化、可獨立指定任意玩家／敵人的公共收服 API。成功依賴既有 coroutine 與目標狀態，不外推到一般遭遇的自動接管。

## 賽特輸入窗口的證據邊界

**已實測，2026-09-06，探針 v0.6，F3 隔離牛魔王。** 輸入期間配合賽特／非賽特 after 的 Boss bit 切換，已有跨第二輪原生收服及交換證據。逐次旗標摘錄及 v0.5 失敗對照見[v0.6 窗口案例](../../research/active/swd3-seth-capture-window-probe/NATIVE-EVENT-AND-CAPTURE-FLOW.md#4-為何-v06-的窗口能工作)；同場妮可只防禦，傷害缺口見[9999 與傷害](../../research/active/swd3-seth-capture-window-probe/NATIVE-EVENT-AND-CAPTURE-FLOW.md#5-9999-與傷害已知與未知)。這回答的是該隔離條件下可收服，不是「所有角色傷害、所有 Boss 與所有退出路徑均安全」。

全魔物靈契 v2.0 已有產品採用與本機驗收完成的紀錄；該敘述與較早待測案例的關係，見該專案 [TESTING 的證據對照](../../swd3-all-monster-static-capture-mod/TESTING.md#v20-驗收敘述的證據對照)。本文件不改寫其發布狀態，也不以籠統完成敘述補齊未附條件的通用驗收。

## 需要下鑽研究的條件

需要跨版本重跑、調整旗標窗口、接管一般手動指令，或追查新反例時才讀上述證據與[研究清冊](../../research/README.md)。一般功能設計先使用本文件與對應正文；不要重跑已否決的 wrapper／執行期新卡方案，除非有新的引擎版本或明確不同條件。
