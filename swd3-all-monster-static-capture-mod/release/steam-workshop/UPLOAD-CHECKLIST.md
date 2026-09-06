# SWD3Works／Steam 工作坊上傳清單

這是 `swd3_all_monster_static_capture` v2.0 的候選上傳清單；通用發布流程見 [Steam 工作坊發布](../../../docs/knowledge/steam-workshop-release.md)。訂閱下載版驗收完成前，只能設私人或僅限好友。

## 應選擇的檔案

- 內容資料夾：`workshop_content`
  - 只包含 `swd3_all_monster_static_capture.ssmod`。
- 主要預覽圖：`preview/all-monster-static-capture-workshop-primary-preview.jpg`
  - 1024 × 1024 JPEG，低於 1 MB。
- 標題：複製 `TITLE-ZH-TW.txt`。
- 說明：複製 `DESCRIPTION-ZH-TW.txt`。
- 文案備忘與建議標籤：`STEAM-WORKSHOP-COPY-ZH-TW.md`。
- 更新說明：複製 `CHANGE-NOTE-v2.0.txt`。

不要把 `source`、`src`、`tests`、README、解包資料、散裝 `.ext`／`.lua`／`.txt` 或其他 MOD 成品放進內容資料夾。

## 建議發布順序

- [ ] 開啟遊戲目錄內的 `SWD3Works.exe`。
- [ ] 新建工作坊項目，語言選繁體中文。
- [ ] 貼上標題、完整說明與更新說明。
- [ ] 內容資料夾選擇本目錄的 `workshop_content`。
- [ ] 預覽圖選擇 `preview/all-monster-static-capture-workshop-primary-preview.jpg`。
- [ ] 第一次先設為私人或僅限好友。
- [ ] 上傳完成後接受 Steam 工作坊法律協議（若 Steam 提示）。
- [ ] 取消訂閱後重新訂閱，確認 Steam 實際下載的內容。
- [ ] 檢查 `steamapps/workshop/content/1638230/<工作坊 ID>` 只含預期成品。
- [ ] 在 MOD 管理停用再啟用，完全關閉並重開遊戲，以訂閱下載版驗收。

## 公開前最低實機驗收

- [ ] Console 顯示 `mappings=193, static=97, failures=0` 與 `sources=193, races=16, skipped=0`。
- [x] **v1.9 隔離驗證：** Lv35 對來源 Lv80 牛魔王，戰鬥副本封頂 Lv46，HP `15/100` 時原生 `CheckObsolt=100`，使用者手動靈契成功；來源／地圖等級仍為 Lv80。
- [x] **v2.0 本機驗收：** 使用者確認原版戰鬥中的 Boss 靈契與妮可傷害窗口可用；原生 action 6 成功後仍由既有交換流程產生映射契靈卡。
- [ ] 訂閱下載版以敵方高至少 12 級的 Boss 代表目標，確認 `battle level cap applied`、`Boss window ... OFF/ON`、原生 action 6 成功與映射交換，並在離場後確認來源等級不變。
- [ ] 訂閱下載版再讓妮可普攻／爆擊同一 Boss，確認傷害不會異常固定為 `9999`；離場後確認沒有殘留的 Boss ItemType。
- [ ] 新卡在物品欄可反白，摘要顯示九維加成；按 N 仍是原版長篇介紹。
- [ ] 新卡留在背包、SP 足夠時，能由「物品 → 護駕」正常召喚；戰後仍在背包。
- [ ] 新卡裝進護駕欄時，角色面板九項加成生效；確認它不會同時出現在背包召喚清單。
- [ ] 含新卡的存檔完整重啟並讀取後，卡片仍在且可反白。
- [ ] 不要在停用 MOD、卡片消失的狀態保存；重新啟用後讀取未覆寫存檔，確認卡片恢復。
- [ ] Race 0 天神系來源若有合適存檔／遭遇，另做一次收服驗收；若尚未完成，不對外宣稱它們已完整實測。
