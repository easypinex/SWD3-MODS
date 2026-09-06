# 原生事件、旗標與靈契流程整理

> 本頁保存隔離探針 v0.6 的條件與推論，末段「正式版若採用」是該輪研究語境。正式全魔物靈契後續 v2.0 已有採用及本機完成紀錄，請查[產品證據對照](../../../swd3-all-monster-static-capture-mod/TESTING.md#v20-驗收敘述的證據對照)；本頁的未解條件不因產品籠統確認而自動通過。

適用版本：Steam HD 4.0.5、`swd3.exe` SHA-256 `63F1D83D8C3A756D17640D9022E19F8928741B091F0E47ABBDB22C0CCF6C9523`。

這是反編譯結果與隔離實測的**解釋性偽碼**，不是遊戲原始碼。`FUN_...`、全域位址與結構欄位名稱是分析器／研究命名；任何 HD 更新都必須重新驗證。

## 1. 先分清三種東西

| 名稱 | 實際位置／性質 | 本研究中的意義 |
| --- | --- | --- |
| 來源資料 `GameData.ItemTemp[id]` | Lua table | 全魔物靈契在戰前 bridge 使用 `IT_12=true`、`IT_06=nil` 準備資格。 |
| 戰鬥副本 `BattleEnemys[i].NPCData` | native userdata | 真正讓原生 UI、action 6 與傷害流程讀取的敵方資料。 |
| `NPCData.ItemType` | userdata 可讀寫整數、native offset `0x8` | bit `0x20` 是 Boss；bit `0x800` 是可靈契資格。 |

因此 `NPCData.IT_06` 並不存在。Lua 中的 `IT_06` 是來源 table 欄位；進入戰鬥後要控制 live Boss 語意，唯一已驗證的操作是保存並修改 `NPCData.ItemType` 的 bit `0x20`。

接近 Lua 的安全 bit 操作如下：

```lua
local BOSS = 0x20

local function hasBoss(itemType)
    return math.floor(itemType / BOSS) % 2 == 1
end

local function setBoss(itemType, enabled)
    if hasBoss(itemType) == enabled then return itemType end
    return enabled and itemType + BOSS or itemType - BOSS
end

-- 必須先保存完整原值，且 write 後 readback。
local old = enemy.NPCData.ItemType
enemy.NPCData.ItemType = setBoss(old, false)
assert(enemy.NPCData.ItemType == setBoss(old, false))
```

這不是「只改 UI」。它會改變 native live target；所以一定會影響某些後續 native 分支。

## 2. action 6 的原生指令流程

`Const.AI_CATCH` 對應 action code `6`。已靜態反解的實際控制流可近似為：

```c
// 使用者在手動選單確認「靈契」目標時。
if (selected_command == 6 && selected_target_is_enemy) {
    if (!NPCROLE_CanObsolt(&BattleEnemys[target]))
        break;                         // 不入 queue；UI 拒絕此目標

    DAT_1401aa8f4 = 6;
    DAT_1401aa918[actor] = 6;          // private action queue
    submit_player_command(actor);
}

// 後續 battle state machine：after 與 executor 是不同 state branch。
if (DAT_1401ab44c != 0) {
    dispatch_lua("BattlePlayerAI_after", actor);
} else {
    execute_player_action(actor);      // switch (queue[actor]) { case 6: ... }
}
```

`DAT_1401aa918` 與 `DAT_1401aa8f4` 沒有註冊成 `_BattleEnv` 或 `BattlePlayers` 的 Lua property；`BattlePlayers[i].AI_Command` 也不是它。因此 Lua 不能精確得知「本次已排入 action 6」。

### 2.1 目標確認 gate

原生目標確認 helper（研究名 `FUN_14007a060`／`NPCROLE.CanObsolt`）在 queue 寫入**之前**讀 live target flag。其必要條件可近似為：

```c
bool NPCROLE_CanObsolt(NPCROLE *target) {
    uint32_t flags = target->ItemType;

    if ((flags & 0x20) != 0) return false;    // Boss = true：拒絕
    if ((flags & 0x800) == 0) return false;   // capture eligibility = false：拒絕
    if (target->capture_class >= 0x16) return false;
    return true;
}
```

這已否決「進戰時暫清、UI 顯示完就恢復」的做法：使用者**確認目標的瞬間**必須仍是 non-Boss，不是只在戰鬥開始時 non-Boss。

### 2.2 原生收服 gate 與成功結算

action executor 的 case 6 進入另一個 native 收服 gate（研究入口 `0x1400752b0`）；它自行讀取玩家／敵方的 Level、HP、物品／種族資料與 native RNG，**不會**再呼叫公開 Lua `Function.CheckObsolt`。

目前可安全寫成的條件是：

```text
native action 6
  → native capture eligibility / level / HP / RNG branches
  → Battle_Dead(index=1, side=1, mode=2)       # 成功訊號，可出現兩次
  → native additem <source monster id>
  → AllMonsterStaticCapture 依背包基線交換成靜態卡
  → Battle_RestoreItem cleanup
```

已實測：玩家 Lv59、牛魔王戰鬥副本先被正式 bridge 封至 Lv70（`player + 11`）、HP `15/100` 時，Lua 查詢 `CheckObsolt=100`；但這不能提升為「完整 native 成功率公式」，因為手動 action 6 的真正擲骰是 native 路徑。完整機率代數、RNG 端點與所有等級／HP 分支仍待專門反解與多次樣本驗證。

## 3. 公開事件實際表示的階段

```text
I. 建立戰鬥
   Battle_EnemyInit / Battle_PlayerInit → Battle_Enter

II. 選擇指令（可能先收集多名玩家）
   InputKeyDown / InputKeyUp / InputClick
   Battle_InputKeyDown
   _BattleEnv.NowMenu = 1（一般指令）或 3（目標確認）
   └─ action 6 target gate → private queue write

III. 執行已提交動作（原生 state machine；可交錯）
   BattlePlayerAI_after(index) → later executor branch
   BattleCriticalHitRate(...)  # 只在條件式計算線；防禦也可能出現
   Battle_Dead(...)            # 僅死亡／收服等結果，不是一般命中

IV. 戰後
   native item add → Battle_RestoreItem
```

事件不是「回合 API」：玩家可能先後完成賽特 UI、妮可 UI，之後才交錯執行行動。`BattlePlayerAI_after` 表示命令已提交後的 state callback，**不是**傷害結算，也不是「同一角色立刻要攻擊」的保證。

| callback | 本研究可用的意思 | 不能拿來推定的事 |
| --- | --- | --- |
| `InputKeyDown`／`InputKeyUp`／`InputClick` | 已實測會在 `NowMenu=1/3` 命令／選目標階段出現。 | 它不告訴 Lua command 是否為 6、目標是誰、命令是否已提交。 |
| `Battle_InputKeyDown` | 戰鬥 input dispatch，成功 action 6 的 `NowMenu=3` 亦已觀察。 | 不是每種輸入裝置／每次 UI 操作都保證呼叫。 |
| `BattlePlayerAI_after(index)` | 已提交玩家的 callback；可辨識賽特或妮可。 | 不是傷害完成；不能讀到 private action queue。 |
| `BattleCriticalHitRate` | 標準攻擊計算線的條件式 callback。 | 防禦會有 self target callback，不能當成普攻／傷害已發生的唯一證據。 |
| `Battle_Dead(mode=2)` | 原生收服成功後的可靠候選信號。 | 不是指令確認事件，且單次收服可重複兩次。 |
| `Battle_RestoreItem` | 戰後清理邊界。 | 尚未證明所有逃跑／腳本中斷的完整共通順序。 |

## 4. 為何 v0.6 的窗口能工作

這是「只有賽特能靈契」前提下的條件式設計，不是 action 6 generic hook：

```lua
-- I：只覆蓋第一個選單尚未收到輸入的空窗。
OnEvent.Battle_Enter:        setBoss(target, false)

-- II：不管目前是哪位玩家；現在不需要辨識 action 6。
if _BattleEnv.NowMenu == 1 or _BattleEnv.NowMenu == 3 then
    on_input:                setBoss(target, false)
end

-- III：只用 actor 身分決定後續 live flag。
OnEvent.BattlePlayerAI_after(index):
    if index == SETH_INDEX then
        setBoss(target, false)  -- action 6 仍可讀 non-Boss
    else
        setBoss(target, true)   -- 妮可 executor 前恢復 Boss
    end
```

2026-09-06 F3 已實測 trace：

```text
妮可 after                    → ItemType 2080（Boss ON）
下一輪賽特 input NowMenu=1    → ItemType 2048（Boss OFF）
賽特選靈契，input NowMenu=3  → ItemType 2048（仍 OFF）
妮可 after                    → ItemType 2080（ON）
賽特 after                    → ItemType 2048（OFF）
native action 6               → Battle_Dead(mode=2) ×2
native additem 59             → bridge exchange 59 → 10024
Battle_RestoreItem            → 還原 ItemType 與 F3 暫改來源資料
```

對照 v0.5：它在**每一個** after 都設 Boss ON；賽特 after 後收服沒有完成。v0.6 的唯一差異是賽特 after 保持 OFF，隨即成功。這是很強的行為證據，支持 executor 在賽特 after 後仍需讀 non-Boss，但不是把未命名 native helper 的完整所有分支都反編譯出來。

## 5. 9999 與傷害：已知與未知

已實測的因果鏈只有：全程把 Boss bit 清除時，妮可對牛魔王的爆擊出現 `9999`；在妮可 `BattlePlayerAI_after` 前／當下把 Boss bit 恢復 ON 的隔離測試中，妮可爆擊不再是 `9999`。故 `ItemType & 0x20` 是妮可高傷害分支的實際輸入之一。

但下列**尚未反解完成**，不能杜撰為公式：

```text
NicoleDamage = ?
criticalMultiplier = ?
9999 = 哪一個 native cap / special branch 的精確運算結果？
```

也就是說，目前修正的是「讓妮可 executor 前重新讀到 Boss」，不是以 Lua 覆寫傷害、壓制爆擊或硬夾傷害上限。v0.6 成功場的妮可只防禦；仍須獨立測「妮可普攻／爆擊，Console 顯示妮可 after 已 ON，畫面不是 9999」。

## 6. 可移植與不可移植的部分

| 項目 | 狀態 |
| --- | --- |
| `ItemType` bit `0x20`／`0x800` 的 live 讀取與 action 6 UI gate | 已靜態反解；限上述 exe SHA。 |
| F3 牛魔王中 input-window + 賽特保留 OFF 的原生收服 | 已實測。 |
| 全魔物靈契的來源 bridge、Lv+11 battle cap、原生加物後換靜態卡 | 已實測，但等級 cap 有暴擊／逃跑／AI 副作用。 |
| 妮可普攻／爆擊、賽特所有非靈契行動、敵方行動 | 待驗證。 |
| 一般地圖的所有 Boss、取消、收服失敗、逃跑、讀檔／停用 | 待驗證。 |
| 私有 queue 的 Lua getter 或「只對 action 6 開窗」 | 目前不存在；純 `.ssmod` 不可取得。 |

正式版若採用，應把這個窗口嵌入全魔物靈契的既有 bridge，保留完整快照與 `Battle_RestoreItem`／`MapLoading`／`GameStart` 還原；在完成待驗證矩陣前不得宣稱所有 Boss 或所有傷害都已平衡。
