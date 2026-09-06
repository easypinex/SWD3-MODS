# SWD3 MOD 通用知識庫

這裡是工作區內通用 SWD3 MOD 開發規則的唯一權威來源。專案 README 應只保存該專案的功能、參數、例外、版本證據與驗收，不複製整段通用教學。

## 按需求閱讀

| 需求 | 文件 |
| --- | --- |
| 查工具、命令與參數 | [工具與命令參考](tools-and-commands.md) |
| 建立專案、撰寫 `.ext` | [專案結構與 metadata](project-structure-and-metadata.md) |
| 封裝、反解、本機安裝 | [封裝與安裝](packaging-and-installation.md) |
| Lua 事件與相容性 | [Lua 事件與相容性](lua-events-and-compatibility.md) |
| 讀取遊戲物品、背包或角色資料 | [執行期 API 與遊戲資料模型](runtime-api-and-data-model.md) |
| 查原版角色、敵人、技能、物品、護駕、靈契或戰鬥強度資料 | [原版遊戲資料](original-game-data/README.md) |
| 建立自訂戰鬥、預留背包物品 | [戰鬥與背包生命週期](battle-and-inventory-lifecycle.md) |
| 查戰鬥 callback、觸發順序 | [戰鬥事件與時序](battle-events-and-timing.md) |
| 修改靈契資格、首領收服或使用 `BSC.Obsolt` | [原生靈契與資格判定](native-capture-and-eligibility.md) |
| 新增物品／物品欄閃退，或修改 live Boss flag | [資料模型](runtime-api-and-data-model.md)；涉及傷害時再讀戰鬥時序 |
| 中文與文字表 | [在地化與文字](localization-and-strings.md) |
| 設定、存檔、暫改資料 | [狀態保存與資料安全](state-persistence-and-safety.md) |
| UI、輸入與原生選單 | [UI、輸入與原生選單](ui-input-and-native-menu.md) |
| PNG、PIC、TSW 與圖庫 | [圖片與 TSW 資產](graphics-and-tsw-assets.md) |
| 自動測試、實機或研究 | [測試與驗證](testing-and-verification.md) |
| 研究未知 API、封包或引擎行為 | [引擎研究流程](engine-research-workflow.md) |
| 反解 `swd3.exe` 的特定 native 事件／函式、安裝前置工具 | [最短研究路徑](engine-research-workflow.md#查特定-native-事件或函式的最短路徑)；[腳本選擇與操作](tools-and-commands.md#ghidra完整-pe-靜態分析唯讀) |
| Steam 工作坊 | [Steam 工作坊發布](steam-workshop-release.md) |

不要為了修改一個功能而讀完全部文件；根目錄 `AGENTS.md` 是正式任務路由，依其最小閱讀路徑選讀即可。

## 證據等級

證據定義唯一正文見[測試與驗證](testing-and-verification.md#證據標記)。研究工具、歷史反例與未解問題見[研究清冊](../../research/README.md)；一般開發先讀上表正文，需要重現或補證據才下鑽研究。

結論引用方式見[精確證據定位](testing-and-verification.md#結論到證據的定位)，重跑前依[現行版本與歷史結果](testing-and-verification.md#現行版本與歷史結果)核對來源；未知版本不由整理日期或現行 metadata 補填。

## 維護規則

1. 一條通用規則只在本目錄保留一份正文；其他文件使用連結。
2. 絕對路徑只標示為本機範例，通用步驟使用 `<game-root>`、`<project-root>`、`<work-dir>`。
3. 不把 `dist`、反解資料夾或圖庫預覽當作可編輯來源。
4. 若行為依遊戲或工具版本而異，必須寫出已驗證範圍。
5. 工具名稱、參數與命令格式只在 `tools-and-commands.md` 維護；主題文件只說明工作流與驗收。
6. 修改通用規則時，同步更新根 `AGENTS.md` 路由與 `docs/document-inventory.md`。
7. 新增會與其他 MOD 共存的識別碼時，同步更新工作區層級的 [相容性登記表](../compatibility-registry.md)。
