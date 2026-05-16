## แผนแก้ Golden2 EA v2.8.5

### เป้าหมาย
แก้ 4 จุด:
1. หลัง Hedging เปิด ต้องถอด Broker TP/SL ของ **ทุก Order ในกรุ๊ป** (รวม main, hedge, และ "orphan main" ที่เกิดก่อน hedge) และคงสภาพ "ไม่มี TP/SL" จนกว่าจะผ่าน 3 Gate
2. หนึ่งกรุ๊ป Hedging ได้เพียงครั้งเดียวเท่านั้น ห้าม re-hedge กรุ๊ปเดิม
3. Matching Close ต้องรวม **Order ที่ไม่ได้ผูกกับ Hedging** (orphan main, ไม่ว่ากำไรหรือขาดทุน) เข้าไปคำนวณด้วย ก่อนที่จะวาง Recovery
4. Broker Avg TP/SL ใส่กลับเฉพาะหลัง Matching Close — รวม Bound order + residual + remaining hedge + recovery + orphan ที่เหลือทั้งหมดเป็นค่าเฉลี่ยเดียว

## ปัญหาที่พบจากโค้ด v2.8.4

### A) Post-Match Avg TP ทำงานเร็วเกินไป
`SyncPostMatchAvgTPSL(g)` trigger เมื่อ `g_stripped[g] || IsGroupHedgeMatched(g)` → แค่ strip เสร็จก็เริ่มใส่ Avg TP กลับเข้าไปก่อน 3 Gate / Matching Close จะทำงาน → hedge โดน TP ก่อนเวลา

### B) Strip ครั้งเดียว ไม่ครอบคลุม orphan ที่เพิ่มทีหลัง
`StripBrokerTPSL_OnHedgeMatch()` เรียกครั้งเดียวเมื่อ `!g_stripped[g]` → ถ้ามี orphan order (main ฝั่งตรงข้าม loss side) มี TP/SL ติดมาก่อน hedge หรือถูก v1.3 SyncSideTPSL ใส่กลับ จะไม่ถูก strip ซ้ำ

### C) ไม่มี state "กรุ๊ปนี้ใช้ Hedge ไปแล้ว"
`ManageGroupHedgeArm()` ดูแค่ว่ายังมี hedge position อยู่ไหม — ถ้า hedge ตัวเดิมโดน TP ไป จะกลับไป arm hedge pending ใหม่ได้ ขัดหลัก 1 group = 1 hedge

### D) Orphan Main Order ฝั่งเดียวกับ Hedge
ตอนนี้ทุก ScanByComment ใช้ `gp==g` อยู่แล้ว ดังนั้น orphan main จะถูก strip + matching close ได้โดยอัตโนมัติ — แต่ต้อง **ยืนยันชัดเจน** ว่า: pre-match SyncSideTPSLToBroker ต้องหยุดเขียน TP/SL ลงไปทันทีเมื่อ `g_groupHedgeUsed[g]==true` (ไม่ใช่แค่ตอน matched) มิฉะนั้น orphan main ฝั่งตรงข้ามจะถูกใส่ Initial TP กลับโดย v1.3 manager หลัง strip

## สิ่งที่จะปรับ

### 1) State Lifecycle ใหม่
เพิ่ม global:
- `bool g_groupHedgeUsed[51]` — true ทันทีที่กรุ๊ปเคยมี hedge position
- `bool g_groupPostMatchAvgActive[51]` — true เฉพาะหลัง Matching Close สำเร็จและยังเหลือ residual

Reset ทั้งสองค่าเฉพาะตอน group flat จริง (`!hasPos && !hasPend`)

### 2) ห้าม Re-Hedge
ใน `ManageGroupHedgeArm(g)`:
- ถ้า `g_groupHedgeUsed[g]==true` → ห้าม arm pending hedge ใหม่ทั้งหมด
- ลบ hedge pending ที่หลงเหลือทิ้ง

### 3) Strip TP/SL ต่อเนื่องหลัง Hedge Used
- เมื่อพบ hedge position → stamp `g_groupHedgeUsed[g]=true` (ใน OnTick block)
- เรียก `StripBrokerTPSL_OnHedgeMatch(g)` ได้ทุก tick ตราบ `g_groupHedgeUsed[g] && !g_groupPostMatchAvgActive[g]` (ไม่ใช่แค่ครั้งแรก)
- `ModifyIfDifferent` มี early-return อยู่แล้ว ดังนั้น tick ที่ TP/SL=0 อยู่แล้วจะไม่ยิง modify ซ้ำ

### 4) บล็อก v1.3 Pre-Match Sync เมื่อ Hedge Used
ปรับเงื่อนไข early-return ของ `SyncSideTPSLToBroker(g, side)`:
- จากเดิม `if(g_stripped[g] || IsGroupHedgeMatched(g)) return;`
- เปลี่ยนเป็น `if(g_stripped[g] || IsGroupHedgeMatched(g) || g_groupHedgeUsed[g]) return;`
ผลคือ orphan main ฝั่งใดก็ตามที่เคยมี hedge อยู่ในกรุ๊ป จะไม่ถูกใส่ Initial TP กลับเข้าไปอีก

### 5) Matching Close รวม Orphan Order
ใน `TryMatchingCloseForGroup(g)`:
- `winProfit` / `netCheck` ปัจจุบันรวม main+hedge ทั้งสองฝั่งอยู่แล้ว (ครอบคลุม orphan) — คงไว้
- `ShredCloseLosingSide` + `ShredAllNegativeFromAllProfit` scan โดย `gp==g` → จับ orphan ทุกตัวอยู่แล้ว — คงไว้
- เพิ่ม log สรุปก่อน Matching: `MATCH-PREP G%d totalTickets=N (main=%d hedge=%d) profitable=%d losing=%d` เพื่อยืนยันว่า orphan ถูกนับ
- หลัง Matching Close ถ้ายังเหลือ residual: เรียก `PlaceRecoveryGridIfNeeded` เหมือนเดิม

### 6) Post-Match Avg TP เปิดเฉพาะหลัง Matching Close
ปรับ `SyncPostMatchAvgTPSL(g)`:
- Trigger ใหม่: `InpPostMatch_AvgBrokerTP && g_groupPostMatchAvgActive[g] && GroupHasAnyPositions(g)`
- ไม่ใช้ `g_stripped` หรือ `IsGroupHedgeMatched` เป็น trigger อีก
- คำนวณ avg ต่อฝั่งจากทุก position (main+hedge+RC+orphan) ที่ยังเหลือในกรุ๊ป — เหมือน v2.8.4 (ใช้ `GroupAveragePrice(g, side, -1)` อยู่แล้ว)

ตั้ง `g_groupPostMatchAvgActive[g] = true` เฉพาะหลัง `TryMatchingCloseForGroup` ทำ matching จริง (มีอย่างน้อย 1 ticket ถูกปิด) และยังเหลือ residual

### 7) Dashboard & Version
- `#property version "2.85"` + description + dashboard title + init log → v2.8.5
- Dashboard hedging panel เพิ่มสถานะสั้น ๆ:
  - `Hedge: ARMED / USED / LOCKED`
  - `PostAvg: WAITING / ACTIVE`
- ไม่เพิ่มรายการ ticket ยาว ๆ (คง slim layout v2.8.4)

## สิ่งที่ไม่เปลี่ยนแปลง
- Entry mode PENDING/SMA/INSTANT, Squeeze BB/KC/ADX/EMA/ATR
- Grid Loss/Profit lot, distance, candle confirm, ATR snapshot
- 3 Gate condition: Squeeze TF3 latch + breakout + WinPool/MinGain
- สูตร Matching Close (winning pool shred + cross-side pool) ของ v2.8.4
- Recovery Grid placement และสูตร multiplier
- ParseComment / MakeComment / B_/S_ side tags
- Per-order trail, Bar-close trail, Cost-Hit, Accumulate, Force-close opp unhedged
- Tester cleanup, prior-group advance guard

## ผลลัพธ์ที่คาดหวัง
- Hedge เปิด → TP/SL ของทุก order ในกรุ๊ป (รวม orphan main, hedge, future grid) ถูกถอด และคงสภาพจนกว่า Matching Close จะทำงาน
- กรุ๊ปเดิมจะไม่ re-hedge แม้ hedge ตัวแรกโดน TP
- Matching Close นำ orphan order (ทั้งกำไร/ขาดทุน) มาคำนวณรวมกับ bound+hedge → ปิดได้สูงสุด
- Order ที่เหลือ + Recovery → คำนวณ Average เดียวกัน → วาง Broker Avg TP/SL ปิดทั้งกรุ๊ปด้วย broker