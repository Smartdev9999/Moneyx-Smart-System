

## v6.71 — Hedge MinSpacing (minutes) + Recovery Close Mode (Matching vs AvgTP) + Fix Duplicate Hedge Spam

### ปัญหาที่ต้องแก้

1. **Hedge ออกซ้ำรัวๆ** (image-912)
   - `GM_HEDGE_7` (tk 2751, 2026.02.05 01:10) → `GM_HEDGE_8` (tk 2770, 01:21) ห่างกันแค่ 11 นาที, lot ขนาดใหญ่ (0.36, 0.05) ทยอยเปิด
   - สาเหตุ: Squeeze Expansion trigger (`CheckAndOpenHedge`) **ไม่มี cooldown** เลย — มีเฉพาะ DD mode ที่ใช้ `InpHedge_DDCooldownSec`. พอ expansion bar ค้างหลายแท่งและ `g_cycleGeneration` ขยับ → trigger ใหม่ทันที
   - และไม่มี gate ระหว่างชุด hedge (set#1 → set#2) ที่เป็น **นาที** ตามที่ user ขอ

2. **ต้องการ "เวลาขั้นต่ำระหว่าง Hedge ชุด" เป็นนาที**
   - หลัง hedge ชุดที่ 1 เปิด → ปล่อยให้ราคาวิ่งสักพัก → ค่อยอนุญาตชุดที่ 2 (กัน fault signal)
   - ใช้กับทุก trigger mode (Expansion / DD% / DD$)

3. **Recovery หลังปลดล็อค hedge ยังเป็น matching close ผสมกับ recovery grid**
   - ตอนนี้ recovery grid เปิดใหม่ไปด้วย แต่ flow matching ยังพยายาม "ซอยปิด" hedge/bound ที่เหลือต่อด้วย profit ของ recovery → สับสน
   - User ต้องการ **เลือกได้** ว่าหลัง hedge unlock แล้วจะใช้:
     - **MATCHING_CLOSE** (เดิม) — recovery profit ใช้ซอยปิดทีละไม้
     - **AVERAGE_TP** (ใหม่) — รวม `bound + hedge ที่เหลือ + recovery grid` → คำนวณ weighted avg → ตั้ง broker TP ห่างจาก avg N points (parameter ใหม่) ให้ **ทุกตั๋วในตะกร้า** แล้วรอปิดพร้อมกันที่ broker

---

## แผนแก้ไข — `public/docs/mql5/Gold_Miner_EA.mq5`

### 1) Version bump → v6.71
อัปเดต `#property version`, description, header, init log, dashboard label

### 2) Input ใหม่ 3 ตัว (กลุ่ม Counter-Trend Hedging)
```cpp
input int    InpHedge_MinSpacingMin       = 30;   // v6.71: Min minutes between hedge sets (0=Off)
input ENUM_RECOVERY_CLOSE_MODE InpRecovery_CloseMode = RECOVERY_CLOSE_MATCHING; // v6.71
input int    InpRecovery_AvgTPDistance    = 500;  // v6.71: Avg TP distance points (AVERAGE_TP mode)
```

Enum ใหม่:
```cpp
enum ENUM_RECOVERY_CLOSE_MODE {
   RECOVERY_CLOSE_MATCHING = 0,  // Matching Close (current behavior)
   RECOVERY_CLOSE_AVG_TP   = 1   // Weighted Avg TP across bound+hedge+recovery
};
```

### 3) Fix Hedge Spam — เพิ่ม MinSpacing gate ทุก trigger
Global tracker ใหม่:
```cpp
datetime g_lastHedgeOpenTime = 0;   // v6.71: last time ANY hedge set opened
```

ใน `CheckAndOpenHedge()` (Expansion) — ก่อน `FindGenerationHedgeSlot`:
```cpp
if(InpHedge_MinSpacingMin > 0 && g_lastHedgeOpenTime > 0)
{
   int elapsedSec = (int)(TimeCurrent() - g_lastHedgeOpenTime);
   int requiredSec = InpHedge_MinSpacingMin * 60;
   if(elapsedSec < requiredSec)
   {
      static datetime s_lastSpaceLog = 0;
      if(TimeCurrent() - s_lastSpaceLog >= 60)
      {
         Print("v6.71 HEDGE SPACING: wait ", (requiredSec - elapsedSec)/60, "m more");
         s_lastSpaceLog = TimeCurrent();
      }
      return;
   }
}
```

หลัง `OpenOrder(...)` สำเร็จ → `g_lastHedgeOpenTime = TimeCurrent();`

ใส่ guard เดียวกันใน `CheckAndOpenHedgeByDD()` (สองสาขา DD%/DD$) — บังคับ spacing ระดับเดียวกัน (เพิ่มเติมจาก `DDCooldownSec` ที่มีอยู่)

ใน `RecoverHedgeSets()` ตอน restart → ตั้ง `g_lastHedgeOpenTime = max(hedge.openTime)` จาก hedge sets ที่ active เพื่อ honor spacing ข้าม restart

### 4) Recovery Close Mode = MATCHING (เดิม)
ไม่เปลี่ยน flow เดิม — `ManageHedgeMatchingClose` + `ManageHedgeBoundAvgTP` + `ManageHedgePartialClose` ทำงานปกติ

### 5) Recovery Close Mode = AVERAGE_TP (ใหม่)
ใน `ManageHedgeSets()` loop ต่อ set, ก่อน `ProbeSetProfit/MatchingClose` block:
```cpp
if(InpRecovery_CloseMode == RECOVERY_CLOSE_AVG_TP)
{
   // Skip matching/partial entirely — manage by weighted avg TP
   ManageRecoveryAvgTP(h);
   g_hedgeSets[h].matchingDone = true;
   // Still allow grid expansion (TryEnterCombinedGridMode + ManageHedgeGridMode)
   if(!blockGridForThisSet) {
      if(g_hedgeSets[h].gridMode) ManageHedgeGridMode(h);
      else TryEnterCombinedGridMode(h);
   }
   continue;
}
```

ฟังก์ชันใหม่ `ManageRecoveryAvgTP(int idx)`:
1. รวมตั๋วทั้งหมดของ set: `hedgeTicket` (ถ้ายังเหลือ) + `boundTickets[]` + recovery grid (comment-match `GM_HD<gen>_*` + `recoveryGridTickets[]`)
2. คำนวณ weighted avg open price (sum(lot*price) / sum(lot)) **แยก side** เพราะตะกร้ามีทั้ง BUY & SELL
   - Net side = side ที่ lot รวมมากกว่า
   - `netLots = |buyLots - sellLots|`, `netAvgPrice` = weighted avg ของ net side หลังหักฝั่งตรงข้าม (ใช้สูตร basket break-even มาตรฐาน)
3. คำนวณ `targetPrice`:
   - Net BUY → `targetPrice = netAvgPrice + InpRecovery_AvgTPDistance * point`
   - Net SELL → `targetPrice = netAvgPrice - InpRecovery_AvgTPDistance * point`
4. **ตั้ง broker TP = `targetPrice`** ให้ **ทุกตั๋วในตะกร้า** ผ่าน `trade.PositionModify(tk, sl_existing, targetPrice)` (skip ถ้า TP เดิม == ใหม่ ภายใน 1 point เพื่อลด server load)
5. Log:
```text
v6.71 AVGTP Set#1 (Gen0): tickets=6 netSide=BUY netLots=0.42 avgPx=4951.20 targetTP=4956.20 (+500p) modified=6/6
```
6. Throttle: เรียกซ้ำได้ทุก tick แต่จริงๆ จะ no-op เพราะ TP ไม่เปลี่ยน เว้นแต่มีตั๋วใหม่หรือปิด

หมายเหตุ: ใช้ `SyncRecoveryBasketTP` ที่มีอยู่เป็นต้นแบบ basket calc — แต่ `ManageRecoveryAvgTP` คำนวณ **ทั้ง bound + hedge + recovery รวมกัน** (ไม่ใช่แค่ hedge-side) เพื่อสะท้อนความต้องการ user

### 6) Dashboard
เพิ่มแถว:
```text
Hedge Spacing : 30min (last hedge 12m ago — 18m to next)
Recovery Mode : AVERAGE_TP (dist=500p)
```

### 7) Validation Checklist
1. `InpHedge_MinSpacingMin=30`, hedge#1 เปิด → 10 นาทีถัดมา expansion เกิดอีก → log "HEDGE SPACING: wait 20m more", ไม่เปิด hedge#2
2. ผ่าน 30 นาที → expansion เกิด → hedge#2 เปิดได้ปกติ
3. `InpHedge_MinSpacingMin=0` → behavior เดิม (regression OK)
4. Restart EA ระหว่าง hedge#1 active → spacing นับต่อจาก openTime ของ hedge#1
5. `InpRecovery_CloseMode=MATCHING` → flow เดิม v6.70 ทุกประการ
6. `InpRecovery_CloseMode=AVERAGE_TP` → ไม่มี partial close / matching close ทำงาน, ทุกตั๋วใน set ได้ broker TP เดียวกัน = avg + 500p
7. ตะกร้า basket ปิดพร้อมกันทั้งหมดเมื่อราคาแตะ targetTP → triggers `ForceResetCycleState` (v6.70) ถ้า flat
8. Dashboard แสดงสถานะ spacing countdown + recovery mode ปัจจุบัน

---

## สิ่งที่ไม่เปลี่ยนแปลง

- Order Execution (`OrderSend`, `trade.Buy/Sell/PositionClose/PositionClosePartial/PositionModify`) — ไม่แก้
- Trading Strategy / Initial Entry / Grid Loss / Grid Profit (basket หลัก) — ไม่แก้
- Hedge open trigger logic (Squeeze Expansion / DD% / DD$ rules) — ไม่แก้, แค่เพิ่ม MinSpacing gate
- Triple Gate exit, Reverse-Walk Seed v6.66, Combined TP formula — ไม่แก้
- v6.67 Unified Recovery Params, v6.68 Gen-Locked Slot, v6.69 New-Candle/GM_HD comments, v6.70 GM1-Start/HardFlatReset — ไม่แก้
- Hedge Side Pause v6.39, BB Filter v6.56, Sequential Recovery Owner v6.59, Strict In-Set Pool v6.62 — ไม่แก้
- News / License / Time Filter / Sync / Balance Guard — ไม่แก้
- Existing `InpHedge_DDCooldownSec` — คงไว้ (ทำงานคู่กับ MinSpacing)
- `InpHedge_UseMatchingClose` toggle — คงไว้ (เป็น master switch; MinSpacing/AvgTP mode อยู่ใต้ switch นี้)

