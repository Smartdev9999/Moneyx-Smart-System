

## v6.56 — Bollinger Band Entry Filter (Block New Orders Only)

### หลักการ

เพิ่ม Bollinger Band indicator (3 เส้น: Upper/Middle/Lower) เป็น **Entry Filter** ที่ block การเปิดออเดอร์ใหม่เท่านั้น — ไม่กระทบ logic ปิดออเดอร์, hedge, recovery

### Logic การทำงาน

**Zones (ใช้ระยะ pip ที่ผู้ใช้กำหนด เช่น 100 จุด):**

```text
                  ─── Upper Band ───
                          ↕ ProximityPips (block both sides)
              ─── Mid-Upper Zone ───
                          
                  ─── Middle Band ───
                          ↕ ProximityPips (block both sides)
              ─── Mid-Lower Zone ───
                          
                  ─── Lower Band ───
```

**กฎ Block การเปิดออเดอร์ใหม่ (รวม initial + grid loss/profit):**

1. **ราคา > Upper Band** → block ทั้ง BUY และ SELL (รอกลับเข้า band)
2. **ราคา < Lower Band** → block ทั้ง BUY และ SELL (รอกลับเข้า band)
3. **ราคาใกล้ Upper Band (±ProximityPips)** → block ฝั่งสวนเทรน (ตัวเลือก: block ทั้ง 2 ฝั่ง)
4. **ราคาใกล้ Middle Band (±ProximityPips)** → block ฝั่งสวนเทรน หรือ ทั้ง 2 ฝั่ง
5. **ราคาใกล้ Lower Band (±ProximityPips)** → block ฝั่งสวนเทรน หรือ ทั้ง 2 ฝั่ง

### แผนแก้ไข — `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Version bump → v6.56

#### 2. Input Parameters ใหม่

```cpp
input group "=== Bollinger Band Entry Filter ==="
input bool   BB_FilterEnable      = false;    // Enable BB Filter
input ENUM_TIMEFRAMES BB_Timeframe = PERIOD_M15;
input int    BB_Period            = 20;
input double BB_Deviation         = 2.0;
input int    BB_ProximityPips     = 100;      // Block range near each band
input int    BB_BlockMode         = 0;        // 0=Block Both Sides, 1=Block Counter-Trend Only
```

#### 3. Helper Functions ใหม่ (เพิ่ม global handle + getters)

```cpp
int g_bbHandle = INVALID_HANDLE;

bool InitBBHandle();   // เรียกใน OnInit
void ReleaseBBHandle(); // เรียกใน OnDeinit

// Returns: 0=allow, 1=block buy only, 2=block sell only, 3=block both
int GetBBBlockState();
bool IsBBBlockingBuy();
bool IsBBBlockingSell();
```

Logic ใน `GetBBBlockState()`:
- อ่าน upper/middle/lower จาก iBands handle (bar index 0)
- คำนวณ distance ของราคาปัจจุบันถึงแต่ละเส้น (เป็น pips)
- ถ้า price > upper หรือ price < lower → return 3 (block both)
- ถ้า |price - band| <= ProximityPips → block ตาม BB_BlockMode
  - Mode 0: block both sides
  - Mode 1: block ฝั่งสวน (ใกล้ upper → block buy, ใกล้ lower → block sell, ใกล้ middle → ใช้ slope ของ middle band ตัดสิน)

#### 4. จุดที่ต้องเพิ่ม guard (Block New Orders เท่านั้น)

ค้นหาจุดเปิดออเดอร์ใหม่ทั้งหมดและเพิ่ม `if(BB_FilterEnable && IsBBBlockingBuy()) return;` ก่อนเรียก `trade.Buy(...)` / `trade.Sell(...)`:

- **Initial Entry** (`OpenInitialBuy`, `OpenInitialSell`)
- **Grid Loss Entry** (`OpenGridLossBuy`, `OpenGridLossSell`)
- **Grid Profit Entry** (`OpenGridProfitBuy`, `OpenGridProfitSell`)

**ไม่แตะ:**
- Hedge order opening (เป็น recovery mechanism)
- ทุกฟังก์ชันปิดออเดอร์ (`PositionClose`, Matching Close, Balance Guard, TP/SL sync)

#### 5. Dashboard Display

เพิ่มบรรทัดแสดงสถานะ:
```
BB Filter | ON M15(20,2.0) | Prox:100p | Mode:Both
BB State  | Upper:1985.20 Mid:1980.10 Low:1975.00 | Px:1980.50
BB Block  | BUY: BLOCKED (near Mid) | SELL: ALLOW
```

#### 6. OnInit / OnDeinit

- `OnInit`: เรียก `InitBBHandle()` ถ้า `BB_FilterEnable = true`
- `OnDeinit`: เรียก `ReleaseBBHandle()` + `IndicatorRelease(g_bbHandle)`

### สิ่งที่ไม่เปลี่ยนแปลง

- Order Execution Logic (ตัว `trade.Buy/Sell/PositionClose`) — ไม่แก้
- Trading Strategy Logic (SMA/EMA, TP/SL, Trailing, Breakeven) — ไม่แก้
- Grid entry/exit calculation logic — ไม่แก้ (เพิ่มแค่ guard ก่อนเปิด)
- Hedge open/close logic — ไม่แก้ (Hedge ยังเปิดได้แม้ BB block)
- Matching Close / BoundAvgTP / PartialClose — ไม่แก้
- Balance Guard — ไม่แก้
- Triple Gate / Hedge Recovery — ไม่แก้
- News Filter / Time Filter / License / Data Sync — ไม่แก้
- v6.37–v6.55 features — ไม่แก้

### ผลลัพธ์

- `BB_FilterEnable = false` → ทำงานเหมือนเดิม 100%
- `BB_FilterEnable = true` → blocks การเปิด initial + grid orders ตามตำแหน่งราคาเทียบ Bollinger Band → hedge และการปิดยังทำงานปกติ

