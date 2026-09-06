# 護駕戰鬥抗性直接副本探針

> 歷史實驗：本頁保存所列版本的操作與證據。是否重用、知識去向及未解問題，先查[研究清冊](../../README.md)；通用能力依[知識庫](../../../docs/knowledge/README.md)，不因歸檔或 mock 通過擴張為正式支援。

## 目的

驗證 Steam HD 4.0.5 能否在 `Battle_PlayerInit` 後，直接讀寫 `BattlePlayers[index].CharData.AttrPoison`，使已裝備靜態契靈的抗性進入當前戰鬥角色副本。這是獨立探針；不改 `ItemTemp`、不寫入 `SaveData`，也不屬於正式全魔物卡庫。

## 前置與操作

1. 啟用正式 `swd3_all_monster_static_capture.ssmod` 與本探針；停用舊的 `guardian_resistance_battle_probe.ssmod`。
2. 裝備任一靜態契靈，例如蚩尤 `10017`。
3. 按 `F6` 進入單隻原版食人花的毒屬性戰。探針只在這場戰鬥直接把賽特的 `CharData.AttrPoison` 設為 `-10`（100%）。
4. Console 預期出現 `direct copy write after Battle_PlayerInit`，且 `write=true`、`AttrPoison ... -> -10`。讓食人花打中賽特，結束戰鬥。
5. 保持同一張卡裝備，按 `F5` 進入基線戰；預期出現 `direct baseline observed`。F6 與 F5 的傷害差異才可歸因於戰鬥副本抗性。

## 安全與停止

- 每場僅暫改當次 `CharData`，在 `Battle_RestoreItem`、切圖與重開時嘗試精確還原。
- 若出現 `direct copy unavailable`、`write=false`、傷害無差異或任何異常，立即停用此探針並完整重啟；不要整合到正式 MOD。

## 證據狀態

- **已否決路徑**：戰前暫改 `GameData.ItemTemp[玩家ID].Attr*` 即使 Console 顯示 `-10`，仍未在食人花毒傷測試中顯示可用效果。
- **已否決路徑**（Steam HD 4.0.5，2026-09-04）：`BattlePlayers[1].CharData` 是 userdata；於 `Battle_PlayerInit` 後寫入 `AttrPoison` 回報 `no member named 'AttrPoison'`。該抗性成員未被公開 Lua binding 暴露，不能成為護駕實作。
