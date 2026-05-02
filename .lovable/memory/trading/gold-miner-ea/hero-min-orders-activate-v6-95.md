---
name: Gold Miner EA v6.95 — Hero Min Orders to Activate
description: New input InpHero_MinOrdersToActivate (default 5) gates Hero formation so Hero only forms after side has >= N orders; Hero count clamped to n-1 to keep at least 1 non-Hero in basket; 0 falls back to v6.94
type: feature
---

# Gold Miner EA v6.95

ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

## เพิ่ม
Input ใหม่: `InpHero_MinOrdersToActivate` (default 5)
- > 0: Hero จะเริ่มกันออเดอร์เป็น Hero ก็ต่อเมื่อจำนวน order ฝั่งนั้น `>= MinOrdersToActivate`
- = 0: fallback v6.94 (กระตุ้นเมื่อ `n > InpHero_OrderCount`)
- guarantee: `take = MathMin(InpHero_OrderCount, n-1)` → เหลือ basket non-Hero อย่างน้อย 1 ตัวเสมอ

## ตัวอย่าง
`InpHero_MinOrdersToActivate=5`, `InpHero_OrderCount=2`:
- side count 1..4 → heroCount=0
- side count 5 → heroCount=2, basket non-Hero=3
- side count 8 → heroCount=2, basket non-Hero=6

## ไม่เปลี่ยน
- ❌ Order execution / OrderSend / trade.PositionClose
- ❌ Entry / SMA / ZigZag / Squeeze / BB / Z-Score
- ❌ Grid Loss / Grid Profit lot/distance/candle confirm
- ❌ Hedge / Triple-Gate / Matching close / Recovery
- ❌ Trailing SL value calculation
- ❌ DD% TP / Daily Target / Balance Guard / News / License / Sync
- ❌ ShouldBlockSameSideGridForHero (v6.94 survivor-only block) — ยังเดิม
- ❌ ManageHeroSameSideClose (v6.93 same-side close) — ยังเดิม
- ❌ IsHeroTicket integration ทุกจุด (avg, PL, trailing exclusion)
