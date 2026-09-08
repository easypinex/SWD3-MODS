# 挑戰入場恢復與離場還原

## 問題與範圍

2026-09-06，v0.6 使用者在對話通過後回報：全員已陣亡仍可開戰，蔡魔王開始攻擊自己。[Console](evidence/v06-dead-entry-console.txt)反覆出現 `can't find target!` 並見敵人HP下降；自擊畫面依人工回報，日誌本身不能判定攻擊來源。挑戰模式v0.6來源同樣沒有補滿流程，只記同類風險，不冒稱已人工重現。

使用者要求兩種挑戰都以全滿狀態入場，離場還原入場前狀態，且不要增加全員陣亡入場限制。v0.7只處理參戰主角的HP／MP／SP、State及絕招Energy；不還原等級、經驗、物品消耗或原有獎勵規則。護駕與NPC不作主角快照。

2026-09-07補記：滿狀態存檔出發的兩入口流程已人工回報通過；Console另有蔡魔王兩人一場的補滿與精確還原值，見[本輪結果](TESTING.md#滿狀態存檔流程通過2026-09-07)。原先全員陣亡、場外異常解除及較廣矩陣仍待驗。

## 原生靜態依據

**已靜態反解；v0.7受限人工結果見上方，不能擴大到全部分支。** Steam HD4.0.5，exe SHA-256 `63F1D83D8C3A756D17640D9022E19F8928741B091F0E47ABBDB22C0CCF6C9523`；Ghidra11.4.3／JDK21。只讀隔離exe和既有資料庫，未附加遊戲、改記憶體或操作遊戲輸入。

| 結論 | 可定位證據 |
| --- | --- |
| CharData的HP／MP／SP、State、SpecialSkill.Energy已註冊為可寫屬性。 | [binding報告](evidence/party-state-static-405/party-bindings2.txt)，`FUNCTION 1400e0020`；CharData offset4／8／0xc／0x30，Energy offset0。短名稱地址另按PE字串核對，分別HP、MP、SP。 |
| 玩家CharData指向四名主角的原生數值；初始化先建立戰鬥副本、判死亡及累計死亡人數，才發PlayerInit。 | [初始化caller](evidence/party-state-static-405/party-bindings4.txt)，`FUNCTION 14003e500`，`FUN_14006f260`、`FUN_14007e8e0`至`Battle_PlayerInit`；[資料綁定](evidence/party-state-static-405/party-bindings5.txt)，`FUNCTION 14006f260`，`param_1+0x18=param_2`。因此原生初始化已有生命上限99999的裁切，超出原生上限的資料不納入本版精確還原承諾。 |
| ReleaseEffect(actor,32768)有獨立復活分支：清死亡bit、重建動作狀態、清死亡旗標並減少死亡人數。 | [解除效果](evidence/party-state-static-405/party-bindings8.txt)，`FUNCTION 140085e10`；[復活動作重建](evidence/party-state-static-405/party-bindings9.txt)，`FUNCTION 14007e430`。單改HP不完成此流程。 |
| 一般效果按bit交給ReleaseEffect清除；死亡bit須單獨傳入，不能把全部bit合併當復活。 | 同上`140085e10`的`param_2==0x8000`分支及後方效果串列處理。 |
| 原生SetSKEnergy(-1)使用Energy56作滿值。 | [能量](evidence/party-state-static-405/party-bindings9.txt)，`FUNCTION 140089340`。本版只暫改Energy，不改SKExp及招式解鎖。 |
| RestoreItem可追加清理，之後仍有原生物品整理；不能單憑事件名承諾所有離場路徑。 | [清理caller](evidence/party-state-static-405/party-bindings4.txt)，`FUNCTION 14004a420`末尾。實機還原時點仍依TESTING驗收。 |

研究排除：`ESC.Healing`可補满並清State，但沒有本次已確認的場外即時快照入口；`BSC.HealAll`對主角使用9999增量，不適合當高成長角色精確補滿的保證；`BSC.SetCharStatus`是面板數值調整，不能因名稱含Status就當解除異常。相關反解保留在本目錄第3、6、7號報告。

## 實作與模型界線

兩份獨立封包各帶自己的PartyState，掛在既有MOD namespace，不新增共用全域或保存key。`Battle_PlayerInit`只於自身戰場保存一次原值，補滿並呼叫原生解除死亡；`Battle_Enter`清除效果並依進場最大值再次補滿、填滿Energy。`Battle_RestoreItem`才還原；挑戰模式撤掉死亡callback內過早釋放，以免戰場尚在時還原成場外陣亡狀態。GameStart丟棄舊快照；換SaveData不寫入舊userdata。正常換圖、失敗、回物品欄有可重入清理，還原失敗會保留待重試記錄。

`tests/party_state.lua`驗證四人、全員原先陣亡、HP超過9999、獨立死亡旗標、六種還原理由、重复初始化、部分恢復失敗、換存檔、GameStart，以及只還原資源而保留等級／經驗。既有兩MOD整合mock實際派送PlayerInit，蔡魔王對話coroutine測試保留。模型不證明native時序、畫面或跨存檔操作已實測；人工步骤見[TESTING](TESTING.md#v07-全滿入場與原狀還原)。

## 重跑

讀[工具索引](../docs/knowledge/tools-and-commands.md#從事件參照追到函式並重跑報告)，在相同hash的既有Ghidra專案用`-process swd3.exe -noanalysis -readOnly`及本專案`tests`作scriptPath，`-postScript ReportPartyState.py`後傳名稱或函式地址。腳本[ReportPartyState.py](tests/ReportPartyState.py)不建立函式；無已定義函式時只印既有指令。現行重跑腳本hash為`44F54932D4FA99F9588F9C07DAD45B7B310672EADA9222B67DD45C38FAEF4F4B`；第2–5報告產生於補上指令fallback前，核心查詢相同。

報告參數：2=`PlayerData Healing CharData`；3=`0x1400a94f0 0x140067270 0x140141730`；4=`Battle_PlayerInit Battle_RestoreItem HealAll SetHPnMPnSP`；5=`0x14006c030 0x14006f260 0x14006a920 0x14003d9e0 0x14003da40`；6=`0x14006c030 0x1400855e0`；7=`0x14006aa40 0x14006eca0 0x14004a420`；8=`0x140066fe0 0x140085e10`；9=`0x14007e9a0 0x14007e430 0x140089340`。stdout保存全文，檢查`PARTY STATE REPORT`與對應FUNCTION／INSTRUCTIONS及無Traceback；不以退出碼代替成功。
