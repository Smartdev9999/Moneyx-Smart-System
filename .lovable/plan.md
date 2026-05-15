
# Golden2 EA v2.8.0 — Plan (revised)

ไฟล์: `public/docs/mql5/Golden2_EA.mq5` (version 2.7.9 → 2.8.0)
อัปเดต `#property version`, `#property description`, header, dashboard, `PrintFormat` log

---

## 1) แก้บั๊ก ATR/ADX ยังโชว์ใน Backtest (จริงจังรอบนี้)

**สาเหตุที่ v2.7.9 ไม่หาย:** `CleanupChartIndicatorsInTester()` ถูกเรียก **ก่อน** สร้าง handle `iATR/iADX/iBands/iMA` (บรรทัด 3227 vs 3253–3270) → cleanup ไม่มีอะไรให้ลบ พอสร้าง handle ทีหลัง MT5 Tester ก็แปะ ATR/ADX ขึ้น subwindow

**แก้:**
- เรียก `CleanupChartIndicatorsInTester()` **หลัง** สร้าง handle ทั้งหมดใน `OnInit` (เพิ่มหลังบรรทัด 3285 ของไฟล์เดิม) — เก็บ call แรกไว้ด้วยเผื่อ chart มี indicator ค้างจาก template
- ใส่ใน throttle loop ของ OnTick รวมกับ `HideAuxiliaryTesterCharts` ทุก 60s → กัน lazy-bind หลังจากนั้น
- เพิ่ม `ChartSetInteger(cid, CHART_SHOW_ASK_LINE/BID_LINE/LAST_LINE, false)` ใน cleanup (เร่ง render เพิ่ม)
- กฎเหล็ก: ไม่มี input ใหม่ (ตามที่ user สั่ง) — บังคับ ON ใน Tester เสมอ, no-op live

---

## 2) จัดหมวดหมู่ Input ใหม่ + ตัด default-only inputs

### โครงสร้างใหม่ (เรียงจากบนลงล่าง — Mode อยู่บน Indicator อยู่ล่าง)
```text
=== General ===
=== Entry Mode ===              ← ขยับขึ้นมาด้านบน
=== Initial Order / Frame ===
=== Group / Queue ===
=== Hedging ===
=== Exit (Triple Gate) ===      ← ขยายในข้อ 3 + ข้อ 4
=== Take Profit (Average) ===
=== Stop Loss (Average) ===
=== Grid Loss Side ===
=== Grid Profit Side ===
=== Max Grid Trailing ===
=== Volatility Squeeze Filter ===
=== Dashboard ===
```

### Input ที่จะ "ฝัง constant ในโค้ด" (ลบจาก input panel)

| Input | ค่าคงที่ที่ฝัง | เหตุผล |
|---|---|---|
| `InpFrameSymmetricTrail` | `false` | DEPRECATED ตั้งแต่ v2.5 |
| `InpFrameRecenterMinPips` | `50` | tuning น้อยมาก |
| `InpExitBBPeriod` | `20` | BB มาตรฐาน |
| `InpExitBBDev` | `2.0` | BB มาตรฐาน |
| `InpExitKeltnerATR` | `20` | KC มาตรฐาน |
| `InpExitKeltnerMult` | `1.5` | KC มาตรฐาน |
| `InpSQ_BBPeriod` | `15` | Squeeze internal |
| `InpSQ_BBMult` | `2.0` | Squeeze internal |
| `InpSQ_KCPeriod` | `15` | Squeeze internal |
| `InpSQ_KCMult` | `1.5` | Squeeze internal |
| `InpSQ_ATRPeriod` | `14` | Squeeze internal |
| `InpSQ_ADXPeriod` | `14` | std |
| `InpSQ_ATRMAPeriod` | `20` | std |
| `InpSQ_ATRMult` | `1.0` | std |
| `InpSQ_EMAPrice` | `PRICE_CLOSE` | std |
| `InpSMA_AppliedPrice` | `PRICE_CLOSE` | std |
| `GridLoss_ATR_Period` | `14` | std |
| `GridProfit_ATR_Period` | `14` | std |
| `InpGL_ImmediateAfterInitial` | `true` | ติด ON เป็น default ที่ user ไม่ปิด |
| `InpInitTrailTF` | `PERIOD_M1` | bar-trail TF ไม่ค่อยเปลี่ยน |
| Dashboard styling: `InpDashColor`/`HeaderBg`/`RowBg`/`Accent`/`Good`/`Bad`/`FontSize`/`Font`/`X`/`Y`/`LeftWidth`/`HedgeGap` | คงค่า default | ไม่ปรับจริง |
| TP/SL line colors: `InpTP_AvgBuyColor`/`SellColor`/`BuyLineColor`/`SellLineColor`/`AvgLineWidth`/`InpSL_LineColor` | คงค่า default | สี/ความหนา line |

**คงไว้ (ผู้ใช้ปรับจริง):** Magic, Slippage, AllowTrade, Verbose, EntryMode + SMA period/TF, Initial lot/Frame distance/TP/SL, ReArm/ReEntry toggles, Group/Queue toggles, Hedge ทั้งหมด, Exit TF/BreakoutPips/MinNetUSD/(ของใหม่ในข้อ 3+4), TP/SL modes, Squeeze TF1-3/ExpansionThreshold/toggles, Grid Loss/Profit ทั้งหมดยกเว้น ATR_Period

**กฎเหล็ก:** ไม่แตะ logic — แค่เปลี่ยน `input` เป็น `const` ใน scope เดิม, ชื่อตัวแปรเดิม, callsites ไม่ต้องแก้

---

## 3) Hedge Exit แบบ Gold Miner (Sequential Matching Close + Recovery Grid)

**สเปก user:**
1. **Zone Gate** — ราคาต้องอยู่นอก zone ระหว่าง avg main กับ avg hedge ของ group นั้น (มีแล้ว = `InpExitBreakoutPips`)
2. **Min Profit Gate** — กำไรขั้นต่ำก่อนปิด (มีแล้ว = `InpExitMinNetUSD`)
3. **Expansion → Normal Gate** — TF ใหญ่ต้อง **ผ่าน Expansion → Normal อย่างน้อย 1 ครั้ง** ต่อ hedge group ก่อน matching close ได้
4. **Sequential Queue** — ปิดทีละ group เริ่มจาก group เก่าสุด (G1 → G2 → ...); group ถัดไปต้องรอ group ก่อนหน้า flat ทั้งหมด
5. **Matching Close ในกลุ่ม** — รวม PL บวก/ลบใน group เดียว, ปิดเท่าที่ pool ≥ `InpExitMinNetUSD`
6. **Recovery Grid** — เมื่อปิดแล้วเหลือติดลบ → ออก Grid Loss เพิ่ม **ต่อจาก GL ตัวล่าสุด** ของฝั่งติดลบ (comment tag ใหม่ `RC#N`)
7. **โหมด Recovery แยกจากปกติ** — group อื่นเทรดปกติได้ ไม่ถูก block; recovery grid ออกเฉพาะ group ที่ active recovery
8. **Cycle Reset** — ทุก group flat → กลับสู่ระบบเริ่มต้น

### State ใหม่ (per-group)

```cpp
bool     g_hedgeExpSeen[51];           // เคยเห็น Expansion หลังเปิด hedge
bool     g_hedgeNormalAfterExp[51];    // ผ่าน Expansion → Normal แล้ว (gate3 armed)
int      g_recoveryActiveGroup;        // group ที่กำลัง recover (0 = ไม่มี)
bool     g_recoveryMode[51];
int      g_recoveryLossSide[51];       // 0=BUY, 1=SELL, -1=none
double   g_hedgeEntryEquity[51];       // baseline equity ตอน hedge เริ่ม (สำหรับ MinGainUSD ข้อ 4)
```

### Inputs ใหม่ (กลุ่ม `=== Exit (Triple Gate) ===`)

```cpp
input bool   InpExit_RequireExpToNormal = true;   // Gate3: require Expansion→Normal
input bool   InpExit_SequentialQueue    = true;   // ปิดทีละ group เริ่ม G1
input double InpExit_MinGainUSD         = 100.0;  // [ข้อ 4 ใหม่] กำไรขั้นต่ำของ hedge group ก่อนปิด (USD จาก hedge entry)
input bool   InpRecovery_Enable         = true;   // Recovery grid หลัง matching
input int    InpRecovery_MaxLevels      = 10;
input double InpRecovery_LotMultiplier  = 1.0;    // คูณบน lot ตัวล่าสุดของฝั่งติดลบ
input int    InpRecovery_StepPoints     = 0;      // 0 = ใช้ GridLoss_Points / >0 = override
input int    InpRecovery_MinAvgTPPoints = 100;    // จุดทำกำไรของ recovery basket
```

### Functions ใหม่ + แก้
- `RefreshHedgeExpansionLatch()` — throttled ทุกบาร์ของ `InpExitTF`; toggle latch per group ที่มี hedge
- `IsExpansionToNormalForGroup(g)` — รวม gate ใหม่กับ existing `IsExpansionToNormal()`
- `PickNextRecoveryGroup()` — return group เก่าสุดที่มี hedge + ผ่าน gates
- `TryMatchingCloseForGroup()` (rewrite) — เพิ่ม sequential gate + 3-gate + min-gain gate (ข้อ 4); หลังปิดถ้ายังเหลือลบ → ตั้ง recovery state
- `ManageRecoveryGrid(g)` — หา GL ตัวล่าสุดฝั่ง loss → ออก order ใหม่ comment `G{n}_{B|S}_RC#{level}`
- `ManageRecoveryAvgTP(g)` — คำนวณ avg ของ orders ฝั่ง loss + recovery → ตั้ง TP ที่ `avg ± InpRecovery_MinAvgTPPoints`
- `ResetRecoveryStateIfFlat()` — group flat → clear, advance ไป group ถัดไป

### ParseComment / MakeComment
- เพิ่ม tag `RC#N` (Recovery) — `MakeComment(g, side, false, "RC#3")` → `G2_S_RC#3`
- ParseComment คืน tag เดิม → downstream `StringFind(tag,"GL")` ไม่กระทบ

---

## 4) [ใหม่] Hedge Exit Min Gain USD

User: "เพิ่ม Gain ของ Expansion เข้ามาด้วย — Gain เท่าไหร่ถึง Exit ได้, ตอนนี้ยังไม่มีให้เลือก"

- `InpExit_MinGainUSD = 100.0` (input ใหม่ในกลุ่ม Exit)
- Stamp `g_hedgeEntryEquity[g] = AccountEquity()` ตอนวาง hedge ครั้งแรกของ group นั้น (hook ที่ตำแหน่งเปิด hedge — เพิ่ม **ก่อน** `trade.PositionOpen` แต่ไม่แก้ flow trade — แค่ assignment)
- ใน `TryMatchingCloseForGroup(g)`:
  - คำนวณ `gainNow = (CurrentGroupRealized + CurrentGroupFloating) - g_hedgeEntryEquityDelta[g]`
  - หรือสูตรง่ายกว่า: ใช้ `GroupNetPL(g) - groupRealizedAtHedgeEntry` — ถ้ายังไม่ถึง `InpExit_MinGainUSD` → return (ไม่ปิด)
- Reset `g_hedgeEntryEquity[g] = 0` ตอน group flat (ใน `ResetRecoveryStateIfFlat`)
- Dashboard เพิ่มแถว `Gain Need: $XX.X / $YY.Y`

---

## 5) [ใหม่] แก้บั๊ก "Order หยุดออก" (จาก log ที่ user ส่ง)

**Log:** `Golden2 v2.7.4: hold G3->G4 (cur safe=1 priors safe=0 blkBUY=0 blkSELL=7 rawBUY=0 rawSELL=8 hedgeBuy=8 hedgeSell=0 plBUY=0.00 plSELL=-14723.83 profitBypass=ON)`

**วิเคราะห์:**
- G3 มี hedge active แล้ว (8 hedgeBuy mirror 8 SELL ติดลบ)
- `cur safe=1` = G3 ผ่าน safe-to-advance แล้ว
- `priors safe=0` = G1 หรือ G2 ยังไม่ flat → block G4
- ไม่ปรากฎว่า Triple-Gate ยิงปิด → stuck แบบไม่มีทางออก
- pl SELL = −14723 ค้างมานาน 30+ บาร์ → matching close ไม่เคยผ่าน Zone/MinNet gate

**สาเหตุหลัก 2 จุด:**
1. **Triple-Gate ไม่เคย fire** เพราะ `IsExpansionToNormal()` (global, ไม่ per-group) อาจ require state ที่ไม่เคยเกิด → ข้อ 3 (per-group latch + sequential queue + recovery grid) แก้ตรงนี้โดยตรง
2. **`AreAllPriorGroupsSafe` priors safe=0** ค้าง — เกิดจาก G1/G2 มี residual position ที่ไม่นับเป็น "safe" — เพิ่ม:
   - `InpAdvance_OnRecoveryActive = true` — ถ้า group ก่อนหน้าอยู่ใน recovery mode (จากข้อ 3) → นับเป็น "safe to advance" ให้ G(N+1) ที่เป็น new cycle เปิดได้
   - เปลี่ยน `IsGroupSafeToAdvance(g)` ให้คืน true เมื่อ `g_recoveryMode[g]==true` (recovery จัดการแยก, ไม่ block flow ปกติ — ตรงตามสเปก user "การทำงานจะแยกกันกับโหมดปกติเลย")

**Diagnostic เพิ่ม:**
- เปลี่ยน hold-log จาก v2.7.4 → v2.8.0 + เพิ่ม field: `g3GateExp=Y/N g3GateZone=Y/N g3GateGain=Y/N recoveryGrp=Gx`
- ทำให้ user/dev เห็นทันทีว่า gate ไหน fail

---

## กฎเหล็กที่ "ไม่เปลี่ยน"

❌ `OrderSend`/`trade.Buy`/`trade.Sell`/`trade.PositionClose`/`trade.OrderModify`/`trade.BuyStop`/`trade.SellStop`/`trade.OrderDelete`
❌ Entry SMA/INSTANT/PENDING (v2.7.6 + v2.73)
❌ Squeeze BB/KC/ADX/EMA/ATR multi-TF logic (v2.7.7) — แค่ฝัง period เป็น const
❌ Grid Loss/Profit lot/distance/candle confirm/ATR snapshot (v1.7+)
❌ Hedge mirror 1:1 / pending hedge / arm/disarm / Block percent (v1.4)
❌ Avg TP/SL / Per-order trail / Bar-close trail / Cost-Hit / Accumulate (v2.0–v2.1)
❌ Force-close opp unhedged (v2.7.8)
❌ ParseComment downstream tag matching — เพิ่ม "RC" เป็น tag ใหม่ไม่กระทบเดิม
❌ Existing matching close pool sort

## Files
- `public/docs/mql5/Golden2_EA.mq5` (version → 2.8.0)
- `mem://trading/golden2-ea/v2-8-0-tester-fix-input-reorg-sequential-recovery-mingain.md` (ใหม่)
- `mem://index.md` (อัปเดต)

ขอ approval แล้วลงมือเลยครับ
