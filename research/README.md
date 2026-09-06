# 研究清冊

一般 MOD 開發先讀 [AGENTS 任務路由](../AGENTS.md)指向的[通用知識](../docs/knowledge/README.md)。需要重現、反例、版本比對或補足未知條件時，才從本清冊選研究。

## 位置與狀態

`active/` 保存持續使用工具與未完成研究；`archive/` 保存已結案、被取代或停止的實驗。**歸檔不等於問題全解，也不等於識別碼已釋放。** 重跑歷史探針須先核對其所依賴的 MOD 版本、停用互斥與不存檔條件；不承諾舊探針可直接搭配現行正式版。

研究狀態只在本清冊維護；證據類型見[測試文件](../docs/knowledge/testing-and-verification.md#證據標記)，識別碼狀態見[相容性登記](../docs/compatibility-registry.md)。以下 19 個專案原本都直接位於工作區根目錄，新位置為表中連結；名稱不變。

## 持續使用與未完成研究（6 個）

| 研究／新位置 | 狀態與用途 | 已萃取知識 | 尚未解答／接續方式 |
| --- | --- | --- | --- |
| [swd3-engine-ui-diagnostics](active/swd3-engine-ui-diagnostics/README.md) | 持續使用：唯讀公開 API／package 名稱盤點 | [正文](../docs/knowledge/ui-input-and-native-menu.md) | 列出函式不證明可安全呼叫；native module 可用性未驗證 |
| [swd3-native-menu-probe](active/swd3-native-menu-probe/README.md) | 持續使用：原生選單、文字及 native 分析工具 | [正文](../docs/knowledge/ui-input-and-native-menu.md) | 選單長度／跨情境；收妖反解另見 NATIVE-CAPTURE-RESEARCH.md |
| [swd3-native-loader-probe](active/swd3-native-loader-probe/README.md) | 持續使用：Workshop／本機載入鏈靜態研究 | [正文](../docs/knowledge/packaging-and-installation.md) | 同名優先序、package runtime 與 DLL 可達性仍未驗證 |
| [swd3-capture-command-timing-probe](active/swd3-capture-command-timing-probe/README.md) | 持續使用：全戰鬥唯讀事件與 L1–L5 量測 | [正文](../docs/knowledge/battle-events-and-timing.md) | 操作先核對[現行來源版本與驗證範圍](active/swd3-capture-command-timing-probe/README.md#現行來源版本與驗證範圍)；完整操作配對、取消／逃跑／非致死 HP 仍缺案例 |
| [swd3-critical-hit-formula-probe](active/swd3-critical-hit-formula-probe/README.md) | 進行中：爆擊與實際 HP 差量測 | [正文](../docs/knowledge/battle-events-and-timing.md) | 真實武器樣本不足；BGI 限制及防禦 callback 使舊取樣假設需重查 |
| [swd3-seth-capture-window-probe](active/swd3-seth-capture-window-probe/README.md) | 進行中：live Boss 旗標與賽特輸入窗口 | [正文](../docs/knowledge/native-capture-and-eligibility.md) | 隔離收服已有證據；產品本機完成敘述不能補齊逐案傷害／取消／逃跑紀錄 |

## 歷史實驗（13 個）

| 研究／新位置 | 狀態與用途 | 已萃取知識 | 尚未解答／接續方式 |
| --- | --- | --- | --- |
| [swd3-all-monster-capture-probe](archive/swd3-all-monster-capture-probe/README.md) | 已歸檔：取代：早期動態新卡與收妖 wrapper | [正文](../docs/knowledge/runtime-api-and-data-model.md) | 新卡改走載入期註冊；wrapper 路徑不再研究，除非版本／條件改變 |
| [swd3-item-registry-cache-probe](archive/swd3-item-registry-cache-probe/README.md) | 已歸檔：否決：執行期新卡與 Lua cache 重建 | [正文](../docs/knowledge/runtime-api-and-data-model.md) | cache 命中仍閃退；不等同所有 native 註冊方式都失敗 |
| [swd3-static-item-registry-probe](archive/swd3-static-item-registry-probe/README.md) | 已歸檔：完成單卡：DAT 2 載入期靜態註冊 | [正文](../docs/knowledge/runtime-api-and-data-model.md) | 批量／存檔／停用依正式卡庫矩陣，不延長此單卡實驗 |
| [swd3-static-capture-exchange-probe](archive/swd3-static-capture-exchange-probe/README.md) | 已歸檔：完成單例：原生加來源物後交換靜態蛇卡 | [正文](../docs/knowledge/battle-and-inventory-lifecycle.md) | 完整卡庫驗收由正式專案承接 |
| [swd3-general-capture-eligibility-probe](archive/swd3-general-capture-eligibility-probe/README.md) | 已歸檔：取代：一般遭遇資格準備與交換 | [正文](../docs/knowledge/native-capture-and-eligibility.md) | 早期「只靠 UI 快取」解釋由 live gate 反解修正；Race 0 代表收服仍查正式矩陣 |
| [swd3-story-boss-level-gate-probe](archive/swd3-story-boss-level-gate-probe/README.md) | 已歸檔：完成隔離例：蚩尤來源 Lv1 的隔離收服 | [正文](../docs/knowledge/native-capture-and-eligibility.md) | 測試值非產品平衡；live 旗標研究接續於賽特窗口 |
| [swd3-high-level-capture-gate-probe](archive/swd3-high-level-capture-gate-probe/README.md) | 已歸檔：完成隔離例：牛魔王來源 Lv1 的第二首領驗證 | [正文](../docs/knowledge/native-capture-and-eligibility.md) | 不外推全部首領、一般遭遇或保存安全 |
| [swd3-formal-capture-validation-probe](archive/swd3-formal-capture-validation-probe/README.md) | 已歸檔：完成版本例：正式卡庫 v0.3／v0.4 牛魔王鏈路 | [正文](../docs/knowledge/battle-and-inventory-lifecycle.md) | 舊版成功不等於目前版本完整回歸；由正式 TESTING 承接 |
| [swd3-guardian-resistance-battle-probe](archive/swd3-guardian-resistance-battle-probe/README.md) | 已歸檔：否決：來源 Attr 與 callback 可寫性 | [正文](../docs/knowledge/runtime-api-and-data-model.md) | 否決已測方法；完整抗性公式暫停，新的不同方法另立研究 |
| [swd3-guardian-resistance-runtime-probe](archive/swd3-guardian-resistance-runtime-probe/README.md) | 已歸檔：否決：userdata AttrPoison 寫入 | [正文](../docs/knowledge/runtime-api-and-data-model.md) | 欄位不存在的反例；不重新嘗試同一寫入方案 |
| [swd3-high-level-capture-rate-probe](archive/swd3-high-level-capture-rate-probe/README.md) | 已歸檔：受限完成：高等目標、BattleScript 與 BSC.Obsolt | [正文](../docs/knowledge/native-capture-and-eligibility.md) | 僅自訂 coroutine 已成功；一般手動轉接未成立 |
| [swd3-manual-capture-bridge-probe](archive/swd3-manual-capture-bridge-probe/README.md) | 已歸檔：受限／否決：明確武裝接力及自動辨識反例 | [正文](../docs/knowledge/native-capture-and-eligibility.md) | 手動 AI 欄位不對應 private queue；一般自動接管暫停 |
| [swd3-live-card-battle-dialogue-probe](archive/swd3-live-card-battle-dialogue-probe/README.md) | 已歸檔：被取代：舊對話容器與輸入穿透 | [正文](../docs/knowledge/ui-input-and-native-menu.md) | 原 README 沒有完成結果；相關否決證據見原生選單紀錄，不把此探針本身標成通過 |

## 歷史文件與整理證據

- [早期蚩尤契約提案](archive/legacy-designs/CAPTURE-PROPOSAL.md)：保存被取代的建議與當時待測順序。
- [活物挑戰圖片研究](archive/legacy-designs/LIVE-CARD-IMAGE-ASSET-GUIDE.md)：舊格式與視覺實驗；候選素材仍在原 MOD 專案。
- [戰鬥 trace 與量測矩陣](active/swd3-capture-command-timing-probe/EVIDENCE.md)：完整案例、舊假設與 L1–L5；現行時序不再複製它們。
- [知識萃取與矛盾處理紀錄](archive/knowledge-consolidation-20260906/README.md)：逐條來源、正文去向、證據限制及本次搬遷驗證。

本機建置／反解與歷史封包已移至 `.work/legacy/` 或 `.work/extracted/`，不作為可編輯來源。搬遷清單記錄原路徑，歷史命令中的原路徑只表示當時環境；正式重跑使用目前專案入口與工具文件。
