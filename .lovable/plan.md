# แผนแก้ Gold Miner EA v6.94 — Grid Loss / Grid Profit ถูก Hero Block เร็วเกินไป

จากภาพ Journal เห็นชัดว่า Grid ไม่ได้เสียที่เงื่อนไขระยะ/แท่งเทียน แต่ถูกบล็อกโดย Hero โดยตรง:

```text
v6.92 Hero BLOCK: side=POSITION_TYPE_BUY has 1 Hero — skip GM1_GL#1
v6.93 Hero CACHE: total=2 heroBUY=1 heroSELL=1
```

สาเหตุคือ v6.93 ใช้ `CountHeroOnSide(side) > 0` เป็นเงื่อนไข block แบบทันที ทำให้ทันทีที่ระบบเจอ Hero candidate 1 ตัว ฝั่งนั้นจะห้ามเปิด `_INIT`, `_GL`, `_GP` ทั้งหมด ส่งผลให้ Grid Loss / Grid Profit ไม่สามารถเดินต่อได้

## เป้าหมาย v6.94

ทำให้ Hero ทำงานตามเจตนาเดิม:

1. Grid Loss / Grid Profit ต้องยังทำงานได้ตามปกติระหว่าง basket กำลังสร้าง/กู้คืน
2. Hero คือ N ออเดอร์ล่าสุดของ generation ปัจจุบัน แต่ต้องไม่ทำให้ grid ถูกล็อกตั้งแต่ยังมี basket หลักอยู่
3. Block grid ฝั่งเดียวกันจะทำงานเฉพาะตอนที่เหลือ Hero survivor จริง ๆ แล้วเท่านั้น เช่น basket non-Hero ถูกปิดไปแล้ว แต่ Hero ยังเหลือค้างอยู่
4. ถ้าเปิด toggle ปิด Hero พร้อม same-side basket แล้ว Hero จะถูกปิดตาม basket และ grid/entry จะกลับมาทำงานตามปกติหลังไม่มี Hero เหลือ

## สิ่งที่จะเปลี่ยนใน `public/docs/mql5/Gold_Miner_EA.mq5`

### 1. แก้ `BuildHeroTicketCache()` ไม่ให้ INIT ตัวแรกกลายเป็น Hero ทันที

ปัจจุบันถ้า `InpHero_OrderCount=1` และมีแค่ initial order 1 ตัว ระบบจะนับตัวนั้นเป็น Hero ทันที ทำให้ไม่มี basket หลักเหลือให้ grid ทำงาน

จะแก้เป็น:

```cpp
if(n <= InpHero_OrderCount)
   continue; // ยังไม่สร้าง Hero จนกว่าจำนวน order ฝั่งนั้นจะมากกว่า N
```

ผลลัพธ์:
- มี order 1 ตัว และ HeroCount=1 → ยังไม่ถือเป็น Hero
- มี order 2 ตัว และ HeroCount=1 → ตัวล่าสุดเป็น Hero candidate, ตัวก่อนหน้าเป็น basket หลัก
- มี order 5 ตัว และ HeroCount=2 → 2 ตัวล่าสุดเป็น Hero candidate, 3 ตัวก่อนหน้าเป็น basket หลัก

### 2. เปลี่ยนเงื่อนไข Block Grid จาก “มี Hero” เป็น “เหลือแต่ Hero survivor”

ปัจจุบัน:

```cpp
if(CountHeroOnSide(wantSide) > 0)
   return false;
```

จะแก้เป็น helper ใหม่ เช่น:

```cpp
bool ShouldBlockSameSideGridForHero(ENUM_POSITION_TYPE side)
{
   return CountHeroOnSide(side) > 0
       && CountNonHeroMainOnSide(side) == 0;
}
```

ความหมาย:
- ถ้ามี Hero candidate แต่ยังมี non-Hero basket หลักอยู่ → ให้ Grid Loss / Grid Profit ทำงานต่อได้
- ถ้า non-Hero basket ถูกปิดหมดแล้วและเหลือ Hero เท่านั้น → block `_INIT`, `_GL`, `_GP` ฝั่งเดียวกันตามสเปก

### 3. เพิ่ม helper ตรวจนับ non-Hero main orders

เพิ่ม helper สำหรับนับ order ฝั่งเดียวกันที่เป็น:

- current generation เท่านั้น
- ไม่ใช่ hedge
- ไม่ใช่ bound order
- comment เป็น `_INIT`, `_GL`, `_GP`
- ไม่ใช่ Hero ticket

ใช้สำหรับตัดสินว่า Hero เป็นแค่ candidate ระหว่าง basket ทำงาน หรือเป็น survivor ที่ควรล็อก grid แล้ว

### 4. ปรับ Log ให้แยก “Hero candidate” กับ “Hero survivor block” ชัดเจน

อัปเดต log จาก `v6.92 Hero BLOCK` เป็น `v6.94` และระบุเหตุผล เช่น:

```text
v6.94 Hero CACHE: total=2 heroBUY=1 heroSELL=1 nonHeroBUY=3 nonHeroSELL=2
v6.94 Hero BLOCK: standalone Hero BUY remains; skip GM1_GL#1
```

เพื่อให้ดู Journal แล้วรู้ทันทีว่า:
- Hero ถูกเลือกกี่ตัว
- basket หลักเหลือกี่ตัว
- block เกิดเพราะเหลือแต่ Hero จริงหรือไม่

### 5. Audit จุดที่เกี่ยวกับ GL/GP ไม่ให้ Hero ไปปิด grid ผิดจังหวะ

ตรวจและปรับเฉพาะจุดที่เกี่ยวกับ Hero guard:

- `OpenOrder()` — block เฉพาะ Hero survivor
- `BuildHeroTicketCache()` — ไม่สร้าง Hero ถ้า order count ยังไม่เกิน N
- `NormalOrderCount()` — คง behavior `InpHero_IncludeInMaxOrders` ตามเดิม
- `FindLastOrder()` — คงไว้ให้ grid ใช้ order ล่าสุดจริง เพื่อไม่ทำให้ระยะ grid เพี้ยน
- `CountPositions()` — คงไว้ให้นับ GL/GP ตามจริง เพื่อไม่เปลี่ยน MaxTrades/level behavior

### 6. ตรวจ TF grid path เพิ่มเติมแบบปลอดภัย

ถ้า EA ใช้ TF grid path ด้วย จะตรวจจุดเหล่านี้ไม่ให้ Hero ถูกปิดผิด:

- `CloseAllSideTF()` ควร skip Hero เช่นเดียวกับ `CloseAllSide()`
- `CalculateAveragePriceTF()` / `CalculateFloatingPL_TF()` ถ้าเข้ากับ Hero comment format ต้อง skip Hero เช่น main path
- `OpenOrderTF()` ใช้ `OpenOrder()` อยู่แล้ว จึงจะได้ block rule ใหม่อัตโนมัติ

### 7. Version bump เป็น v6.94

อัปเดตทุกจุดตามกฎโปรเจกต์:

- `#property version`
- `#property description`
- Header comment block
- OnInit / Deinit log
- Dashboard version display
- log tag ที่เกี่ยวกับ Hero จาก v6.92/v6.93 เป็น v6.94 ตามจุดที่แก้

## สิ่งที่ไม่เปลี่ยนแปลง

ยืนยันว่าจะไม่แตะส่วนเหล่านี้:

- ไม่แก้สูตรระยะ Grid Loss / Grid Profit
- ไม่แก้สูตร lot ของ Grid Loss / Grid Profit
- ไม่แก้เงื่อนไข SMA / Entry signal / Squeeze / BB / Z-Score
- ไม่แก้ Hedge / Triple-Gate / Matching close / Recovery / Auto Recovery
- ไม่แก้ DD% TP / Daily Target / Balance Guard
- ไม่แก้ค่า trailing stop calculation
- ไม่แก้ License / News / Time filter / Sync module
- ไม่เปลี่ยน logic การส่งคำสั่งซื้อขาย นอกจาก guard ที่อนุญาต/บล็อกตาม Hero state เดิม

## Checklist หลังแก้

1. ตั้ง `InpHero_Enabled=true`, `InpHero_OrderCount=1`
2. เปิด initial BUY/SELL ตัวแรก → ไม่ควรมี Hero block ทันที
3. ราคาวิ่งผิดทาง → `GM1_GL#1` ต้องเปิดได้
4. ราคาวิ่งถูกทาง → `GM1_GP#1` ต้องเปิดได้
5. เมื่อ basket หลักถูก average trailing/TP ปิดและเหลือ Hero เท่านั้น:
   - ถ้า `InpHero_CloseWithOpposite=true` (label เดิม แต่ behavior คือ close same-side) → Hero ปิดตาม basket
   - ถ้า toggle ปิด → Hero ค้าง และ grid ฝั่งเดียวกันถูก block ตามสเปก
6. Journal ต้องเห็น log v6.94 ที่บอกจำนวน Hero และ non-Hero ชัดเจน