
## แผนปรับปรุง Harmony Dream EA v1.8.6

### เป้าหมาย:
1. เปลี่ยน Comment prefix จาก `HrmDream_` เป็นตัวย่อคู่เงิน (เช่น `EU-GU`)
2. ตรวจสอบและแก้ไขการคำนวณ Lot บน Dashboard (Main + Sub)
3. เปลี่ยนชื่อ Dashboard Title เป็น "Moneyx Harmony Dream v1.8.6"
4. เพิ่ม Confirmation Popup ก่อนกดปุ่มทุกปุ่มบน Dashboard

---

### 1. สร้างฟังก์ชัน GetPairAbbreviation() (ใหม่)

สร้างฟังก์ชันใหม่เพื่อแปลงชื่อ Symbol เป็นตัวย่อ:

**ตำแหน่ง:** หลัง OnInit() หรือใน Helper Functions section

```text
// ตารางการแปลงชื่อ Symbol → ตัวย่อ
string GetSymbolAbbreviation(string symbol)
{
   // ลบ suffix ออกก่อน (e.g., EURUSD.i, EURUSDm)
   string cleanSymbol = symbol;
   int dotPos = StringFind(symbol, ".");
   if(dotPos > 0) cleanSymbol = StringSubstr(symbol, 0, dotPos);
   
   // Gold pairs
   if(StringFind(cleanSymbol, "XAUUSD") >= 0) return "XU";
   if(StringFind(cleanSymbol, "XAUEUR") >= 0) return "XE";
   
   // Major pairs - ใช้ 2 ตัวอักษรแรกของแต่ละสกุลเงิน
   if(StringFind(cleanSymbol, "EURUSD") >= 0) return "EU";
   if(StringFind(cleanSymbol, "GBPUSD") >= 0) return "GU";
   if(StringFind(cleanSymbol, "AUDUSD") >= 0) return "AU";
   if(StringFind(cleanSymbol, "NZDUSD") >= 0) return "NU";
   if(StringFind(cleanSymbol, "USDJPY") >= 0) return "UJ";
   if(StringFind(cleanSymbol, "USDCHF") >= 0) return "UC";
   if(StringFind(cleanSymbol, "USDCAD") >= 0) return "UCd";
   
   // Cross pairs
   if(StringFind(cleanSymbol, "EURGBP") >= 0) return "EG";
   if(StringFind(cleanSymbol, "EURJPY") >= 0) return "EJ";
   if(StringFind(cleanSymbol, "EURCHF") >= 0) return "EC";
   if(StringFind(cleanSymbol, "EURAUD") >= 0) return "EA";
   if(StringFind(cleanSymbol, "EURNZD") >= 0) return "EN";
   if(StringFind(cleanSymbol, "EURCAD") >= 0) return "ECd";
   if(StringFind(cleanSymbol, "GBPJPY") >= 0) return "GJ";
   if(StringFind(cleanSymbol, "GBPCHF") >= 0) return "GC";
   if(StringFind(cleanSymbol, "GBPAUD") >= 0) return "GA";
   if(StringFind(cleanSymbol, "GBPNZD") >= 0) return "GN";
   if(StringFind(cleanSymbol, "GBPCAD") >= 0) return "GCd";
   if(StringFind(cleanSymbol, "AUDJPY") >= 0) return "AJ";
   if(StringFind(cleanSymbol, "AUDNZD") >= 0) return "AN";
   if(StringFind(cleanSymbol, "AUDCAD") >= 0) return "ACd";
   if(StringFind(cleanSymbol, "AUDCHF") >= 0) return "AC";
   if(StringFind(cleanSymbol, "NZDJPY") >= 0) return "NJ";
   if(StringFind(cleanSymbol, "NZDCHF") >= 0) return "NC";
   if(StringFind(cleanSymbol, "CADJPY") >= 0) return "CJ";
   if(StringFind(cleanSymbol, "CADCHF") >= 0) return "CC";
   if(StringFind(cleanSymbol, "CHFJPY") >= 0) return "CHJ";
   
   // Fallback: ใช้ 2 ตัวแรกของ Symbol
   return StringSubstr(cleanSymbol, 0, 2);
}

// สร้าง Pair Abbreviation (e.g., "EU-GU")
string GetPairCommentPrefix(int pairIndex)
{
   string abbrevA = GetSymbolAbbreviation(g_pairs[pairIndex].symbolA);
   string abbrevB = GetSymbolAbbreviation(g_pairs[pairIndex].symbolB);
   return abbrevA + "-" + abbrevB;
}
```

---

### 2. อัพเดท Order Comment ทุกที่ที่ใช้ HrmDream_

**ตำแหน่งที่ต้องเปลี่ยน:**

| บรรทัด | ประเภท Order | Comment เดิม | Comment ใหม่ |
|--------|--------------|--------------|--------------|
| 5636-5643 | Grid Loss BUY | `HrmDream_GL_BUY_%d[...]` | `%s_GL_BUY[...]` |
| 5721-5728 | Grid Loss SELL | `HrmDream_GL_SELL_%d[...]` | `%s_GL_SELL[...]` |
| 5806-5813 | Grid Profit BUY | `HrmDream_GP_BUY_%d[...]` | `%s_GP_BUY[...]` |
| 5886-5893 | Grid Profit SELL | `HrmDream_GP_SELL_%d[...]` | `%s_GP_SELL[...]` |
| 6018-6025 | Main BUY | `HrmDream_BUY_%d[...]` | `%s_BUY[...]` |
| 6196-6203 | Main SELL | `HrmDream_SELL_%d[...]` | `%s_SELL[...]` |

**ตัวอย่างการเปลี่ยน (Main BUY):**

จาก:
```text
comment = StringFormat("HrmDream_BUY_%d[ADX:%.0f/%.0f][M:%d]", 
                       pairIndex + 1, adxA, adxB, InpMagicNumber);
```

เป็น:
```text
string pairPrefix = GetPairCommentPrefix(pairIndex);
comment = StringFormat("%s_BUY[ADX:%.0f/%.0f][M:%d]", 
                       pairPrefix, adxA, adxB, InpMagicNumber);
```

**ผลลัพธ์ตัวอย่าง:**
- คู่ EURUSD/GBPUSD → `EU-GU_BUY[ADX:25/30][M:888888]`
- คู่ AUDUSD/USDCAD → `AU-UCd_GL_SELL[M:888888]`
- คู่ XAUUSD/XAUEUR → `XU-XE_BUY[M:888888]`

---

### 3. ตรวจสอบการคำนวณ Lot บน Dashboard

**สถานะปัจจุบัน (บรรทัด 7986-7987, 8032-8033):**
```text
double buyLot = g_pairs[i].directionBuy == 1 ? g_pairs[i].lotBuyA + g_pairs[i].lotBuyB : 0;
double sellLot = g_pairs[i].directionSell == 1 ? g_pairs[i].lotSellA + g_pairs[i].lotSellB : 0;
```

**วิเคราะห์:**
- ✅ โค้ดปัจจุบันรวม Main + Sub แล้ว (`lotBuyA + lotBuyB`)
- ❓ แต่อาจมีปัญหาเมื่อ orderCountBuy > 1 (Grid orders)

**ปัญหาที่อาจเกิด:**
เมื่อมี Grid Orders หลายตัว (เช่น Main + Grid Loss 2 ตัว) ค่า `lotBuyA` และ `lotBuyB` อาจเก็บเฉพาะ Lot ของ Main Order ไม่รวม Grid

**แนวทางแก้ไข:**
สร้างฟังก์ชันคำนวณ Total Lot จาก Positions จริงแทนการใช้ค่าจาก struct:

```text
double GetTotalLotForPair(int pairIndex, bool isBuySide)
{
   double totalLot = 0;
   string symbolA = g_pairs[pairIndex].symbolA;
   string symbolB = g_pairs[pairIndex].symbolB;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      
      string sym = PositionGetString(POSITION_SYMBOL);
      string comment = PositionGetString(POSITION_COMMENT);
      long magic = PositionGetInteger(POSITION_MAGIC);
      
      if(magic != InpMagicNumber) continue;
      
      // ตรวจสอบว่า comment มี pair prefix ที่ถูกต้อง
      string pairPrefix = GetPairCommentPrefix(pairIndex);
      if(StringFind(comment, pairPrefix) < 0) continue;
      
      // ตรวจสอบฝั่ง Buy/Sell
      if(isBuySide && StringFind(comment, "_BUY") < 0) continue;
      if(!isBuySide && StringFind(comment, "_SELL") < 0) continue;
      
      totalLot += PositionGetDouble(POSITION_VOLUME);
   }
   
   return totalLot;
}
```

**อัพเดท UpdateDashboard() (บรรทัด 7986-7987):**

จาก:
```text
double buyLot = g_pairs[i].directionBuy == 1 ? g_pairs[i].lotBuyA + g_pairs[i].lotBuyB : 0;
```

เป็น:
```text
double buyLot = g_pairs[i].directionBuy == 1 ? GetTotalLotForPair(i, true) : 0;
```

---

### 4. เปลี่ยนชื่อ Dashboard Title

**ตำแหน่ง:** บรรทัด 7399

จาก:
```text
ObjectSetString(0, prefix + "TITLE_NAME", OBJPROP_TEXT, "Harmony Dream EA v1.8.5");
```

เป็น:
```text
ObjectSetString(0, prefix + "TITLE_NAME", OBJPROP_TEXT, "Moneyx Harmony Dream v1.8.6");
```

---

### 5. เพิ่ม Confirmation Popup ก่อนกดปุ่ม

**ตำแหน่ง:** OnChartEvent() บรรทัด 2213-2292

**หลักการ:**
ใช้ `MessageBox()` ถามยืนยันก่อนทำงานทุกปุ่ม:

```text
int result = MessageBox("Are you sure you want to [ACTION]?", 
                        "Confirm Action", 
                        MB_YESNO | MB_ICONQUESTION);
if(result != IDYES) 
{
   ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
   return;
}
```

**รายการปุ่มที่ต้องเพิ่ม Confirmation:**

| ปุ่ม | Message |
|------|---------|
| Close Buy (per pair) | "Close Buy side for Pair X?" |
| Close Sell (per pair) | "Close Sell side for Pair X?" |
| Toggle Buy Status | "Toggle Buy side for Pair X?" |
| Toggle Sell Status | "Toggle Sell side for Pair X?" |
| Close All Buy | "Close ALL Buy positions?" |
| Close All Sell | "Close ALL Sell positions?" |
| Start All | "Start ALL pairs?" |
| Stop All | "Stop ALL pairs?" |
| Pause/Start Global | "Pause/Resume EA?" |

**ตัวอย่างโค้ดใหม่ (Close Buy per pair):**

```text
if(StringFind(sparam, prefix + "_CLOSE_BUY_") >= 0)
{
   int pairIndex = (int)StringToInteger(StringSubstr(sparam, StringLen(prefix + "_CLOSE_BUY_")));
   
   // v1.8.6: Confirmation popup
   string msg = StringFormat("Close Buy side for Pair %d (%s)?", 
                             pairIndex + 1, 
                             g_pairs[pairIndex].symbolA + "/" + g_pairs[pairIndex].symbolB);
   int result = MessageBox(msg, "Confirm Close", MB_YESNO | MB_ICONQUESTION);
   if(result != IDYES)
   {
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      return;
   }
   
   CloseBuySide(pairIndex);
   ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
}
```

---

### 6. อัพเดท Version

**บรรทัด 7:**
```text
#property version   "1.86"
```

---

### สรุปไฟล์ที่ต้องแก้ไข:

| ไฟล์ | การเปลี่ยนแปลง |
|------|----------------|
| `public/docs/mql5/Harmony_Dream_EA.mq5` | เพิ่มฟังก์ชัน GetSymbolAbbreviation() และ GetPairCommentPrefix(), อัพเดท Comment ทุกที่, เพิ่ม GetTotalLotForPair(), เพิ่ม MessageBox confirmations, เปลี่ยน Title |

---

### สิ่งที่ไม่แตะต้อง:

- Trading Logic (Entry/Exit conditions)
- ADX / CDC / Correlation Calculation
- Grid Distance และ Lot Sizing Logic
- License System
- Theme System (v1.8.5)

---

### ผลลัพธ์ที่คาดหวัง:

**Order Comments (ในมือถือ/Terminal):**
- เดิม: `HrmDream_BUY_1[M:888888]`
- ใหม่: `EU-GU_BUY[M:888888]` ← เห็นชัดว่าคู่ไหน

**Dashboard Lot Column:**
- แสดง Total Lots ของทั้ง Main + Sub + Grid Orders

**Dashboard Title:**
- "Moneyx Harmony Dream v1.8.6"

**Button Actions:**
- ทุกปุ่มจะมี Popup ถามยืนยันก่อนทำงาน
