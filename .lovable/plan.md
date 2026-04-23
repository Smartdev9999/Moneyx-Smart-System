

## Golden_EA.mq5 v1.0 — สร้าง EA ใหม่จากโครง Gold Miner (เลือก 14 โมดูล)

### ไฟล์ที่จะสร้าง
- `public/docs/mql5/Golden_EA.mq5` (ไฟล์ใหม่ ~5,000–6,000 บรรทัด — กลั่นจาก `Gold_Miner_EA.mq5` 12,643 บรรทัด)

### โมดูลที่รวม (ตามที่ผู้ใช้ระบุ)

| # | โมดูล | แหล่งอ้างอิงใน Gold Miner |
|---|---|---|
| 1 | License Check | LicenseManager.mqh + verify-license edge fn |
| 2 | News Filter | RefreshNewsData / IsNewsTimePaused (+ serverGMTOffset) |
| 3 | Volatility Squeeze Filter (BB vs Keltner) | v6.13–v6.14 directional agreement |
| 4 | Matching Close (hedge + bound, partial pool) | ManageHedgeMatchingClose v6.61 |
| 5 | SMA Indicator (entry signal) | ENTRY_SMA path |
| 6 | Grid Loss Side | CheckGridLoss + CandleConfirm v6.40 |
| 7 | Grid Profit Side | CheckGridProfit |
| 8 | Initial Lot | InitialLotSize + MaxLotSize cap |
| 9 | Max Grid Average Trailing Stop | v6.41/v6.54 |
| 10 | Take Profit (broker-side TP) | SyncBrokerTPSL v6.50 |
| 11 | Stop Loss (broker-side SL) | SyncBrokerTPSL v6.50 |
| 12 | Dashboard | OnChartEvent + comment panel |
| 13 | Time Filter | IsWithinTradingHours |
| 14 | Counter-Trend Hedging (3 โหมด) | InpHedge_TriggerMode: Expansion / DD% / DD$ + Triple Gate v6.25 |

**โบนัสตามคำขอ:** Data Sync (sync-account-data edge fn ส่ง `ea_name="Golden_EA"`)

### โมดูลที่ "ตัดออก" จาก Gold Miner (เพื่อให้ EA ใหม่กระชับ)
ZigZag MTF entry, Balance Guard, Daily Target Profit, Drawdown Emergency Exit, Hedge Open Delay (v6.78), Stuck-TP Scanner (v6.79), Stuck-Hedge Scanner (v6.80), Legacy Gen Grid Continuation (v6.81 Part A), Hedge-Grid AvgTP/Filters (v6.81 Part B), No-ReHedge Lock (v6.74), Cross-Gen INIT Guard (v6.76), Orphan Hedge Auto-Heal (v6.73), Sequential Recovery Owner ระบบ generation ซับซ้อน

### โครงสร้าง Counter-Trend Hedging (ตามที่ผู้ใช้เลือก: ทั้ง 3 โหมด)

```text
InpHedge_TriggerMode:
  0 = HEDGE_TRIGGER_EXPANSION   → BB squeeze→expand เปิด hedge ตาม bias
  1 = HEDGE_TRIGGER_DD_PERCENT  → DD% ของฝั่งใดฝั่งหนึ่งทะลุ → hedge ฝั่งตรงข้าม
  2 = HEDGE_TRIGGER_DD_DOLLAR   → DD$ ของฝั่งใดฝั่งหนึ่งทะลุ → hedge ฝั่งตรงข้าม

Triple Gate (บังคับก่อนปิด hedge set):
  Gate 1: Cycle Ready
  Gate 2: Zone OUT (BB)
  Gate 3: Distance OK (จุดห่างจาก hedge entry)

Matching Close: pool = hedge + bound tickets
  → partial close เมื่อ pool PnL ≥ InpMatch_MinProfit ($)
  → set ยัง active จนกว่า hedge ปิดหมด
```

### Inputs หลัก (groups)
- General Settings (Magic, MaxOpenOrders, TradingMode)
- License (URL, ApiKey, GracePeriodMin)
- News Filter (Enable, MinutesBefore/After, ImpactFilter, CustomKeywords, CacheFile)
- Time Filter (StartHour/Min, EndHour/Min, ServerOffset)
- Volatility Squeeze (BB Period/Dev, Keltner Period/Mult, Timeframe, RequireDirAgreement)
- SMA Indicator (Period, AppliedPrice, Timeframe, AutoReEntry, DontOpenSameCandle)
- Initial Lot (InitialLotSize, MaxLotSize)
- Grid Loss Side (MaxTrades, LotMode, GapType, Distance, MinGap, CandleConfirm, OnlyNewCandle)
- Grid Profit Side (Enable, MaxTrades, LotMode, GapType, Distance)
- Take Profit / Stop Loss (TP_Points, SL_Points, BrokerSync)
- Max Grid Average Trailing (Enable, Mode, StartOrders, Activation, Step, BreakevenBuffer)
- Counter-Trend Hedging (TriggerMode, DD_Pct, DD_Dollar, HedgeLotMultiplier, MaxHedgeSets, TripleGate_*, Match_MinProfit)
- Dashboard (Enable, X, Y, FontSize, ShowButtons)
- Data Sync (Enable, EdgeFnURL, SyncIntervalMin, ApiKey)

### Dashboard
แสดง: Version `v1.0`, License status, News next event, Time filter status, Squeeze state, SMA signal, Open orders/PnL ต่อฝั่ง, Hedge sets active + Triple Gate status, Trailing status, ปุ่ม `[Pause]` `[Close All]` `[Refresh News]`

### Comment prefixes
- `GLDN_INIT` (initial), `GLDN_GL#N` (grid loss), `GLDN_GP#N` (grid profit), `GLDN_Hedge_DN` (hedge set N)
- Magic = ตามที่ user ตั้ง (default 202600 ≠ 202500 ของ Gold Miner)

### สิ่งที่ "ไม่เปลี่ยนแปลง" (กฎเหล็ก)
- ไม่แตะ `Gold_Miner_EA.mq5` หรือ EA อื่นใด
- License/News/Time/Data Sync **คัดลอก logic ตรงตาม Gold Miner / MoneyX Smart** (รวม `serverGMTOffset` UTC→server, WebRequest retry, file cache)
- ใช้ `OrderSend / trade.Buy / trade.Sell / trade.PositionClose / trade.PositionModify` แบบเดียวกับ Gold Miner ทุกจุด ไม่ดัดแปลง
- TP/SL/Trailing/Grid formulas คัดมาตรง ๆ ไม่ปรับสูตร
- Triple Gate + Matching Close logic เหมือน v6.25/v6.61 ทุกประการ

### ผลลัพธ์ที่คาดหวัง
- EA ใหม่ `Golden_EA.mq5` v1.0 compile ได้ใน MT5 ทันที
- มี 14 โมดูลครบตามรายการ + Data Sync
- Dashboard, ปุ่มควบคุม, log version ครบทุกจุด (`#property version "1.00"`)
- ไม่มี dependencies ภายนอกอื่น (รวม LicenseManager logic inline)

### ความเสี่ยง & Mitigation
- **Risk:** การคัด Counter-Trend Hedging แบบ 3 โหมด + Triple Gate + Matching จาก Gold Miner ขาด helper บางตัว → **Mitigation:** ลอกเฉพาะ functions ที่ต่อเนื่องในกราฟ call แล้วทดสอบ compile (จะ list functions ที่คัดมาก่อน implement)
- **Risk:** ไฟล์ใหม่ใหญ่ ~5,000+ บรรทัด → **Mitigation:** เขียนเป็นชุดต่อเนื่องโดยจัดกลุ่ม sections ชัด (Inputs → Globals → OnInit/Deinit → OnTick → Modules → Helpers)
- **Risk:** Data Sync URL/ApiKey ซ้ำกับ Gold Miner → **Mitigation:** ส่ง `ea_name="Golden_EA"` ทำให้ dashboard แยก EA ได้อัตโนมัติ (per memory `sync-account-data-auto-linking-v3`)

