

## บันทึกกฎเหล็กการพัฒนา EA เข้าระบบ Memory

### สิ่งที่จะทำ

สร้าง Project Knowledge entry ใหม่เพื่อฝังกฎมาตรฐานการพัฒนา MQL5 EA ไว้ในระบบถาวร ทำให้ทุกการสนทนาในอนาคตจะรับรู้กฎนี้โดยอัตโนมัติ โดยไม่ต้องพูดซ้ำอีก

### เนื้อหากฎเหล็กที่จะบันทึก

**หัวข้อ**: `mql5-ea-development-rules`

**เนื้อหา**:

```text
กฎเหล็กการพัฒนา MQL5 EA (บังคับทุกไฟล์ .mq5)

เมื่อแก้ไขหรือเพิ่มฟีเจอร์ใน EA ใดก็ตาม:

1. ห้ามแก้ไข Order Execution Logic
   - ห้ามแตะ code ที่เกี่ยวกับการเปิด/ปิดออเดอร์ (OrderSend, trade.Buy, trade.Sell, trade.PositionClose)
   - ยกเว้นกรณีที่ user ระบุชัดเจนว่าต้องการแก้ไขส่วนนี้โดยเฉพาะ

2. ห้ามแก้ไข Trading Strategy Logic
   - SMA/EMA signal conditions
   - Grid entry/exit logic (ทั้ง Loss grid และ Profit grid)
   - TP/SL/Trailing/Breakeven calculations
   - Accumulate close / Basket close logic
   - Drawdown exit logic
   - Entry conditions (shouldEnterBuy/shouldEnterSell)
   - ยกเว้น user ระบุชัดเจนว่าต้องการแก้ไขกลยุทธ์

3. ห้ามแก้ไข Core Module Logic
   - License verification module
   - News filter core logic (IsNewsTimePaused, RefreshNewsData)
   - Time filter core logic (IsWithinTradingHours)
   - Data sync logic
   - ยกเว้น user ระบุชัดเจนว่าต้องการแก้ไข module นั้น

4. สิ่งที่ทำได้โดยไม่ต้องขออนุญาตพิเศษ
   - เพิ่ม input parameters ใหม่
   - เพิ่ม global variables ใหม่
   - เพิ่ม/แก้ไข Dashboard display
   - เพิ่ม/แก้ไข OnChartEvent buttons
   - เพิ่ม helper functions ใหม่
   - เพิ่ม guard conditions ที่ block entry (เช่น g_newOrderBlocked)
   - แก้ไข OnDeinit cleanup

5. ทุกครั้งที่แก้ไข EA ต้องระบุในแผนว่า
   - "สิ่งที่ไม่เปลี่ยนแปลง" มีอะไรบ้าง
   - ยืนยันว่าไม่กระทบ trading logic

กฎนี้ใช้กับทุกไฟล์ .mq5 ใน public/docs/mql5/ และ docs/mql5/
```

### วิธีดำเนินการ

ผู้ใช้ต้องเพิ่ม Knowledge entry นี้ผ่าน **Project Settings -> Manage Knowledge** เนื่องจากระบบไม่สามารถเพิ่ม Knowledge โดยตรงผ่าน code ได้ แต่ผมจะสร้างไฟล์ `.lovable/rules.md` ไว้ใน project เพื่อให้ระบบอ่านกฎนี้ได้ทุกครั้งที่เริ่มสนทนาใหม่

### รายละเอียดทางเทคนิค

สร้างไฟล์: `.lovable/rules.md` -- ไฟล์นี้จะถูกอ่านโดยระบบอัตโนมัติทุกครั้ง ทำให้กฎเหล็กมีผลถาวรโดยไม่ต้องพูดซ้ำ

