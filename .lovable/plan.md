

## Counter-Trend Hedging Mode — Gold Miner SQ EA (v4.3 → v4.4)

### การแก้ไขจากแผนเดิม

**จุดที่เข้าใจผิดก่อนหน้า**: Hedge แทน DirectionalBlock ทั้งหมด
**จุดที่ถูกต้อง**: Hedge แทนเฉพาะ **"block new order on expansion"** — DirectionalBlock (ฝั่งถูกเทรนยังออกออเดอร์ได้) ยังคงทำงานปกติ

**จุดสำคัญเพิ่มเติม**: Hedge **ทำงานหลายชุดพร้อมกัน** — ถ้า Expansion เปลี่ยนทิศ → สร้าง Hedge ชุดใหม่แยกอิสระจากชุดเดิม

---

### ตัวอย่างสถานการณ์

```text
1. Bearish Expansion → มี Buy orders ติด 10 ตัว (2 lot)
   → เปิด Sell Hedge 2 lot (ชุด #1)
   → Sell orders ปกติยังออกได้ (DirectionalBlock ทำงาน)

2. ระหว่างนั้นตลาดกลับตัวฉับพลัน → Bullish Expansion
   → ตอนนี้มี Sell orders ติด (ทั้งปกติ + อาจมี Hedge grid)
   → เปิด Buy Hedge ชุด #2 แยกจากชุด #1
   → ทั้ง 2 ชุด Hedge ทำงานแยกกัน จัดการกันเอง
```

---

### Input Parameters ใหม่

```text
input group "=== Counter-Trend Hedging ==="
input bool     InpHedge_Enable              = false;
input double   InpHedge_MatchMinProfit      = 5.0;    // Min Profit for Hedge Matching ($)
input int      InpHedge_MatchMinProfitOrders = 2;     // Min Profit Orders for Hedge Grid Matching
input double   InpHedge_PartialMinProfit    = 5.0;    // Min Profit for Partial Close ($)
```

### Global Structure — Multi-Hedge Support

```text
struct HedgeSet {
   bool     active;
   ulong    hedgeTicket;
   ENUM_POSITION_TYPE hedgeSide;  // BUY or SELL (ฝั่ง hedge)
   double   hedgeLots;
   double   originalTotalLots;
   bool     gridMode;
   int      gridLevel;
   ulong    gridTickets[];        // tickets ของ hedge grid orders
};
HedgeSet g_hedgeSets[4];  // รองรับ 4 ชุดพร้อมกัน
int g_hedgeSetCount = 0;
```

### Logic หลัก

#### 1. เปิด Hedge (ปรับจากเดิม)
ใน Squeeze check (~line 929-948):
- เมื่อ `InpHedge_Enable = true` + Expansion + direction detected:
  - **DirectionalBlock ยังทำงานปกติ** (block ฝั่งสวนเทรน)
  - **เพิ่ม**: ถ้ามี orders ติดในฝั่งสวนเทรน → สร้าง Hedge ชุดใหม่
  - Bearish expansion + Buy orders ติด → เปิด Sell Hedge
  - Bullish expansion + Sell orders ติด → เปิด Buy Hedge
  - **ไม่เปิดซ้ำ** ถ้ามี Hedge ชุดเดิมฝั่งเดียวกันอยู่แล้ว
  - Comment: `"GM_HEDGE_1"`, `"GM_HEDGE_2"` ฯลฯ
- เมื่อ `InpHedge_Enable = false` → DirectionalBlock อย่างเดียว (เหมือน v4.3)

#### 2. Scenario 1: Hedge กำไร + สถานะกลับ Normal
`ManageHedgeMatchingClose(hedgeSetIndex)` — เหมือนแผนเดิม แต่ทำงานต่อ Hedge set

#### 3. Scenario 2: ราคากลับตัว → Hedge ขาดทุน + orders เดิมบวก
`ManageHedgePartialClose(hedgeSetIndex)` — partial close hedge ด้วยกำไร orders เดิม

#### 4. Hedge Grid Mode
เมื่อ orders เดิมหมดแต่ hedge ยังค้าง → คำนวณ equiv grid level → เปิด grid ต่อ

#### 5. การทำงานร่วมกัน
- **แต่ละ Hedge set ทำงานอิสระ** — จัดการ matching/partial close เฉพาะ orders ของตัวเอง
- **Accumulate Close** ปิดทุกอย่างรวม Hedge ทุกชุด
- **Matching Close ปกติ** ข้าม orders ที่มี comment `GM_HEDGE` / `GM_HG#`
- **DirectionalBlock** ทำงานคู่ขนาน — ฝั่งถูกเทรนยังออกออเดอร์ได้ตามปกติ

### Dashboard เพิ่ม

```text
=== HEDGE MODE ===
Set#1: SELL 2.00 lot | PnL: +$150 | Grid: OFF
Set#2: BUY 1.50 lot  | PnL: -$80  | Grid: ON L2
```

### Version bump: v4.3 → v4.4
อัปเดตทุกจุด: `#property version "4.40"`, description, header, Dashboard

---

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL/Trailing)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Matching Close ปกติ (แยกกัน ไม่กวน)
- DirectionalBlock logic (ยังทำงานเหมือนเดิม — Hedge เป็นฟีเจอร์เสริม)
- Accumulate/Drawdown logic (ปิดทุก order รวม hedge)
- เมื่อ `InpHedge_Enable = false` → behavior เหมือน v4.3 100%

