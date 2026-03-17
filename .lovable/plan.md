

## อัปเดต plan.md — รวมงานค้างทั้งหมดเพื่อทำทีเดียว

### งานที่จะเพิ่มเข้า plan.md

**งานที่ 1 (มีอยู่แล้ว):** Jutlameasu EA — Squeeze Filter (เสร็จแล้ว ✅)

**งานที่ 2:** Gold Miner SQ EA — Directional Squeeze Block
- เพิ่ม `InpSqueeze_DirectionalBlock` input (bool)
- เพิ่ม `g_squeezeBuyBlocked` / `g_squeezeSellBlocked` globals
- เพิ่ม `direction` field ใน SqueezeState struct (Close vs EMA → 1=Bull, -1=Bear)
- แก้ OnTick squeeze check: ถ้า directional on → block เฉพาะฝั่งสวนเทรนด์
- แทรก `!g_squeezeBuyBlocked` / `!g_squeezeSellBlocked` ในทุก entry point (SMA, Instant, ZigZag + Grid)
- อัปเดต Dashboard แสดง BUY BLOCKED / SELL BLOCKED / OK
- **Version bump: v4.0 → v4.1**

**งานที่ 3:** เพิ่มกฎ Version Bumping ใน `.lovable/rules.md`
- เพิ่มหัวข้อ #6: ทุกครั้งที่แก้ไข EA ต้องเพิ่ม minor version
- อัปเดตทุกจุด: `#property version`, `#property description`, header comment, Dashboard

### ไฟล์ที่จะแก้ไข
1. `.lovable/plan.md` — เขียนใหม่รวมงานทั้ง 3
2. `.lovable/rules.md` — เพิ่มกฎ #6 Version Bumping
3. `public/docs/mql5/Gold_Miner_EA.mq5` — Directional Squeeze Block + version bump to v4.1

### สิ่งที่ไม่เปลี่ยนแปลงใน Gold Miner
- Order Execution Logic (OpenOrder, CheckGridLoss, CheckGridProfit)
- Trading Strategy Logic (SMA/ZigZag/Instant signals, Grid calculations, TP/SL/Trailing)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Matching Close / Accumulate / Drawdown logic
- เมื่อ `InpSqueeze_DirectionalBlock = false` → behavior เหมือนเดิม 100%

