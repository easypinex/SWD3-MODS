# 四人終局測試開局

2026-09-08：此測試模組保留於工作區，不發佈 Steam、不包含在正式模組封包。本次語法與既有 mock 回歸通過，未操作遊戲。蔡魔王正式本體 v1.3 起已移除測試補給及手動召喚接手選單；下方舊 Insert 操作只適用對應歷史本體，不能當現行正式版入口。

**現行v0.3，2026-09-07：** 保留v0.2原生存檔畫面的崩潰修復；新遊戲補給改為蟠桃3、仙魄香4、仙爐灰3、仙蓮子3、十果粉20、真夢娃娃1，以及額外神龍／鳳凰／鬥戰聖佛／尼凱各2份供召喚。原八份裝備護駕不挪用。

既有已完成整備的四人測試檔不用重建：搭配蔡魔王v0.10，物品欄Insert選「補齊測試補給與召喚護駕」。只對具有既有Ready標記且44槽／技能符合基準的測試檔开放，按下才補至定額；普通劇情檔與戰鬥中均拒絕。重複按不超額，讀檔／Scene重入不自動補回消耗。完成後由使用者另存空槽；精確測試狀態見[驗收](TESTING.md#v03-額外召喚庫存與明確補給入口)。下方v0.2敘述保留為歷史。

v0.2，2026-09-07，**使用者已通過取消存檔畫面後的Esc選單／四人回歸，並完成保存**；重讀及AI實戰仍待驗證。v0.1的選單崩潰定位為共用邊框TSW未初始化；v0.2先開原生存檔畫面補齊載入。獨立測試MOD，供沒有四人滿裝存檔的使用者建立蔡魔王／挑戰模式測試基準。採原生「新遊戲」建立角色、技能及命名裝備槽；不編輯既有`.sav`，不把未確認的等級寫入介面用於舊存檔。

目標：四名Lv60主角、[既定配裝](../../../swd3-cai-demon-king-mod/LOADOUT-AND-TESTING-SETUP.md)、原版可學技能與固定補給。能力由初始值加原版升級表，不加入永久能力藥。啟用期間「新遊戲」改為測試開局，讀取既有存檔不整備；使用者已人工保存測試檔。逐件裝備／修練效果、重读與停用後重讀仍待驗證，精確結果見[驗收](TESTING.md)。

遊戲操作一律人工。本研究的靜態工具只分析工作區內exe副本；來源在src，建置產物在dist，反解在工作區.work。沒有Codex plugin結構。

## 操作

啟用`cai_test_start.ssmod`完整重啟，在標題選**新遊戲**。看到整備完成後關閉提示，會開啟**原生存檔畫面**；首次回歸可先取消，再按Esc確認四人與裝備，通過後**另存空槽**。MOD只開畫面，不選槽、不自動保存。物品欄Insert可開始蔡魔王自動測試，開場台詞仍須手動關閉。建立並驗證測試存檔後可停用本開局包；恢復一般新遊戲亦需停用並完整重啟。此起點略過原版序章，只供戰鬥測試。

## 崩潰研究工具

`python tools/ReadCrashDump.py <dump路徑>`只讀Windows已產生的AMD64 minidump，輸出例外暫存器、已捕獲堆疊與本版共用邊框欄位；不附加程序、不修改dump。不提交完整dump。

`tools/InspectMenuCrash.py`、`InspectFrameInit.py`、`InspectSharedFrameAccess.py`、`InspectFrameRepair.py`、`InspectSaveEntry.py`，分別查故障函式、初始化字串／指令、共用ACT物件參照、ACT解譯與對話、原生存檔入口。中間排查工具`InspectFrameLifecycle.py`、`InspectLazyFrameCallers.py`與`InspectUiReinit.py`保留供重跑。皆為Ghidra Jython，固定HD4.0.5位址、不接收額外參數；依[工具索引](../../../docs/knowledge/tools-and-commands.md#ghidra完整-pe-靜態分析唯讀)，用既有副本專案`-process swd3.exe -noanalysis -readOnly -postScript <腳本名>`執行，stdout另存`.work`。只產生報告／Ghidra日誌，不修改程式。採用報告及指紋見[驗收](TESTING.md#v02-esc崩潰修正候選)。

設定只在新的測試起點發放一次，不靠GameStart判斷讀檔來加物品。失敗會顯示整備未完成並記錄Console，該次不要保存。補給包括蟠桃3、仙魄香2、仙爐灰3、仙蓮子3、十果粉10、真夢娃娃1；重複入口不補回已消耗物品。

`Build.ps1`沿工作區已驗證封裝／反解流程，`tests/run-tests.ps1`以隔離原版資料作測試。`tools/InspectNewGame.py`及`InspectStartFlow.py`是Ghidra Jython唯讀腳本，只適用驗收所記固定exe版本；按[工具索引](../../../docs/knowledge/tools-and-commands.md#ghidra完整-pe-靜態分析唯讀)以既有工作區副本產生報告，不可交一般Python執行。
