# Steam 工作坊發布素材包

2026-09-08 已查回原公開作品並下载核對，現行來源與 Steam 封包一致，本次無須上傳；見 [檢查紀錄](AUDIT-20260908.md)。下列候選／上傳清單為原發布準備歷史，未回報的遊戲案例仍保持待驗。

本目錄保留 `swd3-all-monster-static-capture-mod` v2.0 的 Steam 工作坊候選發布素材。v2.0 在保留 v1.9 高等目標原生收服邏輯外，加入原生 Boss 靈契窗口：原版 UI 與 action 6 可對原 Boss 目標使用，同時在非賽特執行前恢復 Boss 傷害分支。使用者已完成本機 v2.0 驗收；訂閱下載版仍須先以私人或僅限好友驗證。

通用發布流程與內容邊界見 [Steam 工作坊發布](../../../docs/knowledge/steam-workshop-release.md)；本目錄保存目前版本的具體素材、刊登文案與上傳驗收清單。

```text
steam-workshop/
├─ workshop_content/                         實際上傳內容，只含單一 .ssmod
├─ preview/                                  可直接選用的 Steam 預覽圖
├─ source/                                   封面原始大圖與 ImageGen prompt，不放進工作坊內容
├─ TITLE-ZH-TW.txt                           可直接貼入的工作坊標題
├─ DESCRIPTION-ZH-TW.txt                     可直接貼入的 Steam BBCode 說明
├─ STEAM-WORKSHOP-COPY-ZH-TW.md              標題、摘要、完整 BBCode 說明與建議標籤
├─ CHANGE-NOTE-v2.0.txt                      目前版本更新說明
├─ RELEASE-MANIFEST-v2.0.txt                 目前成品、預覽圖大小與 SHA-256
├─ CHANGE-NOTE-v1.8.txt、RELEASE-MANIFEST-v1.8.txt、v1.6 歷史版本證據
└─ UPLOAD-CHECKLIST.md                       SWD3Works 上傳與公開前驗收
```

v2.0 不包裝 `Function.CheckObsolt`，也不重寫原生 action 6。它只在命令／目標 UI 與賽特執行窗口暫時清除原始 Boss 目標的戰鬥副本 Boss bit；非賽特執行前立即恢復。高等卡庫目標仍只在 `Battle_Enter` 封頂為第一位戰鬥主角 +11，讓 HP ≤25% 走原生 100% 分支。訂閱下載版驗收前，仍應先設私人或僅限好友；細節見 [UPLOAD-CHECKLIST.md](UPLOAD-CHECKLIST.md)。
