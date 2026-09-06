# 原版戰鬥資料：強度、物品與收妖

此資料夾保存可供所有 MOD 共用的原版戰鬥資料盤點：角色成長、敵人、技能、戰鬥物品、護駕與收妖資格。它不是遊戲資料的修改來源，也不會寫入遊戲安裝目錄或存檔。

其中 `current-challengeable-*.csv` 是依目前「自由挑戰」的選取條件額外整理的閱讀檢視；其他 CSV 均為原版資料或由原版資料直接推導，可供其他插件重用。

## 證據分級

證據類型依[測試文件](../../testing-and-verification.md#證據標記)。CSV 是官方檔內數值或其推導，不是實機傷害／取得保證；「資料最大值」不等於正常流程最佳配裝。

## 產生表格

先按[工具文件的原版腳本重建／匯出](../../tools-and-commands.md#原版腳本重建與資料匯出)準備正版安裝的解包副本，再執行匯出器。預設來源為工作區 `.work/extracted/script-index-inspect/out_data`；`-SourceRoot` 可指定其他隔離來源，`-OutputRoot` 可指定驗證輸出，避免覆寫目前 CSV。

這個匯出器只載入下列已解出的原版檔：物品、戰鬥角色、武器、護具、法術、攻擊效果、四名隊員初始／升級資料、種族與中文文字表。輸出使用 UTF-8 CSV，可用試算表或文字工具檢視。由於命令列 Lua host 不提供標準檔案 I/O，外層 PowerShell 只負責讀取原版 `ItemString.txt` 轉譯名稱並寫出 CSV；兩者都不碰遊戲安裝目錄或存檔。

| 檔案 | 用途 |
| --- | --- |
| `players-level-60.csv` | 四名固定隊員在原版等級上限 60 的裸身成長值與全習得法術。 |
| `player-learned-skills.csv`、`skills.csv` | 角色習得法術與全部法術的 MP／SP 消耗、攻擊效果、屬性、範圍、異常／增益欄位。 |
| `equipment-and-artifacts.csv` | 武器、防具、飾品、法寶及其能力加成；這是最佳配裝候選集，不是取得保證。 |
| `guardian-cards.csv` | 所有已標為 `IT_12` 護駕／活物卡的體力消耗、召喚攻擊效果與卡本身戰鬥資料。 |
| `permanent-growth-items.csv` | `Calculation=256` 且只可平時使用（`UsePlace=2`）的能力上限道具。這些道具使「只以 Lv60 裸身成長定義絕對最強」不成立；其正常可取得份數與 engine 上限須另驗證。 |
| `battle-usable-items.csv` | 原版資料標示可在戰鬥（`UsePlace=1`）或隨時（`UsePlace=4`）使用、且不是法術的物品；含補給、增益、攻擊、法寶與活物等候選，供策略分析。 |
| `combatants.csv`、`attack-effects.csv` | 可作戰物件、技能／特殊攻擊、掉落和屬性抗性。 |
| `capture-card-audit.csv` | 所有具戰鬥資料物件是否已有 `IT_12` 活物卡，以及以四名隊員 Lv60 為前提的原版靈契初步阻擋原因。它不取代實機收妖驗收。 |
| `current-challengeable-enemies.csv`、`top-challengeable-enemies-by-hp.csv` | 套用**目前** `CardBattleRules.IsBattleReady` 的可選敵人與 HP 優先閱讀清單；排序不是最終強度公式。 |
| `current-challengeable-enemy-actions.csv` | 每個目前可選敵人的普通攻擊、技能、特殊攻擊、治療／危急技能，含原始攻擊點、屬性、範圍、異常、初始使用次數與 AI 使用率。 |
| `export-manifest.csv` | 本次匯出的資料來源。 |

## 已知界線

1. 戰鬥傷害、命中與回合順序的關鍵計算在 native engine；Lua 資料的 `iAttackPoint` 是攻擊效果點數，不可直接當成最終傷害。靈契的資格與**機率值**則可由原版 Lua `Function.CheckObsolt` 重現，完整門檻與矩陣見 [BALANCE-RESEARCH.md](BALANCE-RESEARCH.md#原版靈契門檻官方檔內說明)。native 端如何擲骰、是否額外夾限負值，尚未以隔離實機測試確認。
   `SkillsCount`／`SP_AttackEffectsCount` 也不是 CD：原版敵方 AI 在次數降為 0 後仍保留最低權重。因此表格會保留原始次數與 `SkillRate`，但把冷卻標成未定義。
2. 資料表沒有完整標示商店庫存、寶箱、劇情贈與、合成配方與掉落機率的「正常取得」總清單。最佳可取得配裝需要補做原版劇情／商店／掉落來源的索引，並以實機存檔驗收。
3. `IT_12` 證明現有物品範本是活物卡；不具 `IT_12` 的首領可有完整敵方資料，卻不代表原版煉妖壺可收服。新增卡必須使用新的物品 ID，絕不能原地把劇情敵人範本改成 `IT_12`。
4. `Function.CheckObsolt` 的原版 Lua 已可確認會先拒絕 `IT_06`、非 `IT_12`、沒有 `Race.catch=true` 的目標，並在敵方比玩家高 12 級以上時回傳 0。故蚩尤（Lv80）即使處於 15% HP，原版也不能由 Lv60 隊伍收服；若由 MOD 開放，必須是明確、可驗收的非原版收妖規則，並安全交換為新的活物卡 ID。
