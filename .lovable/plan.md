

## รีเซ็ต Comment Generation เมื่อ Order เคลียร์หมด — Gold Miner SQ EA (v6.0 → v6.1)

### ปัญหา

เมื่อ order ทั้งหมดถูกปิดหมดแล้ว `g_cycleGeneration` ยังค้างค่าเดิม (เช่น 3) → order ชุดใหม่ใช้ comment `GM3_INIT`, `GM3_GL#1` แทนที่จะกลับมาเป็น `GM_INIT`, `GM_GL#1`

### การแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. เพิ่ม reset `g_cycleGeneration = 0` ที่จุด "all positions cleared"

มี 2 จุดที่เช็ค `g_hadPositions && currentCount == 0`:

| จุด | Line | เพิ่ม |
|---|---|---|
| Accumulate reset (SMA/Instant mode) | ~1758 | `g_cycleGeneration = 0;` |
| Accumulate reset (ZigZag mode) | ~3996 | `g_cycleGeneration = 0;` |

เพิ่มเงื่อนไขตรวจสอบว่าไม่มี hedge set active ด้วย:
```cpp
if(g_hadPositions && currentCount == 0)
{
   // Reset cycle generation — no positions left, start fresh
   if(g_hedgeSetCount == 0 && g_cycleGeneration > 0)
   {
      g_cycleGeneration = 0;
      Print("CYCLE GENERATION reset to 0 — all positions cleared");
   }
   // ... existing accumulate reset code ...
}
```

#### 2. เพิ่ม standalone reset สำหรับกรณีไม่ใช้ AccumulateClose

กรณี `UseAccumulateClose = false` → block ด้านบนไม่ทำงาน → ต้องเพิ่ม check แยกต่างหากใน `OnTick()` หลัง `CountPositions()`:

```cpp
// Reset cycle generation when all positions cleared (regardless of AccumulateClose setting)
if(g_hadPositions && buyCount == 0 && sellCount == 0 && g_hedgeSetCount == 0 && g_cycleGeneration > 0)
{
   g_cycleGeneration = 0;
   Print("CYCLE GENERATION reset to 0 — all positions cleared");
}
```

#### 3. Version bump: v6.0 → v6.1

### ผลลัพธ์
- Order เคลียร์หมด + ไม่มี hedge set → `g_cycleGeneration = 0` → order ใหม่กลับมาเป็น `GM_INIT`, `GM_GL#1`
- ยังมี hedge set active → ไม่ reset (ป้องกัน comment ชน)

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic, Trading Strategy Logic, Core Module Logic
- Hedge system logic ทั้งหมด
- Comment Generation logic ตอน hedge เปิด (ยัง increment ตามปกติ)

