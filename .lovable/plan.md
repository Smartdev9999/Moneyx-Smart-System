ผมเข้าใจประเด็นแล้วครับ: `20 orders` คือจำนวนออเดอร์ที่ยังเปิดอยู่ ณ ตอนนั้น ไม่ใช่ประวัติรวม และเมื่อฝั่ง BUY มี active ถึง 36 orders พร้อมตั้ง `InpHero_OrderCount=3` ระบบต้องกัน BUY 3 ออเดอร์ล่าสุดไว้เป็น Hero ทันที ไม่ใช่กันแค่ตัวที่ 18-20 ตอนแตะ threshold ครั้งแรก

จากรูปเห็นว่า EA เป็น v6.97 [INST] และมีเส้น broker TP สีฟ้า/เส้นปิดเฉลี่ยที่ปิด basket ไปทั้งหมด แปลว่า Hero 3 ตัวล่าสุดยังไม่ได้ถูก strip TP/SL หรือยังไม่ได้อยู่ใน cache ตอน broker TP ถูกตั้ง/ถูกชน

Do I know what the issue is? Yes.

ปัญหาหลักที่เจอในโค้ด v6.97 คือ Hero cache ยังไม่ hard real-time พอ:

1. `BuildHeroTicketCache()` rebuild ที่ต้น `OnTick()` และมี throttle ด้วย `TimeCurrent()` ระดับ 1 วินาที ถ้า order เพิ่มหลายตัวในวินาทีเดียวกัน หรือ `SyncBrokerTPSL()` ถูกเรียกหลังเปิด grid ภายใน tick เดียวกัน cache อาจยังไม่ใช่ latest 3 จริง
2. `SyncBrokerTPSL()` เป็นตัวตั้ง broker TP จริงบนออเดอร์ ถ้า latest 3 ยังไม่ถูก mark เป็น Hero ก่อนเข้าฟังก์ชันนี้ มันจะได้รับ TP สีฟ้าเหมือนออเดอร์ทั่วไป แล้ว broker จะปิดเองทันทีเมื่อราคาชน TP โดย EA ไม่มีโอกาสมา `skip IsHeroTicket()` ภายหลัง
3. การ sort “ออเดอร์ล่าสุด” ตอนนี้ใช้ `POSITION_TIME` ระดับวินาที ทำให้ถ้าเปิดหลายออเดอร์ในวินาทีเดียวกัน การเลือก 3 ตัวล่าสุดอาจไม่แน่นอน ต้องใช้ `POSITION_TIME_MSC` และ fallback ด้วย ticket number

แผนแก้ v6.98:

1. ทำ Hero selection เป็น rolling latest-N แบบ deterministic
   - เปลี่ยนการเลือก Hero ให้เรียงด้วย `POSITION_TIME_MSC` จากใหม่ไปเก่า
   - ถ้าเวลาเท่ากัน ให้ใช้ ticket ที่มากกว่าเป็นตัวใหม่กว่า
   - เมื่อฝั่งที่ locked มี active orders >= `InpHero_MinOrdersToActivate` จะเลือก `InpHero_OrderCount` ตัวล่าสุดเสมอ เช่น active BUY 36 และ HeroCount 3 = ticket ล่าสุด 3 ตัวเท่านั้น
   - ไม่ใช่ snapshot เฉพาะตอนแตะ 20 orders ครั้งแรก

2. ตัด throttle ที่ทำให้ cache stale
   - ให้ Hero cache rebuild ทุก tick / ทุกครั้งที่ต้อง sync TP ไม่ผูกกับ `TimeCurrent()`
   - ยังคง throttle เฉพาะ audit log เพื่อไม่ให้ Journal spam

3. เพิ่ม helper ป้องกันก่อน broker TP ทุกครั้ง
   - เพิ่ม `EnsureHeroProtection(reason)` ทำงานตามลำดับ:
     1. rebuild Hero cache ทันที
     2. เลือก latest N tickets ของ locked side
     3. force strip TP/SL ของ Hero tickets ใน phase ARMED
     4. log ticket ที่ถูกกันไว้ เช่น `v6.98 Hero PROTECT BUY active=36 keep=3 tickets=...`
   - เรียก helper นี้ก่อน `SyncBrokerTPSL()` จะ set TP/SL
   - เรียกซ้ำหลัง `SyncBrokerTPSL()` เป็น defense-in-depth เพื่อเคลียร์ TP ที่หลุดมา

4. ปิดช่องทาง basket close ที่ cache stale
   - ที่ `CloseAllSide()` และ `CloseGenSide()` จะ force refresh Hero cache ก่อน loop ปิด basket
   - ยืนยันให้ `IsHeroTicket(ticket)` skip Hero ก่อน `trade.PositionClose(ticket)` เหมือนเดิม แต่จะใช้ cache ล่าสุดเสมอ
   - เพิ่ม Hero skip ใน `CloseAllSideTF()` ด้วย เพื่อป้องกันโหมด multi-timeframe ปิด Hero ผ่านทาง per-TF basket close

5. เพิ่ม log/debug ให้ตรวจง่ายใน Strategy Tester
   - เพิ่ม log เมื่อ Hero lock ฝั่ง BUY/SELL
   - เพิ่ม log เมื่อ latest 3 เปลี่ยนตามออเดอร์ใหม่
   - เพิ่ม audit ทุก 30 วินาที: active BUY/SELL, threshold, locked side, protected ticket count, phase
   - อัปเดต Dashboard ให้เห็น Hero status ชัดขึ้น เช่น `Hero BUY: active 36 / keep 3 / ARMED`

6. Version bump ตามกฎโปรเจกต์
   - อัปเดตเป็น v6.98 ใน:
     - `#property version`
     - `#property description`
     - header comment
     - dashboard title/version/log text

สิ่งที่ไม่เปลี่ยนแปลง:

- ไม่เปลี่ยนเงื่อนไขเข้าออเดอร์ BUY/SELL
- ไม่เปลี่ยน Grid Loss / Grid Profit logic
- ไม่เปลี่ยนสูตร Average TP / TP target calculation
- ไม่เปลี่ยน lot calculation
- ไม่เปลี่ยน hedge / triple-gate / recovery logic
- ไม่เปลี่ยน drawdown / balance guard / news / license / sync module
- ไม่แก้ `OrderSend`, `trade.Buy`, `trade.Sell` หรือเงื่อนไขเปิดออเดอร์
- การปิดแบบ emergency/global เช่น manual `Close All`, drawdown stop, accumulate close ยังตั้งใจเป็น close-all จริง และจะไม่ให้ Hero ฝืนรอด ยกเว้นถ้าคุณต้องการให้ Hero รอดจาก global close ด้วย

ผลลัพธ์หลังแก้:

ถ้า `InpHero_MinOrdersToActivate=20` และ `InpHero_OrderCount=3`:

```text
BUY active 19  -> Hero 0
BUY active 20  -> protect latest 3 BUY
BUY active 25  -> protect latest 3 BUY ใหม่ล่าสุด
BUY active 36  -> protect latest 3 BUY ใหม่ล่าสุด
Average TP hit -> close BUY basket 33 orders, เหลือ BUY Hero 3 orders
```

<lov-actions>
  <lov-open-history>View History</lov-open-history>
  <lov-link url="https://docs.lovable.dev/tips-tricks/troubleshooting">Troubleshooting docs</lov-link>
</lov-actions>