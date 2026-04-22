

## v6.69 — Recovery Grid: New-Candle Gate + Comment Format Fix + Ticket-Based Binding + Combined TP for Floaters

### ปัญหา (จาก image-904, 905, 906)

1. **Hedge ออกรัวๆ** — Recovery grid ไม่มี new-candle gate → เปิดติดกันใน tick เดียวกัน (รูป 904 เห็นกระจุก)
2. **Max Grid ไม่นับครบ** — ออเดอร์ที่ comment ว่าง (`""`) จาก partial-close ไม่ถูกนับ → cap เพี้ยน หยุดก่อนถึงค่าที่ตั้ง
3. **Avg TP ไม่รวมตัวลอย** — ตั๋วที่ comment หาย (เช่น 1866 sell 0.01 ในรูป 905) ไม่ถูกใส่ใน `SyncRecoveryBasketTP` → TP ไม่สะท้อนน้ำหนักจริง
4. **Comment สับสน** — `GM_HEDGE_2 ↔ Gen1 (GM1)` อ่านยาก user อยากให้เห็น `GM_HD1_01` ผูก `GM1` ตรงๆ

### ความต้องการของ user
1. เพิ่ม **New Candle Only** สำหรับ Recovery Grid (input ใหม่)
2. **Bind 2 ทาง**: comment **และ** ticket — ถ้า comment หายให้ใช้ ticket bound list
3. นับ/รวม TP ทุกตั๋วที่ผูกกับ set แม้ comment ว่าง
4. เปลี่ยน format → `GM_HD<gen>_<seq>` (เช่น Gen1 → `GM_HD1_01`)

---

## แผนแก้ไข — `public/docs/mql5/Gold_Miner_EA.mq5`

### 1) Version bump → v6.69
อัปเดต `#property version`, header, init/deinit log, Dashboard label

### 2) Input ใหม่: New Candle Only สำหรับ Recovery Grid
```cpp
input bool Recovery_OnlyNewCandle = true;   // v6.69: 1 grid order per new bar
```
วางในกลุ่ม **Recovery Grid (Bound/Orphan Orders)** ใต้ `Recovery_CandleConfirm`

### 3) Gate ตอนเปิด Recovery Grid

เพิ่ม global tracker:
```cpp
datetime g_lastRecoveryGridBarTime[MAX_HEDGE_SETS];   // per-set bar time
datetime g_lastOrphanRecoveryBarTime;                  // orphan path
```

ใน **`ManageHedgeGridMode(idx)`** ก่อน open grid order (รอบ ~บรรทัด 10998 ก่อน `OpenOrder`):
```cpp
if(Recovery_OnlyNewCandle)
{
   datetime curBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(curBar == g_lastRecoveryGridBarTime[idx]) return;
}
...
if(OpenOrder(...))
{
   g_lastRecoveryGridBarTime[idx] = iTime(_Symbol, PERIOD_CURRENT, 0);
   ...
}
```

ใน **`ManageOrphanGrid()`** ใช้ `g_lastOrphanGridCandleTime` ที่มีอยู่แล้ว แต่บังคับใช้เมื่อ `Recovery_OnlyNewCandle=true` (ปัจจุบัน gate แค่ `GridLoss_OnlyNewCandle` — เพิ่ม OR กับตัวใหม่)

### 4) เปลี่ยน Comment Format → `GM_HD<gen>_<seq>`

แก้จุดสร้าง comment ใน `ManageHedgeGridMode` (บรรทัด 11002):
```cpp
int gen = g_hedgeSets[idx].boundGeneration;
string comment = "GM_HD" + IntegerToString(gen) + "_" 
               + StringFormat("%02d", currentGridCount + 1);
// เช่น Gen1 lvl 1 → GM_HD1_01
```

แก้ `ManageOrphanGrid()` (บรรทัด 9341, 9412):
```cpp
string comment = "GM_HD" + IntegerToString(gen) + "_" 
               + StringFormat("%02d", nextLevel);
```

**Backward compat**: ทุกที่ที่ scan `"GM_HG"` ให้เพิ่มการ match `"GM_HD"` ด้วย ผ่าน helper:
```cpp
bool IsRecoveryGridComment(const string c)
{
   return (StringFind(c, "GM_HG") >= 0 || StringFind(c, "GM_HD") >= 0);
}
```
เปลี่ยนใน: `CountHedgeGridOrders`, `SyncRecoveryBasketTP`, `ManageHedgeGridMode` (count + cleanup), `RecoverHedgeSetsFromOpenPositions` (orphan cleanup), `ManageMatchingClose` skip-list (บรรทัด 11056), `IsHedgeComment` (บรรทัด 7395)

**Match-by-set**: helper เพิ่ม:
```cpp
bool IsRecoveryGridForSet(const string c, int idx, int gen)
{
   if(StringFind(c, "GM_HG" + IntegerToString(idx + 1)) >= 0) return true;  // legacy
   if(StringFind(c, "GM_HD" + IntegerToString(gen) + "_") >= 0) return true; // new
   return false;
}
```

### 5) Ticket-Based Binding Fallback (comment-less recoveries)

เพิ่ม persistent grid-ticket list ต่อ set:
```cpp
struct HedgeSet {
   ...
   ulong  recoveryGridTickets[];   // v6.69: tickets opened as recovery grid for this set
   int    recoveryGridCount;
};
```

ทุกครั้งที่เปิด recovery grid สำเร็จ (`ManageHedgeGridMode` + `ManageOrphanGrid`):
```cpp
int rc = g_hedgeSets[idx].recoveryGridCount;
ArrayResize(g_hedgeSets[idx].recoveryGridTickets, rc + 1);
g_hedgeSets[idx].recoveryGridTickets[rc] = newTicket;
g_hedgeSets[idx].recoveryGridCount = rc + 1;
GlobalVariableSet("GME_REC_TK_" + IntegerToString(idx) + "_" + IntegerToString(rc), (double)newTicket);
```

**Cleanup**: ตอน iterate ถ้า `PositionSelectByTicket(tk)` คืน false (ปิดไปแล้ว) → ตัดออกจาก array

**ใช้ใน `SyncRecoveryBasketTP`**:
- เริ่มจาก main hedge ticket
- Union 2 แหล่ง: (a) scan comment `IsRecoveryGridForSet` (b) walk `recoveryGridTickets[]`
- Dedupe ด้วย ticket

**ใช้ใน `CountHedgeGridOrders(idx)`**:
- นับ comment-match + ticket ที่ยัง `PositionSelectByTicket` ได้แต่ comment ว่าง
- Dedupe → ค่าจริง = max grid cap ทำงานถูก

**Recovery จาก restart** (`RecoverHedgeSetsFromOpenPositions`):
- หลัง bind จาก comment เสร็จ อ่าน `GME_REC_TK_<slot>_*` กลับเข้า `recoveryGridTickets[]`
- ตั๋วที่ปิดไปแล้ว → ลบ GV ออก

### 6) Bound List ใส่ตั๋วที่ comment ว่าง (legacy floaters)

ใน `RecoverHedgeSetsFromOpenPositions` step bind:
- ถ้าเจอ position ที่ `comment == ""` และ MAGIC ตรง — ผูกเข้า `boundTickets[]` ของ slot ที่ `boundGeneration` ตรงกับ gen ของไม้นั้น (อนุมานจาก timestamp: เก่ากว่า hedge.openTime ของ slot นั้น)
- ถ้า ambiguous → ผูกกับ slot ที่ `boundGeneration < g_cycleGeneration` ตัวที่อายุใกล้เคียงที่สุด + log warning

### 7) Dashboard / Logging
```text
Recovery Grid | NewCandle:ON Auto:ON | H1 lvl=3/10 next=GM_HD1_04
v6.69 SKIP NEW-CANDLE Set#2: same bar
v6.69 BIND TICKET Set#1: tk=1866 (comment empty) → boundGen=1
v6.69 COUNT Set#1: comment=4 + ticketOnly=1 = 5/10
v6.69 COMBINED TP Set#1: tickets=6 (incl 1 floater) avg=4955.32
```

### 8) Migration หมายเหตุ
- Comment เก่า `GM_HG1_GL1` ยังถูก scan/manage ผ่าน `IsRecoveryGridComment` — ไม่ break running EA
- New ออเดอร์หลัง update ใช้ `GM_HD<gen>_<NN>` format
- GVs `GME_REC_TK_*` สร้างใหม่ ไม่กระทบ `GME_HEDGE_TICKET_*` / `GME_HEDGE_SHRED_*` เดิม

---

## สิ่งที่ไม่เปลี่ยนแปลง

- Order Execution (`OrderSend` / `trade.Buy/Sell/PositionClose/PositionClosePartial`) — ไม่แก้
- Trading Strategy / Signal / Initial Grid / Grid Loss / Grid Profit (basket หลัก) — ไม่แก้
- Hedge open trigger (Expansion / DD% / Dollar) — ไม่แก้
- Triple Gate exit (Cycle/Zone/Distance) — ไม่แก้
- Reverse-Walk Seed v6.66 / One-Time Shred / MaxGridTrades algorithm — ไม่แก้ (แค่ fix การนับ)
- Combined Avg TP formula v6.66 — ไม่แก้ (แค่ขยาย source ของ tickets)
- Unified Recovery params v6.67 — ไม่แก้
- Generation-Locked Hedge Slot v6.68 — ไม่แก้
- Strict Sequential Matching v6.65 / Sequential Recovery Owner v6.59-v6.60 — ไม่แก้
- BB Filter / Recovery distance / Re-hedge guard / Hedge Side Pause — ไม่แก้
- Accumulate Close / Balance Guard / News / License / Time Filter — ไม่แก้
- `GM_HEDGE_<N>` main hedge comment format — ไม่แก้ (เปลี่ยนแค่ recovery grid `GM_HG → GM_HD`)

## Validation Checklist

1. `Recovery_OnlyNewCandle=true`: recovery grid เปิดได้ 1 ไม้/แท่ง/set; แท่งเดียวกัน trigger 2 รอบ → log "SKIP NEW-CANDLE"
2. `Recovery_OnlyNewCandle=false`: regression เหมือน v6.68 (เปิดได้หลายไม้/แท่ง)
3. Set#1 (Gen1) เปิด recovery → comment = `GM_HD1_01`, `GM_HD1_02`, ...
4. Position ที่ comment ว่าง + MAGIC ตรง → ถูก bind เข้า set ที่ใกล้สุด + รวมใน Combined TP
5. `Recovery_MaxGridTrades=10` → นับ comment + ticket-only ครบ 10 ค่อย stop (ไม่หยุดที่ 4-5 เพราะ comment หาย)
6. Restart EA: `GME_REC_TK_*` โหลดกลับ → `recoveryGridTickets[]` ครบ → matching/TP ต่อเนื่อง
7. Order เก่า `GM_HG1_GL1` ยัง float อยู่ตอน update → ถูก scan ตามเดิมผ่าน `IsRecoveryGridComment`
8. Dashboard แสดง `next=GM_HD<gen>_<NN>` สอดคล้อง gen ของ set

