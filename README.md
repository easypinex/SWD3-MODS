# 軒轅劍參 Steam MOD 工作區

本工作區保存《軒轅劍參：雲和山的彼端》Steam 高清版 4.0.x 的 MOD、研究探針、資源圖庫、測試與發布素材。

## Git 與本機重建資產

本目錄是 Git 專案，但不把可由正版遊戲安裝內容重新產生的大量圖檔提交到版本庫。`.gitignore` 排除兩套圖庫的圖片／PIC 目錄、原版 `all_*.tsw` 本機副本、封裝與反解驗證產物、本機 `Mods` 啟用清單、暫存預覽、遊戲存檔備份與一般工具快取；MOD 自製圖片、工作坊預覽、腳本、manifest、CSV 索引和研究文件仍納入版本控制。

從全新 clone 還原圖庫時，需先安裝 Steam HD 版遊戲，再依下列專案文件執行重建；所有輸出都留在工作區或獨立暫存目錄，不會修改遊戲核心資源：

- [重建 Steam HD TSW 圖庫](SWD3-HD-TSW-PNG-GALLERY/README.md#從全新-clone-重建圖庫)
- [重建原版來源 TSW 圖庫](SWD3-TSW-PNG-GALLERY/README.md#從全新-clone-重建圖庫)

這些排除項目不是遺失的編輯來源：它們來自本機遊戲封包，重建腳本、索引與已實測參數才是 Git 中的可維護內容。不要用 Git LFS 提交遊戲原始封包或整批解出圖檔。

本機 `build/`、安裝備份及一般 `.log` 不納入版控；`research/**/evidence/` 中被研究文件引用的原始日誌、版本指紋與驗證結果則保留，不能因為副檔名是 `.log` 而排除。既有產物即使符合忽略規則，仍須另外移出 Git 索引；移出索引不會刪除本機備份。

證據目錄透過 `.gitattributes` 停用自動換行轉換，保留檔案原始位元內容，讓不同平台取出的報告仍能核對既有 SHA-256。

## 正式 MOD

| 專案 | 功能 | 專案入口 |
| --- | --- | --- |
| `swd3-proficiency-multiplier-mod` | 武器熟練度倍率與選單切換 | [README](swd3-proficiency-multiplier-mod/README.md) |
| `swd3-refinery-diagnostics-unlock-mod` | 東西方煉化限制解除與配方診斷 | [README](swd3-refinery-diagnostics-unlock-mod/README.md) |
| `swd3-live-card-battle-mod` | 從活物卡建立 1～3 名敵人的挑戰戰鬥 | [README](swd3-live-card-battle-mod/README.md) |
| `swd3-all-monster-static-capture-mod` | 全魔物靈契、靜態契靈卡庫與原生收服交換 | [README](swd3-all-monster-static-capture-mod/README.md) |

成品狀態、版本、雜湊與實機驗收保留在各專案文件，不在工作區入口保存容易過期的本機狀態。

## 研究與資源

規劃中的獨立 MOD：[蔡魔王](swd3-cai-demon-king-mod/README.md)，目前為造型、戰鬥補齊與相容性評估草案，尚無可安裝版本。

- [研究清冊](research/README.md)：所有探針與診斷的單一入口；區分持續使用、未完成及歷史實驗，列出知識去向與未解問題。
- [Steam HD TSW 圖庫](SWD3-HD-TSW-PNG-GALLERY/README.md)：正式 HD ID／SN 映射與重建流程。
- [原版來源圖庫](SWD3-TSW-PNG-GALLERY/README.md)：swd3DVD 來源索引，不能當成 HD DrawTSW 對照。

一般開發從下方知識與任務路由開始；需要重現或查反例才讀研究。研究原始碼與證據集中於 `research/active`／`research/archive`，本機產物收於 `.work`。既有安全備份與遊戲本機資料保持原位置。

## 文件入口

- [通用知識庫](docs/knowledge/README.md)：依專案結構、封裝、Lua、執行期資料、戰鬥、文字、存檔、UI、圖片、測試、研究及工作坊分類。
- [戰鬥事件與時序](docs/knowledge/battle-events-and-timing.md)：Steam HD 4.0.5 的戰鬥 callback 索引、已知相對順序與證據界線。
- [原生靈契與資格判定](docs/knowledge/native-capture-and-eligibility.md)：開放首領、原生收妖接力與已否決路徑的設計入口。
- [工具與命令參考](docs/knowledge/tools-and-commands.md)：`SS2Dtool` 全部已知命令、參數、Console、SWD3Works、Node／Python 與圖庫腳本。
- [工作區相容性登記表](docs/compatibility-registry.md)：目前已使用的快捷鍵、hook、namespace、保存 key 與 ID；新增跨 MOD 識別碼前必讀。
- [文件盤點](docs/document-inventory.md)：目前說明文件與文字資產的角色及權威來源。
- [Agent 任務路由](AGENTS.md)：告訴後續 Agent 什麼情況應讀哪些知識文件。
- [舊開發筆記入口](SWD3-MOD-DEVELOPMENT-NOTES.md)與[舊發布清單入口](WORKSHOP-RELEASE-CHECKLIST.md)：保留既有連結，內容已移入知識庫。
