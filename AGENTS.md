# SWD3 MOD 工作區指引

本工作區製作的是《軒轅劍參：雲和山的彼端》Steam 高清版 MOD（`.ssmod`），不是 Codex plugin。不要建立 `.codex-plugin/plugin.json`、marketplace 或其他 Codex plugin 結構。

## 遊戲中測試由使用者人工操作

**使用者明確指示，2026-09-06；適用於本工作區後續所有任務。**

- 「遊戲中」的實機操作與驗收一律由使用者人工進行。禁止使用 `computer-use` skill，也不得改用其他 UI 自動化工具、模擬鍵鼠／控制器輸入或腳本代替使用者操作遊戲。
- Agent 先完成可行的靜態、mock、封裝與反解檢查，再提供精簡的人工測試步驟、預期結果與需要回報的資訊；依使用者回報及對應日誌記錄結果，未回報的案例維持待驗證。
- 下方關閉／啟動遊戲、開啟 Console 與安裝 MOD／外掛的既有預先授權仍有效，但不包含遊戲中的自動操作；Agent 可分析已產生的 Console／探針日誌。

## 閱讀原則

1. 先讀目標專案的 `README.md`。
2. 再依本次任務讀取下表指定的知識文件；不要預設讀完整知識庫。
3. 若目標專案有 `TESTING.md`、研究紀錄或發布目錄，只在任務涉及該範圍時讀取。
4. 通用規則與可跨 MOD 重用的原版資料只維護在 `docs/knowledge/`；專案文件只保留功能、具體參數、版本證據、例外與驗收結果。
5. 研究發現依 [測試與驗證的證據標記](docs/knowledge/testing-and-verification.md#證據標記)標示類型、版本與條件；沒有可重現證據的結論不得提升為通用規則。
6. 每次 MOD 開發、實驗或探針任務結束前，檢視本次成果是否包含可獨立重用的通用知識；符合證據與歸屬準則者，依本文件的知識歸屬規則提取到 `docs/knowledge/`，尚未達標者保留在專案或探針紀錄並標示證據等級，供後續開發使用。

## 依任務選讀知識

| 任務 | 必讀文件 |
| --- | --- |
| 建立新 MOD、探針或圖庫專案 | [project-structure-and-metadata.md](docs/knowledge/project-structure-and-metadata.md)；需要封包時再讀 [packaging-and-installation.md](docs/knowledge/packaging-and-installation.md) |
| 修改 `.ext`、`DAT` 或資源配置 | [project-structure-and-metadata.md](docs/knowledge/project-structure-and-metadata.md) |
| 查詢或執行任何外部工具、腳本或參數 | [tools-and-commands.md](docs/knowledge/tools-and-commands.md)，再讀該工具所屬的主題文件 |
| 封裝、解包、本機安裝或 `modlist.txt` | [tools-and-commands.md](docs/knowledge/tools-and-commands.md)、[packaging-and-installation.md](docs/knowledge/packaging-and-installation.md) |
| 新增 Lua hook、包裝原函式或處理載入順序 | [lua-events-and-compatibility.md](docs/knowledge/lua-events-and-compatibility.md) |
| 盤點、選擇或驗證戰鬥 callback／觸發順序／結算時點 | [battle-events-and-timing.md](docs/knowledge/battle-events-and-timing.md)；未知時序再讀 [engine-research-workflow.md](docs/knowledge/engine-research-workflow.md)、[testing-and-verification.md](docs/knowledge/testing-and-verification.md) |
| 讀取物品、背包、角色或 `GameData` | [runtime-api-and-data-model.md](docs/knowledge/runtime-api-and-data-model.md)；要暫改資料再讀 [state-persistence-and-safety.md](docs/knowledge/state-persistence-and-safety.md) |
| 盤點原版角色／敵人／技能／物品／護駕／靈契數值，或評估戰鬥強度與收妖 | [original-game-data/battle-balance-and-capture/README.md](docs/knowledge/original-game-data/battle-balance-and-capture/README.md)；需要結論與已知界線再讀 [original-game-data/battle-balance-and-capture/BALANCE-RESEARCH.md](docs/knowledge/original-game-data/battle-balance-and-capture/BALANCE-RESEARCH.md) |
| 建立自訂戰鬥或暫時預留背包物品 | [battle-and-inventory-lifecycle.md](docs/knowledge/battle-and-inventory-lifecycle.md)、[runtime-api-and-data-model.md](docs/knowledge/runtime-api-and-data-model.md)、[state-persistence-and-safety.md](docs/knowledge/state-persistence-and-safety.md)、[lua-events-and-compatibility.md](docs/knowledge/lua-events-and-compatibility.md) |
| 新增自訂物品、活物卡或遇到物品欄閃退 | [runtime-api-and-data-model.md](docs/knowledge/runtime-api-and-data-model.md) 的註冊時點；需要重現才讀其連結的註冊／快取探針 |
| 修改靈契資格、首領收服、原生接力或使用 `BSC.Obsolt` | [native-capture-and-eligibility.md](docs/knowledge/native-capture-and-eligibility.md)；只有數值問題才加讀原版平衡研究，只有重跑或正文未涵蓋時才讀研究 |
| 修改 Boss flag、戰鬥等級或追查異常爆擊 | [runtime-api-and-data-model.md](docs/knowledge/runtime-api-and-data-model.md) 的 Level／ItemType 段落、[battle-events-and-timing.md](docs/knowledge/battle-events-and-timing.md)；完整公式未知時讀相應研究 |
| 找反例、重現研究或整理／歸檔知識 | 工作區 [research/README.md](research/README.md)、相關主題正文、[testing-and-verification.md](docs/knowledge/testing-and-verification.md)（含[精確證據定位](docs/knowledge/testing-and-verification.md#結論到證據的定位)及[現行版本](docs/knowledge/testing-and-verification.md#現行版本與歷史結果)）；搬工具再讀 tools |
| 新增中文或 `StringDB` 文字 | [localization-and-strings.md](docs/knowledge/localization-and-strings.md) |
| 使用 `Setting`、`SaveData` 或暫改遊戲資料 | [state-persistence-and-safety.md](docs/knowledge/state-persistence-and-safety.md) |
| 製作 UI、鍵鼠／控制器輸入或原生選單 | [ui-input-and-native-menu.md](docs/knowledge/ui-input-and-native-menu.md) |
| 使用 PNG、PIC、TSW、`DrawTSW` 或圖庫 | [tools-and-commands.md](docs/knowledge/tools-and-commands.md)、[graphics-and-tsw-assets.md](docs/knowledge/graphics-and-tsw-assets.md) |
| 撰寫或執行自動測試 | [tools-and-commands.md](docs/knowledge/tools-and-commands.md)、[testing-and-verification.md](docs/knowledge/testing-and-verification.md) |
| 規劃實機驗收或研究探針 | [testing-and-verification.md](docs/knowledge/testing-and-verification.md)；使用研究腳本時再讀 [tools-and-commands.md](docs/knowledge/tools-and-commands.md) |
| 研究未知 API、資料欄位、封包或引擎行為 | [engine-research-workflow.md](docs/knowledge/engine-research-workflow.md)、[testing-and-verification.md](docs/knowledge/testing-and-verification.md)；涉及工具再讀 [tools-and-commands.md](docs/knowledge/tools-and-commands.md) |
| 反解 `swd3.exe`、追特定 native 事件流／函式邏輯、準備 Ghidra | [引擎研究最短路徑](docs/knowledge/engine-research-workflow.md#查特定-native-事件或函式的最短路徑)、[工具與腳本索引](docs/knowledge/tools-and-commands.md#ghidra完整-pe-靜態分析唯讀)、[testing-and-verification.md](docs/knowledge/testing-and-verification.md)；需要原始研究才讀對應探針 README |
| 新增快捷鍵、hook、全域名稱、保存 key、StringDB 前綴、戰場／TSW ID | [docs/compatibility-registry.md](docs/compatibility-registry.md)，再讀相應主題文件 |
| 準備 Steam 工作坊發布 | [tools-and-commands.md](docs/knowledge/tools-and-commands.md)、[packaging-and-installation.md](docs/knowledge/packaging-and-installation.md)、[testing-and-verification.md](docs/knowledge/testing-and-verification.md)、[steam-workshop-release.md](docs/knowledge/steam-workshop-release.md) |
| 修復／替代 SWD3Works、製作獨立 MOD 發佈維護工具 | [工具研究 README](research/active/swd3works-publisher-repair/README.md)、[桌面版與驗收](research/active/swd3works-publisher-repair/DESKTOP.md)、tools、testing、steam-workshop-release；產品規劃再讀 NEW-TOOL-DESIGN，修改安裝清單再讀 packaging |

未另註的主題文件都位於 `docs/knowledge/`；[docs/compatibility-registry.md](docs/compatibility-registry.md) 與 [research/README.md](research/README.md) 是工作區根目錄相對路徑。

[AGENTS.md](AGENTS.md) 是工作區共用知識的正式任務入口；[docs/knowledge/README.md](docs/knowledge/README.md) 僅提供人工瀏覽用索引，不取代本表的最小閱讀路徑。

## 依專案補充閱讀

| 專案 | 專案文件與主要知識 |
| --- | --- |
| `swd3-proficiency-multiplier-mod` | `README.md`；改倍率／保存讀 `state-persistence-and-safety.md`，改事件讀 `lua-events-and-compatibility.md`，改面板讀 `ui-input-and-native-menu.md`，發布讀 `PACKAGING-NOTES.md` |
| `swd3-refinery-diagnostics-unlock-mod` | `README.md`；必讀 `state-persistence-and-safety.md` 與 `lua-events-and-compatibility.md`；改診斷文字再讀 `localization-and-strings.md`；測試讀 `TESTING.md`；發布讀 `release/steam-workshop/` |
| `swd3-live-card-battle-mod` | `README.md`、`TESTING.md`；必讀 `lua-events-and-compatibility.md`、`state-persistence-and-safety.md`、`ui-input-and-native-menu.md`、`runtime-api-and-data-model.md`；改戰鬥／預留再讀 `battle-and-inventory-lifecycle.md`；碰圖片研究才讀 `IMAGE-ASSET-GUIDE.md` 與 `graphics-and-tsw-assets.md` |
| `swd3-cai-demon-king-mod` | `README.md`、涉及驗收時讀 `TESTING.md`；基本動作探針已人工通過，現行正式版技能／卡庫／勝敗仍依矩陣；發布見 release/steam-workshop；動作讀 graphics，未知路徑再讀 engine-research／testing，角色補齊讀 runtime／state，相容性依 README 選讀 |
| `swd3-all-monster-static-capture-mod` | `README.md`；資格／收服讀 native-capture，交換讀 battle-and-inventory，改資料讀 runtime／state；驗收讀 TESTING，發布讀 release |
| `swd3-engine-ui-diagnostics` | `README.md`、testing；只建立唯讀 API 盤點，不呼叫未知介面 |
| `swd3-native-menu-probe` | `README.md`、`ENGINE-UI-RESEARCH.md`、UI、testing |
| `swd3-live-card-battle-dialogue-probe` | `README.md`、UI、testing；正式活物功能不在此專案修改 |
| `SWD3-HD-TSW-PNG-GALLERY` | `README.md`、`SSMOD-FORMAT-RESEARCH.md`、graphics；腳本不得寫入遊戲安裝目錄 |
| `SWD3-TSW-PNG-GALLERY` | `README.md`、graphics；不得把來源索引誤稱為 HD `DrawTSW` 對照 |

研究專案已集中於 `research/active/` 與 `research/archive/`，表中名稱保持不變；實際入口與狀態以 [研究清冊](research/README.md) 為準。

## 文件維護與知識歸屬

新增或修正文檔前，先搜尋 `docs/knowledge/`、目標專案 README／TESTING，以及相關探針；不要因為同一規則在專案程式中出現，就複製一份新的教學。

| 情況 | 應放位置 | 判斷準則與後續動作 |
| --- | --- | --- |
| 已有相同主題的通用文件，且新內容是其直接補充 | 對應的 `docs/knowledge/<topic>.md` | 例如同屬 UI、Lua hook、封裝、存檔、資料模型或戰鬥安全。更新該文件的唯一正文；專案文件只保留連結、具體值與驗收證據。 |
| 是可獨立閱讀的跨 MOD 開發主題，既有文件無法自然容納 | 新增 `docs/knowledge/<english-kebab-case>.md` | 必須有清楚責任邊界、可重用的任務路由、可重現證據與安全限制；不可只是單一 API 或某專案功能的拆檔。同步更新 `docs/knowledge/README.md`、本 `AGENTS.md`、`docs/document-inventory.md`；若工作區入口需要導航，再更新根 `README.md`。 |
| 功能行為、數值、物品 ID、UI 座標、成功訊息、版本、雜湊、發布文案或專案例外 | 目標 MOD 專案內的 README、TESTING、PACKAGING／release 文件 | 這些是專案契約或版本證據，不提升為引擎規則。需要通用背景時連到知識庫，不重複教學。 |
| 未知 API、單次觀察、失敗實驗或尚未完整驗收的引擎行為 | 對應研究探針的 README／研究紀錄 | 標示「待驗證」或「已否決路徑」，寫出版本、步驟、結果與停止／還原方式。只有可重跑且可跨 MOD 使用後才提升。 |
| 快捷鍵、hook 目標、全域 namespace、保存 key、StringDB 前綴、戰場或實驗資產 ID | `docs/compatibility-registry.md` | 這是工作區防撞名登記，不是通用 API 文件；新增或釋放識別碼後立即更新。 |

### 提升與拆分準則

1. 先確認證據等級：沒有可重現證據，先留在探針；有已實測、官方檔內說明或可重跑的已靜態反解，才可按其證據邊界寫成通用知識，且必須保留版本與邊界。
2. 優先補既有文件。只有內容同時具有獨立的任務入口、明確責任邊界，且放入現有文件會迫使 Agent 閱讀大量無關內容時，才新開知識文件。
3. 一條通用規則只能有一個正文權威來源；其他知識文件、專案 README 與舊入口只放精簡摘要或連結。
4. 不把「某 MOD 剛好這樣做」寫成遊戲保證。通用文件要區分已實測、待驗證與專案決策；完整原始證據留在專案／探針。
5. 每次文件修改至少驗證相對 Markdown 連結。新增通用路由或跨 MOD 識別碼時，同步檢查本 `AGENTS.md` 的最小閱讀路徑仍正確。

## 修改與驗證規則

- 不要直接修改遊戲安裝目錄中的核心資源；研究與解包使用獨立工作目錄。
- 執行 `SS2Dtool`、圖庫腳本、Node/Python 工具或 `SWD3Works` 前，先從 `tools-and-commands.md` 核對參數、輸出與副作用。
- 不以工具退出碼代表成功；封裝後必須確認產物並反向解包。
- 修改 Lua、metadata、文字或資源時，執行與風險相稱的靜態、mock、反解及實機驗收。
- 人為進入遊戲進行實機測試屬高成本驗證；應先完成可行的靜態、mock、封裝與反解檢查，僅在需要驗證遊戲內行為或其他低成本方式無法覆蓋驗收時才進行。
- 若修改內容需要安裝 MOD／外掛以驗證或使用，已預先授權 Agent 自行關閉遊戲、開啟 Console 工具、安裝 MOD／外掛並重新啟動遊戲，無須另行詢問確認。安裝前須留意來源：遊戲目錄本身的 `Mods` 與 Steam 版本皆可能提供或覆寫 MOD／外掛，應確認目標版本與實際載入來源一致。
- 本機實機測試先開啟 `<game-root>\Tools\SS2DConsole.exe`，再依使用者目前已驗證的遊戲流程啟動（可直接執行 `<game-root>\swd3.exe`，或由使用者在 Steam 客戶端手動按 Play）。只有遊戲主視窗出現且 Console 收到 MOD 載入訊息時，才能稱為啟動成功；不可只看背景 `swd3` 程序。若一次啟動立即退出或 Windows 應用程式事件記錄出現 `swd3.exe` crash，停止自動重試與猜測 Steam URI／`-applaunch` 參數，保留 Console 並請使用者按其已知可用流程啟動；記錄結果後才更新本規則。
- 不把 `dist`、反解目錄、圖片圖庫或版本化發布素材當作可編輯來源。
- 新增跨 MOD 可見的識別碼前先查 `docs/compatibility-registry.md`，完成後更新登記表。
- 若只改文件，至少檢查相對連結及通用規則是否仍只有一個權威來源。

本工作區根目錄是 Git project root；應從本根目錄開啟 Codex，以載入共用指引。研究移動不得覆蓋未提交修改。新探針建立於 `research/active/`，結束後逐條檢查知識歸屬，再依 `research/README.md` 更新狀態與位置；本機建置／反解工作使用 `.work/` 或專案既有產物目錄，不在根目錄新增散落的 `_build_*`／`_verify_*`。
