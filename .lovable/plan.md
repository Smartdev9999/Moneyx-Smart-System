

## v6.73 — Recovery Orphan Cleanup + Comment Sequence Fix + AVG_TP Includes Released Hedge Residue

### ปัญหาจาก image-915

```
Tickets 1744-1749: 6 ตัว SELL @ lot 0.26 พร้อมกัน
Comment ซ้ำหมด:  GM_HD3_05 (x6 ตัว!)
TP = 0.00 ทุกตัว (ไม่มี broker TP)
Time: 15:51 → 15:55 (M1 chart, 1 ตัว/นาที)

ขณะเดียวกัน account ก็ขึ้น GM3, GM4 ต่อเนื่อง
แสดงว่า g_cycleGeneration ไม่ reset แม้จะดูเหมือน flat
```

3 bug ที่เจอจริง:

1. **Recovery comment sequence ค้าง** → `_05` ซ้ำ 6 ตัว
   - `currentGridCount = CountHedgeGridOrders(idx)` ใช้เป็นเลข suffix
   - แต่ฟังก์ชันนี้นับเฉพาะ ticket ที่ `IsRecoveryGridForSet(comment, idx, boundGeneration)` ผ่าน
   - หาก boundGeneration shift หรือ comment ของ ticket ก่อนหน้าถูก clear (partial close) → count ไม่เพิ่ม → suffix ค้างที่ค่าเดิมตลอด

2. **Recovery orders ถูกทิ้งเป็น orphan หลัง hedge fully released**
   - line 11352-11382: เมื่อ main hedge หมด → set ถูกปิด `active=false`, `g_hedgeSetCount--`
   - block พยายาม `PositionClose` recovery ตัวที่เหลือ — แต่ถ้า close ไม่สำเร็จ (slippage/requote) → ตั๋วลอยต่อ
   - หลังจากนี้ไม่มี code path ใดจัดการ orphan เหล่านี้อีก
   - ผลลัพธ์: 6 ตัว `GM_HD3_05` ลอยถาวร, ไม่มี TP, ไม่ถูก close, block ไม่ให้ `g_cycleGeneration` reset (เพราะ `TotalOrderCount() > 0`)

3. **AVG_TP Stage 2 ไม่ครอบคลุม partial-close residue ของ hedge**
   - `ManageRecoveryAvgTP` รวม: hedgeTicket + boundTickets + recoveryGridTickets + comment-match `GM_HD<gen>_*`
   - **ไม่รวม residue ตั๋วที่เกิดจาก partial close** ของ main hedge (comment ว่าง/ถูก strip, ไม่อยู่ใน boundTickets[], ไม่อยู่ใน recoveryGridTickets[])
   - ตั๋ว residue ฝั่ง hedge เลยลอยอยู่นอก basket → TP คำนวณไม่ครบ
   - User เห็นว่า "TP recovery กับ hedge residue ไม่ใช่จุดเดียวกัน"

---

## แผนแก้ไข — `public/docs/mql5/Gold_Miner_EA.mq5`

### 1) Version bump → v6.73
อัปเดต `#property version`, description, header, init log, dashboard label

### 2) Fix duplicate recovery comment (`GM_HD3_05` ซ้ำ)

ใน `ManageHedgeGridMode(idx)` บรรทัด 11515-11517 — เปลี่ยนวิธีกำหนด suffix:

```cpp
// v6.73: Use monotonic counter from per-set bookkeeping (never duplicates)
int seqNo = g_hedgeSets[idx].recoveryGridCount + 1;   // total ever opened (recoveryGridCount only grows on track)

// safety: collision check — if any existing position carries this comment, bump until unique
int gen = g_hedgeSets[idx].boundGeneration;
string baseLabel = "GM_HD" + IntegerToString(GenLabel(gen)) + "_";
while(true)
{
   string testComment = baseLabel + StringFormat("%02d", seqNo);
   bool collision = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetString(POSITION_COMMENT) == testComment) { collision = true; break; }
   }
   if(!collision) break;
   seqNo++;
   if(seqNo > 999) return;  // sanity
}
string comment = baseLabel + StringFormat("%02d", seqNo);
```

ใช้ `recoveryGridCount` (เพิ่มทุกครั้งที่ track ticket ใหม่ — ไม่ลดเมื่อ partial close) เป็นแหล่งความจริงเดียวสำหรับ suffix และมี collision-guard

### 3) ต่ออายุ set จนกว่า recovery orphan จะหมดจริง

ใน block `if(!mainHedgeExists)` (line 11352-11382) — ก่อน `g_hedgeSets[idx].active = false`:

```cpp
// v6.73: Verify all recovery grid orders actually closed before deactivating set.
//        Otherwise leftover orphans will lose all management.
int stillOpen = 0;
int rgGenC2 = g_hedgeSets[idx].boundGeneration;
for(int i = PositionsTotal() - 1; i >= 0; i--)
{
   ulong tk = PositionGetTicket(i);
   if(tk == 0) continue;
   if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
   if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
   string c = PositionGetString(POSITION_COMMENT);
   bool isOurs = IsRecoveryGridForSet(c, idx, rgGenC2);
   if(!isOurs)
      for(int k = 0; k < g_hedgeSets[idx].recoveryGridCount; k++)
         if(g_hedgeSets[idx].recoveryGridTickets[k] == tk) { isOurs = true; break; }
   if(isOurs) stillOpen++;
}

if(stillOpen > 0)
{
   // Don't deactivate yet — switch set into "AVGTP-S2 only" mode and let TP do the closing
   static datetime s_lastOrphanLog = 0;
   if(TimeCurrent() - s_lastOrphanLog >= 60)
   {
      Print("v6.73 KEEP-ALIVE Set#", idx+1, " Gen", rgGenC2,
            ": hedge fully closed but ", stillOpen, " recovery orphans remain — managing via Stage 2 TP");
      s_lastOrphanLog = TimeCurrent();
   }
   // Also force-sync TP immediately so orphans get a target on this tick
   if(InpRecovery_CloseMode == RECOVERY_CLOSE_AVG_TP) ManageRecoveryAvgTP(idx);
   else                                                SyncRecoveryBasketTP(idx);
   return;
}

// safe to deactivate — no orphans left
```

ผลลัพธ์: ตั๋ว 1744-1749 ที่ปิดไม่ได้จะถูก keep-alive และจัดการต่อด้วย AVG_TP จนปิดครบจริง

### 4) AVG_TP Stage 2 รวม partial-close hedge residue

ใน `ManageRecoveryAvgTP(idx)` หลัง section 4 (comment-match) — เพิ่ม section 5:

```cpp
// 5) v6.73: Catch hedge-side residue from partial closes
//          (tickets with empty/stripped comment that match hedge side + magic + symbol,
//           opened around hedge entry time, not in any other set's bookkeeping)
ENUM_POSITION_TYPE hSide = g_hedgeSets[idx].hedgeSide;
int targetGenLabel = GenLabel(g_hedgeSets[idx].boundGeneration);
for(int i = PositionsTotal() - 1; i >= 0; i--)
{
   ulong tk = PositionGetTicket(i);
   if(tk == 0) continue;
   if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
   if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
   string cmt = PositionGetString(POSITION_COMMENT);
   ENUM_POSITION_TYPE pType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   if(pType != hSide) continue;                          // residue is same side as original hedge
   // skip if explicitly tagged for another set
   if(StringFind(cmt, "GM_HEDGE_") >= 0 || StringFind(cmt, "GM_HD") >= 0 || StringFind(cmt, "GM_HG") >= 0)
   {
      if(IsRecoveryGridForSet(cmt, idx, g_hedgeSets[idx].boundGeneration)) {/* will already be added */}
      else continue;  // belongs to a different set
   }
   // dedup
   bool dup = false;
   for(int z = 0; z < cnt; z++) if(tks[z] == tk) { dup = true; break; }
   if(dup) continue;
   ArrayResize(tks, cnt + 1); ArrayResize(lots, cnt + 1);
   ArrayResize(prices, cnt + 1); ArrayResize(types, cnt + 1);
   tks[cnt]    = tk;
   lots[cnt]   = PositionGetDouble(POSITION_VOLUME);
   prices[cnt] = PositionGetDouble(POSITION_PRICE_OPEN);
   types[cnt]  = (pType == POSITION_TYPE_BUY) ? 0 : 1;
   cnt++;
}
```

ทำให้ TP target เดียวครอบคลุม recovery + hedge residue ทุกตัวจริง

### 5) Eager flat-detect & cycle reset

เสริม guard ใน `OnTick` ที่ line 1340 ให้ครอบคลุมเคส set ถูก deactivate แต่ orphan ยังอยู่:

```cpp
// v6.73: Also reset when no active hedge sets AND no recovery orphans remain
if(g_cycleGeneration > 0 && g_hedgeSetCount == 0 && TotalOrderCount() == 0)
{
   TryResetCycleStateIfFlat("OnTick flat-detect v6.73");
}
```
(เป็นเงื่อนไขเดิม — แค่ยืนยันว่ายังทำงานหลัง keep-alive (3) ปล่อยให้ orphan ปิดเอง)

เพิ่ม log ทุก 60 วินาทีเมื่อยังเหลือ orphan แต่ไม่มี active set:

```cpp
if(g_cycleGeneration > 0 && g_hedgeSetCount == 0 && TotalOrderCount() > 0)
{
   static datetime s_lastOrphanWarn = 0;
   if(TimeCurrent() - s_lastOrphanWarn >= 60)
   {
      Print("v6.73 ORPHAN: ", TotalOrderCount(), " positions remain but no active hedge sets — generation stuck at GM",
            g_cycleGeneration + 1, " until they close");
      s_lastOrphanWarn = TimeCurrent();
   }
}
```

### 6) Dashboard
เพิ่มแถวสถานะ:
```
Set#3 Stage : KEEP-ALIVE (orphans=6, AVGTP=4892.45)
Cycle Reset : Pending (6 orphan positions block reset)
```

### 7) Validation Checklist

1. เปิดบัญชี flat → cycle เริ่มที่ `GM1` (regression)
2. Recovery orders ใหม่ทุกตัว: comment ไม่ซ้ำ (`GM_HD1_01`, `_02`, `_03`, ...)
3. หาก collision detector เจอ comment ซ้ำ → bump เลขจนไม่ชน → log
4. Hedge fully released แต่มี recovery orphan → set ไม่ deactivate, ManageRecoveryAvgTP ทำงานต่อจน orphan ปิดหมด
5. ตั๋ว residue จาก partial-close hedge (comment ว่าง, side=hedgeSide) ถูกรวมใน AVG_TP basket → TP เดียวกันทั้ง basket
6. หลัง orphan ปิดครบ → `g_hedgeSetCount==0 && TotalOrderCount()==0` → `ForceResetCycleState` → cycle ถัดไปกลับไป `GM1`
7. ภาพ image-915 reproduce: 1744-1749 ทั้งหมดต้องได้ TP เดียวกัน, comment เลขเรียง `_05, _06, _07, _08, _09, _10` แทนที่ซ้ำ
8. Restart EA ระหว่าง keep-alive → recover state, AVGTP คำนวณใหม่จาก orphans ที่ยังลอย

---

## สิ่งที่ไม่เปลี่ยนแปลง

- Order Execution (`OrderSend`, `trade.Buy/Sell/PositionClose/PositionClosePartial/PositionModify`) — ไม่แก้
- Trading Strategy / Initial / Grid Loss / Grid Profit — ไม่แก้
- Hedge open trigger (Expansion / DD% / DD$) + MinSpacing v6.71 — ไม่แก้
- Triple Gate exit / Matching Close pool / Partial Hedge fallback — ไม่แก้
- AVG_TP Stage 2 trigger logic v6.72 — ไม่แก้ (แค่ขยาย basket scope)
- Reverse-Walk Seed v6.66 / Combined TP / Unified Recovery v6.67 — ไม่แก้
- Gen-Locked Slot v6.68 / New-Candle Gate v6.69 / GM1-Start v6.70 — ไม่แก้
- BB Filter / Sequential Recovery Owner / Strict In-Set Pool / Hedge Side Pause — ไม่แก้
- News / License / Time Filter / Sync / Balance Guard — ไม่แก้
- `InpHedge_UseMatchingClose` master toggle — ไม่แก้
- `ForceResetCycleState` body — ไม่แก้ (แค่เพิ่มจุดที่จะถูกเรียก)

