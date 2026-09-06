# 靜態蛇卡收妖交換探針：驗證紀錄

| 檢查 | 狀態 |
| --- | --- |
| Lua 語法與 mock：載入期 ID `9004` | 通過 |
| mock：原生來源移除後新增靜態蛇卡 | 通過 |
| mock：橋接還原與 F1 清卡 | 通過 |
| 封裝反解與 SHA-256 | 通過（RunScene 修正後：`C857FA9E533CB679FD7C64566547526E80FE79C0DB8D0B102266EB21128E018A`） |
| 實機：靈契 → ID `9004` → 物品欄反白 | 通過：原生 ID `102` 安全交換為 ID `9004`，反白與返回地圖正常，F1 已清除。 |

## 實機證據

- **已實測**（Steam HD 4.0.5，2026-09-03）：Console 依序記錄資格 bridge、兩次 `Battle_Dead(mode=2)`、原生 `additem 102`／`delitem 102`、`additem 9004`、`confirmed: native source ID 102 exchanged for static snake card ID 9004`、資格還原與 `Battle_RestoreItem`。
- **已實測**：物品欄可正常反白 ID `9004`，可返回地圖；F1 顯示 `removed=1`，沒有保存。
- **待驗證**：護駕啟用、保存後讀取、非蛇魔物與 97 張以上靜態卡的批量註冊。
