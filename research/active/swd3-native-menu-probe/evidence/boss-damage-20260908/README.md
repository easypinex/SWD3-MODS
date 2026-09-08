# Boss 旗幟對傷害的靜態調查

2026-09-08；**已靜態反解**，Steam HD `4.0.5.0`，exe 2,227,712 bytes，SHA-256 `63F1D83D8C3A756D17640D9022E19F8928741B091F0E47ABBDB22C0CCF6C9523`。本次沒有遊戲內操作、安裝或修改 MOD。Ghidra 11.4.3／portable JDK 21，對已核對指紋的隔離資料庫使用 `-process swd3.exe -noanalysis -readOnly`。

問題：全魔物靈契 v2.0 在賽特行動窗口清除敵方 live Boss bit，會改變哪些傷害？答案須分成行動當下的特殊分支，以及戰前來源旗幟的初始化影響。跨 MOD 摘要唯一正文在[資料模型](../../../../../docs/knowledge/runtime-api-and-data-model.md#boss-旗幟的傷害與狀態分支)。

## 證據檔與重跑

| 檔案 | 用途 |
| --- | --- |
| [formulas.txt](formulas.txt) | 普攻、效果傷害核心及 9999 cap；由既有三支 Decompile 腳本產生。 |
| [branches.txt](branches.txt) | 全 PE 的直接 `[register+8],0x20` TEST／AND 候選；戰鬥範圍內命中函式、狀態 helper 與 userdata 註冊反解。 |
| [fields.txt](fields.txt) | 欄位名稱原始 ASCII、關鍵指令、RNG／資料載入 helper、兩個爆擊 callback caller。 |
| [manifest.json](manifest.json) | exe、腳本、MOD 來源、原版 Lua 與報告 SHA-256。 |

分析日誌為 [formulas-analysis.log](formulas-analysis.log)、[branches-analysis.log](branches-analysis.log)、[fields-analysis.log](fields-analysis.log)。三組報告均已確認輸出至結束；本次引用的函式皆有反編譯本文。舊腳本另列的 `damage_formula_support @ 0x14008a280` 在此資料庫為 `<no function defined>`（formulas 第 1007 行），故不以它建立結論，不宣稱全部歷史查詢目標都成功。

從[工具流程](../../../../../docs/knowledge/tools-and-commands.md#從事件參照追到函式並重跑報告)指定該 SHA 的資料庫與新輸出目錄，按以下順序替換 `-postScript`，保存完整 stdout：

1. `DecompileHdDamageFormulaCore.py`、`DecompileHdNormalDamagePath.py`、`DecompileHdCriticalDamageFlow.py` → formulas。
2. [ReportHdBossDamageBranches.py](../../tools/ghidra/ReportHdBossDamageBranches.py) → branches。
3. [ReportHdBossDamageFieldEvidence.py](../../tools/ghidra/ReportHdBossDamageFieldEvidence.py)、`ReportHdCriticalHitPath.py` → fields。

腳本在 `research/active/swd3-native-menu-probe/tools/ghidra/`，無查詢參數；新增兩支會核對資料庫內 exe SHA。舊三支位址固定，執行前仍須按工具流程核對指紋。首次資料庫重建沿用工具文件的 import 流程，不提交 exe、資料庫或完整原版 Lua。

## 欄位與角色對應

`branches.txt` 的 `FUN_1400e0020`：第 4799–4803 行把 `CharData`／`NPCData`／`NPC_GUID` 分別註冊在 actor offset `0x18`／`0x30`／`0x28`；第 4564、4585–4596 行把 NPC `ItemType`／`MaxHP`／`Level`／`ATK`／`DEF`／`SPD`／`WIS`／`SkillHits`／`HP` 對應 `0x8`／`0x38`／`0x42`／`0x44`／`0x46`／`0x48`／`0x4a`／`0x4c`／`0x58`。未被 Ghidra 定義為 data 的短名稱由 `fields.txt` 第 43–48 行原始 ASCII 補證。

`branches.txt` 第 382–387 行顯示主角初始化後讀取 `NewGameChar.ItemTempID`。原版 `GameData_NewGame.lua` 的四筆 `GameData.NewGameChar` 依序為賽特 1、妮可 2、卡瑪 8、李靖 17；**不是**戰鬥隊伍索引 1／2／3／4，也不是武器 ID。原版檔由[基線](../../../../../docs/knowledge/engine-research-workflow.md#steam-hd-405-原版腳本基線)重建，指紋見 manifest。

## 傷害核心與特殊爆擊

定位：`formulas.txt` 第 43 行 `FUN_140089570` 區塊；第 268–356 行為本節核心。其條件包括 `DAT_1401f9d7c==1`、實際結算參數為 0、攻擊者不是 keeper／NPC，以及目前 action 落在指定普通攻擊類別。`FUN_1400712c0` 在 critical flag 成立時設定該 global，後續清除；不得把本節直接套用到全部奇術或所有護駕。

| 攻擊者 `NPC_GUID` | 此特殊分支做什麼 | live Boss bit 的直接作用 |
| --- | --- | --- |
| 賽特 1 | 重建該次攻擊基準，設定目標死亡表現 7（官方效果註解：碎成數塊）。 | 此角色分支没有讀 Boss；沒有因 OFF 開啟妮可的 HP 型高傷害分支。 |
| 妮可 2 | 非 Boss 時，將攻擊基準提高到至少「目標 HP（若暫存 `0x358c` 非零則取該值）＋DEF」，接著有目標 HP／MaxHP 清零或死亡標記處理。 | ON 跳過這整段，OFF 可以進入。不是普通的爆擊倍數。 |
| 卡瑪 8 | 此步攻擊基準乘 85/100，設定死亡表現 13。 | 這段沒有讀 Boss；85% 是中間基準操作，不能當成最終傷害倍率。 |
| 李靖 17 | 此步攻擊基準乘 150/100，非 Boss 時再從 `0x100`、`0x40`、`1` 選一個附加狀態，呼叫 `FUN_140085890`。 | ON 阻擋附加狀態部分；150% 本身在判 Boss 前已完成，不會因 OFF 才增加。 |

原版 `GameData_AttackEffect.lua` 把三個狀態對應寄生、驚嚇、麻痺；選中狀態不等於必然成功，還會通過狀態 helper。

普通物理基準後面仍會扣目標 DEF、處理其他增減與屬性等分支；沒有在此核心看到「Boss 統一乘固定減傷率」的運算。普通奇術的點數／智慧／屬性路徑也沒有此 Boss 數值倍率，但帶異常效果時會進下一節的 helper。這是已追函式的結論，不是全引擎所有特殊技能窮舉。

`formulas.txt` 第 2348–2388 行 `FUN_1400786b0` 把核心結果加上額外攻擊值，再將 `>=9999` 的結果截為 9999，最後呼叫 HP 套用。核心有多处 16-bit 中間值、提前返回、吸收與狀態分支，故不能把妮可概括成「任何 HP 都固定 9999」或完整 `max(普通傷害, HP)` 公式。既有妮可 A/B 實測仍見[歷史結果](../../NATIVE-CAPTURE-RESEARCH.md#已靜態反解it_06-bridge-與-9999-爆擊的關係)，本輪只新增靜態證據。

`fields.txt` 的 `FUN_140071970`／`FUN_140071f60` 及原版 `OnEvent_Battle.lua::BattleCriticalHitRate.main` 中，未見目標 live Boss bit 直接作為爆擊機率的條件。Lua 等級骰與全靈契的等級封頂是另外的影響，不應和 Boss bit 混算。

## 異常狀態保護

定位：`branches.txt` 第 3009–3244 行 `FUN_140085890`，特別是第 3074–3117 行；`fields.txt` 第 49–79 行用指令交叉確認 RNG 引數，避免相信反編譯器顯示的無參數 `FUN_140167e10()`。

對 NPC 目標、效果資料 `+0x2c` 為 0、且未被前段提前返回時，以玩家施加狀態的分支可整理為：

```text
W = 10
若玩家 WIS > 目標 WIS：W = 玩家 WIS - 目標 WIS
N = W + clamp(玩家 Level - 目標 Level, -5, 5)
Boss ON：N = N - 10
若 N <= 0：拒絕此狀態
否則 R = native_rng(N)       # 非負 N 的返回範圍 0..N-1
若 R < 目標 SkillHits：拒絕
通過後才處理狀態登記／更新
```

`fields.txt` 的 `FUN_140167e10` 證明取餘範圍；本輪不以靜態範圍冒充實機隨機分布。目標 `SkillHits` 為資料欄位名稱，不能因名字像命中就略過它。

所以 Boss OFF 使這個窗口的 N 比 ON 大 10，可能令原本必定被擋的異常進入抽選；**不是傷害 +10%，也不是成功率固定 +10 個百分點**。例如 W=10、等級差截為 0、SkillHits=5：ON 的 N=0 直接拒絕；OFF 的 N=10，返回 5–9 可通過。這只是條件計算示例，不是所有 Boss 的通用機率。

本 helper 在傷害核心中被呼叫，故賽特的帶狀態攻擊／奇術仍可能有間接影響；成功施加的狀態不會因後來只補回 ItemType 而自动消失。效果 `+0x2c` 非零另有跳過本段的路徑；其完整資料欄位語意未在本輪命名。

## 戰前來源旗幟與初始化

定位：`branches.txt` 第 303–304 行 `FUN_14003e500` 呼叫 `FUN_140078980` **之後**才 dispatch `Battle_EnemyInit`；第 1712–1815 行為該初始化 helper。

它先經 `FUN_14007a8e0` 從 `GameData`／`SaveData` 載入 NPC 副本，若讀到 Boss bit，執行 **SPD +6、ATK +10**，然後才套用該初始化函式的倍率參數。`fields.txt` 的載入 helper、ASCII 與註冊偏移共同證明欄位，這不是 DEF +10 或所有數值乘倍率。

**對 v2.0 的來源碼推論，尚待實機面板 A/B。** `AllMonsterCaptureRuntime.lua::applyBridge` 在地圖期間將來源 `IT_06=nil`；`prepareBattleBossWindows` 到 Battle_Enter 才建立追蹤，`onBattlePlayerAIAfter` 只修改完整 ItemType 中的 bit。若副本初始化讀到的是這份被 bridge 清除的來源，就會漏掉上述原生加成；稍後恢復 live Boss bit 不會重跑初始化。影響會是整場敵方少了原本的攻擊／敏捷加成，**不限賽特行動期間**。其他 MOD 覆寫、SaveData override、場地倍率與自訂初始化仍可改變實值，本輪沒有宣稱所有實戰都固定差 10／6。

## 現行窗口與待人工確認

核對來源為全魔物靈契 v2.0，指紋見 manifest：`sourceWasBoss` 只追蹤來源本來有 `IT_06` 的敵人；普通敵人原本就沒有 Boss bit。`onCommandInput` 在 NowMenu 1／3 清除全部被追蹤目標；`onBattlePlayerAIAfter` 依是否賽特索引 1 決定 OFF／ON，沒有判斷已提交 command。這是共用 live 資料，不是賽特專屬傷害參數。

本輪没有変更 MOD 行為、安裝版或封包。最小人工補證（有需要再準備隔離探針；本次未安裝）：

1. 同一 Boss、同一場地倍率，比對來源 IT_06 保留／清除兩種開戰條件的 EnemyInit 後 ATK、SPD；普通敵人作對照。預期只在實際經此初始化路徑時看到加成差異。
2. 固定賽特裝備、面板與敵方資料，僅切 live Boss bit；記錄普通攻擊／爆擊畫面與完整 Console。預期此角色本身沒有妮可型 HP 基準提升，傷害亂數需多筆比對。
3. 選確實會走狀態 helper 的賽特招式，記錄狀態、雙方 Level／WIS、敵 SkillHits、旗幟及成功／失敗；單次失敗不能否定機率影響。
4. 妮可與李靖須確認各自傷害時 live bit 的值；after 日誌不單獨證明 executor 期間沒有交錯覆寫。

未回報案例皆維持待驗證，不為本次調查自動操作或啟動遊戲。

## 搜尋邊界與知識歸屬

直接 bit 候選命中 8 個指令位置。掃描不涵蓋先載入寄存器再 TEST、合併 mask、間接呼叫或所有未知函式；死亡表現、捕捉／特殊 action 的其他命中不在本次完整解讀範圍。反編譯報告有既存 globals overlap／型別推測警告；關鍵 Boss 減 10、RNG 參數及角色特殊分支以指令補證。

已可重跑的角色分支、異常保護與初始化加成萃取至既有資料模型；全靈契窗口與漏初始化的產品推論留在本證據及產品連結，沒有新建通用主題、識別碼或遊戲探針。未推導完整全武器傷害公式。
