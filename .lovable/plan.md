## แผนแก้ไข v1.55 — Hero Dynamic Refresh ให้เปลี่ยน Ticket จริง ไม่ล็อคค้าง

จากโค้ดปัจจุบันพบจุดสำคัญว่า ถึงแม้ `InpHero_StickySet=false` แล้ว แต่โครงสร้างภายในยังใช้ `g_heroBuyStable/g_heroSellStable` แบบ “stable set” และมีคอมเมนต์/logic บางส่วนที่ยังยึดแนวคิด freeze จาก v1.49/v1.52 อยู่ ทำให้ในบางจังหวะ ticket เดิมยังถูกมองเป็น Hero ต่อ และ ticket ใหม่ที่ราคาดีกว่าไม่ถูกสลับเข้า Hero จริงทั้งบน Dashboard และใน guard ของออเดอร์จริง

### เป้าหมายพฤติกรรมที่จะแก้

- SELL Hero ต้องเลือก ticket ที่ราคาเปิดสูงที่สุด N ใบเสมอ
- BUY Hero ต้องเลือก ticket ที่ราคาเปิดต่ำที่สุด N ใบเสมอ
- เมื่อมี order ใหม่ที่ “ดีกว่า” เข้ามา ต้องสลับ Hero set ทันทีใน tick เดียวกัน
- Ticket ที่หลุดจาก Hero ต้องกลับไปเป็น non-Hero จริง: restore TP เดิม และล้าง SL lock-profit ที่มาจาก Hero
- Ticket ที่เข้ามาเป็น Hero ใหม่ต้องถูกถอด TP ทันที เพื่อไม่ให้ basket TP/Avg TP ปิดผิดตัว
- Dashboard `Tix SELL/Tix BUY` ต้องแสดงชุดเดียวกับที่ `IsHeroProtectedTicket()` ใช้งานจริง

### สิ่งที่จะเปลี่ยนในไฟล์ `public/docs/mql5/Golden_Kuy3_EA.mq5`

1. **เพิ่ม version เป็น v1.55 ทุกจุดตามกฎ EA**
   - `#property version`
   - `#property description`
   - header comment
   - Dashboard title / Hero panel
   - log init/deinit และ log Hero ที่เกี่ยวข้อง

2. **แก้ `BuildHeroTicketCache()` Branch A ให้เป็น dynamic rebuild จริง**
   - ตอน `curPhase != 0` และ `InpHero_StickySet=false`:
     - scan order ฝั่งนั้นทั้งหมด
     - sort ตาม price-extreme
       - BUY: ราคาต่ำสุดก่อน
       - SELL: ราคาสูงสุดก่อน
     - เลือกจำนวน `InpHero_OrderCount`
     - rebuild `g_heroBuyStable/g_heroSellStable` ใหม่ทุกครั้งจากผล sort
   - เปลี่ยนชื่อ/คอมเมนต์ใน log จาก `STABLE/FROZEN` ให้ชัดว่าเป็น `DYNAMIC PRICE-EXTREME`

3. **แก้ activation ครั้งแรกให้สอดคล้องกับ dynamic mode**
   - ตอน phase ยังเป็น `NONE`:
     - ถ้า `InpHero_StickySet=false` ใช้ `take = MathMin(InpHero_OrderCount, nPool)` เพื่อให้ Hero นับครบ N ใบจริงตามที่ Dashboard แสดง
     - ถ้า `InpHero_StickySet=true` คงพฤติกรรมเดิมแบบ fallback sticky ได้
   - ยังคง activation threshold (`InpHero_MinOrdersToActivate`) เดิม ไม่เปลี่ยนเงื่อนไขการเริ่ม Hero

4. **ทำ sync ตอน Hero set เปลี่ยนให้ครบทั้ง demote และ promote**
   - คง `RestoreInitialTPOnDemoted()` ไว้ แต่จะให้ทำงานทุกครั้งที่มี ticket หลุดจาก Hero set
   - เพิ่ม helper สำหรับ ticket ที่ถูก promote เข้า Hero ใหม่ ให้ถอด TP ทันที (`TP=0`) โดยคง SL เดิมไว้ใน ARMED phase ตามกฎ v1.45
   - ถ้าอยู่ BE_GUARD แล้วมี Hero set เปลี่ยน จะ reset `g_heroBE_Applied_* = false` เพื่อให้ `ApplyHeroLockProfitSL()` ลง SL lock-profit ให้ ticket Hero ชุดใหม่

5. **ป้องกัน dashboard/guard ใช้ข้อมูลคนละชุด**
   - หลัง rebuild จะสร้าง `g_heroTickets[]` จาก stable set ล่าสุดทันที
   - Dashboard ticket list จะอ่านจากชุดล่าสุดเดียวกัน
   - เพิ่ม audit log แบบ throttle แสดง `oldSet -> newSet` พร้อม price เพื่อยืนยันว่ามีการสลับจริง เช่น SELL ควรเห็น ticket ราคาสูงสุดล่าสุดเข้ามาแทน ticket เก่า

6. **คง `InpHero_StickySet=true` เป็นโหมด fallback เท่านั้น**
   - หากผู้ใช้ตั้งค่าเป็น true จะยังกลับไปพฤติกรรม freeze แบบ v1.52 ได้
   - แต่ default จะยังเป็น false และ dashboard จะแสดงให้ชัดว่า mode เป็น Dynamic ไม่ใช่ Sticky

### สิ่งที่ไม่เปลี่ยนแปลง / ไม่กระทบ Trading Logic

- ไม่แก้ `trade.Buy`, `trade.Sell`, `OrderSend`, logic เปิดออเดอร์
- ไม่แก้เงื่อนไข Grid entry / Grid lot / Grid distance
- ไม่แก้ Per-order trailing, BE, TP, SL calculation
- ไม่แก้ Average TP / Average Trailing strict 2-cross
- ไม่แก้ Accumulate close / Cost-Hit Restart
- ไม่แก้ logic ปิดออเดอร์ Hero (`CloseHeroOnSide`) ยกเว้นการทำให้ ticket ที่เป็น Hero จริงตรงกับชุด dynamic ล่าสุด
- ไม่แก้ Side-Alternation v1.46 และ Single-Side Lock v1.45
- ไม่แก้ gate v1.50/v1.51 ที่ให้ Hero ปิดเฉพาะเมื่อ opposite basket ปิดด้วย Avg-TP/Avg-Trail/Master TP/Accumulate

### ผลลัพธ์ที่คาดหวัง

จากเคสในรูปที่ SELL มี active 36 และ Hero=5:

- `Tix SELL` จะต้องอัปเดตเป็น 5 ticket ที่ราคา SELL สูงสุดล่าสุด ไม่ค้างที่ `#42 #41 #39 #29 #28`
- Ticket SELL เดิมที่ไม่ติด top 5 แล้ว จะกลับไปเป็น non-Hero และมี TP/SL ตามระบบปกติ
- Ticket SELL ใหม่ที่ราคาสูงกว่า จะถูก protect เป็น Hero จริงทั้ง Dashboard และ guard (`IsHeroProtectedTicket`) ใน tick เดียวกัน
- ไม่มีการล็อค Hero ตาม ticket เก่าอีกต่อไปใน dynamic mode