# 引擎研究流程

## 目的

未知 Lua API、資料欄位、封包行為或 UI 能力不得直接變成正式 MOD 依賴。本流程把線索、可重現證據與通用規則分開，避免將可執行檔字串或單次成功誤記成已支援 API。

## 證據取得順序

1. **原版 Lua／manifest**：優先以合法解包的原版 script index、原始 `.ext` 與資料表確認名稱、欄位與既有呼叫方式。
2. **唯讀執行期盤點**：以最小探針列印已存在的 table、function 或欄位；不呼叫未知函式、不寫入資料。
3. **隔離行為探針**：一次驗證一個假設，提供觸發、預期、停止與完整還原步驟。
4. **封包與產物驗證**：對檔案配置或格式，以封裝、反解及雜湊確認，而不是只看工具退出碼。
5. **可執行檔字串**：只能作為「下一個要研究什麼」的線索；不構成可呼叫 API 證據。

`script_index.ssmod` 是本機原版 Lua 研究的可能來源之一；它的位置、內容與授權範圍依安裝版本而異。解包一律在獨立工作目錄進行，不修改遊戲核心資源，工具操作讀[工具與命令參考](tools-and-commands.md)。

## 原生執行檔靜態反解

當原版 Lua 已說明「名稱或公式」，但仍無法回答「HD native 是否呼叫它、何時呼叫、是否另有 native gate」時，才進行靜態反解。它的目標是理解已安裝版本的控制流，不是修改、注入或繞過遊戲執行檔。

### 先判斷是否值得做

適合靜態反解的問題：

- public Lua event 是否真的被 native 呼叫、呼叫時有幾個引數；
- 手動 UI 指令在哪一個 native branch 分流，是否會經過已知 Lua callback；
- 某個 Lua bridge 是完整功能，還是只設定 native state；
- 原版 Lua 查詢函式是否只是預覽／AI 參考，而 native 行動另有資格 gate；
- 需要確認「不存在可用 Lua 插點」這類否定結論的範圍。

不適合把反解當成第一步的情況：已能由原版 Lua、資料表或安全唯讀探針直接回答；或問題其實是 UI 佈局、存檔副作用、控制器輸入等必須實機驗收的行為。靜態碼可證明編譯出的分支與呼叫，不會自動證明某個條件在每一場戰鬥都能到達。

### 安全邊界與版本指紋

1. 先記錄遊戲 exe 的檔案版本、大小與 SHA-256；沒有精確版本指紋，位址、結構偏移與結論都不可重用。
2. 從遊戲安裝目錄**複製** exe 到專案的 `native-analysis/input/` 或其他隔離研究資料夾；分析器、反編譯快取和輸出都不得寫回遊戲目錄。
3. 只開啟副本做分析。不要 patch、寫回、附加執行中的遊戲、掃描玩家記憶體，或把反解資料包進 `.ssmod`。
4. 記錄分析器版本與腳本；地址只寫成「限某 SHA-256」，不寫成跨 HD 更新的固定 API。

### 查特定 native 事件或函式的最短路徑

1. 已知事件／binding 名稱時，從[問題到腳本索引](tools-and-commands.md#依問題選擇反解腳本)選查詢入口；它明列哪些接受名稱、哪些只查固定清單或固定地址。查一般函式時，先由已知字串、註冊點或 caller 找入口地址，不能假設 native 保留了原始函式名。
2. 沒有本機工具時，讀[portable 前置工具](tools-and-commands.md#從全新-clone-準備-portable-工具)與[Python／唯讀範圍](tools-and-commands.md#python-執行環境與唯讀的範圍)；有工具但沒有資料庫時，直接按[首次匯入](tools-and-commands.md#首次匯入並保存事件報告)建立副本、指紋與完整分析。
3. 以 `Battle_InputClick` 為例：先取得名稱的 data refs，記下每個參照及 enclosing function，再取該函式偽碼。4.0.5 既有 UI caller 報告涵蓋輸入 dispatcher 與命令 UI，但仍須讀**實際呼叫點**的分支、dispatcher 實參及前後狀態，才可回答「何時呼叫、傳哪些值」；不是找到字串就完成。
4. 欲查的目標不在腳本清單時，依工具索引的擴充步驟建立另名研究腳本；沒有 enclosing function 或同名多地址時保留缺口並檢查指令，不把單一搜尋結果當窮舉。需要下游邏輯就繼續追 callee／資料流，直到足以支持指定問題。
5. 依[報告重跑與驗收](tools-and-commands.md#從事件參照追到函式並重跑報告)保存可定位證據，再使用下表區分已靜態確認與仍需實機驗證的條件。既有引擎結論先查對應知識主題；本節只維護研究方法。

### 由 Lua 線索縮小到 native 分支

先從解出的 HD `script_index.ssmod` 建立候選：事件字串、binding 名稱、原版常數、`OnEventValue` 欄位及資料表欄位。然後逐步收斂：

```text
原版 Lua 的名稱／常數
  → exe 內的字串或 Lua binding 註冊點
  → 對該字串的資料參照
  → 含該參照的 native 函式
  → 該函式的 callers／state machine 分支
  → 實際 gate、callback dispatcher 或 bridge 實作
  → 以唯讀探針驗證仍不確定的 runtime 條件
```

實務技巧：

- **先追呼叫者，不只找字串。** 字串存在只代表名稱被編進去；要找出引用該字串的指令，再找其所屬函式與 callers。
- **交叉比對已知語意。** 例如原版 `Const.AI_CATCH=6`、Lua 函式的等級門檻與 native switch case／比較式相符時，可建立可檢驗的對照；不可只因數字恰好相同就直接命名未知函式。
- **先記錄引數個數與 dispatcher 行為。** 反編譯呼叫點可看出 native 對 Lua event 傳入 0、1 或多個參數，也能看出 dispatcher 是否先呼叫 `.main` 再巡覽追加 handler。這比 Console 上「某次沒有印到」更能界定 callback 的能力。
- **用資料流追 gate。** 從 action code 追到它讀取的 Level、HP、物品旗標與亂數 helper，能判斷改 Lua 預覽函式是否會影響真正行動。
- **保留反例。** 若簡易反組譯工具顯示「0 xref」，只可說該工具的搜尋沒有命中。RIP-relative 資料參照、跳表、間接呼叫與分析器未識別函式都可能漏掉；須以完整 PE 分析器的 reference database 交叉確認，不能把工具侷限提升成引擎結論。

### 靜態與實機證據如何分工

| 問題 | 靜態反解可提供的證據 | 仍須唯讀／隔離實機驗證 |
| --- | --- | --- |
| Lua event | 某 native branch 是否呼叫 dispatcher、名稱、引數個數、前後的 state 更新。 | 特定戰場／裝置／輸入實際是否到達該 branch、handler 的 Console 順序。 |
| 原生命令 | command code、switch 分支、是否有 Lua callback、原生 gate 讀哪些欄位。 | UI 點擊、鍵盤與控制器在各解析度／戰況下選到的 command 與取消路徑。 |
| Lua bridge | binding 註冊、bridge 寫入的 native state、是否有 coroutine 需求線索。 | yield、動畫、結算、失敗、讀檔與中斷時的安全性。 |
| 機率／資格 | 編譯後的條件、常數、欄位讀取與 native 亂數呼叫。 | 亂數端點、未命名結構欄位的意義，以及完整成功／失敗分布。 |

因此結論應分層寫：**已靜態反解**描述某版本副本的程式碼事實；**已實測**描述可重跑的遊戲結果；兩者共同支持的部分才可成為正式 MOD 依賴。不要把 Ghidra 的自動命名、推測型別或一段 pseudocode 視為原始碼。

### 何時才需要除錯器

先完成靜態反解與唯讀 Lua 探針。只有以下問題仍阻斷設計時，才考慮對隔離副本／可丟棄存檔使用除錯器：需要觀察 live register／堆疊來還原間接呼叫、要區分多個相同 native branch 的 runtime path，或必須確認未命名欄位的即時值。除錯器不是「反解不夠時就一定要用」的下一步；它會提高版本脆弱性與測試成本，且不會讓 `.ssmod` 取得新的公開 Lua hook。

任何需要 exe patch、DLL 注入、記憶體改寫或附加常駐 debugger 的方案，都超出本工作區 `.ssmod` 的正式支援範圍；應明確停在研究結論，不將其包裝成可發布 MOD。

## Steam HD 4.0.5 MOD loader 與 native module 載入的界線

載入鏈及 native module 的能力界線統一見[封裝與安裝](packaging-and-installation.md#steam-hd-405-mod-loader-與-native-module-載入的界線)。只有需要重跑反解時才讀[loader 研究](../../research/active/swd3-native-loader-probe/README.md)。

## Steam HD 4.0.5 原版腳本基線

狀態：**已實測解包＋官方檔內說明**。本工作區以 `swd3.exe 4.0.5.0` 同目錄的 `script_index.ssmod` 建立下列可重現基線：

| 項目 | 已驗證值 |
| --- | --- |
| 檔案大小 | `2,029,941` bytes |
| SHA-256 | `9995B9A1327700B9ED8F642D091BCEA40129EC2F9DDFF03220A4DF1691DB85BF` |
| `SS2Dtool x` 輸出 | `out_data` 51 檔、`out_data_1`～`out_data_3` 各 4 檔 |
| `out_data` 類型 | 46 Lua、1 ext、4 文字表 |

這個雜湊只識別目前已測的 Steam HD 4.0.5 安裝內容；更新遊戲後必須重新記錄執行檔版本、archive 大小、SHA-256 與輸出盤點，不可沿用舊結論。完整解出檔與原版 archive 都是可由正版安裝重建的研究材料，不是 Git 編輯來源；應保留重跑方式、雜湊、檔案清單與結論，不提交整包原版內容。

### 研究問題的優先來源

| 問題 | 先讀的解出檔 | 能形成的證據 |
| --- | --- | --- |
| 事件名稱、callback 參數、共享回傳槽 | `OnEvent*.lua` | 原版 `.main` 定義與 `OnEventValue` 寫入線索 |
| 實體鍵與功能旗標 | `ScancodeDefine.lua`、`Setting.lua`、`OnEvent_Input.lua` | scancode 表、`DefineKeyFunc` 位元值、輸入 callback 形狀 |
| 物品查詢、背包異動 | `Function_Repository.lua`、`ItemsClass.lua` | helper 的查表優先序、參數、回傳與原版副作用 |
| 物品與戰鬥角色欄位 | `GameData_ItemData.lua`、`GameData_WeaponData.lua`、`GameData_ArmorData.lua`、`GameData_BattleCharData.lua` | 原版註解與資料實例；不等同所有 runtime 都可安全寫入 |
| Save／Setting 序列化 | `GameData_cFunction.lua` | 原版序列化器接受與略過的 Lua 型別 |
| 戰場與戰鬥事件 | `BattleField.lua`、`BattleArea.lua`、`OnEvent_Battle.lua`、`BattleScript.lua` | schema 註解、原版事件候選與既有呼叫方式 |
| 地圖、角色與場景 coroutine | `GameData_MapDetail.lua`、`GameData_Char.lua`、`SceneSetting.lua`、`Scene*.lua` | 欄位註解與原版場景呼叫範例 |

先以窄搜尋建立候選清單，再只讀命中的來源檔：

```powershell
rg -n 'function\s+OnEvent\.|OnEventValue\.' '<work-dir>\out_data' --glob '*.lua'
rg -n '^function\s+(Function|ItemClass|GameData)\.' '<work-dir>\out_data' --glob '*.lua'
rg -n 'GameData\.<target>|<field-name>' '<work-dir>\out_data' --glob '*.lua'
```

原版 Lua 中「有 table／函式定義」只提升為**官方檔內說明**；實際觸發時序、引擎是否巡覽追加 handler、參數型別及能否安全改寫，仍需唯讀盤點或隔離探針。

## 探針最小規格

- 一個探針只回答一個問題，例如「某函式是否存在」或「選單是否需要 coroutine」。
- 預設唯讀；若必須寫入，必須有快照、所有離開路徑還原、手動停止方式與明確 Console 訊息。
- 避免使用正式 MOD 已占用的快捷鍵、事件或全域名稱；先查[工作區相容性登記表](../compatibility-registry.md)。
- README 記錄遊戲／工具版本、前置狀態、操作步驟、可觀察結果、失敗結果與未測範圍。
- 成功後以全新啟動、不同存檔及必要的載入順序重測；UI 還要實測鍵鼠／控制器與輸入穿透。

## 提升為通用規則的門檻

只有同時符合以下條件，才可寫入 `docs/knowledge/`：

1. 可由另一位開發者重跑。
2. 保留版本與證據範圍。
3. 不依賴單一 MOD 的產品數值或劇情假設。
4. 已說明安全邊界與失敗時的退路。

不符合時，保留在探針或專案研究文件，標示為「待驗證」或「已否決路徑」。通用證據標記與測試要求見[測試與驗證](testing-and-verification.md)。
