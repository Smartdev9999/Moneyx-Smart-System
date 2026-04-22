

## v6.61 — Sequential Gate ใช้ Hedge Comments เท่านั้น (ไม่นับ Bound)

### ปัญหาที่เจอ (จาก screenshot v6.60)

Dashboard: `Allowed: Gen0 (GM_*+GM_HD1)` แต่ **ไม่มี Hedge #1 อยู่แล้ว** (Hedge แสดง #2-#6) → แปลว่า hedge Gen 0 ปิดไปแล้ว แต่ allowed ยังค้างที่ 0 → Set#2-#6 freeze ทั้งหมด → ระบบหยุด

### Root Cause

`GetSequentialAllowedGeneration()` v6.60 scan **ทั้ง bound + hedge orders** → คืน lowest gen ที่ยังมีออเดอร์ใดๆ

หลัง `ManageHedgeMatchingClose()` ปิด Set#1 (Gen 0):
- Hedge `GM_HD1` ปิด ✓
- Reverse + profitable bound ปิด ✓
- **Bound loss orders (`GM`, `GM_GL#*`) ถูก release ไม่ปิด** (v6.55 logic)
- → `GM_GL#*` ยังเหลือ → ParseGen = 0 → allowed ค้างที่ 0 ตลอดไป
- → Set#2 (Gen 1) ถูก freeze ค้าง รอจน Gen 0 orphans recover เสร็จ (อาจไม่มีวันจบ)

แต่ตามเจตนารมณ์ของ user: **"ปลดทีละชุด hedging"** = นับเฉพาะ hedge ที่ active ไม่ใช่ recovery ของ orphan

### แก้ไข — สแกนเฉพาะ hedge comments

```cpp
int GetSequentialAllowedGeneration()
{
   if(!InpHedge_SequentialRelease) return -1;
   int oldest = INT_MAX;
   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;

      string c = PositionGetString(POSITION_COMMENT);
      // v6.61: Count ONLY hedge comments (GM_HD<n>) — bound/orphan orders never gate
      if(StringFind(c, "GM_HD") != 0) continue;
      int gen = ParseGenerationFromComment(c);   // GM_HD1→0, GM_HD2→1, etc.
      if(gen >= 0 && gen < oldest) oldest = gen;
   }
   return (oldest == INT_MAX) ? -1 : oldest;
}
```

### พฤติกรรมใหม่

| สถานการณ์ | allowed | Set ที่ทำงาน |
|---|---|---|
| Hedge #1 (Gen 0) + #2 (Gen 1) active | 0 | Set#1 only |
| Set#1 ปิด → orphan Gen 0 + Hedge #2 (Gen 1) | 1 | **Set#2 ทำงานทันที** ✓ |
| Hedge #2 ปิด → Hedge #3 (Gen 2) | 2 | Set#3 ต่อ |
| ไม่มี hedge เหลือ (เหลือแต่ orphan) | -1 | ไม่ block ใคร |

→ **Orphan ของ generation เก่าจะ recover พร้อมกันแยก** ผ่าน `ManageOrphanGrid()` ซึ่งมี gate ของตัวเอง — ไม่บล็อก hedge sets ใหม่

### ผลกระทบต่อ ManageOrphanGrid (line 8709)

`ManageOrphanGrid()` ก็เรียก `GetSequentialAllowedGeneration()` → ค่าจะเป็น "lowest hedge gen" → orphan Gen N ที่ < lowest hedge gen จะ recover ได้ (ไม่มี hedge ที่บล็อก) → orphan Gen ≥ lowest hedge gen ก็ recover ได้ถ้า == allowed

เพื่อความชัดเจน: orphan ที่ไม่มี hedge ผูกอยู่แล้ว ควร recover ได้เสมอ → เพิ่ม guard:

```cpp
// v6.61 in ManageOrphanGrid loop:
// orphan generations have no live hedge by definition → allow if seqAllowed == -1
// or if orphan.gen <= seqAllowed (older or equal to oldest active hedge gen)
if(seqAllowed != -1 && gen > seqAllowed) continue;
```

= orphan เก่ากว่าหรือเท่ากับ oldest active hedge gen → recover ได้ (เพราะไม่ติด queue ใหม่)
= orphan ใหม่กว่า oldest hedge → freeze (เพราะ hedge เก่ากว่ายังไม่จบ)

### Dashboard อัปเดต

```
Seq Release | ON | Allowed Hedge: GenN (GM_HD(N+1)) | New cycles: ALLOWED | Frozen Hedge: X
Seq Release | ON | No active hedge — full trading + free orphan recovery
```

### แผนแก้ไข — `public/docs/mql5/Gold_Miner_EA.mq5`

1. **Version bump** → v6.61 (`#property version`, header, dashboard)
2. **แก้ `GetSequentialAllowedGeneration()`** — เพิ่ม filter `if(StringFind(c, "GM_HD") != 0) continue;`
3. **แก้ `ManageOrphanGrid()` gate** — เปลี่ยนจาก `gen != seqAllowed` เป็น `gen > seqAllowed` (อนุญาต orphan ที่เก่ากว่าหรือเท่ากับ active hedge)
4. **แก้ Dashboard text** — แสดง "Allowed Hedge: GenN" แทน "Allowed: GenN"
5. **อัปเดต** `.lovable/plan.md` + memory note `mem://trading/gold-miner-ea/sequential-hedge-only-v6-61`

### สิ่งที่ไม่เปลี่ยนแปลง

- Order Execution Logic — ไม่แก้
- Trading Strategy / Entry signals / Grid distance / Lot calc — ไม่แก้
- License / News / Time / Data Sync — ไม่แก้
- Triple Gate / Hedge open trigger / Matching Close pool (v6.60) — ไม่แก้
- Balance Guard / BB Filter — ไม่แก้
- Initial entry ของ cycle gen ใหม่ (v6.59) — ไม่แก้
- `ParseGenerationFromComment()` helper — ไม่แก้
- `ManageHedgeSets()` freeze logic — ไม่แก้ (ใช้ค่า `g_seqAllowedGen` ใหม่อัตโนมัติ)
- v6.37–v6.60 features — ไม่แก้

### ผลลัพธ์

- Set#1 (Gen 0) matching close → bound loss release เป็น orphan → **allowed เลื่อนเป็น Gen 1 ทันที**
- Set#2 active เริ่ม recovery (matching/grid)
- Orphan Gen 0 recover ขนานไปด้วย (ไม่บล็อก hedge ใหม่)
- เลื่อนไปเรื่อยๆ จนหมด hedge → allowed = -1 → ระบบรอ cycle ใหม่
- `InpHedge_SequentialRelease = false` → behavior เดิม 100%

