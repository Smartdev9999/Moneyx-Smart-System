# แผนแก้ Hero v1.52 — Sticky Set + Strict Alternation

## สาเหตุที่แท้จริงของอาการ

จาก log + screenshot (`Hero BUY active=21/15 Hero=5 BE_GUARD`, `Hero SELL active=10/15 Hero=0 WAIT`, `Owner=BUY locked`, `Last Closed=-`)

ปัญหามาจาก **Branch A ใน `BuildHeroTicketCache()` (v1.48 dynamic refresh)** ที่ public/docs/mql5/Golden_Kuy3_EA.mq5:526-583 — ทุก tick มันจะ **เลือก Hero ใหม่** ตาม price-extreme ปัจจุบัน แม้ phase จะอยู่ BE_GUARD แล้วก็ตาม:

1. ตอนแรก Hero BUY = ticket #805,#825,#902,#931,#972 (5 ตัว lowest price) → BE_GUARD lock SL ไว้
2. ราคาลงต่อ → grid เปิด BUY ใหม่ที่ราคาต่ำกว่า (#1010, #1050 …)
3. Branch A เรียงใหม่ทุก tick → Hero set กลายเป็น #1010,#1050,… (5 ใหม่ที่ต่ำสุด) → push #805,#825 ออกจาก stable set
4. Ticket ที่ถูก push ออก: TP ถูก strip ไปแล้ว, SL เดิมที่ ApplyHeroLockProfitSL เคยใส่ก็ยังอยู่แต่ตอนนี้นับเป็น "non-Hero" → Per-Order Trail/BE จะเข้าจัดการ → ปิดพร้อมไม้อื่น
5. Hero owner ยังเป็น BUY (BE_GUARD ไม่ reset) → SELL ไม่มีโอกาสได้ Hero แม้ basket จะใหญ่กว่า threshold
6. `g_heroLastClosedSide` ไม่ถูก stamp เพราะ Hero ไม่เคย "ปิดยกชุด" — มันแค่ถูก demote เงียบ ๆ → Alternation Lock v1.46 ใช้ไม่ได้

ผลลัพธ์ตรงกับที่ user เห็น: Hero BUY ทับซ้อน, BUY ใหม่กลายเป็น Hero ทันที, ไม้เก่าถูกปิดคู่กับ break-even, ฝั่ง SELL ไม่ได้สลับเป็น Hero เลย

## หลักการแก้ v1.52

> **Hero ticket set = STICKY ห้ามเปลี่ยนตัวจน phase รีเซ็ตเป็น NONE**

1. **Branch A เปลี่ยนเป็น Sticky-Only (ตามแบบ v1.47)**
   - เมื่อ `curPhase != 0` (ARMED/BE_GUARD): **ไม่ re-select** จาก price-extreme อีก
   - แค่ prune ticket ที่ปิดไปแล้วจาก stable set (PruneStableSet ทำอยู่แล้วใน STEP 1)
   - ไม่เติม ticket ใหม่เข้า stable set ในระหว่าง phase นี้
   - `sideHeroTagged[s] = stableN` (จำนวนปัจจุบันหลัง prune)

2. **ไม้ใหม่ที่เปิดหลัง Hero ARMED = ไม้ basket ปกติ ไม่ใช่ Hero**
   - ไม่ต้อง strip TP, ไม่ต้อง lock SL
   - Per-Order Trail/BE/Avg-TP จัดการตามปกติ

3. **Stable set ลดลงจน `stableN == 0` → trigger Auto-Release**
   - STEP 5 (line 685-694) มีอยู่แล้ว: ถ้า BE_GUARD แต่ stable set ว่าง → reset phase + `g_heroLastClosedSide = side`
   - ทำให้ Alternation Lock v1.46 ทำงานต่อ → SELL ได้ Hero รอบถัดไป

4. **STEP 1 external-close detection ปรับเป็น "set drained" generically**
   - `prevN > 0 && nowN == 0 && curPhase > 0` → stamp `g_heroLastClosedSide` (เดิมทำอยู่แล้ว ดี)
   - กรณีใหม่: `nowN < prevN && curPhase == 3` → log อย่างเดียว (Hero บางตัวถูกปิด, ที่เหลือยังคุมต่อ)

5. **ลบ logic clear `g_heroBE_Applied_*` บน REFRESH** (line 577-581)
   - ไม่จำเป็นแล้ว เพราะไม่ refresh stable set อีก

6. **Toggle รักษาความเข้ากันได้**
   - เพิ่ม input `InpHero_StickySet = true` (default ON)
   - false = พฤติกรรมเดิม v1.51 (dynamic refresh) สำหรับ rollback ฉุกเฉิน

## รายละเอียดทางเทคนิค (สำหรับ dev)

ไฟล์: `public/docs/mql5/Golden_Kuy3_EA.mq5`

| จุดแก้ | บรรทัดเดิม | การเปลี่ยน |
|---|---|---|
| Header `#property version` + description | 23, 4-19 | bump v1.51 → v1.52, เพิ่มบรรทัด `v1.52: Hero Sticky Set` |
| `input bool InpHero_StickySet` | ใหม่ ใต้บรรทัด 105 | default `true` |
| `BuildHeroTicketCache` Branch A | 523-584 | ตัด sort + re-add เป็น "if sticky: keep current stable set, sideHeroTagged = stableN, continue" |
| Comment Branch A | 524-525 | เขียนใหม่อธิบาย sticky |
| Dashboard `headerVersion` | (search "v1.51") | bump string |
| `OnInit`/`OnDeinit` Print | (search) | bump version string |
| Memory file | `.lovable/memory/trading/golden-kuy3/v1-52-hero-sticky-set.md` | สร้างใหม่ |
| `mem://index.md` | Memories list | เพิ่ม entry v1.52 |

## สิ่งที่ไม่เปลี่ยน (กฎเหล็ก)

- ❌ `trade.Buy/Sell/PositionClose/OrderSend` ไม่แตะ
- ❌ Grid entry/exit/lot multiplier ไม่แตะ
- ❌ Per-Order BE/Trail/SL/TP/Cost-Hit Restart ไม่แตะ
- ❌ Avg-TP/Avg-Trail strict-2-cross ไม่แตะ
- ❌ Accumulate close logic ไม่แตะ
- ❌ Squeeze/News/License/Sync — ไม่มีในไฟล์นี้อยู่แล้ว
- ❌ `ApplyHeroLockProfitSL` / `ComputeHeroLockProfitSL` / `StripBrokerTPSLFromHeroTickets` ไม่แตะ
- ❌ STEP 2 dual BE_GUARD pre-guard, STEP 4 flat rebuild, STEP 5 auto-release, STEP 6 audit log ไม่แตะ
- ❌ Side-Alternation Lock v1.46, Single-Side Lock v1.45, Post-close grace, External-close detection ทำงานต่อปกติ
- ❌ v1.50 `oppRealized` gate, v1.51 Avg-TP intent flag (5 จุด set + Master TP safety net + 60s expiry) ทำงานต่อปกติ
- ❌ `IsHeroProtectedTicket` 9 guards ทำงานต่อปกติ
- ❌ `InpHero_Enabled = false` → behavior เดิม
- ❌ `InpHero_StickySet = false` → fallback v1.51 dynamic refresh เป๊ะ ๆ

ยืนยันว่าไม่กระทบ trading logic — เป็นการเปลี่ยนแค่ "ใครจะถูก tag เป็น Hero" หลัง phase active เท่านั้น
