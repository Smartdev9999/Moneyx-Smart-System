

## แผนแก้ไข Grid Order Issues - Harmony Dream EA v1.8.8 Hotfix

### สรุปปัญหาที่พบ (2 ปัญหาหลัก):

#### ปัญหาที่ 1: Grid Comment ไม่มี Level Number (#1, #2, #3...)

**ตอนนี้ผิด:**
```text
XU-XE_GL_SELL_20[M:888888]   ← ไม่มี Grid Level
```

**ที่ควรจะเป็น:**
```text
XU-XE_GL#1_SELL_20[M:888888]  ← มี Grid Level
```

**สาเหตุ:**
- บรรทัด 6112, 6198, 6284, 6365 ใช้ `pairIndex + 1` แทน Grid Level
- ไม่มีการใส่ #number ลงใน Comment

---

#### ปัญหาที่ 2: Total Basket ไปรบกวน Grid Order Count

เมื่อเปิด Total Basket:
- `g_accumulatedBasketProfit` ถูกเก็บสะสมจาก Group ที่ปิดไปแล้ว
- แต่อาจมีการ reset หรือ conflict กับ Grid Order Count

**เมื่อปิด Total Basket:**
- ระบบไม่ใช้ `CheckTotalTarget()` ส่วนที่เกี่ยวกับ Total Basket
- Grid Orders ทำงานปกติเพราะไม่มี interference

---

### รายละเอียดการแก้ไข:

#### 1. แก้ไข OpenGridLossBuy() - เพิ่ม Grid Level ใน Comment

**ตำแหน่ง:** บรรทัด 6107-6120

**เดิม:**
```mql5
string pairPrefix = GetPairCommentPrefix(pairIndex);
string comment;
if(corrType == -1 && InpUseADXForNegative)
{
     comment = StringFormat("%s_GL_BUY_%d[ADX:%.0f/%.0f][M:%d]", 
                            pairPrefix, pairIndex + 1, ...);
}
else
{
   comment = StringFormat("%s_GL_BUY_%d[M:%d]", pairPrefix, pairIndex + 1, InpMagicNumber);
}
```

**แก้ไขเป็น:**
```mql5
// v1.8.8 HF: Get next Grid Level BEFORE opening (current count + 1)
int gridLevel = g_pairs[pairIndex].avgOrderCountBuy + 1;

string pairPrefix = GetPairCommentPrefix(pairIndex);
string comment;
if(corrType == -1 && InpUseADXForNegative)
{
     comment = StringFormat("%s_GL#%d_BUY_%d[ADX:%.0f/%.0f][M:%d]", 
                            pairPrefix, gridLevel, pairIndex + 1, ...);
}
else
{
   comment = StringFormat("%s_GL#%d_BUY_%d[M:%d]", pairPrefix, gridLevel, pairIndex + 1, InpMagicNumber);
}
```

---

#### 2. แก้ไข OpenGridLossSell() - เพิ่ม Grid Level

**ตำแหน่ง:** บรรทัด 6193-6206

**แก้ไขเหมือนกัน:**
```mql5
int gridLevel = g_pairs[pairIndex].avgOrderCountSell + 1;

// ... ใน StringFormat ใช้ %s_GL#%d_SELL_%d ...
```

---

#### 3. แก้ไข OpenGridProfitBuy() - เพิ่ม Grid Level

**ตำแหน่ง:** บรรทัด 6279-6292

**แก้ไข:**
```mql5
int gridLevel = g_pairs[pairIndex].gridProfitCountBuy + 1;

// ... ใน StringFormat ใช้ %s_GP#%d_BUY_%d ...
```

---

#### 4. แก้ไข OpenGridProfitSell() - เพิ่ม Grid Level

**ตำแหน่ง:** บรรทัด 6360-6373

**แก้ไข:**
```mql5
int gridLevel = g_pairs[pairIndex].gridProfitCountSell + 1;

// ... ใน StringFormat ใช้ %s_GP#%d_SELL_%d ...
```

---

### สรุปไฟล์ที่ต้องแก้ไข:

| ไฟล์ | การเปลี่ยนแปลง |
|------|----------------|
| `public/docs/mql5/Harmony_Dream_EA.mq5` | แก้ไข 4 ฟังก์ชัน OpenGridLossBuy/Sell, OpenGridProfitBuy/Sell เพิ่ม Grid Level (#1, #2...) ใน Comment |

---

### ผลลัพธ์ที่คาดหวัง:

**Comment Format ใหม่:**
```text
XU-XE_GL#1_SELL_20[M:888888]   ← Grid Loss #1
XU-XE_GL#2_SELL_20[M:888888]   ← Grid Loss #2
XU-XE_GL#3_SELL_20[M:888888]   ← Grid Loss #3

XU-XE_GP#1_SELL_20[M:888888]   ← Grid Profit #1
XU-XE_GP#2_SELL_20[M:888888]   ← Grid Profit #2
```

---

### หมายเหตุเกี่ยวกับ Total Basket:

จากการทดสอบของผู้ใช้ - เมื่อปิด Total Basket แล้ว Grid ทำงานปกติ:
- ปัญหา Total Basket interference เป็นเรื่องแยกต่างหาก
- Hotfix นี้จะแก้ไข Grid Level Comment ก่อน
- หากยังมีปัญหา Grid Count เมื่อเปิด Total Basket จะวิเคราะห์เพิ่มเติม

---

### สิ่งที่ไม่แตะต้อง:

- Entry Mode Logic (Z-Score / Correlation Only)
- Grid Distance Calculation  
- Grid Lot Sizing Logic (CDC Multiplier, ADX)
- Total Basket Logic (จะทดสอบแยก)
- Auto Balance Scaling

