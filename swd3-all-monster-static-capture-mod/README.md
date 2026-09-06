# 全魔物靈契

本 MOD 建立 Steam HD 4.0.5 原版資料中 **193** 筆完整戰鬥物件的「敵人 ID → 活物卡 ID」表：原有 **96** 張活物維持原 ID，另為 **97** 筆非活物建立載入期靜態卡 ID `10001`–`10097`。

新卡不在 `GameStart`、戰後或按鍵時新增；它們在 MOD `DAT 2` 載入期建立，沿用已實測安全的靜態註冊機制。`AllMonsterStaticCapture.ExchangeCapturedSource(enemyId, baselineCount)` 提供收妖成功後的安全交換 helper：只在原生來源物品數量高於開戰前基線時，移除一張來源並加入映射卡。

v1.6 將本 MOD 新建的 97 張靜態契靈卡設為 `NotInBook=true`，不列入神魔異事錄；原有 96 張活物維持原本圖鑑行為。每張新卡都有已實測生效的九維護駕能力加成（生命、靈力、體力、力量、耐力、智慧、敏捷、攻擊、防禦），並以**原始戰鬥面板**而非劇情旗標決定護駕強度。62 張原先重複設計組合的卡片改由可審核的手動覆寫表逐張指定專屬定位；地圖期間自動套用已驗證的原生靈契資格 bridge；原生收服成功後，會以開戰前背包基線把來源物安全交換為映射的靜態卡。

驗收證據的版本與案例對照見 [TESTING](TESTING.md#v20-驗收敘述的證據對照)；既有本機可用確認與可跨 MOD 的通用保證分開記錄。

## 目前範圍

一般地圖會自動啟用原生靈契前置資格：`IT_12=true`、`IT_06=nil`、`Race.catch=true`。它不寫入來源 `ItemTemp.Level`、HP、攻防、速度、技能、掉落或獎勵；原生收服成功後才以開戰前背包基線交換卡片，不自行發卡。戰鬥副本等級的例外見下一節。

> **v2.0 Boss 旗標窗口（專案決策；隔離證據與使用者本機驗收，2026-09-06）。** bridge 仍在地圖期間提供 `IT_12=true`、`IT_06=nil`，讓原生靈契 UI 能選到目標；但進入戰鬥後，runtime 只追蹤原始資料本來具有 `IT_06` 的敵方副本。命令／目標 UI 的 `_BattleEnv.NowMenu=1/3` 輸入會暫清其 live `NPCData.ItemType` Boss bit `0x20`；賽特 `BattlePlayerAI_after(1)` 維持 OFF，非賽特 after 則在自身 executor 前恢復 ON。這讓 action 6 持續讀到 non-Boss，同時讓妮可後續傷害重新讀到 Boss 分支。每個戰鬥副本的完整 `ItemType` 都在 `Battle_RestoreItem`、切圖與重啟還原。F3 隔離牛魔王已完成原生 `mode=2` 收服與卡片交換，使用者也確認目前 v2.0 正常可用；仍需在 Steam 訂閱下載版進行公開前回歸。原生流程與證據邊界見 [`research/active/swd3-seth-capture-window-probe/NATIVE-EVENT-AND-CAPTURE-FLOW.md`](../research/active/swd3-seth-capture-window-probe/NATIVE-EVENT-AND-CAPTURE-FLOW.md)。

**v1.9 正式高等收服規則（專案決策；核心路徑已隔離實測，2026-09-04）。** 對卡庫 bridge 範圍內、戰鬥等級高於第一位戰鬥主角 `+11` 的敵人，僅在 `Battle_Enter` 將該場的 `BattleEnemys[index].NPCData.Level` 封頂為主角 `+11`。來源 `GameData.ItemTemp.Level`、地圖與異事錄數值保持原始值；`Battle_RestoreItem`、切圖與重啟都會還原戰鬥副本。因為使用原生公式，封頂後在 HP **≤25%** 時會進入原版 **100%** 收服分支；本 MOD 不包裝 `Function.CheckObsolt`，不再宣稱固定 33%。

**已實測依據，Steam HD 4.0.5，2026-09-04，隔離牛魔王戰。** Lv35 主角對來源仍為 Lv80 的牛魔王：`Battle_Enter` 將戰鬥副本 Lv80 → Lv46，HP `15/100` 時原生 `CheckObsolt=100`，使用者以手動靈契成功收服。這證明目前版本的核心收服路徑；正式 MOD 的一般遭遇完整實機回歸仍列在 [TESTING.md](TESTING.md)。戰鬥等級同時會影響原版暴擊、逃跑與自動 AI 的等級判定，這是本規則明確接受的戰鬥內例外；已知影響見[執行期 API 與資料模型](../docs/knowledge/runtime-api-and-data-model.md#敵方-npcdatalevel-不是只供靈契使用)。HP、攻防、速度、技能、掉落與獎勵均不由本 MOD 改寫。

先前牛魔王／蚩尤「可收服高等首領」的隔離探針，是在 `ESC.StartBattle` 前把來源 `ItemTemp.Level` 暫設為 1，讓新建立的專用戰鬥副本從一開始就是 Lv1，戰後再還原；這不是 v1.9 的作法。v1.9 保留來源原始等級，只在已建立的戰鬥副本以主角 `+11` 封頂。通用時序與邊界見[戰鬥事件與時序](../docs/knowledge/battle-events-and-timing.md#高等首領曾可收服的原因)。

v0.6 診斷確認先前 10 筆全是目錄中 `Race=0` 的天神系活物：`149`、`152`、`153`、`154`、`158`、`159`、`172`、`197`、`198`、`255`。v0.7 實機進一步確認這些來源在 HD runtime 的 `ItemTemp.Race` 欄位本身缺失，故未能直接使用 Race 0 bridge。v0.8 從可審核目錄暫補來源 Race 0，並在必要時依原版 `GameData_RaceDefine.lua` 補建 `Race[0]={name='NAME1000', catch=true}`；兩者都在戰後／切圖／重啟時精確還原。**已實測啟動整合**：本機顯示 `sources=193`、`sourceRaceFallbacks=10`、`races=16`、`skipped=0`；本次 Race 0 table 原已存在，故 `createdRaces=0`。實機收服仍待一個天神系代表案例。

新增靜態卡的載入期註冊、背包反白與來源交換流程保持不變；`NotInBook=true` 的已知原版效果是排除神魔異事錄與煉化候選。**已實測 v1.0 回歸**：靜態蚩尤卡 `10017` 設為 `NotInBook=true` 後，留在背包且 SP 足夠時仍會出現在戰鬥「物品 → 護駕」並可正常召喚。

## 靜態卡與交換表

- 可審核完整表：[all-monster-static-cards.csv](catalogue/all-monster-static-cards.csv)。
- **97 張自製卡完整規格表**：[static-card-guardian-specs.csv](catalogue/static-card-guardian-specs.csv)。每列包含來源與靜態卡戰鬥數值、召喚體力消耗、九維護駕加成、原型主題、戰鬥傾向與設計說明；97 組九維加成皆不重複。
- **手動專屬定位表**：[guardian-specialization-overrides.csv](catalogue/guardian-specialization-overrides.csv)。它恰好列出 62 張曾有重複設計組合的卡片；每列指定專屬稱號、原型、個性印、能力傾向、說明與九維偏向。其餘 35 張維持既有的唯一設計。
- 產生器：[Build-StaticCardCatalogue.ps1](tools/Build-StaticCardCatalogue.ps1)，來源是共用原版 `capture-card-audit.csv`。
- 生成 Lua：[AllMonsterStaticCatalogue.lua](src/data/AllMonsterStaticCatalogue.lua)；它是封包載入來源，不手改。
- ID 映射包含原生卡的 identity mapping，例如黏怪 `101 → 101`；蛇為 `102 → 10042`。

## 護駕平衡：略強但可追溯

原生資料沒有可重現的怪物遭遇率／掉落率總表。因此收妖稀有度不是假稱的原始機率，而是以下**專案決策**：劇情／特殊或圖鑑外為「契約」；其餘依可見等級與 HP 分為常見、少見、稀有、菁英。每張新卡保留原怪的戰鬥資料與既有攻擊效果，只對 HP／ATK／DEF 作小幅提升。這個「收妖稀有度」只用於卡庫整理，**不決定護駕 SP 成本**；護駕強度與成本以下一節的五階規則為唯一權威。

| 收妖分層 | 可驗證代理 | 靜態卡戰鬥 HP／ATK／DEF 微調 |
| --- | --- | --- |
| 常見 | Lv<20、HP<400 | +8%／+5%／+5% |
| 少見 | Lv20+ 或 HP400+ | +10%／+7%／+7% |
| 稀有 | Lv35+ 或 HP1,500+ | +12%／+9%／+9% |
| 菁英 | Lv50+ 或 HP5,000+ | +15%／+12%／+12% |
| 契約 | 劇情／特殊或圖鑑外 | +18%／+15%／+15% |

護駕主動效果的 native 實際傷害／效果仍待單卡實機驗證，因此不偽造未驗證的新攻擊效果。

### 裝備型護駕加護（v1.6 專案決策）

新建的 97 張靜態卡在裝入護駕欄時，使用原生 `Add*` 欄位提供完整九維能力加成。**收妖稀有度與護駕戰力分離**：前者保留既有規則；後者依來源的等級、HP、ATK、DEF、WIS、SPD 同時決定九維加成與召喚 SP 成本。因此低面板的劇情角色不再因「契約」標記獲得首領加成或首領成本；真正的首領則會更強、也需要更多 SP 才能召喚。

| 護駕階級 | 可追溯的原始面板代理 | 召喚 SP | 基礎 HP／MP／SP | 力／耐／智 | 敏捷 | 攻／防 |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| 初階 | 低於熟練門檻 | 10 | +20／+10／+10 | +1 | +1 | +1 |
| 熟練 | HP 400+、ATK 80+、DEF 70+ 或 Lv20+ | 30 | +45／+20／+20 | +2 | +2 | +3 |
| 菁英 | HP 2,000+、ATK 250+、DEF 180+ 或 Lv40+ | 90 | +90／+38／+35 | +4 | +3 | +6 |
| 首領 | HP 8,000+，或 Lv50+ 的高攻／高防目標 | 160 | +165／+65／+55 | +6 | +4 | +11 |
| 傳說首領 | HP 20,000+，或 Lv70+ 的極高攻／防目標 | 280 | +250／+100／+85 | +9 | +6 | +17 |

每張卡在基礎值外，另依 HP、ATK、DEF、WIS、SPD 五個原始面板分段折算，再加入名稱／原型主題、攻勢／守勢／術法／迅捷傾向，以及語意相符的個性印。例如攻勢來源只會取得破軍、獵心、壓陣或銳鋒；守勢來源只會取得厚命、鐵壁、磐石或守脈。這使牛魔王偏向「平天巨力」、蚩尤偏向「兵主戰神」、鬥戰聖佛偏向「鬥戰神通」、最高攻防的撒旦偏向「魔王霸權」；低面板的加賽因與修道院院長則為熟練級。

完整規格表中的 `guardian_theme` 是每張卡唯一的護駕稱號，`guardian_archetype` 是原型類別，`guardian_signature`／`guardian_signature_note` 說明個性加護，`specialization_mode` 則標示 `manual` 或 `generated`。v1.6 對手動覆寫的 62 張卡採名稱／意象與原始面板混合設計；同名不同 ID 會依其面板分化，不將設計敘述冒充為原版劇情。97 組九維加成向量與「原型＋個性印＋傾向」組合皆唯一，且任兩張卡的九維總差距至少為 `12`。

物品欄的數值敘述會直接列出該卡九項實際加成與原型主題；按 `N` 的長篇介紹則保留來源魔物原版 `HelpText`，不以 MOD 文字覆蓋。

## 安全與驗證

- **已實測代表性卡存檔**：靜態蚩尤卡 ID `10017` 已在第 1 格存檔後完整重啟、讀檔與物品欄反白正常。
- **已實測原生護駕完整生命週期**（Steam HD 4.0.5）：蚩尤卡留在背包、賽特 SP 足夠 `200` 時，會出現在戰鬥「物品 → 護駕」清單並可正常召喚及使用；戰鬥結束後仍留在背包且可反白。裝入護駕欄後會離開背包，因而不會出現在該清單。這不是靜態 ID 或物品註冊失敗。
- **已實測 v0.3 一般與高等首領**（Steam HD 4.0.5）：野猴 `106` 在 BS41 原生戰鬥由靈契收服後，正確交換為 `10046`；Lv80 牛魔王 `59` 也在不提供資格／等級／交換邏輯的正式鏈路驗證戰中自動交換為 `10024`。兩張卡都可正常反白；每次戰後 bridge 都會先還原再重新武裝。
- **已實測 v0.4 的收斂修正**（Steam HD 4.0.5，2026-09-03）：Lv80 牛魔王 `59` 可由正式鏈路收服並交換為 `10024`；戰後異事錄／怪物資訊顯示正常原始等級，不再有地圖常駐 Lv1。此次 Console 未輸出預期的副本代理診斷，故「哪個 callback 實際改寫了戰鬥副本」仍不提升為通用引擎規則；但產品行為與資料呈現均已驗收。
- **已實測 v0.5 圖鑑排除**（Steam HD 4.0.5，2026-09-03）：新增靜態契靈卡設為 `NotInBook=true` 後，使用者確認神魔異事錄不再顯示這些卡。
- **已實測 v1.0 護駕回歸**（Steam HD 4.0.5，2026-09-03）：`NotInBook=true` 的靜態契靈卡仍可由背包進入原生戰鬥護駕清單並成功召喚。
- **已實測 v0.8 目錄完整整合**（Steam HD 4.0.5，2026-09-03）：Console 顯示收妖 bridge 已武裝 `sources=193`、`races=16`、`sourceRaceFallbacks=10`、`skipped=0`；不再有未納入 bridge 的來源。
- **停用限制（已實測）**：持有 ID `10017` 的存檔在停用卡庫時仍可載入，但該卡在本次載入中消失；若不保存、重新啟用卡庫後再讀原存檔，卡片會回來。**不得在停用卡庫且卡片消失的狀態下保存。**
- 啟動後 Console 應顯示 `mappings=193, static=97, failures=0`；在本機基線也應記錄 `itemCache=97, raceCache=97`。
- 未持有靜態卡時可停用本 MOD；持有任一靜態卡時，先保留卡庫啟用並建立備份，不將停用視為可安全的正式流程。
- 封裝與完整實機矩陣見 [TESTING.md](TESTING.md)。

## Steam 工作坊發布素材

v2.0 的可上傳內容資料夾、繁中標題與 BBCode 說明、更新說明、預覽圖、雜湊 manifest 與公開前驗收清單，皆位於 [release/steam-workshop](release/steam-workshop/README.md)。工作坊內容資料夾只含已驗證的 `swd3_all_monster_static_capture.ssmod`；使用者本機驗收已通過，但首次 Steam 上傳後仍應先以私人或僅限好友完成訂閱下載版驗收。
