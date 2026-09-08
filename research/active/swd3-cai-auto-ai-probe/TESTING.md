# 自動AI驗收

## v0.4 戰術介面卡住回報（2026-09-08）

使用者在F9自由挑戰看到額外「戰術」指令，點選後回報卡住。[配對Console](../../../swd3-cai-demon-king-mod/evidence/v16-f9-tactics-user-console.txt)確認AI v0.4啟用、戰場MOD_CARD_CHALLENGE、敵人438（原值HP10000），並非正式蔡魔王11001；未記錄可定位卡住原因的Lua錯誤。來源CaiAutoAI.lua在載入時設定BattlePlayerAI_mod=true，足以確認介面由測試模組開啟，但不能由此斷言native卡住根因。使用者已選擇停用AI測試並恢復手動戰鬥；停用後介面回歸仍待人工確認。保留探針來源，不把移除入口稱為修復原生戰術介面。

## 四人完整挑戰勝利（2026-09-07）

**已實測，使用者人工回報＋Console。** v0.1搭配蔡魔王v0.9、四人Lv60滿裝測試開局v0.2，使用者回報完整戰勝且壓力偏低。詳見[本體首勝紀錄](../../../swd3-cai-demon-king-mod/TESTING.md#四人滿裝自動挑戰首勝2026-09-07)。Console記錄真夢娃娃三次選用、仙魄香兩份與仙蓮子一份原生扣除、妮可死亡後救援及勝利後模式還原；不外推至未出現的策略、停用回歸或全部技能成功。

同場使用者詢問真夢重複使用。原版是SP300的重複使用道具，非一次性消耗品；本場賽特入場SP1100，三次選用不足以證明違規使用。但查碼發現recovery的道具支線缺Cons_SP／Cons_MP／Cons_Item支付能力篩選，需補足並測不足／恰好足夠／資源用盡後換手或改選；目前無逐次SP trace，不能聲稱原生一定拒絕或已免費施放。詳見[原版效果與庫存核對](../../../swd3-cai-demon-king-mod/LOADOUT-AND-TESTING-SETUP.md#首場勝利後的補給核對2026-09-07)。

## v0.1範圍

2026-09-07。先靜態／mock／封裝反解，遊戲內由使用者操作。尚未人工回報自動施法、物品實際消耗或完整勝敗，不能聲稱已能自動打贏蔡魔王。

`tests/run-tests.ps1`使用既有隔離原版Lua，載入原生玩家AI dispatcher、HP／MP／SP回復helper及回復記憶初始化，僅mock原生userdata、技能可用性、傷害預測與狀態清單。驗證四名主角模式與還原、重複安裝／事件、其他戰場多回傳值、多人全體优先、百分比技能及道具單位、已排治療避免重複、預留物品不可用、角色／命令／技能资格、65%／75%與60%階段邊界、原生預測擇優、足夠普攻收尾、零MP／SP、錯誤停止AI、不同戰鬥對象／切圖／讀檔清理。mock傷害不驗證實機傷害公式；假物品不證明推薦配裝已存在於存檔。

原版來源指紋（Steam HD4.0.5解包繁中out_data）：

| 檔案 | SHA-256 |
| --- | --- |
| Function_Repository.lua | `7E3F5CC42C5D44011A51FB5DD118A2CF88583DFE66F483C6C6C98FE0A37354BF` |
| BattlePlayerAI.lua | `82BC6E89159D9DCCAEF6D84421048D97B3E06C0CA334053881D9199632F1C6CB` |
| OnEvent_BattlePlayerAI.lua | `676CC2B1C3311E116BF633E4471103378DBF9A796C6A48BCE50250EFFBBC53B5` |

回復候選問題定位：Function_Repository的`CheckPlayerCureHPfromSkill`／`CheckPlayerCureHPfromItems`；SP=0被排除定位`CheckAllPPlayerSP`。本研究只在自身決策修正候選及缺漏，未改原版檔案。完整原始資料可由[工具索引](../../../docs/knowledge/tools-and-commands.md#原版腳本重建與資料匯出)重建。

## 人工最小驗收

**已mock、封裝反解與啟動，2026-09-07：** `tests/run-tests.ps1`通過；manifest與兩個DAT逐檔反解相同。安裝包SHA-256 `CB2B15AC65BA3009E6DF2D4BF3048F43342A1E3ABEB71453336A1EFD1148D3CE`；備份`.work/cai-auto-v01-install-20260907-211831-891`保留原清單、既有包指紋與存檔hash。Cai v0.9與Live v0.7封包不變，Save/*.sav前後hash不變，未上傳工作坊。

本機Mods已啟用本測試包，其他兩包及Steam啟用清單不變；遊戲主視窗已出現。[啟動Console](evidence/v01-startup-console.txt)第4–5行確認helper包裝與v0.1載入，第30–32行確認Cai v0.9、references ready=true及Live v0.7。只證明初始化成功，未操作遊戲進行戰鬥；下列實戰全待人工驗證。

1. 啟用本包完整重啟，使用測試存檔，在物品欄Insert開始蔡魔王挑戰。關閉開場台詞後，觀察現有主角是否自動出招；兩人存檔也能先測選招，不代表四人終局平衡。
2. 受傷後觀察是否主動補血；若有多人受傷且有可用全體回復，應優先選全體。記錄有無卡住、用错對象或無物品仍反覆選用。无需逐次手抄傷害，Console可讀取決策。
3. 正常勝敗離場，再進挑戰應能重新自動戰鬥；確認蔡魔王v0.9物理／一次回血的演出与效果。此輪不要求必勝。
4. 停用本包、完整重啟後，確認恢復原有戰鬥介面。原生AI介面內切換手動模式、逃跑／異常中斷及不同MOD載入順序的實機矩陣仍待驗。

回報只需：能否自行出招／補血、有無停住、勝敗及是否已具完整四人配裝。日誌`select`表示排入決策，不能當作技能命中、消耗或補血完成。

## 知識歸屬

本輪策略數值與原生helper組合是研究契約；未把mock提升為引擎保證。全域AI開關限制仍只有戰鬥時序正文，已把原版Lua直接支持的決策接口／預排治療記憶補至同一正文；沒有新增通用知識主題。

## v0.2 召喚與資源管理

2026-09-07：原版dispatcher整合mock、Lua靜態與封裝逐檔反解通過。新增測試包括SP／MP不足、恰足、材料缺少／Stock鎖定、原生ID召喚、自身目標、兩槽上限、死亡替補、一個全局待確認、失敗不無限重試、SP300保留邊界、低HP／Boss收尾停止召喚及復活替代候選完整回傳契約。庫存／SP測試不模擬native必定扣除，仍由人工戰鬥與log配對核實。

封包SHA-256 `CB9BCDA5ABFB9160339CDC49B9CD4D1C581BB10FA12241473DDB20E5565EEC83`。完整整合配置、人工步驟、安裝與載入證據見[蔡魔王v0.10](../../../swd3-cai-demon-king-mod/TESTING.md#v010-召喚資源與勝利結算)。新功能人工待驗，v0.1的首勝不外推為本版通過。

## v0.3 撤回失敗召喚並提供手動接手

2026-09-08。使用者回報AI v0.2搭配Boss v0.10勝利但完全未召喚，[Console反例](../../../swd3-cai-demon-king-mod/evidence/v010-first-win-console.txt)第140、188、256、614行選了四種卡；第166–171行含神龍未確認與SP590→270。沒有Battle_KeeperInit，不是庫存不足；原生有付出費用。

已靜態反解HD4.0.5.0：[native-summon-route.txt](evidence/v03-summon-route/native-summon-route.txt)第56行開始的FUN1400524e0，至第130–131行把共享及角色private queue固定設為3；第406行的FUN1400725c0查物品並判MP／SP、IT12 flag。完整公开userdata注册FUN1400e0020第1412–1418行是AI_Command等公開欄位，沒有直接queue setter。原入口140044ab0 case3與真正KeeperInit所在140040820 case0x10見[前版native報告](../../../swd3-cai-demon-king-mod/evidence/v010-native/native-finish-summon.txt)，不得把AI_Command數字16當已知召喚接口。[指紋與腳本](evidence/v03-summon-route/manifest.json)記版本；反編譯有型別推測警告，此結論只否決具體AI_ITEM路徑，不宣稱所有其他API不可能做到。

v0.3移除活物AI_ITEM提交，普通全自動保留。可選手動召喚兩隻再由AI接手，採真正KeeperInit與兩個存活槽判定，不替玩家選卡、按鍵或暫停Boss。原生召喚／接手畫面待人工；完整dispatcher mock與模式還原通過，操作見[本體v0.11](../../../swd3-cai-demon-king-mod/TESTING.md#v011-縮短戰鬥與召喚路徑修正)。完整自動召喚及死亡補召仍未完成。

v0.3已本機安裝並確認載入，hash `5119BAF869F935B197CFFA6F058B745F4079D11C776E06E1D68D32E0A20C0CDE`；[整合啟動證據](../../../swd3-cai-demon-king-mod/TESTING.md#v011-安裝與啟動證據)。手動兩隻後接手與完整自動召喚不可混稱，後者仍未完成。

## v0.4 手動召喚接手修正

**後續實測成功，2026-09-08：** 搭配本體v0.11，使用者人工完成戰鬥并肯定體驗；[候選定稿報告](../../../swd3-cai-demon-king-mod/evidence/v011-approved-battle/REPORT.md)中的Console123／126行均為HP正值、dead=false、hidden=true，living分別1／2，127行接手，其後44次主角策略與兩護駕各12次決策，勝利後模式還原。確認本場是舊isHide條件會排除的護駕，不是免費／假召喚。下列修正時「接手待驗」已由本場取代；延後重查退路、其他狀態及完整自動召喚不可跟隨宣稱通過。

2026-09-08，使用者回報 v0.3 手動召喚後未接手。[完整 Console](evidence/v03-manual-handoff-failed-console.txt)可搜尋 `BattleKeeper init : ID=5`／`ID=6`：神龍178與鳳凰179登錄成功、各 Stock=1，但两次探針均記錄 `living=0`；後續兩隻都有 BattleNPCAI，四人仍 AI:0。這證明召喚成功而接手失敗；該版未記錄 hidden／dead 讀值，尚不能把具體哪個布林條件當作已實測結論。

**原版 Lua 查碼：** HD4.0.5 `OnEvent_Battle.lua` 的 `Battle_KeeperInit.main` 登錄 self／NPCData／GUID／isKeeper；`OnEvent_BattleEnemyAI.lua` 的玩家目標條件只對主角檢查 isHide，護駕則檢查有效 NPC_GUID、HP及非死亡。v0.4據此修正，另加當前對象一致性及移除記錄，在後續 BattleNPCAI／BattlePlayerAI 追加事件重查。後者在原版 main 之後執行，不聲稱能替換已打開的當次手動指令。KeeperInit新增HP／dead／hidden診斷，成功只接手一次。

**自動檢查通過：** 原版 KeeperInit.main 整合（技能資料讀取mock）、原版玩家dispatcher、isHide=true的護駕、初始HP尚未就緒後續再查、重複事件、不足兩隻、死亡／移除／換槽、其他戰場、成功後尊重人工切回手動、離場還原。此前mock把護駕isHide固定false，漏掉此條件。故障注入的 ERROR 是預期測試輸出。封裝與兩份DAT／manifest逐檔反解相同；hash `3B640925C802A2749ED8778C350AD85E04007EA1D77610062D06DD6BB5AA9DEA`。

人工待驗：重啟讀測試檔 → Insert選「手動召喚兩隻後交給AI」→ 召喚神龍與鳳凰；預期四名主角自動，Console出現 `two native keepers confirmed; automatic hero AI resumed`。若已有手動指令視窗開啟，先完成該次指令再觀察。回報是否接手即可，不要求先打完整場。完整自動召喚仍不支援。本次失敗的欄位實值尚缺，保留本研究；原版護駕條件的可重用查碼結論補於戰鬥時序正文。

原版來源 SHA-256：OnEvent_Battle.lua `1173F8008165EE8939394794FD32C92B3C6CF9ED7DCCAE7282976E85F72B043E`；OnEvent_BattleEnemyAI.lua `AE1312D4CF0574351C7E6A89B9D14C007B7BFF02C0514A515A9EF0899644AACF`。依知識庫原版脚本基線重建。

已本機安裝並重啟：[載入 Console](evidence/v04-launch-console.txt)確認 AI v0.4、Cai v0.11及 references ready=true；遊戲PID45804、主視窗4920022。備份位置見本機 `.work/cai-ai-v04-install-latest.txt`，保留原包、清單與完整Save；全部既有sav hash不變。首次複製遇退出中的檔案鎖，等待程序結束後複製並比對成功，沒有重試啟動。僅更新AI包，未修改其他包與啟用清單。初始化成功不代表手動接手實測通過。


## 2026-09-08 全模組檢查

既有語法與 mock 回歸通過。來源保留、不發佈 Steam，不重啟或操作遊戲；先前未通過／待驗案例不因此變更。
