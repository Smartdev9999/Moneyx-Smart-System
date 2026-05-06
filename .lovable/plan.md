## ปัญหา v1.52
Sticky Set ทำให้ Hero ล็อคที่ ticket แรกตอน activate (เช่น SELL #41,#42) แม้จะมี SELL ใหม่เปิดที่ราคาสูงกว่าตามที่ผู้ใช้ต้องการ. ผู้ใช้ต้องการให้ Hero อัปเดต ticket ตามราคา-สุดขอบเสมอ (BUY = ต่ำสุด N ตัว, SELL = สูงสุด N ตัว) จนกว่าฝั่งตรงข้ามจะปิดกำไร non-Hero แบบปกติ.

## v1.53 — Dynamic Hero Refresh + Demote Restore

หลักการ: ฟื้น dynamic refresh แบบ v1.48 พร้อมแก้ bug 2 อย่างที่เคยทำให้ ticket หลุดถูก BE close:
1. **Promote (เพิ่ม Hero ใหม่):** เคลียร์ `g_heroBE_Applied_<side>` ให้ `ApplyHeroLockProfitSL` วาง BE-SL ลงไม้ใหม่ (มีอยู่แล้วใน v1.48)
2. **Demote (Hero เก่าหลุดเป็น non-Hero):** เพิ่ม helper `RestoreInitialTPOnDemoted(prevSet, newSet, side)` คืน TP เดิม (`InpInitialTPPips`) และล้าง lock-profit SL ออกจาก ticket ที่ถูก push ออก เพื่อให้ join basket ปกติได้ ปิดร่วมกับ Avg-TP ของฝั่งเดียวกันได้

### จุดแก้ใน `public/docs/mql5/Golden_Kuy3_EA.mq5`

| จุด | บรรทัดเดิม | การเปลี่ยน |
|---|---|---|
| `#property version` + description | 23, 4-19 | bump v1.52 → v1.53 + บรรทัด `v1.53: Hero Dynamic Refresh + Demote Restore` |
| `InpHero_StickySet` default | 110 | เปลี่ยน default เป็น `false` (= dynamic refresh) แต่คง input ไว้สำหรับ rollback |
| Branch A (line 534-592) | | ตัด `if(InpHero_StickySet) {...continue;}` shortcut ออก เมื่อ default=false. คง logic v1.51 dynamic refresh + diff detection |
| **ใหม่:** ก่อน `ClearStableSet` (ราว 571) | | เก็บ `prevSet[]` (มีอยู่แล้ว 564-569). หลัง rebuild ที่ 572-573 → คำนวณ `demoted[]` = ticket ที่อยู่ใน prevSet แต่ไม่อยู่ใน newSet → เรียก `RestoreInitialTPOnDemoted` |
| **ใหม่:** function `RestoreInitialTPOnDemoted` | ใต้ `StripBrokerTPSLFromHeroTickets` | สำหรับแต่ละ demoted ticket: คำนวณ TP ใหม่จาก `openPrice ± PipsToPrice(InpInitialTPPips)` (เคารพ STOPS_LEVEL); ตั้ง SL = 0 (หรือคง SL เดิมถ้า InpUseBreakeven/Trail เปิด); `trade.PositionModify(ticket, newSL, newTP)`. Print log `v1.53 Hero DEMOTE restore TP: #ticket TP=...` |
| `g_heroBE_Applied_<side> = false` | 587-588 | คงไว้ (v1.48 logic) — ไม้ใหม่จะถูก lock-profit SL ใน BE_GUARD รอบถัดไป |
| Dashboard version string | (search "v1.52") | bump |

### ผลลัพธ์
- มี SELL ใหม่เปิดราคา 3354.06 → Hero set อัปเดตเป็น 5 ตัว highest price → ticket #41,#42 (ราคาต่ำกว่า) ถูก demote → ได้ TP เดิมคืน → ปิดร่วม Avg-TP ฝั่ง SELL ปกติ
- Hero (5 ตัว top extreme) ยังคง strip TP / lock SL เพื่อกันหน้าทุน
- เมื่อฝั่งตรงข้าม (BUY basket) ปิดกำไรครบ → Hero SELL ทั้ง 5 ตัวปิดด้วย gating v1.51 (Avg-TP intent) → side-alternation ทำงานปกติ
- Single-Side Lock v1.45 / Alternation v1.46 / Post-close grace ทำงานเหมือนเดิม เพราะ "Hero CLOSE" event เกิดเฉพาะ ManageHeroOppositeClose → CloseHeroOnSide เท่านั้น (demote ไม่ใช่ close)

### สิ่งที่ไม่เปลี่ยน (กฎเหล็ก)
- ไม่แตะ `trade.Buy/Sell/PositionClose`/OrderSend
- ไม่แตะ Grid entry/exit/lot multiplier
- ไม่แตะ Per-Order BE/Trail/SL/TP/Cost-Hit
- ไม่แตะ Avg-TP/Avg-Trail strict-2-cross/Accumulate
- ไม่แตะ `ApplyHeroLockProfitSL`/`ComputeHeroLockProfitSL`/`StripBrokerTPSLFromHeroTickets`
- ไม่แตะ Single-Side Lock v1.45, Side-Alternation Lock v1.46, Post-close grace, External-close detection
- ไม่แตะ v1.50 `oppRealized` gate, v1.51 Avg-TP intent flag (5 จุด set + Master TP safety + 60s expiry)
- ไม่แตะ `IsHeroProtectedTicket` 9 guards
- `InpHero_Enabled=false` → behavior เดิม
- `InpHero_StickySet=true` → fallback v1.52 sticky behavior (no-op refresh + no demote restore)
