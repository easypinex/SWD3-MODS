# 活物挑戰 MOD：圖片方案研究紀錄

PNG、PIC、TSW、轉檔、來源／HD 圖庫及通用安全界線已集中到 [圖片與 TSW 資產](../../../docs/knowledge/graphics-and-tsw-assets.md)。原位置：`swd3-live-card-battle-mod/IMAGE-ASSET-GUIDE.md`。文中未帶連結的 assets／tsw-format-probe 等相對路徑仍指原 MOD 專案，不以本歷史目錄為基準。

本文件只保存活物挑戰的圖片方案歷史、失敗證據與後續驗證條件。

## 目前專案決策

v0.2 已改用 `ESC.Menu` 原生選單，不再使用 `DrawMenuAfter` 覆蓋式大面板，也不依賴自訂背景圖。正式 `live_card_battle.ssmod` 不包含或引用自訂 TSW ID。

可編輯候選素材仍保留在 `assets/`，格式探針保留在 `tsw-format-probe/`、`tsw-index-format-probe/` 與 `graphics_src/`；它們不是正式功能來源。

## 圖片轉檔探針

**已實測，2026-09-03：** 64×64 候選 PNG 能透過官方工具轉成帶 `tswp` 檔頭的 PIC，再回轉為 PNG。這只證明位元轉檔可行，不證明一般 Lua MOD 能登錄新 TSW ID。

格式結果：

| 路徑 | 觀察 |
| --- | --- |
| 24 位 RGB → `gp` → `pg` | 尺寸保留，顏色有量化。 |
| 32 位 ARGB → `gp` → `pg` | 測試區出現錯誤黃綠色，已否決。 |
| 32 位 ARGB → `gp2` | 色彩大致保留，但全部不透明。 |
| 32 位 ARGB → `gpa`／`pga` | 深色與半透明像素變化，不是保真 RGBA。 |

完整通用命令與使用規則不在此重複，見 graphics 知識文件。

## 自訂 TSW 登錄失敗證據

**已否決路徑：最小增量圖片包。** `graphics_src/live_card_battle_graphics.ext` 曾註冊 `TSW 20001/SN0`，圖像包先於主 Lua MOD 載入，但 `DrawFunc.DrawTSW(20001, 0, ...)` 沒有顯示圖片。

**已否決路徑：主 Lua 包加入帶檔名的 `MODpicture`。** 這個變體使面板文字與 `StringDB` 失效，因此未併入正式來源。

**已實測但不可發布：全量 TSW 重建。** 由 `swd3DVD/all_*.tsw` 重建的資源包能收錄新增圖片；但把全量重建包當作額外 MOD 載入，遊戲曾出現無畫面／無回應。未獲明確授權不得替換遊戲核心 `tsw_index.ssmod`。

以上只說明已測封包結構不可用，不能推論引擎永遠不支援自訂 PIC。

## 正式版可接受方案

- 使用 HD manifest 已存在且經用途驗證的原版 TSW ID/SN。
- 或維持原生 `ESC.Menu`，不使用圖片背景；目前 v0.2 採此方案。
- 不因視覺相似或來源圖庫編號相同，就把來源 ID 當作 HD ID。

## 未來重新開啟研究的最低驗收

1. 在隔離探針中由 `GetTSWSizeWH` 和 `DrawTSW` 成功讀取新增 ID。
2. 自訂圖像包與主 Lua 包分離時，載入順序明確且不影響 StringDB。
3. 封包能反解並逐檔比對，停用後遊戲可正常啟動。
4. 不替換核心資源，不影響其他 MOD 或原版 TSW ID。
5. 通過透明度、不同解析度、選單切換與完全重啟的實機驗收。
