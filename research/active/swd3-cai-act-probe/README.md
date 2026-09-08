# 蔡魔王紅衣動作探針

2026-09-08：此測試模組保留於工作區，不發佈 Steam、不包含在正式模組封包。本次來源語法檢查通過；未重跑已通過的動作實機案例。

目前版本：**v0.2（DAT1），2026-09-06；基本動作已由使用者人工通過。** 首輪 v0.1（Lua ACTData）未取得進戰證據，不能與 v0.2 混稱。後續三招技能與生命週期由[完整版驗收](../../../swd3-cai-demon-king-mod/TESTING.md)承接，探針保留可重跑來源，不與完整版同開。

## v0.2 人工結果（2026-09-06）

**已實測：使用者回報＋部分 Console。** 使用者按明列測試步驟回覆「全部正常通過」，範圍為紅衣外觀、進場、普攻命中後回待機、受擊無錯圖／卡住、擊敗後返回地圖、再次挑戰。HP2000，只配置普攻；施法、治療、卡圖、全滅、護駕與保存未測。

[保存的 Console](evidence/20260906/user-test-v02-console.log)：第29行識別 `v0.2 DAT1 loaded`，第55行開戰，第61行 `entered; DAT1 ACT438`，第133行蔡魔王死亡，第137行戰後清理。日誌僅保存一場；重複開戰依使用者回報，沒有完整多場 trace 或截圖。Console 中全魔物靈契已載入，末段顯示我方 Lv59／敵方 Lv70，不是原版來源 Lv99 的平衡驗收。其他 MOD 的實際作用不由啟用清單推定。

- 安裝探針 SHA-256：`4D91EE101918A37CADAEF6FC320599FBCC1B6E0CB8CF5CAD2F6C1400537DDD7D`，與已封裝反解的 v0.2 產物相同。
- `CaiDemonActions.ext` SHA-256：`3ADA49D73CABB639A780914F613E96C23A2068073E324930517214788C82B766`，與完整版候選來源相同。
- `script_index.ssmod`：`9995B9A1327700B9ED8F642D091BCEA40129EC2F9DDFF03220A4DF1691DB85BF`。
- `swd3.exe` 4.0.5.0：`63F1D83D8C3A756D17640D9022E19F8928741B091F0E47ABBDB22C0CCF6C9523`。

## 實作與重跑

[動作宣告來源](../../../swd3-cai-demon-king-mod/src/data/CaiDemonActions.ext)使用原版 ACT2198 的紅衣劍俠圖像，以 DAT1 載入獨立 ACT438；只引用既有 TSW2290／2291／2300／4779。未新增 TSW、未覆寫原版 ACT2198、未改核心封包。建置腳本只複製此共享來源至 `.work`，不另維護可編輯副本。

由工作區執行 `./research/active/swd3-cai-act-probe/Build.ps1 -GameRoot <game-root>`。工具命令規格依[工具索引](../../../docs/knowledge/tools-and-commands.md)，封裝後比對來源與反解，輸出留在獨立建置目錄。原 v0.2 來源包含輸入診斷，可能較多 log，不應作正式版啟用。

重跑時啟用此探針並保留測試存檔必要卡庫，停用完整版及其他戰鬥探針，完整重啟、物品欄手動按 Insert。不要存檔。按[完整版 TESTING](../../../swd3-cai-demon-king-mod/TESTING.md#已通過的動作基線)描述的首輪範圍驗收；完成後停用探針、還原原啟用清單並重啟。

## Lua ACTData 路線與靜態線索

v0.1 曾依原版 ACT_Append.lua 建立 ACTData438，僅確認載入、未取得進戰結果。候選程式保存在[歷史來源](evidence/20260906/CaiDemonActions-lua-candidate.lua)，不包進 v0.2。

**已靜態反解，限前述 exe hash。** [報告](evidence/20260906/actdata.txt)由 [ReportCaiActData.py](tools/ghidra/ReportCaiActData.py)在 Ghidra11.4.3、JDK21、既有 NativeEvents 副本專案以 `-process swd3.exe -noanalysis -readOnly` 產生；重跑方式依[引擎研究工具](../../../docs/knowledge/tools-and-commands.md#從事件參照追到函式並重跑報告)。真正 ACTData 字串參照為 `0x140100b05`，consumer 為 `0x140100a60`。報告中的 `0x1400ea870` 來自早期掃描器的 absolute-pointer 線索，不應標為已確認 ACTData consumer。

該 consumer 的反編譯型別／參數讀取有疑點，尚未完整核對指令或以最小案例重現，不宣稱 Lua ACTData 一定失效。v0.2 使用 DAT1 的成功也不能反證 Lua 路線失敗。

## 知識歸屬

DAT1 引用既有 TSW 補新 ACT 的有限實測例提取到[圖片知識](../../../docs/knowledge/graphics-and-tsw-assets.md#既有-tsw-的增量-act-宣告)。本專案的編號、具體動作、user-test 原始證據及 Lua 疑點留在此處。未驗證部分不提升為一般支援保證。
