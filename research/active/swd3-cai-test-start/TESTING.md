# 四人測試開局驗收

## v0.2 選單與首次保存通過

**已實測：使用者人工回報＋Console，2026-09-07，HD4.0.5。** 使用者針對「新遊戲→關閉整備提示→取消原生存檔畫面→Esc開選單及四人人數」的最小回歸回覆：「通過且存檔啦」。本輪選單崩潰修正、四人檢查及首次保存記為通過；未逐件回報裝備／修練，不將其或重讀／停用／AI勝敗一併標為通過。

[本輪Console](evidence/v02-menu-save-pass-console.txt)含`v0.2 loaded`、四份Lv60設定、`READY`與`opening native save menu`。實際安裝包SHA-256仍為`54A61932EFE0FDF32096A00BC839C53FA56CD8F11ADA23078F199D70EFA752CB`。磁碟新增`Save/3.sav`，53,136 bytes，修改時間22:09:23，SHA-256 `FE9DA145C63A18AD29D30090BA69FEC6310ED563F47BE0CEF2DFD386F35A1E09`；這支持首次保存已落盤，不代表已驗證重讀內容。未解析或改寫存檔二進位。

完整Save已複製到`.work/cai-four-hero-saved-baseline-20260907-221127-540/Save`，12檔逐檔hash一致，manifest留在同目錄。下方修正候選與v0.1的待驗敘述為歷史；**現行仍待：** 重讀、完整重啟重讀、停用開局包後重讀、逐件配裝／修練效果與四人AI實戰。下一步先人工重讀新檔確認四人60級／裝備，再從物品欄Insert試一場；關閉開場對話後觀察AI。試戰後不覆寫基準檔，物品消耗仍由原生扣除。

## v0.2 Esc崩潰修正候選

**已人工回報失敗＋崩潰檔定位，2026-09-07：** v0.1新遊戲可進入場景、看到及關閉整備提示；按Esc開角色選單時，在選單顯示前崩潰。21:36與21:37的[Windows事件](evidence/v01-crash-events.json)皆為`0xc0000005 / swd3.exe+0x15a18e`。[Console](evidence/v01-esc-crash-console.txt)已出現`READY`，沒有後續Lua例外，不能把「已整備」等同「可操作／可保存」。

**已靜態反解＋已捕獲狀態：** [暫存器](evidence/v01-crash-registers.txt)中RBX=0、R14=0，共用ACT設定RVA`0x2bf3cc`=9019、TSW快取RVA`0x2bf41c`=0。故障[函式](evidence/native-menu-crash.txt)`FUN_140159f30 @ 0x14015a18e`無空指標檢查即讀圖片寬度；[指令](evidence/native-frame-init.txt)`0x140159fa3`證明R14保存第二實參。堆疊返回`0xb27aa`位於`FUN_1400b2700`的物品說明框繪製，傳入上述共用TSW。這是本次崩潰的直接原因；沒有證據將其歸因於AI或44件配裝。

[共用物件報告](evidence/native-shared-frame.txt)第149–156行、`FUN_1400b3550`在標題介面初始化清空共用ACT後只設9019／QQ0，未重新解譯；原版`act.ext:9344`的ACT9019以RF9094指向TSW。[ACT解譯](evidence/native-frame-loader.txt)`FUN_140101200`的RF分支（`0x5246`）才填入物件+0x74。自訂起點省略序章後立即開物品頁，會碰到尚未填入的共用快取；不外推所有新遊戲或其他起點。

**v0.2專案決策：** 完成提示後呼叫原生`ESC.SaveMenu()`。原版`SceneSetting.lua`的SAVE_POOL亦使用此入口，MOD不選槽、不保存。[入口](evidence/native-save-entry.txt)`FUN_1400a6ea0`設定存檔UI狀態，`FUN_140092990`配置所有存檔列（空槽也有物件）；[繪製](evidence/native-menu-crash.txt)`FUN_1400947a0`先呼叫存檔列renderer，而[共用報告](evidence/native-shared-frame.txt)第271行、`FUN_140099a90`在畫列框前呼叫`FUN_140100260(&DAT_1402bf3a8,0)`載入共用ACT。藉此補齊初始化後再進角色／物品選單。這是有靜態控制流支持的修正候選，**尚非實機通過**。

**已mock／封裝反解：** 原有四人、44裝備、技能與熟練測試通過；補驗成功路徑為整備→提示→原生存檔UI、失敗不開存檔UI、缺入口於發物前拒絕、重入不重複補給。manifest與三個DAT逐檔一致；包SHA-256 `54A61932EFE0FDF32096A00BC839C53FA56CD8F11ADA23078F199D70EFA752CB`。[研究指紋](evidence/v02-research-fingerprints.json)包括exe、dump及採用腳本；Ghidra11.4.3／JDK21，唯讀既有同hash副本。

**本輪最小人工回歸：** 完整重啟→新遊戲→關閉提示→應開啟原生存檔畫面→先取消→Esc應正常開角色／物品選單。回報是否仍崩潰及四人人數即可；通過後再另存空槽。其餘保存／重載與AI實戰未回報，維持待驗。下方v0.1啟動時「尚未人工」描述為歷史狀態，以本節後續回報為準。

**已安裝及啟動：** 備份`.work/cai-test-start-v02-install-20260907-220822-081`含舊包、完整Save與两份MOD清單；只替換本機`Mods/cai_test_start.ssmod`，安裝hash與上述反解包一致。11個Save檔安裝及啟動後hash均未變，兩份清單未改，未動Steam工作坊版本。主視窗已出現，[Console](evidence/v02-startup-console.txt)確認本包v0.2、蔡魔王v0.9、玩家AI v0.1、挑戰模式v0.7載入；未操作遊戲內UI，取消存檔畫面與Esc回歸仍待人工。

## v0.1靜態與mock

2026-09-07，Steam HD4.0.5，原exe SHA-256 `63F1D83D8C3A756D17640D9022E19F8928741B091F0E47ABBDB22C0CCF6C9523`，既有Ghidra工作区副本以-readOnly／-noanalysis讀取；不修改遊戲核心資源。

**已靜態反解：** [新遊戲控制流](evidence/native-start-flow.txt)中`FUN_14009e820`先重建SaveData與dispatch GameStart，接著四次呼叫`FUN_14009dd70`初始化主角；後者直接讀NewGameChar的Level、HPMax／MPMax／SPMax、能力及抗性。新技能從NewGameSkill逐角色匯入，NewGameEqu則由native解譯11個命名部位，再透過原生裝備新增流程建立，無需猜數字槽位。來源脚本為[InspectStartFlow.py](tools/InspectStartFlow.py)；完整效果與讀舊存檔回歸仍待人工。

**已靜態反解：** [熟練讀寫](evidence/native-training.txt)的`FUN_14007ae20`／`FUN_14007aee0`使用ItemTemp的ProficientHard、Familiar與FamiliarPercent，`FUN_1400751a0`在達標後設isFamiliarMax；`FUN_140149d60`的SaveData優先查詢由前份report補足。物品結構Value有讀取，但不把ItemsClass舊註解當成完整修練契約。本版僅在新測試開局的SaveData.ItemTemp為12件裝備設原版門檻、等額Familiar、100%及完成標記。沒有改CommonSave.Familiar，沒有依名字呼叫未知native binding。來源[InspectNewGame.py](tools/InspectNewGame.py)。

**已mock／原表核對：** `tests/run-tests.ps1`載入七份原版數值Lua、原版ItemsClass，驗證四名60級資料與既有CSV基準HP／MP／SP相同，44件裝備、每人的升級法術與12個後續絕招、十二個原版修練門檻、啟動載入不寫SaveData、來源資料不累加、整備前驗裝／驗技能、四旗標、定量補給不重複發放、失敗禁止默默重試。mock以命名配置模擬native裝備建立，不宣稱驗證真實角色缓存或存檔重載。

## 人工最小驗收

**已封裝、反解、安裝與啟動，2026-09-07：** manifest與三個DAT逐檔SHA一致，安裝包SHA-256 `5D1FBC466AD1E0075460F9F9E988F04AF9D15347C43E450F7E1AA37EF792EFF9`。備份`.work/cai-test-start-v01-install-20260907-213453-139`包含完整Save資料夾及兩份MOD清單；安裝前後Save各檔hash不變。原Cai v0.9、玩家AI v0.1及挑戰模式v0.7維持啟用，Steam清單未改，未上傳工作坊。

遊戲主視窗已出現，[本輪Console](evidence/v01-startup-console.txt)第6–10行記錄四份Lv60設定及本包載入；第38–81行原生NewEquip逐角色建立44個部位：1武器、2頭、3身、4手、5腳、6／7飾品、8／9護駕、10／11法寶。這證明本版native命名裝備初始化實際執行，不能把原版Function.CheckSutra中的舊8／9註解當成已驗證法寶位置。尚未由使用者選新遊戲／進入CST_BEGIN，故整備完成、實際人物面板、修練及保存仍待人工。

1. 啟用`cai_test_start.ssmod`與既有蔡魔王／AI測試包，完整重啟。在標題選「新遊戲」，不要讀原本兩人檔來整備。
2. 應略過原版開場劇情，出現「四人滿裝測試開局」完成選单；關閉後開人物／裝備欄，確認四人60級、完整裝備、修練100%。若顯示整備失敗，不保存，回報Console。
3. **另存到空槽**，作為固定測試檔；物品欄Insert開始蔡魔王AI戰。關閉戰鬥開場台詞後應自動行動；若仍兩人或裝備缺件，回報人數／缺項即可。
4. 保存重讀、完整重啟重讀與停用開局包後重讀：四人／配裝／修練／技能須保留，補給不能憑讀檔增加。測完開局功能可停用此包，保留蔡魔王與AI包。

**待人工：** 上述全部實戰／保存矩陣。靜態與mock、啟動載入不能代替四人畫面、修練效果、操作可用及合法保存。此開局是測試環境，原版開場劇情被略過，不作正常劇情遊玩檔。

原版既有存檔不被本工具讀寫二進位內容。啟用期間「新遊戲」改為本測試起點；載入其他檔不從GameStart發放物品或補隊伍。仍應以停用後重啟使用正常遊玩檔，避免把測試模式當正式遊玩。

## 知識歸屬

本次可重用反例補至[UI正文](../../../docs/knowledge/ui-input-and-native-menu.md#選型原則)：提示選單成功不代表後續介面快取完成。原生冷啟動與存檔列載入的位址、dump及修正候選留在本研究；在人工回歸前不提升為通用修復保證。

原版新角色／命名配裝初始化及修練欄位的靜態路徑補至既有資料模型正文；具體44件配裝、60級、12件修練與起點留在本研究。新開局、保存／重載與native屬性缓存尚未人工驗證，沒有提升為已實測保證。

## v0.3 額外召喚庫存與明確補給入口

2026-09-07：新增4種原生護駕各2份背包備份、仙魄香定額4與十果粉20。保留44槽、原生成長、技能與訓練基準，保留先開native存檔UI的ESC崩潰修復。只在明確按下測試選單時補至定額；原版Lua整合mock已核對讀檔不發物、普通檔拒絕、戰鬥中拒絕、重複不超額及新遊戲失敗前置檢查。

封包SHA-256 `7E1B39DD3A87CA5F440AAE21CD5CCD4B3C690B92F1FCC8A181ADEF5F01FE6F6C`。逐檔封裝反解通過；使用舊四人Ready存檔的選單實際補給、保存重讀仍待人工。整合步驟見[蔡魔王v0.10](../../../swd3-cai-demon-king-mod/TESTING.md#v010-召喚資源與勝利結算)；未修改既有.sav。


## 2026-09-08 全模組檢查

既有語法與 mock 回歸通過。來源保留、不發佈 Steam，不重啟或操作遊戲；先前未通過／待驗案例不因此變更。
