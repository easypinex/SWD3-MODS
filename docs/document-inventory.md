# 文件責任與現況盤點

更新日期：2026-09-06。這是現況與權威位置清冊，不是知識正文或按批次累加的更新日誌。歷史盤點基線與本次搬遷證據見[整理紀錄](../research/archive/knowledge-consolidation-20260906/README.md)。

## 入口責任

| 文件 | 唯一責任 | 不應保存 |
| --- | --- | --- |
| [工作區 README](../README.md) | 正式 MOD、圖庫與主要入口導航 | 易過期的本機啟用／發布狀態 |
| [AGENTS](../AGENTS.md) | 依開發任務條件決定最小閱讀路徑、知識歸屬 | 原始 trace、產品版本教學 |
| [知識庫索引](knowledge/README.md) | 人工按主題瀏覽 | 第二份通用規則或證據定義 |
| [研究清冊](../research/README.md) | 20 個研究專案的位置、狀態、正文去向與缺口 | 完整引擎結論 |
| [相容性登記](compatibility-registry.md) | 快捷鍵、hook、namespace、保存 key、文字與資產 ID 的擁有／保留狀態 | native API 規格 |
| 本文件 | 文件與資料責任清冊 | 研究結果的另一份摘要正文 |

## 通用主題（15 份正文）

| 主題 | 責任邊界 |
| --- | --- |
| [專案結構](knowledge/project-structure-and-metadata.md) | 型態、metadata、DAT、來源／產物位置 |
| [工具與命令](knowledge/tools-and-commands.md) | 工具參數、輸出、副作用與目前可執行路徑；native 問題到腳本索引、前置環境、首次 Ghidra 匯入與報告重跑 |
| [封裝與安裝](knowledge/packaging-and-installation.md) | 建置反解、安裝與版本限定 loader 能力界線 |
| [Lua 事件](knowledge/lua-events-and-compatibility.md) | dispatch、追加／包裝、回傳與相容性 |
| [資料模型](knowledge/runtime-api-and-data-model.md) | 查表、靜態註冊、userdata 與欄位副作用 |
| [原生靈契](knowledge/native-capture-and-eligibility.md) | 資格到結算、公開能力與 BattleScript 邊界 |
| [戰鬥時序](knowledge/battle-events-and-timing.md) | callback 索引、已知相對關係與安全選點 |
| [戰鬥／背包](knowledge/battle-and-inventory-lifecycle.md) | 預留、交換與副作用補償 |
| [狀態安全](knowledge/state-persistence-and-safety.md) | 序列化、快照及依預覽／戰鬥／預留用途選擇還原時點 |
| [UI／輸入](knowledge/ui-input-and-native-menu.md) | 原生選單、輸入與 modal 限制；逐項來源及早期版本缺口 |
| [在地化](knowledge/localization-and-strings.md) | StringDB、語言槽與文字使用 |
| [圖片](knowledge/graphics-and-tsw-assets.md) | PNG／PIC／TSW 與來源／HD 對照界線 |
| [測試](knowledge/testing-and-verification.md) | 證據標記與精確定位、現行版本／歷史結果的唯一規則正文、驗證層次及文件搬遷檢查 |
| [引擎研究](knowledge/engine-research-workflow.md) | 原版基線、研究方法與提升門檻；特定 native 事件／函式的最短證據路徑，命令連到工具正文 |
| [工作坊](knowledge/steam-workshop-release.md) | 上傳、訂閱下載驗收與發布流程 |

## 正式專案、圖庫與資料

| 位置／群組 | 文件及資產角色 |
| --- | --- |
| [熟練度 MOD](../swd3-proficiency-multiplier-mod/README.md) | README 功能／倍率；PACKAGING-NOTES 歷史版本與例外；workshop-description 發布文案 |
| [煉化 MOD](../swd3-refinery-diagnostics-unlock-mod/README.md) | README 功能；TESTING 驗收／還原；PACKAGING 與 release 保留版本證據及發布素材 |
| [挑戰 MOD](../swd3-live-card-battle-mod/README.md) | README／TESTING 為現行產品契約；BALANCE-AND-SAFETY-AUDIT 為產品決策；IMAGE-ASSET-GUIDE 僅為歷史入口；release 為逐版素材 |
| [全魔物靈契](../swd3-all-monster-static-capture-mod/README.md) | README／TESTING 為功能、具體數值、版本與案例證據；catalogue 為自有映射／平衡輸出；release 為發布素材 |
| [蔡魔王 MOD 規劃](../swd3-cai-demon-king-mod/README.md) | 僅評估草案：既有造型選項、戰鬥補齊需求、獨立入口、相容性與分階段門檻；尚無來源封包或實機結果 |
| [HD 圖庫](../SWD3-HD-TSW-PNG-GALLERY/README.md) | README 重建；SSMOD-FORMAT-RESEARCH 為格式證據；manifest／CSV 為映射，圖片可由正版安裝重建 |
| [來源圖庫](../SWD3-TSW-PNG-GALLERY/README.md) | README 重建；來源 manifest／CSV 不作 HD 映射 |
| [原版資料入口](knowledge/original-game-data/README.md)及[戰鬥資料集](knowledge/original-game-data/battle-balance-and-capture/README.md) | BALANCE-RESEARCH 只維護原版數值分析與界線；匯出腳本及 generated CSV 為共用資料來源／推導，不是產品設定 |
| [研究清冊](../research/README.md) | 7 個持續使用／未完成、13 個歷史探針；各 README／TESTING 保存條件、重跑與停止方法 |
| [發佈工具診斷與替代](../research/active/swd3works-publisher-repair/README.md) | README 保存 F1–F3 與備案；NEW-TOOL-DESIGN 為產品規劃；DESKTOP 保存現行 0.3.0 桌面版契約；RELEASES／PROTOTYPE 保存 0.2.0／M0 歷史；prototype／scripts 為自有來源；evidence 保存靜態與真實 Steam 驗證、核對報告 |
| research/archive/legacy-designs | 舊蚩尤提案、圖片方案；現行文件只連結，不複製教學 |

## 非說明文件與本機產物

- `src/data/*.txt` 是 StringDB 可編輯來源；requirements.txt 是工具依賴，不能當成舊說明而歸檔。
- `.ext`、Lua、原創圖片是 MOD／工具來源，本次只移研究位置，不改 MOD 行為；發布文案與 manifest 仍留各 release。
- `.work/legacy` 保存根目錄舊建置、反解、預覽與退休封包；`.work/extracted/script-index-inspect` 保存原版腳本副本。它們不納入版本庫，不作編輯來源；本次未刪除其內容。
- 舊根 archive 安全備份、Save、Mods、SnapShot 維持原位置。`.tools`、Ghidra input／database 及兩套大量原版圖片屬本機快取；研究報告與重跑腳本仍保留。
- [文件檢查器](tools/check-docs.py)只檢查本工作區維護的 Markdown 檔案與錨點；執行方式見[工具文件](knowledge/tools-and-commands.md#文件連結檢查)。

## 舊入口相容性

[舊開發筆記](../SWD3-MOD-DEVELOPMENT-NOTES.md)、[舊發布清單](../WORKSHOP-RELEASE-CHECKLIST.md)與挑戰圖片舊入口保留精簡導引。研究專案原本的根目錄位置不另建空殼，避免再次混雜；新舊位置由研究清冊及[逐檔搬遷清單](../research/archive/knowledge-consolidation-20260906/file-manifest.csv)追溯。
