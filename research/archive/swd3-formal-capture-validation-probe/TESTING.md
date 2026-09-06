# 測試紀錄

## 自動檢查

- Lua 語法解析。
- mock：驗證戰拒絕未啟用正式 bridge 的狀態；啟動後只暫改戰鬥欄位，戰後完整還原。

## 實機驗收

依 README 操作。正式卡庫的 `capture exchange confirmed: source=59, card=10024` 是本驗證的必要證據。

## 實機結果

- **已實測，Steam HD 4.0.5，2026-09-03。** 正式卡庫輸出 `capture exchange confirmed: source=59, card=10024` 與 bridge 還原／重新武裝訊息；本驗證戰還原 HP 30,000、ATK 800，使用者確認 `10024` 反白正常。

## 封裝驗收

- **已通過，2026-09-03。** 自動 mock 通過；成品 SHA-256：`07E720DAD31B994BC107DEFB82FC8DCA49FC2334978C72FB5D113242DC304B42`。
- **已通過，2026-09-03。** 反解 manifest SHA-256：`4BEA1BB020274BD5C3E537D82A5935B6F77AE13EF6B74B873CAAB09458846151`；Lua SHA-256：`600C95FB99C1B45ACB3690CB7E58AB4D47D165430FF0BE95F797B6234B1891C5`，皆與來源一致。
