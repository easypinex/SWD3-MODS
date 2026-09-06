# 戰鬥事件與時序

## 範圍與閱讀方式

本文件回答 Steam HD 4.0.5 的 callback 形狀、已知相對順序與安全選點。名稱存在不代表每場觸發；原版 Lua 形參不代表 native 實際傳入引數。證據標記依[測試文件](testing-and-verification.md#證據標記)。

原版腳本基線與 exe 指紋見[引擎研究流程](engine-research-workflow.md#steam-hd-405-原版腳本基線)。事件 dispatch／包裝見[Lua 相容性](lua-events-and-compatibility.md#優先追加不覆蓋)；目前擁有者只在[相容性登記](../compatibility-registry.md)維護。收妖資格見[原生靈契](native-capture-and-eligibility.md)，資料欄位見[執行期資料模型](runtime-api-and-data-model.md)。

## 已知戰鬥輪廓

| 層次 | 已知關係與證據 | 不可推定 |
| --- | --- | --- |
| 整場建立 | **已實測，[BS36 初始化案例](../../research/active/swd3-capture-command-timing-probe/EVIDENCE.md#bs36-初始化順序)：** EnemyInit、PlayerInit 在 Battle_Enter 前。 | 不外推到中途召喚、全部角色種類或所有戰場。 |
| 指令選擇 | **已靜態反解，[指令分流與 dispatcher](../../research/active/swd3-native-menu-probe/NATIVE-CAPTURE-RESEARCH.md#已靜態反解hd-戰鬥輸入與靈契命令分流)：** 輸入、選單與 private queue 是不同階段。 | `NowMenu`、一次點擊或公開 AI 欄位不能唯一識別已提交指令。 |
| 行動執行 | **已實測，[L2 操作／序號](../../research/active/swd3-capture-command-timing-probe/EVIDENCE.md#l2-bs34-操作與事件摘錄)：** after 不是傷害完成事件；CriticalHitRate 在防禦的 self-target 分支也出現。 | 只涵蓋所列防禦與致死攻擊，不定義「一輪一次」或非致死傷害完成 callback。 |
| 收妖／結算 | **已實測，[BS36 v0.1／v0.3](../../research/active/swd3-capture-command-timing-probe/README.md#已知證據與邊界)：** Dead(mode=2) 可重複，native additem 在其後；[L2 擊殺序列](../../research/active/swd3-capture-command-timing-probe/EVIDENCE.md#l2-bs34-操作與事件摘錄)為 Dead → BattleGain → RestoreItem。 | 不把擊殺排序套用到逃跑、Game Over 或中斷。 |

### callback 重複頻率矩陣

初始化按已建立的對象觀察；輸入按實際輸入及 native predicate 出現；AI、計算與狀態事件按命中分支出現；RestoreItem 是正常戰後清理界線。這些均不構成每回合固定清單。細部案例與尚未測得的粒度見[研究矩陣](../../research/active/swd3-capture-command-timing-probe/EVIDENCE.md#callback-重複頻率矩陣)。

## 對 MOD 設計的直接規則

1. 整場設定須限制在自身戰場／目標，保存原值，並有戰後、切圖、重啟及可重入清理。
2. `Battle_Dead` 可以標候選；交換與補償須等原生新增物後核對基線，見[交換正文](battle-and-inventory-lifecycle.md#原生靈契--靜態活物卡)。
3. `BattlePlayerAI_after(index)` 和 executor 是 native state machine 的不同分支；已測 after 早於致死結果，但不能保證每名角色 after 後立即執行該角色，也不能表示非致死 HP 已寫入。
4. 已追到的一般非致死 HP 套用鏈未發現 Lua dispatcher；不得用 timer、下一次輸入或另一名角色 after 當通用傷害完成點。範圍限定於已分析的 HD 4.0.5 路徑，見[反解證據](../../research/active/swd3-native-menu-probe/NATIVE-CAPTURE-RESEARCH.md#已靜態反解非致死傷害後沒有可用-lua-還原點)。

## Battle_DrawBGI 與玩家 AI 模式

**已靜態反解＋已實測，HD 4.0.5。** primary dispatcher 受啟動時讀取的 `BattlePlayerAI_mod` 控制，且在 `NowMenu != 3`、`NowMenu < 100` 等條件下才呼叫；index 是行動者，不是 action 選項。啟用該 global 的隔離實測同時接管手動指令，因此不能只為開啟繪圖／觀察 callback 而設定它，也不能把它當可靠逐幀或 action 6 目標確認窗口。位址、caller 與失敗測試見[BGI 重新反解與 v0.4 隔離反例](../../research/active/swd3-native-menu-probe/NATIVE-CAPTURE-RESEARCH.md#bgi-啟動條件與隔離反例)。

## 尚缺的生命週期證據與標準量測組合

需要確認重複粒度、取消、混合動作或結束分支時，才讀 [L1–L5 操作與既有 trace](../../research/active/swd3-capture-command-timing-probe/EVIDENCE.md#尚缺的生命週期證據與標準量測組合)。必須把實際操作與完整 Console 配對；mock 呼叫全部事件不等於 native 會走過全部事件。

## 高等首領曾可收服的原因

早期隔離案例在建立戰鬥前暫降來源等級；後續副本封頂與 live flag 窗口是不同條件。不得混成同一引擎保證。現行能力邊界見[原生靈契](native-capture-and-eligibility.md)，逐版證據見[研究清冊](../../research/README.md)。

## 原版戰鬥 callback 完整索引

狀態均為**官方檔內說明**，除非表內另註。此表涵蓋目前原版 Lua 宣告的戰鬥相關 `OnEvent` callback；它不宣稱列出未暴露給 Lua 的 native 呼叫點。目前擁有者以相容性登記為準；逐事件的 native 實際觸發仍按案例判讀。

| 階段 | callback／原版 signature | 原版預設角色 |
| --- | --- | --- |
| 進戰 | `Battle_Enter()` | 建立戰鬥環境暫態、輸出 BattleField ID。 |
| 輸入 | `Battle_InputKeyDown()` | 原版預設為空。 |
| 輸入 | `Battle_InputClick()`（native；Lua main 形參為 `cmd`） | 已靜態反解：native 以零參數 dispatch；Lua 預設 handler 的形參不構成 native 引數契約。 |
| 輸入 | `Battle_InputDClick()` | 原版只建立 event table，未提供 `.main`；**已靜態反解：** native 雙擊 predicate 成立時以零參數 dispatch。 |
| 輸入 | `Battle_CmdSelectOK()` | 原版清除 AI 選取狀態，註解為「AI→手動命令選取結束」。 |
| UI | `Battle_DrawBGI(active_index)` | 繪製／維護戰鬥背景與 AI UI；**已靜態反解：** `active_index` 是目前戰鬥行動者，不是 action 選項。 |
| 初始化 | `Battle_EnemyInit(index)` | 將 `BattleEnemys[index]` 與 `NPCData` 登錄到原版戰鬥暫態。 |
| 初始化 | `Battle_PlayerInit(index)` | 將玩家 `CharData` 登錄並初始化玩家 AI 記憶。 |
| 初始化 | `Battle_NPCInit(index)` | 將我方 NPC 的 `NPCData` 登錄，原版也可能依主角等級調整該副本。 |
| 初始化 | `Battle_KeeperInit(index, itemtabIdx)` | 將護駕的 `NPCData` 與背包物品登錄。 |
| 狀態變化 | `Battle_Dead(index, side, mode)` | 死亡、逃跑、收妖或 script 結果；`side` 為 0 我方／1 敵方，`mode` 為 0 一般、1 逃跑、2 收妖、3 script。 |
| 狀態變化 | `Battle_StopSkill(index, side)` | 技能被封印時重設我方玩家 AI 記憶。 |
| 狀態變化 | `Battle_Freeze(index, side)` | 定身等狀態變更時重設我方玩家 AI 記憶。 |
| 狀態變化 | `Battle_SetActive(index, side, sw)` | 顯示／隱藏角色時重設我方玩家 AI 記憶；`sw` 0 隱藏、1 出現。 |
| 結束／清理 | `Battle_RestoreItem()` | 原版清除背包物品 `Stock`。 |
| 取消 | `Battle_CancelClick()` | 取消原版 AI 選取狀態；**已靜態反解：** native 以戰鬥狀態 byte 在它與一般 `CancelClick` 間條件選擇，接著零參數 dispatch。 |
| 成長計算 | `CheckLearnSpecialSkill(index, now_exp)` | 以 `OnEventValue` 回傳可習得絕招與門檻經驗。 |
| 成長計算 | `CheckStatSpecialSkill(index, now_exp)` | 以 `OnEventValue` 回傳絕招經驗結果。 |
| 行動計算 | `BattleCriticalHitRate(BeCriticalHit, Index, Side, TargetIndex, TargetSide)` | 若 native 進入該判定，原版依雙方戰鬥等級再擲骰，寫入 `OnEventValue.BeCriticalHit`。 |
| 行動計算 | `BattleEnemyEscapeRate(Index, Side, PlayerLevel, EscapeRate)` | 依敵方等級與 `EscapeRate` 計算，寫入 `OnEventValue.EscapeRate`。 |
| 結算 | `BattleGain(PlayerExp, Money, MItemExp, SpecialSkillExp)` | 把獎勵寫入 `OnEventValue`。 |
| 敵方 AI | `BattleEnemyAI(index)` | 選擇敵方攻擊、技能、治療或特殊攻擊及目標。 |
| 玩家 AI | `BattlePlayerAI(index)` | 依玩家 AI 模式選擇命令與目標。**已靜態反解，HD 4.0.5：** native 在清空該角色選擇暫態、建立可用命令與開啟 command UI 前 dispatch；action queue 尚未寫入。 |
| 玩家 AI 後 | `BattlePlayerAI_after(index)` | 清空玩家 AI 命令、目標與選取物，重設 AI 記憶。 |
| 護駕 AI | `BattleNPCAI(index)` | 選擇護駕的攻擊、技能、治療或特殊攻擊。 |

## `OnEventValue` 與計算 callback

計算／結算 callback 的原版 Lua 透過共享 `OnEventValue` 回傳結果，而不是以 Lua 函式 return 作為唯一介面：

| callback | 原版寫入欄位 |
| --- | --- |
| `CheckLearnSpecialSkill` | `LearnNewSpecialSkill`、`NewSpecialSkillExp` |
| `CheckStatSpecialSkill` | `LearnNewSpecialSkill`、`NewSpecialSkillExp` |
| `BattleCriticalHitRate` | `BeCriticalHit` |
| `BattleEnemyEscapeRate` | `EscapeRate` |
| `BattleGain` | `PlayerExp`、`Money`、`MItemExp`、`SpecialSkillExp` |

這只證明原版 Lua 寫入這些欄位，**不**證明 native 讀取時點、有效值域、空表重設時機或多 MOD 覆寫優先序。需要改寫時，先做獨立、可還原的探針；wrapper 的回傳與錯誤處理方式仍依[Lua 事件與相容性](lua-events-and-compatibility.md#包裝器的回傳值與原版計算結果)。
