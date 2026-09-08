# 武器熟練度 100 倍

現行 **v1.1**，與 [Steam 已發佈版本](https://steamcommunity.com/sharedfiles/filedetails/?id=3787409181)一致。2026-09-08 依使用者要求移除本機 v1.2 的倍率滑桿，來源回復為遠端 v1.1 的原始內容。

## 原理與相容性

啟用後自動以固定 100 倍設定降低武器熟練門檻，最低為 1；原始門檻不足 100 的武器會變成命中一次即可達標，實際倍率不一定正好 100 倍。不修改熟練完成後的攻擊力加成，也不讀取舊版保存的倍率設定。

沒有遊戲內滑桿或 F8 面板。需要其他倍率的進階使用者，可修改來源設定檔後自行重新封裝；Steam 成品固定預設 100 倍。

支援 Steam 高清版 4.0.x，不綁定存檔。停用後可以繼續原存檔；因門檻恢復，原先顯示全滿的武器可能改顯示未滿，既有熟練值不會主動刪除。安裝、更新與停用後請完整重啟。

載入訊息：`[ProficiencyMultiplier] Applied x100.000 to 58 weapons`。封印之劍門檻由 2800 降至 28。

成品為 `dist/proficiency_multiplier.ssmod`；封裝方式見[共同規則](../docs/knowledge/packaging-and-installation.md)。[版本紀錄](PACKAGING-NOTES.md)、[刊登文案](workshop-description.md)、[本次核對](release/steam-workshop/AUDIT-20260908.md)保留來源與驗證證據。
