# 全魔物靜態收妖卡庫：驗證紀錄

## v2.0 驗收敘述的證據對照

2026-09-06 文件整理：本文件同時保存早期待測案例及較晚的「使用者已完成本機 v2.0 驗收」。後者保留為產品本機狀態；本次沒有重測、撤銷或擴張該驗收，也不改發布狀態。

| 證據 | 目前可支持的範圍 | 尚須對照的資料 |
| --- | --- | --- |
| v2.0 語法／mock／封裝反解紀錄 | 腳本及既列規則與成品一致 | 不代替遊戲 callback 或傷害驗收 |
| F3 v0.6 隔離牛魔王的 trace | 賽特第二輪收服、原生加物與卡片交換 | 成功場妮可防禦，不是該版普攻／爆擊回歸 |
| README 與本文件較晚的本機完成敘述 | 使用者確認 v2.0 正常可用的產品紀錄 | 未逐一配對 Boss、武器、角色、操作與完整 Console，不能據此把矩陣每格提升為通用實測 |
| 舊版「10 筆來源缺資料」待測項 | v0.8 啟動整合已補齊來源，舊缺資料狀態已被取代 | Race 0 代表實際捕捉仍依第 8 案例，不能以啟動 sources=193 代替 |
| Steam 訂閱下載版 | 既有文件仍列公開前驗收 | 維持原發布清單，不由本次知識整理判定完成 |

下列實機矩陣中的操作及失敗處置是版本化驗收規格；只有帶實際結果的列才是該案例證據。舊「待驗證」敘述需按此表及日期閱讀，不能推翻較晚產品確認，也不能被其籠統覆蓋。

## 自動檢查

| 檢查 | 狀態 |
| --- | --- |
| 原版審計表：193 映射、96 identity、97 新靜態卡 | 通過 |
| 自製護駕規格表：97 列、卡片 ID 唯一、九維加成組合全不重複、原型主題／設計說明完整 | 通過 |
| 每個來源與卡片 ID 唯一 | 通過 |
| Lua 語法與 mock：97 張卡於載入期建立 | 通過 |
| mock：蛇 `102 → 10042` 的基線保護交換 | 通過 |
| mock：97 張新增靜態卡帶有 `NotInBook=true` | 通過 |
| mock：自動資格 bridge、`Battle_Enter` 對已 bridge 高等戰鬥副本封頂為第一位主角 +11、HP ≤25% 的原生 100% 分支、戰後等級還原、重複 callback 去重、交換、切圖還原與下一戰重啟 | 通過（v1.9） |
| mock：跳過來源會記錄 ID 與缺少的 `ItemTemp`／`Race` 原因 | 通過 |
| mock：runtime 缺少來源 `Race` 時，依審核目錄暫補；原版 `Race[0]` 只在 bridge 期間補建，切圖後兩者移除 | 通過 |
| mock：原始 Boss 目標的 live `ItemType` 窗口：命令輸入／賽特 after OFF、非賽特 after ON、目標確認再 OFF、戰後還原完整 snapshot | 通過（v2.0） |
| 封裝反解與 SHA-256 | 通過（v1.6：`BC13F44E932DF272FD4973ABD2A0234C9DFBC87E7072ACF9C62683DCF78E40A5`） |

## 實機矩陣

| 編號 | 操作 | 成功證據 | 失敗處置 |
| ---: | --- | --- | --- |
| 1 | 僅啟用本 MOD，完整重啟 | **通過**：Console 顯示 `mappings=193, static=97, failures=0, itemCache=97, raceCache=97`。 | 不存檔、不發卡。 |
| 2 | 靜態蚩尤卡 `10017` 存到第 1 格，完整重啟、讀檔、物品欄反白 | **通過，2026-09-03**：卡片仍在且反白正常。 | 保留卡庫啟用。 |
| 3 | 停用卡庫與首領探針後讀取同一份含 `10017` 的存檔 | **受限通過，2026-09-03**：可進地圖，但 `10017` 暫時消失。未保存；重新啟用並重讀原檔後卡片恢復且可反白。 | **禁止在此狀態保存**；持卡存檔不支援停用卡庫。 |
| 4 | v0.4：一般遭遇中收服一隻原先非活物目標 | 異事錄／怪物資訊顯示原始等級；Console 顯示 `capture bridge armed`、原生新增來源、`capture exchange confirmed`；映射卡可反白。 | 不保存，回報完整 Console。 |
| 5 | v0.4：高等／劇情首領代表案例 | 來源資料在地圖仍是原等級；以獨立存檔收服，映射卡可反白。 | 任一項失敗即停用 v0.4、不保存。 |
| 6 | v0.5：靜態契靈圖鑑排除 | **通過，2026-09-03**：使用者確認神魔異事錄不再列出新增靜態卡。 | 若後續版本仍列出，勿保存，回報畫面與 Console。 |
| 7 | v1.0：靜態契靈護駕回歸 | **通過，2026-09-03**：`NotInBook=true` 的靜態契靈留在背包、SP 足夠時，仍出現在戰鬥「物品 → 護駕」並成功召喚。 | 後續若個別卡未列出，保留卡片與 Console 紀錄再判定，不以裝備欄狀態誤判。 |
| 8 | v0.8：天神系代表收服 | **啟動整合通過，2026-09-03**：Console 顯示 `sources=193`、`races=16`、`sourceRaceFallbacks=10`、`createdRaces=0`、`skipped=0`。仍待遭遇任一 Race 0 目標後確認原生靈契成功且不重複發卡。 | 未完成實際收服前，不把 10 筆寫成完整實機支援。 |
| 9 | v1.3：靜態契靈裝備護駕加護與文字 | 裝備一張新靜態卡前後，比對角色面板九項能力；物品欄摘要須列實際加成，按 `N` 須保留原版長篇介紹。 | 九項能力已通過；文字分層待本次實機確認。 |
| 10 | v1.4：護駕強度與 SP 分級 | 分別檢視一張初階、熟練、菁英、首領與傳說首領卡的物品摘要；應依序顯示 10／30／90／160／280 SP，且強卡的九維數值明顯更高。 | 不影響既有收服交換；若摘要未更新，完整重啟後再驗。 |
| 11 | v1.5：個性印與差異門檻 | 檢視同原型的兩張卡；物品摘要應各自顯示不同的個性印，九維數值不應只差一、兩點。 | 自動檢查要求所有配對的九維總差距至少為 12。 |
| 12 | v1.6：手動專屬定位覆寫 | 檢視一張手動覆寫卡與一張既有唯一卡；摘要須顯示專屬稱號與個性印，規格表的 `specialization_mode` 分別為 `manual`／`generated`。 | 自動檢查要求 62 張覆寫精確覆蓋原先重複卡，且 97 個原型／個性印／傾向組合皆唯一。 |
| 13 | v1.9：高等目標原生收服與還原 | Steam HD 4.0.5，隔離牛魔王：主角 Lv35、來源 Lv80，`Battle_Enter` 戰鬥副本 Lv80 → Lv46；HP `15/100` 時 `CheckObsolt=100`，使用者手動靈契成功。來源／地圖等級維持 Lv80。 | 正式 MOD 安裝後，另以一個高於主角 11 級的一般遭遇或首領確認 Console 的 `battle level cap applied`、成功交換與離場後來源等級；未完成前不公開工作坊。 |
| 14 | v2.0：一般地圖 Boss 的原生靈契與妮可傷害窗口 | 以可丟棄存檔進入原版 Boss 戰；賽特用靈契、妮可選防禦，Console 應依序顯示 `Boss window ... OFF`、非賽特 after `ON`、賽特 after `OFF`、`Battle_Dead(mode=2)`、交換與 restore。另開一場讓妮可普攻／爆擊，傷害不得是 `9999`。 | 任一 UI 拒絕、收服失敗、`9999`、殘留 ItemType 或未還原，立即不存檔並停用 v2.0；保留完整 Console。 |

### 護駕清單前提

**已實測，Steam HD 4.0.5，2026-09-03。** 蚩尤卡 `10017` 留在背包時會出現在戰鬥「物品 → 護駕」清單；裝入護駕欄後，診斷記錄為 `bagTotal=0` 且位於 `PlayerEqu`，故不會列在由背包物品供應的原生召喚清單。賽特 SP 足夠 `200` 時，從該清單選擇蚩尤已成功召喚並正常使用；戰鬥結束後卡片仍在背包且可反白。先前以「已裝備但未列出」推測靜態 ID／`NotInBook`／ACT 橋接問題，前提不成立，**不形成這些假設的正反證據**。

## 證據狀態

- **已實測**：單張靜態 ID `9003` 可正常反白；原生蛇收妖可安全交換為靜態 ID `9004`。
- **已實測**（Steam HD 4.0.5，2026-09-03）：193 條映射與 97 張靜態卡同時在載入期註冊；原生 Lua 物品／種族快取各含 97 張，`failures=0`。
- **已實測**（Steam HD 4.0.5，2026-09-03）：靜態蚩尤卡 ID `10017` 已通過「收服交換 → 反白 → 存檔 → 完整重啟 → 讀檔反白」。
- **已實測**（Steam HD 4.0.5，2026-09-03）：`10017` 未裝備、仍在背包時可進入原生戰鬥護駕清單；裝備後不在背包，故不列出。
- **已實測**（Steam HD 4.0.5，2026-09-03）：賽特 SP 足夠 200 時，背包中的 `10017` 可由原生戰鬥護駕清單成功召喚並正常使用。
- **已實測**（Steam HD 4.0.5，2026-09-03）：上述戰鬥結束後 `10017` 仍在背包且可反白。
- **已實測**（Steam HD 4.0.5，2026-09-03）：第二個 Lv80 首領牛魔王來源 `59` 可在隔離戰中由原生靈契收服，並依基線交換為靜態卡 `10024`；來源資料戰後還原正常。
- **歷史 mock 限制**（Steam HD 4.0.5，2026-09-03）：v0.3 mock 用 Lua table 模擬敵方 `NPCData`，曾覆蓋到戰鬥等級 proxy；這不代表 HD 實機的 userdata 可安全寫入，不能作為正式行為證據。
- **已實測**（Steam HD 4.0.5，2026-09-03）：v0.3 在原生一般遭遇 BS41 中，野猴 `106` 可由靈契收服；原生新增來源後已交換為靜態卡 `10046`，bridge 在 `Battle_RestoreItem` 還原後立即重啟，且 `10046` 物品欄反白正常。
- **已實測**（Steam HD 4.0.5，2026-09-03）：v0.3 在正式鏈路驗證戰中自動處理 Lv80 牛魔王 `59`；原生新增來源後交換為 `10024`，bridge 先還原後重啟，驗證戰只還原其暫時的 HP／ATK／SPD／技能。`10024` 物品欄反白正常。
- **已實測產品結果**（Steam HD 4.0.5，2026-09-03）：v0.4 在低風險牛魔王驗證戰中完成原生收服與 `59 → 10024` 交換；使用者離場後確認異事錄／怪物資訊正常顯示原始等級。來源 `ItemTemp.Level` 未在地圖長駐為 1。
- **已實測，Steam HD 4.0.5，2026-09-04，BS36：** v1.6 runtime 觀察到 `BattleEnemys[index].NPCData` 為 userdata，兩隻來源 `112` 隱翅蟲維持原始 Lv9，且 `battleLevelOverrides=0`、未出現 `battle capture-level proxy applied`。故舊 `type(status) == 'table'` guard 沒有在 HD 實機改寫戰鬥等級；這不構成 userdata 可安全寫入的證據。
- **已否決路徑，Steam HD 4.0.5，2026-09-04，v1.8：** Lv35 對 Lv80 牛魔王、HP `15/100` 時，探針基線確認 `CheckObsolt=33` 且 UI 可選取；使用者隨後完成一次手動靈契，沒有第二次 `CheckObsolt` 呼叫。原生成功骰子不採用 wrapper，故不可用它實現固定 33% 或解除 native 等級限制。
- **已實測，Steam HD 4.0.5，2026-09-04，高等收服隔離驗證戰 v0.8：** 主角 Lv35、來源 Lv80 的牛魔王在 `Battle_Enter` 寫入戰鬥副本 Lv46（主角 +11）；來源與地圖的 Lv80 未改。HP `15/100` 時原生 `CheckObsolt=100`，使用者手動靈契成功。這是 v1.9 使用戰鬥副本封頂、原生結算的依據；它同時接受原版暴擊、逃跑、AI 等級判定改變的戰鬥內副作用。
- **已實測限制**（Steam HD 4.0.5，2026-09-03）：停用卡庫時，含 ID `10017` 的存檔可載入但卡片不顯示；未保存下重新啟用並讀取原存檔可恢復。停用狀態再保存的結果尚未測試，並列為禁止。
- **官方檔內說明**：193／96／97 的原版資料盤點與現有活物 SP 成本，來源見共用戰鬥資料集。
- **專案決策**：新卡採分級 +5%～18% HP／ATK／DEF、同級 SP 成本約低一成；契約級固定 200 SP。
- **待驗證**：97 張同時載入的 native cache、其他代表性卡的保存、其他卡的護駕 SP／戰後處理、10 筆缺少可修改 `ItemTemp + Race` 的目錄項，以及可安全停用／遷移的正式相容性。
- **已通過 mock、待實機**（Steam HD 4.0.5，2026-09-03）：v0.5 對每張新增靜態卡寫入 `NotInBook=true`。原版資料註解定義此欄位為「不在神魔異事錄顯示」；對背包反白與護駕召喚的實際影響分開驗收。
- **已實測**（Steam HD 4.0.5，2026-09-03）：v0.5 安裝並完整重啟後，使用者確認新增靜態契靈卡未出現在神魔異事錄。
- **已實測**（Steam HD 4.0.5，2026-09-03）：v1.0 中 `NotInBook=true` 的靜態契靈 `10017` 留在背包、SP 足夠時，仍在原生護駕清單可見並成功召喚；圖鑑排除不影響該原生流程。
- **已實測啟動整合**（Steam HD 4.0.5，2026-09-03）：v0.8 完整重啟後，Console 顯示 `sources=193`、`races=16`、`sourceRaceFallbacks=10`、`createdRaces=0`、`skipped=0`。這證明 10 筆原先缺少 `ItemTemp.Race` 的 Race 0 來源已進入 bridge；實際捕捉代表例仍待驗證。
- **已實測**（Steam HD 4.0.5，2026-09-03）：新靜態卡的 `AddHP`、`AddMP`、`AddSP`、`AddSTR`、`AddStamina`、`AddWIS`、`AddSPD`、`AddATK`、`AddDEF` 在護駕欄生效。
- **已否決路徑**（Steam HD 4.0.5，2026-09-04）：`ItemTemp[玩家ID].Attr*` 在玩家初始化前的暫時 bridge 對實戰毒傷無效；`BattlePlayers[index].CharData` 是 userdata，直接寫入 `AttrPoison` 回報 `no member named 'AttrPoison'`。故 v1.2 移除自訂靜態卡 `Attr*` 值，不將抗性寫成護駕能力。

## 封裝驗收

- **已通過靜態、mock、封裝與反解驗收，2026-09-06，v2.0。** 成品 `17,680` bytes、SHA-256：`6E0D15A866705297A25EC735CBB2535D460F2F0ABE984FDFE00362F67843B73A`；反解後 `AllMonsterStaticCatalogue.lua`、`AllMonsterStaticCapture.lua`、`AllMonsterCaptureRuntime.lua`、`AllMonsterStaticCapture.txt` 均與來源 SHA-256 一致。自動檢查涵蓋原始 Boss source 的 command-input OFF、賽特 after OFF、非賽特 after ON、目標確認再 OFF 與完整 ItemType snapshot 還原。F3 隔離收服為此窗口的先行實機證據；正式一般地圖 Boss 與妮可攻擊回歸仍待本版安裝後驗收。
- **已通過靜態、mock、封裝與反解驗收，2026-09-04，v1.9。** 成品 `16,794` bytes、SHA-256：`D17004ABE76AF3476CC65817F5190BBE4DC2FF0FAF775A0CA25F4917648DC005`；反解後 `AllMonsterStaticCatalogue.lua`、`AllMonsterStaticCapture.lua`、`AllMonsterCaptureRuntime.lua`、`AllMonsterStaticCapture.txt` 均與來源 SHA-256 一致。自動檢查涵蓋 bridge 範圍內敵方戰鬥副本封頂為第一位主角 +11、HP ≤25% 的原生 100% 分支與戰後等級還原。隔離實機已成功；正式一般遭遇回歸待本機安裝後執行。
- **已通過靜態／封裝驗收、實機否決高等收服宣稱，2026-09-04，v1.8 候選版。** 成品 `16,701` bytes、SHA-256：`74E0A00CAA7BB8163B269A4637236EB3AD5950AD2F21B1A5140FE6A366565878`；反解後 `AllMonsterStaticCatalogue.lua`、`AllMonsterStaticCapture.lua`、`AllMonsterCaptureRuntime.lua`、`AllMonsterStaticCapture.txt` 均與來源 SHA-256 一致。自動檢查確認 Lua 查詢在高出至少 12 級且 HP 為 15% 的已 bridge 目標回傳 33；實機追蹤確認手動原生靈契不再呼叫此函式，故 native 骰子不受控制。
- **已通過靜態／封裝驗收，2026-09-04，v1.7 候選版。** 成品 `15,797` bytes、SHA-256：`A6F96CF0C336AED2B4135173DD4A5B3CA3CF4244E3940F5648CAF3576AA8914D`；反解後 `AllMonsterStaticCatalogue.lua`、`AllMonsterStaticCapture.lua`、`AllMonsterCaptureRuntime.lua`、`AllMonsterStaticCapture.txt` 均與來源 SHA-256 一致。自動檢查確認 runtime 不再註冊 `Battle_EnemyInit`，不會寫入敵方戰鬥等級；尚待完整重啟後的實機資格／交換驗收。
- **已通過，2026-09-04，v1.6。** 成品 SHA-256：`BC13F44E932DF272FD4973ABD2A0234C9DFBC87E7072ACF9C62683DCF78E40A5`；反解後 `AllMonsterStaticCatalogue.lua`、`AllMonsterStaticCapture.lua`、`AllMonsterCaptureRuntime.lua`、`AllMonsterStaticCapture.txt` 均與來源 SHA-256 一致。完整自動檢查通過：62 張手動專屬定位精確覆蓋原先重複的卡片、35 張仍為自動唯一設計；97 個原型／個性印／傾向組合、九維向量與護駕稱號皆唯一，且強度階級、SP 成本與最小九維差距維持既有規則。

## Steam 工作坊素材驗收

- **已完成候選發布素材，2026-09-06，v2.0。** `release/steam-workshop/workshop_content` 僅含 `swd3_all_monster_static_capture.ssmod`，大小 `17,680` bytes、SHA-256 `6E0D15A866705297A25EC735CBB2535D460F2F0ABE984FDFE00362F67843B73A`，與已反解驗證的 `build/package-20260906-v20-boss-window` 成品一致。繁中 BBCode 與更新說明記載：原生 Boss 靈契 UI／action 6 的 live Boss bit 窗口、非賽特行動前恢復 Boss 分支，以及 v1.9 的高等目標封頂邊界。使用者已完成本機 v2.0 驗收；Steam 訂閱下載版仍須先設私人或僅限好友驗證。
- **已完成候選發布素材，2026-09-04，v1.9。** `release/steam-workshop/workshop_content` 僅含 `swd3_all_monster_static_capture.ssmod`，大小 `16,794` bytes、SHA-256 `D17004ABE76AF3476CC65817F5190BBE4DC2FF0FAF775A0CA25F4917648DC005`，與 `_build_v19_final` 已反解驗證成品一致。文案明確說明：戰鬥內封頂為第一位主角 +11、HP ≤25% 使用原生 100% 分支，以及暴擊／逃跑／AI 的等級副作用。訂閱下載版與一般遭遇回歸前不得公開。
- **已完成靜態發布素材，2026-09-04，v1.8 候選版。** `release/steam-workshop/workshop_content` 僅含 `swd3_all_monster_static_capture.ssmod`，大小 `16,682` bytes、SHA-256 `E9850B9D5256036813186928AB7B46490E386E19BA3396135EF49F6BEFDD5983`，與 `_build_v18_title` 已反解驗證成品一致。MOD 管理與工作坊標題均為「全魔物靈契」；繁中 BBCode 說明、更新說明與 v1.8 manifest 已明確載明「敵方高至少 12 級且 HP ≤15% 時固定 33%」及不改戰鬥等級的邊界；預覽圖沿用既有 1024 × 1024 JPEG。Steam 訂閱下載版與高等目標實機驗收尚未完成，公開發布受阻。
- **已完成，2026-09-04，v1.6。** [release/steam-workshop](release/steam-workshop/README.md) 的 `workshop_content` 只含 `swd3_all_monster_static_capture.ssmod`；其 `16,166` bytes 與 SHA-256 `BC13F44E932DF272FD4973ABD2A0234C9DFBC87E7072ACF9C62683DCF78E40A5` 均與 `dist` 成品一致。
- **已完成，2026-09-04，v1.6。** 主要預覽圖為原創、無文字、以收妖鼎與環繞護駕為主視覺的 `1024 × 1024` JPEG，`290,074` bytes，低於 1 MB；畫面已人工檢視。原始 PNG 與生成 prompt 僅保留於發布素材 `source`，不會上傳到工作坊內容。
- **待驗證。** 尚未經 `SWD3Works.exe` 上傳、Steam 取消訂閱／重新訂閱及下載版完整重啟驗收。依 [UPLOAD-CHECKLIST.md](release/steam-workshop/UPLOAD-CHECKLIST.md) 先設私人或僅限好友，通過後再公開。
- **已通過，2026-09-04，v1.5。** 成品 SHA-256：`5A1F1917DB25C3DAE2072F2C01F552AC23C73BB9BBC1F564271DB64B9ECDBFFB`；反解後 `AllMonsterStaticCatalogue.lua`、`AllMonsterStaticCapture.lua`、`AllMonsterCaptureRuntime.lua`、`AllMonsterStaticCapture.txt` 均與來源 SHA-256 一致。完整自動檢查通過：97 組九維加成與 97 個護駕稱號皆唯一；任兩張卡的九維總差距至少為 12；個性印只會依攻勢、守勢、術法或迅捷傾向選取；護駕階級與 SP 成本仍依序遞增（10／30／90／160／280）。
- **已通過，2026-09-04，v1.4。** 成品 SHA-256：`C7E4F59F6CEF23E6F89013D553EB5D86548E6630DF87879BFFEABF572365F7E0`；反解後 `AllMonsterStaticCatalogue.lua`、`AllMonsterStaticCapture.lua`、`AllMonsterCaptureRuntime.lua`、`AllMonsterStaticCapture.txt` 均與來源 SHA-256 一致。完整自動檢查通過：97 組九維加成與 97 個護駕稱號皆唯一，並強制初階／熟練／菁英／首領／傳說首領的加成總量與 SP 成本依序遞增（10／30／90／160／280）。
- **已通過，2026-09-04，v1.3。** 成品 SHA-256：`B6CAAC2781C4004DB4FF7CFF8086C3FA63026F88E057B5EDC6E135A4E5E93D0E`；反解後 `AllMonsterStaticCatalogue.lua`、`AllMonsterStaticCapture.lua`、`AllMonsterCaptureRuntime.lua`、`AllMonsterStaticCapture.txt` 均與來源 SHA-256 一致。完整自動檢查通過；規格表移除所有抗性欄位，並驗證 97 組九維加成向量全不重複。
- **已通過，2026-09-04，v1.2。** 成品 SHA-256：`ABF38AA6A8834AC04554C203C706EC9EFB16BFA0BB7A8F198B2187A0B01998BA`；反解後 `AllMonsterStaticCatalogue.lua`、`AllMonsterStaticCapture.lua`、`AllMonsterCaptureRuntime.lua`、`AllMonsterStaticCapture.txt` 均與來源 SHA-256 一致。完整自動檢查通過；97 張規格表抗性欄位全為 `0`，且 97 列皆標示護駕抗性不支援。
- **已通過，2026-09-03，v1.1。** 成品 SHA-256：`D2F60D64BF846E72BCEB266FD074245661228CDED50A6B7750ED523118357B43`；反解 manifest SHA-256：`307CFE48BF7C587E489FB75EE03882A0C79B668902098421DF611D9E875D4598`、catalogue SHA-256：`BBA52530C54741DC5EA9B975DF52B2AA2A668BC22B482DC4E09C95F7FACF7E1D`、installer SHA-256：`B60878343F7C0EB4F3B0DB35AF9095052F0306D201F7840486E4CB3918669DE7`、runtime SHA-256：`5239328309A297ECA198358631F51D480B0E23E3288BFFCE0D592A2D50FF0C3A`、文字 SHA-256：`79AFE1DB974E0AC353F541CD8F9C03C05F36836DA9415EE1A39CC8ECE486324D`，皆與來源一致。雷屬性採原版實際欄位 `AttrThunder`，並清除舊拼寫 `AttrTunder`。
- **已通過，2026-09-03，v1.0。** 成品 SHA-256：`BA591F8A2F24815919415966417A8086A9912B2D5B801518B8A2D85EBB628543`；反解 manifest SHA-256：`130F5A8C22770330A3BC4931ABC9CA8ED52871DB71F0EEEE18224E215F7ED329`、catalogue SHA-256：`BBA52530C54741DC5EA9B975DF52B2AA2A668BC22B482DC4E09C95F7FACF7E1D`、installer SHA-256：`00D6AEAB47CAAB49E7AACD8CE064B454362287899922B9CEBAFE839AFC334CB3`、runtime SHA-256：`5239328309A297ECA198358631F51D480B0E23E3288BFFCE0D592A2D50FF0C3A`，皆與來源一致。此版本只更新正式版本標記與驗收文件，不改變 runtime。
- **已通過，2026-09-03，v0.8。** 成品 SHA-256：`8FAE4364575F9529305EA769AB10547EE8AF67571A1FD418AA9B311F8BFE7437`；反解 manifest SHA-256：`CC5B9061B865048BB0D86049B9F80F09431B81A830A33D636A7E467CA1AEED7D`、catalogue SHA-256：`BBA52530C54741DC5EA9B975DF52B2AA2A668BC22B482DC4E09C95F7FACF7E1D`、installer SHA-256：`00D6AEAB47CAAB49E7AACD8CE064B454362287899922B9CEBAFE839AFC334CB3`、runtime SHA-256：`5239328309A297ECA198358631F51D480B0E23E3288BFFCE0D592A2D50FF0C3A`，皆與來源一致。
- **已通過，2026-09-03，v0.7（待啟動觀察）。** 成品 SHA-256：`68FBC0532D1E9E76F832BC6601DECEB823EBD501AD5E2DEBA7B537C7241C624F`；反解 manifest SHA-256：`F16948DAE5256B3FA87B7F676B565CDC29D67479E55B2ACEF14B0C11754B9EA8`、catalogue SHA-256：`8ABBC39F1256A4472C8A76412CAB5C502FD1ED801C47EC7DD6DCEB6E0763D99A`、installer SHA-256：`00D6AEAB47CAAB49E7AACD8CE064B454362287899922B9CEBAFE839AFC334CB3`、runtime SHA-256：`961BDBB233823F6E16DDAF942199A220D27BD8176901F6ACB2A3CFEDBB3E5A30`，皆與來源一致。
- **已通過，2026-09-03，v0.6（待啟動觀察）。** 成品 SHA-256：`416780CE57C1D4E3258AB111EA7D6C9E1A80C292906437503C92262B91774270`；反解 manifest SHA-256：`4A523A47EC0C89DD397D6F6E65F9A2E2AABB5EE531C5849B26B01DAD9FCADC64`、catalogue SHA-256：`8ABBC39F1256A4472C8A76412CAB5C502FD1ED801C47EC7DD6DCEB6E0763D99A`、installer SHA-256：`00D6AEAB47CAAB49E7AACD8CE064B454362287899922B9CEBAFE839AFC334CB3`、runtime SHA-256：`8B319C3EADCEC57D130AC866EED1F9F1EA56B7CCF983388CEE0523C0333069C6`，皆與來源一致。
- **已通過，2026-09-03，v0.5。** 成品 SHA-256：`218BF6BBDF3D721359E56488A591E48D55F04FB97D7F71E6743FDBBFA80AF7F6`；反解 manifest SHA-256：`A8D3D5D9B03974A9EBD9DCEE6589F1EFB675FCE20812B3A61FD846DC1B694185`、catalogue SHA-256：`8ABBC39F1256A4472C8A76412CAB5C502FD1ED801C47EC7DD6DCEB6E0763D99A`、installer SHA-256：`00D6AEAB47CAAB49E7AACD8CE064B454362287899922B9CEBAFE839AFC334CB3`、runtime SHA-256：`759A76EF54640B9EC171404310C74912BB3BE0D937C2E7AE04463E818B594A7E`，皆與來源一致。
- **已通過，2026-09-03，v0.4。** 成品 SHA-256：`9C5F06A1FF4173DCC0370680780A8C2A727140D9436954C3916E0AC954FCF03E`；反解 manifest SHA-256：`2F8235F1576F3FE33F8FB8A72E0C16367816BE03984029163E742219279E7F0B`、catalogue SHA-256：`8ABBC39F1256A4472C8A76412CAB5C502FD1ED801C47EC7DD6DCEB6E0763D99A`、installer SHA-256：`D252A9BA1ED2869BC5F4DA1F2DA36EADF8C58FC1E4C69C9ED35C09080C4BBDB4`、runtime SHA-256：`759A76EF54640B9EC171404310C74912BB3BE0D937C2E7AE04463E818B594A7E`，皆與來源一致。
- **已通過，2026-09-03，v0.3。** 成品 SHA-256：`91C947A839A5E4CF5C41024F0D709BE557D31F8576D88F123B61087B3A6E70E5`；反解 manifest SHA-256：`D1BC52C79E850F248E7D17189F6E58DC4554C44E604E8838CDE1A0D20C6992C2`、catalogue SHA-256：`8ABBC39F1256A4472C8A76412CAB5C502FD1ED801C47EC7DD6DCEB6E0763D99A`、installer SHA-256：`D252A9BA1ED2869BC5F4DA1F2DA36EADF8C58FC1E4C69C9ED35C09080C4BBDB4`、runtime SHA-256：`78B1D2951B2EFDBD1E15E776B2A88F55A356131118A3774CE40E61F9C5CEFE7B`，皆與來源一致。
