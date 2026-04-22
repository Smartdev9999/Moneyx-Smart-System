

## v6.59 — Fix: Sequential Release ไม่ block การสร้าง Cycle Generation ใหม่

### ปัญหาที่เจอ

จาก v6.58 logic ปัจจุบัน:

```cpp
g_seqAllowedGen = GetSequentialAllowedGeneration();
if(g_seqAllowedGen != -1 && g_seqAllowedGen != g_cycleGeneration)
   g_newOrderBlocked = true;  // ← block ทุก order รวมถึง initial entry ของ gen ใหม่
```

**Scenario ที่เกิด:**
1. Gen0 เปิดออเดอร์ → โดน hedge → `oldestHedge = 0` → `allowedGen = 0`
2. หลัง hedge เปิด → ระบบควรเริ่ม cycle ใหม่ (Gen1) เพื่อเทรดต่อ
3. แต่ `g_cycleGeneration` ยังเป็น 0 (หรือถูก increment เป็น 1)
4. `allowedGen (0) != g_cycleGeneration (1)` → `g_newOrderBlocked = true`
5. **ระบบ block ทุก initial entry → ไม่เปิดออเดอร์ใหม่อีกเลย**

ผลลัพธ์: ระบบหยุดเทรดถาวรจนกว่า Gen0 จะ recovery สำเร็จ — ขัดกับเจตนารมณ์ของผู้ใช้ที่ต้องการให้ระบบ **เทรดต่อเนื่อง** ขณะ recovery ทำทีละชุด

### เจตนารมณ์ที่ถูกต้อง

Sequential Release ควร gate **เฉพาะ recovery grid** (grid loss/profit ของ gen เก่าที่ติด hedge) — **ไม่ควร block initial entry ของ cycle generation ใหม่**

| Order Type | ก่อนแก้ (v6.58) | หลังแก้ (v6.59) |
|---|---|---|
| Initial entry (Gen ใหม่) | ❌ Block | ✅ Allow |
| Grid loss/profit (Gen ที่ allowed) | ✅ Allow | ✅ Allow |
| Grid loss/profit (Gen ที่ไม่ allowed) | ❌ Block | ❌ Block |
| Orphan grid (allowed gen) | ✅ Allow | ✅ Allow |
| Orphan grid (non-allowed) | ❌ Block | ❌ Block |
| Hedge orders | ✅ Allow | ✅ Allow |

### แผนแก้ไข — `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Version bump → v6.59

#### 2. ลบ global block ใน OnTick (line 1274–1276)

**ลบ:**
```cpp
g_seqAllowedGen = GetSequentialAllowedGeneration();
if(g_seqAllowedGen != -1 && g_seqAllowedGen != g_cycleGeneration)
   g_newOrderBlocked = true;
```

**แทนด้วย:** เก็บแค่การคำนวณ `g_seqAllowedGen` เพื่อใช้แสดง dashboard และเป็น reference สำหรับ guard เฉพาะจุด:
```cpp
g_seqAllowedGen = GetSequentialAllowedGeneration();
// Note: ไม่ตั้ง g_newOrderBlocked อีกต่อไป — gating ทำเฉพาะที่ grid recovery sites
```

#### 3. เพิ่ม gate เฉพาะจุดที่เปิด Grid Loss / Grid Profit ของ "existing generation" 

หาจุดที่ loop เปิด grid loss/profit สำหรับแต่ละ generation ที่มีอยู่ (ใน OnTick line ~1509–1660 ตามแผน v6.58 เดิม) แล้วเพิ่ม guard:

```cpp
// v6.59: Sequential Release — block grid recovery สำหรับ gen ที่ไม่ใช่ allowed
if(g_seqAllowedGen != -1 && currentGen != g_seqAllowedGen)
   continue;  // skip grid loss/profit ของ gen นี้
```

**ห้ามเพิ่ม guard นี้ในจุดที่เปิด initial entry ของ cycle gen ใหม่** — initial entry ต้องเปิดได้เสมอเพื่อให้ระบบเทรดต่อเนื่อง

#### 4. Orphan grid guard — คงเดิม (ใน `ManageOrphanGrid()` line 8661)

ไม่แก้ — ถูกต้องแล้ว เพราะ orphan = บาดแผลเก่าที่ต้อง recovery ทีละชุด

#### 5. Dashboard อัปเดต — แสดงข้อความให้ชัดเจน

```
Seq Release | ON | Allowed Recovery: Gen0 | New cycle entries: ALLOWED
Seq Release | ON | No active sets — full trading
Seq Release | OFF | Parallel recovery
```

### สิ่งที่ไม่เปลี่ยนแปลง

- Order Execution Logic (`trade.Buy/Sell/PositionClose`) — ไม่แก้
- Trading Strategy / Entry signals (SMA/EMA/ZigZag/Instant) — ไม่แก้
- Grid distance/lot calculation — ไม่แก้
- Hedge open / Triple Gate / Matching Close / BoundAvgTP / PartialClose — ไม่แก้
- Balance Guard / News / Time / License — ไม่แก้
- BB Filter (v6.56) — ไม่แก้ (ยัง block initial + grid ตามปกติ)
- v6.37–v6.58 features — ไม่แก้
- `GetSequentialAllowedGeneration()` helper — ไม่แก้
- `ManageOrphanGrid()` sequential gate — ไม่แก้

### ผลลัพธ์

- **เปิดออเดอร์ Gen0** → โดน hedge → Gen0 เข้าสู่ recovery mode (allowed = 0)
- **ระบบเปิด Gen1, Gen2, Gen3 ต่อได้ทันที** (initial entry ไม่ถูก block)
- Gen1/Gen2/Gen3 ก็โดน hedge → กลายเป็นชุด recovery รอคิว
- **Grid recovery** ทำงานเฉพาะ Gen0 เท่านั้น (ตามเจตนารมณ์เดิมของ Sequential Release)
- เมื่อ Gen0 เคลียร์หมด → allowed เลื่อนเป็น Gen1 → recovery Gen1 ต่อไป
- Trading ไม่หยุด — recovery ทำทีละชุดตามต้องการ

