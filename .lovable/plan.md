# Golden Kuy3 v1.48 — Dynamic Price-Extreme Hero (Side-Locked)

## ปัญหา
v1.47 freeze stable set ครั้งเดียวตอน activate → ถ้ามีออเดอร์ใหม่เปิดที่ราคา extreme กว่า (BUY ต่ำกว่า / SELL สูงกว่า) ระบบไม่ swap เข้า Hero set
- ตัวอย่าง: SELL Hero stuck ที่ #28@3313.63 ทั้งที่ #742@3319.17 สูงกว่า

## หลักการ v1.48
ผสานสองสิ่งที่เคยขัดกัน:
1. **Side-Alternation Lock (v1.46/v1.47)** — คงไว้ทั้งหมด: เมื่อ Hero ฝั่งหนึ่งปิดหมด → stamp `g_heroLastClosedSide` → ฝั่งเดิมห้าม re-arm จนกว่าฝั่งตรงข้าม ARMED/BE_GUARD หรือ flat สนิท
2. **Per-Tick Price-Extreme Refresh (NEW)** — ภายในฝั่งที่ phase active แล้ว stable set รีเฟรชทุก tick ตาม price-extreme ปัจจุบัน (BUY = N ตัวล่างสุด, SELL = N ตัวบนสุด)

## Algorithm `BuildHeroTicketCache()` v1.48

### STEP 1 — Snapshot prev stable set
```
prevBuyStable[] = copy of g_heroBuyStable[] (เพื่อ detect external close)
prevSellStable[] = copy of g_heroSellStable[]
```

### STEP 2 — Prune dead tickets (เหมือน v1.47)
ถ้า prevN>0 && nowN==0 && phase>0 → external Hero close → reset phase + stamp lastClosedSide

### STEP 3 — Per-side processing
สำหรับแต่ละฝั่ง:
- รวบรวม pool ออเดอร์ปัจจุบัน + sort ตาม price-extreme (BUY asc / SELL desc)
- คำนวณ `desiredSet[] = top min(N, nPool-1) tickets`

**Branch A: phase active (ARMED/BE_GUARD)**
- **REFRESH** stable set = `desiredSet` (ไม่ freeze แล้ว)
- ถ้ามี ticket ใหม่เข้า set → strip broker TP (StripBrokerTPSLFromHeroTickets ทำใน step ถัดไป)
- ถ้ามี ticket หลุดจาก set (มีออเดอร์ extreme กว่ามาแทน) → restore broker TP ตาม Avg-mode (handled by SyncBrokerTPSL ใน next sync)
- ถ้า BE_GUARD → re-apply ApplyHeroLockProfitSL กับ set ใหม่ (เฉพาะ ticket ใหม่ที่ยังไม่มี SL)

**Branch B: phase == NONE**
- ผ่าน post-close grace + alt-lock + single-side-lock + threshold → activate
- ตั้ง stable set = desiredSet, phase = ARMED

### STEP 4-5 — Rebuild flat array + auto-release (เหมือน v1.47)

## โค้ดที่ต้องเพิ่ม
1. `RestoreBrokerTPForReleasedHeroTickets(prevSet, newSet)` — เปรียบเทียบ prev vs new; ticket ที่หลุดจาก Hero ควรกลับเข้า Avg TP คำนวณใหม่ (ปกติ SyncBrokerTPSL จะ push TP ให้เองเมื่อไม่อยู่ใน g_heroTickets — ไม่ต้องทำเพิ่ม)
2. `StripTPOnNewHeroEntrants(prevSet, newSet)` — ticket ใหม่ที่เพิ่งเข้า Hero set → strip broker TP ทันที
3. ใน Branch A: เรียก StripTPOnNewHeroEntrants + (ถ้า phase==BE_GUARD) ApplyHeroLockProfitSL กับ set ใหม่

## ส่วนที่ไม่เปลี่ยน (กฎเหล็ก)
- ❌ OrderSend / trade.Buy/Sell/PositionClose
- ❌ OpenInitial / OpenGrid / Manage*Entry / CalcGridLot
- ❌ Per-Order BE/Trail / Avg-Trail strict-2-cross / TP modes / Accumulate / Cost-Hit Restart
- ❌ ComputeHeroLockProfitSL / ApplyHeroLockProfitSL formula
- ❌ Side-Alternation Lock v1.46/v1.47 condition (oppActive || selfFlat)
- ❌ Single-Side Lock v1.45 (BE_GUARD-only owner)
- ❌ v1.42 Accumulate cycle reset
- `InpHero_Enabled=false` → behavior = v1.47

## ผลลัพธ์ที่คาดหวัง
- SELL Hero (N=5) ตอนมี SELL 4 ตัว: #742@3319.17, #736@3317.16, #746@3315.17, #28@3313.63 → take=min(5, 4-1)=3 → Hero=[#742, #736, #746] (3 ตัวบนสุด)
- ถ้า SELL ใหม่เปิดที่ราคา 3325 → Hero refresh เป็น [#newTicket, #742, #736] อัตโนมัติ tick ถัดไป
- ถ้า BUY ปิดหมดก่อน → alt-lock ยังกัน BUY re-arm → SELL ครอง Hero ต่อ

## Version + Memory
- Version bump 1.47 → 1.48 ทุกจุด (`#property version`, `#property description`, header, dashboard, OnInit/OnDeinit Print, audit log)
- เพิ่ม memory: `mem://trading/golden-kuy3/v1-48-hero-dynamic-price-extreme.md`
- อัปเดต `mem://index.md` (แทนที่บรรทัด v1.47)
