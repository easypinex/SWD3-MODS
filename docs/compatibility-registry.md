# SWD3 MOD 工作區相容性登記表

此表是**本工作區目前使用中的識別碼登記**，不是遊戲 API 規格。新增或修改快捷鍵、事件包裝、全域 namespace、保存 key、StringDB 前綴、戰場 ID 或實驗 TSW ID 前先閱讀本表；完成後同步更新。引擎通用規則仍以 `docs/knowledge/` 為權威。

## 使用狀態與研究位置

2026-09-08：熟練度回復 v1.1，釋放 F8、UI namespace 與倍率保存 key；其餘識別碼仍按下表保留。正式 MOD 的登記維持使用中；下列研究登記以此狀態表為準，舊操作欄的「目前」「待測」必須配合所列版本閱讀。重新啟用停用保留的探針前先檢查與現行 MOD 的衝突。

| 專案群組 | 識別碼狀態 | 位置與說明 |
| --- | --- | --- |
| 正式 MOD（5 個） | 使用中 | 根目錄專案；實際安裝／啟用不由目錄位置推定 |
| `swd3-engine-ui-diagnostics` | 研究保留；不代表遊戲已啟用 | [入口](../research/active/swd3-engine-ui-diagnostics/README.md) |
| `swd3-cai-auto-ai-probe` | 玩家AI測試專用 | [入口](../research/active/swd3-cai-auto-ai-probe/README.md)；使用者2026-09-07明確要求AI戰鬥，主動啟用全域原生AI介面；不得當被動探針使用 |
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

2026-09-07四人測試開局另登記：`swd3-cai-test-start`使用全域`SWD3CaiTestStart`、`Scene.CST_BEGIN`、StringDB前綴`CST_`、`SaveData.SWD3CaiTestStart.Version/Ready`。DAT期只替換NewGameChar／NewGameSkill／NewGameEqu及NewGame.Script的新遊戲配置；不新增按鍵或物品。起點81沿用原生地圖，Scene建立戰鬥隊伍旗標30–33及本測試檔12件ItemTemp熟練override；無GameStart發物hook。啟用期間與其他新遊戲配置MOD互斥，見[研究](../research/active/swd3-cai-test-start/README.md)。

蔡魔王占用（2026-09-06）：`Insert`／scancode `73`，物品欄入口；`swd3-cai-demon-king-mod` 與 `swd3-cai-act-probe` 互斥使用。全域 `SWD3CaiDemonKing`、`SWD3CaiActProbe`，文字前綴 `CDK_`，Scene `CDK_ChallengeMenu`／`CDK_ActProbe`，戰場 `CDK_CAI_CHALLENGE`／`CDK_ACT_PROBE`。v0.2 以 DAT1 填補原版未宣告的 ACT438，保留 ItemTemp438 身分；不用 Lua ACTData，不新增 TSW／物品 ID／保存 key。追加 GameStart、DrawMenuAfter、InputKeyDown、InputClick、Battle_Enter、Battle_Dead、Battle_RestoreItem、MapLoading；完整版v0.2另追加 BattleEnemyAI 只讀選招診斷；v0.8追加選招限制，見下方11002／11003登記。基本動作的有限實測見[探針](../research/active/swd3-cai-act-probe/README.md#v02-人工結果2026-09-06)，完整版 v0.2 技能已人工回報正常，卡片／全滅仍待驗。v0.3 在 DAT2 補來源438的 IT_06=true，戰鬥中的 Boss 位元由全魔物靈契既有流程接管；護駕卡10096不加 Boss 身分，詳見[驗收](../swd3-cai-demon-king-mod/TESTING.md)。

| 識別碼 | 擁有專案 | 範圍／用途 | 處理方式 |
| --- | --- | --- | --- |
| `F8`／scancode `65` | 已釋放（熟練度 v1.2 歷史） | 現行 v1.1 不註冊 | 重用前確認本機未載入舊 v1.2。 |
| `F9`／scancode `66` | `swd3-live-card-battle-mod` | 物品籃啟動原生活物選單 | 已與下列對話探針衝突；探針不可與正式 MOD 同時啟用。 |
| `F3`／scancode `60` | `swd3-seth-capture-window-probe` | 建立賽特 action 6 的 live Boss 旗標隔離研究戰 | 僅與全魔物靈契並用；以隔離牛魔王戰鬥副本 `NPCData.ItemType` 的 `0x20` bit 表示 Boss。v0.6 於 `NowMenu=1/3` 的輸入期關閉、賽特 after 維持關閉、非賽特 after 開啟；待驗證，不得保存。 |
| `F4`／scancode `61` | `swd3-high-level-capture-rate-probe` | 建立腳本化 Lv80、HP 15% 的原生收妖隔離戰 | v1.5 在 `BattleScript` coroutine 中於全魔物壓等後還原目標 Lv80，並呼叫一次原版 `BSC.Obsolt(1,-1)`；不得和其他收妖／戰鬥探針並用、不得保存。 |
| `F5`／scancode `62` | `swd3-high-level-capture-rate-probe` | 歷史時序實驗保留鍵 | v1.3／v1.4 的 F5 路徑已否決：`GameFunc.RunScene` 不會在戰鬥進入 Scene。v1.5 F4 已改由 `BattleScript` 自動測試；不得在一般戰鬥使用、不得保存。 |
| `F6`／scancode `63` | `swd3-manual-capture-bridge-probe` | 建立手動靈契→原生 bridge 隔離戰 | F6 建立腳本化 Lv80、HP 15% 牛魔王；僅研究用，不得與其他收妖／戰鬥探針並用、不得保存。 |
| `F7`／scancode `64` | `swd3-manual-capture-bridge-probe` | 歷史明確武裝接力鍵 | v0.3 已實測 F7 後的手動回合可接力 native bridge；v0.4／v0.5 自動辨識研究已否決，目前不作正式功能。 |

## 事件與函式包裝

2026-09-08 蔡魔王v0.12／挑戰v0.8：既有namespace下新增`Inventory`模組（CaiInventory／LiveCardInventory），純記憶體消耗帳，不新增保存key。各自在第一次開戰前包裝`ItemClass.AddItem`／`ItemClass.DelItem`，只在自身戰場記負向實際數量差；包裝`OnEvent.Battle_RestoreItem.main`在原版清Stock後、追加handler前返還。两種包裝順序整合mock通過。F9的收妖去重刪除以WithoutRefund排除，卡庫追加交換在停止記帳後執行；不覆蓋原函式回傳值。實際返還仍待人工。

| 目標 | 擁有專案 | 備註 |
| --- | --- | --- |
| `OnEvent.SysInit[4]`（v1.2 歷史） | `swd3-proficiency-multiplier-mod` | 現行 v1.1 資料就緒時直接初始化，否則連續追加 SysInit；不再佔用固定索引。 |
| `Function.BattlePlayerAI_FullAuto`、`Function.CheckPlayerCureHPfromSkill`、`Function.CheckPlayerCureHPfromItems`；追加`SysInit`、`GameStart`、`Battle_Enter`、`Battle_RestoreItem`、`MapLoading` | `swd3-cai-auto-ai-probe` | 包裝並保存原函式；僅蔡魔王11001自有場FullAuto期間改決策／回復候選，其餘原樣轉交。入場最多四主角AImode=1，正常退出還原，切圖／重讀丟棄舊引用。實戰待驗。 |
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

2026-09-08 蔡魔王v1.0：新增`SaveData.SWD3CaiDemonKing`，只保存數字欄位`DialogueVersion`、`Attempts`、`Defeats`、`Seed`。成功通過入場檢查並進入BattleScript後計數，與獎勵持有判定分離；不回填舊版本歷史，不自動存檔。既有全域內新增`Dialogue`／`FairPlay`模組；新台詞沿`CDK_`前綴（REPEAT、NOST、HEAL、FAIR等），不新增事件或快捷鍵。CaiInventory既有AddItem／DelItem包裝增加本場數量對帳；F9版本不加入此公平比試檢查。詳見[正式版候選](../swd3-cai-demon-king-mod/TESTING.md#v10-正式版候選)。

| 類型 | 已占用值 | 擁有專案 |
| --- | --- | --- |
| Lua 全域 | `SWD3ProficiencyMultiplier` | 熟練度 v1.1；舊 UI namespace 已釋放 |
| Lua 全域 | `SWD3RefineryDiagnostics` | 煉化診斷 |
| Lua 全域 | `SWD3LiveCardBattle` | 活物挑戰 |
| Lua 全域 | `SWD3NativeMenuProbe` | 原生選單探針 |
| Lua 全域 | `SWD3LiveCardDialogueProbe` | 對話探針 |
| Lua 全域 | `SWD3AllMonsterStaticCatalogue`、`SWD3AllMonsterStaticCapture` | 全魔物靜態卡庫與交換 helper |
| Lua 全域 | `SWD3CaptureCommandTimingProbe` | 唯讀靈契指令時序探針 |
| Lua 全域 | `SWD3CriticalHitFormulaProbe` | 爆擊傷害唯讀量測探針 |
| Lua 全域 | `SWD3CaiAutoAIProbe` | 蔡魔王玩家自動AI測試；沒有保存key、快捷鍵或新增戰場／物品ID。 |
| Lua 全域（HD 原生預留） | `BattlePlayerAI_mod` | 賽特靈契窗口v0.4的被動觀察用途已否決：也會接管手動指令。2026-09-07使用者明確要求AI戰鬥，僅允許已登記的`cai-auto-ai-probe`主動AI測試用途，啟用全域UI且需完整重啟；不得混入正式蔡魔王或當被動BGI探針。 |
| `Setting` key | `SWD3ProficiencyMultiplierValue` | v1.2 歷史，現行已釋放／不讀寫 |
| `SaveData` namespace | `SWD3RefineryDiagnostics` | 煉化診斷 |
| StringDB 前綴 | `LCB_`、`RDU_` | 活物挑戰、煉化診斷 |
| StringDB key | `LCB_CAI_FORMAL`、`LCB_CAI_REQUIRED`、`LCB_CAI_ORIGINAL`、`LCB_CAI_FREE` | 挑戰模式v0.9：蔡魔王入口、缺少依賴提示與資料標示；沿用既有Scene，不新增保存key。 |
| 跨MOD介面 | `SWD3CaiDemonKing.StartFreeChallenge(field,rewardsAllowed)`、`freeChallengeVersion=1`、`freeChallengeField` | Cai v1.7供F9 v0.9使用；Cai管理CDK_CAI_CHALLENGE角色／道具／策略，F9管理編成Stock／倍率／一般獎勵；純記憶體，無新戰場或保存key。 |

新 MOD 使用完整名稱前綴，例如 `SWD3<ModName>`、`<MOD>_` 與 `SaveData.SWD3<ModName>`，不得使用泛稱如 `State`、`Config` 作為全域。

## 戰場與資產實驗 ID

蔡魔王v0.6另占用`BattleScript.CDK_CAI_CHALLENGE`（與自身BattleField同名），於開始前掛接，沿原版`BSC.Enter/Run`及`BattleScript.AutoPrint`在coroutine中顯示開場／敗北對話。既有`Battle_Dead`追加handler改為script存活時只排敗北狀態；不新增hook、不改原版AutoPrint、不新增TSW或保存key。移除v0.4／v0.5選單提示，v0.6戰鬥內對話已人工通過。

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
| `11001`（ItemTemp ID） | `swd3-cai-demon-king-mod` | v0.4 DAT2註冊的獨立Lv99蔡魔王敵人，ACT438；不加入卡庫、不設IT_12、不發此物品。沿用`CDK_CAI_CHALLENGE`，F9來源438仍是舊基線。文字沿用`CDK_`，無新增保存key；v0.6撤回選單提示，改本場BattleScript開場／敗北對話，見上方登記。v0.6既有事件追加範圍不變、AI只讀；v0.8行為依下行技能登記。v0.4新敵人進場、全滅返回與再戰已人工回報正常；v0.6戰鬥內對話已人工通過。 |
| `11002`、`11003`（ItemTemp 與 AttackEffect 各自同號） | `swd3-cai-demon-king-mod` | v0.8 DAT2註冊的挑戰專用幻光聖劍／六芒星斬，3000／2400點；只由11001引用，不發背包。預先檢查兩種表的占用衝突，保留原版1676／1668及121／73。既有`BattleEnemyAI`追加handler從唯讀改為本場11001選招後處理：連續全體選招改單體；回血不清除此限制。mock及完整原表比對通過，native傷害／選招節奏待人工驗收，見[蔡魔王驗收](../swd3-cai-demon-king-mod/TESTING.md#v08-攻擊技能強度)。 |
| `11004`、`11005`（ItemTemp 與 AttackEffect 各自同號） | `swd3-cai-demon-king-mod` | v0.9：物理單體4200、自己回血10000。DAT2複製1649→285與1683→198；原表不改。`SWD3CaiDemonKing.CombatAI`與本場`state.combat`管理首動、60%階段、45%一次回血及全體間隔，沿既有`BattleEnemyAI`追加handler覆寫自身選招，不覆蓋main、不新增保存key。新文字沿`CDK_`，詳見[v0.9驗收](../swd3-cai-demon-king-mod/TESTING.md#v09-物理招分階段策略與一次回血)。 |
| `11006`（ItemTemp ID） | `swd3-cai-demon-king-mod` | v0.10真契靈獎勵，DAT2靜態註冊；`SWD3CaiDemonKing.Reward`管理庫存／裝備去重，追加`BattleGain`並在既有RestoreItem有條件補結算；無保存key。技能引用11002～11004，獨立次數表，無CR回血。 |

2026-09-08 v1.5：`ACT11005`由蔡魔王模組持有，DAT1沿用原版6079／TSW6040的60幀動畫，於PA48及PA58各放一次AT16；每段6000、一場只排入一次。不同於ItemTemp／AttackEffect同號的既有命名空間；沒有新增TSW、快捷鍵、hook或保存key。目的為避免12000跳字擠在四位欄位，詳見[本版驗收](../swd3-cai-demon-king-mod/TESTING.md#v15-回血跳字與雙段回復)。

2026-09-08 v0.11／AI v0.3：沿用原namespace、Scene與事件，追加`CDK_MANUAL_SUMMON`／`CDK_SUMMON_INFO`文字，`SWD3CaiAutoAIProbe.supportsManualSummon`供菜單檢查、`state.manualSummon`與`awaitSummons`純記憶體旗標，不新增保存key。既有KeeperInit只讀成功登場並有條件切回四人AI；撤回活物AI_ITEM召喚提交。11005自身回血改6000；11006不变。

v0.10更新：11003威力3200、11005自身回血16000；原同號技能與效果所有權不變。`CDK_`新增階段／勝利／獎勵／測試補給文字。既有Scene菜單於測試Ready存檔才呼叫`SWD3CaiTestStart.Restock`；不新增Scene或快捷鍵。AI v0.2另包裝`Function.CheckPlayerCureStatefromItems`，追加`Battle_KeeperInit`／`Battle_Dead`／`BattlePlayerAI`供本場召喚與資源讀回；不改原生KeeperAI。
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

蔡魔王與挑戰模式v0.7各追加`Battle_PlayerInit`，使用既有namespace的`PartyState`保存本場主角資源；`Battle_Enter`補滿／解除異常，`Battle_RestoreItem`還原，換圖／GameStart／物品欄保留清理。兩份封包各有独立命名的Lua，不新增共用全域、快捷鍵、保存key或戰場ID。人工待驗，見[狀態研究](../swd3-cai-demon-king-mod/PARTY-STATE-RESEARCH.md)。

2026-09-08 AI v0.4：追加 BattleNPCAI，只於本場等待兩隻護駕時重查接手，不修改護駕出招；沿用 BattlePlayerAI 追加事件重查。removedKeepers 為既有 SWD3CaiAutoAIProbe 內純記憶體狀態，退出／切圖清空，無新增保存key。

2026-09-08 蔡魔王v1.6：新增`Scene.CDK_RewardReceipt`與`CDK_RECEIPT_TITLE／ITEM／BACK`三個StringDB key；沿既有DrawMenuAfter派送確認領獎後的系統通知，無新hook／快捷鍵／保存key。`Reward.pendingReceipt`綁定目前SaveData，GameStart／MapLoading清除；戰鬥結算只發物一次。見[驗收](../swd3-cai-demon-king-mod/TESTING.md#v16-戰後獎勵通知與物品欄重建)。
