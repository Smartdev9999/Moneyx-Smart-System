
# Gold Miner EA v7.04 — Single-Side Hero Lock + Active Per-Side Gen Isolation

## ปัญหาที่พบ (จากภาพล่าสุด)
1. **Hero เกิดขึ้น 2 ฝั่งพร้อมกัน** — เดิมมี Hero ฝั่ง BUY (145, 146 = `GM1_GL#41/42`) เหลือจาก 5 ตัวที่ปิดไป 3 ตัว → ราคาขึ้น → SELL basket โต → SELL ก็ activate Hero ตามไปด้วย → ปิดออเดอร์ BUY ไม่ได้เพราะ Hero SELL ขวาง
2. **ยังไม่เห็น GMx+1 บนฝั่งที่มี Hero รอด** — `InpHero_PerSideGenIsolation` default = OFF + แม้เปิด ก็ไม่ทำงานจริงเพราะ ~12 จุดในระบบ filter ด้วย `orderGen != g_cycleGeneration`

## เป้าหมาย v7.04
- **Hero ทำงานได้แค่ฝั่งเดียวต่อครั้ง** — ฝั่งไหน activate ก่อน lock ฝั่งตรงข้ามจน Hero = 0
- **ฝั่งที่มี Hero รอด** → เปิด/นับ/จัดการออเดอร์ใหม่เป็น `GM(N+1)` เต็มวงจร
- **ฝั่งตรงข้าม** → ใช้ `GM(N)` เดิมตามปกติจนกว่าจะปิดพร้อม Hero

---

## แผนการเปลี่ยนแปลง

### 1. Single-Side Hero Activation Lock
ใน `BuildHeroTicketCache` (L2318) — ก่อน loop ทั้ง 2 ฝั่ง:
```cpp
// v7.04: หาว่ามีฝั่งไหน "ครอง" Hero อยู่แล้ว (มี Hero ticket จริง หรือ phase != NONE)
int activeOwner = -1;
if(CountHeroOnSide(POSITION_TYPE_BUY)  > 0 || g_heroPhase_Buy  != 0) activeOwner = (int)POSITION_TYPE_BUY;
else if(CountHeroOnSide(POSITION_TYPE_SELL) > 0 || g_heroPhase_Sell != 0) activeOwner = (int)POSITION_TYPE_SELL;
```
ในลูป — ถ้า `activeOwner >= 0 && sideId != activeOwner && curPhase == 0` → **skip activation** (อย่า tag, อย่าตั้ง phase) → ฝั่งตรงข้ามถูกแช่แข็งจาก Hero pool
- **Reset อัตโนมัติ**: เมื่อฝั่งที่ครองปิด Hero หมด (CountHeroOnSide == 0 และ phase reset เป็น 0 ใน CloseHeroOnSide / ResetHeroStateIfFlat) → ฝั่งตรงข้ามกลับมา activate ได้
- เพิ่ม input `InpHero_SingleSideLock` (default = `true`) เผื่อย้อนพฤติกรรม v6.99 dual-side

### 2. Per-Side Gen Isolation — Default ON + Wire Filter
**ต้องแก้ filter ทั่ว EA** เพื่อให้ `GM(N+1)` ฝั่ง BUY ถูก "มองเห็น" โดย CountOrders / FindLatestGridPrice / FindMaxGridLevel / RecoverInitialPrices

#### Helper ใหม่
```cpp
int GetActiveGenForSide(ENUM_POSITION_TYPE side) {
   int sg = (side == POSITION_TYPE_BUY) ? g_sideGen_Buy : g_sideGen_Sell;
   return (sg > 0) ? sg : ((g_cycleGeneration < 1) ? 1 : g_cycleGeneration);
}
```

#### แก้ filter pattern ที่ ~12 จุด
แทน:
```cpp
if(orderGen >= 0 && orderGen != g_cycleGeneration) continue;
```
ด้วย:
```cpp
ENUM_POSITION_TYPE pSide = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
int activeGen = GetActiveGenForSide(pSide);
if(orderGen >= 0 && orderGen != activeGen) continue;
```
จุดที่ต้องแก้: **L1190, L1222, L1995, L2050, L3931, L3960, L4572, L5896, L6091, L6194, L6226**

จุดที่ **ไม่แตะ** (เกี่ยวกับ hedge/recovery/orphan ที่อิง global gen ตาม design เดิม): L9378, L10282, L10790, L11162

#### Default
```cpp
input bool InpHero_PerSideGenIsolation = true; // v7.04 default ON
```

### 3. CrossGen INIT Guard ปรับให้รับ side gen
จุด L1469 (`g_cycleGeneration > 1 && g_hedgeSetCount == 0`) และ L5642 ใน dashboard logic — เปลี่ยนจาก global → per-side (ตรวจ `GetActiveGenForSide(side) > 1` แทนเมื่อพิจารณา block INIT) เพื่อให้ฝั่ง BUY ที่ activeGen=2 ผ่าน guard ได้แม้ global=1

### 4. Cycle Reset Total Flat
ใน `ResetCycleStateIfFlat` (L9600+) — ถ้าทั้งบัญชีว่าง: รีเซ็ต `g_sideGen_Buy = g_sideGen_Sell = 0` พร้อม `g_cycleGeneration = 1`

### 5. Dashboard Hero Monitor — เพิ่ม
- Side Gen BUY: `GM2` (Hero owns GM1) — สีทอง
- Side Gen SELL: `GM1` (active)
- Hero Owner: `BUY` (single-side lock active) / `NONE`

### 6. Version Bump → v7.04
- `#property version "7.04"`
- `#property description` → สรุปสั้น
- Init log: `"Gold Miner EA v7.04 initialized..."`
- Dashboard footer

---

## สิ่งที่ไม่เปลี่ยนแปลง (ยืนยันตามกฎเหล็ก)
- ❌ ไม่แตะ `OrderSend` / `trade.Buy` / `trade.Sell` / `trade.PositionClose`
- ❌ ไม่แก้ entry conditions (SMA/EMA/ZigZag/BB/Squeeze)
- ❌ ไม่แก้ Grid loss/profit lot/distance/candle confirm
- ❌ ไม่แก้ TP/SL/Trailing/Breakeven/Avg TP calculations
- ❌ ไม่แก้ Hedge/Triple-Gate/Recovery/DD% TP/Daily Target/Balance Guard
- ❌ ไม่แก้ Accumulate Close logic
- ❌ ไม่แก้ License/News/Sync modules
- ❌ ไม่แก้ Hero formula (`ComputeHeroLockProfitSL`, `ValidateHeroLockProfitSL` v7.02, BE_GUARD logic, Post-Close Grace v7.03)
- ✅ เปลี่ยนแค่: (1) gate "ฝั่งไหนเป็น Hero owner", (2) wiring ของ orderGen filter ต่อฝั่ง, (3) default flag, (4) dashboard

## ผลลัพธ์ที่คาดหวัง
**Scenario ตามภาพ:**
1. BUY มี Hero (145, 146 = `GM1_GL#41/42`) → `g_heroPhase_Buy=2/3`, owner = BUY
2. ราคาขึ้น → SELL grid โต → ถึง threshold → **ถูก single-side lock block** → ไม่ถูก tag เป็น Hero
3. ราคาดิ่งกลับ → SELL ปิดได้ตามปกติ (ไม่มี Hero SELL ขวาง)
4. ฝั่ง BUY: `g_sideGen_Buy=2` → grid ใหม่ฝั่ง BUY = `GM2_INIT, GM2_GL#1...` ทำงานเต็มระบบ (count/TP/trail)
5. ฝั่ง SELL: ใช้ `GM1` ตามปกติจนปิดพร้อม Hero BUY
6. เมื่อ Hero BUY ปิดหมด → ทุก side gen รีเซ็ต → กลับสู่ GM1 ปกติ + SELL กลับมา activate Hero ได้ในรอบถัดไป
