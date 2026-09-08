# 武器熟練度 MOD：封裝與相容性紀錄

通用的專案結構、`SS2Dtool` 呼叫、反向解包、本機安裝與工作坊流程，分別見：

- [專案結構與 metadata](../docs/knowledge/project-structure-and-metadata.md)
- [封裝與安裝](../docs/knowledge/packaging-and-installation.md)
- [Steam 工作坊發布](../docs/knowledge/steam-workshop-release.md)

本文件只保留 `proficiency_multiplier` 的實測歷史與專案例外。

## 現行 v1.1 回復（2026-09-08）

依使用者要求從 Steam ID `3787409181` 下載 v1.1，反解後將 metadata 與兩份 Lua 原樣還原至來源。移除 v1.2 的 UI Lua／DAT；不再使用 F8、`SysInit[4]` 或保存的倍率 key。遠端維持原 v1.1，不重新上傳。

v1.1：2,209 bytes，SHA-256 `580CB912620E79A315F3705E9CAEA198A097A5E2A0FC47329F9A22DE77958DB7`。本次檢查見[紀錄](release/steam-workshop/AUDIT-20260908.md)。下列滑桿、點擊及固定 SysInit 索引均為已移除的 v1.2 歷史。

## 實測基線

- 遊戲：Steam HD `swd3.exe 4.0.5`
- Steam App ID：`1638230`
- 測試日期：2026-08-21
- `dist/proficiency_multiplier.ssmod`：4,022 bytes
- SHA-256：`D41F625F79EEF388B6F43D0E36588C32A2419F6FB2698F6A7F8384C14980B982`

## 工作坊散檔事故

早期工作坊內容使用 `proficiency_multiplier.ext` 加三個 `data/*.lua`。Steam 能完整下載，MOD 管理也顯示啟用，`modlist.txt` 寫成 `.ext`，但 Console 沒有任何本 MOD 訊息，Lua 未執行。

改成單一 `proficiency_multiplier.ssmod` 後，Console 才出現：

```text
[ProficiencyMultiplier] Applied x100.000 to 58 weapons
```

同一工作坊項目由散檔切換成 `.ssmod` 時，既有 `modlist.txt` 曾殘留 `.ext`；在 MOD 管理停用再啟用後才更新。這是通用封裝規則的原始實測證據之一。

## 異常小封包事故

三個 Lua 曾錯放在 `src` 根目錄。工具仍產生約 759 bytes 的 `.ssmod`，但反解後只有清單、沒有 Lua。此專案的正式來源必須是：

```text
src/
├─ proficiency_multiplier.ext
└─ data/
   ├─ 00_ProficiencyMultiplierConfig.lua
   ├─ ProficiencyMultiplier.lua
   └─ ProficiencyMultiplierUI.lua
```

## `SysInit[4]` 專案例外

本 MOD 的 Lua 早於 `Save/setting_v2.lua` 載入，不能在檔案頂層讀取上次倍率。原始腳本已建立連續 `SysInit[1..3]`，因此本 MOD 固定使用 `[4]`，等設定載入後再套用倍率。

這不是新 MOD 的通用範本；一般事件掛接仍依 [Lua 事件與相容性](../docs/knowledge/lua-events-and-compatibility.md) 使用連續追加。

## 點擊穿透風險

倍率面板依賴 `OnEvent.InputClick`，而公開事件沒有已確認的 consume 契約。發布前必須在物品、裝備、技能、煉化與系統頁逐一點擊八個倍率節點，確認不會同時操作底層選單。詳見 [UI、輸入與原生選單](../docs/knowledge/ui-input-and-native-menu.md)。
