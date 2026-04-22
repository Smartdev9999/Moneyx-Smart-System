

## v6.72 — AVERAGE_TP เป็น Stage 2 (ทำงานหลัง Matching Close ปลดล็อค Hedge แล้ว)

### ปัญหา (image-913 / image-914)

ตอนนี้เลือก `InpRecovery_CloseMode = AVERAGE_TP` แล้วระบบ **ข้าม Matching Close ทั้งหมด** ตั้งแต่แรก → hedge หลัก (`GM_HEDGE_1`, `GM_HEDGE_2`) ไม่เคยถูกซอยปิดเลย → ค้างอยู่กับ Loss ก้อนใหญ่ (-$721, -$9971) ทั้งที่ Triple Gate ผ่านแล้ว (`Cy:Ready Z:OUT OK`)

**สาเหตุ**: บรรทัด 10084-10094 — เจอ AVG_TP mode → เรียก `ManageRecoveryAvgTP()` แล้ว `continue` ทันที → flow `ManageHedgeMatchingClose` / `ManageHedgePartialClose` ไม่เคยรัน

### ความเข้าใจถูกต้องของ user
AVG_TP เป็น **stage 2** ไม่ใช่ replacement:

```
Stage 1: Matching Close (ซอยปิด hedge หลักด้วย profit pool)
   ↓ เมื่อ hedge หลักถูก close หมด (hedgeTicket==0) แต่ยังเหลือ bound + recovery grid
Stage 2: AVERAGE_TP — รวม bound+recovery หาค่าเฉลี่ย แล้วตั้ง broker TP +N points
```

---

## แผนแก้ไข — `public/docs/mql5/Gold_Miner_EA.mq5`

### 1) Version bump → v6.72
อัปเดต `#property version`, description, header, init log, dashboard label

### 2) ย้าย AVG_TP block ออกจากตำแหน่งปัจจุบัน (บรรทัด 10084-10094)
ลบ block ที่ skip matching ออกทั้งหมด

### 3) เพิ่ม AVG_TP เป็น **stage 2 หลัง matching** 
ใน `ManageHedgeSets()` ต่อ set — flow ใหม่:

```cpp
// STAGE 1: Matching Close (เดิม v6.71) — ทำงานปกติทุก tick
//   - ManageHedgeMatchingClose / ManageHedgeBoundAvgTP / ManageHedgePartialClose
//   - ซอยปิด hedge หลักด้วย profit pool

// STAGE 2 (ใหม่ v6.72): AVG_TP กระตุ้นเมื่อ
//   (a) InpRecovery_CloseMode == RECOVERY_CLOSE_AVG_TP
//   (b) hedge หลักถูกปลดแล้ว: hedgeTicket==0 หรือ !PositionSelectByTicket(hedgeTicket)
//   (c) มี recovery grid อย่างน้อย 1 ตัว (recoveryGridCount > 0 หรือ comment-match GM_HD<gen>_*)
//   (d) ยังเหลือ bound tickets หรือตั๋วลอย
if(InpRecovery_CloseMode == RECOVERY_CLOSE_AVG_TP)
{
   bool hedgeReleased = (g_hedgeSets[h].hedgeTicket == 0 
                         || !PositionSelectByTicket(g_hedgeSets[h].hedgeTicket));
   int recoveryCount = CountHedgeGridOrders(h);   // ใช้ helper เดิม v6.69
   if(hedgeReleased && recoveryCount > 0)
   {
      ManageRecoveryAvgTP(h);   // ตั้ง broker TP บน basket ที่เหลือ
   }
}
```

วาง block นี้ **หลัง** matching/partial block ของ set (หลังจุดที่ matchingDone อาจถูกเซ็ต) — ก่อน grid expansion check

### 4) `ManageRecoveryAvgTP()` — ปรับ basket ให้ตรง stage 2
- รวมเฉพาะตั๋วที่ยังเหลือจริง: `boundTickets[]` ที่ยัง select ได้ + recovery grid (comment + ticket array) — ไม่รวม hedge หลักเพราะถูกปิดไปแล้ว
- คำนวณ weighted avg net side
- Net BUY → TP = avg + `InpRecovery_AvgTPDistance * point`
- Net SELL → TP = avg − distance
- `trade.PositionModify` ทุกตั๋ว (skip ถ้า TP ห่างจากเดิม < 1 point)
- Log:
  ```
  v6.72 AVGTP-S2 Set#1 Gen0: bounds=2 recovery=4 net=BUY 0.27L avg=4892.30 TP=4897.30 modified=6/6
  ```

### 5) Dashboard
เปลี่ยนข้อความให้สะท้อน 2-stage:
```
Recovery Mode : MATCHING+AVGTP (dist=500p)   ← เมื่อเลือก AVG_TP mode
Recovery Mode : MATCHING_CLOSE                ← เมื่อเลือก MATCHING mode
```
Per-set status:
```
Set#1 Stage: MATCHING (hedge active)
Set#1 Stage: AVGTP-S2 (hedge released, basket TP=4897.30)
```

### 6) MinSpacing v6.71 — คงเดิม ไม่แก้

### 7) Validation Checklist
1. `InpRecovery_CloseMode = MATCHING` → flow เดิม v6.71 (regression OK)
2. `InpRecovery_CloseMode = AVG_TP` + hedge ยัง active → matching ทำงานปกติ ซอยปิดต่อเนื่อง (เหมือน MATCHING)
3. หลัง matching ปลดปิด hedge หลัก (`hedgeTicket==0`) แล้วมี recovery grid เปิด → AVG_TP เริ่ม set broker TP บนทุกตั๋วที่เหลือ
4. ราคาแตะ TP → broker ปิด basket พร้อมกัน → flat → `ForceResetCycleState`
5. ภาพ image-914: Set#2 (`GM_HEDGE_2 -$9977`) — matching จะรันได้ปกติ ไม่ถูก skip อีก
6. ถ้า hedge ปลดแล้วแต่ยังไม่มี recovery grid → AVG_TP ไม่ทำงาน รอ grid expansion
7. Restart EA ระหว่าง stage 2 → recover state, AVG_TP คำนวณใหม่จากตั๋วที่ยังลอย

---

## สิ่งที่ไม่เปลี่ยนแปลง

- Order Execution (`OrderSend`, `trade.Buy/Sell/PositionClose/PositionClosePartial/PositionModify`) — ไม่แก้
- Trading Strategy / Initial / Grid Loss / Grid Profit — ไม่แก้
- Hedge open trigger (Expansion / DD% / DD$) + MinSpacing v6.71 — ไม่แก้
- Triple Gate exit / Matching Close pool / Partial Hedge fallback v6.64 — ไม่แก้
- Reverse-Walk Seed v6.66 / Combined TP / Unified Recovery v6.67 — ไม่แก้
- Gen-Locked Slot v6.68 / New-Candle Gate v6.69 / GM1-Start + HardFlatReset v6.70 — ไม่แก้
- BB Filter / Sequential Recovery Owner / Strict In-Set Pool / Hedge Side Pause — ไม่แก้
- News / License / Time Filter / Sync / Balance Guard — ไม่แก้
- `InpHedge_UseMatchingClose` master toggle — ไม่แก้
- `ManageRecoveryAvgTP()` formula — คงเดิม แค่เปลี่ยน trigger condition

