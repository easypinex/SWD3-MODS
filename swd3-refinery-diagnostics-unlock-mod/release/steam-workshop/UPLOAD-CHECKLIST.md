# SWD3Works／Steam 工作坊上傳清單

這是 `refinery_diagnostics_unlock` v1.5 的專案清單；通用發布流程見 [Steam 工作坊發布](../../../docs/knowledge/steam-workshop-release.md)。

## 應選擇的檔案

- 內容資料夾：`workshop_content`
  - 只包含 `refinery_diagnostics_unlock.ssmod`。
- 主要預覽圖：`preview/refinery-workshop-primary-preview.jpg`
  - 1024 × 1024 JPEG。
  - 327,581 bytes，低於 1 MB。
- 標題：複製 `TITLE-ZH-TW.txt`。
- 說明：複製 `DESCRIPTION-ZH-TW.txt`。
- 文案備忘與建議標籤：`STEAM-WORKSHOP-COPY-ZH-TW.md`。
- 更新說明：複製 `CHANGE-NOTE-v1.5.txt`。

不要把 `source`、`src`、`tests`、README、解包資料或散裝 `.ext`／`.lua`／`.txt` 放進內容資料夾。

## 建議發布順序

- [ ] 開啟遊戲目錄內的 `SWD3Works.exe`。
- [ ] 新建工作坊項目，語言選繁體中文。
- [ ] 貼上標題、完整說明與更新說明。
- [ ] 內容資料夾選擇本目錄的 `workshop_content`。
- [ ] 預覽圖選擇 `preview/refinery-workshop-primary-preview.jpg`。
- [ ] 第一次先設為私人或僅限好友。
- [ ] 上傳完成後接受 Steam 工作坊法律協議（若 Steam 提示）。
- [ ] 取消訂閱後重新訂閱，確認 Steam 實際下載的內容。
- [ ] 檢查 `steamapps/workshop/content/1638230/<工作坊 ID>` 只含預期成品。
- [ ] 完全關閉並重開遊戲，以訂閱下載版重新測試。
- [ ] 確認 Console 初始化訊息、東西方切換、正式煉化與離開選單清理。
- [ ] 另拍一張 v1.5 實機診斷面板圖，確認文字清晰無重影後再設為公開。

## 公開前最低實機驗收

- [ ] 預設西方為黃橘色，東方為淺黃色。
- [ ] 未取得封神壇時，`End` 使東方變黃橘色。
- [ ] 已取得封神壇時，`Q／左` 選東方，`E／右` 選西方。
- [ ] 更換配方後方向不會錯跳。
- [ ] 正式成品等級不是 1。
- [ ] 只扣兩份材料、只增加一份成品。
- [ ] 取消、換地圖、進戰鬥後面板不殘留。
