## Golden2 EA v2.72 — Combined: Backtest Speed Optimizations + Per-Side Squeeze Block

ไฟล์เดียวที่แก้: `public/docs/mql5/Golden2_EA.mq5`

### A) Per-Side Squeeze Block (เดิม v2.62)
- ใน `PlaceInitialFrame()` แทนที่ `SqueezeBlocksAny()` (block ทั้งกลุ่ม) ด้วยการตรวจ **per-side**:
  - `if(SqueezeBlocksSide(0)) placeBuy=false;`
  - `if(SqueezeBlocksSide(1)) placeSell=false;`
  - `if(!placeBuy && !placeSell) return;`
- พฤติกรรม: ถ้า Squeeze บล็อกฝั่ง BUY → ยังออก SellStop ได้ปกติ และกลับกัน
- ตรงกับ Grid Loss/Profit ที่ใช้ per-side อยู่แล้ว

### B) Backtest Speed Optimizations (เดิม v2.71)
1. **Tester / Visual detect**
   - `g_isTesterMode = (bool)MQLInfoInteger(MQL_TESTER);`
   - `g_isVisualMode = (bool)MQLInfoInteger(MQL_VISUAL_MODE);`
2. **Dashboard throttle**
   - Input ใหม่ `InpDashRenderIntervalSec` (default 1)
   - ใน Tester non-visual → skip `DrawDashboard()` ทั้งหมด
   - ใน live/visual → render ทุก N วินาทีเท่านั้น
3. **Chart objects (avg / TP lines)**
   - Skip `DrawAverageAndTPLinesForGroup()` เมื่อ tester non-visual
4. **Squeeze refresh**
   - `RefreshSqueezeState()` คำนวณเฉพาะตอน **new bar (M1)** แทนทุก tick
5. **History scan cache**
   - Cache ผลของ `HasClosedMainOnSide(g, side)` ไว้ ~2s ต่อ (group,side) เพื่อลด `HistorySelect`
6. **Group loop bound**
   - แทน `for(gi=1..InpMaxGroups)` ด้วย `for(gi=1..MathMin(g_highestActiveGroup+1, InpMaxGroups))` ในลูปจัดการกลุ่ม

### Version
- Bump → **2.72** ทุกจุด (`#property version`, header block, `OnInit` log, Dashboard `L_TITLE`)
- เพิ่มบรรทัด log: `ReEntryOnClose / SqueezePerSide / TesterMode / VisualMode / DashInterval`

### สิ่งที่ "ไม่เปลี่ยน" (ยืนยัน)
- ❌ ไม่แตะ `OrderSend` / `trade.*`
- ❌ ไม่แตะเงื่อนไข Entry / Exit / TP / SL
- ❌ ไม่แตะ Grid Loss / Grid Profit / Hedge / Triple-Gate / Accumulate
- ❌ ไม่แตะ v2.5 Toward-Price Trail, v2.6 Re-entry, v2.70 Continuous Frame
- ❌ ไม่แตะ Squeeze indicator math (BB/KC) — แค่เปลี่ยน "ใช้ผลยังไง" และความถี่ refresh
- ❌ ไม่แตะ License/News/Sync modules
- ✅ Output trade เหมือนเดิม 100% — เปลี่ยนแค่ความเร็วการประมวลผล + การ block ฝั่งของ Squeeze
