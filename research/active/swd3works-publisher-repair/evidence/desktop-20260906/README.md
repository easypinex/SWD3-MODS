# 桌面版 0.3.0 驗收

**已實測，2026-09-06。** Windows／Framework 4.8，Steam 登入帳號 `76561198095249191`，AppID `1638230`。使用自有純測試 `.ssmod`，不含遊戲功能。介面測試先於正式交付版本完成；正式版再驗證啟動、作品清單、紀錄恢復及核對結果。來源指紋見 [desktop-fingerprint.json](desktop-fingerprint.json)／[worker-fingerprint.json](worker-fingerprint.json)。正式版從介面[匯出報告](desktop-verification.html)，9 項完整資料均顯示一致。

| 案例 | 結果與證據 |
| --- | --- |
| 更新既有私人作品 | `3796691396`，0.5 → 0.6；由介面修改標題、說明、更新說明及檔案選擇器指定成品。[計畫](v0.6-plan.json)、[狀態](v0.6-state.json)含 Before／After／兩個語言／實際下載 SHA-256 |
| 新建私人作品 | `3796719765`，0.7；透過新建及草稿匯入、核對頁送出，取得並保存新 ID。[計畫](v0.7-plan.json)、[狀態](v0.7-state.json) |
| 遠端查詢 | 介面重新下載 0.6：`studio_m0_fixture.ssmod`，768 bytes，`456AF85FF3CF3C2707CE741937DCF73BD7C315882543DC7EB45659AAC3B3A7A1`；歷史含 0.3／0.4／0.5／0.6 |
| 封包找回 | 正式版從 0.7 作品按「取回目前 Steam 封包」，成功複製到一般使用者目錄的 recovered，綁定草稿；本機檔案 SHA-256 與 0.7 計畫相同 |
| 重啟與恢復 | 完整關閉再開啟：草稿文字／封包綁定仍在；正式版找回 7 個作品，發佈紀錄保留 0.6／0.7「已驗證完成」 |
| 錯誤路徑 | 空白新草稿阻止發佈；Steam 真實拒絕提交後按鈕恢復，可切換設定／發佈紀錄；重新開啟失敗操作及重新審閱可用 |
| 離線程序測試 | 工作者 14 + 18 項，桌面 [13 項](desktop-self-test.jsonl)：64 位 ID、非法網址、UTF-8 原子保存／備份、含引號／空格參數、stdout/stderr 同時排空、非零失敗、停止後可再執行 |
| 封包回歸 | 5 項通過：錯誤封包、宣告版本不可覆蓋內嵌版本、既有發布快照不可覆寫、非封包拒絕、來源變更不影響快照 |
| 公開作品 | 原四件公開作品標題、說明、可見度、更新時間、大小、metadata 比對未變；見 [public-unchanged.json](public-unchanged.json) |

0.7 實際下載為 770 bytes，SHA-256 `56964451328E480C9F179A72B0DE7574EBD72FF7C700B2611FEBD1A1B27C2F6F`。所有成功結果均以真實查回／下載判定，沒有把 Submit OK 或程序退出碼單獨當成成功。

## 預覽環境的資料隔離問題

**已實測＋官方說明，限定本次啟動環境。** 原預覽將快照寫入 LocalAppData，程式可讀，但 Steam 上傳回 `k_EResultFail`。縮短路徑仍失敗；[Steam mapping 紀錄](steam-mapping-failure.log)指出 LocalAppData 位置不存在。另找到實際檔案位於宿主套件的 `LocalCache/Local/SWD3Upload`。這符合 Microsoft 描述的 [MSIX AppData 重導向](https://learn.microsoft.com/en-us/windows/msix/desktop/desktop-to-uwp-behind-the-scenes)，不能把首次觀察誤記為 Steam 路徑 127 字元上限。

最終將桌面資料、操作快照、工作者歷史放在一般 `%USERPROFILE%/SWD3ModStudio/`，同一 0.6 封包隨後成功。若匯入的計畫仍位於 LocalAppData，工作者會產生一般使用者目錄的上傳副本，核對完整雜湊且鎖定後才提交。這項副本分支具靜態檢查，本次成功 GUI 路徑直接使用一般使用者快照；不宣稱所有封裝啟動環境均已測。

失敗的原操作已重新下載核對未變後結案，原紀錄保留。未修改遊戲核心／已安裝 MOD，未操作四件公開作品的發佈。未測 Windows 登出、斷電、磁碟耗盡與其他 Steam 帳號；本機程序取消測試不宣稱遠端上傳取消成功。
