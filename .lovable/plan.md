แผน v1.58: Hero Handoff Reserve + Conditional Alternation Lock

ปัญหาที่ต้องแก้
1. Hero ออกฝั่งเดียวสลับได้ครบ 2 รอบ แต่รอบที่ 3 ระบบ "ปิดรวบ" ทุกออเดอร์ฝั่งตรงข้ามรวมทั้งตัวที่ควรกันไว้เป็น Hero ชุดถัดไป
2. ถ้าทั้งสองฝั่งยังไม่ครบเงื่อนไข Hero (จำนวนออเดอร์ไม่ถึง `InpHero_MinOrdersToActivate`) — ระบบไม่ควร "ล็อค" ฝั่งใดไว้ก่อน ให้รีเซ็ตเสมือนเริ่มเทรดใหม่ ฝั่งไหนชน TP ก่อนก็ได้สิทธิ์เป็น Hero รอบใหม่

หลักการ flow ที่ต้องการ
```
[เริ่มเทรด] ทั้ง BUY/SELL ยังไม่ถึง threshold -> Next Allowed = ANY
    ฝั่งใดถึง threshold ก่อน -> Hero ฝั่งนั้น (เช่น BUY)
    SELL basket ชน TP -> ปิด BUY Hero + กัน SELL Hero ชุดถัดไป
    BUY basket ชน TP -> ปิด SELL Hero + กัน BUY Hero ชุดถัดไป
    วนสลับต่อเนื่อง

[ถ้าทั้งสองฝั่ง flat / ไม่ถึง threshold พร้อมกัน]
    ปลด Next Allowed กลับเป็น ANY
    ระบบไม่ผูกฝั่ง — รอฝั่งไหนถึง threshold ก่อนค่อย Hero ฝั่งนั้น
```

การเปลี่ยนแปลงในโค้ด `public/docs/mql5/Golden_Kuy3_EA.mq5`

1. เลข version v1.57 -> v1.58 ทุกจุด
- `#property version`, `#property description`
- Header comment block แบบสั้น (ไม่มี history ยาวตามที่คุณขอ)
- Dashboard title `Golden Kuy3 v1.58`, Hero panel `=== HERO ORDER (v1.58) ===`
- Log prefix `v1.58 Hero ...`

2. Hero Handoff Reserve (กันชุด Hero ฝั่งตรงข้ามล่วงหน้า)
- ขณะฝั่งหนึ่งเป็น Owner (`BE_GUARD`) เช่น SELL Hero ค้าง — อนุญาตให้ฝั่ง BUY ถูกเลือกเป็น Hero Candidate (`ARMED`) ล่วงหน้าได้แม้ Single-Side Lock เปิดอยู่
- Candidate ถูก Strip TP-only เหมือน ARMED ปกติ → BUY basket ชน TP จะปิดเฉพาะ non-Hero, ส่วน BUY Reserve รอด
- เมื่อ TP-event latch ปิด SELL Hero แล้ว — BUY ที่กันไว้กลายเป็น Owner ของรอบถัดไปทันที

3. Conditional Alternation Lock (ใหม่ตามที่ user ขอ)
- `g_heroNextAllowedSide` จะถูก stamp เฉพาะตอนฝั่งตรงข้าม "ครบ threshold พร้อมเป็น Reserve" หรือ "มี Hero จริงแล้ว"
- ถ้าฝั่งตรงข้ามยังไม่ถึง threshold → ไม่ stamp Next Allowed (ปล่อยเป็น ANY)
- เพิ่มฟังก์ชัน `MaintainNextAllowedReset()` รันทุก tick:
  - ถ้า BUY และ SELL ทั้งคู่ phase=NONE และ active < threshold ทั้งสองฝั่ง → reset `g_heroNextAllowedSide = -1`
  - log throttled 30s: `v1.58 Hero ALT-RESET — both sides under threshold, lock cleared`
- ผลลัพธ์: ถ้าหลังปิด Hero แล้วทั้งสองฝั่ง flat/น้อย → ระบบกลับเป็น ANY ไม่บังคับสลับฝั่ง

4. แก้การ rebuild หลัง CloseHeroOnSide()
- ปิดเฉพาะ Hero ฝั่งที่กำหนด, clear stable set เฉพาะฝั่งนั้น
- rebuild `g_heroTickets[]` จาก stable set ที่เหลือทันทีใน tick เดียว
- Reserve ฝั่งตรงข้ามยังถูกป้องกันต่อเนื่อง

5. Dashboard ปรับให้เห็นชัด
- `Hero Owner`: BUY/SELL locked หรือ NONE
- `Next Allowed`: BUY only / SELL only / **ANY (no lock)**
- `Handoff Reserve`: เช่น `BUY armed (reserve while SELL owner)` หรือ `-`
- `TP Event`: คงเดิม

ไม่เปลี่ยนแปลง (กฎเหล็ก)
- Grid entry/exit logic, Lot multiplier (`CalcGridLot`)
- `trade.Buy` / `trade.Sell` / `trade.PositionClose` ทุกจุด
- Per-Order BE/Trail/SL/TP, Avg-TP/Avg-Trail strict-2-cross
- Accumulate Close, Cost-Hit Restart
- `IsHeroProtectedTicket` 9 guards
- `ApplyHeroLockProfitSL` / `ComputeHeroLockProfitSL`
- หลักการเลือก Hero: BUY ราคาต่ำสุด N ตัว / SELL ราคาสูงสุด N ตัว
- จำนวน Hero ใช้ `InpHero_OrderCount`, threshold `InpHero_MinOrdersToActivate`
- `InpHero_Enabled=false` → behavior เดิม

ไฟล์ที่จะปรับหลังอนุมัติ
- `public/docs/mql5/Golden_Kuy3_EA.mq5`
- สร้าง memory `mem://trading/golden-kuy3/v1-58-handoff-reserve-conditional-lock`
- update `mem://index.md`

<lov-actions>
<lov-link url="https://docs.lovable.dev/tips-tricks/troubleshooting">Troubleshooting docs</lov-link>
</lov-actions>