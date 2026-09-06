# 煉化診斷 MOD：v1.5 成品紀錄

通用封裝、反解、安裝與發布流程見：

- [封裝與安裝](../docs/knowledge/packaging-and-installation.md)
- [測試與驗證](../docs/knowledge/testing-and-verification.md)
- [Steam 工作坊發布](../docs/knowledge/steam-workshop-release.md)

本文件只保存 `refinery_diagnostics_unlock` v1.5 的版本證據與發布限制。

## 正式來源與成品

```text
src/
├─ refinery_diagnostics_unlock.ext
└─ data/
   ├─ RefineryDiagnosticsUnlock.lua
   └─ RefineryDiagnosticsUnlock.txt
```

本機與 Steam 工作坊都使用單一 `refinery_diagnostics_unlock.ssmod`。

## 2026-09-01 v1.5 證據

- 大小：6,011 bytes
- SHA-256：`498DB24C022C33B802CE2BD34EAC12A6D5E113FD75304FE44CEDDF37D8C0AC83`
- 反向解包的 `.ext`、Lua 和文字表均與來源 SHA-256 相同。
- `dist` 與當時遊戲 `Mods` 安裝版 SHA-256 相同。
- v1.3 起使用 `TYPE 0` UTF-8 文字表、`StringDB` 與完整 ASCII fallback。
- v1.4 依有效的 `End`、`Q／左`、`E／右` 事件標示東西方結果。
- v1.5 移除偏移重疊的粗體模擬，改成單次繪製的黃橘色／淺黃色，避免中文字重影。

## 發布限制

完成鍵盤、滑鼠、控制器、動畫、唯一物品、背包滿載、Steam 統計／成就與選單殘留的遊戲內驗收前，只能視為本機測試版。專案案例見 [TESTING.md](TESTING.md)。
