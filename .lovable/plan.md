
## แก้ไขปัญหา EA ไม่ออกออเดอร์ใหม่หลังปิด

### สาเหตุ

เมื่อ Broker ปิด position ผ่าน SL (จาก Per-Order Trailing) ตัว EA ไม่ได้ตรวจจับว่า position หายไป ทำให้ `g_initialBuyPrice` และ `g_initialSellPrice` ยังคงค้างเป็นค่าเดิม (ไม่ใช่ 0)

ในขณะที่ Entry Logic บรรทัด 375 ต้องการ:

```text
if(buyCount == 0 && g_initialBuyPrice == 0 && ...)
```

เมื่อ `g_initialBuyPrice` ยังไม่เป็น 0 -> ไม่ผ่านเงื่อนไข -> ไม่เปิดออเดอร์ใหม่

### การแก้ไข

| ไฟล์ | รายละเอียด |
|------|-----------|
| `public/docs/mql5/Gold_Miner_EA.mq5` | เพิ่ม auto-detect เมื่อ position ถูกปิดโดย broker |

### สิ่งที่จะเพิ่ม

**เพิ่มโค้ดหลัง CountPositions() (บรรทัด ~335) ก่อน Grid Logic:**

```text
// Auto-detect broker-closed positions (e.g. trailing SL hit by broker)
if(buyCount == 0 && g_initialBuyPrice != 0)
{
   Print("BUY cycle ended (broker SL). Resetting g_initialBuyPrice.");
   g_initialBuyPrice = 0;
}
if(sellCount == 0 && g_initialSellPrice != 0)
{
   Print("SELL cycle ended (broker SL). Resetting g_initialSellPrice.");
   g_initialSellPrice = 0;
}
```

Logic: ถ้าไม่มี position ฝั่งนั้นเหลือแล้ว แต่ initialPrice ยังค้างอยู่ แสดงว่า broker ปิดให้ -> reset เพื่อให้ Entry Logic ทำงานได้

### สิ่งที่ไม่เปลี่ยน

- Entry Logic, Grid Logic, Trailing, Accumulate ทั้งหมดคงเดิม
- เพิ่มแค่ 2 บล็อก if-check เท่านั้น
