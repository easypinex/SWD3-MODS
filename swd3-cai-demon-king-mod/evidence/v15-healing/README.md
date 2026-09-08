# v1.5 回血跳字調查

2026-09-08，使用者回報v1.4魔氣縱橫跳字僅1000，並明確澄清未核對實際HP。保留[當場Console](v14-user-console.txt)，可見選入11005；舊日誌未記錄精確回血前後HP，不能把1000當實際回復量。

## 靜態證據

Steam HD4.0.5.0、Ghidra11.4.3，精確指紋與腳本雜湊見[manifest](manifest.json)。兩支腳本只讀已隔離、SHA一致的資料庫，未附加遊戲或寫入exe。

- [native-healing](native-healing.txt)：`FUN_14008a370`結尾由RestorHP（actor+0x388c）產生負傷害；`FUN_140086e90`的NPC分支以HP減負傷害並限制至MaxHP，這兩段未把12000截為1000。這是指定函式的靜態結論，不能代替本場HP量測，狀態／中斷仍有其他分支。
- [native-display](native-display.txt)：`FUN_1400438b0`在BattleEnemyAI返回後由AI_SKILL=2呼叫`FUN_1400797a0`建立技能；後者不重設RestorHP。`FUN_1400851b0`把絕對值拆進四個short欄位，千位未取模，12000得到[12,0,0,0]。`FUN_140083170`以x-12、x、x+12、x+24繪製四欄；`FUN_14003be20`可繪製多位整數，因此首欄12與下一欄0共用原本一位數的間距，有重疊風險。此證據支持顯示失真，沒有把玩家看到的1000當作HP實際只加1000。
- 原有[效果事件解析報告](../../../research/active/swd3-native-menu-probe/evidence/boss-damage-20260908/formulas.txt)的`FUN_14004b660`：AT bit0／bit4都進效果計算，單體分支將每次結果累加到DAT_1401ab330並逐次送跳字。原版6079在PA58使用AT16；v1.5僅在PA48增加相同事件，維持60幀與既有TSW6040。ATK_Count原版註解為AI預測次數，不用它冒充實際命中事件。

## 決策與界線

v1.5同一次魔氣縱橫採兩段各6000，由原生效果與結算處理，設計總量12000；不以Lua直接補寫NPC的HP、不在下一次選招補差額。仍一場只排入一次、原有45%門檻與中斷規則。新的兩段實機顯示、總回血及中斷效果待人工，不稱為已實測。既有台詞不變。

重跑：依[工具流程](../../../docs/knowledge/tools-and-commands.md#從事件參照追到函式並重跑報告)，scriptPath用本專案tools，postScript依次為InspectNativeHealing.py、InspectNativeHealingDisplay.py；輸出到新的.work目錄，核對完整END標記與無反編譯失敗。通用跳字界線提取至[圖像文件](../../../docs/knowledge/graphics-and-tsw-assets.md#戰鬥跳字與實際數值)，本檔保留具體修法與人工界線。
