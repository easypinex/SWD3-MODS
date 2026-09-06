# SWD3 引擎 UI API 診斷

> 研究來源：本頁保存所列版本的操作與證據。是否重用、知識去向及未解問題，先查[研究清冊](../../README.md)；通用能力依[知識庫](../../../docs/knowledge/README.md)，不因歸檔或 mock 通過擴張為正式支援。

這是唯讀研究模組。開始遊戲後，它會把 `ESC`、`GameFunc`、`DrawFunc`、`InputFunc`、`EditLayer`、`MenuFunc` 與 `package` 的已公開 Lua 欄位名稱輸出至 `SS2DConsole`。

它不會呼叫被列出的函式，不改動存檔、背包、地圖、戰鬥或按鍵。

研究探針的共用證據與安全規則見 [測試與驗證](../../../docs/knowledge/testing-and-verification.md)。列出名稱只形成 API 線索，不等於函式已可安全呼叫；尤其 `package.loadlib` 若存在，只能證實它可見，不能授權或證明可載入 DLL。

完成記錄後即可在 `Mods/modlist.txt` 設為 `0`。
