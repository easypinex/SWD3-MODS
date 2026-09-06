# 測試紀錄

## 自動檢查

- Lua 語法解析與 mock runtime。
- mock 驗證 F6 僅在全魔物靈契 bridge 已武裝時開始，目標在 `Battle_Enter` 後由主角 `+11` 還原為 Lv80。
- mock 驗證包裝的 `BattlePlayerAI_after.main` 在原版清除前讀取 `AI_Command=6`、玩家與敵方目標，`BSC.Obsolt(1,-1)` 只會在 `BSC.Run(1)` 返回後呼叫一次。
- mock 驗證來源臨時欄位在 `Battle_RestoreItem` 後完整還原。

## 實機驗收

**已實測，Steam HD 4.0.5，2026-09-04，v0.3：** 依 README 的 F6 → F7 → 一次手動靈契流程，Console 依序出現 `Battle_Enter restored target Level 70 -> 80`、`BSC.Run returned after armed handoff`、`native BSC.Obsolt completed in BattleScript coroutine: value=nil`、兩次 `Battle_Dead(mode=2)`、native `additem 59`、`capture exchange confirmed: source=59, card=10024` 與 `cleanup complete: Battle_RestoreItem`。沒有 yield 錯誤，整次未保存。

**已否決於此觀察點，Steam HD 4.0.5，2026-09-04，v0.4：** wrapper 與 `BSC.Run` 均正常執行，但沒有出現 `manual 靈契 observed before AI reset`；Console 顯示 `BattleCriticalHitRate` 後才是妮可、賽特的 `BattlePlayerAI after`，代表至少這輪已觀察到的是原生攻擊回合，而非可讀的靈契 AI 指令。v0.5 先唯讀輸出 wrapper 進入時的完整命令欄位；不把 v0.4 視為自動辨識成功。

**已否決自動辨識，Steam HD 4.0.5，2026-09-04，v0.5：** `BattlePlayerAI_after.main` wrapper 已安裝並在兩位角色回合進入，但快照是妮可 `command=0,target=2,enemySide=false,item=0,envTarget=nil`、賽特 `command=0,target=1,enemySide=true,item=0,envTarget=nil`。使用者確認未開啟自動戰鬥，故 `aiMode=1` 不可單獨解讀為自動模式；無論 UI 模式為何，這個公開 wrapper 沒有產出可安全識別手動靈契的指令或目標。與先前 `Battle_InputClick`、`Battle_CmdSelectOK`、`Function.CheckObsolt` 的否定結果合併後，沒有公開 Lua 時點可將一般手動靈契無縫轉交 `BSC.Obsolt`。

## 證據狀態

- **已實測、受限於隔離自訂 BattleScript，Steam HD 4.0.5，2026-09-04，v0.3：** 高等 Lv80 牛魔王的手動靈契後，`BSC.Run(1)` 返回；在 F7 預先武裝的條件下，同一 coroutine 的 `BSC.Obsolt(1,-1)` 成功收妖並完成正式卡交換。這證明接力可行，不證明一般戰鬥可自動辨識靈契命令或目標。
- **已否決的 v0.1 實機前置：** 探針把敵方誤讀為 `BattleEnemys[index]`，但本機 HD runtime 的正式 bridge 使用 `BattleEnv.enemys[index].self`／`.GUID`。因此 v0.1 在 `Battle_Enter` 拒絕目標，未實際呼叫 bridge；v0.2 改用相同的 runtime accessor 後才重測。
- **已否決的 v0.2 實機前置：** `BattleEnv.enemys[index].self` 與其 `NPCData` 均可讀，但型別是 `userdata`；v0.2 把它錯誤限制為 Lua `table`，故拒絕執行。v0.3 僅檢查物件存在，並仍限定來源 ID、隔離戰 ID 與一次性武裝狀態。

## 封裝驗收

- **已通過靜態、mock、封裝與實機否定驗收，2026-09-04，v0.5。** 成品 `4,281` bytes、SHA-256：`963DE162405551F3A955647CD180BA90C4937206EBB0749E2BA6476C892A283B`；反解 manifest 與 `ManualCaptureBridgeProbe.lua` 均與來源逐檔 SHA-256 一致。v0.3 的明確 F7 接力仍是已實測，v0.5 的自動指令辨識已否決；探針應停用。

- **已通過靜態、mock、封裝與實機驗收，2026-09-04，v0.3。** 成品 `3,612` bytes、SHA-256：`1FBC49C6E8373050D6644440063C282E3B36B037419C55064158E508936C9123`；反解 manifest 與 `ManualCaptureBridgeProbe.lua` 均與來源逐檔 SHA-256 一致。僅屬隔離研究，完成後應停用。

## Native 執行檔初步評估

**已實測唯讀靜態分析，Steam HD 4.0.5，2026-09-04。** `swd3.exe` 為 `2,227,712` bytes、SHA-256 `63F1D83D8C3A756D17640D9022E19F8928741B091F0E47ABBDB22C0CCF6C9523`。其 `.rdata` 可找到 `Obsolt`、`CanOBSOLT`、`CanObsolt`、`CalDamage`、`BattlePlayers`、`BattleEnemys` 與 `BattleScript` 名稱；其中 `Obsolt` 是原版 BattleScript 已使用且實機可呼叫的 `BSC` binding。

同版本以工作區 `FindLuaBindingXrefs.py` 分析 `Obsolt`、`CanOBSOLT`、`CanObsolt`、`DoAI`、`BattlePlayers`、`BattleScript`，皆沒有找到絕對指標或 `.text` RIP-relative 交叉參照。這只表示目前的輕量工具不能由字串反推出函式位址，**不**表示 native 函式不存在或不可逆向。

**評估結論：** 要在一般遭遇的手動靈契、原生等級門檻檢查或 native 收服失敗前無縫改呼叫 bridge，必須先以 debugger／反組譯器定位 C++ 指令解碼與收妖分支，再以 DLL 注入或記憶體 hook 改寫執行中流程。這不是 `.ssmod` 可承載的 Lua／DAT 功能，沒有已驗證的發行、版本相容、存檔安全或 Steam 工作坊分發路徑；在沒有明確的 native 擴充框架前，列為**不建議進入實作的高風險路徑**。
