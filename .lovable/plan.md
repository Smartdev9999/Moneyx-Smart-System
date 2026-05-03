
# แผนแก้ Hero Order — v6.99 → v7.00

ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

## เงื่อนไขปิด Hero ที่ผู้ใช้ยืนยัน (Final Spec)

Hero ปิดได้แค่ 3 เงื่อนไขเท่านั้น:
1. **Lock-profit SL hit** — broker SL กันทุนถูกชน
2. **Opposite-basket close** — ฝั่งตรงข้าม (ที่เป็น order ปกติ) ปิด basket ผ่าน Avg TP / Avg Trailing → Hero ปิดตาม
3. **Accumulate close** — global close ทั้งบัญชี

Hero **ห้าม** ถูกปิดด้วย: per-order trailing, per-order SL, basket trail SL, hedge module, recovery, squeeze, daily target, balance guard ฯลฯ

## Hero Selection Spec (Final)

- Hero = **เฉพาะ `_GL`** ของฝั่งนั้น (Grid Loss เท่านั้น)
- ไม่นับ `_INIT` และ `_GP` เป็น Hero
- การนับ threshold (เช่น >=20 orders) ใช้ active total ของ `_INIT + _GL + _GP` รวม (เพื่อไม่ให้ Hero โผล่เร็วเกิน)
- Activation: side total ≥ `InpHero_MinOrdersToActivate`
- เลือก `InpHero_OrderCount` ตัวล่าสุดของ `_GL` (เรียงด้วย POSITION_TIME_MSC + ticket)
- Rolling: เปิด GL ใหม่ → GL เก่าสุดออกจาก Hero → คืนสู่ basket ปกติ

## การเปลี่ยนแปลง

### 1. BuildHeroTicketCache — แยก count vs tag (line ~2310-2380)

```cpp
// PASS 1: นับ active total ทั้งฝั่ง (INIT+GL+GP) เพื่อ threshold gate
int sideTotalActive = นับทุก _INIT/_GL/_GP ของฝั่งนั้น;

// PASS 2: collect เฉพาะ _GL เท่านั้นมาเป็น Hero candidate
ulong glOnly[200]; long glMs[200]; int nGL = 0;
for(...) {
   if(StringFind(c,"_GL") < 0) continue;   // GL ONLY
   glOnly[nGL] = ticket;
   glMs[nGL]   = POSITION_TIME_MSC;
   nGL++;
}

// Activation: ใช้ sideTotalActive
if(sideTotalActive < activateThreshold) continue;

// Sort glOnly desc → take latest N
int take = MathMin(InpHero_OrderCount, nGL - 1);
if(curPhase==BE_GUARD) take = MathMin(InpHero_OrderCount, nGL);
```

Dashboard ต้องอัปเดตทั้ง `Active=sideTotalActive` (แสดง 36/20) และ `GL pool=nGL` (เช่น 30/3).

### 2. ลบ lock check ที่ตาย — Bug A fix (line 2510-2517)

```cpp
bool DetectSameSideBasketClearedForHero(ENUM_POSITION_TYPE side)
{
   if(!InpHero_Enabled) return false;
   // v7.00: REMOVED dead check (g_heroLockedSide always -1 in v6.99+)
   // if((int)side != g_heroLockedSide) return false;
   if(CountHeroOnSide(side) <= 0) return false;
   if(CountNonHeroMainOnSide(side) > 0) return false;
   return true;
}
```

ผลลัพธ์: เมื่อ basket ฝั่ง Hero clear แล้ว → BE_GUARD trigger → ApplyHeroLockProfitSL ใส่ SL กันทุนได้จริง

### 3. เพิ่ม Hero-skip ใน close path ที่ขาด

Audit ทุก `trade.PositionClose` ที่ไม่ skip Hero (line 8497, 9782, 10479, 10724, hedge module 11885-12876):
- ถ้า path เป็น **manual close all / accumulate close / drawdown global close** → ไม่ skip (ตามสเปก #3)
- ถ้า path เป็น **per-order/per-side/squeeze/hedge module** → ใส่ `if(IsHeroTicket(ticket)) continue;`

### 4. Per-Order Trailing & Breakeven — block Hero

ตรวจ `ManagePerOrderTrailing`, `ManageBreakeven`, `ApplyTrailingSL_TF` ให้ทุกฟังก์ชัน skip Hero ticket

### 5. Hero Close Audit Log

แต่ละจุดที่ปิด Hero → log เหตุผลชัดเจน:
```
v7.00 Hero CLOSED ticket=#653 side=SELL reason=OppositeBasketClose|LockProfitSL_HIT|AccumClose|UNKNOWN_PATH
```
จุด `UNKNOWN_PATH` ใส่ใน OnTradeTransaction เพื่อจับ path ที่ไม่ตั้งใจปิด Hero

### 6. Dashboard — แสดง GL pool

```
Hero BUY: 36 act / 28 GL / keep 3 / ARMED
Tix BUY:  #693, #695, #697
```

### 7. Version bump → v7.00

อัปเดต `#property version`, `#property description`, header, OnInit/OnDeinit Print, dashboard headerVersion, audit log prefix

## สิ่งที่ไม่เปลี่ยน (กฎเหล็ก)

- ❌ OrderSend / trade.Buy / trade.Sell / market entry conditions
- ❌ SMA/EMA/Squeeze/BB/ZigZag entry filter
- ❌ Grid Loss / Grid Profit lot calc / distance / candle confirm
- ❌ Average TP / Average Trailing Stop **คำนวณ** (Hero ถูก exclude อยู่แล้ว)
- ❌ Hedge / Triple-Gate / Matching close / Recovery / Auto Recovery
- ❌ Drawdown / Daily Target / Balance Guard / Max DD tracking
- ❌ License / News / Time / Sync module
- ❌ Block-same-side-grid (v6.94 survivor logic) — ยังคงทำงานเหมือนเดิม
- ❌ Lock-profit BE-SL formula (`InpHero_BE_OffsetPoints`)
- ❌ EnsureHeroProtection wrapping pre/post SyncBrokerTPSL

## Test Steps

1. set InpHero_Enabled=true, MinActivate=20, OrderCount=3
2. เปิด BUY ถึง 36 orders (1 INIT + 35 GL)
3. Log: `v7.00 Hero AUDIT: BUY active=36 glPool=35 hero=3 phase=ARMED`
4. Dashboard: `Hero BUY: 36/20 GL=35 Hero=3 [#693, #695, #697]`
5. ราคาเด้ง → Avg TP ปิด BUY 33 ตัว (INIT + 32 GL)
6. Log: `v7.00 Hero PHASE BUY -> BE_GUARD; SL applied #693, #695, #697`
7. SELL basket Avg TP ชน → Log: `v7.00 Hero CLOSED reason=OppositeBasketClose` x3
8. ห้ามเห็น Hero ปิดด้วย reason อื่นในระหว่างที่ BUY ยังเปิดอยู่
