# 軒轅劍參 Steam 版：武器熟練度 100 倍 MOD

這個 MOD 會把武器熟練度成長速度提升至最高 **100 倍**。不會修改武器熟練後所增加的攻擊力數值。

Steam 工作坊版本採用單一 `.ssmod` 發布，預設為 100 倍。進入遊戲選單後，可在左下角的八段滑桿即時切換倍率，不必重新封裝或重新啟動遊戲。

## 遊戲內操作

- 打開遊戲選單，左下角會顯示倍率面板。
- 點擊滑桿節點切換倍率：`0.5、1、2、5、10、20、50、100`。
- 按 `F8` 隱藏或重新顯示面板。
- 倍率會全域保存，下次啟動會沿用；面板則會在每次啟動時重新顯示。

預設值與無效保存值的回復值都是 `100` 倍。倍率切換會立即從每把武器的原始熟練門檻重新計算，不會因為反覆切換而累積誤差。

門檻需要是整數，所以無法整除時會四捨五入，最低為 1。

因為遊戲可使用的熟練門檻最低為 1，原始門檻低於 100 的武器在設定 100 倍時會直接降至門檻 1，也就是命中一次即可達到門檻；這是該武器能表達的最快速度，但實際比例不一定恰好為 100 倍。

## 原理與相容性

遊戲把武器目前熟練值記在存檔的 `Familiar`，每把武器的熟練門檻則是 `ProficientHard`。本 MOD 在初始化及滑桿變更時，以「原始門檻 ÷ 倍率」計算新門檻，因此預設會讓熟練條與熟練完成速度最高達到原版的約一百倍。

只有帶有武器標記 `IT_09`、且具備有效 `ProficientHard` 的資料會被修改；`ProficientPoint`（熟練後攻擊力加成）不會改動。

MOD 設為不綁定存檔，可以停用後繼續使用原存檔。不過，若某把武器在高倍率下已達滿熟練，之後停用或降低倍率，該武器可能會依原始較高門檻顯示為尚未全滿；熟練值本身不會被本 MOD 主動刪除。

## 成品與安裝

`dist/proficiency_multiplier.ssmod` 是預設 100 倍、遊戲內可切換倍率的完成品；basename 固定為 `proficiency_multiplier`。共用的建置、反解、`modlist.txt` 與完整重啟步驟見 [封裝與安裝](../docs/knowledge/packaging-and-installation.md)。

本專案的成品雜湊、散檔事故、`SysInit[4]` 例外和點擊穿透風險見 [PACKAGING-NOTES.md](PACKAGING-NOTES.md)。

## Steam 工作坊

本專案的 `workshop_content` 只放 `proficiency_multiplier.ssmod`，刊登內容見 [workshop-description.md](workshop-description.md)。通用上傳、重新訂閱與公開門檻見 [Steam 工作坊發布](../docs/knowledge/steam-workshop-release.md)；本專案由散檔改成 `.ssmod` 的歷史證據見 [PACKAGING-NOTES.md](PACKAGING-NOTES.md)。

## 建議測試

先開啟 `Tools/SS2DConsole.exe`，再啟動遊戲。看到以下訊息即代表 MOD 腳本已載入並修改 58 把武器：

```text
[ProficiencyMultiplier] Applied x100.000 to 58 weapons
```

封印之劍的原始熟練門檻是 2800；在預設 100 倍下會降為 28。從熟練值 0 開始，以普通攻擊有效命中約 28 次即可達到熟練 100，可用來實戰確認。

切換倍率時，控制台會再次輸出套用訊息。例如選擇 20 倍：

```text
[ProficiencyMultiplier] Applied x20.000 to 58 weapons
```
