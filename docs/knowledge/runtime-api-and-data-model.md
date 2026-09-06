# 執行期 API 與遊戲資料模型

## 適用範圍與證據

以下項目由 Steam HD 4.0.x 現有 MOD 與 mock／實機驗收取得；它們描述已觀察到的存取方式，不代表所有欄位、所有版本或所有情境都穩定可用。呼叫前先檢查 table／function 存在，可能失敗的呼叫以 `pcall` 保護。未知欄位先依[引擎研究流程](engine-research-workflow.md)建立唯讀探針。

## 物品範本與玩家背包

| 目標 | 已觀察入口 | 已觀察欄位／結果 | 安全原則 |
| --- | --- | --- | --- |
| 原版物品範本 | `GameData.ItemTemp[itemId]` | `Name`、`Level`、`IT_12`、`isBattleChar`、`ACT`、`Race`、`NotInBook` | 先確認 table 與 item 存在；除非依資料安全流程暫改，保持唯讀。 |
| 玩家背包槽位 | `SaveData.Items[slot]` | `ItemTempID`、`Count`、`Count_New`、`Stock` | 槽位與數量都可能不存在；不可假設 `ipairs` 外的鍵或欄位有效。 |
| 物品總數 | `Count + Count_New` | 現有活物規則以此計算持有數 | `Stock` 是已預留數，先扣除後才是可用數。 |
| 已在地化的物品名稱 | `Function.GetItemTemp(itemId, 'Name')` | 原版 helper 內部已呼叫 `StringDB` | 此呼叫以 `pcall` 保護；不要把成功結果再送進 `StringDB`。 |
| 玩家物品數 | `GameFunc.PlayerItemCount(itemId)` | 已用於判斷持有條件 | 回傳值與函式都要驗證；不得用它推定背包槽位。 |

### 原版查表 helper 的實作邊界

狀態：**官方檔內說明**，來源為 [Steam HD 4.0.5 腳本基線](engine-research-workflow.md#steam-hd-405-原版腳本基線)的 `Function_Repository.lua`，定位 `Function.GetItemTemp`／`Function.GetGameData`。原檔依[重建入口](tools-and-commands.md#原版腳本重建與資料匯出)取得；以下查表行為由原版實作支持，不以現有 MOD 的部分讀取結果代替所有欄位的實機驗收。

- `Function.GetItemTemp(itemId, key)` 先讀 `SaveData.ItemTemp[itemId][key]`，再退回 `GameData.ItemTemp[itemId][key]`。
- `key` 為 `Name`、`HelpText`、`InfoText` 或 `SutraName` 時，helper 會在內部呼叫 `StringDB`；其他欄位直接回傳值。
- 找不到欄位時回傳數字 `0`，不是 `nil`。呼叫端要同時驗證型別與內容。
- `Function.GetGameData(a[, b[, c]])` 同樣先查 `SaveData` 再查 `GameData`，只處理 1～3 層，找不到時回傳 `0`。原版實作直接索引中間 table，未知路徑仍應使用 `pcall`。
- 兩個 helper 都可能在 `GameData`／`SaveData` 尚未建立時主動拋錯，不能在檔案頂層假設可用。

名稱顯示的安全順序為：先以 `pcall(Function.GetItemTemp, itemId, 'Name')` 取得已在地化文字；失敗時才讀 `GameData.ItemTemp[itemId].Name` 的原始 key 並嘗試 `StringDB`，最後退回 ID。自訂 UI 字串仍使用自己的 StringDB 前綴，詳見[在地化與文字](localization-and-strings.md)。

### 原版物品欄位來源索引

`GameData.ItemTemp` 並非只由單一檔案建立。研究欄位時應同時搜尋 `GameData_ItemData.lua`、`GameData_WeaponData.lua`、`GameData_ArmorData.lua` 與 `GameData_BattleCharData.lua`：

| 類別 | 官方檔內已註解的代表欄位 |
| --- | --- |
| 共通識別與顯示 | `Name`、`HelpText`、`InfoText`、`ACT`、`Race`、`Level`、`Area` |
| 分類與使用 | `IT_01`～`IT_13`、`IT_28`～`IT_32`、`UsePlace`、`Consumption`、`Cons_*` |
| 裝備與能力 | `User_01`～`User_04`、`AddATK`、`AddDEF`、`AddSPD`、`AddDodge`、`AddSTR`、`AddStamina`、`AddWIS`、`AddFriend` |
| 戰鬥角色 | `isBattleChar`、`HP`、`ATK`、`DEF`、`SPD`、`WIS`、`Skills*`、`DropItems*`、`GainEXP`、`GainGold`、`EscapeRate` |
| 特殊與安全篩選 | `IT_06`、`IT_12`、`NotInBook`、`isUnique`、`discard`、`FN_*` |

**官方檔內說明，Steam HD 4.0.5。** `GameData_BattleCharData.lua` 將 `NotInBook` 註解為「不在神魔異事錄顯示」；`OnEvent_Obsolt.lua` 也會排除 `NotInBook=true` 的活物煉化候選。這只說明圖鑑與煉化篩選；它是否影響背包反白、護駕清單或其他 MOD 選單，必須逐項實測。

欄位出現在原版資料或註解中，只證明它是研究候選；缺省值、布林／數字表示、Save override 與可寫性仍需按實際功能驗證。特別是同名欄位可能在不同物品類別具有不同產品語意。

### 新增活物卡的原生註冊時點

**已實測方案，Steam HD 4.0.5，2026-09-03。** 目前可依賴的新增活物卡做法是在 MOD 的 Lua `DAT 2` **載入期**建立完整的 `GameData.ItemTemp[newId]`。實測成功限下列單卡反白案例；工作區不採用 `GameStart`、按鍵或戰後才新增 ID 的方式，這不等同已窮盡所有未知 native 註冊方法。

- 執行期新 ID 與 Lua cache 重建的反例見[索引快取實測結論](../../research/archive/swd3-item-registry-cache-probe/README.md#已實測結論)：物品可見／cache 命中不足以證明 native 反白安全。
- 載入期單卡反白的成功與未測範圍見[靜態註冊實測結論](../../research/archive/swd3-static-item-registry-probe/README.md#已實測結論)，重跑見其[實機步驟](../../research/archive/swd3-static-item-registry-probe/README.md#實機步驟)；收妖交換另有[靜態蛇卡實測結論](../../research/archive/swd3-static-capture-exchange-probe/README.md#已實測結論)證據。

因此正式 MOD 的做法是：以已驗收的原版活物卡作 UI／使用欄位樣板，在載入期建立靜態新 ID，再覆蓋對應怪物的戰鬥資料與自有 StringDB key。這是本版本對「新增活物卡」的唯一可依賴註冊時點；存檔、停用與護駕完整矩陣仍必須另外驗收。

## 查表名稱與原生物品異動

`GameData.Race[raceId]` 已在活物挑戰用來取得種族資料，再以其 `Name` 作為 `StringDB` key 顯示。這是可重用的「資料表 → 名稱 key → 在地化文字」模式；`Race` 的完整欄位與所有資料表種類仍待驗證，取值時需逐層檢查 table 與 key。

原版 `ItemsClass.lua` 提供下列寫入 helper；參數與回傳是**官方檔內說明**，不代表所有模式都已由 MOD 實機驗收：

原檔定位使用上述 4.0.5 基線的 `ItemClass.AddItem`／`ItemClass.DelItem`；不以本機檔案路徑作跨 clone 的證據連結。

| Helper | 原版註解／實作 |
| --- | --- |
| `ItemClass.AddItem(id, count, mode, isUnique)` | `mode`：0 一般、1 只對舊品、2 先把新品併入舊品再增減；回傳狀態與槽位，狀態註解為 `-2` 條件不符、`-1` 錯誤、`0` 正常、`1` 新增欄位、`2` 移除欄位。原版新增流程還會更新辨識度／成就資料。 |
| `ItemClass.DelItem(tabid, itemId, count, mode, linkStock)` | 先用槽位，槽位不存在或 ID 不符時可依正值 `itemId` 搜尋；`mode` 使用同一組 0／1／2 計數策略。`linkStock` 為真時同步扣 `Stock` 並下限歸零；找不到回 `-1`，整列移除時回原槽位，否則回 `0`。 |

若 MOD 必須移除引擎已新增的物品，現有活物挑戰實測使用 `ItemClass.DelItem(slot, itemId, count, 0)`，也就是省略第五個 `linkStock`。安全前提如下：

1. 在可能產生物品的原版流程前，按 item ID 保存基線總數。
2. callback 後再次計數；只有目前數量明確大於基線時，才尋找可移除槽位。
3. 驗證 `ItemClass.DelItem`、槽位、ID 與數量後才以 `pcall` 呼叫；找不到新增物品時不做事。
4. 不直接寫入 `Count` 或 `Count_New`，也不只憑 callback 的 mode／參數推定可以扣除。

這種「先量測原生副作用、再最小幅度補償」的模式適用於捕捉、獎勵與交易等流程；若功能不必補償，優先完全交給原版處理。涉及戰鬥事件時再讀[戰鬥與背包生命週期](battle-and-inventory-lifecycle.md)。

## 戰鬥中的角色資料

`BattlePlayers[1].CharData.Level` 已在煉化診斷 MOD 用來讀取戰鬥中主角等級。可定位的[專案功能](../../swd3-refinery-diagnostics-unlock-mod/README.md#功能)與[2026-09-01 mock 記錄](../../swd3-refinery-diagnostics-unlock-mod/TESTING.md#自動檢查)支持該用法與保存邏輯；此項未附獨立實機版號／完整 trace，不能標成完整角色 API 規格。其他角色、欄位或寫入需求仍須先建立探針。

**已否決，Steam HD 4.0.5，2026-09-04。** `BattlePlayers[1].CharData` 在 `Battle_PlayerInit` 後是 userdata，不是可任意擴充的 Lua table；直接寫 `AttrPoison` 會回報 `no member named 'AttrPoison'`。同次研究也確認在玩家初始化前暫改 `GameData.ItemTemp[玩家ID].AttrPoison=-10` 不會使食人花毒屬性傷害進入可用免傷。這否決了所測 `AttrPoison` 寫入與來源暫改方案，不代表全部未知抗性 API 永遠不存在。護駕 `Add*` 與卡片 `Attr*` 的區別及替代路徑反例見[來源抗性探針](../../research/archive/swd3-guardian-resistance-battle-probe/README.md)、[userdata 探針](../../research/archive/swd3-guardian-resistance-runtime-probe/README.md)。

### 敵方 `NPCData.Level` 不是只供靈契使用

**官方檔內說明，Steam HD 4.0.5，2026-09-04。** `BattleEnemys[index].NPCData.Level` 是戰鬥中存活的等級欄位，不可把它當成「只影響靈契」的安全代理值。原版 Lua 明確以它做下列判定：

- `Function.CheckObsolt` 用它計算靈契等級差與機率。
- `OnEvent.BattleCriticalHitRate.main` 用攻擊者與目標的戰鬥等級決定隨機基數；把敵人降成 Lv1 會令 Lv7 以上玩家對原本未低 6 級以上的目標，從 1/20 變為 1/10 的該 Lua 暴擊判定。
- `OnEvent.BattleEnemyEscapeRate.main` 用它選擇敵方逃跑亂數分母；玩家 Lv12 以上面對被降為 Lv1、且 `EscapeRate` 非 0 的敵人，會採 1/10 而不是原本依等級差可能採用的 1/20 或 1/40。
- `Function.CheckAllEnemyLV` 以它算敵方平均／最高等級，而全自動戰鬥會用平均敵等是否不低於玩家平均等級，決定優先術攻或普攻。

因此任何為收妖而暫降敵方戰鬥副本等級的 MOD，都已知會改變收妖以外的戰鬥判定；HP、ATK、DEF、SPD、WIS、技能與掉落即使未寫入，也不能據此宣稱「戰鬥平衡不變」。原生傷害、命中、回合與獎勵的 native 路徑是否也讀取此欄位，仍須以隔離實機測試確認。

**已實測，Steam HD 4.0.5，2026-09-04，BS36。** `BattleEnemys[index].NPCData` 在敵方初始化後為 `userdata`，但可唯讀取得 `Level`、`HP` 與 `MaxHP`；兩隻來源 `112` 的 `Level` 都是原始 Lv9。故不要用 `type(status) == 'table'` 作為「可以安全寫入」的判斷：它會跳過 HD 的真實戰鬥副本。

此案例的 userdata／Lv9 摘要見[時序探針 v0.3 BS36](../../research/active/swd3-capture-command-timing-probe/README.md#已知證據與邊界)，正式 MOD 的 table guard 反例見[卡庫案例記錄](../../swd3-all-monster-static-capture-mod/TESTING.md#證據狀態)；HP／MaxHP 的逐值原始 trace 未在該摘要保留，不據此建立其他欄位可寫契約。

**已實測的受限寫入，Steam HD 4.0.5，2026-09-04，隔離牛魔王戰。** `Battle_Enter` 時可對敵方 userdata 的 `NPCData.Level` 成功寫入：來源／地圖仍 Lv80 的牛魔王，其戰鬥副本由 Lv80 寫成 Lv46（主角 Lv35 +11），HP `15/100` 時原生 `CheckObsolt=100`，且使用者手動靈契成功。這只證明目前版本、該欄位及該進場時點的可寫性；正式使用仍必須保存原值，於所有已知離場路徑還原，並接受本節已列的暴擊、逃跑與 AI 等級副作用。它不證明其他 userdata 欄位、所有戰場或 native 傷害路徑可安全改寫。

來源為[卡庫證據狀態的高等收服隔離 v0.8 案例](../../swd3-all-monster-static-capture-mod/TESTING.md#證據狀態)，正式一般遭遇的待驗收另見[實機矩陣第 13 項](../../swd3-all-monster-static-capture-mod/TESTING.md#實機矩陣)；不以「正式 MOD v1.9 規則採用」推定該結果已覆蓋全部正式戰場。

### 敵方 live ItemType 旗標

**已靜態反解，Steam HD 4.0.5、exe SHA-256 `63F1D83D8C3A756D17640D9022E19F8928741B091F0E47ABBDB22C0CCF6C9523`。** HD 的 `NPCData` Lua registration 以名稱 `ItemType` 對應 native offset `0x8`；原生 Boss／劇情判定使用其中 bit `0x20`。資料表中的 `IT_06` 是來源 `GameData.ItemTemp` 的 Lua 欄位，**不是**戰鬥 userdata 的 `NPCData.IT_06` 屬性。研究或隔離探針若要暫時切換 Boss 語意，必須保存完整整數 `NPCData.ItemType`，僅加／清 `0x20`，保留其餘 bit 並以 readback 驗證後再繼續；不得對 userdata 虛構 `IT_06` 欄位。`ItemType` 在實際戰鬥各時點的可寫性仍須逐案 readback 實測，不能因 binding 名稱存在而外推為正式功能安全。

**已靜態反解＋隔離實測。** 同一 `ItemType` 的 `0x800` 對應靈契資格。Boss bit 同時是 native 攻擊／爆擊分支的輸入，暫清後曾出現妮可 9999 的 A/B 反例；不得宣稱只影響 UI，也不能據此推導所有武器完整傷害公式。完整旗標與傷害證據見[反解紀錄](../../research/active/swd3-native-menu-probe/NATIVE-CAPTURE-RESEARCH.md#已靜態反解it_06-bridge-與-9999-爆擊的關係)、[賽特窗口紀錄](../../research/active/swd3-seth-capture-window-probe/NATIVE-EVENT-AND-CAPTURE-FLOW.md)。如何選擇收妖方案見[原生靈契](native-capture-and-eligibility.md)。

## 安全讀取範例

```lua
local function safeItemName(itemId)
    if Function ~= nil and type(Function.GetItemTemp) == 'function' then
        local ok, text = pcall(Function.GetItemTemp, itemId, 'Name')
        if ok and type(text) == 'string' and text ~= '' then
            return text
        end
    end
    local item = GameData and GameData.ItemTemp and GameData.ItemTemp[itemId]
    local key = item and item.Name
    if type(key) == 'string' and type(StringDB) == 'function' then
        local ok, text = pcall(StringDB, key)
        if ok and type(text) == 'string' and text ~= '' then
            return text
        end
    end
    return tostring(itemId)
end
```

這個範例只示範防禦式讀取；不要把 fallback 當成資料完整或 API 支援的證明。

## 何時改讀其他文件

- 要暫改 `GameData` 或保存 MOD 自己的資料：讀[狀態保存與資料安全](state-persistence-and-safety.md)。
- 要用物品建立戰鬥、預留背包數量或接收戰鬥結束事件：讀[戰鬥與背包生命週期](battle-and-inventory-lifecycle.md)。
- 要發現未知資料表、欄位或函式：讀[引擎研究流程](engine-research-workflow.md)。
