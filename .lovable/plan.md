

## Fix: Hedge เปิดรัวๆ + H2 เปิดก่อนเวลา (v5.21 → v5.22)

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

---

### วิเคราะห์ปัญหา

**ปัญหาที่ 1: Hedge เปิดหลาย orders รัวๆ**

`CheckAndOpenHedge()` ถูกเรียกทุก tick (line 1065) → หลังเปิด H1 สำเร็จ tick ถัดไป:
- Guard 2 (line 6364): เช็ค `g_hedgeSets[slot].active` — แต่ slot ที่เพิ่งเปิดอาจยังไม่ถูกเก็บถูกต้องถ้า `trade.ResultDeal()` ยังไม่ return
- Net Imbalance (line 6386): ถ้า `IsBelongsToCycle()` ไม่รวม hedge ticket ที่เพิ่ง open → ยังเห็น imbalance → เปิดอีก
- ไม่มี cooldown/debounce → ออเดอร์ซ้ำหลายตัว

**ปัญหาที่ 2: H2 เปิดโดยไม่รอ bound orders ถูกเคลียร์**

ตาม user: H2 เปิดได้เมื่อ:
1. Expansion เปลี่ยนทิศ (เช่น sell→buy)
2. Bound orders ฝั่งเดิม (10 sell orders) ถูกปิดหมดแล้ว
3. เหลือแค่ H1 hedge + grid loss orders → H2 lot = sum ของที่เหลือ

แต่ปัจจุบัน Guard 1 (line 6344) เช็คแค่ "มี counter-side orders ไหม" → ผ่านได้แม้ bound orders ยังไม่ถูกเคลียร์

---

### การแก้ไข

#### 1. เพิ่ม Cooldown หลังเปิด Hedge

```text
เพิ่ม global:
  datetime g_lastHedgeOpenTime = 0;

หลัง OpenOrder สำเร็จ:
  g_lastHedgeOpenTime = TimeCurrent();

ต้น CheckAndOpenHedge():
  if(TimeCurrent() - g_lastHedgeOpenTime < 60) return;  // cooldown 60 วินาที
```

#### 2. เพิ่ม Guard: H2+ ต้องรอ bound orders ของ hedge ก่อนหน้าถูกเคลียร์

```text
เพิ่มหลัง Guard 3 (line 6380):

  // Guard 4: H2+ ต้องรอให้ bound orders ของ hedges ก่อนหน้าใน cycle ถูกปิดหมดก่อน
  for(int h = 0; h < MAX_HEDGE_SETS; h++)
  {
     if(!g_hedgeSets[h].active) continue;
     if(g_hedgeSets[h].cycleIndex != g_currentCycleIndex) continue;
     if(g_hedgeSets[h].boundTicketCount > 0)
        return;  // ยังมี bound orders ค้าง → ห้ามเปิด hedge ใหม่
  }
```

**ผล:** H2 จะเปิดได้ก็ต่อเมื่อ:
- Expansion เปลี่ยนทิศ (Guard 3 ผ่าน)
- Bound orders ของ H1 ถูกปิดหมดแล้ว (Guard 4 ผ่าน)
- ยังมี imbalance (H1 hedge + grid orders ยังค้าง)

#### 3. Version bump: v5.21 → v5.22

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL/Trailing)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Hedge/Grid Recovery logic ทั้งหมด
- Normal Matching Close logic
- Dashboard / Hedge Cycle Monitor

