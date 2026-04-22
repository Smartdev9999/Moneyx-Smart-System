

## v6.60 — Sequential Release by Comment Prefix (Generation-Number Based)

### แนวคิดใหม่ (ตามที่ user เสนอ)

แทนที่จะใช้ `g_seqAllowedGen` จาก hedge set index + orphan struct → เปลี่ยนมาใช้ **comment prefix matching** ตรงๆ ซึ่งเรียบง่ายและ deterministic กว่า

### การ Map Generation ↔ Comment

| Generation | Bound Comments | Hedge Comment |
|---|---|---|
| Gen 0 | `GM_*` (GM_GL, GM_GP, GM) | `GM_HD1` |
| Gen 1 | `GM1_*` | `GM_HD2` |
| Gen 2 | `GM2_*` | `GM_HD3` |
| Gen N | `GM{N}_*` | `GM_HD{N+1}` |

**ลำดับการปลด:** Gen 0 → Gen 1 → Gen 2 → ... → ไม่มีออเดอร์ → reset → เริ่มใหม่จาก Gen ปัจจุบัน

### Logic ใหม่: `GetSequentialAllowedGeneration()`

```cpp
// v6.60: Scan ออเดอร์จริงทุกตัวบน symbol/magic
// คืน generation ต่ำสุดที่ยังมีออเดอร์ใดๆ อยู่ (รวม bound + hedge ของ gen นั้น)
int GetSequentialAllowedGeneration()
{
   if(!InpHedge_SequentialRelease) return -1;
   
   int oldest = INT_MAX;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong tk = PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      
      string c = PositionGetString(POSITION_COMMENT);
      int gen = ParseGenerationFromComment(c);  // GM_*=0, GM1_*=1, GM_HD1=0, GM_HD2=1...
      if(gen >= 0 && gen < oldest) oldest = gen;
   }
   return (oldest == INT_MAX) ? -1 : oldest;
}
```

### Helper ใหม่: `ParseGenerationFromComment()`

```cpp
// "GM_GL#3" → 0, "GM" → 0, "GM_HD1" → 0
// "GM1_GP#2" → 1, "GM_HD2" → 1
// "GM5_GL#1" → 5, "GM_HD6" → 5
int ParseGenerationFromComment(string c)
{
   if(StringFind(c, "GM_HD") == 0)
      return (int)StringToInteger(StringSubstr(c, 5)) - 1;  // HD1→0
   if(StringFind(c, "GM_") == 0 || c == "GM") return 0;
   if(StringFind(c, "GM") == 0)
   {
      // "GM3_GL#1" → ตัด GM, อ่านเลขจนเจอ _
      int us = StringFind(c, "_", 2);
      string numStr = (us > 0) ? StringSubstr(c, 2, us - 2) : StringSubstr(c, 2);
      return (int)StringToInteger(numStr);
   }
   return -1;
}
```

### จุดที่ใช้ Gate (เหมือน v6.58/v6.59 แต่ logic แม่นกว่า)

1. **`ManageOrphanGrid()`** — skip orphan group ที่ generation ≠ allowed
2. **Grid Loss/Profit loop in OnTick** — skip currentGen ≠ allowed
3. **Hedge sets `ManageHedgeSets()`** — freeze set ที่ boundGeneration ≠ allowed (matching/avgTP/partial/grid)
4. **Initial entry** — ไม่ block (v6.59 logic คงไว้ → cycle ใหม่เปิดได้)

### ผลลัพธ์ตัวอย่าง

```text
ออเดอร์ที่มี: GM_GL#1, GM_GL#2, GM_HD1, GM1_GL#1, GM_HD2, GM2_GL#1, GM_HD3
              └────── Gen 0 ──────┘  └─── Gen 1 ───┘  └─── Gen 2 ───┘

Tick 1: oldest = 0 → allowed = Gen 0
        → Recovery ทำเฉพาะ GM_*, GM_HD1
        → Gen 1 (GM1_*, GM_HD2) freeze
        → Gen 2 (GM2_*, GM_HD3) freeze

Gen 0 ปิดหมด → tick ถัดไป oldest = 1 → allowed = Gen 1 → ทำต่อ
Gen 1 ปิดหมด → allowed = Gen 2 → ทำต่อ
Gen 2 ปิดหมด → allowed = -1 (ไม่มีออเดอร์เหลือ → reset) → cycle ใหม่เริ่ม Gen ปัจจุบัน
```

### ข้อดีของวิธี Comment-Based เทียบกับ v6.59

| | v6.59 (struct-based) | v6.60 (comment-based) |
|---|---|---|
| Source of truth | `g_hedgeSets[].active` + `g_orphanGroups[]` | ออเดอร์จริงบน server |
| EA restart | ขึ้นกับ persistence | ทำงานทันทีจาก scan |
| Race condition | Hedge deactivate → tick ถัดไป set ใหม่เริ่ม | ไม่มี — ตราบใดที่ comment Gen N ยังเหลือ |
| Logic complexity | ต้อง sync 3 sources | Single scan loop |

### ส่วนปัญหา Matching Close (รวม bound กำไรเข้า pool)

แก้ตามแผน v6.60 เดิม — `ManageHedgeMatchingClose()`:
- รวม `boundProfitPool` (bound counterSide ที่ pnl > 0) เข้า `totalBudgetProfit`
- ปิด profitable bound tickets หลังปิด reverse
- Log: `hedge $X + reverse $Y + boundProfit $Z covers N losses`

### แผนแก้ไข — `public/docs/mql5/Gold_Miner_EA.mq5`

1. **Version bump** → v6.60 (#property, header, dashboard)
2. **เพิ่ม helper** `ParseGenerationFromComment()`
3. **แทนที่ `GetSequentialAllowedGeneration()`** ด้วย version comment-scan
4. **ลบ** การพึ่ง `GetOldestActiveHedgeSetIndex()` + orphan struct scan ใน gate (helper เดิมคงไว้สำหรับ dashboard)
5. **แก้ `ManageHedgeSets()`** — `seqFreeze` คำนวณจาก `boundGeneration vs g_seqAllowedGen` แทน slot index
6. **แก้ `ManageHedgeMatchingClose()`** — รวม bound profit + ปิด profitable bound (จากแผนเดิม)
7. **`ManageOrphanGrid()` + grid loops** — gate logic เหมือนเดิม (ใช้ `g_seqAllowedGen` ค่าใหม่)
8. **Dashboard**: `Seq Release | ON | Allowed: Gen0 (GM_*+GM_HD1) | Frozen: Gen1, Gen2`
9. **อัปเดต** `.lovable/plan.md` + memory note

### สิ่งที่ไม่เปลี่ยนแปลง

- Order Execution (`trade.Buy/Sell/PositionClose`) — ไม่แก้
- Trading Strategy / Entry signals / Grid distance / Lot calc — ไม่แก้
- License / News / Time / Data Sync — ไม่แก้
- Triple Gate / Hedge open trigger — ไม่แก้
- Balance Guard / BB Filter — ไม่แก้
- Initial entry ของ cycle gen ใหม่ (v6.59) — ไม่แก้
- Comment structure (v6.50) — ไม่แก้ (อ่านอย่างเดียว)
- Hedge slot persistence (v6.68) — ไม่แก้
- v6.37–v6.59 features — ไม่แก้

### ผลลัพธ์รวม

- **Issue #1 (Matching Close)**: รวม bound กำไร → ปิดทั้งชุดสมดุล
- **Issue #2 (Sequential Recovery)**: comment-based scan → guarantee ปลดทีละ generation จากเลขต่ำ→สูง → reset เมื่อหมด → เริ่มใหม่
- `InpHedge_SequentialRelease = false` → behavior เดิม 100%

