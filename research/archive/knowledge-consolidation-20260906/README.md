# 知識收斂與搬遷紀錄（2026-09-06）

這是本次文件維護的版本證據，不是另一份通用教學。本次未改 MOD 功能、安裝清單、存檔或發布狀態，也未增加實機驗收；採用整理開始時尚未提交的工作區內容，未以 Git HEAD 覆蓋它們。

## 逐條萃取對照

每列按一個開發問題回溯到現行正文與原始條件；下列舊假設是被修正的歷史，不是實作建議。原生位址與 exe SHA 保留於所連結證據。

| 開發問題 | 證據層次／條件 | 現行結論正文 | 原始證據 | 被修正的舊假設 | 保留界線 |
| --- | --- | --- | --- | --- | --- |
| 執行期新卡／重建 cache | 已實測反例；4.0.5／9-03 | [正文](../../../docs/knowledge/runtime-api-and-data-model.md#新增活物卡的原生註冊時點) | [研究](../../archive/swd3-item-registry-cache-probe/README.md) | cache 命中就能安全反白 | 限制於已測新卡與重建方法 |
| 載入期新卡 | 已實測；4.0.5／9-03 | [正文](../../../docs/knowledge/runtime-api-and-data-model.md#新增活物卡的原生註冊時點) | [研究](../../archive/swd3-static-item-registry-probe/README.md) | 所有新增 ItemTemp 都不安全 | 單卡註冊，不涵蓋全部保存／停用 |
| 原生來源物交換 | 已實測；4.0.5／9-03 | [正文](../../../docs/knowledge/battle-and-inventory-lifecycle.md#原生靈契--靜態活物卡) | [研究](../../archive/swd3-static-capture-exchange-probe/README.md) | Dead 可以立即扣物／發卡 | 保留基線與原生新增量條件 |
| 資格快取 | 已靜態反解＋隔離實測；4.0.5／9-05–06 | [正文](../../../docs/knowledge/native-capture-and-eligibility.md#四個不同階段) | [研究](../../active/swd3-native-menu-probe/NATIVE-CAPTURE-RESEARCH.md) | 戰前可選就保證後續不重讀旗標 | native 目標確認與結算要分開 |
| CheckObsolt wrapper | 已否決＋已靜態反解；4.0.5 | [正文](../../../docs/knowledge/native-capture-and-eligibility.md#公開-lua-能力與不可採用的推論) | [研究](../../archive/swd3-manual-capture-bridge-probe/README.md) | 以 wrapper 改手動成功率的早期提案 | 只否決 native 手動鏈，不否認直接呼叫 Lua 的結果 |
| BSC.Obsolt 上下文 | 已實測成功／失敗；4.0.5／9-05 | [正文](../../../docs/knowledge/native-capture-and-eligibility.md#bscobsolt-的受限呼叫上下文) | [研究](../../archive/swd3-high-level-capture-rate-probe/README.md) | 一般輸入 handler 或地圖 Scene 可以代用 | 不是任意玩家／目標公共收服 API |
| after 與傷害 | 已靜態反解＋L2；4.0.5／9-05 | [正文](../../../docs/knowledge/battle-events-and-timing.md#對-mod-設計的直接規則) | [研究](../../active/swd3-capture-command-timing-probe/EVIDENCE.md) | after 是傷害完成點 | 完整非致死與跨角色交錯仍不定義 |
| 暴擊 callback 識別動作 | 已實測 L2；4.0.5／9-05 | [正文](../../../docs/knowledge/battle-events-and-timing.md#已知戰鬥輪廓) | [研究](../../active/swd3-capture-command-timing-probe/README.md) | 有 callback 就是普攻 | 防禦 self-target 也會出現；不能推導傷害公式 |
| DrawBGI 開關 | 已靜態反解＋已否決實測；4.0.5 | [正文](../../../docs/knowledge/battle-events-and-timing.md#battle_drawbgi-與玩家-ai-模式) | [研究](../../active/swd3-native-menu-probe/NATIVE-CAPTURE-RESEARCH.md) | 追加 handler 不執行就是引擎永不 dispatch | 啟用 global 接管手動指令；不是純觀察開關 |
| live ItemType／來源 IT_06 | 已靜態反解＋隔離 readback；4.0.5 | [正文](../../../docs/knowledge/runtime-api-and-data-model.md#敵方-live-itemtype-旗標) | [研究](../../active/swd3-seth-capture-window-probe/NATIVE-EVENT-AND-CAPTURE-FLOW.md) | 來源 table 欄位就是 userdata 屬性 | 寫入時點按案例；Boss flag 有傷害副作用 |
| 來源 Level／戰鬥 Level | 官方檔內說明＋隔離實測；4.0.5 | [正文](../../../docs/knowledge/runtime-api-and-data-model.md#敵方-npcdatalevel-不是只供靈契使用) | [研究](../../archive/swd3-high-level-capture-rate-probe/README.md) | 降等只影響靈契 | 來源 Lv1 實驗與副本 +11 不混為一例 |
| 護駕 Attr／Add | 已實測反例；4.0.5／9-04 | [正文](../../../docs/knowledge/runtime-api-and-data-model.md#戰鬥中的角色資料) | [研究](../../archive/swd3-guardian-resistance-runtime-probe/README.md) | 已寫來源 Attr 或新增 userdata 欄位即可生效 | 已否決條件不擴張為全部未知抗性 API 不存在 |
| OnEvent dispatcher | 已靜態反解；固定 4.0.5 exe SHA | [正文](../../../docs/knowledge/lua-events-and-compatibility.md#優先追加不覆蓋) | [研究](../../active/swd3-native-menu-probe/NATIVE-CAPTURE-RESEARCH.md) | Lua 宣告本身可以證明 native 觸發 | dispatcher 順序與是否到達分支分開 |
| 選單 coroutine／Esc／中文 | 既有實測；4.0.x 範圍見原紀錄 | [正文](../../../docs/knowledge/ui-input-and-native-menu.md) | [研究](../../active/swd3-native-menu-probe/ENGINE-UI-RESEARCH.md) | Esc=0 與點空白取消混淆、顯示正確就代表不穿透 | 內部緩衝原因仍未反解，不提升猜測 |
| loader／native module | 已靜態反解；固定 4.0.5 exe SHA | [正文](../../../docs/knowledge/packaging-and-installation.md#steam-hd-405-mod-loader-與-native-module-載入的界線) | [研究](../../active/swd3-native-loader-probe/README.md) | 含 LoadLibrary 就是 Workshop DLL 載入機制 | runtime module 可用性仍未驗證 |

## 未提升的內容與矛盾處理

- 完整爆擊／抗性公式、所有 Boss 與完整退出矩陣沒有因本次整理而變成已驗證；續查[研究清冊](../../README.md)。
- 全魔物靈契 v2.0 的本機完成敘述保留為產品狀態；早期待測矩陣與籠統完成紀錄的差別，明列於[專案 TESTING](../../../swd3-all-monster-static-capture-mod/TESTING.md#v20-驗收敘述的證據對照)。
- 原生選單研究中舊提案與新反證保持時間順序，收妖／傷害段落拆至同專案 NATIVE-CAPTURE-RESEARCH；通用正文不再推薦已否決版本。
- UI 對話探針的 README 只有驗收條件，未保存完整結果；歸檔理由為被正式原生選單方案取代，沒有杜撰該探針的成功／失敗紀錄。
- 原版解包目錄是可由正版安裝重建的本機資料；搬到 `.work/extracted` 並保留匯出器、來源指紋與重跑入口，不將整包遊戲腳本當編輯來源。

## 搬遷與還原線索

[逐檔搬遷清單](file-manifest.csv)記錄原位置、目標位置、整理前／搬遷時大小與 SHA-256，以及完成後雜湊與變更類型。原有 604 檔之外，另含搬前新增的 2 份拆分證據；Markdown 有語意整理及連結改寫，不要求它們與整理前正文相同。原有非文件來源的雜湊另行核對，只有兩個研究／資料工具的定位修正屬預期例外。

本機 `.work/knowledge-consolidation/before/` 保存本次改寫前文件與腳本；未將可能過時的完整知識庫快照放回日常搜尋範圍。`.work/legacy` 的舊封包／反解資料全部保留，沒有刪除；不宣稱全部舊版本都能由目前 src 位元重建。需要舊命令環境時，按清單尋找現存檔案，不直接照抄歷史原路徑執行。

正式 MOD、兩套圖庫、根目錄 `archive` 的安全備份、`Save`、`Mods` 與 `SnapShot` 維持原位置。沒有因歸檔釋放任何識別碼。

## 驗證結果

**已完成文件與搬遷驗證，2026-09-06；未新增遊戲實測。** 詳細結果見 [validation.json](validation.json)。

| 檢查 | 實際結果 |
| --- | --- |
| 研究分類 | 19 個：active 6、archive 13；原根目錄探針均已搬移 |
| 移動前後完整性 | 41 個來源項目、606 個檔案，搬遷瞬間 SHA-256 全部一致；包括 20 個根目錄底線產物目錄、原版解包與根目錄舊封包 |
| 來源保護 | 核對 208 個既有非 Markdown 文字／程式／資料來源；僅 `.gitignore` 與 2 個工具定位改動，無非預期差異。原 MOD Lua、metadata、StringDB 與 CSV 沒有因本次整理改寫 |
| 文件連結 | 86 份 Markdown 的相對檔案／章節檢查通過；精確連結總數見 validation.json |
| 既有探針測試 | 15／15 組語法與 mock 包裝器通過，且均有 PASS，未見 stack traceback |
| PowerShell 與 loader | 18 份腳本語法解析通過；只執行 loader 的目錄定位區塊，正確找到根 `.tools/static-re`，未啟動 Ghidra／遊戲 |
| 資料集搬遷 | 由預設新來源位置匯出至獨立目錄，14 份 CSV 與既有 generated 逐檔完全相同，沒有覆寫原資料 |
| 忽略規則 | `.work`、研究 input／Ghidra database 的新位置均驗證仍為本機產物；未修改 Git index |

入口人工檢查涵蓋：新增物品／閃退、靈契资格／BSC、Boss／等級與異常傷害、callback 選點、重現與反例。均由 AGENTS 直達指定正文；只有重跑或正文未知時才進研究。

完成後的 SHA 清單允許文件更新，但不得把本次路徑／mock 檢查引用為新引擎實測。
