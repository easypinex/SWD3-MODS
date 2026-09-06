# SWD3 MOD 工作區相容性登記表

此表是**本工作區目前使用中的識別碼登記**，不是遊戲 API 規格。新增或修改快捷鍵、事件包裝、全域 namespace、保存 key、StringDB 前綴、戰場 ID 或實驗 TSW ID 前先閱讀本表；完成後同步更新。引擎通用規則仍以 `docs/knowledge/` 為權威。

## 使用狀態與研究位置

本次只整理位置，**沒有釋放任何識別碼**。正式 MOD 的登記維持使用中；下列研究登記以此狀態表為準，舊操作欄的「目前」「待測」必須配合所列版本閱讀。重新啟用停用保留的探針前先檢查與現行 MOD 的衝突。

| 專案群組 | 識別碼狀態 | 位置與說明 |
| --- | --- | --- |
| 正式 MOD（4 個） | 使用中 | 根目錄專案；實際安裝／啟用不由目錄位置推定 |
| `swd3-engine-ui-diagnostics` | 研究保留；不代表遊戲已啟用 | [入口](../research/active/swd3-engine-ui-diagnostics/README.md) |
| `swd3-native-menu-probe` | 研究保留；不代表遊戲已啟用 | [入口](../research/active/swd3-native-menu-probe/README.md) |
| `swd3-native-loader-probe` | 研究保留；不代表遊戲已啟用 | [入口](../research/active/swd3-native-loader-probe/README.md) |
| `swd3-capture-command-timing-probe` | 研究保留；不代表遊戲已啟用 | [入口](../research/active/swd3-capture-command-timing-probe/README.md) |
| `swd3-critical-hit-formula-probe` | 研究保留；不代表遊戲已啟用 | [入口](../research/active/swd3-critical-hit-formula-probe/README.md) |
| `swd3-seth-capture-window-probe` | 研究保留；不代表遊戲已啟用 | [入口](../research/active/swd3-seth-capture-window-probe/README.md) |
| `swd3-all-monster-capture-probe` | 停用保留；尚未釋放 | [歷史入口](../research/archive/swd3-all-monster-capture-probe/README.md) |
| `swd3-item-registry-cache-probe` | 停用保留；尚未釋放 | [歷史入口](../research/archive/swd3-item-registry-cache-probe/README.md) |
| `swd3-static-item-registry-probe` | 停用保留；尚未釋放 | [歷史入口](../research/archive/swd3-static-item-registry-probe/README.md) |
| `swd3-static-capture-exchange-probe` | 停用保留；尚未釋放 | [歷史入口](../research/archive/swd3-static-capture-exchange-probe/README.md) |
| `swd3-general-capture-eligibility-probe` | 停用保留；尚未釋放 | [歷史入口](../research/archive/swd3-general-capture-eligibility-probe/README.md) |
| `swd3-story-boss-level-gate-probe` | 停用保留；尚未釋放 | [歷史入口](../research/archive/swd3-story-boss-level-gate-probe/README.md) |
| `swd3-high-level-capture-gate-probe` | 停用保留；尚未釋放 | [歷史入口](../research/archive/swd3-high-level-capture-gate-probe/README.md) |
| `swd3-formal-capture-validation-probe` | 停用保留；尚未釋放 | [歷史入口](../research/archive/swd3-formal-capture-validation-probe/README.md) |
| `swd3-guardian-resistance-battle-probe` | 停用保留；尚未釋放 | [歷史入口](../research/archive/swd3-guardian-resistance-battle-probe/README.md) |
| `swd3-guardian-resistance-runtime-probe` | 停用保留；尚未釋放 | [歷史入口](../research/archive/swd3-guardian-resistance-runtime-probe/README.md) |
| `swd3-high-level-capture-rate-probe` | 停用保留；尚未釋放 | [歷史入口](../research/archive/swd3-high-level-capture-rate-probe/README.md) |
| `swd3-manual-capture-bridge-probe` | 停用保留；尚未釋放 | [歷史入口](../research/archive/swd3-manual-capture-bridge-probe/README.md) |
| `swd3-live-card-battle-dialogue-probe` | 停用保留；尚未釋放 | [歷史入口](../research/archive/swd3-live-card-battle-dialogue-probe/README.md) |

已釋放：本次無。各研究 src 中既有 namespace／按鍵／ID 仍由其原擁有者保留，不能因舊表缺列而視為可占用。完整研究狀態見[研究清冊](../research/README.md)。

## 快捷鍵與輸入觸發

| 識別碼 | 擁有專案 | 範圍／用途 | 處理方式 |
| --- | --- | --- | --- |
| `F8`／scancode `65` | `swd3-proficiency-multiplier-mod` | 遊戲選單中的熟練度面板顯示切換 | 新功能避免重用；若必須共用，需做狀態互斥實測。 |
| `F9`／scancode `66` | `swd3-live-card-battle-mod` | 物品籃啟動原生活物選單 | 已與下列對話探針衝突；探針不可與正式 MOD 同時啟用。 |
| `F3`／scancode `60` | `swd3-seth-capture-window-probe` | 建立賽特 action 6 的 live Boss 旗標隔離研究戰 | 僅與全魔物靈契並用；以隔離牛魔王戰鬥副本 `NPCData.ItemType` 的 `0x20` bit 表示 Boss。v0.6 於 `NowMenu=1/3` 的輸入期關閉、賽特 after 維持關閉、非賽特 after 開啟；待驗證，不得保存。 |
| `F4`／scancode `61` | `swd3-high-level-capture-rate-probe` | 建立腳本化 Lv80、HP 15% 的原生收妖隔離戰 | v1.5 在 `BattleScript` coroutine 中於全魔物壓等後還原目標 Lv80，並呼叫一次原版 `BSC.Obsolt(1,-1)`；不得和其他收妖／戰鬥探針並用、不得保存。 |
| `F5`／scancode `62` | `swd3-high-level-capture-rate-probe` | 歷史時序實驗保留鍵 | v1.3／v1.4 的 F5 路徑已否決：`GameFunc.RunScene` 不會在戰鬥進入 Scene。v1.5 F4 已改由 `BattleScript` 自動測試；不得在一般戰鬥使用、不得保存。 |
| `F6`／scancode `63` | `swd3-manual-capture-bridge-probe` | 建立手動靈契→原生 bridge 隔離戰 | F6 建立腳本化 Lv80、HP 15% 牛魔王；僅研究用，不得與其他收妖／戰鬥探針並用、不得保存。 |
| `F7`／scancode `64` | `swd3-manual-capture-bridge-probe` | 歷史明確武裝接力鍵 | v0.3 已實測 F7 後的手動回合可接力 native bridge；v0.4／v0.5 自動辨識研究已否決，目前不作正式功能。 |

## 事件與函式包裝

| 目標 | 擁有專案 | 備註 |
| --- | --- | --- |
| `OnEvent.SysInit[4]` | `swd3-proficiency-multiplier-mod` | 專案依設定載入時序使用；不是可自由分配的通用槽位。 |
| `OnEvent.Obsolt.main` | `swd3-refinery-diagnostics-unlock-mod` | 函式包裝；新 MOD 若觸碰同一函式，須做雙載入順序測試。 |
| `OnEvent.Battle_Dead`、`Battle_RestoreItem` | `swd3-live-card-battle-mod` | 用於挑戰預留釋放；新增 handler 必須可重入。 |
| `InputKeyDown`、`InputKeyUp`、`InputClick`、`Battle_InputKeyDown`、`Battle_Enter`、`BattlePlayerAI_after`、`Battle_Dead`、`Battle_RestoreItem`、`MapLoading`、`MapLoaded` | `swd3-all-monster-static-capture-mod` | v2.0 正式自動收妖 bridge：資格在戰前預備；對 bridge 範圍內原始 Boss 的 live `NPCData.ItemType`，命令 `NowMenu=1/3` 與賽特 after 暫清 `0x20`、非賽特 after 還原，戰後／切圖／重啟還原完整 snapshot。高於第一位主角 +11 的敵方副本仍於 `Battle_Enter` 封頂，並依原生新增物與背包基線交換靜態卡。一般地圖 Boss、妮可傷害與取消／逃跑回歸待驗證；與活物挑戰同時啟用時需驗證兩種載入順序。 |
| `InputClick`、`Battle_EnemyInit`、`Battle_Enter`、`Battle_InputClick`、`Battle_CmdSelectOK`、`Battle_CancelClick`、`Battle_DrawBGI`、三類 AI、`BattleCriticalHitRate`、`Function.CheckObsolt`、`BSC.Obsolt`、`Battle_Dead`、`Battle_RestoreItem`、`MapLoading` | `swd3-high-level-capture-rate-probe` | F4 隔離驗證戰：`Battle_Enter` 將敵方副本封頂為主角 +11，再在自訂 `BattleScript` coroutine 還原 Lv80 並呼叫一次 `BSC.Obsolt(1,-1)`。此組合已實測成功；一般地圖遭遇尚無可接入同一 coroutine 的證據。 |
| `InputKeyDown`、`InputKeyUp`、`InputClick`、`Battle_InputKeyDown`、`Battle_EnemyInit`、`Battle_Enter`、`BattlePlayerAI_after`、`BattleCriticalHitRate`、`Battle_Dead`、`Battle_RestoreItem`、`MapLoading` | `swd3-seth-capture-window-probe` | F3 隔離研究：只對來源 `59` 的戰鬥副本讀寫 `NPCData.ItemType` 的 `0x20` Boss bit，保留其餘 bit。v0.6 僅在 `NowMenu=1/3` 的輸入 callback 暫清 Boss；賽特 after 維持 OFF，非賽特 after 還原 ON。不使用 `Battle_DrawBGI`、不設定 `BattlePlayerAI_mod`。此窗口已有 F3 隔離收服紀錄；逐案傷害／退出矩陣及正式產品驗收界線見研究入口。 |
| `InputClick`、`Battle_EnemyInit`、`Battle_Enter`、`Battle_Dead`、`Battle_RestoreItem`、`MapLoading`、`BSC.Run`／`BSC.Obsolt`（自訂 BattleScript 內） | `swd3-manual-capture-bridge-probe` | F6/F7 隔離接力研究已實測：手動靈契回合後，BattleScript coroutine 可呼叫 bridge 並完成原生收妖；尚未自動攔截一般指令，完成後應停用。 |
| 全域 `InputKeyDown`、`InputKeyUp`、`InputClick`、`InputDClick`；`Battle_Enter`、全部戰鬥輸入／初始化／狀態／結算／AI callback（完整清單見 `battle-events-and-timing.md`） | `swd3-capture-command-timing-probe` | 唯讀全戰鬥時序探針；全域輸入僅在戰鬥期間記錄。追加 handler，不寫入戰鬥、`OnEventValue` 或存檔。完成測試後應停用。 |
| `Battle_Enter`、`BattleCriticalHitRate`、`BattlePlayerAI_after`、`Battle_DrawBGI`、`Battle_RestoreItem`、`MapLoading` | `swd3-critical-hit-formula-probe` | 唯讀玩家普攻量測：讀取爆擊旗標、武器與敵方 HP 差；不寫入 `OnEventValue` 或任何戰鬥資料。測試時不與全戰鬥時序探針並用。 |
| `DrawMenuAfter`、`InputClick` | 多個正式 MOD／探針 | 共用事件；一律追加 handler、以自身狀態縮小作用範圍。 |

## Namespace、保存與文字 key

| 類型 | 已占用值 | 擁有專案 |
| --- | --- | --- |
| Lua 全域 | `SWD3ProficiencyMultiplier`、`SWD3ProficiencyMultiplierUI` | 熟練度 |
| Lua 全域 | `SWD3RefineryDiagnostics` | 煉化診斷 |
| Lua 全域 | `SWD3LiveCardBattle` | 活物挑戰 |
| Lua 全域 | `SWD3NativeMenuProbe` | 原生選單探針 |
| Lua 全域 | `SWD3LiveCardDialogueProbe` | 對話探針 |
| Lua 全域 | `SWD3AllMonsterStaticCatalogue`、`SWD3AllMonsterStaticCapture` | 全魔物靜態卡庫與交換 helper |
| Lua 全域 | `SWD3CaptureCommandTimingProbe` | 唯讀靈契指令時序探針 |
| Lua 全域 | `SWD3CriticalHitFormulaProbe` | 爆擊傷害唯讀量測探針 |
| Lua 全域（HD 原生預留） | `BattlePlayerAI_mod` | 賽特靈契旗標窗口探針 v0.4 已否決實驗：啟用 BGI／玩家 AI dispatch 也會接管手動指令；不得供正式 MOD 或未知同名 MOD 使用。 |
| `Setting` key | `SWD3ProficiencyMultiplierValue` | 熟練度 |
| `SaveData` namespace | `SWD3RefineryDiagnostics` | 煉化診斷 |
| StringDB 前綴 | `LCB_`、`RDU_` | 活物挑戰、煉化診斷 |

新 MOD 使用完整名稱前綴，例如 `SWD3<ModName>`、`<MOD>_` 與 `SaveData.SWD3<ModName>`，不得使用泛稱如 `State`、`Config` 作為全域。

## 戰場與資產實驗 ID

| ID | 擁有專案 | 狀態 |
| --- | --- | --- |
| `MOD_CARD_CHALLENGE`（BattleField ID） | `swd3-live-card-battle-mod` | 已使用；新戰場採不同且可辨識的文字 ID。 |
| `AMCP_CAPTURE_PROBE`（BattleField ID） | `swd3-all-monster-capture-probe` | 收妖／自訂卡隔離探針；不可作正式戰場。 |
| `SBLGP_CHIYOU_LEVEL`（BattleField ID） | `swd3-story-boss-level-gate-probe` | 蚩尤 Lv80 → Lv1 的隔離靈契門檻戰；不可作正式戰場。 |
| `HLCGP_BULL_DEMON_LEVEL`（BattleField ID） | `swd3-high-level-capture-gate-probe` | 牛魔王 Lv80 → Lv1 的隔離靈契選取驗證戰；不可作正式戰場。 |
| `AMSC_FORMAL_BOSS_VALIDATE`（BattleField ID） | `swd3-formal-capture-validation-probe` | 僅降低牛魔王戰鬥壓力的正式鏈路驗證戰；不可作正式戰場。 |
| `HLCRP_BULL_DEMON_RATE`（BattleField ID） | `swd3-high-level-capture-rate-probe` | Lv80 牛魔王、HP 15% 的主角 +11／原生 100% 靈契隔離驗證戰；不可作正式戰場。 |
| `MCBP_BULL_DEMON_HANDOFF`（BattleField ID） | `swd3-manual-capture-bridge-probe` | 手動靈契→原生 bridge 的 Lv80 牛魔王隔離驗證戰；不可作正式戰場。 |
| `SCWP_BULL_DEMON_WINDOW`（BattleField ID） | `swd3-seth-capture-window-probe` | 賽特 action 6 live Boss 旗標窗口隔離研究戰；不可作正式戰場。 |
| `10001`–`10097`（ItemTemp ID） | `swd3-all-monster-static-capture-mod` | 97 張載入期靜態活物卡；代表卡已有保存／重讀證據，其他案例與停用限制依正式 TESTING，不因本次整理改變使用契約。 |
| `20001`、`20002`（TSW 實驗） | 活物挑戰圖片研究 | 待驗證／研究用途；不可聲稱已成為可發布的自訂 TSW 規則。 |

此表只列目前掃描到的編輯來源；`dist`、反解資料與發布副本不納入登記依據。

## 歷史來源識別碼補登記（停用保留）

以下從搬遷後的歷史 `src/data` 核對，補齊舊登記表未列出的識別碼。原版 SOURCE_ID 不屬自訂占用，未列入。重複按鍵表示隔離實驗互斥，不代表可以同時啟用；F7 等舊版本保留鍵仍依上方記錄。

| 擁有專案 | Namespace | 來源宣告的按鍵／scancode | 自訂卡／戰場／文字前綴 |
| --- | --- | --- | --- |
| `swd3-all-monster-capture-probe` | `SWD3AllMonsterCaptureProbe` | `F5/62`、`F6/63`、`F7/64`、`F10/67` | `AMCP_CAPTURE_PROBE`、`9001`、`AMCP_` |
| `swd3-item-registry-cache-probe` | `SWD3ItemRegistryCacheProbe` | `F11/68`、`F12/69` | `9002`、`IRCP_` |
| `swd3-static-item-registry-probe` | `SWD3StaticItemRegistryProbe` | `F3/60`、`F4/61` | `9003`、`SIRP_` |
| `swd3-static-capture-exchange-probe` | `SWD3StaticCaptureExchangeProbe` | `F1/58`、`F2/59` | `SCEP_SNAKE_CAPTURE`、`9004`、`SCEP_` |
| `swd3-general-capture-eligibility-probe` | `SWD3GeneralCaptureEligibilityProbe` | `HOME/74` | 無新增 |
| `swd3-story-boss-level-gate-probe` | `SWD3StoryBossLevelGateProbe` | `F6/63` | `SBLGP_CHIYOU_LEVEL` |
| `swd3-high-level-capture-gate-probe` | `SWD3HighLevelCaptureGateProbe` | `F5/62`、`F7/64` | `HLCGP_BULL_DEMON_LEVEL` |
| `swd3-formal-capture-validation-probe` | `SWD3FormalCaptureValidationProbe` | `F4/61` | `AMSC_FORMAL_BOSS_VALIDATE` |
| `swd3-guardian-resistance-battle-probe` | `SWD3GuardianResistanceBattleProbe` | `F5/62`、`F6/63` | `GRBP_POISON_FLOWER` |
| `swd3-guardian-resistance-runtime-probe` | `SWD3GuardianResistanceRuntimeProbe` | `F5/62`、`F6/63` | `GRRP_POISON_FLOWER` |
| `swd3-high-level-capture-rate-probe` | `SWD3HighLevelCaptureRateProbe` | `F4/61`、`F5/62` | `HLCRP_BULL_DEMON_RATE` |
| `swd3-manual-capture-bridge-probe` | `SWD3ManualCaptureBridgeProbe` | `F6/63` | `MCBP_BULL_DEMON_HANDOFF` |
| `swd3-live-card-battle-dialogue-probe` | `SWD3LiveCardDialogueProbe` | `F9/66` | `LCDP_` |
